# Credits — Godot port

- **Car models** (`assets/cars/*.glb`): the same CC BY 4.0 models as the browser game; authors and links are in
  `../game/city/CREDITS.md` (section "More cars"). Prepared here the same way: one file per vehicle, re-oriented,
  wheels grouped, textures resized.
- **Street and facade textures** (`assets/tex/*.jpg`): copied from the browser game; see `../game/city/CREDITS.md`.
- **People** (`assets/people/*.glb`): Microsoft Rocketbox Avatar Library, MIT licence (`assets/people/LICENSE.txt`).
- **Font**: Noto Sans Armenian, © The Noto Project Authors, SIL Open Font License 1.1 (`fonts/OFL.txt`).
- **Engine**: Godot Engine 4.3 (MIT), https://godotengine.org
- **Ground and wall materials** (`assets/tex/ph/`): Poly Haven (https://polyhaven.com), CC0 — asphalt_02,
  hexagonal_concrete_paving, pavement_02, sandstone_blocks_05. Re-saved as JPEG at quality 86.
- **Second wall stone**: Poly Haven rough_block_wall, CC0.
- **Facade parts** (`assets/facade/*.glb`): made for this game in Blender by `tools/blender/facade_parts.py`.
- **Trees** (`assets/tree/`): grown in Blender with the Sapling add-on by `tools/blender/trees.py`; bark from Poly Haven
  (bark_platanus, CC0); the leaf card is made from ambientCG LeafSet010 (CC0).
- **Skies** (`assets/sky/`): Poly Haven, the Qwantani pure-sky series (CC0), tonemapped and resized to 4096 x 2048.
- **Motion capture** (`assets/anim/*.json`): Microsoft Rocketbox animation library, MIT licence
  (https://github.com/microsoft/Microsoft-Rocketbox, `Assets/Animations`): walks, runs, idles, phone calls, talking,
  waiting, sitting, cheering, anger, dancing. Turned into small per-bone clips by `tools/blender/rocketbox_anims.py`
  and retargeted onto the avatars in `scripts/people.gd`.
- **Street furniture** (`assets/street/`): Poly Haven models, CC0 — painted_wooden_bench, metal_trash_can,
  fire_hydrant, street_lamp_01, planter_box_01 (trimmed and lightened by `tools/blender/street_kit.py`). The bus stop,
  newspaper kiosk and traffic light are made in Blender by the same script.
- **Parks** (`assets/plants/`): Poly Haven plants, CC0 — celandine_01, flower_gazania, periwinkle_plant, shrub_02;
  lawn texture leafy_grass (CC0). Grass blades are made in code (`city.gd`, `_grass_patch`).
- **Arches** (`assets/facade/arch.glb`): made in Blender by `tools/blender/arch.py`.
- **Sounds**: all made in code at start (`scripts/sound.gd`, `interior.gd`) — no sound files.
