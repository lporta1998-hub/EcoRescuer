# EcoRescuer art generators

Python scripts that drew the original pixel art for the new content. They need
Python 3 and Pillow (`pip install pillow`). The `Tools/.gdignore` file keeps
Godot from importing this folder.

The generated images are already in the project; run these only to tweak or
regenerate them. Most scripts take an output folder as their first argument.
Write to a temporary folder first, check the result, then copy the files into
the game.

## Shared renderers
| Script | What it is |
|---|---|
| `vol.py` | Volume-shaded pixel renderer (ellipsoids, capsules, rounded boxes, lighting, outline). Used by heads, props, boss, portrait. |
| `pixelkit.py` | Smaller pixel-art helpers used by the collectibles and the trash bag. |

## Levels (every campaign level)
All levels are `BuiltLevel`s (`Misc/Builder/built_level.gd`): a text map drawn
with the tilesets and props below. Themes: `ruins`, `factory`, `harbor`,
`fortress`, and `forest`, `snow`, `city`, `lake`, `datacenter` for Forest,
Snow Path, City, Polluted Lake and AI DataCenter.

| Script | Output | Goes to |
|---|---|---|
| `tiles2.py OUT` | `<theme>.png` (8x2 atlas), `<theme>_water.png`, `<theme>_path.png` (dual-grid edges), `city_grass.png` (the park lawn), `passage.png` (marks the teleports between the areas of a map) | `Misc/Builder/Tiles/` |
| `props.py OUT` | trees, pines, crystals, lamps, cars, palms, junk heaps, server racks... per theme, plus `turret_side/up/down.png` | `Misc/Builder/Props/<theme>/`, the turrets to `Levels/Ai DataCenter_level/Assets/Turrets/` |
| `gen_maps2.py OUT [Name ...]` | `Ruins.txt`, `Factory.txt`, `Harbor.txt`, `Fortress.txt`, `City.txt`, `SnowPath.txt`, `Lake.txt`, `DataCenter.txt` (seeded, same result every run; give names to make only those) | `Levels/<Name>_level/map.txt` (`SnowPath` → `SnowPathLevel/`, `Lake` → `BeachLevel/`, `DataCenter` → `Ai DataCenter_level/`) |
| `preview_map.py MAP THEME OUT.png [x y w h]` | picture of a map as the game draws it (needs `tiles2/` and `props/` next to the script) | level-select previews in `Resources/Levels/`, menu backgrounds in `Menu/Background/` |

The map characters are documented at the top of `Misc/Builder/built_level.gd`.
The prop names per theme are listed in `PROPS` in the same file (and in `CAT`
in `preview_map.py`). If you add a prop, add it there too.

City, Snow Path, Polluted Lake and AI DataCenter are designed in
`gen_maps2.py` (one function each, the layout is described at the top of it):
the City's blocks of buildings round the park in the middle, the Snow Path
trail from the valley to the summit with its two caves, the lake with a use
for every shore, the data center's halls and corridors (and its wall turrets,
in the extras after `---`). Their secret rooms are carved by `secret_room()`,
which checks that the portal can only be reached by breaking the crates.
Ruins, Factory, Harbor and Fortress got their secret rooms afterwards from
`Tools/dev/carve_secret_rooms.py`, so regenerate only the maps you change.

The Forest keeps the layout of its old hand-made scene (which used
third-party tilesets, now removed): `Tools/dev/scene_to_map.py` read which
cells were walkable, water or walls, and where the start, enemies, items and
teleports were. It was converted once and can be edited by hand.

## Boss and story
| Script | Output | Goes to |
|---|---|---|
| `boss3.py OUT.png` | the armored suit sheet (6 rows x 4 frames of 128 px; rows listed in the script) | `Boss/mecca_rifiuti.png` |
| `baron_portrait.py OUT.png` | Baron bust portrait | used by `panels.py` |
| `panels.py` | `04_baron_new.png`, `07_fall_new.png` (run in a folder holding `boss3_sheet.png`, `baron_portrait.png` and `pv_arena.png`, an arena render made with `preview_map.py`) | `Misc/Story/Art/04_baron.png`, `07_fall.png` |

## Enemies
| Script | Output | Goes to |
|---|---|---|
| `enemies.py OUT` | `sprayer.png`, `bomber.png` (40 px frames), `brute.png` (56 px), `drone.png` (32 px); rows down / up / side / death, columns idle x2, walk x4, windup, attack | `Enemies/<Type>/sheet.png` |

## Effects
| Script | Output | Goes to |
|---|---|---|
| `effects.py OUT` | `hit`, `hurt`, `purify`, `sparkle`, `heal`, `blast`, `splash`, `dust`, `stars` (one horizontal strip each), `leaf_bolt.png` (magic-bow shot, 2 rows), `plasma.png` (AI DataCenter turret bullets) | `Misc/FX/` |

`Misc/FX/fx.gd` (class `FX`) plays them: `FX.spawn("hit", parent, where)` or
`FX.at_node("purify", enemy, offset)`. Frame sizes and speeds are in `FX.SHEETS`.

## Sound effects
`../audio/sfx.py OUT` synthesizes the gameplay sounds from scratch (pure
Python, no packages): `hit`, `hurt`, `purify`, `pickup`, `heal`, `blast`,
`splash`, `lob`, `fuse`, `charge`, `stun`, `stomp`, `laser`, `alert`, plus the
menu set (`ui_confirm`, `ui_back`, `ui_tab`, `ui_denied`, `ui_buy`, `ui_on`,
`ui_off`, `ui_pause`, `ui_unpause`, `ui_page`) and `teleport`, `shield`,
`deflect`. They go to `Audio/SFX/Eco/`.

## Music
`../audio/music.py OUT [track ...]` composes and synthesizes the soundtrack
(melodies and chords are written in the script): `menu`, one track per map
(`forest`, `snow`, `city`, `lake`, `ruins`, `factory`, `harbor`, `datacenter`,
`fortress`) and `boss` (looping WAVs with the loop point inside the file) and the
`victory` / `gameover` jingles. They go to `Audio/Music_Levels/Eco/`. Which
level plays which track is the `"music"` entry of each chapter in
`Misc/Story/story.gd`; `Audio/Music_Levels/MusicManager.gd` plays them.

## Heroes and collectibles
| Script | What it does |
|---|---|
| `derive.py` | Color-role recolor of the original hero sheets in `orig/` (Luca's drawings, copied from git history). |
| `heads.py`, `redesign.py` | New heads and outfits for Mira, Silvano, ECO-9 composited onto every frame of the original animations. |
| `restyle.py` | Restyle pass for the existing heroes' frames. |
| `collectibles.py`, `bag2.py` | Coin, heart, feather, barrel, eco chest, battery, trash bag. |
| `preview_chars.py` | Preview sheet of the characters. |

Careful: `derive.py`, `redesign.py` and `restyle.py` read from and can write
straight into the game folders (`GAME_ROOT` is the EcoRescuer project). Commit
or back up first.
