#define GOLDEN_GARDREN_SHIELD_UPKEEP (0.005 * STANDARD_CELL_CHARGE)
#define GOLDEN_GARDREN_SHIELD_RECHARGE_RATE 15
#define GOLDEN_GARDREN_SHIELD_RECHARGE_DELAY (5 SECONDS)
#define GOLDEN_GARDREN_SHIELD_TOGGLE_DELAY (3 SECONDS)
#define GOLDEN_GARDREN_SHIELD_COLLAPSE_DELAY (15 SECONDS)

/datum/component/golden_gardren_shield
	var/active = FALSE
	var/charge = 300
	var/max_charge = 300
	var/overlay_scale = 1
	var/overlay_offset_w = 0
	var/overlay_offset_z = 4
	COOLDOWN_DECLARE(toggle_cooldown)
	COOLDOWN_DECLARE(recharge_cooldown)

/datum/component/golden_gardren_shield/Initialize(overlay_scale = 1, overlay_offset_w = 0, overlay_offset_z = 4)
	if(!istype(parent, /obj/vehicle/sealed/mecha))
		return COMPONENT_INCOMPATIBLE
	src.overlay_scale = overlay_scale
	src.overlay_offset_w = overlay_offset_w
	src.overlay_offset_z = overlay_offset_z

/datum/component/golden_gardren_shield/RegisterWithParent()
	RegisterSignal(parent, COMSIG_ATOM_UPDATE_OVERLAYS, PROC_REF(on_update_overlays))

/datum/component/golden_gardren_shield/UnregisterFromParent()
	UnregisterSignal(parent, COMSIG_ATOM_UPDATE_OVERLAYS)

/datum/component/golden_gardren_shield/Destroy(force)
	STOP_PROCESSING(SSobj, src)
	return ..()

/datum/component/golden_gardren_shield/process(seconds_per_tick)
	var/obj/vehicle/sealed/mecha/mech = parent
	if(active)
		if(!mech.cell || !mech.use_energy(GOLDEN_GARDREN_SHIELD_UPKEEP * seconds_per_tick))
			set_active(FALSE, collapsed = TRUE)
		return
	if(!COOLDOWN_FINISHED(src, recharge_cooldown))
		return
	charge = min(max_charge, charge + GOLDEN_GARDREN_SHIELD_RECHARGE_RATE * seconds_per_tick)
	if(charge >= max_charge)
		return PROCESS_KILL

/datum/component/golden_gardren_shield/proc/absorb(damage_amount, damage_type)
	if(!active || damage_amount <= 0 || (damage_type != BRUTE && damage_type != BURN))
		return damage_amount
	var/absorbed = min(damage_amount, charge)
	charge -= absorbed
	COOLDOWN_START(src, recharge_cooldown, GOLDEN_GARDREN_SHIELD_RECHARGE_DELAY)
	playsound(parent, 'sound/vehicles/mecha/mech_shield_deflect.ogg', 60, TRUE)
	if(charge <= 0)
		set_active(FALSE, collapsed = TRUE)
	return damage_amount - absorbed

/datum/component/golden_gardren_shield/proc/toggle(mob/user)
	var/obj/vehicle/sealed/mecha/mech = parent
	if(active)
		set_active(FALSE)
		return TRUE
	if(!COOLDOWN_FINISHED(src, toggle_cooldown))
		mech.balloon_alert(user, "щит перезаряжается!")
		return FALSE
	if(charge <= 0)
		mech.balloon_alert(user, "щит разряжен!")
		return FALSE
	if(!mech.has_charge(GOLDEN_GARDREN_SHIELD_UPKEEP))
		mech.balloon_alert(user, "мало энергии!")
		return FALSE
	set_active(TRUE)
	return TRUE

/datum/component/golden_gardren_shield/proc/drop_if_unmanned()
	var/obj/vehicle/sealed/mecha/mech = parent
	if(active && !mech.return_amount_of_controllers_with_flag(VEHICLE_CONTROL_EQUIPMENT))
		set_active(FALSE)

/datum/component/golden_gardren_shield/proc/set_active(new_state, collapsed = FALSE)
	if(active == new_state)
		return
	var/obj/vehicle/sealed/mecha/mech = parent
	active = new_state
	if(active)
		START_PROCESSING(SSobj, src)
		playsound(mech, 'sound/vehicles/mecha/mech_shield_raise.ogg', 50, FALSE)
		to_chat(mech.occupants, span_notice("Щит поднят."))
	else
		COOLDOWN_START(src, toggle_cooldown, collapsed ? GOLDEN_GARDREN_SHIELD_COLLAPSE_DELAY : GOLDEN_GARDREN_SHIELD_TOGGLE_DELAY)
		COOLDOWN_START(src, recharge_cooldown, GOLDEN_GARDREN_SHIELD_RECHARGE_DELAY)
		playsound(mech, 'sound/vehicles/mecha/mech_shield_drop.ogg', 50, FALSE)
		to_chat(mech.occupants, collapsed ? span_danger("Щит пробит!") : span_notice("Щит опущен."))
	mech.log_message("Shield [active ? "raised" : "lowered"][collapsed ? " (collapsed)" : ""], charge [charge].", LOG_MECHA)
	golden_gardren_update_buttons(mech, /datum/action/vehicle/sealed/mecha/golden_gardren_shield)
	mech.update_appearance(UPDATE_OVERLAYS)

/datum/component/golden_gardren_shield/proc/on_update_overlays(atom/source, list/overlays)
	SIGNAL_HANDLER
	if(!active)
		return
	var/mutable_appearance/glow = mutable_appearance('icons/mob/effects/durand_shield.dmi', "shield")
	if(overlay_scale != 1)
		glow.transform = matrix().Scale(overlay_scale)
	glow.pixel_w = overlay_offset_w
	glow.pixel_z = overlay_offset_z
	overlays += glow

/datum/action/vehicle/sealed/mecha/golden_gardren_shield
	name = "Щит"
	desc = "Поднять или опустить энергощит. Щит гасит урон собственным зарядом, тратит энергию батареи и после пробития долго восстанавливается."
	button_icon_state = "mech_defense_mode_off"

/datum/action/vehicle/sealed/mecha/golden_gardren_shield/Trigger(mob/clicker, trigger_flags)
	. = ..()
	if(!.)
		return
	var/datum/component/golden_gardren_shield/shield = chassis?.GetComponent(/datum/component/golden_gardren_shield)
	if(!shield || !(owner in chassis.return_controllers_with_flag(VEHICLE_CONTROL_EQUIPMENT)))
		return
	shield.toggle(owner)

/datum/action/vehicle/sealed/mecha/golden_gardren_shield/apply_button_icon(atom/movable/screen/movable/action_button/current_button, force)
	var/datum/component/golden_gardren_shield/shield = chassis?.GetComponent(/datum/component/golden_gardren_shield)
	button_icon_state = "mech_defense_mode_[shield?.active ? "on" : "off"]"
	return ..()

#undef GOLDEN_GARDREN_SHIELD_UPKEEP
#undef GOLDEN_GARDREN_SHIELD_RECHARGE_RATE
#undef GOLDEN_GARDREN_SHIELD_RECHARGE_DELAY
#undef GOLDEN_GARDREN_SHIELD_TOGGLE_DELAY
#undef GOLDEN_GARDREN_SHIELD_COLLAPSE_DELAY
