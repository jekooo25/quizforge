extends Control
## Scene-backed Stars shop; only the repeated ShopItem cards are instanced.

const ITEM_CARD: PackedScene = preload("res://scenes/ShopItem.tscn")
const REWARD_POPUP: PackedScene = preload("res://scenes/RewardPopup.tscn")

@onready var balance_label: Label = %BalanceLabel
@onready var item_list: VBoxContainer = %ItemList
@onready var close_button: Button = %CloseButton
@onready var confirmation_overlay: Control = %ConfirmationOverlay
@onready var confirm_title: Label = %ConfirmTitle
@onready var confirm_text: Label = %ConfirmText
@onready var cancel_button: Button = %CancelButton
@onready var confirm_button: Button = %ConfirmButton

var _pending_item_id := ""


func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	cancel_button.pressed.connect(_cancel_purchase)
	confirm_button.pressed.connect(_confirm_purchase)
	ShopManager.inventory_changed.connect(_refresh)
	TaskManager.tasks_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	balance_label.text = "Stars: %d" % TaskManager.stars_balance()
	for child in item_list.get_children():
		item_list.remove_child(child)
		child.queue_free()
	for item in ShopManager.items():
		var card := ITEM_CARD.instantiate() as Control
		item_list.add_child(card)
		var item_id := str(item["id"])
		card.call("configure", item, ShopManager.is_owned(item_id), ShopManager.is_equipped(item_id),
			TaskManager.stars_balance() >= int(item["price"]))
		card.connect("purchase_requested", _ask_purchase)
		card.connect("equip_requested", _equip_item)


func _ask_purchase(item_id: String) -> void:
	var item := ShopManager.get_item(item_id)
	if item.is_empty():
		_show_notice("SHOP ERROR", "This item is no longer available.")
		return
	if ShopManager.is_owned(item_id):
		_show_notice("ALREADY OWNED", "This cosmetic is already in your collection.")
		return
	if TaskManager.stars_balance() < int(item["price"]):
		_show_notice("NOT ENOUGH STARS", "Earn more Stars from Daily Tasks.")
		return
	_pending_item_id = item_id
	confirm_title.text = "Confirm purchase"
	confirm_text.text = "Spend %d Stars on %s?" % [int(item["price"]), str(item["title"])]
	confirmation_overlay.show()


func _confirm_purchase() -> void:
	if _pending_item_id.is_empty():
		return
	var item := ShopManager.get_item(_pending_item_id)
	var item_id := _pending_item_id
	_pending_item_id = ""
	confirmation_overlay.hide()
	var result := ShopManager.purchase(item_id)
	match result:
		"purchased":
			_show_notice("ITEM UNLOCKED!", "%s is owned and equipped for battle." % str(item["title"]))
		"insufficient_stars":
			_show_notice("NOT ENOUGH STARS", "Earn more Stars from Daily Tasks.")
		"owned":
			_show_notice("ALREADY OWNED", "This cosmetic is already in your collection.")
		_:
			_show_notice("PURCHASE FAILED", "Your Stars were not spent. Please try again.")


func _equip_item(item_id: String) -> void:
	var item := ShopManager.get_item(item_id)
	if item.is_empty() or not ShopManager.equip(item_id):
		_show_notice("EQUIP FAILED", "Unlock this cosmetic before equipping it.")
		return
	_show_notice("EQUIPPED!", "%s will appear on Emberpup in battle." % str(item["title"]))


func _show_notice(title: String, message: String) -> void:
	var popup := REWARD_POPUP.instantiate() as Control
	popup.call("configure_notice", title, message)
	add_child(popup)


func _cancel_purchase() -> void:
	_pending_item_id = ""
	confirmation_overlay.hide()


func _on_close_pressed() -> void:
	Nav.show_screen(load("res://scenes/HomeScreen.tscn").instantiate())
