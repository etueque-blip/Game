# Game

- `uz-nomerok.html` — Uz Nomerok
- `carrier-strike.html` — **Carrier Strike**, carrier-based air combat (three.js). Open the file in a browser.
- `carrier-strike-original.html` — the original version, kept for comparison.

## Carrier Strike — what was upgraded

**Controls**
- Mouse-aim mode (default on desktop): the mouse steers a point in the sky and the jet's autopilot flies toward it; click captures the cursor, Esc opens the menu and pauses.
- Smooth keyboard input (no more jerky on/off), rotational inertia in the flight model, energy bleed in hard turns.
- Gamepad support (standard mapping), mouse wheel throttle, throttle on Shift/Z (Ctrl removed — Ctrl+W closed the tab).
- Visible touch joystick with a precision response curve; camera views (chase / close / cockpit) on V.
- Settings menu: mouse mode, sensitivity, invert, auto-level, camera, graphics quality (low/medium/high), sound.

**HUD**
- Pitch ladder, heading tape, gun boresight, gun lead pipper with range, missile lock progress, arrows to off-screen enemies and incoming missiles, radar sweep, landing guidance near your carrier.

**World**
- Four large city islands (Порт-Арка, Новоморск, Сан-Лазаро, Верхнегорск): skyscraper downtowns, streets, hills, harbours with cranes, lighthouses. Buildings are solid — you can crash into them; bots avoid them.
- Civilian shipping: container ships, tankers, ferries on sea lanes, fishing boats and yachts around the cities, all with wakes. Shown on the map and radar.

**Islands & capture**: five large tropical islands (smooth terrain coloured by height and slope, palms, forests, rocks) and two main city islands, Порт-Арка and Новоморск, that can be captured by flying inside the ring below 900 m. An owned island drains enemy tickets every 12 s and fires flak; capturing pays +300 CR / +200 XP. Bots fight over them too.

**Easier attacks**: player bullets hit more easily, rockets and bombs have bigger blasts, gun auto-aim also tracks ships, costs 1000 CR at level 2 and is available on more jets.

**Installable app**: manifest, icons and an offline service worker — add it to the home screen from Safari/Chrome.

**Flat turns**: ◀ ВЛЕВО / ВПРАВО ▶ buttons and the ←/→ keys bank about 60°, hold altitude and level the wings on release — no roll-overs. The touch stick and gamepad are bank-limited too; free barrel rolls stay on A/D and the БОЧКА button.

**Aerobatics**
- Full 360° loops and rolls: pull the mouse back (the aim view rolls with you over the top), hold S, or hold A/D (auto-level no longer caps bank).
- Automatic manoeuvres: N — loop, J / Shift+J — barrel roll; also ПЕТЛЯ / БОЧКА buttons on the HUD.

**New aircraft**: F/A-18E Super Hornet, Су-33, Rafale M, F-35C (stealth: enemies need longer to lock on).

**Ultra graphics**: new top quality level (2.5× resolution cap, 4096 shadows, stronger bloom), sun lens flare, cloud shadows on the sea, panel lines on the jets, afterburner shock diamonds.

**Main menu**: opens on start — menu panel on the left, your jet on the carrier deck on the right with a slow cinematic camera; arrows (or ←/→) flip through the jets, Enter starts.

**3D aircraft**: lofted airfoil wings, tails and fins (rounded leading edge, thinner tips), leading-edge extensions on modern fighters, pitot tubes, pylons, fin numbers, and moving control surfaces (all-moving tails and rudders follow your inputs).

**Menu showcase**: sunset sky over the sea, a formation of jets flying past with contrails, deck crew around your jet, and three cinematic camera shots with fades.

**Pilot levels & special modules**
- Pilot level 1–10 from XP (kills, ships, carrier landings, missions). Expensive jets need a level to buy.
- Special modules bought per plane (only on some jets) and switchable on/off in the hangar: Турбо-ускоритель (Y, +35% speed for 5 s, level 2), Автоприцел пушки (bullets steer to a plane near the reticle, level 3), Авто-ИК захват (IR missiles lock 3× faster in a wider cone, level 5).
- Jets with auto-aim / auto-IR cost more: МиГ-29 3000, F/A-18E 4500, Rafale M 6000, Су-33 6500, F-35C 9000 CR.

**Weapons**
- Missiles: AIM-9 / Р-73 (heat-seeking, can be decoyed by flares), AIM-120 / Р-77 (radar, long range, ignore flares), AGM-65 Maverick (guided anti-ship), AGM-84 Harpoon (sea-skimming anti-ship), plus rockets and bombs. Russian/Chinese jets get Р-73/Р-77.
- Five hangar loadouts; select weapons with 1–5, R/Tab or by tapping the weapon cards. Each missile has its own lock time, range and agility.

**Performance & menus**
- Static model parts are merged (far fewer draw calls), clouds are one instanced mesh, water only considers nearby ships/islands, adaptive resolution keeps the frame rate smooth, shaders are pre-compiled behind a loading screen.
- New main menu with logo, settings screen, pause menu with match stats, keyboard diagram in the controls help, key badges on HUD buttons and an on-screen key cheat sheet (H).

**Graphics**
- Bloom + colour grade post-processing (high quality), environment reflections on metal and glass.
- New sky with sun disk, sea with ripples, ship foam/wakes, shallow water and surf around islands.
- Puffy lit clouds, noisy terrain islands with beaches and trees.
- Detailed jets: canopy frame and pilot, radome, team roundels and fin stripes, nav lights and strobe, landing gear, layered afterburner with nozzle glow.
- Carriers with deck lights, parked aircraft, rotating radar, beacons; ships bob on the waves.
- Explosion flashes and lights, sparks, muzzle flashes, wing-tip vortices under G, contrails at altitude, camera shake.
