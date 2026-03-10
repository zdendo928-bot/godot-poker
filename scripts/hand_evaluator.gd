class_name HandEvaluator
extends RefCounted

enum HandRank {
	HIGH_CARD,
	ONE_PAIR,
	TWO_PAIR,
	THREE_OF_A_KIND,
	STRAIGHT,
	FLUSH,
	FULL_HOUSE,
	FOUR_OF_A_KIND,
	STRAIGHT_FLUSH,
	ROYAL_FLUSH
}

static func evaluate(hole_cards: Array[Card], community_cards: Array[Card]) -> Dictionary:
	var all_cards: Array[Card] = hole_cards.duplicate()
	all_cards.append_array(community_cards)
	
	# 排序，从大到小
	all_cards.sort_custom(func(a, b): return int(b.rank) - int(a.rank))
	
	var is_flush_result = _is_flush(all_cards)
	var flush_cards = is_flush_result[1]
	var is_straight_result = _is_straight(all_cards)
	
	# 检查同花顺
	if is_flush_result[0] and is_straight_result[0]:
		var straight_flush_cards = _is_straight(flush_cards)
		if straight_flush_cards[0]:
			if straight_flush_cards[1][0].rank == Card.Rank.ACE:
				return {"rank": HandRank.ROYAL_FLUSH, "cards": straight_flush_cards[1], "kicker": []}
			return {"rank": HandRank.STRAIGHT_FLUSH, "cards": straight_flush_cards[1], "kicker": []}
	
	# 检查四条
	var quads = _find_of_a_kind(all_cards, 4)
	if quads.size() > 0:
		var kicker = _get_kickers(all_cards, quads, 1)
		return {"rank": HandRank.FOUR_OF_A_KIND, "cards": quads, "kicker": kicker}
	
	# 检查葫芦
	var trips = _find_of_a_kind(all_cards, 3)
	var pairs = _find_of_a_kind(all_cards, 2)
	if trips.size() > 0 and pairs.size() > 0:
		var full_house = trips.slice(0, 3)
		full_house.append_array(pairs.slice(0, 2))
		return {"rank": HandRank.FULL_HOUSE, "cards": full_house, "kicker": []}
	
	# 检查同花
	if is_flush_result[0]:
		return {"rank": HandRank.FLUSH, "cards": flush_cards.slice(0, 5), "kicker": []}
	
	# 检查顺子
	if is_straight_result[0]:
		return {"rank": HandRank.STRAIGHT, "cards": is_straight_result[1], "kicker": []}
	
	# 检查三条
	if trips.size() > 0:
		var kicker = _get_kickers(all_cards, trips, 2)
		return {"rank": HandRank.THREE_OF_A_KIND, "cards": trips, "kicker": kicker}
	
	# 检查两对
	if pairs.size() >= 4:
		var two_pair = pairs.slice(0, 4)
		var kicker = _get_kickers(all_cards, two_pair, 1)
		return {"rank": HandRank.TWO_PAIR, "cards": two_pair, "kicker": kicker}
	
	# 检查一对
	if pairs.size() >= 2:
		var kicker = _get_kickers(all_cards, pairs, 3)
		return {"rank": HandRank.ONE_PAIR, "cards": pairs, "kicker": kicker}
	
	# 高牌
	return {"rank": HandRank.HIGH_CARD, "cards": all_cards.slice(0, 5), "kicker": []}

static func _is_flush(cards: Array[Card]) -> Array:
	var suit_counts = {}
	for card in cards:
		if not suit_counts.has(card.suit):
			suit_counts[card.suit] = []
		suit_counts[card.suit].append(card)
	
	for suit in suit_counts:
		if suit_counts[suit].size() >= 5:
			return [true, suit_counts[suit]]
	return [false, []]

static func _is_straight(cards: Array[Card]) -> Array:
	var unique_cards: Array[Card] = []
	var seen_ranks = {}
	for card in cards:
		if not seen_ranks.has(card.rank):
			seen_ranks[card.rank] = true
			unique_cards.append(card)
	
	# 处理A作为1的特殊情况
	var has_ace = unique_cards.size() > 0 and unique_cards[0].rank == Card.Rank.ACE
	
	for i in range(unique_cards.size() - 4):
		var straight = [unique_cards[i]]
		var prev_rank = int(unique_cards[i].rank)
		
		for j in range(i + 1, unique_cards.size()):
			if int(unique_cards[j].rank) == prev_rank - 1:
				straight.append(unique_cards[j])
				prev_rank = int(unique_cards[j].rank)
				if straight.size() == 5:
					return [true, straight]
			elif int(unique_cards[j].rank) < prev_rank - 1:
				break
	
	# 检查A-2-3-4-5顺子
	if has_ace and unique_cards.size() >= 4:
		var wheel = [unique_cards[0]]  # A
		for i in range(unique_cards.size() - 1, 0, -1):
			if int(unique_cards[i].rank) == 5 - wheel.size() + 1:
				wheel.append(unique_cards[i])
				if wheel.size() == 5:
					return [true, wheel]
	
	return [false, []]

static func _find_of_a_kind(cards: Array[Card], count: int) -> Array[Card]:
	var rank_counts = {}
	for card in cards:
		if not rank_counts.has(card.rank):
			rank_counts[card.rank] = []
		rank_counts[card.rank].append(card)
	
	var result: Array[Card] = []
	for rank in rank_counts:
		if rank_counts[rank].size() >= count:
			result.append_array(rank_counts[rank].slice(0, count))
	
	return result

static func _get_kickers(all_cards: Array[Card], used_cards: Array[Card], count: int) -> Array[Card]:
	var used_set = {}
	for card in used_cards:
		used_set[card] = true
	
	var kickers: Array[Card] = []
	for card in all_cards:
		if not used_set.has(card) and kickers.size() < count:
			kickers.append(card)
	return kickers

static func compare_hands(hand1: Dictionary, hand2: Dictionary) -> int:
	if hand1.rank != hand2.rank:
		return int(hand1.rank) - int(hand2.rank)
	
	# 同等级，比较牌面
	for i in range(min(hand1.cards.size(), hand2.cards.size())):
		var cmp = Card.compare_rank(hand1.cards[i], hand2.cards[i])
		if cmp != 0:
			return cmp
	
	# 比较踢脚
	for i in range(min(hand1.kicker.size(), hand2.kicker.size())):
		var cmp = Card.compare_rank(hand1.kicker[i], hand2.kicker[i])
		if cmp != 0:
			return cmp
	
	return 0

static func get_hand_name(hand: Dictionary) -> String:
	var names = ["高牌", "一对", "两对", "三条", "顺子", "同花", "葫芦", "四条", "同花顺", "皇家同花顺"]
	return names[hand.rank]
