class_name ClickHandler
extends RefCounted
## UI entry point for both touch and mouse clicks.
var _stream_service: StreamService

func _init(stream_service: StreamService) -> void:
	_stream_service = stream_service

func handle() -> OperationResult:
	return _stream_service.click()
