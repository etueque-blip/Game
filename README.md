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
