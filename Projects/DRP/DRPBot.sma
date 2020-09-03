//////////////////////////////////////////////
// DRPBot.sma
// ------------------------------
// Author(s):
//
//
//

#include <amxmodx>
#include <bot_api>
#include <engine>
#include <fakemeta>

#include <xs>

enum
{
	WALK = 0,
	IDLE,
	BITE,
	EAT,
	LOW_TO_EAT,
	RISE_FROM_EAT,
	LAYDOWN,
	GETUP,
	ROLL_OVER,
	ROLL_BACK,
	SLEEP_CHEST,
	SLEEP_SIDE
}
	
	
new g_User

public plugin_precache()
{
	precache_model("models/player/gordon/gordon.mdl");
}

public plugin_init()
{
	register_plugin("DRP - Bots","0.1a","Drak");
	register_concmd("amx_fox","CmdBot");
	register_concmd("amx_s","CmdS");
}
//,pev(id,pev_iuser2)) = id of the user we are spectating
// ,pev(id,pev_iuser1)) = camera spectator mode
public CmdS(id)
{
	set_pev(id,pev_iuser2,0);
	set_pev(id,pev_iuser1,0);
}
public CmdBot(id)
{
	g_User = id
	
	new Bot = create_bot("Fox-Test");
	set_user_info(Bot,"model","Aki");
	set_task(0.1,"Spawn",Bot);
}

public Spawn(id)
{
	DispatchSpawn(id)
	
	new Float:Origin[3]
	entity_get_vector(g_User,EV_VEC_origin,Origin)
	
	Origin[1] -= 50.0
	entity_set_origin(id,Origin)
	
	//ts_giveweapon(id,TSW_AK47,250,0)
}