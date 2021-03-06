/*
* DRPCore.sma
* -------------------------------------
* Author(s):
* Hawk - ARP
* Drak - DRP (Based off of ARP)
* -------------------------------------
* NOTE:
* The data layer (DRP_Class* Functions) are commented out
* I'm not going to use it.
* Untill Hawk maybe fixes it, haha
*/
#pragma dynamic 32768

//#define log_amx(%1,%2) DRP_Log(%1,%2)

#include <amxmodx>
#include <amxmisc>

#include <engine>
#include <fakemeta>

#include <sqlx>

#include <DRP/DRPCore>
#include <TSXWeapons>
#include <hamsandwich>

#define STD_USER_QUERIES 3

new const VERSION[] = "0.1a BETA"
new const g_MonthDays[12] = {31,28,31,30,31,30,31,31,30,31,30,31};

// SQL Stuff
new Handle:g_SqlHandle
new g_Query[4096]

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
new p_ItemsPerPage
new p_Log
new p_Hostname
new p_Welcome[2]
new p_FLName
new p_FallingDamage
new p_LogtoAdmins

new TravTrie:g_Fix

// Arrays
new Array:g_CommandArray
new g_CommandNum
new Array:g_JobArray
new g_JobNum
new Array:g_ItemsArray
new g_ItemsNum
new Array:g_PropertyArray
new g_PropertyNum
new Array:g_DoorArray
new g_DoorNum

new TravTrie:g_EventTrie
new TravTrie:g_MenuArray[33]

new g_MenuAccepting[33]
new g_Menu[256]

new g_CurItem[33]
new g_ItemShow[33]
new g_CurProp[33]

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

// User password is optional
// I use it for logging into the website to view there information
new g_UserPass[33][33]

new Float:g_ConsoleTimeout[33]
new Float:g_DoorBellTime[33]

// [0] = WeaponID
// [1] = Clip
// [2] = Ammo
// [3] = Mode
// [4] = Extra
new g_UserWpnID[33][5]

new gmsgTSFade
new gmsgWeaponInfo

new TravTrie:g_UserItemArray[33]

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

new const g_CVarBreakables[] = "DRP_GodBreakables"
new const g_CVarDoors[] = "DRP_GodDoors"
new const g_DoorBellSound[] = "OZDRP/doorbell4.wav"

// Player Error Checking
new g_GotInfo[33]
new bool:g_Saving[33] = false
new bool:g_Joined[33] = false
new bool:g_BadJob[33] = false
new g_Display[33] = {1,...}

// Name Stuff
new bool:g_NameLoad[33]
new g_NameMenu
new const g_StartingName[] = "John Doe"

new g_PropMenu

// Native Forwards
new g_HudForward
new g_EventForward

// Entity
new const g_FuncDoor[] = "func_door"

// [0] = Seconds
// [1] = Minutes
// [2] = Hours
// [3] = AM/PM
// [4] = Month
// [5] = Month Day
// [6] = Year
new g_WorldTime[7]

// Used for setting ammo
new tsweaponoffset[37];

new g_HardAccess[5]

#define p_MedicAccess g_HardAccess[0]
#define p_AdminAccess g_HardAccess[1]
#define p_CopAccess g_HardAccess[2]
#define p_VIPAccess g_HardAccess[3]
#define p_OtherAccess g_HardAccess[4]

// Show debug messages
//#define DEBUG

#if defined DEBUG
new g_Querys
#endif

new g_MaxPlayers

// DO NOT EDIT ANYTHING BELOW THIS LINE
// UNLESS YOU KNOW WHAT YOU'RE DOING
public plugin_precache()
{	
	g_Plugin = register_plugin("DRP Core",VERSION,"Drak");
	g_MaxPlayers = get_maxplayers();
	
	// CVars 
	p_StartMoney = register_cvar("DRP_StartBankCash","100");
	
	register_cvar(g_CVarDoors,"0"); 
	register_cvar(g_CVarBreakables,"0");
	
	p_ItemsPerPage = register_cvar("DRP_ItemsPerPage","30");
	p_FLName = register_cvar("DRP_FirstAndLastName","1");
	p_Log = register_cvar("DRP_LogType","0");
	p_FallingDamage = register_cvar("DRP_FallingDamage","1");
	p_LogtoAdmins = register_cvar("DRP_LogToAdmins","1");
	
	p_Hostname = get_cvar_pointer("hostname");
	
	p_Welcome[0] = register_cvar("DRP_Welcome_Msg1","Welcome #name# to #hostname#");
	p_Welcome[1] = register_cvar("DRP_Welcome_Msg2","Enjoy your stay");
	
	register_cvar(sql_Host,"",FCVAR_PROTECTED);
	register_cvar(sql_DB,"",FCVAR_PROTECTED);
	register_cvar(sql_Pass,"",FCVAR_PROTECTED);
	register_cvar(sql_User,"",FCVAR_PROTECTED);
	
	register_clcmd("drp_testfunc","CmdTest");
	
	// Access
	g_HardAccess[0] = register_cvar(g_MedicsAccessCvar,"b"); // Access Letter for Medics
	g_HardAccess[1] = register_cvar(g_AdminAccessCvar,"z"); // Access Letter for DRP admins. (Rights to set job/create money, etc)
	g_HardAccess[2] = register_cvar(g_CopAccessCvar,"a");
	g_HardAccess[3] = register_cvar(g_VIPAccessCvar,"c");
	g_HardAccess[4] = register_cvar(g_OtherAccessCvar,"d");
	
	new MapName[33]
	for(new Count;Count < HUD_NUM;Count++)
	{
		formatex(MapName,32,"DRP_HUD%d_X",Count + 1);
		p_Hud[Count][X] = register_cvar(MapName,"");
		
		formatex(MapName,32,"DRP_HUD%d_Y",Count + 1);
		p_Hud[Count][Y] = register_cvar(MapName,"");
		
		formatex(MapName,32,"DRP_HUD%d_R",Count + 1);
		p_Hud[Count][R] = register_cvar(MapName,"");
		
		formatex(MapName,32,"DRP_HUD%d_G",Count + 1);
		p_Hud[Count][G] = register_cvar(MapName,"");
		
		formatex(MapName,32,"DRP_HUD%d_B",Count + 1);
		p_Hud[Count][B] = register_cvar(MapName,"");
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
	
	precache_sound(g_DoorBellSound);
	
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
	
	new ConfigFile[128]
	get_mapname(MapName,32);
	
	get_localinfo("amxx_configsdir",ConfigFile,127);
	format(g_ConfigDir,127,"%s/DRP",ConfigFile);
	
	if(!dir_exists(g_ConfigDir))
	{
		if(mkdir(g_ConfigDir) != 0)
		{
			UTIL_Error(0,1,"Unable to create Core Dir (Folder). (%s)",0,g_ConfigDir);
			return
		}
	}
	
	format(g_ConfigDir,127,"%s/%s",g_ConfigDir,MapName);
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
	g_CommandArray = ArrayCreate(_,128);
	g_JobArray = ArrayCreate(_,128);
	g_ItemsArray = ArrayCreate(_,128);
	g_PropertyArray = ArrayCreate(_,128);
	g_DoorArray = ArrayCreate(_,128);
	g_EventTrie = TravTrieCreate();
	
	// HACK HACK:
	// Because of how the ItemID's work - we have to push 1 value into the array
	// So we start from 1 - so yeah.. just.. keep this
	ArrayPushCell(g_ItemsArray,0);
	
	// TODO: Use a newer TravTrie
	// Or chnage to trie
	for(new Count,Count2;Count <= g_MaxPlayers;Count++)
	{
		g_UserItemArray[Count] = TravTrieCreate();
		g_MenuArray[Count] = TravTrieCreate();
		
		for(Count2 = 0;Count2 < HUD_NUM;Count2++)
			g_HudArray[Count][Count2] = TravTrieCreate();
	}
	
	new Forward = CreateMultiForward("DRP_RegisterItems",ET_IGNORE),Return
	if(Forward <= 0 || !ExecuteForward(Forward,Return)) 
		UTIL_Error(0,1,"Could not execute ^"DRP_RegisterItems^" forward.",0);
	
	DestroyForward(Forward);
	
	// Forwards
	register_forward(FM_PlayerPreThink,"forward_PreThink");
	register_forward(FM_Touch,"forward_Touch");
	register_forward(FM_SetClientKeyValue,"fw_SetKeyValue"); // Used for catching player names
	register_forward(FM_Sys_Error,"fw_SysError");
	
	// Native Forwards
	g_HudForward = CreateMultiForward("DRP_HudDisplay",ET_IGNORE,FP_CELL,FP_CELL);
	g_EventForward = CreateMultiForward("DRP_Event",ET_STOP2,FP_STRING,FP_ARRAY,FP_CELL);
	
	LoadHelpFiles();
	SQLInit();
	
	_TSWeaponOffsets();
}

public plugin_init()
{
	register_cvar("DRP_Version",VERSION,FCVAR_SERVER);
	
	// Old HarbuRP Commands
	register_clcmd("amx_joblist","CmdJobList"); // REMOVE ME
	register_clcmd("amx_itemlist","CmdItemList"); // REMOVE ME
	
	DRP_RegisterCmd("drp_joblist","CmdJobList","Lists all the jobs");
	DRP_RegisterCmd("drp_itemlist","CmdItemList","List all the items");
	DRP_RegisterCmd("drp_help","CmdHelp","Shows a list of commands you can use");
	
	DRP_RegisterCmd("say /buy","CmdBuy","Allows you to activate (use) the NPC/Property you're facing");
	DRP_RegisterCmd("say /items","CmdItems","Opens your inventory");
	DRP_RegisterCmd("say /inventory","CmdItems","Opens your inventory")
	
	DRP_RegisterCmd("say /menu","CmdMenu","Opens a Quick-Access menu");
	DRP_RegisterCmd("say /iteminfo","CmdItemInfo","Allows you to view info on the item last shown to you");
	DRP_RegisterCmd("say /propertyinfo","CmdPropertyInfo","Displays information about your property");
	
	#if defined DEBUG
	DRP_RegisterCmd("drp_querynum","CmdQueryNum","Returns an Est. Amount of Queries the core has called.");
	#endif
	
	register_srvcmd("DRP_DumpInfo","CmdDump");
	
	// Menus
	register_menucmd(register_menuid(g_ItemsOptions),g_Keys,"ItemsOptions");
	register_menucmd(register_menuid(g_ItemsDrop),g_Keys,"ItemsDrop");
	register_menucmd(register_menuid(g_ItemsGive),g_Keys,"ItemsGive");
	
	// Ham is good too
	RegisterHam(Ham_TakeDamage,"player","EventTakeDamage");
	
	// Name Menu
	g_NameMenu = menu_create("Name Save","_HandleName");
	menu_additem(g_NameMenu,"Yes");
	menu_additem(g_NameMenu,"No");
	menu_addtext(g_NameMenu,"^nWould you like DRP to save your name^nso its the same each connect?",0);
	
	g_PropMenu = menu_create("","_HandleProperty");
	menu_additem(g_PropMenu,"Use Door");
	menu_additem(g_PropMenu,"View Property Info");
	menu_additem(g_PropMenu,"View All My Property");
	
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
	new Temp,Ent
	Temp = get_cvar_num(g_CVarDoors);
	if(Temp)
	{	
		while(( Ent = engfunc(EngFunc_FindEntityByString,Ent,"classname","func_door_rotating")) != 0)
			set_pev(Ent,pev_takedamage,0.0);
		
		Ent = 0
		while(( Ent = engfunc(EngFunc_FindEntityByString,Ent,"classname",g_FuncDoor)) != 0)
			set_pev(Ent,pev_takedamage,0.0);
	}
	Temp = get_cvar_num(g_CVarBreakables);
	if(Temp)
	{
		Ent = 0
		if(Temp == 2)
		{
			// God every window - besides the one's with the targetname of "DRPNoGod"
			while(( Ent = engfunc(EngFunc_FindEntityByString,Ent,"classname","func_breakable")) != 0)
			{
				pev(Ent,pev_targetname,ConfigsDir,127);
				
				if(equali(ConfigsDir,"DRPNoGod"))
					continue
				
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
	gmsgWeaponInfo = get_user_msgid("WeaponInfo");
	
	// Tasks
	set_task(1.0,"ShowHud",_,_,_,"b");
	set_task(30.0,"SaveData_Forward",_,_,_,"b");
	
	// Tips
	DRP_RegToolTip("ItemUse","Item_Use.txt");
	
	// --
	if(!g_PluginEnd)
		server_print("^n[DRP] Reached PluginInit. (If no errors have occured - it's safe to say DRP is running O.K.)^n");
}
public CmdDump(id)
{
	// Just incase
	if(id > 0)
		return 0
	
	new Temp[256],Date[26]
	get_time("%m-%d-%Y",Date,25);
	
	formatex(Temp,255,"%s/DRPDump-%s.log",g_ConfigDir,Date);
	
	if(file_exists(Temp))
		delete_file(Temp);
	
	new pFile = fopen(Temp,"w+");
	if(!pFile)
		return server_print("[DRP] Unable to open / write dump file (%s)",Temp);
	
	fclose(pFile);
	return server_print("[DRP] Dump Successful.");
}

#if defined DEBUG
public CmdQueryNum(id,level,cid)
{
	if(!DRP_CmdAccess(id,cid,1))
		return PLUGIN_HANDLED
	
	client_print(id,print_console,"[DRP] Estimated Query Num: %d",g_Querys);
	return PLUGIN_HANDLED
}
#endif

stock DRP_TS_GetUserSlots(const id)
{
	if(!id)
		return FAILED
	
	return get_pdata_int(id,333);
}

stock DRP_TS_SetUserSlots(const id,const Slots)
{
	if(!id || Slots < 0 || Slots > 100)
		return FAILED
	
	set_pdata_int(id,333,Slots);
	set_pdata_int(id,334,Slots);
	
	// Update HUD
	message_begin(MSG_ONE_UNRELIABLE,get_user_msgid("TSSpace"),_,id);
	write_byte(Slots);
	message_end();
	
	return SUCCEEDED
}

#define TE_FIREFIELD                123      // Makes a field of fire
// write_byte(TE_FIREFIELD)
// write_coord(origin)
// write_short(radius) (fire is made in a square around origin. -radius, -radius to radius, radius)
// write_short(modelindex)
// write_byte(count)
// write_byte(flags)
// write_byte(duration (in seconds) * 10) (will be randomized a bit)
//
// to keep network traffic low, this message has associated flags that fit into a byte:
#define TEFIRE_FLAG_ALLFLOAT        1        // All sprites will drift upwards as they animate
#define TEFIRE_FLAG_SOMEFLOAT       2        // Some of the sprites will drift upwards. (50% chance)
#define TEFIRE_FLAG_LOOP            4        // If set, sprite plays at 15 fps, otherwise plays at whatever rate stretches the animation over the sprite's duration.
#define TEFIRE_FLAG_ALPHA           8        // If set, sprite is rendered alpha blended at 50% else, opaque
#define TEFIRE_FLAG_PLANAR          16       // If set, all fire sprites have same initial Z instead of randomly filling a cube. 
new gOrigin[3]
public CmdTest(id)
{
	new ent = create_entity("info_target");
	if(ent)
	{
		pev(id,pev_origin,gOrigin);
		
		engfunc(EngFunc_SetOrigin,ent,gOrigin);
		set_pev(ent,pev_classname,"derp");
		engfunc(EngFunc_SetModel,ent,"models/OZDRP/p_drp_moneybag2.mdl");
		set_pev(ent,pev_movetype,MOVETYPE_FOLLOW);
		set_pev(ent,pev_solid,SOLID_BBOX);
		set_pev(ent,pev_aiment,id);
		
		server_print("dicks");
	}
	
	/*
	L 12/06/2010 - 21:28:57: MessageBegin (PwUp "110") (Destination "One<1>") (Args "2") (Entity "1") (Classname "player") (Netname "Drak") (Origin "0.000000 0.000000 0.000000")
	L 12/06/2010 - 21:28:57: Arg 1 (Short "1")
	L 12/06/2010 - 21:28:57: Arg 2 (Byte "3")
	L 12/06/2010 - 21:28:57: MessageEnd (PwUp "110") - Message Num: 33
	*/
	/*
	2/06/2010 - 21:28:54: MessageBegin (TSSlowMo "125") (Destination "One<1>") (Args "1") (Entity "1") (Classname "player") (Netname "Drak") (Origin "0.000000 0.000000 0.000000")
	L 12/06/2010 - 21:28:54: Arg 1 (Coord "22.500000")
	L 12/06/2010 - 21:28:54: MessageEnd (TSSlowMo "125") - Message Num: 6
	L 12/06/2010 - 21:28:54: MessageBegin (TSBTime "118") (Destination "One<1>") (Args "1") (Entity "1") (Classname "player") (Netname "Drak") (Origin "0.000000 0.000000 0.000000")
	L 12/06/2010 - 21:28:54: Arg 1 (Byte "1")
	L 12/06/2010 - 21:28:54: MessageEnd (TSBTime "118") - Message Num: 7
	L 12/06/2010 - 21:28:54: MessageBegin (23 "23") (Destination "PAS<5>") (Args "4") (Entity "<NULL>") (Classname "<NULL>") (Netname "<NULL>") (Origin "-244.000000 -1736.000000 211.000000")
	L 12/06/2010 - 21:28:54: Arg 1 (Byte "105")
	L 12/06/2010 - 21:28:54: Arg 2 (Short "757")
	L 12/06/2010 - 21:28:54: Arg 3 (Short "332")
	L 12/06/2010 - 21:28:54: Arg 4 (Byte "4")
	L 12/06/2010 - 21:28:54: MessageEnd (23 "23") - Message Num: 8
	*/
	/*
	L 09/11/2010 - 04:28:00: MessageBegin (Objective "114") (Destination "One<1>") (Args "5") (Entity "1") (Classname "player") (Netname "sprayer") (Origin "0.000000 0.000000 0.000000")
	L 09/11/2010 - 04:28:00: Arg 1 (Coord "1664.000000")
	L 09/11/2010 - 04:28:00: Arg 2 (Coord "-688.000000")
	L 09/11/2010 - 04:28:00: Arg 3 (Coord "29.780001")
	L 09/11/2010 - 04:28:00: Arg 4 (Byte "0")
	L 09/11/2010 - 04:28:00: Arg 5 (String "Defuse")
	L 09/11/2010 - 04:28:00: MessageEnd (Objective "114") - Message Num: 33
	*/
	
	
	/*
	L 09/11/2010 - 04:28:06: MessageEnd (ResetHUD "79") - Message Num: 45
	L 09/11/2010 - 04:28:06: MessageBegin (RoundTime "113") (Destination "One<1>") (Args "2") (Entity "1") (Classname "player") (Netname "sprayer") (Origin "0.000000 0.000000 0.000000")
	L 09/11/2010 - 04:28:06: Arg 1 (Byte "173")
	L 09/11/2010 - 04:28:06: Arg 2 (Byte "0")
	L 09/11/2010 - 04:28:06: MessageEnd (RoundTime "113") - Message Num: 46
	*/
	/*
	* L 09/11/2010 - 04:28:47: MessageBegin (TeamScore "85") (Destination "All<2>") (Args "3") (Entity "<NULL>") (Classname "<NULL>") (Netname "<NULL>") (Origin "0.000000 0.000000 0.000000")
	L 09/11/2010 - 04:28:47: Arg 1 (String "Mercenary")
	L 09/11/2010 - 04:28:47: Arg 2 (Short "0")
	L 09/11/2010 - 04:28:47: Arg 3 (Short "0")
	L 09/11/2010 - 04:28:47: MessageEnd (TeamScore "85") - Message Num: 82
	*/
	
	/*
	* L 09/11/2010 - 04:28:50: MessageBegin (TeamInfo "84") (Destination "All<2>") (Args "2") (Entity "<NULL>") (Classname "<NULL>") (Netname "<NULL>") (Origin "0.000000 0.000000 0.000000")
	L 09/11/2010 - 04:28:50: Arg 1 (Byte "1")
	L 09/11/2010 - 04:28:50: Arg 2 (String "Specialists")
	L 09/11/2010 - 04:28:50: MessageEnd (TeamInfo "84") - Message Num: 94
	*/
	/*
	new Arg[33]
	read_argv(1,Arg,32);
	
	new TSWeapon = ts_get_user_tsgun(id);
	if(!TSWeapon)
		return 0
	
	Offsets[1] = 80; // glock 18
	Offsets[2] = -1; // no weapon
	Offsets[3] = 108; // uzi
	Offsets[4] = 122; // shotgun m3
	Offsets[5] = 136; // m4a1
	Offsets[6] = 150; // mp5sd
	Offsets[7] = 164; // mp5k
	Offsets[8] = 94; // bretta
	Offsets[9] = 192; // socom
	Offsets[10] = 206; // akimbo socom
	Offsets[11] = 220; // usas
	Offsets[12] = 234; // degal
	Offsets[13] = 248; // ak47
	Offsets[14] = 262; // 57
	Offsets[15] = 276; // aug
	Offsets[16] = 290; // akimbo uzi
	Offsets[17] = 304; // skorpeon
	Offsets[18] = 318; // barret
	Offsets[19] = 332; // mp7
	Offsets[20] = 346; // spas
	Offsets[21] = 360; // colts
	Offsets[22] = 374; // glock 20
	Offsets[23] = 388; // ump
	Offsets[24] = 624; // m61 grenade
	Offsets[25] = -1; // combat knife
	Offsets[26] = 430; // mossberg
	Offsets[27] = 444; // m16a1
	Offsets[28] = 458; // rugar
	Offsets[29] = -1; // C4
	Offsets[30] = 486; // akimbo 57's
	Offsets[31] = 500; // bull
	Offsets[32] = 514; // m60
	Offsets[33] = 528; // sawed off
	Offsets[34] = -1; // Katana
	Offsets[35] = -1; // Seal Knife
	Offsets[36] = -1; // contender // unknown
	Offsets[37] = 584;
	
	
	for(new Count=500;Count < 800;Count++)
		if(get_pdata_int(TSWeapon,Count) == str_to_num(Arg))
			server_print("%d: %d",Count,get_pdata_int(TSWeapon,Count))
		
	
	new Results[TS_MAX_WEAPONS + 1],Num
	for(new Count;Count < sizeof(Offsets);Count++)
	{
	if(Offsets[Count] <= 0)
		continue
	
	if(get_pdata_int(TSWeapon,Offsets[Count]) > 0)
		Results[Num++] = Count
	}
	server_print("Num: %d",Num);
	*/
}
/*

//	pev->skin = (entityIndex & 0x0FFF) | ((pev->skin&0xF000)<<12); 
//	pev->aiment = g_engfuncs.pfnPEntityOfEntIndex( entityIndex );

//	inline void	SetType( int type ) { pev->rendermode = (pev->rendermode & 0xF0) | (type&0x0F); }
m_pNoise = CBeam::BeamCreate( EGON_BEAM_SPRITE, 55 );
m_pNoise->PointEntInit( pev->origin, m_pPlayer->entindex() );
m_pNoise->SetScrollRate( 25 );
m_pNoise->SetBrightness( 100 );
m_pNoise->SetEndAttachment( 1 );
m_pNoise->pev->spawnflags |= SF_BEAM_TEMPORARY;
m_pNoise->pev->flags |= FL_SKIPLOCALHOST;
m_pNoise->pev->owner = m_pPlayer->edict();


//	EngFunc_CrosshairAngle,		// void )		(const edict_t *pClient, float pitch, float yaw);
//EngFunc_ParticleEffect,		// void )		(const float *org, const float *dir, float color, float count);
new Index,Body
get_user_aiming(id,Index,Body,200);

if(Index)
{
new Class[33],Model[33],Origin[3]
pev(Index,pev_classname,Class,32);
pev(Index,pev_model,Model,32);
pev(id,pev_origin,Origin);
client_print(id,print_console,"%s - %s",Class,Model);

new Ent = engfunc(EngFunc_CreateNamedEntity,engfunc(EngFunc_AllocString,"func_wall"));
if(Ent)
{
engfunc(EngFunc_SetModel,Ent,Model);
engfunc(EngFunc_SetOrigin,Ent,Origin);
dllfunc(DLLFunc_Spawn,Ent);
drop_to_floor(Ent);
client_print(id,print_chat,"hurrr udrr");
}
}

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


new MiscText[1024]

DRP_MiscSetText("fuckyeah","Dude, i love tits");
DRP_MiscGetText("fuckyeah",MiscText,1023);

server_print("GOT STRING: %s",MiscText);


message_begin(MSG_ONE,get_user_msgid("KFuPower"),_,id);
write_byte(42);
message_end();


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
/*==================================================================================================================================================*/
LoadHelpFiles()
{
	if(g_PluginEnd)
		return
	
	server_print("^n");
	
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
		
		// Hard-coded
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
			
			if(containi(Data,"*C") != -1)
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
			new szFile[128]
			strtok(File,File,32,Data,127,'.',1);
			
			formatex(szFile,127,"say /%s",File);
			register_clcmd(szFile,"CmdMotd");
		}
		
		server_print("[MOTD CHECKER] Checked: %s - O.K.",File);
		
		Count[1]++
		fclose(pFile);
	}
	server_print("[MOTD CHECKER] %d files checked. (%d Error(s))^n",Count[1],Count[2]);
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
	
	format(g_Query,4095,"CREATE TABLE IF NOT EXISTS %s (JobName VARCHAR(32),JobSalary INT(11),JobAccess VARCHAR(27),PRIMARY KEY (JobName))",g_JobsTable);
	UTIL_CleverQuery(g_Plugin,g_SqlHandle,"IgnoreHandle",g_Query)
	
	format(g_Query,4095,"CREATE TABLE IF NOT EXISTS %s (Internalname VARCHAR(66),Externalname VARCHAR(66),Ownername VARCHAR(40),OwnerAuthID VARCHAR(36),Price INT(11),Access VARCHAR(27),Profit INT(11),CustomMessage TEXT,Locked INT(11),PRIMARY KEY (Internalname))",g_PropertyTable)
	UTIL_CleverQuery(g_Plugin,g_SqlHandle,"IgnoreHandle",g_Query)
	
	format(g_Query,4095,"CREATE TABLE IF NOT EXISTS %s (AuthIDName VARCHAR(64),Num INT(11),PRIMARY KEY (AuthIDName))",g_ItemsTable)
	UTIL_CleverQuery(g_Plugin,g_SqlHandle,"IgnoreHandle",g_Query)
	
	format(g_Query,4095,"CREATE TABLE IF NOT EXISTS %s (Targetname VARCHAR(36),Internalname VARCHAR(66),Locked INT(11),PRIMARY KEY (Targetname))",g_DoorsTable);
	UTIL_CleverQuery(g_Plugin,g_SqlHandle,"IgnoreHandle",g_Query);
	
	format(g_Query,4095,"CREATE TABLE IF NOT EXISTS %s (AuthIDKey VARCHAR(64),PRIMARY KEY (AuthIDKey))",g_KeysTable);
	UTIL_CleverQuery(g_Plugin,g_SqlHandle,"IgnoreHandle",g_Query);
	
	format(g_Query,4095,"CREATE TABLE IF NOT EXISTS %s (ClassKey VARCHAR(64),Value TEXT,PRIMARY KEY (ClassKey))",g_DataTable);
	UTIL_CleverQuery(g_Plugin,g_SqlHandle,"IgnoreHandle",g_Query);
	
	format(g_Query,4095,"CREATE TABLE IF NOT EXISTS %s (SteamID VARCHAR(36),BankMoney INT(11),WalletMoney INT(11),JobName VARCHAR(33),Hunger INT(11),Access VARCHAR(24),JobRight VARCHAR(24),PlayTime INT(11),PlayerName VARCHAR(33),PlayerPass VARCHAR(33),PRIMARY KEY (SteamID))",g_UserTable);
	UTIL_CleverQuery(g_Plugin,g_SqlHandle,"IgnoreHandle",g_Query);
	
	format(g_Query,4095,"CREATE TABLE IF NOT EXISTS `Time` (CurrentTime VARCHAR(36),PRIMARY KEY (CurrentTime))");
	UTIL_CleverQuery(g_Plugin,g_SqlHandle,"IgnoreHandle",g_Query);
	
	// Load the Data from the SQL DB
	format(g_Query,4095,"SELECT * FROM %s",g_JobsTable);
	UTIL_CleverQuery(g_Plugin,g_SqlHandle,"FetchJobs",g_Query);
	
	format(g_Query,4095,"SELECT * FROM %s",g_PropertyTable);
	UTIL_CleverQuery(g_Plugin,g_SqlHandle,"FetchProperty",g_Query);
	
	format(g_Query,4095,"SELECT * FROM %s",g_DoorsTable);
	UTIL_CleverQuery(g_Plugin,g_SqlHandle,"FetchDoors",g_Query);
	
	format(g_Query,4095,"SELECT * FROM Time");
	UTIL_CleverQuery(g_Plugin,g_SqlHandle,"FetchWorldTime",g_Query);
	
	new Forward = CreateMultiForward("DRP_Init",ET_IGNORE),Return
	if(Forward <= 0 || !ExecuteForward(Forward,Return))
		return UTIL_Error(0,1,"Could not execute ^"DRP_Init^" forward.",0);
	
	#if defined DEBUG
	g_Querys += 12
	#endif
	
	return DestroyForward(Forward);
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
	
	new InternalName[127],ExternalName[64],OwnerName[33],OwnerAuthid[36],AccessStr[JOB_ACCESSES + 1],Access,Profit,Array:CurArray
	while(SQL_MoreResults(Query))
	{
		SQL_ReadResult(Query,0,InternalName,63);
		SQL_ReadResult(Query,1,ExternalName,63);
		SQL_ReadResult(Query,2,OwnerName,32);
		SQL_ReadResult(Query,3,OwnerAuthid,35);
		SQL_ReadResult(Query,5,AccessStr,JOB_ACCESSES);
		
		Access = DRP_AccessToInt(AccessStr);
		Profit = SQL_ReadResult(Query,6);
		
		CurArray = ArrayCreate(128);
		
		ArrayPushCell(g_PropertyArray,CurArray);
		g_PropertyNum++
		
		ArrayPushString(CurArray,InternalName); // 0
		ArrayPushString(CurArray,ExternalName); // 1
		ArrayPushString(CurArray,OwnerName); // 2
		ArrayPushString(CurArray,OwnerAuthid); // 3
		
		ArrayPushCell(CurArray,SQL_ReadResult(Query,4));
		ArrayPushCell(CurArray,SQL_ReadResult(Query,8));
		ArrayPushCell(CurArray,Access);
		ArrayPushCell(CurArray,Profit);
		ArrayPushCell(CurArray,0);
		ArrayPushCell(CurArray,0);
		
		SQL_ReadResult(Query,7,InternalName,127);
		ArrayPushString(CurArray,InternalName);
		
		SQL_NextRow(Query);
	}
	
	static CurName[64]
	for(new Count;Count < g_PropertyNum;Count++)
	{
		ArrayGetString(ArrayGetCell(g_PropertyArray,Count),0,CurName,63);
		server_print("#%d. %s (%d)",Count,CurName,g_PropertyNum);
	}
	
	return PLUGIN_CONTINUE
}

public FetchDoors(FailState,Handle:Query,const Error[],Errcode,const Data[],DataSize)
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
	
	new Targetname[64],InternalName[64],Array:CurArray
	while(SQL_MoreResults(Query))
	{		
		SQL_ReadResult(Query,0,Targetname,63);
		SQL_ReadResult(Query,1,InternalName,63);
		
		CurArray = ArrayCreate(32);
		
		ArrayPushCell(g_DoorArray,CurArray);
		g_DoorNum++
		
		if(equali(Targetname,"e|",2))
		{
			replace(Targetname,63,"e|","");
			
			ArrayPushString(CurArray,""); // 0
			ArrayPushCell(CurArray,str_to_num(Targetname)); // 1
		}
		else if(equali(Targetname,"t|",2))
		{
			replace(Targetname,63,"t|","");
			
			ArrayPushString(CurArray,Targetname); // 0
			ArrayPushCell(CurArray,0); // 1
		}
		
		ArrayPushString(CurArray,InternalName); // 2
		ArrayPushCell(CurArray,0); // 3
		ArrayPushCell(CurArray,SQL_ReadResult(Query,2));
		
		SQL_NextRow(Query);
	}
	
	return PLUGIN_CONTINUE
}
public FetchJobs(FailState,Handle:Query,const Error[],Errcode,const Data[],DataSize)
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
	
	new Temp[JOB_ACCESSES + 1],Array:CurArray
	while(SQL_MoreResults(Query))
	{
		CurArray = ArrayCreate(32);
		
		ArrayPushCell(g_JobArray,CurArray);
		g_JobNum++
		
		// Backwards compat.
		ArrayPushCell(CurArray,0); // 0 - don't use
		
		SQL_ReadResult(Query,0,g_Query,4095);
		ArrayPushString(CurArray,g_Query); // 1
		
		ArrayPushCell(CurArray,SQL_ReadResult(Query,1)); // 2
		
		SQL_ReadResult(Query,2,Temp,JOB_ACCESSES);
		ArrayPushCell(CurArray,DRP_AccessToInt(Temp)); // 3
		
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
	
	new const Num = SQL_NumResults(Query);
	if(!Num)
		return PLUGIN_CONTINUE
	
	if(Num > 1)
		return UTIL_Error(0,1,"Time Error. There is more than one time entry in the SQL.",0);
	
	SQL_ReadResult(Query,0,g_Menu,255);
	
	new StrMin[4],StrHour[4],StrMonth[4],StrMonthDay[4],StrYear[6],StrAM[4]
	parse(g_Menu,StrMin,3,StrHour,3,StrMonth,3,StrMonthDay,3,StrYear,5,StrAM,3);
	
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
	
	new const Array:CurArray = ArrayGetCell(g_PropertyArray,Property),Price = ArrayGetCell(CurArray,4);
	new AuthID[36],Name[33]
	get_user_authid(id,AuthID,35);
	
	ArrayGetString(CurArray,2,Name,32);
	ArrayGetString(CurArray,3,Targetname,63);
	
	if(equali(AuthID,Targetname))
	{
		client_print(id,print_chat,"[DRP] You already own this property.");
		return PLUGIN_HANDLED
	}
	else if(!Price)
	{
		client_print(id,print_chat,"[DRP] This property is already owned / not for sale.");
		return PLUGIN_HANDLED
	}
	
	new Data[4]
	Data[0] = id
	Data[1] = Property + 1
	Data[2] = DRP_PropertyGetOwner(Property + 1); // :(
	Data[3] = (Price > g_UserBank[id]) ? 0 : 1 // can we afford it
	
	if(_CallEvent("Property_Buy",Data,4))
		return PLUGIN_HANDLED
	
	if(Price > g_UserBank[id])
	{
		client_print(id,print_chat,"[DRP] You do not have enough money in your bank to buy this property.");
		return PLUGIN_HANDLED
	}
	
	new ExternalName[33]
	ArrayGetString(CurArray,1,ExternalName,32);
	
	if(Targetname[0] && Price)
	{
		new Players[32],iNum,Player,PlayerAuthid[36],Flag
		get_players(Players,iNum);
		
		for(new Count;Count < iNum;Count++)
		{
			Player = Players[Count]
			get_user_authid(Player,PlayerAuthid,35);
			
			if(equali(PlayerAuthid,Targetname))
			{
				g_UserBank[Player] += Price
				
				get_user_name(id,Name,32);
				client_print(Player,print_chat,"[DRP] Your property, ^"%s^", has been bought by %s for $%d.",ExternalName,Name,Price);
				
				Flag = 1
				break
			}
		}
		
		if(!Flag)
		{
			format(g_Query,4095,"UPDATE %s SET bankmoney = bankmoney + %d WHERE SteamID='%s'",g_UserTable,Price,Targetname);
			UTIL_CleverQuery(g_Plugin,g_SqlHandle,"IgnoreHandle",g_Query);
		}
	}
	
	g_UserBank[id] -= Price
	
	get_user_name(id,Name,32);
	
	ArraySetString(CurArray,2,Name);
	ArraySetString(CurArray,3,AuthID);
	
	ArraySetCell(CurArray,4,0);
	ArraySetCell(CurArray,8,0);
	ArraySetCell(CurArray,9,1);
	
	ArraySetString(CurArray,10,"");
	
	client_print(id,print_chat,"[DRP] You have successfully bought the property ^"%s^"",ExternalName);
	
	ArrayGetString(CurArray,0,ExternalName,63);
	
	format(g_Query,4095,"DELETE FROM %s WHERE authidkey LIKE '%%|%s'",g_KeysTable,ExternalName);
	SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",g_Query);
	
	#if defined DEBUG
	g_Querys += 2
	#endif
	
	return PLUGIN_HANDLED
}
public CmdMotd(id)
{
	read_argv(1,g_Menu,255);
	format(g_Menu,127,"%s%s.txt",g_HelpDIR,g_Menu);
	
	if(!file_exists(g_Menu))
	{
		client_print(id,print_chat,"[DRP] Unable to open file. (%s)",g_Menu);
		return PLUGIN_HANDLED
	}
	
	show_motd(id,g_Menu,"DRP");
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
	
	new const Size = TravTrieSize(g_UserItemArray[id]);
	new Success,Num,ItemID
	
	if(Size < 1)
	{
		client_print(id,print_chat,"[DRP] There are no items in your inventory.");
		return PLUGIN_HANDLED
	}
	else if(Size >= 256)
		client_print(id,print_chat,"[DRP] You have more than 256 items. This may cause problems. Recommended to remove some items.");
	
	new ItemName[33]
	formatex(ItemName,32,"Inventory - Total Items: %d^nPage:",TravTrieSize(g_UserItemArray[id]))
	
	new Menu = menu_create(ItemName,"ItemsHandle");
	while(Num < Size && (ItemID = array_get_nth(g_UserItemArray[id],++Num,_,Success)) != 0 && Success)
	{
		UTIL_ValidItemID(ItemID) ?
		UTIL_GetItemName(ItemID,ItemName,32) : copy(ItemName,32,"BAD ITEMID : Contact Admin");
		
		formatex(g_Menu,255,"%s x %d",ItemName,UTIL_GetUserItemNum(id,ItemID));
		menu_additem(Menu,g_Menu);
	}
	
	menu_display(id,Menu);
	return PLUGIN_HANDLED
}
public ItemsHandle(id,Menu,Item)
{
	menu_destroy(Menu);
	
	if(Item == MENU_EXIT)
		return PLUGIN_HANDLED
	
	new Success
	new const ItemID = array_get_nth(g_UserItemArray[id],Item + 1,_,Success);
	
	g_CurItem[id] = ItemID
	
	if(UTIL_GetUserItemNum(id,ItemID) <= 0)
	{ client_print(id,print_chat,"[DRP] Your quantity for this item is zero."); UTIL_SetUserItemNum(id,ItemID,0); }
	else if(!UTIL_ValidItemID(ItemID))
		client_print(id,print_chat,"[DRP] This item is invalid. Please contact the administrator.");
	else
	{
		new ItemName[33]
		UTIL_GetItemName(ItemID,ItemName,32);
		
		const Keys = MENU_KEY_0|MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5
		
		format(g_Menu,255,"Item: %s ( x %d )^n^n1. Use^n2. Give^n3. Drop^n4. Show^n5. Examine^n^n0. Exit",ItemName,UTIL_GetUserItemNum(id,ItemID));
		show_menu(id,Keys,g_Menu,-1,g_ItemsOptions);
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
			if(ArrayGetCell(ArrayGetCell(g_ItemsArray,g_CurItem[id]),7) == 0)
			{
				client_print(id,print_chat,"[DRP] This item is not giveable.");
				return
			}
			
			const Keys = MENU_KEY_0|MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6|MENU_KEY_7
			
			format(g_Menu,255,"Give Items^n^n1. Give 1^n2. Give 5^n3. Give 10^n4. Give 20^n5. Give 50^n6. Give 100^n7. Give All^n^n0. Exit");
			show_menu(id,Keys,g_Menu,-1,g_ItemsGive);
		}
		case 2:
		{
			if(ArrayGetCell(ArrayGetCell(g_ItemsArray,g_CurItem[id]),6) == 0)
			{
				client_print(id,print_chat,"[DRP] This item is not dropable.");
				return
			}
			
			const Keys = MENU_KEY_0|MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6|MENU_KEY_7
			
			format(g_Menu,255,"Drop Items^n^n1. Drop 1^n2. Drop 5^n3. Drop 10^n4. Drop 20^n5. Drop 50^n6. Drop 100^n7. Drop All^n^n0. Exit");
			show_menu(id,Keys,g_Menu,-1,g_ItemsDrop);
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
			client_print(Index,print_chat,"[DRP] %s has showed you his/her: %s",Name[1],ItemName);
			
			g_ItemShow[Index] = ItemID
			
			if(DRP_IsPlayerInMenu(Index))
				client_print(Index,print_chat,"You may type ^"/iteminfo^" for more information on this item.");
			else
			{
				new Menu = menu_create("Item Description","_ViewItem");
				menu_additem(Menu,"View Item Description");
				menu_additem(Menu,"Ignore");
				
				formatex(g_Menu,255,"^n%s has shown you an item^nwould you like to view info about it?",Name[1]);
				menu_addtext(Menu,g_Menu,0);
				
				menu_display(Index,Menu);
			}
		}
		
		case 4:
		ItemInfo(id,g_CurItem[id]);
	}
}

public _ViewItem(id,Menu,Item)
{
	menu_destroy(Menu);
	
	if(Item == MENU_EXIT)
		return PLUGIN_HANDLED
	
	if(Item == 0)
		ItemInfo(id,g_ItemShow[id]);
	
	return PLUGIN_HANDLED
}

public ItemsGive(id,Key)
{
	if(!is_user_alive(id) || Key == 9)
		return
	
	new Index,Body
	get_user_aiming(id,Index,Body,100);
	
	if(!Index || !is_user_alive(Index))
	{
		client_print(id,print_chat,"[DRP] You are not looking at a user.");
		return
	}
	
	new const ItemID = g_CurItem[id]
	
	new szItemNum[12]
	TravTrieGetStringEx(g_UserItemArray[id],ItemID,szItemNum,11);
	
	new Num,ItemNum = abs(str_to_num(szItemNum))
	
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
	
	client_print(id,print_chat,"[DRP] You have given ^"%s^" %d %s%s.",Name[0],Num,ItemName,Num == 1 ? "" : "s");
	client_print(Index,print_chat,"[DRP] %s has given you %d %s%s.",Name[1],Num,ItemName,Num == 1 ? "" : "s");
}

public ItemsDrop(id,Key)
{
	if(!is_user_alive(id) || Key == 9)
		return
	
	new const ItemID = g_CurItem[id]
	
	new szItemNum[12]
	TravTrieGetStringEx(g_UserItemArray[id],ItemID,szItemNum,11);
	
	new Num,ItemNum = abs(str_to_num(szItemNum));
	
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
	
	new Data[3],Float:plOrigin[3]
	Data[0] = id
	Data[1] = ItemID
	Data[2] = Num
	
	if(_CallEvent("Item_Drop",Data,3))
		return
	
	new ItemName[33]
	pev(id,pev_origin,plOrigin);
	
	UTIL_GetItemName(ItemID,ItemName,32);
	
	if(!_CreateItemDrop(id,plOrigin,Num,ItemName))
	{
		client_print(id,print_chat,"[DRP] There was an error dropping the item.");
		return
	}
	UTIL_SetUserItemNum(id,ItemID,UTIL_GetUserItemNum(id,ItemID) - Num);
	
	client_cmd(id,"spk ^"items/ammopickup1.wav^"");
	client_print(id,print_chat,"[DRP] You have dropped %d x %s",Num,ItemName);
}
ItemInfo(id,ItemID)
{
	if(!is_user_alive(id) || !UTIL_ValidItemID(ItemID))
		return
	
	// show_motd() - uses alot of bandwidth - so limit
	if(!CheckTime(id))
		return
	
	new ItemName[33]
	UTIL_GetItemName(ItemID,ItemName,32);
	
	ArrayGetString(ArrayGetCell(g_ItemsArray,ItemID),4,g_Menu,255);
	
	if(!g_Menu[0])
	{
		client_print(id,print_chat,"[DRP] This item does not have a description.");
		return
	}
	
	format(g_Menu,255,"Item: %s^n^nDescription:^n%s",ItemName,g_Menu);
	show_motd(id,g_Menu,"DRP");
}
/*==================================================================================================================================================*/
public CmdHelp(id)
{
	if(!CheckTime(id))
		return PLUGIN_HANDLED
	
	new Arg[33]
	read_argv(1,Arg,32);
	
	new const Start = str_to_num(Arg),Items = get_pcvar_num(p_ItemsPerPage);
	
	if(Start)
		read_argv(2,Arg,32);
	
	if(Start >= g_CommandNum || Start < 0)
	{
		client_print(id,print_console,"[DRP] No help items in this area to display.");
		return PLUGIN_HANDLED
	}
	
	new Extra = containi(Arg,"extra") != -1 ? 1 : 0,Admin = UTIL_IsUserAdmin(id);
	
	client_print(id,print_console,"^n---- DRP %s: Commands ----",Admin ? " (Inc. Admin Commands)" : "");
	client_print(id,print_console,"Commad Name       %s",Extra ? "Description" : "");
	
	new Description[128],Array:CurArray,CommandNum
	for(new Count = Start;Count < Start + Items;Count++)
	{
		if(Count >= g_CommandNum)
			break
		
		CurArray = ArrayGetCell(g_CommandArray,Count);
		ArrayGetString(CurArray,1,Arg,32);
		
		if(Extra)
			ArrayGetString(CurArray,2,Description,127);
		
		if(ArrayGetCell(CurArray,3) && !Admin)
			continue
		
		CommandNum++
		client_print(id,print_console,"%d: %s      %s",CommandNum,Arg,Extra ? Description : "");
	}
	
	if(Start + Items < g_CommandNum)
		client_print(id,print_console,"[DRP] Type ^"drp_help %d^" to view the next page.",Start + Items);
	
	if(!Extra)
		client_print(id,print_console,"[DRP] NOTE: You may type ^"drp_help # extra^" to view the list with descriptions.");
	
	return PLUGIN_HANDLED
}
public CmdJobList(id)
{
	if(!CheckTime(id))
		return PLUGIN_HANDLED
	
	new Arg[33]
	read_argv(1,Arg,32);
	
	new const Start = str_to_num(Arg),Items = get_pcvar_num(p_ItemsPerPage);
	
	if(Start >= g_JobNum || Start < 0)
	{
		client_print(id,print_console,"[DRP] No jobs in this area to display.");
		return PLUGIN_HANDLED
	}
	
	new JobName[33],JobAccess[JOB_ACCESSES + 1],Array:CurArray
	client_print(id,print_console,"^nDRP Jobs List (Starting at: #%d)",Start);
	client_print(id,print_console,"JobID JobName       JobSalary       Access");
	
	for(new Count = Start;Count < Start + Items;Count++)
	{
		if(Count >= g_JobNum)
			break
		
		CurArray = ArrayGetCell(g_JobArray,Count);
		
		ArrayGetString(CurArray,1,JobName,32);
		DRP_IntToAccess(ArrayGetCell(CurArray,3),JobAccess,JOB_ACCESSES);
		
		client_print(id,print_console,"%d: %s       $%d       %s",Count + 1,JobName,ArrayGetCell(CurArray,2),JobAccess);
	}
	
	if(Start + Items < g_JobNum)
		client_print(id,print_console,"[DRP] Type ^"drp_joblist %d^" to view the next page.", Start + Items);
	
	// Temp ------
	read_argv(0,Arg,32);
	if(equali(Arg,"amx_joblist"))
		client_print(id,print_console,"^n-----------^n Please use the new ^"drp_joblist^" command instead of this one^n-----------^n");
	// ------
	
	return PLUGIN_HANDLED
}
public CmdItemList(id)
{	
	if(!CheckTime(id))
		return PLUGIN_HANDLED
	
	new Arg[33]
	read_argv(1,Arg,32);
	
	new const Start = str_to_num(Arg) + 1,Items = get_pcvar_num(p_ItemsPerPage);
	
	if(Start - 1)
		read_argv(2,Arg,32);
	
	if(Start > g_ItemsNum || Start < 1)
	{
		client_print(id,print_console,"[DRP] No items in this area to display.")
		return PLUGIN_HANDLED
	}
	
	new const Extra = containi(Arg,"extra") != -1 ? 1 : 0
	
	client_print(id,print_console,"^nDRP Items List (Starting at: #%d)",Start);
	client_print(id,print_console,"ItemID       Name       %s",Extra ? "Description" : "");
	
	new Name[33],Description[128],Array:CurArray
	for(new Count = Start;Count < Start + Items;Count++)
	{
		if(Count >= g_ItemsNum)
			break
		
		CurArray = ArrayGetCell(g_ItemsArray,Count);
		ArrayGetString(CurArray,1,Name,32);
		
		if(Extra)
			ArrayGetString(CurArray,4,Description,127);
		
		client_print(id,print_console,"%d: %s       %s",Count,Name,Extra ? Description : "");
	}
	
	if(Start + Items <= g_ItemsNum)
		client_print(id,print_console,"[DRP] Type ^"drp_itemlist %d^" to view the next page.",Start + Items - 1);
	
	if(!Extra)
		client_print(id,print_console,"[DRP] NOTE: You may type ^"drp_itemlist # extra^" to view the list with descriptions.");
	
	// Temp ------
	read_argv(0,Arg,32);
	if(equali(Arg,"amx_itemlist"))
		client_print(id,print_console,"^n-----------^n Please use the new ^"drp_itemlist^" command instead of this one^n-----------^n");
	// ------
	
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
		client_print(id,print_chat,"[DRP] There is currently no items in your menu.");
		return PLUGIN_HANDLED
	}
	
	new Info[128],Key[64]
	new travTrieIter:Iter = GetTravTrieIterator(g_MenuArray[id]),Menu = menu_create("Quick-Access Menu","ClientMenuHandle");
	
	while(MoreTravTrie(Iter))
	{
		ReadTravTrieKey(Iter,Key,63);
		ReadTravTrieString(Iter,Info,127);
		
		menu_additem(Menu,Key,Info);
	}
	DestroyTravTrieIterator(Iter);
	menu_display(id,Menu);
	
	return PLUGIN_HANDLED
}
public ClientMenuHandle(id,Menu,Item)
{
	if(Item == MENU_EXIT)
	{
		menu_destroy(Menu);
		return PLUGIN_HANDLED
	}
	
	new Access,Callback
	menu_item_getinfo(Menu,Item,Access,g_Menu,255,_,_,Callback);
	
	new Forward = CreateOneForward(g_Menu[0],g_Menu[1],FP_CELL),Return
	if(Forward <= 0 || !ExecuteForward(Forward,Return,id))
	{
		menu_destroy(Menu);
		return PLUGIN_HANDLED
	}
	
	DestroyForward(Forward);
	menu_destroy(Menu);
	
	return PLUGIN_HANDLED
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
public CmdPropertyInfo(id,EntID)
{
	if(!is_user_alive(id) || !CheckTime(id))
		return PLUGIN_HANDLED
	
	new Index
	if(!EntID)
	{
		new Body
		get_user_aiming(id,Index,Body,100);
		
		if(!Index)
		{
			client_print(id,print_chat,"[DRP] You must be looking at a property.");
			return PLUGIN_HANDLED
		}
	}
	else
	Index = EntID
	
	new TargetName[33]
	pev(Index,pev_targetname,TargetName,32);
	
	new Property = UTIL_GetProperty(TargetName);
	if(Property == -1)
	{
		client_print(id,print_chat,"[DRP] You must be looking at a property.");
		return PLUGIN_HANDLED
	}
	
	if(DRP_PropertyGetOwner(Property + 1) != id)
	{
		client_print(id,print_chat,"[DRP] You do not own this property.");
		return PLUGIN_HANDLED
	}
	
	new Data[2]
	Data[0] = id
	Data[1] = Property
	
	format(g_Query,4095,"SELECT * FROM `%s`",g_KeysTable);
	SQL_ThreadQuery(g_SqlHandle,"FetchPropertyUserInfo",g_Query,Data,2);
	
	client_print(id,print_chat,"[DRP] Fetching Property Information..");
	return PLUGIN_HANDLED
}

// We have todo this, so we can show which steamid's have access to our property
public FetchPropertyUserInfo(FailState,Handle:Query,const Error[],Errcode,const Data[],DataSize) 
{
	if(FailState != TQUERY_SUCCESS)
		return DRP_Log("[DRP-CORE] [SQL ERROR] Unable to connect to SQL Database. (Error: %s)",Error ? Error : "UNKNOWN");
	
	new id = Data[0],Property = Data[1],SQLProperty
	new Users[256],AuthID[36],InternalName[33]
	
	while(SQL_MoreResults(Query))
	{
		SQL_ReadResult(Query,0,g_Menu,255);
		strtok(g_Menu,AuthID,35,InternalName,32,'|');
		
		SQLProperty = UTIL_MatchProperty(InternalName);
		
		if(SQLProperty == Property)
		{
			add(Users,255,AuthID);
			add(Users,255,"^n");
		}
		
		SQL_NextRow(Query);
	}
	
	new Pos
	new Array:CurArray = ArrayGetCell(g_PropertyArray,Property);
	console_print(id,"-------Users-------^n%s",Users);
	
	ArrayGetString(CurArray,1,g_Query,4095);
	Pos += formatex(g_Menu[Pos],255 - Pos,"Name: %s^nProfit: $%d^n",g_Query,ArrayGetCell(CurArray,4));
	
	DRP_IntToAccess(ArrayGetCell(CurArray,6),g_Query,4095);
	Pos += formatex(g_Menu[Pos],255 - Pos,"Access Letter: %s^n",g_Query[0] ? g_Query : "N/A");
	
	ArrayGetString(CurArray,0,g_Query,4095);
	Pos += formatex(g_Menu[Pos],255 - Pos,"InternalName: %s^n^nAccess to this Property^n%s^n^nThis list has also been put into your console (for copy/paste)",g_Query,Users);
	
	show_motd(id,g_Menu,"Prop Info");
	return PLUGIN_CONTINUE
}
CheckTime(id,Float:CoolDown = 1.5)
{
	new const Float:Time = get_gametime();
	if(Time - g_ConsoleTimeout[id] < CoolDown && g_ConsoleTimeout[id])
		return FAILED
	
	g_ConsoleTimeout[id] = Time
	return SUCCEEDED
}
/*==================================================================================================================================================*/
public fw_SetKeyValue(const id,const infobuffer[],const key[],const value[])
{
	if(!is_user_connected(id))
		return FMRES_IGNORED
	
	if(!get_pcvar_num(p_FLName) || !equal(key,"name"))
		return FMRES_IGNORED
	
	// Only DRP admins get past this
	// Normal admins do not
	
	if(UTIL_IsUserAdmin(id))
		return FMRES_IGNORED
	
	// We do not have a "space" within our name.
	// Example: Drak (Returns -1) - Drak Smith (Returns Position)
	new const Contain = contain(value," ");
	if(Contain != -1)
	{
		if(!equali(value,g_StartingName) && !g_NameLoad[id])
			menu_display(id,g_NameMenu)
		
		g_NameLoad[id] = false
		return FMRES_IGNORED
	}
	
	set_user_info(id,key,g_StartingName);
	client_print(id,print_chat,"[DRP] Your name has been changed. Please use a first and last name.");
	
	return FMRES_SUPERCEDE // Return this to tell "WelcomeMsg()"
}
public _HandleName(id,Menu,Item)
{
	if(Item == MENU_EXIT)
		return PLUGIN_HANDLED
	
	switch(Item)
	{
		case 0:
		{
			new AuthID[36]
			get_user_authid(id,AuthID,35);
			get_user_name(id,g_Menu,255);
			
			replace_all(g_Menu,255,"'","\'");
			
			format(g_Query,4095,"UPDATE `%s` SET `PlayerName`='%s' WHERE `SteamID`='%s'",g_UserTable,g_Menu,AuthID);
			SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",g_Query);
			
			client_print(id,print_chat,"[DRP] Your name has been saved. It will be changed everytime you connect.");
		}
		case 1:
		{
			client_print(id,print_chat,"[DRP] Your name has not been saved.");
		}
	}
	return PLUGIN_HANDLED
}
public client_authorized(id)
{
	if(is_user_bot(id) || is_user_hltv(id))
		return
	
	if(id > 32)
	{
		id -= 32
		
		if(g_Saving[id])
		{
			set_task(0.5,"client_authorized",id + 32);
			return
		}
	}
	
	if(g_Saving[id])
	{
		set_task(0.5,"client_authorized",id + 32);
		return
	}
	
	g_Joined[id] = false
	g_GotInfo[id] = 0
	
	new AuthID[36],Data[1]
	get_user_authid(id,AuthID,35);
	
	Data[0] = id
	
	format(g_Query,4095,"SELECT * FROM %s WHERE SteamID='%s'",g_UserTable,AuthID);
	SQL_ThreadQuery(g_SqlHandle,"FetchClientData",g_Query,Data,1);
	
	format(g_Query,4095,"SELECT * FROM %s WHERE AuthIDName LIKE '%s|%%'",g_ItemsTable,AuthID);
	SQL_ThreadQuery(g_SqlHandle,"FetchClientItems",g_Query,Data,1);
	
	format(g_Query,4095,"SELECT * FROM %s WHERE AuthIDKey LIKE '%s|%%'",g_KeysTable,AuthID);
	SQL_ThreadQuery(g_SqlHandle,"FetchClientKeys",g_Query,Data,1);
	
	#if defined DEBUG
	g_Querys += 3
	#endif
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
new g_Unemployed
public FetchClientData(FailState,Handle:Query,const Error[],Errcode,const Data[],DataSize) 
{
	if(FailState != TQUERY_SUCCESS || Errcode)
		return UTIL_Error(0,0,"SQL Error (Error: %s)",0,Error ? Error : "UNKNOWN");
	
	new const id = Data[0]
	g_GotInfo[id]++
	
	// HACKHACK!! - PRINT_CENTER 2 SECOND HOLD TIME
	client_cmd(id,"scr_centertime 2");
	
	if(SQL_NumResults(Query) < 1)
	{
		// Load it
		if(g_Unemployed == 0)
		{		
			new Results[1]
			DRP_FindJobID("Unemployed",Results,1);
			
			Results[0] -= 1
			g_Unemployed = Results[0]
			
			g_UserJobID[id] = g_Unemployed
		}
		else
		{
			g_UserJobID[id] = g_Unemployed
		}
		
		new AuthID[36],StartBankMoney = get_pcvar_num(p_StartMoney);
		get_user_authid(id,AuthID,35);
		
		if(containi(AuthID,"PENDING") != -1)
			DRP_Log("Invalid Player SteamID (%s)",AuthID);
		
		format(g_Query,4095,"INSERT INTO %s VALUES('%s','%d','0','Unemployed','0','','',0,'','%s')",g_UserTable,AuthID,StartBankMoney,DEFAULT_PASS);
		SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",g_Query);
		
		CheckReady(id);
		
		g_UserBank[id] = StartBankMoney
		g_UserWallet[id] = 0
		g_UserHunger[id] = 0
		g_AccessCache[id] = 0
		
		g_UserTime[id] = 0
		g_UserJobRight[id] = 0
		
		new const Array:CurArray =  ArrayGetCell(g_JobArray,g_UserJobID[id]);
		g_UserAccess[id] = ArrayGetCell(CurArray,3);
		g_UserSalary[id] =  ArrayGetCell(CurArray,2);
		
		server_print("[DRP-CORE] Player %d (%s) was added to the database.",id,AuthID);
		TravTrieClear(g_UserItemArray[id]);
		
		if(_CallEvent("DRP_NewPlayer",Data,1))
			return PLUGIN_CONTINUE
		
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
		
		if(g_Unemployed == 0)
		{
			DRP_FindJobID("Unemployed",Results,1);
			g_Unemployed = Results[0] - 1
		}
		
		if(!UTIL_ValidJobID(g_Unemployed))
		{
			Results[0] = DRP_AddJob("Unemployed",5,0) - 1
			g_Unemployed = Results[0]
		}
		
		g_UserJobID[id] = g_Unemployed
		g_UserSalary[id] = 5
	}
	
	else if(!UTIL_ValidJobID(g_UserJobID[id]))
		g_BadJob[id] = true
	
	g_UserHunger[id] = SQL_ReadResult(Query,4);
	
	SQL_ReadResult(Query,5,Temp,63);
	g_UserAccess[id] = DRP_AccessToInt(Temp);
	g_AccessCache[id] = g_UserAccess[id]
	
	new const Array:CurArray =  ArrayGetCell(g_JobArray,g_UserJobID[id]);
	g_UserSalary[id] =  ArrayGetCell(CurArray,2);
	g_UserAccess[id] |=  ArrayGetCell(CurArray,3);
	
	SQL_ReadResult(Query,6,Temp,63);
	g_UserJobRight[id] = DRP_AccessToInt(Temp);
	
	g_UserTime[id] = SQL_ReadResult(Query,7);
	
	SQL_ReadResult(Query,8,Temp,63);
	
	if(Temp[0] && !UTIL_IsUserAdmin(id))
	{
		g_NameLoad[id] = true
		set_user_info(id,"name",Temp);
	}
	
	Temp[0] = 0
	SQL_ReadResult(Query,9,Temp,63);
	
	if(Temp[0])
		copy(g_UserPass[id],32,Temp);
	
	CheckReady(id);
	
	return PLUGIN_CONTINUE
}
public FetchClientItems(FailState,Handle:Query,const Error[],Errcode,const Data[],DataSize) 
{
	if(FailState != TQUERY_SUCCESS || Errcode)
		return UTIL_Error(0,0,"SQL Error (Error: %s)",0,Error ? Error : "UNKNOWN");
	
	new const id = Data[0]
	
	g_GotInfo[id]++
	
	if(!SQL_NumResults(Query))
	{
		CheckReady(id);
		return PLUGIN_CONTINUE
	}
	
	new Temp[2][36],ItemID
	TravTrieClear(g_UserItemArray[id]);
	
	while(SQL_MoreResults(Query))
	{
		SQL_ReadResult(Query,0,g_Menu,255);
		strtok(g_Menu,Temp[0],35,Temp[1],35,'|',1);
		
		ItemID = UTIL_FindItemID(Temp[1]);
		
		if(!UTIL_ValidItemID(ItemID))
		{			
			SQL_NextRow(Query);
			continue
		}
		
		formatex(Temp[0],35,"%d",-SQL_ReadResult(Query,1));
		TravTrieSetStringEx(g_UserItemArray[id],ItemID,Temp[0]);
		
		SQL_NextRow(Query);
	}
	CheckReady(id);
	
	return PLUGIN_CONTINUE
}
public FetchClientKeys(FailState,Handle:Query,const Error[],Errcode,const Data[],DataSize) 
{
	if(FailState != TQUERY_SUCCESS || Errcode)
		return UTIL_Error(0,0,"SQL Error (Error: %s)",0,Error ? Error : "UNKNOWN");
	
	new const id = Data[0]
	g_GotInfo[id]++
	
	if(!SQL_NumResults(Query))
	{
		CheckReady(id);
		return PLUGIN_CONTINUE
	}
	
	new InternalName[33],Property,AuthidKey[64],Garbage[1],Array:CurArray
	while(SQL_MoreResults(Query))
	{
		SQL_ReadResult(Query,0,AuthidKey,63);
		strtok(AuthidKey,Garbage,0,InternalName,32,'|');
		
		Property = UTIL_MatchProperty(InternalName);
		
		if(Property != -1)
		{
			CurArray = ArrayGetCell(g_PropertyArray,Property);
			ArraySetCell(CurArray,8,ArrayGetCell(CurArray,8)|(1<<(id - 1)));
		}
		
		SQL_NextRow(Query);
	}
	CheckReady(id);
	
	return PLUGIN_CONTINUE
}
/*==================================================================================================================================================*/
// HUD System
public ShowHud()
{
	if(!g_HudForward || g_PluginEnd)
		return
	
	g_Time -= 10
	
	if(g_Time <= 0)
		g_Time = 600
	
	new Data[1],iNum,id
	
	static iPlayers[32]
	get_players(iPlayers,iNum);
	
	for(new Count,Count2;Count < iNum;Count++)
	{
		id = iPlayers[Count]
		
		if(!is_user_alive(id) || is_user_bot(id))
			continue
		
		if(g_Time == 600)
		{
			Data[0] = id
			
			if(_CallEvent("Player_Salary",Data,1))
				continue
			
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
	
	switch(g_WorldTime[2])
	{
		// It's 11:59
		case 11:
		{
			// AM <-> PM
			new const CompilerFix = g_WorldTime[3]
			g_WorldTime[3] = !CompilerFix
			
			if(++g_WorldTime[5] >= g_MonthDays[g_WorldTime[4]])
			{
				g_WorldTime[5] = 1
				
				if(++g_WorldTime[4] >= 11)
				{
					g_WorldTime[6]++
					g_WorldTime[4] = 1
				}
			}
			g_WorldTime[2]++
		}
		default:
		{
			if(++g_WorldTime[2] >= 13)
				g_WorldTime[2] = 1
		}
	}
	g_WorldTime[1] = 0
}
RenderHud(id,Hud)
{
	TravTrieClear(g_HudArray[id][Hud]);
	
	if(!is_user_alive(id))
		return
	
	g_HudPending = true
	
	static Temp[256],Message[512],Return
	
	if(!ExecuteForward(g_HudForward,Return,id,Hud))
		return
	
	Message[0] = 0
	
	new travTrieIter:Iter = GetTravTrieIterator(g_HudArray[id][Hud]),Priority,Ticker
	while(MoreTravTrie(Iter))
	{
		ReadTravTrieKey(Iter,Temp,255);
		ReadTravTrieCell(Iter,Priority);
		
		replace_all(Temp,255,"\n","^n");
		
		float(Priority);
		
		Ticker += formatex(Message[Ticker],511 - Ticker,"%s^n",Temp);
	}
	DestroyTravTrieIterator(Iter);
	
	g_HudPending = false
	
	set_hudmessage(get_pcvar_num(p_Hud[Hud][R]),get_pcvar_num(p_Hud[Hud][G]),get_pcvar_num(p_Hud[Hud][B]),get_pcvar_float(p_Hud[Hud][X]),get_pcvar_float(p_Hud[Hud][Y]),0,0.0,999999.9,0.0,0.0,-1)
	ShowSyncHudMsg(id,g_HudObjects[Hud],"%s",Message);
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
// Forwards
public forward_PreThink(id)
{
	if(g_PluginEnd)
		return FMRES_IGNORED
	
	// Don't allow players to spectate other players
	
	if(!is_user_alive(id))
	{
		static Target
		Target = pev(id,pev_iuser2);
		
		if(Target)
			set_pev(id,pev_iuser2,0);
		
		return FMRES_HANDLED
	}
	
	new Index,Body
	get_user_aiming(id,Index,Body,100);
	
	if(g_Display[id])// && Index)
		PrintDisplay(id,Index);
	
	if(!(pev(id,pev_button) & IN_USE && !(pev(id,pev_oldbuttons) & IN_USE)))
		return FMRES_IGNORED
	
	static Classname[36]
	if(Index)
	{
		pev(Index,pev_classname,Classname,35);
		if(containi(Classname,g_FuncDoor) != -1)
		{
			new DoorArray
			pev(Index,pev_targetname,Classname,35);
			
			new const Property = UTIL_GetProperty(Classname,Index,DoorArray);
			if(Property == -1)
				return FMRES_IGNORED
			
			// First - check if this door has a "master lock"
			// If it's not locked (by default it is) - we can go into it. This allows us to lock/unlock specific doors
			// Instead of the WHOLE property
			
			if(ArrayGetCell(ArrayGetCell(g_DoorArray,DoorArray),4) == 0)
				return dllfunc(DLLFunc_Use,Index,id);
			
			new Array:CurArray = ArrayGetCell(g_PropertyArray,Property),AuthID[36]
			get_user_authid(id,AuthID,35);
			
			ArrayGetString(CurArray,3,Classname,35);
			
			if(equali(Classname,AuthID))
			{
				g_CurProp[id] = Index
				ArrayGetString(CurArray,1,Classname,35);
				
				formatex(g_Menu,255,"%s Info",Classname);
				
				menu_setprop(g_PropMenu,MPROP_TITLE,g_Menu);
				menu_display(id,g_PropMenu);
			}
			else if(ArrayGetCell(CurArray,8) & (1<<(id - 1)) || ArrayGetCell(CurArray,6) & g_UserAccess[id] || !ArrayGetCell(CurArray,5))
			{
				client_print(id,print_chat,"[DRP] You used the door.");
				dllfunc(DLLFunc_Use,Index,id);
			}
			else
			{
				// Doorbell wont ring for property's with "hard access" letters assigned to them
				// like the police station and such
				
				new AccessStr[JOB_ACCESSES + 1]
				DRP_IntToAccess(ArrayGetCell(CurArray,6),AccessStr,JOB_ACCESSES);
				
				new bool:Hard
				for(new Count;Count < sizeof(g_HardAccess);Count++)
				{
					get_pcvar_string(g_HardAccess[Count],g_Query,4095);
					if(equali(g_Query,AccessStr))
					{
						Hard = true
						break
					}
				}
				
				new const Float:Time = get_gametime();
				if(Hard)
					client_print(id,print_chat,"[DRP] You do not have keys to this door.");
				else if(Time - g_DoorBellTime[id] > 5.0 && g_DoorBellTime[id])
				{
					client_print(id,print_chat,"[DRP] The door is locked; you rang the doorbell.");
					g_DoorBellTime[id] = Time
					emit_sound(Index,CHAN_AUTO,g_DoorBellSound,0.5,ATTN_NORM,0,PITCH_NORM);
				}
			}
			
			return FMRES_HANDLED
		}
		
		else if(equali(Classname,g_szNPCName))
			return _CallNPC(id,Index);
		
		// HACK HACK:
		// We use the DRP Event system for some plugins (IE: In DRPDrugs.amxx when we "use" our plants. This is easier the putting a prethink function there)
		else
		{
			new Data[2]
			Data[0] = id
			Data[1] = Index
			
			if(_CallEvent("Player_UseEntity",Data,2))
			{
				return FMRES_IGNORED
			}
		}
	}
	
	// We are not looking at an entity
	// Check around us
	
	static EntList[1]
	if(find_sphere_class(id,g_szNPCName,50.0,EntList,1))
	{
		new const Ent = EntList[0],SkipTraceCheck = pev(Ent,pev_iuser2);
		
		// FROM DRPNPC.AMXX
		// iUser2 = Skip TraceLine
		if(SkipTraceCheck)
			return _CallNPC(id,Ent);
		else if(is_visible(id,Ent))
			return _CallNPC(id,Ent);
	}
	
	else if(find_sphere_class(id,g_szItem,40.0,EntList,1))
	{
		new const Ent = EntList[0]
		pev(Ent,pev_noise,Classname,35);
		
		new const ItemID = UTIL_FindItemID(Classname),Num = pev(Ent,pev_iuser2)
		
		if(!UTIL_ValidItemID(ItemID))
		{
			client_print(id,print_chat,"[DRP] Invalid Item in the Item Drop. Deleteing..");
			engfunc(EngFunc_RemoveEntity,Ent);
			
			return FMRES_HANDLED;
		}
		
		UTIL_SetUserItemNum(id,ItemID,UTIL_GetUserItemNum(id,ItemID) + Num);
		
		client_cmd(id,"spk ^"items/ammopickup1.wav^"");
		client_print(id,print_chat,"[DRP] You have picked up %d x %s%s.",Num,Classname,Num == 1 ? "" : "s");
		
		engfunc(EngFunc_RemoveEntity,Ent);
		return FMRES_HANDLED
	}
	else if(find_sphere_class(id,g_szMoneyPile,40.0,EntList,1))
	{
		new const Ent = EntList[0],Amount = pev(Ent,pev_iuser3);
		new Data[2]
		
		g_UserWallet[id] += Amount
		client_print(id,print_chat,"[DRP] You have picked up $%d dollar%s.",Amount,Amount == 1 ? "" : "s");
		
		Data[0] = pev(Ent,pev_owner);
		Data[1] = id
		
		if(_CallEvent("Player_PickupCash",Data,2))
			return FMRES_HANDLED
		
		engfunc(EngFunc_RemoveEntity,Ent);
		return FMRES_HANDLED
	}
	return FMRES_IGNORED
}
PrintDisplay(const id,const Index)
{
	static Classname[36],Message[256]
	
	// NPC Viewing
	if(!Index)
	{
		if(find_sphere_class(id,g_szNPCName,40.0,Classname,1))
		{
			new const Ent = Classname[0]
			pev(Ent,pev_noise1,Classname,63);
			
			formatex(Message,255,"NPC: %s^nPress use (default e) to use",Classname);
			client_print(id,print_center,"%s",Message);
		}
	}
	else
	{
		pev(Index,pev_classname,Classname,35);
		
		if(containi(Classname,g_FuncDoor) != -1)
		{
			new DoorArray
			pev(Index,pev_targetname,Classname,35);
			
			new const Property = UTIL_GetProperty(Classname,Index,DoorArray);
			if(Property != -1)
			{
				new Data[2]
				Data[0] = id
				Data[1] = Property + 1
				
				if(_CallEvent("Print_PropDisplay",Data,2) != PLUGIN_HANDLED)
				{
					new CMessage[128],Name[33],Temp[26]
					new const Array:CurArray = ArrayGetCell(g_PropertyArray,Property),Price = ArrayGetCell(CurArray,4);
					
					new Locked = (ArrayGetCell(CurArray,5) && ArrayGetCell(Array:ArrayGetCell(g_DoorArray,DoorArray),4)) ? 1 : 0
					
					ArrayGetString(CurArray,1,Name,32);
					ArrayGetString(CurArray,2,Classname,35);
					ArrayGetString(CurArray,10,CMessage,127);
					
					if(Price)
						formatex(Temp,25,"Price: $%d",Price);
					
					formatex(Message,255,"%s^nOwner: %s%s^n%s^n%s^n%s",Name[0] ? Name : "",Classname[0] ? Classname : "N/A",
					Price ? " (Selling)" : "",
					Locked ? "Locked" : "Unlocked",
					Price ? Temp : "",
					CMessage[0] ? CMessage : "");
					
					client_print(id,print_center,"^n^n^n^n^n^n^n^n^n^n^n^n^n%s",Message)
				}
			}
		}
		else if(equali(Classname,g_szNPCName))
		{
			pev(Index,pev_noise1,Classname,63);
			
			// We might want to use a HUD (HUD_EXTRA) Message for this
			// Down the line
			
			formatex(Message,255,"NPC: %s^nPress use (default e) to use",Classname);
			client_print(id,print_center,"%s",Message);
		}
	}
	
	if(!g_HudPending)
	{ 
		g_Display[id] = 0; 
		set_task(1.6,"ResetDisplay",id);
	}
}
public ResetDisplay(id)
	g_Display[id] = 1

// TODO:
// Update to use the doors "master lock" feature
public forward_Touch(const EntTouched,const EntToucher)
{
	if(!EntTouched || !EntToucher)
		return FMRES_IGNORED
	
	static Classname[24]
	pev(EntToucher,pev_classname,Classname,23);
	
	if(!equali(Classname,"player"))
		return FMRES_IGNORED
	
	pev(EntTouched,pev_classname,Classname,23);
	
	if(containi(Classname,g_FuncDoor) == -1)
		return FMRES_IGNORED
	
	pev(EntTouched,pev_targetname,Classname,23);
	
	new DoorArray
	new const Property = UTIL_GetProperty(Classname,_,DoorArray);
	
	if(Property == -1)
		return FMRES_IGNORED
	
	new Locked = (ArrayGetCell(Array:ArrayGetCell(g_PropertyArray,Property),5) && ArrayGetCell(Array:ArrayGetCell(g_DoorArray,DoorArray),4)) ? 1 : 0
	if(!Locked)
	{
		dllfunc(DLLFunc_Use,EntTouched,EntToucher);
	}
	
	return FMRES_HANDLED
}

public _HandleProperty(id,Menu,Item)
{
	if(Item == MENU_EXIT || !g_CurProp[id])
		return PLUGIN_HANDLED
	
	switch(Item)
	{
		case 0: dllfunc(DLLFunc_Use,g_CurProp[id],id);
		case 1: CmdPropertyInfo(id,g_CurProp[id]);
		case 2:
		{
		}
	}
	
	g_CurProp[id] = 0
	return PLUGIN_HANDLED
}
/*==================================================================================================================================================*/
// Events
public EventDeathMsg()
{
	new const id = read_data(2);
	
	if(!id)
		return PLUGIN_HANDLED
	
	g_UserHunger[id] = 0
	DeathScreen(id);
	
	return PLUGIN_CONTINUE
}
public EventResetHUD(id)
	set_task(1.0,"ForwardWelcome",id);

public DeathScreen(id)
{
	if(is_user_alive(id))
	{
		// Hack to clear the screen
		message_begin(MSG_ONE_UNRELIABLE,gmsgTSFade,_,id);
		
		write_short(0);
		write_short(0);
		write_short(FFADE_STAYOUT);
		
		write_byte(0);
		write_byte(0);
		write_byte(0);
		write_byte(0);
		
		message_end();
		return
	}
	
	message_begin(MSG_ONE_UNRELIABLE,gmsgTSFade,_,id);
	
	write_short(~0);
	write_short(~0);
	write_short(FFADE_STAYOUT);
	
	write_byte(0);
	write_byte(0);
	write_byte(0);
	write_byte(255);
	
	message_end();
	
	set_task(1.0,"DeathScreen",id);
}

public EventWpnInfo(const id)
{
	if(!is_user_connected(id) || is_user_bot(id))
		return
	
	g_UserWpnID[id][0] = read_data(1);
	g_UserWpnID[id][1] = read_data(2);
	g_UserWpnID[id][2] = read_data(3);
	g_UserWpnID[id][3] = read_data(4);
	g_UserWpnID[id][4] = read_data(5);
}

public EventTakeDamage(id,inflictor,attacker,Float:damage,Bits)
{
	if(get_pcvar_num(p_FallingDamage))
		return HAM_IGNORED
	
	if(Bits & DMG_FALL)
		return HAM_SUPERCEDE
	
	return HAM_IGNORED
}

public ForwardWelcome(const id)
{
	if(!g_Joined[id])
		WelcomeMsg(id);
	
	DeathScreen(id);
}

WelcomeMsg(id)
{
	if(!is_user_alive(id))
		return
	
	new Data[1]
	Data[0] = id
	
	_CallEvent("Player_Spawn",Data,1);
	
	// Name checking
	new Temp[64],Flag = 0
	get_user_name(id,Temp,63);
	
	if(fw_SetKeyValue(id,"","name",Temp) == FMRES_SUPERCEDE)
		Flag = 1
	
	get_user_authid(id,Temp,63);
	
	if(containi(Temp,"PENDING") != -1 || containi(Temp,"LAN") != -1 || equali(Temp,"STEAM_0:0"))
	{
		client_print(id,print_chat,"[DRP] Your SteamID (%s) is Invalid. Your user data will not be saved.",Temp);
		client_print(id,print_chat,"[DRP] Please try re-connecting.");
		
		client_print(id,print_console,"^n---------^n[DRP - WARNING]^nDRP WILL NOT SAVE YOUR DATA YOUR - STEAMID IS INVALID.^nPLEASE TRY RE-CONNECTING^n---------^n");
		return // stop - we don't want to show any more messages
	}
	
	g_Joined[id] = true
	
	if(g_BadJob[id])
	{
		client_print(id,print_chat,"[DRP] ** Notice: Your job no longer exists. Please contact an administrator.");
		client_print(id,print_chat,"[DRP] ** You have been temporarily set back to Unemployed.");
		return // stop - we don't want to show any more messages
	}
	
	client_print(id,print_console,"-------------------------------------------^nDRP is based from/on ARP. The features you see, are features of ARP.");
	client_print(id,print_console,"www.apollorp.org | http://drp.hopto.org^n-------------------------------------------");
	
	// Name is more important
	if(Flag)
		return
	
	new Message[128]
	
	for(new Count;Count < 2;Count++)
	{
		get_pcvar_string(p_Welcome[Count],Message,127);
		
		if(containi(Message,"#name#") != -1)
		{
			get_user_name(id,Temp,63);
			replace_all(Message,127,"#name#",Temp);
		}
		if(containi(Message,"#hostname#") != -1)
		{
			get_pcvar_string(p_Hostname,Temp,63);
			replace_all(Message,127,"#hostname#",Temp);
		}
		
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
		new Name[33]
		get_plugin(Plugin,_,_,Name,32);
		
		DRP_Log("[NPCUse] Unable to find function in plugin. (Function: %s - Plugin: %s)",Handler,Name);
		return FAILED
	}
	DestroyForward(Forward);
	
	return SUCCEEDED
}
ItemUse(id,ItemID,UseUp)
{
	if(!UTIL_ValidItemID(ItemID))
		return FAILED
	
	static Handler[33]
	
	new const Array:CurArray = ArrayGetCell(g_ItemsArray,ItemID),Plugin = ArrayGetCell(CurArray,2);
	new Val1,Val2,Val3
	
	ArrayGetString(CurArray,3,Handler,32);
	
	Val1 = ArrayGetCell(CurArray,8);
	Val2 = ArrayGetCell(CurArray,9);
	Val3 = ArrayGetCell(CurArray,10);
	
	new Forward = CreateOneForward(Plugin,Handler,FP_CELL,FP_CELL,FP_CELL,FP_CELL,FP_CELL),Return
	if(Forward <= 0 || !ExecuteForward(Forward,Return,id,ItemID,Val1,Val2,Val3))
	{
		DRP_Log("[ItemUse] Unable to find function in plugin. (Function: %s)",Handler);
		return FAILED
	}
	DestroyForward(Forward);
	
	// Tip
	DRP_ShowToolTip(id,"ItemUse");
	
	// We want to keep this item.
	if(Return == ITEM_KEEP_RETURN) 
		return SUCCEEDED
	
	// If disposable
	if(UseUp && ArrayGetCell(CurArray,5))
		UTIL_SetUserItemNum(id,ItemID,UTIL_GetUserItemNum(id,ItemID) - 1);
	
	return SUCCEEDED
}
/*==================================================================================================================================================*/
// Dynamic Natives
public plugin_natives()
{
	// First array created - because of a werid error, this is gonna be zero-d out
	g_Fix = TravTrieCreate();
	
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
	register_native("DRP_TSGiveUserWeapon","_DRP_TSGiveUserWeapon");
	
	register_native("DRP_IsCop","_DRP_IsCop");
	register_native("DRP_IsAdmin","_DRP_IsAdmin");
	register_native("DRP_IsMedic","_DRP_IsMedic");
	register_native("DRP_IsJobAdmin","_DRP_IsJobAdmin");
	register_native("DRP_IsVIP","_DRP_IsVIP");
	
	register_native("DRP_UserDisplay","_DRP_UserDisplay");
	
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
	register_native("DRP_FindJobID2","_DRP_FindJobID2");
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
	
	register_native("DRP_ItemInfo","_DRP_ItemInfo");
	
	register_native("DRP_GetUserItemNum","_DRP_GetUserItemNum");
	register_native("DRP_SetUserItemNum","_DRP_SetUserItemNum");
	register_native("DRP_GetUserTotalItems","_DRP_GetUserTotalItems");
	register_native("DRP_ForceUseItem","_DRP_ForceUseItem");
	register_native("DRP_FetchUserItems","_DRP_FetchUserItems");
	
	register_native("DRP_GetUserPass","_DRP_GetUserPass");
	register_native("DRP_SetUserPass","_DRP_SetUserPass");
	
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
	register_native("DRP_PropertyGetAccess","_DRP_PropertyGetAccess");
	
	register_native("DRP_PropertyGetMessage","_DRP_PropertyGetMessage");
	register_native("DRP_PropertySetMessage","_DRP_PropertySetMessage");
	register_native("DRP_PropertyGetLocked","_DRP_PropertyGetLocked");
	register_native("DRP_PropertySetLocked","_DRP_PropertySetLocked");
	register_native("DRP_PropertyDoorGetLocked","_DRP_PropertyDoorGetLocked");
	register_native("DRP_PropertyDoorSetLocked","_DRP_PropertyDoorSetLocked");
	
	register_native("DRP_PropertyGetProfit","_DRP_PropertyGetProfit");
	register_native("DRP_PropertySetProfit","_DRP_PropertySetProfit");
	register_native("DRP_PropertyGetPrice","_DRP_PropertyGetPrice");
	register_native("DRP_PropertySetPrice","_DRP_PropertySetPrice");
	
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
	
	// Fatal
	if(get_param(1))
		UTIL_Error(0,1,"",Plugin);
	
	vdformat(g_Query,4095,2,3);
	
	return UTIL_DRP_Log(Plugin,g_Query);
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
	
	new Handle:Tuple = Handle:get_param(1),Handler[64],Data[256],Len = min(255,get_param(5))
	get_string(2,Handler,63);
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
// 1 = HOUR:MINUTE AM/PM (MONTH/DAY/YEAR)
// 2 = Hour only
// 3 = Minute Only
// 4 = date() = "year month day"
public _DRP_GetWorldTime(Plugin,Params)
{
	if(Params != 3)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected 3, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new const Len = get_param(2),Mode = get_param(3);
	
	switch(Mode)
	{
		// HOUR:MINUTE AM/PM (MONTH/DAY/YEAR)
		case 1:
		formatex(g_Menu,255,"%d:%s%d %s (%d/%d/%d)",g_WorldTime[2],g_WorldTime[1] < 10 ? "0" : "",
		g_WorldTime[1],g_WorldTime[3] ? "AM" : "PM",g_WorldTime[4],g_WorldTime[5],g_WorldTime[6]);
		case 2:
		formatex(g_Menu,255,"%d",g_WorldTime[2]);
		case 3:
		formatex(g_Menu,255,"%d",g_WorldTime[1]);
		case 4:
		formatex(g_Menu,255,"%d %d %d",g_WorldTime[6],g_WorldTime[4],g_WorldTime[5]);
		
		default:
		return FAILED
	}
	
	set_string(1,g_Menu,Len);
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
public _DRP_TSGetUserWeaponID(Plugin,Params)
{
	if(Params < 1)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected 1 or more, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new const id = get_param(1);
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
	
	new TSGun = ts_get_user_tsgun(id);
	if(!TSGun)
		return FAILED
	
	if(WeaponID == 24 || WeaponID == 25 || WeaponID == 35)
	{
		set_pdata_int(TSGun,41,Ammo);
		set_pdata_int(TSGun,839,Ammo);
		
		Ammo = 0
	}
	else
	set_pdata_int(TSGun,tsweaponoffset[WeaponID],Ammo);
	
	message_begin(MSG_ONE_UNRELIABLE,gmsgWeaponInfo,_,id);
	write_byte(WeaponID);
	write_byte(g_UserWpnID[id][1]);
	
	write_short(Ammo)
	
	write_byte(g_UserWpnID[id][3]);
	write_byte(g_UserWpnID[id][4]);
	
	message_end();
	
	return SUCCEEDED
}
public _DRP_TSGiveUserWeapon(Plugin,Params)
{
	if(Params < 1)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected 1 or more, Found: %d",Plugin,Params);
		return FAILED
	}
	new id = get_param(1),WeaponID = get_param(2),ExtraClip = get_param(3),Flags = get_param(4);
	if(!is_user_alive(id) || (WeaponID > 36 || !WeaponID))
		return FAILED
	
	new Weapon = create_entity("ts_groundweapon");
	if(!Weapon)
		return FAILED
	
	new Temp[12]
	formatex(Temp,11,"%d",WeaponID);
	
	DispatchKeyValue(Weapon,"tsweaponid",Temp);
	DispatchKeyValue(Weapon,"wduration","180");
	
	formatex(Temp,11,"%d",ExtraClip);
	DispatchKeyValue(Weapon,"wextraclip",Temp);
	
	formatex(Temp,11,"%d",Flags);
	DispatchKeyValue(Weapon,"spawnflags",Temp);
	
	DispatchSpawn(Weapon);
	dllfunc(DLLFunc_Use,Weapon,id);
	
	engfunc(EngFunc_RemoveEntity,Weapon);
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
	
	new const id = get_param(1);
	
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
	
	new const id = get_param(1);
	return UTIL_IsUserAdmin(id);
}
public _DRP_IsMedic(Plugin,Params)
{
	if(Params != 1)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 1, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new const id = get_param(1);
	
	new StrAccess[JOB_ACCESSES + 1]
	get_pcvar_string(p_MedicAccess,StrAccess,JOB_ACCESSES);
	
	new Access = DRP_AccessToInt(StrAccess);
	
	if(g_UserAccess[id] & Access)
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
public _DRP_IsVIP(Plugin,Params)
{
	if(Params != 1)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 1, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new const id = get_param(1);
	
	new StrAccess[JOB_ACCESSES + 1]
	get_pcvar_string(g_HardAccess[3],StrAccess,JOB_ACCESSES);
	
	new Access = DRP_AccessToInt(StrAccess);
	
	if(g_UserAccess[id] & Access)
		return SUCCEEDED
	
	return FAILED
}
/*==================================================================================================================================================*/
public _DRP_UserDisplay(Plugin,Params)
{
	if(Params != 1)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 1, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new const id = get_param(1);
	if(!is_user_connected(id))
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"User not connected: %d",Plugin,id);
		return FAILED
	}
	return g_Display[id]
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
// TODO: Probably remove
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
	
	new const Total = ( get_user_time(id) / 60 ) + g_UserTime[id]
	return Total
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
	
	return UTIL_ValidJobID(g_UserJobID[id]) ? g_UserJobID[id] + 1 : FAILED
}
public _DRP_SetUserJobID(Plugin,Params)
{
	if(Params != 3)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 2, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new const JobID = get_param(2) - 1,id = get_param(1),Event = get_param(3);
	new OldJobID = g_UserJobID[id]
	
	if(!UTIL_ValidJobID(JobID))
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Invalid JobID %d",Plugin,JobID);
		return FAILED
	}
	
	if(!is_user_connected(id))
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"User not connected: %d",Plugin,id);
		return FAILED
	}
	
	g_UserJobID[id] = JobID
	g_UserAccess[id] = g_AccessCache[id]
	
	new const Array:CurArray = ArrayGetCell(g_JobArray,JobID);
	g_UserSalary[id] = ArrayGetCell(CurArray,2);
	g_UserAccess[id] |= ArrayGetCell(CurArray,3);
	
	// Called after the job is set
	// so we can't stop it - but we sometimes wanna check "DRP_IsCop()" when the event is called
	// and if they were switched to a cop, it would return zero (because it's called before)
	// so let's leave this down here.
	if(Event)
	{
		new Data[3]
		Data[0] = id
		Data[1] = JobID
		Data[2] = OldJobID
		
		if(_CallEvent("Player_ChangeJobID",Data,3))
			return FAILED
	}
	
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
	
	return ArrayGetCell(ArrayGetCell(g_JobArray,JobID),2);
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
		
		ArrayGetString(ArrayGetCell(g_JobArray,Count),1,Name,32);
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
	
	if(Num) 
		set_array(2,Results,min(MaxResults,Num));
	
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
	
	for(new Count = 1;Count < g_ItemsNum && Num < 512;Count++)
	{
		ArrayGetString(ArrayGetCell(g_ItemsArray,Count),1,Name,32);
		
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
	
	if(Num) 
		set_array(2,Results,min(MaxResults,Num));
	
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
public _DRP_FindJobID2(Plugin,Params)
{
	if(Params != 1)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 3, Found: %d",Plugin,Params);
		return FAILED
	}
	new Name[33]
	get_string(1,Name,32);
	
	return UTIL_FindJobID(Name) + 1
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
	
	new Array:CurArray = ArrayCreate(128);
	
	g_CommandNum++
	ArrayPushCell(g_CommandArray,CurArray);
	
	// Backwards Compat.
	ArrayPushCell(CurArray,0);
	
	get_string(1,g_Query,4095);
	ArrayPushString(CurArray,g_Query);
	
	get_string(2,g_Query,4095);
	
	ArrayPushString(CurArray,g_Query);
	ArrayPushCell(CurArray,containi(g_Query,"(ADMIN)") != -1 ? 1 : 0);
	
	return SUCCEEDED
}
public _DRP_AddHudItem(Plugin,Params)
{
	if(Params < 3)
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
	
	if(Channel < 0 || Channel > HUD_NUM)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Invalid HUD Channel: %d",Plugin,Channel);
		return FAILED
	}
	
	static Message[256]
	vdformat(Message,255,3,4);
	
	UTIL_AddHudItem(id,Channel,Message);
	
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
		ArrayGetString(ArrayGetCell(g_JobArray,Results[0]),1,TempName,32);
		
		UTIL_Error(AMX_ERR_NATIVE,0,"A job with a similar name already exists. User input: %s - Existing job: %s",Plugin,Name,TempName)
		return FAILED
	}
	
	new Access[JOB_ACCESSES + 1],Letter[12]
	DRP_IntToAccess(IntAccess,Access,JOB_ACCESSES);
	
	for(new Count;Count < sizeof(g_HardAccess);Count++)
	{
		get_pcvar_string(g_HardAccess[Count],Letter,11);
		if(equali(Access,Letter))
		{
			UTIL_Error(AMX_ERR_NATIVE,0,"Unable to use this access - hard access letter",Plugin);
			return FAILED
		}
	}
	
	format(g_Query,4095,"INSERT INTO %s VALUES ('%s','%d','%s')",g_JobsTable,Name,Salary,Access);
	SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",g_Query);
	
	new Array:CurArray = ArrayCreate(32);
	ArrayPushCell(g_JobArray,CurArray);
	g_JobNum++
	
	// Backwards compat.
	ArrayPushCell(CurArray,0); // 0 - don't use
	
	ArrayPushString(CurArray,Name);
	ArrayPushCell(CurArray,Salary);
	ArrayPushCell(CurArray,IntAccess);
	
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
	
	ArrayGetString(ArrayGetCell(g_JobArray,JobID),1,JobName,35);	
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
	if(Params != 3)
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
	new Data[2]
	Data[0] = id
	Data[1] = Access
	
	if(!_CallEvent("Player_SetAccess",Data,2))
		return FAILED
	
	g_UserAccess[id] = Access
	g_UserAccess[id] |= ArrayGetCell(ArrayGetCell(g_JobArray,g_UserJobID[id]),3);
	
	get_param(3) == 1 ? 
	(g_AccessCache[id] |= Access) : (g_AccessCache[id] = Access)
	
	
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
	
	return ArrayGetCell(ArrayGetCell(g_JobArray,JobID),3);
}
public _DRP_RegisterItem(Plugin,Params)
{
	if(Params < 6)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 6 or more, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new Name[33],Handler[33],Description[128]
	get_string(1,Name,32);
	get_string(2,Handler,32);
	get_string(3,Description,127);
	
	new Len = strlen(Name);
	if(!Len)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Item name must have a length.",Plugin);
		return FAILED
	}
	
	new Array:CurArray = ArrayCreate(128);
	ArrayPushCell(g_ItemsArray,CurArray);
	g_ItemsNum++
	
	// Backwards Compat.
	ArrayPushCell(CurArray,0); // 0 - don't use
	
	ArrayPushString(CurArray,Name); // 1
	ArrayPushCell(CurArray,Plugin); // 2
	ArrayPushString(CurArray,Handler); // 3
	ArrayPushString(CurArray,Description); // 4
	
	ArrayPushCell(CurArray,get_param(4) ? 1 : 0); // Use up? // 5
	ArrayPushCell(CurArray,get_param(5) ? 1 : 0); // Droppable? // 6
	ArrayPushCell(CurArray,get_param(6) ? 1 : 0); // Giveable? // 7
	
	new Values[3]
	Values[0] = get_param(7);
	Values[1] = get_param(8);
	Values[2] = get_param(9);
	
	// We have to push them, even if they are blank
	// so we can keep the index's correctly.
	ArrayPushCell(CurArray,Values[0]); // 8
	ArrayPushCell(CurArray,Values[1]); // 9
	ArrayPushCell(CurArray,Values[2]); // 10
	
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
	
	return UTIL_SetUserItemNum(id,ItemID,ItemNum)
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
	
	return TravTrieSize(g_UserItemArray[id]);
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
	
	new Num,ItemID,Size = TravTrieSize(g_UserItemArray[id]) + 1
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

public _DRP_GetUserPass(Plugin,Params)
{
	if(Params != 3)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 3, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new const id = get_param(1);
	if(!is_user_connected(id))
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"User not connected: %d",Plugin,id);
		return FAILED
	}
	
	// DEFAULT_PASS = the password the server sets (-1)
	if(!g_UserPass[id][0] || equali(g_UserPass[id],DEFAULT_PASS))
		return -1
	
	set_string(2,g_UserPass[id],get_param(3));
	
	// Update SQL now
	new AuthID[36]
	get_user_authid(id,AuthID,35);
	
	formatex(g_Query,4095,"UPDATE `users` SET `PlayerPass`='%s' WHERE `SteamID`='%s'",g_UserPass[id],AuthID);
	SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",g_Query);
	
	return SUCCEEDED
}
public _DRP_SetUserPass(Plugin,Params)
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
	
	new szPassword[33]
	get_string(2,szPassword,32);
	
	if(!szPassword[0])
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"NULL Password (%s)",Plugin,szPassword);
		return FAILED
	}
	
	copy(g_UserPass[id],32,szPassword);
	return FAILED
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
	if(Params < 2)
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
	
	new UserID = get_param(3);
	if(UserID)
	{
		velocity_by_aim(UserID,300,Origin);
		set_pev(Ent,pev_velocity,Origin);
		set_pev(Ent,pev_owner,UserID);
	}
	
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
public _DRP_ItemInfo(Plugin,Params)
{	
	if(Params != 2)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 2, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new const id = get_param(1),ItemID = get_param(2);
	ItemInfo(id,ItemID);
	
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
	
	new travTrieIter:Iter = GetTravTrieIterator(g_EventTrie),Event[64],Handler[128],Key[128],Dummy[2]
	get_string(1,Event,63);
	get_string(2,Handler,127);
	
	format(Handler,127,"%d|%s",Plugin,Handler);
	
	while(MoreTravTrie(Iter))
	{
		ReadTravTrieKey(Iter,Key,127);
		ReadTravTrieString(Iter,Dummy,1);
		
		// It's okay if the event repeats as multiple plugins can register it
		if(equali(Handler,Key))
		{
			DestroyTravTrieIterator(Iter);
			return FAILED
		}
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
	
	static Name[33]
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
	
	new Name[33],Handler[64]
	get_string(2,Name,32);
	get_string(3,Handler[1],62);
	
	Handler[0] = Plugin
	
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
	
	new InternalName[64],ExternalName[64],OwnerName[33],OwnerAuth[36],Price,Access,Profit,Locked,AccessStr[JOB_ACCESSES + 1]
	get_string(1,InternalName,63);
	get_string(2,ExternalName,63);
	get_string(3,OwnerName,32);
	get_string(4,OwnerAuth,35);
	
	Price = get_param(5);
	get_string(6,AccessStr,JOB_ACCESSES);
	
	Profit = get_param(7);
	Access = read_flags(AccessStr);
	Locked = get_param(8);
	
	if(UTIL_MatchProperty(InternalName) > -1)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Property already exists: ^"%s^"",Plugin,InternalName);
		return FAILED
	}
	
	new Array:CurArray = ArrayCreate(128);
	ArrayPushCell(g_PropertyArray,CurArray);
	g_PropertyNum++
	
	ArrayPushString(CurArray,InternalName);
	ArrayPushString(CurArray,ExternalName);
	ArrayPushString(CurArray,OwnerName);
	ArrayPushString(CurArray,OwnerAuth);
	
	ArrayPushCell(CurArray,Price);
	ArrayPushCell(CurArray,Locked);
	ArrayPushCell(CurArray,Access);
	ArrayPushCell(CurArray,Profit);
	ArrayPushCell(CurArray,0);
	ArrayPushCell(CurArray,1);
	
	ArrayPushString(CurArray,"");
	
	format(g_Query,4095,"INSERT INTO %s VALUES ('%s','%s','%s','%s','%d','%s','%d','','%d')",g_PropertyTable,InternalName,ExternalName,OwnerName,OwnerAuth,Price,AccessStr,Profit,Locked);
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
	
	new InternalName[33],FetchInternalName[33],Array:CurArray,Array:NextArray,Array:PropArray = ArrayGetCell(g_PropertyArray,Property);
	ArrayGetString(PropArray,0,InternalName,32);
	
	new NextInternalName[64],ExternalName[64],OwnerName[33],OwnerAuth[36]
	for(new Count = Property;Count < g_PropertyNum - 1;Count++)
	{
		NextArray = ArrayGetCell(g_PropertyArray,Count + 1);
		
		ArrayGetString(NextArray,0,NextInternalName,63);
		ArrayGetString(NextArray,1,ExternalName,63);
		ArrayGetString(NextArray,2,OwnerName,32);
		ArrayGetString(NextArray,3,OwnerAuth,35);
		
		CurArray = ArrayGetCell(g_PropertyArray,Count);
		
		ArraySetString(CurArray,0,NextInternalName);
		ArraySetString(CurArray,1,ExternalName);
		ArraySetString(CurArray,2,OwnerName);
		ArraySetString(CurArray,3,OwnerAuth);
		ArraySetCell(CurArray,4,ArrayGetCell(NextArray,4));
		ArraySetCell(CurArray,5,ArrayGetCell(NextArray,5));
		ArraySetCell(CurArray,6,ArrayGetCell(NextArray,6));
		ArraySetCell(CurArray,7,ArrayGetCell(NextArray,7));
		ArraySetCell(CurArray,8,ArrayGetCell(NextArray,8));
		ArraySetCell(CurArray,9,ArrayGetCell(NextArray,9));
		
		ArraySetCell(g_PropertyArray,Count,NextArray);
	}
	
	ArrayDestroy(PropArray);
	ArrayDeleteItem(g_PropertyArray,--g_PropertyNum);
	
	format(g_Query,4095,"DELETE FROM %s WHERE Internalname='%s'",g_PropertyTable,InternalName);
	UTIL_CleverQuery(g_Plugin,g_SqlHandle,"IgnoreHandle",g_Query);
	
	for(new Count;Count < g_DoorNum;Count++)
	{
		CurArray = ArrayGetCell(g_DoorArray,Count);
		ArrayGetString(g_DoorArray,2,FetchInternalName,32);
		
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
	
	new Array:CurArray = ArrayCreate(32);
	
	ArrayPushCell(g_DoorArray,CurArray);
	g_DoorNum++
	
	ArrayPushString(CurArray,Targetname);
	ArrayPushCell(CurArray,EntID);
	ArrayPushString(CurArray,InternalName);
	ArrayPushCell(CurArray,1);
	ArrayPushCell(CurArray,1); // locked - default: yes - the property will take care of this
	
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
	
	ArrayGetString(ArrayGetCell(g_PropertyArray,Property),0,InternalName,63);
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
	
	ArrayGetString(ArrayGetCell(g_PropertyArray,Property),1,ExternalName,63);
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
	ArraySetString(ArrayGetCell(g_PropertyArray,Property),1,ExternalName);
	
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
	
	ArrayGetString(ArrayGetCell(g_PropertyArray,Property),2,OwnerName,33);
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
	ArraySetString(ArrayGetCell(g_PropertyArray,Property),2,OwnerName);
	
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
	
	ArrayGetString(ArrayGetCell(g_PropertyArray,Property),3,OwnerAuth,33);
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
	ArraySetString(ArrayGetCell(g_PropertyArray,Property),3,OwnerAuth);
	
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
	
	new Array:CurArray = ArrayGetCell(g_PropertyArray,Property);
	ArrayGetString(CurArray,0,InternalName,63);
	
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
			ArraySetCell(CurArray,8,ArrayGetCell(CurArray,8)|(1<<(Index - 1)));
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
	
	new Array:CurArray = ArrayGetCell(g_PropertyArray,Property);
	ArrayGetString(CurArray,0,InternalName,63);
	
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
			ArraySetCell(CurArray,8,ArrayGetCell(CurArray,8) & ~(1<<(Index - 1)))
			break
		}
	}
	
	return SUCCEEDED
}
public _DRP_PropertyGetAccess(Plugin,Params)
{
	if(Params != 1)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 1, Found: %d",Plugin,Params);
		return FAILED
	}
	new Property = get_param(1) - 1
	return ArrayGetCell(ArrayGetCell(g_PropertyArray,Property),6);
	
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
	
	return ArrayGetCell(ArrayGetCell(g_PropertyArray,Property),7);
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
	ArraySetCell(ArrayGetCell(g_PropertyArray,Property),7,max(0,get_param(2)));
	
	return SUCCEEDED
}
public _DRP_PropertyGetPrice(Plugin,Params)
{
	if(Params != 1)
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
	
	return ArrayGetCell(ArrayGetCell(g_PropertyArray,Property),4);
}
public _DRP_PropertySetPrice(Plugin,Params)
{
	if(Params != 2)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 2, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new const Property = get_param(1) - 1,Price = get_param(2)
	if(!UTIL_ValidProperty(Property))
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Property does not exist: %d",Property);
		return FAILED
	}
	
	new Data[2]
	Data[0] = Property + 1
	Data[1] = Price
	
	if(_CallEvent("Property_SetPrice",Data,2))
		return FAILED
	
	ArraySetCell(ArrayGetCell(g_PropertyArray,Property),4,max(0,Price));
	UTIL_PropertyChanged(Property);
	
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
	
	get_string(2,g_Menu,255);
	
	new Len = strlen(g_Menu);
	
	if(Len > 128)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Property message must not be longer than 128 chars. (%d - current length)",Len);
		return FAILED
	}
	
	ArraySetString(ArrayGetCell(g_PropertyArray,Property),10,g_Menu);
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
	
	ArrayGetString(ArrayGetCell(g_PropertyArray,Property),10,g_Menu,255);
	set_string(2,g_Menu,get_param(3));
	
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
		UTIL_Error(AMX_ERR_NATIVE,0,"Property does not exist: %d",Plugin,Property);
		return FAILED
	}
	
	UTIL_PropertyChanged(Property);
	ArraySetCell(ArrayGetCell(g_PropertyArray,Property),5,get_param(2) ? 1 : 0);
	
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
		UTIL_Error(AMX_ERR_NATIVE,0,"Property does not exist: %d",Plugin,Property);
		return FAILED
	}
	
	return ArrayGetCell(ArrayGetCell(g_PropertyArray,Property),5);
}
public _DRP_PropertyDoorSetLocked(Plugin,Params)
{
	if(Params != 2)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 2, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new Index = get_param(1);
	if(!Index || !is_valid_ent(Index))
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Door does not exist: %d",Plugin,Index);
		return FAILED
	}
	
	new TargetName[33],DoorArray
	pev(Index,pev_targetname,TargetName,32);
	
	if(UTIL_GetProperty(TargetName,Index,DoorArray) == -1)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Door not linked to a property.",0);
		return FAILED
	}
	
	UTIL_DoorChanged(DoorArray);
	ArraySetCell(ArrayGetCell(g_DoorArray,DoorArray),4,get_param(2) ? 1 : 0);
	
	return SUCCEEDED
}
public _DRP_PropertyDoorGetLocked(Plugin,Params)
{
	if(Params != 1)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Parameters do not match. Expected: 1, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new Index = get_param(1);
	if(!Index || !is_valid_ent(Index))
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Door does not exist: %d",Plugin,Index);
		return FAILED
	}
	
	new TargetName[33],DoorArray
	pev(Index,pev_targetname,TargetName,32);
	
	if(UTIL_GetProperty(TargetName,Index,DoorArray) == -1)
	{
		UTIL_Error(AMX_ERR_NATIVE,0,"Door not linked to a property.",0);
		return FAILED
	}
	
	return ArrayGetCell(ArrayGetCell(g_DoorArray,DoorArray),4);
}
/*==================================================================================================================================================*/
// Data Layer
/*
public _DRP_ClassLoad(Plugin,Params)
{
//native DRP_ClassLoad(const Class[],const Handler[],Data[],const Table[] = "");
// DRP_ClassLoad("Skills","LoadSkills","AuthID","SkillsMod");
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

formatex(ClassName,127,"%s|%s",Table,Param);
formatex(Temp,127,"%d|%s",Plugin,Handler);

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

new Forward = CreateOneForward(Plugin,Handler,FP_CELL,FP_STRING,FP_STRING,FP_CELL),Return
if(!Forward || !ExecuteForward(Forward,Return,_:CurTrie,ClassHeader,g_Query,0))
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

new iFlag = 0

if(!SQL_NumResults(Query))
	iFlag = 1

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

Forward = CreateOneForward(Plugin,Handler,FP_CELL,FP_STRING,FP_STRING,FP_CELL);
if(Forward <= 0 || !ExecuteForward(Forward,Return,_:CurTrie,Data,g_Query,iFlag))
{
UTIL_Error(AMX_ERR_NATIVE,0,"Could not execute %s forward to %d",0,Handler,Plugin);
return FAILED
}
DestroyForward(Forward);
}

DestroyTravTrieIterator(Iter);
TravTrieDestroy(CallsTrie);

if(g_ClassForward <= 0 || !ExecuteForward(g_ClassForward,Return,_:CurTrie,Data,iFlag))
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

formatex(Temp,127,"%d|%s",Plugin,Handler);
TravTrieGetHCell(CurTrie,"/savetrie",SaveTrie);

get_string(3,g_Query,4095);
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
*/
// End Data Layer
/*==================================================================================================================================================*/
// UTIL Functions
UTIL_Error(Error,Fatal,const Message[],Plugin,any:...)
{
	vformat(g_Query,4095,Message,5);
	
	// Hacky Timestamp
	if(g_PluginEnd)
	{
		format(g_Menu,255," - [TOTAL RUN TIME %d MINUTES]",floatround((get_gametime() / 60.0)));
		add(g_Query,4095,g_Menu);
	}
	
	if(Plugin)
	{
		new Name[64],Filename[64],Temp[2]
		get_plugin(Plugin,Filename,63,Name,63,Temp,1,Temp,1,Temp,1);
		
		if(Error)
			log_error(Error,"[DRP] [PLUGIN: %s - %s ] %s %s",Name,Filename,g_Query,Fatal ? "(Fatal Error)" : "");
		else
		DRP_Log("[DRP] [PLUGIN: %s - %s] %s %s",Name,Filename,g_Query,Fatal ? "(Fatal Error)" : "");
	}
	else
	{
		// If no plugin was sent, we automatically assume the core is calling
		if(Error)
			log_error(Error,"[DRP] [PLUGIN: CORE] %s %s",g_Query,Fatal ? "(Fatal Error)" : "");
		else
		DRP_Log("[DRP] [PLUGIN: CORE] %s %s",g_Query,Fatal ? "(Fatal Error)" : "");
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
		case 0:
		log_amx("[DRP - %s] %s",PluginName,Message);
		case 1:
		{
			new Date[256]
			get_time("%m-%d-%Y",Date,255);
			
			format(Date,255,"%s/%s.log",g_LogDir,Date);
			log_to_file(Date,"[DRP - %s] %s",PluginName,Message);
		}	
		default:
		return FAILED
	}
	
	if(get_pcvar_num(p_LogtoAdmins))
	{
		for(new Count;Count <= g_MaxPlayers;Count++)
			if(UTIL_IsUserAdmin(Count))
				client_print(Count,print_chat,"[DLog: %s] %s",PluginName,Message);
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
	new Targetname[33],InternalName[64],Array:CurArray,Array:NextArray,Array:DoorArray = ArrayGetCell(g_DoorArray,Door);
	ArrayGetString(DoorArray,2,InternalName,63);
	
	format(g_Query,4095,"DELETE FROM %s WHERE Internalname='%s'",g_DoorsTable,InternalName);
	UTIL_CleverQuery(g_Plugin,g_SqlHandle,"IgnoreHandle",g_Query);
	
	for(new Count = Door;Count < g_DoorNum - 1;Count++)
	{
		NextArray = ArrayGetCell(g_DoorArray,Count + 1);
		ArrayGetString(NextArray,0,Targetname,32);
		ArrayGetString(NextArray,2,InternalName,63);
		
		CurArray = ArrayGetCell(g_DoorArray,Count);
		ArraySetString(CurArray,0,Targetname);
		
		ArraySetCell(CurArray,1,ArrayGetCell(NextArray,1));
		ArraySetString(CurArray,2,InternalName);
		
		ArraySetCell(CurArray,3,ArrayGetCell(NextArray,3));
		ArraySetCell(g_DoorArray,Count,NextArray);
	}
	
	ArrayDestroy(DoorArray);
	ArrayDeleteItem(g_DoorArray,--g_DoorNum);
	
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
	ArrayGetString(ArrayGetCell(g_JobArray,JobID),1,Name,32);
	
	format(g_Query,4095,"DELETE FROM %s WHERE JobName='%s'",g_JobsTable,Name);
	UTIL_CleverQuery(g_Plugin,g_SqlHandle,"IgnoreHandle",g_Query);
	
	new Array:JobArray = ArrayGetCell(g_JobArray,JobID);
	ArrayDestroy(JobArray);
	ArraySetCell(g_JobArray,JobID,-1);
	
	return SUCCEEDED
}

UTIL_GetUserItemNum(id,const ItemID)
{
	new TempCheck[2],Result = TravTrieGetStringEx(g_UserItemArray[id],ItemID,TempCheck,1);
	new Value
	
	if(Result)
	{
		static Temp[64]
		TravTrieGetStringEx(g_UserItemArray[id],ItemID,Temp,63);
		Value = str_to_num(Temp);
	}
	
	return Result ? abs(Value) : 0
}

UTIL_GetItemName(ItemID,Name[],Len)
ArrayGetString(ArrayGetCell(g_ItemsArray,ItemID),1,Name,Len);

UTIL_PropertyChanged(Property)
ArraySetCell(ArrayGetCell(g_PropertyArray,Property),9,1);
UTIL_DoorChanged(DoorArray)
ArraySetCell(ArrayGetCell(g_DoorArray,DoorArray),3,1);


UTIL_FindItemID(const ItemName[])
{
	static Name[33]
	for(new Count = 1;Count < g_ItemsNum;Count++)
	{
		ArrayGetString(ArrayGetCell(g_ItemsArray,Count),1,Name,32);
		
		if(equali(Name,ItemName))
			return Count
	}
	return -1
}
UTIL_FindJobID(const JobName[])
{
	static Name[33]
	for(new Count = 0;Count < g_JobNum;Count++)
	{
		ArrayGetString(ArrayGetCell(g_JobArray,Count),1,Name,32);
		
		if(equali(Name,JobName))
			return Count
	}
	return -1
}
UTIL_SetUserItemNum(id,ItemID,Num)
{
	if(!UTIL_ValidItemID(ItemID))
		return FAILED
	
	static ItemName[64]
	
	if(Num)
		formatex(ItemName,32,"%d",Num);
	
	Num ? TravTrieSetStringEx(g_UserItemArray[id],ItemID,ItemName) : TravTrieDeleteKeyEx(g_UserItemArray[id],ItemID);
	
	if(!Num)
	{
		new AuthID[36]
		UTIL_GetItemName(ItemID,ItemName,63);
		replace_all(ItemName,63,"'","\'");
		
		get_user_authid(id,AuthID,35)
		
		format(g_Query,4095,"DELETE FROM %s WHERE authidname='%s|%s'",g_ItemsTable,AuthID,ItemName);
		UTIL_CleverQuery(g_Plugin,g_SqlHandle,"IgnoreHandle",g_Query);
		
		return FAILED
	}
	
	// TODO: MAYBE REMOVE
	// SaveUserItems(id);
	return SUCCEEDED
}

UTIL_GetProperty(const Targetname[] = "",EntID = 0,&DoorArray=0)
{
	static PropertyName[64]
	for(new Count,Array:CurArray;Count < g_DoorNum;Count++)
	{
		CurArray = ArrayGetCell(g_DoorArray,Count);
		ArrayGetString(CurArray,0,PropertyName,63);
		
		if((equali(PropertyName,Targetname) && Targetname[0]) || (EntID && EntID == ArrayGetCell(CurArray,1)))
		{
			ArrayGetString(CurArray,2,PropertyName,63);
			DoorArray = Count
			return UTIL_MatchProperty(PropertyName);
		}
	}
	return -1
}
UTIL_GetDoor(const Targetname[] = "",EntID = 0)
{
	static PropertyTargetname[33]
	for(new Count,Array:CurArray;Count < g_DoorNum;Count++)
	{
		CurArray = ArrayGetCell(g_DoorArray,Count);
		ArrayGetString(CurArray,0,PropertyTargetname,32)
		
		if((equali(PropertyTargetname,Targetname) && Targetname[0]) || (EntID && EntID == ArrayGetCell(CurArray,1)))
			return Count
	}
	
	return FAILED
}
UTIL_MatchProperty(const InternalName[])
{
	static CurName[64]
	for(new Count;Count < g_PropertyNum;Count++)
	{
		ArrayGetString(ArrayGetCell(g_PropertyArray,Count),0,CurName,63);
		if(equali(CurName,InternalName))
			return Count
	}
	return -1
}
UTIL_LoadConfigFile(File)
{
	new Left[128],Right[128]
	while(!feof(File))
	{
		fgets(File,g_Menu,sizeof g_Menu - 1 );
		trim(g_Menu);
		
		if(g_Menu[0] == ';' || (g_Menu[0] == '/' && g_Menu[1] == '/'))
			continue
		
		parse(g_Menu,Left,sizeof Left - 1,Right,sizeof Right - 1)
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
			else if(equal(Left,g_VIPAccessCvar))
				set_pcvar_string(p_VIPAccess,Right);
			
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
			
			else if(equal(Left,g_CVarBreakables))
				set_cvar_num(g_CVarBreakables,str_to_num(Right));
			else if(equal(Left,g_CVarDoors))
				set_cvar_num(g_CVarDoors,str_to_num(Right));
		}
	}
	fclose(File);
}
UTIL_AddHudItem(id,Channel,const Message[])
{
	if(id == -1)
	{
		new iPlayers[32],iNum
		get_players(iPlayers,iNum);
		
		for(new Count;Count < iNum;Count++)
			TravTrieSetCell(g_HudArray[iPlayers[Count]][Channel],Message,Channel);
	}
	else
	TravTrieSetCell(g_HudArray[id][Channel],Message,Channel);
}
public IgnoreHandle(FailState,Handle:Query,const Error[],Errcode,const Data[],DataSize) 
{
	if(FailState == TQUERY_CONNECT_FAILED)
		return DRP_Log("[DRP-CORE] [SQL ERROR] Unable to connect to SQL Database. (Error: %s)",Error ? Error : "UNKNOWN");
	
	else if(FailState == TQUERY_QUERY_FAILED)
	{
		SQL_QueryError(Query,g_Query,4095);
		return DRP_Log("[DRP-CORE] [SQL ERROR] Query Failed. (Error: %s)",g_Query);
	}
	if(Errcode)
		return DRP_Log("[DRP-CORE] [SQL ERROR] %s",Error);
	
	return PLUGIN_CONTINUE
}
UTIL_CleverQuery(PluginGiven,Handle:Tuple,const Handler[],const QueryS[],Data[] = "",Len = 0)
return _DRP_CleverQuery(PluginGiven,Tuple,Handler,QueryS,Data,Len) ? SQL_ThreadQuery(Tuple,Handler,QueryS,Data,Len) : PLUGIN_HANDLED

_CallEvent(const Name[],const Data[],const Length)
{
	static Event[64],Handler[33],Key[128]
	new travTrieIter:Iter = GetTravTrieIterator(g_EventTrie),Plugin,PluginStr[12],Forward,Return,CurArray = PrepareArray(Data,Length);
	
	while(MoreTravTrie(Iter))
	{
		ReadTravTrieKey(Iter,Key,127);
		ReadTravTrieString(Iter,Event,63);
		
		if(!equal(Event,Name))
			continue
		
		strtok(Key,PluginStr,11,Handler,32,'|');
		
		Plugin = str_to_num(PluginStr);
		Forward = CreateOneForward(Plugin,Handler,FP_STRING,FP_ARRAY,FP_CELL);
		
		if(Forward <= 0 || !ExecuteForward(Forward,Return,Event,CurArray,Length))
		{
			DRP_Log("[DRP] [_CALLEVENT] Could not execute forward. Function: %s - Plugin: %d",Handler,Plugin);
			return FAILED
		}
		
		DestroyForward(Forward);
		
		if(Return)
		{
			DestroyTravTrieIterator(Iter);
			return Return
		}
	}
	DestroyTravTrieIterator(Iter);
	
	if(!ExecuteForward(g_EventForward,Return,Name,CurArray,Length))
	{
		DRP_Log("[DRP] [_CALLEVENT] Could not execute Global Event (g_EventForward) forward.");
		return FAILED
	}
	
	return Return
}
_DRP_CleverQuery(Plugin,Handle:Tuple,const Handler[],const QueryS[],Data[] = "",Len = 0)
{
	if(!get_playersnum() || g_PluginEnd)
	{
		new ErrorCode,Handle:SqlConnection = SQL_Connect(Tuple,ErrorCode,g_Menu,255);
		if(SqlConnection == Empty_Handle)
		{
			CleverQueryFunction(Plugin,Handler,TQUERY_CONNECT_FAILED,Empty_Handle,g_Menu,ErrorCode,Data,Len,0.0);
			SQL_FreeHandle(SqlConnection);
			return PLUGIN_CONTINUE
		}
		
		new Handle:Query = SQL_PrepareQuery(SqlConnection,QueryS);
		
		if(!SQL_Execute(Query))
		{
			ErrorCode = SQL_QueryError(Query,g_Menu,255);
			
			SQL_FreeHandle(Query);
			SQL_FreeHandle(SqlConnection);
			
			CleverQueryFunction(Plugin,Handler,TQUERY_QUERY_FAILED,Query,g_Menu,ErrorCode,Data,Len,0.0);
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
		DRP_Log("[DRP CORE] [ERROR] Could not execute forward to %d: %s",PluginGiven,HandlerS);
		return
	}
	DestroyForward(Forward);
}
/*==================================================================================================================================================*/
public client_kill(id)
{
	return PLUGIN_HANDLED
}

public fw_SysError(const Error[])
{ 
	plugin_end(); 
}

public plugin_end()
{
	g_PluginEnd = 1
	SaveData_Forward();
	
	for(new Count,Count2;Count <= g_MaxPlayers;Count++)	
	{
		TravTrieDestroy(g_MenuArray[Count]);
		
		for(Count2 = 0;Count2 < HUD_NUM;Count2++)
			TravTrieDestroy(g_HudArray[Count][Count2])
	}
	
	new Array:Num
	for(new Count;Count < g_CommandNum;Count++)
	{
		Num = ArrayGetCell(g_CommandArray,Count);
		if(Num != Invalid_Array)
			ArrayDestroy(Num);
	}
	for(new Count;Count < g_JobNum;Count++)
	{
		Num = ArrayGetCell(g_JobArray,Count);
		if(Num != Invalid_Array)
			ArrayDestroy(Num);
	}
	for(new Count;Count < g_PropertyNum;Count++)
	{
		Num = ArrayGetCell(g_PropertyArray,Count);
		if(Num != Invalid_Array)
			ArrayDestroy(Num);
	}
	for(new Count;Count < g_DoorNum;Count++)
	{
		Num = ArrayGetCell(g_DoorArray,Count);
		if(Num != Invalid_Array)
			ArrayDestroy(Num);
	}
	
	// Menus
	menu_destroy(g_NameMenu);
	
	// Arrays
	ArrayDestroy(g_JobArray);
	ArrayDestroy(g_CommandArray);
	ArrayDestroy(g_PropertyArray);
	ArrayDestroy(g_DoorArray);
	ArrayDestroy(g_ItemsArray);
	TravTrieDestroy(g_EventTrie);
	
	// Forwards
	DestroyForward(g_HudForward);
	DestroyForward(g_EventForward);
	
	// SQL
	if(g_SqlHandle)
		SQL_FreeHandle(g_SqlHandle);
	
	TravTrieDestroy(g_Fix);
}

/*==================================================================================================================================================*/
// Saving
public SaveData_Forward()
	SaveData();

SaveData()
{
	// The server likes to not restart proper if we call the "Core_Save" event on shutdown
	// This may cause loss of data for plugins. But will only be behind 30seconds (the default save time)
	// Work around?
	
	if(!g_PluginEnd)
		_CallEvent("Core_Save","",0);
	
	static iPlayers[32],Message[128]
	new iNum
	
	get_players(iPlayers,iNum);
	
	for(new Count;Count < iNum;Count++)
		if(g_GotInfo[iPlayers[Count]] >= STD_USER_QUERIES)
			SaveUserData(iPlayers[Count],0);
		
	new InternalName[64],ExternalName[64],OwnerName[33],OwnerAuthid[36],Price,Locked,AccessStr[JOB_ACCESSES + 1],Access,Profit,Array:CurArray,Changed
	for(new Count;Count < g_PropertyNum;Count++)
	{		
		CurArray = ArrayGetCell(g_PropertyArray,Count),Changed = ArrayGetCell(CurArray,9);
		if(!Changed)
			continue
		
		ArrayGetString(CurArray,0,InternalName,63);
		ArrayGetString(CurArray,1,ExternalName,63);
		ArrayGetString(CurArray,2,OwnerName,32);
		ArrayGetString(CurArray,3,OwnerAuthid,32);
		ArrayGetString(CurArray,10,Message,127);
		
		Price = ArrayGetCell(CurArray,4);
		Locked = ArrayGetCell(CurArray,5);
		Access = ArrayGetCell(CurArray,6);
		Profit = ArrayGetCell(CurArray,7);
		
		replace_all(ExternalName,32,"'","\'");
		replace_all(OwnerName,32,"'","\'");
		replace_all(Message,127,"'","\'");
		
		DRP_IntToAccess(Access,AccessStr,JOB_ACCESSES);
		
		format(g_Query,4095,"INSERT INTO %s VALUES ('%s','%s','%s','%s','%d','%s','%d','%s','%d') ON DUPLICATE KEY UPDATE externalname='%s',ownername='%s',ownerauthid='%s',price='%d',access='%s',profit='%d',custommessage='%s',locked='%d'",g_PropertyTable,
		InternalName,ExternalName,OwnerName,OwnerAuthid,Price,AccessStr,Profit,Message,Locked,
		ExternalName,OwnerName,OwnerAuthid,Price,AccessStr,Profit,Message,Locked);
		
		UTIL_CleverQuery(g_Plugin,g_SqlHandle,"IgnoreHandle",g_Query);
		ArraySetCell(CurArray,9,0);
		
		#if defined DEBUG
		g_Querys++
		#endif
	}
	
	for(new Count;Count < g_DoorNum;Count++)
	{
		CurArray = ArrayGetCell(g_DoorArray,Count),Changed = ArrayGetCell(CurArray,3);
		if(!Changed)
			continue
		
		ArrayGetString(CurArray,0,OwnerName,32); // Targetname actually
		Changed = ArrayGetCell(CurArray,1);
		ArrayGetString(CurArray,2,InternalName,32);
		
		Changed ? 
		formatex(OwnerName,32,"e|%d",Changed) : format(OwnerName,32,"t|%s",OwnerName);
		
		Changed = ArrayGetCell(CurArray,4);
		
		format(g_Query,4095,"INSERT INTO %s VALUES ('%s','%s','%d') ON DUPLICATE KEY UPDATE internalname='%s',Locked='%d'",g_DoorsTable,OwnerName,InternalName,Changed,InternalName,Changed);
		UTIL_CleverQuery(g_Plugin,g_SqlHandle,"IgnoreHandle",g_Query);
		
		ArraySetCell(CurArray,3,0);
		
		#if defined DEBUG
		g_Querys++
		#endif
	}
	
	formatex(Message,127,"%d %d %d %d %d %d",
	g_WorldTime[1],g_WorldTime[2],
	g_WorldTime[4],g_WorldTime[5],
	g_WorldTime[6],g_WorldTime[3]);
	
	format(g_Query,4095,"UPDATE `time` SET `CurrentTime`='%s'",Message);
	UTIL_CleverQuery(g_Plugin,g_SqlHandle,"IgnoreHandle",g_Query);
	
	#if defined DEBUG
	g_Querys++
	#endif
}
SaveUserItems(id)
{
	new const Size = TravTrieSize(g_UserItemArray[id]) + 1
	new ItemID,Num
	
	if(Size < 2)
		return
	
	new AuthID[36],ItemName[64]
	get_user_authid(id,AuthID,35);
	
	for(new Count = 1,Success = 1;Count < Size && Success;Count++)
	{
		ItemID = array_get_nth(g_UserItemArray[id],Count,_,Success);
		if(ItemID < 1 || !Success)
			continue
		
		TravTrieGetStringEx(g_UserItemArray[id],ItemID,ItemName,63);
		Num = str_to_num(ItemName);
		
		if(Num < 1)
			continue
		
		UTIL_GetItemName(ItemID,ItemName,63);
		replace_all(ItemName,63,"'","\'");
		
		format(g_Query,4095,"INSERT INTO %s VALUES('%s|%s','%d') ON duplicate KEY UPDATE num='%d'",g_ItemsTable,AuthID,ItemName,abs(Num),abs(Num));
		UTIL_CleverQuery(g_Plugin,g_SqlHandle,"IgnoreHandle",g_Query);
		
		Num = -abs(Num);
	}
	if(g_PluginEnd)
		TravTrieDestroy(g_UserItemArray[id]);
}
SaveUserData(id,Disconnected)
{
	new Data[2]
	Data[0] = id
	Data[1] = Disconnected
	
	get_user_authid(id,g_UserAuthID[id],35);
	
	if(containi(g_UserAuthID[id],"PENDING") != -1 || containi(g_UserAuthID[id],"LAN") != -1)
		return
	
	SaveUserItems(id);
	
	new Access[27],JobRight[27],JobName[33]
	DRP_IntToAccess(g_AccessCache[id],Access,26);
	DRP_IntToAccess(g_UserJobRight[id],JobRight,26);
	
	ArrayGetString(ArrayGetCell(g_JobArray,g_UserJobID[id]),1,JobName,32);
	
	// Player name is updated via the name change menu
	
	new const Time = ( get_user_time(id) / 60 ) + g_UserTime[id]
	
	format(g_Query,4095,"UPDATE %s SET `BankMoney`=%d ,`WalletMoney`=%d ,`JobName`='%s' ,`Hunger`=%d ,`Access`='%s' ,`JobRight`='%s' ,`PlayTime`=%d WHERE `SteamID`='%s'",
	g_UserTable,g_UserBank[id],g_UserWallet[id],JobName,g_UserHunger[id],Access,JobRight,Time,g_UserAuthID[id]);
	
	g_Saving[id] = true
	UTIL_CleverQuery(g_Plugin,g_SqlHandle,"SaveUserDataHandle",g_Query,Data,2);
}
public SaveUserDataHandle(FailState,Handle:Query,const Error[],Errcode,const Data[],DataSize) 
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
_ClearSettings(const id)
{
	new Count = 0,Array:CurArray
	for(Count = 0;Count < g_PropertyNum;Count++)
	{
		CurArray = ArrayGetCell(g_PropertyArray,Count);
		ArraySetCell(CurArray,8,ArrayGetCell(CurArray,8) & ~(1<<(id - 1)));
	}
	
	g_Saving[id] = false
	g_Display[id] = 1
	g_BadJob[id] = false
	g_NameLoad[id] = false
	
	g_UserAccess[id] = 0
	g_AccessCache[id] = 0
	
	g_UserAuthID[id][0] = 0
	g_ConsoleTimeout[id] = 0.0
	g_DoorBellTime[id] = 0.0
	
	TravTrieClear(g_UserItemArray[id]);
	
	for(Count = 0;Count < HUD_NUM;Count++)
		TravTrieClear(g_HudArray[id][Count]);
	
	return PLUGIN_CONTINUE
}
_CreateItemDrop(id = 0,Float:Origin[3],const Num,const ItemName[])
{
	// Just incase
	if(id)
	{
		if(!CheckTime(id))
			return FAILED
		
		new CurrentDrops,AuthID[36],ItemAuth[36]
		get_user_authid(id,AuthID,35);
		
		new ItemNum
		while(( CurrentDrops = engfunc(EngFunc_FindEntityByString,CurrentDrops,"classname",g_szItem)) != 0 )
		{
			pev(CurrentDrops,pev_noise1,ItemAuth,35);
			if(equali(AuthID,ItemAuth))
				ItemNum++
		}
		if(ItemNum >= 3)
		{
			client_print(id,print_chat,"[DRP] You can only drop up to 3 items.");
			return FAILED
		}
	}
	
	new const Ent = engfunc(EngFunc_CreateNamedEntity,engfunc(EngFunc_AllocString,"info_target"));
	if(!Ent)
		return FAILED
	
	set_pev(Ent,pev_classname,g_szItem);
	set_pev(Ent,pev_solid,SOLID_TRIGGER);
	set_pev(Ent,pev_movetype,MOVETYPE_TOSS);
	
	engfunc(EngFunc_SetModel,Ent,g_ItemMdl);
	engfunc(EngFunc_SetSize,Ent,Float:{-2.5,-2.5,-2.5},Float:{2.5,2.5,2.5});
	engfunc(EngFunc_SetOrigin,Ent,Origin);
	
	if(id)
	{
		new AuthID[36]
		get_user_authid(id,AuthID,35);
		
		velocity_by_aim(id,400,Origin);
		
		set_pev(Ent,pev_velocity,Origin);
		set_pev(Ent,pev_noise1,AuthID);
	}
	
	set_pev(Ent,pev_noise,ItemName);
	set_pev(Ent,pev_iuser2,Num);
	
	return SUCCEEDED
}
_CallNPC(const id,const Ent)
{
	new const Plugin = pev(Ent,pev_iuser3);
	new Handler[32],Data[2]
	pev(Ent,pev_noise,Handler,31);
	
	Data[0] = id
	Data[1] = Ent
	
	if(_CallEvent("NPC_Use",Data,2))
		return 0
	
	NPCUse(Handler,Plugin,id,Ent);
	return 1
}
_TSWeaponOffsets()
{
	tsweaponoffset[1] = 50; // Glock18
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
}

/*
// This traces your view, and skips glass, and check if we hit a NPC
// For MecklenburgD Series all NPC's needing a trace (behind a wall of sorts) are now func_illusionary()
// So this isn't needed. And I'm not going to use it. But I'll leave it here.
TraceNPC(id,EntityToIgnore,Float:r[3])
{
new Float:start[3],Float:view_ofs[3];

pev(id,pev_origin,start);
pev(id,pev_view_ofs,view_ofs);

xs_vec_add(start, view_ofs, start);

new Float:dest[3];
pev(id,pev_v_angle,dest);
engfunc(EngFunc_MakeVectors,dest);

global_get(glb_v_forward,dest);
xs_vec_mul_scalar(dest, 9999.0, dest);
xs_vec_add(start, dest, dest);
engfunc(EngFunc_TraceLine,start,dest,IGNORE_GLASS,EntityToIgnore,0);

new EntID = get_tr2(0,TR_pHit);
get_tr2(0,TR_vecEndPos,r);

if(pev_valid(EntID))
{
pev(EntID,pev_classname,g_Menu,255);
if(equali(g_szNPCName,g_Menu))
	return EntID
}

return 0
}
*/


// ArrayX -> TravTrie Stocks
stock array_get_nth(TravTrie:array,nth,start = -1,&success = 0)
{
	if(start) {}
	
	static key[36]
	
	success = TravTrieNth(TravTrie:array,nth - 1,key,35);
	return str_to_num(key);
}