# 《我带着AI穿越大宋》: Song-dynasty city kit, v2 polish pass (low-poly, Civ VI-style)

Every model is original and procedural: bpy/bmesh code only, no external assets, no image textures.

## Conventions
- **Scale:** 1 unit = 1 m. Houses are built and then scaled ×0.88 (tavern ×0.9, gate ×0.82, palace ×0.78, pagoda ×0.85, people ×0.85). The scale is baked into the meshes, so the sizes below are the final sizes.
- **Hex tile:** pointy-top, circumradius 10 m (20 m corner to corner).
- **Origin:** bottom centre; the lowest vertex sits at height 0.
- **Facing:** fronts face Blender −Y, which is **glTF/Godot +Z** (south toward the camera).
- **Axes:** glTF Y-up.
- **Shading:** flat shading. Materials are Principled base colour only and map 1:1 to StandardMaterial3D in the Compatibility renderer.

### Baked vertex-colour shading (new)
- Every mesh has a baked `COLOR_0` vertex colour (glTF attribute; the Blender attribute is `Col`) that is **multiplied with the material base colour**.
- The colour holds ray-traced fake AO (24 hemisphere rays, 1.1 m), plus:
  - darker eave undersides/soffits
  - darker wall bases (a gradient toward the ground)
  - lighter roofs toward the ridge
- The material's baseColorFactor carries the palette colour.
- **Godot:** the importer normally enables `vertex_color_use_as_albedo` when COLOR_0 exists. If the shading looks flat in-engine, turn it on in the material (or with an import script). Final albedo = base colour × vertex colour.

### Single-sided-safe geometry (new)
- All materials use backface culling, so the GLBs carry no `doubleSided` flag.
- Every mesh is a closed shell (0 open edges on every model):
  - roofs are top surface + fascia + soffit
  - 悬山 roofs are watertight solids with gable boards
- These were checked by re-importing the GLBs.

## Buildings (`buildings/`), LOD0
| file | description | tris | size X×Y×H m |
|---|---|---|---|
| house_small_a | 民居 A, white walls, 悬山 roof | 486 | 3.05×2.59×2.99 |
| house_small_b | 民居 B, ochre walls, 歇山 roof | 570 | 3.88×3.24×3.26 |
| house_large_c | 民居 C, L-plan, dark main roof + brown-roof wing | 1168 | 5.26×4.15×3.48 |
| house_twostory | two-storey house, jettied upper floor, balcony, jade roof | 866 | 3.93×3.52×4.22 |
| house_courtyard | 四合院: walled compound with coping, SE gate, main hall, 2 side wings, tree, jar | 2044 | 5.05×5.27×3.14 |
| house_thatched | thatched farmhouse with haystack | 402 | 3.95×2.46×2.74 |
| shop_tavern | 酒楼, two storeys, waist eave, wine banner, lanterns | 1798 | 5.41×3.86×4.86 |
| pagoda | 7-tier octagonal pagoda | 2652 | 3.29×3.29×9.86 |
| city_gate | 城门楼 gate tower | 2402 | 4.82×2.54×5.6 |
| palace_hall | 宫殿, double-eave 庑殿 golden roof on marble platform | 2742 | 7.02×5.56×5.5 |
| wall_straight | 5.0 m wall segment, outer side −Y | 412 | 5.0×1.67×2.3 |
| wall_moat | wall + moat/river-edge water channel on the outer (−Y) side; tiles with wall_straight | 480 | 5.0×3.65×2.3 |
| wall_corner | hex corner tower, small pavilion | 510 | 2.14×2.44×3.95 |
| wall_corner_jiaolou | 角楼 corner tower with cross-ridge 歇山 pavilion | 1088 | 2.14×2.44×4.2 |

## Props
| file | tris | file | tris |
|---|---|---|---|
| tree_pine | 64 | tree_willow (dome crown + 2 rings of fronds) | 312 |
| bush | 60 | rock | 20 |
| field_patch / field_wheat | 276 each | well (open, windlass, no roof) | 224 |
| market_stall | 296 | cart | 296 |
| jars | 252 | fence (2 m) | 60 |
| lantern_post | 108 | banner_pole | 112 |
| person_farmer | 120 | person_merchant | 108 |
| person_soldier | 140 | | |

## LOD1 (`buildings/lod1/<name>_lod1.glb`)
LOD1 is built from the same recipes with:
- no bevels
- no tile corrugation
- fewer eave ring points
- 4-sided pillars
- detail parts dropped

| model | LOD0 | LOD1 |
|---|---|---|
| house_large_c | 1168 | 680 |
| house_twostory | 866 | 438 |
| house_courtyard | 2044 | 1428 |
| shop_tavern | 1798 | 798 |
| pagoda | 2652 | 1484 |
| city_gate | 2402 | 1062 |
| palace_hall | 2742 | 850 |
| wall_corner_jiaolou | 1088 | 704 |

## Clusters (`clusters/`)
- Each cluster has one node per building/prop plus a `hex_ground_*` node.
- The ground node's top surface is at height 0 and it is 0.6 m thick, so a cluster's zmin is −0.6.
- Ground detail is all vertex colour and geometry:
  - noisy grass/earth with a noisy falloff from the district into grass
  - dirt paths
  - contact shadows under buildings
  - darkened rim
  - grass tufts and small rocks
  - in the capital, paved stone roads (slabs on a grout bed, with curbs)
- Hide the ground node if the game's terrain hex provides its own.

| file | content | tris | nodes |
|---|---|---|---|
| cluster_town | open crossroads town: tavern, two-storey, small_a, small_b, thatched, well, stall, fields, people | 11344 | 30 |
| cluster_walled | walled town: **all 6 house variants**, plus well plaza, soldiers, banner, cart | 21112 | 41 |
| cluster_capital | capital: palace on axis, pagoda, 角楼 corners, paved roads, banners, lanterns, guards | 24642 | 43 |

The moat wall is not used in the clusters because its water would fall outside the 20 m tile. Use it on hex edges that border rivers or water.

## Previews (`previews/`, 1280×720, Cycles 64 spp, 50° camera)
- `cluster_town.png`, `cluster_walled.png`, `cluster_capital.png`: game camera
- `lineup_buildings.png`: all buildings + wall pieces
- `props_lineup.png`: trees, fields, well, stall, cart, jars, fence, lantern, banner, people
- `far_zoom.png`: 7-hex map at roughly Civ default zoom (readability check)
- `before_after_capital.png`: v1 capital vs v2 capital

## Source / rebuild
- `song_city.blend` contains these collections:
  - `Buildings` lineup (y=−60)
  - `Props` (y=−100)
  - `LOD1` (y=−140)
  - `Cluster_*` (30 m apart on X)
  - `FarZoom` (x=300)
- `src/songlib.py` holds the palette (`PAL`), materials, primitives, roof/fascia generators, the vertex-colour AO bake and the `LOD` flag.
- `src/models.py` holds all recipes, `CATALOG` and `LOD1_SET`.
- `src/scene.py` holds the ground tile, lighting and camera.
- `src/build.py` exports the GLBs, clusters and far map, and writes `stats.json`.
- `src/render.py` renders the previews. Optional args: town walled capital lineup props far. Env vars: `SONG_SPP`, `SONG_ENGINE`.
- Rebuild: `cd src && blender -b --python build.py && blender -b ../song_city.blend --python render.py` (build ~10 s, renders ~2 min on CPU).
- `src/_before_capital.png` is the v1 capital render, kept as the source for the before/after image.
