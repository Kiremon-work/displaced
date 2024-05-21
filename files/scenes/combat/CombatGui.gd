extends Control

onready var combat = get_parent()

onready var utility_bar = $SkillPanel/UtilityContainer
onready var active_panel = $ActiveActionPanel
onready var active_panel2 = $ActiveActionPanel2
onready var skill_panel = $SkillPanel
onready var allskill_container = $SkillPanel/Skills
onready var skill_container = $SkillPanel/Skills/SkillContainer
onready var ultskill_container = $SkillPanel/Skills/UltSkillContainer
onready var defaultskill_container = $SkillPanel/Skills/DefaultSkillContainer
onready var item_container = $SkillPanel/ItemContainer

var hpanel1 = load("res://files/scenes/combat/char_stat_party.tscn")
var hpanel2 = load("res://files/scenes/combat/char_stat_reserve.tscn")

var hotkey_buttons = {
	hotkey_skill_2 = 0,
	hotkey_skill_3 = 1,
	hotkey_skill_4 = 2,
	
	hotkey_skill_7 = 3,
	hotkey_skill_8 = 4,
	hotkey_skill_9 = 5,
	
	#for hotkey identification checks only
	hotkey_skill_1 = -1,
	hotkey_skill_6 = -1,
	hotkey_skill_5 = -1,
	hotkey_skill_10 = -1,
}
var hotkeys
var sounds = {
	"skill_pressed" : "sound/itemget_2"
}

func _ready():
	for i in sounds.values():
		resources.preload_res(i)
	if resources.is_busy(): yield(resources, "done_work")
	
	$SkillPanel/Escape.connect("pressed", combat, "try_to_run")
	$SkillPanel/cheat.connect("pressed", combat, "cheatvictory")
	$SkillPanel/cheatheal.connect("pressed", combat, "cheatheal")
	$SkillPanel/CategoriesContainer/SkillsButton.connect('pressed', self, "RebuildSkillPanel")
	$SkillPanel/CategoriesContainer/ItemsButton.connect('pressed', self, "RebuildItemPanel")
	$Combatlog2.connect("pressed", self, 'set_log')
	bind_hero_panels()
	hide_screen()
	
	set_process_input(false)
	combat.connect("combat_ended", self, "combat_finish")
	hotkeys = globals.get_hotkeys_handler()
	
	$EmemyStats/ExpandBtn.connect("pressed", self, "expand_ememy_stats")
	
	#strange thing, but at this point SkillPanel hasn't yet updated it's coordinates
	#so we have to yield, to get correct global_position for button
#	yield(get_tree(), "idle_frame")
	TutorialCore.register_dynamic_button("skill", self, "pressed")
	TutorialCore.register_dynamic_button("char_reserve", self, "button_down")

func get_tutorial_button(button_name :String):
	if button_name == "skill":
		return skill_container.get_child(0)
	elif button_name == "char_reserve":
		for ch in state.characters:
			var node = get_hero_reserve(ch)
			if node.visible:
				return node

func combat_start():
	clear_log()
	prepare_shades()
	hide_screen()
	$Combatlog.visible = false
	set_process_input(true)

func combat_finish():
	set_process_input(false)
	HideSkillPanel()
	globals.hideskilltooltip()

#panels
func get_hero_panel(hero_id):
	return get_node("PlayerStats/VBoxContainer/%s" % hero_id)

func get_hero_reserve(hero_id):
	return get_node("PlayerStats/VBoxContainer/%s_reserve" % hero_id)

func get_enemy_panel(pos):
	pos -= 4
	var r = pos / 3
	var l = pos % 3
	return get_node("EmemyStats/Panel/VBoxContainer").get_child(l * 2 + r)


func bind_hero_panels():
	input_handler.ClearContainerForced($PlayerStats/VBoxContainer)
	for ch in state.characters:
		var node = hpanel1.instance()
		node.name = ch
		node.connect('pressed_lmb', combat, 'select_player_char', [ch])
		node.connect('pressed_rmb', self, 'ShowHeroTooltip', [ch])
		$PlayerStats/VBoxContainer.add_child(node)
	for ch in state.characters:
		var node = hpanel2.instance()
		node.name = ch + '_reserve'
		node.connect('pressed_rmb', self, 'ShowHeroTooltip', [ch])
		$PlayerStats/VBoxContainer.add_child(node)


func ShowFighterStats(fighter): #obsolete
	var node = input_handler.get_spec_node(input_handler.NODE_SLAVEPANEL)
	node.open(state.heroes[fighter], true)


func build_hero_panels():
	var ch_order = []
	for pos in range(1, 4):
		var ch = combat.battlefield[pos]
		if ch == null: continue
		ch_order.push_back(ch.id)
#	for ch in state.characters:
#		if ch_order.has(ch): continue
#		ch_order.push_back(ch)
	for i in range(ch_order.size()):
		var ch = ch_order[i]
		var node = get_hero_panel(ch)
		$PlayerStats/VBoxContainer.move_child(node, i)
		var ch_d = state.heroes[ch].displaynode
		ch_d.get_parent().move_child(ch_d, i)
	for ch in state.characters:
		var hero = state.heroes[ch]
		var node1 = get_hero_panel(ch)
		var node2 = get_hero_reserve(ch)
		node1.visible = hero.unlocked
		node2.visible = hero.unlocked
		if hero.position != null:
			node2.visible = false
		else:
			node1.visible = false


func build_enemy_panels():
	for pos in range(4, 10):
		var node = get_enemy_panel(pos)
#		node.connect("mouse_exited", self, "HideEnemyTooltip")
		var ch = combat.battlefield[pos]
		if ch == null:
			node.modulate = Color(1,1,1,0.4)
			node.disabled = true
			for n in node.get_children():
				n.visible = false
			if node.is_connected("pressed", self, "ShowEnemyTooltip"):
				node.disconnect("pressed", self, "ShowEnemyTooltip")
		else:
			node.disabled = false
			node.modulate = Color(1,1,1,1)
			for n in node.get_children():
				n.visible = true
			if node.is_connected("pressed", self, "ShowEnemyTooltip"):
				node.disconnect("pressed", self, "ShowEnemyTooltip")
			node.connect("pressed", self, "ShowEnemyTooltip", [ch.id])


func ShowEnemyTooltip(fighter):
	if TryHideEnemyTooltip(fighter):
		return
	var panel = $enemypanel
	panel.build_for_fighter(fighter)
	panel.show()

func TryHideEnemyTooltip(fighter) ->bool:
	var panel = $enemypanel
	if !panel.visible or panel.ch_id != fighter:
		return false
	HideEnemyTooltip()
	return true

func HideEnemyTooltip():
	$enemypanel.hide()


func ShowHeroTooltip(fighter):
	if $heropanel.ch_id == fighter and $heropanel.visible:
		HideHeroTooltip()
		return 
	$heropanel.build_for_fighter(fighter)
	$heropanel.show()

func HideHeroTooltip():
	$heropanel.hide()

#shades
func prepare_shades():
	for shade in $CharShades.get_children():
		shade.set_inactive()
		shade.rect_position = combat.positions[shade.pos]
		shade.rect_position.x += 100
		shade.rect_position.y += 40


func activate_shades(positions = []):
	$dropscreen.visible = true
	for shade in $CharShades.get_children():
		if shade.pos in positions:
			shade.set_active()
		else:
			shade.set_inactive()


func hide_screen():
	$dropscreen.visible = false


func skill_button_pressed(mode, arg):
	if !combat.allowaction: return
	match mode:
		'skill':
			input_handler.PlaySound(sounds["skill_pressed"])
			combat.SelectSkill(arg)
		'item':
			combat.ActivateItem(arg)

#skill panel
func ClearSkillPanel():
	input_handler.ClearContainer(skill_container)
	input_handler.ClearContainer(ultskill_container)

func HideSkillPanel():
	skill_panel.visible = false


func RebuildSkillPanel():
	if !combat.allowaction: 
		HideSkillPanel()
		return
	skill_panel.visible = true
	hotkeys.set_hotkey_for_node(
		defaultskill_container.get_node("attack"),
		"hotkey_skill_1")
	hotkeys.set_hotkey_for_node(
		defaultskill_container.get_node("defence"),
		"hotkey_skill_6")
	var activecharacter = combat.activecharacter
	ClearSkillPanel()
	var skill_num = -1
	var first_ult = true
	for i in activecharacter.skills:
		if i in ['attack', 'defence']: continue
		var skill = Skillsdata.patch_skill(i, activecharacter)
		var hotkey = "err"
		var container
		if skill.skilltype == 'ultimate':
			container = ultskill_container
			if first_ult:
				hotkey = 'hotkey_skill_5'
				first_ult = false
			else:
				hotkey = 'hotkey_skill_10'
		else:
			container = skill_container
			skill_num +=1
			for key in hotkey_buttons:
				if hotkey_buttons[key] == skill_num:
					hotkey = key
					break
		var newbutton = input_handler.DuplicateContainerTemplate(container)
		newbutton.get_node("TextureRect").texture = skill.icon
		newbutton.get_node("Cooldown").text = ""
		if !activecharacter.can_use_skill(skill):
			newbutton.disabled = true
			newbutton.get_node("TextureRect").material = load("res://assets/sfx/bw_shader.tres")
			if activecharacter.cooldowns.has(i):
				newbutton.get_node("Cooldown").text = str(activecharacter.cooldowns[i])
			if skill.skilltype == 'ultimate':
				newbutton.get_node("Cooldown").text = "%d%%" % activecharacter.get_ultimeter()
#		newbutton.connect('pressed', combat, 'SelectSkill', [skill.code])
		newbutton.connect('pressed', self, 'skill_button_pressed', ['skill', skill.code])
		newbutton.set_meta('skill', skill.code)
		globals.connectskilltooltip(newbutton, activecharacter.id, i)
		if newbutton.disabled:
			hotkeys.disable_hotkey_for_node(newbutton)
		else:
			hotkeys.set_hotkey_for_node(newbutton, hotkey)
	
	if activecharacter.combatgroup == 'ally':
		allskill_container.visible = true
		item_container.visible = false
		$SkillPanel/CategoriesContainer.visible = true
		UpdatePressedStatus()
	else:
		HideSkillPanel()


#item panel
func ClearItemPanel():
	input_handler.ClearContainer(item_container)

func RebuildItemPanel():
	if !combat.allowaction: return
	ClearItemPanel()
	for id in state.materials:
		if state.materials[id] <= 0: continue
		var i = Items.Items[id]
		if i.itemtype == 'usable_combat':
			var newbutton = input_handler.DuplicateContainerTemplate(item_container)
			newbutton.get_node("icon").texture = i.icon
			newbutton.get_node("count").text = str(state.materials[id])
			newbutton.set_meta('skill', i.useskill)
			newbutton.connect('pressed', self, 'skill_button_pressed', ['item', i])
			globals.connectmaterialtooltip(newbutton, i)
	allskill_container.visible = false
	item_container.visible = true
	UpdatePressedStatus()

#utility & default
func RebuildDefaultsPanel():
	if !combat.allowaction: return
	var activecharacter = combat.activecharacter
	for i in ['attack', 'defence']:
		var newbutton = defaultskill_container.get_node(i)
		var skill = Skillsdata.patch_skill(i, activecharacter)
		if !newbutton.is_connected('pressed', self, 'skill_button_pressed'):
			newbutton.connect('pressed', self, 'skill_button_pressed', ['skill', skill.code])
			newbutton.set_meta('skill', skill.code)
		globals.connectskilltooltip(newbutton, activecharacter.id, i)


#func RebuildReserve(forced = false):
#	if !combat.allowaction and !forced: return
#	$SkillPanel/Escape.visible = true
#	for ch in state.characters:
#		var hero = state.heroes[ch]
#		if !hero.unlocked: continue
#		if hero.position != null: continue
#		var button = input_handler.DuplicateContainerTemplate(utility_bar, 'Button')
#		button.get_node('TextureRect').texture = hero.portrait_circle()
#		if hero.acted:
#			button.disabled = true
#		else:
#			button.connect('pressed', combat, 'SelectExchange', [ch])


#global info
func build_enemy_head():
	var cw = combat.curstage + 1
	var nw = combat.enemygroup_full.size()
	$EmemyStats/Label.text = tr("WAVE") + " %d/%d" % [cw, nw]

func UpdatePressedStatus():
	$SkillPanel/CategoriesContainer/ItemsButton.pressed = item_container.visible
	$SkillPanel/CategoriesContainer/SkillsButton.pressed = allskill_container.visible

#stub for next 3 actions
#this panel not helps in re-selecting heroes 
func build_selected_skill(skill): #not skill_id
	active_panel.visible = true
	active_panel2.visible = true
	active_panel2.get_node("TextureRect").texture = skill.icon
	active_panel2.get_node("Label").text = tr(skill.name)

	UpdatePressedStatus()
	defaultskill_container.get_node("attack").pressed = skill.code == "attack"
	for ch in skill_container.get_children() + ultskill_container.get_children():
		if ch.name == 'Button': continue
		ch.pressed = ch.get_meta("skill") == skill.code


func build_selected_item(item): 
	active_panel.visible = true
	active_panel2.visible = true
	active_panel2.get_node("TextureRect").texture = item.icon
	active_panel2.get_node("Label").text = item.name
	UpdatePressedStatus()
	for ch in item_container.get_children():
		if ch.name == 'Button': continue
		ch.pressed = ch.get_meta("skill") == item.useskill


#func build_selected_char(hero):
#	active_panel.visible = true
#	active_panel2.visible = true
#	active_panel2.get_node("TextureRect").texture = hero.portrait_circle()
#	active_panel2.get_node("Label").text = hero.name


func unbild_selection():
	active_panel.visible = false
	active_panel2.visible = false
#	UpdatePressedStatus()
	if allskill_container.visible:
		defaultskill_container.get_node("attack").pressed = false
		for ch in skill_container.get_children() + ultskill_container.get_children():
			ch.pressed = false
	elif item_container.visible:
		for ch in item_container.get_children():
			ch.pressed = false


func _input(event):
	if skill_panel.visible and allskill_container.visible:
		for hotkey in hotkey_buttons:
			if event.is_action_pressed(hotkey):
				var button = get_button_by_hotkey(hotkey)
				if button != null and !button.disabled:
					button.emit_signal("pressed")
				get_tree().set_input_as_handled()
				break


func get_button_by_hotkey(hotkey :String) ->Node:
	if hotkey == "hotkey_skill_1":
		return defaultskill_container.get_node("attack")
	if hotkey == "hotkey_skill_6":
		return defaultskill_container.get_node("defence")
	if hotkey == "hotkey_skill_5":
		#with all get_child_count() mind, that there is always 'template' child at the end of list
		if ultskill_container.get_child_count() < 2:
			return null
		return ultskill_container.get_child(0)
	if hotkey == "hotkey_skill_10":
		if ultskill_container.get_child_count() < 3:
			return null
		return ultskill_container.get_child(1)
	if !hotkey_buttons.has(hotkey):
		assert(false, "no such hotkey in CombatGui.gd")
		return null
	var button_num = hotkey_buttons[hotkey]
	if button_num >= skill_container.get_child_count()-1:
		return null
	return skill_container.get_child(button_num)


func expand_ememy_stats():
	var ememy_stats = $EmemyStats/Panel
	ememy_stats.visible = !ememy_stats.visible


#combatlog
func clear_log():
	$Combatlog/RichTextLabel.clear()


func combatlogadd_q(text):
	$Combatlog/RichTextLabel.append_bbcode(text + "\n")


func set_log():
	$Combatlog.visible = !$Combatlog.visible
