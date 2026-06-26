@tool
extends Node3D
## ============================================================
## CRIMSON CITY — AAA Procedural World Generator
## Generates a 5000x5000 open world at runtime.
## Architecture mirrors GTA5 / RDR2 / Cyberpunk streaming.
## ============================================================

# ─── WORLD CONSTANTS ───────────────────────────────────────
const WORLD_SIZE       := 5000.0
const CHUNK_SIZE       := 250.0          # Streaming cell size
const CHUNKS_PER_AXIS  := int(WORLD_SIZE / CHUNK_SIZE)  # 20x20 = 400 chunks
const CULL_DISTANCE    := 600.0
const LOD_HIGH_DIST    := 150.0
const LOD_MED_DIST     := 350.0
const LOD_LOW_DIST     := 600.0

# ─── DISTRICT DEFINITIONS ──────────────────────────────────
enum District {
	DOWNTOWN_CORE,       # Skyscrapers, glass, finance
	MIDTOWN,             # Mixed-use, dense mid-rises
	CHINATOWN,           # Dense low-rise, signage, markets
	INDUSTRIAL_NORTH,    # Factories, warehouses, smokestacks
	INDUSTRIAL_SOUTH,    # Refineries, pipelines, tanks
	DOCKLANDS,           # Cranes, containers, waterfront
	HARBOR,              # Water, jetties, fishing
	SLUMS_EAST,          # Favela, corrugated metal, dense
	SLUMS_WEST,          # Abandoned, decay, graffiti
	SUBURBS_NORTH,       # Houses, gardens, quiet streets
	SUBURBS_SOUTH,       # Richer, bigger houses
	AIRPORT,             # Runways, terminals, control tower
	MILITARY_BASE,       # Fences, bunkers, watchtowers
	UNDERGROUND,         # Metro tunnels, sewers, caves
	FREEWAY_RING,        # Elevated highway loop
	COUNTRYSIDE_NW,      # Hills, forests, rivers
	COUNTRYSIDE_NE,      # Open fields, farms
	COUNTRYSIDE_SW,      # Rocky cliffs, coast
	COUNTRYSIDE_SE,      # Desert scrub, quarry
	OCEAN,               # Deep water, islands
}

# District rectangles [x_min, z_min, x_max, z_max] in world space
const DISTRICT_BOUNDS := {
	District.DOWNTOWN_CORE:    [-400, -400,  400,  400],
	District.MIDTOWN:          [-800, -800,  800,  800],
	District.CHINATOWN:        [-600, -200, -400,  200],
	District.INDUSTRIAL_NORTH: [-1800, -600, -800,  400],
	District.INDUSTRIAL_SOUTH: [-1800,  400, -800, 1200],
	District.DOCKLANDS:        [ 800, -200, 1800,  800],
	District.HARBOR:           [ 800,  800, 2200, 2200],
	District.SLUMS_EAST:       [ 400, -800, 1200, -200],
	District.SLUMS_WEST:       [-1200, -800, -600, -200],
	District.SUBURBS_NORTH:    [-800, -1800,  800, -800],
	District.SUBURBS_SOUTH:    [-800,  800,  800, 1800],
	District.AIRPORT:          [-1200, -2500,  400, -1800],
	District.MILITARY_BASE:    [ 1200, -2500, 2500, -1000],
	District.COUNTRYSIDE_NW:   [-2500, -2500, -1200, -800],
	District.COUNTRYSIDE_NE:   [ 1200, -2500, 2500, -800],
	District.COUNTRYSIDE_SW:   [-2500,  800, -1200, 2500],
	District.COUNTRYSIDE_SE:   [ 1200,  800, 2500, 2500],
	District.OCEAN:            [ 2000, -2500, 2500, 2500],
}

# Building height ranges per district [min, max] in meters
const BUILDING_HEIGHTS := {
	District.DOWNTOWN_CORE:    [80,  320],
	District.MIDTOWN:          [25,  85],
	District.CHINATOWN:        [8,   30],
	District.INDUSTRIAL_NORTH: [12,  45],
	District.INDUSTRIAL_SOUTH: [10,  35],
	District.DOCKLANDS:        [6,   22],
	District.SLUMS_EAST:       [5,   18],
	District.SLUMS_WEST:       [4,   14],
	District.SUBURBS_NORTH:    [5,   12],
	District.SUBURBS_SOUTH:    [6,   16],
	District.AIRPORT:          [8,   65],
	District.MILITARY_BASE:    [4,   20],
}

# Building density (buildings per 100x100m cell)
const BUILDING_DENSITY := {
	District.DOWNTOWN_CORE:    0.85,
	District.MIDTOWN:          0.75,
	District.CHINATOWN:        0.92,
	District.INDUSTRIAL_NORTH: 0.55,
	District.INDUSTRIAL_SOUTH: 0.48,
	District.DOCKLANDS:        0.35,
	District.SLUMS_EAST:       0.88,
	District.SLUMS_WEST:       0.72,
	District.SUBURBS_NORTH:    0.30,
	District.SUBURBS_SOUTH:    0.25,
	District.AIRPORT:          0.20,
	District.MILITARY_BASE:    0.40,
}

# ─── MATERIAL CATALOG ──────────────────────────────────────
# All materials reference external .tres files (in res://materials/)
# These match what the WorldRenderer will import from disk.
const MAT_PATHS := {
	"glass_curtain_wall":   "res://materials/building/glass_curtain_wall.tres",
	"glass_dark":           "res://materials/building/glass_dark.tres",
	"concrete_modern":      "res://materials/building/concrete_modern.tres",
	"concrete_brutalist":   "res://materials/building/concrete_brutalist.tres",
	"concrete_stained":     "res://materials/building/concrete_stained.tres",
	"concrete_worn":        "res://materials/building/concrete_worn.tres",
	"brick_red":            "res://materials/building/brick_red.tres",
	"brick_dark":           "res://materials/building/brick_dark.tres",
	"metal_corrugated":     "res://materials/building/metal_corrugated.tres",
	"metal_panel":          "res://materials/building/metal_panel.tres",
	"metal_rusty":          "res://materials/building/metal_rusty.tres",
	"metal_clean":          "res://materials/building/metal_clean.tres",
	"wood_plank":           "res://materials/building/wood_plank.tres",
	"asphalt_road":         "res://materials/terrain/asphalt_road.tres",
	"asphalt_worn":         "res://materials/terrain/asphalt_worn.tres",
	"concrete_sidewalk":    "res://materials/terrain/concrete_sidewalk.tres",
	"grass_urban":          "res://materials/terrain/grass_urban.tres",
	"grass_wild":           "res://materials/terrain/grass_wild.tres",
	"dirt_dry":             "res://materials/terrain/dirt_dry.tres",
	"gravel":               "res://materials/terrain/gravel.tres",
	"rock_cliff":           "res://materials/terrain/rock_cliff.tres",
	"sand_beach":           "res://materials/terrain/sand_beach.tres",
	"water_ocean":          "res://materials/terrain/water_ocean.tres",
	"water_river":          "res://materials/terrain/water_river.tres",
	"steel_beam":           "res://materials/industrial/steel_beam.tres",
	"oil_tank":             "res://materials/industrial/oil_tank.tres",
	"chimney":              "res://materials/industrial/chimney.tres",
	"container_red":        "res://materials/props/container_red.tres",
	"container_blue":       "res://materials/props/container_blue.tres",
	"container_green":      "res://materials/props/container_green.tres",
	"container_yellow":     "res://materials/props/container_yellow.tres",
	"neon_red":             "res://materials/neon/neon_red.tres",
	"neon_cyan":            "res://materials/neon/neon_cyan.tres",
	"neon_amber":           "res://materials/neon/neon_amber.tres",
	"neon_purple":          "res://materials/neon/neon_purple.tres",
	"neon_green":           "res://materials/neon/neon_green.tres",
	"neon_white":           "res://materials/neon/neon_white.tres",
}

# ─── MESH CATALOG ──────────────────────────────────────────
const MESH_PATHS := {
	# Buildings
	"skyscraper_glass_a":     "res://meshes/buildings/skyscraper_glass_a.glb",
	"skyscraper_glass_b":     "res://meshes/buildings/skyscraper_glass_b.glb",
	"skyscraper_concrete_a":  "res://meshes/buildings/skyscraper_concrete_a.glb",
	"tower_office_a":         "res://meshes/buildings/tower_office_a.glb",
	"tower_office_b":         "res://meshes/buildings/tower_office_b.glb",
	"midrise_a":              "res://meshes/buildings/midrise_a.glb",
	"midrise_b":              "res://meshes/buildings/midrise_b.glb",
	"midrise_c":              "res://meshes/buildings/midrise_c.glb",
	"apartment_block_a":      "res://meshes/buildings/apartment_block_a.glb",
	"apartment_block_b":      "res://meshes/buildings/apartment_block_b.glb",
	"house_a":                "res://meshes/buildings/house_a.glb",
	"house_b":                "res://meshes/buildings/house_b.glb",
	"house_c":                "res://meshes/buildings/house_c.glb",
	"warehouse_a":            "res://meshes/buildings/warehouse_a.glb",
	"warehouse_b":            "res://meshes/buildings/warehouse_b.glb",
	"factory_a":              "res://meshes/buildings/factory_a.glb",
	"factory_b":              "res://meshes/buildings/factory_b.glb",
	"hangar_a":               "res://meshes/buildings/hangar_a.glb",
	"shack_a":                "res://meshes/buildings/shack_a.glb",
	"shack_b":                "res://meshes/buildings/shack_b.glb",
	# Infrastructure
	"chimney_a":              "res://meshes/infra/chimney_a.glb",
	"chimney_b":              "res://meshes/infra/chimney_b.glb",
	"oil_tank_a":             "res://meshes/infra/oil_tank_a.glb",
	"oil_tank_b":             "res://meshes/infra/oil_tank_b.glb",
	"crane_a":                "res://meshes/infra/crane_a.glb",
	"crane_b":                "res://meshes/infra/crane_b.glb",
	"control_tower":          "res://meshes/infra/control_tower.glb",
	"water_tower":            "res://meshes/infra/water_tower.glb",
	"billboard_a":            "res://meshes/infra/billboard_a.glb",
	"lamppost_a":             "res://meshes/infra/lamppost_a.glb",
	"lamppost_b":             "res://meshes/infra/lamppost_b.glb",
	"traffic_light":          "res://meshes/infra/traffic_light.glb",
	"fire_hydrant":           "res://meshes/infra/fire_hydrant.glb",
	"dumpster":               "res://meshes/infra/dumpster.glb",
	"bench":                  "res://meshes/infra/bench.glb",
	"mailbox":                "res://meshes/infra/mailbox.glb",
	"ac_unit":                "res://meshes/infra/ac_unit.glb",
	# Containers
	"shipping_container":     "res://meshes/props/shipping_container.glb",
	# Vegetation
	"tree_oak_a":             "res://meshes/vegetation/tree_oak_a.glb",
	"tree_oak_b":             "res://meshes/vegetation/tree_oak_b.glb",
	"tree_pine_a":            "res://meshes/vegetation/tree_pine_a.glb",
	"tree_dead_a":            "res://meshes/vegetation/tree_dead_a.glb",
	"shrub_a":                "res://meshes/vegetation/shrub_a.glb",
	"grass_patch":            "res://meshes/vegetation/grass_patch.glb",
	# Vehicles (parked, static)
	"car_sedan_a":            "res://meshes/vehicles/car_sedan_a.glb",
	"car_sedan_b":            "res://meshes/vehicles/car_sedan_b.glb",
	"car_suv_a":              "res://meshes/vehicles/car_suv_a.glb",
	"truck_a":                "res://meshes/vehicles/truck_a.glb",
	"bus_a":                  "res://meshes/vehicles/bus_a.glb",
	# Terrain rocks / boulders
	"rock_a":                 "res://meshes/terrain/rock_a.glb",
	"rock_b":                 "res://meshes/terrain/rock_b.glb",
	"rock_cluster_a":         "res://meshes/terrain/rock_cluster_a.glb",
}

# ─── SCENE CATALOG (prebuilt sub-scenes) ───────────────────
const SCENE_PATHS := {
	"neon_sign_hotel":        "res://scenes/props/neon_sign_hotel.tscn",
	"neon_sign_bar":          "res://scenes/props/neon_sign_bar.tscn",
	"neon_sign_pharmacy":     "res://scenes/props/neon_sign_pharmacy.tscn",
	"neon_sign_casino":       "res://scenes/props/neon_sign_casino.tscn",
	"neon_sign_club":         "res://scenes/props/neon_sign_club.tscn",
	"neon_sign_chinese":      "res://scenes/props/neon_sign_chinese.tscn",
	"street_corner_downtown": "res://scenes/streets/corner_downtown.tscn",
	"street_corner_slums":    "res://scenes/streets/corner_slums.tscn",
	"alleyway_a":             "res://scenes/streets/alleyway_a.tscn",
	"fire_escape_a":          "res://scenes/props/fire_escape_a.tscn",
	"fire_escape_b":          "res://scenes/props/fire_escape_b.tscn",
	"rooftop_hvac":           "res://scenes/props/rooftop_hvac.tscn",
	"rooftop_garden":         "res://scenes/props/rooftop_garden.tscn",
	"plaza_fountain":         "res://scenes/props/plaza_fountain.tscn",
	"bus_stop_a":             "res://scenes/props/bus_stop_a.tscn",
	"phone_booth":            "res://scenes/props/phone_booth.tscn",
	"crime_scene_tape":       "res://scenes/props/crime_scene_tape.tscn",
	"graffiti_wall_a":        "res://scenes/props/graffiti_wall_a.tscn",
	"market_stall_a":         "res://scenes/props/market_stall_a.tscn",
	"market_stall_b":         "res://scenes/props/market_stall_b.tscn",
	"military_checkpoint":    "res://scenes/props/military_checkpoint.tscn",
	"dock_crane_rig":         "res://scenes/industrial/dock_crane_rig.tscn",
	"refinery_cluster":       "res://scenes/industrial/refinery_cluster.tscn",
	"metro_station":          "res://scenes/underground/metro_station.tscn",
	"metro_entrance":         "res://scenes/underground/metro_entrance.tscn",
	"tunnel_segment":         "res://scenes/underground/tunnel_segment.tscn",
}

# ─── ROAD NETWORK DATA ─────────────────────────────────────
# Arterials defined as [x1,z1, x2,z2, width, type]
# Types: "highway", "arterial", "collector", "local", "alley"
const ROAD_NETWORK := [
	# === FREEWAYS / ELEVATED HIGHWAYS ===
	[-2500, 0, 2500, 0,  28, "highway"],      # East-West Freeway (Route 1)
	[0, -2500, 0, 2500,  28, "highway"],      # North-South Freeway (Route 9)
	[-1800,-1800, 1800,-1800, 22, "highway"], # North Ring Road
	[-1800, 1800, 1800, 1800, 22, "highway"], # South Ring Road
	[-1800,-1800,-1800, 1800, 22, "highway"], # West Ring Road
	[ 1800,-1800, 1800, 1800, 22, "highway"], # East Ring Road
	[-800, -800,  800, -800, 20, "highway"],  # Inner North Bypass
	[-800,  800,  800,  800, 20, "highway"],  # Inner South Bypass
	# === MAIN ARTERIALS ===
	[-2500,-400, 2500,-400, 16, "arterial"],  # 1st Avenue
	[-2500, 400, 2500, 400, 16, "arterial"],  # 2nd Avenue
	[-400,-2500,-400, 2500, 16, "arterial"],  # 1st Street
	[ 400,-2500, 400, 2500, 16, "arterial"],  # 2nd Street
	[-1200,-2500,-1200,2500, 14, "arterial"], # West Boulevard
	[ 1200,-2500, 1200,2500, 14, "arterial"], # East Boulevard
	[-2500,-1200,2500,-1200, 14, "arterial"], # North Boulevard
	[-2500, 1200,2500, 1200, 14, "arterial"], # South Boulevard
	# === COLLECTORS (Downtown Grid) ===
	[-400, -800, 400, -800, 12, "collector"],
	[-400, -600, 400, -600, 12, "collector"],
	[-400, -200, 400, -200, 12, "collector"],
	[-400,  200, 400,  200, 12, "collector"],
	[-400,  600, 400,  600, 12, "collector"],
	[-800, -400,-400, -400, 12, "collector"],
	[-800,  400,-400,  400, 12, "collector"],
	[ 400, -400, 800, -400, 12, "collector"],
	[ 400,  400, 800,  400, 12, "collector"],
	[-200,-2500,-200,  400, 10, "collector"], # Mid-city grid
	[ 200,-2500, 200,  400, 10, "collector"],
	[-600,-2500,-600,  400, 10, "collector"],
	[ 600,-2500, 600,  400, 10, "collector"],
	# === LOCAL STREETS (Slums/Suburbs irregular) ===
	# Slums East organic grid (slight angle variations)
	[ 500,-700, 1100,-700, 8, "local"],
	[ 500,-600, 1000,-600, 8, "local"],
	[ 500,-450, 1100,-450, 8, "local"],
	[ 500,-300, 1000,-300, 8, "local"],
	[ 600,-750,  600,-250, 8, "local"],
	[ 750,-750,  750,-200, 8, "local"],
	[ 900,-720,  900,-200, 8, "local"],
	[1050,-720, 1050,-250, 8, "local"],
	# Suburbs
	[-700,-1700,-200,-1700, 8, "local"],
	[-700,-1500,-200,-1500, 8, "local"],
	[-700,-1300,-200,-1300, 8, "local"],
	[-700,-1200,-700,-900,  8, "local"],
	[-500,-1200,-500,-900,  8, "local"],
	[-300,-1200,-300,-900,  8, "local"],
	# Airport access
	[-1200,-2300, 400,-2300, 14, "arterial"],
	[-1200,-2100, 400,-2100, 14, "arterial"],
	# Dock access roads
	[ 800, -100, 1800,-100, 12, "collector"],
	[ 800,  300, 1800, 300, 12, "collector"],
	[ 800,  600, 1800, 600, 12, "collector"],
	[1600, -200,1600,  700, 12, "collector"],
	[1200, -200,1200,  700, 10, "local"],
	# === ALLEYS (Downtown) ===
	[-350,-350, 350,-350, 5, "alley"],
	[-350,-250, 350,-250, 5, "alley"],
	[-350,-150, 350,-150, 5, "alley"],
	[-350,  50, 350,  50, 5, "alley"],
	[-350, 150, 350, 150, 5, "alley"],
]

# ─── TERRAIN ZONES ─────────────────────────────────────────
# Each zone: [x, z, radius, type, height_scale, noise_freq]
const TERRAIN_ZONES := [
	# Downtown — flat, paved
	[0, 0, 850, "urban_flat", 0.5, 0.001],
	# River cutting through city
	[200, 0, 80, "river_bed", -2.0, 0.002],
	# Industrial — slightly elevated
	[-1300, 200, 600, "industrial_flat", 3.0, 0.003],
	# Airport — very flat, sealed
	[-400,-2200, 700, "airport_flat", 0.2, 0.0005],
	# Military base — flat
	[1800,-1800, 600, "military_flat", 1.0, 0.001],
	# NW Country — hills
	[-1800,-1800, 800, "rolling_hills", 45.0, 0.008],
	# NE Country — plains
	[ 1800,-1800, 700, "open_plain", 8.0, 0.004],
	# SW Country — rocky coast / cliffs
	[-1800, 1800, 800, "rocky_coast", 60.0, 0.012],
	# SE Country — desert / scrub
	[ 1800, 1800, 700, "desert_scrub", 18.0, 0.006],
	# Ocean
	[ 2300, 0, 500, "ocean_deep", -25.0, 0.002],
	# Harbor
	[ 1500, 1500, 400, "harbor_shallow", -4.0, 0.003],
]

# ─── WATER BODIES ──────────────────────────────────────────
const WATER_BODIES := [
	# [x, z, w, d, type, depth]
	[2200,    0, 1200, 5000, "ocean",   -30.0],
	[1500, 1500,  800,  800, "harbor",   -5.0],
	[200,     0,   35, 4000, "river",    -2.5],  # Main river
	[-600, 1200,  250,  600, "lake",     -3.0],
]

# ─── BRIDGE DEFINITIONS ────────────────────────────────────
const BRIDGES := [
	# [x, z, length, width, angle, type]
	[200, -600, 120, 20, 0.0, "suspension"],    # Main river bridge N
	[200,    0, 120, 20, 0.0, "arch"],           # Main river bridge C
	[200,  600, 120, 20, 0.0, "beam"],           # Main river bridge S
	[200, -1200, 100, 14, 0.0, "beam"],          # Uptown river crossing
	[1600, 800,  80, 18, 0.0, "arch"],           # Harbor bridge
	# Elevated freeway river crossing
	[200, 0, 160, 28, 0.0, "freeway_elevated"],
]

# ─── CHUNK STREAMING SYSTEM ────────────────────────────────
var _loaded_chunks: Dictionary = {}
var _chunk_data: Array[Dictionary] = []
var _player_ref: Node3D = null
var _last_player_chunk: Vector2i = Vector2i(-9999, -9999)
var _rng := RandomNumberGenerator.new()

# ─── INITIALIZATION ────────────────────────────────────────
func _ready() -> void:
	_rng.seed = 20240101
	_prebake_chunk_data()
	_find_player()
	print("[CityGenerator] World initialized. %d chunks prebaked." % _chunk_data.size())

func _find_player() -> void:
	_player_ref = get_tree().get_first_node_in_group("player")

func _process(_delta: float) -> void:
	if _player_ref == null:
		return
	var pc := _world_to_chunk(_player_ref.global_position)
	if pc != _last_player_chunk:
		_last_player_chunk = pc
		_stream_chunks(pc)

# ─── CHUNK DATA PREBAKE ────────────────────────────────────
func _prebake_chunk_data() -> void:
	_chunk_data.clear()
	for cx in CHUNKS_PER_AXIS:
		for cz in CHUNKS_PER_AXIS:
			var wx := (cx - CHUNKS_PER_AXIS / 2.0) * CHUNK_SIZE + CHUNK_SIZE * 0.5
			var wz := (cz - CHUNKS_PER_AXIS / 2.0) * CHUNK_SIZE + CHUNK_SIZE * 0.5
			var district := _get_district(wx, wz)
			_chunk_data.append({
				"cx": cx, "cz": cz,
				"wx": wx, "wz": wz,
				"district": district,
				"seed": cx * 1000 + cz,
				"loaded": false,
			})

# ─── STREAMING ─────────────────────────────────────────────
const STREAM_RADIUS_CHUNKS := 4  # Load 9x9 ring around player

func _stream_chunks(player_chunk: Vector2i) -> void:
	# Determine desired loaded set
	var desired := {}
	for dx in range(-STREAM_RADIUS_CHUNKS, STREAM_RADIUS_CHUNKS + 1):
		for dz in range(-STREAM_RADIUS_CHUNKS, STREAM_RADIUS_CHUNKS + 1):
			var key := Vector2i(player_chunk.x + dx, player_chunk.y + dz)
			if key.x >= 0 and key.x < CHUNKS_PER_AXIS and key.y >= 0 and key.y < CHUNKS_PER_AXIS:
				desired[key] = true

	# Unload far chunks
	for key in _loaded_chunks.keys():
		if not desired.has(key):
			_unload_chunk(key)

	# Load new chunks
	for key in desired.keys():
		if not _loaded_chunks.has(key):
			_load_chunk(key)

func _load_chunk(key: Vector2i) -> void:
	var idx := key.x * CHUNKS_PER_AXIS + key.y
	if idx < 0 or idx >= _chunk_data.size():
		return
	var data := _chunk_data[idx]
	var root := Node3D.new()
	root.name = "Chunk_%d_%d" % [key.x, key.y]
	add_child(root)
	_generate_chunk(root, data)
	_loaded_chunks[key] = root
	data["loaded"] = true

func _unload_chunk(key: Vector2i) -> void:
	if _loaded_chunks.has(key):
		_loaded_chunks[key].queue_free()
		_loaded_chunks.erase(key)

# ─── CHUNK GENERATION (DISTRICT-AWARE) ────────────────────
func _generate_chunk(root: Node3D, data: Dictionary) -> void:
	_rng.seed = data["seed"] * 7919 + 13337
	var district: District = data["district"]
	var cx: float = data["wx"]
	var cz: float = data["wz"]

	match district:
		District.DOWNTOWN_CORE:
			_gen_downtown_chunk(root, cx, cz)
		District.MIDTOWN:
			_gen_midtown_chunk(root, cx, cz)
		District.CHINATOWN:
			_gen_chinatown_chunk(root, cx, cz)
		District.INDUSTRIAL_NORTH, District.INDUSTRIAL_SOUTH:
			_gen_industrial_chunk(root, cx, cz)
		District.DOCKLANDS:
			_gen_docks_chunk(root, cx, cz)
		District.SLUMS_EAST, District.SLUMS_WEST:
			_gen_slums_chunk(root, cx, cz)
		District.SUBURBS_NORTH, District.SUBURBS_SOUTH:
			_gen_suburbs_chunk(root, cx, cz)
		District.AIRPORT:
			_gen_airport_chunk(root, cx, cz)
		District.MILITARY_BASE:
			_gen_military_chunk(root, cx, cz)
		District.COUNTRYSIDE_NW, District.COUNTRYSIDE_NE:
			_gen_countryside_chunk(root, cx, cz, false)
		District.COUNTRYSIDE_SW, District.COUNTRYSIDE_SE:
			_gen_countryside_chunk(root, cx, cz, true)
		District.OCEAN:
			_gen_ocean_chunk(root, cx, cz)
		_:
			_gen_generic_terrain_chunk(root, cx, cz)

	_populate_street_furniture(root, cx, cz, district)

# ─── DOWNTOWN GENERATOR ────────────────────────────────────
func _gen_downtown_chunk(root: Node3D, cx: float, cz: float) -> void:
	var cell_size := 55.0
	var cols := int(CHUNK_SIZE / cell_size)
	for col in cols:
		for row in cols:
			var lx := cx - CHUNK_SIZE*0.5 + col * cell_size + cell_size*0.5
			var lz := cz - CHUNK_SIZE*0.5 + row * cell_size + cell_size*0.5
			if _rng.randf() > 0.15:  # 85% fill
				_place_skyscraper(root, lx, lz, col, row)

func _place_skyscraper(root: Node3D, x: float, z: float, col: int, row: int) -> void:
	var h_range := BUILDING_HEIGHTS[District.DOWNTOWN_CORE]
	var height := _rng.randf_range(h_range[0], h_range[1])
	var w := _rng.randf_range(22, 45)
	var d := _rng.randf_range(20, 42)

	# Base podium
	var podium := _make_box(root, x, 0, z, w + 8, 6, d + 8,
		_pick_mat(["concrete_modern", "concrete_brutalist"]))
	podium.name = "Podium_%d_%d" % [col, row]

	# Main tower body
	var body := _make_box(root, x, 3 + height*0.5, z, w, height, d,
		_pick_mat(["glass_curtain_wall", "concrete_modern", "glass_dark",
				   "concrete_brutalist", "metal_panel"]))
	body.name = "Tower_%d_%d" % [col, row]

	# Setback
	if height > 100 and _rng.randf() > 0.5:
		var sb_h := _rng.randf_range(30, height * 0.5)
		var _setback := _make_box(root, x, height * 0.6, z,
			w * 0.65, sb_h, d * 0.65,
			_pick_mat(["glass_curtain_wall", "glass_dark", "metal_panel"]))

	# Spire / antenna
	if _rng.randf() > 0.6:
		var spire_h := _rng.randf_range(15, 45)
		var _spire := _make_cylinder(root, x, height + spire_h*0.5, z,
			_rng.randf_range(0.5, 1.5), spire_h, "metal_clean")

	# Rooftop details
	_place_rooftop_details(root, x, z, w, d, height)

	# Neon signs on lower floors
	if _rng.randf() > 0.5:
		_place_neon_sign(root, x, z, w, 20)

	# Window lighting
	var wlight := OmniLight3D.new()
	wlight.light_color = Color(_rng.randf_range(0.7,1.0),
								_rng.randf_range(0.6,1.0),
								_rng.randf_range(0.4,0.9))
	wlight.light_energy = _rng.randf_range(0.8, 2.5)
	wlight.omni_range = _rng.randf_range(30, 80)
	wlight.transform.origin = Vector3(x, height * 0.4, z)
	wlight.shadow_enabled = false
	root.add_child(wlight)

func _place_rooftop_details(root: Node3D, x: float, z: float,
							 w: float, d: float, height: float) -> void:
	var count := _rng.randi_range(2, 8)
	for i in count:
		var rx := x + _rng.randf_range(-w*0.4, w*0.4)
		var rz := z + _rng.randf_range(-d*0.4, d*0.4)
		match _rng.randi_range(0, 4):
			0: # AC unit
				var _ac := _make_box(root, rx, height + 0.75, rz,
					_rng.randf_range(1.5, 3.0), 1.5, _rng.randf_range(1.5, 2.5),
					"concrete_modern")
			1: # Comms tower
				var _ct := _make_cylinder(root, rx, height + 4, rz,
					0.2, 8.0, "metal_clean")
			2: # Water tank
				var _wt := _make_cylinder(root, rx, height + 2, rz,
					_rng.randf_range(1.5, 3.0), 4.0, "wood_plank")
			3: # Helipad
				var _hp := _make_box(root, x, height + 0.4, z,
					min(w*0.6, 16), 0.4, min(d*0.6, 16), "asphalt_worn")
				var hl := OmniLight3D.new()
				hl.light_color = Color(1.0, 0.3, 0.0)
				hl.light_energy = 2.0
				hl.omni_range = 8.0
				hl.shadow_enabled = false
				hl.transform.origin = Vector3(x, height + 1.5, z)
				root.add_child(hl)
			4: # Rooftop garden (green patch)
				var _rg := _make_box(root, rx, height + 0.3, rz,
					_rng.randf_range(4, 8), 0.3, _rng.randf_range(4, 8),
					"grass_urban")

# ─── MIDTOWN GENERATOR ─────────────────────────────────────
func _gen_midtown_chunk(root: Node3D, cx: float, cz: float) -> void:
	var cell_size := 45.0
	var cols := int(CHUNK_SIZE / cell_size)
	for col in cols:
		for row in cols:
			var lx := cx - CHUNK_SIZE*0.5 + col * cell_size + _rng.randf_range(-4, 4)
			var lz := cz - CHUNK_SIZE*0.5 + row * cell_size + _rng.randf_range(-4, 4)
			if _rng.randf() > 0.22:
				var h := _rng.randf_range(25, 85)
				var w := _rng.randf_range(18, 38)
				var d := _rng.randf_range(16, 32)
				var _b := _make_box(root, lx, h*0.5, lz, w, h, d,
					_pick_mat(["brick_red", "brick_dark", "concrete_stained",
							   "concrete_worn", "concrete_modern"]))
				if _rng.randf() > 0.5:
					_place_fire_escape(root, lx, lz, w, d, h)
				if _rng.randf() > 0.6:
					_place_neon_sign(root, lx, lz, w, _rng.randf_range(10, 30))

# ─── CHINATOWN GENERATOR ───────────────────────────────────
func _gen_chinatown_chunk(root: Node3D, cx: float, cz: float) -> void:
	var cell_size := 22.0
	var cols := int(CHUNK_SIZE / cell_size)
	for col in cols:
		for row in cols:
			var lx := cx - CHUNK_SIZE*0.5 + col * cell_size + _rng.randf_range(-3, 3)
			var lz := cz - CHUNK_SIZE*0.5 + row * cell_size + _rng.randf_range(-3, 3)
			if _rng.randf() > 0.08:  # Very dense
				var h := _rng.randf_range(8, 30)
				var w := _rng.randf_range(8, 18)
				var _b := _make_box(root, lx, h*0.5, lz, w, h, w * 0.85,
					_pick_mat(["brick_red", "concrete_stained", "concrete_worn"]))
				# Lots of neon
				_place_neon_sign(root, lx, lz, w, _rng.randf_range(6, 18),
					_rng.randi_range(2, 5))  # Multiple signs per building
				# Canopies / awnings
				var _aw := _make_box(root, lx, _rng.randf_range(4, 8), lz + w*0.5 + 1,
					w * 0.8, 0.2, 2.5, _pick_mat(["metal_corrugated", "wood_plank"]))

# ─── INDUSTRIAL GENERATOR ──────────────────────────────────
func _gen_industrial_chunk(root: Node3D, cx: float, cz: float) -> void:
	# Large factory blocks
	for i in _rng.randi_range(1, 3):
		var lx := cx + _rng.randf_range(-100, 100)
		var lz := cz + _rng.randf_range(-100, 100)
		var w := _rng.randf_range(40, 90)
		var d := _rng.randf_range(30, 70)
		var h := _rng.randf_range(15, 45)
		var _factory := _make_box(root, lx, h*0.5, lz, w, h, d, "metal_corrugated")
		# Chimneys
		var chimney_count := _rng.randi_range(1, 4)
		for _ci in chimney_count:
			var chx := lx + _rng.randf_range(-w*0.35, w*0.35)
			var chz := lz + _rng.randf_range(-d*0.35, d*0.35)
			var ch_h := _rng.randf_range(25, 60)
			var _ch := _make_cylinder(root, chx, h + ch_h*0.5, chz,
				_rng.randf_range(1.0, 2.5), ch_h, "chimney")
			var clight := OmniLight3D.new()
			clight.light_color = Color(1.0, 0.4, 0.05)
			clight.light_energy = _rng.randf_range(3, 8)
			clight.omni_range = 20.0
			clight.shadow_enabled = false
			clight.transform.origin = Vector3(chx, h + ch_h + 2, chz)
			root.add_child(clight)

	# Oil / storage tanks
	var tank_count := _rng.randi_range(2, 6)
	for _ti in tank_count:
		var tx := cx + _rng.randf_range(-110, 110)
		var tz := cz + _rng.randf_range(-110, 110)
		var tr := _rng.randf_range(5, 14)
		var th := _rng.randf_range(10, 22)
		var _tank := _make_cylinder(root, tx, th*0.5, tz, tr, th, "oil_tank")

	# Warehouses
	for _wi in _rng.randi_range(1, 3):
		var wx := cx + _rng.randf_range(-110, 110)
		var wz := cz + _rng.randf_range(-110, 110)
		var ww := _rng.randf_range(35, 65)
		var wd := _rng.randf_range(25, 45)
		var wh := _rng.randf_range(12, 22)
		var _wh := _make_box(root, wx, wh*0.5, wz, ww, wh, wd, "metal_corrugated")

	# Perimeter security
	_place_perimeter_wall(root, cx, cz, 230, 4.5, "concrete_worn")
	_place_perimeter_wall(root, cx, cz, 232, 1.5, "metal_rusty")

# ─── DOCKS GENERATOR ───────────────────────────────────────
func _gen_docks_chunk(root: Node3D, cx: float, cz: float) -> void:
	# Warehouses along dock
	for _wi in _rng.randi_range(2, 4):
		var lx := cx + _rng.randf_range(-100, 100)
		var lz := cz + _rng.randf_range(-80, 80)
		var _b := _make_box(root, lx, 10, lz,
			_rng.randf_range(35, 55), 20, _rng.randf_range(25, 40), "metal_corrugated")

	# Container stacks (physics-enabled or static)
	for si in _rng.randi_range(5, 20):
		var sx := cx + _rng.randf_range(-110, 110)
		var sz := cz + _rng.randf_range(-110, 110)
		var stack_h := _rng.randi_range(1, 5)
		var container_mats := ["container_red","container_blue","container_green","container_yellow"]
		for sh in stack_h:
			var _c := _make_box(root, sx, sh * 2.5 + 1.25, sz,
				6.0, 2.5, 2.5, container_mats[si % 4])

	# Cranes
	for _cri in _rng.randi_range(1, 3):
		var crx := cx + _rng.randf_range(-100, 100)
		var crz := cz + _rng.randf_range(-80, 80)
		var crane_h := _rng.randf_range(40, 80)
		# Tower
		var _ct := _make_box(root, crx, crane_h*0.5, crz, 4, crane_h, 4, "steel_beam")
		# Boom
		var _cb := _make_box(root, crx, crane_h + 1.5, crz - 18,
			2.5, 3.0, 40, "steel_beam")
		# Crane light
		var cl := SpotLight3D.new()
		cl.light_color = Color(0.9, 0.9, 1.0)
		cl.light_energy = 15.0
		cl.spot_range = 60.0
		cl.spot_angle = 35.0
		cl.shadow_enabled = true
		cl.transform.origin = Vector3(crx, crane_h + 3, crz)
		cl.transform = cl.transform.looking_at(Vector3(crx, 0, crz), Vector3.UP)
		root.add_child(cl)

	# Jetties
	for _ji in _rng.randi_range(1, 4):
		var jx := cx + _rng.randf_range(-100, 100)
		var jz := cz + 80
		var jl := _rng.randf_range(40, 80)
		var _jetty := _make_box(root, jx, 0.5, jz + jl*0.5, 6, 0.8, jl, "wood_plank")

# ─── SLUMS GENERATOR ───────────────────────────────────────
func _gen_slums_chunk(root: Node3D, cx: float, cz: float) -> void:
	var cell_size := 18.0
	var cols := int(CHUNK_SIZE / cell_size)
	for col in cols:
		for row in cols:
			if _rng.randf() > 0.10:  # Very dense, irregular
				var angle := _rng.randf_range(-0.15, 0.15)  # Organic angles
				var lx := cx - CHUNK_SIZE*0.5 + col * cell_size + _rng.randf_range(-5, 5)
				var lz := cz - CHUNK_SIZE*0.5 + row * cell_size + _rng.randf_range(-5, 5)
				var h := _rng.randf_range(5, 18)
				var w := _rng.randf_range(8, 20)
				var d := _rng.randf_range(6, 16)
				var mat := _pick_mat(["brick_red", "brick_dark", "metal_corrugated",
									  "concrete_worn", "concrete_stained", "wood_plank"])
				var body := _make_box(root, lx, h*0.5, lz, w, h, d, mat)
				body.rotation.y = angle

				# Rooftop shacks
				if _rng.randf() > 0.4:
					var sh := _rng.randf_range(2, 5)
					var _shack := _make_box(root, lx + _rng.randf_range(-w*0.3, w*0.3),
						h + sh*0.5, lz + _rng.randf_range(-d*0.3, d*0.3),
						_rng.randf_range(3, 7), sh, _rng.randf_range(3, 6),
						"metal_corrugated")

				# Connecting bridges between buildings (random)
				if _rng.randf() > 0.8 and col < cols - 1:
					var next_x := cx - CHUNK_SIZE*0.5 + (col+1) * cell_size
					var bridge_y := minf(h, _rng.randf_range(4.0, h)) * 0.8
					var span := next_x - lx
					var _br := _make_box(root, lx + span*0.5, bridge_y, lz,
						span, 0.3, 1.5, "wood_plank")

				# Fire barrels / lights
				if _rng.randf() > 0.7:
					var fl := OmniLight3D.new()
					fl.light_color = Color(1.0, _rng.randf_range(0.3,0.5), 0.0)
					fl.light_energy = _rng.randf_range(3.0, 6.0)
					fl.omni_range = _rng.randf_range(6, 12)
					fl.shadow_enabled = false
					fl.transform.origin = Vector3(lx + _rng.randf_range(-5,5),
												   1.5,
												   lz + _rng.randf_range(-5,5))
					root.add_child(fl)

				# Neon (dim, criminal)
				if _rng.randf() > 0.65:
					_place_neon_sign(root, lx, lz, w, h * 0.5, 1, 0.6)

# ─── SUBURBS GENERATOR ─────────────────────────────────────
func _gen_suburbs_chunk(root: Node3D, cx: float, cz: float) -> void:
	var cell_size := 40.0
	var cols := int(CHUNK_SIZE / cell_size)
	for col in cols:
		for row in cols:
			if _rng.randf() > 0.35:  # Sparser
				var lx := cx - CHUNK_SIZE*0.5 + col * cell_size + _rng.randf_range(-8, 8)
				var lz := cz - CHUNK_SIZE*0.5 + row * cell_size + _rng.randf_range(-8, 8)
				var w := _rng.randf_range(10, 18)
				var d := _rng.randf_range(9, 16)
				var h := _rng.randf_range(5, 12)
				# House body
				var _house := _make_box(root, lx, h*0.5, lz, w, h, d,
					_pick_mat(["brick_red", "brick_dark", "concrete_stained"]))
				# Pitched roof (wedge approximation)
				var _roof := _make_box(root, lx, h + 1.5, lz, w+1.5, 3.5, d+1.5,
					_pick_mat(["metal_corrugated", "brick_dark"]))
				# Fence
				_make_box(root, lx, 0.8, lz - d*0.5 - 0.5, w + 4, 1.6, 0.2, "wood_plank")
				_make_box(root, lx, 0.8, lz + d*0.5 + 0.5, w + 4, 1.6, 0.2, "wood_plank")
				# Garden / trees
				if _rng.randf() > 0.4:
					for _ti in _rng.randi_range(1, 4):
						var tx := lx + _rng.randf_range(-w, w)
						var tz := lz + _rng.randf_range(-d, d)
						_place_tree(root, tx, tz)
				# Parked car
				if _rng.randf() > 0.5:
					_make_box(root, lx + _rng.randf_range(-w*0.3, w*0.3),
							  0.8, lz + d*0.5 + 2.5,
							  4.5, 1.6, 9.0, "concrete_modern")

# ─── AIRPORT GENERATOR ─────────────────────────────────────
func _gen_airport_chunk(root: Node3D, cx: float, cz: float) -> void:
	# Only generate special structures if near terminal or runway zones
	var dist_to_center := Vector2(cx, cz).distance_to(Vector2(-400, -2150))
	if dist_to_center < 300:
		# Terminal
		if _rng.randf() > 0.5:
			var _term := _make_box(root, cx, 11, cz, 130, 22, 35, "glass_curtain_wall")
			var _base := _make_box(root, cx, 4, cz, 136, 9, 40, "concrete_modern")
		# Control tower
		var _shaft := _make_box(root, cx - 200, 35, cz, 9, 70, 9, "concrete_dark" if false else "concrete_modern")
		var _cab := _make_box(root, cx - 200, 73, cz, 16, 7, 16, "glass_dark")
		# Hangar
		var _hangar := _make_box(root, cx + 100, 13, cz - 50, 60, 26, 50, "metal_corrugated")
		# Runway lights
		var runway_steps := 20
		for ri in runway_steps:
			var rl := OmniLight3D.new()
			rl.light_color = Color(0.4, 0.7, 1.0)
			rl.light_energy = 3.0
			rl.omni_range = 12.0
			rl.shadow_enabled = false
			rl.transform.origin = Vector3(cx - 300 + ri * 30.0, 0.5, cz - 25)
			root.add_child(rl)

# ─── MILITARY GENERATOR ────────────────────────────────────
func _gen_military_chunk(root: Node3D, cx: float, cz: float) -> void:
	# Bunkers
	for _bi in _rng.randi_range(1, 3):
		var bx := cx + _rng.randf_range(-100, 100)
		var bz := cz + _rng.randf_range(-100, 100)
		var bw := _rng.randf_range(20, 45)
		var _bunker := _make_box(root, bx, 2.5, bz, bw, 5, bw * 0.7, "concrete_brutalist")
		# Earthwork mound
		var _mound := _make_cylinder(root, bx, -0.5, bz, bw * 0.8, 3.5, "dirt_dry")

	# Watchtowers
	for _wt in _rng.randi_range(1, 4):
		var tx := cx + _rng.randf_range(-110, 110)
		var tz := cz + _rng.randf_range(-110, 110)
		var th := _rng.randf_range(12, 22)
		var _leg := _make_box(root, tx, th*0.4, tz, 1.5, th*0.8, 1.5, "metal_rusty")
		var _cab := _make_box(root, tx, th, tz, 5, 3, 5, "concrete_modern")
		var sl := SpotLight3D.new()
		sl.light_color = Color(1.0, 0.95, 0.8)
		sl.light_energy = 20.0
		sl.spot_range = 80.0
		sl.spot_angle = 28.0
		sl.shadow_enabled = true
		sl.transform.origin = Vector3(tx, th + 2, tz)
		root.add_child(sl)

	# Perimeter double fence
	_place_perimeter_wall(root, cx, cz, 240, 4.0, "metal_rusty")
	_place_perimeter_wall(root, cx, cz, 250, 4.0, "metal_rusty")

# ─── COUNTRYSIDE GENERATOR ─────────────────────────────────
func _gen_countryside_chunk(root: Node3D, cx: float, cz: float, rocky: bool) -> void:
	# Scatter trees, rocks, shrubs
	var tree_count := _rng.randi_range(8, 30) if not rocky else _rng.randi_range(2, 8)
	for _ti in tree_count:
		var tx := cx + _rng.randf_range(-120, 120)
		var tz := cz + _rng.randf_range(-120, 120)
		_place_tree(root, tx, tz)

	if rocky:
		var rock_count := _rng.randi_range(5, 18)
		for _ri in rock_count:
			var rx := cx + _rng.randf_range(-120, 120)
			var rz := cz + _rng.randf_range(-120, 120)
			var rs := _rng.randf_range(1.5, 8.0)
			var _rock := _make_box(root, rx, rs*0.5, rz,
				rs * _rng.randf_range(0.8, 1.4),
				rs, rs * _rng.randf_range(0.7, 1.2), "rock_cliff")

	# Occasional farm buildings
	if _rng.randf() > 0.85:
		var fx := cx + _rng.randf_range(-80, 80)
		var fz := cz + _rng.randf_range(-80, 80)
		var _barn := _make_box(root, fx, 8, fz, 20, 16, 12, "wood_plank")
		var _roof := _make_box(root, fx, 17, fz, 22, 5, 14, "metal_corrugated")

# ─── OCEAN GENERATOR ───────────────────────────────────────
func _gen_ocean_chunk(root: Node3D, cx: float, cz: float) -> void:
	# Flat water surface
	var _water := _make_box(root, cx, -0.5, cz, CHUNK_SIZE, 1.0, CHUNK_SIZE, "water_ocean")
	# Occasional buoys
	if _rng.randf() > 0.7:
		var bl := OmniLight3D.new()
		bl.light_color = Color(1.0, 0.3, 0.1)
		bl.light_energy = 3.0
		bl.omni_range = 10.0
		bl.shadow_enabled = false
		bl.transform.origin = Vector3(
			cx + _rng.randf_range(-100, 100), 2.0,
			cz + _rng.randf_range(-100, 100))
		root.add_child(bl)

func _gen_generic_terrain_chunk(root: Node3D, cx: float, cz: float) -> void:
	var _grass := _make_box(root, cx, -0.5, cz, CHUNK_SIZE, 1.0, CHUNK_SIZE, "grass_wild")

# ─── STREET FURNITURE POPULATOR ────────────────────────────
func _populate_street_furniture(root: Node3D, cx: float, cz: float,
								 district: District) -> void:
	match district:
		District.DOWNTOWN_CORE, District.MIDTOWN, District.CHINATOWN:
			# Dense lampposts
			var lamp_count := _rng.randi_range(8, 20)
			for _li in lamp_count:
				_place_streetlamp(root,
					cx + _rng.randf_range(-120, 120), 0,
					cz + _rng.randf_range(-120, 120))
			# Bus stops
			for _bi in _rng.randi_range(1, 4):
				var _bench := _make_box(root,
					cx + _rng.randf_range(-120, 120), 0.5,
					cz + _rng.randf_range(-120, 120),
					2.5, 1.0, 0.6, "concrete_modern")
			# Dumpsters
			for _di in _rng.randi_range(2, 8):
				var dx := cx + _rng.randf_range(-120, 120)
				var dz := cz + _rng.randf_range(-120, 120)
				var _d := _make_box(root, dx, 1.0, dz, 2.4, 1.8, 1.2, "metal_rusty")
			# Traffic lights at intersections
			for _ti in _rng.randi_range(2, 5):
				_place_traffic_light(root,
					cx + _rng.randf_range(-120, 120), 0,
					cz + _rng.randf_range(-120, 120))

		District.SUBURBS_NORTH, District.SUBURBS_SOUTH:
			# Sparse lampposts
			for _li in _rng.randi_range(2, 5):
				_place_streetlamp(root,
					cx + _rng.randf_range(-120, 120), 0,
					cz + _rng.randf_range(-120, 120), Color(1.0, 0.9, 0.7))

		District.DOCKLANDS:
			# Dock lighting
			for _li in _rng.randi_range(4, 10):
				var sl := SpotLight3D.new()
				sl.light_color = Color(1.0, 0.9, 0.75)
				sl.light_energy = _rng.randf_range(8, 18)
				sl.spot_range = 40.0
				sl.spot_angle = 45.0
				sl.shadow_enabled = false
				sl.transform.origin = Vector3(
					cx + _rng.randf_range(-110, 110), 20,
					cz + _rng.randf_range(-110, 110))
				root.add_child(sl)

# ─── HELPER: PLACE STREETLAMP ──────────────────────────────
func _place_streetlamp(root: Node3D, x: float, y: float, z: float,
						color := Color(1.0, 0.75, 0.4)) -> void:
	var _post := _make_cylinder(root, x, 4.2, z, 0.1, 8.4, "metal_clean")
	var arm := CSGBox3D.new()
	arm.size = Vector3(0.1, 0.1, 1.8)
	arm.transform.origin = Vector3(x, 8.5, z + 0.9)
	root.add_child(arm)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = _rng.randf_range(2.5, 4.5)
	light.omni_range = _rng.randf_range(18, 28)
	light.shadow_enabled = false
	light.transform.origin = Vector3(x, 9.2, z + 1.8)
	root.add_child(light)

# ─── HELPER: PLACE TRAFFIC LIGHT ───────────────────────────
func _place_traffic_light(root: Node3D, x: float, _y: float, z: float) -> void:
	var _post := _make_cylinder(root, x, 4.2, z, 0.12, 8.4, "metal_clean")
	var _box := _make_box(root, x, 8.8, z, 0.6, 1.8, 0.4, "metal_clean")
	var active_color: Color = [Color(1, 0, 0), Color(1, 0.5, 0), Color(0, 1, 0)].pick_random()
	var tl := OmniLight3D.new()
	tl.light_color = active_color
	tl.light_energy = 2.5
	tl.omni_range = 8.0
	tl.shadow_enabled = false
	tl.transform.origin = Vector3(x, 8.8, z + 0.3)
	root.add_child(tl)

# ─── HELPER: PLACE NEON SIGN ───────────────────────────────
func _place_neon_sign(root: Node3D, x: float, z: float, width: float,
					   height: float, count := 1, energy_mult := 1.0) -> void:
	var neon_mats := ["neon_red","neon_cyan","neon_amber","neon_purple","neon_green","neon_white"]
	var neon_colors := [Color(1,0.05,0.05), Color(0,0.9,0.85), Color(1,0.55,0),
						Color(0.7,0.05,0.95), Color(0.05,0.95,0.1), Color(1,1,0.9)]
	for si in count:
		var offset_h := si * 3.5
		var mat_idx := _rng.randi_range(0, neon_mats.size()-1)
		var sign_y := height + offset_h + _rng.randf_range(-1, 2)
		var sign_w := _rng.randf_range(3.0, min(width * 0.8, 8.0))
		var _sign := _make_box(root,
			x + _rng.randf_range(-width*0.3, width*0.3),
			sign_y,
			z + (width * 0.5) + 0.1,
			sign_w, 0.35, 0.12,
			neon_mats[mat_idx])
		var nl := OmniLight3D.new()
		nl.light_color = neon_colors[mat_idx]
		nl.light_energy = _rng.randf_range(3, 7) * energy_mult
		nl.omni_range = _rng.randf_range(10, 22)
		nl.shadow_enabled = false
		nl.transform.origin = Vector3(x, sign_y, z + width * 0.5 + 1)
		root.add_child(nl)

# ─── HELPER: PLACE FIRE ESCAPE ─────────────────────────────
func _place_fire_escape(root: Node3D, x: float, z: float,
						 w: float, _d: float, h: float) -> void:
	var side := (1 if _rng.randf() > 0.5 else -1) * (w * 0.5 + 0.15)
	var floor_count := int(h / 3.5)
	for fi in floor_count:
		var fy := fi * 3.5 + 1.5
		var _platform := _make_box(root, x + side, fy, z, 3.0, 0.15, 2.0, "metal_rusty")
		var _railing := _make_box(root, x + side, fy + 0.6, z, 3.0, 0.08, 0.06, "metal_rusty")

# ─── HELPER: PERIMETER WALL ────────────────────────────────
func _place_perimeter_wall(root: Node3D, cx: float, cz: float,
							half_size: float, height: float, mat: String) -> void:
	# 4 sides of a square perimeter
	_make_box(root, cx,          height*0.5, cz - half_size, half_size*2, height, 1.0, mat)
	_make_box(root, cx,          height*0.5, cz + half_size, half_size*2, height, 1.0, mat)
	_make_box(root, cx - half_size, height*0.5, cz, 1.0, height, half_size*2, mat)
	_make_box(root, cx + half_size, height*0.5, cz, 1.0, height, half_size*2, mat)

# ─── HELPER: PLACE TREE ────────────────────────────────────
func _place_tree(root: Node3D, x: float, z: float) -> void:
	var h := _rng.randf_range(4, 16)
	var r := _rng.randf_range(1.5, 4.0)
	# Trunk
	var _trunk := _make_cylinder(root, x, h*0.35, z, r*0.15, h*0.7, "wood_plank")
	# Canopy
	var _canopy := _make_cylinder(root, x, h*0.75, z, r, h*0.55, "grass_wild")

# ─── PRIMITIVE FACTORY FUNCTIONS ───────────────────────────
func _make_box(root: Node3D, x: float, y: float, z: float,
			   w: float, h: float, d: float, mat_name: String) -> CSGBox3D:
	var box := CSGBox3D.new()
	box.size = Vector3(w, h, d)
	box.transform.origin = Vector3(x, y, z)
	box.use_collision = true
	# Assign material by name (will resolve to .tres path in real project)
	box.set_meta("material_key", mat_name)
	root.add_child(box)
	return box

func _make_cylinder(root: Node3D, x: float, y: float, z: float,
					radius: float, height: float, mat_name: String) -> CSGCylinder3D:
	var cyl := CSGCylinder3D.new()
	cyl.radius = radius
	cyl.height = height
	cyl.transform.origin = Vector3(x, y, z)
	cyl.use_collision = true
	cyl.set_meta("material_key", mat_name)
	root.add_child(cyl)
	return cyl

func _pick_mat(options: Array) -> String:
	return options[_rng.randi_range(0, options.size() - 1)]

# ─── COORDINATE HELPERS ────────────────────────────────────
func _world_to_chunk(world_pos: Vector3) -> Vector2i:
	var cx := int((world_pos.x + WORLD_SIZE * 0.5) / CHUNK_SIZE)
	var cz := int((world_pos.z + WORLD_SIZE * 0.5) / CHUNK_SIZE)
	return Vector2i(clamp(cx, 0, CHUNKS_PER_AXIS-1), clamp(cz, 0, CHUNKS_PER_AXIS-1))

func _get_district(world_x: float, world_z: float) -> District:
	# Check innermost first (more specific districts override outer ones)
	for district in DISTRICT_BOUNDS.keys():
		var b: Array = DISTRICT_BOUNDS[district]
		if world_x >= b[0] and world_x <= b[2] and world_z >= b[1] and world_z <= b[3]:
			return district
	return District.COUNTRYSIDE_NW

# ─── PUBLIC API ────────────────────────────────────────────
func force_generate_all() -> void:
	"""Generate entire world at once (editor only, very slow)."""
	for data in _chunk_data:
		if not data["loaded"]:
			var root := Node3D.new()
			root.name = "Chunk_%d_%d" % [data["cx"], data["cz"]]
			add_child(root)
			_generate_chunk(root, data)
			data["loaded"] = true
	print("[CityGenerator] Full world generated: %d chunks" % _chunk_data.size())

func get_district_at(world_pos: Vector3) -> String:
	return District.keys()[_get_district(world_pos.x, world_pos.z)]

func get_world_bounds() -> Rect2:
	return Rect2(-WORLD_SIZE*0.5, -WORLD_SIZE*0.5, WORLD_SIZE, WORLD_SIZE)
