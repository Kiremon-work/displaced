extends "res://files/Close Panel Button/ClosingPanel.gd"

export(Texture) var autosave_shot

onready var saves_container = $ScrollContainer/GridContainer
var saves_folder :String
var cur_save
var no_save_state = false
var double_click_info = {time = 0, savename = ''}

onready var btn_save = $buttons/save_btn
onready var btn_load = $buttons/load_btn
onready var btn_delete = $delete_btn

func _enter_tree():
	closebuttonoffset = [8,6]

func _ready():
	saves_folder = globals.userfolder + 'saves'
	btn_delete.connect("pressed", self, 'PressDeleteGame')
	btn_save.connect('pressed', self, 'PressSaveGame')
	btn_load.connect('pressed', self, 'PressLoadGame')

func show(no_save = false):
	no_save_state = no_save
	ResetSavePanel()
	.show()

func can_save() ->bool:
	return !no_save_state
	#that stuff seems not work nor needed
#	return state.CurrentScreen in ['Map', 'Village', 'Scene']

static func save_files_sort(a, b) ->bool:
	return a[0] > b[0]

func ResetSavePanel():
	cur_save = null
	btn_delete.disabled = true
	btn_load.disabled = true
	btn_save.disabled = true
	input_handler.ClearContainer(saves_container)
	
	if can_save():
		var newbutton = input_handler.DuplicateContainerTemplate(saves_container)
		newbutton.get_node("name").text = tr("SAVENEWSAVE")
		newbutton.get_node("date").text = ""
		newbutton.get_node("time").text = ""
		newbutton.set_meta("save_name", "")
		newbutton.set_meta("file_name", "")
		newbutton.connect("pressed", self, "on_file_click", [""])
		newbutton.get_node("LineEdit").connect("text_entered", self, 'on_lineedit_enter')
	
	var filereader = File.new()
	var file_list = []
	for i in globals.dir_contents(saves_folder):
		if !i.ends_with('.sav'):
			continue
		var file_unix_time = filereader.get_modified_time(i) + (Time.get_time_zone_from_system().bias * 60)
		file_list.append([file_unix_time,i])
	file_list.sort_custom(self, 'save_files_sort')
	for entry in file_list:
		var file_unix_time = entry[0]
		var file_path = entry[1]
		var newbutton = input_handler.DuplicateContainerTemplate(saves_container)
		var file_time :Dictionary = Time.get_datetime_dict_from_unix_time(file_unix_time)
		var file_name :String = SaveNameTransform(file_path)
		var save_name :String = file_name
		filereader.open(file_path, File.READ)
		var first_line = filereader.get_line()
		filereader.close()
		if first_line.begins_with("name="):
			save_name = first_line.trim_prefix("name=")
		newbutton.get_node("name").text = save_name
		newbutton.set_meta("save_name", save_name)
		newbutton.set_meta("file_name", file_name)
		newbutton.get_node("date").text = "%d/%02d/%02d" % [file_time.day, file_time.month, file_time.year % 100]
		newbutton.get_node("time").text = "%d:%02d" % [file_time.hour, file_time.minute]
		
		if file_name == variables.autosave_name:
			newbutton.get_node("screenshot").texture = autosave_shot
		else:
			var screenshot_file = file_path.replace('.sav', '.png')
			if filereader.file_exists(screenshot_file):
				var screenshot = Image.new()
				screenshot.load(screenshot_file)
				var screenshot_tex = ImageTexture.new()
				screenshot_tex.create_from_image(screenshot)
				newbutton.get_node("screenshot").texture = screenshot_tex
		newbutton.connect("pressed", self, "on_file_click", [file_name])

func on_lineedit_enter(_text):
	PressSaveGame()

func on_file_click(file_name :String):
	var click_time = Time.get_ticks_msec()
	if (click_time - double_click_info.time < 300
			and double_click_info.savename == file_name):
		PressSaveGame()
		return
	
	double_click_info.time = click_time
	double_click_info.savename = file_name
	choose_save(file_name)

func choose_save(file_name :String):
	if cur_save:
		if cur_save.get_meta("file_name") == file_name:
			return
		cur_save.pressed = false
		var editor = cur_save.get_node("LineEdit")
		if editor.visible:
			editor.clear()
			editor.hide()
			cur_save.get_node("name").show()
	for btn in saves_container.get_children():
		if btn.get_meta("file_name") == file_name:
			cur_save = btn
			break
	cur_save.pressed = true
	var is_new_save :bool = file_name.empty()
	var is_auto_save :bool = (file_name == variables.autosave_name)
	btn_delete.disabled = is_new_save
	btn_load.disabled = is_new_save
	btn_save.disabled = !can_save() or is_auto_save

func PressLoadGame():
	input_handler.get_spec_node(input_handler.NODE_CONFIRMPANEL, [self, 'LoadGame', tr("LOADCONFIRM")])

func PressSaveGame():
	if btn_save.disabled: return
	if cur_save.get_meta("save_name").empty():
		var editor = cur_save.get_node("LineEdit")
		if !editor.visible:
			cur_save.get_node("name").hide()
			editor.show()
			editor.grab_focus()
			return
		if editor.text.empty():
			input_handler.get_spec_node(input_handler.NODE_NOTIFICATION, [tr("NOSAVENAMENOTE")])
			return
		var all_chars = editor.get_font("font").get_available_chars()
		for letter in editor.text:
			if !(letter in all_chars):
				input_handler.get_spec_node(input_handler.NODE_NOTIFICATION, [tr("WRONGLETTERNOTE")])
				return
		cur_save.set_meta("save_name", editor.text)
		SaveGame()
	else:
		input_handler.get_spec_node(input_handler.NODE_CONFIRMPANEL, [self, 'SaveGame', tr("OVERWRITECONFIRM")])

func PressDeleteGame():
	input_handler.get_spec_node(input_handler.NODE_CONFIRMPANEL, [self, 'DeleteSave', tr("DELETECONFIRM") % cur_save.get_meta("save_name")])

func DeleteSave():
	var file_name = saves_folder + '/' + cur_save.get_meta("file_name")
	var dir = Directory.new()
	dir.remove(file_name + '.sav')
	if dir.file_exists(file_name + '.png'):
		dir.remove(file_name + '.png')
	ResetSavePanel()

func SaveGame():
	globals.SaveGame(cur_save.get_meta("file_name"), cur_save.get_meta("save_name"))
	hide()
#	ResetSavePanel()

func LoadGame():
	globals.LoadGame(cur_save.get_meta("file_name"))

func SaveNameTransform(path):
	return path.replace(saves_folder + "/","").replace('.sav', '')
