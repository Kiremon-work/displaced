extends "res://files/Close Panel Button/ClosingPanel.gd"
var click_sound = "sound/menu_btn"

func _ready():
	resources.preload_res(click_sound)
	if resources.is_busy(): yield(resources, "done_work")
#warning-ignore:return_value_discarded
	$VBoxContainer/Save.connect('pressed', $saveloadpanel, 'show')
#warning-ignore:return_value_discarded
#	$VBoxContainer/Load.connect('pressed', $saveloadpanel, 'LoadPanelOpen')
#warning-ignore:return_value_discarded
	$VBoxContainer/Options.connect('pressed', self, 'OptionsOpen')
#warning-ignore:return_value_discarded
	$VBoxContainer/Exit.connect('pressed', self, 'Exit')
	move_child($InputBlock, 0)
	for i in $VBoxContainer.get_children():
		i.connect("pressed", self, "PlayClickSound")
	$saveloadpanel.raise()
	$Options.raise()

func show():
	globals.make_save_screenshot()
	input_handler.map_node.pause_daytime(true)
	.show()
#	if state.CurrentScreen in ['Map', 'Village', 'Scene']: #can it be 'Scene'?
#		$VBoxContainer/Save.disabled = false
#	else:
#		$VBoxContainer/Save.disabled = true

func hide():
	globals.free_save_screenshot()
	input_handler.map_node.pause_daytime(false)
	.hide()

func OptionsOpen():
	$Options.open()

func PlayClickSound():
	input_handler.PlaySound(click_sound)


func Exit():
	input_handler.get_spec_node(input_handler.NODE_CONFIRMPANEL, [self, 'MainMenu', tr('LEAVECONFIRM')])

func MainMenu():
	globals.CurrentScene.queue_free()
	globals.ChangeScene('menu')
	get_parent().queue_free()
