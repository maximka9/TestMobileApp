extends "res://tests/typography_smoke.gd"

func _run() -> void:
	root.size = Vector2i(540, 960)
	game = (load("res://src/features/stream/scenes/main_game.tscn") as PackedScene).instantiate() as MainGameController
	(game.get_node("AppBootstrap") as AppBootstrap).repository_override = FakeSaveRepository.new()
	root.add_child(game)
	await process_frame
	await process_frame
	game.app.set_process(false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var state: PlayerState = game.app.stream.state
	var bounds: Rect2 = game.room.get_global_rect()
	var position: Vector2 = game.room.sasavot_sprite.position
	state.settings["reduced_motion"] = true
	for tier: int in range(3):
		state.career_tier = tier
		game._refresh()
		var texture: Texture2D = game.room.sasavot_sprite.texture
		if texture is AtlasTexture:
			_check(Rect2(Vector2.ZERO, texture.atlas.get_size()).encloses(texture.region), "Career atlas region within image")
		state.viewers = 99999
		game._refresh()
		_check(game.room.sasavot_sprite.texture == texture, "Instant viewers cannot switch appearance")
		_check(game.room.get_global_rect() == bounds and game.room.sasavot_sprite.position == position, "Appearance preserves hitbox and desk position")
		await _capture("career_tier_%d" % tier)
	state.current_location_id = "kitchen"
	game._refresh()
	_check(game.room.name == "Kitchen" and game.room.sasavot_sprite.texture != null, "Kitchen uses independent scene and career appearance")
	await _capture("career_kitchen")
	state.current_location_id = "streamer_room"
	game._refresh()
	_check(not game.room.get_node("Stage/Aquarium").visible, "Aquarium absent before purchase")
	state.money = 10000
	_check(game.app.room_customization.purchase_item(state, "aquarium").success, "Aquarium purchase succeeds")
	game._refresh()
	_check(game.room.get_node("Stage/Aquarium").visible and game.room.get_node("Stage/Aquarium").z_index > 0, "Purchased aquarium above backdrop")
	await _capture("career_aquarium")
	game._show_interior()
	await _capture("career_interior")
	game._show_achievements()
	await _capture("career_achievements")
	game._close_modal()
	state.followers = 1000000
	state.lifetime_peak_viewers = 50000
	state.completed_collabs = 10
	state.high_tier_collabs = 3
	state.viral_posts = 10
	state.cosplay_streams = 1
	state.stream_history.append({"stream_type": "cooking"})
	state.stream_history.append({"stream_type": "irl"})
	state.owned_room_items = ["aquarium", "neon_light", "dark_wood_wall", "industrial_floor"]
	state.current_home_id = "new_apartment"
	state.reputation = 79
	game.app.achievements.evaluate(state)
	_check(not "slay_king" in state.unlocked_achievements, "SLAY KING requires reputation too")
	state.reputation = 80
	game.app.achievements.evaluate(state)
	_check("slay_king" in state.unlocked_achievements, "SLAY KING reachable with catalog achievements")
	_check(game.app.achievements.evaluate(state).is_empty(), "Achievements never unlock twice")
	game.queue_free()
	await process_frame
	print("CAREER FINAL SMOKE: %d failures" % failures)
	quit(0 if failures == 0 else 1)
