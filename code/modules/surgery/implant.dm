//Procedures in this file: Putting items in body cavity. Implant removal. Items removal.

//////////////////////////////////////////////////////////////////
//					ITEM PLACEMENT SURGERY						//
//////////////////////////////////////////////////////////////////

/datum/surgery_step/cavity
	priority = 1

/datum/surgery_step/cavity/can_use(mob/living/user, mob/living/carbon/human/target, target_zone, obj/item/tool, obj/limb/affected, checks_only)
	var/bleeding_check = FALSE
	for(var/datum/effects/bleeding/external/E in affected.bleeding_effects_list)
		bleeding_check = TRUE
		break
	return affected.surgery_open_stage == (affected.encased ? 3 : 2) && !bleeding_check

/datum/surgery_step/cavity/proc/get_max_wclass(obj/limb/affected)
	switch (affected.name)
		if("head")
			return 1
		if("chest")
			return 3
		if("groin")
			return 2
	return 0

/datum/surgery_step/cavity/proc/get_cavity(obj/limb/affected)
	switch (affected.name)
		if("head")
			return "cranial"
		if("chest")
			return "thoracic"
		if("groin")
			return "abdominal"
	return ""

/datum/surgery_step/cavity/make_space
	allowed_tools = list(
	/obj/item/tool/surgery/surgicaldrill = 100, \
	/obj/item/tool/pen = 75,            \
	/obj/item/stack/rods = 50
	)

	min_duration = SURGICAL_DRILL_MIN_DURATION
	max_duration = SURGICAL_DRILL_MAX_DURATION

/datum/surgery_step/cavity/make_space/can_use(mob/living/user, mob/living/carbon/human/target, target_zone, obj/item/tool, obj/limb/affected, checks_only)
	if(..())
		return !affected.cavity && !affected.hidden

/datum/surgery_step/cavity/make_space/begin_step(mob/user, mob/living/carbon/human/target, target_zone, obj/item/tool, obj/limb/affected)
	user.visible_message(SPAN_NOTICE("[user] starts making some space inside [target]'s [get_cavity(affected)] cavity with \the [tool]."), \
	SPAN_NOTICE("You start making some space inside [target]'s [get_cavity(affected)] cavity with \the [tool]."))
	log_interact(user, target, "[key_name(user)] started to make some space in [key_name(target)]'s [affected.display_name] with \the [tool].")

	target.custom_pain("The pain in your chest is living hell!", 1)
	affected.cavity = 1
	..()

/datum/surgery_step/cavity/make_space/end_step(mob/living/user, mob/living/carbon/human/target, target_zone, obj/item/tool, obj/limb/affected)
	user.visible_message(SPAN_NOTICE("[user] makes some space inside [target]'s [get_cavity(affected)] cavity with \the [tool]."), \
	SPAN_NOTICE("You make some space inside [target]'s [get_cavity(affected)] cavity with \the [tool]."))
	log_interact(user, target, "[key_name(user)] made some space in [key_name(target)]'s [affected.display_name] with \the [tool].")


/datum/surgery_step/cavity/make_space/fail_step(mob/living/user, mob/living/carbon/human/target, target_zone, obj/item/tool, obj/limb/affected)
	user.visible_message(SPAN_WARNING("[user]'s hand slips, scraping tissue inside [target]'s [affected.display_name] with \the [tool]!"), \
	SPAN_WARNING("Your hand slips, scraping tissue inside [target]'s [affected.display_name] with \the [tool]!"))
	log_interact(user, target, "[key_name(user)] failed to make some space in [key_name(target)]'s [affected.display_name] with \the [tool].")

	affected.createwound(CUT, 20)
	affected.update_wounds()



/datum/surgery_step/cavity/close_space
	allowed_tools = list(
    /obj/item/tool/surgery/cautery = 100,         \
    /obj/item/clothing/mask/cigarette = 75,    \
    /obj/item/tool/lighter = 50,    \
    /obj/item/tool/weldingtool = 50
    )

	min_duration = CAUTERY_MIN_DURATION
	max_duration = CAUTERY_MAX_DURATION

/datum/surgery_step/cavity/close_space/can_use(mob/living/user, mob/living/carbon/human/target, target_zone, obj/item/tool, obj/limb/affected, checks_only)
	if(..())
		return affected.cavity

/datum/surgery_step/cavity/close_space/begin_step(mob/user, mob/living/carbon/human/target, target_zone, obj/item/tool, obj/limb/affected)
	user.visible_message(SPAN_NOTICE("[user] starts mending [target]'s [get_cavity(affected)] cavity wall with \the [tool]."), \
	SPAN_NOTICE("You start mending [target]'s [get_cavity(affected)] cavity wall with \the [tool]."))
	log_interact(user, target, "[key_name(user)] started to mend [key_name(target)]'s [get_cavity(affected)] cavity wall with \the [tool].")

	target.custom_pain("The pain in your chest is living hell!",1)
	affected.cavity = 0
	..()

/datum/surgery_step/cavity/close_space/end_step(mob/living/user, mob/living/carbon/human/target, target_zone, obj/item/tool, obj/limb/affected)
	user.visible_message(SPAN_NOTICE("[user] mends [target]'s [get_cavity(affected)] cavity walls with \the [tool]."), \
	SPAN_NOTICE("You mend [target]'s [get_cavity(affected)] cavity walls with \the [tool]."))
	log_interact(user, target, "[key_name(user)] mended [key_name(target)]'s [get_cavity(affected)] cavity wall with \the [tool].")


/datum/surgery_step/cavity/close_space/fail_step(mob/living/user, mob/living/carbon/human/target, target_zone, obj/item/tool, obj/limb/affected)
	user.visible_message(SPAN_WARNING("[user]'s hand slips, scraping tissue inside [target]'s [affected.display_name] with \the [tool]!"), \
	SPAN_WARNING("Your hand slips, scraping tissue inside [target]'s [affected.display_name] with \the [tool]!"))
	log_interact(user, target, "[key_name(user)] failed to mend [key_name(target)]'s [get_cavity(affected)] cavity wall with \the [tool].")

	affected.createwound(CUT, 20)
	affected.update_wounds()



/datum/surgery_step/cavity/place_item
	priority = 0 //Do NOT allow surgery items to go in here
	allowed_tools = list(/obj/item = 100)

	min_duration = IMPLANT_MIN_DURATION
	max_duration = IMPLANT_MAX_DURATION

/datum/surgery_step/cavity/place_item/can_use(mob/living/user, mob/living/carbon/human/target, target_zone, obj/item/tool, obj/limb/affected, checks_only)
	if(..())
		return !istype(user,/mob/living/silicon/robot) && !affected.hidden && affected.cavity && tool.w_class <= get_max_wclass(affected)

/datum/surgery_step/cavity/place_item/begin_step(mob/user, mob/living/carbon/human/target, target_zone, obj/item/tool, obj/limb/affected)
	user.visible_message(SPAN_NOTICE("[user] starts putting \the [tool] inside [target]'s [get_cavity(affected)] cavity."), \
	SPAN_NOTICE("You start putting \the [tool] inside [target]'s [get_cavity(affected)] cavity.") )
	log_interact(user, target, "[key_name(user)] started to put \the [tool] inside [key_name(target)]'s [get_cavity(affected)] cavity.")

	target.custom_pain("The pain in your chest is living hell!",1)
	..()

/datum/surgery_step/cavity/place_item/end_step(mob/living/user, mob/living/carbon/human/target, target_zone, obj/item/tool, obj/limb/affected)
	user.visible_message(SPAN_NOTICE("[user] puts \the [tool] inside [target]'s [get_cavity(affected)] cavity."), \
	SPAN_NOTICE("You put \the [tool] inside [target]'s [get_cavity(affected)] cavity."))
	log_interact(user, target, "[key_name(user)] put \the [tool] inside [key_name(target)]'s [get_cavity(affected)] cavity.")

	if(tool.w_class > get_max_wclass(affected)/2 && prob(50))
		to_chat(user, SPAN_WARNING("You tear some blood vessels trying to fit such a big object in this cavity."))
		log_interact(user, target, "[key_name(user)] damaged some blood vessels while putting \the [tool] inside [key_name(target)]'s [get_cavity(affected)] cavity.")

		var/datum/wound/internal_bleeding/I = new (0)
		affected.add_bleeding(I, TRUE)
		affected.wounds += I
		affected.owner.custom_pain("You feel something rip in your [affected.display_name]!", 1)
	user.drop_inv_item_to_loc(tool, target)
	affected.hidden = tool
	affected.cavity = 0

/datum/surgery_step/cavity/place_item/fail_step(mob/living/user, mob/living/carbon/human/target, target_zone, obj/item/tool, obj/limb/affected)
	user.visible_message(SPAN_WARNING("[user]'s hand slips, scraping tissue inside [target]'s [affected.display_name] with \the [tool]!"), \
	SPAN_WARNING("Your hand slips, scraping tissue inside [target]'s [affected.display_name] with \the [tool]!"))
	log_interact(user, target, "[key_name(user)] failed to put \the [tool] inside [key_name(target)]'s [get_cavity(affected)] cavity.")

	affected.createwound(CUT, 20)
	affected.update_wounds()



//////////////////////////////////////////////////////////////////
//					IMPLANT/ITEM REMOVAL SURGERY				//
//////////////////////////////////////////////////////////////////


/datum/surgery_step/cavity/implant_removal
	priority = 1
	allowed_tools = list(
	/obj/item/tool/surgery/hemostat = 100,           \
	/obj/item/tool/wirecutters = 75,         \
	/obj/item/tool/kitchen/utensil/fork = 20
	)

	min_duration = REMOVE_OBJECT_MIN_DURATION
	max_duration = REMOVE_OBJECT_MAX_DURATION

/datum/surgery_step/cavity/implant_removal/can_use(mob/living/user, mob/living/carbon/human/target, target_zone, obj/item/tool, obj/limb/affected, checks_only)
	var/datum/internal_organ/brain/sponge = target.internal_organs_by_name["brain"]
	//potential conflict with brain repair surgery
	return ..() && (target_zone != "head" || (!sponge || !sponge.damage || sponge.damage>20))

/datum/surgery_step/cavity/implant_removal/begin_step(mob/user, mob/living/carbon/human/target, target_zone, obj/item/tool, obj/limb/affected)
	user.visible_message(SPAN_NOTICE("[user] starts poking around inside the incision on [target]'s [affected.display_name] with \the [tool]."), \
	SPAN_NOTICE("You start poking around inside the incision on [target]'s [affected.display_name] with \the [tool]."))
	log_interact(user, target, "[key_name(user)] started poking around inside the incision on [key_name(target)]'s [affected.display_name] with \the [tool].")

	target.custom_pain("The pain in your chest is living hell!", 1)
	..()

/datum/surgery_step/cavity/implant_removal/end_step(mob/living/user, mob/living/carbon/human/target, target_zone, obj/item/tool, obj/limb/affected)
	if(affected.implants.len)

		var/obj/item/obj = affected.implants[1]
		user.visible_message(SPAN_NOTICE("[user] takes something out of incision on [target]'s [affected.display_name] with \the [tool]."), \
		SPAN_NOTICE("You take [obj] out of incision on [target]'s [affected.display_name]s with \the [tool]."))
		log_interact(user, target, "[key_name(user)] removed [obj] from [key_name(target)]'s [affected.display_name] with \the [tool].")

		affected.implants -= obj

		obj.forceMove(get_turf(target))
		if(istype(obj,/obj/item/implant))
			var/obj/item/implant/imp = obj
			imp.imp_in = null
			imp.implanted = 0

		if(istype(target, /mob/living/carbon/human))
			var/mob/living/carbon/human/H = target
			if(is_sharp(obj) || istype(obj, /obj/item/shard/shrapnel))
				H.embedded_items -= obj
			user.count_niche_stat(STATISTICS_NICHE_SURGERY_SHRAPNEL)

	else if(affected.hidden)
		user.visible_message(SPAN_NOTICE("[user] takes something out of incision on [target]'s [affected.display_name] with \the [tool]."), \
		SPAN_NOTICE("You take something out of incision on [target]'s [affected.display_name]s with \the [tool]."))
		log_interact(user, target, "[key_name(user)] removed something from [key_name(target)]'s [affected.display_name] with \the [tool].")

		affected.hidden.forceMove(get_turf(target))

		affected.hidden.blood_color = target.get_blood_color()
		affected.hidden.update_icon()
		affected.hidden = null

	else
		user.visible_message(SPAN_NOTICE("[user] could not find anything inside [target]'s [affected.display_name], and pulls \the [tool] out."), \
		SPAN_NOTICE("You could not find anything inside [target]'s [affected.display_name]."))
		log_interact(user, target, "[key_name(user)] found nothing inside [key_name(target)]'s [affected.display_name] with \the [tool].")


/datum/surgery_step/cavity/implant_removal/fail_step(mob/living/user, mob/living/carbon/human/target, target_zone, obj/item/tool, obj/limb/affected)
	user.visible_message(SPAN_WARNING("[user]'s hand slips, scraping tissue inside [target]'s [affected.display_name] with \the [tool]!"), \
	SPAN_WARNING("Your hand slips, scraping tissue inside [target]'s [affected.display_name] with \the [tool]!"))
	log_interact(user, target, "[key_name(user)] damaged the inside of [key_name(target)]'s [affected.display_name] with \the [tool].")

	affected.createwound(CUT, 20)
	if(affected.implants.len)
		var/fail_prob = 10
		fail_prob += 100 - tool_quality(tool)
		if(prob(fail_prob))
			var/obj/item/I = affected.implants[1]
			if(istype(I,/obj/item/implant))
				var/obj/item/implant/imp = I
				user.visible_message(SPAN_WARNING("Something beeps inside [target]'s [affected.display_name]!"))
				playsound(imp.loc, 'sound/items/countdown.ogg', 25, 1)
				addtimer(CALLBACK(imp, /obj/item/implant.proc/activate), 25)
	target.updatehealth()
	affected.update_wounds()
