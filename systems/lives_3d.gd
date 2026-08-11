class_name Lives3D
extends Node

## Can: başlangıç 3 · her 100 coin = +1 can · kalp pickup = +1

signal lives_changed(lives: int)
signal life_gained(reason: StringName, lives: int)
signal life_lost(lives: int)
signal coin_progress_changed(progress: int, needed: int)

const START_LIVES := 3
const MAX_LIVES := 6
const COINS_PER_LIFE := 100

var _lives: int = START_LIVES
var _coin_progress: int = 0 ## 0..COINS_PER_LIFE-1


func get_lives() -> int:
	return _lives


func get_coin_progress() -> int:
	return _coin_progress


func get_coins_per_life() -> int:
	return COINS_PER_LIFE


func set_state(lives: int, coin_progress: int = 0) -> void:
	_lives = clampi(lives, 0, MAX_LIVES)
	_coin_progress = clampi(coin_progress, 0, COINS_PER_LIFE - 1)
	lives_changed.emit(_lives)
	coin_progress_changed.emit(_coin_progress, COINS_PER_LIFE)


func add_life(reason: StringName = &"bonus") -> bool:
	if _lives >= MAX_LIVES:
		return false
	_lives += 1
	lives_changed.emit(_lives)
	life_gained.emit(reason, _lives)
	return true


func lose_life() -> bool:
	if _lives <= 0:
		return false
	_lives -= 1
	lives_changed.emit(_lives)
	life_lost.emit(_lives)
	return true


func has_lives() -> bool:
	return _lives > 0


## Cüzdana giren coin'ler — her 100'de +1 can.
func register_coins_earned(amount: int) -> int:
	if amount <= 0:
		return 0
	_coin_progress += amount
	var gained := 0
	while _coin_progress >= COINS_PER_LIFE:
		_coin_progress -= COINS_PER_LIFE
		if add_life(&"coins"):
			gained += 1
		else:
			# Cap'te progress birikmesin — taşanı tutma
			_coin_progress = mini(_coin_progress, COINS_PER_LIFE - 1)
			break
	coin_progress_changed.emit(_coin_progress, COINS_PER_LIFE)
	return gained
