# Carrier Strike → Roblox: пошаговая инструкция

Это не «перенос» файла: игра написана на JavaScript, а в Roblox пишут на Luau. Модели и идеи переносятся, код пишется заново. Ниже — порядок, в котором это делать, и готовые скрипты для магазина и B-2.

## ⚠️ Сначала про лицензии моделей (важно!)
Продажа за Robux — это **коммерческое использование**.
- Модели с лицензией **CC BY** (можно, с указанием автора): F-16, Рафаль, F/A-18, Су-33, AV-8B, МиГ-21, A-4, кабина F-16.
- Модели **bohmerang** (Мираж 2000, F-35, МиГ-29, F-4, **B-2**) имеют лицензию **CC BY-NC-SA — только некоммерческое**. Продавать их (и B-2 за 200 Robux) **нельзя**.
- Что делать с B-2: найти на Sketchfab модель B-2 с лицензией **CC BY** или **CC0** (в поиске включи фильтр лицензии), либо заказать/сделать свою, либо написать автору bohmerang и попросить письменное разрешение.
- Авторов с CC BY надо указать в описании игры (список есть в `real/README.md`).

## Шаг 1. Roblox Studio и проект
1. Скачай **Roblox Studio** (create.roblox.com) и войди в аккаунт.
2. New → шаблон **Baseplate**. Назови проект Carrier Strike.
3. Включи сохранение игры: File → Publish to Roblox.

## Шаг 2. Загрузить самолёты
1. Файлы `.glb` лежат в папке `real/` репозитория avia (у тебя на GitHub: etueque-blip/avia).
2. В Studio: вкладка **Avatar → Import 3D** (или View → Asset Manager → Bulk Import). Выбери `.glb`/`.fbx`.
3. Модели с миллионами треугольников Roblox не принимает: лимит около 10–20 тысяч на деталь. Тяжёлые упрости в Blender (Decimate) или возьми модель полегче.
4. Каждый самолёт сделай **Model** с главной деталью `PrimaryPart` (центр самолёта), положи в `ReplicatedStorage/Planes/` под именами `f16`, `fa18`, `su33`…

## Шаг 3. Полёт
Самый простой рабочий вариант для начала:
- Игрок «садится» в самолёт (`VehicleSeat` в кабине).
- Локальный скрипт читает клавиши/джойстик, сервер двигает самолёт через `LinearVelocity` + `AlignOrientation`: тяга вперёд, крен/тангаж — вращение.
- Для телефона и iPad Roblox сам даёт виртуальный джойстик (`ContextActionService`).

Этот шаг самый большой. Напиши мне «делаем полёт», и я дам готовый скрипт управления отдельно — тестировать его придётся тебе в Studio (кнопка Play), у меня Roblox Studio нет.

## Шаг 4. Валюта и сохранение
Создай скрипт `ServerScriptService/Data` (Script):
```lua
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local store = DataStoreService:GetDataStore("CarrierStrikeV1")

local DEFAULT = { credits = 1500, owned = { f16 = true }, inv = {} }
_G.PlayerData = {}

local function load(player)
	local ok, data = pcall(function() return store:GetAsync("u" .. player.UserId) end)
	_G.PlayerData[player] = (ok and data) or table.clone(DEFAULT)
	local ls = Instance.new("Folder"); ls.Name = "leaderstats"; ls.Parent = player
	local cr = Instance.new("IntValue"); cr.Name = "Credits"; cr.Value = _G.PlayerData[player].credits; cr.Parent = ls
end

local function save(player)
	local d = _G.PlayerData[player]; if not d then return end
	local cr = player:FindFirstChild("leaderstats") and player.leaderstats.Credits.Value
	if cr then d.credits = cr end
	pcall(function() store:SetAsync("u" .. player.UserId, d) end)
end

Players.PlayerAdded:Connect(load)
Players.PlayerRemoving:Connect(function(p) save(p); _G.PlayerData[p] = nil end)
game:BindToClose(function() for _, p in Players:GetPlayers() do save(p) end end)
```
В Game Settings → Security включи **Enable Studio Access to API Services**, чтобы DataStore работал при тесте.

## Шаг 5. B-2 за 200 Robux (Game Pass)
1. create.roblox.com → твоя игра → **Monetization → Passes → Create a Pass**. Название «B-2 Spirit», цена **200**, и сохрани ID пасса.
2. Скрипт `ServerScriptService/B2Pass` (Script):
```lua
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local B2_PASS_ID = 0 -- ← ВСТАВЬ ID ПАССА

local function hasB2(player)
	local ok, owns = pcall(function() return MarketplaceService:UserOwnsGamePassAsync(player.UserId, B2_PASS_ID) end)
	return ok and owns
end

-- вызывается, когда игрок выбирает B-2 в ангаре
local ask = Instance.new("RemoteFunction"); ask.Name = "CanUsePlane"; ask.Parent = game.ReplicatedStorage
ask.OnServerInvoke = function(player, planeId)
	if planeId ~= "b2" then return true end
	if hasB2(player) then return true end
	MarketplaceService:PromptGamePassPurchase(player, B2_PASS_ID)
	return false
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if purchased and passId == B2_PASS_ID then
		local e = game.ReplicatedStorage:FindFirstChild("B2Unlocked"); if e then e:FireClient(player) end
	end
end)
```
Всегда проверяй владение на **сервере** (как тут), а не на клиенте.

## Шаг 6. Магазин (Developer Products, покупаются много раз)
Предметы те же, что в браузерной версии: броня, ловушки, двойной боезапас, мощные боеголовки, заряды ПРО, зенитный щит.
1. Monetization → **Developer Products** → создай по одному на каждый предмет. Запиши ID и цену (например 50–150 Robux).
2. Скрипт `ServerScriptService/Shop` (Script):
```lua
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local PRODUCTS = {
	[0] = "armor",    -- ← замени 0 на ID продукта «Усиленная броня»
	[1] = "flares",   -- ← ID «Запас ловушек»
	[2] = "ammo",
	[3] = "warhead",
	[4] = "aps",
	[5] = "sam",
}

MarketplaceService.ProcessReceipt = function(info)
	local player = Players:GetPlayerByUserId(info.PlayerId)
	local item = PRODUCTS[info.ProductId]
	if not player or not item then return Enum.ProductPurchaseDecision.NotProcessedYet end
	local d = _G.PlayerData[player]; if not d then return Enum.ProductPurchaseDecision.NotProcessedYet end
	d.inv[item] = (d.inv[item] or 0) + 1
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- кнопка в интерфейсе вызывает это на клиенте:
-- MarketplaceService:PromptProductPurchase(player, productId)
```
3. Эффекты предметов при вылете (как в `useShop()` в `index.html`): броня +40% HP, ловушки +30, патроны ×2, урон ракет ×1,35, ПРО +3, зенитный щит — вдвое чаще ПВО авианосца. Расходуются на один вылет.

## Шаг 7. Игровая экономика (как в браузерной версии)
- Кредиты (Credits) за сбитых и за задания — внутриигровая валюта, **не Robux**.
- Robux только за B-2 и предметы из магазина.
- Не делай так, чтобы платные предметы были обязательны: «pay to win» в Roblox ругают в отзывах.

## Что дальше
1. Импорт самолётов (шаг 2) и тест, что они не слишком тяжёлые.
2. Полёт (шаг 3) — самый сложный кусок.
3. Остальное из браузерной игры: острова, авианосец, враги-боты, ракеты — переносим по очереди.

Напиши, с какого шага начинаем, и я подготовлю скрипт именно для него.
