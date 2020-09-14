#if defined _drp_smod	
	#endinput
#endif
#define _drp_smod


#pragma reqlib "DRPCore"
#pragma reqlib "DRPSMod"

enum
{
	S_BASIC = 0,
	S_COOKING,
	S_COMPUTER,
	S_LAW,
	S_FIGHTING,
	S_WEAPONS,
	S_DRUGS
}
// Returns the skill level for the given skill
// Use the S_* defines
native DRP_GetUserSkill(id,skill);
 
// Returns SUCCEEDED or FAILED on setting the level
// Use the S_* defines
native DRP_SetUserSkill(id,skill,level);

// Show's an MOTD window of the "view_this_skills_id"
// to "show_to_id"
native DRP_ShowUserSkills(show_to_id,view_this_skills_id);