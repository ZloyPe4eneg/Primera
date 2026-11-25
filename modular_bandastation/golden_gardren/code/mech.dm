/obj/vehicle/sealed/mecha/golden_gardren_base
	abstract_type = /obj/vehicle/sealed/mecha/golden_gardren_base
	SET_BASE_PIXEL(-4, 0)
	armor_type = /datum/armor/mecha_marauder
	mecha_flags = CAN_STRAFE | IS_ENCLOSED | HAS_LIGHTS | BEACON_TRACKABLE
	mech_type = EXOSUIT_MODULE_SAVANNAH
	max_temperature = 30000
	destruction_sleep_duration = 40
	exit_delay = 40
	equip_by_category = list(
		MECHA_L_ARM = /obj/item/mecha_parts/mecha_equipment/weapon/energy/laser,
		MECHA_R_ARM = /obj/item/mecha_parts/mecha_equipment/weapon/ballistic/lmg,
		MECHA_UTILITY = list(/obj/item/mecha_parts/mecha_equipment/thrusters/ion, /obj/item/mecha_parts/mecha_equipment/repair_droid),
		MECHA_POWER = list(),
		MECHA_ARMOR = list(/obj/item/mecha_parts/mecha_equipment/armor/antiproj_armor_booster),
	)
	max_equip_by_category = list(
		MECHA_L_ARM = 1,
		MECHA_R_ARM = 1,
		MECHA_UTILITY = 3,
		MECHA_POWER = 1,
		MECHA_ARMOR = 1,
	)
	factory_cell_type = /obj/item/stock_parts/power_store/cell/bluespace
	var/heavy_emergency_smoke = FALSE

/obj/vehicle/sealed/mecha/golden_gardren_base/Initialize(mapload, built_manually)
	. = ..()
	AddComponent(/datum/component/golden_gardren_ejection, heavy_emergency_smoke)

/obj/vehicle/sealed/mecha/golden_gardren_base/update_overlays()
	. = ..()
	if(length(occupants))
		. += emissive_appearance(icon, "[base_icon_state]-glow", src, alpha = src.alpha)

/obj/vehicle/sealed/mecha/golden_gardren_base/remove_occupant(mob/driver)
	. = ..()
	var/datum/component/golden_gardren_ejection/ejection = GetComponent(/datum/component/golden_gardren_ejection)
	ejection?.clear_landing_choice(driver)
	drop_unmanned_systems()

/obj/vehicle/sealed/mecha/golden_gardren_base/proc/drop_unmanned_systems()
	var/datum/component/golden_gardren_shield/shield = GetComponent(/datum/component/golden_gardren_shield)
	shield?.drop_if_unmanned()
	if(!return_amount_of_controllers_with_flag(VEHICLE_CONTROL_MELEE))
		golden_gardren_release_fist(src)

/obj/vehicle/sealed/mecha/golden_gardren_base/take_damage(damage_amount, damage_type = BRUTE, damage_flag = "", sound_effect = TRUE, attack_dir, armour_penetration = 0)
	var/datum/component/golden_gardren_shield/shield = GetComponent(/datum/component/golden_gardren_shield)
	if(shield?.active && damage_amount > 0)
		damage_amount = shield.absorb(damage_amount, damage_type)
		if(damage_amount <= 0)
			return 0
	return ..()

/obj/vehicle/sealed/mecha/golden_gardren_base/user_unbuckle_mob(mob/living/buckled_mob, mob/user)
	if(golden_gardren_fist_intercept_unbuckle(src, buckled_mob, user))
		return null
	return ..()

/obj/vehicle/sealed/mecha/golden_gardren_base/on_mouseclick(mob/user, atom/target, list/modifiers)
	var/datum/component/golden_gardren_ejection/ejection = GetComponent(/datum/component/golden_gardren_ejection)
	if(ejection?.handle_click(user, target))
		return COMSIG_MOB_CANCEL_CLICKON
	return ..()

/obj/vehicle/sealed/mecha/golden_gardren_base/atom_destruction()
	var/datum/component/golden_gardren_ejection/ejection = GetComponent(/datum/component/golden_gardren_ejection)
	ejection?.eject(destroying = TRUE)
	return ..()

/obj/vehicle/sealed/mecha/golden_gardren_base/proc/transfer_support_parts(obj/vehicle/sealed/mecha/golden_gardren_base/destination)
	for(var/obj/item/stock_parts/part in list(scanmod, capacitor, servo))
		part.forceMove(destination)
	locate_parts()
	destination.locate_parts()

/obj/vehicle/sealed/mecha/golden_gardren_base/proc/transfer_pilot(obj/vehicle/sealed/mecha/golden_gardren_base/destination, mob/living/pilot)
	if(!is_occupant(pilot) || pilot.loc != src)
		return FALSE
	SStgui.close_user_uis(pilot, src)
	if(!destination.mob_enter(pilot, silent = TRUE))
		return FALSE
	pilot.update_mouse_pointer()
	destination.set_mouse_pointer()
	return TRUE

/obj/vehicle/sealed/mecha/golden_gardren_base/proc/get_machine_gun()
	var/obj/item/mecha_parts/mecha_equipment/weapon/ballistic/lmg/gun = equip_by_category[MECHA_R_ARM]
	return istype(gun) ? gun : null

/proc/golden_gardren_transfer_ammo(obj/item/mecha_parts/mecha_equipment/weapon/ballistic/lmg/source, obj/item/mecha_parts/mecha_equipment/weapon/ballistic/lmg/destination, limit = INFINITY)
	if(!source || !destination)
		return
	var/loaded = max(0, source.projectiles)
	var/magazine_space = max(0, initial(destination.projectiles) - destination.projectiles)
	var/reserve_space = max(0, destination.projectiles_cache_max - destination.projectiles_cache)
	var/transferred = min(limit, loaded + source.projectiles_cache, magazine_space + reserve_space)
	if(transferred <= 0)
		return
	var/from_magazine = min(transferred, loaded)
	var/to_magazine = min(transferred, magazine_space)
	source.projectiles -= from_magazine
	source.projectiles_cache -= transferred - from_magazine
	destination.projectiles += to_magazine
	destination.projectiles_cache += transferred - to_magazine

/obj/item/mecha_parts/mecha_equipment/weapon/energy/laser/heavy/golden_gardren
	equip_cooldown = 1 SECONDS

/obj/item/mecha_parts/mecha_equipment/weapon/ballistic/lmg/golden_gardren
	projectiles_cache = 900
	projectiles_cache_max = 1800
