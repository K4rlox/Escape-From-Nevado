/**
 * Poopmadness component, given to guns.
 * Makes the current holder of the gun get hallucinations.
 * Makes the current magazine of the gun be able to be reloaded with blood.
 */
/datum/component/poopmadness
	/// The mob that has the gun
	var/mob/living/carbon/human/madman
	/// Jumpscare fullscreen overlay
	var/atom/movable/screen/fullscreen/jumpscare/jumpscare
	/// Old combat music, cached
	var/cached_combat_music
	/// Ammo type we reload our evil gun with
	var/ammo_type

/datum/component/poopmadness/Initialize(ammo_type)
	if(!istype(parent, /obj/item/gun/ballistic))
		return COMPONENT_INCOMPATIBLE
	if(ammo_type)
		src.ammo_type = ammo_type
	else
		var/obj/item/gun/ballistic/ballistic = parent
		var/obj/item/ammo_box/magazine/mag_type = ballistic.mag_type
		src.ammo_type = initial(mag_type.ammo_type)

/datum/component/poopmadness/RegisterWithParent()
	RegisterSignal(parent, COMSIG_ITEM_EQUIPPED, .proc/on_equip)
	RegisterSignal(parent, COMSIG_ITEM_DROPPED, .proc/on_drop)
	RegisterSignal(parent, COMSIG_ITEM_AFTERATTACK, .proc/on_afterattack)
	RegisterSignal(parent, COMSIG_GUN_FIRED, .proc/on_gun_fired)

/datum/component/poopmadness/UnregisterFromParent()
	if(madman)
		on_drop(parent, madman)
	UnregisterSignal(parent, list(COMSIG_ITEM_EQUIPPED, COMSIG_ITEM_DROPPED, COMSIG_ITEM_ATTACK_OBJ, COMSIG_GUN_FIRED))

/datum/component/poopmadness/proc/on_equip(obj/item/source, mob/equipper, slot)
	SIGNAL_HANDLER

	if(!ishuman(equipper))
		return

	if(!(slot & ITEM_SLOT_HANDS|ITEM_SLOT_LPOCKET|ITEM_SLOT_RPOCKET|ITEM_SLOT_BELT|ITEM_SLOT_BACK))
		return

	madman = equipper
	jumpscare = madman.overlay_fullscreen("poopmadness", /atom/movable/screen/fullscreen/jumpscare)
	jumpscare.flash_scare(madman, 'modular_septic/sound/insanity/poopmadness/evil_laugh.ogg')
	madman.add_chem_effect(CE_PULSE, 1, "poopmadness")
	madman.add_chem_effect(CE_PAINKILLER, 50, "poopmadness")
	madman.add_chem_effect(CE_BRAIN_REGEN, 1, "poopmadness")
	ADD_TRAIT(madman, TRAIT_HEROIN_JUNKIE, "poopmadness")
	ADD_TRAIT(madman, TRAIT_STABLEHEART, "poopmadness")
	RegisterSignal(madman, COMSIG_LIVING_DEATH, .proc/violent_death)
	madman.hallucination += 10 SECONDS
	madman.attributes?.add_attribute_modifier(/datum/attribute_modifier/poopmadness, update = TRUE)
	madman.adjust_blurriness(2)
	if(madman.mind)
		cached_combat_music = madman.mind.combat_music
		madman.mind.combat_music = 'modular_septic/sound/music/combat/evilgun.ogg'
	to_chat(madman, span_bigdanger("You feel an URGE to shoot yourself in the head."))

	START_PROCESSING(SSobj, src)

/datum/component/poopmadness/proc/on_drop(obj/item/source, mob/dropper)
	SIGNAL_HANDLER

	STOP_PROCESSING(SSobj, src)
	madman?.clear_fullscreen("poopmadness")
	madman.remove_chem_effect(CE_PULSE, "poopmadness")
	madman.remove_chem_effect(CE_PAINKILLER, "poopmadness")
	madman.remove_chem_effect(CE_BRAIN_REGEN, "poopmadness")
	REMOVE_TRAIT(madman, TRAIT_HEROIN_JUNKIE, "poopmadness")
	REMOVE_TRAIT(madman, TRAIT_STABLEHEART, "poopmadness")
	UnregisterSignal(madman, COMSIG_LIVING_DEATH)
	madman.attributes?.remove_attribute_modifier(/datum/attribute_modifier/poopmadness, update = TRUE)
	if(cached_combat_music && (madman.mind.combat_music == 'modular_septic/sound/music/combat/evilgun.ogg'))
		madman.mind.combat_music = cached_combat_music
	madman = null
	QDEL_NULL(jumpscare)

/datum/component/poopmadness/proc/on_afterattack(obj/item/source, atom/target, mob/user, proximity_flag)
	SIGNAL_HANDLER

	if(!proximity_flag)
		return

	if(istype(target, /obj/effect/decal/cleanable))
		return consume_blood(source, target, user, proximity_flag)
	if(istype(target, /obj/item/organ) || istype(target, /obj/item/bodypart))
		return consume_organ(source, target, user, proximity_flag)

/datum/component/poopmadness/proc/consume_blood(obj/item/source, atom/target, mob/user, proximity_flag)
	jumpscare.flash_scare(user, null)
	var/obj/effect/decal/cleanable/bloody = target
	if(!bloody.bloodiness)
		qdel(bloody)
		playsound(source, 'modular_septic/sound/insanity/poopmadness/pm9alarm.ogg', 80, vary = FALSE)
		return COMPONENT_CANCEL_ATTACK_CHAIN

	var/obj/item/gun/ballistic/evil_gun = parent
	if(evil_gun.magazine && bloody.bloodiness)
		var/amount_fed = 0
		for(var/i in 1 to min(bloody.bloodiness, evil_gun.magazine.max_ammo - evil_gun.magazine.ammo_count(countempties = FALSE)))
			var/casing = new ammo_type
			if(!evil_gun.magazine.give_round(casing, replace_spent = TRUE))
				qdel(casing)
			else
				amount_fed++
		if(amount_fed)
			jumpscare.flash_scare(user, null)
			evil_gun.say("FED [amount_fed].")
			if(ishuman(user))
				var/mob/living/carbon/human/human_user = user
				if(prob(10))
					human_user.agony_scream()
		qdel(bloody)
		playsound(source, 'modular_septic/sound/insanity/poopmadness/pm9alarm.ogg', 80, vary = FALSE)
	return COMPONENT_CANCEL_ATTACK_CHAIN

/datum/component/poopmadness/proc/consume_organ(obj/item/source, atom/target, mob/user, proximity_flag)
	var/obj/item/gun/ballistic/evil_gun = parent
	if(evil_gun.magazine)
		var/amount_fed = 0
		for(var/i in 1 to (evil_gun.magazine.max_ammo - evil_gun.magazine.ammo_count(countempties = FALSE)))
			var/casing = new ammo_type
			if(!evil_gun.magazine.give_round(casing, replace_spent = TRUE))
				qdel(casing)
			else
				amount_fed++
		if(amount_fed)
			jumpscare.flash_scare(user, null)
			evil_gun.say("FED [amount_fed].")
			if(ishuman(user))
				var/mob/living/carbon/human/human_user = user
				if(prob(10))
					human_user.agony_scream()
		qdel(target)
		playsound(source, 'modular_septic/sound/insanity/poopmadness/pm9alarm.ogg', 80, vary = FALSE)
	return COMPONENT_CANCEL_ATTACK_CHAIN

/datum/component/poopmadness/process(delta_time)
	if(!madman)
		return PROCESS_KILL
	var/epinephrine_amount = madman.reagents.get_reagent_amount(/datum/reagent/medicine/epinephrine)
	if(epinephrine_amount < 15)
		madman.reagents.add_reagent(/datum/reagent/medicine/epinephrine, epinephrine_amount-15)
	var/atropine_amount = madman.reagents.get_reagent_amount(/datum/reagent/medicine/atropine)
	if(atropine_amount < 15)
		madman.reagents.add_reagent(/datum/reagent/medicine/atropine, atropine_amount-15)
	var/minoxidil_amount = madman.reagents.get_reagent_amount(/datum/reagent/medicine/c2/penthrite)
	if(minoxidil_amount < 15)
		madman.reagents.add_reagent(/datum/reagent/medicine/c2/penthrite, minoxidil_amount-15)
	var/spaceacillin_amount = madman.reagents.get_reagent_amount(/datum/reagent/medicine/spaceacillin)
	if(spaceacillin_amount < 15)
		madman.reagents.add_reagent(/datum/reagent/medicine/spaceacillin, spaceacillin_amount-15)
	var/salbutamol_amount = madman.reagents.get_reagent_amount(/datum/reagent/medicine/salbutamol)
	if(salbutamol_amount < 15)
		madman.reagents.add_reagent(/datum/reagent/medicine/salbutamol, salbutamol_amount-50)
	var/viscous_amount = madman.reagents.get_reagent_amount(/datum/reagent/medicine/whiteviscous)
	if(viscous_amount < 50)
		madman.reagents.add_reagent(/datum/reagent/medicine/whiteviscous, viscous_amount-50)
	if(madman.blood_volume < BLOOD_VOLUME_NORMAL)
		madman.blood_volume += 3 * delta_time
	madman.heal_bodypart_damage(2 * delta_time, 2 * delta_time, 2 * delta_time)
	madman.hallucination += 0.5 * delta_time
	if(DT_PROB(1, delta_time))
		jumpscare.flash_scare(madman)

/datum/component/poopmadness/proc/on_gun_fired(obj/item/gun/weapon, mob/living/user, atom/target, params, zone_override)
	SIGNAL_HANDLER

	//nuh uh
	if(!weapon.chambered?.loaded_projectile)
		return

	if(madman && prob(10))
		jumpscare.flash_scare(madman)
	if(prob(2))
		playsound(weapon, 'modular_septic/sound/insanity/poopmadness/atumalaka.ogg', vol = 80, vary = FALSE)
		weapon.audible_message("laughs.", audible_message_flags = EMOTE_MESSAGE)

/datum/component/poopmadness/proc/violent_death(mob/living/source, gibbed)
	SIGNAL_HANDLER

	playsound(source, 'modular_septic/sound/sanity/seamonster.wav', 80, extrarange = 7, vary = FALSE)
	if(!gibbed)
		var/obj/item/bodypart/head = source.get_bodypart(BODY_ZONE_HEAD)
		if(head)
			head.dismember(BRUTE, destroy = TRUE, wounding_type = WOUND_SLASH)
