# 3D-рендер иконки и обложек

`scene.html` — сцена на three.js: закатное небо, океан, авианосец, острова с рельефом, самолёты из `Avia/real/*.glb`.
Перерисовать: положить рядом ссылку `real` на папку `Avia/real`, запустить `python3 -m http.server 8790` и `node shot.js` (Playwright).
Режимы: `?m=icon` (512×512), `?m=t1` (Dogfight), `?m=t2` (Capture Islands). Рендер в 2× и уменьшение — сглаживание.

Модели (только с лицензией CC BY 4.0 — их можно использовать в рекламе):
- Boeing F/A-18E/F Super Hornet — andertan (Sketchfab), CC BY 4.0
- Sukhoi Su-33 — andertan (Sketchfab), CC BY 4.0
- Dassault Rafale — andertan (Sketchfab), CC BY 4.0
