class_name Deck
extends RefCounted

var cards: Array[Card] = []

func _init():
	reset()

func reset():
	cards.clear()
	for s in range(4):
		for r in range(2, 15):
			cards.append(Card.new(s, r))
	shuffle()

func shuffle():
	var n = cards.size()
	for i in range(n - 1, 0, -1):
		var j = randi() % (i + 1)
		var temp = cards[i]
		cards[i] = cards[j]
		cards[j] = temp

func draw() -> Card:
	if cards.is_empty():
		return null
	return cards.pop_back()

func size() -> int:
	return cards.size()
