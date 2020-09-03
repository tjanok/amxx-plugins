#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <engine>

#include <DRP/DRPCore>
#include <bot_api>

#include <celltravtrie>

#define MAX_BOTS 15

enum BOT_INFO
{
	INFO_AUTO = 0,
	INFO_TIME,
	INFO_MODE
}
enum
{
	IDLE = 0,
	WALK
}

new g_Bots[MAX_BOTS]
new g_BotInfo[BOT_INFO][33]
new g_NumBots

new g_Controling[33]

new TravTrie:g_BotDialog

public plugin_init()
{
	register_plugin("DRP - Citizens","0.1a","Drak");
	
	// Admin Commands
	register_clcmd("drp_ctrlbot","CmdControl",ADMIN_LEVEL_H,"<name> - controls the bot (attaches your view also)");
	
	// Touch
	register_touch("player","player","touch_Player");
	
	// There must be a "Bot-Spawn" delay, or the server crashes
	set_task(1.0,"SpawnBots");
}

public plugin_precache()
	LoadData(1);
public SpawnBots()
	LoadData(0);

/*==================================================================================================================================================*/
public CmdControl(id,level,cid)
{
	if(!cmd_access(id,level,cid,2))
		return PLUGIN_HANDLED
	
	new Arg[33]
	read_argv(1,Arg,32);
	
	new Target = cmd_target(id,Arg);
	if(!Target)
		return PLUGIN_HANDLED
	
	if(CheckBot(Target))
	{
		client_print(id,print_console,"[AMXX] This user is not a bot.");
		return PLUGIN_HANDLED
	}
	get_user_name(Target,Arg,32);
	client_print(id,print_console,"[AMXX] You are now controlling %s",Arg);
	
	g_Controling[id] = Target
	
	// Create the bot camera
	new Cam = create_entity("info_target"),Float:Origin[3]
	entity_set_model(Cam,"models/pellet.mdl");
	
	entity_get_vector(Target,EV_VEC_origin,Origin);
	Origin[2] += 50.0
	entity_set_vector(Cam,EV_VEC_origin,Origin);
	
	entity_get_vector(Target,EV_VEC_angles,Origin);
	entity_set_vector(Cam,EV_VEC_angles,Origin);
	
	entity_set_size(Cam,Float:{0.0,0.0,0.0},Float:{0.0,0.0,0.0});

	/*
	
	set_pev(Camera,pev_movetype,MOVETYPE_NOCLIP);
	set_pev(Camera, pev_solid, SOLID_NOT );
	set_pev(Camera, pev_takedamage, DAMAGE_NO );
	set_pev(Camera,pev_owner,id);
	set_pev(Camera,pev_gravity,0);
	*/
	
	engfunc(EngFunc_SetView,id,Cam);
	
	client_print(0,print_chat,"%f %f %f",Origin[0],Origin[1],Origin[2]);
	
	
	return PLUGIN_HANDLED
}
/*==================================================================================================================================================*/
public touch_Player(pToucher,pTouched)
{
	if(!CheckBot(pTouched))
		return
}
public bot_think(id)
{
	if(!CheckBot(id))
		return
}
public bot_disconnect(id)
{
	if(!CheckBot(id))
		return
	
	for(new Count;Count < BOT_INFO;Count++)
		g_BotInfo[Count][id] = 0
}
/*==================================================================================================================================================*/
public client_PreThink(id)
{
	static Target
	Target = g_Controling[id]
	
	if(!Target || !is_user_alive(Target))
		return
	
	static Buttons
	pev(id,pev_button,Buttons);
}
public fm_cmdstart(id,uc_handle,random_seed) {
	new bot = botindex[id], movement = copymovements[id]
	if(!bot || !movement) return FMRES_IGNORED

	new alive = is_user_alive(id), button = get_uc(uc_handle,UC_Buttons)
	if(!alive) set_uc(uc_handle,UC_Buttons, button & ~IN_JUMP & ~IN_ATTACK & ~IN_ATTACK2 & ~IN_FORWARD & ~IN_BACK & ~IN_MOVELEFT & ~IN_MOVERIGHT)

	if(is_user_alive(bot)) {
		get_uc(uc_handle,UC_ForwardMove, botmove[id][0])
		get_uc(uc_handle,UC_SideMove, botmove[id][1])
		get_uc(uc_handle,UC_UpMove, botmove[id][2])

		static Float:angles[3]
		if(movement == 2 && alive && button&IN_ATTACK) {
			static Float:target[3]
			get_user_aim(id,target)
			aim_at_origin(bot,target,angles)
		}
		else {
			get_uc(uc_handle,UC_ViewAngles, angles)
			if(movement == 3 && alive) {
				angles[1] += (angles[1] < 180.0) ? 180.0 : -180.0
				if(button&IN_JUMP) button = button & ~IN_JUMP | IN_DUCK
				else if(button&IN_DUCK) button = button & ~IN_DUCK | IN_JUMP
			}
		}
		botangles[id][0] = angles[0]
		botangles[id][1] = angles[1]
		botangles[id][2] = angles[2]
		botbuttons[id] = button
		botimpulses[id] = get_uc(uc_handle,UC_Impulse)
	}
/*==================================================================================================================================================*/
LoadData(PrecacheOnly=0)
{
	new ConfigFile[256]
	DRP_GetConfigsDir(ConfigFile,255);
	
	add(ConfigFile,255,"/Citizens.ini");
	
	new pFile = fopen(ConfigFile,"rt");
	if(!pFile)
		return DRP_ThrowError(1,"Unable to open DRP-Citizens File (%s)",ConfigFile);
	
	new Model[33],Temp[1]
	new Auto = 0,Precache = 0
	
	if(PrecacheOnly)
	{
		while(!feof(pFile))
		{
			fgets(pFile,ConfigFile,255);
			if(containi(ConfigFile,"[END]") != -1)
			{
				if(!Precache)
					continue
				
				Precache = 0
				
				format(ConfigFile,255,"models/player/%s/%s.mdl",Model,Model);
				if(!file_exists(ConfigFile))
					return DRP_ThrowError(0,"The model ^"%s^" cannot be found to be precached.");
				
				precache_model(ConfigFile);
			}
			else if(containi(ConfigFile,"model") != -1)
			{
				parse(ConfigFile,Temp,1,Model,32)
				remove_quotes(Model);
			}
			else if(containi(ConfigFile,"precache") != -1)
				Precache = 1
		}
		return fclose(pFile);
	}
	
	
	g_BotDialog = TravTrieCreate();
	
	new Name[33],Other[33],Chat[256]
	while(!feof(pFile))
	{
		fgets(pFile,ConfigFile,255);
		if(containi(ConfigFile,"[END]") != -1)
		{
			if(g_NumBots >= MAX_BOTS)
				return DRP_ThrowError(0,"Max DRP Citizens Reached (%d) - This value is hardcoded.",MAX_BOTS);
			
			g_Bots[g_NumBots++] = CreateBot(Name,Model);
		}
		else if(containi(ConfigFile,"name") != -1)
		{
			parse(ConfigFile,Temp,1,Name,32);
			remove_quotes(Name);
		}
		else if(containi(ConfigFile,"model") != -1)
		{
			parse(ConfigFile,Temp,1,Model,32);
			remove_quotes(Model);
		}
	}
	return fclose(pFile);
}
CreateBot(const Name[],const Model[],Auto=0)
{
	new Bot = create_bot(Name);
	if(!Bot)
		return FAILED
	
	set_user_info(Bot,"model",Model);
	spawn_bot(Bot);
	
	return Bot
}
CheckBot(id)
{
	for(new Count = 1;Count < MAX_BOTS;Count++)
		if(id == g_Bots[Count])
			return Count
	
	return FAILED
}
public plugin_end()
	TravTrieDestroy(g_BotDialog);