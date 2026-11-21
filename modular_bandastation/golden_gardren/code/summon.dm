#define GOLDEN_GARDREN_SUMMON_COOLDOWN (1 MINUTES)
#define GOLDEN_GARDREN_SUMMON_TAKEOFF (1.5 SECONDS)
#define GOLDEN_GARDREN_SUMMON_RANGE 2
#define GOLDEN_GARDREN_SUMMON_DELAYS list(POD_TRANSIT = 20, POD_FALLING = 8, POD_OPENING = 1, POD_LEAVING = 1)

/obj/item/implant/golden_gardren_summon
	name = "\improper Golden-Gardren summon implant"
	desc = "Маячок вызова, связанный с одним мехом пары Голден-Гардрен."
	icon = 'modular_bandastation/golden_gardren/icons/actions.dmi'
	icon_state = "summon"
	implant_color = "r"
	implant_info = "Активируется вручную. Внутри меха пары Голден-Гардрен привязывает имплант к этому меху. \
		Снаружи вызывает привязанный мех: тот взлетает, где бы ни был, и падает с неба рядом с владельцем. \
		Не стойте на отмеченной клетке посадки. Мех должен быть пустым. Перезарядка — минута."
	implant_lore = "Экспериментальный маячок ЦК для ивентовых машин. Подаёт сигнал автопилоту меха, \
		который поднимает машину на реактивной тяге и сбрасывает её по координатам носителя."
	var/datum/weakref/linked_mech
	var/obj/vehicle/sealed/mecha/launching_mech
	COOLDOWN_DECLARE(summon_cooldown)

/obj/item/implant/golden_gardren_summon/Destroy(force)
	finish_takeoff()
	return ..()

/obj/item/implant/golden_gardren_summon/on_activate()
	. = ..()
	var/mob/living/user = imp_in
	if(!user)
		return
	if(istype(user.loc, /obj/vehicle/sealed/mecha/golden_gardren_base))
		linked_mech = WEAKREF(user.loc)
		balloon_alert(user, "мех привязан")
		return
	var/obj/vehicle/sealed/mecha/mech = get_linked_mech()
	if(!mech)
		balloon_alert(user, "мех не привязан!")
		to_chat(user, span_warning("Сядьте в Голдена, Гардрена или Голден-Гардрена и активируйте имплант, чтобы привязать его."))
		return
	var/turf/landing = find_landing(user)
	var/blocker = summon_blocker(mech, user, landing, check_cooldown = TRUE)
	if(blocker)
		balloon_alert(user, blocker)
		return
	COOLDOWN_START(src, summon_cooldown, GOLDEN_GARDREN_SUMMON_COOLDOWN)
	launching_mech = mech
	GLOB.golden_gardren_busy += mech
	user.log_message("summoned [mech] from [AREACOORD(mech)] with a summon implant.", LOG_GAME)
	to_chat(user, span_notice("Сигнал принят: [mech.declent_ru(NOMINATIVE)] вылетает к вам!"))
	take_off(mech)
	addtimer(CALLBACK(src, PROC_REF(launch), user), GOLDEN_GARDREN_SUMMON_TAKEOFF)

/obj/item/implant/golden_gardren_summon/proc/get_linked_mech()
	var/obj/vehicle/sealed/mecha/mech = linked_mech?.resolve()
	if(istype(mech?.loc, /obj/vehicle/sealed/mecha/golden_gardren))
		mech = mech.loc
	return mech

/obj/item/implant/golden_gardren_summon/proc/summon_blocker(obj/vehicle/sealed/mecha/mech, mob/living/user, turf/landing, check_cooldown)
	if(QDELETED(mech))
		return "мех уничтожен"
	if(QDELETED(user) || !isturf(user.loc))
		return "нужно стоять на полу"
	if(check_cooldown && !COOLDOWN_FINISHED(src, summon_cooldown))
		return "имплант перезаряжается"
	if(!isturf(mech.loc))
		return "мех недоступен"
	if(length(mech.occupants))
		return "в мехе кто-то есть"
	if(mech.completely_disabled || mech.is_currently_ejecting || golden_gardren_is_ejecting(mech) || (check_cooldown && (mech in GLOB.golden_gardren_busy)))
		return "мех занят"
	if(!landing)
		return "нет места для посадки"
	return null

/obj/item/implant/golden_gardren_summon/proc/find_landing(mob/living/user)
	var/turf/center = get_turf(user)
	if(!center)
		return null
	for(var/radius in 1 to GOLDEN_GARDREN_SUMMON_RANGE)
		var/list/candidates = list()
		for(var/turf/candidate in orange(radius, center))
			if(get_dist(center, candidate) != radius || !isopenturf(candidate) || isgroundlessturf(candidate))
				continue
			if(candidate.is_blocked_turf() || !can_see(center, candidate, radius))
				continue
			candidates += candidate
		if(length(candidates))
			return pick(candidates)
	return null

/obj/item/implant/golden_gardren_summon/proc/take_off(obj/vehicle/sealed/mecha/mech)
	var/turf/origin = get_turf(mech)
	golden_gardren_release_fist(mech)
	mech.visible_message(span_warning("[mech.declent_ru(NOMINATIVE)] с рёвом двигателей взмывает в небо!"))
	playsound(origin, 'sound/vehicles/rocketlaunch.ogg', 80, TRUE)
	for(var/turf/smoke_turf in range(1, origin))
		new /obj/effect/temp_visual/small_smoke/halfsecond(smoke_turf)
	animate(mech, pixel_z = mech.base_pixel_z + 10 * ICON_SIZE_Y, alpha = 0, time = GOLDEN_GARDREN_SUMMON_TAKEOFF, easing = QUAD_EASING | EASE_IN)

/obj/item/implant/golden_gardren_summon/proc/finish_takeoff()
	var/obj/vehicle/sealed/mecha/mech = launching_mech
	if(!mech)
		return null
	launching_mech = null
	GLOB.golden_gardren_busy -= mech
	if(QDELETED(mech))
		return null
	animate(mech)
	mech.pixel_z = mech.base_pixel_z
	mech.alpha = initial(mech.alpha)
	return mech

/obj/item/implant/golden_gardren_summon/proc/launch(mob/living/user)
	var/obj/vehicle/sealed/mecha/mech = finish_takeoff()
	if(!mech)
		return
	var/summoner_gone = QDELETED(user) || user != imp_in
	var/turf/landing = summoner_gone ? null : find_landing(user)
	var/blocker = summoner_gone ? "носитель импланта пропал" : summon_blocker(mech, user, landing, check_cooldown = FALSE)
	if(blocker)
		mech.visible_message(span_warning("[mech.declent_ru(NOMINATIVE)] не находит цели и опускается обратно."))
		if(!QDELETED(user))
			to_chat(user, span_warning("Вызов сорвался: [blocker]."))
		return
	drop_mech(mech, landing)

/obj/item/implant/golden_gardren_summon/proc/drop_mech(obj/vehicle/sealed/mecha/mech, turf/landing)
	mech.log_message("Summoned to [AREACOORD(landing)].", LOG_MECHA)
	podspawn(list(
		"target" = landing,
		"path" = /obj/structure/closet/supplypod/podspawn/golden_gardren_summon,
		"style" = /datum/pod_style/seethrough,
		"spawn" = mech,
		"explosionSize" = list(0, 0, 0, 0),
		"bluespace" = TRUE,
		"delays" = GOLDEN_GARDREN_SUMMON_DELAYS,
	))

/obj/structure/closet/supplypod/podspawn/golden_gardren_summon
	damage = 10
	effectQuiet = TRUE

/obj/structure/closet/supplypod/podspawn/golden_gardren_summon/pre_open()
	var/turf/landing = get_turf(src)
	. = ..()
	if(!landing)
		return
	if(isfloorturf(landing))
		landing.break_tile()
	playsound(landing, 'sound/effects/meteorimpact.ogg', 100, TRUE)
	playsound(landing, 'sound/effects/explosion/explosion_distant.ogg', 60, TRUE)
	new /obj/effect/temp_visual/mook_dust(landing)
	for(var/mob/living/witness in range(6, landing))
		shake_camera(witness, 4, 3)

/obj/item/implanter/golden_gardren_summon
	name = "implanter (Golden-Gardren summon)"
	imp_type = /obj/item/implant/golden_gardren_summon

#undef GOLDEN_GARDREN_SUMMON_COOLDOWN
#undef GOLDEN_GARDREN_SUMMON_TAKEOFF
#undef GOLDEN_GARDREN_SUMMON_RANGE
#undef GOLDEN_GARDREN_SUMMON_DELAYS
