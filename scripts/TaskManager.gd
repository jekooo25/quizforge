extends Node
## Persistent, local-time Daily and Weekly Tasks.

signal tasks_changed
signal reward_claimed(task_id: String, stars_awarded: int)

const SAVE_PATH := "user://daily_tasks.json"
const DAILY_SCORE_TARGET := 300
const WEEKLY_ACCURACY_TARGET := 50.0
const DAILY_REWARD_STARS := 10
const WEEKLY_REWARD_STARS := 25
const STARS_PER_CORRECT_ANSWER := 1
const STARS_FOR_BATTLE_WIN := 2
const PERIOD_CHECK_SECONDS := 30.0

var _data: Dictionary = {}
var _period_check_elapsed := 0.0


func _ready() -> void:
	_load_state()
	_sync_periods()


func _process(delta: float) -> void:
	_period_check_elapsed += delta
	if _period_check_elapsed >= PERIOD_CHECK_SECONDS:
		_period_check_elapsed = 0.0
		_sync_periods()


## Receives one real answer submission from Battle. Partial battles still count
## the answers the player actually submitted toward weekly accuracy.
func record_answer(is_correct: bool) -> void:
	_sync_periods()
	_data["weekly_total"] = int(_data.get("weekly_total", 0)) + 1
	if is_correct:
		_data["weekly_correct"] = int(_data.get("weekly_correct", 0)) + 1
		if weekly_accuracy_percent() >= WEEKLY_ACCURACY_TARGET:
			_data["weekly_completed"] = true
	_save_state()
	tasks_changed.emit()


## Receives the score for a completed battle only. The Battle screen calculates
## score from correct answers; quitting before completion never emits this.
func record_battle(score: int) -> void:
	_sync_periods()
	if score > int(_data.get("daily_best_score", 0)):
		_data["daily_best_score"] = score
	_save_state()
	tasks_changed.emit()


## Awards a battle result once. The bounded ID list prevents a results scene being
## reopened or emitted twice from duplicating Stars, while keeping saves small.
func award_battle_stars(battle_id: String, amount: int) -> bool:
	if battle_id.is_empty() or amount <= 0:
		return false
	var claimed: Array = _data.get("battle_reward_ids", [])
	if claimed.has(battle_id):
		return false
	var previous_balance := stars_balance()
	claimed.append(battle_id)
	if claimed.size() > 500:
		claimed = claimed.slice(claimed.size() - 500)
	_data["battle_reward_ids"] = claimed
	_data["stars"] = previous_balance + amount
	if not _save_state():
		_data["stars"] = previous_balance
		claimed.erase(battle_id)
		_data["battle_reward_ids"] = claimed
		return false
	tasks_changed.emit()
	return true


func claim_daily_reward() -> bool:
	_sync_periods()
	if not daily_is_complete() or daily_is_claimed():
		return false
	_data["daily_claimed"] = true
	_data["stars"] = stars_balance() + DAILY_REWARD_STARS
	_save_state()
	reward_claimed.emit("daily_high_score", DAILY_REWARD_STARS)
	tasks_changed.emit()
	return true


func claim_weekly_reward() -> bool:
	_sync_periods()
	if not weekly_is_complete() or weekly_is_claimed():
		return false
	_data["weekly_claimed"] = true
	_data["stars"] = stars_balance() + WEEKLY_REWARD_STARS
	_save_state()
	reward_claimed.emit("weekly_accuracy", WEEKLY_REWARD_STARS)
	tasks_changed.emit()
	return true


func daily_best_score() -> int:
	_sync_periods()
	return int(_data.get("daily_best_score", 0))


func daily_is_complete() -> bool:
	return daily_best_score() >= DAILY_SCORE_TARGET


func daily_is_claimed() -> bool:
	_sync_periods()
	return bool(_data.get("daily_claimed", false))


func daily_progress() -> float:
	return minf(float(daily_best_score()), float(DAILY_SCORE_TARGET))


func weekly_correct_count() -> int:
	_sync_periods()
	return int(_data.get("weekly_correct", 0))


func weekly_total_answers() -> int:
	_sync_periods()
	return int(_data.get("weekly_total", 0))


func weekly_accuracy_percent() -> float:
	var total := int(_data.get("weekly_total", 0))
	if total <= 0:
		return 0.0
	return float(_data.get("weekly_correct", 0)) / float(total) * 100.0


func weekly_is_complete() -> bool:
	_sync_periods()
	return bool(_data.get("weekly_completed", false))


func weekly_is_claimed() -> bool:
	_sync_periods()
	return bool(_data.get("weekly_claimed", false))


func stars_balance() -> int:
	return maxi(0, int(_data.get("stars", 0)))


func shop_owned_item_ids() -> Array[String]:
	var result: Array[String] = []
	for item_id in _data.get("shop_owned_items", ["ember_classic"]):
		result.append(str(item_id))
	return result


func equipped_cosmetic_id(slot: String) -> String:
	var equipped: Dictionary = _data.get("equipped_cosmetics", {})
	return str(equipped.get(slot, "ember_classic" if slot == "body_color" else ""))


## Deducts Stars and records ownership in one atomic save operation.
func purchase_shop_item(item_id: String, price: int, slot: String) -> bool:
	if item_id.is_empty() or price < 0:
		return false
	var owned := shop_owned_item_ids()
	if owned.has(item_id) or stars_balance() < price:
		return false
	var previous_balance := stars_balance()
	var previous_equipped: Dictionary = _data.get("equipped_cosmetics", {}).duplicate(true)
	owned.append(item_id)
	_data["shop_owned_items"] = owned
	_data["stars"] = previous_balance - price
	var equipped: Dictionary = _data.get("equipped_cosmetics", {}).duplicate(true)
	equipped[slot] = item_id
	_data["equipped_cosmetics"] = equipped
	if not _save_state():
		_data["stars"] = previous_balance
		_data["shop_owned_items"] = owned.filter(func(owned_id: String) -> bool:
			return owned_id != item_id)
		_data["equipped_cosmetics"] = previous_equipped
		return false
	tasks_changed.emit()
	return true


func equip_shop_item(item_id: String, slot: String) -> bool:
	if not shop_owned_item_ids().has(item_id) or slot.is_empty():
		return false
	var equipped: Dictionary = _data.get("equipped_cosmetics", {}).duplicate(true)
	if str(equipped.get(slot, "")) == item_id:
		return true
	var previous_equipped := equipped.duplicate(true)
	equipped[slot] = item_id
	_data["equipped_cosmetics"] = equipped
	if not _save_state():
		_data["equipped_cosmetics"] = previous_equipped
		return false
	tasks_changed.emit()
	return true


func _load_state() -> void:
	var result := SaveManager.read_json(SAVE_PATH, "daily_tasks")
	if result["ok"] and typeof(result["data"]) == TYPE_DICTIONARY:
		_data = result["data"].duplicate(true)
	else:
		_data = _default_data()

	# Fill fields added by future schema versions or missing from an older save.
	for key in _default_data():
		if not _data.has(key):
			_data[key] = _default_data()[key]
	_data["stars"] = maxi(0, int(_data.get("stars", 0)))
	if typeof(_data["shop_owned_items"]) != TYPE_ARRAY:
		_data["shop_owned_items"] = ["ember_classic"]
	if typeof(_data["equipped_cosmetics"]) != TYPE_DICTIONARY:
		_data["equipped_cosmetics"] = {"body_color": "ember_classic", "accessory": ""}
	if not _data["shop_owned_items"].has("ember_classic"):
		_data["shop_owned_items"].append("ember_classic")


func _default_data() -> Dictionary:
	return {
		"version": int(SaveManager.VERSIONS["daily_tasks"]),
		"daily_date": "",
		"daily_best_score": 0,
		"daily_claimed": false,
		"week_anchor_day": -1,
		"weekly_correct": 0,
		"weekly_total": 0,
		"weekly_completed": false,
		"weekly_claimed": false,
		"stars": 0,
		"battle_reward_ids": [],
		"shop_owned_items": ["ember_classic"],
		"equipped_cosmetics": {"body_color": "ember_classic", "accessory": ""},
	}


func _sync_periods() -> void:
	if _data.is_empty():
		_data = _default_data()
	var changed := false
	var local_date := _local_date_key()
	if str(_data.get("daily_date", "")) != local_date:
		_data["daily_date"] = local_date
		_data["daily_best_score"] = 0
		_data["daily_claimed"] = false
		changed = true

	var current_week_anchor := _current_week_anchor_day()
	if int(_data.get("week_anchor_day", -1)) != current_week_anchor:
		_data["week_anchor_day"] = current_week_anchor
		_data["weekly_correct"] = 0
		_data["weekly_total"] = 0
		_data["weekly_completed"] = false
		_data["weekly_claimed"] = false
		changed = true

	if changed:
		_save_state()


func _local_date_key() -> String:
	var date := Time.get_datetime_dict_from_system(false)
	return "%04d-%02d-%02d" % [int(date["year"]), int(date["month"]), int(date["day"])]


## Returns a civil-day number, then backs up to the Monday of that local week.
## Using a day number avoids year-boundary bugs in week labels.
func _current_week_anchor_day() -> int:
	var date := Time.get_datetime_dict_from_system(false)
	var year := int(date["year"])
	var month := int(date["month"])
	var day := int(date["day"])
	if month <= 2:
		year -= 1
	var era := floori(float(year) / 400.0)
	var year_of_era := year - era * 400
	var adjusted_month := month + (-3 if month > 2 else 9)
	var day_of_year := int((153 * adjusted_month + 2) / 5) + day - 1
	var day_of_era := year_of_era * 365 + int(year_of_era / 4) - int(year_of_era / 100) + day_of_year
	var civil_day := era * 146097 + day_of_era - 719468
	# 1970-01-01 was Thursday; Monday is weekday index zero.
	var monday_index := posmod(civil_day + 3, 7)
	return civil_day - monday_index


func _save_state() -> bool:
	_data["version"] = int(SaveManager.VERSIONS["daily_tasks"])
	_data["saved_at"] = Time.get_datetime_string_from_system(false)
	var saved := SaveManager.write_json(SAVE_PATH, _data, "daily_tasks")
	if not saved:
		push_warning("Daily Tasks progress could not be saved")
	return saved
