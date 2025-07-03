extends Node

enum GameState { IDLE, PLAY, END }

func remove_item(datalist, filter: Callable):
	var temp_list = []
	for data in datalist:
		if filter.call(data):
			temp_list.append(data)
	return temp_list

func find_item(datalist, id: int):
	for data in datalist:
		if data.id == id:
			return data
	return null

func fix_item(datalist, id, value):
	var temp_list = []
	for data in datalist:
		if data.id == id:
			temp_list.append(value)
		else:
			temp_list.append(data)
	return temp_list
