extends RoomView

func _ready() -> void:
	_ignore_child_input(self)
	floating_pool = $Effects/FloatingTextPool
	resized.connect(_fit_stage)
	_fit_stage()

func present(state: PlayerState) -> void:
	live = state.is_streaming
	reduced_motion = bool(state.settings.get("reduced_motion", false))
	hype = state.hype
	$Stage/LiveChat.text = "● LIVE / CHAT\nкот: готовь!\nМаша: ++\nanon: рецепт?" if live else "OFFLINE / CHAT\nЧат ждёт эфира"
	_set_appearance(state.career_tier)

func _process(delta: float) -> void:
	pulse = maxf(0, pulse - delta * 5)
	sasavot_sprite.scale = _appearance_scale * (1.0 + (pulse * 0.025 if not reduced_motion else 0.0))

func _fit_stage() -> void:
	if not is_instance_valid(_stage) or size.x <= 0 or size.y <= 0:
		return
	var ratio: float = minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	_stage.scale = Vector2.ONE * ratio
	_stage.position = (size - DESIGN_SIZE * ratio) / 2.0
