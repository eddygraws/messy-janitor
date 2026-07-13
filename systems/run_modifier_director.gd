class_name RunModifierDirector
extends Node

signal card_acquired(card: CardData)
signal draft_finished

@export var draft_ui_path: NodePath = ^"../UI/DraftCardUI"
@export var active_strip_path: NodePath = ^"../UI/ActiveCardsStrip"

var _draft_ui: DraftCardUI
var _strip: ActiveCardsStrip
var _pool: Array[CardData] = []
var _owned_ids: Array[String] = []
var _owned_cards: Array[CardData] = []
var _mult_mods: Dictionary = {}
var _add_mods: Dictionary = {}
var _flags: Dictionary = {}


func _ready() -> void:
	_draft_ui = get_node_or_null(draft_ui_path) as DraftCardUI
	_strip = get_node_or_null(active_strip_path) as ActiveCardsStrip
	_pool = CardPool.starter_cards()


func reset_run() -> void:
	_owned_ids.clear()
	_owned_cards.clear()
	_mult_mods.clear()
	_add_mods.clear()
	_flags.clear()
	_refresh_strip()


func is_endless_active() -> bool:
	return not _owned_cards.is_empty()


func get_owned_cards() -> Array[CardData]:
	return _owned_cards.duplicate()


func has_card(card_id: String) -> bool:
	return card_id in _owned_ids


func get_mult(key: StringName, default: float = 1.0) -> float:
	return float(_mult_mods.get(key, default))


func get_add(key: StringName, default: float = 0.0) -> float:
	return float(_add_mods.get(key, default))


func get_flag(key: StringName, default: Variant = null) -> Variant:
	return _flags.get(key, default)


func get_scrub_speed_multiplier(combo: int) -> float:
	var mult := get_mult(&"clean_speed_mult", 1.0)
	var threshold := int(get_flag(&"hot_streak_threshold", 0))
	if threshold > 0 and combo >= threshold:
		mult *= get_mult(&"hot_streak_speed_mult", 1.0)
	return mult


func get_mop_good_clean_ratio(base: float) -> float:
	return clampf(base + get_add(&"mop_good_clean_add", 0.0), 0.0, 1.0)


func present_draft(room_combo: int) -> void:
	if _draft_ui == null:
		return
	var offers := _roll_offers(room_combo)
	if offers.is_empty():
		return
	var picked: CardData = await _draft_ui.present(offers, room_combo)
	if picked != null:
		_acquire(picked)
	draft_finished.emit()


func _roll_offers(room_combo: int) -> Array[CardData]:
	var available: Array[CardData] = []
	for card in _pool:
		if not has_card(card.id):
			available.append(card)
	if available.is_empty():
		return []

	available.shuffle()
	var count := mini(3, available.size())
	var offers: Array[CardData] = []
	for i in count:
		offers.append(available[i])

	# Combo yüksekse bir slotu nadir kart şansına çevir (henüz alınmamış uncommon/rare).
	if room_combo >= 10 and offers.size() >= 2:
		var rare_candidates: Array[CardData] = []
		for card in available:
			if card.rarity >= CardData.Rarity.UNCOMMON and not offers.has(card):
				rare_candidates.append(card)
		if not rare_candidates.is_empty():
			offers[0] = rare_candidates.pick_random()
	return offers


func _acquire(card: CardData) -> void:
	if has_card(card.id):
		return
	_owned_ids.append(card.id)
	_owned_cards.append(card)
	for key in card.mult_mods:
		var k := StringName(key)
		_mult_mods[k] = get_mult(k, 1.0) * float(card.mult_mods[key])
	for key in card.add_mods:
		var k := StringName(key)
		_add_mods[k] = get_add(k, 0.0) + float(card.add_mods[key])
	for key in card.flags:
		_flags[StringName(key)] = card.flags[key]
	card_acquired.emit(card)
	_refresh_strip()


func _refresh_strip() -> void:
	if _strip != null:
		_strip.set_cards(_owned_cards)
