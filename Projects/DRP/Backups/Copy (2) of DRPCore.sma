/*
* DRPCore.sma
* -------------------------------------
* Author(s):
* Drak - Main Author
* Hawk
* -------------------------------------
*/
#pragma dynamic 32768

#include <amxmodx>
#include <amxmisc>

#include <engine>
#include <fakemeta>

#include <sqlx>

#include <DRP/DRPCore>
#include <arrayx_travtrie>

#include <TSXWeapons>

#define HUNGER_OFFSET 567478
#define STD_USER_QUERIES 3
#define MAX_USER_CMSGS 6

#define AM 0
#define PM 1

new const VERSION[] = "0.1a BETA"
new const g_MonthDays[12] = {31,28,31,30,31,30,31,31,30,31,30,31};

// SQL Stuff
new Handle:g_SqlHandle
new g_Query[4096]
new g_Cache[4096]

// Files
new g_ConfigDir[128]
new g_LogDir[128]
new g_HelpDIR[128]

// SQL Connection
new const sql_Host[] = "DRP_SQL_Host"
new const sql_DB[] = "DRP_SQL_DB"
new const sql_Pass[] = "DRP_SQL_Pass"
new const sql_User[] = "DRP_SQL_User"

// SQL Tables
new g_UserTable[64] = "Users"
new g_JobsTable[64] = "Jobs"
new g_PropertyTable[64] = "Property"
new g_KeysTable[64] = "PropertyKeys"
new g_DoorsTable[64] = "PropertyDoors"
new g_ItemsTable[64] = "Items"
new g_DataTable[64] = "Data"

// Menus
new const g_ItemsDrop[] = "DRP_ItemsDrop"
new const g_ItemsGive[] = "DRP_ItemsGive"
new const g_ItemsOptions[] = "DRP_ItemsOptions"

// PCvars
new p_StartMoney
new p_HungerEnabled
new p_HungerEffects
new p_HungerTimer
new p_ItemsPerPage
new p_SalaryToWallet
new p_Log
new p_GameName
new p_Hostname
new p_Welcome[3]
new p_BlackOut
new p_RespawnTime

new p_AdminAccess
new p_MedicAccess
new p_CopAccess

// Arrays
new g_CommandArray
new g_CommandNum
new g_JobArray
new g_JobNum
new g_ItemsArray
new g_ItemsNum
new g_PropertyArray
new g_PropertyNum
new g_DoorArray
new g_DoorNum

new TravTrie:g_EventTrie
new TravTrie:g_MenuArray[33]
new TravTrie:g_ClassArray

new g_MenuAccepting[33]
new g_Menu[256]

new g_CurItem[33]
new g_ItemShow[33]
new g_SellAmount[33]

// User Data
new g_UserWallet[33]
new g_UserBank[33]
new g_UserHunger[33]
new g_UserJobID[33]
new g_UserSalary[33]
new g_UserAccess[33]
new g_AccessCache[33]
new g_UserJobRight[33]
new g_UserTime[33]
new g_UserAuthID[33][36]

// [0] = WeaponID
// [1] = Clip
// [2] = Ammo
// [3] = Mode
// [4] = Extra
new g_UserWpnID[33][5]

// Counters
new g_HungerCounter

new gmsgTSFade
new gmsgWeaponInfo
new gmsgScreenShake

new g_ItemsRegistered
new g_UserItemArray[33]

new g_Time
new g_Plugin
new g_PluginEnd

enum _:HUD_CVARS
{
	X = 0,
	Y,
	R,
	G,
	B
}

new p_Hud[HUD_NUM][HUD_CVARS]
new TravTrie:g_HudArray[33][HUD_NUM]
new g_HudObjects[HUD_NUM]
new g_HudPending

// Player Error Checking
new g_GotInfo[33]
new bool:g_Saving[33] = false
new bool:g_Joined[33] = false
new bool:g_BadJob[33] = false
new bool:g_BadAuthID[33] = false
new g_Display[33] = {1,...}

// Native Forwards
new g_HudForward
new g_ClassForward
new g_EventForward

// Precaches
new const g_ItemDrop[] = "items/ammopickup1.wav"
new const g_ItemPickUp[] = "items/gunpickup2.wav"

// [0] = Seconds
// [1] = Minutes
// [2] = Hours
// [3] = AM/PM
// [4] = Month
// [5] = Month Day
// [6] = Year
new g_WorldTime[7]

// DO NOT EDIT ANYTHING BELOW THIS LINE
// UNLESS YOU KNOW WHAT YOU'RE DOING
public plugin_precache()
{
	g_Plugin = register_plugin("DRP Core",VERSION,"Drak");
	
	// CVars 
	p_StartMoney = register_cvar("DRP_StartBankCash","100");
	p_HungerEnabled = register_cvar("DRP_HungerEnable","1");
	p_HungerEffects = register_cvar("DRP_HungerEffects","1");
	p_HungerTimer = register_cvar("DRP_HungerTimer","30");
	
	register_cvar("DRP_GodDoors","0"); 
	register_cvar("DRP_GodBreakables","0");
	
	p_ItemsPerPage = register_cvar("DRP_ItemsPerPage","30");
	p_SalaryToWallet = register_cvar("DRP_SalaryToWallet","0");
	p_BlackOut = register_cvar("DRP_BlackScreen","1");
	
	p_Log = register_cvar("DRP_LogType","0");
	p_GameName = register_cvar("DRP_GameName","OzForceRP");
	
	p_Hostname = get_cvar_pointer("hostname");
	p_RespawnTime = get_cvar_pointer("respawntime");
	
	p_Welcome[0] = register_cvar("DRP_Welcome_Msg1","Welcome #name# to #hostname#");
	p_Welcome[1] = register_cvar("DRP_Welcome_Msg2","Enjoy your stay");
	p_Welcome[2] = register_cvar("DRP_Welcome_Msg3","");
	
	register_cvar(sql_Host,"",FCVAR_PROTECTED);
	register_cvar(sql_DB,"",FCVAR_PROTECTED);
	register_cvar(sql_Pass,"",FCVAR_PROTECTED);
	register_cvar(sql_User,"",FCVAR_PROTECTED);
	
	register_clcmd("drp_testfunc","CmdTest");
	
	// Access
	p_MedicAccess = register_cvar(g_MedicsAccessCvar,"b"); // Access Letter for Medics
	p_AdminAccess = register_cvar(g_AdminAccessCvar,"z"); // Access Letter for DRP admins. (Rights to set job/create money, etc)
	p_CopAccess = register_cvar(g_CopAccessCvar,"a");
	
	for(new Count,Cvar[33];Count < HUD_NUM;Count++)
	{
		format(Cvar,32,"DRP_HUD%d_X",Count + 1);
		p_Hud[Count][X] = register_cvar(Cvar,"");
		
		format(Cvar,32,"DRP_HUD%d_Y",Count + 1);
		p_Hud[Count][Y] = register_cvar(Cvar,"");
		
		format(Cvar,32,"DRP_HUD%d_R",Count + 1);
		p_Hud[Count][R] = register_cvar(Cvar,"");
		
		format(Cvar,32,"DRP_HUD%d_G",Count + 1);
		p_Hud[Count][G] = register_cvar(Cvar,"");
		
		format(Cvar,32,"DRP_HUD%d_B",Count + 1);
		p_Hud[Count][B] = register_cvar(Cvar,"");
	}
	
	if(file_exists(g_ItemMdl))
		precache_model(g_ItemMdl);
	else
	{
		UTIL_Error(0,1,"Item model missing: %s",0,g_ItemMdl);
		return 
	}
	if(file_exists(g_MoneyMdl))
		precache_model(g_MoneyMdl);
	else
	{
		UTIL_Error(0,1,"Money model missing: %s",0,g_MoneyMdl);
		return 
	}
	
	get_localinfo("amxx_logs",g_LogDir,127);
	format(g_LogDir,127,"%s/DRP",g_LogDir);
	
	if(!dir_exists(g_LogDir))
	{
		if(mkdir(g_LogDir) != 0)
		{
			UTIL_Error(0,1,"Unable to create the DRP Log Dir (Folder) (%s)",0,g_LogDir);
			return
		}
	}
	
	precache_sound(g_ItemDrop);
	precache_sound(g_ItemPickUp);
	
	new MapName[33],ConfigFile[128]
	get_mapname(MapName,32);
	
	get_localinfo("amxx_configsdir",ConfigFile,127);
	format(g_ConfigDir,127,"%s/DRP/%s",ConfigFile,MapName);
	
	if(!dir_exists(g_ConfigDir))
	{
		if(mkdir(g_ConfigDir) != 0)
		{
			UTIL_Error(0,1,"Unable to create Core Map Dir (Folder). (%s)",0,g_ConfigDir);
			return
		}
	}
	
	add(ConfigFile,127,"/DRP/DRPCore.cfg");
	
	if(!file_exists(ConfigFile))
	{
		UTIL_Error(0,1,"Unable to open the DRP Core Config File. (%s)",0,ConfigFile);
		return
	}

	new pFile = fopen(ConfigFile,"r");
	if(!pFile)
	{
		UTIL_Error(0,1,"Unable to open DRP Core Config File. (%s)",0,ConfigFile);
		return
	}
	
	UTIL_LoadConfigFile(pFile);
	
	// Arrays
	g_CommandArray = array_create();
	g_JobArray = array_create();
	g_ItemsArray = array_create();
	g_PropertyArray = array_create();
	g_DoorArray = array_create();
	
	g_ClassArray = TravTrieCreate();
	g_EventTrie = TravTrieCreate();

	for(new Count,Count2;Count <= get_maxplayers();Count++)
	{
		g_UserItemArray[Count] = array_create();
		g_MenuArray[Count] = TravTrieCreate();
		
		for(Count2 = 0;Count2 < HUD_NUM;Count2++)
			g_HudArray[Count][Count2] = TravTrieCreate(256,_);
	}
	
	// Forwards
	register_forward(FM_GetGameDescription,"forward_GameDescription");
	register_forward(FM_PlayerPreThink,"forward_PreThink");
	
	register_forward(FM_ClientKill,"fw_ClientKill");
	register_forward(FM_Sys_Error,"fw_SysError");
	
	// Native Forwards
	g_HudForward = CreateMultiForward("DRP_HudDisplay",ET_IGNORE,FP_CELL,FP_CELL);
	g_ClassForward = CreateMultiForward("DRP_ClassLoaded",ET_IGNORE,FP_CELL,FP_STRING);
	g_EventForward = CreateMultiForward("DRP_Event",ET_STOP2,FP_STRING,FP_ARRAY,FP_CELL);
	
	g_ItemsRegistered = 1
	
	new Forward = CreateMultiForward("DRP_RegisterItems",ET_IGNORE),Return
	if(Forward <= 0 || !ExecuteForward(Forward,Return)) 
		UTIL_Error(0,1,"Could not execute ^"DRP_RegisterItems^" forward.",0);
	
	DestroyForward(Forward);
	
	g_ItemsRegistered = 0
	
	LoadHelpFiles();
	SQLInit();
}
public plugin_init()
{
	register_cvar("DRP_Version",VERSION,FCVAR_SERVER);
	
	// Old HarbuRP Commands
	register_clcmd("amx_joblist","CmdJobList"); // REMOVE ME
	register_clcmd("amx_itemlist","CmdItemList"); // REMOVE ME
	register_clcmd("say !info","CmdInfo",ADMIN_LEVEL_H); // TEST COMMAND
	
	DRP_RegisterCmd("drp_joblist","CmdJobList","Lists all the jobs in the database");
	DRP_RegisterCmd("drp_itemlist","CmdItemList","List all the items in the database");
	DRP_RegisterCmd("drp_help","CmdHelp","Shows a list of commands you can use");
	
	DRP_RegisterCmd("say /buy","CmdBuy","Allows you to activate (use) the NPC/Property your facing");
	DRP_RegisterCmd("say /items","CmdItems","Opens your inventory");
	DRP_RegisterCmd("say /menu","CmdMenu","Opens a Quick-Access menu");
	DRP_RegisterCmd("say /iteminfo","CmdItemInfo","Allows you to view info on the item last shown to you");
	
	register_srvcmd("DRP_DumpInfo","CmdDump");
	
	// Menus
	register_menucmd(register_menuid(g_ItemsOptions),g_Keys,"ItemsOptions");
	register_menucmd(register_menuid(g_ItemsDrop),g_Keys,"ItemsDrop");
	register_menucmd(register_menuid(g_ItemsGive),g_Keys,"ItemsGive");
	
	new ConfigsDir[128]
	get_localinfo("amxx_configsdir",ConfigsDir,127);
	
	server_cmd("exec %s/DRP/DRPCore.cfg",ConfigsDir);
	server_exec();
	
	// Events
	register_event("DeathMsg","EventDeathMsg","a");
	register_event("ResetHUD","EventResetHUD","b");
	register_event("WeaponInfo","EventWpnInfo","b");
	
	for(new Count;Count < HUD_NUM;Count++)
		g_HudObjects[Count] = CreateHudSyncObj();
	
	// Entity 'Godding'
	new pGodDoors = get_cvar_num("DRP_GodDoors");
	if(pGodDoors)
	{
		new Ent
		if(pGodDoors == 2)
		{
			new szData[36]
			while(( Ent = engfunc(EngFunc_FindEntityByString,Ent,"classname","func_door")) != 0)
			{
				pev(Ent,pev_targetname,szData,35);
				if(equali(szData,"DRPGodDoor"))
					set_pev(Ent,pev_takedamage,0.0);
			}
			
			Ent = 0
			while(( Ent = engfunc(EngFunc_FindEntityByString,Ent,"classname","func_door_rotating")) != 0)
			{
				pev(Ent,pev_targetname,szData,35);
				if(equali(szData,"DRPGodDoor"))
					set_pev(Ent,pev_takedamage,0.0);
			}
		}
		else
		{		
			while(( Ent = engfunc(EngFunc_FindEntityByString,Ent,"classname","func_door_rotating")) != 0)
				set_pev(Ent,pev_takedamage,0.0);
			
			Ent = 0
			while(( Ent = engfunc(EngFunc_FindEntityByString,Ent,"classname","func_door")) != 0)
				set_pev(Ent,pev_takedamage,0.0);
		}
	}
	new pGodBreakables = get_cvar_num("DRP_GodBreakables");
	if(pGodBreakables)
	{
		new Ent
		if(pGodBreakables == 2)
		{
			new szData[36]
			while(( Ent = engfunc(EngFunc_FindEntityByString,Ent,"classname","func_breakable")) != 0)
			{
				pev(Ent,pev_targetname,szData,35);
				if(equali(szData,"DRPWinGod"))
					set_pev(Ent,pev_takedamage,0.0);
			}
		}
		else
		{			
			Ent = 0
			while(( Ent = engfunc(EngFunc_FindEntityByString,Ent,"classname","func_breakable")) != 0)
				set_pev(Ent,pev_takedamage,0.0);
		}
	}
	
	gmsgTSFade = get_user_msgid("TSFade");
	gmsgScreenShake = get_user_msgid("ScreenShake");
	gmsgWeaponInfo = get_user_msgid("WeaponInfo");
	
	// Tasks
	set_task(1.0,"ShowHud",_,_,_,"b");
}
public forward_GameDescription()
{
	static GameName[33]
	get_pcvar_string(p_GameName,GameName,32);
	
	if(GameName[0])
	{
		forward_return(FMV_STRING,GameName);
		return FMRES_SUPERCEDE
	}
	
	return FMRES_IGNORED
}
public CmdDump(id)
{
	new Temp[256],Date[26]
	get_time("%m-%d-%Y",Date,25);
	
	format(Temp,255,"%s/DRPDump-%s.log",g_ConfigDir,Date);
	
	if(file_exists(Temp))
		delete_file(Temp);
	
	new pFile = fopen(Temp,"w+");
	if(!pFile)
		return server_print("[DRP] Unable to open / write dump file (%s)",Temp);
	
	fclose(pFile);
	return server_print("[DRP] Dump Successful.");
}
public CmdTest(id)
{
	//client_print(id,print_chat,"$$$%d",g_SellAmount[id]);
	//CmdHungerTest(id);
	HandleHunger(id);
	
	
	/*
	new Float:Origin[3]
	pev(id,pev_origin,Origin);
	
	DRP_DropItem(1,100000,Origin);
	DRP_DropCash(10066,Origin);
	
	new lol[33]
	new Stuff = array_get_int(g_ItemsArray,1);
	array_get_string(Stuff,1,lol,32);
	server_print("Stuff: %s",lol);
	
	g_UserHunger[id] = 118
	
	new Ent = engfunc(EngFunc_CreateNamedEntity,engfunc(EngFunc_AllocString,"info_target"))
	engfunc(EngFunc_SetModel,Ent,"models/pellet.mdl");
	engfunc(EngFunc_SetOrigin,Ent,Float:{4096.0,4096.0,4096.0});
	
	set_pev(Ent,pev_owner,id);
	
	engfunc(EngFunc_SetView,id,Ent);
	*/
}
	/*
	new MiscText[1024]
	
	DRP_MiscSetText("fuckyeah","Dude, i love tits");
	DRP_MiscGetText("fuckyeah",MiscText,1023);
	
	server_print("GOT STRING: %s",MiscText);
	*/
	/*
	message_begin(MSG_ONE,get_user_msgid("KFuPower"),_,id);
	write_byte(42);
	message_end();
	*/
	/*
	set_pdata_int(id,453,8)//constant for slowpause
	set_pdata_int(id,455,10)//duration of powerup
	set_pdata_int(id,456,10)//same
	set_pdata_int(id,457,8)//same

	//fm_set_rendering(id,kRenderFxGlowShell,10,15,45,kRenderNormal,25.0)
	new plModel[64]
	get_user_info(id,"model",plModel,63);
	
	if(!plModel[0])
		return
	
	pev(id,pev_viewmodel2,plModel,63);
	set_pev(id,pev_viewmodel2,"");
	
	new ent = engfunc(EngFunc_CreateNamedEntity,engfunc(EngFunc_AllocString,"info_target"));
	if(!ent)
		return
	
	dllfunc(DLLFunc_Spawn,ent);
	
	set_pev(ent,pev_classname,"fakePlayer");
	set_pev(ent,pev_movetype,MOVETYPE_FOLLOW);
	set_pev(ent,pev_aiment,id);
	
	engfunc(EngFunc_SetModel,ent,plModel);
	
	client_print(id,print_chat,"Model Fake Created");
	
	fm_set_rendering(ent,kRenderFxGlowShell,10,15,45,kRenderNormal,25.0);
	
	new ent = engfunc(EngFunc_CreateNamedEntity,engfunc(EngFunc_AllocString,"info_target"));
	if(!ent)
		return
	
	dllfunc(DLLFunc_Spawn,ent);
	
	set_pev(ent,pev_classname,"fakePlayer");
	set_pev(ent,pev_movetype,MOVETYPE_FOLLOW);
	set_pev(ent,pev_aiment,id);
	
	engfunc(EngFunc_SetModel,ent,"models/player/gordon/gordon.mdl");
	
	client_print(id,print_chat,"Model Fake Created");
	
	fm_set_rendering(ent,kRenderFxGlowShell,10,15,45,kRenderNormal,25.0);
	
	//set_entity_visibility(id,0);
	for(new Count;Count <= g_ItemsNum;Count++)
	{
		server_print("ITEM ID IN ARRAY: %d",g_ItemIDs[Count]);
	}
	if(UTIL_ValidItemID(100))
		server_print("VALID")
	else
		server_print("VALIDDDD NO");
		
	dllfunc(DLLFunc_Spawn,2,2)
	entity_set_int(id,EV_INT_effects,entity_get_int(id,EV_INT_effects) & EF_BRIGHTLIGHT);
	entity_set_int(id,EV_INT_effects,entity_get_int(id,EV_INT_effects) & EF_LIGHT);
	
	new Float:speed = get_user_maxspeed(id)
	speed -= float(160)
	set_user_maxspeed(id,speed)
	
	for(new Count;Count <= g_ItemsNum;Count++)
		client_print(0,print_console,"ITEM: %d",g_ItemIDs[Count]);
	
	client_print(id,print_console,"SIZE: %d - %d - %d",array_memory2(g_UserItemArray[id]),array_memory2(g_ItemsArray),array_get_int(g_UserItemArray[id],116))/*
	
	if(!pev_valid(FakeWeaponID[id]))
		FakeWeaponID[id] = engfunc(EngFunc_CreateNamedEntity,engfunc(EngFunc_AllocString,"info_target"))
		if(pev_valid(FakeWeaponID[id]))
		{
			dllfunc(DLLFunc_Spawn,    FakeWeaponID[id])
            set_pev(FakeWeaponID[id],   pev_classname,  "FakeWeapon")
            set_pev(FakeWeaponID[id],   pev_movetype,    MOVETYPE_FOLLOW)
            set_pev(FakeWeaponID[id],   pev_aiment,            id)
			
			client_print(id,print_chat,"YOUUUU GOT THE WEAPON");
		}
		
		new weaponstr[32]
		pev(id,pev_weaponmodel2,weaponstr,30);
		set_pev(id,pev_weaponmodel2,"");
		
		engfunc(EngFunc_SetModel,FakeWeaponID[id],weaponstr);
		
		//   fm_entity_set_model(FakeWeaponID[id],         weaponstr)  //Apply the weapon stored above to our fake weapon
			set_pev(FakeWeaponID[id],   pev_renderfx,  kRenderFxGlowShell)   //Render Away!
			set_pev(FakeWeaponID[id],   pev_rendercolor,   {10.0, 115.0, 85.0}) //R, G, B
			set_pev(FakeWeaponID[id],   pev_rendermode,        kRenderNormal)
		set_pev(FakeWeaponID[id],   pev_renderamt,  50.0) 
		
		DRP_DropCash(id,10);
		*/
public CmdInfo(id)
{
	client_print(id,print_console,"[AMXX] Bad Job: %s",g_BadJob[id] ? "Yes" : "No")
	client_print(id,print_console,"[AMXX] Bad AuthID: %s",g_BadAuthID[id] ? "Yes" : "No")
	client_print(id,print_console,"[AMXX] Joined: %s",g_Joined[id] ? "Yes" : "No")
	client_print(id,print_console,"[AMXX] Got Info: %s",g_GotInfo[id] ? "Yes" : "No")
	client_print(id,print_console,"[AMXX] Saving: %s",g_Saving[id] ? "Yes" : "No")
}
/*==================================================================================================================================================*/
LoadHelpFiles()
{
	get_localinfo("amxx_configsdir",g_HelpDIR,255);
	add(g_HelpDIR,255,"/DRP/MOTD");
	
	if(!dir_exists(g_HelpDIR))
	{
		if(mkdir(g_HelpDIR) != 0)
		{
			UTIL_Error(0,1,"[MOTD CHECKER] Unable to Create Help(MOTD) Dir (%s)",0,g_HelpDIR);
			return
		}
	}
	
	new Data[128],File[33],Count[3]
	new pFile,OpenDIR = open_dir(g_HelpDIR,Data,127);

	if(!OpenDIR)
	{
		UTIL_Error(0,1,"[MOTD CHECKER] OpenDIR Failed (%s)",0,g_HelpDIR);
		return
	}
	
	new bool:MakeCommand = false
	while(next_file(OpenDIR,Data,127))
	{
		Count[0] = 0
		
		if(equali(Data,"Readme.txt"))
			continue
		
		format(Data,127,"%s/%s",g_HelpDIR,Data);
		pFile = fopen(Data,"r");
		
		if(!pFile)
			continue
		
		MakeCommand = false
		
		remove_filepath(Data,Data,127);
		copy(File,32,Data);
		
		while(!feof(pFile))
		{
			fgets(pFile,Data,127);
			Count[0] += strlen(Data);
			
			if(containi(Data,"*CMD") != -1)
				MakeCommand = true
			
			if(Count[0] >= 1535)
			{
				server_print("[MOTD CHECKER] WARNING: File ^"%s^" is to large.",File);
				Count[2]++
				break
			}
		}
		
		if(MakeCommand)
		{
			strtok(File,File,32,Data,127,'.',1);
			
			format(File,127,"say /%s",File);
			
			register_clcmd(File,"CmdMotd");
		}
		
		Count[1]++
		fclose(pFile);
	}
	server_print("[MOTD CHECKER] %d files checked. (%d Error(s))",Count[1],Count[2]);
	close_dir(OpenDIR);
}
SQLInit()
{
	new sqlHost[36],sqlDB[36],sqlPass[36],sqlUser[36]
	
	get_cvar_string(sql_Host,sqlHost,35);
	get_cvar_string(sql_DB,sqlDB,35);
	get_cvar_string(sql_User,sqlUser,35);
	get_cvar_string(sql_Pass,sqlPass,35);

	g_SqlHandle = SQL_MakeDbTuple(sqlHost,sqlUser,sqlPass,sqlDB);
	
	if(!g_SqlHandle || g_SqlHandle == Empty_Handle)
		return UTIL_Error(0,1,"Failed to create SQL tuple.",0);
	
	format(g_Query,4095,"CREATE TABLE IF NOT EXISTS %s (JobName VARCHAR(32),JobSalary INT(11),JobAccess VARCHAR(27),UNIQUE KEY (JobName))",g_JobsTable);
	UTIL_CleverQuery(g_Plugin,g_SqlHandle,"IgnoreHandle",g_Query)
	
	format(g_Query,4095,"CREATE TABLE IF NOT EXISTS %s (Internalname VARCHAR(66),Externalname VARCHAR(66),Ownername VARCHAR(40),OwnerAuthID VARCHAR(36),Price INT(11),Locked INT(11),Access VARCHAR(27),Profit INT(11),UNIQUE KEY (Internalname))",g_PropertyTable)
	UTIL_CleverQuery(g_Plugin,g_SqlHandle,"IgnoreHandle",g_Query)
	
	format(g_Query,4095,"CREATE TABLE IF NOT EXISTS %s (AuthIDName VARCHAR(64),Num INT(11),UNIQUE KEY (AuthIDName))",g_ItemsTable)
	UTIL_CleverQuery(g_Plugin,g_SqlHandle,"IgnoreHandle",g_Query)
	
	format(g_Query,4095,"CREATE TABLE IF NOT EXISTS %s (Targetname VARCHAR(36),Internalname VARCHAR(66),UNIQUE KEY (Targetname))",g_DoorsTable);
	UTIL_CleverQuery(g_Plugin,g_SqlHandle,"IgnoreHandle",g_Query);
	
	format(g_Query,4095,"CREATE TABLE IF NOT EXISTS %s (AuthIDKey VARCHAR(64),UNIQUE KEY (AuthIDKey))",g_KeysTable);
	UTIL_CleverQuery(g_Plugin,g_SqlHandle,"IgnoreHandle",g_Query);
	
	format(g_Query,4095,"CREATE TABLE IF NOT EXISTS `ItemDrops` (ItemName VARCHAR(33),Num INT(11),X FLOAT(11),Y FLOAT(11),Z FLOAT(11))");
	UTIL_CleverQuery(g_Plugin,g_SqlHandle,"IgnoreHandle",g_Query);
	
	format(g_Query,4095,"CREATE TABLE IF NOT EXISTS %s (ClassKey VARCHAR(64),Value TEXT,UNIQUE KEY (ClassKey))",g_DataTable);
	UTIL_CleverQuery(g_Plugin,g_SqlHandle,"IgnoreHandle",g_Query);

	format(g_Query,4095,"CREATE TABLE IF NOT EXISTS %s (SteamID VARCHAR(36),BankMoney INT(11),WalletMoney INT(11),JobName VARCHAR(33),Hunger INT(11),Access VARCHAR(24),JobRight VARCHAR(24),PlayTime INT(11),UNIQUE KEY (SteamID))",g_UserTable);
	UTIL_CleverQuery(g_Plugin,g_SqlHandle,"IgnoreHandle",g_Query);
	
	// Load the Data from the SQL DB
	format(g_Query,4095,"SELECT * FROM %s",g_JobsTable);
	UTIL_CleverQuery(g_Plugin,g_SqlHandle,"FetchJobs",g_Query);
	
	format(g_Query,4095,"SELECT * FROM %s",g_PropertyTable);
	UTIL_CleverQuery(g_Plugin,g_SqlHandle,"FetchProperty",g_Query);
	
	format(g_Query,4095,"SELECT * FROM %s",g_DoorsTable);
	UTIL_CleverQuery(g_Plugin,g_SqlHandle,"FetchDoors",g_Query);
	
	format(g_Query,4095,"SELECT * FROM ItemDrops");
	UTIL_CleverQuery(g_Plugin,g_SqlHandle,"FetchItemDrops",g_Query);
	
	format(g_Query,4095,"SELECT * FROM Time");
	UTIL_CleverQuery(g_Plugin,g_SqlHandle,"FetchWorldTime",g_Query);
	
	new Forward = CreateMultiForward("DRP_Init",ET_IGNORE),Return
	if(Forward <= 0 || !ExecuteForward(Forward,Return))
		return UTIL_Error(0,1,"Could not execute ^"DRP_Init^" forward.",0);
	
	return DestroyForward(Forward);
}
public FetchItemDrops(FailState,Handle:Query,Error[],Errcode,Data[],DataSize)
{
	if(FailState == TQUERY_CONNECT_FAILED)
	{
		UTIL_Error(0,1,"Could not connect to SQL database. (Error: %s)",0,Error ? Error : "UNKNOWN");
		return FAILED
	}
	else if(FailState == TQUERY_QUERY_FAILED)
	{
		SQL_QueryError(Query,g_Query,4095);
		return UTIL_Error(0,1,"Query Failed (Error: %s)",0,g_Query);
	}
	if(Errcode)
	{
		UTIL_Error(0,1,"SQL ErrorCode (Error: %s)",0,Error);
		return FAILED
	}
	
	if(!SQL_NumResults(Query))
		return PLUGIN_CONTINUE
	
	new Float:fOrigin[3],iOrigin[3],ItemName[33]
	while(SQL_MoreResults(Query))
	{
		SQL_ReadResult(Query,0,ItemName,32);
		
		iOrigin[0] = SQL_ReadResult(Query,2);
		iOrigin[1] = SQL_ReadResult(Query,3);
		iOrigin[2] = SQL_ReadResult(Query,4);
		
		IVecFVec(iOrigin,fOrigin);
		_CreateItemDrop(_,fOrigin,SQL_ReadResult(Query,1),ItemName,false,SQL_ReadResult(Query,5));
		
		SQL_NextRow(Query);
	}
	return PLUGIN_CONTINUE
}
public FetchProperty(FailState,Handle:Query,Error[],Errcode,Data[],DataSize)
{
	if(FailState == TQUERY_CONNECT_FAILED)
	{
		UTIL_Error(0,1,"Could not connect to SQL database. (Error: %s)",0,Error ? Error : "UNKNOWN");
		return FAILED
	}
	else if(FailState == TQUERY_QUERY_FAILED)
	{
		SQL_QueryError(Query,g_Query,4095);
		return UTIL_Error(0,1,"Query Failed (Error: %s)",0,g_Query);
	}
	if(Errcode)
	{
		UTIL_Error(0,1,"SQL ErrorCode (Error: %s)",0,Error);
		return FAILED
	}
	
	if(!SQL_NumResults(Query))
		return PLUGIN_CONTINUE
	
	new InternalName[127],ExternalName[64],OwnerName[33],OwnerAuthid[36],Price,Locked,AccessStr[JOB_ACCESSES + 1],Access,Profit,CurArray
	while(SQL_MoreResults(Query))
	{
		SQL_ReadResult(Query,0,InternalName,63);
		SQL_ReadResult(Query,1,ExternalName,63);
		SQL_ReadResult(Query,2,OwnerName,32);
		SQL_ReadResult(Query,3,OwnerAuthid,35);
		Price = SQL_ReadResult(Query,4);
		Locked = SQL_ReadResult(Query,5);
		SQL_ReadResult(Query,6,AccessStr,JOB_ACCESSES);
		Access = DRP_AccessToInt(AccessStr);
		Profit = SQL_ReadResult(Query,7);
		
		CurArray = array_create();
		
		array_set_int(g_PropertyArray,g_PropertyNum++,CurArray);
		
		array_set_string(CurArray,0,InternalName);
		array_set_string(CurArray,1,ExternalName);
		array_set_string(CurArray,2,OwnerName);
		array_set_string(CurArray,3,OwnerAuthid);
		array_set_int(CurArray,4,Price);
		array_set_int(CurArray,5,Locked);
		array_set_int(CurArray,6,Access);
		array_set_int(CurArray,7,Profit);
		array_set_int(CurArray,8,0);
		array_set_int(CurArray,9,0);
		
		SQL_ReadResult(Query,8,InternalName,127);
		array_set_string(CurArray,10,InternalName);
		
		SQL_NextRow(Query);
	}
	
	return PLUGIN_CONTINUE
}
public FetchDoors(FailState,Handle:Query,Error[],Errcode,Data[],DataSize)
{
	if(FailState == TQUERY_CONNECT_FAILED)
	{
		UTIL_Error(0,1,"Could not connect to SQL database. (Error: %s)",0,Error ? Error : "UNKNOWN");
		return FAILED
	}
	else if(FailState == TQUERY_QUERY_FAILED)
	{
		SQL_QueryError(Query,g_Query,4095);
		return UTIL_Error(0,1,"Query Failed (Error: %s)",0,g_Query);
	}
	if(Errcode)
	{
		UTIL_Error(0,1,"SQL ErrorCode (Error: %s)",0,Error);
		return FAILED
	}
	
	if(!SQL_NumResults(Query))
		return PLUGIN_CONTINUE
	
	new Targetname[64],InternalName[64],CurArray
	while(SQL_MoreResults(Query))
	{		
		SQL_ReadResult(Query,0,Targetname,63);
		SQL_ReadResult(Query,1,InternalName,63);
		
		CurArray = array_create();
		array_set_int(g_DoorArray,g_DoorNum++,CurArray);
		
		if(equali(Targetname,"e|",2))
		{
			replace(Targetname,63,"e|","");
			
			array_set_string(CurArray,0,"");
			array_set_int(CurArray,1,str_to_num(Targetname));
		}
		else if(equali(Targetname,"t|",2))
		{
			replace(Targetname,63,"t|","");
			
			array_set_string(CurArray,0,Targetname);
			array_set_int(CurArray,1,0);
		}
		
		array_set_string(CurArray,2,InternalName);
		array_set_int(CurArray,3,0);
		
		SQL_NextRow(Query);
	}
	
	return PLUGIN_CONTINUE
}
public FetchJobs(FailState,Handle:Query,Error[],Errcode,Data[],DataSize)
{
	if(FailState == TQUERY_CONNECT_FAILED)
	{
		UTIL_Error(0,1,"Could not connect to SQL database. (Error: %s)",0,Error ? Error : "UNKNOWN");
		return FAILED
	}
	else if(FailState == TQUERY_QUERY_FAILED)
	{
		SQL_QueryError(Query,g_Query,4095);
		return UTIL_Error(0,1,"Query Failed (Error: %s)",0,g_Query);
	}
	if(Errcode)
	{
		UTIL_Error(0,1,"SQL ErrorCode (Error: %s)",0,Error);
		return FAILED
	}
	
	if(!SQL_NumResults(Query))
		return PLUGIN_CONTINUE
	
	new Temp[JOB_ACCESSES + 1],CurArray
	while(SQL_MoreResults(Query))
	{
		CurArray = array_create();
		array_set_int(g_JobArray,g_JobNum++,CurArray);
		
		SQL_ReadResult(Query,0,g_Query,4095);
		array_set_string(CurArray,1,g_Query);
		
		array_set_int(CurArray,2,SQL_ReadResult(Query,1));
		
		SQL_ReadResult(Query,2,Temp,JOB_ACCESSES);
		array_set_int(CurArray,3,DRP_AccessToInt(Temp));
		
		SQL_NextRow(Query);
	}
	
	new Forward = CreateMultiForward("DRP_JobsInit",ET_IGNORE),Return
	if(Forward <= 0 || !ExecuteForward(Forward,Return))
		return UTIL_Error(0,1,"Could not execute ^"DRP_JobsInit^" forward.",0);
	
	DestroyForward(Forward);
	
	return PLUGIN_CONTINUE
}
public FetchWorldTime(FailState,Handle:Query,Error[],Errcode,Data[],DataSize)
{
	if(FailState == TQUERY_CONNECT_FAILED)
	{
		UTIL_Error(0,1,"Could not connect to SQL database. (Error: %s)",0,Error ? Error : "UNKNOWN");
		return FAILED
	}
	else if(FailState == TQUERY_QUERY_FAILED)
	{
		SQL_QueryError(Query,g_Query,4095);
		return UTIL_Error(0,1,"Query Failed (Error: %s)",0,g_Query);
	}
	if(Errcode)
	{
		UTIL_Error(0,1,"SQL ErrorCode (Error: %s)",0,Error);
		return FAILED
	}
	
	if(SQL_NumResults(Query) > 1)
		return UTIL_Error(0,1,"Time Error. There is more than one time entry in the SQL.",0);
	
	new Time[128]
	SQL_ReadResult(Query,0,Time,127);
	
	new StrMin[4],StrHour[4],StrMonth[4],StrMonthDay[4],StrYear[6],StrAM[4]
	parse(Time,StrMin,3,StrHour,3,StrMonth,3,StrMonthDay,3,StrYear,5,StrAM,3);
	
	g_WorldTime[1] = str_to_num(StrMin);
	g_WorldTime[2] = str_to_num(StrHour);
	g_WorldTime[3] = str_to_num(StrAM)// ? AM : PM
	g_WorldTime[4] = str_to_num(StrMonth);
	g_WorldTime[5] = str_to_num(StrMonthDay);
	g_WorldTime[6] = str_to_num(StrYear);
	
	return PLUGIN_CONTINUE
}
/*==================================================================================================================================================*/
// Commands
public CmdBuy(id)
{
	if(!is_user_alive(id))
		return PLUGIN_HANDLED
	
	new Index,Body
	get_user_aiming(id,Index,Body,100);
	
	if(!pev_valid(Index))
		return PLUGIN_HANDLED
	
	static Targetname[64]
	pev(Index,pev_classname,Targetname,63);
	
	if(equali(Targetname,g_szNPCName))
		return _CallNPC(id,Index);
	
	pev(Index,pev_targetname,Targetname,63);
	
	new const Property = UTIL_GetProperty(Targetname,Index);
	if(Property == -1)
		return PLUGIN_HANDLED
	
	new CurArray = array_get_int(g_PropertyArray,Property),AuthID[36],OtherAuthID[36],Name[33]
	get_user_authid(id,AuthID,35);
	
	array_get_string(CurArray,2,Name,32);
	array_get_string(CurArray,3,OtherAuthID,36);
	
	new Price = array_get_int(CurArray,4);

	if(equali(AuthID,OtherAuthID))
	{
		client_print(id,print_chat,"[DRP] You already own this property.");
		return PLUGIN_HANDLED
	}
	else if(OtherAuthID[0] && !Price)
	{
		client_print(id,print_chat,"[DRP] This property is already owned by %s.",Name);
		return PLUGIN_HANDLED
	}
	
	new Data[2]
	Data[0] = id
	Data[1] = Property
	
	if(_CallEvent("Property_Buy",Data,2))
		return PLUGIN_HANDLED
	
	if(Price > g_UserBank[id])
	{
		client_print(id,print_chat,"[DRP] You do not have enough money in your bank to buy this property.");
		return PLUGIN_HANDLED
	}
	new Selling = (OtherAuthID[0] && Price) ? 1 : 0
	
	return PLUGIN_HANDLED
	
	/*
	
	new Data[2]
	Data[0] = id
	Data[1] = Property
	
	if(_CallEvent("Property_Buy",Data,2))
		return PLUGIN_HANDLED
	
	if(Price > g_UserBank[id])
	{
		client_print(id,print_chat,"[DRP] You do not have enough money in your bank to buy this property.");
		return PLUGIN_HANDLED
	}
	
	new Selling = OtherAuthID[0] && Price ? 1 : 0
	get_user_name(id,Name,32);
	
	if(Selling)
	{
	}
	
	array_set_string(CurArray,2,Name);
	array_set_string(CurArray,3,AuthID);
	array_get_string(CurArray,0,Targetname,63);
	
	array_set_int(CurArray,4,0);
	array_set_int(CurArray,8,0);
	array_set_int(CurArray,9,1);
	
	g_UserBank[id] -= Price
	
	format(g_Query,4095,"DELETE FROM %s WHERE authidkey LIKE '%%|%s'",g_KeysTable,Targetname);
	UTIL_CleverQuery(g_Plugin,g_SqlHandle,"IgnoreHandle",g_Query)
	
	return PLUGIN_HANDLED
	*/
}
public CmdMotd(id)
{
	new File[128]
	read_argv(1,File,127);
	
	format(File,127,"%s%s.txt",g_HelpDIR,File);
	
	if(!file_exists(File))
	{
		client_print(id,print_chat,"[DRP] Unable to open file. (%s)",File);
		return PLUGIN_HANDLED
	}
	
	show_motd(id,File,"DRP");
	return PLUGIN_HANDLED
}
public CmdItems(id)
{
	ItemMenu(id);
	return PLUGIN_HANDLED
}
ItemMenu(id)
{	
	if(!is_user_alive(id))
		return PLUGIN_HANDLED
	
	new Success,Num,ItemID,Size = array_size(g_UserItemArray[id]);
	if(Size < 1)
	{
		client_print(id,print_chat,"[DRP] There are no items in your inventory.");
		return PLUGIN_HANDLED
	}
	
	new Menu = menu_create("Item Menu","ItemsHandle"),ItemName[33],Item[128]
	while(Num < Size && (ItemID = array_get_nth(g_UserItemArray[id],++Num,_,Success)) != 0 && Success)
	{
		UTIL_ValidItemID(ItemID) ?
			UTIL_GetItemName(ItemID,ItemName,32) : copy(ItemName,32,"BAD ITEMID : Contact Admin");
			
		formatex(Item,127,"%s x %d",ItemName,UTIL_GetUserItemNum(id,ItemID));
		menu_additem(Menu,Item);
	}
	menu_display(id,Menu);
	return PLUGIN_HANDLED
}
public ItemsHandle(id,Menu,Item)
{
	menu_destroy(Menu);
	
	if(Item == MENU_EXIT)
		return PLUGIN_HANDLED
	
	new Success,ItemID = array_get_nth(g_UserItemArray[id],Item + 1,_,Success);
	g_CurItem[id] = ItemID
	
	if(UTIL_GetUserItemNum(id,ItemID) <= 0)
		client_print(id,print_chat,"[DRP] Your quantity for this item is zero.");
	else if(!UTIL_ValidItemID(ItemID))
		client_print(id,print_chat,"[DRP] This item is invalid. Please contact the administrator.");
	else
	{
		new ItemName[33]
		UTIL_GetItemName(ItemID,ItemName,32);
		
		format(g_Menu,255,"Item: %s ( x %d )^n^n1. Use^n2. Give^n3. Drop^n4. Show^n5. Examine^n^n6. Sell^n7. Back^n^n0. Exit",ItemName,UTIL_GetUserItemNum(id,ItemID));
		show_menu(id,g_Keys,g_Menu,-1,g_ItemsOptions);
	}
	return PLUGIN_HANDLED
}
public ItemsOptions(id,Key)
{
	if(!is_user_alive(id))
		return
	
	switch(Key)
	{
		case 0:
		{
			new Data[2]
			Data[0] = id
			Data[1] = g_CurItem[id]
			
			if(_CallEvent("Item_Use",Data,2))
				return
		
			ItemUse(id,g_CurItem[id],1);
		}
		case 1:
		{
			format(g_Menu,255,"Give Items^n^n1. Give 1^n2. Give 5^n3. Give 10^n4. Give 20^n5. Give 50^n6. Give 100^n7. Give All^n^n0. Exit");
			show_menu(id,g_Keys,g_Menu,-1,g_ItemsGive);
		}
		case 2:
		{
			format(g_Menu,255,"Drop Items^n^n1. Drop 1^n2. Drop 5^n3. Drop 10^n4. Drop 20^n5. Drop 50^n6. Drop 100^n7. Drop All^n^n0. Exit");
			show_menu(id,g_Keys,g_Menu,-1,g_ItemsDrop);
		}
		case 3:
		{
			new Index,Body
			get_user_aiming(id,Index,Body,100);
			
			if(!Index || !is_user_alive(Index)) 
			{
				client_print(id,print_chat,"[DRP] You are not looking at a user.");
				return 
			}
	
			new Name[2][33],ItemID = g_CurItem[id],ItemName[33]
			get_user_name(id,Name[1],32);
			get_user_name(Index,Name[0],32);
			
			UTIL_GetItemName(ItemID,ItemName,32);
			
			client_print(id,print_chat,"[DRP] You showed player %s your %s.",Name[0],ItemName);
			
			client_print(Index,print_chat,"[DRP] Player %s shows you his/her %s",Name[1],ItemName);
			client_print(Index,print_chat,"You may type ^"/iteminfo^" for more information on this item.");
			
			g_ItemShow[Index] = ItemID
		}
		
		case 4:
			ItemInfo(id,g_CurItem[id]);
		
		case 5: 
		{
			new Menu = menu_create("Current Price: $0","ItemSellHandle"),Item[64]
			g_SellAmount[id] = 0
			
			menu_additem(Menu,"One","1");
			menu_additem(Menu,"Ten","10");
			menu_additem(Menu,"Fifteen","15");
			menu_additem(Menu,"Twenty","20");
			menu_additem(Menu,"Fifty^n","50");
			menu_additem(Menu,"Reset");
			menu_additem(Menu,"Done");
			
			menu_addtext(Menu,"^nEach number will add onto the total value",0);
			menu_addtext(Menu,"Remember to face a player (to sell too)^n",0);
			
			UTIL_GetItemName(g_CurItem[id],Item,63);
			
			format(Item,63,"Selling Item: %s",Item);
			menu_addtext(Menu,Item,0);
			
			client_print(id,print_chat,"[DRP] NOTE: You may also use the cmd ^"/sellitem <itemname> <price>^"");
			menu_display(id,Menu);
		}
		
		case 6:
			ItemMenu(id);
	}
}
SellItem(id,Menu)
{
	static szMenu[128]
	formatex(szMenu,127,"Current Price: $%d",g_SellAmount[id]);
	
	menu_setprop(Menu,MPROP_TITLE,szMenu);
	menu_display(id,Menu);
	
	return PLUGIN_HANDLED
}
public ItemsGive(id,Key)
{
	if(!is_user_alive(id))
		return
	
	new Index,Body,Num
	get_user_aiming(id,Index,Body,100);
	
	if(!Index || !is_user_alive(Index))
	{
		client_print(id,print_chat,"[DRP] You are not looking at a user.");
		return
	}
	
	new ItemID = g_CurItem[id],ItemNum = abs(array_get_int(g_UserItemArray[id],g_CurItem[id]))
	
	switch(Key)
	{
		case 0:
			Num = 1
		case 1:
			Num = 5
		case 2:
			Num = 10
		case 3:
			Num = 20
		case 4:
			Num = 50
		case 5:
			Num = 100
		case 6:
			Num = ItemNum
	}
	
	if(ItemNum < Num)
	{
		client_print(id,print_chat,"[DRP] You do not have enough of this item.");
		return
	}
	
	if(array_get_int(array_get_int(g_ItemsArray,ItemID),7) == 0)
	{
		client_print(id,print_chat,"[DRP] This item is not giveable.");
		return
	}
	
	new Data[4]
	Data[0] = id
	Data[1] = Index
	Data[2] = ItemID
	Data[3] = Num
	
	if(_CallEvent("Item_Give",Data,4))
		return
	
	if(!UTIL_SetUserItemNum(Index,ItemID,UTIL_GetUserItemNum(Index,ItemID) + Num))
	{
		client_print(id,print_chat,"[DRP] There was an error giving the user the item.");
		return
	}
	
	UTIL_SetUserItemNum(id,ItemID,UTIL_GetUserItemNum(id,ItemID) - Num);
	
	new Name[2][33],ItemName[33]
	get_user_name(Index,Name[0],32);
	get_user_name(id,Name[1],32);
	
	UTIL_GetItemName(ItemID,ItemName,32);
	
	client_print(id,print_chat,"[DRP] You have given %s %d %s%s.",Name[0],Num,ItemName,Num == 1 ? "" : "s");
	client_print(Index,print_chat,"[DRP] %s has given you %d %s%s.",Name[1],Num,ItemName,Num == 1 ? "" : "s");
}

public ItemsDrop(id,Key)
{
	if(!is_user_alive(id))
		return
	
	new Num,ItemNum = abs(array_get_int(g_UserItemArray[id],g_CurItem[id])),ItemID = g_CurItem[id]
	
	switch(Key)
	{
		case 0:
			Num = 1
		case 1: 
			Num = 5
		case 2:
			Num = 10
		case 3:
			Num = 20
		case 4:
			Num = 50
		case 5:
			Num = 100
		case 6:
			Num = ItemNum
	}
	
	if(ItemNum < Num)
	{
		client_print(id,print_chat,"[DRP] You do not have enough of this item.");	
		return
	}
	
	if(array_get_int(array_get_int(g_ItemsArray,ItemID),6) == 0)
	{
		client_print(id,print_chat,"[DRP] This item is not droppable.");
		return
	}
	
	new Data[3]
	Data[0] = id
	Data[1] = ItemID
	Data[2] = Num
	
	if(_CallEvent("Item_Drop",Data,3))
		return
	
	new Float:plOrigin[3],ItemName[33]
	pev(id,pev_origin,plOrigin);
	
	UTIL_GetItemName(ItemID,ItemName,32);
	
	if(!_CreateItemDrop(id,plOrigin,Num,ItemName,true))
	{
		client_print(id,print_chat,"[DRP] There was an error dropping the item.");
		return
	}
	
	UTIL_SetUserItemNum(id,ItemID,UTIL_GetUserItemNum(id,ItemID) - Num);
	
	emit_sound(id,CHAN_ITEM,g_ItemDrop,VOL_NORM,ATTN_NORM,0,PITCH_NORM);
	client_print(id,print_chat,"[DRP] You have dropped %d x %s",Num,ItemName);
}
public ItemSellHandle(id,Menu,Item)
{
	if(Item == MENU_EXIT)
	{
		menu_destroy(Menu);
		return PLUGIN_HANDLED
	}
	
	new StrNum[8],Temp
	menu_item_getinfo(Menu,Item,Temp,StrNum,7,_,_,Temp);
	
	switch(Item)
	{
		case 5: { g_SellAmount[id] = 0; return SellItem(id,Menu); }
		
		case 6:
		{
			new Index,Body
			get_user_aiming(id,Index,Body,100);
			
			if(!Index || !is_user_alive(Index))
			{
				client_print(id,print_chat,"[DRP] You must be looking at a player.");
				return menu_display(id,Menu);
			}
			
			if(g_SellAmount[id] < 1)
			{
				client_print(id,print_chat,"[DRP] The sell amount must be greater than zero.");
				return menu_display(id,Menu);
			}
			
			new ItemName[33],Data[33]
			UTIL_GetItemName(g_CurItem[id],ItemName,32);
			
			get_user_name(id,Data,32);
			
			format(g_Menu,255,"[Item Offer]^n^nSeller: %s^nItem: %s^nPrice: $%d",Data,ItemName,g_SellAmount[id]);
			menu_destroy(Menu);
			
			new TMenu = menu_create(g_Menu,"ItemTSell");
			formatex(Data,32,"%d %d %d",id,g_CurItem[id],g_SellAmount[id]);
			
			menu_additem(TMenu,"Accept",Data);
			menu_additem(TMenu,"View Item Info",Data);
			menu_additem(TMenu,"Ignore Offer",Data);
			
			menu_display(Index,TMenu);
			return PLUGIN_HANDLED
		}
		
		default: { g_SellAmount[id] += str_to_num(StrNum); return SellItem(id,Menu); }
	}
	menu_destroy(Menu);
	return PLUGIN_HANDLED
}
public ItemTSell(id,Menu,Item)
{
	if(Item == MENU_EXIT)
	{
		menu_destroy(Menu);
		return PLUGIN_HANDLED
	}
	
	new Data[33],Temp
	menu_item_getinfo(Menu,Item,Temp,Data,32,_,_,Temp);
	
	new StrId[4],StrItem[4],StrPrice[8]
	parse(Data,StrId,3,StrItem,3,StrPrice,7);
	
	new ItemID = str_to_num(StrItem),Index = str_to_num(StrId);
	if(!Index || !is_user_alive(Index))
	{
		client_print(id,print_chat,"[DRP] The seller has disconnected or died.");
		menu_destroy(Menu);
		
		return PLUGIN_HANDLED
	}
	
	new Float:Origin[3],Float:iOrigin[3]
	pev(id,pev_origin,Origin);
	pev(Index,pev_origin,iOrigin);
	
	if(get_distance_f(Origin,iOrigin) > 100.0)
	{
		client_print(id,print_chat,"[DRP] You have moved to far away from the seller.");
		menu_destroy(Menu);
		
		return PLUGIN_HANDLED
	}
	
	new Price = str_to_num(StrPrice);
	get_user_name(id,Data,32);
	
	switch(Item)
	{
		case 0:
		{
			if(g_UserWallet[id] < Price)
			{
				client_print(id,print_chat,"[DRP] You do not have enough cash in your wallet for this item.");
				menu_destroy(Menu);
				
				return PLUGIN_HANDLED
			}
			
			new ItemName[33]
			UTIL_GetItemName(ItemID,ItemName,32);
			
			client_print(Index,print_chat,"[DRP] Your item ^"%s^" has been bought by %s",ItemName,Data);
			get_user_name(Index,Data,32);
			client_print(id,print_chat,"[DRP] You have bought the item ^"%s^" from %s for $%d",ItemName,Data,Price);
			
			UTIL_SetUserItemNum(id,ItemID,UTIL_GetUserItemNum(id,ItemID) + 1);
			UTIL_SetUserItemNum(Index,ItemID,UTIL_GetUserItemNum(Index,ItemID) - 1);
			
			g_UserWallet[id] -= Price
			g_UserWallet[Index] += Price
		}
		case 1:
		{
			ItemInfo(id,ItemID);
			return menu_display(id,Menu);
		}
		case 2:
		{
			client_print(Index,print_chat,"[DRP] %s has ignored your selling offer.",Data);
			client_print(id,print_chat,"[DRP] You have ignored the offer.");
			
			menu_destroy(Menu);
			return PLUGIN_HANDLED
		}
	}
	menu_destroy(Menu);
	return PLUGIN_HANDLED
}
ItemInfo(id,ItemID)
{
	if(!is_user_alive(id) || !UTIL_ValidItemID(ItemID))
		return
	
	new ItemName[33]
	UTIL_GetItemName(ItemID,ItemName,32);
	
	array_get_string(array_get_int(g_ItemsArray,ItemID),4,g_Menu,255);
	format(g_Menu,255,"Item: %s^n^nDescription:^n%s",ItemName,g_Menu);
	
	show_motd(id,g_Menu,"DRP");
}
/*==================================================================================================================================================*/
public CmdHelp(id)
{
	new Arg[33]
	read_argv(1,Arg,32);
	
	new Start = str_to_num(Arg),Items = get_pcvar_num(p_ItemsPerPage);
	
	if(Start)
		read_argv(2,Arg,32);
	
	if(Start >= g_CommandNum || Start < 0)
	{
		client_print(id,print_console,"[DRP] No help items in this area to display.");
		return PLUGIN_HANDLED
	}
	
	new Extra = containi(Arg,"extra") != -1 ? 1 : 0
	
	client_print(id,print_console,"DRP Help List (Starting at: #%d)",Start);
	client_print(id,print_console,"CmdNum       CmdName       %s",Extra ? "Description" : "");
	
	new Description[256],CurArray,CommandNum
	for(new Count = Start;Count < Start + Items;Count++)
	{
		if(Count >= g_CommandNum)
			break
		
		CurArray = array_get_int(g_CommandArray,Count + 1);
		
		array_get_string(CurArray,1,Arg,32);
		
		if(Extra)
			array_get_string(CurArray,2,Description,255);
		
		if(array_get_int(CurArray,3) && !UTIL_IsUserAdmin(id))
			continue
		
		CommandNum++
		client_print(id,print_console,"#%d       %s       %s",CommandNum,Arg,Extra ? Description : "");
	}
	
	if(Start + Items < g_CommandNum)
		client_print(id,print_console,"[DRP] Type ^"drp_help %d^" to view the next page.",Start + Items);
	
	if(!Extra)
		client_print(id,print_console,"[DRP] NOTE: You may type ^"drp_help # extra^" to view the list with descriptions.");
	
	return PLUGIN_HANDLED
}
public CmdJobList(id)
{
	new Arg[33]
	read_argv(1,Arg,32);
	
	new Start = str_to_num(Arg),Items = get_pcvar_num(p_ItemsPerPage);
	
	if(Start >= g_JobNum || Start < 0)
	{
		client_print(id,print_console,"[DRP] No jobs in this area to display.");
		return PLUGIN_HANDLED
	}
	
	new JobName[33],JobAccess[JOB_ACCESSES + 1],CurArray
	client_print(id,print_console,"DRP Jobs List (Starting at: #%d)",Start);
	client_print(id,print_console,"JobID       JobName       JobSalary       Access");
	
	for(new Count = Start;Count < Start + Items;Count++)
	{
		if(Count >= g_JobNum)
			break
		
		CurArray = array_get_int(g_JobArray,Count);
		
		array_get_string(CurArray,1,JobName,32);
		DRP_IntToAccess(array_get_int(CurArray,3),JobAccess,JOB_ACCESSES);
		
		client_print(id,print_console,"#%d       %s       $%d       %s",Count + 1,JobName,array_get_int(CurArray,2),JobAccess);
	}
	
	if(Start + Items < g_JobNum)
		client_print(id,print_console,"[DRP] Type ^"drp_joblist %d^" to view the next page.", Start + Items);
	
	return PLUGIN_HANDLED
}
public CmdItemList(id)
{
	new Arg[33]
	read_argv(1,Arg,32);
	
	new Start = str_to_num(Arg) + 1,Items = get_pcvar_num(p_ItemsPerPage);
	
	if(Start - 1)
		read_argv(2,Arg,32);
	
	if(Start > g_ItemsNum || Start < 1)
	{
		client_print(id,print_console,"[DRP] No items in this area to display.")
		return PLUGIN_HANDLED
	}
	
	new Extra = containi(Arg,"extra") != -1 ? 1 : 0
	
	client_print(id,print_console,"DRP Items List (Starting at: #%d)",Start);
	client_print(id,print_console,"ItemID       Name       %s",Extra ? "Description" : "");

	new Name[33],Description[128],CurArray
	for(new Count = Start;Count < Start + Items;Count++)
	{
		if(Count > g_ItemsNum)
			break
		
		CurArray = array_get_int(g_ItemsArray,Count);
		array_get_string(CurArray,1,Name,32);
		
		if(Extra)
			array_get_string(CurArray,4,Description,127);
		
		client_print(id,print_console,"%d       %s       %s",Count,Name,Extra ? Description : "");
	}
	
	if(Start + Items <= g_ItemsNum)
		client_print(id,print_console,"[DRP] Type ^"drp_itemlist %d^" to view the next page.",Start + Items - 1);
	
	if(!Extra)
		client_print(id,print_console,"[DRP] NOTE: You may type ^"drp_itemlist # extra^" to view the list with descriptions.");
	
	return PLUGIN_HANDLED
}
public CmdMenu(id)
{
	TravTrieClear(g_MenuArray[id]);
	
	g_MenuAccepting[id] = 1
	
	new Data[1]
	Data[0] = id
	
	if(_CallEvent("Menu_Display",Data,1))
		return PLUGIN_HANDLED
	
	g_MenuAccepting[id] = 0
	
	new const Size = TravTrieSize(g_MenuArray[id]);
	
	if(!Size)
	{
		client_print(id,print_chat,"[DRP] There is currently no items in the menu.");
		return PLUGIN_HANDLED
	}
	
	new travTrieIter:Iter = GetTravTrieIterator(g_MenuArray[id]),Menu = menu_create("Quick-Access Menu","ClientMenuHandle"),Info[128],Key[64]
	while(MoreTravTrie(Iter))
	{
		ReadTravTrieKey(Iter,Key,63);
		ReadTravTrieString(Iter,Info,127);
		
		menu_additem(Menu,Key,Info);
	}
	DestroyTravTrieIterator(Iter);
	menu_display(id,Menu,0);
	
	return PLUGIN_HANDLED
}
public ClientMenuHandle(id,Menu,Item)
{
	if(Item == MENU_EXIT)
	{
		menu_destroy(Menu);
		return PLUGIN_HANDLED
	}
	
	new Info[128],Access,Callback
	menu_item_getinfo(Menu,Item,Access,Info,127,_,_,Callback);
	
	new Forward = CreateOneForward(Info[0],Info[1],FP_CELL),Return
	if(Forward <= 0 || !ExecuteForward(Forward,Return,id))
	{
		menu_destroy(Menu);
		return PLUGIN_HANDLED
	}
	
	DestroyForward(Forward);
	menu_destroy(Menu);
	
	return PLUGIN_HANDLED
}
Shove(id,Index)
{
	new Float:iVelo[3]
	pev(id,pev_size,iVelo);
	
	if(iVelo[2] < 72.0)
		return
	
	if(!(pev(Index,pev_flags) & FL_ONGROUND) || !(pev(id,pev_flags) & FL_ONGROUND))
		return
	
	new Data[2]
	Data[0] = id
	Data[1] = Index
	
	if(_CallEvent("Player_Shove",Data,2))
		return
	
	new plName[2][33]
	get_user_name(id,plName[0],32);
	get_user_name(Index,plName[1],32);
	
	pev(Index,pev_size,iVelo);
	
	client_print(id,print_chat,"[DRP] You have just %s %s",iVelo[2] < 72.0 ? "kicked" : "shoved",plName[1]);
	client_print(Index,print_chat,"[DRP] You have just been %s by %s",iVelo[2] < 72.0 ? "kicked" : "shoved",plName[0]);
	
	emit_sound(id,CHAN_AUTO,"player/block.wav",VOL_NORM,ATTN_NORM,0,PITCH_NORM);
}
public CmdItemInfo(id)
{
	if(!is_user_alive(id))
		return PLUGIN_HANDLED
	
	if(!g_ItemShow[id])
	{
		client_print(id,print_chat,"[DRP] Nobody has recently showed you an item.");
		return PLUGIN_HANDLED
	}
	
	ItemInfo(id,g_ItemShow[id]);
	g_ItemShow[id] = 0
	
	return PLUGIN_HANDLED
}
/*==================================================================================================================================================*/
public client_authorized(id)
{
	if(is_user_bot(id) || is_user_hltv(id))
		return
	
	if(id > 32)
	{
		id -= 32
		if(g_Saving[id])
			set_task(0.5,"client_authorized",id + 32);
		
		return
	}
	if(g_Saving[id])
	{
		set_task(0.5,"client_authorized",id + 32);
		return
	}
	
	g_Joined[id] = false
	g_GotInfo[id] = 0
	g_BadAuthID[id] = false
	
	new AuthID[36],Data[1],Results[1]
	get_user_authid(id,AuthID,35);
	
	if(DRP_FindJobID("Unemployed",Results,1))
		g_UserJobID[id] = Results[0]
	
	Data[0] = id
	
	format(g_Query,4095,"SELECT * FROM %s WHERE SteamID='%s'",g_UserTable,AuthID);
	SQL_ThreadQuery(g_SqlHandle,"FetchClientData",g_Query,Data,1);
	
	format(g_Query,4095,"SELECT * FROM %s WHERE AuthIDName LIKE '%s|%%'",g_ItemsTable,AuthID);
	SQL_ThreadQuery(g_SqlHandle,"FetchClientItems",g_Query,Data,1);
	
	format(g_Query,4095,"SELECT * FROM %s WHERE AuthIDKey LIKE '%s|%%'",g_KeysTable,AuthID);
	SQL_ThreadQuery(g_SqlHandle,"FetchClientKeys",g_Query,Data,1);
}
public client_disconnect(id)
{
	if(is_user_bot(id) || is_user_hltv(id))
		return
	
	if(g_GotInfo[id] >= STD_USER_QUERIES && !g_PluginEnd)
	{
		SaveUserData(id,1);
		g_GotInfo[id] = 0
	}
}
/*==================================================================================================================================================*/
public FetchClientData(FailState,Handle:Query,Error[],Errcode,Data[],DataSize) 
{
	if(FailState != TQUERY_SUCCESS || Errcode)
		return UTIL_Error(0,0,"SQL Error (Error: %s)",0,Error ? Error : "UNKNOWN");
	
	new const id = Data[0]
	g_GotInfo[id]++
	
	// HACKHACK!! - PRINT_CENTER 2 SECOND HOLD TIME
	client_cmd(id,"scr_centertime 2");
	
	if(SQL_NumResults(Query) < 1)
	{
		new AuthID[36],StartBankMoney = get_pcvar_num(p_StartMoney);
		get_user_authid(id,AuthID,35);
		
		format(g_Query,4095,"INSERT INTO %s VALUES('%s','%d','0','Unemployed','0','','',0)",g_UserTable,AuthID,StartBankMoney);
		SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",g_Query)
		
		new Results[1]
		DRP_FindJobID("Unemployed",Results,1);
		
		Results[0] -= 1
		
		g_UserBank[id] = StartBankMoney
		g_UserWallet[id] = 0
		g_UserHunger[id] = 0
		g_AccessCache[id] = 0
		
		g_UserTime[id] = 0
		
		g_UserJobID[id] = Results[0]
		g_UserAccess[id] = array_get_int(array_get_int(g_JobArray,Results[0]),3);
		g_UserSalary[id] = array_get_int(array_get_int(g_JobArray,Results[0]),2);
		
		server_print("[DRP-CORE] Player %d (%s) was added to the database.",id,AuthID);
		
		array_clear(g_UserItemArray[id]);
		CheckReady(id);
		
		return PLUGIN_CONTINUE
	}
	
	g_UserBank[id] = SQL_ReadResult(Query,1);
	g_UserWallet[id] = SQL_ReadResult(Query,2);
	
	new Temp[64],Results[2]
	SQL_ReadResult(Query,3,Temp,63);
	DRP_FindJobID(Temp,Results,2);
	
	g_UserJobID[id] = Results[0] - 1
	
	// We can't find this job
	if((Results[0] && Results[1]) || !Results[0])
	{
		g_BadJob[id] = true
		
		DRP_FindJobID("Unemployed",Results,1);
		
		if(!UTIL_ValidJobID(Results[0] - 1))
			Results[0] = DRP_AddJob("Unemployed",5,0) - 1
		
		g_UserJobID[id] = Results[0] - 1
		g_UserSalary[id] = 5
	}
	
	else if(!UTIL_ValidJobID(g_UserJobID[id]))
		g_BadJob[id] = true
	
	g_UserHunger[id] = SQL_ReadResult(Query,4);
	
	SQL_ReadResult(Query,5,Temp,63);
	g_UserAccess[id] = DRP_AccessToInt(Temp);
	g_AccessCache[id] = g_UserAccess[id]
	
	g_UserSalary[id] = array_get_int(array_get_int(g_JobArray,g_UserJobID[id]),2);
	g_UserAccess[id] |= array_get_int(array_get_int(g_JobArray,g_UserJobID[id]),3);
	
	SQL_ReadResult(Query,6,Temp,63);
	g_UserJobRight[id] = DRP_AccessToInt(Temp);
	
	g_UserTime[id] = SQL_ReadResult(Query,7);
	CheckReady(id);
	
	return PLUGIN_CONTINUE
}
public FetchClientItems(FailState,Handle:Query,Error[],Errcode,Data[],DataSize) 
{
	if(FailState != TQUERY_SUCCESS || Errcode)
		return UTIL_Error(0,0,"SQL Error (Error: %s)",0,Error ? Error : "UNKNOWN");
		
	new const id = Data[0]
	new Temp[2][36],ItemID
	
	g_GotInfo[id]++
	array_clear(g_UserItemArray[id]);
	
	while(SQL_MoreResults(Query))
	{
		SQL_ReadResult(Query,0,g_Query,4095);
		strtok(g_Query,Temp[0],35,Temp[1],35,'|',1);
		
		ItemID = UTIL_FindItemID(Temp[1]);
		
		/*
		if(!UTIL_ValidItemID(ItemID))
		{			
			SQL_NextRow(Query);
			continue
		}
		*/
		
		array_set_int(g_UserItemArray[id],ItemID,-SQL_ReadResult(Query,1));
		SQL_NextRow(Query);
	}
	CheckReady(id);
	
	return PLUGIN_CONTINUE
}
public FetchClientKeys(FailState,Handle:Query,Error[],Errcode,Data[],DataSize) 
{
	if(FailState != TQUERY_SUCCESS || Errcode)
		return UTIL_Error(0,0,"SQL Error (Error: %s)",0,Error ? Error : "UNKNOWN");
	
	new const id = Data[0]
	
	new InternalName[33],Property,AuthidKey[64],Garbage[1]
	g_GotInfo[id]++
	
	while(SQL_MoreResults(Query))
	{
		SQL_ReadResult(Query,0,AuthidKey,63);
		strtok(AuthidKey,Garbage,0,InternalName,32,'|');
		
		Property = UTIL_GetProperty(InternalName);
		if(Property != -1)		
			array_set_int(array_get_int(g_PropertyArray,Property),8,array_get_int(array_get_int(g_PropertyArray,Property),8)|(1<<(id - 1)));
		
		SQL_NextRow(Query);
	}
	CheckReady(id);
	
	return PLUGIN_CONTINUE
}
/*==================================================================================================================================================*/
// HUD System
// Hunger System
public ShowHud()
{
	if(!g_HudForward || g_PluginEnd)
		return
	
	g_Time -= 10
	
	if(g_Time <= 0)
		g_Time = 600
	
	new pSalToWal = get_pcvar_num(p_SalaryToWallet),pHunger = get_pcvar_num(p_HungerEnabled);
	new Data[1]
	
	if(pHunger)
		if(++g_HungerCounter >= get_pcvar_num(p_HungerTimer))
			g_HungerCounter = 0
	
	static iPlayers[32],iNum,id
	get_players(iPlayers,iNum);
	
	for(new Count,Count2;Count < iNum;Count++)
	{
		id = iPlayers[Count]
		
		if(!is_user_alive(id) || is_user_bot(id))
			continue
		
		if(!g_HungerCounter && pHunger)
			HandleHunger(id);
		
		if(g_Time == 600)
		{
			Data[0] = id
			
			if(_CallEvent("Player_Salary",Data,1))
				continue
			
			if(pSalToWal)
				g_UserWallet[id] += g_UserSalary[id]
			else
				g_UserBank[id] += g_UserSalary[id]
		}
		
		for(Count2 = 0;Count2 < HUD_NUM;Count2++)
			RenderHud(id,Count2);
	}
	DoTime();
}

// [0] = Seconds
// [1] = Minutes
// [2] = Hours
// [3] = AM/PM
// [4] = Month
// [5] = Month Day
// [6] = Year

DoTime()
{
	if(++g_WorldTime[0] < 60)
		return
	
	g_WorldTime[0] = 0
	
	if(++g_WorldTime[1] < 60)
		return
	
	if(g_WorldTime[2] == 11 && g_WorldTime[1] >= 60)
	{
		if(g_WorldTime[3] == PM)
		{
			g_WorldTime[3] = AM
			if(++g_WorldTime[5] >= g_MonthDays[g_WorldTime[4]])
			{
				g_WorldTime[5] = 1
				
				if(++g_WorldTime[4] >= 11)
				{
					g_WorldTime[6]++
					g_WorldTime[4] = 0
				}
			}
		}
		else
			g_WorldTime[3] = AM
		
		g_WorldTime[1] = 0
	}
	else if(g_WorldTime[2] == 12)
		g_WorldTime[2] = 1
	else if(g_WorldTime[2] == 0) 
		g_WorldTime[2] = 1
	else
		g_WorldTime[2]++
	
	g_WorldTime[1] = 0
}
RenderHud(id,Hud)
{	
	g_HudPending = true
	
	static Temp[256],Return
	
	if(Hud != HUD_EXTRA)
		TravTrieClear(g_HudArray[id][Hud]);
	
	if(!ExecuteForward(g_HudForward,Return,id,Hud))
		return
	
	g_Query[0] = 0
	
	new travTrieIter:Iter = GetTravTrieIterator(g_HudArray[id][Hud]),Priority,Ticker
	while(MoreTravTrie(Iter))
	{
		ReadTravTrieKey(Iter,Temp,255);
		ReadTravTrieCell(Iter,Priority);
		
		float(Priority);
		
		Ticker += format(g_Query[Ticker],4095 - Ticker,"%s^n",Temp);
	}
	DestroyTravTrieIterator(Iter);
	
	if(Hud == HUD_EXTRA)
		TravTrieClear(g_HudArray[id][Hud]);
	
	g_HudPending = false
	
	set_hudmessage(get_pcvar_num(p_Hud[Hud][R]),get_pcvar_num(p_Hud[Hud][G]),get_pcvar_num(p_Hud[Hud][B]),get_pcvar_float(p_Hud[Hud][X]),get_pcvar_float(p_Hud[Hud][Y]),0,0.0,999999.9,0.0,0.0,-1)
	ShowSyncHudMsg(id,g_HudObjects[Hud],"%s",g_Query);
}
CheckReady(id)
{
	if(g_GotInfo[id] < STD_USER_QUERIES)
		return
	
	new Data[1]
	Data[0] = id
	
	if(_CallEvent("Player_Ready",Data,1))
		return
}
/*==================================================================================================================================================*/
public CmdHungerTest(id)
{
	new MaxHunger = 120
	g_UserHunger[id] = 0
	for(new Count;Count<MaxHunger;Count++)
	{
		if(g_UserHunger[id] >= 120)
		{
			server_print("STOPPED AT: %d (Total Time: %d Minutes)",Count,get_pcvar_num(p_HungerTimer) * Count / 60);
			break
		}
		
		HandleHunger(id);
	}
}
HandleHunger(id)
{
	if(!is_user_alive(id))
		return
		
	new Hunger = random_num(0,(g_UserHunger[id] >= 119) ? 1 : 3);
	if(!Hunger)
		return
	
	static Data[2]
	Data[0] = id
	Data[1] = Hunger
	
	if(_CallEvent("Player_Hunger",Data,2))
		return
	
	g_UserHunger[id] += Hunger
	
	new Random = random_num(0,3);
	if(!Random)
		return
	
	switch(g_UserHunger[id])
	{
		case 90..95:
		{
			switch(Random)
			{ 
				case 1: client_print(id,print_chat,"[HungerMod] You're feeling abit hungry."); 
				case 2: client_print(id,print_chat,"[HungerMod] You're getting hungry.");  
			}
		}
		case 107..111:
		{
			switch(Random)
			{ 
				case 1: client_print(id,print_chat,"[HungerMod] You need to eat.");
				case 2: client_print(id,print_chat,"[HungerMod] Your hungry. Eat something");
			}
		}
		case 115..120:
		{
			switch(Random)
			{
				case 1: client_print(id,print_chat,"[HungerMod] You are dehidrating. You need food.");
				case 2: client_print(id,print_chat,"[HungerMod] Your body is losing energy.");
			}
			
			if(!get_pcvar_num(p_HungerEffects))
				return
			
			if(g_UserHunger[id] >= 117)
			{
				message_begin(MSG_ONE_UNRELIABLE,gmsgScreenShake,_,id);
				
				write_short(1<<13);
				write_short(seconds_to_screenfade_units(10));
				write_short(5<<14);
				
				message_end();
				
				client_print(id,print_chat,"[HungerMod] You're getting dizzy. Eating something.");
				
				if(!task_exists(id + HUNGER_OFFSET))
					set_task(3.5,"HungerEffects",id + HUNGER_OFFSET,_,_,"a",4);
			}
		}
		case 121..130:
		{
			client_print(id,print_chat,"[HungerMod] You have died from hunger.");
			user_kill(id);
		}
	}
}
public HungerEffects(id)
{
	id -= HUNGER_OFFSET
	
	if(g_UserHunger[id] >= 120 || !is_user_alive(id))
	{
		if(task_exists(id + HUNGER_OFFSET))
			remove_task(id + HUNGER_OFFSET);
		
		return
	}
	
	message_begin(MSG_ONE_UNRELIABLE,gmsgTSFade,_,id);
	
	write_short(seconds_to_screenfade_units(3)) // Duration
	write_short(seconds_to_screenfade_units(1)) // Hold Time
	write_short(FFADE_IN)
	
	write_byte(random_num(50,125));
	write_byte(random_num(80,115));
	write_byte(random_num(0,200));
	write_byte(150);
	
	message_end();
}
/*==================================================================================================================================================*/
// Forwards
public forward_PreThink(id)
{
	if(!is_user_alive(id))
		return FMRES_IGNORED
	
	new Index,Body
	get_user_aiming(id,Index,Body,100);
	
	if(g_Display[id])
		PrintDisplay(id,Index);
	
	if(!(pev(id,pev_button) & IN_USE && !(pev(id,pev_oldbuttons) & IN_USE)))
		return FMRES_IGNORED
	
	static Classname[64],Data[3],EntList[1]
	EntList[0] = 0
	
	if(find_sphere_class(id,g_szNPCName,80.0,EntList,1))
		return _CallNPC(id,EntList[0]);
	
	else if(find_sphere_class(id,g_szItem,40.0,EntList,1))
	{
		new Ent = EntList[0]
		pev(Ent,pev_noise,Classname,63);
		
		new ItemID = UTIL_FindItemID(Classname),Num = pev(Ent,pev_iuser2),Key = pev(Ent,pev_iuser3);
		
		UTIL_SetUserItemNum(id,ItemID,UTIL_GetUserItemNum(id,ItemID) + Num);
		
		emit_sound(id,CHAN_ITEM,g_ItemPickUp,1.0,ATTN_NORM,0,PITCH_NORM);
		client_print(id,print_chat,"[DRP] You have picked up %d x %s%s.",Num,Classname,Num == 1 ? "" : "s");
		
		if(Key)
		{
			format(g_Query,4095,"DELETE FROM `ItemDrops` WHERE UniqueNum=%d",Key);
			SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",g_Query);
		}
		
		engfunc(EngFunc_RemoveEntity,Ent);
		return FMRES_HANDLED
	}
	else if(find_sphere_class(id,g_szMoneyPile,40.0,EntList,1))
	{
		new Ent = EntList[0]
		new Amount = pev(Ent,pev_iuser3);
		
		g_UserWallet[id] += Amount
		client_print(id,print_chat,"[DRP] You have picked up $%d dollar%s.",Amount,Amount == 1 ? "" : "s");
		
		engfunc(EngFunc_RemoveEntity,Ent);
		return FMRES_HANDLED
	}
	
	if(!pev_valid(Index))
		return FMRES_IGNORED
	
	pev(Index,pev_classname,Classname,63);
	
	if(equali(Classname,"func_door") || equali(Classname,"func_door_rotating"))
	{
		pev(Index,pev_targetname,Classname,63);
		
		new const Property = UTIL_GetProperty(Classname,Index);
		if(Property == -1)
			return FMRES_IGNORED
		
		new CurArray = array_get_int(g_PropertyArray,Property),AuthID[36]
		get_user_authid(id,AuthID,35);
		
		array_get_string(CurArray,3,Classname,63);
		
		if(equali(Classname,AuthID) || !array_get_int(CurArray,5) || array_get_int(CurArray,8) & (1<<(id - 1)) || array_get_int(CurArray,6) & g_UserAccess[id])
		{
			client_print(id,print_chat,"[DRP] You used the door.");
			dllfunc(DLLFunc_Use,Index,id);
		}
		else
		{
			client_print(id,print_chat,"[DRP] You do not have keys to this door.");
		}
		
		return FMRES_IGNORED
	}
	else if(equali(Classname,g_szNPCName))
		return _CallNPC(id,Index);
	
	return FMRES_HANDLED
}
PrintDisplay(id,Index)
{
	/*
	static Message[128],Classname[64]
	new EntList[10],Num = find_sphere_class(id,g_szNPCName,50.0,EntList,9)
	for(new Count;Count < Num;Count++)
	{
		EntList[0] = EntList[Count]
		pev(EntList[0],pev_noise1,Classname,32);
		
		formatex(Message,127,"%s^nPress use (default e) to use",Classname);
		client_print(id,print_center,"%s",Message);
		break
	}
	*/
	
	if(!Index)
		return
	
	Index = id
	
	static Message[128],Classname[64],HudMsg
	pev(Index,pev_classname,Classname,63);
	
	HudMsg = 0
	
	if(equali(Classname,g_szNPCName))
	{
		pev(Index,pev_noise1,Classname,32);
		
		formatex(Message,127,"%s^nPress use (default e) to use",Classname);
		client_print(id,print_center,"%s",Message);
	}
	
	else if(equali(Classname,"func_door") || equali(Classname,"func_door_rotating"))
	{
		static CMessage[128],Name[33],Temp[64]
		pev(Index,pev_targetname,Classname,63);
		
		new Property = UTIL_GetProperty(Classname,Index);
		if(Property == -1)
			return
		
		new CurArray = array_get_int(g_PropertyArray,Property);
		
		array_get_string(CurArray,1,Name,32);
		array_get_string(CurArray,2,Classname,63);
		array_get_string(CurArray,10,CMessage,127);
		
		new Price = array_get_int(CurArray,4);
		
		if(Price)
			formatex(Temp,63,"Price: $%d. Say /buy to purchase",Price);
		
		formatex(Message,127,"%s^nOwner: %s ( %s )^nStatus: %s^n%s^n%s",Name[0] ? Name : "",Classname[0] ? Classname : "",Price ? "Selling" : "Owned",array_get_int(CurArray,5) ? "Locked" : "Unlocked",Price ? Temp : "",CMessage[0] ? CMessage : "");
		client_print(id,print_center,"^n^n^n^n^n^n^n^n^n^n^n^n^n^n^n^n%s",Message);
	}
	
	if(!g_HudPending)
		{ g_Display[id] = 0; set_task(HudMsg ? 0.9 : 1.6,"ResetDisplay",id); }
}
public ResetDisplay(id)
	g_Display[id] = 1

/*==================================================================================================================================================*/
// Events
public EventDeathMsg()
{
	new const id = read_data(2);
	if(!is_user_connected(id))
	{
		log_amx("EventDeathMsg Player Not Conntected. (ID: %d)",id);
		return PLUGIN_CONTINUE
	}
	
	if(get_pcvar_num(p_BlackOut))
		DeathScreen(id);
	
	g_UserHunger[id] = 0
	
	return PLUGIN_CONTINUE
}
public EventDeathMsg2(msg_id,msg_dest,msg_entity)
{
	set_msg_arg_string(3,"Hunger");
	server_print("FUCK YESPENISANDVAGINA");
}
/*
L 04/11/2009 - 13:17:27: MessageBegin (DeathMsg "80") (Destination "All<2>") (Args "3") (Entity "<NULL>") (Classname "<NULL>") (Netname "<NULL>") (Origin "0.000000 0.000000 0.000000")
L 04/11/2009 - 13:17:27: Arg 1 (Byte "2")
L 04/11/2009 - 13:17:27: Arg 2 (Byte "1")
L 04/11/2009 - 13:17:27: Arg 3 (String "Kung Fu")
*/
public EventResetHUD(id)
{
	if(get_pcvar_num(p_BlackOut))
		DeathScreen(id);
	
	set_task(1.0,"ForwardWelcome",id);
}

public DeathScreen(id)
{
	if(is_user_alive(id))
		return
	
	message_begin(MSG_ONE_UNRELIABLE,gmsgTSFade,_,id);
	
	write_short(seconds_to_screenfade_units(2));
	write_short(seconds_to_screenfade_units(2));
	write_short(FFADE_OUT);
	
	write_byte(0);
	write_byte(0);
	write_byte(0);
	write_byte(255);
	
	message_end();
	
	set_task(1.5,"DeathScreen",id);
}
public EventWpnInfo(id)
{
	if(!is_user_connected(id))
		return
	
	g_UserWpnID[id][0] = read_data(1);
	g_UserWpnID[id][1] = read_data(2);
	g_UserWpnID[id][2] = read_data(3);
	g_UserWpnID[id][3] = read_data(4);
	g_UserWpnID[id][4] = read_data(5);
}

public ForwardWelcome(id)
{
	static Data[1]
	Data[0] = id
	
	if(_CallEvent("Player_Spawn",Data,1))
		return
	
	if(!g_Joined[id] || g_BadAuthID[id])
		WelcomeMsg(id);
}

WelcomeMsg(id)
{
	static Message[128]
	
	if(!is_user_alive(id))
	{
		if(g_Joined[id])
			return
		
		get_pcvar_string(p_Welcome[2],Message,127);
		
		replace_all(Message,127,"\n","^n");
		
		set_hudmessage(25,225,45,_,_,2,2.5,get_pcvar_float(p_RespawnTime),_,_,-1);
		show_hudmessage(id,"%s",Message);
		
		return
	}
	
	new AuthID[64]
	get_user_authid(id,AuthID,63);
	
	if(containi(AuthID,"PENDING") != -1 || containi(AuthID,"LAN") != -1 || equali(AuthID,"STEAM_0:0"))
	{
		client_print(id,print_chat,"[DRP] Your SteamID is Invalid. Your user data will not be saved.");
		client_print(id,print_chat,"[DRP] Please try re-connecting.");
		
		g_BadAuthID[id] = true
	}
	else
		g_BadAuthID[id] = false

	if(g_Joined[id])
		return
	
	if(g_BadJob[id])
	{
		client_print(id,print_chat,"[DRP] ** Notice: Your job no longer exists. Please contact an administrator.");
		client_print(id,print_chat,"[DRP] ** You have been temporarily set back to Unemployed.");
	}
	
	g_Joined[id] = true
	
	client_print(id,print_console,"-------------------------------------------^nServer Powered by DRPCore (Version: %s)",VERSION);
	client_print(id,print_console,"Many features offered by DRP are features and ideas in ARP.");
	client_print(id,print_console,"www.apollorp.org | http://drp.hopto.org^n-------------------------------------------");
	
	new plName[33]
	get_pcvar_string(p_Hostname,AuthID,63);
	get_user_name(id,plName,32);
	
	for(new Count;Count < 2;Count++)
	{
		get_pcvar_string(p_Welcome[Count],Message,127);
		
		replace(Message,127,"#name#",plName);
		replace(Message,127,"#hostname#",AuthID);
		
		if(Message[0])
			client_print(id,print_chat,"[DRP] %s",Message);
	}
}
/*==================================================================================================================================================*/
NPCUse(const Handler[],const Plugin,const id,const Index)
{
	new Forward = CreateOneForward(Plugin,Handler,FP_CELL,FP_CELL),Return
	if(Forward <= 0 || !ExecuteForward(Forward,Return,id,Index))
	{
		log_amx("[NPCUse] Unable to find function in plugin. (Function: %s)",Handler);
		return FAILED
	}
	DestroyForward(Forward);
	
	return SUCCEEDED
}
ItemUse(id,ItemID,UseUp)
{
	if(!UTIL_ValidItemID(ItemID))
		return FAILED
	
	new const CurArray = array_get_int(g_ItemsArray,ItemID);
	new Handler[33],Values[3]
	new const Plugin = array_get_int(CurArray,2);
	
	array_get_string(CurArray,3,Handler,32);
	
	Values[0] = array_get_int(CurArray,8);
	Values[1] = array_get_int(CurArray,9);
	Values[2] = array_get_int(CurArray,10);
	
	new Forward = CreateOneForward(Plugin,Handler,FP_CELL,FP_CELL,FP_CELL,FP_CELL,FP_CELL),Return
	if(Forward <= 0 || !ExecuteForward(Forward,Return,id,ItemID,Values[0],Values[1],Values[2]))
	{
		log_amx("[ItemUse] Unable to find function in plugin. (Function: %s)",Handler);
		return FAILED
	}
	DestroyForward(Forward);
	
	// We want to keep this item.
	if(Return == ITEM_KEEP_RETURN) 
		return SUCCEEDED
	
	// If disposable
	if(UseUp && array_get_int(CurArray,5))
		UTIL_SetUserItemNum(id,ItemID,UTIL_GetUserItemNum(id,ItemID) - 1);
	
	return SUCCEEDED
}
/*==================================================================================================================================================*/
// Dynamic Natives
public plugin_natives()
{
	register_library("DRPCore");
	
	register_native("DRP_Log","_DRP_Log");
	register_native("DRP_ThrowError","_DRP_ThrowError");
	register_native("DRP_SqlHandle","_DRP_SqlHandle");
	register_native("DRP_GetConfigsDir","_DRP_GetConfigsDir");
	register_native("DRP_CleverQueryBackend","_DRP_CleverQueryBackend");
	register_native("DRP_GetWorldTime","_DRP_GetWorldTime");
	
	register_native("DRP_PlayerReady","_DRP_PlayerReady");
	register_native("DRP_ShowMOTDHelp","_DRP_ShowMOTDHelp");
	
	// TSX MODULE
	register_native("DRP_TSGetUserWeaponID","_DRP_TSGetUserWeaponID");
	register_native("DRP_TSSetUserAmmo","_DRP_TSSetUserAmmo");
	
	register_native("DRP_IsCop","_DRP_IsCop");
	register_native("DRP_IsAdmin","_DRP_IsAdmin");
	register_native("DRP_IsMedic","_DRP_IsMedic");
	register_native("DRP_IsJobAdmin","_DRP_IsJobAdmin");
	
	register_native("DRP_GetUserWallet","_DRP_GetUserWallet");
	register_native("DRP_SetUserWallet","_DRP_SetUserWallet");
	register_native("DRP_GetUserBank","_DRP_GetUserBank");
	register_native("DRP_SetUserBank","_DRP_SetUserBank");
	
	register_native("DRP_GetPlayerInfo","_DRP_GetPlayerInfo");
	register_native("DRP_GetUserTime","_DRP_GetUserTime");
	
	register_native("DRP_GetUserJobID","_DRP_GetUserJobID");
	register_native("DRP_SetUserJobID","_DRP_SetUserJobID");
	register_native("DRP_GetJobSalary","_DRP_GetJobSalary");
	
	register_native("DRP_FindJobID","_DRP_FindJobID");
	register_native("DRP_FindItemID","_DRP_FindItemID");
	register_native("DRP_FindItemID2","_DRP_FindItemID2");
	
	register_native("DRP_ValidJobID","_DRP_ValidJobID");
	register_native("DRP_ValidItemID","_DRP_ValidItemID");
	
	register_native("DRP_GetUserHunger","_DRP_GetUserHunger");
	register_native("DRP_SetUserHunger","_DRP_SetUserHunger");
	
	register_native("DRP_AddCommand","_DRP_AddCommand");
	register_native("DRP_AddHudItem","_DRP_AddHudItem");
	register_native("DRP_ForceHUDUpdate","_DRP_ForceHUDUpdate");
	
	register_native("DRP_AddJob","_DRP_AddJob");
	register_native("DRP_DeleteJob","_DRP_DeleteJob");
	
	register_native("DRP_GetPayDay","_DRP_GetPayDay");
	
	register_native("DRP_RegisterItem","_DRP_RegisterItem");
	register_native("DRP_GetItemName","_DRP_GetItemName");
	
	register_native("DRP_GetUserItemNum","_DRP_GetUserItemNum");
	register_native("DRP_SetUserItemNum","_DRP_SetUserItemNum");
	register_native("DRP_GetUserTotalItems","_DRP_GetUserTotalItems");
	register_native("DRP_ForceUseItem","_DRP_ForceUseItem");
	register_native("DRP_FetchUserItems","_DRP_FetchUserItems");
	
	register_native("DRP_DropItem","_DRP_DropItem");
	register_native("DRP_DropCash","_DRP_DropCash");
	
	register_native("DRP_GetUserAccess","_DRP_GetUserAccess");
	register_native("DRP_SetUserAccess","_DRP_SetUserAccess");
	
	register_native("DRP_SetUserJobRight","_DRP_SetUserJobRight");
	register_native("DRP_GetUserJobRight","_DRP_GetUserJobRight");
	
	register_native("DRP_GetJobAccess","_DRP_GetJobAccess");
	
	register_native("DRP_GetJobName","_DRP_GetJobName");
	
	register_native("DRP_CallEvent","_DRP_CallEvent");
	register_native("DRP_RegisterEvent","_DRP_RegisterEvent");
	
	register_native("DRP_AddMenuItem","_DRP_AddMenuItem");
	
	register_native("DRP_AddProperty","_DRP_AddProperty");
	register_native("DRP_AddDoor","_DRP_AddDoor");
	
	register_native("DRP_DeleteProperty","_DRP_DeleteProperty")
	register_native("DRP_DeleteDoor","_DRP_DeleteDoor")
	
	register_native("DRP_ValidProperty","_DRP_ValidProperty");
	register_native("DRP_ValidPropertyName","_DRP_ValidPropertyName");
	register_native("DRP_ValidDoor","_DRP_ValidDoor");
	register_native("DRP_ValidDoorName","_DRP_ValidDoorName");
	
	register_native("DRP_PropertyNum","_DRP_PropertyNum");
	register_native("DRP_DoorNum","_DRP_DoorNum");
	
	register_native("DRP_PropertyMatch","_DRP_PropertyMatch");
	register_native("DRP_DoorMatch","_DRP_DoorMatch");
	
	register_native("DRP_PropertyGetInternalName","_DRP_PropertyGetInternalName");
	register_native("DRP_PropertyGetExternalName","_DRP_PropertyGetExternalName");
	register_native("DRP_PropertySetExternalName","_DRP_PropertySetExternalName");
	
	register_native("DRP_PropertyGetOwnerName","_DRP_PropertyGetOwnerName");
	register_native("DRP_PropertySetOwnerName","_DRP_PropertySetOwnerName");
	register_native("DRP_PropertyGetOwnerAuth","_DRP_PropertyGetOwnerAuth");
	register_native("DRP_PropertySetOwnerAuth","_DRP_PropertySetOwnerAuth");
	
	register_native("DRP_PropertyAddAccess","_DRP_PropertyAddAccess");
	register_native("DRP_PropertyRemoveAccess","_DRP_PropertyRemoveAccess");
	
	register_native("DRP_PropertyGetMessage","_DRP_PropertyGetMessage");
	register_native("DRP_PropertySetMessage","_DRP_PropertySetMessage");
	register_native("DRP_PropertyGetLocked","_DRP_PropertyGetLocked");
	register_native("DRP_PropertySetLocked","_DRP_PropertySetLocked");
	
	register_native("DRP_PropertyGetProfit","_DRP_PropertyGetProfit");
	register_native("DRP_PropertySetProfit","_DRP_PropertySetProfit");
	register_native("DRP_PropertyGetPrice","_DRP_PropertyGetPrice");
	register_native("DRP_PropertySetPrice","_DRP_PropertySetPrice");
	
	register_native("DRP_ClassLoad","_DRP_ClassLoad");
	register_native("DRP_ClassSave","_DRP_ClassSave");
	
	register_native("DRP_ClassSaveHook","_DRP_ClassSaveHook");
	register_native("DRP_ClassDeleteKey","_DRP_ClassDeleteKey");
}
/*==================================================================================================================================================*/
public _DRP_Log(Plugin,Params)
{
	if(Params < 1)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 1 or more, Found: %d",Plugin,Params);
		return FAILED
	}
	
	vdformat(g_Query,4095,1,2);
	return UTIL_DRP_Log(Plugin,g_Query);
}
public _DRP_ThrowError(Plugin,Params)
{
	if(Params < 2)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 2 or more, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new Mode = get_param(1);
	vdformat(g_Query,4095,2,3);
	
	return UTIL_Error(0,Mode,g_Query,Plugin);
}
public _DRP_SqlHandle(Plugin,Params)
{
	return _:g_SqlHandle
}
public _DRP_GetConfigsDir(Plugin,Params)
{
	if(Params != 2)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 2, Found: %d",Plugin,Params);
		return FAILED
	}
	
	set_string(1,g_ConfigDir,get_param(2));
	
	return SUCCEEDED
}
public _DRP_CleverQueryBackend(Plugin,Params)
{
	if(Params != 5)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected 5, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new Handle:Tuple = Handle:get_param(1),Handler[128],Data[1024],Len = min(1023,get_param(5))
	get_string(2,Handler,127);
	get_array(4,Data,Len);
	get_string(3,g_Query,4095);
	
	return _DRP_CleverQuery(Plugin,Tuple,Handler,g_Query,Data,Len);
}
// [0] = Seconds
// [1] = Minutes
// [2] = Hours
// [3] = AM/PM
// [4] = Month
// [5] = Month Day
// [6] = Year
// DRP_GetWorldTime(String[],Len,Mode=1)
// 2 = Hour only
// 3 = Minute Only
public _DRP_GetWorldTime(Plugin,Params)
{
	if(Params != 3)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected 3, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new Len = get_param(2),Mode = get_param(3);
	
	switch(Mode)
	{
		// HOUR:MINUTE AM/PM (MONTH/DAY/YEAR)
		case 1:
			format(g_Query,4095,"%d:%s%d %s (%d/%d/%d)",g_WorldTime[2],g_WorldTime[1] < 10 ? "0" : "",
			g_WorldTime[1],g_WorldTime[3] == AM ? "AM" : "PM",g_WorldTime[4],g_WorldTime[5],g_WorldTime[6]);
		case 2:
			format(g_Query,4095,"%d",g_WorldTime[2]);
		case 3:
			format(g_Query,4095,"%d",g_WorldTime[1]);
	}
	
	set_string(1,g_Query,Len);
	return SUCCEEDED
}
public _DRP_PlayerReady(Plugin,Params)
{
	if(Params < 1)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected 1, Found: %d",Plugin,Params);
		return FAILED
	}	
	
	new id = get_param(1);
	if(!is_user_connected(id))
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"User not connected: %d",Plugin,id);
		return FAILED
	}
	return (g_GotInfo[id] >= STD_USER_QUERIES) ? SUCCEEDED : FAILED
}
public _DRP_ShowMOTDHelp(Plugin,Params)
{
	if(Params != 2)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected 2, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new const id = get_param(1);
	if(!is_user_connected(id))
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"User not connected: %d",Plugin,id);
		return FAILED
	}
	
	new File[256]
	get_string(2,File,255);
	
	format(File,255,"%s/%s",g_HelpDIR,File);
	
	if(!file_exists(File))
		return FAILED
	
	show_motd(id,File,"DRP");
	
	return SUCCEEDED
}

/*
public _DRP_AddUserCMsg(Plugin,Params)
{
	if(Params < 2)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected 3 or less, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new id = get_param(1);
	if(!is_user_connected(id))
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"User not connected: %d",Plugin,id);
		return FAILED
	}
	
	new Array:CurArray = ArrayGetCell(g_UserCMsgs,id),iTotal = MessageCount(id);
	vdformat(g_Query,4095,2,3);
    
    for(new Count;Count < iTotal;Count++)
    {
		if(!IsValidMessage(id,Count))
		{
			ArraySetString(CurArray,Count,g_Query);
			server_print("RE-FILLING");
            return Count;
		}
    }
	
	ArrayPushString(CurArray,g_Query);
	return ArraySize(CurArray) - 1
}
public _DRP_RemoveUserCMsg(Plugin,Params)
{
	if(Params != 2)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected 2, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new id = get_param(1),Index = get_param(2);
	if(!is_user_connected(id))
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"User not connected: %d",Plugin,id);
		return FAILED
	}
	
	if(!IsValidMessage(id,Index))
		return FAILED
	
    new Array:CurArray = ArrayGetCell(g_UserCMsgs,id);
	return ArraySetString(CurArray,Index,"");
}
*/
public _DRP_TSGetUserWeaponID(Plugin,Params)
{
	if(Params < 1)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected 1 or more, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new id = get_param(1);
	if(!is_user_connected(id))
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"User not connected: %d",Plugin,id);
		return FAILED
	}
	
	set_param_byref(2,g_UserWpnID[id][1]); // Clip
	set_param_byref(3,g_UserWpnID[id][2]); // Ammo
	set_param_byref(4,g_UserWpnID[id][3]); // Mode
	set_param_byref(5,g_UserWpnID[id][4]); // Extra
	
	return g_UserWpnID[id][0]
}
public _DRP_TSSetUserAmmo(Plugin,Params)
{
	if(Params < 1)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected 1 or more, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new id = get_param(1);
	if(!is_user_connected(id))
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"User not connected: %d",Plugin,id);
		return FAILED
	}
	new WeaponID = get_param(2),Ammo = get_param(3);
	if(WeaponID <= 0 || WeaponID > 36 || WeaponID == 34)
		return FAILED
	
	client_cmd(id,"weapon_%d",WeaponID);
	
	static tsweaponoffset[37];
	tsweaponoffset[1] = 51; // Glock18
	tsweaponoffset[3] = 50; // Uzi
	tsweaponoffset[4] = 52; // M3
	tsweaponoffset[5] = 53; // M4A1
	tsweaponoffset[6] = 50; // MP5SD
	tsweaponoffset[7] = 50; // MP5K
	tsweaponoffset[8] = 50; // Beretta
	tsweaponoffset[9] = 51; // Socom
	tsweaponoffset[11] = 52; // USAS
	tsweaponoffset[12] = 59; // Desert Eagle
	tsweaponoffset[13] = 55; // AK47
	tsweaponoffset[14] = 56; // Fiveseven
	tsweaponoffset[15] = 53; // Steyr AUG
	tsweaponoffset[17] = 61; // Skorpion
	tsweaponoffset[18] = 57; // Barret
	tsweaponoffset[19] = 56; // Mp7
	tsweaponoffset[20] = 52; // Spas
	tsweaponoffset[21] = 51; // Golden Colts
	tsweaponoffset[22] = 58; // Glock20
	tsweaponoffset[23] = 51; // UMP
	tsweaponoffset[24] = 354; // M61 Grenade
	tsweaponoffset[25] = 366; // Combat Knife
	tsweaponoffset[26] = 52; // Mossberg
	tsweaponoffset[27] = 53; // M16
	tsweaponoffset[28] = 59; // Ruger Mk1
	tsweaponoffset[31] = 60; // Raging Bull
	tsweaponoffset[32] = 53; // M60
	tsweaponoffset[33] = 52; // Sawed Off
	tsweaponoffset[35] = 486; // Seal Knife
	tsweaponoffset[36] = 62; // Contender
	
	new TSGun = ts_get_user_tsgun(id);
	if(!TSGun)
		return FAILED
	
	set_pdata_int(TSGun,tsweaponoffset[WeaponID],Ammo);
	
	if(WeaponID == 24 || WeaponID == 25 || WeaponID == 35)
	{
		set_pdata_int(TSGun,41,Ammo);
		set_pdata_int(TSGun,839,Ammo);
		
		Ammo = 0
	}
	
	message_begin(MSG_ONE,gmsgWeaponInfo,_,id);
	write_byte(WeaponID);
	write_byte(g_UserWpnID[id][1]);
	write_short(Ammo)
	write_byte(g_UserWpnID[id][3]);
	write_byte(g_UserWpnID[id][4]);
	message_end();
	
	return SUCCEEDED
}
/*==================================================================================================================================================*/
/*
public _DRP_UserHaveProgressBar(Plugin,Params)
{
	if(Params != 1)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected 1, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new id = get_param(1);
	if(g_ProgressBar[id][SECONDS] >= 1)
		return SUCCEEDED
	
	return FAILED
}

// Creates a Progress Bar in the center of the screen (If DRPHud is 0)
// Define R,G,B Progress Colors, and R,G,B
// DRP_ProgressBar(id,const Title[],const FinishedText[],Seconds,BarLen,Red = 255,Green = 0,Blue = 0,DRPHud = 0,const Function2Call[]="");
public _DRP_ProgressBar(Plugin,Params)
{
	
	if(Params != 1)
	{
	}
	
	
	new id = get_param(1);
	if(!is_user_connected(id) && id != -1)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"User not connected: %d",Plugin,id);
		return FAILED
	}
	if(g_ProgressBar[id][SECONDS] >= 1)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"User (ID: %d) already has a progress bar in progress",Plugin,id);
		return FAILED
	}
	
	new Count
	for(Count = 0;Count < ProgressBar;Count++)
		g_ProgressBar[id][Count] = 0
	
	new Output[128],Handler[33],Seconds = get_param(4),BarLen = get_param(5),DRPHud = get_param(9);
	if(Seconds <= 0 || BarLen <= 0)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"The progress bar must have Seconds & BarLen greater than 1",Plugin);
		return FAILED
	}
	
	g_ProgressBar[id][RED] = get_param(6);
	g_ProgressBar[id][GREEN] = get_param(7);
	g_ProgressBar[id][BLUE] = get_param(8);
	
	get_string(10,Handler,32);
	get_string(2,Output,127);
	
	new TitleLen = format(Output,127,"%s^n",Output);
	
	
	BarLen = (BarLen + TitleLen > sizeof Output - 1 ? sizeof Output - (1 + TitleLen) : BarLen)
	
	for(Count = TitleLen + 1;Count < (BarLen + TitleLen + 1);Count++)
		add(Output,sizeof Output - 1,"-");
	
	if(Handler[0])
		{ g_ProgressBar[PLUGIN_ID][id] = Plugin; copy(g_ProgressBar[id][HANDLER],32,Handler); }
	else
		g_ProgressBar[PLUGIN_ID][id] = -1
		
	g_ProgressBar[SECONDS][id] = Seconds
		
	for(Count = 0;Count <= BarLen + 1;Count++)
	{
		// End of the progress bar
		if(Count == BarLen + 1)
		{
			get_string(3,Output,sizeof Output - 1);
			set_task(Count * float(Seconds) / BarLen, "_ProgressBarEnd",id,Output,sizeof Output - 1);
			break
		}
		set_task(Count * float(Seconds) / BarLen,"_RunProgressBar",id,Output,sizeof Output - 1);
		replace(Output,sizeof Output - 1,"-","|");
	}
	
	
	return SUCCEEDED
}

// Progress Bar Task Functions
public _ProgressBarEnd(const Message[],id)
{
	new Plugin = g_ProgressBar[PLUGIN_ID][id]
	if(Plugin > 0)
	{
		new Forward = CreateOneForward(Plugin,g_ProgressBar[id][HANDLER],FP_CELL,FP_CELL),Return
		if(Forward <= 0 || !ExecuteForward(Forward,Return,id,g_ProgressBar[SECONDS][id]))
			return FAILED
		
		DestroyForward(Forward);
	}
	
	g_ProgressBar[SECONDS][id] = 0
	
	set_hudmessage(0,150,0,_,_,1,_,6.0,_,_,-1);
	show_hudmessage(id,Message);
	
	
	_Debug("PLUGIN: %d - SECONDS: %d",g_ProgressBar[PLUGIN_ID][id],g_ProgressBar[SECONDS][id]);
	g_ProgressBar[SECONDS][id] = 0
	
	set_hudmessage(255);
	show_hudmessage(id,Message);
	
	
	return SUCCEEDED
}
public _RunProgressBar(const Message[],id)
{
	set_hudmessage(g_ProgressBar[RED][id],g_ProgressBar[GREEN][id],g_ProgressBar[BLUE][id],_,_,_,_,12.0,_,_,4);
	
	if(id == -1)
		show_hudmessage(0,Message);
	else
		show_hudmessage(id,Message);
}
*/
/*==================================================================================================================================================*/
public _DRP_IsCop(Plugin,Params)
{
	if(Params != 1)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 1, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new id = get_param(1);
	if(!is_user_connected(id))
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"User not connected: %d",Plugin,id);
		return FAILED
	}
	
	new StrAccess[JOB_ACCESSES + 1]
	get_pcvar_string(p_CopAccess,StrAccess,JOB_ACCESSES);
	
	new Access = DRP_AccessToInt(StrAccess);
	
	if(g_UserAccess[id] & Access)
		return SUCCEEDED
	
	return FAILED
}
public _DRP_IsAdmin(Plugin,Params)
{
	if(Params != 1)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 1, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new id = get_param(1);
	if(!is_user_connected(id))
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"User not connected: %d",Plugin,id);
		return FAILED
	}
	
	return UTIL_IsUserAdmin(id);
}
public _DRP_IsMedic(Plugin,Params)
{
	if(Params != 1)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 1, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new id = get_param(1);
	if(!is_user_connected(id))
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"User not connected: %d",Plugin,id);
		return FAILED
	}
	
	new StrAccess[JOB_ACCESSES + 1]
	get_pcvar_string(p_MedicAccess,StrAccess,JOB_ACCESSES);
	
	new Access = DRP_AccessToInt(StrAccess);
	
	if(g_UserJobRight[id] & Access)
		return SUCCEEDED
	
	return FAILED
}
public _DRP_IsJobAdmin(Plugin,Params)
{
	if(Params != 1)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 1, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new id = get_param(1);
	if(!is_user_connected(id))
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"User not connected: %d",Plugin,id);
		return FAILED
	}
	
	new StrAccess[JOB_ACCESSES + 1]
	get_pcvar_string(p_AdminAccess,StrAccess,JOB_ACCESSES);
	
	new Access = DRP_AccessToInt(StrAccess);
	
	if(g_UserJobRight[id] & Access)
		return SUCCEEDED
	
	return FAILED
}
/*==================================================================================================================================================*/
public _DRP_GetUserWallet(Plugin,Params)
{
	if(Params != 1)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 1, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new id = get_param(1);
	if(!is_user_connected(id))
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"User not connected: %d",id);
		return FAILED
	}
	
	return g_UserWallet[id]
}
public _DRP_SetUserWallet(Plugin,Params)
{
	if(Params != 2)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 2, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new id = get_param(1);
	if(!is_user_connected(id))
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"User not connected: %d",id);
		return FAILED
	}
	
	new Amount = get_param(2);
	g_UserWallet[id] = Amount;
	
	return SUCCEEDED
}
public _DRP_GetUserBank(Plugin,Params)
{
	if(Params != 1)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 1, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new id = get_param(1);
	if(!is_user_connected(id))
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"User not connected: %d",id);
		return FAILED
	}
	
	return g_UserBank[id]
}
public _DRP_SetUserBank(Plugin,Params)
{
	if(Params != 2)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 2, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new id = get_param(1);
	if(!is_user_connected(id))
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"User not connected: %d",id);
		return FAILED
	}
	
	new Amount = get_param(2);
	g_UserBank[id] = Amount
	
	return SUCCEEDED
}
/*==================================================================================================================================================*/
public _DRP_GetPlayerInfo(Plugin,Params)
{
	if(Params != 2)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 2, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new id = get_param(1);
	if(!is_user_connected(id))
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"User not connected: %d",Plugin,id);
		return FAILED
	}
	
	switch(get_param(2))
	{
		case PLY_GOT_INFO: 
			return g_GotInfo[id];
		case PLY_SAVING:
			return g_Saving[id];
		case PLY_JOINED:
			return g_Joined[id];
		case PLY_BADJOB:
			return g_BadJob[id];
		case PLY_BADAUTH:
			return g_BadAuthID[id]
			
		default:
		{
			UTIL_Error(AMX_ERR_NATIVE,0,"Invalid 'FROM' Handle. Please check the 'PLY' enum",Plugin);
			return FAILED
		}
	}
	return SUCCEEDED
}
public _DRP_GetUserTime(Plugin,Params)
{
	if(Params != 1)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 1, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new id = get_param(1);
	if(!is_user_connected(id))
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"User not connected: %d",Plugin,id);
		return FAILED
	}
	return g_UserTime[id]
}
/*==================================================================================================================================================*/
public _DRP_GetUserJobID(Plugin,Params)
{
	if(Params != 1)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 1, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new id = get_param(1);
	if(!is_user_connected(id))
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"User not connected: %d",Plugin,id);
		return FAILED
	}
	
	return g_UserJobID[id] + 1
}
public _DRP_SetUserJobID(Plugin,Params)
{
	if(Params != 2)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 2, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new JobID = get_param(2) - 1
	
	if(!UTIL_ValidJobID(JobID))
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Invalid JobID %d",Plugin,JobID);
		return FAILED
	}
	
	new id = get_param(1);
	if(!is_user_connected(id))
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"User not connected: %d",Plugin,id);
		return FAILED
	}
	
	g_UserJobID[id] = JobID
	g_UserAccess[id] = g_AccessCache[id]
	
	g_UserSalary[id] = array_get_int(array_get_int(g_JobArray,JobID),2);
	g_UserAccess[id] |= array_get_int(array_get_int(g_JobArray,JobID),3);
	
	return SUCCEEDED
}
public _DRP_GetJobSalary(Plugin,Params)
{
	if(Params != 1)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 1, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new JobID = get_param(1) - 1;
	
	if(!UTIL_ValidJobID(JobID))
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Invalid JobID %d",Plugin,JobID);
		return FAILED
	}
	
	return array_get_int(array_get_int(g_JobArray,JobID),2);
}
/*==================================================================================================================================================*/
public _DRP_FindJobID(Plugin,Params)
{
	if(Params != 3)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 3, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new SearchString[64],MaxResults = get_param(3),Num,Name[33]
	static Results[512],Temp[512],Length[512]
	
	get_string(1,SearchString,63);
	
	for(new Count;Count < g_JobNum;Count++)
	{		
		if(!UTIL_ValidJobID(Count)) 
			continue
		
		array_get_string(array_get_int(g_JobArray,Count),1,Name,32);
		if(containi(Name,SearchString) != -1)
		{
			Temp[Num] = Count + 1
			Length[Num] = strlen(Name);
			
			Num++
		}
	}
	
	new CurStep,Cell = -1
	for(new Count,LowLength,Count2;Count < Num && Count < MaxResults;Count++)
	{
		LowLength = 9999999
		for(Count2 = 0;Count2 < Num;Count2++)
		{
			if(Length[Count2] < LowLength && Length[Count2] >= CurStep && Cell != Count2)
			{
				LowLength = Length[Count2]
				Cell = Count2
			}
		}
		
		CurStep = LowLength
		Results[Count] = Temp[Cell]
	}
	
	set_array(2,Results,Num);
	return Num
}
public _DRP_FindItemID(Plugin,Params)
{
	if(Params != 3)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 3, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new Item[33],MaxResults = get_param(3),Num,Name[33]
	static Temp[512],Results[512],Length[512]
	
	get_string(1,Item,32);
	
	for(new Count = 1;Count <= g_ItemsNum && Num < 512;Count++)
	{
		array_get_string(array_get_int(g_ItemsArray,Count),1,Name,32);
		
		if(containi(Name,Item) != -1)
		{
			Temp[Num] = Count
			Length[Num] = strlen(Name);
			
			Num++
		}
	}
	
	new CurStep,Cell = -1
	for(new Count,LowLength,Count2;Count < Num && Count < MaxResults;Count++)
	{
		LowLength = 9999999
		for(Count2 = 0;Count2 < Num;Count2++)
		{
			if(Length[Count2] < LowLength && Length[Count2] >= CurStep && Cell != Count2)
			{
				LowLength = Length[Count2]
				Cell = Count2
			}
		}
		
		CurStep = LowLength
		Results[Count] = Temp[Cell]
	}
	
	set_array(2,Results,Num);
	return Num
}
public _DRP_FindItemID2(Plugin,Params)
{
	if(Params != 1)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 3, Found: %d",Plugin,Params);
		return FAILED
	}
	new Name[33]
	get_string(1,Name,32);
	
	return UTIL_FindItemID(Name);
}
	
public _DRP_ValidJobID(Plugin,Params)
{
	if(Params != 1)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 1, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new JobID = get_param(1) - 1
	
	return UTIL_ValidJobID(JobID);
}
public _DRP_ValidItemID(Plugin,Params)
{
	if(Params != 1)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 1, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new ItemID = get_param(1);
	
	return UTIL_ValidItemID(ItemID);
}	
/*==================================================================================================================================================*/
public _DRP_GetUserHunger(Plugin,Params)
{
	if(Params != 1)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 1, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new id = get_param(1);
	if(!is_user_connected(id))
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"User not connected: %d",Plugin,id);
		return FAILED
	}
	
	return g_UserHunger[id]
}
public _DRP_SetUserHunger(Plugin,Params)
{
	if(Params != 2)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 2, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new id = get_param(1);
	if(!is_user_connected(id))
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"User not connected: %d",Plugin,id);
		return FAILED
	}
	
	g_UserHunger[id] = clamp(get_param(2),0,120);
	
	return SUCCEEDED
}
/*==================================================================================================================================================*/
public _DRP_AddCommand(Plugin,Params)
{
	if(Params != 2)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 2, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new CurArray = array_create();
	array_set_int(g_CommandArray,++g_CommandNum,CurArray);
	
	get_string(1,g_Query,4095);
	array_set_string(CurArray,1,g_Query);
	
	get_string(2,g_Query,4095);
	array_set_string(CurArray,2,g_Query);
	
	if(containi(g_Query,"(ADMIN)") != -1)
		array_set_int(CurArray,3,1);
	
	return SUCCEEDED
}
public _DRP_AddHudItem(Plugin,Params)
{
	if(Params < 4)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 4, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new const id = get_param(1),Channel = get_param(2);
	if(!is_user_connected(id) && id != -1)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"User not connected: %d",Plugin,id);
		return FAILED
	}
	
	new Refresh = get_param(3);
	if(Channel < 0 || Channel > HUD_NUM)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Invalid HUD Channel: %d",Plugin,Channel);
		return FAILED
	}
	
	static Message[256]
	vdformat(Message,255,4,5);

	if(g_HudPending)
		Refresh = 0
	
	UTIL_AddHudItem(id,Channel,Message,Refresh);
	
	return SUCCEEDED
}
public _DRP_ForceHUDUpdate(Plugin,Params)
{
	if(Params != 2)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 2, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new const id = get_param(1),Hud = get_param(2);
	
	if(!is_user_connected(id) && id != -1)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"User not connected: %d",Plugin,id);
		return FAILED
	}
	
	if(id == -1)
	{
		new iPlayers[32],iNum
		get_players(iPlayers,iNum);
		
		for(new Count;Count < iNum;Count++)
			RenderHud(iPlayers[Count],Hud);
	}
	else
	{
		RenderHud(id,Hud);
	}
	
	return SUCCEEDED
}
public _DRP_AddJob(Plugin,Params)
{
	if(Params != 3)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 3, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new Name[33],Salary = get_param(2),IntAccess = get_param(3);
	get_string(1,Name,32);
	
	new Results[1]
	DRP_FindJobID(Name,Results,1);
	
	if(Results[0])
	{
		Results[0] -= 1
		
		new TempName[33]
		array_get_string(array_get_int(g_JobArray,Results[0]),1,TempName,32);
		
		UTIL_Error(AMX_ERR_NATIVE,0,"A job with a similar name already exists. User input: %s - Existing job: %s",Plugin,Name,TempName)
		return FAILED
	}
	
	new Access[JOB_ACCESSES + 1]
	DRP_IntToAccess(IntAccess,Access,JOB_ACCESSES);
	
	format(g_Query,4095,"INSERT INTO %s VALUES ('%s','%d','%s')",g_JobsTable,Name,Salary,Access);
	SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",g_Query);
	
	new CurArray = array_create();
	array_set_int(g_JobArray,g_JobNum++,CurArray);
	
	array_set_string(CurArray,1,Name);
	array_set_int(CurArray,2,Salary);
	array_set_int(CurArray,3,IntAccess);
	
	return g_JobNum
}
public _DRP_DeleteJob(Plugin,Params)
{
	if(Params != 1)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 1, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new JobID = get_param(1) - 1
	
	if(!UTIL_ValidJobID(JobID))
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Invalid job id: %d",Plugin,JobID);
		return FAILED
	}
	
	return UTIL_DeleteJob(JobID);
}
/*==================================================================================================================================================*/
public _DRP_GetPayDay(Plugin,Params)
	return g_Time / 10
/*==================================================================================================================================================*/
public _DRP_GetJobName(Plugin,Params)
{
	if(Params != 3)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 3, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new JobID = get_param(1) - 1,JobName[36]
	
	if(!UTIL_ValidJobID(JobID))
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Invalid JobID: %d",Plugin,JobID);
		return FAILED
	}
	
	array_get_string(array_get_int(g_JobArray,JobID),1,JobName,35);	
	set_string(2,JobName,get_param(3));
	
	return SUCCEEDED
}
/*==================================================================================================================================================*/
public _DRP_GetUserAccess(Plugin,Params)
{
	if(Params != 1)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 1, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new id = get_param(1);
	if(!is_user_connected(id))
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"User not connected: %d",Plugin,id);
		return FAILED
	}
	
	return g_UserAccess[id]
}

public _DRP_SetUserAccess(Plugin,Params)
{
	if(Params != 2)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 2, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new id = get_param(1);
	if(!is_user_connected(id))
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"User not connected: %d",Plugin,id);
		return FAILED
	}
	
	new Access = get_param(2);
	
	g_UserAccess[id] = Access
	g_UserAccess[id] |= array_get_int(array_get_int(g_JobArray,g_UserJobID[id]),3);
	
	g_AccessCache[id] = Access
	
	return SUCCEEDED
}
public _DRP_SetUserJobRight(Plugin,Params)
{
	if(Params != 2)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 2, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new id = get_param(1),Rights = get_param(2),Set
	for(new Count;Count < JOB_ACCESSES;Count++)
		if(Rights & (1<<Count))
			Set |= (1<<Count)
	
	if(!is_user_connected(id))
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"User not connected: %d",Plugin,id);
		return FAILED
	}
	
	g_UserJobRight[id] = Set
	return SUCCEEDED
}
public _DRP_GetUserJobRight(Plugin,Params)
{
	if(Params != 1)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 1, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new id = get_param(1);
	if(!is_user_connected(id))
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"User not connected: %d",Plugin,id);
		return FAILED
	}
	
	return g_UserJobRight[id]
}
public _DRP_GetJobAccess(Plugin,Params)
{
	if(Params != 1)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 1, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new JobID = get_param(1) - 1
	if(!UTIL_ValidJobID(JobID))
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Invalid JobID: %d",Plugin,JobID);
		return FAILED
	}
	
	return array_get_int(array_get_int(g_JobArray,JobID),3);
}
public _DRP_RegisterItem(Plugin,Params)
{
	if(Params < 6)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 6 or more, Found: %d",Plugin,Params);
		return FAILED
	}
	
	if(!g_ItemsRegistered && !get_param(10))
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"^"DRP_RegisterItem^" can only be called in the ^"DRP_RegisterItems^" Forward/Function.",Plugin);
		return FAILED
	}
		
	new Name[33],Handler[33],Description[64]
	get_string(1,Name,32);
	get_string(2,Handler,32);
	
	new Len = strlen(Name);
	if(!Len)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Item name must have a length.",Plugin);
		return FAILED
	}
	
	for(new Count = 1;Count <= g_ItemsNum;Count++)
	{
		array_get_string(array_get_int(g_ItemsArray,Count),1,Description,63);
		if(equali(Name,Description))
		{
			UTIL_Error(AMX_ERR_NATIVE,0,"Item collision detected. Name: %s",Plugin,Name);
			return FAILED
		}
	}
	
	get_string(3,Description,63);
	
	new CurArray = array_create();
	
	array_set_int(g_ItemsArray,++g_ItemsNum,CurArray);
	array_set_string(CurArray,1,Name);
	array_set_int(CurArray,2,Plugin);
	array_set_string(CurArray,3,Handler);
	array_set_string(CurArray,4,Description);
	
	array_set_int(CurArray,5,get_param(4) ? 1 : 0); // Use up?
	array_set_int(CurArray,6,get_param(5) ? 1 : 0); // Droppable?
	array_set_int(CurArray,7,get_param(6) ? 1 : 0); // Giveable?
	
	new Values[3]
	Values[0] = get_param(7);
	Values[1] = get_param(8);
	Values[2] = get_param(9);
	
	if(Values[0])
		array_set_int(CurArray,8,Values[0]);
	if(Values[1])
		array_set_int(CurArray,9,Values[1]);
	if(Values[2])
		array_set_int(CurArray,10,Values[2]);
	
	return g_ItemsNum
}

public _DRP_GetUserItemNum(Plugin,Params)
{
	if(Params != 2)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 2, Found: %d",Plugin,Params);
		return FAILED
	}
		
	new id = get_param(1),ItemID = get_param(2);
	if(!is_user_connected(id))
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"User not connected: %d",Plugin,id);
		return FAILED
	}
	if(!UTIL_ValidItemID(ItemID))
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Invalid ItemID: %d",Plugin,ItemID);
		return FAILED
	}
	
	return UTIL_GetUserItemNum(id,ItemID);
}

public _DRP_SetUserItemNum(Plugin,Params)
{
	if(Params != 3)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 3, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new id = get_param(1),ItemID = get_param(2),ItemNum = get_param(3);
	if(!is_user_connected(id))
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"User not connected: %d",Plugin,id);
		return FAILED
	}
	if(ItemNum < 0)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Invalid item number, must be more than 0. Num: %d",Plugin,ItemNum);
		return FAILED
	}
	if(!UTIL_ValidItemID(ItemID))
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Invalid ItemID: %d",Plugin,ItemID);
		return FAILED
	}
	
	return UTIL_SetUserItemNum(id,ItemID,ItemNum);
}
public _DRP_GetUserTotalItems(Plugin,Params)
{
	if(Params != 1)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 1, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new id = get_param(1);
	if(!is_user_connected(id))
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"User not connected: %d",Plugin,id);
		return FAILED
	}
	
	return array_size(g_UserItemArray[id]);
}

public _DRP_ForceUseItem(Plugin,Params)
{
	if(Params != 3)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 3, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new id = get_param(1),ItemID = get_param(2),UseUp = get_param(3);
	if(!is_user_connected(id))
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"User not connected: %d",Plugin,id);
		return FAILED
	}
	if(UseUp && !UTIL_GetUserItemNum(id,ItemID))
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"User %d has none of ItemID: %d",Plugin,id,ItemID);
		return FAILED
	}
	if(!UTIL_ValidItemID(ItemID))
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Invalid ItemID: %d",Plugin,ItemID);
		return FAILED
	}
	
	ItemUse(id,ItemID,UseUp ? 1 : 0);
	return SUCCEEDED
}
public _DRP_FetchUserItems(Plugin,Params)
{
	if(Params != 2)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 2, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new const id = get_param(1);
	if(!is_user_connected(id))
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"User not connected: %d",Plugin,id);
		return FAILED
	}
	
	new Num,ItemID,Size = array_size(g_UserItemArray[id]) + 1
	new Results[128]
	
	if(Size < 2)
		return FAILED
	
	for(new Count = 1,Success;Count < Size;Count++)
	{
		ItemID = array_get_nth(g_UserItemArray[id],Count,_,Success);
		
		if(ItemID < 1 || ItemID > g_ItemsNum || !Success)
			continue
		
		Results[Num++] = ItemID
	}
	set_array(2,Results,Size);
	
	return Size - 1
}
public _DRP_DropItem(Plugin,Params)
{
	if(Params != 3)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 4, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new ItemID = get_param(1),Num = get_param(2)
	if(!UTIL_ValidItemID(ItemID))
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Invalid ItemID - %d",Plugin,ItemID);
		return FAILED
	}
	if(!Num)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Invalid Item Amount - %d",Plugin,Num);
		return FAILED
	}
	
	new ItemName[33],Float:Origin[3]
	UTIL_GetItemName(ItemID,ItemName,32);
	
	get_array_f(3,Origin,2);
	
	if(!_CreateItemDrop(0,Origin,Num,ItemName))
		return FAILED
	
	return SUCCEEDED
}
public _DRP_DropCash(Plugin,Params)
{
	if(Params != 2)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 2 or less, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new const Cash = get_param(1);
	
	if(Cash < 1)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Invalid cash value: %d",Plugin,Cash);
		return FAILED
	}
	
	new Ent = engfunc(EngFunc_CreateNamedEntity,engfunc(EngFunc_AllocString,"info_target"))
	if(!Ent)
		return FAILED
	
	new Float:Origin[3]
	get_array_f(2,Origin,3);
	
	engfunc(EngFunc_SetModel,Ent,g_MoneyMdl);
	engfunc(EngFunc_SetSize,Ent,{-2.79,-0.0,-6.14},{2.42,1.99,6.35});
	engfunc(EngFunc_SetOrigin,Ent,Origin);
	
	set_pev(Ent,pev_movetype,MOVETYPE_TOSS);
	set_pev(Ent,pev_solid,SOLID_TRIGGER);
	
	Origin[0] = 0.0
	Origin[1] = random_float(0.0,270.0);
	Origin[2] = 0.0
	
	set_pev(Ent,pev_angles,Origin);
	set_pev(Ent,pev_takedamage,DAMAGE_NO);
	
	set_pev(Ent,pev_classname,g_szMoneyPile);
	set_pev(Ent,pev_iuser3,Cash);
	
	set_pev(Ent,pev_renderfx,kRenderFxGlowShell);
	set_pev(Ent,pev_rendercolor,{0.0,255.0,0.0});
	set_pev(Ent,pev_rendermode,kRenderNormal);
	set_pev(Ent,pev_renderamt,16);
	
	return Ent
}
public _DRP_GetItemName(Plugin,Params)
{
	if(Params != 3)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 3, Found: %d",Plugin,Params);
		return FAILED
	}
		
	new ItemID = get_param(1),Len = get_param(3);
	if(!UTIL_ValidItemID(ItemID))
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Invalid ItemID: %d",Plugin,ItemID);
		return FAILED
	}
	
	new Name[33]
	UTIL_GetItemName(ItemID,Name,32);
	
	set_string(2,Name,Len);
	
	return SUCCEEDED
}
/*==================================================================================================================================================*/
public _DRP_RegisterEvent(Plugin,Params)
{
	if(Params != 2)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 2, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new travTrieIter:Iter = GetTravTrieIterator(g_EventTrie),Event[128],Handler[128],Key[128],Dummy[2]
	get_string(1,Event,127);
	get_string(2,Handler,127);
	
	format(Handler,127,"%d|%s",Plugin,Handler);
	
	while(MoreTravTrie(Iter))
	{
		ReadTravTrieKey(Iter,Key,127);
		ReadTravTrieString(Iter,Dummy,1);
		
		// It's okay if the event repeats as multiple plugins can register it
		if(equali(Handler,Key))
			return FAILED
	}
	DestroyTravTrieIterator(Iter);
	TravTrieSetString(g_EventTrie,Handler,Event);
	
	return SUCCEEDED
}
public _DRP_CallEvent(Plugin,Params)
{
	if(Params != 3)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 3, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new const Len = min(4095,get_param(3))
	new Name[33]
	get_string(1,Name,32);
	get_array(2,g_Query,Len);

	return _CallEvent(Name,g_Query,Len);
}
public _DRP_AddMenuItem(Plugin,Params)
{
	if(Params != 3)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 3, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new const id = get_param(1);
	
	if(!g_MenuAccepting[id])
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Menu items can only be added durning the ^"Menu_Display^" event.",Plugin);
		return FAILED
	}
	
	new Name[33],Handler[64],Data[64]
	get_string(2,Name,32);
	get_string(3,Handler[1],62);
	
	Handler[0] = Plugin
	Data[0] = Plugin
	
	copy(Data[1],62,Name);
	
	return TravTrieSetString(g_MenuArray[id],Name,Handler);
}
/*==================================================================================================================================================*/
public _DRP_AddProperty(Plugin,Params)
{
	if(Params != 8)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 8, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new InternalName[64],ExternalName[64],OwnerName[33],OwnerAuth[36],Price,Locked,Access,Profit
	get_string(1,InternalName,63);
	get_string(2,ExternalName,63);
	get_string(3,OwnerName,32);
	get_string(4,OwnerAuth,35);
	
	Price = get_param(5);
	Locked = get_param(6);
	Access = get_param(7);
	Profit = get_param(8);
	
	if(UTIL_MatchProperty(InternalName) > -1)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Property already exists: ^"%s^"",Plugin,InternalName);
		return FAILED
	}
	
	new CurArray = array_create();
	array_set_int(g_PropertyArray,g_PropertyNum++,CurArray);
	
	array_set_string(CurArray,0,InternalName);
	array_set_string(CurArray,1,ExternalName);
	array_set_string(CurArray,2,OwnerName);
	array_set_string(CurArray,3,OwnerAuth);
	array_set_int(CurArray,4,Price);
	array_set_int(CurArray,5,Locked);
	array_set_int(CurArray,6,Access);
	array_set_int(CurArray,7,Profit);
	array_set_int(CurArray,8,0);
	array_set_int(CurArray,9,1);
	
	format(g_Query,4095,"INSERT INTO %s VALUES ('%s','%s','%s','%s','%d','%d','%d','%d')",g_PropertyTable,InternalName,ExternalName,OwnerName,OwnerAuth,Price,Locked,Access,Profit);
	SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",g_Query);
	
	return g_PropertyNum
}
public _DRP_DeleteProperty(Plugin,Params)
{
	if(Params != 1)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 1, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new const Property = get_param(1) - 1
	if(!UTIL_ValidProperty(Property))
		return FAILED
	
	new InternalName[33],FetchInternalName[33],CurArray,NextArray,PropArray = array_get_int(g_PropertyArray,Property);
	array_get_string(PropArray,0,InternalName,32);
	
	new NextInternalName[64],ExternalName[64],OwnerName[33],OwnerAuth[36]
	for(new Count = Property;Count < g_PropertyNum - 1;Count++)
	{
		NextArray = array_get_int(g_PropertyArray,Count + 1);
		
		array_get_string(NextArray,0,NextInternalName,63);
		array_get_string(NextArray,1,ExternalName,63);
		array_get_string(NextArray,2,OwnerName,32);
		array_get_string(NextArray,3,OwnerAuth,35);
		
		CurArray = array_get_int(g_PropertyArray,Count);
		
		array_set_string(CurArray,0,NextInternalName);
		array_set_string(CurArray,1,ExternalName);
		array_set_string(CurArray,2,OwnerName);
		array_set_string(CurArray,3,OwnerAuth);
		array_set_int(CurArray,4,array_get_int(NextArray,4));
		array_set_int(CurArray,5,array_get_int(NextArray,5));
		array_set_int(CurArray,6,array_get_int(NextArray,6));
		array_set_int(CurArray,7,array_get_int(NextArray,7));
		array_set_int(CurArray,8,array_get_int(NextArray,8));
		array_set_int(CurArray,9,array_get_int(NextArray,9));
		
		array_set_int(g_PropertyArray,Count,NextArray);
	}
	
	array_destroy(PropArray);
	array_delete(g_PropertyArray,--g_PropertyNum);
	
	format(g_Query,4095,"DELETE FROM %s WHERE Internalname='%s'",g_PropertyTable,InternalName);
	UTIL_CleverQuery(g_Plugin,g_SqlHandle,"IgnoreHandle",g_Query);
	
	for(new Count;Count < g_DoorNum;Count++)
	{
		CurArray = array_get_int(g_DoorArray,Count);
		array_get_string(g_DoorArray,2,FetchInternalName,32);
		
		if(equali(InternalName,FetchInternalName))
			UTIL_DeleteDoor(Count);
	}
	
	return SUCCEEDED
}
public _DRP_AddDoor(Plugin,Params)
{
	if(Params != 3)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 3, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new Targetname[33],InternalName[64],EntID = get_param(2);
	get_string(1,Targetname,32);
	get_string(3,InternalName,63);
	
	if(UTIL_GetProperty(Targetname,EntID) != -1)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Door already exists: %s (EntID: %d)",Plugin,Targetname,EntID);
		return 0 // Door already exists
	}
	else if(UTIL_MatchProperty(InternalName) == -1)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Property does not exist: %s",Plugin,InternalName);
		return -1 // Property does not exist
	}
	
	new CurArray = array_create();
	array_set_int(g_DoorArray,g_DoorNum++,CurArray);
	
	array_set_string(CurArray,0,Targetname);
	array_set_int(CurArray,1,EntID);
	array_set_string(CurArray,2,InternalName);
	array_set_int(CurArray,3,1);
	
	return g_DoorNum
}
public _DRP_DeleteDoor(Plugin,Params)
{
	if(Params != 1)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 1, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new const Door = get_param(1) - 1
	if(UTIL_ValidDoor(Door))
		return UTIL_DeleteDoor(Door);
	
	return FAILED
}
public _DRP_ValidProperty(Plugin,Params)
{
	if(Params != 1)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 1, Found: %d",Plugin,Params);
		return FAILED
	}
	
	return UTIL_ValidProperty(get_param(1) - 1);
}
public _DRP_ValidDoor(Plugin,Params)
{
	if(Params != 1)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 1, Found: %d",Plugin,Params);
		return FAILED
	}
	
	return UTIL_ValidDoor(get_param(1) - 1);
}
public _DRP_ValidPropertyName(Plugin,Params)
{
	if(Params != 1)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 1, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new InternalName[64]
	get_string(1,InternalName,63);
	
	if(UTIL_MatchProperty(InternalName) > -1)
		return SUCCEEDED
	
	return FAILED
}
public _DRP_ValidDoorName(Plugin,Params)
{
	if(Params != 2)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 2, Found: %d",Plugin,Params);
		return FAILED
	}
		
	new const Ent = get_param(2);
	new Targetname[33]
	get_string(1,Targetname,32);
	
	if(UTIL_GetProperty(Targetname,Ent) > -1)
		return SUCCEEDED
	
	return FAILED
}

public _DRP_PropertyNum()
	return g_PropertyNum

public _DRP_DoorNum()
	return g_DoorNum

public _DRP_PropertyMatch(Plugin,Params)
{
	if(Params != 3)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 3, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new Targetname[33],EntID = get_param(2),InternalName[64]
	get_string(1,Targetname,32);
	get_string(3,InternalName,63);
	
	if(Targetname[0] || EntID)
		return UTIL_GetProperty(Targetname,EntID) + 1
		
	return UTIL_MatchProperty(InternalName) + 1
}

public _DRP_DoorMatch(Plugin,Params)
{
	if(Params != 2)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 2, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new Targetname[33],EntID = get_param(2);
	get_string(1,Targetname,32);
	
	if(Targetname[0] || EntID)
		return UTIL_GetDoor(Targetname,EntID) + 1
		
	return FAILED
}
public _DRP_PropertyGetInternalName(Plugin,Params)
{
	if(Params != 3)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 3, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new Property = get_param(1) - 1,InternalName[64]
	if(!UTIL_ValidProperty(Property))
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Property does not exist: %d",Plugin,Property);
		return FAILED
	}
	
	array_get_string(array_get_int(g_PropertyArray,Property),0,InternalName,63);
	set_string(2,InternalName,get_param(3));
	
	return SUCCEEDED
}
public _DRP_PropertyGetExternalName(Plugin,Params)
{
	if(Params != 3)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 3, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new Property = get_param(1) - 1,ExternalName[64]
	if(!UTIL_ValidProperty(Property))
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Property does not exist: %d",Plugin,Property);
		return FAILED
	}
	
	array_get_string(array_get_int(g_PropertyArray,Property),1,ExternalName,63);
	set_string(2,ExternalName,get_param(3));
	
	return SUCCEEDED
}
public _DRP_PropertySetExternalName(Plugin,Params)
{
	if(Params != 2)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 2, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new Property = get_param(1) - 1,ExternalName[64]
	if(!UTIL_ValidProperty(Property))
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Property does not exist: %d",Plugin,Property);
		return FAILED
	}
	
	get_string(2,ExternalName,63);
	array_set_string(array_get_int(g_PropertyArray,Property),1,ExternalName);
	
	UTIL_PropertyChanged(Property);
	
	return SUCCEEDED
}
public _DRP_PropertyGetOwnerName(Plugin,Params)
{
	if(Params != 3)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 3, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new Property = get_param(1) - 1,OwnerName[33]
	if(!UTIL_ValidProperty(Property))
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Property does not exist: %d",Plugin,Property);
		return FAILED
	}
	
	array_get_string(array_get_int(g_PropertyArray,Property),2,OwnerName,33);
	set_string(2,OwnerName,get_param(3));
	
	return SUCCEEDED
}
public _DRP_PropertySetOwnerName(Plugin,Params)
{
	if(Params != 2)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 3, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new Property = get_param(1) - 1,OwnerName[33]
	if(!UTIL_ValidProperty(Property))
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Property does not exist: %d",Plugin,Property);
		return FAILED
	}
	
	UTIL_PropertyChanged(Property)
	
	get_string(2,OwnerName,32);
	array_set_string(array_get_int(g_PropertyArray,Property),2,OwnerName);
	
	return SUCCEEDED
}
public _DRP_PropertyGetOwnerAuth(Plugin,Params)
{
	if(Params != 3)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 3, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new Property = get_param(1) - 1,OwnerAuth[33]
	if(!UTIL_ValidProperty(Property))
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Property does not exist: %d",Plugin,Property);
		return FAILED
	}
	
	array_get_string(array_get_int(g_PropertyArray,Property),3,OwnerAuth,33);
	set_string(2,OwnerAuth,get_param(3));
	
	return SUCCEEDED
}
public _DRP_PropertySetOwnerAuth(Plugin,Params)
{
	if(Params != 2)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 2, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new Property = get_param(1) - 1,OwnerAuth[33]
	if(!UTIL_ValidProperty(Property))
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Property does not exist: %d",Plugin,Property);
		return FAILED
	}
	
	UTIL_PropertyChanged(Property);
	
	get_string(2,OwnerAuth,32);
	array_set_string(array_get_int(g_PropertyArray,Property),3,OwnerAuth);
	
	return SUCCEEDED
}
public _DRP_PropertyAddAccess(Plugin,Params)
{
	if(Params != 2)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 2, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new Property = get_param(1) - 1,AuthID[36],InternalName[64]
	get_string(2,AuthID,35);
	
	if(!UTIL_ValidProperty(Property))
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Property does not exist: %d",Plugin,Property);
		return FAILED
	}
	
	UTIL_PropertyChanged(Property);
	
	new CurArray = array_get_int(g_PropertyArray,Property);
	array_get_string(CurArray,0,InternalName,63);
	
	format(g_Query,4095,"INSERT INTO %s VALUES('%s|%s')",g_KeysTable,AuthID,InternalName);
	UTIL_CleverQuery(g_Plugin,g_SqlHandle,"IgnoreHandle",g_Query);
	
	new PlayerAuthID[36],iPlayers[32],iNum,Index
	get_players(iPlayers,iNum);
	
	for(new Count;Count < iNum;Count++)
	{
		Index = iPlayers[Count]
		get_user_authid(Index,PlayerAuthID,35);
		
		if(equali(AuthID,PlayerAuthID))
		{
			array_set_int(CurArray,8,array_get_int(CurArray,8)|(1<<(Index - 1)));
			break
		}
	}
	
	return SUCCEEDED
}
public _DRP_PropertyRemoveAccess(Plugin,Params)
{
	if(Params != 2)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 2, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new Property = get_param(1) - 1,AuthID[36],InternalName[64]
	get_string(2,AuthID,35);
	
	if(!UTIL_ValidProperty(Property))
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Property does not exist: %d",Plugin,Property);
		return FAILED
	}
	
	UTIL_PropertyChanged(Property);
	
	new CurArray = array_get_int(g_PropertyArray,Property);
	array_get_string(CurArray,0,InternalName,63);
	
	format(g_Query,4095,"DELETE FROM %s WHERE authidkey='%s|%s'",g_KeysTable,AuthID,InternalName)
	UTIL_CleverQuery(g_Plugin,g_SqlHandle,"IgnoreHandle",g_Query);
	
	new PlayerAuthID[36],iPlayers[32],iNum,Index
	get_players(iPlayers,iNum);
	
	for(new Count;Count < iNum;Count++)
	{
		Index = iPlayers[Count]
		get_user_authid(Index,PlayerAuthID,35);
		
		if(equali(AuthID,PlayerAuthID))
		{
			array_set_int(CurArray,8,array_get_int(CurArray,8) & ~(1<<(Index - 1)))
			break
		}
	}
	
	return SUCCEEDED
}
public _DRP_PropertyGetProfit(Plugin,Params)
{
	if(Params != 1)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 1, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new Property = get_param(1) - 1
	if(!UTIL_ValidProperty(Property))
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Property does not exist: %d",Property);
		return FAILED
	}
	
	return array_get_int(array_get_int(g_PropertyArray,Property),7);
}
public _DRP_PropertySetProfit(Plugin,Params)
{
	if(Params != 2)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 2, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new Property = get_param(1) - 1
	if(!UTIL_ValidProperty(Property))
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Property does not exist: %d",Property);
		return FAILED
	}
	
	UTIL_PropertyChanged(Property);
	array_set_int(array_get_int(g_PropertyArray,Property),7,max(0,get_param(2)));
	
	return SUCCEEDED
}
public _DRP_PropertyGetPrice(Plugin,Params)
{
	if(Params != 2)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 2, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new Property = get_param(1) - 1
	if(!UTIL_ValidProperty(Property))
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Property does not exist: %d",Property);
		return FAILED
	}
	
	return array_get_int(array_get_int(g_PropertyArray,Property),4);
}
public _DRP_PropertySetPrice(Plugin,Params)
{
	if(Params != 2)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 2, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new Property = get_param(1) - 1
	if(!UTIL_ValidProperty(Property))
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Property does not exist: %d",Property);
		return FAILED
	}
	
	array_set_int(array_get_int(g_PropertyArray,Property),4,max(0,get_param(2)));
	
	return SUCCEEDED
}
public _DRP_PropertySetMessage(Plugin,Params)
{
	if(Params != 2)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 2, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new Property = get_param(1) - 1
	if(!UTIL_ValidProperty(Property))
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Property does not exist: %d",Property);
		return FAILED
	}
	
	new Message[200]
	get_string(2,Message,199);
	
	new Len = strlen(Message);
	
	if(Len > 128)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Property message must not be longer than 128 chars. (%d - current length)",Len);
		return FAILED
	}
	
	array_set_string(array_get_int(g_PropertyArray,Property),10,Message);
	UTIL_PropertyChanged(Property);
	
	return SUCCEEDED
}
public _DRP_PropertyGetMessage(Plugin,Params)
{
	if(Params != 3)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 3, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new Property = get_param(1) - 1
	if(!UTIL_ValidProperty(Property))
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Property does not exist: %d",Property);
		return FAILED
	}
	
	new Message[128]
	array_get_string(array_get_int(g_PropertyArray,Property),10,Message,127);
	set_string(2,Message,get_param(3));
	
	return SUCCEEDED
}
public _DRP_PropertySetLocked(Plugin,Params)
{
	if(Params != 2)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 2, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new Property = get_param(1) - 1
	if(!UTIL_ValidProperty(Property))
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Property does not exist: %d",Property);
		return FAILED
	}
	
	UTIL_PropertyChanged(Property);
	array_set_int(array_get_int(g_PropertyArray,Property),5,get_param(2) ? 1 : 0);
	
	return SUCCEEDED
}
public _DRP_PropertyGetLocked(Plugin,Params)
{
	if(Params != 1)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 1, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new Property = get_param(1) - 1
	if(!UTIL_ValidProperty(Property))
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Property does not exist: %d",Property);
		return FAILED
	}
	
	return array_get_int(array_get_int(g_PropertyArray,Property),5);
}
/*==================================================================================================================================================*/
public _DRP_ClassLoad(Plugin,Params)
{
	if(Params != 4)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 4, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new Param[64],Handler[64],Temp[128],Table[64],ClassName[128]
	get_string(1,Param,63);
	get_string(2,Handler,63);
	get_string(4,Table,63);
	get_string(3,g_Query,4095);
	
	if(!Table[0])
		copy(Table,63,g_DataTable);
	
	format(ClassName,127,"%s|%s",Table,Param);
	format(Temp,127,"%d|%s",Plugin,Handler);
	
	new travTrieIter:Iter = GetTravTrieIterator(g_ClassArray),Cell,ClassHeader[64],Loaded,TravTrie:CurTrie,TravTrie:PluginTrie,Flag,ReadTable[64],Garbage[1]
	while(MoreTravTrie(Iter))
	{
		ReadTravTrieKey(Iter,ClassHeader,63);
		ReadTravTrieCell(Iter,Cell);
		
		strtok(ClassHeader,ReadTable,63,Garbage,0,'|');
		if(Table[0] && equali(ReadTable,Table))
			Flag = 1
		
		if(equali(ClassName,ClassHeader))
		{
			TravTrieGetCell(g_ClassArray,ClassHeader,CurTrie);
			TravTrieGetHCell(CurTrie,"/plugins",PluginTrie);
			
			TravTrieSetCellEx(PluginTrie,Plugin,1);
			TravTrieGetHCell(CurTrie,"/loaded",Loaded);
			
			if(!Loaded)
			{
				new TravTrie:CallsTrie
				
				TravTrieGetHCell(CurTrie,"/calls",CallsTrie);
				TravTrieSetString(CallsTrie,Temp,g_Query);
				
				return -1
			}
			
			new Forward = CreateOneForward(Plugin,Handler,FP_CELL,FP_STRING,FP_STRING),Return
			if(!Forward || !ExecuteForward(Forward,Return,_:CurTrie,ClassHeader,g_Query))
			{
				UTIL_Error(AMX_ERR_NATIVE,0,"Could not execute %s forward to %d",Plugin,Handler,Plugin);
				return FAILED
			}				
			DestroyForward(Forward);
			
			return PLUGIN_HANDLED
		}
	}
	DestroyTravTrieIterator(Iter);
	
	if(!Flag && !equali(g_DataTable,Table))
	{
		static Query[512]
		format(Query,511,"CREATE TABLE IF NOT EXISTS %s (classkey VARCHAR(64),value TEXT,UNIQUE KEY (classkey))",Table);
		UTIL_CleverQuery(g_Plugin,g_SqlHandle,"IgnoreHandle",Query);
	}
	
	new Buffer[128]
	copy(Buffer,126,Param);
	
	new TravTrie:CallTrie = TravTrieCreate();
	TravTrieSetString(CallTrie,Temp,g_Query);
	
	CurTrie = TravTrieCreate();
	TravTrieSetCell(g_ClassArray,ClassName,CurTrie);
	TravTrieSetHCell(CurTrie,"/loaded",0)
	TravTrieSetHCell(CurTrie,"/saving",0)
	TravTrieSetHCell(CurTrie,"/lastquery",0)
	TravTrieSetHCell(CurTrie,"/plugins",TravTrieCreate())
	TravTrieSetHCell(CurTrie,"/changed",TravTrieCreate())
	TravTrieSetHCell(CurTrie,"/calls",CallTrie)
	TravTrieSetHCell(CurTrie,"/savetrie",TravTrieCreate())
	TravTrieSetString(CurTrie,"/table",Table)
	
	Buffer[127] = _:CurTrie
	
	format(g_Query,4095,"SELECT * FROM %s WHERE classkey LIKE '%s|%%%%'",Table,Buffer);
	SQL_ThreadQuery(g_SqlHandle,"ClassLoadHandle",g_Query,Buffer,128);
	
	return PLUGIN_CONTINUE
}
public ClassLoadHandle(FailState,Handle:Query,Error[],Errcode,Data[],DataSize) 
{
	if(FailState == TQUERY_CONNECT_FAILED)
	{
		UTIL_Error(0,1,"Could not connect to SQL database. (Error: %s)",0,Error ? Error : "UNKNOWN");
		return FAILED
	}
	else if(FailState == TQUERY_QUERY_FAILED)
	{
		SQL_QueryError(Query,g_Query,4095);
		return UTIL_Error(0,1,"Query Failed (Error: %s)",0,g_Query);
	}
	if(Errcode)
	{
		UTIL_Error(0,1,"SQL ErrorCode (Error: %s)",0,Error);
		return FAILED
	}
	
	new ClassKey[128],Key[64],Value[128],Garbage[2],TravTrie:CurTrie = TravTrie:Data[127],TravTrie:CallsTrie
	while(SQL_MoreResults(Query))
	{
		SQL_ReadResult(Query,0,ClassKey,127);
		
		strtok(ClassKey,Garbage,1,Key,63,'|');
		SQL_ReadResult(Query,1,Value,127);
		
		TravTrieSetString(CurTrie,Key,Value);
		SQL_NextRow(Query);
	}
	
	TravTrieSetHCell(CurTrie,"/loaded",1);
	TravTrieGetHCell(CurTrie,"/calls",CallsTrie);
	
	new travTrieIter:Iter = GetTravTrieIterator(CallsTrie),Handler[64],Forward,Return,Temp[64],PluginStr[10],Plugin
	while(MoreTravTrie(Iter))
	{
		ReadTravTrieKey(Iter,Temp,63);
		strtok(Temp,PluginStr,9,Handler,63,'|');
		
		Plugin = str_to_num(PluginStr);
		ReadTravTrieString(Iter,g_Query,4095);
		
		Forward = CreateOneForward(Plugin,Handler,FP_CELL,FP_STRING,FP_STRING)
		if(Forward <= 0 || !ExecuteForward(Forward,Return,_:CurTrie,Data,g_Query))
		{
			UTIL_Error(AMX_ERR_NATIVE,0,"Could not execute %s forward to %d",0,Handler);
			return FAILED
		}
		DestroyForward(Forward);
	}
	
	DestroyTravTrieIterator(Iter);
	TravTrieDestroy(CallsTrie);
	
	if(g_ClassForward <= 0 || !ExecuteForward(g_ClassForward,Return,_:CurTrie,Data))
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Could not execute DRP_ClassLoaded forward",0);
		return FAILED
	}
	
	return PLUGIN_CONTINUE
}
public _DRP_ClassSave(Plugin,Params)
{
	if(Params != 2)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 2, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new TravTrie:ClassNum = TravTrie:get_param_byref(1),Close = get_param(2),travTrieIter:Iter = GetTravTrieIterator(g_ClassArray);
	new TravTrie:CurTrie,TravTrie:PluginTrie,ClassName[64],TrieClass[64],ProcClass[128]
	
	while(MoreTravTrie(Iter))
	{
		ReadTravTrieKey(Iter,TrieClass,63);
		ReadTravTrieCell(Iter,CurTrie);
		
		copy(ClassName,63,TrieClass[containi(TrieClass,"|") + 1]);

		if(CurTrie == ClassNum && !task_exists(_:CurTrie))
		{
			copy(ProcClass[1],126,TrieClass);
			ProcClass[0] = _:CurTrie
			
			new TravTrie:SaveTrie
			TravTrieGetHCell(CurTrie,"/savetrie",SaveTrie);
			
			new travTrieIter:Iter = GetTravTrieIterator(SaveTrie),Handler[64],Temp[128],PluginStr[10],Plugin,Forward,Return
			while(MoreTravTrie(Iter))
			{
				ReadTravTrieKey(Iter,Temp,127);
				ReadTravTrieString(Iter,g_Query,4095);
				
				strtok(Temp,PluginStr,9,Handler,63,'|');
				
				Plugin = str_to_num(PluginStr);
				Forward = CreateOneForward(Plugin,Handler,FP_CELL,FP_STRING,FP_STRING)
				
				if(Forward <= 0 || !ExecuteForward(Forward,Return,CurTrie,ClassName,g_Query))
				{
					UTIL_Error(AMX_ERR_NATIVE,0,"Could not register forward. Function: %s - Plugin: %d",0,Handler,Plugin);
					return FAILED
				}
				DestroyForward(Forward);
			}
			DestroyTravTrieIterator(Iter);
			
			if(Close)
			{
				TravTrieGetHCell(CurTrie,"/plugins",PluginTrie);
				TravTrieDeleteKeyEx(PluginTrie,Plugin);
				
				set_param_byref(1,_:Invalid_TravTrie);
			}
			
			SaveClass(CurTrie,ProcClass[1]);
			
			return SUCCEEDED
		}
	}
	DestroyTravTrieIterator(Iter);
	
	return SUCCEEDED
}
public SaveClass(TravTrie:CurTrie,ProcClass[])
{
	new Saving
	TravTrieGetHCell(CurTrie,"/saving",Saving);
	
	if(Saving)
		return SUCCEEDED
	
	new TravTrie:ChangedTrie,Table[64],ClassName[64]
	TravTrieGetHCell(CurTrie,"/changed",ChangedTrie);
	
	strtok(ProcClass,Table,63,ClassName,63,'|');
	TravTrieSetHCell(CurTrie,"/saving",1);
	
	new Key[128],Data[64],TrieClass[64]
	Data[1] = _:CurTrie
	
	copy(Data[2],60,ProcClass);
	
	new travTrieIter:Iter = GetTravTrieIterator(CurTrie),Changed,ChangedNum
	while(MoreTravTrie(Iter))
	{				
		ReadTravTrieKey(Iter,TrieClass,63);
		ReadTravTrieString(Iter,g_Query,4095);
		
		TravTrieGetCell(ChangedTrie,TrieClass,Changed)
		
		if(TrieClass[0] != '^n' && TrieClass[0] != '/' && Changed)
			ChangedNum++
		
		Changed = 0
	}
	TravTrieSetHCell(CurTrie,"/lastquery",ChangedNum);
	DestroyTravTrieIterator(Iter);
	
	Iter = GetTravTrieIterator(CurTrie);
	while(MoreTravTrie(Iter))
	{
		ReadTravTrieKey(Iter,TrieClass,63);
		ReadTravTrieString(Iter,g_Query,4095);
		
		TravTrieGetCell(ChangedTrie,TrieClass,Changed);
		
		if(TrieClass[0] == '^n' || TrieClass[0] == '/' || !Changed) 
			continue
		
		TravTrieSetCell(ChangedTrie,TrieClass,0);
		
		Changed = 0
		
		copy(Key,127,TrieClass);
		copy(g_Cache,4095,g_Query);
		
		Data[0]++
		
		replace_all(ClassName,127,"'","\'");
		replace_all(Key,127,"'","\'");
		replace_all(g_Cache,4095,"'","\'");
		
		format(g_Query,4095,"INSERT INTO %s VALUES ('%s|%s','%s') ON DUPLICATE KEY UPDATE value='%s'",Table,ClassName,Key,g_Cache,g_Cache)
		UTIL_CleverQuery(g_Plugin,g_SqlHandle,"ClassSaveHandle",g_Query,Data,64);
	}
	DestroyTravTrieIterator(Iter);
	
	new TravTrie:PluginTrie,TravTrie:SaveTrie
	
	TravTrieGetHCell(CurTrie,"/plugins",PluginTrie);
	TravTrieGetHCell(CurTrie,"/savetrie",SaveTrie);
	
	return SUCCEEDED
}
public ClassSaveHandle(FailState,Handle:Query,Error[],Errcode,Data[],DataSize) 
{
	if(FailState == TQUERY_CONNECT_FAILED)
	{
		UTIL_Error(0,1,"Could not connect to SQL database. (Error: %s)",0,Error ? Error : "UNKNOWN");
		return FAILED
	}
	else if(FailState == TQUERY_QUERY_FAILED)
	{
		SQL_QueryError(Query,g_Query,4095);
		return UTIL_Error(0,1,"Query Failed (Error: %s)",0,g_Query);
	}
	if(Errcode)
	{
		UTIL_Error(0,1,"SQL ErrorCode (Error: %s)",0,Error);
		return FAILED
	}
	
	new LastQuery,TravTrie:CurTrie = TravTrie:Data[1]
	TravTrieGetHCell(CurTrie,"/lastquery",LastQuery);
	
	if(Data[0] == LastQuery)
	{
		TravTrieSetHCell(CurTrie,"/saving",0);
	
		new TravTrie:PluginTrie,TravTrie:ChangedTrie,TravTrie:SaveTrie
		TravTrieGetHCell(CurTrie,"/plugins",PluginTrie);
		TravTrieGetHCell(CurTrie,"/changed",ChangedTrie);
		TravTrieGetHCell(CurTrie,"/savetrie",SaveTrie);

		if(!TravTrieSize(PluginTrie) && !g_PluginEnd)
		{
			TravTrieDestroy(PluginTrie);
			TravTrieDestroy(CurTrie);
			TravTrieDestroy(ChangedTrie);
			TravTrieDestroy(SaveTrie);
			
			TravTrieDeleteKey(g_ClassArray,Data[2]);
		}
	}
	
	return PLUGIN_CONTINUE
}
public _DRP_ClassSaveHook(Plugin,Params)
{
	if(Params != 3)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 3, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new TravTrie:CurTrie = TravTrie:get_param(1),Handler[64],Temp[128],TravTrie:SaveTrie
	get_string(2,Handler,63);
	get_string(3,g_Query,4095);
	
	format(Temp,127,"%d|%s",Plugin,Handler);
	
	TravTrieGetHCell(CurTrie,"/savetrie",SaveTrie);
	TravTrieSetString(SaveTrie,Temp,g_Query);
	
	return SUCCEEDED
}
public _DRP_ClassDeleteKey(Plugin,Params)
{
	if(Params != 2)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 2, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new TravTrie:ClassNum = TravTrie:get_param(1),Key[64]
	get_string(2,Key,63);
	
	if(Key[0] == '/' || Key[0] == '^n' || !ClassNum) 
		return FAILED
	
	new travTrieIter:Iter = GetTravTrieIterator(g_ClassArray),Cell,Name[64]
	while(MoreTravTrie(Iter))
	{
		ReadTravTrieKey(Iter,Name,63);
		ReadTravTrieCell(Iter,Cell);
		
		if(Cell == _:ClassNum)			
			break
	}
	DestroyTravTrieIterator(Iter);
	
	format(g_Query,4095,"DELETE FROM %s WHERE classkey='%s|%s'",g_DataTable,Name,Key);
	UTIL_CleverQuery(g_Plugin,g_SqlHandle,"IgnoreHandle",g_Query);
	
	return TravTrieDeleteKey(ClassNum,Key);
}
/*==================================================================================================================================================*/
// UTIL Functions
UTIL_Error(Error,Fatal,const Message[],Plugin,any:...)
{
	vformat(g_Query,4095,Message,5);
	
	if(Plugin)
	{
		new Name[64],Filename[64],Temp[2]
		get_plugin(Plugin,Filename,63,Name,63,Temp,1,Temp,1,Temp,1);
		
		if(Error)
			log_error(Error,"[DRP] [PLUGIN: %s - %s ] %s %s",Name,Filename,g_Query,Fatal ? "(Fatal Error)" : "");
		else
			log_amx("[DRP] [PLUGIN: %s - %s] %s %s",Name,Filename,g_Query,Fatal ? "(Fatal Error)" : "");
	}
	else
	{
		// If no plugin was sent, we automatically assume the core is calling
		if(Error)
			log_error(Error,"[DRP] [PLUGIN: CORE] %s %s",g_Query,Fatal ? "(Fatal Error)" : "");
		else
			log_amx("[DRP] [PLUGIN: CORE] %s %s",g_Query,Fatal ? "(Fatal Error)" : "");
	}
	if(Fatal)
	{
		new Forward = CreateMultiForward("DRP_Error",ET_IGNORE,FP_STRING),Return
		if(Forward <= 0 || !ExecuteForward(Forward,Return,g_Query))
			return SUCCEEDED
		
		DestroyForward(Forward);
		pause("d");
	}
	
	return FAILED
}
UTIL_DRP_Log(Plugin,const Message[])
{
	new PluginName[64],Garbage[1]
	get_plugin(Plugin,Garbage,0,PluginName,63,Garbage,0,Garbage,0,Garbage,0);
	
	replace(PluginName,63,"DRP - ","");
	
	switch(get_pcvar_num(p_Log))
	{
		case 1:
			log_amx("[DRP - %s] %s",PluginName,Message);
		case 2:
		{
			new Date[256]
			get_time("%m-%d-%Y",Date,255);
			
			format(Date,255,"%s/%s.log",g_LogDir,Date);
			log_to_file(Date,"[DRP - %s] %s",PluginName,Message);
		}
		default:
			return FAILED
	}
	return SUCCEEDED
}
UTIL_IsUserAdmin(id)
{
	new StrAccess[JOB_ACCESSES + 1]
	get_pcvar_string(p_AdminAccess,StrAccess,JOB_ACCESSES);
	
	new const Access = DRP_AccessToInt(StrAccess);
	
	if(g_UserAccess[id] & Access)
		return SUCCEEDED
	
	return FAILED
}
UTIL_ValidItemID(ItemID)
{
	if(ItemID <= g_ItemsNum && ItemID > 0)
		return SUCCEEDED
	
	return FAILED
}

UTIL_ValidJobID(JobID)
{
	if(JobID < g_JobNum && JobID >= 0)
		return SUCCEEDED
	
	return FAILED
}
UTIL_ValidProperty(Property)
{
	if(Property >= 0 && Property < g_PropertyNum)
		return SUCCEEDED
	
	return FAILED
}
UTIL_ValidDoor(Door)
{
	if(Door >= 0 && Door < g_DoorNum)
		return SUCCEEDED
	
	return FAILED
}
UTIL_DeleteDoor(Door)
{
	new Targetname[33],InternalName[64],CurArray,NextArray,DoorArray = array_get_int(g_DoorArray,Door);
	array_get_string(DoorArray,2,InternalName,63);
	
	format(g_Query,4095,"DELETE FROM %s WHERE Internalname='%s'",g_DoorsTable,InternalName);
	UTIL_CleverQuery(g_Plugin,g_SqlHandle,"IgnoreHandle",g_Query);
	
	for(new Count = Door;Count < g_DoorNum - 1;Count++)
	{
		NextArray = array_get_int(g_DoorArray,Count + 1);
		array_get_string(NextArray,0,Targetname,32);
		array_get_string(NextArray,2,InternalName,63);
		
		CurArray = array_get_int(g_DoorArray,Count);
		array_set_string(CurArray,0,Targetname);
		
		array_set_int(CurArray,1,array_get_int(NextArray,1));
		array_set_string(CurArray,2,InternalName);
		
		array_set_int(CurArray,3,array_get_int(NextArray,3));
		array_set_int(g_DoorArray,Count,NextArray);
	}
	
	array_destroy(DoorArray);
	array_delete(g_DoorArray,--g_DoorNum);
	
	return SUCCEEDED
}
UTIL_DeleteJob(JobID)
{
	new iPlayers[32],iNum,Index,Jobs[1]
	get_players(iPlayers,iNum);
	
	if(!DRP_FindJobID("Unemployed",Jobs,1))
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Error finding ^"Unemployed^" job.",0);
		return FAILED
	}
	
	new Unemployed = Jobs[0] - 1
	
	for(new Count;Count < iNum;Count++)
	{
		Index = iPlayers[Count]
		if(g_UserJobID[Index] == JobID)
			g_UserJobID[Index] = Unemployed
	}
	
	new Name[33]
	array_get_string(array_get_int(g_JobArray,JobID),1,Name,32);
	
	format(g_Query,4095,"DELETE FROM %s WHERE JobName='%s'",g_JobsTable,Name);
	UTIL_CleverQuery(g_Plugin,g_SqlHandle,"IgnoreHandle",g_Query);
	
	new JobArray = array_get_int(g_JobArray,JobID);
	array_destroy(JobArray);
	array_set_int(g_JobArray,JobID,-1);
	
	return SUCCEEDED
}
UTIL_GetUserItemNum(id,ItemID)
	return array_isfilled(g_UserItemArray[id],ItemID) ? abs(array_get_int(g_UserItemArray[id],ItemID)) : 0

UTIL_GetItemName(ItemID,Name[],Len)
	array_get_string(array_get_int(g_ItemsArray,ItemID),1,Name,Len);

UTIL_PropertyChanged(Property)
	array_set_int(array_get_int(g_PropertyArray,Property),9,1);

UTIL_FindItemID(const ItemName[])
{
	static Name[33]
	for(new Count = 1;Count <= g_ItemsNum;Count++)
	{
		array_get_string(array_get_int(g_ItemsArray,Count),1,Name,32);
		
		if(equali(Name,ItemName))
			return Count
	}
	return -1
}
UTIL_FindJobID(const JobName[])
{
	static Name[33]
	for(new Count = 1;Count <= g_ItemsNum;Count++)
	{
		array_get_string(array_get_int(g_JobArray,Count),1,Name,32);
		
		if(equali(Name,ItemName))
			return Count
	}
	return -1
}
UTIL_SetUserItemNum(id,ItemID,Num)
{
	if(!UTIL_ValidItemID(ItemID))
		return FAILED
	
	Num ? array_set_int(g_UserItemArray[id],ItemID,Num) : array_delete(g_UserItemArray[id],ItemID);
	
	new AuthID[36],ItemName[33]
	get_user_authid(id,AuthID,35);
	
	if(!Num)
	{
		UTIL_GetItemName(ItemID,ItemName,32);
		
		format(g_Query,4095,"DELETE FROM %s WHERE authidname='%s|%s'",g_ItemsTable,AuthID,ItemName);
		UTIL_CleverQuery(g_Plugin,g_SqlHandle,"IgnoreHandle",g_Query);
		
		return FAILED
	}
	SaveUserItems(id);
	return SUCCEEDED
}

UTIL_GetProperty(const Targetname[] = "",EntID = 0)
{
	static PropertyName[64]
	for(new Count,CurArray;Count < g_DoorNum;Count++)
	{
		CurArray = array_get_int(g_DoorArray,Count);
		array_get_string(CurArray,0,PropertyName,63);
		
		if((equali(PropertyName,Targetname) && Targetname[0]) || (EntID && EntID == array_get_int(CurArray,1)))
		{
			array_get_string(CurArray,2,PropertyName,63);
			return UTIL_MatchProperty(PropertyName);
		}
	}
	return -1
}
UTIL_GetDoor(const Targetname[] = "",EntID = 0)
{
	static PropertyTargetname[33]
	for(new Count,CurArray;Count < g_DoorNum;Count++)
	{
		CurArray = array_get_int(g_DoorArray,Count);
		array_get_string(CurArray,0,PropertyTargetname,32)
		
		if((equali(PropertyTargetname,Targetname) && Targetname[0]) || (EntID && EntID == array_get_int(CurArray,1)))
			return Count
	}
	
	return FAILED
}
UTIL_MatchProperty(const InternalName[])
{
	static CurName[64]
	for(new Count;Count < g_PropertyNum;Count++)
	{
		array_get_string(array_get_int(g_PropertyArray,Count),0,CurName,63);
		if(equali(CurName,InternalName))
			return Count
	}
	return -1
}

UTIL_LoadConfigFile(File)
{
	new ConfigFile[128],Left[128],Right[128]
	while(!feof(File))
	{
		fgets(File,ConfigFile,sizeof ConfigFile-1 );
		trim(ConfigFile);
		
		if(ConfigFile[0] == ';' || ConfigFile[0] == '/' && ConfigFile[1] == '/')
			continue
		
		parse(ConfigFile,Left,sizeof Left - 1,Right,sizeof Right - 1)
		remove_quotes(Left)
		trim(Left)
		remove_quotes(Right)
		trim(Right)
		
		if(Left[0] && Right[0])
		{
			if(equal(Left,sql_Host))
				set_cvar_string(sql_Host,Right);
			else if(equal(Left,sql_DB))
				set_cvar_string(sql_DB,Right);
			else if(equal(Left,sql_User))
				set_cvar_string(sql_User,Right);
			else if(equal(Left,sql_Pass))
				set_cvar_string(sql_Pass,Right);
			
			else if(equal(Left,g_CopAccessCvar))
				set_pcvar_string(p_CopAccess,Right);
			else if(equal(Left,g_MedicsAccessCvar))
				set_pcvar_string(p_MedicAccess,Right);
			else if(equal(Left,g_AdminAccessCvar))
				set_pcvar_string(p_AdminAccess,Right);
			
			else if(equal(Left,"DRP_UserTable"))
				copy(g_UserTable,sizeof g_UserTable - 1,Right);
			else if(equal(Left,"DRP_JobsTable"))
				copy(g_JobsTable,sizeof g_JobsTable - 1,Right);
			else if(equal(Left,"DRP_PropertyTable"))
				copy(g_PropertyTable,sizeof g_PropertyTable - 1,Right);
			else if(equal(Left,"DRP_KeysTable"))
				copy(g_KeysTable,sizeof g_KeysTable - 1,Right);
			else if(equal(Left,"DRP_DoorsTable"))
				copy(g_DoorsTable,sizeof g_DoorsTable - 1,Right);
			else if(equal(Left,"DRP_ItemsTable"))
				copy(g_ItemsTable,sizeof g_ItemsTable - 1,Right);
			else if(equal(Left,"DRP_DataTable"))
				copy(g_DataTable,sizeof g_DataTable - 1,Right);
		}
	}
	fclose(File);
}
UTIL_AddHudItem(id,Channel,const Message[],Refresh)
{
	if(id == -1)
	{
		new iPlayers[32],iNum
		get_players(iPlayers,iNum);
		for(new Count;Count < iNum;Count++)
			AddItem(iPlayers[Count],Channel,Message,Refresh);
	}
	else
		AddItem(id,Channel,Message,Refresh);
}
AddItem(id,Channel,const Message[],Refresh)
{
	TravTrieSetCell(g_HudArray[id][Channel],Message,Channel);
	if(Refresh)
		RenderHud(id,Channel);
}
public IgnoreHandle(FailState,Handle:Query,const Error[],Errcode,const Data[],DataSize) 
{
	if(FailState == TQUERY_CONNECT_FAILED)
		return log_amx("[DRP-CORE] [SQL ERROR] Unable to connect to SQL Database. (Error: %s)",Error ? Error : "UNKNOWN");
	
	else if(FailState == TQUERY_QUERY_FAILED)
	{
		SQL_QueryError(Query,g_Query,4095);
		return log_amx("[DRP-CORE] [SQL ERROR] Query Failed. (Error: %s)",g_Query);
	}
	if(Errcode)
		return log_amx("[DRP-CORE] [SQL ERROR] %s",Error);
	
	return PLUGIN_CONTINUE
}
UTIL_CleverQuery(PluginGiven,Handle:Tuple,Handler[],QueryS[],Data[] = "",Len = 0)
	return _DRP_CleverQuery(PluginGiven,Tuple,Handler,QueryS,Data,Len) ? SQL_ThreadQuery(Tuple,Handler,QueryS,Data,Len) : PLUGIN_HANDLED

_CallEvent(const Name[],const Data[],const Length)
{
	new travTrieIter:Iter = GetTravTrieIterator(g_EventTrie),Event[128],Key[128],Plugin,PluginStr[12],Handler[128],Forward,Return//,CurArray
	while(MoreTravTrie(Iter))
	{
		ReadTravTrieKey(Iter,Key,127);
		ReadTravTrieString(Iter,Event,127);
		
		if(!equal(Event,Name))
			continue
		
		strtok(Key,PluginStr,11,Handler,127,'|');
		
		Plugin = str_to_num(PluginStr);
		Forward = CreateOneForward(Plugin,Handler,FP_STRING,FP_ARRAY,FP_CELL);
		
		if(Forward <= 0)
		{
			log_amx("[DRP] [_CALLEVENT] Unable to register forward. Function: %s - Plugin: %d",Handler,Plugin);
			return FAILED
		}
		
		new CurArray = PrepareArray(Data,Length);
	
		if(!ExecuteForward(Forward,Return,Event,CurArray,Length))
		{
			log_amx("[DRP] [_CALLEVENT] Could not execute forward. Function: %s - Plugin: %d",Handler,Plugin);
			return FAILED
		}
		
		DestroyForward(Forward);
		
		if(Return)
			return Return
	}
	DestroyTravTrieIterator(Iter);
	
	new CurArray = PrepareArray(Data,Length);
	if(!ExecuteForward(g_EventForward,Return,Name,CurArray,Length))
	{
		log_amx("[DRP] [_CALLEVENT] Could not execute Global Event (g_EventForward) forward.");
		return FAILED
	}
	
	return Return
}
_DRP_CleverQuery(Plugin,Handle:Tuple,Handler[],QueryS[],Data[] = "",Len = 0)
{
	if(!get_playersnum() || g_PluginEnd)
	{
		new Error[512],ErrorCode,Handle:SqlConnection = SQL_Connect(Tuple,ErrorCode,Error,511);
		if(SqlConnection == Empty_Handle)
		{
			CleverQueryFunction(Plugin,Handler,TQUERY_CONNECT_FAILED,Empty_Handle,Error,ErrorCode,Data,Len,0.0);
			return PLUGIN_CONTINUE
		}
		
		new Handle:Query = SQL_PrepareQuery(SqlConnection,QueryS);
		
		if(!SQL_Execute(Query))
		{
			ErrorCode = SQL_QueryError(Query,Error,511);
			CleverQueryFunction(Plugin,Handler,TQUERY_QUERY_FAILED,Query,Error,ErrorCode,Data,Len,0.0);
			return PLUGIN_CONTINUE
		}
		
		CleverQueryFunction(Plugin,Handler,TQUERY_SUCCESS,Query,"",0,Data,Len,0.0);
		
		SQL_FreeHandle(Query);
		SQL_FreeHandle(SqlConnection);
		
		return PLUGIN_CONTINUE
	}
	
	return PLUGIN_HANDLED
}
CleverQueryFunction(PluginGiven,const HandlerS[],FailState,Handle:Query,const Error[],Errcode,const PassData[],Len,Float:HangTime)
{
	new Forward = CreateOneForward(PluginGiven,HandlerS,FP_CELL,FP_CELL,FP_STRING,FP_CELL,FP_ARRAY,FP_CELL,FP_CELL),CurArray = Len ? PrepareArray(PassData,Len) : 0,Return
	if(Forward <= 0|| !ExecuteForward(Forward,Return,FailState,Query,Error,Errcode,CurArray,Len,HangTime))
	{
		log_amx("[DRP CORE] [ERROR] Could not execute forward to %d: %s",PluginGiven,HandlerS);
		return
	}
	DestroyForward(Forward);
}
/*==================================================================================================================================================*/
public fw_ClientKill(const id)
	{ client_print(id,print_console,"[AMXX] Sorry, the kill command is disabled."); return FMRES_SUPERCEDE; }
public fw_SysError(const Error[])
	{ plugin_end(); UTIL_Error(0,0,"Forward SysError. (%s)",0,Error); }

public plugin_end()
{
	g_PluginEnd = 1
	
	SaveData();

	new const Players = get_maxplayers();
	for(new Count,Count2;Count <= Players;Count++)	
	{
		array_destroy(g_UserItemArray[Count]);
		TravTrieDestroy(g_MenuArray[Count]);
		
		for(Count2 = 0;Count2 < HUD_NUM;Count2++)
			TravTrieDestroy(g_HudArray[Count][Count2])
	}
	
	new Num
	for(new Count;Count < g_CommandNum;Count++)
	{
		Num = array_get_int(g_CommandArray,Count + 1);
		array_destroy(Num);
	}
	for(new Count;Count < g_JobNum;Count++)
	{
		Num = array_get_int(g_JobArray,Count);
		array_destroy(Num);
	}
	for(new Count;Count < g_PropertyNum;Count++)
	{
		Num = array_get_int(g_PropertyArray,Count);
		array_destroy(Num);
	}
	for(new Count;Count < g_DoorNum;Count++)
	{
		Num = array_get_int(g_DoorArray,Count);
		array_destroy(Num);
	}
	
	// Arrays
	array_destroy(g_JobArray);
	array_destroy(g_CommandArray);
	array_destroy(g_PropertyArray);
	array_destroy(g_DoorArray);
	array_destroy(g_ItemsArray);
	
	TravTrieDestroy(g_EventTrie);
	
	// Forwards
	DestroyForward(g_HudForward);
	DestroyForward(g_ClassForward);
	DestroyForward(g_EventForward);
	
	// SQL
	if(g_SqlHandle)
		SQL_FreeHandle(g_SqlHandle);
}

/*==================================================================================================================================================*/
// Saving
public SaveData()
{
	new iPlayers[32],iNum
	get_players(iPlayers,iNum);
	
	for(new Count;Count < iNum;Count++)
		if(g_GotInfo[iPlayers[Count]] >= STD_USER_QUERIES)
			SaveUserData(iPlayers[Count],0);
		
	new Message[128],InternalName[64],ExternalName[64],OwnerName[33],OwnerAuthid[36],Price,Locked,AccessStr[JOB_ACCESSES + 1],Access,Profit,CurArray,Targetname[33],EntID,Changed
	
	for(new Count;Count < g_PropertyNum;Count++)
	{		
		CurArray = array_get_int(g_PropertyArray,Count),Changed = array_get_int(CurArray,9);
		if(!Changed)
			continue
		
		array_get_string(CurArray,0,InternalName,63);
		array_get_string(CurArray,1,ExternalName,63);
		array_get_string(CurArray,2,OwnerName,32);
		array_get_string(CurArray,3,OwnerAuthid,32);
		array_get_string(CurArray,10,Message,127);
		
		Price = array_get_int(CurArray,4);
		Locked = array_get_int(CurArray,5);
		Access = array_get_int(CurArray,6);
		Profit = array_get_int(CurArray,7);
		
		replace_all(ExternalName,32,"'","\'");
		replace_all(OwnerName,32,"'","\'");
		
		DRP_IntToAccess(Access,AccessStr,JOB_ACCESSES);
		
		format(g_Query,4095,"INSERT INTO %s VALUES ('%s','%s','%s','%s','%d','%d','%s','%d','%s') ON DUPLICATE KEY UPDATE externalname='%s',ownername='%s',ownerauth='%s',price='%d',locked='%d',access='%s',profit='%d',custommessage='%s'",g_PropertyTable,
		InternalName,ExternalName,OwnerName,OwnerAuthid,Price,Locked,AccessStr,Profit,Message,
		ExternalName,OwnerName,OwnerAuthid,Price,Locked,AccessStr,Profit,Message);
		
		UTIL_CleverQuery(g_Plugin,g_SqlHandle,"IgnoreHandle",g_Query);
	}
	
	for(new Count;Count < g_DoorNum;Count++)
	{
		CurArray = array_get_int(g_DoorArray,Count),Changed = array_get_int(CurArray,3);
		if(!Changed)
			continue
		
		array_get_string(CurArray,0,Targetname,32);
		EntID = array_get_int(CurArray,1);
		array_get_string(CurArray,2,InternalName,32);
		
		EntID ? 
			format(Targetname,32,"e|%d",EntID) : format(Targetname,32,"t|%s",Targetname);
		
		format(g_Query,4095,"INSERT INTO %s VALUES ('%s','%s') ON DUPLICATE KEY UPDATE internalname='%s'",g_DoorsTable,Targetname,InternalName,InternalName);
		UTIL_CleverQuery(g_Plugin,g_SqlHandle,"IgnoreHandle",g_Query);
	}
	
	format(Message,127,"%d %d %d %d %d %d",g_WorldTime[1],g_WorldTime[2],
	g_WorldTime[4],g_WorldTime[5],
	g_WorldTime[6],g_WorldTime[3]);
	
	format(g_Query,4095,"UPDATE `time` SET `CurrentTime`='%s'",Message);
	UTIL_CleverQuery(g_Plugin,g_SqlHandle,"IgnoreHandle",g_Query);
}
SaveUserItems(id)
{
	new const Size = array_size(g_UserItemArray[id]) + 1
	new ItemID,Num
	
	if(Size < 2)
		return
	
	new AuthID[36],ItemName[33]
	get_user_authid(id,AuthID,35);
	
	for(new Count = 1,Success = 1;Count < Size && Success;Count++)
	{
		ItemID = array_get_nth(g_UserItemArray[id],Count,_,Success);
		if(ItemID < 1 || !Success)
			continue
		
		Num = array_get_int(g_UserItemArray[id],ItemID);
		if(Num < 1)
			continue
		
		UTIL_GetItemName(ItemID,ItemName,32);
		
		format(g_Query,4095,"INSERT INTO %s VALUES('%s|%s','%d') ON duplicate KEY UPDATE num='%d'",g_ItemsTable,AuthID,ItemName,abs(Num),abs(Num));
		UTIL_CleverQuery(g_Plugin,g_SqlHandle,"IgnoreHandle",g_Query);
		
		Num = -abs(Num);
	}
	if(g_PluginEnd)
		array_destroy(g_UserItemArray[id]);
}
public SaveUserData(id,Disconnected)
{
	new Data[2]
	Data[0] = id
	Data[1] = Disconnected
	
	SaveUserItems(id);
	get_user_authid(id,g_UserAuthID[id],35);
	
	if(containi(g_UserAuthID[id],"PENDING") != -1 || containi(g_UserAuthID[id],"LAN") != -1 || equali(g_UserAuthID[id],"STEAM_0:0") || containi(g_UserAuthID[id],"UNKNOWN") != -1)
		return
	
	new Access[27],JobRight[27],JobName[33]
	DRP_IntToAccess(g_AccessCache[id],Access,26);
	DRP_IntToAccess(g_UserJobRight[id],JobRight,26);
	array_get_string(array_get_int(g_JobArray,g_UserJobID[id]),1,JobName,32);
	
	format(g_Query,4095,"UPDATE %s SET `BankMoney`=%d ,`WalletMoney`=%d ,`JobName`='%s' ,`Hunger`=%d ,`Access`='%s' ,`JobRight`='%s', `PlayTime`=%d WHERE SteamID='%s'",g_UserTable,g_UserBank[id],g_UserWallet[id],JobName,g_UserHunger[id],Access,JobRight,g_UserTime[id] + get_user_time(id),g_UserAuthID[id]);
	
	g_Saving[id] = true
	UTIL_CleverQuery(g_Plugin,g_SqlHandle,"SaveUserDataHandle",g_Query,Data,2);
}
public SaveUserDataHandle(FailState,Handle:Query,Error[],Errcode,Data[],DataSize) 
{
	if(FailState != TQUERY_SUCCESS || Errcode)
		return UTIL_Error(0,1,"SQL Error (Error: %s)",0,Error ? Error : "UNKNOWN");
	
	new const id = Data[0]
	g_Saving[id] = false
	
	if(g_PluginEnd)
		return PLUGIN_CONTINUE
	
	new AuthID[36]
	get_user_authid(id,AuthID,35);
	
	if(Data[1] || !is_user_connected(id) || !equali(g_UserAuthID[id],AuthID))
		return _ClearSettings(id);
	
	return PLUGIN_CONTINUE
}
_ClearSettings(id)
{
	for(new Count,CurArray;Count < g_PropertyNum;Count++)
	{
		CurArray = array_get_int(g_PropertyArray,Count);
		array_set_int(CurArray,8,array_get_int(CurArray,8) & ~(1<<(id - 1)));
	}
	
	g_Saving[id] = false
	g_Display[id] = 1
	g_BadJob[id] = false
	
	g_UserAccess[id] = 0
	g_AccessCache[id] = 0
	
	g_UserAuthID[id][0] = 0
	
	array_clear(g_UserItemArray[id]);
	
	for(new Count = 0;Count < HUD_NUM;Count++)
		TravTrieClear(g_HudArray[id][Count]);
	
	return PLUGIN_CONTINUE
}
_CreateItemDrop(id = 0,Float:Origin[3] = {0.0,0.0,0.0},Num,const ItemName[],bool:SQLSave = false,SQLKey = 0)
{	
	new Ent = engfunc(EngFunc_CreateNamedEntity,engfunc(EngFunc_AllocString,"info_target"))
	if(!pev_valid(Ent))
		return FAILED
	
	set_pev(Ent,pev_classname,g_szItem);
	set_pev(Ent,pev_solid,SOLID_TRIGGER);
	set_pev(Ent,pev_movetype,MOVETYPE_TOSS);
	
	engfunc(EngFunc_SetModel,Ent,g_ItemMdl);
	engfunc(EngFunc_SetSize,Ent,Float:{-2.5,-2.5,-2.5},Float:{2.5,2.5,2.5});
	engfunc(EngFunc_SetOrigin,Ent,Origin);
	
	if(id)
	{
		velocity_by_aim(id,400,Origin);
		set_pev(Ent,pev_velocity,Origin);
	}
	
	set_pev(Ent,pev_noise,ItemName);
	set_pev(Ent,pev_iuser2,Num);
	
	if(SQLKey)
		set_pev(Ent,pev_iuser3,SQLKey);
	
	if(SQLSave)
	{
		new iOrigin[3]
		pev(Ent,pev_origin,Origin);
		
		FVecIVec(Origin,iOrigin);
		
		format(g_Query,4095,"INSERT INTO `ItemDrops` (ItemName,Num,X,Y,Z) VALUES('%s','%d','%d','%d','%d')",ItemName,Num,iOrigin[0],iOrigin[1],iOrigin[2]);
		UTIL_CleverQuery(g_Plugin,g_SqlHandle,"IgnoreHandle",g_Query);
	}
	
	return SUCCEEDED
}
_CallNPC(const id,const Ent)
{
	new Plugin = pev(Ent,pev_iuser3),Handler[32],Data[2]
	pev(Ent,pev_noise,Handler,31);
	
	Data[0] = id
	Data[1] = Ent
	
	if(_CallEvent("NPC_Use",Data,2))
		return 1
	
	NPCUse(Handler,Plugin,id,Ent);
	return 1
}