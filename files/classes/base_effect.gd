extends Reference
class_name base_effect

var parent = null
var id
var template
var args : = []
var self_args := {}
var sub_effects := []
var tags := []
var buffs := []
var atomic := []
var sfx := {}
var is_applied
var applied_char = null
var name = "undefined debug name"
var screen_name = ""

func _init(caller):
	parent = caller
	is_applied = false

func get_parent():
	if typeof(parent) == TYPE_STRING:
		return effects_pool.get_effect_by_id(parent)
	return parent

func apply():
	var obj = get_applied_obj()
	is_applied = true
	atomic.clear()
	calculate_args()
	for a in template.atomic:
		var tmp := atomic_effect.new(a, id)
		tmp.resolve_template()
		#tmp.apply_template(obj)
		obj.apply_atomic(tmp.template)
		atomic.push_back(tmp.template)
	sub_effects.clear()
	for e in template.sub_effects:
		var tmp = effects_pool.e_createfromtemplate(e, id)
		#tmp.calculate_args()
		sub_effects.push_back(effects_pool.add_effect(tmp))
		pass
	setup_siblings()
	rebuild_buffs()
	rebuild_sfx()

func reapply():
	var obj = get_applied_obj()
	for a in atomic:
		obj.remove_atomic(a)
	atomic.clear()
	for a in template.atomic:
		var tmp := atomic_effect.new(a, id)
		tmp.resolve_template()
		obj.apply_atomic(tmp.template)
		atomic.push_back(tmp.template)
	for e in sub_effects:
		var t = effects_pool.get_effect_by_id(e)
		t.remove()
	sub_effects.clear()
	for e in template.sub_effects:
		var tmp = effects_pool.e_createfromtemplate(e, id)
		sub_effects.push_back(effects_pool.add_effect(tmp))
		pass
	setup_siblings()
	rebuild_buffs()
	rebuild_sfx()
	

func setup_siblings():
	if sub_effects.size() < 2:
		return
	for se in sub_effects:
		var eff = effects_pool.get_effect_by_id(se)
		eff.self_args['siblings'] = sub_effects.duplicate()
		eff.self_args['siblings'].erase(se)

func remove_siblings():
	if !self_args.has('siblings'): return
	for se in self_args['siblings']:
		var eff = effects_pool.get_effect_by_id(se)
		eff.remove()

func recheck():
	if !is_applied: return
	rebuild_sfx()

func remove():
	if !is_applied: return
	var obj = get_applied_obj()
	if obj != null:
		obj.remove_effect(id)
		for a in atomic:
			obj.remove_atomic(a)
	atomic.clear()
	buffs.clear()
	clear_sfx()

func get_applied_obj():
	if applied_char == null:
		return null
	return state.heroes[applied_char]

func get_applied_obj_name() -> String:
	var obj = get_applied_obj()
	if obj:
		var resault = obj.get("name")
		if resault:
			return resault
		return "not_named_obj"
	elif self_args.has('skill'):
		return self_args['skill'].template.name
	return "no_obj"

func createfromtemplate(buff_t):
	if typeof(buff_t) == TYPE_STRING:
		template = Effectdata.effect_table[buff_t].duplicate()
	else:
		template = buff_t.duplicate()
	if template.has('tags'):
		tags = template.tags.duplicate()
	if !template.has('sub_effects'):
		template['sub_effects'] = []
	if !template.has('buffs'):
		template['buffs'] = []
	if !template.has('atomic'):
		template['atomic'] = []
	if template.has('name'):
		name = template.name#mind, that this param sort of duplicates template_name for effects, that has it
	elif template.has('debug_name'):
		name = template.debug_name
	if template.has('screen_name'):
		screen_name = template.screen_name



func calculate_args():
	args.clear()
	if template.has('args'):
		for arg in template.args:
			match arg.obj:
				'self':
					args.push_back(self_args[arg.param])
				'parent':
					var par = get_parent()
					if par == null:
						args.push_back(null)
					else:
						args.push_back(par.get(arg.param))
				'template':
					args.push_back(template[arg.param])
				'parent_args':
					var par = get_parent()
					if par == null:
						args.push_back(null)
					else:
						args.push_back(par.get_arg(int(arg.param)))
				'parent_arg_get':
					var par = get_parent()
					if par == null:
						args.push_back(null)
					else:
						args.push_back(par.get_arg(arg.index).get(arg.param))
				'app_obj':
					var par = get_applied_obj()
					args.push_back(par.get(arg.param))
				'skill':
					if self_args.has('skill'):
						var obj = self_args['skill']
						args.push_back(obj.get(arg.param))
					else:
						args.push_back(0)#considered to be dynamic

func get_arg(index):
	var arg = template.args[index]
	if arg.has('dynamic') || args[index] == null:
		match arg.obj:
			'parent':
				var par = get_parent()
				if par != null:
					args[index] = par.get(arg.param)
				pass
			'parent_args':
				var par = get_parent()
				if par != null:
					args[index] = par.get_arg(int(arg.param))
			'parent_arg_get':
				var par = get_parent()
				if par != null:
					args[index] = par.get_arg(int(arg.index)).get(arg.param)
			'app_obj':
				var par = get_applied_obj()
				args[index] = par.get(arg.param)
			'skill':
				assert(self_args.has('skill'), "no skill for skill's arg")
				var obj = self_args['skill']
				args[index] = obj.get(arg.param)
	return args[index]

#func test_id_me() -> String:
#	var par = get_applied_obj()
#	var my_id = "%s " % id
#	if par != null:
#		return my_id + par.name
#	elif typeof(parent) == TYPE_STRING:
#		return my_id + parent
#	else:
#		return my_id + parent.code

func set_args(arg, value):
	self_args[arg] = value
	#calculate_args()

#mind, that effects are no longer suppose to be saved in savegames, so serialize/deserialize should be useless for now
func serialize():
	var tmp := {}
	tmp['name'] = name
	tmp['is_applied'] = is_applied
	tmp['template'] = template
	tmp['args'] = self_args
	tmp['sub_effects'] = sub_effects
	tmp['type'] = 'base'
	tmp['atomic'] = atomic
	tmp['buffs'] = []
#	tmp['app_char'] = applied_char
	for b in buffs:
		tmp['buffs'].push_back(b.serialize())
	return tmp

func deserialize(tmp):
	if tmp.has('name'):#probably only old savegame compatibility issue
		name = tmp['name']
	is_applied = tmp['is_applied']
	template = tmp['template'].duplicate()
	if template.has('tags'):
		tags = template.tags.duplicate()
	self_args = tmp['args'].duplicate()
	sub_effects = tmp['sub_effects'].duplicate()
	atomic = tmp['atomic'].duplicate()
#warning-ignore:incompatible_ternary
#	applied_char = tmp['app_char']
	applied_char = null
	buffs.clear()
#	calculate_args()
	for b in tmp['buffs']:
		var t = Buff.new(id)
		t.deserialize(b)
		buffs.push_back(t)
	pass

func rebuild_buffs():
	buffs.clear()
	for e in template.buffs:
		var tmp = Buff.new(id)
		tmp.createfromtemplate(e)
		tmp.calculate_args()
		buffs.push_back(tmp)

func clear_buffs():
	buffs.clear()

func has_screen_name() ->bool:
	return !screen_name.empty()

func get_screen_name() ->String:
	return tr(screen_name)

func rebuild_sfx():
	if !template.has('sfx'): return
	for e in template.sfx:
		var do_apply = true
		if e.has('conditions'):
			for cond in e.conditions:
				match cond.type:
					#add new types per need, or find a way to group it with triggered_effect
					'owner':
						do_apply = get_applied_obj().process_check(cond.value)
				if !do_apply: break
		if do_apply:
			if !sfx.has(e.id):
				var obj = get_applied_obj()
				assert(obj.has_method('add_permanent_sfx'), 'applied_obj seems not compatible with permanent_sfx')
				var new_sfx = obj.add_permanent_sfx(e.code)
				sfx[e.id] = new_sfx
		elif sfx.has(e.id):
			sfx[e.id].queue_free()#fade better?
			sfx.erase(e.id)

func clear_sfx():
	for id in sfx:
		sfx[id].queue_free()#fade better?
	sfx.clear()

