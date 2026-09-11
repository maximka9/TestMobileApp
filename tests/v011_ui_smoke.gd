extends SceneTree

func _initialize() -> void:
	assert(SasaUI.DEFAULT_AVATAR != null)
	assert(SasaUI.EVENT_ATLAS != null)
	assert(SasaUI.ACHIEVEMENT_ATLAS != null)
	assert(SasaUI.avatar("creator") != null)
	assert(SasaUI.avatar("") != null)
	assert(SasaUI.avatar("missing_creator") == SasaUI.DEFAULT_AVATAR)
	for creator: String in ["rostikfacekid", "iceicell", "morphe_ya", "dasha228play", "helin139", "korya_mc"]:
		assert(SasaUI.avatar(creator) != SasaUI.DEFAULT_AVATAR)
	assert(SasaUI.event_image("clip") != null)
	assert(SasaUI.event_image("") != null)
	assert(SasaUI.achievement_icon("first_collab") != null)
	var primary := SasaUI.button("Primary", func() -> void: pass, true)
	var danger := SasaUI.button("Danger", func() -> void: pass, false, SasaUI.ButtonVariant.DANGER)
	assert(primary.theme_type_variation == &"AccentButton")
	assert(danger.theme_type_variation == &"DangerButton")
	assert(primary.custom_minimum_size.y >= 48.0)
	primary.free()
	danger.free()
	print("V0.11 UI SMOKE PASS")
	quit()
