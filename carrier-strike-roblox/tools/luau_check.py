#!/usr/bin/env python3
"""Проверка Luau-кода без Roblox Studio.

Что ловит:
  * синтаксические ошибки (полный разбор Luau: типы, +=, if-выражения, `::`, строки `...{x}...`);
  * чтение переменных, которые нигде не объявлены (опечатки, local, объявленный ниже места использования);
  * запись в необъявленные (глобальные) переменные;
  * обращения Модуль.поле к своим модулям (require), если такого поля в модуле нет;
  * вызовы ui.xxx (интерфейс из Hud.new), которых Hud не определяет.

Запуск:  python3 tools/luau_check.py src
"""
import os
import re
import sys

ROBLOX_GLOBALS = set("""
game workspace script plugin shared _G Instance Vector3 Vector2 Vector3int16 Vector2int16 CFrame Color3 UDim UDim2 Enum
task math string table os typeof type pairs ipairs next select tostring tonumber print warn error pcall xpcall require
setmetatable getmetatable rawget rawset rawequal rawlen unpack utf8 bit32 buffer coroutine debug tick time wait delay spawn
Random BrickColor NumberSequence NumberSequenceKeypoint ColorSequence ColorSequenceKeypoint TweenInfo Ray RaycastParams
Region3 Region3int16 Rect PhysicalProperties NumberRange Font DateTime OverlapParams assert Axes Faces PathWaypoint
SharedTable newproxy gcinfo elapsedTime settings UserSettings DockWidgetPluginGuiInfo CatalogSearchParams
""".split())

KEYWORDS = set("and break do else elseif end false for function if in local nil not or repeat return then true until while".split())

SYMBOLS = ["...", "..=", "//=", "..", "::", "->", "==", "~=", "<=", ">=", "+=", "-=", "*=", "/=", "%=", "^=", "//",
           "+", "-", "*", "/", "%", "^", "#", "<", ">", "=", "(", ")", "{", "}", "[", "]", ";", ":", ",", ".", "?", "|", "&", "@"]


class LuauError(Exception):
    pass


RE_LCOM = re.compile(r"--\[(=*)\[")
RE_LSTR = re.compile(r"\[(=*)\[")
RE_NUM = re.compile(r"0[xX][0-9a-fA-F_]+|0[bB][01_]+|(\d[\d_]*)?\.?\d[\d_]*([eE][+-]?\d+)?")
RE_NAME = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")


def tokenize(src):
    toks = []
    i, n, line = 0, len(src), 1
    while i < n:
        c = src[i]
        if c == "\n":
            line += 1
            i += 1
            continue
        if c in " \t\r":
            i += 1
            continue
        if src.startswith("--", i):
            m = RE_LCOM.match(src, i)
            if m:
                end = "]" + m.group(1) + "]"
                j = src.find(end, i)
                if j < 0:
                    raise LuauError(f"line {line}: незакрытый длинный комментарий")
                line += src[i:j].count("\n")
                i = j + len(end)
            else:
                j = src.find("\n", i)
                i = n if j < 0 else j
            continue
        m = RE_LSTR.match(src, i)
        if m:
            end = "]" + m.group(1) + "]"
            j = src.find(end, i)
            if j < 0:
                raise LuauError(f"line {line}: незакрытая длинная строка")
            toks.append(("str", src[i:j + len(end)], line))
            line += src[i:j].count("\n")
            i = j + len(end)
            continue
        if c in "\"'":
            j = i + 1
            while True:
                if j >= n or src[j] == "\n":
                    raise LuauError(f"line {line}: незакрытая строка")
                if src[j] == "\\":
                    j += 2
                    continue
                if src[j] == c:
                    break
                j += 1
            toks.append(("str", src[i:j + 1], line))
            i = j + 1
            continue
        if c == "`":
            # интерполированная строка: выражения в {} разбираем отдельно
            j = i + 1
            parts = []
            while True:
                if j >= n:
                    raise LuauError(f"line {line}: незакрытая строка с `")
                if src[j] == "\\":
                    j += 2
                    continue
                if src[j] == "`":
                    break
                if src[j] == "{":
                    depth, k = 1, j + 1
                    while depth:
                        if src[k] == "{":
                            depth += 1
                        elif src[k] == "}":
                            depth -= 1
                        k += 1
                    parts.append((src[j + 1:k - 1], line))
                    j = k
                    continue
                if src[j] == "\n":
                    line += 1
                j += 1
            toks.append(("istr", parts, line))
            i = j + 1
            continue
        m = RE_NUM.match(src, i)
        if m and m.group(0) and (c.isdigit() or (c == "." and i + 1 < n and src[i + 1].isdigit())):
            toks.append(("num", m.group(0), line))
            i += len(m.group(0))
            continue
        m = RE_NAME.match(src, i)
        if m:
            w = m.group(0)
            toks.append(("kw" if w in KEYWORDS else "name", w, line))
            i += len(w)
            continue
        for s in SYMBOLS:
            if src.startswith(s, i):
                toks.append(("op", s, line))
                i += len(s)
                break
        else:
            raise LuauError(f"line {line}: неизвестный символ {c!r}")
    toks.append(("eof", "<eof>", line))
    return toks


class Parser:
    def __init__(self, src, path):
        self.t = tokenize(src)
        self.p = 0
        self.path = path
        self.scopes = [set()]
        self.problems = []
        self.fields = []  # (alias, field, line)
        self.alias_mod = {}  # local name -> module name
        self.defined_fields = {}  # name -> set(fields) assigned like X.f = / function X.f

    # ---------- helpers
    def peek(self, k=0):
        return self.t[self.p + k]

    def at(self, v, k=0):
        tk = self.t[self.p + k]
        return tk[1] == v and tk[0] in ("op", "kw")

    def at_name(self, v=None):
        tk = self.peek()
        return tk[0] == "name" and (v is None or tk[1] == v)

    def next(self):
        tk = self.t[self.p]
        self.p += 1
        return tk

    def expect(self, v):
        tk = self.next()
        if tk[1] != v or tk[0] not in ("op", "kw"):
            raise LuauError(f"line {tk[2]}: ожидалось '{v}', а стоит '{tk[1]}'")
        return tk

    def name(self):
        tk = self.next()
        if tk[0] != "name":
            raise LuauError(f"line {tk[2]}: ожидалось имя, а стоит '{tk[1]}'")
        return tk[1]

    def declare(self, n):
        self.scopes[-1].add(n)

    def resolve(self, n, line, write=False):
        for s in reversed(self.scopes):
            if n in s:
                return
        if n in ROBLOX_GLOBALS and not write:
            return
        if write:
            self.problems.append(f"{self.path}:{line}: запись в глобальную переменную '{n}' (нет local?)")
        else:
            self.problems.append(f"{self.path}:{line}: '{n}' не объявлена (опечатка или local ниже по коду?)")

    # ---------- types
    def parse_type(self):
        self.parse_simple_type()
        while True:
            if self.at("?"):
                self.next()
            elif self.at("|") or self.at("&"):
                self.next()
                self.parse_simple_type()
            else:
                break

    def parse_type_list_paren(self):
        # после '(' ; возвращает True, если было "-> ..."
        self.expect("(")
        while not self.at(")"):
            if self.at("..."):
                self.next()
                if not self.at(")") and not self.at(","):
                    self.parse_type()
            elif self.peek()[0] == "name" and self.at(":", 1):
                self.next()
                self.next()
                self.parse_type()
            else:
                self.parse_type()
            if self.at(","):
                self.next()
            else:
                break
        self.expect(")")
        if self.at("->"):
            self.next()
            self.parse_type()

    def parse_simple_type(self):
        tk = self.peek()
        if self.at("("):
            self.parse_type_list_paren()
        elif self.at("{"):
            self.next()
            while not self.at("}"):
                if self.at("["):
                    self.next()
                    self.parse_type()
                    self.expect("]")
                    self.expect(":")
                    self.parse_type()
                elif self.peek()[0] == "name" and self.at(":", 1):
                    self.next()
                    self.next()
                    self.parse_type()
                elif self.at_name("read") or self.at_name("write"):
                    self.next()
                    if self.peek()[0] == "name" and self.at(":", 1):
                        self.next()
                        self.next()
                    self.parse_type()
                else:
                    self.parse_type()
                if self.at(",") or self.at(";"):
                    self.next()
                else:
                    break
            self.expect("}")
        elif self.at("<"):
            self.parse_generic_decl()
            self.parse_type_list_paren()
        elif self.at("..."):
            self.next()
            self.parse_type()
        elif tk[0] == "str":
            self.next()
        elif self.at("nil") or self.at("true") or self.at("false"):
            self.next()
        elif tk[0] == "name" and tk[1] == "typeof":
            self.next()
            self.expect("(")
            self.parse_expr()
            self.expect(")")
        elif tk[0] == "name":
            self.next()
            if self.at("."):
                self.next()
                self.name()
            if self.at("<"):
                self.next()
                while not self.at(">"):
                    if self.at("("):
                        self.parse_type_list_paren()
                    else:
                        self.parse_type()
                    if self.at(","):
                        self.next()
                    else:
                        break
                self.expect(">")
        else:
            raise LuauError(f"line {tk[2]}: непонятный тип '{tk[1]}'")

    def parse_generic_decl(self):
        if self.at("<"):
            self.next()
            while not self.at(">"):
                if self.at("..."):
                    self.next()
                else:
                    self.name()
                    if self.at("..."):
                        self.next()
                    if self.at("="):
                        self.next()
                        self.parse_type()
                if self.at(","):
                    self.next()
                else:
                    break
            self.expect(">")

    # ---------- blocks
    def block(self, end_tokens):
        while not any(self.at(e) for e in end_tokens) and self.peek()[0] != "eof":
            if self.statement():
                # return / break: дальше в блоке только ';'
                pass

    def push(self):
        self.scopes.append(set())

    def pop(self):
        self.scopes.pop()

    def funcbody(self, method=False):
        self.parse_generic_decl()
        self.expect("(")
        self.push()
        if method:
            self.declare("self")
        while not self.at(")"):
            if self.at("..."):
                self.next()
                if self.at(":"):
                    self.next()
                    self.parse_type()
                break
            self.declare(self.name())
            if self.at(":"):
                self.next()
                self.parse_type()
            if self.at(","):
                self.next()
            else:
                break
        self.expect(")")
        if self.at(":"):
            self.next()
            self.parse_type()
        self.block(["end"])
        self.expect("end")
        self.pop()

    def statement(self):
        tk = self.peek()
        v = tk[1]
        line = tk[2]
        if self.at(";"):
            self.next()
            return False
        if tk[0] == "kw":
            if v == "local":
                self.next()
                if self.at("function"):
                    self.next()
                    n = self.name()
                    self.declare(n)
                    self.funcbody()
                    return False
                names = []
                while True:
                    names.append(self.name())
                    if self.at("<"):  # атрибуты <const>/<close>
                        self.next()
                        self.name()
                        self.expect(">")
                    if self.at(":"):
                        self.next()
                        self.parse_type()
                    if self.at(","):
                        self.next()
                    else:
                        break
                req = None
                if self.at("="):
                    self.next()
                    start = self.p
                    self.explist()
                    req = self.t[start:self.p]
                for n in names:
                    self.declare(n)
                if req and len(names) == 1:
                    txt = " ".join(x[1] if isinstance(x[1], str) else "`" for x in req)
                    m = re.search(r'require \( (?:.*?WaitForChild \( "(\w+)" \)|script \. (\w+)|Shared \. (\w+))', txt)
                    if m and txt.startswith("require"):
                        self.alias_mod[names[0]] = next(g for g in m.groups() if g)
                return False
            if v == "function":
                self.next()
                n = self.name()
                full = [n]
                self.resolve(n, line)
                method = False
                while self.at(".") or self.at(":"):
                    method = self.at(":")
                    self.next()
                    full.append(self.name())
                if len(full) == 2:
                    self.defined_fields.setdefault(full[0], set()).add(full[1])
                self.funcbody(method)
                return False
            if v == "if":
                self.next()
                self.parse_expr()
                self.expect("then")
                self.push()
                self.block(["elseif", "else", "end"])
                self.pop()
                while self.at("elseif"):
                    self.next()
                    self.parse_expr()
                    self.expect("then")
                    self.push()
                    self.block(["elseif", "else", "end"])
                    self.pop()
                if self.at("else"):
                    self.next()
                    self.push()
                    self.block(["end"])
                    self.pop()
                self.expect("end")
                return False
            if v == "while":
                self.next()
                self.parse_expr()
                self.expect("do")
                self.push()
                self.block(["end"])
                self.pop()
                self.expect("end")
                return False
            if v == "do":
                self.next()
                self.push()
                self.block(["end"])
                self.pop()
                self.expect("end")
                return False
            if v == "for":
                self.next()
                n1 = self.name()
                if self.at(":"):
                    self.next()
                    self.parse_type()
                if self.at("="):
                    self.next()
                    self.parse_expr()
                    self.expect(",")
                    self.parse_expr()
                    if self.at(","):
                        self.next()
                        self.parse_expr()
                    names = [n1]
                else:
                    names = [n1]
                    while self.at(","):
                        self.next()
                        names.append(self.name())
                        if self.at(":"):
                            self.next()
                            self.parse_type()
                    self.expect("in")
                    self.explist()
                self.expect("do")
                self.push()
                for n in names:
                    self.declare(n)
                self.block(["end"])
                self.pop()
                self.expect("end")
                return False
            if v == "repeat":
                self.next()
                self.push()
                self.block(["until"])
                self.expect("until")
                self.parse_expr()
                self.pop()
                return False
            if v == "return":
                self.next()
                if not (self.at("end") or self.at("else") or self.at("elseif") or self.at("until") or self.peek()[0] == "eof" or self.at(";")):
                    self.explist()
                if self.at(";"):
                    self.next()
                if not (self.at("end") or self.at("else") or self.at("elseif") or self.at("until") or self.peek()[0] == "eof"):
                    raise LuauError(f"line {line}: после return должен закончиться блок")
                return True
            if v == "break":
                self.next()
                return True
            raise LuauError(f"line {line}: неожиданное '{v}'")
        if tk[0] == "name" and v == "continue" and not (self.at("=", 1) or self.at(".", 1) or self.at("(", 1) or self.at("[", 1) or self.at(":", 1)):
            self.next()
            return True
        if tk[0] == "name" and v in ("type", "export") and (self.peek(1)[0] == "name"):
            if v == "export":
                self.next()
            if self.at_name("type"):
                self.next()
                self.name()
                self.parse_generic_decl()
                self.expect("=")
                self.parse_type()
                return False
        # присваивание или вызов
        targets = [self.suffixedexp(assign_ctx=True)]
        while self.at(","):
            self.next()
            targets.append(self.suffixedexp(assign_ctx=True))
        if self.at("=") or (self.peek()[0] == "op" and self.peek()[1] in ("+=", "-=", "*=", "/=", "%=", "^=", "..=", "//=")):
            op = self.next()[1]
            if op == "=":
                self.explist()
            else:
                self.parse_expr()
            for kind, info in targets:
                if kind == "name":
                    self.resolve(info[0], info[1], write=(op == "="))
                    if op != "=":
                        pass
                elif kind == "field":
                    base, field = info
                    self.defined_fields.setdefault(base, set()).add(field)
        else:
            if len(targets) != 1 or targets[0][0] != "call":
                raise LuauError(f"line {line}: это не вызов и не присваивание")
        return False

    def explist(self):
        self.parse_expr()
        while self.at(","):
            self.next()
            self.parse_expr()

    # ---------- expressions
    BIN = {"or": 1, "and": 2, "<": 3, ">": 3, "<=": 3, ">=": 3, "~=": 3, "==": 3, "..": 5, "+": 6, "-": 6,
           "*": 7, "/": 7, "//": 7, "%": 7, "^": 10}
    RIGHT = {"..", "^"}

    def parse_expr(self, limit=0):
        if self.at("not") or self.at("-") or self.at("#"):
            self.next()
            self.parse_expr(8)
        else:
            self.simpleexp()
        while True:
            tk = self.peek()
            op = tk[1] if tk[0] in ("op", "kw") else None
            prec = self.BIN.get(op)
            if prec is None or prec <= limit:
                break
            self.next()
            self.parse_expr(prec - 1 if op in self.RIGHT else prec)

    def simpleexp(self):
        tk = self.peek()
        if tk[0] in ("num", "str"):
            self.next()
        elif tk[0] == "istr":
            self.next()
            for code, line in tk[1]:
                sub = Parser(code, self.path)
                sub.scopes = [set().union(*self.scopes)]
                sub.t = [(a, b, line) for (a, b, _) in tokenize(code)]
                sub.parse_expr()
                self.problems += sub.problems
        elif self.at("nil") or self.at("true") or self.at("false") or self.at("..."):
            self.next()
        elif self.at("function"):
            self.next()
            self.funcbody()
        elif self.at("{"):
            self.table()
        elif self.at("if"):
            self.next()
            self.parse_expr()
            self.expect("then")
            self.parse_expr()
            while self.at("elseif"):
                self.next()
                self.parse_expr()
                self.expect("then")
                self.parse_expr()
            self.expect("else")
            self.parse_expr()
        else:
            self.suffixedexp()
        if self.at("::"):
            self.next()
            self.parse_type()

    def table(self):
        self.expect("{")
        while not self.at("}"):
            if self.at("["):
                self.next()
                self.parse_expr()
                self.expect("]")
                self.expect("=")
                self.parse_expr()
            elif self.peek()[0] == "name" and self.at("=", 1):
                self.next()
                self.next()
                self.parse_expr()
            else:
                self.parse_expr()
            if self.at(",") or self.at(";"):
                self.next()
            else:
                break
        self.expect("}")

    def args(self):
        if self.at("("):
            self.next()
            if not self.at(")"):
                self.explist()
            self.expect(")")
        elif self.at("{"):
            self.table()
        elif self.peek()[0] == "str":
            self.next()
        else:
            tk = self.peek()
            raise LuauError(f"line {tk[2]}: ожидались аргументы вызова")

    def suffixedexp(self, assign_ctx=False):
        tk = self.peek()
        kind, info = None, None
        base_name = None
        if tk[0] == "name":
            self.next()
            base_name = tk[1]
            kind, info = "name", (tk[1], tk[2])
        elif self.at("("):
            self.next()
            self.parse_expr()
            self.expect(")")
            kind, info = "paren", None
        else:
            raise LuauError(f"line {tk[2]}: неожиданное '{tk[1]}'")
        first = True
        while True:
            if self.at("."):
                self.next()
                f = self.name()
                if first and base_name is not None:
                    self.fields.append((base_name, f, tk[2]))
                kind, info = "field", (base_name if first else None, f)
            elif self.at("["):
                self.next()
                self.parse_expr()
                self.expect("]")
                kind, info = "index", None
            elif self.at(":"):
                # метод — но в объявлении «local x: T» сюда не попадаем
                self.next()
                self.name()
                self.args()
                kind, info = "call", None
            elif self.at("(") or self.at("{") or self.peek()[0] == "str":
                if self.at("(") and self.peek()[2] != self.t[self.p - 1][2] and assign_ctx is False:
                    pass
                self.args()
                kind, info = "call", None
            else:
                break
            if first and base_name is not None and not (kind == "name"):
                pass
            first = False
        if base_name is not None and not (assign_ctx and kind == "name"):
            self.resolve(base_name, tk[2])
        elif base_name is not None and assign_ctx and kind != "name":
            self.resolve(base_name, tk[2])
        return kind, info

    def chunk(self):
        self.block([])
        if self.peek()[0] != "eof":
            tk = self.peek()
            raise LuauError(f"line {tk[2]}: лишнее '{tk[1]}'")


def module_fields(path):
    """Поля, которые модуль отдаёт наружу: X.f = / function X.f / ключи в return { ... }."""
    src = open(path, encoding="utf-8").read()
    p = Parser(src, path)
    p.chunk()
    m = re.search(r"\nreturn\s+(\w+)\s*$", src)
    fields = set()
    if m:
        fields |= p.defined_fields.get(m.group(1), set())
        # поля из табличного литерала local X = { a = ..., b = ... }
        lm = re.search(r"local\s+" + m.group(1) + r"(?:\s*:[^=]+)?\s*=\s*\{", src)
        if lm:
            fields |= top_keys(src, lm.end() - 1)
    else:
        rm = re.search(r"\nreturn\s*\{", src)
        if rm:
            fields |= top_keys(src, rm.end() - 1)
    return fields


def top_keys(src, brace):
    depth, i, keys = 0, brace, set()
    while i < len(src):
        c = src[i]
        if c in "{([":
            depth += 1
        elif c in "})]":
            depth -= 1
            if depth == 0:
                break
        elif depth == 1:
            m = re.match(r"([A-Za-z_]\w*)\s*=[^=]", src[i:])
            if m and (i == 0 or not (src[i - 1].isalnum() or src[i - 1] in "_.")):
                keys.add(m.group(1))
                i += len(m.group(1))
                continue
        elif c == "-" and src.startswith("--", i):
            i = src.find("\n", i)
            continue
        elif c in "\"'":
            j = i + 1
            while src[j] != c:
                j += 2 if src[j] == "\\" else 1
            i = j
        i += 1
    return keys


def main(root):
    files = []
    for d, _, fs in os.walk(root):
        for f in fs:
            if f.endswith(".luau") or f.endswith(".lua"):
                files.append(os.path.join(d, f))
    files.sort()
    exported = {}
    for f in files:
        name = os.path.basename(f).split(".")[0]
        if name in ("init",):
            continue
        try:
            exported[name] = module_fields(f)
        except LuauError:
            pass
    # интерфейс ui из Hud.new
    hud_ui = set()
    for f in files:
        if os.path.basename(f) == "Hud.luau":
            src = open(f, encoding="utf-8").read()
            hud_ui = set(re.findall(r"\bui\.([A-Za-z_]\w*)\s*=", src)) | set(re.findall(r"function ui\.([A-Za-z_]\w*)", src))
    bad = 0
    for f in files:
        src = open(f, encoding="utf-8").read()
        try:
            p = Parser(src, f)
            p.chunk()
        except LuauError as e:
            print(f"{f}: СИНТАКСИС: {e}")
            bad += 1
            continue
        for pr in p.problems:
            print(pr)
            bad += 1
        for alias, field, line in p.fields:
            mod = p.alias_mod.get(alias)
            if mod and mod in exported and exported[mod] and field not in exported[mod]:
                print(f"{f}:{line}: у модуля {mod} нет поля '{field}' ({alias}.{field})")
                bad += 1
        if hud_ui and os.path.basename(f) != "Hud.luau" and re.search(r"local ui\s*=\s*Hud\.new", src):
            for m in re.finditer(r"\bui\.([A-Za-z_]\w*)", src):
                if m.group(1) not in hud_ui:
                    line = src[:m.start()].count("\n") + 1
                    print(f"{f}:{line}: Hud не определяет ui.{m.group(1)}")
                    bad += 1
    print(f"Проверено файлов: {len(files)}, проблем: {bad}")
    return bad


if __name__ == "__main__":
    sys.exit(1 if main(sys.argv[1] if len(sys.argv) > 1 else "src") else 0)
