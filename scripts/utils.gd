extends Node

enum GameState { IDLE, PLAY, END }
enum EntityState { IDLE, WALK, ATTACK, DEATH } # SNEAK

func count_item(datalist, filter: Callable):
	var count = 0
	for data in datalist:
		if filter.call(data):
			count += 1
	return count

func fix_item(datalist, id, value):
	var temp_list = []
	for data in datalist:
		if data == id:
			temp_list.append(value)
		else:
			temp_list.append(data)
	return temp_list
