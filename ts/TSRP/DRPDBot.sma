/* ======================================
* DRPDBot.sma
* --------------
* Purpose:
* N/A
* 
* Idea:
* A bot that roams around the map, recording kills and other misc info.
* Players can interact with the bot.
* This was an experiment with A.I.
* =======================================
*/


#include <amxmodx>
#include <amxmisc>
#include <fakemeta>

#include <DRP/DRPCore>
#include <bot_api>

new g_Seen[33]

new const BOT_NAME[] = "DrakB"
new const BOT_MODEL[] = "models/player/DRPDrakRobo/DRPDrakRobo.mdl"

new g_Bot

// CVars
new p_Enable
new p_Death

// Menus
new const g_BotMenu[] = "DRP_BotMenu"

public plugin_precache()
{
	new mapName[33]
	get_mapname(mapName,32);
	
	// Hard-Coded
	if(!equali(mapName,"mecklenburg_drak"))
		pause("d");
	
	if(!file_exists(BOT_MODEL))
		pause("d");
	
	precache_model(BOT_MODEL);
	
	// CVars
	// 0 = Disabled 1 = Spawn Only 2 = Spawn / Leave Automatically
	p_Enable = register_cvar("DRP_DrakBot","1");
	
	// 0 = Bot cannot die. Anything higher then zero is the amount of health
	// the bot has
	p_Death = register_cvar("DRP_Death","0");
}
public plugin_init()
{
	register_plugin("DRP - Drak Bot","0.1a","Drak");
	
	// Menus
	register_menucmd(register_menuid(g_BotMenu),g_Keys,"_Bot_Menu");
	
	// Events
	DRP_RegisterEvent("Menu_Display","Menu_Display");
	
	if(get_pcvar_num(p_Enable) >= 2)
		CreateBot();
}
public DRP_Error(const Reason[])
	pause("d");

/*==================================================================================================================================================*/
public Menu_Display(const Name[],const Data[],Len)
{
	new id = Data[0]
	if(get_user_flags(id) & ADMIN_IMMUNITY)
		DRP_AddMenuItem(id,"DRP DBot M22enu","Bot_Menu");
}
public Bot_Menu(id)
{
	static Menu[256]
	format(Menu,255,"DRP DBot^n^n1. %s^n2. Bot Info",g_Bot ? "Remove Bot" : "Spawn Bot");
	
	g_Seen[id] = 1
	
	show_menu(id,g_Keys,Menu,_,g_BotMenu);
}
public _Bot_Menu(id,Key)
{
	switch(Key)
	{
		case 0:
			g_Bot ? CleanupBot() : CreateBot();
		case 1:
		{
			show_motd(id,"Bot Info","DRP");
		}
	}
}
/*==================================================================================================================================================*/
public bot_think(id)
{
	if(id != g_Bot)
		return
	
	static Float:botOrigin[3],Float:targetOrigin[3]
	pev(id,pev_origin,botOrigin);
	
	static iPlayers[32],iNum,Target
	get_players(iPlayers,iNum);
	
	//for(new Count,Float:Distance = 9999999.0,Float:CmpDistance;Count < Playersnum;Count++)
	for(new Count;Count < iNum;Count++)
	{
		Target = iPlayers[Count]
		
		if(Target == g_Bot || !fm_is_ent_visible(id,Target))
			continue
		
		pev(Target,pev_origin,targetOrigin);
	}
}
/*==================================================================================================================================================*/
// Player Bot: CreateBot(True,_,"models/player/MODEL/MODEL.MDL");
// NPC: CreateBot(False,Origin[3],"models/mecklenburg/some_model.mdl");
/*
CreateBot(bool:IsPlayer = false,const Float:Origin[3],const Model[])
{
	if(!IsPlayer)
	{
	}
}
*/

CreateBot()
{
	if(g_Bot)
		return FAILED
	
	new szModel[33],Temp[2]
	remove_filepath(BOT_MODEL,szModel,32); 
	strtok(szModel,szModel,32,Temp,1,'.');
	
	g_Bot = create_bot(BOT_NAME);
	set_user_info(g_Bot,"model",szModel);
	
	dllfunc(DLLFunc_Spawn,g_Bot);
	
	return SUCCEEDED
}
CleanupBot()
{
	if(!g_Bot)
		return FAILED
	
	remove_bot(g_Bot);
	
	return SUCCEEDED
}

stock bool:fm_is_ent_visible(index, entity) 
{
    new Float:origin[3], Float:view_ofs[3], Float:eyespos[3]
    pev(index, pev_origin, origin)
    pev(index, pev_view_ofs, view_ofs)
    xs_vec_add(origin, view_ofs, eyespos)

    new Float:entpos[3]
    pev(entity, pev_origin, entpos)
    engfunc(EngFunc_TraceLine, eyespos, entpos, 0, index)

    switch (pev(entity, pev_solid)) {
        case SOLID_BBOX..SOLID_BSP: return global_get(glb_trace_ent) == entity
    }
    
    new Float:fraction
    global_get(glb_trace_fraction, fraction)
    if (fraction == 1.0)
        return true

    return false
}
#include <xs>
// the dot product is performed in 2d, making the view cone infinitely tall
stock bool:fm_is_in_viewcone(index, const Float:point[3]) {
	new Float:angles[3];
	pev(index, pev_angles, angles);
	engfunc(EngFunc_MakeVectors, angles);
	global_get(glb_v_forward, angles);
	angles[2] = 0.0;

	new Float:origin[3], Float:diff[3], Float:norm[3];
	pev(index, pev_origin, origin);
	xs_vec_sub(point, origin, diff);
	diff[2] = 0.0;
	xs_vec_normalize(diff, norm);

	new Float:dot, Float:fov;
	dot = xs_vec_dot(norm, angles);
	pev(index, pev_fov, fov);
	if (dot >= floatcos(fov * M_PI / 360))
		return true;

	return false;
}
/*==================================================================================================================================================*/