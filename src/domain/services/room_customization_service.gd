class_name RoomCustomizationService
extends RefCounted

var catalog: ContentCatalog

func _init(content: ContentCatalog) -> void:
	catalog = content

func purchase_item(state: PlayerState, id: String) -> OperationResult:
	var item: RoomItemDefinition = catalog.room_items.get(id) as RoomItemDefinition
	if item == null or id in state.owned_room_items:
		return OperationResult.fail(&"INVALID_ARGUMENT")
	if state.career_tier < item.required_tier or state.money < item.price:
		return OperationResult.fail(&"UNAVAILABLE", "Недостаточно уровня карьеры или монет")
	state.money -= item.price
	state.owned_room_items.append(id)
	return OperationResult.new(true, &"SUCCESS", "Предмет добавлен в интерьер")

func home_availability(state: PlayerState, id: String) -> OperationResult:
	var home: HomeDefinition = catalog.homes.get(id) as HomeDefinition
	if home == null:
		return OperationResult.fail(&"INVALID_ARGUMENT")
	if id in state.owned_homes:
		return OperationResult.new()
	if state.level < home.required_player_level:
		return OperationResult.fail(&"LEVEL_LOCKED", "Нужен УР. %d" % home.required_player_level)
	if state.career_tier < home.required_career_tier:
		return OperationResult.fail(&"UNAVAILABLE", "Нужен тир карьеры %d" % home.required_career_tier)
	if state.money < home.price:
		return OperationResult.fail(&"NOT_ENOUGH_MONEY", "Не хватает монет")
	return OperationResult.new()

func purchase_home(state: PlayerState, id: String) -> OperationResult:
	var available: OperationResult = home_availability(state, id)
	if not available.success:
		return available
	if id not in state.owned_homes:
		state.money -= catalog.homes[id].price
		state.owned_homes.append(id)
	state.current_home_id = id
	return OperationResult.new(true, &"SUCCESS", "Переезд завершён")
