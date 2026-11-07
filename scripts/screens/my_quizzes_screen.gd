extends Control
## Quiz library behavior for scenes/my_quizzes.tscn.

const QUIZ_CARD_SCENE: PackedScene = preload("res://scenes/quiz_card.tscn")

@onready var search_box: LineEdit = %SearchBox
@onready var sort_option: OptionButton = %SortOption
@onready var quiz_list: VBoxContainer = %QuizList
@onready var quiz_scroll: ScrollContainer = %QuizScroll
@onready var empty_state_box: VBoxContainer = %EmptyStateBox
@onready var empty_state: Label = %EmptyState
@onready var upload_reviewer_button: Button = %UploadReviewerButton
@onready var main_menu_button: Button = %MainMenuButton
@onready var my_quizzes_pane: VBoxContainer = %MyQuizzesPane
@onready var browse_shared_pane: VBoxContainer = %BrowseSharedPane
@onready var progress_pane: VBoxContainer = %ProgressPane
@onready var my_quizzes_tab: Button = %MyQuizzesTab
@onready var browse_shared_tab: Button = %BrowseSharedTab
@onready var progress_tab: Button = %ProgressTab
@onready var rename_dialog: AcceptDialog = %RenameDialog
@onready var rename_title: LineEdit = %RenameTitle
@onready var delete_dialog: ConfirmationDialog = %DeleteDialog

var all_quizzes: Array = []
@export var initial_tab := "quizzes"
var busy := false
var _tab := "quizzes"
## Shared/public networking is retained for development, but it is not part of
## the offline presentation path. Launch with --show-wip to expose it.
var _show_wip := false
var _pending_rename_id := ""
var _pending_delete_id := ""


func _ready() -> void:
	_show_wip = OS.get_cmdline_user_args().has("--show-wip")
	browse_shared_tab.visible = _show_wip
	%SharedJoin.visible = _show_wip
	if not _show_wip and initial_tab == "browse":
		initial_tab = "quizzes"
	sort_option.add_item("Recent")
	sort_option.add_item("A–Z")
	search_box.text_changed.connect(_on_filter_changed)
	sort_option.item_selected.connect(_on_filter_changed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	upload_reviewer_button.pressed.connect(_on_upload_reviewer_pressed)
	my_quizzes_tab.pressed.connect(show_tab.bind("quizzes"))
	browse_shared_tab.pressed.connect(show_tab.bind("browse"))
	progress_tab.pressed.connect(show_tab.bind("progress"))
	rename_dialog.confirmed.connect(_on_rename_confirmed)
	delete_dialog.confirmed.connect(_on_delete_confirmed)
	%SharedJoin.get_node("%Join").pressed.connect(join_shared)
	%SharedJoin.get_node("%ToggleCode").toggled.connect(toggle_code)
	%SharedJoin.get_node("%Send").visible=not SharingService.state.outbox.is_empty()
	%SharedJoin.get_node("%Public").pressed.connect(func()->void:Nav.show_screen(load("res://scenes/PublicQuizzes.tscn").instantiate()))
	%SharedJoin.get_node("%Send").pressed.connect(send_results)
	_tab=initial_tab
	_refresh_list()
	show_tab(_tab)


func show_tab(tab_name: String) -> void:
	if tab_name not in ["quizzes", "browse", "progress"]:
		return
	_tab = tab_name
	my_quizzes_pane.visible = _tab in ["quizzes","browse"]
	%SharedJoin.visible = _tab == "browse"
	%Heading.text = "Shared Quizzes" if _tab=="browse" else "Progress" if _tab=="progress" else "My Quizzes"
	browse_shared_pane.visible = false
	progress_pane.visible = _tab == "progress"
	_set_tab_style(my_quizzes_tab, _tab == "quizzes")
	_set_tab_style(browse_shared_tab, _tab == "browse")
	_set_tab_style(progress_tab, _tab == "progress")
	_on_filter_changed()


func _set_tab_style(button: Button, active: bool, is_soon := false) -> void:
	if active:
		button.theme_type_variation = &"MyQuizzesActiveTab"
	elif is_soon:
		button.theme_type_variation = &"MyQuizzesSoonTab"
	else:
		button.theme_type_variation = &"MyQuizzesTab"


func _refresh_list() -> void:
	all_quizzes = QuizLibrary.all()
	_on_filter_changed()


func _on_filter_changed(_dummy = null) -> void:
	for child in quiz_list.get_children():
		quiz_list.remove_child(child)
		child.queue_free()

	var search_text := search_box.text.to_lower()
	var filtered: Array = []
	var shelf_count:=0
	for quiz in all_quizzes:
		if QuizLibrary.is_shared(quiz) != (_tab=="browse"):continue
		shelf_count+=1
		if search_text == "" or str(quiz.get("title", "")).to_lower().contains(search_text):
			filtered.append(quiz)

	if sort_option.selected == 1:
		filtered.sort_custom(func(a, b) -> bool:
			return str(a.get("title", "")).to_lower() < str(b.get("title", "")).to_lower())

	var has_no_results := filtered.is_empty()
	empty_state_box.visible = has_no_results
	quiz_scroll.visible = not has_no_results
	upload_reviewer_button.visible = shelf_count==0 and _tab!="browse"
	if has_no_results:
		empty_state.text = "No quizzes yet! Upload a reviewer to make your first quiz." \
			if shelf_count==0 else "No quizzes match your search."
		if _tab=="browse" and shelf_count==0:empty_state.text="No shared quizzes yet. Enter a teacher code or browse Public quizzes above."
		return

	for quiz in filtered:
		_add_quiz_card(quiz)


func _add_quiz_card(quiz: Dictionary) -> void:
	var card: QuizCard = QUIZ_CARD_SCENE.instantiate() as QuizCard
	quiz_list.add_child(card)
	var score := _format_score_line(quiz)
	for review: Dictionary in preload("res://scripts/teacher_reviews.gd").all():
		if review.quiz_id == quiz.id and review.author == str(Nav.user.get("username", "")):
			score += " · Teacher review: " + str(review.status)
	card.setup(quiz, _format_detail_line(quiz), score)
	card.play_requested.connect(_on_play_requested)
	card.action_requested.connect(_on_menu_pressed)


func _format_detail_line(quiz: Dictionary) -> String:
	var detail: String="%d questions" % int(quiz.get("count",0))
	var joined: Dictionary=SharingService.state.joins.get(str(quiz.id),{})
	if joined.get("author","")!="":detail+=" · "+str(joined.author)
	if joined.has("review_version"):detail+=" · v%d" % int(joined.review_version)
	return detail


func _format_score_line(quiz: Dictionary) -> String:
	var score: Variant = quiz.get("last_score", null)
	if score == null or str(score).strip_edges() == "":
		return "Not started"
	return "Last score: %s" % str(score)


func _on_play_requested(quiz_id: String) -> void:
	var picker: Control = load("res://scenes/QuizDetails.tscn").instantiate()
	picker.library_id = quiz_id
	Nav.show_screen(picker)


func _on_menu_pressed(action_id: int, quiz_id: String, current_title: String) -> void:
	if action_id == 4:
		var editor: Control = load("res://scenes/QuizEditor.tscn").instantiate()
		editor.library_id = quiz_id
		Nav.show_screen(editor)
		return
	if action_id == 3:
		var picker: Control=load("res://scenes/ReviewModeSelect.tscn").instantiate()
		picker.library_id=quiz_id
		Nav.show_screen(picker)
		return
	if action_id == 2:
		var reply: Dictionary = await SharingService.submit_quiz(quiz_id)
		if not is_inside_tree(): return
		var notice := AcceptDialog.new()
		notice.dialog_text = str(reply.get("message","This quiz was already submitted. No duplicate was created.")) if reply.get("duplicate",false) else "Submitted to the teacher on the laptop server." if reply.get("ok",false) else str(reply.get("error","Could not submit."))
		add_child(notice)
		notice.popup_centered()
		notice.confirmed.connect(notice.queue_free)
		return
	if action_id == 0:
		_pending_rename_id = quiz_id
		rename_title.text = current_title
		rename_dialog.popup_centered()
	elif action_id == 1:
		_pending_delete_id = quiz_id
		delete_dialog.dialog_text = "Delete this quiz?"
		delete_dialog.popup_centered()


func _on_rename_confirmed() -> void:
	var new_title := rename_title.text.strip_edges()
	if new_title != "":
		QuizLibrary.rename(_pending_rename_id, new_title)
		_refresh_list()


func _on_delete_confirmed() -> void:
	QuizLibrary.remove(_pending_delete_id)
	_refresh_list()


func _on_upload_reviewer_pressed() -> void:
	Nav.show_screen(load("res://scenes/UploadReviewer.tscn").instantiate())


func _on_main_menu_pressed() -> void:
	Nav.show_screen(load("res://scenes/HomeScreen.tscn").instantiate())

func join_shared() -> void:
	if busy:return
	busy=true
	var controls: Control=%SharedJoin
	controls.get_node("%Join").disabled=true
	controls.get_node("%Status").visible=true
	controls.get_node("%Status").text="Joining..."
	var reply: Dictionary=await SharingService.join_quiz(controls.get_node("%Code").text.strip_edges().to_upper())
	busy=false
	if not is_inside_tree():return
	controls.get_node("%Join").disabled=false
	if not reply.get("ok",false):
		controls.get_node("%Status").text=str(reply.get("error","Could not join."))
		return
	controls.get_node("%Code").clear()
	search_box.clear()
	_refresh_list()
	controls.get_node("%Entry").visible=false
	controls.get_node("%ToggleCode").set_pressed_no_signal(false)
	controls.get_node("%Status").text="Added to Shared Quizzes. Open the quiz below to start."
func send_results() -> void:
	if busy:return
	busy=true
	var reply: Dictionary=await SharingService.send_pending()
	busy=false
	if is_inside_tree():
		%SharedJoin.get_node("%Send").visible=not SharingService.state.outbox.is_empty()
		%SharedJoin.get_node("%Status").visible=true
		%SharedJoin.get_node("%Status").text="All saved results sent." if reply.get("ok",false) else str(reply.get("error","Results remain saved."))

func toggle_code(show_entry: bool) -> void:
	%SharedJoin.get_node("%Entry").visible=show_entry
	if show_entry:%SharedJoin.get_node("%Code").grab_focus()
