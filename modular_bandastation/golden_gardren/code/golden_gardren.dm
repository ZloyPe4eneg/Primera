#define GOLDEN_GARDREN_CRITICAL_INTEGRITY 0.3

/obj/vehicle/sealed/mecha/golden_gardren
	parent_type = /obj/vehicle/sealed/mecha/golden_gardren_base
	name = "\improper Golden-Gardren"
	desc = "Громадная боевая машина: Голден сидит в люке Гардрена, как голова на плечах, и возвышается над обычными мехами. Управляется двумя пилотами."
	icon = 'modular_bandastation/golden_gardren/icons/golden_gardren.dmi'
	icon_state = "golden_gardren"
	base_icon_state = "golden_gardren"
	SET_BASE_PIXEL(-8, 0)
	movedelay = 3
	max_integrity = 450
	armor_type = /datum/armor/mecha_golden_gardren
	force = 45
	max_occupants = 2
	equipment_action_control_flag = VEHICLE_CONTROL_EQUIPMENT
	factory_cell_type = /obj/item/stock_parts/power_store/cell/infinite/abductor
	removable_cell = FALSE
	heavy_emergency_smoke = TRUE
	wreckage = /obj/structure/mecha_wreckage/golden_gardren
	equip_by_category = list(
		MECHA_L_ARM = /obj/item/mecha_parts/mecha_equipment/weapon/energy/laser/heavy/golden_gardren,
		MECHA_R_ARM = /obj/item/mecha_parts/mecha_equipment/weapon/ballistic/lmg/golden_gardren,
		MECHA_UTILITY = list(/obj/item/mecha_parts/mecha_equipment/thrusters/ion, /obj/item/mecha_parts/mecha_equipment/repair_droid),
		MECHA_POWER = list(),
		MECHA_ARMOR = list(/obj/item/mecha_parts/mecha_equipment/armor/antiproj_armor_booster),
	)
	var/obj/vehicle/sealed/mecha/golden/docked_golden
	var/obj/vehicle/sealed/mecha/gardren/docked_gardren
	var/datum/golden_gardren_cockpit/cockpit

/datum/armor/mecha_golden_gardren
	melee = 90
	bullet = 90
	laser = 90
	energy = 45
	bomb = 75
	fire = 100
	acid = 100

/obj/vehicle/sealed/mecha/golden_gardren/Initialize(mapload, built_manually)
	. = ..()
	AddComponent(/datum/component/golden_gardren_shield, 1.5, 8, 12)
	AddComponent(/datum/component/golden_gardren_phasing)
	AddComponent(/datum/component/golden_gardren_fist, 20)

/obj/vehicle/sealed/mecha/golden_gardren/Destroy()
	QDEL_NULL(cockpit)
	var/datum/component/golden_gardren_ejection/ejection = GetComponent(/datum/component/golden_gardren_ejection)
	ejection?.eject(use_capsules = FALSE)
	QDEL_NULL(docked_golden)
	QDEL_NULL(docked_gardren)
	return ..()

/obj/vehicle/sealed/mecha/golden_gardren/generate_actions()
	. = ..()
	initialize_passenger_action_type(/datum/action/vehicle/sealed/mecha/golden_gardren_cockpit)
	initialize_passenger_action_type(/datum/action/vehicle/sealed/mecha/golden_gardren_swap_seat)
	initialize_passenger_action_type(/datum/action/vehicle/sealed/mecha/golden_gardren_emergency_eject)
	initialize_passenger_action_type(/datum/action/vehicle/sealed/mecha/golden_gardren_separate)
	initialize_controller_action_type(/datum/action/vehicle/sealed/mecha/golden_gardren_phasing, VEHICLE_CONTROL_DRIVE)
	initialize_controller_action_type(/datum/action/vehicle/sealed/mecha/golden_gardren_fist, VEHICLE_CONTROL_MELEE)
	initialize_controller_action_type(/datum/action/vehicle/sealed/mecha/golden_gardren_fist_squeeze, VEHICLE_CONTROL_MELEE)
	initialize_controller_action_type(/datum/action/vehicle/sealed/mecha/mech_view_stats, VEHICLE_CONTROL_EQUIPMENT)
	initialize_controller_action_type(/datum/action/vehicle/sealed/mecha/golden_gardren_shield, VEHICLE_CONTROL_EQUIPMENT)
	initialize_controller_action_type(/datum/action/vehicle/sealed/mecha/ivanov_strike/golden_gardren, VEHICLE_CONTROL_EQUIPMENT)

/obj/vehicle/sealed/mecha/golden_gardren/auto_assign_occupant_flags(mob/new_occupant)
	if(driver_amount() < max_drivers)
		add_control_flags(new_occupant, GOLDEN_GARDREN_MAIN_SEAT)
	else
		add_control_flags(new_occupant, GOLDEN_GARDREN_WEAPONS_SEAT)

/obj/vehicle/sealed/mecha/golden_gardren/proc/assign_seat(mob/occupant, main_seat)
	var/seat_flags = main_seat ? GOLDEN_GARDREN_MAIN_SEAT : GOLDEN_GARDREN_WEAPONS_SEAT
	if(!is_occupant(occupant) || occupants[occupant] == seat_flags)
		return
	remove_control_flags(occupant, ALL)
	remove_all_equipment_actions(occupant)
	add_control_flags(occupant, seat_flags)
	generate_equipment_actions(occupant)
	drop_unmanned_systems()
	update_appearance()

/obj/vehicle/sealed/mecha/golden_gardren/proc/find_seat_occupant(control_flag)
	for(var/mob/occupant as anything in occupants)
		if(occupants[occupant] & control_flag)
			return occupant
	return null

/obj/vehicle/sealed/mecha/golden_gardren/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	var/mob/user = ui?.user
	if(user && is_occupant(user))
		var/static/list/weapons_seat_actions = list("select_module", "equip_act", "toggle_safety")
		if(occupants[user] & VEHICLE_CONTROL_SETTINGS)
			if(action == "equip_act")
				return FALSE
		else if(!(action in weapons_seat_actions))
			return FALSE
	return ..()

/obj/vehicle/sealed/mecha/golden_gardren/take_damage(damage_amount, damage_type = BRUTE, damage_flag = "", sound_effect = TRUE, attack_dir, armour_penetration = 0)
	var/critical_integrity = max_integrity * GOLDEN_GARDREN_CRITICAL_INTEGRITY
	var/was_above_critical = get_integrity() > critical_integrity
	. = ..()
	if(was_above_critical && !QDELETED(src) && get_integrity() > 0 && get_integrity() <= critical_integrity)
		log_message("Integrity critical.", LOG_MECHA)
		to_chat(occupants, span_userdanger("КРИТИЧЕСКИЕ ПОВРЕЖДЕНИЯ! Корпус вот-вот разрушится — готовьтесь к аварийному катапультированию."))
		playsound(src, 'sound/machines/warning-buzzer.ogg', 75, FALSE)

/obj/vehicle/sealed/mecha/golden_gardren/proc/assemble(obj/vehicle/sealed/mecha/golden/golden, obj/vehicle/sealed/mecha/gardren/gardren, mob/living/golden_pilot, mob/living/gardren_pilot)
	if(!golden_gardren_pilot_ready(golden, golden_pilot) || !golden_gardren_pilot_ready(gardren, gardren_pilot))
		return FALSE
	if(!gardren.transfer_pilot(src, gardren_pilot))
		return FALSE
	if(!golden.transfer_pilot(src, golden_pilot))
		transfer_pilot(gardren, gardren_pilot)
		return FALSE
	assign_seat(gardren_pilot, main_seat = TRUE)
	assign_seat(golden_pilot, main_seat = FALSE)

	if(!cell)
		cell = new factory_cell_type(src)
	gardren.transfer_support_parts(src)
	for(var/obj/item/mecha_parts/mecha_equipment/equipment as anything in flat_equipment)
		equipment.detachable = FALSE
	var/obj/item/mecha_parts/mecha_equipment/weapon/ballistic/lmg/gun = get_machine_gun()
	if(gun)
		gun.projectiles = 0
		gun.projectiles_cache = 0
		golden_gardren_transfer_ammo(golden.get_machine_gun(), gun)
		golden_gardren_transfer_ammo(gardren.get_machine_gun(), gun)

	max_integrity = golden.max_integrity + gardren.max_integrity
	update_integrity(golden.get_integrity() + gardren.get_integrity())

	dock_component(golden)
	dock_component(gardren)
	docked_golden = golden
	docked_gardren = gardren
	diag_hud_set_mechhealth()
	update_appearance()
	log_message("Combined from [golden] ([key_name(golden_pilot)]) and [gardren] ([key_name(gardren_pilot)]).", LOG_MECHA)
	return TRUE

/obj/vehicle/sealed/mecha/golden_gardren/proc/dock_component(obj/vehicle/sealed/mecha/component)
	golden_gardren_release_fist(component)
	var/datum/component/golden_gardren_phasing/phasing = component.GetComponent(/datum/component/golden_gardren_phasing)
	phasing?.set_active(FALSE)
	if(component.mecha_flags & LIGHTS_ON)
		component.toggle_lights()
	component.forceMove(src)
	component.completely_disabled = TRUE
	STOP_PROCESSING(SSobj, component)
	RegisterSignal(component, COMSIG_QDELETING, PROC_REF(on_docked_component_deleted))

/obj/vehicle/sealed/mecha/golden_gardren/proc/on_docked_component_deleted(datum/source)
	SIGNAL_HANDLER
	if(source == docked_golden)
		docked_golden = null
	else if(source == docked_gardren)
		docked_gardren = null

/obj/structure/mecha_wreckage/golden_gardren
	name = "\improper Golden-Gardren wreckage"
	desc = "Груда искорёженного золочёного металла — всё, что осталось от Голден-Гардрена. Восстановить невозможно, но что-то ещё можно снять."
	icon = 'modular_bandastation/golden_gardren/icons/golden_gardren.dmi'
	icon_state = "golden_gardren-broken"
	SET_BASE_PIXEL(-8, 0)
	welder_salvage = list(/obj/item/stack/sheet/mineral/gold, /obj/item/stack/sheet/plasteel, /obj/item/stack/sheet/iron, /obj/item/stack/rods)
	salvage_num = 8

#undef GOLDEN_GARDREN_CRITICAL_INTEGRITY
