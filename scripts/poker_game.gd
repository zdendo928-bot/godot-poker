class_name PokerGame
extends RefCounted

enum GameState {
	WAITING,
	PRE_FLOP,
	FLOP,
	TURN,
	RIVER,
	SHOWDOWN
}

var players: Array[Player] = []
var deck: Deck
var community_cards: Array[Card] = []
var pot: int = 0
var current_state: GameState = GameState.WAITING
var current_player_index: int = 0
var dealer_index: int = 0
var small_blind: int = 10
var big_blind: int = 20
var current_bet: int = 0
var last_raise: int = 0

signal state_changed(new_state: GameState)
signal player_turn(player: Player)
signal pot_updated(amount: int)
signal community_cards_updated(cards: Array[Card])

func _init():
	deck = Deck.new()

func add_player(name: String, chips: int = 1000) -> Player:
	var player = Player.new(name, chips)
	players.append(player)
	return player

func start_new_hand():
	deck.reset()
	community_cards.clear()
	pot = 0
	current_bet = 0
	last_raise = 0
	
	for player in players:
		player.reset_hand()
		player.receive_card(deck.draw())
		player.receive_card(deck.draw())
	
	# 下盲注
	var sb_index = (dealer_index + 1) % players.size()
	var bb_index = (dealer_index + 2) % players.size()
	
	pot += players[sb_index].bet(small_blind)
	pot += players[bb_index].bet(big_blind)
	current_bet = big_blind
	
	current_state = GameState.PRE_FLOP
	current_player_index = (bb_index + 1) % players.size()
	
	state_changed.emit(current_state)
	pot_updated.emit(pot)

func get_current_player() -> Player:
	return players[current_player_index]

func next_player():
	current_player_index = (current_player_index + 1) % players.size()
	if players[current_player_index].can_act():
		player_turn.emit(get_current_player())

func player_fold():
	get_current_player().fold()
	next_player()
	check_round_end()

func player_check():
	if current_bet > get_current_player().current_bet:
		return false
	next_player()
	check_round_end()
	return true

func player_call() -> int:
	var player = get_current_player()
	var amount = current_bet - player.current_bet
	var actual_bet = player.bet(amount)
	pot += actual_bet
	pot_updated.emit(pot)
	next_player()
	check_round_end()
	return actual_bet

func player_raise(amount: int) -> int:
	var player = get_current_player()
	var total = current_bet - player.current_bet + amount
	var actual_bet = player.bet(total)
	pot += actual_bet
	current_bet += amount
	last_raise = amount
	pot_updated.emit(pot)
	next_player()
	check_round_end()
	return actual_bet

func check_round_end():
	var active_count = 0
	var last_active: Player = null
	for player in players:
		if player.is_active:
			active_count += 1
			last_active = player
	
	if active_count == 1:
		last_active.chips += pot
		current_state = GameState.WAITING
		state_changed.emit(current_state)
		return
	
	var all_matched = true
	for player in players:
		if player.is_active and not player.is_all_in:
			if player.current_bet != current_bet:
				all_matched = false
				break
	
	if all_matched:
		advance_state()

func advance_state():
	for player in players:
		player.reset_bet()
	current_bet = 0
	
	match current_state:
		GameState.PRE_FLOP:
			for i in range(3):
				community_cards.append(deck.draw())
			current_state = GameState.FLOP
			
		GameState.FLOP:
			community_cards.append(deck.draw())
			current_state = GameState.TURN
			
		GameState.TURN:
			community_cards.append(deck.draw())
			current_state = GameState.RIVER
			
		GameState.RIVER:
			current_state = GameState.SHOWDOWN
			resolve_showdown()
			return
	
	community_cards_updated.emit(community_cards)
	state_changed.emit(current_state)
	
	for i in range(players.size()):
		if players[i].can_act():
			current_player_index = i
			player_turn.emit(get_current_player())
			break

func resolve_showdown():
	var best_hands = {}
	
	for player in players:
		if player.is_active:
			best_hands[player] = HandEvaluator.evaluate(player.hole_cards, community_cards)
	
	var winners: Array[Player] = []
	var best_hand = null
	
	for player in best_hands:
		var hand = best_hands[player]
		if winners.is_empty():
			winners.append(player)
			best_hand = hand
		else:
			var cmp = HandEvaluator.compare_hands(hand, best_hand)
			if cmp > 0:
				winners = [player]
				best_hand = hand
			elif cmp == 0:
				winners.append(player)
	
	var win_amount = pot / winners.size()
	for winner in winners:
		winner.chips += win_amount
	
	current_state = GameState.WAITING
	state_changed.emit(current_state)
