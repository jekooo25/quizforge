extends Node
## Shop integration tests use the actual StarsShop, ShopItem, RewardPopup, and
## battle scenes. Save files are restored before the test process exits.

var failures := 0
var checks := 0
var _previous_task_save := ""
var _previous_quiz_save := ""


func _ready() -> void:
	if FileAccess.file_exists(TaskManager.SAVE_PATH):
		_previous_task_save = FileAccess.get_file_as_string(TaskManager.SAVE_PATH)
	if FileAccess.file_exists(QuizData.SAVE_PATH):
		_previous_quiz_save = FileAccess.get_file_as_string(QuizData.SAVE_PATH)
	TaskManager._data = TaskManager._default_data()
	TaskManager._sync_periods()
	TaskManager._data["stars"] = 80
	TaskManager._save_state()
	var legacy_state := TaskManager._default_data()
	legacy_state["version"] = 1
	legacy_state["stars"] = 80
	legacy_state.erase("shop_owned_items")
	legacy_state.erase("equipped_cosmetics")
	var legacy_file := FileAccess.open(TaskManager.SAVE_PATH, FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify(legacy_state))
	legacy_file.close()
	TaskManager._load_state()
	_check(TaskManager.stars_balance() == 80
		and TaskManager.shop_owned_item_ids().has("ember_classic")
		and TaskManager.equipped_cosmetic_id("body_color") == "ember_classic",
		"version 1 Daily Tasks saves migrate with Stars and the starter cosmetic intact")
	QuizData.save("shop test", QuizData.sample())

	var shop := (load("res://scenes/StarsShop.tscn") as PackedScene).instantiate() as Control
	Nav.show_screen(shop)
	await get_tree().process_frame
	var item_list: VBoxContainer = shop.get_node("%ItemList")
	_check(item_list.get_child_count() == ShopManager.items().size()
		and item_list.get_child_count() == 5, "shop displays only equipable cosmetic items")
	_check(shop.get_node("%BalanceLabel").text == "Stars: 80", "shop uses the Daily Tasks Stars balance")

	var azure_card := item_list.get_child(1) as Control
	var azure_action := azure_card.get_node("%ActionButton") as Button
	azure_action.pressed.emit()
	_check(shop.get_node("%ConfirmationOverlay").visible,
		"Buy opens the editable purchase confirmation panel")
	shop.get_node("%ConfirmButton").pressed.emit()
	await get_tree().process_frame
	_check(TaskManager.stars_balance() == 45 and ShopManager.is_owned("ember_azure"),
		"confirmed purchase deducts the price and saves ownership")
	_check(ShopManager.is_equipped("ember_azure"), "purchased color cosmetic is equipped")
	var popup: Control = shop.get_node_or_null("RewardPopup") as Control
	_check(popup != null and str(popup.get_node("%Title").text) == "ITEM UNLOCKED!",
		"successful purchase shows its success notification")
	if popup != null:
		popup.get_node("%OKButton").pressed.emit()
		await get_tree().create_timer(0.2).timeout

	_check(ShopManager.purchase("ember_azure") == "owned"
		and TaskManager.stars_balance() == 45,
		"duplicate purchases are rejected without charging Stars")
	_check(ShopManager.purchase("ember_horns") == "purchased"
		and TaskManager.stars_balance() == 0,
		"a second valid cosmetic purchase spends the exact remaining balance")
	_check(ShopManager.purchase("ember_mint") == "insufficient_stars"
		and TaskManager.stars_balance() == 0
		and not ShopManager.is_owned("ember_mint"),
		"insufficient Stars cannot buy or unlock an item")
	var mint_card := item_list.get_child(2) as Control
	_check((mint_card.get_node("%ActionButton") as Button).disabled,
		"insufficient Stars disables the card purchase button")
	_check(TaskManager.purchase_shop_item("bad", 1, "body_color") == false,
		"TaskManager refuses a direct overspend")

	TaskManager._load_state()
	_check(TaskManager.stars_balance() == 0
		and ShopManager.is_owned("ember_azure")
		and ShopManager.is_owned("ember_horns")
		and ShopManager.is_equipped("ember_azure"),
		"ownership, equipment, and the balance survive a save reload")
	_check(not TaskManager.purchase_shop_item("ember_mint", 1, "body_color")
		and TaskManager.stars_balance() >= 0,
		"Stars are never allowed to become negative")

	var battle := (load("res://scenes/battle.tscn") as PackedScene).instantiate() as Control
	add_child(battle)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(battle.player.color == ShopManager.equipped_body_color()
		and battle.player.horns, "the real battle creature receives equipped cosmetics")
	_check(battle.player_sprite.body_color == ShopManager.equipped_body_color()
		and battle.player_sprite.horns, "equipped cosmetics render on the battle sprite")
	if battle.has_method("_on_close_pressed"):
		battle.call("_on_close_pressed")
	else:
		battle.queue_free()

	_restore_files()
	if failures == 0:
		print("ALL SHOP CHECKS PASSED (%d)" % checks)
		get_tree().quit(0)
	else:
		printerr("%d SHOP CHECK(S) FAILED (%d ran)" % [failures, checks])
		get_tree().quit(1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("  ok   ", message)
	else:
		failures += 1
		printerr("  FAIL ", message)


func _restore_files() -> void:
	SaveManager.forget(TaskManager.SAVE_PATH)
	if _previous_task_save != "":
		var task_file := FileAccess.open(TaskManager.SAVE_PATH, FileAccess.WRITE)
		if task_file != null:
			task_file.store_string(_previous_task_save)
			task_file.close()
	SaveManager.forget(QuizData.SAVE_PATH)
	if _previous_quiz_save != "":
		var quiz_file := FileAccess.open(QuizData.SAVE_PATH, FileAccess.WRITE)
		if quiz_file != null:
			quiz_file.store_string(_previous_quiz_save)
			quiz_file.close()
