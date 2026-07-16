extends TileMapLayer

func global_to_map(pos: Vector2):
  return local_to_map(to_local(pos))

func get_cell_at(pos: Vector2): 
  return get_cell_tile_data(global_to_map(pos))

func set_puddlemap_cells(pos: Vector2):
  set_cell(global_to_map(pos), 0, Vector2i(0,0))
  set_cell(global_to_map(pos) + Vector2i(1,0), 0, Vector2i(0,0))
  set_cell(global_to_map(pos) + Vector2i(0,1), 0, Vector2i(0,0))
  set_cell(global_to_map(pos) - Vector2i(1,0), 0, Vector2i(0,0))
  set_cell(global_to_map(pos) - Vector2i(0,1), 0, Vector2i(0,0))
