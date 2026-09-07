class_name SasaUI
extends RefCounted
## Small factory for data-driven modal content. All visual styling lives in Theme.
const THEME: Theme = preload("res://resources/themes/sasa_theme.tres")
const TOUCH_TARGET: float = 48.0

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

static func button(text: String, callback: Callable, accent: bool = false) -> Button:
	var node: Button = Button.new()
	node.text = text
	node.custom_minimum_size.y = TOUCH_TARGET
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.theme_type_variation = &"AccentButton" if accent else &"Button"
	node.pressed.connect(callback)
	return node
