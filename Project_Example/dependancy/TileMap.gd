extends TileMap


var dijkstra_map_for_pikemen: DijkstraMap
var dijkstra_map_for_archers: DijkstraMap

var point_id_to_position: Dictionary = {}
var point_position_to_id: Dictionary = {}
var speed_modifiers: Dictionary = {}


func _ready() -> void:
	#we create our Dijkstra maps. We will need 2 - one for archers, one for pikemen
	dijkstra_map_for_archers = DijkstraMap.new()
	dijkstra_map_for_pikemen = DijkstraMap.new()
	#first we must add all points and connections to the dijkstra maps
	#this only has to be done once, when project loads

	#we collect all walkable tiles from the tilemap
	var walkable_tiles: Array = []
	for tilename in ["grass", "bushes", "road"]:
		var tile_id: int = tile_set.find_tile_by_name(tilename)
		walkable_tiles += get_used_cells_by_id(tile_id)

	#DijkstraMap only ever references points by their unique ID.
	#It does not know about their actual position or even what they represent.
	#We will have to keep dictionaries to lookup position by ID and vice versa
	point_id_to_position.clear()
	point_position_to_id.clear()
	#now we insert the points
	var id: int = 0
	for pos in walkable_tiles:
		id += 1
		point_id_to_position[id] = pos
		point_position_to_id[pos] = id
		#we also need to specify a terrain type for the tile.
		#terrain types can then have different weights, when DijkstraMap is recalculated
		var terrain_type: int = self.get_cellv(pos)
		dijkstra_map_for_archers.add_point(id, terrain_type)

	#now we need to connect the points with connections
	#each connection has a source point, target point and a cost

	var orthogonal: Array = [Vector2.DOWN, Vector2.UP, Vector2.LEFT, Vector2.RIGHT]
	var diagonal: Array = [
		Vector2.DOWN + Vector2.LEFT,
		Vector2.UP + Vector2.LEFT,
		Vector2.DOWN + Vector2.RIGHT,
		Vector2.UP + Vector2.RIGHT
	]

	for pos in walkable_tiles:
		#NOTE: costs are a measure of time. they are distance/speed
		var id_of_current_tile: int = point_position_to_id[pos]
		#we loop through orthogonal tiles
		var cost: float = 1.0
		for offset in orthogonal:
			var pos_of_neighbour: Vector2 = pos + offset
			var id_of_neighbour: int = point_position_to_id.get(pos_of_neighbour, -1)
			#we skip adding connection if point doesnt exist
			if id_of_neighbour == -1:
				continue
			#now we make the connection.
			#Note: last parameter specifies whether to also make the reverse connection too.
			#since we loop through all points and their neighbours in both directions anyway, this would be unnecessary. 
			dijkstra_map_for_archers.connect_points(
				id_of_current_tile, id_of_neighbour, cost, false
			)

		#we do the same for diagonal tiles, except cost is further multiplied by sqrt(2)
		cost = sqrt(2.0)
		for offset in diagonal:
			var pos_of_neighbour: Vector2 = pos + offset
			var id_of_neighbour: int = point_position_to_id.get(pos_of_neighbour, -1)
			#we skip adding connection if point doesnt exist
			if id_of_neighbour == -1:
				continue
			dijkstra_map_for_archers.connect_points(
				id_of_current_tile, id_of_neighbour, cost, false
			)

	#now we will duplicate the points and connections into dijkstra_map_for_pikemen
	#This way we dont have to manually add them in, each time we need independent dijkstra map with the same graph.
	dijkstra_map_for_pikemen.duplicate_graph_from(dijkstra_map_for_archers)

	#lastly, we specify the weights for different terrain types:
	#note: higher value means slower movement.
	speed_modifiers = {
		tile_set.find_tile_by_name("grass"): 1.0,
		tile_set.find_tile_by_name("bushes"): 2.0,
		tile_set.find_tile_by_name("road"): 0.5
	}
	#now that points are added and properly connected, we can calculate the dijkstra maps

	recalculate_dijkstra_maps()


func recalculate_dijkstra_maps() -> void:
	#where is the dragon_position_id?

	var dragon_position_id: int = point_position_to_id.get(world_to_map(get_node("dragon").position), 0)

	#we want pikemen to charge the dragon_position_id head on
	#We .recalculate the DijkstraMap.
	#First argument is the origin (be default) or destination (ie. the ID of the point where dragon_position_id is).
	#Second argument is a dictionary of optional parameters. For absent entries, default values are used.
	#We will specify the terrain weights and specify that input is the destination, not origin
	var optional_parameters: Dictionary = {"terrain_weights": speed_modifiers, "input_is_destination": true}

	var res: int = dijkstra_map_for_pikemen.recalculate(dragon_position_id, optional_parameters)
	assert(res == 0)
	#now the map has recalculated for pikemen and we can access the data.

	#we want archers to stand at safe distance from the dragon_position_id, but within firing range.
	#dragon_position_id flies, so terrain doesnt matter
	#first we recalculate their Dijkstra map with dragon_position_id as the origin.
	#we also do not need to calculate entire DijkstraMap, only until we have points at required distance
	#this can be achieved by providing optional parameter "maximum cost"

	res = dijkstra_map_for_archers.recalculate(dragon_position_id,optional_parameters)
	assert(res == 0)
	#now we get IDs of all points safe distance from dragon_position_id, but within firing range
	var stand_over_here: PoolIntArray = dijkstra_map_for_archers.get_all_points_with_cost_between(4.0, 5.0)
	var cost_map: Dictionary = dijkstra_map_for_archers.get_cost_map()
	var direction_map: Dictionary = dijkstra_map_for_archers.get_direction_map()
	optional_parameters = {"terrain_weights": speed_modifiers, "input_is_destination": true}
	#and we pass those points as new destinations for the archers to walk towards
	res = dijkstra_map_for_archers.recalculate(stand_over_here, {"terrain_weights": speed_modifiers})
	assert(res == 0)
	#BTW yes, Dijkstra map works for multiple destination points too.
	#The path will simply lead towards the nearest destination point.


func get_speed_modifier(pos: Vector2) -> float:
	return 1.0 / speed_modifiers.get(get_cellv(world_to_map(pos)), 0.5)


#given position of a pikeman,
#this method will look up the indented direction of movement for the pikeman.
func get_direction_for_pikeman(pos: Vector2) -> Vector2:
	var map_coords: Vector2 = world_to_map(pos)
	#we look up in the Dijkstra map where the pikeman should go next

	var target_ID: int = dijkstra_map_for_pikemen.get_direction_at_point(
		point_position_to_id[map_coords]
	)
	#if dragon_position_id is inaccessible from current position, then Dijkstra map spits out -1
	if target_ID == -1:
		return Vector2(0, 0)
	var target_coords: Vector2 = point_id_to_position[target_ID]
	return map_coords.direction_to(target_coords)


func get_direction_for_archer(pos: Vector2) -> Vector2:
	var map_coords: Vector2 = world_to_map(pos)
	#we look up in the Dijkstra map where the archer should go next
	
	var target_ID: int = dijkstra_map_for_archers.get_direction_at_point(
		point_position_to_id[map_coords]
	)
	#if dragon_position_id is inaccessible from current position, then Dijkstra map spits out -1
	if target_ID == -1:
		return Vector2(0, 0)
	var target_coords: Vector2 = point_id_to_position[target_ID]
	return map_coords.direction_to(target_coords)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var pos: Vector2 = get_local_mouse_position()
		var dragon_position_id: KinematicBody2D = get_node("dragon")
		dragon_position_id.position = pos
		recalculate_dijkstra_maps()
