class_name MockAuth
extends Node

signal completed(ok: bool, message: String, user: Dictionary)

func sign_in(identifier: String, password: String) -> void:
	await get_tree().create_timer(0.25).timeout
	if identifier.strip_edges().is_empty() or password.is_empty():
		completed.emit(false, "Enter your email and password.", {})
		return
	completed.emit(true, "", {"id": "mock-%s" % identifier.to_lower(), "email": identifier})

func sign_up(email: String, password: String, display_name: String) -> void:
	await get_tree().create_timer(0.25).timeout
	if email.strip_edges().is_empty() or password.length() < 8 or display_name.strip_edges().is_empty():
		completed.emit(false, "Use a display name, email, and a password of at least 8 characters.", {})
		return
	completed.emit(true, "Check your inbox to verify your account.", {"id": "mock-%s" % email.to_lower(), "email": email, "display_name": display_name})

func sign_out() -> void:
	completed.emit(true, "", {})

func request_password_reset(email: String) -> void:
	await get_tree().create_timer(0.25).timeout
	completed.emit(true, "If that email exists, a reset link has been sent.", {})
