class_name Wallet3D
extends Node

## Kalıcı coin cüzdanı — skor ayrı, upgrade için harcanacak.

signal balance_changed(balance: int)

var _balance: int = 0


func get_balance() -> int:
	return _balance


func set_balance(amount: int) -> void:
	_balance = maxi(0, amount)
	balance_changed.emit(_balance)


func add(amount: int) -> int:
	if amount <= 0:
		return _balance
	_balance += amount
	balance_changed.emit(_balance)
	return _balance


func spend(amount: int) -> bool:
	if amount <= 0:
		return true
	if _balance < amount:
		return false
	_balance -= amount
	balance_changed.emit(_balance)
	return true


func can_afford(amount: int) -> bool:
	return _balance >= maxi(0, amount)
