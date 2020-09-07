/////////////////////////////////////////////
// Small AI Bird that roam around the map.
// -------------------------
// Author:
// Drak - Main Author
///////////////////////////////////////////////

#include <amxmodx>
#include <amxmisc>
#include <fakemeta>

#define MAX_BIRDS 10

new const g_Seagull[] = "models/DRP/seagull.mdl"
new const g_NPCName[] = "DBird"

enum
{
	IDLE = 0,
	WALK,
	RUN,
	HOP,
	HOP_B,
	TAKE_OFF,
	FLY,
	SOAR,
	LAND
}

new g_Birds[MAX_BIRDS]
new g_BirdNum

// Bird Info
new g_BirdAnimation[MAX_BIRDS]

public plugin_precache()
{
	precache_model(g_Seagull);
}
/*==================================================================================================================================================*/
public plugin_init()
{
	register_plugin("DRP - Bird","0.1a","Drak");
	
	// Commands
	register_clcmd("amx_spawnbird","CmdSpawn",ADMIN_ALL,"- spawn a bird");
	
	// Forwards
	register_forward(FM_Think,"forward_Think");
	register_forward(FM_TraceLine,"forward_TraceLine",1);
}
/*==================================================================================================================================================*/
public CmdSpawn(id,level,cid)
{
	if(!cmd_access(id,level,cid,1))
		return PLUGIN_HANDLED
	
	if(g_BirdNum >= MAX_BIRDS)
	{
		client_print(id,print_chat,"[AMXX] Maximum birds reached. (%d max)",MAX_BIRDS);
		return PLUGIN_HANDLED
	}
	
	new Float:plOrigin[3]
	pev(id,pev_origin,plOrigin);
	
	g_Birds[g_BirdNum++] = SpawnBird(plOrigin);
	if(g_Birds[g_BirdNum] == -1)
	{
		client_print(id,print_chat,"[DRP] Failed to create Bird.");
		return g_Birds[g_BirdNum] == 0
	}
	
	return PLUGIN_HANDLED
}
/*==================================================================================================================================================*/
public forward_Think(Ent)
{
	if(!Ent)
		return
	
	static Classname[33]
	pev(Ent,pev_classname,Classname,32);
	
	if(!equali(Classname,g_NPCName))
		return
	
	set_pev(Ent,pev_nextthink,get_gametime() + 0.2);
	
	if(!engfunc(EngFunc_FindClientInPVS,Ent))
		return
	
	set_pev(Ent,pev_nextthink,get_gametime() + 0.1);
	HandleThink(Ent);
}
HandleThink(Ent)
{
	new Sequence = pev(Ent,pev_sequence);
	
	// There's something in our way, 
	if(!PathClear(Ent))
	{
		switch(Sequence)
		{
			case IDLE:
				SetAnimation(Ent,WALK);
		}
	}
	
	/*
	switch(pev(Ent,pev_sequence))
	{
		case IDLE:
		{
			// Where blocked, walk forward
			if(CheckPath(Ent))
			{
			//server_print("I TRACED LOL");
		}
	}
	*/
}
#include <chr_engine>
SetAnimation(Ent,Seq)
{
	set_pev(Ent,pev_sequence,Seq);
	switch(Seq)
	{
		get_spe
		case WALK: set_pev(id,pev_vel
public forward_TraceLine(Float:start[3],Float:end[3],monsters,id,ptr)
{
}
/*==================================================================================================================================================*/
SpawnBird(const Float:Origin[3])
{
	new Ent = engfunc(EngFunc_CreateNamedEntity,engfunc(EngFunc_AllocString,"info_target"));
	if(!pev_valid(Ent))
		return -1
	
	set_pev(Ent,pev_classname,g_NPCName);
	set_pev(Ent,pev_takedamage,DAMAGE_NO);
	set_pev(Ent,pev_solid,SOLID_SLIDEBOX);
	set_pev(Ent,pev_movetype,MOVETYPE_FLY);
	
	set_pev(Ent,pev_animtime,2.0);
	set_pev(Ent,pev_framerate,1.0);
	set_pev(Ent,pev_gaitsequence,0);
	set_pev(Ent,pev_sequence,0);
	
	set_pev(Ent,pev_nextthink,get_gametime() + 0.01);
	
	engfunc(EngFunc_SetModel,Ent,g_Seagull);
	engfunc(EngFunc_SetOrigin,Ent,Origin);
	engfunc(EngFunc_DropToFloor,Ent);

	return Ent
}
GetBird(Ent)
{
	for(new Count;Count < MAX_BIRDS;Count++)
		if(Ent == g_Birds[Count])
			return Count
	
	return -1
}
#include <xs>
bool:PathClear(const Ent)
{
	new Tr
	new Float:Angles[3],Float:Origin[3],Float:vForward[3]
	new Float:vFinal[3]
	
	pev(Ent,pev_angles,Angles);
	pev(Ent,pev_origin,Origin);
	
	global_get(glb_v_forward,vForward);
	xs_vec_add(vForward,Origin,vFinal);
	
	engfunc(EngFunc_MakeVectors,Angles);
	engfunc(EngFunc_TraceLine,Origin,vFinal,IGNORE_MONSTERS,Ent,Tr);
	
	new Float:Fraction
	get_tr2(Tr,TR_flFraction,Fraction);
	
	server_print("FRACTION: %f",Fraction);
	
	return (Fraction == 1.0) ? true : false
	
	//EngFunc_TraceLine,		// void )		(const float *v1, const float *v2, int fNoMonsters, edict_t *pentToSkip, TraceResult *ptr);
}
stock bool:is_in_line_of_sight(Float:origin1[3], Float:origin[2], bool:ignore_players = true)
{
    new trace = 0
    engfunc(EngFunc_TraceLine, origin1, origin2, (ignore_players ? IGNORE_MONSTERS : DONT_IGNORE_MONSTERS), 0, trace)
    
    new Float:fraction
    get_tr2(trace, TR_flFraction, fraction)
    
    return (fraction == 1.0) ? true : false
}  

/*
//=========================================================
// FBoidPathBlocked - returns TRUE if there is an obstacle ahead
//=========================================================
BOOL CFlockingFlyer :: FPathBlocked( )
{
	TraceResult		tr;
	Vector			vecDist;// used for general measurements
	Vector			vecDir;// used for general measurements
	BOOL			fBlocked;

	if ( m_flFakeBlockedTime > gpGlobals->time )
	{
		m_flLastBlockedTime = gpGlobals->time;
		return TRUE;
	}

	// use VELOCITY, not angles, not all boids point the direction they are flying
	//vecDir = UTIL_VecToAngles( pevBoid->velocity );
	UTIL_MakeVectors ( pev->angles );

	fBlocked = FALSE;// assume the way ahead is clear

	// check for obstacle ahead
	UTIL_TraceLine(pev->origin, pev->origin + gpGlobals->v_forward * AFLOCK_CHECK_DIST, ignore_monsters, ENT(pev), &tr);
	if (tr.flFraction != 1.0)
	{
		m_flLastBlockedTime = gpGlobals->time;
		fBlocked = TRUE;
	}

	// extra wide checks
	UTIL_TraceLine(pev->origin + gpGlobals->v_right * 12, pev->origin + gpGlobals->v_right * 12 + gpGlobals->v_forward * AFLOCK_CHECK_DIST, ignore_monsters, ENT(pev), &tr);
	if (tr.flFraction != 1.0)
	{
		m_flLastBlockedTime = gpGlobals->time;
		fBlocked = TRUE;
	}

	UTIL_TraceLine(pev->origin - gpGlobals->v_right * 12, pev->origin - gpGlobals->v_right * 12 + gpGlobals->v_forward * AFLOCK_CHECK_DIST, ignore_monsters, ENT(pev), &tr);
	if (tr.flFraction != 1.0)
	{
		m_flLastBlockedTime = gpGlobals->time;
		fBlocked = TRUE;
	}

	if ( !fBlocked && gpGlobals->time - m_flLastBlockedTime > 6 )
	{
		// not blocked, and it's been a few seconds since we've actually been blocked.
		m_flFakeBlockedTime = gpGlobals->time + RANDOM_LONG(1, 3); 
	}

	return	fBlocked;
}
*/
/*==================================================================================================================================================*/