class_name PayoutCalculator
extends RefCounted

# Mock payout calculator for M4. In production this reads from operator config
# and feeds into the real wallet/ledger. For now it just computes numbers and
# prints them.

const DEFAULT_HOUSE_EDGE := 0.05  # 5%
const DEFAULT_BUY_IN := 1.0       # 1 unit per marble (mock currency)

var house_edge: float
var buy_in_per_marble: float

func _init(edge: float = DEFAULT_HOUSE_EDGE, buy_in: float = DEFAULT_BUY_IN) -> void:
	house_edge = edge
	buy_in_per_marble = buy_in

func calculate(marble_count: int, placements: Array) -> Dictionary:
	var pot := float(marble_count) * buy_in_per_marble
	var house_take := pot * house_edge
	var prize_pool := pot - house_take

	var payouts: Array = []
	if placements.size() >= 1:
		# Winner-takes-all for MVP. Future: top-3 split, etc.
		payouts.append({
			"place": 1,
			"name": placements[0].name if placements.size() > 0 else "?",
			"payout": prize_pool,
		})

	return {
		"marble_count": marble_count,
		"buy_in_per_marble": buy_in_per_marble,
		"pot": pot,
		"house_edge": house_edge,
		"house_take": house_take,
		"prize_pool": prize_pool,
		"payouts": payouts,
	}

func print_results(result: Dictionary) -> void:
	print("--- PAYOUT ---")
	print("  Pot: %.2f (%d marbles × %.2f)" % [result["pot"], result["marble_count"], result["buy_in_per_marble"]])
	print("  House edge: %.1f%% (%.2f)" % [result["house_edge"] * 100, result["house_take"]])
	print("  Prize pool: %.2f" % result["prize_pool"])
	for p in result["payouts"]:
		print("  #%d %s → %.2f" % [p["place"], p["name"], p["payout"]])
