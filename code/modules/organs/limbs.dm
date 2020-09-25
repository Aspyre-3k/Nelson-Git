/****************************************************
				EXTERNAL ORGANS
****************************************************/
/obj/limb
	name = "limb"
	appearance_flags = KEEP_TOGETHER | TILE_BOUND
	vis_flags = VIS_INHERIT_ID | VIS_INHERIT_DIR
	var/icon_name = null
	var/display_name
	var/body_part = null
	var/icon_position = 0
	var/damage_state = "=="

	var/brute_dam = 0
	var/burn_dam = 0
	var/max_damage = 0
	var/integrity_damage = 0 //INT damage sets the levels
	var/integrity_level = NO_FLAGS //Levels are not cumulative, but instead, are flags. This is so to allow some levels to be neutralized without changing the others (ex: level 3 effects are neutralized, but 2 and 4 are in effect)

	var/last_dam_time

	var/brute_autoheal = 0.02 //per life tick
	var/burn_autoheal = 0.04
	var/integrity_autoheal = 0.01
	var/neutralized_integrity_effects = NO_FLAGS
	var/healing_naturally = TRUE //natural healing is limited by health and other stuff
	var/max_medical_items = 3
	var/list/medical_items = list() //obj/item/stack/medical

	var/list/avaiable_surgeries = list(/datum/surgery_procedure/open_limb, /datum/surgery_procedure/close_limb)

	var/obj/limb/parent
	var/list/obj/limb/children
	var/has_stump_icon = FALSE

	var/processing = FALSE

	var/surgery_open_stage = 0

	var/obj/item/hidden = null
	var/list/implants = list()

	var/status //limb status flags

	var/mob/living/carbon/human/owner = null
	var/vital //Lose a vital limb, die immediately.

	var/datum/effects/bleeding/bleeding_effect //External bleeding


/obj/limb/New(obj/limb/P, mob/mob_owner)
	if(P)
		parent = P
		if(!parent.children)
			parent.children = list()
		parent.children.Add(src)
	if(mob_owner)
		owner = mob_owner

	loc = mob_owner

/obj/limb/Destroy()
	if(parent)
		parent.children -= src
	parent = null
	if(children)
		for(var/obj/limb/L in children)
			L.parent = null
		children = null

	if(hidden)
		qdel(hidden)
		hidden = null

	if(implants)
		for(var/I in implants)
			qdel(I)
		implants = null

	if(bleeding_effect)
		qdel(bleeding_effect)
		bleeding_effect = null

	if(owner && owner.limbs)
		owner.limbs -= src
		owner.update_body()
	owner = null

	return ..()

/obj/limb/proc/start_processing()
	owner.limbs_to_process += src
	processing = TRUE
/obj/limb/proc/stop_processing()
	owner.limbs_to_process -= src
	processing = FALSE

/obj/limb/process()
	if(brute_dam == 0 && burn_dam == 0 && integrity_damage == 0)
		return

	if(world.time - last_dam_time < MINIMUM_AUTOHEAL_DAMAGE_INTERVAL)
		return
	if(healing_naturally)
		if(owner.health < MINIMUM_AUTOHEAL_HEALTH || owner.stat == DEAD)
			return
	//Integrity autoheal
	if(integrity_damage < LIMB_INTEGRITY_AUTOHEAL_THRESHOLD)
		take_integrity_damage(-integrity_autoheal)

	heal_damage(brute_autoheal, burn_autoheal)

/obj/limb/proc/get_slowdown()
	return 0

//Integrity damage changes the integrity level
/obj/limb/proc/take_integrity_damage(amount)
	integrity_damage = max(min(integrity_damage + amount, MAX_LIMB_INTEGRITY),0)
	recalculate_integrity_level()

/obj/limb/proc/recalculate_integrity()
	recalculate_health_effects()
	recalculate_integrity_level()

/obj/limb/proc/recalculate_integrity_level()
	var/new_level
	if(integrity_damage >= LIMB_INTEGRITY_THRESHOLD_OKAY)
		new_level |= LIMB_INTEGRITY_OKAY
		if(integrity_damage >= LIMB_INTEGRITY_THRESHOLD_CONCERNING)
			new_level |= LIMB_INTEGRITY_CONCERNING
			if(integrity_damage >= LIMB_INTEGRITY_THRESHOLD_SERIOUS)
				new_level |= LIMB_INTEGRITY_SERIOUS
				if(integrity_damage >= LIMB_INTEGRITY_THRESHOLD_CRITICAL)
					new_level |= LIMB_INTEGRITY_CRITICAL
					if(integrity_damage >= LIMB_INTEGRITY_NONE)
						new_level |= LIMB_INTEGRITY_NONE
	
	new_level &= ~neutralized_integrity_effects

	if(new_level == integrity_level)
		return

	var/added_effects = ~integrity_level & new_level
	var/removed_effects = integrity_level & ~new_level
	integrity_level = new_level

	reapply_integrity_effects(added_effects, removed_effects)

/obj/limb/proc/reapply_integrity_effects(added, removed)

/mob/living/carbon/human/proc/check_limb_integrity(limb_name, level)
	var/obj/limb/L = get_limb(limb_name)
	if(!L)
		return FALSE
	if(L.integrity_level & level)
		return TRUE
	return TRUE

/****************************************************
			   DAMAGE PROCS
****************************************************/

/obj/limb/emp_act(severity)
	if(!(status & LIMB_ROBOT))	//meatbags do not care about EMP
		return
	var/probability = 30
	var/damage = 15
	if(severity == 2)
		probability = 1
		damage = 3
	if(prob(probability))
		droplimb(0, 0, "EMP")
	else
		take_damage(damage, 0, 1, 1, used_weapon = "EMP")

/*
	Describes how limbs (body parts) of human mobs get damage applied.
	Less clear vars:
	*	impact_name: name of an "impact icon." For now, is only relevant for projectiles but can be expanded to apply to melee weapons with special impact sprites.
*/
/obj/limb/proc/take_damage(brute, burn, sharp, edge, used_weapon = null, list/forbidden_limbs = list(), no_limb_loss, impact_name = null, var/damage_source = "dismemberment", var/mob/attack_source = null)
	if((brute <= 0) && (burn <= 0))
		return 0

	if(status & LIMB_DESTROYED)
		return 0
	var/is_ff = FALSE
	if(istype(attack_source) && attack_source.faction == owner.faction)
		brute /= 2
		is_ff = TRUE


	brute_dam += brute
	burn_dam += burn
	if(!is_ff)
		if((owner.stat != DEAD))
			take_integrity_damage(brute * 0.7) //Need to adjust to skills and armor
			if(brute > LIMB_BLEEDING_DAMAGE_THRESHOLD)
				add_bleeding(brute)

		if(length(medical_items))
			for(var/obj/item/stack/medical/M in medical_items)
				if(!M.take_onlimb_damage(brute, burn))
					remove_medical_item(M, TRUE)
	if(!processing)
		start_processing()

	last_dam_time = world.time
	owner.updatehealth()
	update_icon()

/obj/limb/proc/get_avaiable_surgeries()
	var/list/L = avaiable_surgeries.Copy()

	var/list/r_list = list()
	var/datum/surgery_procedure/S
	for(var/T in L)
		S = new T(owner, src)
		if(S.is_avaiable())
			r_list[S.name] = S

	if(owner.status_flags & XENO_HOST)
		S = new /datum/surgery_procedure/alien_embryo_removal(owner, src)
		r_list[S.name] = S

	return r_list

/obj/limb/proc/heal_damage(brute, burn, internal = 0, robo_repair = 0)
	if(status & LIMB_ROBOT && !robo_repair)
		return

	if(brute)
		remove_all_bleeding(TRUE)

	brute_dam = brute > brute_dam ? 0 : brute_dam - brute
	burn_dam = burn > burn_dam ? 0 : burn_dam - burn

	owner.updatehealth()

	update_icon()

/*
This function completely restores a damaged organ to perfect condition.
*/
/obj/limb/proc/rejuvenate()
	damage_state = "=="
	if(status & LIMB_ROBOT)	//Robotic organs stay robotic.  Fix because right click rejuvinate makes IPC's organs organic.
		status = LIMB_ROBOT
	else
		status = 0
	brute_dam = 0
	burn_dam = 0
	integrity_damage = 0
	recalculate_integrity()

	remove_all_bleeding()

	// remove embedded objects and drop them on the floor
	for(var/obj/implanted_object in implants)
		if(!istype(implanted_object,/obj/item/implant))	// We don't want to remove REAL implants. Just shrapnel etc.
			implanted_object.loc = owner.loc
			implants -= implanted_object
			if(is_sharp(implanted_object) || istype(implanted_object, /obj/item/shard/shrapnel))
				owner.embedded_items -= implanted_object

	owner.pain.recalculate_pain()
	owner.updatehealth()
	update_icon()

//Internal bleeding will most likely be a wound, so this only concerns external bleeding
/obj/limb/proc/add_bleeding(damage_taken)
	if(!(SSticker.current_state >= GAME_STATE_PLAYING)) //If the game hasnt started, don't add bleed. Hacky fix to avoid having 100 bleed effect from roundstart.
		return

	if(status & LIMB_ROBOT)
		return
	if(bleeding_effect)
		bleeding_effect.add_on(damage_taken)
	else
		bleeding_effect = new /datum/effects/bleeding/external(owner, src, 30)


/obj/limb/proc/remove_all_bleeding()
	if(bleeding_effect)
		qdel(bleeding_effect)
		bleeding_effect = null


/obj/limb/update_icon(forced = FALSE)
	if(has_stump_icon && (!parent || !(parent.status & LIMB_DESTROYED)))
		icon = 'icons/mob/humans/dam_human.dmi'
		icon_state = "stump_[icon_name]"

	var/race_icon = owner.species.icobase

	if (status & LIMB_ROBOT && !(owner.species && owner.species.flags & IS_SYNTHETIC))
		icon = 'icons/mob/robotic.dmi'
		icon_state = "[icon_name]"
		return

	var/datum/ethnicity/E = ethnicities_list[owner.ethnicity]
	var/datum/body_type/B = body_types_list[owner.body_type]

	var/e_icon
	var/b_icon

	if (!E)
		e_icon = "western"
	else
		e_icon = E.icon_name

	if (!B)
		b_icon = "mesomorphic"
	else
		b_icon = B.icon_name

	icon = race_icon
	icon_state = "[get_limb_icon_name(owner.species, b_icon, owner.gender, icon_name, e_icon)]"

	var/n_is = damage_state_text()
	if (forced || n_is != damage_state)
		overlays.Cut()
		damage_state = n_is
		update_overlays()


/obj/limb/proc/update_overlays()
	update_damage_icon_part()

// new damage icon system
// returns just the brute/burn damage code
/obj/limb/proc/damage_state_text()
	if(status & LIMB_DESTROYED)
		return "--"

	var/tburn = 0
	var/tbrute = 0

	if(burn_dam == 0)
		tburn = 0
	else if (burn_dam < (max_damage * 0.25 / 1.5))
		tburn = 1
	else if (burn_dam < (max_damage * 0.75 / 1.5))
		tburn = 2
	else
		tburn = 3

	if (brute_dam == 0)
		tbrute = 0
	else if (brute_dam < (max_damage * 0.25 / 1.5))
		tbrute = 1
	else if (brute_dam < (max_damage * 0.75 / 1.5))
		tbrute = 2
	else
		tbrute = 3
	return "[tbrute][tburn]"

/****************************************************
			   DISMEMBERMENT
****************************************************/

//Recursive setting of all child organs to amputated
/obj/limb/proc/setAmputatedTree()
	for(var/obj/limb/O in children)
		O.status |= LIMB_AMPUTATED
		O.setAmputatedTree()

/mob/living/carbon/human/proc/remove_random_limb(var/delete_limb = 0)
	var/list/limbs_to_remove = list()
	for(var/obj/limb/E in limbs)
		if(istype(E, /obj/limb/chest) || istype(E, /obj/limb/groin) || istype(E, /obj/limb/head))
			continue
		limbs_to_remove += E
	if(limbs_to_remove.len)
		var/obj/limb/L = pick(limbs_to_remove)
		var/limb_name = L.display_name
		L.droplimb(0, delete_limb)
		return limb_name
	return null

//Handles dismemberment
/obj/limb/proc/droplimb(amputation, var/delete_limb = 0, var/cause)
	if(!owner)
		return
	if(status & LIMB_DESTROYED)
		return
	else
		if(body_part == BODY_FLAG_CHEST)
			return
		if(status & LIMB_ROBOT)
			status = LIMB_DESTROYED|LIMB_ROBOT
		else
			status = LIMB_DESTROYED
			owner.pain.apply_pain(PAIN_BONE_BREAK)
		if(amputation)
			status |= LIMB_AMPUTATED
		for(var/i in implants)
			implants -= i
			if(is_sharp(i) || istype(i, /obj/item/shard/shrapnel))
				owner.embedded_items -= i
			qdel(i)

		for(var/i in medical_items)
			remove_medical_item(i)

		remove_all_bleeding()

		if(hidden)
			hidden.forceMove(owner.loc)
			hidden = null

		// If any organs are attached to this, destroy them
		for(var/obj/limb/O in children)
			O.droplimb(amputation, delete_limb, cause)
		/*
		if(parent && !amputation)
			var/datum/wound/W
			if(max_damage < 50) W = new/datum/wound/lost_limb/small(max_damage)
			else 				W = new/datum/wound/lost_limb(max_damage)
		*/

		//we reset the surgery related variables
		reset_limb_surgeries()

		var/obj/organ	//Dropped limb object
		switch(body_part)
			if(BODY_FLAG_HEAD)
				if(owner.species.flags & IS_SYNTHETIC) //special head for synth to allow brainmob to talk without an MMI
					organ= new /obj/item/limb/head/synth(owner.loc, owner)
				else
					organ= new /obj/item/limb/head(owner.loc, owner)
				owner.drop_inv_item_on_ground(owner.glasses, null, TRUE)
				owner.drop_inv_item_on_ground(owner.head, null, TRUE)
				owner.drop_inv_item_on_ground(owner.wear_ear, null, TRUE)
				owner.drop_inv_item_on_ground(owner.wear_mask, null, TRUE)
				owner.update_hair()
			if(BODY_FLAG_ARM_RIGHT)
				if(status & LIMB_ROBOT)
					organ = new /obj/item/robot_parts/r_arm(owner.loc)
				else
					organ = new /obj/item/limb/arm/r_arm(owner.loc, owner)
				if(owner.w_uniform && !amputation)
					var/obj/item/clothing/under/U = owner.w_uniform
					U.removed_parts |= body_part
					owner.update_inv_w_uniform()
			if(BODY_FLAG_ARM_LEFT)
				if(status & LIMB_ROBOT)
					organ = new /obj/item/robot_parts/l_arm(owner.loc)
				else
					organ = new /obj/item/limb/arm/l_arm(owner.loc, owner)
				if(owner.w_uniform && !amputation)
					var/obj/item/clothing/under/U = owner.w_uniform
					U.removed_parts |= body_part
					owner.update_inv_w_uniform()
			if(BODY_FLAG_LEG_RIGHT)
				if(status & LIMB_ROBOT)
					organ = new /obj/item/robot_parts/r_leg(owner.loc)
				else
					organ = new /obj/item/limb/leg/r_leg(owner.loc, owner)
				if(owner.w_uniform && !amputation)
					var/obj/item/clothing/under/U = owner.w_uniform
					U.removed_parts |= body_part
					owner.update_inv_w_uniform()
			if(BODY_FLAG_LEG_LEFT)
				if(status & LIMB_ROBOT)
					organ = new /obj/item/robot_parts/l_leg(owner.loc)
				else
					organ = new /obj/item/limb/leg/l_leg(owner.loc, owner)
				if(owner.w_uniform && !amputation)
					var/obj/item/clothing/under/U = owner.w_uniform
					U.removed_parts |= body_part
					owner.update_inv_w_uniform()
			if(BODY_FLAG_HAND_RIGHT)
				if(!(status & LIMB_ROBOT))
					organ= new /obj/item/limb/hand/r_hand(owner.loc, owner)
				owner.drop_inv_item_on_ground(owner.gloves, null, TRUE)
				owner.drop_inv_item_on_ground(owner.r_hand, null, TRUE)
			if(BODY_FLAG_HAND_LEFT)
				if(!(status & LIMB_ROBOT))
					organ= new /obj/item/limb/hand/l_hand(owner.loc, owner)
				owner.drop_inv_item_on_ground(owner.gloves, null, TRUE)
				owner.drop_inv_item_on_ground(owner.l_hand, null, TRUE)
			if(BODY_FLAG_FOOT_RIGHT)
				if(!(status & LIMB_ROBOT))
					organ= new /obj/item/limb/foot/r_foot/(owner.loc, owner)
				owner.drop_inv_item_on_ground(owner.shoes, null, TRUE)
			if(BODY_FLAG_FOOT_LEFT)
				if(!(status & LIMB_ROBOT))
					organ = new /obj/item/limb/foot/l_foot(owner.loc, owner)
				owner.drop_inv_item_on_ground(owner.shoes, null, TRUE)

		if(delete_limb)
			qdel(organ)
		else
			owner.visible_message(SPAN_WARNING("[owner.name]'s [display_name] flies off in an arc!"),
			SPAN_HIGHDANGER("<b>Your [display_name] goes flying off!</b>"),
			SPAN_WARNING("You hear a terrible sound of ripping tendons and flesh!"), 3)

			if(organ)
				//Throw organs around
				var/lol = pick(cardinal)
				step(organ,lol)

		owner.update_body(1)
		owner.UpdateDamageIcon(1)
		owner.update_med_icon()

		// OK so maybe your limb just flew off, but if it was attached to a pair of cuffs then hooray! Freedom!
		release_restraints()

		if(vital) owner.death(cause)

/****************************************************
			   HELPERS
****************************************************/

/obj/limb/proc/release_restraints()
	if(!owner)
		return
	if (owner.handcuffed && (body_part in list(BODY_FLAG_ARM_LEFT, BODY_FLAG_ARM_RIGHT, BODY_FLAG_HAND_LEFT, BODY_FLAG_HAND_RIGHT)))
		owner.visible_message(\
			"\The [owner.handcuffed.name] falls off of [owner.name].",\
			"\The [owner.handcuffed.name] falls off you.")

		owner.drop_inv_item_on_ground(owner.handcuffed)

	if (owner.legcuffed && (body_part in list(BODY_FLAG_FOOT_LEFT, BODY_FLAG_FOOT_RIGHT, BODY_FLAG_LEG_LEFT, BODY_FLAG_LEG_RIGHT)))
		owner.visible_message(\
			"\The [owner.legcuffed.name] falls off of [owner.name].",\
			"\The [owner.legcuffed.name] falls off you.")

		owner.drop_inv_item_on_ground(owner.legcuffed)
/*
/obj/limb/proc/fracture()
	if(status & (LIMB_BROKEN|LIMB_DESTROYED|LIMB_ROBOT) )
		if (knitting_time != -1)
			knitting_time = -1
			to_chat(owner, SPAN_WARNING("You feel your [src] stop knitting together as it absorbs damage!"))
		return
	if(owner.chem_effect_flags & CHEM_EFFECT_RESIST_FRACTURE)
		return
	owner.recalculate_move_delay = TRUE
	owner.visible_message(\
		SPAN_WARNING("You hear a loud cracking sound coming from [owner]!"),
		SPAN_HIGHDANGER("Something feels like it shattered in your [display_name]!"),
		SPAN_HIGHDANGER("You hear a sickening crack!"))
	var/F = pick('sound/effects/bone_break1.ogg','sound/effects/bone_break2.ogg','sound/effects/bone_break3.ogg','sound/effects/bone_break4.ogg','sound/effects/bone_break5.ogg','sound/effects/bone_break6.ogg','sound/effects/bone_break7.ogg')
	playsound(owner,F, 45, 1)
	if(owner.pain.feels_pain)
		owner.emote("scream")

	start_processing()

	status |= LIMB_BROKEN
	status &= ~LIMB_REPAIRED
	owner.pain.apply_pain(PAIN_BONE_BREAK)
	broken_description = pick("broken","fracture","hairline fracture")
	perma_injury = brute_dam
*/

/obj/limb/proc/robotize()
	status &= ~LIMB_AMPUTATED
	status &= ~LIMB_DESTROYED
	status &= ~LIMB_MUTATED
	status &= ~LIMB_REPAIRED
	status |= LIMB_ROBOT
	reset_limb_surgeries()

	for (var/obj/limb/T in children)
		if(T)
			T.robotize()

	update_icon()

/obj/limb/proc/mutate()
	src.status |= LIMB_MUTATED
	owner.update_body()

/obj/limb/proc/unmutate()
	src.status &= ~LIMB_MUTATED
	owner.update_body()

/obj/limb/proc/get_damage()	//returns total damage
	return brute_dam + burn_dam


/obj/limb/proc/is_usable()
	return !(status & (LIMB_DESTROYED|LIMB_MUTATED))

/obj/limb/proc/is_malfunctioning()
	return ((status & LIMB_ROBOT) && prob(brute_dam + burn_dam))

/obj/limb/proc/embed(var/obj/item/W, var/silent = 0)
	if(!W || QDELETED(W) || (W.flags_item & (NODROP|DELONDROP)) || W.embeddable == FALSE)
		return
	if(!silent)
		owner.visible_message(SPAN_DANGER("\The [W] sticks in the wound!"))
	implants += W

	if(is_sharp(W) || istype(W, /obj/item/shard/shrapnel))
		W.embedded_organ = src
		owner.embedded_items += W
		if(is_sharp(W)) // Only add the verb if its not a shrapnel
			owner.verbs += /mob/proc/yank_out_object
	W.add_mob_blood(owner)

	if(ismob(W.loc))
		var/mob/living/H = W.loc
		H.drop_held_item()
	if(W)
		W.forceMove(owner)

/obj/limb/proc/apply_medical_item(obj/item/stack/medical/item, mob/living/user)
	if(!istype(item) || !istype(user))
		return
	if(length(medical_items) >= max_medical_items)
		var/obj/item/stack/medical/removed_item = input(user, "Please choose an item to replace", "Medical Item Application") in (medical_items + "Cancel")
		if(!istype(removed_item))
			return FALSE
		medical_items -= removed_item
	//Pasted from medical.dm
	var/do_after_time = item.regular_delay
	if(user.skills && item.low_skill_delay)
		if(item.required_skill)
			if(!skillcheck(user, SKILL_MEDICAL, item.required_skill))
				do_after_time = item.low_skill_delay

	if(do_after_time)
		if(!do_after(user, do_after_time * user.get_skill_duration_multiplier(SKILL_MEDICAL), INTERRUPT_NO_NEEDHAND, BUSY_ICON_FRIENDLY, owner, INTERRUPT_MOVED, BUSY_ICON_MEDICAL))
			return FALSE

	var/possessive = "[user == owner ? "your" : "[owner]'s"]"
	var/possessive_their = "[user == owner ? "their" : "[owner]'s"]"
	user.affected_message(owner,
		SPAN_HELPFUL("You apply \an <b>[item.name]</b> to [possessive] <b>[display_name]</b>."),
		SPAN_HELPFUL("[user] applies \an <b>[item.name]</b> to your <b>[display_name]</b>."),
		SPAN_NOTICE("[user] applies \an [item.name] to [possessive_their] [display_name]."))
	item.use(1)
	playsound(user, item.application_sound, 25, 1, 2)
	//Add the item
	medical_items += new item.type(src, 1)
	recalculate_health_effects()

	owner.update_med_icon()
	return TRUE

/obj/limb/proc/remove_medical_item(obj/item/stack/medical/item, destroyed)
	if(!medical_items.Find(item))
		return
	medical_items -= item
	recalculate_health_effects()
	if(destroyed)
		qdel(item)
	else
		item.loc = get_turf(owner)

	owner.update_med_icon()

/obj/limb/proc/recalculate_health_effects()
	brute_autoheal = initial(brute_autoheal)
	burn_autoheal = initial(burn_autoheal)
	var/old_neutralized = neutralized_integrity_effects
	neutralized_integrity_effects = 0

	for(var/obj/item/stack/medical/M in medical_items)
		if(M.brute_autoheal > brute_autoheal)
			brute_autoheal = M.brute_autoheal
			healing_naturally = FALSE
		if(M.burn_autoheal > burn_autoheal)
			burn_autoheal = M.burn_autoheal
			healing_naturally = FALSE
		neutralized_integrity_effects |= M.limb_integrity_levels_neutralized
	if(neutralized_integrity_effects != old_neutralized)
		recalculate_integrity_level()

/obj/limb/proc/update_damage_icon_part()
	var/image/DI

	var/brutestate = copytext(damage_state, 1, 2)
	var/burnstate = copytext(damage_state, 2)
	if(brutestate != "0")
		DI = new /image('icons/mob/humans/dam_human.dmi', "grayscale_[brutestate]")
		DI.blend_mode = BLEND_INSET_OVERLAY
		DI.color = owner.species.blood_color
		overlays += DI

	if(burnstate != "0")
		DI = new /image('icons/mob/humans/dam_human.dmi', "burn_[burnstate]")
		DI.blend_mode = BLEND_INSET_OVERLAY
		overlays += DI

	// for(var/datum/wound/W in wounds)
	// 	if(W.impact_icon)
	// 		DI = new /image(W.impact_icon)
	// 		DI.blend_mode = BLEND_INSET_OVERLAY
	// 		overlays += DI


//called when limb is removed or robotized, any ongoing surgery and related vars are reset
/obj/limb/proc/reset_limb_surgeries()
	surgery_open_stage = 0




/****************************************************
			   LIMB TYPES
****************************************************/

/obj/limb/chest
	name = "chest"
	icon_name = "torso"
	display_name = "chest"
	max_damage = 200
	body_part = BODY_FLAG_CHEST
	vital = 1
	display_name = "chest"
	max_damage = 200
	body_part = BODY_FLAG_CHEST

/obj/limb/chest/reapply_integrity_effects(added, removed)
	..()
	if(removed & LIMB_INTEGRITY_CONCERNING)
		owner.bonus_knockdown -= 2
	else if(added & LIMB_INTEGRITY_CONCERNING)
		owner.bonus_knockdown += 2

/obj/limb/chest/take_damage(brute, burn, sharp, edge, used_weapon, list/forbidden_limbs, no_limb_loss, impact_name, damage_source, mob/attack_source)
	if(burn)
		if(integrity_level & LIMB_INTEGRITY_SERIOUS)
			burn *= 2
	. = ..()


/obj/limb/groin
	name = "groin"
	icon_name = "groin"
	display_name = "groin"
	max_damage = 200
	body_part = BODY_FLAG_GROIN
	vital = 1
	display_name = "groin"
	max_damage = 200

/obj/limb/groin/reapply_integrity_effects(added, removed)
	..()
	if(removed & LIMB_INTEGRITY_CONCERNING)
		owner.xeno_neurotoxin_buff -= 1.75
	else if(added & LIMB_INTEGRITY_CONCERNING)
		owner.xeno_neurotoxin_buff += 1.75

/obj/limb/leg
	name = "leg"
	display_name = "leg"
	max_damage = 35

/obj/limb/leg/get_slowdown()
	if(integrity_level & LIMB_INTEGRITY_CONCERNING)
		return 0.4

/obj/limb/leg/reapply_integrity_effects(added, removed)
	..()

	if(removed & LIMB_INTEGRITY_SERIOUS)
		owner.minimum_gun_recoil -= 1
	else if(added & LIMB_INTEGRITY_SERIOUS)
		owner.minimum_gun_recoil += 1

/obj/limb/foot
	name = "foot"
	display_name = "foot"
	max_damage = 30

/obj/limb/arm
	name = "arm"
	display_name = "arm"
	max_damage = 35

/obj/limb/arm/reapply_integrity_effects(added, removed)
	..()

	if(removed & LIMB_INTEGRITY_CONCERNING)
		owner.minimum_wield_delay -= 1
	else if(added & LIMB_INTEGRITY_CONCERNING)
		owner.minimum_wield_delay += 1

	if(removed & LIMB_INTEGRITY_SERIOUS) //This is really nasty
		owner.action_delay -= 3 SECONDS
	else if(added & LIMB_INTEGRITY_SERIOUS)
		owner.action_delay += 3 SECONDS

/obj/limb/hand
	name = "hand"
	display_name = "hand"
	max_damage = 30

/obj/limb/arm/l_arm
	name = "l_arm"
	display_name = "left arm"
	icon_name = "l_arm"
	body_part = BODY_FLAG_ARM_LEFT
	has_stump_icon = TRUE


/obj/limb/leg/l_leg
	name = "l_leg"
	display_name = "left leg"
	icon_name = "l_leg"
	body_part = BODY_FLAG_LEG_LEFT
	icon_position = LEFT
	has_stump_icon = TRUE

/obj/limb/arm/r_arm
	name = "r_arm"
	display_name = "right arm"
	icon_name = "r_arm"
	body_part = BODY_FLAG_ARM_RIGHT
	has_stump_icon = TRUE

/obj/limb/leg/r_leg
	name = "r_leg"
	display_name = "right leg"
	icon_name = "r_leg"
	body_part = BODY_FLAG_LEG_RIGHT
	icon_position = RIGHT
	has_stump_icon = TRUE

/obj/limb/foot/l_foot
	name = "l_foot"
	display_name = "left foot"
	icon_name = "l_foot"
	body_part = BODY_FLAG_FOOT_LEFT
	icon_position = LEFT
	has_stump_icon = TRUE

/obj/limb/foot/r_foot
	name = "r_foot"
	display_name = "right foot"
	icon_name = "r_foot"
	body_part = BODY_FLAG_FOOT_RIGHT
	icon_position = RIGHT
	has_stump_icon = TRUE

/obj/limb/hand/r_hand
	name = "r_hand"
	display_name = "right hand"
	icon_name = "r_hand"
	body_part = BODY_FLAG_HAND_RIGHT
	has_stump_icon = TRUE

/obj/limb/hand/l_hand
	name = "l_hand"
	display_name = "left hand"
	icon_name = "l_hand"
	body_part = BODY_FLAG_HAND_LEFT
	has_stump_icon = TRUE

/obj/limb/head
	name = "head"
	icon_name = "head"
	display_name = "head"
	max_damage = 60
	body_part = BODY_FLAG_HEAD
	vital = 1
	has_stump_icon = TRUE
	var/disfigured = 0 //whether the head is disfigured.

/obj/limb/head/reapply_integrity_effects(added, removed)

	if(removed & LIMB_INTEGRITY_CONCERNING)
		owner.zoom_blocked -= 1
	else if(added & LIMB_INTEGRITY_CONCERNING)
		owner.zoom_blocked += 1

	if(removed & LIMB_INTEGRITY_SERIOUS) //This is really nasty
		owner.special_vision_blocked -= 1
	else if(added & LIMB_INTEGRITY_SERIOUS)
		owner.special_vision_blocked += 1

/obj/limb/head/update_overlays()
	..()

	var/image/eyes = new/image('icons/mob/humans/onmob/human_face.dmi', owner.species.eyes)
	eyes.color = list(null, null, null, null, rgb(owner.r_eyes, owner.g_eyes, owner.b_eyes))
	overlays += eyes

	if(owner.lip_style && (owner.species && owner.species.flags & HAS_LIPS))
		var/icon/lips = new /icon('icons/mob/humans/onmob/human_face.dmi', "camo_[owner.lip_style]_s")
		overlays += lips

/obj/limb/head/take_damage(brute, burn, sharp, edge, used_weapon = null, list/forbidden_limbs = list(), no_limb_loss, impact_name = null, var/mob/attack_source = null)
	. = ..()
	if (!disfigured)
		if (brute_dam > 50 || brute_dam > 40 && prob(50))
			disfigure("brute")
		if (burn_dam > 40)
			disfigure("burn")

/obj/limb/head/proc/disfigure(var/type = "brute")
	if (disfigured)
		return
	if(type == "brute")
		owner.visible_message(SPAN_DANGER("You hear a sickening cracking sound coming from \the [owner]'s face."),	\
		SPAN_DANGER("<b>Your face becomes unrecognizible mangled mess!</b>"),	\
		SPAN_DANGER("You hear a sickening crack."))
	else
		owner.visible_message(SPAN_DANGER("[owner]'s face melts away, turning into mangled mess!"),	\
		SPAN_DANGER("<b>Your face melts off!</b>"),	\
		SPAN_DANGER("You hear a sickening sizzle."))
	disfigured = 1
	owner.name = owner.get_visible_name()

