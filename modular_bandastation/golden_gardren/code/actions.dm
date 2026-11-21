/proc/golden_gardren_update_buttons(obj/vehicle/sealed/mecha/mech, action_type)
	for(var/mob/occupant as anything in mech.occupants)
		var/datum/action/button = LAZYACCESSASSOC(mech.occupant_actions, occupant, action_type)
		button?.build_all_button_icons()

/datum/action/vehicle/sealed/mecha/golden_gardren_swap_seat
	name = "Сменить место"
	desc = "Перебраться на свободное место второго пилота."
	button_icon_state = "mech_seat_swap"

/datum/action/vehicle/sealed/mecha/golden_gardren_swap_seat/Trigger(mob/clicker, trigger_flags)
	. = ..()
	if(!.)
		return
	var/obj/vehicle/sealed/mecha/golden_gardren/mech = chassis
	if(!istype(mech) || !(owner in mech.occupants))
		return
	if(mech.occupant_amount() >= mech.max_occupants)
		mech.balloon_alert(owner, "второе место занято!")
		return
	INVOKE_ASYNC(src, PROC_REF(swap_seat), mech)

/datum/action/vehicle/sealed/mecha/golden_gardren_swap_seat/proc/swap_seat(obj/vehicle/sealed/mecha/golden_gardren/mech)
	var/mob/living/pilot = owner
	if(QDELETED(mech) || QDELETED(pilot) || !mech.is_occupant(pilot) || mech.is_currently_ejecting)
		return
	mech.balloon_alert(pilot, "перебираюсь...")
	mech.is_currently_ejecting = TRUE
	var/moved = do_after(pilot, mech.has_gravity() ? mech.exit_delay : 0, target = mech)
	if(QDELETED(mech))
		return
	mech.is_currently_ejecting = FALSE
	if(QDELETED(pilot) || !mech.is_occupant(pilot))
		return
	if(!moved)
		mech.balloon_alert(pilot, "прервано!")
		return
	if(mech.occupant_amount() >= mech.max_occupants)
		return
	var/to_main_seat = !mech.is_driver(pilot)
	mech.assign_seat(pilot, main_seat = to_main_seat)
	mech.balloon_alert(pilot, to_main_seat ? "место пилота" : "место стрелка")

/datum/action/vehicle/sealed/mecha/ivanov_strike/golden_gardren
	name = "Ракетный удар"
	strike_pod_type = /obj/structure/closet/supplypod/podspawn/golden_gardren_missile
	strike_explosion_size = list(0, 0, 2, 2)

/datum/action/vehicle/sealed/mecha/ivanov_strike/golden_gardren/on_melee_click(datum/source, mob/living/pilot, atom/target, on_cooldown, is_adjacent)
	return NONE

/datum/action/vehicle/sealed/mecha/ivanov_strike/golden_gardren/on_equipment_click(datum/source, mob/living/pilot, atom/target)
	if(pilot != owner)
		return NONE
	var/datum/component/golden_gardren_phasing/phasing = chassis.GetComponent(/datum/component/golden_gardren_phasing)
	if(!phasing?.active)
		..()
	return COMPONENT_CANCEL_EQUIPMENT_CLICK

/obj/structure/closet/supplypod/podspawn/golden_gardren_missile/pre_open()
	var/turf/impact = get_turf(src)
	. = ..()
	if(!impact)
		return
	for(var/turf/scorched in range(1, impact))
		if(isopenturf(scorched) && !isspaceturf(scorched))
			if(scorched == impact || prob(50))
				scorched.break_tile()
			else
				scorched.burn_tile()
			if(!(locate(/obj/effect/hotspot) in scorched))
				new /obj/effect/hotspot(scorched)
		for(var/mob/living/victim in scorched)
			victim.apply_damage(20, BURN, spread_damage = TRUE)
			victim.adjust_fire_stacks(3)
			victim.ignite_mob()
