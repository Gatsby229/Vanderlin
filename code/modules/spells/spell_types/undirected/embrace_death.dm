/datum/action/innate/embrace_death
	name = "Embrace Death"
	button_icon_state = "necra"

/datum/action/innate/embrace_death/Activate()
	. = ..()
	if(!isliving(owner) || !owner.mind)
		return

	var/confirm = browser_alert(owner, "This will END YOUR CHARACTER PERMANENTLY. Are you absolutely sure?", "Embrace Death", DEFAULT_INPUT_CHOICES)
	if(QDELETED(src) || QDELETED(owner))
		return

	if(confirm != CHOICE_CONFIRM)
		return

	owner.say("NECRA, I AM READY!", forced = "necra_ritual")

	owner.visible_message(
		span_userdanger("[owner] begins chanting Necra's last rites!"), \
		span_userdanger("You feel Necra's presence as you start the final ritual...")
	)

	if(!do_after(owner, 10 SECONDS, owner))
		to_chat(owner, span_warning("The ritual was interrupted!"))
		return

	owner.say("NECRA, EMBRACE ME!", forced = "necra_ritual")
	playsound(owner, 'sound/magic/churn.ogg', 100)
	ADD_TRAIT(owner, TRAIT_NECRA_CURSE, "necra_ritual")
	ADD_TRAIT(owner, TRAIT_BURIED_COIN_GIVEN, "necra_ritual")
	owner.death()

	var/datum/objective/personal/embrace_death/objective = target
	if(!QDELETED(objective) && !objective.completed)
		objective.complete_objective()

	qdel(src)
