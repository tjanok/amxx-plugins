//////////////////////////////////////////////
// DRPFoxBot.sma
// ------------------------------
// Author(s):
// Drak
//
//
//

#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>


new const iFoxMdl[] = "models/DRP/DRPFox.mdl"
new const iFoxClass[] = "DRP_Fox"

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

new bool:m_fSequenceFinished = false
new bool:FoxWatching = false

new g_EntFox // Only one fox will be spawned.

public plugin_precache()
{
	precache_model(iFoxMdl);
	precache_generic("models/DRP/DRPFoxCredits.txt");
}

public plugin_init()
{
	register_plugin("DRP - Drak Fox","0.1a","Drak");
	
	// Forwards
	register_forward(FM_PlayerPreThink,"Forward_PreThink");
	register_forward(FM_Think,"Forward_Think");
	
	// This is for me only. So the command will use AMXX Admin flags
	register_clcmd("amx_drakfox","CmdSpawn",ADMIN_IMMUNITY,"(ADMIN) Drak-Only Command");
}

public CmdSpawn(id,level,cid)
{
	if(!cmd_access(id,level,cid,1))
		return PLUGIN_HANDLED
	
	if(g_EntFox) {
		client_print(id,print_console,"[AMXX] Fox Already Spawned.");
		return PLUGIN_HANDLED
	}
	
    new ent = engfunc(EngFunc_CreateNamedEntity,engfunc(EngFunc_AllocString,"info_target"))
	if(!pev_valid(ent)) {
		client_print(id,print_console,"[AMXX] Unable to create bot.");
		return PLUGIN_HANDLED
	}
	
	g_EntFox = ent
	
	new Float:plOrigin[3]
    pev(id,pev_origin,plOrigin);
	
	plOrigin[1] -= 50.0
    
	engfunc(EngFunc_SetOrigin,ent,plOrigin);

    set_pev(ent,pev_takedamage,DAMAGE_NO);
    set_pev(ent,pev_health,100.0);

    set_pev(ent,pev_classname,iFoxClass);
	engfunc(EngFunc_SetModel,ent,iFoxMdl);
    set_pev(ent,pev_solid,SOLID_BBOX);

    entity_set_byte(ent,EV_BYTE_controller1,125);
    entity_set_byte(ent,EV_BYTE_controller2,125);
    entity_set_byte(ent,EV_BYTE_controller3,125);
    entity_set_byte(ent,EV_BYTE_controller4,125);

	new const Float:Mins[3] = { -12.0, -12.0, -34.0 }
	new const Float:Maxs[3] = { 12.0, 12.0, 1.0 }
	engfunc(EngFunc_SetSize,ent,Mins,Maxs);
	
	FoxSetSequence(1,ent);

	set_pev(ent,pev_nextthink,halflife_time() + 0.01);

    engfunc(EngFunc_DropToFloor,ent);
	
	dllfunc(DLLFunc_Think,ent);
    
	return 1;
}

FoxSetSequence(seq,ent)
{
	if(pev(ent,pev_sequence) == seq)
		return
	
	set_pev(ent,pev_sequence,seq);
	set_pev(ent,pev_frame,0);
	set_pev(ent,pev_animtime,get_gametime());
	set_pev(ent,pev_framerate,1.0);
	
	m_fSequenceFinished = false
}
/*==================================================================================================================================================*/
public Forward_PreThink(id)
{
	if(!is_user_alive(id) || !FoxWatching)
		return FMRES_IGNORED
	
	return FMRES_HANDLED
}
public Forward_Think(ent)
{
	if(!g_EntFox || ent != g_EntFox)
		return FMRES_IGNORED
	
	set_pev(ent,pev_nextthink,get_gametime() + 0.01);
	dllfunc(DLLFunc_Think,ent);
	
	return FMRES_HANDLED
}

/*==================================================================================================================================================*/