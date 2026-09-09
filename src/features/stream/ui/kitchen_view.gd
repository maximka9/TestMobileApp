extends RoomView

func _ready() -> void:
	_ignore_child_input(self)
	floating_pool = $Effects/FloatingTextPool
	resized.connect(_fit_stage)
	_fit_stage()
	$Stage/LiveChat.clip_text = true
	$Stage/LiveChat.text = "○ OFFLINE"

func present(state: PlayerState) -> void:
	live = state.is_streaming
	viewers = state.viewers
	chat.advance(0, live, viewers, state.hype)
	reduced_motion = bool(state.settings.get("reduced_motion", false))
	hype = state.hype
	if not live:
		$Stage/LiveChat.text = "○ OFFLINE"
	elif not _shown_live:
		_chat_lines.clear()
		$Stage/LiveChat.text = "● LIVE / CHAT"
	_shown_live = live
	_set_appearance(state.career_tier)

func _process(delta: float) -> void:
	var nickname: String = chat.advance(delta, live, viewers, hype)
	if not nickname.is_empty():
		_chat_lines.append(nickname + ": " + CHAT_MESSAGES[chat_index % CHAT_MESSAGES.size()])
		chat_index += 1
		if _chat_lines.size() > CHAT_LIMIT:
			_chat_lines.remove_at(0)
		$Stage/LiveChat.text = "● LIVE / CHAT\n" + "\n".join(_chat_lines)
	pulse = maxf(0, pulse - delta * 5)
	sasavot_sprite.scale = _appearance_scale * (1.0 + (pulse * 0.025 if not reduced_motion else 0.0))

func _fit_stage() -> void:
	if not is_instance_valid(_stage) or size.x <= 0 or size.y <= 0:
		return
	var ratio: float = minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	_stage.scale = Vector2.ONE * ratio
	_stage.position = (size - DESIGN_SIZE * ratio) / 2.0
