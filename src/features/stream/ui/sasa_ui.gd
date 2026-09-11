class_name SasaUI
extends RefCounted
## Small factory for data-driven modal content. All visual styling lives in Theme.
const THEME: Theme = preload("res://resources/themes/sasa_theme.tres")
const TOUCH_TARGET: float = 48.0
const DEFAULT_AVATAR: Texture2D = preload("res://assets/ui/avatars/default_streamer.svg")
const COLLAB_AVATAR_SIZE := Vector2(64, 64)
static var avatar_paths: Dictionary = {}
static var avatars_loaded: bool = false
const EVENT_ATLAS: Texture2D = preload("res://assets/ui/events/events_atlas.png")
const ACHIEVEMENT_ATLAS: Texture2D = preload("res://assets/ui/achievements/achievements_atlas.png")
enum ButtonVariant { PRIMARY, SECONDARY, DANGER, GHOST, NAVIGATION, TOGGLE }

static func color(token: StringName) -> Color:
	return THEME.get_color(token, &"SasaTokens")

static func label(text: String, role: StringName = &"body", variation: StringName = &"Label") -> Label:
	var node: Label = Label.new()
	node.text = text
	node.theme_type_variation = variation
	node.add_theme_font_size_override("font_size", THEME.get_font_size(role, &"Typography"))
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

static func button(text: String, callback: Callable, accent: bool = false, variant: ButtonVariant = ButtonVariant.SECONDARY) -> Button:
	var node: Button = Button.new()
	node.text = text
	node.custom_minimum_size.y = TOUCH_TARGET
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if accent:
		variant = ButtonVariant.PRIMARY
	var variations: Array[StringName] = [&"AccentButton", &"Button", &"DangerButton", &"GhostButton", &"NavButton", &"ToggleButton"]
	node.theme_type_variation = variations[variant]
	node.pressed.connect(callback)
	return node

static func atlas_icon(atlas: Texture2D, key: String, columns: int, rows: int) -> AtlasTexture:
	var result := AtlasTexture.new()
	result.atlas = atlas
	var index: int = absi(key.hash()) % (columns * rows)
	var cell := Vector2(atlas.get_width() / float(columns), atlas.get_height() / float(rows))
	result.region = Rect2(Vector2(index % columns, index / columns) * cell, cell)
	return result

static func avatar(key: String) -> Texture2D:
	if not avatars_loaded:
		var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://resources/streamers/avatars.json"))
		if manifest is Dictionary:
			for entry: Dictionary in manifest.get("avatars", []):
				avatar_paths[str(entry.creator_id)] = str(entry.get("path", ""))
		avatars_loaded = true
	var path: String = avatar_paths.get(key, "")
	if not path.is_empty() and ResourceLoader.exists(path, "Texture2D"):
		var texture: Texture2D = load(path) as Texture2D
		if texture != null:
			return texture
	return DEFAULT_AVATAR

static func event_image(key: String) -> Texture2D:
	var texture := AtlasTexture.new()
	texture.atlas = EVENT_ATLAS
	texture.region = Rect2(945, 945, 300, 300)
	return texture

static func achievement_icon(key: String) -> Texture2D:
	var texture := AtlasTexture.new()
	texture.atlas = ACHIEVEMENT_ATLAS
	texture.region = Rect2(1015, 1015, 225, 225)
	return texture

static func image(texture: Texture2D, minimum: Vector2) -> TextureRect:
	var node := TextureRect.new()
	node.texture = texture
	node.custom_minimum_size = minimum
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

static func icon_heading(text: String, texture: Texture2D) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_child(image(texture if texture != null else achievement_icon(""), Vector2(40, 40)))
	var title := label(text, &"heading", &"AccentLabel")
	title.custom_minimum_size = Vector2(180, 32)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	return row
