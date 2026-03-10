extends Node2D

@onready var pot_label = %PotLabel
@onready var community_cards = %CommunityCards
@onready var player_area = %PlayerArea
@onready var ai1_area = %AI1Area
@onready var ai2_area = %AI2Area
@onready var action_panel = %ActionPanel
@onready var status_label = %StatusLabel
@onready var fold_button = %FoldButton
@onready var check_button = %CheckButton
@onready var call_button = %CallButton
@onready var raise_button = %RaiseButton
@onready var raise_amount = %RaiseAmount
@onready var new_game_button = %NewGameButton

var game: PokerGame

func _ready():
	randomize()
	setup_game()
	connect_signals()
	action_panel.visible = false

func setup_game():
	game = PokerGame.new()
	game.add_player("You", 1000)
	game.add_player("AI 1", 1000)
	game.add_player("AI 2", 1000)
	game.add_player("AI 3", 1000)
	game.add_player("AI 4", 1000)

func connect_signals():
	game.state_changed.connect(_on_state_changed)
	game.pot_updated.connect(_on_pot_updated)
	game.community_cards_updated.connect(_on_community_cards_updated)
	game.player_turn.connect(_on_player_turn)
	
	fold_button.pressed.connect(_on_fold_pressed)
	check_button.pressed.connect(_on_check_pressed)
	call_button.pressed.connect(_on_call_pressed)
	raise_button.pressed.connect(_on_raise_pressed)
	new_game_button.pressed.connect(_on_new_game_pressed)

func _on_new_game_pressed():
	new_game_button.visible = false
	action_panel.visible = true
	game.start_new_hand()
	update_player_cards()
	update_all_ai_cards()

func _on_state_changed(new_state: PokerGame.GameState):
	match new_state:
		PokerGame.GameState.PRE_FLOP:
			status_label.text = "翻牌前"
		PokerGame.GameState.FLOP:
			status_label.text = "翻牌"
		PokerGame.GameState.TURN:
			status_label.text = "转牌"
		PokerGame.GameState.RIVER:
			status_label.text = "河牌"
		PokerGame.GameState.SHOWDOWN:
			status_label.text = "游戏结束"
			action_panel.visible = false
			new_game_button.visible = true
			show_all_cards()
		PokerGame.GameState.WAITING:
			status_label.text = "点击开始新游戏"
			action_panel.visible = false
			new_game_button.visible = true

func _on_pot_updated(amount: int):
	pot_label.text = "奖池: $%d" % amount

func _on_community_cards_updated(cards: Array[Card]):
	update_community_cards()

func _on_player_turn(player: Player):
	if player.name == "You":
		status_label.text = "你的回合"
		update_action_buttons()
	else:
		status_label.text = "%s 的回合..." % player.name
		action_panel.visible = false
		await get_tree().create_timer(1.0).timeout
		ai_action(player)

func update_action_buttons():
	action_panel.visible = true
	var player = game.get_current_player()
	
	if game.current_bet > player.current_bet:
		check_button.visible = false
		call_button.visible = true
		call_button.text = "跟注 $%d" % (game.current_bet - player.current_bet)
	else:
		check_button.visible = true
		call_button.visible = false
	
	raise_button.visible = player.chips > (game.current_bet - player.current_bet)
	raise_amount.max_value = player.chips
	raise_amount.min_value = game.current_bet + game.last_raise if game.last_raise > 0 else game.current_bet * 2

func _on_fold_pressed():
	game.player_fold()
	clear_player_cards()

func _on_check_pressed():
	game.player_check()

func _on_call_pressed():
	game.player_call()
	update_player_info()

func _on_raise_pressed():
	game.player_raise(int(raise_amount.value))
	update_player_info()

func ai_action(ai_player: Player):
	var hand_strength = evaluate_ai_hand(ai_player)
	var to_call = game.current_bet - ai_player.current_bet
	
	if hand_strength < 0.3 and to_call > ai_player.chips * 0.1:
		game.player_fold()
		clear_ai_cards(ai_player)
	elif hand_strength < 0.5 or to_call == 0:
		if to_call == 0:
			game.player_check()
		else:
			game.player_call()
	else:
		if hand_strength > 0.7 and ai_player.chips > 100:
			game.player_raise(min(ai_player.chips / 4, 100))
		elif to_call == 0:
			game.player_check()
		else:
			game.player_call()
	
	update_ai_info(ai_player)

func evaluate_ai_hand(ai_player: Player) -> float:
	if game.community_cards.is_empty():
		return evaluate_preflop_hand(ai_player.hole_cards)
	else:
		var hand = HandEvaluator.evaluate(ai_player.hole_cards, game.community_cards)
		return float(hand.rank) / 10.0

func evaluate_preflop_hand(cards: Array[Card]) -> float:
	if cards.size() < 2:
		return 0.0
	
	var r1 = int(cards[0].rank)
	var r2 = int(cards[1].rank)
	var suited = cards[0].suit == cards[1].suit
	
	if r1 == r2 and r1 >= 12:
		return 0.9
	if r1 == r2:
		return 0.6 + (r1 - 2) * 0.03
	if suited and (r1 + r2) >= 20:
		return 0.7
	if r1 + r2 >= 22:
		return 0.6
	if r1 + r2 >= 18:
		return 0.4
	return 0.2

func update_player_cards():
	clear_player_cards()
	var cards_container = player_area.get_node("Cards")
	for card in game.players[0].hole_cards:
		cards_container.add_child(create_card_ui(card, false))

func clear_player_cards():
	var cards_container = player_area.get_node("Cards")
	for child in cards_container.get_children():
		child.queue_free()

func update_all_ai_cards():
	for i in range(1, game.players.size()):
		var ai_player = game.players[i]
		var area = get_ai_area(i)
		var cards_container = area.get_node("Cards")
		for child in cards_container.get_children():
			child.queue_free()
		for j in range(2):
			cards_container.add_child(create_card_back_ui())

func clear_ai_cards(ai_player: Player):
	var index = game.players.find(ai_player)
	if index < 0:
		return
	var area = get_ai_area(index)
	var cards_container = area.get_node("Cards")
	for child in cards_container.get_children():
		child.queue_free()

func get_ai_area(index: int) -> Control:
	match index:
		1: return ai1_area
		2: return ai2_area
		3: return get_node("AI3Area")
		4: return get_node("AI4Area")
	return null

func update_community_cards():
	for child in community_cards.get_children():
		child.queue_free()
	for card in game.community_cards:
		community_cards.add_child(create_card_ui(card, false))

func show_all_cards():
	for i in range(1, game.players.size()):
		var ai_player = game.players[i]
		if ai_player.is_active:
			clear_ai_cards(ai_player)
			var area = get_ai_area(i)
			var cards_container = area.get_node("Cards")
			for card in ai_player.hole_cards:
				cards_container.add_child(create_card_ui(card, false))

func update_player_info():
	player_area.get_node("Info").text = "你: $%d" % game.players[0].chips

func update_ai_info(ai_player: Player):
	var index = game.players.find(ai_player)
	if index >= 0:
		var area = get_ai_area(index)
		area.get_node("Info").text = "%s: $%d" % [ai_player.name, ai_player.chips]

func create_card_ui(card: Card, face_down: bool) -> Control:
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(60, 90)
	
	if face_down:
		panel.modulate = Color(0.2, 0.2, 0.4)
	else:
		var label = Label.new()
		label.text = card.to_string()
		label.modulate = card.get_color()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.size = Vector2(60, 90)
		panel.add_child(label)
	
	return panel

func create_card_back_ui() -> Control:
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(60, 90)
	panel.modulate = Color(0.2, 0.2, 0.4)
	return panel
