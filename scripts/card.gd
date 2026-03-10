class_name Card
extends RefCounted

enum Suit { SPADES, HEARTS, CLUBS, DIAMONDS }
enum Rank { TWO = 2, THREE, FOUR, FIVE, SIX, SEVEN, EIGHT, NINE, TEN, JACK, QUEEN, KING, ACE }

var suit: Suit
var rank: Rank

func _init(s: Suit, r: Rank):
	suit = s
	rank = r

func get_suit_string() -> String:
	match suit:
		Suit.SPADES: return "♠"
		Suit.HEARTS: return "♥"
		Suit.CLUBS: return "♣"
		Suit.DIAMONDS: return "♦"
	return "?"

func get_rank_string() -> String:
	match rank:
		Rank.TWO: return "2"
		Rank.THREE: return "3"
		Rank.FOUR: return "4"
		Rank.FIVE: return "5"
		Rank.SIX: return "6"
		Rank.SEVEN: return "7"
		Rank.EIGHT: return "8"
		Rank.NINE: return "9"
		Rank.TEN: return "10"
		Rank.JACK: return "J"
		Rank.QUEEN: return "Q"
		Rank.KING: return "K"
		Rank.ACE: return "A"
	return "?"

func to_string() -> String:
	return get_suit_string() + get_rank_string()

func get_color() -> Color:
	if suit == Suit.HEARTS or suit == Suit.DIAMONDS:
		return Color.RED
	return Color.BLACK

static func compare_rank(a: Card, b: Card) -> int:
	return int(a.rank) - int(b.rank)
