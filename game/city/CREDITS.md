# Credits for third-party assets in Pink City

## Buildings

**Apartment blocks** — `tex/facade1.jpg`, `tex/facade2.jpg`, `tex/roof.jpg`

"residential_complex_modern_apartment_building" by ap-school (https://sketchfab.com/ap-school)
is licensed under CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/).
Source: https://sketchfab.com/3d-models/residential-complex-modern-apartment-building-bb94414a94cb40cbb5eb17691c1e6c68.
Distributed by AiZity (https://aizity.com), who cleaned it up (centred, grounded, renamed) and converted it.
Changes made here: the model's two long facades and its roof were rendered straight-on into images, and those
images are mapped onto simple box buildings, cropped to each building's size and tinted.

**Towers** — `models/tower.txt` (a binary glTF model stored as base64 text)

"Residential building (Moscow)" by Aleksandr Shevchenko (https://sketchfab.com/furious93rus)
is licensed under CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/).
Source: https://sketchfab.com/3d-models/residential-building-moscow-5653cbfa4c324667ba595d847e456b8d.
Distributed by AiZity (https://aizity.com), who cleaned it up (centred, grounded, renamed) and converted it.
Changes made here: converted to binary glTF, colour texture resized to 1024 px, normal and roughness maps
dropped, scaled per building.

## Streets

**Asphalt, paving and kerb textures** — `tex/asphalt.jpg`, `tex/paving.jpg`, `tex/curb.jpg`

Taken from the "Road segment" model at https://grab3d.com/models/city/road-segment/, supplied by the
repository owner. The colour textures were extracted, cropped square and resized to 512 px.
The licence of this model has not been confirmed; check the source page before reusing these files.

## Cars and street lanterns

**Car and lantern** — `models/car.txt`, `models/lamp.txt` (binary glTF models stored as base64 text)

"Car Scene" by toivo (https://sketchfab.com/toivo) is licensed under CC BY 4.0
(http://creativecommons.org/licenses/by/4.0/).
Source: https://sketchfab.com/3d-models/car-scene-b7b32eaca80d460c9338197e2c9d1408.
Changes made here: the car and the lantern were split into two files; the car's interior, chrome trim,
wipers, badge and ground shadow were removed; both were reduced in triangle count; only colour textures
were kept and resized; the car's body texture was converted to neutral grey so the game can repaint it.

## Nightclub interior

**Club** — `models/club.txt` (a binary glTF model stored as base64 text)

"Nightclub1" model supplied by the repository owner as `nightclub.zip`. The file carries no author or
licence information, so its licence has not been confirmed; check the page it was downloaded from before
reusing it. Changes made here: only the colour and emissive textures were kept and resized to 1024 px.

## People

See `models/LICENSE.txt` (Microsoft Rocketbox Avatar Library, MIT).

## More cars (`models/cars/*.txt`, binary glTF stored as base64 text)

All from Sketchfab under **CC Attribution 4.0** (https://creativecommons.org/licenses/by/4.0/).
Changes made here for every model: split into one file per vehicle, turned to face along one axis and
set on the ground, wheels grouped so they can turn, normal/roughness textures removed, colour textures
resized to 512 px (256 px for the packs), and the two sports cars reduced in triangle count.

- **V12 Goblin** (`goblin`) — "Fictional supercar - V12 Goblin" by ollitei — https://sketchfab.com/3d-models/fictional-supercar-v12-goblin-0a20e49ad5774d778567cb5c3f345786
- **Lamborghini Revuelto** (`revuelto`) — "Free Lamborghini Revuelto" by ALIEEEN — https://sketchfab.com/3d-models/free-lamborghini-revuelto-cf52245eb68f48daa909c7ad2a8deaa3
- **McLaren 720S** (`mclaren`) — "2017 Mclaren 720s" by s0h1o9b — https://sketchfab.com/3d-models/2017-mclaren-720s-f7bece69400f4640a4a3be746b44998b
- **Mercedes G-class** (`gclass`) — "Mercedes Benz G-class W263" by Lexyc16 — https://sketchfab.com/3d-models/mercedes-benz-g-class-w263-1a2a52b16cad4e618af347461817895c
- **Police SUV** (`policesuv`) — "Lowpoly Generic SUV Police" by mk2design — https://sketchfab.com/3d-models/lowpoly-generic-suv-police-259fc16c23d548ba8d5802c563d8ebdc
- **Police sedan, taxi** (`police_sedan`, `taxi`) — from "Generic civil service vehicles pack" by comrade1280 — https://sketchfab.com/3d-models/generic-civil-service-vehicles-pack-8ff2a13f30914932a70c7950cfa58465
- **Traffic cars** (`traffic_*`: compact, coupe, hatchback, minivan, offroad, pickup, sedan, sport, SUV, wagon) — from "Generic passenger car pack" by comrade1280 — https://sketchfab.com/3d-models/generic-passenger-car-pack-20f9af9b8a404d5cb022ac6fe87f21f5

Brand names belong to their owners; the models are fan-made and not endorsed by the car makers.
