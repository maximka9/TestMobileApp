class_name ResetProgressService
extends RefCounted

func reset(queue: SaveJobQueue) -> OperationResult:
	var fresh: PlayerState = CareerService.new(queue.config).new_player()
	fresh.settings = queue.state.settings.duplicate(true)
	queue.cancel()
	var result: OperationResult = queue.service.save(fresh)
	if not result.success:
		queue.service.logger.write("ERROR", "SAVE", "reset_failed", {"code": result.error_code})
		queue.request_save()
		return result
	queue.state = fresh
	return OperationResult.new(true, &"SUCCESS", "", {"state": fresh})
