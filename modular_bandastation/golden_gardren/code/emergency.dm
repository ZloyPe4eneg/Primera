#define GOLDEN_GARDREN_EJECT_DELAY (5 SECONDS)
#define GOLDEN_GARDREN_EJECT_RANGE 5
#define GOLDEN_GARDREN_EJECT_KNOCKDOWN (2 SECONDS)
#define GOLDEN_GARDREN_CAPSULE_TRANSIT (1 SECONDS)
#define GOLDEN_GARDREN_CAPSULE_FALL (0.4 SECONDS)
#define GOLDEN_GARDREN_CAPSULE_OPEN (0.5 SECONDS)

/datum/component/golden_gardren_ejection
	var/timer
	var/list/landings
	var/list/markers
	var/dying = FALSE
	var/smoke_type = /particles/smoke/burning
	var/smoke_key
	var/heavy_smoke = FALSE

/datum/component/golden_gardren_ejection/Initialize(heavy_smoke = FALSE)
	if(!istype(parent, /obj/vehicle/sealed/mecha))
		return COMPONENT_INCOMPATIBLE
	src.heavy_smoke = heavy_smoke
	if(heavy_smoke)
		smoke_type = /particles/smoke/burning/golden_gardren
	smoke_key = "golden_gardren_ejection_[smoke_type]"

/datum/component/golden_gardren_ejection/RegisterWithParent()
	RegisterSignal(parent, COMSIG_ATOM_TAKE_DAMAGE, PROC_REF(on_take_damage))

/datum/component/golden_gardren_ejection/UnregisterFromParent()
	var/obj/vehicle/sealed/mecha/mech = parent
	mech.remove_shared_particles(smoke_key)
	UnregisterSignal(parent, COMSIG_ATOM_TAKE_DAMAGE)

/datum/component/golden_gardren_ejection/Destroy(force)
	deltimer(timer)
	timer = null
	for(var/mob/pilot as anything in markers?.Copy())
		clear_landing_choice(pilot)
	landings = null
	return ..()

/datum/component/golden_gardren_ejection/proc/on_take_damage(datum/source, damage_amount, damage_type, damage_flag, sound_effect, attack_dir, armour_penetration)
	SIGNAL_HANDLER
	var/obj/vehicle/sealed/mecha/mech = parent
	if(dying)
		return COMPONENT_NO_TAKE_DAMAGE
	if(damage_amount < mech.get_integrity() || !LAZYLEN(mech.occupants))
		return NONE
	start_dying()
	return COMPONENT_NO_TAKE_DAMAGE

/datum/component/golden_gardren_ejection/proc/start_dying()
	var/obj/vehicle/sealed/mecha/mech = parent
	dying = TRUE
	mech.update_integrity(1)
	mech.completely_disabled = TRUE
	mech.log_message("Took a lethal blow, blowing up once the ejection countdown runs out.", LOG_MECHA)
	mech.visible_message(span_userdanger("[mech.declent_ru(NOMINATIVE)] охвачен огнём и вот-вот взорвётся!"))
	mech.add_shared_particles(smoke_type, smoke_key)
	mech.spark_system?.start()
	playsound(mech, 'sound/machines/warning-buzzer.ogg', 100, FALSE)
	start()

/datum/component/golden_gardren_ejection/proc/finish_countdown()
	if(!dying)
		eject()
		return
	var/obj/vehicle/sealed/mecha/mech = parent
	mech.update_integrity(0)
	mech.atom_destruction()

/datum/component/golden_gardren_ejection/proc/start(mob/user)
	var/obj/vehicle/sealed/mecha/mech = parent
	if(timer)
		if(user)
			mech.balloon_alert(user, "катапультирование уже идёт!")
		return FALSE
	mech.log_message("[user ? key_name(user) : "Lethal damage"] started the emergency ejection.", LOG_MECHA)
	to_chat(mech.occupants, span_userdanger("АВАРИЙНОЕ КАТАПУЛЬТИРОВАНИЕ через [DisplayTimeText(GOLDEN_GARDREN_EJECT_DELAY)]! Кликните по клетке, куда сядет ваша капсула: не дальше [GOLDEN_GARDREN_EJECT_RANGE] клеток и в зоне видимости. Без выбора капсула сядет рядом с мехом."))
	playsound(mech, 'sound/machines/warning-buzzer.ogg', 75, FALSE)
	for(var/mob/pilot as anything in mech.occupants)
		set_landing_cursor(pilot, aiming = TRUE)
	timer = addtimer(CALLBACK(src, PROC_REF(finish_countdown)), GOLDEN_GARDREN_EJECT_DELAY, TIMER_STOPPABLE)
	return TRUE

/datum/component/golden_gardren_ejection/proc/handle_click(mob/user, atom/target)
	if(!timer)
		return FALSE
	choose_landing(user, target)
	return TRUE

/datum/component/golden_gardren_ejection/proc/landing_blocker(turf/landing)
	var/turf/center = get_turf(parent)
	if(!isturf(landing) || !center || landing.z != center.z)
		return "сюда не долететь"
	if(landing == center)
		return "капсула не сядет на сам мех"
	if(get_dist(center, landing) > GOLDEN_GARDREN_EJECT_RANGE)
		return "слишком далеко"
	if(!can_see(center, landing, GOLDEN_GARDREN_EJECT_RANGE))
		return "нет прямой видимости"
	if(landing.is_blocked_turf(exclude_mobs = TRUE))
		return "место занято"
	if(!is_safe_turf(landing, extended_safety_checks = TRUE))
		return "опасное место"
	return null

/datum/component/golden_gardren_ejection/proc/choose_landing(mob/user, atom/target)
	var/obj/vehicle/sealed/mecha/mech = parent
	if(!timer || !mech.is_occupant(user))
		return FALSE
	var/turf/landing = get_turf(target)
	var/blocker = landing_blocker(landing)
	if(blocker)
		mech.balloon_alert(user, blocker)
		return FALSE
	for(var/mob/other_pilot as anything in landings)
		if(other_pilot != user && landings[other_pilot] == landing)
			mech.balloon_alert(user, "место занято другой капсулой")
			return FALSE
	remove_landing_marker(user)
	LAZYSET(landings, user, landing)
	var/image/marker = image('icons/mob/telegraphing/telegraph.dmi', landing, "target_circle")
	SET_PLANE_EXPLICIT(marker, ABOVE_GAME_PLANE, landing)
	LAZYSET(markers, user, marker)
	user.client?.images += marker
	mech.balloon_alert(user, "место посадки выбрано")
	return TRUE

/datum/component/golden_gardren_ejection/proc/clear_landing_choice(mob/user)
	remove_landing_marker(user)
	LAZYREMOVE(landings, user)
	set_landing_cursor(user, aiming = FALSE)

/datum/component/golden_gardren_ejection/proc/remove_landing_marker(mob/user)
	var/image/marker = LAZYACCESS(markers, user)
	if(marker)
		user.client?.images -= marker
	LAZYREMOVE(markers, user)

/datum/component/golden_gardren_ejection/proc/set_landing_cursor(mob/user, aiming)
	if(!user.client)
		return
	user.client.mouse_override_icon = aiming ? 'icons/effects/mouse_pointers/supplypod_down_target.dmi' : null
	user.update_mouse_pointer()

/datum/component/golden_gardren_ejection/proc/eject(use_capsules = TRUE, destroying = FALSE)
	var/obj/vehicle/sealed/mecha/mech = parent
	deltimer(timer)
	timer = null
	mech.remove_shared_particles(smoke_key)
	var/list/taken_turfs = list()
	var/launched = FALSE
	for(var/mob/living/pilot as anything in mech.occupants?.Copy())
		var/turf/landing = LAZYACCESS(landings, pilot)
		if(!landing || landing_blocker(landing) || (landing in taken_turfs))
			landing = golden_gardren_find_exit_turf(mech, taken_turfs)
		mech.mob_exit(pilot, silent = TRUE, forced = TRUE)
		if(QDELETED(pilot))
			continue
		if(use_capsules)
			var/capsule_time = landing ? GOLDEN_GARDREN_CAPSULE_TRANSIT + GOLDEN_GARDREN_CAPSULE_FALL + GOLDEN_GARDREN_CAPSULE_OPEN : 0
			pilot.Knockdown(GOLDEN_GARDREN_EJECT_KNOCKDOWN + capsule_time)
		if(!landing)
			continue
		taken_turfs += landing
		mech.log_message("[key_name(pilot)] ejected to [AREACOORD(landing)].", LOG_MECHA)
		if(use_capsules)
			launch_capsule(pilot, landing)
			launched = TRUE
		else
			pilot.forceMove(landing)
	if(launched)
		mech.visible_message(span_warning("Из [mech.declent_ru(GENITIVE)] с грохотом вылетают спасательные капсулы!"))
		playsound(mech, 'sound/vehicles/mecha/hydraulic.ogg', 75, TRUE)
	if(heavy_smoke && destroying)
		var/turf/origin = get_turf(mech)
		if(origin)
			new /obj/effect/temp_visual/golden_gardren_smoke(origin)

/datum/component/golden_gardren_ejection/proc/launch_capsule(mob/living/pilot, turf/landing)
	return podspawn(list(
		"target" = landing,
		"style" = /datum/pod_style/advanced,
		"spawn" = pilot,
		"explosionSize" = list(0, 0, 0, 0),
		"bluespace" = TRUE,
		"delays" = list(
			POD_TRANSIT = GOLDEN_GARDREN_CAPSULE_TRANSIT,
			POD_FALLING = GOLDEN_GARDREN_CAPSULE_FALL,
			POD_OPENING = GOLDEN_GARDREN_CAPSULE_OPEN,
			POD_LEAVING = 1 SECONDS,
		),
	))

/proc/golden_gardren_is_ejecting(obj/vehicle/sealed/mecha/mech)
	var/datum/component/golden_gardren_ejection/ejection = mech.GetComponent(/datum/component/golden_gardren_ejection)
	return !!ejection?.timer

/proc/golden_gardren_find_exit_turf(atom/mech, list/exclude, first_available = FALSE)
	var/turf/center = get_turf(mech)
	if(!center)
		return null
	var/list/safe_turfs
	var/list/passable_turfs
	for(var/turf/candidate in orange(1, center))
		if((candidate in exclude) || candidate.is_blocked_turf(exclude_mobs = TRUE) || !center.Adjacent(candidate))
			continue
		if(first_available)
			return candidate
		if(is_safe_turf(candidate, extended_safety_checks = TRUE))
			LAZYADD(safe_turfs, candidate)
		else if(!length(safe_turfs))
			LAZYADD(passable_turfs, candidate)
	if(length(safe_turfs))
		return pick(safe_turfs)
	if(length(passable_turfs))
		return pick(passable_turfs)
	return null

/datum/action/vehicle/sealed/mecha/golden_gardren_emergency_eject
	name = "АВАРИЙНОЕ КАТАПУЛЬТИРОВАНИЕ"
	desc = "Запускает отсчёт до выброса пилотов в капсулах. До выброса каждый пилот может кликом выбрать безопасную клетку посадки поблизости. Отменить нельзя."
	button_icon = 'modular_bandastation/golden_gardren/icons/actions.dmi'
	button_icon_state = "emergency_eject"

/datum/action/vehicle/sealed/mecha/golden_gardren_emergency_eject/Trigger(mob/clicker, trigger_flags)
	. = ..()
	if(!.)
		return
	if(!chassis || !(owner in chassis.occupants))
		return
	var/datum/component/golden_gardren_ejection/ejection = chassis.GetComponent(/datum/component/golden_gardren_ejection)
	ejection?.start(owner)

/particles/smoke/burning/golden_gardren
	width = 124
	height = 144
	count = 176
	spawning = 12
	lifespan = 2.4 SECONDS
	fade = 1.8 SECONDS
	scale = list(1.1, 1.1)
	position = generator(GEN_VECTOR, list(-12, 7, 0), list(12, 19, 0), UNIFORM_RAND)
	velocity = generator(GEN_VECTOR, list(-1.2, 0.7, 0), list(1.2, 1.6, 0), UNIFORM_RAND)

/particles/smoke/burning/golden_gardren/burst
	count = 72
	spawning = 12
	lifespan = 1.5 SECONDS
	fade = 1.2 SECONDS
	position = generator(GEN_VECTOR, list(-15, -6, 0), list(15, 10, 0), UNIFORM_RAND)
	velocity = generator(GEN_VECTOR, list(-2, 0, 0), list(2, 0.8, 0), UNIFORM_RAND)

/obj/effect/temp_visual/golden_gardren_smoke
	name = "cloud of smoke"
	duration = 3 SECONDS
	randomdir = FALSE

/obj/effect/temp_visual/golden_gardren_smoke/Initialize(mapload)
	. = ..()
	particles = new /particles/smoke/burning/golden_gardren/burst
	addtimer(CALLBACK(src, PROC_REF(stop_spawning)), 0.8 SECONDS)

/obj/effect/temp_visual/golden_gardren_smoke/Destroy()
	QDEL_NULL(particles)
	return ..()

/obj/effect/temp_visual/golden_gardren_smoke/proc/stop_spawning()
	particles.spawning = 0

#undef GOLDEN_GARDREN_EJECT_DELAY
#undef GOLDEN_GARDREN_EJECT_RANGE
#undef GOLDEN_GARDREN_EJECT_KNOCKDOWN
#undef GOLDEN_GARDREN_CAPSULE_TRANSIT
#undef GOLDEN_GARDREN_CAPSULE_FALL
#undef GOLDEN_GARDREN_CAPSULE_OPEN
