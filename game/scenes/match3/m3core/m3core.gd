extends Node

class_name M3Core

# масштаб анимации подсказки (+15%).
const animation_scale:float = 1.15
# длительность изменения масштаба в подсказке(сек).
const hint_time:float = 0.4
# длительность анимации перемещения предметов между клетками(сек).
const move_time:float = 0.2
var _cols = 0
enum EDirect{DOWN, LEFT, RIGHT, TOP, TOP_LEFT, TOP_RIGHT, DOWN_LEFT, DOWN_RIGHT}
# размещаем клетки в матрице 
var _cell_mat:Array
var _rows:int = 0
# возможные комбинации для матча с уже сматченными предметами
var _cells_spawnable:Array
var _cells_auto_movable:Array
var _cells_not_hole:Array

var _items = {
	Item.EItem.RED: preload("res://game/scenes/match3/items/item_red.tscn"),
	Item.EItem.BLUE: preload("res://game/scenes/match3/items/item_blue.tscn"),
	Item.EItem.GREEN: preload("res://game/scenes/match3/items/item_green.tscn"),
	Item.EItem.PURPLE: preload("res://game/scenes/match3/items/item_purple.tscn"),
	Item.EItem.WHITE: preload("res://game/scenes/match3/items/item_white.tscn"),
	Item.EItem.YELLOW: preload("res://game/scenes/match3/items/item_yellow.tscn"),
	
	Item.EItem.ROCKET_LINE_H: preload("res://game/scenes/match3/items/item_rocket_h.tscn"),
	Item.EItem.ROCKET_LINE_V: preload("res://game/scenes/match3/items/item_rocket_v.tscn"),
	Item.EItem.BOMB: preload("res://game/scenes/match3/items/item_bomb.tscn"),
	Item.EItem.AMULET: preload("res://game/scenes/match3/items/item_amulet.tscn"),
	Item.EItem.BOMB_TOTAL: preload("res://game/scenes/match3/items/item_total_bomb.tscn"),
	
	Item.EItem.GLASS: preload("res://game/scenes/match3/items/item_glass.tscn"),
	Item.EItem.CHAIN: preload("res://game/scenes/match3/items/item_chains.tscn")
}

func init_cells(cells:Array, cols:int):
	_cols = cols
	_rows = cells.size() / _cols
	var count = 0
	var tmp:Array[Cell]
	tmp.resize(_rows)
	for i in range(_cols):
		_cell_mat.append(tmp.duplicate())

	for cell in cells:
		# в этом массиве клеток будем создавать новые предметы
		if cell.is_spawn():
			_cells_spawnable.append(cell)
		# по этому массиву можно опрашивать все клетки участвующие в игре
		if not cell.is_hole():
			_cells_not_hole.append(cell)
		cell.x = count % _cols
		cell.y = count / _cols
		count += 1
		_cell_mat[cell.x][cell.y] = cell
		# по клеткам этого массива предметы могут падать, без последней строки под которой дно
		if not cell.is_hole() and cell.y < _rows - 1:
			_cells_auto_movable.append(cell)
		# массив клеток по которому предметы будут падать опрашиваем снизу вверх для избежания двойного перемещения
		_cells_auto_movable.reverse()

func swap(cell_first:Cell, cell_second:Cell)->bool:
	# свап только в пределах соседних валидных клеток
	if absi(cell_first.x - cell_second.x) + absi(cell_first.y - cell_second.y) == 1 \
	and cell_first.can_move() and cell_second.can_move():
		get_tree().call_group("stop_cell_animations", "stop_animations")
		cell_first.swap(cell_second)
		# если один из предметов сматченный - можно считать за новый матч
		if cell_first.is_matched() or cell_second.is_matched():
			_hit([cell_first, cell_second])
			return true
		
		if _is_match(cell_first) or _is_match(cell_second):
			return true
		else:
			cell_first.swap(cell_second)
	return false
	
func _is_valid_col(col:int)->bool:
	return true if col < _cols and col >= 0 else false
	
func _is_valid_row(row:int)->bool:
	return true if row < _rows and row >= 0 else false

func _is_match(cell:Cell)->bool:
	var accum = 0
	var is_match_with_current = false
	
	for x in range(_cols):
		if _is_valid_col(x + 1) and _cell_mat[x][cell.y].is_common() \
		and _cell_mat[x][cell.y].get_item_type() == _cell_mat[x + 1][cell.y].get_item_type():
			accum += 1
			if x == cell.x or x + 1 == cell.x:
				is_match_with_current = true
		else:
			if accum > 1 and is_match_with_current:
				return true
			accum = 0
			is_match_with_current = false
			
	for y in range(_rows):
		if _is_valid_row(y + 1) and _cell_mat[cell.x][y].is_common() \
		and _cell_mat[cell.x][y].get_item_type() == _cell_mat[cell.x][y + 1].get_item_type():
			accum += 1
			if y == cell.y or y + 1 == cell.y:
				is_match_with_current = true
		else:
			if accum > 1 and is_match_with_current:
				return true
			accum = 0
			is_match_with_current = false
			
	return false
		
# проходим по строкам и столбцам в поисках предметов с одинаковым типом идущих подряд.
func _match()->Array:
	# количество подряд встретившихся предметов
	var accum = 0
	# общий список последовательностей предметов
	var removes:Array
	# последовательность предметов которую мы нашли
	var match_arr:Array[Cell]
	
	# проверяем вертикально по столбцам
	for col in range(_cols):
		for row in range(_rows):
			if _is_valid_row(row + 1) and _cell_mat[col][row].is_common() and _cell_mat[col][row + 1].is_common()\
			and _cell_mat[col][row].get_item_type() == _cell_mat[col][row + 1].get_item_type():
				accum += 1
				match_arr.append(_cell_mat[col][row])
			else:
				# добавляем последний найденный предмет в текущую последовательность
				if accum > 1:
					match_arr.append(_cell_mat[col][row])
					removes.append(match_arr.duplicate())
				accum = 0
				match_arr.clear()
	# проверяем горизонтально по строкам
	for row in range(_rows):
		for col in range(_cols):
			if _is_valid_col(col + 1) and _cell_mat[col][row].is_common() \
			and _cell_mat[col][row].get_item_type() == _cell_mat[col + 1][row].get_item_type():
				accum += 1
				match_arr.append(_cell_mat[col][row])
			else:
				if accum > 1:
					match_arr.append(_cell_mat[col][row])
					removes.append(match_arr.duplicate())
				accum = 0
				match_arr.clear()
			
	if not removes.is_empty():
		# найти пересечения(если есть) и слить в один массив по сборкам
		var curr_match = false
		for i in range(0, removes.size()):
			curr_match = false
			if removes[i].is_empty() or i + 1 >= removes.size():
				continue
			for j in range(i + 1, removes.size()):
				if not removes[i].is_empty() and not removes[j].is_empty():
					for cell in removes[i]:
						if removes[j].has(cell):
							removes[j].erase(cell)
							removes[i].append_array(removes[j])
							removes[j].clear()
							curr_match = true
							break
				if curr_match:
					break
	return removes
	
func _move_if_can(cell:Cell, direct:EDirect)->bool:
	if cell.can_move():
		var other_cell = _neighbour_cell(cell, direct) as Cell
		if other_cell and not other_cell.is_hole() and other_cell.is_empty():
			get_tree().call_group("stop_cell_animations", "stop_animations")
			cell.swap(other_cell)
			return true
	return false
	
func _spawn_match_item(src_arr:Array[Cell]):
	# в клетку в которую перемещали предмет записываем дату, сматченный предмет вставляем в клетку с самой поздней датой.
	var cell = _get_last_updated_cell(src_arr)
	if cell:
		var new_type:Item.EItem = Item.EItem.NONE
		# TODO - тут раздаём награды за матчи
		match src_arr.size():
			4:# ROCKET_LINE_V or ROCKET_LINE_H
				new_type = Item.EItem.ROCKET_LINE_V if src_arr[0].x == src_arr[1].x else Item.EItem.ROCKET_LINE_H
			5:# BOMB
				new_type = Item.EItem.BOMB
			6:# AMULET
				new_type = Item.EItem.AMULET
			7:# BOMB_TOTAL
				new_type = Item.EItem.BOMB_TOTAL
		_hit(src_arr)
		cell.spawn(create_item(new_type))
	else:
		print("Erorr. _spawn_match_item(_get_last_updated_cell) is null.")
		
func _hit(cells:Array[Cell]):
	var hit_area:Array[Cell]
	# находим клетки в зоне поражения матчеров
	for i in range(cells.size()):
		# TODO проверяем, если сосед матчер - усиливаем воздействие каждого из матчеров.
		if cells[i].is_matched():
			# амулет подрывает все клетки с предметами некоего типа
			if cells[i].get_item_type() == Item.EItem.AMULET:
				# передали две клетки с амулетом - это свап, определяем тип предмета и получаем зону поражения.
				if cells.size() == 2:
					# амулет стоит первым
					if i == 0:
						hit_area.append_array(_get_hit_area(cells[i], cells[i + 1].get_item_type()))
					else:
						hit_area.append_array(_get_hit_area(cells[i], cells[i - 1].get_item_type()))
				# вероятно амулет попал в зону поражения, подрываем его как вторичный объект со случайным типом обычного предмета
				else:
					hit_area.append_array(_get_hit_area(cells[i], Item.get_next_common()))
			# обычный матчер без специальных условий подрыва
			else:
				hit_area.append_array(_get_hit_area(cells[i]))
	# удаляем предметы в клетках текущего массива попавшего под удар(в аргументе)
	for cell in cells:
		cell.delete_item()
	var second_hit_area:Array[Cell]
	# выбираем из всей области поражения попавшие туда матчеры(не входящие в переданный массив), остальное подрываем.
	for cell in hit_area:
		if cell and cell.is_common():
			cell.delete_item()
		if cell and cell.is_matched():
			second_hit_area.append(cell)
	# рекурсивно обрабатываем вторичные матчеры в зоне поражения.
	if not second_hit_area.is_empty():
		_hit(second_hit_area)
	
func _get_hit_area(cell:Cell, type:Item.EItem = Item.EItem.NONE)->Array[Cell]:
	var result:Array[Cell]
	match cell.get_item_type():
		# подрывает вертикально весь столбец
		Item.EItem.ROCKET_LINE_V:
			for y in range(_rows):
				if _cell_mat[cell.x][y] != cell:
					result.append(_cell_mat[cell.x][y])
		# подрывает горизонтально всю строку
		Item.EItem.ROCKET_LINE_H:
			for x in range(_cols):
				if _cell_mat[x][cell.y] != cell:
					result.append(_cell_mat[x][cell.y])
		# бомба подрывает зону по своему периметру
		Item.EItem.BOMB:
			result.append(_neighbour_cell(cell, EDirect.DOWN))
			result.append(_neighbour_cell(cell, EDirect.LEFT))
			result.append(_neighbour_cell(cell, EDirect.RIGHT))
			result.append(_neighbour_cell(cell, EDirect.TOP))
			result.append(_neighbour_cell(cell, EDirect.TOP_LEFT))
			result.append(_neighbour_cell(cell, EDirect.TOP_RIGHT))
			result.append(_neighbour_cell(cell, EDirect.DOWN_LEFT))
			result.append(_neighbour_cell(cell, EDirect.DOWN_RIGHT))
		# амулет подрывает предметы типа с которым сматчен или рандомным типом при вторичном подрыве
		Item.EItem.AMULET:
			if type != Item.EItem.NONE:
				for _cell in _cells_not_hole:
					if _cell.get_item_type() == type and _cell != cell:
						result.append(_cell)
			else:
				print("Erorr. _get_hit_area, for the item Item.EItem.AMULET type is Item.EItem.NONE.")
		Item.EItem.BOMB_TOTAL:
			result.append_array(_cells_not_hole.duplicate())
			result.erase(cell)

	return result

# на моделях клеток ставим метки времени последнего изменения, это нужно для определения позиции вставки предмета. 
func _get_last_updated_cell(arr:Array[Cell])->Cell:
	var update_time:int = 0
	var cell:Cell = null
	for _cell in arr:
		if _cell.get_last_update() > update_time:
			update_time = _cell.get_last_update()
			cell = _cell
	return cell
		
func worker()->bool:
	# не менять последовательность! создание - перемещение -удаление
	var is_event = false
	
	# создаем предметы в клетках спавна если они пустые(пакетное)
	for cell in _cells_spawnable:
		if cell.can_spawn():
			cell.spawn(create_item(Item.get_next_common()))
			is_event = true
	if is_event:
		return true
	
	# перемещаем предметы между клетками, сначала вниз для создания эффекта падения(пакетное).
	for cell in _cells_auto_movable:
		if _move_if_can(cell, EDirect.DOWN):
			is_event = true
	if is_event:
		return true
		
	# перемещаем предметы влево или вправо вниз(одиночное)
	for cell in _cells_auto_movable:
		if _move_if_can(cell, EDirect.DOWN_LEFT) or _move_if_can(cell, EDirect.DOWN_RIGHT):
			# приоритет падения вниз! Смещение лево-право по одному шагу и опять вниз.
			return true

			
	# удаление последовательностей(пакетное).
	# находим последовательности, они будут в виде списков указателей на модели клеток собранных с пересечениями.
	for arr in _match():
		if not arr.is_empty():
			# подобрать и вставить предмет по типу матча и количеству.
			_spawn_match_item(arr)
			is_event = true
	
					
	return is_event
	
# вернуть соседнюю клетку по указанному направлению
func _neighbour_cell(cell:Cell, direct:EDirect)->Cell:
	if not cell.is_hole():
		match direct:
			EDirect.TOP:
				if _is_valid_row(cell.y - 1):
					return _cell_mat[cell.x][cell.y - 1]
			EDirect.TOP_RIGHT:
				if _is_valid_row(cell.y - 1) and _is_valid_col(cell.x + 1):
					return _cell_mat[cell.x + 1][cell.y - 1]
			EDirect.RIGHT:
				if _is_valid_col(cell.x + 1):
					return _cell_mat[cell.x + 1][cell.y]
			EDirect.DOWN_RIGHT:
				if _is_valid_row(cell.y + 1) and _is_valid_col(cell.x + 1):
					return _cell_mat[cell.x + 1][cell.y + 1]
			EDirect.DOWN:
				if _is_valid_row(cell.y + 1):
					return _cell_mat[cell.x][cell.y + 1]
			EDirect.DOWN_LEFT:
				if _is_valid_row(cell.y + 1) and _is_valid_col(cell.x - 1):
					return _cell_mat[cell.x - 1][cell.y + 1]
			EDirect.LEFT:
				if _is_valid_col(cell.x - 1):
					return _cell_mat[cell.x - 1][cell.y]
			EDirect.TOP_LEFT:
				if _is_valid_row(cell.y - 1) and _is_valid_col(cell.x - 1):
					return _cell_mat[cell.x - 1][cell.y - 1]
	return null
	
# проверить соседнюю клетку с переданной по указанному направлению, на равенство типа.
func _cell_hintable(cell:Cell, direct:EDirect, type = Item.EItem.NONE)->bool:
	if cell:
		# если тип не указан - ищем клетку с типом исходной
		if type == Item.EItem.NONE:
			type = cell.get_item_type()
		var other_cell = _neighbour_cell(cell, direct)
		if other_cell and other_cell.can_move() and other_cell.get_item_type() == type:
			return true
	return false
	
func _find_pair()->Array:
	var accum = 0
	var _pair:Array[Cell]
	var _find:Array
	
	for col in range(_cols):
		for row in range(_rows):
			if row < _rows - 1 and _cell_mat[col][row].can_move() and _cell_mat[col][row].get_item_type() == _cell_mat[col][row + 1].get_item_type():
				accum += 1
				_pair.append(_cell_mat[col][row])
			else:
				if accum == 1:
					_pair.append(_cell_mat[col][row])
					_find.append(_pair.duplicate())
				accum = 0
				_pair.clear()
	for row in range(_rows):
		for col in range(_cols):
			if col < _cols - 1 and _cell_mat[col][row].can_move() and _cell_mat[col][row].get_item_type() == _cell_mat[col + 1][row].get_item_type():
				accum += 1
				_pair.append(_cell_mat[col][row])
			else:
				if accum == 1:
					_pair.append(_cell_mat[col][row])
					_find.append(_pair.duplicate())
				accum = 0
				_pair.clear()
			
	return _find
	
func hint()->Array[Cell]:
	var result:Array[Cell]
	# t - top, r - right...
	# указатель на соседа
	var _t = null; var _r = null; var _d = null; var _l = null
	var _tr = null; var _tl = null; var _dr = null; var _dl = null
	# ищем по диагонали
	for cell in _cells_not_hole:
		if cell.is_empty():
			continue
		_t = _neighbour_cell(cell, EDirect.TOP)
		_r = _neighbour_cell(cell, EDirect.RIGHT)
		_d = _neighbour_cell(cell, EDirect.DOWN)
		_l = _neighbour_cell(cell, EDirect.LEFT)
		
		_tl = _neighbour_cell(cell, EDirect.TOP_LEFT)
		_tr = _neighbour_cell(cell, EDirect.TOP_RIGHT)
		_dl = _neighbour_cell(cell, EDirect.DOWN_LEFT)
		_dr = _neighbour_cell(cell, EDirect.DOWN_RIGHT)
		
		# если предмет сматченный, то его можно использовать с любым незаблокированным соседом
		if cell.is_matched():
			if _t and _t.can_move():
				result.append(cell)
				result.append(_t)
			elif _r and _r.can_move():
				result.append(cell)
				result.append(_r)
			elif _d and _d.can_move():
				result.append(cell)
				result.append(_d)
			elif _l and _l.can_move():
				result.append(cell)
				result.append(_l)
			if not result.is_empty():
				return result
		
		# есть два соседа по диагонали и того же типа
		if _tl and _tr and _t and _tl.get_item_type() == _tr.get_item_type() and _tl.get_item_type() == cell.get_item_type() and _t.can_move():
			result.append(cell)
			result.append(_tl)
			result.append(_tr)
			return result
		if _tr and _dr and _r and _tr.get_item_type() == _dr.get_item_type() and _tr.get_item_type() == cell.get_item_type() and  _r.can_move():
			result.append(cell)
			result.append(_tr)
			result.append(_dr)
			return result
		if _dr and _dl and _d and _dr.get_item_type() == _dl.get_item_type() and _dr.get_item_type() == cell.get_item_type() and _d.can_move():
			result.append(cell)
			result.append(_dr)
			result.append(_dl)
			return result
		if _dl and _tl and _l and _dl.get_item_type() == _tl.get_item_type() and _dl.get_item_type() == cell.get_item_type() and _l.can_move():
			result.append(cell)
			result.append(_dl)
			result.append(_tl)
			return result
			
	# ищем по вертикали и горизонтали
	# все вертикальные и горизонтальные пары
	var pairs = _find_pair()
	for pair in pairs:
		if not pair.is_empty():
			# через одну клетку есть предмет незаблокированный того же типа
			# вертикальная пара
			if pair[0].x == pair[1].x:
				# сосед выше
				_t = _neighbour_cell(pair[0], EDirect.TOP)
				# сосед ниже
				_d = _neighbour_cell(pair[1], EDirect.DOWN)
				# у соседа выше сосед выше такого же типа как пара?
				_tr = _cell_hintable(_t, EDirect.TOP, pair[0].get_item_type()) as bool
				_dl = _cell_hintable(_d, EDirect.DOWN, pair[1].get_item_type()) as bool
				if _tr:
					result.append(pair[0])
					result.append(pair[1])
					result.append(_neighbour_cell(_t, EDirect.TOP))
					return result
				if _dl:
					result.append(pair[0])
					result.append(pair[1])
					result.append(_neighbour_cell(_d, EDirect.DOWN))
					return result
			# горизонтальная пара
			else:
				_l = _neighbour_cell(pair[0], EDirect.LEFT)
				_r = _neighbour_cell(pair[1], EDirect.RIGHT)
				_dl = _cell_hintable(_l, EDirect.LEFT, pair[0].get_item_type()) as bool
				_tr = _cell_hintable(_r, EDirect.RIGHT, pair[1].get_item_type()) as bool
				if _tr:
					result.append(pair[0])
					result.append(pair[1])
					result.append(_neighbour_cell(_r, EDirect.RIGHT))
					return result
				if _dl:
					result.append(pair[0])
					result.append(pair[1])
					result.append(_neighbour_cell(_l, EDirect.LEFT))
					return result

	print("No combinations!")
	return result

# обменять предметы в клетках если они не заблокированы
func shuffle():
	var shuffle_cells:Array[Cell]
	for cell in _cells_not_hole:
		if cell.can_move():
			shuffle_cells.append(cell)
	for cell in shuffle_cells:
		# выбираем рандомно кого с кем поменять
		cell.swap(shuffle_cells[randi_range(0, shuffle_cells.size() - 1)])

func create_item(item_type:Item.EItem)->Item:
	var item:Item = null
	var _scn = _items.get(item_type, null)
	if _scn:
		item = _scn.instantiate()
	return item
