extends base_effect
class_name temp_e_progress
#temp effect that progress on expiring

var tick_event := []
#all temp effects should be removed on death or combat end
var rem_event := [variables.TR_COMBAT_F, variables.TR_DEATH]
var remains := -1

var template_name

func _init(caller).(caller):
	pass

func createfromtemplate(tmp):
	.createfromtemplate(tmp)
	if template.has('tick_event'): 
		if typeof(template.tick_event) == TYPE_ARRAY:
			tick_event = template.tick_event.duplicate()
		else:
			tick_event.clear()
			tick_event.push_back(template.tick_event)
	if template.has('rem_event'): 
		if typeof(template.rem_event) == TYPE_ARRAY:
			rem_event.append_array(template.rem_event)
		else:
			rem_event.push_back(template.rem_event)
	template_name = template.name

func apply():
	.apply()
	if template.has('duration'): 
		if typeof(template.duration) == TYPE_STRING:
			match template.duration:
				'parent':
					var par
					if typeof(parent) == TYPE_STRING:
						par = effects_pool.get_effect_by_id(parent)
					else:
						par = parent
					if par != null:
						template.duration = int(par.template.duration)
					else:
						print('error in template %s' % template_name)
						template.duration = -1
				'parent_arg':
					var par
					if typeof(parent) == TYPE_STRING:
						par = effects_pool.get_effect_by_id(parent)
					else:
						par = parent
					if par != null:
						template.duration = int(par.self_args['duration'])
					else:
						print('error in template %s' % template_name)
						template.duration = -1
		elif typeof(template.duration) == TYPE_DICTIONARY:
			if template.duration.obj == 'parent_args':
				var par = get_parent()
				if par != null:
					template.duration = int(par.get_arg(template.duration.param))
				else:
					print('error in template %s' % template_name)
					template.duration = -1
			else:
				print('error in template %s' % template_name)
				template.duration = -1
		remains = template.duration
	var obj = get_applied_obj()
	for eff in sub_effects:
		obj.apply_effect(eff)

func upgrade():
	remove()
#	createfromtemplate(template.next_level)
	var tmp = effects_pool.e_createfromtemplate(template.next_level, id)
#	get_applied_obj().apply_effect(id)
	get_applied_obj().apply_effect(effects_pool.add_effect(tmp))
	pass

func tick_eff():
	remains -= 1
	for b in buffs:
		b.calculate_args()
	if remains == 0:
		upgrade()

func process_event(ev):
	if !is_applied: return
	if tick_event.has(ev):
		tick_eff()
	if rem_event.has(ev):
		remove()

func reset_duration():
	if template.has('duration'): remains = template.duration

func serialize():
	var tmp = .serialize()
	tmp['type'] = 'temp_p'
	tmp['remains'] = remains
	return tmp
	pass

func deserialize(tmp):
	.deserialize(tmp)
	if template.has('tick_event'): 
		if typeof(template.tick_event) == TYPE_ARRAY:
			for tr in template.tick_event:
				tick_event.push_back(int(tr))
		else:
			tick_event.push_back(int(template.tick_event))
	rem_event.clear()
	if template.has('rem_event'): 
		if typeof(template.rem_event) == TYPE_ARRAY:
			for tr in template.rem_event:
				rem_event.push_back(int(tr))
		else:
			rem_event.push_back(int(template.rem_event))
	remains = int(tmp.remains)
	template_name = template.name
	pass

func remove():
	if !is_applied: return
	.remove()
	for e in sub_effects:
		var t = effects_pool.get_effect_by_id(e)
		t.remove()
	sub_effects.clear()
	is_applied = false
