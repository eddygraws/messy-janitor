class_name ScrapCollection3D
extends Node

## Kalıcı lost & found — scrap id listesi.

signal scrap_unlocked(scrap_id: String, is_new: bool)
signal collection_changed(found: int, total: int)

var _found: Dictionary = {} ## id -> true


func has_scrap(scrap_id: String) -> bool:
	return bool(_found.get(scrap_id, false))


func get_found_ids() -> PackedStringArray:
	var ids: PackedStringArray = []
	for k in _found.keys():
		if bool(_found[k]):
			ids.append(String(k))
	ids.sort()
	return ids


func found_count() -> int:
	return get_found_ids().size()


func total_count() -> int:
	return ScrapCatalog.count()


func unlock(scrap_id: String) -> bool:
	if scrap_id.is_empty():
		return false
	var is_new := not has_scrap(scrap_id)
	_found[scrap_id] = true
	scrap_unlocked.emit(scrap_id, is_new)
	collection_changed.emit(found_count(), total_count())
	return is_new


func load_ids(ids: PackedStringArray) -> void:
	_found.clear()
	for id in ids:
		if not String(id).is_empty():
			_found[String(id)] = true
	collection_changed.emit(found_count(), total_count())


func save_ids() -> PackedStringArray:
	return get_found_ids()
