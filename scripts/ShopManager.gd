extends Node
## Cosmetic catalogue and operations. Currency and ownership are saved together
## by TaskManager so a successful purchase cannot deduct Stars without owning it.

signal inventory_changed

const CATALOG: Array[Dictionary] = [
	{
		"id": "ember_classic",
		"title": "Classic Emberpup",
		"description": "The original warm orange look.",
		"slot": "body_color",
		"price": 0,
		"color": Color(0.98, 0.55, 0.32),
		"horns": false,
	},
	{
		"id": "ember_azure",
		"title": "Azure Emberpup",
		"description": "A cool blue color variation.",
		"slot": "body_color",
		"price": 35,
		"color": Color(0.28, 0.68, 0.92),
		"horns": false,
	},
	{
		"id": "ember_mint",
		"title": "Mint Emberpup",
		"description": "A fresh mint color variation.",
		"slot": "body_color",
		"price": 35,
		"color": Color(0.30, 0.78, 0.55),
		"horns": false,
	},
	{
		"id": "ember_violet",
		"title": "Violet Emberpup",
		"description": "A bright violet color variation.",
		"slot": "body_color",
		"price": 40,
		"color": Color(0.62, 0.45, 0.88),
		"horns": false,
	},
	{
		"id": "ember_horns",
		"title": "Pixel Horns",
		"description": "A small horn accessory for Emberpup.",
		"slot": "accessory",
		"price": 45,
		"color": Color(0.98, 0.55, 0.32),
		"horns": true,
	},
]


func items() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in CATALOG:
		result.append(item.duplicate())
	return result


func get_item(item_id: String) -> Dictionary:
	for item in CATALOG:
		if str(item["id"]) == item_id:
			return item.duplicate()
	return {}


func is_owned(item_id: String) -> bool:
	return TaskManager.shop_owned_item_ids().has(item_id)


func is_equipped(item_id: String) -> bool:
	var item := get_item(item_id)
	return not item.is_empty() and TaskManager.equipped_cosmetic_id(str(item["slot"])) == item_id


func purchase(item_id: String) -> String:
	var item := get_item(item_id)
	if item.is_empty():
		return "invalid_item"
	if is_owned(item_id):
		return "owned"
	var price := int(item["price"])
	if TaskManager.stars_balance() < price:
		return "insufficient_stars"
	if not TaskManager.purchase_shop_item(item_id, price, str(item["slot"])):
		return "purchase_failed"
	inventory_changed.emit()
	return "purchased"


func equip(item_id: String) -> bool:
	var item := get_item(item_id)
	if item.is_empty() or not is_owned(item_id):
		return false
	var changed := TaskManager.equip_shop_item(item_id, str(item["slot"]))
	if changed:
		inventory_changed.emit()
	return changed


func equipped_body_color() -> Color:
	var item := get_item(TaskManager.equipped_cosmetic_id("body_color"))
	if item.is_empty():
		item = get_item("ember_classic")
	return item["color"]


func has_equipped_horns() -> bool:
	var item := get_item(TaskManager.equipped_cosmetic_id("accessory"))
	return not item.is_empty() and bool(item.get("horns", false))
