/obj/projectile/bullet/shrap
	name = "lead fragment"
	icon = 'icons/obj/shards.dmi'
	icon_state = "small"
	damage = 60
	damage_type = BRUTE
	woundclass = BCLASS_SHOT
	range = 30
	impact_effect_type = /obj/effect/temp_visual/impact_effect
	flag =  "piercing"
	speed = 0.8




/obj/item/explosive/grenadeshell
	name = "Grenade Shell"
	desc = "A metal tube with a tight screw cap and slots for shrapnel."
	icon_state = "grenade_shell"
	icon = 'icons/obj/bombs.dmi'
	w_class = WEIGHT_CLASS_NORMAL
	throwforce = 0
	slot_flags = ITEM_SLOT_HIP
	grid_height = 64
	grid_width = 32

/obj/item/explosive/canister_bomb
	name = "Canister Bomb"
	desc = "A professional Grenzelhoftan explosive, filled with lead shrapnel and sticky blastpowder."
	icon_state = "canbomb"
	icon = 'icons/obj/bombs.dmi'
	w_class = WEIGHT_CLASS_NORMAL
	throwforce = 0
	slot_flags = ITEM_SLOT_HIP
	grid_height = 64
	grid_width = 32

	///do we explode on impact?
	var/impact_explode = FALSE
	///odds we fail on ignite
	var/prob2fail = 5

	/// Bitfields which prevent the grenade from detonating if set. Includes ([GRENADE_DUD]|[GRENADE_USED])
	var/dud_flags = NONE
	///Were we made sticky?
	var/sticky = FALSE
	///how big of a devastation explosion radius on prime
	var/ex_dev = 0
	///how big of a heavy explosion radius on prime
	var/ex_heavy = 1
	///how big of a light explosion radius on prime
	var/ex_light = 2
	///how big of a flame explosion radius on prime
	var/ex_flame = 0
	///how big the hotspot range is
	var/ex_hotspot_range = 0
	///do we smoke?
	var/ex_smoke = FALSE

	///our ignite timer
	var/explode_timer

	///Is this grenade currently armed?
	var/active = FALSE
	///How long it takes for a grenade to explode after being armed
	var/det_time = 10 SECONDS


	// dealing with creating a [/datum/component/pellet_cloud] on detonate
	/// if set, will spew out projectiles of this type
	var/shrapnel_type = /obj/projectile/bullet/shrap
	/// the higher this number, the more projectiles are created as shrapnel
	var/shrapnel_radius = 8
	///Did we add the component responsible for spawning sharpnel to this?
	var/shrapnel_initialized

/obj/item/explosive/Initialize()
	. = ..()
	det_time = rand(det_time * 0.5, det_time)

/**
 * Checks for various ways to botch priming a grenade.
 *
 * Arguments:
 * * mob/living/carbon/human/user - who is priming our grenade?
 */
/obj/item/explosive/canister_bomb/proc/botch_check(mob/living/carbon/human/user)
	if(prob(prob2fail))
		return TRUE

	if(sticky && prob(50)) // to add risk to sticky tape grenade cheese, no return cause we still prime as normal after.
		to_chat(user, span_warning("What the... [src] is stuck to your hand!"))
		ADD_TRAIT(src, TRAIT_NODROP, "sticky")

/obj/item/explosive/canister_bomb/attack_self(mob/user)
	if(HAS_TRAIT(src, TRAIT_NODROP))
		to_chat(user, span_notice("You try prying [src] off your hand..."))
		if(do_after(user, 7 SECONDS, target = src))
			to_chat(user, span_notice("You manage to remove [src] from your hand."))
			REMOVE_TRAIT(src, TRAIT_NODROP, "sticky")
		return

/obj/item/explosive/canister_bomb/fire_act(added, maxstacks)
	if (active)
		return
	if(usr)
		if(!botch_check(usr)) // if they botch the prime, it'll be handled in botch_check
			arm_grenade(usr)
	else
		arm_grenade(null)
	. = ..()

/obj/item/explosive/canister_bomb/spark_act()
	if (active)
		return
	if(usr)
		if(!botch_check(usr)) // if they botch the prime, it'll be handled in botch_check
			arm_grenade(usr)
	else
		arm_grenade(null)
	. = ..()

/obj/item/explosive/canister_bomb/extinguish()
	. = ..()
	if(explode_timer)
		deltimer(explode_timer)
		explode_timer = null
	icon_state = initial(icon_state)

/obj/item/explosive/canister_bomb/proc/log_grenade(mob/user)
	log_bomber(user, "has primed a", src, "for detonation", message_admins = !dud_flags)


/**
 * arm_grenade (formerly preprime) refers to when a grenade with a standard time fuze is activated, making it go beepbeepbeep and then detonate a few seconds later.
 * Grenades with other triggers like remote igniters probably skip this step and go straight to [/obj/item/Canister_bomb/proc/detonate]
 */
/obj/item/explosive/canister_bomb/proc/arm_grenade(mob/user, delayoverride, msg = TRUE, volume = 60)
	log_grenade(user) //Inbuilt admin procs already handle null users
	playsound(src.loc, 'sound/items/fuse.ogg', 100)
	if(user)
		add_fingerprint(user)
		if(msg)
			to_chat(user, span_warning("You prime [src]! [capitalize(DisplayTimeText(det_time))]!"))
	if(shrapnel_type && shrapnel_radius)
		shrapnel_initialized = TRUE
		AddComponent(/datum/component/pellet_cloud, projectile_type = shrapnel_type, magnitude = shrapnel_radius)
	active = TRUE
	icon_state = initial(icon_state) + "_active"
	SEND_SIGNAL(src, COMSIG_GRENADE_ARMED, det_time, delayoverride)
	explode_timer = addtimer(CALLBACK(src, PROC_REF(detonate)), isnull(delayoverride)? det_time : delayoverride)


/**
 * detonate (formerly prime) refers to when the grenade actually delivers its payload (whether or not a boom/bang/detonation is involved)
 *
 * Arguments:
 * * lanced_by- If this grenade was detonated by an elance, we need to pass that along with the COMSIG_GRENADE_DETONATE signal for pellet clouds
 */
/obj/item/explosive/canister_bomb/proc/detonate(mob/living/lanced_by)
	if (dud_flags)
		active = FALSE
		update_appearance()
		return FALSE

	if(shrapnel_type && shrapnel_radius && !shrapnel_initialized) // add a second check for adding the component in case whatever triggered the grenade went straight to prime (badminnery for example)
		shrapnel_initialized = TRUE
		AddComponent(/datum/component/pellet_cloud, projectile_type = shrapnel_type, magnitude = shrapnel_radius)

	SEND_SIGNAL(src, COMSIG_GRENADE_DETONATE, lanced_by)
	if(ex_dev || ex_heavy || ex_light || ex_flame)
	cell_explosion(src, ex_dev, ex_heavy, ex_light, flame_range = ex_flame, smoke = ex_smoke, hotspot_range = ex_hotspot_range, soundin = pick('sound/misc/explode/bottlebomb (1).ogg','sound/misc/explode/bottlebomb (2).ogg'))

	new turf_debris (get_turf(src))

	qdel(src)
	return TRUE

/obj/item/explosive/canister_bomb/proc/update_mob()
	if(ismob(loc))
		var/mob/mob = loc
		mob.dropItemToGround(src)

/obj/item/explosive/canister_bomb/throw_impact(atom/hit_atom, datum/thrownthing/throwingdatum)
	..()
	if(impact_explode)
		if(active)
			detonate(throwingdatum.thrower)
		else
			new turf_debris (get_turf(src))
			qdel(src)

//I hate this shit code...
