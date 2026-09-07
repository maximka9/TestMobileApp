extends SceneTree
## Runs deliberately invalid composition in a child process. The main test runner
## accepts only the three exact expected diagnostics, never arbitrary errors.
var failed: bool = false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_check_failure(Node.new(), "", "MainGameController parent is required")
	_check_failure(MainGameController.new(), "res://tests/fakes/missing_game_config.tres", "GameConfig resource is missing or could not be loaded")
	_check_failure(MainGameController.new(), "res://tests/fakes/not_game_config.tres", "Config resource must be a GameConfig")
	if not failed:
		print("BOOTSTRAP_FAILURE_SMOKE_PASS: 3 rejected dependencies; processing stopped; no partial services")
	quit(1 if failed else 0)

func _check_failure(parent: Node, path: String, reason: String) -> void:
	var bootstrap: AppBootstrap = AppBootstrap.new()
	var test_logger: FakeLogger = FakeLogger.new()
	var repository: FakeSaveRepository = FakeSaveRepository.new()
	bootstrap.config_path = path
	bootstrap.repository_override = repository
	bootstrap.logger = test_logger
	parent.add_child(bootstrap)
	# Invoke before adding to the tree, keeping controller UI dependencies out of
	# these composition tests; each invalid dependency must stop before tree use.
	bootstrap.set_process(true)
	bootstrap._ready()
	var rejected: bool = not bootstrap.is_processing() and bootstrap.stream == null and bootstrap.queue == null and bootstrap.config == null and repository.calls == 0
	var logged: bool = test_logger.entries.size() == 1
	if logged:
		var entry: Dictionary = test_logger.entries[0]
		logged = entry["severity"] == "ERROR" and entry["category"] == "APP" and entry["event"] == "bootstrap_failed" and entry["context"]["reason"] == reason
	if not rejected or not logged:
		failed = true
		printerr("FAIL: Bootstrap did not reject dependency cleanly: " + reason)
	parent.free()
