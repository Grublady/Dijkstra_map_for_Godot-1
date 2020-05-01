extends "res://addons/gut/test.gd"
"""
"""

var map : DijkstraMap
var res
const _len = 5

func before_each():
	gut.p("#-----Start Test-----#")
	map = DijkstraMap.new()
	map.add_point(0,0)
	map.add_point(1,0)
	map.add_point(2,0)
	
func after_each():
	gut.p("#------End Test------#")

func test_add_point():
	res = map.add_point(3,0)
	assert_eq(res,OK,"you can add a point once")
	res = map.add_point(3,0)
	assert_eq(res,FAILED,"but not twice")
	res = map.add_point(3,1)
	assert_eq(res,FAILED,"you cannot even change the terrain this way")

func test_set_terrain():
	res = map.set_terrain_for_point(0,1)
	assert_eq(res,OK,"you can set the point terrain")
	assert_eq(map.get_terrain_for_point(0),1,"the terrain corresponds")
	
	res = map.set_terrain_for_point(0,2)
	assert_eq(res,OK,"has much as you want")
	assert_eq(map.get_terrain_for_point(0),2,"the terrain corresponds")

func test_has_points():
	assert_true(map.has_point(1))
	assert_true(map.has_point(2))
	assert_false(map.has_point(3))

func test_connect_points():
	res = map.connect_points(1,3,1.0,false)
	assert_eq(res,FAILED,"id absent should failed")
	
	res = map.connect_points(1,4,1.0,true)
	assert_eq(res,FAILED,"id absent should failed")
	
	res = map.connect_points(1,2,1.0,false)
	assert_eq(res,OK,"id both exist, connects ok")
	
func test_connect_defaut_args():
	res = map.connect_points(1,3)
	assert_eq(res,FAILED,"id absent should failed")
	
	res = map.connect_points(1,4)
	assert_eq(res,FAILED,"id absent should failed")
	
	res = map.connect_points(1,2)
	assert_eq(res,OK,"id both exist, connects ok")
	



func test_connect_points_recalculate():
	gut.p("reversed, unilateral : point as target from which you start")
	res = map.connect_points(1,2,1.0,false)
	assert_eq(res,OK,"connected 1 -> 2 succesfully")
	
	map.recalculate(1,{"input is destination":false}) #this throws a gdnative error if it fails, 
							#the only way i can see it is by opening godot in the terminal and watching it...
	
	res = map.get_cost_at_point(2)
	assert_eq(res,1.0,"1 is target where the search starts 1->2 costs 1")
	
	gut.p(map.get_cost_map())
	
	gut.p("reversed, unilateral : point as target from which you start")
	map.recalculate(2,{"input is destination":true})
	
	res = map.get_cost_at_point(1)
	assert_eq(res,1.0,"2 is where you want to go\n1->2 costs 1.0")
	
	res = map.get_cost_at_point(2)
	assert_eq(res,0.0,"2 is where you want to be, cost 0.0")
	gut.p(map.get_cost_map())

func test_connect_points_recalculate_default_args():
	res = map.connect_points(1,2,1.0,false)
	map.recalculate(1)
	
	res = map.get_cost_at_point(2)
	assert_eq(res,1.0,"2 is where you want to go\n1->2 costs 1.0")
	
	res = map.get_cost_at_point(1)
	assert_eq(res,0.0,"1 is where you want to be, cost 0.0")


func test_disable_enables():
	map.add_point(3,0)
	map.connect_points(1,2,1.0,false)
	map.connect_points(2,3,1.0,false)
	
	gut.p("recalculate")
	map.recalculate(1,{'input is destination':false})
	gut.p("end_recalculate")
	
	assert_eq(map.get_cost_at_point(3),2.0,"point is enabled, you can go from 1 to 3 via 2")
	map.disable_point(2)
	map.recalculate(1,{'input is destination':false})
	
	assert_eq(map.get_cost_at_point(3),INF,"2 is disabled")
	map.enable_point(2)
	map.recalculate(1,{'input is destination':false})
	
	assert_eq(map.get_cost_at_point(3),2.0,"back to ok")
	
	
func test_connect_point_unilateral():
	
	map.connect_points(1,2,1.0,false)
	map.connect_points(2,3,1.0,false)
	
	
	assert_true(map.has_point(1))
	assert_true(map.has_point(2))
	
	assert_false(map.is_point_disabled(1))
	assert_false(map.is_point_disabled(2))
	
	assert_true(map.has_connection(1,2),"1 to 2 should be connected")
	assert_false(map.has_connection(2,1),"reverse connection doesnt exist")
	
	map.recalculate(1,{'input is destination':false})
	assert_eq(map.get_cost_at_point(2),1.0,"")
	
func test_connect_point_bilateral():
	pending()
	map.connect_points(1,2,1.0,true)
	#map.recalculate_for_target(1,INF,false)
	map.recalculate(1,{'input is destination':true})
	
	assert_true(map.has_point(1))
	assert_true(map.has_point(2))
	
	assert_false(map.is_point_disabled(1))
	assert_false(map.is_point_disabled(2))
	
	assert_true(map.has_connection(1,2),"1 to 2 should be connected")
	assert_true(map.has_connection(2,1),"2 to 1 connected")
	
	gut.p(map.get_cost_map())
	assert_eq(map.get_cost_at_point(2),1.0)
	assert_eq(map.get_cost_at_point(1),0.0)

func test_create_as_grid():
	var relative_connections := {}
	var initial_offset := 0
	map = DijkstraMap.new()
	for size in 4:
		gut.p("size : " +str(size))
		gut.p("id to pos :")
		gut.p(Tcreate_as_grid(map,relative_connections,initial_offset,size))
	
	map = DijkstraMap.new()
	relative_connections = {Vector2.RIGHT : 1.0}
	
	var id_to_pos : Dictionary = Tcreate_as_grid(map,relative_connections,0,5)
	## we get a way to pos -> id
	var pos_to_id = {}
	for each_id in id_to_pos.keys():
		var each_pos = id_to_pos[each_id]
		pos_to_id[each_pos] = each_id
	##
	var this_pos = Vector2(2,2)
	
	assert_true(\
			map.has_connection(\
						pos_to_id[this_pos],\
						pos_to_id[this_pos + Vector2.RIGHT]\
						),\
			"a point not on the edge should be connected to its Right neighbour"
				)
	assert_false(\
			map.has_connection(pos_to_id[this_pos + Vector2.RIGHT],\
								pos_to_id[this_pos]\
								),\
			"but its not reciprocal"
				)
	
	
	
func Tcreate_as_grid(map,relatvConnect,initaloffset,size):
	var bitmap := BitMap.new()
	bitmap.create(Vector2.ONE * size)
	bitmap.set_bit_rect(Rect2(Vector2.ZERO,\
						Vector2.ONE * size)\
						,true
					)
	
	
	return map.initialize_as_grid(bitmap,relatvConnect,initaloffset)



