extends Node

#This script handles inputs, sounds, closes windows and plays animation

#warning-ignore-all:unused_signal
var CloseableWindowsArray = []
var ShakingNodes = []

var BeingAnimated = []
var SystemMessageNode



signal ScreenChanged
signal BuildingEntered
signal LocationEntered
signal ItemObtained
signal MaterialObtained
signal ExplorationStarted
signal CombatStarted
signal CombatEnded
signal WorkerAssigned
signal SpeedChanged
signal UpgradeUnlocked
signal QuestStarted
signal QuestCompleted
signal Midday

signal PositionChanged

signal RMB_pressed
signal RMB_released

var connect_queue = []

#===those should be set with set_handler_node()
var map_node
var village_node
var explore_node
var combat_node
var scene_node
var menu_node
#===========

var curtains

var rmb_state = false

var musicfading = false
var musicraising = false
const musicfade_speed_default = 50
var musicfade_speed = musicfade_speed_default
const musicraise_speed_default = 100
var musicraise_speed = musicraise_speed_default
var setting_music
var screen_blocked = false

func _input(event):
	if event.is_action_pressed("RMB") and !rmb_state:
		emit_signal("RMB_pressed")
		rmb_state = true
	if event.is_action_released("RMB"):# and rmb_state:
		emit_signal("RMB_released")
		rmb_state = false
	if event.is_echo() == true || event.is_pressed() == false :
		return
	if event.is_action_pressed("ESC") && !screen_blocked:
		if !CloseableWindowsArray.empty():
			if CloseTopWindow():
				get_tree().set_input_as_handled()
		else:
			if input_handler.menu_node and input_handler.menu_node.visible:
				input_handler.menu_node.openmenu()
				get_tree().set_input_as_handled()
	if event.is_action("F9") && event.is_pressed():
		OS.window_fullscreen = !OS.window_fullscreen
		globals.globalsettings.fullscreen = OS.window_fullscreen
		if globals.globalsettings.fullscreen == false:
			OS.window_position = Vector2(0,0)
		get_tree().set_input_as_handled()
	
	
#	if CurrentScreen == 'Town' && str(event.as_text().replace("Kp ",'')) in str(range(1,9)) && CloseableWindowsArray.size() == 0:
#		if str(int(event.as_text())) in str(range(1,4)):
#			globals.CurrentScene.changespeed(globals.CurrentScene.timebuttons[int(event.as_text())-1])

func _process(delta):
	#that stuff was bad. It's endlessly trys to hide non-ClosingPanel.gd nodes
	#keeping this here for a while, if some crutch would fall. Delete in time
#	for i in CloseableWindowsArray:
#		if i.is_visible_in_tree() == false:
#			i.hide()
	for i in ShakingNodes:
		if i.time > 0:
			i.time -= delta
			i.node.rect_position = i.originpos + Vector2(rand_range(-1.0,1.0)*i.magnitude, rand_range(-1.0,1.0)*i.magnitude)
		else:
			i.node.rect_position = i.originpos
			ShakingNodes.erase(i)
	soundcooldown -= delta

	ProcessMusic(delta)





func CloseTopWindow() ->bool:#true if closed
	var node = CloseableWindowsArray.back()
	if node.has_method("can_hide") and !node.can_hide() :
		return false
	CloseableWindowsArray.pop_back()
	node.hide()#node can try to reg_close(), but that's no problem while reg_open() restricts doubles
	return true

#not in use
#func LockOpenWindow():
#	CloseableWindowsArray.append('lock')
#func UnlockOpenWindow():
#	var node = CloseableWindowsArray.back()
#	if typeof(node) == TYPE_STRING:
#		CloseableWindowsArray.pop_back();

func reg_close(node):
	#mind that reg_open() should restrict doubles
	CloseableWindowsArray.erase(node)

func reg_open(node) ->bool:#true on success
	if CloseableWindowsArray.has(node):
		return false
	CloseableWindowsArray.append(node)
	return true

func clear_closeable_windows():
	CloseableWindowsArray.clear()

func GetItemTooltip():
	var tooltipnode
	var node = get_tree().get_root()
	if node.has_node('itemtooltip'):
		tooltipnode = node.get_node('itemtooltip')
		node.remove_child(tooltipnode)
	else:
		tooltipnode = load("res://files/Simple Tooltip/Itemtooltip.tscn").instance()
		tooltipnode.name = 'itemtooltip'
	node.add_child(tooltipnode)
	return tooltipnode

func GetSkillTooltip():
	var tooltipnode
	var node = get_tree().get_root()
	if node.has_node('skilltooltip'):
		tooltipnode = node.get_node('skilltooltip')
		node.remove_child(tooltipnode)
	else:
		tooltipnode = load("res://files/scenes/SkillToolTip.tscn").instance()
		tooltipnode.name = 'skilltooltip'
	node.add_child(tooltipnode)
	return tooltipnode

#----------separate tween mechanics to singleton--------
func GetTweenNode(node):
	#new variant with SceneTreeTween can't add new tweeners on play
#	if !node.has_meta("tween") or !node.get_meta("tween").is_valid():
#		node.set_meta("tween", node.create_tween())
#	return node.get_meta("tween")
	#old variant with Tween node. As of Godot v3.5.2 Tween node has a bug with tweeners processing.
	#so the new variant above goes through SceneTreeTween with more direct control over tweeners
	var tweennode
	if node.has_node('tween'):
		tweennode = node.get_node('tween')
	else:
		tweennode = Tween.new()
		tweennode.name = 'tween'
		node.add_child(tweennode)
	return tweennode

func force_end_tweens(node):
	var tween = GetTweenNode(node)
	#new variant
#	tween.kill()
#	node.remove_meta("tween")
	#old variant with Tween node
	tween.stop_all()
#	tween.remove_all()

func tween_property(node :Node, property :String, from_val, to_val, transition :float, delay :float = 0, trans_type = Tween.TRANS_LINEAR, ease_type = Tween.EASE_IN_OUT):
	var tween = GetTweenNode(node)
	tween_property_with(tween, node, property, from_val, to_val, transition, delay, trans_type, ease_type)

func tween_property_with(tween, node :Node, property :String, from_val, to_val, transition :float, delay :float = 0, trans_type = Tween.TRANS_LINEAR, ease_type = Tween.EASE_IN_OUT):
	#in new variant tween is a SceneTreeTween
#	var tweener = tween.tween_property(node, property, to_val, transition)
#	tweener.from(from_val)
#	tweener.set_delay(delay)
#	tweener.set_trans(trans_type)
#	tweener.set_ease(ease_type)
	#in old variant tween is a Tween node
	tween.interpolate_property(node, property, from_val, to_val, transition, trans_type, ease_type, delay)
	tween.start()

func tween_callback(node :Node, method :String, delay :float = 0, binds: Array = []):
	var tween = GetTweenNode(node)
	tween_callback_with(tween, node, method, delay, binds)

func tween_callback_with(tween, node :Node, method :String, delay :float = 0, binds: Array = []):
	#in new variant tween is a SceneTreeTween
#	var tweener = tween.tween_callback(node, method, binds)
#	tweener.set_delay(delay)
	#in old variant tween is a Tween node
	if binds.size() == 0:
		tween.interpolate_callback(node, delay, method)
	elif binds.size() == 1:
		tween.interpolate_callback(node, delay, method, binds[0])
	elif binds.size() == 2:
		tween.interpolate_callback(node, delay, method, binds[0], binds[1])
	assert(binds.size() < 3, "too much binds for this version")
	tween.start()

func get_tween_finish_signal() ->String:
	#new variant with SceneTreeTween
#	return "finished"
	#old variant with Tween node
	return "tween_all_completed"

func is_tween_active(tween) ->bool:
	#new variant with SceneTreeTween
#	return tween.is_running()
	#old variant with Tween node
	return tween.is_active()
#------------------------------------------



#seems not in use
#func GetRepeatTweenNode(node):
#	var pos = node.rect_position
#	var tweennode
#	if node.has_node('repeatingtween'):
#		tweennode = node.get_node("repeatingtween")
#		tweennode.repeat = true
#	else:
#		tweennode = Tween.new()
#		tweennode.repeat = true
#		tweennode.name = 'repeatingtween'
#		node.add_child(tweennode)
#	return tweennode

#seems not in use
#func SelectionGlow(node):
#	var tween = GetRepeatTweenNode(node)
#	tween.interpolate_property(node, 'modulate', Color(1,1,1,1), Color(1,0.5,1,1), 1, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
#	tween.interpolate_property(node, 'modulate', Color(1,0.5,1,1), Color(1,1,1,1), 1, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT,1)
#	tween.start()

#seems not in use
#func TargetGlow(node):
#	var tween = GetRepeatTweenNode(node)
#	tween.interpolate_property(node, 'modulate', Color(1,1,1,1), Color(1,0.8,0.3,1), 1, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
#	tween.interpolate_property(node, 'modulate', Color(1,0.8,0.3,1), Color(1,1,1,1), 1, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT,1)
#	tween.start()

#seems not in use
#func TargetSupport(node):
#	var tween = GetRepeatTweenNode(node)
#	tween.interpolate_property(node, 'modulate', Color(1,1,1,1), Color(0.5,1,0.5,1), 1, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
#	tween.interpolate_property(node, 'modulate', Color(0.5,1,0.5,1), Color(1,1,1,1), 1, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT,1)
#	tween.start()

#seems not in use
#func TargetEnemyTurn(node):
#	var tween = GetRepeatTweenNode(node)
#	tween.interpolate_property(node, 'rect_scale', Vector2(1,1), Vector2(1.05,1.05), 0.5, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
#	tween.interpolate_property(node, 'rect_scale', Vector2(1.05,1.05), Vector2(1,1), 0.5, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT,0.5)
#	tween.start()

var floatfont = preload("res://assets/fonts/mainfont_float.tres")

func FloatTextArgs(args):
	#print('ftchecked')
	FloatText(args.node, args.text, args.type, args.size, args.color, args.time, args.fadetime, args.offset)

func FloatDmgArgs(args):
	FloatDmg(args.node, args.args, args.time, args.fadetime, args.offset)


func FloatHealArgs(args):
	FloatHeal(args.node, args.args, args.time, args.fadetime, args.offset)

func FloatText(node, text, type = '', size = 80, color = Color(1,1,1), time = 3, fadetime = 0.5, positionoffset = Vector2(0,0)):
	var textnode = Label.new()
	get_tree().get_root().add_child(textnode)
	textnode.text = text
	textnode.rect_global_position = node.rect_global_position + node.rect_size * 0.5  + positionoffset 
	textnode.set("custom_colors/font_color", color)
	textnode.set("custom_colors/font_color_shadow", Color(0,0,0))
	floatfont.size = 50
	textnode.set("custom_fonts/font", floatfont)
	match type:
		'damageenemy':
			DamageTextFly(textnode, false)
		'damageally':
			DamageTextFly(textnode, true)
		'miss':
			FadeAnimation(textnode, fadetime, time)
		"heal":
			HealTextFly(textnode)
	#FadeAnimation(textnode, fadetime, time)
	var wr = weakref(textnode)
	yield(get_tree().create_timer(time+1), 'timeout')
	if wr.get_ref(): textnode.queue_free()


func FloatDmg(node, args, time = 3, fadetime = 0.5, positionoffset = Vector2(50,0)): #critical, group, type, damage = {}
	if args.type == 'pure':
		args.type = 'pierce'
	var floatnode = HBoxContainer.new()
	var size = 50
	var color1 = Color(0.8,0.2,0.2)
	var color2 = Color(0.6,0.6,0.6)
	var color3 = Color(1, 0.8, 0)
	
	var textnode = Label.new()
	textnode.set("custom_colors/font_color", color1)
	textnode.set("custom_colors/font_color_shadow", Color(0,0,0))
	floatfont.size = size
	textnode.set("custom_fonts/font", floatfont)
	
	var textnode2 = textnode.duplicate()
	textnode2.set("custom_colors/font_color", color2)
	
	var heigh = 48 #2test
	
	if args.damage.hp > 0:
		var text = str(ceil(args.damage.hp))
		if args.critical: 
			text += "!"
			textnode.set("custom_colors/font_color", color3)
		textnode.text = text
#		var iconnode = TextureRect.new()
#		iconnode.rect_size.x = heigh
#		iconnode.rect_size.y = heigh
#		iconnode.rect_min_size = iconnode.rect_size
#		iconnode.expand = true
#		iconnode.texture = load("res://assets/images/iconsskills/source_%s.png" % args.type)
#		floatnode.add_child(iconnode)
		floatnode.add_child(textnode)
		if args.damage.shield > 0:
			var text2 = str(ceil(args.damage.shield))
			if args.critical: 
				text2 += "!"
			textnode2.text = text2
			var iconnode2 = TextureRect.new()
			iconnode2.rect_size.x = heigh
			iconnode2.rect_size.y = heigh
			iconnode2.rect_min_size = iconnode2.rect_size
			iconnode2.expand = true
			iconnode2.texture = load("res://assets/images/iconsskills/shield.png")
			floatnode.add_child(iconnode2)
			floatnode.add_child(textnode2)
	elif args.damage.shield > 0:
		var text2 = str(ceil(args.damage.shield))
		if args.critical: 
			text2 += "!"
		textnode2.text = text2
		var iconnode2 = TextureRect.new()
		iconnode2.rect_size.x = heigh
		iconnode2.rect_size.y = heigh
		iconnode2.rect_min_size = iconnode2.rect_size
		iconnode2.expand = true
		iconnode2.texture = load("res://assets/images/iconsskills/shield.png")
		floatnode.add_child(iconnode2)
		floatnode.add_child(textnode2)
	else:
		var text = "0"
		if args.critical: 
			text += "!"
			textnode.set("custom_colors/font_color", color3)
		textnode.text = text
#		var iconnode = TextureRect.new()
#		iconnode.rect_size.x = heigh
#		iconnode.rect_size.y = heigh
#		iconnode.rect_min_size = iconnode.rect_size
#		iconnode.expand = true
#		iconnode.texture = load("res://assets/images/iconsskills/source_%s.png" % args.type)
#		floatnode.add_child(iconnode)
		floatnode.add_child(textnode)
	
	get_tree().get_root().add_child(floatnode)
	floatnode.rect_global_position = node.rect_global_position + node.rect_size * 0.5  + positionoffset 
	if args.group == 'ally':
		DamageTextFly(floatnode, false)
	elif args.group == 'enemy':
		DamageTextFly(floatnode, true)
	var wr = weakref(floatnode)
	gfx_sprite(node, "src_%s" % args.type, 0.5, null, (args.group == 'ally'))
	yield(get_tree().create_timer(time + 1), 'timeout')
	if wr.get_ref(): floatnode.queue_free()


func FloatHeal(node, args, time = 3, fadetime = 0.5, positionoffset = Vector2(0,0)): #critical, group, heal
	#heal spells can't crit, but negeative damage still can
	#group arg is not required here
	var text = str(ceil(args.heal))
	var size = 50
	var color = Color(0.2,0.8,0.2)
	if args.critical: 
		text += "!"
		#add size and color change if required
	var textnode = Label.new()
	get_tree().get_root().add_child(textnode)
	textnode.text = text
	textnode.rect_global_position = node.rect_global_position + node.rect_size * 0.5  + positionoffset 
	textnode.set("custom_colors/font_color", color)
	textnode.set("custom_colors/font_color_shadow", Color(0,0,0))
	floatfont.size = size
	textnode.set("custom_fonts/font", floatfont)
	HealTextFly(textnode)
	var wr = weakref(textnode)
	yield(get_tree().create_timer(time + 1), 'timeout')
	if wr.get_ref(): textnode.queue_free()


func DamageTextFly(node, reverse = false):
	var firstvector = Vector2(-30, -200)
	var secondvector = Vector2(200, 200)
	if reverse == true:
		firstvector = Vector2(30, -200)
		secondvector = Vector2(-200, 200)
	
	#yield(get_tree().create_timer(0.5), 'timeout')
	tween_property(node, 'rect_position', node.rect_position, node.rect_position+firstvector, 1.7, 0, Tween.TRANS_SINE)
	#tween.interpolate_property(node, 'rect_position', node.rect_position+firstvector, node.rect_position+secondvector, 0.5, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT, 0.3)
	FadeAnimation(node, 0.4 , 0.9)

func HealTextFly(node):
	var firstvector = Vector2(0, -150)
	tween_property(node, 'rect_position', node.rect_position, node.rect_position+firstvector, 1, 0.5)
	FadeAnimation(node, 0.2, 1)

#seems not in use
#func StopTweenRepeat(node):
#	var tween = GetRepeatTweenNode(node)
#	tween.seek(0)
#	tween.set_active(false)
#	tween.remove_all()

#Music
#var prevtheme = ""
func SetMusic(res, raise_speed = musicraise_speed_default, fade_speed = musicfade_speed_default):
	if typeof(res) == TYPE_STRING:
		res = resources.get_res("music/%s" % res)
	var musicnode = get_spec_node(NODE_MUSIC)
	if res == null:
		if musicnode.is_playing():
			MusicFade(fade_speed)
		return
	elif musicnode.stream == res and musicnode.is_playing() :
		return
	setting_music = res
	musicraise_speed = raise_speed
	MusicFade(fade_speed)

func on_music_fade():
	if setting_music == null:
		return
	var musicnode = get_spec_node(NODE_MUSIC)
#	prevtheme = musicnode.stream
	musicnode.stream = setting_music
	musicnode.play(0)
	MusicRaise(musicraise_speed)
	setting_music = null

func StopMusic(fade_speed = musicfade_speed_default):
	setting_music = null
	MusicFade(fade_speed)

#not used for now. Delete with time
#func RevertMusic():
#	if prevtheme != null:
#		SetMusic(prevtheme)

func MusicFade(speed = musicfade_speed_default):
	musicraising = false
	musicfading = true
	musicfade_speed = speed

func MusicRaise(speed = musicraise_speed_default):
	musicfading = false
	musicraising = true
	musicraise_speed = speed

func ProcessMusic(delta):
	if musicfading:
		AudioServer.set_bus_volume_db(1, AudioServer.get_bus_volume_db(1) - delta*musicfade_speed)
		if AudioServer.get_bus_volume_db(1) <= -80:
			musicfading = false
			get_spec_node(NODE_MUSIC).stop()
			on_music_fade()
	elif musicraising:
		AudioServer.set_bus_volume_db(1, AudioServer.get_bus_volume_db(1) + delta*musicraise_speed)
		if AudioServer.get_bus_volume_db(1) >= globals.globalsettings.musicvol:
			AudioServer.set_bus_volume_db(1, globals.globalsettings.musicvol)
			musicraising = false

#Sounds

func PlaySound(res, delay = 0):
	var true_res
	if res is String:
		true_res = resources.get_res(res)
	else:
		true_res = res
	if true_res == null:
		return
	yield(get_tree().create_timer(delay), 'timeout')
	var soundnode = get_spec_node(NODE_SOUND)#GetSoundNode()
	soundnode.stream = true_res
	soundnode.seek(0)
	soundnode.play(0)
	yield(soundnode, 'finished')
	soundnode.queue_free()

var soundcooldown = 0

func PlaySoundIsolated(sound, cooldown):
	if soundcooldown > 0:
		return
	PlaySound(sound)
	soundcooldown = cooldown

func GetSoundNode():
	var node = get_tree().get_root()
	var soudnnode = AudioStreamPlayer.new()
	soudnnode.bus = 'Sound'
	node.add_child(soudnnode)
	return soudnnode

func GetEventNode():
	var node
	if get_tree().get_root().has_node('EventNode') == false:
		node = load("res://files/TextScene/TextSystem.tscn").instance()
		get_tree().get_root().add_child(node)
		#node.set_as_toplevel(true)
		node.name = 'EventNode'
	else:
		node = get_tree().get_root().get_node("EventNode")
		get_tree().get_root().remove_child(node)
		get_tree().get_root().add_child(node)
	return node

#func ShowConfirmPanel(TargetNode, TargetFunction, Text):
#	var node
#	if get_tree().get_root().has_node('ConfirmPanel') == false:
#		node = load("res://files/scenes/ConfirmPanel.tscn").instance()
#		get_tree().get_root().add_child(node)
#		node.name = 'ConfirmPanel'
#	else:
#		node = get_tree().get_root().get_node("ConfirmPanel")
#		get_tree().get_root().remove_child(node)
#		get_tree().get_root().add_child(node)
#	node.Show(TargetNode, TargetFunction, Text)


#Item shading function

func itemshadeimage(node, item): #reworked to a new itemdata structure
	var shader = load("res://files/scenes/ItemShader.tres").duplicate()
	if node.get_class() == "TextureButton":
		node.texture_normal = load(item.icon)
	else:
		node.texture = load(item.icon)
#	if node.material != shader:
#		node.material = shader
#	else:
#		shader = node.material
#	for i in item.parts:
#		var part = 'part' +  str(item.partcolororder[i]) + 'color'
#		var color = Items.Materials[item.parts[i]].color
#		node.material.set_shader_param(part, color)
#	for i in range(item.colors.size()):
#		var part = 'part' +  str(i) + 'color'
#		var color = item.colors[i]
#		node.material.set_shader_param(part, color)


#Enlarge/fade out animation


func CloseAnimation(node):
	if BeingAnimated.has(node) == true:
		return
	BeingAnimated.append(node)
	tween_property(node, 'modulate', Color(1,1,1,1), Color(1,1,1,0), 0.2)
	tween_property(node, 'rect_scale', Vector2(1,1), Vector2(0.7,0.6), 0.2)
	yield(get_tree().create_timer(0.3), 'timeout')
	node.visible = false
	BeingAnimated.erase(node)
	globals.hidetooltip()
	if node.has_method('on_close_finished'):
		node.on_close_finished()
	#globals.call_deferred('EventCheck');

func OpenAnimation(node):
	if BeingAnimated.has(node) == true:
		return
	BeingAnimated.append(node)
	node.visible = true
	tween_property(node, 'modulate', Color(1,1,1,0), Color(1,1,1,1), 0.2)
	tween_property(node, 'rect_scale', Vector2(0.7,0.6), Vector2(1,1), 0.2)
	yield(get_tree().create_timer(0.3), 'timeout')
	BeingAnimated.erase(node)
	if node.has_method('on_open_finished'):
		node.on_open_finished()
	#globals.call_deferred('EventCheck');






func FadeAnimation(node, time = 0.3, delay = 0, chain = false):
	if !chain:
		node.modulate = Color(1,1,1,1)
	tween_property(node, 'modulate', Color(1,1,1,1), Color(1,1,1,0), time, delay)

func UnfadeAnimation(node, time = 0.3, delay = 0, chain = false):
	if !chain:
		node.modulate = Color(1,1,1,0)
	tween_property(node, 'modulate', Color(1,1,1,0), Color(1,1,1,1), time, delay)
	node.visible = true

func ShakeAnimation(node, time = 0.5, magnitude = 5):
	var newdict = {node = node, time = time, magnitude = magnitude, originpos = node.rect_position}
	for i in ShakingNodes:
		if i.node == node:
			newdict.originpos = i.originpos
			ShakingNodes.erase(i)
	ShakingNodes.append(newdict)

#seems not in use
#func SmoothValueAnimation(node, time, value1, value2):
#	var tween = GetTweenNode(node)
#	tween.interpolate_property(node, 'value', value1, value2, time, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
#	tween.start()


func gfx(node, effect, fadeduration = 0.5, delayuntilfade = 0.3, rotate = false):
	var x = TextureRect.new()
	x.texture = resources.get_res(effect)
	x.expand = true
	x.stretch_mode = 6
	node.add_child(x)

	x.rect_size = node.rect_size
	if rotate == true:
		x.rect_pivot_offset = x.texture.get_size()/2
		x.rect_rotation = rand_range(0,360)

	input_handler.FadeAnimation(x, fadeduration, delayuntilfade)
	var wr = weakref(x)
	yield(get_tree().create_timer(fadeduration*2), 'timeout')

	if wr.get_ref(): x.queue_free()

var sprites = {slash = 'res://assets/images/gfx/hit/HitAnimation.tscn'} 

func gfx_sprite(node, effect, fadeduration = 0.5, delayuntilfade = 0.3, flip_h = false, flip_v = false):
	var scene
	if sprites.has(effect):
		if sprites[effect] is bool:#can only be false here
			return
		else:
			scene = sprites[effect]
	else:
		scene = "res://assets/images/gfx/%s/scene_animation.tscn" % effect
	if !(scene is PackedScene):
		if scene is String:
			if ResourceLoader.exists(scene):
				scene = load(scene)
				sprites[effect] = scene
			else:
				sprites[effect] = false
				return
		else:
			return
	var x = scene.instance()
	if x is AnimatedSprite:#x can be AnimationPlayer
		if flip_h or flip_v:
			x.position.y -= 80 # need do adjust because hero sprites are too tall
		x.flip_h = flip_h
		x.flip_v = flip_v
	node.add_child(x)
	if effect == "earthquake":
		node.move_child(x, 0)
	x.play()
#	if delayuntilfade == null:
#		delayuntilfade = x.frames.get_frame_count(x.animation) / x.frames.get_animation_speed(x.animation)
	if delayuntilfade != null:
		input_handler.FadeAnimation(x, fadeduration, delayuntilfade)
	var wr = weakref(x)
#	yield(get_tree().create_timer(fadeduration*2), 'timeout')
	yield(x, 'animation_finished')
	
	if wr.get_ref(): x.queue_free()


func ResourceGetAnimation(node, startpoint, endpoint, time = 0.5, delay = 0.2):
	tween_property(node, 'rect_position', startpoint, endpoint, time, delay)
	tween_property(node, 'modulate', Color(1,1,1,1), Color(1,1,1,0), 0.1, delay + (time/1.2))

func SmoothTextureChange(node, newtexture, time = 0.5):
	var NodeCopy = node.duplicate()
	node.get_parent().add_child_below_node(node, NodeCopy)
	node.texture = newtexture
	FadeAnimation(NodeCopy, time)
	yield(get_tree().create_timer(time+0.1), 'timeout')
	NodeCopy.queue_free()

func BlackScreenTransition(duration = 0.5):
	var blackscreen = load("res://files/SFX/BlackScreen.tscn").instance()
	get_tree().get_root().add_child(blackscreen)
	UnfadeAnimation(blackscreen, duration)
	FadeAnimation(blackscreen, duration, duration)
	yield(get_tree().create_timer(duration*2+0.1), 'timeout')
	blackscreen.queue_free()

func DelayedText(node, text):
	node.text = text

func calculate_number_from_string_array(arr, caster, target):
	if typeof(arr) != TYPE_ARRAY:
		return float(arr)
	var array = arr.duplicate()
	var endvalue = 0
	var singleop = ''
	var firstrun = true
	for i in array:
		if typeof(i) == TYPE_ARRAY:
			i = str(calculate_number_from_string_array(i, caster, target))
		if i in ['+','-','*','/']:
			singleop = i
			continue
		var modvalue = i
		if (i.find('caster') >= 0) or (i.find('target') >= 0):
			i = i.split('.')
			if i[0] == 'caster':
				modvalue = str(caster.get_stat(i[1]))
			elif i[0] == 'target':
				modvalue = str(target.get_stat(i[1]))
		elif (i.find('random') >= 0):
			i = i.split(' ')
			modvalue = str(globals.rng.randi_range(0, int(i[1])))
		if singleop != '':
			endvalue = string_to_math(endvalue, singleop+modvalue)
			singleop = ''
			continue
		if !modvalue[0].is_valid_float():
			if modvalue[0] == '-' && firstrun == true:
				endvalue += float(modvalue)
			else:
				endvalue = string_to_math(endvalue, modvalue)
		else:
			endvalue += float(modvalue)
		firstrun = false
	return endvalue

func FindFighterRow(fighter):
	var pos = fighter.position
	if pos in range(4,7) || pos in range(10,13):
		pos = 'backrow'
	else:
		pos = 'frontrow'
	return pos


func operate(operation, value1, value2):
	var result

	match operation:
		'eq':
			result = value1 == value2
		'neq':
			result = value1 != value2
		'gte':
			result = value1 >= value2
		'gt':
			result = value1 > value2
		'lte':
			result = value1 <= value2
		'lt':
			result = value1 < value2
		'has':
			result = value1.has(value2)
		'has_no':
			result = !value1.has(value2)
		'mask':
			result = (int(value1) & int(value2)) != 0
	return result

func string_to_math(value = 0, string = ''):
	var modvalue = float(string.substr(1, string.length()))
	var operator = string[0]

	match operator:
		'+':value += modvalue
		'-':value -= modvalue
		'*':value *= modvalue
		'/':value /= modvalue
	return value

func weightedrandom(array): #array must be made out of dictionaries with {value = name, weight = number} Number is relative to other elements which may appear
	var total = 0
	var counter = 0
	for i in array:
		if typeof(i) == TYPE_DICTIONARY:
			total += i.weight
		else:
			total += i[1]
	var random = rand_range(0,total)
	for i in array:
		if typeof(i) == TYPE_DICTIONARY:
			if counter + i.weight >= random:
				return i
			counter += i.weight
		else:
			if counter + i[1] >= random:
				return i[0]
			counter += i[1]

func open_shell(string):
	var path = string
	match string:
		'Itch':
			path = 'https://strive4power.itch.io/strive-for-power'
		'Patreon':
			path = 'https://www.patreon.com/maverik'
		'Discord':
			path = "https://discord.gg/VXSx9Zk"
#warning-ignore:return_value_discarded
	OS.shell_open(path)

func SystemMessage(text, time = 4):
	var basetime = time
	if SystemMessageNode == null:
		return
	text = '[center]' + tr(text) + '[/center]'
	SystemMessageNode.modulate.a = 1
	SystemMessageNode.bbcode_text = text
	FadeAnimation(SystemMessageNode, 1, basetime)

#!!!!!! Clearup NODE_GAMETIP constants befor deleting this
#func ShowGameTip(tip):
#	if globals.globalsettings.disabletips == true || state.viewed_tips.has(tip):
#		return
#	var tipnode = get_spec_node(NODE_GAMETIP)
#	tipnode.showtip(tip)

func ShowOutline(node):
	node.material = load('res://files/scenes/portret_shader.tres').duplicate()
	node.material.set_shader_param('opacity', 1)

func HideOutline(node):
	node.material.set_shader_param('opacity', 0)

func ConnectSound(node, sound, action):
	node.connect(action, input_handler, 'PlaySound', [sound])

#variative get node method stuff
enum {NODE_GAMETIP, NODE_CHAT, NODE_TUTORIAL, NODE_LOOTTABLE, NODE_DIALOGUE, NODE_INVENTORY, NODE_POPUP, NODE_CONFIRMPANEL, NODE_SLAVESELECT, NODE_SKILLSELECT, NODE_EVENT, NODE_MUSIC, NODE_SOUND, NODE_TEXTEDIT, NODE_SLAVETOOLTIP, NODE_SKILLTOOLTIP, NODE_ITEMTOOLTIP, NODE_TEXTTOOLTIP, NODE_CHARCREATE, NODE_SLAVEPANEL, NODE_COMBATPOSITIONS, NODE_GEARTOOLTIP, NODE_CREDITS, NODE_CONFIRMPANELBIG, NODE_NOTIFICATION, NODE_UNLOCKCHAR} #, NODE_TWEEN, NODE_REPEATTWEEN}

var node_data = {
	NODE_GAMETIP : {name = 'GameTips', mode = 'scene', scene = preload("res://files/scenes/GameplayTips.tscn")},
#	NODE_CHAT : {name = 'chatwindow', mode = 'scene', scene = preload("res://src/scenes/ChatNode.tscn")},
#	NODE_TUTORIAL : {name = 'TutorialNode', mode = 'scene', scene = preload("res://files/scenes/Tutorial.tscn")},
#	NODE_LOOTTABLE : {name = 'lootwindow', mode = 'scene', scene = preload("res://src/scenes/LootWindow.tscn")},
#	NODE_DIALOGUE : {name = 'dialogue', mode = 'scene', scene = preload("res://src/InteractiveMessage.tscn")},
#	NODE_INVENTORY : {name = 'inventory', mode = 'scene', scene = preload("res://files/Inventory.tscn"), calls = 'open'},
#	NODE_POPUP : {name = 'PopupPanel', mode = 'scene', scene = preload("res://src/scenes/PopupPanel.tscn"), calls = 'open'},
	NODE_CONFIRMPANEL : {name = 'ConfirmPanel', mode = 'scene', scene = preload("res://files/scenes/ConfirmPanel.tscn"), calls = 'show_confirm'},
	NODE_CONFIRMPANELBIG : {name = 'ConfirmPanelBig', mode = 'scene_on_demand', scene_path = 'res://files/scenes/ConfirmPanelBig.tscn', calls = 'show_confirm'},
	NODE_NOTIFICATION : {name = 'ConfirmPanel', mode = 'scene', scene = preload("res://files/scenes/ConfirmPanel.tscn"), calls = 'show_notify'},
#	NODE_SLAVESELECT : {name = 'SlaveSelectMenu', mode = 'scene', scene = preload("res://src/SlaveSelectMenu.tscn")},
#	NODE_SKILLSELECT : {name = 'SelectSkillMenu', mode = 'scene', scene = preload("res://src/SkillSelectMenu.tscn")},
	NODE_EVENT : {name = 'EventNode', mode = 'scene', scene = preload("res://files/TextSceneNew/TextSystem.tscn")},
	NODE_MUSIC : {name = 'music', mode = 'node', node = AudioStreamPlayer, args = {'bus':"Music"}},
	NODE_SOUND : {name = 'music', mode = 'node', no_return = true, node = AudioStreamPlayer, args = {'bus':"Sound"}},
	#NODE_REPEATTWEEN : {name = 'repeatingtween', mode = 'node', node = Tween, args = {'repeat':true}},
	#NODE_TWEEN : {name = 'tween', mode = 'node', node = Tween},
#	NODE_TEXTEDIT : {name = 'texteditnode', mode = 'scene', scene = preload("res://src/TextEditField.tscn")},
#	NODE_SLAVETOOLTIP : {name = 'slavetooltip', mode = 'scene', scene = preload("res://src/SlaveTooltip.tscn")},
	NODE_SKILLTOOLTIP : {name = 'skilltooltip', mode = 'scene', scene = preload("res://files/scenes/SkillToolTip.tscn")},
	NODE_ITEMTOOLTIP : {name = 'itemtooltip', mode = 'scene', scene = preload("res://files/Simple Tooltip/Itemtooltip.tscn")},
	NODE_GEARTOOLTIP : {name = 'slottooltip', mode = 'scene', scene = preload("res://files/scenes/GearTooltip.tscn")},
#	NODE_TEXTTOOLTIP : {name = 'texttooltip', mode = 'scene', scene = preload("res://src/TextTooltipPanel.tscn")},
#	NODE_CHARCREATE : {name = 'charcreationpanel', mode = 'scene', scene = preload("res://src/CharacterCreationPanel.tscn"), calls = 'open'},
	NODE_SLAVEPANEL : {name = 'slavepanel', mode = 'scene', scene = preload("res://files/scenes/CharPanel/CharacterPanel.tscn")},
#	NODE_COMBATPOSITIONS : {name = 'combatpositions', mode = 'scene', scene = preload("res://src/PositionSelectMenu.tscn"), calls = 'open'},
	NODE_CREDITS : {name = 'credits', mode = 'scene_on_demand', scene_path = "res://files/scenes/Credits.tscn"},
	NODE_UNLOCKCHAR : {name = 'UnlockCharPanel', mode = 'scene_on_demand', scene_path = 'res://files/scenes/UnlockCharPanel.tscn', calls = 'open'},
}

func get_spec_node(type, args = null, raise = true):
	var window
	var node = get_tree().get_root()
	if node.has_node(node_data[type].name) and !node_data[type].has('no_return'):
		window = node.get_node(node_data[type].name)
		#node.remove_child(window)
	else:
		match node_data[type].mode:
			'scene':
				window = node_data[type].scene.instance()
			'scene_on_demand':
				window = load(node_data[type].scene_path).instance()
			'node':
				window = node_data[type].node.new()
		window.name = node_data[type].name
		node.add_child(window)
	if raise: window.raise()
	if node_data[type].has('args'):
		for param in node_data[type].args:
			window.set(param, node_data[type].args[param])
	if node_data[type].has('calls'):
		if args == null: args = []
		window.callv(node_data[type].calls, args)
	elif args != null:
		for param in args:
			window.set(param, args[param])
	return window

func initiate_scennode(node):
	var tscene = load("res://files/TextSceneNew/TextSystem.tscn")
	var tnode = tscene.instance()
#	input_handler.scene_node = tnode #will be set on add_child anyway
	tnode.hide()
	node.add_child(tnode)



func random_element(arr:Array):
	if arr.size() == 0: return null
	var pos = globals.rng.randi_range(0, arr.size() -1)
	return arr[pos]


func if_mouse_inside(node):
	if node is BaseButton:
		if !node.visible or node.modulate.a == 0.0: return false
		return node.get_global_rect().has_point(node.get_global_mouse_position())
	else:
		if !node.visible or node.modulate.a == 0.0 or node.texture == null: return false
		if !node.get_global_rect().has_point(node.get_global_mouse_position()): return false
		var pos = node.get_local_mouse_position()
		var tt = node.texture.get_data()
		var t = Image.new()
		t.copy_from(tt)
		pos.x *= (t.get_width()/node.rect_size.x)
		pos.y *= (t.get_height()/node.rect_size.y)
		t.lock()
		var col = t.get_pixelv(pos)
		return (col.a > 0.0)


func ClearContainer(container, templates = ['Button']):
	for i in container.get_children():
		i.hide()
		if !(i.name in templates):
			i.queue_free()

func ClearContainerForced(container, templates = ['Button']):
	for i in container.get_children():
		i.hide()
		if !(i.name in templates):
			i.free()

func DuplicateContainerTemplate(container, template = 'Button'):
	var newbutton = container.get_node(template).duplicate()
	newbutton.show()
	container.add_child(newbutton)
	container.move_child(container.get_node(template), newbutton.get_position_in_parent())
	return newbutton

#TODO: move all screen block mechanics in game to this solution
func block_screen():
	if map_node == null: return
	screen_blocked = true
	map_node.switch_block_screen(true)

func unblock_screen():
	if map_node == null: return
	screen_blocked = false
	map_node.switch_block_screen(false)

func queue_connection(obj :String, sig :String, subj :Node, method :String):
	var node = get(obj)
	if node != null and is_instance_valid(node):
		node.connect(sig, subj, method)
		return
	connect_queue.append({obj = obj, sig = sig, subj = subj, method = method})

func set_handler_node(property :String, node :Node):
	set(property, node)
	for i in range(connect_queue.size()-1,-1,-1):
		var connection = connect_queue[i]
		if connection.obj == property:
			node.connect(connection.sig, connection.subj, connection.method)
			connect_queue.remove(i)


