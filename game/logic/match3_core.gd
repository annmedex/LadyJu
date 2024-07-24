extends Node

class_name Match3Logic

enum EItemTypes{
	RED,
	BLUE,
	GREEN,
	PURPLE,
	WHITE,
	YELLOW
}

var _cols:int = 0
var _rows:int = 0
var _size:int = 0
var _cells:Array
var _result:UpdateResult = UpdateResult.new()
var _spawn_index:int = 0

func _init(cols:int, rows:int):
	for col in range(cols):
		var array:Array[CellModel]
		for row in range(rows):
			array.append(CellModel.new())
		print("Add row size {0}".format([array.size()]))
		_cells.append(array)
	_cols = cols
	_rows = rows
	_size = cols * rows
	
func set_cell_opt(flat_index:int, is_hole:bool, is_spawn:bool):
	if flat_index < _size:
		var cell = _cells[flat_index % _cols][flat_index / _cols] as CellModel
		cell.is_hole = is_hole
		cell.is_spawn = is_spawn
	
func set_cell_item(flat_index:int, is_blocked:bool, type:EItemTypes):
	var cell = _cells[flat_index % _cols][flat_index / _cols] as CellModel
	cell.items.append(ItemModel.new(is_blocked, type))

func _move_if_can(col:int, row:int, shift:int, result:UpdateResult)->bool:
	if col + shift >= 0 \
	and col + shift < _cols \
	and _cells[col + shift][row + 1].can_receive():
		var from_flat_index = col + row * _cols
		var to_flat_index = col + shift + (row + 1) * _cols
		result.moves.append([from_flat_index, to_flat_index])
		_cells[col][row].swap(_cells[col + shift][row + 1])
		return true
	return false
	
func _spawn(col:int, row:int, result:UpdateResult):
	var new_item = _spawn_index
	_spawn_index += 1
	if _spawn_index == EItemTypes.size():
		_spawn_index = 0
	_cells[col][row].add_item(ItemModel.new(false, new_item))
	var in_flat_index = col + row * _cols
	_result.spawns.append([in_flat_index, new_item])

func swap(index_first:int, index_second:int)->bool:
	var col_first = index_first % _cols
	var row_first = index_first / _cols
	
	var col_second = index_second % _cols
	var row_second = index_second / _cols
	
	if absi(col_first - col_second) + absi(row_first - row_second) == 1 \
	and _cells[col_first][row_first].can_move() and _cells[col_second][row_second].can_move():
		_cells[col_first][row_first].swap(_cells[col_second][row_second])
		if _is_match(col_first, row_first) or _is_match(col_second, row_second):
			return true
		else:
			_cells[col_first][row_first].swap(_cells[col_second][row_second])
	return false
	
func _is_match(col:int, row:int)->bool:
	var accum = 1
	var is_match_with_current = false
	for i in range(_cols):
		if i < _cols - 1 and _cells[i][row].get_item_type() > -1 and _cells[i][row].get_item_type() == _cells[i + 1][row].get_item_type():
			accum += 1
			if i == col or i + 1 == col:
				is_match_with_current = true
		else:
			if accum > 2 and is_match_with_current:
				return true
			accum = 1
			
	for i in range(_rows):
		if i < _rows - 1 and _cells[col][i].get_item_type() > -1 and _cells[col][i].get_item_type() == _cells[col][i + 1].get_item_type():
			accum += 1
			if i == row or i + 1 == row:
				is_match_with_current = true
		else:
			if accum > 2 and is_match_with_current:
				return true
			accum = 1
			
	return false
	
func _match():
	var accum = 1
	var removes:Array
	var remove:Array
	
	for col in range(_cols):
		for row in range(_rows):
			if row < _rows - 1 and _cells[col][row].get_item_type() > -1 and _cells[col][row].get_item_type() == _cells[col][row + 1].get_item_type():
				accum += 1
				remove.append([col, row])
			else:
				if accum > 2:
					remove.append([col, row])
					removes.append_array(remove)
				accum = 1
				remove.clear()
	for row in range(_rows):
		for col in range(_cols):
			if col < _cols - 1 and _cells[col][row].get_item_type() > -1 and _cells[col][row].get_item_type() == _cells[col + 1][row].get_item_type():
				accum += 1
				remove.append([col, row])
			else:
				if accum > 2:
					remove.append([col, row])
					removes.append_array(remove)
				accum = 1
				remove.clear()
			
	if not removes.is_empty():
		for cell in removes:
			_cells[cell[0]][cell[1]].remove_item()
	
func update()->UpdateResult:
	_result.clear()
	_match()
	for col in range(_cols - 1, -1, -1):
		# -2  start from last - 1 row and check moving down
		for row in range(_rows - 2, -1, -1):
			# move
			if _cells[col][row].can_move():
				if not _move_if_can(col, row, 0, _result):
					if not _move_if_can(col, row, 1, _result):
						_move_if_can(col, row, -1,  _result)
				continue
					
			# spawn
			if _cells[col][row].can_spawn():
				_spawn(col, row, _result)
				continue
	return _result
