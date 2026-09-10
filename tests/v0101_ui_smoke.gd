extends "res://tests/typography_smoke.gd"

func _run() -> void:
	root.size = Vector2i(540, 960)
	game = load("res://src/features/stream/scenes/main_game.tscn").instantiate()
	game.get_node("AppBootstrap").repository_override = FakeSaveRepository.new()
	root.add_child(game)
	await process_frame
	await process_frame
	game.app.set_process(false)
	var state: PlayerState = game.app.stream.state
	game.app.collaborations.clock = func() -> int: return 1000
	game.app.inbound.clock = func() -> int: return 1000
	state.pending_outbound_collab = {"creator_id": "rostikfacekid", "format": "irl"}
	state.incoming_collab_queue = [{"creator_id": "iceicell", "format": "irl", "created_at": 900, "expires_at": 2000, "accepted": false}]
	game._show_incoming()
	for child: Node in game.modal_body.get_children():
		if child is Button:
			_check(child.disabled == (child.text == "Принять"), "Pending outbound blocks accept, permits decline")
	state.pending_outbound_collab.clear()
	state.incoming_collab_queue[0]["accepted"] = true
	game._show_collaborations()
	for child: Node in game.modal_body.get_children():
		if child is Button and child.text == "Выбрать формат":
			_check(child.disabled, "Accepted inbound disables outbound cards")
		if child is Label:
			_check(not "Стримит:" in child.text, "Snapshot never claims live streaming")
	game._show_collab_offer("rostikfacekid", "irl")
	_check((game.modal_body.get_child(game.modal_body.get_child_count() - 1) as Button).disabled, "Detail action also blocked")
	state.completed_collabs = 1
	state.completed_irl_collab_creator_ids.append("rostikfacekid")
	game._show_achievements()
	_check(not "first_collab" in state.unlocked_achievements and game.achievement_tree.buttons["first_collab"].get_meta("state") == "locked", "Locked domain agrees with tree")
	game.app.queue.cancel()
	game.queue_free()
	await process_frame
	print("V0101 UI SMOKE: %d failures" % failures)
	quit(0 if failures == 0 else 1)
