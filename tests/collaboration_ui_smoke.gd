extends "res://tests/typography_smoke.gd"
## Real scene integration, including rapid double presses and persistence before UI delay.

func _run() -> void:
	root.size = Vector2i(540, 960)
	game = (load("res://src/features/stream/scenes/main_game.tscn") as PackedScene).instantiate() as MainGameController
	var repository: FakeSaveRepository = FakeSaveRepository.new()
	(game.get_node("AppBootstrap") as AppBootstrap).repository_override = repository
	root.add_child(game)
	await process_frame
	await process_frame
	game.app.set_process(false)
	game.app.collaborations.random = ScriptedRandomProvider.new([0])
	game.app.collaborations.clock = func() -> int: return 1000
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	game._show_collaborations()
	await _capture("collab_candidates")
	game._show_collab_formats("fixture_01")
	await _capture("collab_formats")
	game._show_collab_offer("fixture_01", "just_chatting")
	await _capture("collab_offer")
	game._send_collab("fixture_01", "just_chatting")
	game._send_collab("fixture_01", "just_chatting")
	_check(game.app.stream.state.completed_collabs == 1, "Rapid UI press resolves once")
	_check(repository.document["player"]["completed_collabs"] == 1, "Outcome saved before presentation delay")
	game._close_modal()
	_check(game.modal_layer.visible and game.modal_close.disabled, "Wait cannot be dismissed during response animation")
	await _capture("collab_wait")
	await create_timer(game.app.config.collab_response_delay + 0.1).timeout
	_check(not game.modal_close.disabled and game.modal_kind == "collab_offer", "Response returns to usable offer screen")
	_check(_buttons_disabled(), "Cooldown disables repeated UI request")
	await _capture("collab_success")
	game._close_modal()
	game.app.collaborations.random = ScriptedRandomProvider.new([999999])
	game._show_collab_offer("fixture_02", "just_chatting")
	await game._send_collab("fixture_02", "just_chatting")
	_check(game.app.stream.state.completed_collabs == 1 and _buttons_disabled(), "Rejection has no reward and disables retry")
	await _capture("collab_rejection")
	game._close_modal()
	game._start_content("just_chatting")
	game._show_collaborations()
	_check(_buttons_disabled(), "Live stream disables collaboration entry actions")
	game.queue_free()
	await process_frame
	print("COLLABORATION UI: %d failures" % failures)
	quit(0 if failures == 0 else 1)
