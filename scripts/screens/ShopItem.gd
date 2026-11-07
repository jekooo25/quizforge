extends PanelContainer
## Reusable, visually editable cosmetic card.

signal purchase_requested(item_id: String)
signal equip_requested(item_id: String)

@onready var preview: CreatureSprite = %CreaturePreview
@onready var title_label: Label = %ItemTitle
@onready var description_label: Label = %ItemDescription
@onready var status_label: Label = %ItemStatus
@onready var price_label: Label = %ItemPrice
@onready var action_button: Button = %ActionButton

var _item_id := ""
var _owned := false
var _equipped := false


func _ready() -> void:
	action_button.pressed.connect(_on_action_pressed)


func configure(item: Dictionary, owned: bool, equipped: bool, can_afford: bool) -> void:
	_item_id = str(item.get("id", ""))
	_owned = owned
	_equipped = equipped
	preview.body_color = item.get("color", Color.WHITE)
	preview.horns = bool(item.get("horns", false))
	preview.queue_redraw()
	title_label.text = str(item.get("title", "Cosmetic"))
	description_label.text = str(item.get("description", ""))
	var price := int(item.get("price", 0))
	price_label.text = "FREE" if price == 0 else "%d Stars" % price
	if equipped:
		status_label.theme_type_variation = &"ShopItemStatus"
		status_label.text = "EQUIPPED"
		status_label.visible = true
		action_button.text = "EQUIPPED"
		action_button.disabled = true
	elif owned:
		status_label.theme_type_variation = &"ShopItemStatus"
		status_label.text = "OWNED"
		status_label.visible = true
		action_button.text = "EQUIP"
		action_button.disabled = false
	else:
		status_label.text = "" if can_afford else "NOT ENOUGH STARS"
		status_label.theme_type_variation = &"ShopItemStatus" if can_afford else &"ShopItemWarning"
		status_label.visible = not can_afford
		action_button.text = "BUY"
		action_button.disabled = not can_afford


func _on_action_pressed() -> void:
	if _owned:
		equip_requested.emit(_item_id)
	else:
		purchase_requested.emit(_item_id)
