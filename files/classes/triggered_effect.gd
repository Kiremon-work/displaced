extends base_effect
class_name triggered_effect
#triggers. please do not add atomic effects to triggers - put them into separate static effect

# warning-ignore-all:return_value_discarded
var triggered_event := []
var reset_event := []
var ready = true
var req_skill = false
#var skill :S_Skill

func _init(caller).(caller):
	is_applied = true
	pass

func createfromtemplate(buff_t):
	.createfromtemplate(buff_t)
	triggered_event = template.trigger.duplicate()
	if template.has('reset'):
		reset_event = template.reset.duplicate()
	req_skill = template.req_skill
	if template.has('ready'):
		ready = template.ready
	pass

func serialize():
	self_args.erase('skill')
	var tmp = .serialize()
	tmp['type'] = 'trigger'
	tmp['ready'] = ready
	return tmp


func deserialize(tmp):
	.deserialize(tmp)
	#triggered_event = template.trigger.duplicate
	triggered_event.clear()
	for e in template.trigger: triggered_event.push_back(int(e))
	reset_event.clear()
	if template.has('reset'):
		#reset_event = template.reset.duplicate()
		for e in template.reset: reset_event.push_back(int(e))
	ready = tmp['ready']
	req_skill = template.req_skill

func process_event(ev):
#	print("process_event %s for %s of %s" % [ev, name, get_applied_obj_name()])
	if triggered_event.has(ev) and ready:
		if !req_skill or (self_args.has('skill') and self_args['skill'] != null):
			#check conditions
			var res = true
			for cond in template.conditions:
				match cond.type:
					'random': 
						res = res and (globals.rng.randf() < cond.value)
					'skill':
						var obj = self_args['skill']
						res = res and obj.process_check(cond.value)
					'caster':
						var obj = self_args['skill']
						res = res and obj.caster.process_check(cond.value)
					'target':
						var obj = self_args['skill']
						res = res and obj.target.process_check(cond.value)
					'owner':
						var obj = get_applied_obj()
						res = res and obj.process_check(cond.value)
					'combat':
						res = res and input_handler.combat_node.process_check(cond.value)
			if res:
				ready = false
				.clear_buffs()
				#apply trigger
				e_apply()
	if reset_event.has(ev) or reset_event.size() == 0:
		ready = true
		.rebuild_buffs()
	pass

func apply():
	setup_siblings()
	calculate_args()
	if ready: .rebuild_buffs()
	else: .clear_buffs()

func e_apply():
	sub_effects.clear()
	for e in template.sub_effects:
		var tmp = effects_pool.e_createfromtemplate(e, id)
		#tmp.calculate_args()
		sub_effects.push_back(effects_pool.add_effect(tmp))
		pass
	
	setup_siblings()
	for e in sub_effects:
		var eff = effects_pool.get_effect_by_id(e)
		var t1 = eff.template.target
		match t1:
			'self':
				match eff.template.execute:
					'remove':
						call_deferred('remove')
					'remove_siblings':#haven't been tested
						remove_siblings()
						input_handler.combat_node.update_buffs()
						call_deferred('remove')
			'skill':
				var obj = self_args['skill']
				obj.apply_effect(e)
			'caster':
				var obj = self_args['skill']
				obj.caster.apply_effect(e)
			'target':
				var obj = self_args['skill']
				obj.target.apply_effect(e)
			'receiver':
				var obj = self_args['receiver']
				obj.apply_effect(e)
			'owner':
				var obj = get_applied_obj()
				obj.apply_effect(e)
			'parent':
				match eff.template.execute:
					'remove':
						var obj = effects_pool.get_effect_by_id(parent)
						obj.remove()
					'remove_siblings':
						var obj = effects_pool.get_effect_by_id(parent)
						obj.remove_siblings()
						obj.remove()
						input_handler.combat_node.update_buffs()
					'tick':
						var obj = effects_pool.get_effect_by_id(parent)
						if obj is temp_e_progress or obj is temp_e_simple or obj is temp_e_upgrade:
							obj.tick_eff()
				#that seems not to be in use
#				var obj = effects_pool.get_effect_by_id(parent).get_applied_obj
#				obj.apply_effect(e)
			'combat':
				var obj = input_handler.combat_node
				if obj != null:
					match eff.template.execute:
						#seems to be useless
#						'enable_followup':
#							obj.follow_up_flag = true
#						'resurrect_all':
#							obj.res_all(eff.template.value * 0.01)
						'clean_summons':
							obj.clean_summons()
		pass
	sub_effects.clear()
	pass

func remove():
	var obj = get_applied_obj()
	if obj != null:
		obj.remove_effect(id)
	#.remove()
	is_applied = false
	pass
