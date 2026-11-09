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

## Levels (Ruins, Factory, Harbor, Fortress)
| Script | Output | Goes to |
|---|---|---|
| `tiles2.py OUT` | `<theme>.png` (8x2 atlas), `<theme>_water.png`, `<theme>_path.png` (dual-grid edges) | `Misc/Builder/Tiles/` |
| `props.py OUT` | trees, pillars, tanks, containers, junk piles... per theme | `Misc/Builder/Props/<theme>/` |
| `gen_maps2.py OUT` | `Ruins.txt`, `Factory.txt`, `Harbor.txt`, `Fortress.txt` (seeded, same result every run) | `Levels/<Name>_level/map.txt` |
| `preview_map.py MAP THEME OUT.png [x y w h]` | picture of a map as the game draws it (needs `tiles2/` and `props/` next to the script) | level-select previews in `Resources/Levels/` |

The map characters are documented at the top of `Misc/Builder/built_level.gd`.
The prop names per theme are listed in `PROPS` in the same file. If you add a
prop, add it there too.

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
