extends Node

const Mock: Script = preload("res://scripts/auth/mock_auth.gd")
var _provider: MockAuth

func _ready() -> void:
	_provider = Mock.new()
	add_child(_provider)

func sign_in(identifier: String, password: String) -> void:
	_provider.sign_in(identifier, password)

func sign_up(email: String, password: String, display_name: String) -> void:
	_provider.sign_up(email, password, display_name)

func sign_out() -> void:
	_provider.sign_out()

func request_password_reset(email: String) -> void:
	_provider.request_password_reset(email)
