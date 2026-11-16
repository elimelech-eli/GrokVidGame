# Starwake

Phase 1 of a PC sci-fi action RPG: a third-person surveyor on the rust flats of **Vesper-9**, beside their landed skiff, with a hostile outpost in the valley. The pitch for the full game is "Skyrim in space" — Starfield's range with Mass Effect's squad and conversation. This build is the feel of moving, aiming, and shooting in one handsome outdoor zone.

Godot **4.7.2** (stable) and GDScript. Later phases plug into the autoloads and groups instead of rewriting the player.

## Run

1. Install [Godot 4.7.2 or any later 4.7/4.8 stable](https://godotengine.org/download/archive/4.7.2-stable/). The project uses Forward+.
2. Open `project.godot`, or from a terminal:

```bash
godot --path .
```

3. Press F5. The main menu looks out over the valley. **Launch expedition** drops you next to the ship.
4. A headless boot check (no window, quits after a few frames):

```bash
godot --headless --path . --quit-after 60
```

The first launch imports glTF, textures, and audio. That takes longer than later launches.

## Controls

The input map is built at boot by `scripts/autoload/input_bindings.gd` (keyboard plus a standard Xbox-style pad).

| Action | Keyboard | Gamepad |
| --- | --- | --- |
| Move | W A S D | Left stick |
| Look | Mouse | Right stick |
| Jump | Space | A |
| Sprint | Shift | LB or left stick click |
| Dodge roll | Ctrl or Q | B or RB |
| Fire | Left mouse | RT |
| Aim | Right mouse | LT |
| Reload | R | X |
| Melee | F or V | Y |
| Interact | E | D-pad up |
| Pause | Esc | Start |

Aiming tightens the spring-arm camera and the crosshair. Shields absorb hits and recharge after a delay. The rifle has a magazine; reload or dry-fire when it is empty. Dodge rolls are briefly invulnerable.

Standing at the skiff and pressing interact shows a sealed-hatch line. Boarding is a later phase. The ship is already in the `ship_hub` group, with a `ShipHubSocket` marker for that work.

## Settings

Esc, or Settings on the main menu. Mouse and gamepad sensitivity, invert Y, volumes, fullscreen, and screen shake are saved to `user://settings.cfg`.

**Mature content (18+)** is stored and does nothing else. Later phases will hide adult scenes behind it. This build has no mature content.

## Windows build

`export_presets.cfg` contains a Windows Desktop preset that writes `build/windows/Starwake.exe` plus `Starwake.pck`.

One-time template install for Godot 4.7.2:

```bash
mkdir -p ~/.local/share/godot/export_templates/4.7.2.stable
# Download Godot_v4.7.2-stable_export_templates.tpz from the 4.7.2 release.
unzip Godot_v4.7.2-stable_export_templates.tpz -d /tmp/godot-templates
cp -a /tmp/godot-templates/templates/. ~/.local/share/godot/export_templates/4.7.2.stable/
```

Export:

```bash
godot --headless --path . --export-release "Windows Desktop" build/windows/Starwake.exe
```

In the editor: Project, Export, Windows Desktop, Export Project. `build/` is gitignored.

A packaged Windows build produced in this environment is attached to the pull request when the export succeeds. Copy `Starwake.exe` and `Starwake.pck` into the same folder and run the exe.

## Layout

```
scenes/     main, player, enemies
scripts/    autoload, player, combat, enemies, world, ui, vfx
assets/     models, audio, fonts
shaders/    terrain, stars, damage wash, menu
ui/         (theme is built in scripts/ui)
```

Autoloads:

| Singleton | Role |
| --- | --- |
| `EventBus` | Signals for damage, pause, prompts, settings. Later dialogue and quests subscribe here. |
| `GameState` | Phase, vitals, ammo, zone id. Empty slots for progression, inventory, quests, ship modules, and followers. |
| `Settings` | User config, including the mature-content flag. |
| `InputBindings` | Keyboard and gamepad map. |
| `AudioDirector` | Keyed sound effects and looping ambience. |

`HealthComponent` is the shield-first vitality model ships can reuse. Projectiles and the animator do not care whether the body is a person or a drone.

## Six phases

1. **Core feel (this build).** Third-person move, aim, gun, melee, a few enemies, HUD, menus, one outdoor zone, day and night.
2. **RPG layer.** Attributes, skills, inventory, loot, experience, and a quest log on `GameState.progression`, `inventory`, and `quests`.
3. **Ship hub and upgrades.** Walk into the skiff through `ship_hub` / `ShipHubSocket`. Module sockets edit `GameState.ship`.
4. **Ship combat.** A separate scene that reuses health, shields, and the weapon interface for craft-versus-craft.
5. **Dialogue and followers.** Conversation drives `EventBus`. Companions reuse the enemy locomotion stack and live in `GameState.followers`.
6. **Multi-zone open world.** More biomes and a system map. `GameState.zone_id` is already `vesper_9_aether_reach` so travel can swap it.

## Assets

Every pack, license, and URL is in [ASSETS_CREDITS.md](ASSETS_CREDITS.md). Models are Quaternius CC0. Sounds and the secondary miner are Kenney CC0. The UI face is Orbitron (OFL).

## Known limits

- One valley. No save games, inventory, or conversation.
- Enemy sensing is distance, a view cone, and a ray. They do not use a navigation mesh and can stall on tight props.
- The mature-content toggle does not change any scene.
- SDFGI, SSAO, and volumetric fog turn off when Godot reports a software renderer (lavapipe / llvmpipe), so a VM screenshot is flatter than a desktop GPU. On a normal GPU those features stay on: ACES tonemap, glow, color grading, and the day/night cycle (about four minutes) still run everywhere.
- The valley is dressed procedurally from the CC0 kits at startup, so prop placement has a fixed seed rather than a hand-authored level file.
- Ambience is ship and wind-like engine loops. There is no music score in the CC0 packs used here.
