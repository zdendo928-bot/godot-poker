class_name Player
extends RefCounted

var name: String
var chips: int
var hole_cards: Array[Card] = []
var is_active: bool = true
var current_bet: int = 0
var is_all_in: bool = false

func _init(n: String, starting_chips: int = 1000):
	name = n
	chips = starting_chips
	reset_hand()

func reset_hand():
	hole_cards.clear()
	is_active = true
	current_bet = 0
	is_all_in = false

func receive_card(card: Card):
	hole_cards.append(card)

func bet(amount: int) -> int:
	if amount >= chips:
		amount = chips
		is_all_in = true
	chips -= amount
	current_bet += amount
	return amount

func fold():
	is_active = false
	hole_cards.clear()

func reset_bet():
	current_bet = 0

func can_act() -> bool:
	return is_active and not is_all_in and chips > 0
