/*
* DRPCore.sma
* -------------------------------------
* Author(s):
* -------------------------------------
* NOTE:
*/

#pragma dynamic 32768

#include <amxmodx>
#include <amxmisc>

#include <engine>
#include <fakemeta>
#include <fun>

#include <sqlx>
#include <regex>

#include <drp/drp_core>
#include <hamsandwich>

// the number of queries that have to be ran successfully for the PLAYER to be considered "loaded"
#define NUM_USER_QUERIES 3

// the number of queries that have to be ran successfully for the SERVER to be considered "loaded"
#define NUM_SERVER_QUERIES 3

new const VERSION[] = "0.2a BETA"
new const g_MonthDays[12] = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};

// SQL Stuff
new Handle:g_SqlHandle
new g_Query[4096]
new g_StartQueries

// Files
new g_ConfigDir[128]
new g_LogDir[128]
new g_HelpDir[128]

// SQL Connection
new const sql_Host[] = "DRP_SQL_Host"
new const sql_DB[] = "DRP_SQL_DB"
new const sql_Pass[] = "DRP_SQL_Pass"
new const sql_User[] = "DRP_SQL_User"

// SQL Tables
new const g_UserTable[] = "users"
new const g_JobsTable[] = "jobs"
new const g_PropertyTable[] = "property"
new const g_KeysTable[] = "property_keys"
new const g_DoorsTable[] = "property_doors"
new const g_ItemsTable[] = "items"
new const g_DataTable[] = "user_data"

// Menus
new g_MenuItemOptions
new g_MenuItemGive
new g_MenuItemDrop
new g_MenuProperty
new g_MenuName

// PCvars
new p_StartMoney
new p_ItemsPerPage
new p_Hostname
new p_Welcome[2]
new p_FLName
new p_FallingDamage
new p_LogtoAdmins
new p_SalaryTime
new p_UnemployedSalary
new p_GameName
new p_GodBreakables
new p_GodDoors
new p_TimeMultiplier

// Arrays
new Array:g_CommandArray
new Array:g_JobArray
new Array:g_ItemsArray
new Array:g_PropertyArray
new Array:g_DoorArray
new Array:g_EventArray
new Array:g_UserHudArray[33][HUD_NUM]
new Array:g_UserAccessArray[33]

// Trie
new Trie:g_UserMenuTrie[33]
new Trie:g_UserItemTrie[33]
new Trie:g_UserDataTrie[33]
new Trie:g_UserSpeedTrie[33]

// This is only true durning the "Menu_Display" event. 
// To block plugins adding menu items outside of the event
new bool:g_MenuAccepting[33]
new g_Menu[256]

new g_CurItem[33]
new g_ItemShow[33]
new g_CurProp[33]

// User Data
new g_UserWallet[33]
new g_UserBank[33]
new g_UserJobID[33]
new g_UserTime[33]
new g_UserAuthID[33][36]

new Float:g_UserMaxSpeed[33]
new Float:g_UserSpeedOverride[33]
new Float:g_ConsoleTimeout[33]
new Float:g_DoorBellTime[33]
new g_UserSpeedOverridePlugin[33]
// [0] = WeaponID
// [1] = Clip
// [2] = Ammo
// [3] = Mode
// [4] = Extra
new g_UserWpnID[33][5]

new gmsgTSFade
new gmsgWeaponInfo

new g_SalaryTime
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
new g_HudObjects[HUD_NUM]
new bool:g_HudPending

// Player Error Checking
new bool:g_Saving[33]
new bool:g_Joined[33]
new g_UserInfoNum[33]
new g_Display[33] = {1, ...}

// Native Forwards
new g_HudForward
new g_EventForward

// Strings
new const g_FuncDoor[] = "func_door"
new const g_RotatingDoor[] = "func_door_rotating"
new const g_Breakables[] = "func_breakable"
new const g_GameName[] = "DRP"

// [0] = Seconds
// [1] = Minutes
// [2] = Hours
// [3] = AM/PM
// [4] = Month
// [5] = Month Day
// [6] = Year
enum _:WORLDTIME
{
	TIME_SEC = 0,
	TIME_MIN,
	TIME_HOURS,
	TIME_AM_PM,
	TIME_MONTH,
	TIME_MONTH_DAY,
	TIME_YEAR
}
new g_WorldTime[WORLDTIME]

// Used for setting ammo
new tsweaponoffset[37];

new g_MaxPlayers

enum REGEX_COMPILED
{
	REGEX_STRIP_SPECIAL = 0,
	REGEX_STEAMID,
	REGEX_NAME
}

new Regex:g_RegexPatterns[REGEX_COMPILED]

// DO NOT EDIT ANYTHING BELOW THIS LINE
// UNLESS YOU KNOW WHAT YOU'RE DOING
public plugin_precache()
{	
	g_Plugin = register_plugin("DRP Core", VERSION, "Trevor 'Drak' - www.odgames.com");
	g_MaxPlayers = get_maxplayers();

	g_RegexPatterns[REGEX_STRIP_SPECIAL] = regex_compile("[^^0-9a-zA-Z]");
	g_RegexPatterns[REGEX_STEAMID] = regex_compile("^^STEAM_0:[01]:\d+$");
	g_RegexPatterns[REGEX_NAME] = regex_compile("^^[a-zA-Z ]+[\s]+[a-zA-Z]+$");
	
	// CVars 
	p_StartMoney = register_cvar("DRP_StartBankCash", "100"); // starting bank
	p_ItemsPerPage = register_cvar("DRP_ItemsPerPage", "30"); // how many items show inside the console
	p_FLName = register_cvar("DRP_StartName", "John Doe"); // require both a first and last name
	p_FallingDamage = register_cvar("DRP_FallingDamage", "1"); // should we take falling damage
	p_LogtoAdmins = register_cvar("DRP_LogToAdmins", "1"); // display logs in chat to admins
	p_SalaryTime = register_cvar("DRP_SalaryPayTime", "15"); // how long (in minutes) users get paid
	p_UnemployedSalary = register_cvar("DRP_UnemployedSalary", "5"); // unemployed job salary
	p_GodBreakables = register_cvar("DRP_GodBreakables", "1"); // unbreakable windows
	p_GodDoors = register_cvar("DRP_GodDoors", "1"); // unbreakable doors
	p_GameName = register_cvar("DRP_GameName","1"); // should we change the games name
	p_TimeMultiplier = register_cvar("DRP_TimeMultiplier", "12"); // Speed the in-game clock by this amount (24hours / multiplier(12) = 2hr days)
	
	p_Hostname = get_cvar_pointer("hostname");
	
	p_Welcome[0] = register_cvar("DRP_Welcome_Msg1", "Welcome #name# to #hostname#");
	p_Welcome[1] = register_cvar("DRP_Welcome_Msg2", "Enjoy your stay");
	
	register_cvar(sql_Host, "", FCVAR_PROTECTED);
	register_cvar(sql_DB, "", FCVAR_PROTECTED);
	register_cvar(sql_Pass, "", FCVAR_PROTECTED);
	register_cvar(sql_User, "", FCVAR_PROTECTED);
	
	new Temp[128]
	for(new Count;Count < _:HUD_NUM;Count++)
	{
		formatex(Temp, 127, "DRP_HUD%d_X", Count + 1);
		p_Hud[Count][X] = register_cvar(Temp, "");
		
		formatex(Temp, 127, "DRP_HUD%d_Y", Count + 1);
		p_Hud[Count][Y] = register_cvar(Temp, "");
		
		formatex(Temp, 127, "DRP_HUD%d_R", Count + 1);
		p_Hud[Count][R] = register_cvar(Temp, "");
		
		formatex(Temp, 127, "DRP_HUD%d_G", Count + 1);
		p_Hud[Count][G] = register_cvar(Temp, "");
		
		formatex(Temp, 127, "DRP_HUD%d_B", Count + 1);
		p_Hud[Count][B] = register_cvar(Temp, "");
	}
	
	if(file_exists(g_drpItemModel))
		precache_model(g_drpItemModel);
	else
	{
		UTIL_Error(_, _, true, "Model Missing: %s", g_drpItemModel);
		return 
	}
	if(file_exists(g_drpMoneyModel))
		precache_model(g_drpMoneyModel);
	else
	{
		UTIL_Error(_, _, true, "Model Missing: %s", g_drpMoneyModel);
		return 
	}
	
	formatex(Temp, 127, "sound/%s", g_drpDoorBellSfx);
	if(file_exists(Temp))
		precache_sound(g_drpDoorBellSfx);
	else
	{
		UTIL_Error(_, _, true, "Sound file missing: %s", g_drpDoorBellSfx);
		return 
	}
	
	get_localinfo("amxx_logs", g_LogDir, 127);
	format(g_LogDir, 127, "%s/DRP", g_LogDir);
	
	if(!dir_exists(g_LogDir))
	{
		if(mkdir(g_LogDir) != 0)
		{
			UTIL_Error(_, _, true, "Unable to create the DRP Log Dir (Folder) (%s)", g_LogDir);
			return
		}
	}
	
	new ConfigFile[128]
	get_mapname(Temp, 127);
	
	// make the map name lower-case
	strtolower(Temp);
	
	get_localinfo("amxx_configsdir", ConfigFile, 127);
	format(g_ConfigDir, 127, "%s/DRP", ConfigFile);
	
	// create main config folder
	if(!dir_exists(g_ConfigDir))
	{
		if(mkdir(g_ConfigDir) != 0)
		{
			UTIL_Error(_, _, true, "Unable to create folder (%s)", g_ConfigDir);
			return
		}
	}
	
	// create map specific folder
	format(Temp, 127, "%s/%s", g_ConfigDir, Temp);
	if(!dir_exists(g_ConfigDir))
	{
		if(mkdir(g_ConfigDir) != 0)
		{
			UTIL_Error(_, _, true, "Unable to create folder (%s)", g_ConfigDir);
			return
		}
	}
	
	// Arrays
	g_CommandArray = ArrayCreate();
	g_JobArray = ArrayCreate();
	g_ItemsArray = ArrayCreate();
	g_PropertyArray = ArrayCreate();
	g_DoorArray = ArrayCreate();
	g_EventArray = ArrayCreate();
	
	for(new Count, Count2;Count <= g_MaxPlayers;Count++)
	{
		g_UserItemTrie[Count] = TrieCreate();
		g_UserMenuTrie[Count] = TrieCreate();
		
		g_UserAccessArray[Count] = ArrayCreate(18);
		g_UserDataTrie[Count] = TrieCreate();
		g_UserSpeedTrie[Count] = TrieCreate();
		
		for(Count2 = 0;Count2 < HUD_NUM;Count2++)
			g_UserHudArray[Count][Count2] = ArrayCreate(64);
	}
	
	new Forward = CreateMultiForward("DRP_RegisterItems", ET_IGNORE), Results
	if(Forward <= 0 || !ExecuteForward(Forward, Results)) 
		UTIL_Error(_, _, true, "Could not execute ^"DRP_RegisterItems^" forward.");
	
	DestroyForward(Forward);
	
	// Forwards
	register_forward(FM_PlayerPreThink, "fw_PreThink");
	register_forward(FM_Touch, "fwTouch");
	register_forward(FM_SetClientKeyValue, "fw_SetKeyValue");
	register_forward(FM_Sys_Error, "fw_SysError");
	register_forward(FM_GetGameDescription, "fw_GameDescription");
	register_forward(FM_SetClientMaxspeed, "fw_ClientMaxSpeed");
	
	// Native Forwards
	g_HudForward = CreateMultiForward("DRP_HudDisplay", ET_IGNORE, FP_CELL, FP_CELL);
	g_EventForward = CreateMultiForward("DRP_Event", ET_STOP2, FP_STRING, FP_ARRAY, FP_CELL);
	
	// Load now, so we have our SQL information
	UTIL_LoadConfigFile();
	
	LoadHelpFiles();
	SQLInit();
	
	TSWeaponOffsets();
}

public plugin_init()
{
	register_cvar("DRP_Version", VERSION, FCVAR_SERVER);
	
	// Old HarbuRP Commands
	// TODO: Remove these commands at some point
	register_clcmd("amx_joblist", "CmdJobList");
	register_clcmd("amx_itemlist", "CmdItemList");
	
	register_clcmd("drp_test", "testfunc");
	
	DRP_RegisterCmd("drp_joblist", "CmdJobList", "Lists all the jobs");
	DRP_RegisterCmd("drp_itemlist", "CmdItemList", "List all the items");
	DRP_RegisterCmd("drp_help", "CmdHelp", "Shows a list of commands you can use");
	
	DRP_RegisterCmd("say /buy", "CmdBuy", "Allows you to activate (use) the NPC/Property you're facing");
	DRP_RegisterCmd("say /items", "CmdItems", "Opens your inventory");
	DRP_RegisterCmd("say /inventory", "CmdItems", "Opens your inventory")
	
	DRP_RegisterCmd("say /menu", "CmdMenu", "Opens a Quick-Access menu");
	DRP_RegisterCmd("say /iteminfo", "CmdItemInfo", "Allows you to view info on the item last shown to you");
	DRP_RegisterCmd("say /propertyinfo", "CmdPropertyInfo", "Displays information about your property");
	
	// Menus
	g_MenuItemOptions = menu_create("", "ItemOptions");
	menu_additem(g_MenuItemOptions, "Use");
	menu_additem(g_MenuItemOptions, "Give");
	menu_additem(g_MenuItemOptions, "Drop");
	menu_additem(g_MenuItemOptions, "Show");
	menu_additem(g_MenuItemOptions, "Examine");
	menu_addblank2(g_MenuItemOptions);
	menu_additem(g_MenuItemOptions, "Go Back");
	
	g_MenuItemGive = menu_create("Give Items", "ItemTransferOptions")
	menu_additem(g_MenuItemGive, "Give 1");
	menu_additem(g_MenuItemGive, "Give 5");
	menu_additem(g_MenuItemGive, "Give 10");
	menu_additem(g_MenuItemGive, "Give 50");
	menu_additem(g_MenuItemGive, "Give All");

	g_MenuItemDrop = menu_create("Drop Items", "ItemTransferOptions")
	menu_additem(g_MenuItemDrop, "Drop 1");
	menu_additem(g_MenuItemDrop, "Drop 5");
	menu_additem(g_MenuItemDrop, "Drop 10");
	menu_additem(g_MenuItemDrop, "Drop 50");
	menu_additem(g_MenuItemDrop, "Drop All");
	
	g_MenuName = menu_create("Name Save", "MenuHandleName");
	menu_additem(g_MenuName, "Yes");
	menu_additem(g_MenuName, "No");
	menu_addtext(g_MenuName, "^nWould you like to save your name?", 0);
	
	g_MenuProperty = menu_create("", "MenuHandleProperty");
	menu_additem(g_MenuProperty, "Use Door");
	menu_additem(g_MenuProperty, "View Property Info");
	menu_additem(g_MenuProperty, "View All My Property");
	
	// Ham is good too
	RegisterHam(Ham_TakeDamage, "player", "EventTakeDamage");
	
	// Events
	register_event("DeathMsg", "EventDeathMsg", "a");
	register_event("ResetHUD", "EventResetHUD", "b");
	register_event("WeaponInfo", "EventWpnInfo", "b");
	
	for(new Count;Count < _:HUD_NUM;Count++)
		g_HudObjects[Count] = CreateHudSyncObj();
	
	// Entity 'Godding'
	new Ent
	new Target[128]
	if(get_pcvar_num(p_GodDoors))
	{	
		while(( Ent = engfunc(EngFunc_FindEntityByString, Ent, "classname", g_RotatingDoor)) != 0)
		{
			pev(Ent, pev_targetname, Target, 127);
			
			// HACK!
			// Mappers can add "DRPNoGod" to windows/doors to override this functionality
			if(equali(Target, "DRPNoGod"))
				continue
			
			set_pev(Ent, pev_takedamage, 0.0);
		}
		
		Ent = 0
		while(( Ent = engfunc(EngFunc_FindEntityByString, Ent, "classname", g_FuncDoor)) != 0)
		{
			pev(Ent, pev_targetname, Target, 127);
			
			// HACK!
			// Mappers can add "DRPNoGod" to windows/doors to override this functionality
			if(equali(Target, "DRPNoGod"))
				continue
			
			set_pev(Ent, pev_takedamage, 0.0);
		}
	}
	if(get_pcvar_num(p_GodBreakables))
	{
		Ent = 0
		while(( Ent = engfunc(EngFunc_FindEntityByString, Ent, "classname", g_Breakables)) != 0)
		{
			pev(Ent, pev_targetname, Target, 127);
			
			// HACK!
			// Mappers can add "DRPNoGod" to windows/doors to override this functionality
			if(equali(Target, "DRPNoGod"))
				continue
			
			set_pev(Ent, pev_takedamage, 0.0);
		}
	}
	
	gmsgTSFade = get_user_msgid("TSFade");
	gmsgWeaponInfo = get_user_msgid("WeaponInfo");
	
	// Tasks
	set_task(1.0, "ShowHud", _, _, _, "b");
	set_task(30.0, "SaveData_Forward", _, _, _, "b");
}

stock DRP_TS_GetUserSlots(const id)
{
	if(!id)
		return FAILED
	
	return get_pdata_int(id, 333);
}

public testfunc(id)
{
	new args[111]
	read_args(args, 110);
	
	trim(args)
	remove_quotes(args)
	
	new num = str_to_num(args);
	for(new Count;Count<num;Count++)
		DoTime()
}

stock DRP_TS_SetUserSlots(const id, const Slots)
{
	if(!id || Slots < 0 || Slots > 100)
		return FAILED
	
	set_pdata_int(id, 333, Slots);
	set_pdata_int(id, 334, Slots);
	
	// Update HUD
	message_begin(MSG_ONE_UNRELIABLE, get_user_msgid("TSSpace"), _, id);
	write_byte(Slots);
	message_end();
	
	return SUCCEEDED
}

#define TE_FIREFIELD                123      // Makes a field of fire
// write_byte(TE_FIREFIELD)
// write_coord(origin)
// write_short(radius) (fire is made in a square around origin. -radius,  -radius to radius,  radius)
// write_short(modelindex)
// write_byte(count)
// write_byte(flags)
// write_byte(duration (in seconds) * 10) (will be randomized a bit)
//
// to keep network traffic low,  this message has associated flags that fit into a byte:
#define TEFIRE_FLAG_ALLFLOAT        1        // All sprites will drift upwards as they animate
#define TEFIRE_FLAG_SOMEFLOAT       2        // Some of the sprites will drift upwards. (50% chance)
#define TEFIRE_FLAG_LOOP            4        // If set,  sprite plays at 15 fps,  otherwise plays at whatever rate stretches the animation over the sprite's duration.
#define TEFIRE_FLAG_ALPHA           8        // If set,  sprite is rendered alpha blended at 50% else,  opaque
#define TEFIRE_FLAG_PLANAR          16       // If set,  all fire sprites have same initial Z instead of randomly filling a cube. 
new gOrigin[3]
public CmdTest(id)
{
	new ent = create_entity("info_target");
	if(ent)
	{
		pev(id, pev_origin, gOrigin);
		
		engfunc(EngFunc_SetOrigin, ent, gOrigin);
		set_pev(ent, pev_classname, "derp");
		engfunc(EngFunc_SetModel, ent, "models/OZDRP/p_drp_moneybag2.mdl");
		set_pev(ent, pev_movetype, MOVETYPE_FOLLOW);
		set_pev(ent, pev_solid, SOLID_BBOX);
		set_pev(ent, pev_aiment, id);
		
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
	read_argv(1, Arg, 32);
	
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
		if(get_pdata_int(TSWeapon, Count) == str_to_num(Arg))
			server_print("%d: %d", Count, get_pdata_int(TSWeapon, Count))
		
	
	new Results[TS_MAX_WEAPONS + 1], Num
	for(new Count;Count < sizeof(Offsets);Count++)
	{
	if(Offsets[Count] <= 0)
		continue
	
	if(get_pdata_int(TSWeapon, Offsets[Count]) > 0)
		Results[Num++] = Count
	}
	server_print("Num: %d", Num);
	*/
}
/*

//	pev->skin = (entityIndex & 0x0FFF) | ((pev->skin&0xF000)<<12); 
//	pev->aiment = g_engfuncs.pfnPEntityOfEntIndex( entityIndex );

//	inline void	SetType( int type ) { pev->rendermode = (pev->rendermode & 0xF0) | (type&0x0F); }
m_pNoise = CBeam::BeamCreate( EGON_BEAM_SPRITE,  55 );
m_pNoise->PointEntInit( pev->origin,  m_pPlayer->entindex() );
m_pNoise->SetScrollRate( 25 );
m_pNoise->SetBrightness( 100 );
m_pNoise->SetEndAttachment( 1 );
m_pNoise->pev->spawnflags |= SF_BEAM_TEMPORARY;
m_pNoise->pev->flags |= FL_SKIPLOCALHOST;
m_pNoise->pev->owner = m_pPlayer->edict();


//	EngFunc_CrosshairAngle, 		// void )		(const edict_t *pClient,  float pitch,  float yaw);
//EngFunc_ParticleEffect, 		// void )		(const float *org,  const float *dir,  float color,  float count);
new Index, Body
get_user_aiming(id, Index, Body, 200);

if(Index)
{
new Class[33], Model[33], Origin[3]
pev(Index, pev_classname, Class, 32);
pev(Index, pev_model, Model, 32);
pev(id, pev_origin, Origin);
client_print(id, print_console, "%s - %s", Class, Model);

new Ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "func_wall"));
if(Ent)
{
engfunc(EngFunc_SetModel, Ent, Model);
engfunc(EngFunc_SetOrigin, Ent, Origin);
dllfunc(DLLFunc_Spawn, Ent);
drop_to_floor(Ent);
client_print(id, print_chat, "hurrr udrr");
}
}

new Float:Origin[3]
pev(id, pev_origin, Origin);

DRP_DropItem(1, 100000, Origin);
DRP_DropCash(10066, Origin);

new lol[33]
new Stuff = array_get_int(g_ItemsArray, 1);
array_get_string(Stuff, 1, lol, 32);
server_print("Stuff: %s", lol);

g_UserHunger[id] = 118

new Ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))
engfunc(EngFunc_SetModel, Ent, "models/pellet.mdl");
engfunc(EngFunc_SetOrigin, Ent, Float:{4096.0, 4096.0, 4096.0});

set_pev(Ent, pev_owner, id);

engfunc(EngFunc_SetView, id, Ent);


new MiscText[1024]

DRP_MiscSetText("fuckyeah", "Dude,  i love tits");
DRP_MiscGetText("fuckyeah", MiscText, 1023);

server_print("GOT STRING: %s", MiscText);


message_begin(MSG_ONE, get_user_msgid("KFuPower"), _, id);
write_byte(42);
message_end();


set_pdata_int(id, 453, 8)//constant for slowpause
set_pdata_int(id, 455, 10)//duration of powerup
set_pdata_int(id, 456, 10)//same
set_pdata_int(id, 457, 8)//same

//fm_set_rendering(id, kRenderFxGlowShell, 10, 15, 45, kRenderNormal, 25.0)
new plModel[64]
get_user_info(id, "model", plModel, 63);

if(!plModel[0])
	return

pev(id, pev_viewmodel2, plModel, 63);
set_pev(id, pev_viewmodel2, "");

new ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"));
if(!ent)
	return

dllfunc(DLLFunc_Spawn, ent);

set_pev(ent, pev_classname, "fakePlayer");
set_pev(ent, pev_movetype, MOVETYPE_FOLLOW);
set_pev(ent, pev_aiment, id);

engfunc(EngFunc_SetModel, ent, plModel);

client_print(id, print_chat, "Model Fake Created");

fm_set_rendering(ent, kRenderFxGlowShell, 10, 15, 45, kRenderNormal, 25.0);

new ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"));
if(!ent)
	return

dllfunc(DLLFunc_Spawn, ent);

set_pev(ent, pev_classname, "fakePlayer");
set_pev(ent, pev_movetype, MOVETYPE_FOLLOW);
set_pev(ent, pev_aiment, id);

engfunc(EngFunc_SetModel, ent, "models/player/gordon/gordon.mdl");

client_print(id, print_chat, "Model Fake Created");

fm_set_rendering(ent, kRenderFxGlowShell, 10, 15, 45, kRenderNormal, 25.0);

//set_entity_visibility(id, 0);
for(new Count;Count <= g_ItemsNum;Count++)
{
server_print("ITEM ID IN ARRAY: %d", g_ItemIDs[Count]);
}
if(UTIL_ValidItemID(100))
	server_print("VALID")
else
server_print("VALIDDDD NO");

dllfunc(DLLFunc_Spawn, 2, 2)
entity_set_int(id, EV_INT_effects, entity_get_int(id, EV_INT_effects) & EF_BRIGHTLIGHT);
entity_set_int(id, EV_INT_effects, entity_get_int(id, EV_INT_effects) & EF_LIGHT);

new Float:speed = get_user_maxspeed(id)
speed -= float(160)
set_user_maxspeed(id, speed)

for(new Count;Count <= g_ItemsNum;Count++)
	client_print(0, print_console, "ITEM: %d", g_ItemIDs[Count]);

if(!pev_valid(FakeWeaponID[id]))
	FakeWeaponID[id] = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))
if(pev_valid(FakeWeaponID[id]))
{
dllfunc(DLLFunc_Spawn,     FakeWeaponID[id])
set_pev(FakeWeaponID[id],    pev_classname,   "FakeWeapon")
set_pev(FakeWeaponID[id],    pev_movetype,     MOVETYPE_FOLLOW)
set_pev(FakeWeaponID[id],    pev_aiment,             id)

client_print(id, print_chat, "YOUUUU GOT THE WEAPON");
}

new weaponstr[32]
pev(id, pev_weaponmodel2, weaponstr, 30);
set_pev(id, pev_weaponmodel2, "");

engfunc(EngFunc_SetModel, FakeWeaponID[id], weaponstr);

//   fm_entity_set_model(FakeWeaponID[id],          weaponstr)  //Apply the weapon stored above to our fake weapon
set_pev(FakeWeaponID[id],    pev_renderfx,   kRenderFxGlowShell)   //Render Away!
set_pev(FakeWeaponID[id],    pev_rendercolor,    {10.0,  115.0,  85.0}) //R,  G,  B
set_pev(FakeWeaponID[id],    pev_rendermode,         kRenderNormal)
set_pev(FakeWeaponID[id],    pev_renderamt,   50.0) 

DRP_DropCash(id, 10);
*/
/*==================================================================================================================================================*/
LoadHelpFiles()
{
	if(g_PluginEnd)
		return
	
	get_localinfo("amxx_configsdir", g_HelpDir, 255);
	add(g_HelpDir, 255, "/DRP/help files");
	
	if(!dir_exists(g_HelpDir))
	{
		if(mkdir(g_HelpDir) != 0)
		{
			UTIL_Error(_, _, true, "Unable to create folder (%s)", g_HelpDir);
			return
		}
	}
	
	new Data[128], File[33]
	new pFile, OpenDIR = open_dir(g_HelpDir, Data, 127);
	
	if(!OpenDIR)
	{
		UTIL_Error(_, _, true, "Failed to browse folder (%s)", g_HelpDir);
		return
	}
	
	new FileLen = 0
	while(next_file(OpenDIR, Data, 127))
	{
		FileLen = 0
		
		// Hard-coded
		if(equali(Data, "Readme.txt"))
			continue
		
		format(Data, 127, "%s/%s", g_HelpDir, Data);
		pFile = fopen(Data, "r");
		
		if(!pFile)
			continue
		
		remove_filepath(Data, Data, 127);
		copy(File, 32, Data);
		
		while(!feof(pFile))
		{
			fgets(pFile, Data, 127);
			FileLen += strlen(Data);
			
			if(FileLen >= 1535)
			{
				UTIL_Error(_, _, false, "File ^"%s^" is to large too show in a MOTD window", File);
				break
			}
		}
		if(containi(File,"-command") != -1)
		{
			replace_all(File, 32, "-command", "");
			
			new Command[64]
			strtok(File, File, 32, Data, 63, '.', 1);
			
			formatex(Command, 63, "say /%s", File);
			strtolower(Command);
			register_clcmd(Command, "CmdMotd");
			
			UTIL_Log(_, "Registered MOTD command: %s", Command);
		}
		fclose(pFile);
	}
	close_dir(OpenDIR);
}
SQLInit()
{
	new sqlHost[36], sqlDB[36], sqlPass[36], sqlUser[36]
	
	get_cvar_string(sql_Host, sqlHost, 35);
	get_cvar_string(sql_DB, sqlDB, 35);
	get_cvar_string(sql_User, sqlUser, 35);
	get_cvar_string(sql_Pass, sqlPass, 35);
	
	if(!sqlHost[0] || !sqlDB[0] || !sqlUser[0] || !sqlPass[0])
		return UTIL_Error(_, _, true, "Missing required SQL connection information" );
	
	g_SqlHandle = SQL_MakeDbTuple(sqlHost, sqlUser, sqlPass, sqlDB);
	
	if(!g_SqlHandle || g_SqlHandle == Empty_Handle)
		return UTIL_Error(_, _, true, "Failed to create SQL tuple.");
	
	formatex(g_Query, 4095, "CREATE TABLE IF NOT EXISTS %s (name VARCHAR(32), salary INT(11), access VARCHAR(12), job_group VARCHAR(12), PRIMARY KEY (name))", g_JobsTable);
	UTIL_CleverQuery(g_Plugin, g_SqlHandle, "IgnoreHandle", g_Query)
	
	// insert default job
	new Salary = get_pcvar_num(p_UnemployedSalary)
	formatex(g_Query, 4095, "INSERT INTO %s (name, salary, access, job_group) VALUES( 'Unemployed', '%d', '', '' ) ON DUPLICATE KEY UPDATE salary='%d'", g_JobsTable, Salary, Salary);
	UTIL_CleverQuery(g_Plugin, g_SqlHandle, "IgnoreHandle", g_Query)
	
	formatex(g_Query, 4095, "CREATE TABLE IF NOT EXISTS %s (name VARCHAR(66), externalname VARCHAR(66), owner VARCHAR(40), ownersteamid VARCHAR(36), price INT(11), access VARCHAR(12), profit INT(11), message TEXT, locked INT, PRIMARY KEY (name))", g_PropertyTable)
	UTIL_CleverQuery(g_Plugin, g_SqlHandle, "IgnoreHandle", g_Query)
	
	formatex(g_Query, 4095, "CREATE TABLE IF NOT EXISTS %s (steamid_name VARCHAR(64), quantity INT(11), PRIMARY KEY (steamid_name))", g_ItemsTable)
	UTIL_CleverQuery(g_Plugin, g_SqlHandle, "IgnoreHandle", g_Query)
	
	formatex(g_Query, 4095, "CREATE TABLE IF NOT EXISTS %s (targetname VARCHAR(36), internalname VARCHAR(66), locked INT, PRIMARY KEY (targetname))", g_DoorsTable);
	UTIL_CleverQuery(g_Plugin, g_SqlHandle, "IgnoreHandle", g_Query);
	
	new originDoorTable[128]
	formatex(originDoorTable, 127, "%s_origin", g_DoorsTable);
	
	formatex(g_Query, 4095, "CREATE TABLE IF NOT EXISTS %s (x FLOAT, y FLOAT, z FLOAT, propertyname VARCHAR(66), locked INT,  PRIMARY KEY (x, y, z))", originDoorTable);
	UTIL_CleverQuery(g_Plugin, g_SqlHandle, "IgnoreHandle", g_Query);
	
	formatex(g_Query, 4095, "CREATE TABLE IF NOT EXISTS %s (steamid_key VARCHAR(64), PRIMARY KEY (steamid_key))", g_KeysTable);
	UTIL_CleverQuery(g_Plugin, g_SqlHandle, "IgnoreHandle", g_Query);
	
	formatex(g_Query, 4095, "CREATE TABLE IF NOT EXISTS %s (steamid_key VARCHAR(64), value TEXT, PRIMARY KEY (steamid_key))", g_DataTable);
	UTIL_CleverQuery(g_Plugin, g_SqlHandle, "IgnoreHandle", g_Query);
	
	formatex(g_Query, 4095, "CREATE TABLE IF NOT EXISTS %s (steamid VARCHAR(36), bank INT(11), wallet INT(11), jobname VARCHAR(33), access TEXT, playtime INT(11), name VARCHAR(36), PRIMARY KEY (steamid))", g_UserTable);
	UTIL_CleverQuery(g_Plugin, g_SqlHandle, "IgnoreHandle", g_Query);
	
	formatex(g_Query, 4095, "CREATE TABLE IF NOT EXISTS `Time` (currenttime VARCHAR(36), PRIMARY KEY (currenttime))");
	UTIL_CleverQuery(g_Plugin, g_SqlHandle, "IgnoreHandle", g_Query);
	
	// Load the Data from the SQL DB
	formatex(g_Query, 4095, "SELECT * FROM %s", g_JobsTable);
	UTIL_CleverQuery(g_Plugin, g_SqlHandle, "FetchJobs", g_Query);
	
	formatex(g_Query, 4095, "SELECT * FROM %s", g_PropertyTable);
	UTIL_CleverQuery(g_Plugin, g_SqlHandle, "FetchProperty", g_Query);
	
	formatex(g_Query, 4095, "SELECT * FROM %s", g_DoorsTable);
	UTIL_CleverQuery(g_Plugin, g_SqlHandle, "FetchDoors", g_Query);
	
	formatex(g_Query, 4095, "SELECT * FROM Time");
	UTIL_CleverQuery(g_Plugin, g_SqlHandle, "FetchWorldTime", g_Query);
	
	return SUCCEEDED
}

CheckQueries()
{
	if(++g_StartQueries < NUM_SERVER_QUERIES)
		return FAILED
	
	return SUCCEEDED
}

public Init()
{
	if(!CheckQueries())
		return FAILED
	
	new Forward = CreateMultiForward("DRP_Init", ET_IGNORE), Return
	if(Forward <= 0 || !ExecuteForward(Forward, Return))
		return UTIL_Error(_, _, true, "Could not execute ^"DRP_Init^" forward.");
	
	DestroyForward(Forward);
	
	// load the config file again, after our modules/plugins created all the commands/cvars
	UTIL_LoadConfigFile(true);
	
	return SUCCEEDED
}

public FetchProperty(FailState, Handle:Query, Error[], Errcode, Data[], DataSize)
{
	if(CheckSQLState(Query, FailState) == FAILED)
		return FAILED
	
	Init();
	
	if(!SQL_NumResults(Query))
		return SUCCEEDED
	
	new Name[128], Message[255], ExternalName[64], Owner[33], OwnerAuthid[36]
	new Access[18]
	
	while(SQL_MoreResults(Query))
	{
		SQL_ReadResult(Query, 0, Name, 127);
		SQL_ReadResult(Query, 1, ExternalName, 63);
		SQL_ReadResult(Query, 2, Owner, 32);
		SQL_ReadResult(Query, 3, OwnerAuthid, 35);
		SQL_ReadResult(Query, 5, Access, 17);
		SQL_ReadResult(Query, 7, Message, 255);
		
		new Price = SQL_ReadResult(Query, 4);
		new Profit = SQL_ReadResult(Query, 6);
		new Locked = SQL_ReadResult(Query, 8);
		
		AddProperty(Name, ExternalName, Owner, OwnerAuthid, Message, Access, Price, Profit, Locked);
		SQL_NextRow(Query);
	}
	return SUCCEEDED
}

CheckSQLState(Handle:Query, FailState, const Error[]="")
{
	if(!strlen(Error))
		SQL_QueryError(Query, g_Query, 4095);
	else
		copy(g_Query, 4095, Error);
	
	switch(FailState)
	{
		case TQUERY_SUCCESS:
			return SUCCEEDED
		case TQUERY_CONNECT_FAILED:
		{
			UTIL_Error(_, _, false, "Could not connect to SQL database. (Error: %s)", g_Query);
			return FAILED
		}
		case TQUERY_QUERY_FAILED:
		{
			UTIL_Error(_, _, false, "Query Failed (Error: %s)", g_Query);
			return FAILED
		}
		default:
		{
			UTIL_Error(_, _, false, "SQL Error (Error: %s)", g_Query);
			return FAILED
		}
	}
	
	return SUCCEEDED
}

AddProperty(const Name[], const ExternalName[], const Owner[], const OwnerID[]="", const Message[]="", Access[], const Price, const Profit, const Locked)
{
	strtolower(Access);
	
	new Trie:trie = TrieCreate();
	ArrayPushCell(g_PropertyArray, trie);
	
	TrieSetString(trie, "name", Name);
	TrieSetString(trie, "externalname", ExternalName);
	TrieSetString(trie, "owner", Owner);
	TrieSetString(trie, "owner_authid", OwnerID);
	TrieSetString(trie, "message", Message);
	TrieSetString(trie, "access", Access);
	
	TrieSetCell(trie, "price", Price);
	TrieSetCell(trie, "locked", Locked);
	TrieSetCell(trie, "profit", Profit);
}

AddDoor(const TargetName[], const PropertyName[], bool:Locked)
{
	new Trie:trie = TrieCreate();
	ArrayPushCell(g_DoorArray, trie);
	
	TrieSetString(trie, "targetname", TargetName)
	TrieSetString(trie, "property_name", PropertyName)
	
	TrieSetCell(trie, "locked", Locked);
}

public FetchDoors(FailState, Handle:Query, const Error[], Errcode, const Data[], DataSize)
{
	if(CheckSQLState(Query, FailState) == FAILED)
		return FAILED
	
	Init();
	
	if(!SQL_NumResults(Query))
		return SUCCEEDED
	
	new TargetName[64], PropertyName[64], Locked
	while(SQL_MoreResults(Query))
	{		
		SQL_ReadResult(Query, 0, TargetName, 63);
		SQL_ReadResult(Query, 1, PropertyName, 63);
		SQL_ReadResult(Query, 2, Locked);
		
		if(equali(TargetName, "e|", 2))
		{
			replace(TargetName, 63, "e|", "");
		}
		else if(equali(TargetName, "t|", 2))
		{
			replace(TargetName, 63, "t|", "");
		}
		
		AddDoor(TargetName, PropertyName, bool:Locked)
		SQL_NextRow(Query);
	}
	
	return SUCCEEDED
}
public FetchJobs(FailState, Handle:Query, const Error[], Errcode, const Data[], DataSize)
{
	if(CheckSQLState(Query, FailState) == FAILED)
		return FAILED
	
	Init();
	
	if(!SQL_NumResults(Query))
		return SUCCEEDED
	
	new JobName[33], JobAccess[18], JobRight[18]
	while(SQL_MoreResults(Query))
	{
		SQL_ReadResult(Query, 0, JobName, 32);
		
		new JobSalary = SQL_ReadResult(Query, 1);
		SQL_ReadResult(Query, 2, JobAccess, 17);
		SQL_ReadResult(Query, 3, JobRight, 17);
		
		AddJob(JobName, JobSalary, JobAccess, JobRight);
		SQL_NextRow(Query);
	}
	
	new Forward = CreateMultiForward("DRP_JobsInit", ET_IGNORE), Return
	if(Forward <= 0 || !ExecuteForward(Forward, Return))
		return UTIL_Error(_, _, true, "Could not execute ^"DRP_JobsInit^" forward.");
	
	DestroyForward(Forward);
	
	return SUCCEEDED
}

AddJob(const Name[], const Salary, const AccessString[], JobRight[])
{
	strtolower(JobRight);
	
	new Trie:trie = TrieCreate();
	ArrayPushCell(g_JobArray, trie);
	
	TrieSetString(trie, "name", Name);
	TrieSetString(trie, "access", AccessString);
	TrieSetString(trie, "jobright", JobRight);
	
	TrieSetCell(trie, "salary", Salary);
}

public FetchWorldTime(FailState, Handle:Query, Error[], Errcode, Data[], DataSize)
{
	if(CheckSQLState(Query, FailState) == FAILED)
		return FAILED
	
	new const Num = SQL_NumResults(Query);
	if(!Num)
		return FAILED
	
	if(Num > 1)
	{
		// TODO
		// What??
		return FAILED
	}
	
	SQL_ReadResult(Query, 0, g_Menu, 255);
	
	new StrMin[4], StrHour[4], StrMonth[4], StrMonthDay[4], StrYear[6], StrAM[4]
	parse(g_Menu, StrMin, 3, StrHour, 3, StrMonth, 3, StrMonthDay, 3, StrYear, 5, StrAM, 3);
	
	g_WorldTime[TIME_MIN] = str_to_num(StrMin);
	g_WorldTime[TIME_HOURS] = str_to_num(StrHour);
	g_WorldTime[TIME_AM_PM] = str_to_num(StrAM);
	g_WorldTime[TIME_MONTH] = str_to_num(StrMonth);
	g_WorldTime[TIME_MONTH_DAY] = str_to_num(StrMonthDay);
	g_WorldTime[TIME_YEAR] = str_to_num(StrYear);
	
	return SUCCEEDED
}
/*==================================================================================================================================================*/
// Commands
public CmdBuy(id)
{
	if(!is_user_alive(id))
		return PLUGIN_HANDLED
	
	new Index, Body
	get_user_aiming(id, Index, Body, 100);
	
	if(!pev_valid(Index))
		return PLUGIN_HANDLED
	
	static Targetname[64]
	pev(Index, pev_classname, Targetname, 63);
	
	if(equali(Targetname, g_drpEntNpc))
		return _CallNPC(id, Index);
	
	pev(Index, pev_targetname, Targetname, 63);
	
	new const Property = UTIL_GetProperty(Targetname, Index);
	if(Property == -1)
		return PLUGIN_HANDLED
	
	new const Array:CurArray = ArrayGetCell(g_PropertyArray, Property), Price = ArrayGetCell(CurArray, 4);
	new AuthID[36], Name[33]
	get_user_authid(id, AuthID, 35);
	
	ArrayGetString(CurArray, 2, Name, 32);
	ArrayGetString(CurArray, 3, Targetname, 63);
	
	if(equali(AuthID, Targetname))
	{
		client_print(id, print_chat, "[DRP] You already own this property.");
		return PLUGIN_HANDLED
	}
	else if(!Price)
	{
		client_print(id, print_chat, "[DRP] This property is already owned / not for sale.");
		return PLUGIN_HANDLED
	}
	
	new Data[4]
	Data[0] = id
	Data[1] = Property + 1
	Data[2] = DRP_PropertyGetOwner(Property + 1); // :(
	Data[3] = (Price > g_UserBank[id]) ? 0 : 1 // can we afford it
	
	if(UTIL_Event("Property_Buy", Data, 4) == EVENT_HALT)
		return PLUGIN_HANDLED
	
	if(Price > g_UserBank[id])
	{
		client_print(id, print_chat, "[DRP] You do not have enough money in your bank to buy this property.");
		return PLUGIN_HANDLED
	}
	
	new ExternalName[33]
	ArrayGetString(CurArray, 1, ExternalName, 32);
	
	if(Targetname[0] && Price)
	{
		new Players[32], iNum, Player, PlayerAuthid[36], Flag
		get_players(Players, iNum);
		
		for(new Count;Count < iNum;Count++)
		{
			Player = Players[Count]
			get_user_authid(Player, PlayerAuthid, 35);
			
			if(equali(PlayerAuthid, Targetname))
			{
				g_UserBank[Player] += Price
				
				get_user_name(id, Name, 32);
				client_print(Player, print_chat, "[DRP] Your property,  ^"%s^",  has been bought by %s for $%d.", ExternalName, Name, Price);
				
				Flag = 1
				break
			}
		}
		
		if(!Flag)
		{
			format(g_Query, 4095, "UPDATE %s SET bankmoney = bankmoney + %d WHERE SteamID='%s'", g_UserTable, Price, Targetname);
			UTIL_CleverQuery(g_Plugin, g_SqlHandle, "IgnoreHandle", g_Query);
		}
	}
	
	g_UserBank[id] -= Price
	
	get_user_name(id, Name, 32);
	
	ArraySetString(CurArray, 2, Name);
	ArraySetString(CurArray, 3, AuthID);
	
	ArraySetCell(CurArray, 4, 0);
	ArraySetCell(CurArray, 8, 0);
	ArraySetCell(CurArray, 9, 1);
	
	ArraySetString(CurArray, 10, "");
	
	client_print(id, print_chat, "[DRP] You have successfully bought the property ^"%s^"", ExternalName);
	
	ArrayGetString(CurArray, 0, ExternalName, 63);
	
	format(g_Query, 4095, "DELETE FROM %s WHERE authidkey LIKE '%%|%s'", g_KeysTable, ExternalName);
	SQL_ThreadQuery(g_SqlHandle, "IgnoreHandle", g_Query);
	
	return PLUGIN_HANDLED
}
public CmdMotd(id)
{
	read_argv(1, g_Menu, 255);
	format(g_Menu, 127, "%s%s-command.txt", g_HelpDir, g_Menu);
	
	if(!file_exists(g_Menu))
	{
		client_print(id, print_chat, "[DRP] Unable to show MOTD window, please try again later.", g_Menu);
		UTIL_Error(_, _, false, "Missing file: %s", g_Menu);
		return PLUGIN_HANDLED
	}
	
	show_motd(id, g_Menu, "DRP");
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
	
	new Snapshot:Iter = TrieSnapshotCreate(g_UserItemTrie[id]);
	new Success, Num, ItemID, Size = TrieSnapshotLength(Iter);
	
	if(Size < 1)
	{
		client_print(id, print_chat, "[DRP] There are no items in your inventory.");
		TrieSnapshotDestroy(Iter);
		return PLUGIN_HANDLED
	}
	else if(Size >= 256)
	{
		new AuthID[36]
		get_user_authid(id, AuthID, 35);
		UTIL_Error(_, _, false, "User has 256 or more items. This will cause buffer overflows. Size: %d User AuthID: %s", Size, AuthID);
	}
	
	new ItemName[33]
	formatex(ItemName, 32, "Inventory - Total Items: %d^nPage:", Size);
	
	new Menu = menu_create(ItemName, "ItemsHandle");
	
	for(new Count; Count < Size; Count++)
	{
		new ItemIDEx[5]
		TrieSnapshotGetKey(Iter, Count, ItemIDEx, 4);
		
		new ItemID = str_to_num(ItemIDEx);
		UTIL_ValidItemID(ItemID) ?
			UTIL_GetItemName(ItemID, ItemName) : copy(ItemName, 32, "BAD ITEMID : Contact Admin");
			
		formatex(g_Menu, 255, "%s x %d", ItemName, UTIL_GetUserItemNum(id, ItemID));
		menu_additem(Menu, g_Menu, ItemIDEx);
	}
	
	TrieSnapshotDestroy(Iter);
	menu_display(id, Menu);
	
	return PLUGIN_HANDLED
}
public ItemsHandle(id, Menu, Item)
{
	new Info[5], Access, Callback
	menu_item_getinfo(Menu, Item, Access, Info, 4, _, _, Callback);
	menu_destroy(Menu);
	
	if(Item == MENU_EXIT)
		return PLUGIN_HANDLED
	
	new ItemID = str_to_num(Info);
	g_CurItem[id] = ItemID
	
	new Amount = UTIL_GetUserItemNum(id, ItemID);
	if(Amount <= 0)
		return PLUGIN_HANDLED
	
	if(!UTIL_ValidItemID(ItemID))
		return PLUGIN_HANDLED
	
	new ItemName[33]
	UTIL_GetItemName(ItemID, ItemName);
	
	formatex(g_Menu, 255, "Item: %s ( x %d )", ItemName, Amount);
	
	menu_setprop(g_MenuItemOptions, MPROP_TITLE, g_Menu);
	menu_display(id, g_MenuItemOptions);
	
	return PLUGIN_HANDLED
}
public ItemOptions(id, Menu, Item)
{
	if(!is_user_alive(id))
		return PLUGIN_HANDLED
	
	new Trie:ItemTrie = ArrayGetCell(g_ItemsArray, g_CurItem[id]);
	if(ItemTrie == Invalid_Trie)
		return PLUGIN_HANDLED
	
	switch(Item)
	{
		case 0:
		{
			new Data[2]
			Data[0] = id
			Data[1] = g_CurItem[id]
			
			if(UTIL_Event("Item_Use", Data, 2) == EVENT_HALT)
				return PLUGIN_HANDLED
			
			new UseUp
			TrieGetCell(ItemTrie, "useup", UseUp);
			
			ItemUse(id, g_CurItem[id], UseUp);
		}
		case 1:
		{
			new Giveable
			TrieGetCell(ItemTrie, "giveable", Giveable);
			
			if(!Giveable)
			{
				client_print(id, print_chat, "[DRP] This item is not giveable.");
				return PLUGIN_HANDLED
			}
			
			menu_display(id, g_MenuItemGive);
		}
		case 2:
		{
			new Droppable
			TrieGetCell(ItemTrie, "droppable", Droppable);
			
			if(!Droppable)
			{
				client_print(id, print_chat, "[DRP] This item is not dropable.");
				return PLUGIN_HANDLED
			}
			
			menu_display(id, g_MenuItemDrop);
			
		}
		case 3:
		{
			new Index
			if(!UTIL_UserGetAim(id, Index))
				return PLUGIN_HANDLED
			
			new Name[2][33], ItemID = g_CurItem[id], ItemName[33]
			get_user_name(id, Name[1], 32);
			get_user_name(Index, Name[0], 32);
			
			UTIL_GetItemName(ItemID, ItemName);
			
			client_print(id, print_chat, "[DRP] You showed player %s your %s.", Name[0], ItemName);
			client_print(Index, print_chat, "[DRP] %s has showed you his/her: %s", Name[1], ItemName);
			
			g_ItemShow[Index] = ItemID
			
			if(DRP_IsPlayerInMenu(Index))
				client_print(Index, print_chat, "You may type ^"/iteminfo^" for more information on this item.");
			else
			{
				new Menu = menu_create("Item Description", "_ViewItem");
				menu_additem(Menu, "View Item Description");
				menu_additem(Menu, "Ignore");
				
				formatex(g_Menu, 255, "^n%s has shown you an item^nwould you like to view info about it?", Name[1]);
				menu_addtext(Menu, g_Menu, 0);
				
				menu_display(Index, Menu);
			}
		}
		
		case 4:
		{
			ItemInfo(id, g_CurItem[id]);
		}
		
		case 6:
		{
			CmdItems(id);
		}
	}
	return PLUGIN_HANDLED
}
UTIL_UserGetAim(id, &Target)
{
	new Index, Body
	get_user_aiming(id, Index, Body, 100);
	
	if(!Index || !is_user_alive(Index)) 
	{
		client_print(id, print_chat, "[DRP] You are not looking at another player.");
		return FAILED
	}
	
	Target = Index
	return SUCCEEDED
}
public _ViewItem(id, Menu, Item)
{
	menu_destroy(Menu);
	
	if(Item == MENU_EXIT)
		return PLUGIN_HANDLED
	
	if(Item == 0)
		ItemInfo(id, g_ItemShow[id]);
	
	return PLUGIN_HANDLED
}

public ItemTransferOptions(id, Menu, Item)
{
	if(!is_user_alive(id) || Item == MENU_EXIT)
		return PLUGIN_HANDLED
	
	new ItemID = g_CurItem[id]
	new Num, ItemNum = UTIL_GetUserItemNum(id, ItemID);
	
	switch(Item)
	{
		case 0:
			Num = 1
		case 1:
			Num = 5
		case 2:
			Num = 10
		case 3:
			Num = 50
		case 6:
			Num = ItemNum
	}
	
	if(ItemNum < Num)
	{
		client_print(id, print_chat, "[DRP] You do not have enough of this item.");
		return PLUGIN_HANDLED
	}
	
	if(Menu == g_MenuItemGive)
	{
		new Index
		
		if(!UTIL_UserGetAim(id, Index))
			return PLUGIN_HANDLED
	
		new Data[4]
		Data[0] = id
		Data[1] = Index
		Data[2] = ItemID
		Data[3] = Num
		
		if(UTIL_Event("Item_Give", Data, 4) == EVENT_HALT)
			return PLUGIN_HANDLED
	
		if(!UTIL_SetUserItemNum(Index, ItemID, UTIL_GetUserItemNum(Index, ItemID) + Num))
		{
			client_print(id, print_chat, "[DRP] There was an error giving the user the item.");
			return PLUGIN_HANDLED
		}
		
		UTIL_SetUserItemNum(id, ItemID, UTIL_GetUserItemNum(id, ItemID) - Num);
		
		new Name[2][33], ItemName[33]
		get_user_name(Index, Name[0], 32);
		get_user_name(id, Name[1], 32);
		
		UTIL_GetItemName(ItemID, ItemName);
		
		client_print(id, print_chat, "[DRP] You have given ^"%s^" %d %s%s.", Name[0], Num, ItemName, Num == 1 ? "" : "s");
		client_print(Index, print_chat, "[DRP] %s has given you %d %s%s.", Name[1], Num, ItemName, Num == 1 ? "" : "s");
	}
	
	if(Menu == g_MenuItemDrop)
	{
		new Data[3], Float:plOrigin[3]
		Data[0] = id
		Data[1] = ItemID
		Data[2] = Num
		
		if(UTIL_Event("Item_Drop", Data, 3) == EVENT_HALT)
			return PLUGIN_HANDLED

		new ItemName[33]
		pev(id, pev_origin, plOrigin);
		
		UTIL_GetItemName(ItemID, ItemName);
		
		if(!_CreateItemDrop(id, plOrigin, Num, ItemName))
		{
			client_print(id, print_chat, "[DRP] There was an error dropping the item.");
			return PLUGIN_HANDLED
		}
		
		UTIL_SetUserItemNum(id, ItemID, UTIL_GetUserItemNum(id, ItemID) - Num);
		
		client_cmd(id, "spk %s", g_drpDropSfx);
		client_print(id, print_chat, "[DRP] You have dropped %d x %s", Num, ItemName);
	}
	return PLUGIN_HANDLED
}
ItemInfo(id, ItemID)
{
	if(!is_user_alive(id) || !UTIL_ValidItemID(ItemID))
		return
	
	// show_motd() - uses alot of bandwidth - so limit
	if(!CheckTime(id))
		return
	
	new ItemName[33]
	UTIL_GetItemName(ItemID, ItemName);
	
	new Trie:ItemTrie = ArrayGetCell(g_ItemsArray, ItemID);
	if(ItemTrie == Invalid_Trie)
		return
	
	TrieGetString(ItemTrie, "description", g_Menu, 255);
	
	if(!g_Menu[0])
	{
		client_print(id, print_chat, "[DRP] This item does not have a description.");
		return
	}
	
	show_motd(id, g_Menu, ItemName);
}
/*==================================================================================================================================================*/
public CmdHelp(id)
{
	if(!CheckTime(id))
		return PLUGIN_HANDLED
	
	new Arg[33]
	read_argv(1, Arg, 32);
	
	new Start = str_to_num(Arg), Items = get_pcvar_num(p_ItemsPerPage);
	new NumCommands = ArraySize(g_CommandArray)
	
	if(Start)
		read_argv(2, Arg, 32);
	
	if(Start >= NumCommands || Start < 0)
	{
		client_print(id, print_console, "[DRP] No help items in this area to display.");
		return PLUGIN_HANDLED
	}
	
	new bool:Extra = containi(Arg, "extra") != -1 ? true : false, bool:Admin = UTIL_UserIsAdmin(id);
	
	client_print(id, print_console, "^n---- DRP %s Commands ----", Admin ? " (Including Admin Commands)" : "");
	client_print(id, print_console, "NAME		%s", Extra ? "DESCRIPTION" : "");
	
	new Description[128]
	for(new Count = Start;Count < Start + Items;Count++)
	{
		if(Count >= NumCommands)
			break
		
		new Trie:trie = ArrayGetCell(g_CommandArray, Count);
		if(trie == Invalid_Trie)
			continue
		
		TrieGetString(trie, "command", Arg, 32);
		if(Extra)
			TrieGetString(trie, "description", Description, 127);
		
		new bool:isAdmin = false
		TrieGetCell(trie, "adminonly", isAdmin)
		
		// we are not an admin, don't list this command
		if(isAdmin && !Admin)
			continue
		
		client_print(id, print_console, "%s		%s", Arg, Extra ? Description : "");
	}
	
	if(Start + Items < NumCommands)
		client_print(id, print_console, "[DRP] Type ^"drp_help %d^" to view the next page.", Start + Items);
	
	if(!Extra)
		client_print(id, print_console, "[DRP] Type ^"drp_help # extra^" to view the list with descriptions.");
	
	return PLUGIN_HANDLED
}
public CmdJobList(id)
{
	if(!CheckTime(id))
		return PLUGIN_HANDLED
	
	new Arg[33]
	read_argv(1, Arg, 32);
	
	new Start = str_to_num(Arg), Items = get_pcvar_num(p_ItemsPerPage);
	new NumJobs = ArraySize(g_JobArray);
	
	if(Start >= NumJobs || Start < 0)
	{
		client_print(id, print_console, "[DRP] No jobs in this area to display.");
		return PLUGIN_HANDLED
	}
	
	new JobName[33], JobAccess[18], Salary = 0
	new bool:IsAdmin = UTIL_UserIsAdmin(id);
	
	client_print(id, print_console, "^n---- DRP Jobs ----");
	client_print(id, print_console, "ID		NAME		SALARY		%s", IsAdmin ? "ACCESS" : "");
	
	for(new Count = Start;Count < Start + Items;Count++)
	{
		if(Count >= NumJobs)
			break
		
		new Trie:trie = ArrayGetCell(g_JobArray, Count);
		if(trie == Invalid_Trie)
			continue
		
		TrieGetString(trie, "name", JobName, 32);
		TrieGetCell(trie, "salary", Salary);
		
		if(IsAdmin)
		{
			TrieGetString(trie, "access", JobAccess, 17);
		}
		
		client_print(id, print_console, "%d		%s		$%i		%s", Count, JobName, Salary, JobAccess);
	}
	
	if(Start + Items < NumJobs)
		client_print(id, print_console, "[DRP] Type ^"drp_joblist %d^" to view the next page.",  Start + Items);
	
	return PLUGIN_HANDLED
}
public CmdItemList(id)
{	
	if(!CheckTime(id))
		return PLUGIN_HANDLED
	
	new Arg[33]
	read_argv(1, Arg, 32);
	
	new Start = str_to_num(Arg), Items = get_pcvar_num(p_ItemsPerPage);
	new NumItems = ArraySize(g_ItemsArray);
	
	if(Start)
		read_argv(2, Arg, 32);
	
	if(Start > NumItems)
	{
		client_print(id, print_console, "[DRP] No items in this area to display.")
		return PLUGIN_HANDLED
	}
	
	new bool:Extra = containi(Arg, "extra") != -1 ? true : false
	
	client_print(id, print_console, "^n---- DRP Items ----");
	client_print(id, print_console, "ITEMID		NAME	%s", Extra ? "DESCRIPTION" : "");
	
	new Name[33], Description[128]
	for(new Count = Start;Count < Start + Items;Count++)
	{
		if(Count >= NumItems)
			break
		
		new Trie:trie = ArrayGetCell(g_ItemsArray, Count);
		if(trie == Invalid_Trie)
			continue
		
		TrieGetString(trie, "name", Name, 32)
		if(Extra)
			TrieGetString(trie, "description", Description, 127)
		
		client_print(id, print_console, "%d		%s		%s", Count, Name, Extra ? Description : "");
	}
	
	if(Start + Items < NumItems)
		client_print(id, print_console, "[DRP] Type ^"drp_itemlist %d^" to view the next page.", Start + Items - 1);
	
	if(!Extra)
		client_print(id, print_console, "[DRP] Type ^"drp_itemlist # extra^" to view the list with descriptions.");
	
	return PLUGIN_HANDLED
}
public CmdMenu(id)
{
	TrieClear(g_UserMenuTrie[id]);
	g_MenuAccepting[id] = true
	
	new Data[1]
	Data[0] = id
	
	if(UTIL_Event("Menu_Display", Data, 1) == EVENT_HALT)
		return PLUGIN_HANDLED
	
	g_MenuAccepting[id] = false
	
	new Snapshot:Iter = TrieSnapshotCreate(g_UserMenuTrie[id]);
	new MenuItems = TrieSnapshotLength(TrieIterator);
	
	if(MenuItems <= 0)
	{
		client_print(id, print_chat, "[DRP] There is currently no items in your menu.");
		TrieSnapshotDestroy(Iter);
		return PLUGIN_HANDLED
	}
	
	new Info[128], Key[64]
	new Menu = menu_create("Quick-Access Menu", "ClientMenuHandle");
	
	for(new Count;Count < MenuItems;Count++)
	{
		TrieSnapshotGetKey(Iter, Count, Key, 63);
		TrieGetString(g_UserMenuTrie[id], Key, Info, 127);
		
		if(Key[0])
			menu_additem(Menu, Key, Info);
	}
	
	TrieSnapshotDestroy(TrieIterator);
	menu_display(id, Menu);
	
	return PLUGIN_HANDLED
}
public ClientMenuHandle(id, Menu, Item)
{
	if(Item == MENU_EXIT)
	{
		menu_destroy(Menu);
		return PLUGIN_HANDLED
	}
	
	new Access, Callback
	menu_item_getinfo(Menu, Item, Access, g_Menu, 255, _, _, Callback);
	
	new Forward = CreateOneForward(g_Menu[0], g_Menu[1], FP_CELL), Return
	if(Forward <= 0 || !ExecuteForward(Forward, Return, id))
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
		client_print(id, print_chat, "[DRP] Nobody has recently showed you an item.");
		return PLUGIN_HANDLED
	}
	
	ItemInfo(id, g_ItemShow[id]);
	g_ItemShow[id] = 0
	
	return PLUGIN_HANDLED
}
public CmdPropertyInfo(id, EntID)
{
	if(!is_user_alive(id) || !CheckTime(id))
		return PLUGIN_HANDLED
	
	new Index
	if(!EntID)
	{
		new Body
		get_user_aiming(id, Index, Body, 100);
		
		if(!Index)
		{
			client_print(id, print_chat, "[DRP] You must be looking at a property.");
			return PLUGIN_HANDLED
		}
	}
	else
		Index = EntID
	
	new TargetName[33]
	pev(Index, pev_targetname, TargetName, 32);
	
	new Property = UTIL_GetProperty(TargetName);
	if(Property == -1)
	{
		client_print(id, print_chat, "[DRP] You must be looking at a property.");
		return PLUGIN_HANDLED
	}
	
	if(DRP_PropertyGetOwner(Property + 1) != id)
	{
		client_print(id, print_chat, "[DRP] You do not own this property.");
		return PLUGIN_HANDLED
	}
	
	new Data[2]
	Data[0] = id
	Data[1] = Property
	
	format(g_Query, 4095, "SELECT * FROM `%s`", g_KeysTable);
	SQL_ThreadQuery(g_SqlHandle, "FetchPropertyUserInfo", g_Query, Data, 2);
	
	client_print(id, print_chat, "[DRP] Fetching Property Information..");
	return PLUGIN_HANDLED
}

// We have todo this,  so we can show which steamid's have access to our property
public FetchPropertyUserInfo(FailState, Handle:Query, const Error[], Errcode, const Data[], DataSize) 
{
	if(CheckSQLState(Query, FailState) == FAILED)
		return PLUGIN_HANDLED
	
	new id = Data[0], Property = Data[1], SQLProperty
	new Users[256], AuthID[36], InternalName[33]
	
	while(SQL_MoreResults(Query))
	{
		SQL_ReadResult(Query, 0, g_Menu, 255);
		strtok(g_Menu, AuthID, 35, InternalName, 32, '|');
		
		SQLProperty = UTIL_MatchProperty(InternalName);
		
		if(SQLProperty == Property)
		{
			add(Users, 255, AuthID);
			add(Users, 255, "^n");
		}
		
		SQL_NextRow(Query);
	}
	
	new Pos
	new Array:CurArray = ArrayGetCell(g_PropertyArray, Property);
	console_print(id, "-------Users-------^n%s", Users);
	
	ArrayGetString(CurArray, 1, g_Query, 4095);
	Pos += formatex(g_Menu[Pos], 255 - Pos, "Name: %s^nProfit: $%d^n", g_Query, ArrayGetCell(CurArray, 4));
	
	//DRP_IntToAccess(ArrayGetCell(CurArray, 6), g_Query, 4095);
	Pos += formatex(g_Menu[Pos], 255 - Pos, "Access Letter: %s^n", g_Query[0] ? g_Query : "N/A");
	
	ArrayGetString(CurArray, 0, g_Query, 4095);
	Pos += formatex(g_Menu[Pos], 255 - Pos, "InternalName: %s^n^nAccess to this Property^n%s^n^nThis list has also been put into your console (for copy/paste)", g_Query, Users);
	
	show_motd(id, g_Menu, "Prop Info");
	return PLUGIN_CONTINUE
}
CheckTime(id, Float:CoolDown = 1.5)
{
	new const Float:Time = get_gametime();
	if(Time - g_ConsoleTimeout[id] < CoolDown && g_ConsoleTimeout[id])
		return FAILED
	
	g_ConsoleTimeout[id] = Time
	return SUCCEEDED
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
		{
			set_task(0.5, "client_authorized", id + 32);
			return
		}
	}
	
	if(g_Saving[id])
	{
		set_task(0.5, "client_authorized", id + 32);
		return
	}
	
	new AuthID[36], Data[1]
	get_user_authid(id, AuthID, 35);
	
	Data[0] = id
	
	g_UserInfoNum[id] = 0
	
	// Make sure this id is cleared before loading anything
	// We should only call this once
	ClearSettings(id);
	
	formatex(g_Query, 4095, "SELECT bank, wallet, jobname, access, playtime, name FROM %s WHERE steamid='%s'", g_UserTable, AuthID);
	SQL_ThreadQuery(g_SqlHandle, "FetchClientData", g_Query, Data, 1);
	
	formatex(g_Query, 4095, "SELECT * FROM %s WHERE steamid_name LIKE '%s|%%'", g_ItemsTable, AuthID);
	SQL_ThreadQuery(g_SqlHandle, "FetchClientItems", g_Query, Data, 1);
	
	formatex(g_Query, 4095, "SELECT * FROM %s WHERE steamid_key LIKE '%s|%%'", g_KeysTable, AuthID);
	SQL_ThreadQuery(g_SqlHandle, "FetchClientKeys", g_Query, Data, 1);
	
	// Hold a copy of our AuthID
	// Sometimes when the SQL server is lagging, the client is disconnected before we can run the save query (and cannot grab their steamid anymore)
	copy(g_UserAuthID[id], 35, AuthID);
}
public client_disconnected(id)
{
	if(is_user_bot(id) || is_user_hltv(id))
		return
	
	if(UTIL_UserIsLoaded(id) && !g_PluginEnd && !g_Saving[id])
		SaveUserData(id, true);
}
/*==================================================================================================================================================*/
public FetchClientData(FailState, Handle:Query, const Error[], Errcode, const Data[], DataSize) 
{
	if(CheckSQLState(Query, FailState) == FAILED)
		return FAILED
	
	new id = Data[0]
	g_UserInfoNum[id]++
	
	// HACK
	// This sets the clients "print_center" message hold time
	client_cmd(id, "scr_centertime 2");
	
	new NumResults = SQL_NumResults(Query);
	if(NumResults > 1)
	{
		UTIL_Error(_, _, false, "User data returned multiple rows %d", NumResults);
		return FAILED
	}
	
	static UnemployedID
	
	if(!UnemployedID)
	{		
		new Results[1]
		new Num = DRP_FindJobID("Unemployed", Results, 1);
		
		if(Num <= 0 || Num > 1)
		{
			UTIL_Error(_, _, false, "Failed to obtain the proper Unemployed JobID. Jobs Found: %d", Num);
			return FAILED
		}
		
		UnemployedID = Results[0]
	}
	
	if(NumResults <= 0)
	{
		new AuthID[36], StartBankMoney = get_pcvar_num(p_StartMoney);
		get_user_authid(id, AuthID, 35);
		
		if(regex_match_c(AuthID, Regex:g_RegexPatterns[REGEX_STEAMID]) < 1)
		{
			UTIL_Error(_, _, false, "User was kicked for an invalid steamid: %s", AuthID);
			server_cmd("kick #%d ^"%s^"", get_user_userid(id), "Your SteamID is invalid. Please try reconnecting");
			return FAILED
		}
		
		// New Player
		// Let's set them up
		UTIL_UserSetJobID(id, UnemployedID);
		UTIL_UserSetBank(id, StartBankMoney);
		UTIL_UserSetWallet(id, 0);
		
		formatex(g_Query, 4095, "INSERT INTO %s (steamid, bank, wallet, jobname, access, playtime, name) VALUES('%s', '%i', '0', 'Unemployed', '', 0, '')", g_UserTable, AuthID, StartBankMoney );
		SQL_ThreadQuery(g_SqlHandle, "IgnoreHandle", g_Query);
		
		g_UserTime[id] = 0
		
		UTIL_Log(_, "New player data created for: %s", AuthID);
		CheckReady(id);
		
		UTIL_Event("DRP_NewPlayer", Data, 1);
		return SUCCEEDED
	}

	UTIL_UserSetBank(id, SQL_ReadResult(Query, 0));
	UTIL_UserSetWallet(id, SQL_ReadResult(Query, 1));
	
	new Temp[64], Results[2]
	SQL_ReadResult(Query, 2, Temp, 63);
	new NumJobs = DRP_FindJobID(Temp, Results, 3);
	
	if(!NumJobs || NumJobs > 1)
	{
		UTIL_Error(_, _, false, "Unable to obtain player jobid. Job: %s, Found: %d", Temp, NumJobs);
		UTIL_UserSetJobID(id, UnemployedID);
	}

	g_UserTime[id] = SQL_ReadResult(Query, 4);
	
	new Access[128]
	SQL_ReadResult(Query, 3, Access, 127);
	
	if(Access[0])
	{
		new Exploded[33][18]
		new Num = ExplodeString(Exploded, 32, 17, Access, '|');
		
		if(Num > 0)
		{
			for(new Count; Count <= Num; Count++)
				ArrayPushString(g_UserAccessArray[id], Exploded[Count]);
		}
	}
	
	// Name
	SQL_ReadResult(Query, 5, Temp, 63);
	
	if(Temp[0] && !UTIL_UserIsAdmin(id))
		set_user_info(id, "name", Temp);
	
	CheckReady(id);
	
	return SUCCEEDED
}
public FetchClientItems(FailState, Handle:Query, const Error[], Errcode, const Data[], DataSize) 
{
	if(CheckSQLState(Query, FailState) == FAILED)
		return FAILED
	
	new id = Data[0]
	g_UserInfoNum[id]++
	
	// we have no items.
	if(!SQL_NumResults(Query))
	{
		CheckReady(id);
		return SUCCEEDED
	}
	
	new AuthID[36], ItemName[36], ItemID
	TrieClear(g_UserItemTrie[id]);
	
	while(SQL_MoreResults(Query))
	{
		// use g_Menu[] as a cache
		SQL_ReadResult(Query, 0, g_Menu, 255);
		strtok(g_Menu, AuthID, 35, ItemName, 35, '|', 1);
		
		ItemID = UTIL_FindItemID(ItemName);
		
		// this item does not exist anymore
		// TODO: Log that this item cannot be found? Remove from user inventory?
		if(ItemID == -1)
		{
			SQL_NextRow(Query);
			continue
		}
		
		new Amount = SQL_ReadResult(Query, 1);
		if(Amount > 0)
		{
			num_to_str(Amount, AuthID, 35);
			formatex(ItemName, 35, "%d", ItemID);
			TrieSetString(g_UserItemTrie[id], ItemName, AuthID);
		}
		
		SQL_NextRow(Query);
	}
	CheckReady(id);
	
	return PLUGIN_CONTINUE
}
public FetchClientKeys(FailState, Handle:Query, const Error[], Errcode, const Data[], DataSize) 
{
	if(CheckSQLState(Query, FailState) == FAILED)
		return FAILED
	
	new id = Data[0]
	g_UserInfoNum[id]++
	
	if(!SQL_NumResults(Query))
	{
		CheckReady(id);
		return PLUGIN_CONTINUE
	}
	
	new InternalName[33], Property, AuthidKey[64], Garbage[1], Array:CurArray
	while(SQL_MoreResults(Query))
	{
		SQL_ReadResult(Query, 0, AuthidKey, 63);
		strtok(AuthidKey, Garbage, 0, InternalName, 32, '|');
		
		Property = UTIL_MatchProperty(InternalName);
		
		if(Property != -1)
		{
			CurArray = ArrayGetCell(g_PropertyArray, Property);
			ArraySetCell(CurArray, 8, ArrayGetCell(CurArray, 8)|(1<<(id - 1)));
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

	new iNum, id
	
	static iPlayers[32]
	get_players(iPlayers, iNum);
	
	for(new Count, _:Count2;Count < iNum;Count++)
	{
		id = iPlayers[Count]
		
		if(!is_user_alive(id) || is_user_bot(id))
			continue
		
		for(Count2 = 0;Count2 < HUD_NUM;Count2++)
			RenderHud(id, Count2);
	}
	
	new Num = get_pcvar_num(p_TimeMultiplier);
	for(new Count; Count < Num; Count++)
		DoTime();
}
UTIL_GetJobSalary(JobID)
{
	new Salary
	
	if(UTIL_ValidJobID(JobID))
	{
		new Trie:JobTrie = ArrayGetCell(g_JobArray, JobID);
		if(JobTrie != Invalid_Trie)
			TrieGetCell(JobTrie, "salary", Salary);
	}
	
	return Salary 
}

DoTime()
{
	if(++g_WorldTime[TIME_SEC] < 60)
		return
	
	g_WorldTime[TIME_SEC] = 0
	
	if(++g_WorldTime[TIME_MIN] < 60)
		return
	
	// the clock has moved 1hr, let's pay our players
	for(new Count; Count <= g_MaxPlayers; Count++)
	{
		new id = Count
		if(is_user_connected(id) && UTIL_UserIsLoaded(id))
		{
			new Data[1]
			Data[0] = id
			
			if(UTIL_Event("Player_Salary", Data, 1) == EVENT_HALT)
				continue
			
			UTIL_UserSetBank(id, g_UserBank[id] + UTIL_GetJobSalary(g_UserJobID[id]));
		}
	}
	
	// it's 11 o'clock
	if(g_WorldTime[TIME_HOURS] == 11)
	{
		// AM <-> PM
		new Afternoon = g_WorldTime[3]
		g_WorldTime[TIME_AM_PM] = !Afternoon
		
		if(g_WorldTime[TIME_AM_PM] && ++g_WorldTime[TIME_MONTH_DAY] >= g_MonthDays[g_WorldTime[TIME_MONTH]])
		{
			g_WorldTime[TIME_MONTH_DAY] = 1
			
			if(++g_WorldTime[TIME_MONTH] >= 11)
			{
				g_WorldTime[TIME_YEAR]++
				g_WorldTime[TIME_MONTH] = 1
			}
		}
		g_WorldTime[TIME_HOURS]++
	}
	else
	{
		if(++g_WorldTime[TIME_HOURS] >= 13)
			g_WorldTime[TIME_HOURS] = 1
	}
	
	g_WorldTime[TIME_MIN] = 0
}
RenderHud(id, Hud)
{
	ArrayClear(g_UserHudArray[id][Hud]);
	
	if(!is_user_alive(id))
		return
	
	g_HudPending = true
	
	static Temp[64], Message[512], Return
	
	if(!ExecuteForward(g_HudForward, Return, id, Hud))
		return
	
	Message[0] = 0
	
	new HudItems = ArraySize(g_UserHudArray[id][Hud]), Ticker
	for(new Count;Count < HudItems;Count++)
	{
		ArrayGetString(g_UserHudArray[id][Hud], Count, Temp, 63);
		Ticker += formatex(Message[Ticker], 511 - Ticker, "%s^n", Temp);
	}
	
	g_HudPending = false
	
	set_hudmessage(get_pcvar_num(p_Hud[Hud][R]), get_pcvar_num(p_Hud[Hud][G]), get_pcvar_num(p_Hud[Hud][B]), get_pcvar_float(p_Hud[Hud][X]), get_pcvar_float(p_Hud[Hud][Y]), 0, 0.0, 999999.9, 0.0, 0.0, -1)
	ShowSyncHudMsg(id, g_HudObjects[Hud], "%s", Message);
}
CheckReady(id)
{
	if(g_UserInfoNum[id] < NUM_USER_QUERIES)
		return
	
	new Data[1]
	Data[0] = id
	
	UTIL_Event("Player_Ready", Data, 1);
}
/*==================================================================================================================================================*/
// Forwards
public fw_GameDescription()
{
	new Enabled = get_pcvar_num(p_GameName)
	if(Enabled)
	{
		forward_return(FMV_STRING, g_GameName); 
		return FMRES_SUPERCEDE;
	}
	return FMRES_IGNORED
}
public fw_ClientMaxSpeed(id, Float:NewSpeed)
{
	g_UserMaxSpeed[id] = NewSpeed
	return FMRES_IGNORED
}

public fw_PreThink(id)
{
	if(g_PluginEnd)
		return FMRES_IGNORED
	
	// Don't allow players to spectate other players
	// TS seems to use pev_iuser2 to hold a target to another player
	if(!is_user_alive(id))
	{
		static Target
		Target = pev(id, pev_iuser2);
		
		if(Target)
			set_pev(id, pev_iuser2, 0);
		
		return FMRES_HANDLED
	}
	
	// Control Speed
	if(g_UserSpeedOverride[id])
		set_user_maxspeed(id, g_UserSpeedOverride[id]);
	else
	{
		new Snapshot:Iter = TrieSnapshotCreate(g_UserSpeedTrie[id]);
		new Size = TrieSnapshotLength(Iter), Float:Mul, bool:Flag, Float:NewSpeed = g_UserMaxSpeed[id]
		
		for(new Count; Count < Size; Count++)
		{
			TrieSnapshotGetKey(Iter, Count, g_Menu, 255);
			TrieGetCell(g_UserSpeedTrie[id], g_Menu, Mul);
			client_print(id,print_console,"%f - %f",Mul, NewSpeed);
			NewSpeed *= Mul
			Flag = true
		}
		
		TrieSnapshotDestroy(Iter);
		
		if(Flag)
		{
			client_print(id,print_console,"%f",NewSpeed);
			set_user_maxspeed(id, NewSpeed);
		}
	}
	
	new Index, Body
	get_user_aiming(id, Index, Body, 100);
	
	if(g_Display[id])// && Index)
		PrintDisplay(id, Index);
	
	if(!(pev(id, pev_button) & IN_USE && !(pev(id, pev_oldbuttons) & IN_USE)))
		return FMRES_IGNORED
	
	static Classname[36]
	if(Index)
	{
		pev(Index, pev_classname, Classname, 35);
		if(containi(Classname, g_FuncDoor) != -1)
		{
			/*
			new DoorArray
			pev(Index, pev_targetname, Classname, 35);
			
			new const Property = UTIL_GetProperty(Classname, Index, DoorArray);
			if(Property == -1)
				return FMRES_IGNORED
			
			// First - check if this door has a "master lock"
			// If it's not locked (by default it is) - we can go into it. This allows us to lock/unlock specific doors
			// Instead of the WHOLE property
			
			if(ArrayGetCell(ArrayGetCell(g_DoorArray, DoorArray), 4) == 0)
				return dllfunc(DLLFunc_Use, Index, id);
			
			new Array:CurArray = ArrayGetCell(g_PropertyArray, Property), AuthID[36]
			get_user_authid(id, AuthID, 35);
			
			ArrayGetString(CurArray, 3, Classname, 35);
			
			if(equali(Classname, AuthID))
			{
				g_CurProp[id] = Index
				ArrayGetString(CurArray, 1, Classname, 35);
				
				formatex(g_Menu, 255, "%s Info", Classname);
				
				menu_setprop(g_PropMenu, MPROP_TITLE, g_Menu);
				menu_display(id, g_PropMenu);
			}
			
			else if(ArrayGetCell(CurArray, 8) & (1<<(id - 1)) || ArrayGetCell(CurArray, 6) & g_UserAccess[id] || !ArrayGetCell(CurArray, 5))
			{
				client_print(id, print_chat, "[DRP] You used the door.");
				dllfunc(DLLFunc_Use, Index, id);
			}
			
			else
			{
				// Doorbell wont ring for property's with "hard access" letters assigned to them
				// like the police station and such

				
				new const Float:Time = get_gametime();
				if(Hard)
					client_print(id, print_chat, "[DRP] You do not have keys to this door.");
				else if(Time - g_DoorBellTime[id] > 5.0 && g_DoorBellTime[id])
				{
					client_print(id, print_chat, "[DRP] The door is locked; you rang the doorbell.");
					g_DoorBellTime[id] = Time
					emit_sound(Index, CHAN_AUTO, g_drpDoorBellSfx, 0.5, ATTN_NORM, 0, PITCH_NORM);
				}
			}
			
			return FMRES_HANDLED
			*/
		}
		
		else if(equali(Classname, g_drpEntNpc))
			return _CallNPC(id, Index);
		
		// HACK HACK:
		// We use the DRP Event system for some plugins (IE: In DRPDrugs.amxx when we "use" our plants. This is easier the putting a prethink function there)
		else
		{
			new Data[2]
			Data[0] = id
			Data[1] = Index
			
			if(UTIL_Event("Player_UseEntity", Data, 2) == EVENT_HALT)
			{
				return FMRES_IGNORED
			}
		}
	}
	
	// We are not looking at an entity
	// Check around us
	
	static EntList[1]
	if(find_sphere_class(id, g_drpEntNpc, 50.0, EntList, 1))
	{
		new const Ent = EntList[0], SkipTraceCheck = pev(Ent, pev_iuser2);
		
		// FROM DRPNPC.AMXX
		// iUser2 = Skip TraceLine
		if(SkipTraceCheck)
			return _CallNPC(id, Ent);
		else if(is_visible(id, Ent))
			return _CallNPC(id, Ent);
	}
	
	else if(find_sphere_class(id, g_drpEntItem, 40.0, EntList, 1))
	{
		new const Ent = EntList[0]
		pev(Ent, pev_noise, Classname, 35);
		
		new const ItemID = UTIL_FindItemID(Classname), Num = pev(Ent, pev_iuser2)
		
		if(!UTIL_ValidItemID(ItemID))
		{
			client_print(id, print_chat, "[DRP] Invalid Item in the Item Drop. Deleteing..");
			engfunc(EngFunc_RemoveEntity, Ent);
			
			return FMRES_HANDLED;
		}
		
		UTIL_SetUserItemNum(id, ItemID, UTIL_GetUserItemNum(id, ItemID) + Num);
		
		client_cmd(id, "spk %s",  g_drpDropSfx);
		client_print(id, print_chat, "[DRP] You have picked up %d x %s%s.", Num, Classname, Num == 1 ? "" : "s");
		
		engfunc(EngFunc_RemoveEntity, Ent);
		return FMRES_HANDLED
	}
	else if(find_sphere_class(id, g_drpEntMoney, 40.0, EntList, 1))
	{
		new const Ent = EntList[0], Amount = pev(Ent, pev_iuser3);
		new Data[2]
		
		g_UserWallet[id] += Amount
		client_print(id, print_chat, "[DRP] You have picked up $%d dollar%s.", Amount, Amount == 1 ? "" : "s");
		
		Data[0] = pev(Ent, pev_owner);
		Data[1] = id
		
		if(UTIL_Event("Player_PickupCash", Data, 2) == EVENT_HALT)
			return FMRES_HANDLED
		
		engfunc(EngFunc_RemoveEntity, Ent);
		return FMRES_HANDLED
	}
	return FMRES_IGNORED
}
PrintDisplay(const id, const Index)
{
	static Classname[36], Message[256]
	
	// NPC Viewing
	if(!Index)
	{
		if(find_sphere_class(id, g_drpEntNpc, 40.0, Classname, 1))
		{
			new const Ent = Classname[0]
			pev(Ent, pev_noise1, Classname, 63);
			
			formatex(Message, 255, "NPC: %s^nPress use (default e) to use", Classname);
			client_print(id, print_center, "%s", Message);
		}
	}
	else
	{
		pev(Index, pev_classname, Classname, 35);
		
		if(containi(Classname, g_FuncDoor) != -1)
		{
			new DoorArray
			pev(Index, pev_targetname, Classname, 35);
			
			new const Property = UTIL_GetProperty(Classname, Index, DoorArray);
			if(Property != -1)
			{
				new Data[2]
				Data[0] = id
				Data[1] = Property + 1
				
				if(UTIL_Event("Print_PropDisplay", Data, 2) != EVENT_HALT)
				{
					new CMessage[128], Name[33], Temp[26]
					new const Array:CurArray = ArrayGetCell(g_PropertyArray, Property), Price = ArrayGetCell(CurArray, 4);
					
					new Locked = (ArrayGetCell(CurArray, 5) && ArrayGetCell(Array:ArrayGetCell(g_DoorArray, DoorArray), 4)) ? 1 : 0
					
					ArrayGetString(CurArray, 1, Name, 32);
					ArrayGetString(CurArray, 2, Classname, 35);
					ArrayGetString(CurArray, 10, CMessage, 127);
					
					if(Price)
						formatex(Temp, 25, "Price: $%d", Price);
					
					formatex(Message, 255, "%s^nOwner: %s%s^n%s^n%s^n%s", Name[0] ? Name : "", Classname[0] ? Classname : "N/A", 
					Price ? " (Selling)" : "", 
					Locked ? "Locked" : "Unlocked", 
					Price ? Temp : "", 
					CMessage[0] ? CMessage : "");
					
					client_print(id, print_center, "^n^n^n^n^n^n^n^n^n^n^n^n^n%s", Message)
				}
			}
		}
		else if(equali(Classname, g_drpEntNpc))
		{
			pev(Index, pev_noise1, Classname, 63);
			
			// We might want to use a HUD (HUD_EXTRA) Message for this
			// Down the line
			
			formatex(Message, 255, "NPC: %s^nPress use (default e) to use", Classname);
			client_print(id, print_center, "%s", Message);
		}
	}
	
	if(!g_HudPending)
	{ 
		g_Display[id] = 0; 
		set_task(1.6, "ResetDisplay", id);
	}
}

public ResetDisplay(id)
	g_Display[id] = 1

public fw_SetKeyValue(const id, const Buffer[], const Key[], const Value[])
{
	if(!is_user_connected(id))
		return FMRES_IGNORED
	
	if(!equal(Key, "name"))
		return FMRES_IGNORED
	
	// DRP Admins do not require a name
	if(UTIL_UserIsAdmin(id))
		return FMRES_IGNORED
	
	new StartName[33]
	get_pcvar_string(p_FLName, StartName, 32);
		
	if(!CheckName(id, Value))
	{
		forward_return(FMV_STRING, StartName);
		set_user_info(id, "name", StartName);
		
		client_print(id, print_chat, "[DRP] Please use a first and last name.");
		return FMRES_SUPERCEDE
	}
	
	if(!equali(Value, StartName))
		menu_display(id, g_MenuName);
	
	return FMRES_IGNORED
}
CheckName(id, const Name[])
{
	new Temp[2]
	get_pcvar_string(p_FLName, Temp, 1);
	
	if(!Temp[0])
		return SUCCEEDED
	
	if(regex_match_c(Name, Regex:g_RegexPatterns[REGEX_NAME]) < 1)
		return FAILED
	
	return SUCCEEDED
}
public MenuHandleName(id, Menu, Item)
{
	if(Item == MENU_EXIT)
		return PLUGIN_HANDLED
	
	switch(Item)
	{
		case 0:
		{
			new AuthID[36]
			get_user_authid(id, AuthID, 35);
			get_user_name(id, g_Menu, 255);
			
			DRP_SqlEscape(g_Menu, 255);
			
			formatex(g_Query, 4095, "UPDATE `%s` SET `name`='%s' WHERE `steamid`='%s'", g_UserTable, g_Menu, AuthID);
			UTIL_CleverQuery(g_Plugin, g_SqlHandle, "IgnoreHandle", g_Query);
			
			client_print(id, print_chat, "[DRP] Your name has been saved. It will be changed everytime you connect.");
		}
		case 1:
		{
			client_print(id, print_chat, "[DRP] Your name has not been saved.");
		}
	}
	return PLUGIN_HANDLED
}

// TODO:
// Update to use the doors "master lock" feature
public fw_Touch(const EntTouched, const EntToucher)
{
	if(!EntTouched || !EntToucher)
		return FMRES_IGNORED
	
	static Classname[24]
	pev(EntToucher, pev_classname, Classname, 23);
	
	if(!equali(Classname, "player"))
		return FMRES_IGNORED
	
	pev(EntTouched, pev_classname, Classname, 23);
	
	if(containi(Classname, g_FuncDoor) == -1)
		return FMRES_IGNORED
	
	pev(EntTouched, pev_targetname, Classname, 23);
	
	new DoorArray
	new const Property = UTIL_GetProperty(Classname, _, DoorArray);
	
	if(Property == -1)
		return FMRES_IGNORED
	
	new Locked = (ArrayGetCell(Array:ArrayGetCell(g_PropertyArray, Property), 5) && ArrayGetCell(Array:ArrayGetCell(g_DoorArray, DoorArray), 4)) ? 1 : 0
	if(!Locked)
	{
		dllfunc(DLLFunc_Use, EntTouched, EntToucher);
	}
	
	return FMRES_HANDLED
}

public MenuHandleProperty(id, Menu, Item)
{
	if(Item == MENU_EXIT || !g_CurProp[id])
		return PLUGIN_HANDLED
	
	switch(Item)
	{
		case 0: dllfunc(DLLFunc_Use, g_CurProp[id], id);
		case 1: CmdPropertyInfo(id, g_CurProp[id]);
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
	
	DeathScreen(id);
	
	return PLUGIN_CONTINUE
}
public EventResetHUD(id)
	set_task(1.0, "ForwardWelcome", id);

public DeathScreen(id)
{
	if(is_user_alive(id))
	{
		// Hack to clear the screen
		message_begin(MSG_ONE_UNRELIABLE, gmsgTSFade, _, id);
		
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
	
	message_begin(MSG_ONE_UNRELIABLE, gmsgTSFade, _, id);
	
	write_short(~0);
	write_short(~0);
	write_short(FFADE_STAYOUT);
	
	write_byte(0);
	write_byte(0);
	write_byte(0);
	write_byte(255);
	
	message_end();
	
	set_task(1.0, "DeathScreen", id);
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

public EventTakeDamage(id, inflictor, attacker, Float:damage, Bits)
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
	
	new AuthID[36]
	get_user_authid(id, AuthID, 35);
	
	if(regex_match_c(AuthID, Regex:g_RegexPatterns[REGEX_STEAMID]) < 1)
	{
		client_print(id, print_chat, "[DRP] Your SteamID is Invalid. Your user data will not be saved.");
		return
	}
	
	g_Joined[id] = true
	
	new Temp[64]
	get_user_name(id, Temp, 63);
	
	if(!CheckName(id, Temp))
	{
		new StartName[33]
		get_pcvar_string(p_FLName, StartName, 32);
		
		client_print(id, print_chat, "[DRP] Please use a first and last name.");
		set_user_info(id, "name", StartName);
		
		return
	}
	
	for(new Count; Count < 2; Count++)
	{
		get_pcvar_string(p_Welcome[Count], g_Menu, 255);
		
		if(containi(g_Menu, "#name#") != -1)
		{
			get_user_name(id, Temp, 63);
			replace_all(g_Menu, 127, "#name#", Temp);
		}
		if(containi(g_Menu, "#hostname#") != -1)
		{
			get_pcvar_string(p_Hostname, Temp, 63);
			replace_all(g_Menu, 127, "#hostname#", Temp);
		}
		
		if(g_Menu[0])
			client_print(id, print_chat, "[DRP] %s", g_Menu);
	}
}
/*==================================================================================================================================================*/
NPCUse(const Handler[], const Plugin, const id, const Index)
{
	new Forward = CreateOneForward(Plugin, Handler, FP_CELL, FP_CELL), Return
	if(Forward <= 0 || !ExecuteForward(Forward, Return, id, Index))
	{
		new Name[33]
		get_plugin(Plugin, _, _, Name, 32);
		
		DRP_Log("[NPCUse] Unable to find function in plugin. (Function: %s - Plugin: %s)", Handler, Name);
		return FAILED
	}
	DestroyForward(Forward);
	
	return SUCCEEDED
}
ItemUse(id, ItemID, UseUp)
{
	if(!UTIL_ValidItemID(ItemID))
		return FAILED
	
	new Trie:CurTrie = ArrayGetCell(g_ItemsArray, ItemID), Plugin
	if(CurTrie == Invalid_Trie)
		return FAILED
	
	TrieGetCell(CurTrie, "plugin", Plugin);
	
	if(!Plugin || !get_plugin(Plugin))
	{
		UTIL_Error(_, _, false, "Item has invalid pluginid: %d", Plugin);
		return FAILED
	}
	
	new Function[64], bool:_Useup, Size
	TrieGetString(CurTrie, "handler", Function, 63);
	TrieGetCell(CurTrie, "useup", _Useup);
	TrieGetArray(CurTrie, "data", g_Menu, 255, Size);
	
	new PrepArray = PrepareArray(g_Menu, Size);
	new Forward = CreateOneForward(Plugin, Function, FP_CELL, FP_CELL, FP_ARRAY, FP_CELL), Return
	
	if(Forward <= 0 || !ExecuteForward(Forward, Return, id, ItemID, PrepArray, Size))
	{
		UTIL_Error(Plugin, _, false, "Failed to forward function ^"%s^" to PluginID: %d", Function, Plugin);
		return FAILED
	}
	
	DestroyForward(Forward);
	
	// Even if the item is flagged to be "used up" this overrides that
	if(Return == ITEM_KEEP) 
		return SUCCEEDED
	
	if((UseUp && _Useup) || Return == ITEM_FORCE_REMOVE)
		UTIL_SetUserItemNum(id, ItemID, UTIL_GetUserItemNum(id, ItemID) - 1);
	
	return SUCCEEDED
}
/*==================================================================================================================================================*/
UTIL_UserBuildAccess(id, Buffer[256])
{
	new Size = ArraySize(g_UserAccessArray[id]);
	if(!Size)
		return
	
	new AccessString[16], Built[256]
	for(new Count;Count < Size; Count++)
	{
		ArrayGetString(g_UserAccessArray[id], Count, AccessString, 17);
		
		if((Count + 1) != Size)
			add(AccessString, 17, "|");
		
		add(Built, 255, AccessString);
	}
	
	copy(Buffer, 255, Built);
}
UTIL_UserHasAccess(id, const Key[])
{
	new FixedKey[18]
	copy(FixedKey, 17, Key);
	
	strtolower(FixedKey);
	
	new Num = ArraySize(g_UserAccessArray[id]);
	if(!Num)
		return FAILED

	new Results = ArrayFindString(g_UserAccessArray[id], FixedKey)
	return (Results == -1) ? FAILED : SUCCEEDED
}
UTIL_UserRevokeAccess(id, Key[])
{
	strtolower(Key);
	
	new Num = ArraySize(g_UserAccessArray[id]);
	if(!Num)
		return FAILED
	
	new Results = ArrayFindValue(g_UserAccessArray[id], Key);
	if(Results != -1)
	{
		ArrayDeleteItem(g_UserAccessArray[id], Results);
		return SUCCEEDED
	}
	
	return FAILED
}
UTIL_UserGrantAccess(id, Key[])
{
	strtolower(Key);
	
	new Results = ArrayFindString(g_UserAccessArray[id], Key);
	if(Results == -1)
	{
		ArrayPushString(g_UserAccessArray[id], Key);
		return SUCCEEDED
	}
	
	return FAILED
}
UTIL_UserSetJobID(id, JobID)
{
	if(!UTIL_ValidJobID(JobID))
		return
	
	g_UserJobID[id] = JobID
}
UTIL_UserSetBank(id, Amount)
{
	Amount = abs(Amount)
	if(Amount >= 0)
		g_UserBank[id] = Amount
}
UTIL_UserSetWallet(id, Amount)
{
	Amount = abs(Amount)
	if(Amount >= 0)
		g_UserWallet[id] = Amount
}
bool:UTIL_UserIsAdmin(id)
{
	if(!id || !is_user_connected(id))
		return false
	
	return ( UTIL_UserHasAccess(id, g_drpAdminAccess) == SUCCEEDED ) ? true : false
}
UTIL_UserJobName(id, Name[33])
{
	if(UTIL_ValidJobID(g_UserJobID[id]))
	{
		new Trie:JobTrie = ArrayGetCell(g_JobArray, g_UserJobID[id])
		if(JobTrie != Invalid_Trie)
			TrieGetString(JobTrie, "name", Name, 32);
	}
}
UTIL_UserIsLoaded(id)
	return (g_UserInfoNum[id] >= NUM_USER_QUERIES) ? SUCCEEDED : FAILED
/*==================================================================================================================================================*/
// Dynamic Natives
public plugin_natives()
{
	register_library("drp_core");
	
	register_native("DRP_Log", "_DRP_Log");
	register_native("DRP_ThrowError", "_DRP_ThrowError");
	register_native("DRP_SqlHandle", "_DRP_SqlHandle");
	register_native("DRP_GetConfigsDir", "_DRP_GetConfigsDir");
	register_native("DRP_CleverQueryBackend", "_DRP_CleverQueryBackend");
	register_native("DRP_GetWorldTime", "_DRP_GetWorldTime");
	
	register_native("DRP_PlayerReady", "_DRP_PlayerReady");
	register_native("DRP_ShowMOTDHelp", "_DRP_ShowMOTDHelp");
	
	// TSX MODULE
	register_native("DRP_TSGetUserWeaponID", "_DRP_TSGetUserWeaponID");
	register_native("DRP_TSSetUserAmmo", "_DRP_TSSetUserAmmo");
	register_native("DRP_TSGiveUserWeapon", "_DRP_TSGiveUserWeapon");
	
	register_native("DRP_SetUserMaxSpeed", "_DRP_SetUserMaxSpeed");
	
	register_native("DRP_IsCop", "_DRP_IsCop");
	register_native("DRP_IsAdmin", "_DRP_IsAdmin");
	register_native("DRP_IsMedic", "_DRP_IsMedic");
	register_native("DRP_IsJobAdmin", "_DRP_IsJobAdmin");
	register_native("DRP_IsVIP", "_DRP_IsVIP");
	
	register_native("DRP_UserDisplay", "_DRP_UserDisplay");
	
	register_native("DRP_GetUserWallet", "_DRP_GetUserWallet");
	register_native("DRP_SetUserWallet", "_DRP_SetUserWallet");
	register_native("DRP_GetUserBank", "_DRP_GetUserBank");
	register_native("DRP_SetUserBank", "_DRP_SetUserBank");
	
	register_native("DRP_GetUserTime", "_DRP_GetUserTime");
	
	register_native("DRP_GetUserData", "_DRP_GetUserData");
	register_native("DRP_SetUserData", "_DRP_SetUserData");
	register_native("DRP_LoadUserData","_DRP_LoadUserData");
	
	register_native("DRP_GetUserJobID", "_DRP_GetUserJobID");
	register_native("DRP_SetUserJobID", "_DRP_SetUserJobID");
	register_native("DRP_GetJobSalary", "_DRP_GetJobSalary");
	
	register_native("DRP_FindJobID", "_DRP_FindJobID");
	register_native("DRP_FindJobID2", "_DRP_FindJobID2");
	register_native("DRP_FindItemID", "_DRP_FindItemID");
	register_native("DRP_FindItemID2", "_DRP_FindItemID2");
	
	register_native("DRP_ValidJobID", "_DRP_ValidJobID");
	register_native("DRP_ValidItemID", "_DRP_ValidItemID");
	
	register_native("DRP_AddCommand", "_DRP_AddCommand");
	register_native("DRP_AddHudItem", "_DRP_AddHudItem");
	register_native("DRP_ForceHUDUpdate", "_DRP_ForceHUDUpdate");
	
	register_native("DRP_AddJob", "_DRP_AddJob");
	register_native("DRP_DeleteJob", "_DRP_DeleteJob");
	
	register_native("DRP_GetPayDay", "_DRP_GetPayDay");
	
	register_native("DRP_RegisterItem", "_DRP_RegisterItem");
	register_native("DRP_GetItemName", "_DRP_GetItemName");
	
	register_native("DRP_ItemInfo", "_DRP_ItemInfo");
	
	register_native("DRP_GetUserItemNum", "_DRP_GetUserItemNum");
	register_native("DRP_SetUserItemNum", "_DRP_SetUserItemNum");
	register_native("DRP_GetUserTotalItems", "_DRP_GetUserTotalItems");
	register_native("DRP_ForceUseItem", "_DRP_ForceUseItem");
	register_native("DRP_FetchUserItems", "_DRP_FetchUserItems");
	
	register_native("DRP_CreateItemDrop", "_DRP_CreateItemDrop");
	register_native("DRP_CreateMoneyBag", "_DRP_CreateMoneyBag");
	
	register_native("DRP_GetUserAccess", "_DRP_GetUserAccess");
	register_native("DRP_SetUserAccess", "_DRP_SetUserAccess");
	
	register_native("DRP_GetJobAccess", "_DRP_GetJobAccess");
	register_native("DRP_GetJobName", "_DRP_GetJobName");
	
	register_native("DRP_DoEvent", "_DRP_DoEvent");
	register_native("DRP_RegisterEvent", "_DRP_RegisterEvent");
	
	register_native("DRP_AddMenuItem", "_DRP_AddMenuItem");
	
	register_native("DRP_AddProperty", "_DRP_AddProperty");
	register_native("DRP_AddDoor", "_DRP_AddDoor");
	
	register_native("DRP_DeleteProperty", "_DRP_DeleteProperty")
	register_native("DRP_DeleteDoor", "_DRP_DeleteDoor")
	
	register_native("DRP_ValidProperty", "_DRP_ValidProperty");
	register_native("DRP_ValidPropertyName", "_DRP_ValidPropertyName");
	register_native("DRP_ValidDoor", "_DRP_ValidDoor");
	register_native("DRP_ValidDoorName", "_DRP_ValidDoorName");
	
	register_native("DRP_PropertyNum", "_DRP_PropertyNum");
	register_native("DRP_DoorNum", "_DRP_DoorNum");
	
	register_native("DRP_PropertyMatch", "_DRP_PropertyMatch");
	register_native("DRP_DoorMatch", "_DRP_DoorMatch");
	
	register_native("DRP_PropertyGetInternalName", "_DRP_PropertyGetInternalName");
	register_native("DRP_PropertyGetExternalName", "_DRP_PropertyGetExternalName");
	register_native("DRP_PropertySetExternalName", "_DRP_PropertySetExternalName");
	
	register_native("DRP_PropertyGetOwnerName", "_DRP_PropertyGetOwnerName");
	register_native("DRP_PropertySetOwnerName", "_DRP_PropertySetOwnerName");
	register_native("DRP_PropertyGetOwnerAuth", "_DRP_PropertyGetOwnerAuth");
	register_native("DRP_PropertySetOwnerAuth", "_DRP_PropertySetOwnerAuth");
	
	register_native("DRP_PropertyAddAccess", "_DRP_PropertyAddAccess");
	register_native("DRP_PropertyRemoveAccess", "_DRP_PropertyRemoveAccess");
	register_native("DRP_PropertyGetAccess", "_DRP_PropertyGetAccess");
	
	register_native("DRP_PropertyGetMessage", "_DRP_PropertyGetMessage");
	register_native("DRP_PropertySetMessage", "_DRP_PropertySetMessage");
	register_native("DRP_PropertyGetLocked", "_DRP_PropertyGetLocked");
	register_native("DRP_PropertySetLocked", "_DRP_PropertySetLocked");
	register_native("DRP_PropertyDoorGetLocked", "_DRP_PropertyDoorGetLocked");
	register_native("DRP_PropertyDoorSetLocked", "_DRP_PropertyDoorSetLocked");
	
	register_native("DRP_PropertyGetProfit", "_DRP_PropertyGetProfit");
	register_native("DRP_PropertySetProfit", "_DRP_PropertySetProfit");
	register_native("DRP_PropertyGetPrice", "_DRP_PropertyGetPrice");
	register_native("DRP_PropertySetPrice", "_DRP_PropertySetPrice");
	
}
/*==================================================================================================================================================*/
public _DRP_Log(Plugin, Params)
{
	if(Params < 1)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 1 or more,  Found: %d", Params);
		return FAILED
	}
	
	vdformat(g_Query, 4095, 1, 2);
	return UTIL_Log(Plugin, g_Query);
}
public _DRP_ThrowError(Plugin, Params)
{
	if(Params < 2)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 2 or more,  Found: %d", Params);
		return FAILED
	}
	// TODO
	// FIX ME
}
public _DRP_SqlHandle(Plugin, Params)
{
	return _:g_SqlHandle
}
public _DRP_GetConfigsDir(Plugin, Params)
{
	if(Params != 2)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 2,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	set_string(1, g_ConfigDir, get_param(2));
	
	return SUCCEEDED
}
public _DRP_CleverQueryBackend(Plugin, Params)
{
	if(Params != 5)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected 5,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new Handle:Tuple = Handle:get_param(1), Handler[64], Data[256], Len = min(255, get_param(5))
	get_string(2, Handler, 63);
	get_array(4, Data, Len);
	get_string(3, g_Query, 4095);
	
	return _DRP_CleverQuery(Plugin, Tuple, Handler, g_Query, Data, Len);
}

// [0] = Seconds
// [1] = Minutes
// [2] = Hours
// [3] = AM/PM
// [4] = Month
// [5] = Month Day
// [6] = Year

// DRP_GetWorldTime(String[], Len, Mode=1)
// 1 = HOUR:MINUTE AM/PM (MONTH/DAY/YEAR)
// 2 = Hour only
// 3 = Minute Only
// 4 = date() = "year month day"
public _DRP_GetWorldTime(Plugin, Params)
{
	if(Params != 3)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected 3,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new const Len = get_param(2), Mode = get_param(3);
	
	switch(Mode)
	{
		// HOUR:MINUTE AM/PM (MONTH/DAY/YEAR)
		case 1:
		formatex(g_Menu, 255, "%d:%s%d %s (%d/%d/%d)", g_WorldTime[2], g_WorldTime[1] < 10 ? "0" : "", 
		g_WorldTime[1], g_WorldTime[3] ? "AM" : "PM", g_WorldTime[4], g_WorldTime[5], g_WorldTime[6]);
		case 2:
		formatex(g_Menu, 255, "%d", g_WorldTime[2]);
		case 3:
		formatex(g_Menu, 255, "%d", g_WorldTime[1]);
		case 4:
		formatex(g_Menu, 255, "%d %d %d", g_WorldTime[6], g_WorldTime[4], g_WorldTime[5]);
		
		default:
		return FAILED
	}
	
	set_string(1, g_Menu, Len);
	return SUCCEEDED
}
public _DRP_PlayerReady(Plugin, Params)
{
	if(Params < 1)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected 1,  Found: %d", Plugin, Params);
		return FAILED
	}	
	
	new id = get_param(1);
	if(!is_user_connected(id))
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "User not connected: %d", Plugin, id);
		return FAILED
	}
	
	return UTIL_UserIsLoaded(id);
}
public _DRP_ShowMOTDHelp(Plugin, Params)
{
	if(Params != 2)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected 2,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new const id = get_param(1);
	if(!is_user_connected(id))
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "User not connected: %d", Plugin, id);
		return FAILED
	}
	
	new File[256]
	get_string(2, File, 255);
	
	format(File, 255, "%s/%s", g_HelpDir, File);
	
	if(!file_exists(File))
		return FAILED
	
	show_motd(id, File, "DRP");
	return SUCCEEDED
}
public _DRP_TSGetUserWeaponID(Plugin, Params)
{
	if(Params < 1)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected 1 or more,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new const id = get_param(1);
	if(!is_user_connected(id))
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "User not connected: %d", Plugin, id);
		return FAILED
	}
	
	set_param_byref(2, g_UserWpnID[id][1]); // Clip
	set_param_byref(3, g_UserWpnID[id][2]); // Ammo
	set_param_byref(4, g_UserWpnID[id][3]); // Mode
	set_param_byref(5, g_UserWpnID[id][4]); // Extra
	
	return g_UserWpnID[id][0]
}
public _DRP_TSSetUserAmmo(Plugin, Params)
{
	if(Params < 1)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected 1 or more,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new id = get_param(1);
	if(!is_user_connected(id))
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "User not connected: %d", Plugin, id);
		return FAILED
	}
	new WeaponID = get_param(2), Ammo = get_param(3);
	if(WeaponID <= 0 || WeaponID > 36 || WeaponID == 34)
		return FAILED
	
	client_cmd(id, "weapon_%d", WeaponID);
	
	new TSGun = ts_get_user_tsgun(id);
	if(!TSGun)
		return FAILED
	
	if(WeaponID == 24 || WeaponID == 25 || WeaponID == 35)
	{
		set_pdata_int(TSGun, 41, Ammo);
		set_pdata_int(TSGun, 839, Ammo);
		
		Ammo = 0
	}
	else
	set_pdata_int(TSGun, tsweaponoffset[WeaponID], Ammo);
	
	message_begin(MSG_ONE_UNRELIABLE, gmsgWeaponInfo, _, id);
	write_byte(WeaponID);
	write_byte(g_UserWpnID[id][1]);
	
	write_short(Ammo)
	
	write_byte(g_UserWpnID[id][3]);
	write_byte(g_UserWpnID[id][4]);
	
	message_end();
	
	return SUCCEEDED
}
public _DRP_TSGiveUserWeapon(Plugin, Params)
{
	if(Params < 1)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected 1 or more,  Found: %d", Plugin, Params);
		return FAILED
	}
	new id = get_param(1), WeaponID = get_param(2), ExtraClip = get_param(3), Flags = get_param(4);
	if(!is_user_alive(id) || (WeaponID > 36 || !WeaponID))
		return FAILED
	
	new Weapon = create_entity("ts_groundweapon");
	if(!Weapon)
		return FAILED
	
	new Temp[12]
	formatex(Temp, 11, "%d", WeaponID);
	
	DispatchKeyValue(Weapon, "tsweaponid", Temp);
	DispatchKeyValue(Weapon, "wduration", "180");
	
	formatex(Temp, 11, "%d", ExtraClip);
	DispatchKeyValue(Weapon, "wextraclip", Temp);
	
	formatex(Temp, 11, "%d", Flags);
	DispatchKeyValue(Weapon, "spawnflags", Temp);
	
	DispatchSpawn(Weapon);
	dllfunc(DLLFunc_Use, Weapon, id);
	
	engfunc(EngFunc_RemoveEntity, Weapon);
	return SUCCEEDED
}
/*==================================================================================================================================================*/
/*
public _DRP_UserHaveProgressBar(Plugin, Params)
{
if(Params != 1)
{
UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected 1,  Found: %d", Plugin, Params);
return FAILED
}

new id = get_param(1);
if(g_ProgressBar[id][SECONDS] >= 1)
	return SUCCEEDED

return FAILED
}

// Creates a Progress Bar in the center of the screen (If DRPHud is 0)
// Define R, G, B Progress Colors,  and R, G, B
// DRP_ProgressBar(id, const Title[], const FinishedText[], Seconds, BarLen, Red = 255, Green = 0, Blue = 0, DRPHud = 0, const Function2Call[]="");
public _DRP_ProgressBar(Plugin, Params)
{

if(Params != 1)
{
}


new id = get_param(1);
if(!is_user_connected(id) && id != -1)
{
UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "User not connected: %d", Plugin, id);
return FAILED
}
if(g_ProgressBar[id][SECONDS] >= 1)
{
UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "User (ID: %d) already has a progress bar in progress", Plugin, id);
return FAILED
}

new Count
for(Count = 0;Count < ProgressBar;Count++)
	g_ProgressBar[id][Count] = 0

new Output[128], Handler[33], Seconds = get_param(4), BarLen = get_param(5), DRPHud = get_param(9);
if(Seconds <= 0 || BarLen <= 0)
{
UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "The progress bar must have Seconds & BarLen greater than 1", Plugin);
return FAILED
}

g_ProgressBar[id][RED] = get_param(6);
g_ProgressBar[id][GREEN] = get_param(7);
g_ProgressBar[id][BLUE] = get_param(8);

get_string(10, Handler, 32);
get_string(2, Output, 127);

new TitleLen = format(Output, 127, "%s^n", Output);


BarLen = (BarLen + TitleLen > sizeof Output - 1 ? sizeof Output - (1 + TitleLen) : BarLen)

for(Count = TitleLen + 1;Count < (BarLen + TitleLen + 1);Count++)
	add(Output, sizeof Output - 1, "-");

if(Handler[0])
{ g_ProgressBar[PLUGIN_ID][id] = Plugin; copy(g_ProgressBar[id][HANDLER], 32, Handler); }
else
g_ProgressBar[PLUGIN_ID][id] = -1

g_ProgressBar[SECONDS][id] = Seconds

for(Count = 0;Count <= BarLen + 1;Count++)
{
// End of the progress bar
if(Count == BarLen + 1)
{
get_string(3, Output, sizeof Output - 1);
set_task(Count * float(Seconds) / BarLen,  "_ProgressBarEnd", id, Output, sizeof Output - 1);
break
}
set_task(Count * float(Seconds) / BarLen, "_RunProgressBar", id, Output, sizeof Output - 1);
replace(Output, sizeof Output - 1, "-", "|");
}


return SUCCEEDED
}

// Progress Bar Task Functions
public _ProgressBarEnd(const Message[], id)
{
new Plugin = g_ProgressBar[PLUGIN_ID][id]
if(Plugin > 0)
{
new Forward = CreateOneForward(Plugin, g_ProgressBar[id][HANDLER], FP_CELL, FP_CELL), Return
if(Forward <= 0 || !ExecuteForward(Forward, Return, id, g_ProgressBar[SECONDS][id]))
	return FAILED

DestroyForward(Forward);
}

g_ProgressBar[SECONDS][id] = 0

set_hudmessage(0, 150, 0, _, _, 1, _, 6.0, _, _, -1);
show_hudmessage(id, Message);


_Debug("PLUGIN: %d - SECONDS: %d", g_ProgressBar[PLUGIN_ID][id], g_ProgressBar[SECONDS][id]);
g_ProgressBar[SECONDS][id] = 0

set_hudmessage(255);
show_hudmessage(id, Message);


return SUCCEEDED
}
public _RunProgressBar(const Message[], id)
{
set_hudmessage(g_ProgressBar[RED][id], g_ProgressBar[GREEN][id], g_ProgressBar[BLUE][id], _, _, _, _, 12.0, _, _, 4);

if(id == -1)
	show_hudmessage(0, Message);
else
show_hudmessage(id, Message);
}
*/
/*==================================================================================================================================================*/
public _DRP_IsCop(Plugin, Params)
{
	if(Params != 1)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 1,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new id = get_param(1);
	return UTIL_UserHasAccess(id, g_drpPoliceAccess);
}
public _DRP_IsAdmin(Plugin, Params)
{
	if(Params != 1)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 1,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new id = get_param(1);
	return UTIL_UserIsAdmin(id);
}
public _DRP_IsMedic(Plugin, Params)
{
	if(Params != 1)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 1,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new id = get_param(1);
	return UTIL_UserHasAccess(id, g_drpMedicAccess);
}
public _DRP_IsJobAdmin(Plugin, Params)
{
	if(Params != 1)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 1,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new id = get_param(1);
	
	return FAILED
}
public _DRP_IsVIP(Plugin, Params)
{
	if(Params != 1)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 1,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new id = get_param(1);
	return UTIL_UserHasAccess(id, g_drpVIPAccess);
}
/*==================================================================================================================================================*/
public _DRP_UserDisplay(Plugin, Params)
{
	if(Params != 1)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 1,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new const id = get_param(1);
	if(!is_user_connected(id))
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "User not connected: %d", Plugin, id);
		return FAILED
	}
	return g_Display[id]
}
/*==================================================================================================================================================*/
public _DRP_GetUserWallet(Plugin, Params)
{
	if(Params != 1)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 1,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new id = get_param(1);
	if(!is_user_connected(id))
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "User not connected: %d", id);
		return FAILED
	}
	
	return g_UserWallet[id]
}
public _DRP_SetUserWallet(Plugin, Params)
{
	if(Params != 2)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 2,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new id = get_param(1);
	if(!is_user_connected(id))
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "User not connected: %d", id);
		return FAILED
	}
	
	new Amount = get_param(2);
	g_UserWallet[id] = Amount;
	
	return SUCCEEDED
}
public _DRP_GetUserBank(Plugin, Params)
{
	if(Params != 1)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 1,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new id = get_param(1);
	if(!is_user_connected(id))
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "User not connected: %d", id);
		return FAILED
	}
	
	return g_UserBank[id]
}
public _DRP_SetUserBank(Plugin, Params)
{
	if(Params != 2)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 2,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new id = get_param(1);
	if(!is_user_connected(id))
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "User not connected: %d", id);
		return FAILED
	}
	
	new Amount = get_param(2);
	g_UserBank[id] = Amount
	
	return SUCCEEDED
}
/*==================================================================================================================================================*/
public _DRP_GetUserTime(Plugin, Params)
{
	if(Params != 1)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 1,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new id = get_param(1);
	if(!is_user_connected(id))
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "User not connected: %d", Plugin, id);
		return FAILED
	}
	
	new const Total = ( get_user_time(id) / 60 ) + g_UserTime[id]
	return Total
}

// DRP_LoadUserData(id, const Handler[])
public _DRP_LoadUserData(Plugin, Params)
{
	if(Params != 2)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 2,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new id = get_param(1);
	if(g_UserDataTrie[id] == Invalid_Trie)
		return FAILED
	
	new PluginName[64]
	get_plugin(Plugin, _, _, PluginName, 63);
	
	if(!Plugin || !PluginName[0])
		return FAILED
	
	new Handler[33]
	get_string(2, Handler, 32);
	
	regex_replace(Regex:g_RegexPatterns[REGEX_STRIP_SPECIAL], PluginName, 63, "");
	strtolower(PluginName);
	
	new AuthID[36]
	get_user_authid(id, AuthID, 35);
	
	formatex(g_Menu, 255, "%s|%s", AuthID, PluginName);
	formatex(g_Query, 4095, "SELECT * FROM %s WHERE steamid_key LIKE '%s|%%'", g_DataTable, g_Menu);
	
	new Data[2]
	Data[0] = id
	Data[1] = Plugin
	SQL_ThreadQuery(g_SqlHandle, "FetchUserPluginData", g_Query, Data, 2);
	
	return SUCCEEDED
}

public FetchUserPluginData(FailState, Handle:Query, const Error[], Errcode, const Data[], DataSize) 
{
	if(CheckSQLState(Query, FailState) == FAILED)
		return FAILED
	
	new id = Data[0], PluginID = Data[1]
	
	if(!SQL_NumResults(Query))
		return SUCCEEDED
	
	server_print("FETCHING");
	
	new Key[128], Value[128]
	new Garbage[1]
	
	while(SQL_MoreResults(Query))
	{
		SQL_ReadResult(Query, 0, Key, 127);
		SQL_ReadResult(Query, 1, Value, 127);
		
		strtok2(Key, Garbage, 0, Key, 127, '|', RTRIM_RIGHT);
		
		TrieSetString(g_UserDataTrie[id], Key, Value);
		SQL_NextRow(Query);
	}
	
	return SUCCEEDED
}
// DRP_GetUserData( id, const key[], output[], len)
public _DRP_GetUserData(Plugin, Params)
{
	if(Params != 4)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 4,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new id = get_param(1);
	if(g_UserDataTrie[id] == Invalid_Trie)
		return FAILED
	
	new Key[36], PluginName[64]
	get_string(2, Key, 35);
	get_plugin(Plugin, _, _, PluginName, 63);
	
	if(!Plugin || !PluginName[0])
		return FAILED

	regex_replace(Regex:g_RegexPatterns[REGEX_STRIP_SPECIAL], PluginName, 63, "");
	strtolower(PluginName);
	
	formatex(g_Menu, 255, "%s|%s", PluginName, Key);
	
	if(!TrieKeyExists(g_UserDataTrie[id], g_Menu))
		return FAILED
	
	new Output[128]
	TrieGetString(g_UserDataTrie[id], g_Menu, Output, 127);
	
	set_string(3, Output, get_param(4));
	return SUCCEEDED
}
//DRP_SetUserData(id, const Key[], const Value[], bool:PluginOnly=false)
//TODO: Fix keys/Plugin name with regex (remove spaces/bad chars)
public _DRP_SetUserData(Plugin, Params)
{
	if(Params != 3)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 3,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new id = get_param(1);
	if(g_UserDataTrie[id] == Invalid_Trie)
		return FAILED
	
	new Key[36], Value[128], PluginName[64]
	
	get_string(2, Key, 35);
	get_string(3, Value, 127);
	
	new FixedKey[255]
	get_plugin(Plugin, _, _, PluginName, 63);
	
	if(!Plugin || !PluginName[0])
		return FAILED
	
	regex_replace(Regex:g_RegexPatterns[REGEX_STRIP_SPECIAL], PluginName, 63, "");
	strtolower(PluginName);
	
	formatex(FixedKey, 255, "%s|%s", PluginName, Key);

	new OldValue[128]
	TrieGetString(g_UserDataTrie[id], FixedKey, OldValue, 127);
	
	if(equal(OldValue, Value))
		return SUCCEEDED
	
	TrieSetString(g_UserDataTrie[id], FixedKey, Value);
	
	//new AuthID[36]
	//get_user_authid(id, AuthID, 35);
	
	//formatex(g_Menu, 255, "%s|%s", AuthID, FixedKey);
	//DRP_SqlEscape(Value, 127);
	
	//formatex(g_Query, 4095, "INSERT INTO %s (steamid_key, value) VALUES('%s','%s') ON DUPLICATE KEY UPDATE value='%s'", g_DataTable, g_Menu, Value, Value);
	//SQL_ThreadQuery(g_SqlHandle, "IgnoreHandle", g_Query);
	
	return SUCCEEDED
}
/*==================================================================================================================================================*/
public _DRP_GetUserJobID(Plugin, Params)
{
	if(Params != 1)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 1,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new id = get_param(1);
	if(!is_user_connected(id))
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "User not connected: %d", Plugin, id);
		return FAILED
	}
	
	return UTIL_ValidJobID(g_UserJobID[id]) ? g_UserJobID[id] : -1
}
public _DRP_SetUserJobID(Plugin, Params)
{
	if(Params != 3)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 2,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new const JobID = get_param(2) - 1, id = get_param(1), Event = get_param(3);
	new OldJobID = g_UserJobID[id]
	
	if(!UTIL_ValidJobID(JobID))
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Invalid JobID %d", Plugin, JobID);
		return FAILED
	}
	
	if(!is_user_connected(id))
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "User not connected: %d", Plugin, id);
		return FAILED
	}
	
	g_UserJobID[id] = JobID
	
	// Called after the job is set
	// so we can't stop it - but we sometimes wanna check "DRP_IsCop()" when the event is called
	// and if they were switched to a cop,  it would return zero (because it's called before)
	// so let's leave this down here.
	if(Event)
	{
		new Data[3]
		Data[0] = id
		Data[1] = JobID
		Data[2] = OldJobID
		
		if(UTIL_Event("Player_ChangeJobID", Data, 3) == EVENT_HALT)
			return FAILED
	}
	
	return SUCCEEDED
}
public _DRP_GetJobSalary(Plugin, Params)
{
	if(Params != 1)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 1,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new JobID = get_param(1);
	
	if(!UTIL_ValidJobID(JobID))
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Invalid JobID %d", Plugin, JobID);
		return FAILED
	}
	
	new Trie:trie = ArrayGetCell(g_JobArray, JobID);
	if(trie == Invalid_Trie)
		return FAILED
	
	new Salary = 0;
	TrieGetCell(trie, "salary", Salary);
	
	return Salary
}
/*==================================================================================================================================================*/
public _DRP_FindJobID(Plugin, Params)
{
	if(Params != 3)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 3,  Found: %d", Params);
		return FAILED
	}
	
	new SearchString[64], MaxResults = get_param(3), Num, Name[33]
	new JobNum = ArraySize(g_JobArray)
	
	static Results[512], Temp[512], Length[512]
	
	get_string(1, SearchString, 63);
	
	for(new Count;Count < JobNum;Count++)
	{		
		if(!UTIL_ValidJobID(Count)) 
			continue
		
		new Trie:trie = ArrayGetCell(g_JobArray, Count);
		if(trie == Invalid_Trie)
			continue
		
		TrieGetString(trie, "name", Name, 32);
		if(containi(Name, SearchString) != -1)
		{
			Temp[Num] = Count + 1
			Length[Num] = strlen(Name);
			
			Num++
		}
	}
	
	new CurStep, Cell = -1
	for(new Count, LowLength, Count2;Count < Num && Count < MaxResults;Count++)
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
		set_array(2, Results, min(MaxResults, Num));
	
	return Num
}
public _DRP_FindItemID(Plugin, Params)
{
	if(Params != 3)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 3,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new Item[33], MaxResults = get_param(3), Num, Name[33]
	new ItemNum = ArraySize(g_ItemsArray);
	
	static Temp[512], Results[512], Length[512]
	get_string(1, Item, 32);
	
	for(new Count = 0;Count < ItemNum && Num < 512;Count++)
	{
		new Trie:CurTrie = ArrayGetCell(g_ItemsArray, Count);
		if(CurTrie == Invalid_Trie)
			continue
		
		TrieGetString(CurTrie, "name", Name, 32);
		server_print("WAT: %s", Name);
		
		if(containi(Name, Item) != -1)
		{
			server_print("Added");
			Temp[Num] = Count
			Length[Num] = strlen(Name);
			
			Num++
		}
	}
	
	new CurStep, Cell = -1
	for(new Count, LowLength, Count2;Count < Num && Count < MaxResults;Count++)
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
		set_array(2, Results, min(MaxResults, Num));
	
	return Num
}
public _DRP_FindItemID2(Plugin, Params)
{
	if(Params != 1)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 3,  Found: %d", Plugin, Params);
		return FAILED
	}
	new Name[33]
	get_string(1, Name, 32);
	
	return UTIL_FindItemID(Name);
}
public _DRP_FindJobID2(Plugin, Params)
{
	if(Params != 1)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 3,  Found: %d", Plugin, Params);
		return FAILED
	}
	new Name[33]
	get_string(1, Name, 32);
	
	return UTIL_FindJobID(Name);
}
public _DRP_ValidJobID(Plugin, Params)
{
	if(Params != 1)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 1,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new JobID = get_param(1);
	return UTIL_ValidJobID(JobID);
}
public _DRP_ValidItemID(Plugin, Params)
{
	if(Params != 1)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 1,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new ItemID = get_param(1);
	
	return UTIL_ValidItemID(ItemID);
}
/*==================================================================================================================================================*/
public _DRP_AddCommand(Plugin, Params)
{
	if(Params != 2)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 2,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new Trie:trie = TrieCreate();
	ArrayPushCell(g_CommandArray, trie);
	
	get_string(1, g_Query, 4095);
	TrieSetString(trie, "command", g_Query);
	
	get_string(2, g_Query, 4095);
	TrieSetString(trie, "description", g_Query);
	
	//TODO: ADD THIS TO THE PARAMS
	TrieSetCell(trie, "adminonly", true);
	
	return SUCCEEDED
}
public _DRP_AddHudItem(Plugin, Params)
{
	if(Params < 3)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 4,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new const id = get_param(1), Channel = get_param(2);
	if(!is_user_connected(id) && id != -1)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "User not connected: %d", Plugin, id);
		return FAILED
	}
	
	if(Channel < 0 || Channel > HUD_NUM)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Invalid HUD Channel: %d", Plugin, Channel);
		return FAILED
	}
	
	static Message[256]
	vdformat(Message, 255, 3, 4);
	
	UTIL_AddHudItem(id, Channel, Message);
	
	return SUCCEEDED
}
public _DRP_ForceHUDUpdate(Plugin, Params)
{
	if(Params != 2)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 2,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new const id = get_param(1), Hud = get_param(2);
	
	if(!is_user_connected(id) && id != -1)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "User not connected: %d", Plugin, id);
		return FAILED
	}
	
	if(id == -1)
	{
		new iPlayers[32], iNum
		get_players(iPlayers, iNum);
		
		for(new Count;Count < iNum;Count++)
			RenderHud(iPlayers[Count], Hud);
	}
	else
	{
		RenderHud(id, Hud);
	}
	
	return SUCCEEDED
}
public _DRP_AddJob(Plugin, Params)
{
	if(Params != 4)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 4,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new Name[33], JobAccess[18], JobRight[18], Salary = get_param(2);
	get_string(1, Name, 32);
	
	new Results[1]
	new Num = DRP_FindJobID(Name, Results, 1);
	
	// Similar job exists
	if(Num)
		return FAILED
	
	get_string(3, JobAccess, 17);
	get_string(4, JobRight, 17);
	
	strtolower(JobAccess);
	strtolower(JobRight);
	
	for(new Count; Count < sizeof(g_drpInvalidAccess); Count++)
	{
		if(equali(g_drpInvalidAccess[Count], JobRight) || equali(g_drpInvalidAccess[Count], JobAccess))
			return FAILED
	}
	
	format(g_Query, 4095, "INSERT INTO %s (name, salary, access, job_group) VALUES ('%s', '%i', '%s', '%s')", g_JobsTable, Name, Salary, JobAccess, JobRight);
	SQL_ThreadQuery(g_SqlHandle, "IgnoreHandle", g_Query);
	
	AddJob(Name, Salary, JobAccess, JobRight);
	
	return SUCCEEDED
}

public _DRP_DeleteJob(Plugin, Params)
{
	if(Params != 1)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 1,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new JobID = get_param(1) - 1
	
	if(!UTIL_ValidJobID(JobID))
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Invalid job id: %d", Plugin, JobID);
		return FAILED
	}
	
	return UTIL_DeleteJob(JobID);
}
/*==================================================================================================================================================*/
public _DRP_GetPayDay(Plugin, Params)
	return g_SalaryTime / 10
/*==================================================================================================================================================*/
public _DRP_GetJobName(Plugin, Params)
{
	if(Params != 3)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 3,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new JobID = get_param(1), Len = get_param(3), JobName[36]
	
	if(!UTIL_ValidJobID(JobID))
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Invalid JobID: %d", Plugin, JobID);
		return FAILED
	}
	
	new Trie:trie = ArrayGetCell(g_JobArray, JobID);
	if(trie == Invalid_Trie)
		return FAILED
	
	TrieGetString(trie, "name", JobName, 35);
	set_string(2, JobName, Len);
	
	return SUCCEEDED
}
/*==================================================================================================================================================*/
public _DRP_GetUserAccess(Plugin, Params)
{
	if(Params != 1)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 1,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new id = get_param(1);
	if(!is_user_connected(id))
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "User not connected: %d", Plugin, id);
		return FAILED
	}
	
	return SUCCEEDED
	//return g_UserAccess[id]
}

public _DRP_SetUserAccess(Plugin, Params)
{
	if(Params != 3)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 2,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new id = get_param(1);
	if(!is_user_connected(id))
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "User not connected: %d", Plugin, id);
		return FAILED
	}
	
	new Access = get_param(2);
	new Data[2]
	Data[0] = id
	Data[1] = Access
	
	/*
	if(!UTIL_Event("Player_SetAccess", Data, 2))
		return FAILED
	
	g_UserAccess[id] = Access
	g_UserAccess[id] |= ArrayGetCell(ArrayGetCell(g_JobArray, g_UserJobID[id]), 3);
	
	get_param(3) == 1 ? 
	(g_AccessCache[id] |= Access) : (g_AccessCache[id] = Access)
	*/
	
	return SUCCEEDED
}
public _DRP_GetJobAccess(Plugin, Params)
{
	if(Params != 1)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 1,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new JobID = get_param(1) - 1
	if(!UTIL_ValidJobID(JobID))
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Invalid JobID: %d", Plugin, JobID);
		return FAILED
	}
	
	return ArrayGetCell(ArrayGetCell(g_JobArray, JobID), 3);
}
public _DRP_RegisterItem(Plugin, Params)
{
	if(Params < 3)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 3 or more,  Found: %d", Plugin, Params);
		return FAILED
	}

	new Name[33], Handler[33], Description[128]
	get_string(1, Name, 32);
	get_string(2, Handler, 32);
	get_string(3, Description, 127);
	
	if(!Name[0])
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Item name must have a length.");
		return FAILED
	}
	
	new Results = DRP_FindItem(Name)
	
	if(Results)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Similar item named found, unable to register item: %s", Name);
		return FAILED
	}
	
	new DataLen = get_param(5);
	new Data[256]
	get_array(4, Data, DataLen);
	
	return AddItem(Name, Plugin, Handler, Description, Data, DataLen, bool:get_param(6), bool:get_param(7), bool:get_param(8));
}
AddItem(const Name[], const Plugin, const Handler[], const Description[], const Data[]="", Len = 0, bool:Useup, bool:Droppable, bool:Giveable)
{
	new Trie:trie = TrieCreate();
	ArrayPushCell(g_ItemsArray, trie);
	
	TrieSetString(trie, "name", Name);
	TrieSetString(trie, "handler", Handler);
	TrieSetString(trie, "description", Description);
	
	TrieSetCell(trie, "plugin", Plugin);
	TrieSetCell(trie, "useup", Useup);
	TrieSetCell(trie, "droppable", Droppable);
	TrieSetCell(trie, "giveable", Giveable);
	
	TrieSetArray(trie, "data", Data, Len);
	
	// The ItemID is the index in the array
	// When items are deleted, the array item isn't removed, to keep all the ID's valid
	return ArraySize(g_ItemsArray) - 1
}

public _DRP_GetUserItemNum(Plugin, Params)
{
	if(Params != 2)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 2,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new id = get_param(1), ItemID = get_param(2);
	
	if(!UTIL_ValidItemID(ItemID))
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Invalid ItemID: %d", Plugin, ItemID);
		return FAILED
	}
	
	return UTIL_GetUserItemNum(id, ItemID);
}

public _DRP_SetUserItemNum(Plugin, Params)
{
	if(Params != 3)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 3,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new id = get_param(1), ItemID = get_param(2), ItemNum = get_param(3);
	if(ItemNum < 0)
		return FAILED
	
	if(!UTIL_ValidItemID(ItemID))
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Invalid ItemID: %d", ItemID);
		return FAILED
	}
	
	return UTIL_SetUserItemNum(id, ItemID, ItemNum)
}

public _DRP_SetUserMaxSpeed(Plugin, Params)
{
	if(Params != 3)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 3,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new id = get_param(1), SPEED:Type = SPEED:get_param(2), Float:Value = get_param_f(3)
	if(!is_user_connected(id))
		return FAILED
	
	formatex(g_Menu, 255, "%d", Plugin);
	
	switch(Type)
	{
		case SPEED_NONE:
		{
			TrieDeleteKey(g_UserSpeedTrie[id], g_Menu);
			
			if(g_UserSpeedOverridePlugin[id] == Plugin)
			{
				g_UserSpeedOverride[id] = 0.0
				g_UserSpeedOverridePlugin[id] = 0
			}
		}
		case SPEED_OVERRIDE:
		{
			if(g_UserSpeedOverridePlugin[id] && g_UserSpeedOverridePlugin[id] != Plugin)
				return FAILED
			
			g_UserSpeedOverride[id] = Value
			g_UserSpeedOverridePlugin[id] = Plugin
		}
		case SPEED_MUL:
		{
			if(Value < 0.001)
				Value = 0.001
			
			new Float:PrevSpeed
			if(TrieGetCell(g_UserSpeedTrie[id], g_Menu, PrevSpeed) && PrevSpeed)
				Value *= PrevSpeed
			
			if(Value < 1.001 && Value > 0.999 )
				TrieDeleteKey(g_UserSpeedTrie[id], g_Menu);
			else
				TrieSetCell(g_UserSpeedTrie[id], g_Menu, Value);
		}
	}
	
	// Fake a reset in case client_PreThink() skips.
	set_user_maxspeed(id, g_UserMaxSpeed[id]);
	
	return SUCCEEDED
}
public _DRP_GetUserTotalItems(Plugin, Params)
{
	if(Params != 1)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 1,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new id = get_param(1);
	if(!g_UserItemTrie[id] || g_UserItemTrie[id] == Invalid_Trie)
		return FAILED
	
	new Snapshot:Iter = TrieSnapshotCreate(g_UserItemTrie[id]);
	new Size = TrieSnapshotLength(Iter);
	
	TrieSnapshotDestroy(Iter);
	
	return Size
}
public _DRP_ForceUseItem(Plugin, Params)
{
	if(Params != 3)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 3,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new id = get_param(1), ItemID = get_param(2), UseUp = get_param(3);
	
	if(UseUp && !UTIL_GetUserItemNum(id, ItemID))
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "User %d has none of ItemID: %d", Plugin, id, ItemID);
		return FAILED
	}
	if(!UTIL_ValidItemID(ItemID))
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Invalid ItemID: %d", Plugin, ItemID);
		return FAILED
	}
	
	ItemUse(id, ItemID, UseUp ? 1 : 0);
	return SUCCEEDED
}
public _DRP_FetchUserItems(Plugin, Params)
{
	if(Params != 2)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 2,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new id = get_param(1);
	
	new Num, ItemID, Snapshot:trieIter = TrieSnapshotCreate(g_UserItemTrie[id])
	new Results[128], ItemNum = TrieSnapshotLength(trieIter);
	
	//TODO:
	// FIX ME - WHY 2??
	if(ItemNum < 2)
		return FAILED
	
	for(new Count = 0, Success;Count < ItemNum;Count++)
	{
		//TrieSnapshotGetKey(trieIter, Count, 
		//ItemID = array_get_nth(g_UserItemArray[id], Count, _, Success);
		
		// TODO: FIX FIX
		//if(ItemID < 1 || ItemID > g_ItemsNum || !Success)
		//continue
		
		Results[Num++] = ItemID
	}
	
	//set_array(2, Results, Size);
	
	//return Size - 1
}

public _DRP_CreateItemDrop(Plugin, Params)
{
	if(Params != 3)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 4,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new ItemID = get_param(1), Num = get_param(2)
	if(!UTIL_ValidItemID(ItemID))
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Invalid ItemID - %d", Plugin, ItemID);
		return FAILED
	}
	if(!Num)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Invalid Item Amount - %d", Plugin, Num);
		return FAILED
	}
	
	new ItemName[33], Float:Origin[3]
	UTIL_GetItemName(ItemID, ItemName);
	
	get_array_f(3, Origin, 2);
	
	if(!_CreateItemDrop(0, Origin, Num, ItemName))
		return FAILED
	
	return SUCCEEDED
}
public _DRP_CreateMoneyBag(Plugin, Params)
{
	if(Params < 2)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 2 or less,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new Cash = get_param(1);
	
	if(Cash < 1)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Invalid cash value: %d", Plugin, Cash);
		return FAILED
	}
	
	new Ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))
	if(!Ent)
		return FAILED
	
	new Float:Origin[3]
	get_array_f(2, Origin, 3);
	
	engfunc(EngFunc_SetModel, Ent, g_drpMoneyModel);
	engfunc(EngFunc_SetSize, Ent, {-2.79, -0.0, -6.14}, {2.42, 1.99, 6.35});
	engfunc(EngFunc_SetOrigin, Ent, Origin);
	
	set_pev(Ent, pev_movetype, MOVETYPE_TOSS);
	set_pev(Ent, pev_solid, SOLID_TRIGGER);
	
	Origin[0] = 0.0
	Origin[1] = random_float(0.0, 270.0);
	Origin[2] = 0.0
	
	set_pev(Ent, pev_angles, Origin);
	set_pev(Ent, pev_takedamage, DAMAGE_NO);
	
	new UserID = get_param(3);
	if(UserID)
	{
		velocity_by_aim(UserID, 300, Origin);
		set_pev(Ent, pev_velocity, Origin);
		set_pev(Ent, pev_owner, UserID);
	}
	
	set_pev(Ent, pev_classname, g_drpEntMoney);
	set_pev(Ent, pev_iuser3, Cash);
	
	set_pev(Ent, pev_renderfx, kRenderFxGlowShell);
	set_pev(Ent, pev_rendercolor, {0.0, 255.0, 0.0});
	set_pev(Ent, pev_rendermode, kRenderNormal);
	set_pev(Ent, pev_renderamt, 16);
	
	return Ent
}
public _DRP_GetItemName(Plugin, Params)
{
	if(Params != 3)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 3,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new ItemID = get_param(1), Len = get_param(3);
	if(!UTIL_ValidItemID(ItemID))
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Invalid ItemID: %d", Plugin, ItemID);
		return FAILED
	}
	
	new Name[33]
	UTIL_GetItemName(ItemID, Name);
	
	set_string(2, Name, Len);
	
	return SUCCEEDED
}
public _DRP_ItemInfo(Plugin, Params)
{	
	if(Params != 2)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 2,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new const id = get_param(1), ItemID = get_param(2);
	ItemInfo(id, ItemID);
	
	return SUCCEEDED
}
/*==================================================================================================================================================*/
public _DRP_RegisterEvent(Plugin, Params)
{
	if(Params != 2)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 2,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new Trie:trie = TrieCreate();
	ArrayPushCell(g_EventArray, trie);
	
	new Event[64], Handler[128]
	get_string(1, Event, 63);
	get_string(2, Handler, 127);
	
	format(Handler, 127, "%d|%s", Plugin, Handler);
	TrieSetString(trie, Event, Handler);
	
	return SUCCEEDED
}

public _DRP_DoEvent(Plugin, Params)
{
	if(Params != 3)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 3,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new Len = min(255, get_param(3));
	new Data[255]
	
	get_string(1, g_Menu, 255);
	get_array(2, Data, Len)
	
	return UTIL_Event(g_Menu, Data, Len);
}
public _DRP_AddMenuItem(Plugin, Params)
{
	if(Params != 3)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 3,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new const id = get_param(1);
	
	if(!g_MenuAccepting[id])
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Menu items can only be added durning the ^"Menu_Display^" event.", Plugin);
		return FAILED
	}
	
	new Name[33], Handler[64]
	get_string(2, Name, 32);
	get_string(3, Handler[1], 62);
	
	Handler[0] = Plugin
	
	if(TrieKeyExists(g_UserMenuTrie[id], Name))
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Menu item ^"%s^" already exists.", Plugin, Name);
		return FAILED
	}
	
	TrieSetString(g_UserMenuTrie[id], Name, Handler);
	
	return SUCCEEDED
}
/*==================================================================================================================================================*/
public _DRP_AddProperty(Plugin, Params)
{
	if(Params != 8)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 8,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new InternalName[64], ExternalName[64], OwnerName[33], OwnerAuth[36], Price, Profit, Locked, AccessStr[18]
	get_string(1, InternalName, 63);
	get_string(2, ExternalName, 63);
	get_string(3, OwnerName, 32);
	get_string(4, OwnerAuth, 35);
	
	Price = get_param(5);
	get_string(6, AccessStr, 17);
	
	Profit = get_param(7);
	Locked = get_param(8);
	
	if(UTIL_MatchProperty(InternalName) > -1)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Property already exists: ^"%s^"", Plugin, InternalName);
		return FAILED
	}
	
	AddProperty(InternalName, ExternalName, OwnerName, OwnerAuth, "", AccessStr, Price, Profit, Locked);
	
	format(g_Query, 4095, "INSERT INTO %s VALUES ('%s', '%s', '%s', '%s', '%d', '%s', '%d', '', '%d')", g_PropertyTable, InternalName, ExternalName, OwnerName, OwnerAuth, Price, AccessStr, Profit, Locked);
	UTIL_CleverQuery(g_Plugin, g_SqlHandle, "IgnoreHandle", g_Query);
	
	return SUCCEEDED
}
public _DRP_DeleteProperty(Plugin, Params)
{
	if(Params != 1)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 1,  Found: %d", Plugin, Params);
		return FAILED
	}
	/*
	new Property = get_param(1);
	if(!UTIL_ValidProperty(propertyId))
		return FAILED
	
	new Trie:Property = ArrayGetCell(g_PropertyArray, Property);
	if(propTrie != Invalid_Trie)
	{
		// Clear the memory for this property
		// but don't remove it from the array, to keep the index lined up
		TrieDestroy(propTrie);
		ArraySetCell(g_PropertyArray, Property, Invalid_Trie);
	}
	
	new name[36]
	TrieGetString(propTrie, "name", name, 35);
	
	formatex(g_Query, 4095, "DELETE FROM %s WHERE name='%s'", g_PropertyTable, name);
	UTIL_CleverQuery(g_Plugin, g_SqlHandle, "IgnoreHandle", g_Query);
	
	new numDoors = ArraySize(g_DoorArray);
	for(new Count;Count < numDoors;Count++)
	{
		new Trie:doorTrie = ArrayGetCell(g_DoorArray, Count);
		if(doorTrie != Invalid_Trie)
		{
			TrieGetString(doorTrie, "property", g_Menu, 255);
			
			if(equali(g_Menu, name))
				UTIL_DeleteDoor(Count);
		}
	}
	*/
	return SUCCEEDED
}
public _DRP_AddDoor(Plugin, Params)
{
	if(Params != 3)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 3,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new TargetName[33], PropertyName[64], EntID = get_param(2);
	get_string(1, TargetName, 32);
	get_string(3, PropertyName, 63);
	
	if(UTIL_GetProperty(TargetName, EntID) != -1)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Door already exists: %s (EntID: %d)", TargetName, EntID);
		return 0 // Door already exists
	}
	else if(UTIL_MatchProperty(PropertyName) == -1)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Property does not exist: %s", PropertyName);
		return -1 // Property does not exist
	}
	
	AddDoor(TargetName, PropertyName, true);
	
	return SUCCEEDED
}
public _DRP_DeleteDoor(Plugin, Params)
{
	if(Params != 1)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 1,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new const Door = get_param(1)
	if(UTIL_ValidDoor(Door))
		return UTIL_DeleteDoor(Door);
	
	return FAILED
}
public _DRP_ValidProperty(Plugin, Params)
{
	if(Params != 1)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 1,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	return UTIL_ValidProperty(get_param(1));
}
public _DRP_ValidDoor(Plugin, Params)
{
	if(Params != 1)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 1,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	return UTIL_ValidDoor(get_param(1));
}
public _DRP_ValidPropertyName(Plugin, Params)
{
	if(Params != 1)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 1,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new InternalName[64]
	get_string(1, InternalName, 63);
	
	if(UTIL_MatchProperty(InternalName) > -1)
		return SUCCEEDED
	
	return FAILED
}
public _DRP_ValidDoorName(Plugin, Params)
{
	if(Params != 2)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 2,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new const Ent = get_param(2);
	new Targetname[33]
	get_string(1, Targetname, 32);
	
	if(UTIL_GetProperty(Targetname, Ent) > -1)
		return SUCCEEDED
	
	return FAILED
}

public _DRP_PropertyNum()
	return ArraySize(g_PropertyArray)

public _DRP_DoorNum()
	return ArraySize(g_DoorArray)

public _DRP_PropertyMatch(Plugin, Params)
{
	if(Params != 3)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 3,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new Targetname[33], EntID = get_param(2), InternalName[64]
	get_string(1, Targetname, 32);
	get_string(3, InternalName, 63);
	
	if(Targetname[0] || EntID)
		return UTIL_GetProperty(Targetname, EntID) + 1
	
	return UTIL_MatchProperty(InternalName) + 1
}

public _DRP_DoorMatch(Plugin, Params)
{
	if(Params != 2)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 2,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new Targetname[33], EntID = get_param(2);
	get_string(1, Targetname, 32);
	
	if(Targetname[0] || EntID)
		return UTIL_GetDoor(Targetname, EntID) + 1
	
	return FAILED
}
public _DRP_PropertyGetInternalName(Plugin, Params)
{
	if(Params != 3)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 3,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new Property = get_param(1), InternalName[64]
	if(!UTIL_ValidProperty(Property))
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Property does not exist: %d", Plugin, Property);
		return FAILED
	}
	
	ArrayGetString(ArrayGetCell(g_PropertyArray, Property), 0, InternalName, 63);
	set_string(2, InternalName, get_param(3));
	
	return SUCCEEDED
}
public _DRP_PropertyGetExternalName(Plugin, Params)
{
	if(Params != 3)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 3,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new Property = get_param(1), ExternalName[64]
	if(!UTIL_ValidProperty(Property))
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Property does not exist: %d", Plugin, Property);
		return FAILED
	}
	
	ArrayGetString(ArrayGetCell(g_PropertyArray, Property), 1, ExternalName, 63);
	set_string(2, ExternalName, get_param(3));
	
	return SUCCEEDED
}
public _DRP_PropertySetExternalName(Plugin, Params)
{
	if(Params != 2)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 2,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new Property = get_param(1), ExternalName[64]
	if(!UTIL_ValidProperty(Property))
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Property does not exist: %d", Plugin, Property);
		return FAILED
	}
	
	get_string(2, ExternalName, 63);
	ArraySetString(ArrayGetCell(g_PropertyArray, Property), 1, ExternalName);
	
	UTIL_PropertyChanged(Property);
	
	return SUCCEEDED
}
public _DRP_PropertyGetOwnerName(Plugin, Params)
{
	if(Params != 3)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 3,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new Property = get_param(1), OwnerName[33]
	if(!UTIL_ValidProperty(Property))
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Property does not exist: %d", Plugin, Property);
		return FAILED
	}
	
	ArrayGetString(ArrayGetCell(g_PropertyArray, Property), 2, OwnerName, 33);
	set_string(2, OwnerName, get_param(3));
	
	return SUCCEEDED
}
public _DRP_PropertySetOwnerName(Plugin, Params)
{
	if(Params != 2)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 3,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new Property = get_param(1), OwnerName[33]
	if(!UTIL_ValidProperty(Property))
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Property does not exist: %d", Plugin, Property);
		return FAILED
	}
	
	UTIL_PropertyChanged(Property)
	
	get_string(2, OwnerName, 32);
	ArraySetString(ArrayGetCell(g_PropertyArray, Property), 2, OwnerName);
	
	return SUCCEEDED
}
public _DRP_PropertyGetOwnerAuth(Plugin, Params)
{
	if(Params != 3)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 3,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new Property = get_param(1), OwnerAuth[33]
	if(!UTIL_ValidProperty(Property))
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Property does not exist: %d", Plugin, Property);
		return FAILED
	}
	
	ArrayGetString(ArrayGetCell(g_PropertyArray, Property), 3, OwnerAuth, 33);
	set_string(2, OwnerAuth, get_param(3));
	
	return SUCCEEDED
}
public _DRP_PropertySetOwnerAuth(Plugin, Params)
{
	if(Params != 2)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 2,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new Property = get_param(1), OwnerAuth[33]
	if(!UTIL_ValidProperty(Property))
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Property does not exist: %d", Plugin, Property);
		return FAILED
	}
	
	UTIL_PropertyChanged(Property);
	
	get_string(2, OwnerAuth, 32);
	ArraySetString(ArrayGetCell(g_PropertyArray, Property), 3, OwnerAuth);
	
	return SUCCEEDED
}
public _DRP_PropertyAddAccess(Plugin, Params)
{
	if(Params != 2)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 2,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new Property = get_param(1), AuthID[36], InternalName[64]
	get_string(2, AuthID, 35);
	
	if(!UTIL_ValidProperty(Property))
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Property does not exist: %d", Plugin, Property);
		return FAILED
	}
	
	UTIL_PropertyChanged(Property);
	
	new Array:CurArray = ArrayGetCell(g_PropertyArray, Property);
	ArrayGetString(CurArray, 0, InternalName, 63);
	
	format(g_Query, 4095, "INSERT INTO %s VALUES('%s|%s')", g_KeysTable, AuthID, InternalName);
	UTIL_CleverQuery(g_Plugin, g_SqlHandle, "IgnoreHandle", g_Query);
	
	new PlayerAuthID[36], iPlayers[32], iNum, Index
	get_players(iPlayers, iNum);
	
	for(new Count;Count < iNum;Count++)
	{
		Index = iPlayers[Count]
		get_user_authid(Index, PlayerAuthID, 35);
		
		if(equali(AuthID, PlayerAuthID))
		{
			ArraySetCell(CurArray, 8, ArrayGetCell(CurArray, 8)|(1<<(Index - 1)));
			break
		}
	}
	
	return SUCCEEDED
}
public _DRP_PropertyRemoveAccess(Plugin, Params)
{
	if(Params != 2)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 2,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new Property = get_param(1), AuthID[36], InternalName[64]
	get_string(2, AuthID, 35);
	
	if(!UTIL_ValidProperty(Property))
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Property does not exist: %d", Plugin, Property);
		return FAILED
	}
	
	UTIL_PropertyChanged(Property);
	
	new Array:CurArray = ArrayGetCell(g_PropertyArray, Property);
	ArrayGetString(CurArray, 0, InternalName, 63);
	
	format(g_Query, 4095, "DELETE FROM %s WHERE authidkey='%s|%s'", g_KeysTable, AuthID, InternalName)
	UTIL_CleverQuery(g_Plugin, g_SqlHandle, "IgnoreHandle", g_Query);
	
	new PlayerAuthID[36], iPlayers[32], iNum, Index
	get_players(iPlayers, iNum);
	
	for(new Count;Count < iNum;Count++)
	{
		Index = iPlayers[Count]
		get_user_authid(Index, PlayerAuthID, 35);
		
		if(equali(AuthID, PlayerAuthID))
		{
			ArraySetCell(CurArray, 8, ArrayGetCell(CurArray, 8) & ~(1<<(Index - 1)))
			break
		}
	}
	
	return SUCCEEDED
}
public _DRP_PropertyGetAccess(Plugin, Params)
{
	if(Params != 1)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 1,  Found: %d", Plugin, Params);
		return FAILED
	}
	new Property = get_param(1)
	return ArrayGetCell(ArrayGetCell(g_PropertyArray, Property), 6);
	
}
public _DRP_PropertyGetProfit(Plugin, Params)
{
	if(Params != 1)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 1,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new Property = get_param(1) 
	if(!UTIL_ValidProperty(Property))
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Property does not exist: %d", Property);
		return FAILED
	}
	
	return ArrayGetCell(ArrayGetCell(g_PropertyArray, Property), 7);
}
public _DRP_PropertySetProfit(Plugin, Params)
{
	if(Params != 2)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 2,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new Property = get_param(1) 
	if(!UTIL_ValidProperty(Property))
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Property does not exist: %d", Property);
		return FAILED
	}
	
	UTIL_PropertyChanged(Property);
	ArraySetCell(ArrayGetCell(g_PropertyArray, Property), 7, max(0, get_param(2)));
	
	return SUCCEEDED
}
public _DRP_PropertyGetPrice(Plugin, Params)
{
	if(Params != 1)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 2,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new Property = get_param(1)
	if(!UTIL_ValidProperty(Property))
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Property does not exist: %d", Property);
		return FAILED
	}
	
	return ArrayGetCell(ArrayGetCell(g_PropertyArray, Property), 4);
}
public _DRP_PropertySetPrice(Plugin, Params)
{
	if(Params != 2)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 2,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new const Property = get_param(1), Price = get_param(2)
	if(!UTIL_ValidProperty(Property))
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Property does not exist: %d", Property);
		return FAILED
	}
	
	new Data[2]
	Data[0] = Property + 1
	Data[1] = Price
	
	if(UTIL_Event("Property_SetPrice", Data, 2) == EVENT_HALT)
		return FAILED
	
	ArraySetCell(ArrayGetCell(g_PropertyArray, Property), 4, max(0, Price));
	UTIL_PropertyChanged(Property);
	
	return SUCCEEDED
}
public _DRP_PropertySetMessage(Plugin, Params)
{
	if(Params != 2)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 2,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new Property = get_param(1)
	if(!UTIL_ValidProperty(Property))
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Property does not exist: %d", Property);
		return FAILED
	}
	
	get_string(2, g_Menu, 255);
	
	new Len = strlen(g_Menu);
	
	if(Len > 128)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Property message must not be longer than 128 chars. (%d - current length)", Len);
		return FAILED
	}
	
	ArraySetString(ArrayGetCell(g_PropertyArray, Property), 10, g_Menu);
	UTIL_PropertyChanged(Property);
	
	return SUCCEEDED
}
public _DRP_PropertyGetMessage(Plugin, Params)
{
	if(Params != 3)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 3,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new Property = get_param(1)
	if(!UTIL_ValidProperty(Property))
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Property does not exist: %d", Property);
		return FAILED
	}
	
	ArrayGetString(ArrayGetCell(g_PropertyArray, Property), 10, g_Menu, 255);
	set_string(2, g_Menu, get_param(3));
	
	return SUCCEEDED
}
public _DRP_PropertySetLocked(Plugin, Params)
{
	if(Params != 2)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 2,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new Property = get_param(1) - 1
	if(!UTIL_ValidProperty(Property))
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Property does not exist: %d", Plugin, Property);
		return FAILED
	}
	
	UTIL_PropertyChanged(Property);
	ArraySetCell(ArrayGetCell(g_PropertyArray, Property), 5, get_param(2) ? 1 : 0);
	
	return SUCCEEDED
}
public _DRP_PropertyGetLocked(Plugin, Params)
{
	if(Params != 1)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 1,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new Property = get_param(1) - 1
	if(!UTIL_ValidProperty(Property))
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Property does not exist: %d", Plugin, Property);
		return FAILED
	}
	
	return ArrayGetCell(ArrayGetCell(g_PropertyArray, Property), 5);
}
public _DRP_PropertyDoorSetLocked(Plugin, Params)
{
	if(Params != 2)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 2,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new Index = get_param(1);
	if(!Index || !is_valid_ent(Index))
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Door does not exist: %d", Plugin, Index);
		return FAILED
	}
	
	new TargetName[33], DoorArray
	pev(Index, pev_targetname, TargetName, 32);
	
	if(UTIL_GetProperty(TargetName, Index, DoorArray) == -1)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Door not linked to a property.", 0);
		return FAILED
	}
	
	UTIL_DoorChanged(DoorArray);
	ArraySetCell(ArrayGetCell(g_DoorArray, DoorArray), 4, get_param(2) ? 1 : 0);
	
	return SUCCEEDED
}
public _DRP_PropertyDoorGetLocked(Plugin, Params)
{
	if(Params != 1)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Parameters do not match. Expected: 1,  Found: %d", Plugin, Params);
		return FAILED
	}
	
	new Index = get_param(1);
	if(!Index || !is_valid_ent(Index))
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Door does not exist: %d", Plugin, Index);
		return FAILED
	}
	
	new TargetName[33], DoorArray
	pev(Index, pev_targetname, TargetName, 32);
	
	if(UTIL_GetProperty(TargetName, Index, DoorArray) == -1)
	{
		UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Door not linked to a property.", 0);
		return FAILED
	}
	
	return ArrayGetCell(ArrayGetCell(g_DoorArray, DoorArray), 4);
}
/*==================================================================================================================================================*/
// UTIL Functions
/**
 * @note Logs an error
 * @note This should only be used when it's a logic/dev error. 
 * @note Events/Transactions/Gameplay should be logged with UTIL_Log
 *
 * @param Plugin  	 		Name of the plugin
 * @param ErrorType       	Version of the plugin
 * @param isFatal        	Author of the plugin
 *
 * @noreturn
 */
UTIL_Error(Plugin=0, ErrorType=AMX_ERR_GENERAL, bool:isFatal, const Message[], any:...)
{
	vformat(g_Query, 4095, Message, 5);
	
	// Hacky Timestamp
	if(g_PluginEnd)
	{
		format(g_Menu, 255, " - [TOTAL RUN TIME %d MINUTES]", floatround((get_gametime() / 60.0)));
		add(g_Query, 4095, g_Menu);
	}
	
	new Name[64], FileName[64], Temp[2];
	if(Plugin)
		get_plugin(Plugin, FileName, 63, Name, 63, Temp, 1, Temp, 1, Temp, 1);
	else
	{
		copy(Name, 63, "DRP - Core");
		copy(FileName, 63, "DRPCore.amxx");
	}
	
	UTIL_Log(Plugin, "[ERROR] %s", g_Query);
	log_error(ErrorType, "[DRP] [PLUGIN: %s] %s %s", FileName, g_Query, isFatal ? "(Fatal Error - DRP Shutdown)" : "");
	
	if(isFatal)
	{
		// this was fatal
		// tell other plugins that we are shutting down
		new Forward = CreateMultiForward("DRP_Error", ET_IGNORE, FP_STRING), Results
		if(Forward <= 0 || !ExecuteForward(Forward, Results, g_Query))
			return
		
		DestroyForward(Forward);
		pause("d");
	}
}
UTIL_Log(Plugin = 0, const Message[], any:...)
{
	vformat(g_Query, 4095, Message, 3);
	
	new Name[64], FileName[64], Temp[2];
	if(Plugin)
		get_plugin(Plugin, FileName, 63, Name, 63, Temp, 1, Temp, 1, Temp, 1);
	else
	{
		copy(Name, 63, "DRP - Core");
		copy(FileName, 63, "DRPCore.amxx");
	}
	
	new Date[64]
	get_time("%m-%d-%Y", Date, 63);

	// g_Menu[] as a cache
	formatex(g_Menu, 255, "%s/%s.log", g_LogDir, Date);
	log_to_file(g_Menu, "[DRP] [%s] %s", FileName, g_Query);
	
	if(get_pcvar_num(p_LogtoAdmins))
	{
		for(new Count;Count <= g_MaxPlayers;Count++)
		{
			if(UTIL_UserIsAdmin(Count))
				client_print(Count, print_chat, "[DRP] [%s] %s", FileName, g_Query);
		}
	}
	
	return SUCCEEDED
}
UTIL_ValidItemID(ItemID)
{
	new itemsNum = ArraySize(g_ItemsArray)
	if(ItemID < itemsNum && ItemID >= 0)
		return SUCCEEDED
	
	return FAILED
}
UTIL_ValidJobID(JobID)
{
	new jobsNum = ArraySize(g_JobArray)
	if(JobID < jobsNum && JobID >= 0)
		return SUCCEEDED
	
	return FAILED
}
UTIL_ValidProperty(Property)
{
	new propertyNum = ArraySize(g_PropertyArray)
	if(Property >= 0 && Property < propertyNum)
		return SUCCEEDED
	
	return FAILED
}
UTIL_ValidDoor(Door)
{
	new doorNum = ArraySize(g_DoorArray)
	if(Door >= 0 && Door < doorNum)
		return SUCCEEDED
	
	return FAILED
}
UTIL_DeleteDoor(Door)
{
	// TODO:
	// FIX ME FIX ME
	/*
	new Targetname[33], InternalName[64], Array:CurArray, Array:NextArray, Array:DoorArray = ArrayGetCell(g_DoorArray, Door);
	ArrayGetString(DoorArray, 2, InternalName, 63);
	
	format(g_Query, 4095, "DELETE FROM %s WHERE Internalname='%s'", g_DoorsTable, InternalName);
	UTIL_CleverQuery(g_Plugin, g_SqlHandle, "IgnoreHandle", g_Query);
	
	for(new Count = Door;Count < g_DoorNum - 1;Count++)
	{
	NextArray = ArrayGetCell(g_DoorArray, Count + 1);
	ArrayGetString(NextArray, 0, Targetname, 32);
	ArrayGetString(NextArray, 2, InternalName, 63);
	
	CurArray = ArrayGetCell(g_DoorArray, Count);
	ArraySetString(CurArray, 0, Targetname);
	
	ArraySetCell(CurArray, 1, ArrayGetCell(NextArray, 1));
	ArraySetString(CurArray, 2, InternalName);
	
	ArraySetCell(CurArray, 3, ArrayGetCell(NextArray, 3));
	ArraySetCell(g_DoorArray, Count, NextArray);
	}
	
	ArrayDestroy(DoorArray);
	ArrayDeleteItem(g_DoorArray, --g_DoorNum);
	*/
	
	return SUCCEEDED
}
UTIL_DeleteJob(JobID)
{
	new iPlayers[32], iNum, Index, Jobs[1]
	get_players(iPlayers, iNum);
	
	if(!DRP_FindJobID("Unemployed", Jobs, 1))
	{
		//UTIL_Error(Plugin, AMX_ERR_NATIVE, false, "Error finding ^"Unemployed^" job." );
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
	ArrayGetString(ArrayGetCell(g_JobArray, JobID), 1, Name, 32);
	
	format(g_Query, 4095, "DELETE FROM %s WHERE JobName='%s'", g_JobsTable, Name);
	UTIL_CleverQuery(g_Plugin, g_SqlHandle, "IgnoreHandle", g_Query);
	
	new Array:JobArray = ArrayGetCell(g_JobArray, JobID);
	ArrayDestroy(JobArray);
	ArraySetCell(g_JobArray, JobID, -1);
	
	return SUCCEEDED
}

UTIL_GetUserItemNum(id, ItemID)
{
	new ItemNumEx[5], ItemIDEx[5]
	formatex(ItemIDEx, 4, "%d", ItemID);
	
	new Result = TrieGetString(g_UserItemTrie[id], ItemIDEx, ItemNumEx, 4);
	if(Result)
		return abs(str_to_num(ItemNumEx));
	
	return 0
}

UTIL_GetItemName(ItemID, Name[33])
{
	new Trie:trie = ArrayGetCell(g_ItemsArray, ItemID);
	if(trie == Invalid_Trie)
		return FAILED
	
	TrieGetString(trie, "name", Name, 32);
}

UTIL_PropertyChanged(Property)
ArraySetCell(ArrayGetCell(g_PropertyArray, Property), 9, 1);
UTIL_DoorChanged(DoorArray)
ArraySetCell(ArrayGetCell(g_DoorArray, DoorArray), 3, 1);


UTIL_FindItemID(const ItemName[])
{
	static Name[36]
	new ItemNum = ArraySize(g_ItemsArray);
	
	for(new Count = 0;Count < ItemNum;Count++)
	{
		new Trie:trie = ArrayGetCell(g_ItemsArray, Count);
		if(trie != Invalid_Trie)
		{
			TrieGetString(trie, "name", Name, 35);
			if(equali(Name, ItemName))
				return Count
		}
	}
	return -1
}
UTIL_FindJobID(const JobName[])
{
	static Name[33]
	new JobNum = ArraySize(g_JobArray)
	
	for(new Count = 0;Count < JobNum;Count++)
	{
		new Trie:trie = ArrayGetCell(g_JobArray, Count);
		if(trie != Invalid_Trie)
		{
			TrieGetString(trie, "name", Name, 32);
			if(equali(Name, JobName))
				return Count
		}
	}
	return -1
}
UTIL_SetUserItemNum(id, ItemID, Num)
{
	if(!UTIL_ValidItemID(ItemID))
		return FAILED
	
	new ItemName[33], ItemIDEx[5]
	formatex(ItemName, 32, "%d", Num);
	formatex(ItemIDEx, 4, "%d", ItemID);
	
	if(Num > 0)
		TrieSetString(g_UserItemTrie[id], ItemIDEx, ItemName);
	
	else
	{
		// Removing Item
		TrieDeleteKey(g_UserItemTrie[id], ItemIDEx);
		
		new AuthID[36]
		get_user_authid(id, AuthID, 35);
		
		UTIL_GetItemName(ItemID, ItemName);
		DRP_SqlEscape(ItemName, 32);
		
		formatex(g_Query, 4095, "DELETE FROM %s WHERE steamid_name='%s|%s'", g_ItemsTable, AuthID, ItemName);
		UTIL_CleverQuery(g_Plugin, g_SqlHandle, "IgnoreHandle", g_Query);
	}
	
	return SUCCEEDED
}

UTIL_GetProperty(const Targetname[] = "", EntID = 0, &DoorArray=0)
{
	//TODO: FIX ME FIX ME
	/*
	static PropertyName[64]
	for(new Count, Array:CurArray;Count < g_DoorNum;Count++)
	{
	CurArray = ArrayGetCell(g_DoorArray, Count);
	ArrayGetString(CurArray, 0, PropertyName, 63);
	
	if((equali(PropertyName, Targetname) && Targetname[0]) || (EntID && EntID == ArrayGetCell(CurArray, 1)))
	{
	ArrayGetString(CurArray, 2, PropertyName, 63);
	DoorArray = Count
	return UTIL_MatchProperty(PropertyName);
	}
	}
	*/
	return -1
}
UTIL_GetDoor(const Targetname[] = "", EntID = 0)
{
	// TODO: FIX ME FIX ME
	/*
	static PropertyTargetname[33]
	for(new Count, Array:CurArray;Count < g_DoorNum;Count++)
	{
	CurArray = ArrayGetCell(g_DoorArray, Count);
	ArrayGetString(CurArray, 0, PropertyTargetname, 32)
	
	if((equali(PropertyTargetname, Targetname) && Targetname[0]) || (EntID && EntID == ArrayGetCell(CurArray, 1)))
		return Count
	}
	*/
	return FAILED
}
UTIL_MatchProperty(const InternalName[])
{
	static Name[64]
	new PropertyNum = ArraySize(g_PropertyArray);
	
	for(new Count;Count < PropertyNum;Count++)
	{
		new Trie:trie = ArrayGetCell(g_PropertyArray, Count);
		if(trie != Invalid_Trie)
		{
			TrieGetString(trie, "name", Name, 63);
			if(equali(Name, InternalName))
				return Count
		}
	}
	return -1
}
UTIL_LoadConfigFile(bool:ServerExec = false)
{
	new FileName[256]
	formatex(FileName, 255, "%s/DRPCore.cfg", g_ConfigDir);
	
	DRP_Log("Reading config file: %s", FileName);
	
	new File = fopen(FileName, "r"), Left[128], Right[128]
	if(!File)
	{
		UTIL_Error(_, _, true, "Failed to open config file (%s)", FileName);
		return
	}
	
	while(!feof(File))
	{
		fgets(File, g_Menu, 255);
		trim(g_Menu);
		
		if(g_Menu[0] == ';' || (g_Menu[0] == '/' && g_Menu[1] == '/'))
			continue
		
		parse(g_Menu, Left, sizeof Left - 1, Right, sizeof Right - 1)
		remove_quotes(Left)
		trim(Left)
		remove_quotes(Right)
		trim(Right)
		strtolower(Left);
		
		if(Left[0] && Right[0])
		{
			if(equali(Left, sql_Host))
				set_cvar_string(sql_Host, Right);
			else if(equali(Left, sql_DB))
				set_cvar_string(sql_DB, Right);
			else if(equali(Left, sql_User))
				set_cvar_string(sql_User, Right);
			else if(equali(Left, sql_Pass))
				set_cvar_string(sql_Pass, Right);
			
			else if(equali(Left, "DRP_GodBreakables"))
				set_pcvar_num(p_GodBreakables, 1);
			else if(equali(Left, "DRP_GodDoors"))
				set_pcvar_num(p_GodDoors, 1);
			
		}
	}
	fclose(File);
	
	if(ServerExec)
	{
		server_cmd("exec %s", FileName);
		server_exec();
	}
}
UTIL_AddHudItem(id, Channel, const Message[])
{
	if(id == -1)
	{
		new iPlayers[32], iNum
		get_players(iPlayers, iNum);
		
		new id
		for(new Count;Count < iNum;Count++)
		{
			id = iPlayers[Count]
			ArrayPushString(g_UserHudArray[id][Channel], Message);
		}
	}
	else
	{
		ArrayPushString(g_UserHudArray[id][Channel], Message);
	}
}


public IgnoreHandle(FailState, Handle:Query, const Error[], Errcode, const Data[], DataSize) 
{
	if(CheckSQLState(Query, FailState, Error) == FAILED)
		return FAILED
	
	return PLUGIN_CONTINUE
}

UTIL_CleverQuery(PluginGiven, Handle:Tuple, const Handler[], const QueryS[], Data[] = "", Len = 0)
	return _DRP_CleverQuery(PluginGiven, Tuple, Handler, QueryS, Data, Len) ? SQL_ThreadQuery(Tuple, Handler, QueryS, Data, Len) : PLUGIN_HANDLED

UTIL_Event(const Name[], const Data[], Length)
{
	static Handler[33], Key[128]
	new EventNum = ArraySize(g_EventArray),  Plugin,  PluginStr[12],  Forward, CurArray = PrepareArray(Data, Length);
	new bool:Halted = false
	
	for(new Count;Count < EventNum;Count++)
	{
		new Trie:trie = ArrayGetCell(g_EventArray, Count);
		if(trie == Invalid_Trie)
			continue
		
		if(!TrieKeyExists(trie, Name))
			continue
		
		TrieGetString(trie, Name, Key, 127);
		strtok(Key, PluginStr, 11, Handler, 32, '|');
		
		Plugin = str_to_num(PluginStr);
		Forward = CreateOneForward(Plugin, Handler, FP_ARRAY, FP_CELL);
	
		new Return
		if(Forward <= 0 || !ExecuteForward(Forward, Return, CurArray, Length))
		{
			UTIL_Error(_, _, false, "Could not execute forward. Function: %s - PluginID: %d", Handler, Plugin);
			return FAILED
		}
		
		if(Return == EVENT_HALT)
			Halted = true
		
		DestroyForward(Forward);
	}
	
	new Return
	if(!ExecuteForward(g_EventForward, Return, Name, CurArray, Length))
	{
		UTIL_Error(_, _, false, "Could not execute ^"DRP_Event^" forward.");
		return FAILED
	}
	
	if(Return == EVENT_HALT)
		Halted = true
	
	return Halted
}
_DRP_CleverQuery(Plugin, Handle:Tuple, const Handler[], const QueryS[], Data[] = "", Len = 0)
{
	if(!get_playersnum() || g_PluginEnd)
	{
		new ErrorCode, Handle:SqlConnection = SQL_Connect(Tuple, ErrorCode, g_Menu, 255);
		if(SqlConnection == Empty_Handle)
		{
			CleverQueryFunction(Plugin, Handler, TQUERY_CONNECT_FAILED, Empty_Handle, g_Menu, ErrorCode, Data, Len, 0.0);
			SQL_FreeHandle(SqlConnection);
			return PLUGIN_CONTINUE
		}
		
		new Handle:Query = SQL_PrepareQuery(SqlConnection, QueryS);
		
		if(!SQL_Execute(Query))
		{
			ErrorCode = SQL_QueryError(Query, g_Menu, 255);
			
			SQL_FreeHandle(Query);
			SQL_FreeHandle(SqlConnection);
			
			CleverQueryFunction(Plugin, Handler, TQUERY_QUERY_FAILED, Query, g_Menu, ErrorCode, Data, Len, 0.0);
			return PLUGIN_CONTINUE
		}
		
		CleverQueryFunction(Plugin, Handler, TQUERY_SUCCESS, Query, "", 0, Data, Len, 0.0);
		
		SQL_FreeHandle(Query);
		SQL_FreeHandle(SqlConnection);
		
		return PLUGIN_CONTINUE
	}
	
	return PLUGIN_HANDLED
}
CleverQueryFunction(PluginGiven, const HandlerS[], FailState, Handle:Query, const Error[], Errcode, const PassData[], Len, Float:HangTime)
{
	new Forward = CreateOneForward(PluginGiven, HandlerS, FP_CELL, FP_CELL, FP_STRING, FP_CELL, FP_ARRAY, FP_CELL, FP_CELL), CurArray = Len ? PrepareArray(PassData, Len) : 0, Return
	if(Forward <= 0|| !ExecuteForward(Forward, Return, FailState, Query, Error, Errcode, CurArray, Len, HangTime))
	{
		DRP_Log("[DRP CORE] [ERROR] Could not execute forward to %d: %s", PluginGiven, HandlerS);
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

ArrayTrieClear(Array:TrieArray)
{
	if(TrieArray == Invalid_Array)
		return
	
	new Size = ArraySize(TrieArray);
	for(new Count;Count < Size;Count++)
	{
		new Trie:trie = ArrayGetCell(TrieArray, Count);
		if(trie != Invalid_Trie)
			TrieDestroy(trie);
	}
	ArrayDestroy(TrieArray);
}

public plugin_end()
{
	g_PluginEnd = 1
	SaveData_Forward();
	
	for(new Count,Count2; Count <= g_MaxPlayers; Count++)	
	{
		TrieDestroy(g_UserMenuTrie[Count]);
		TrieDestroy(g_UserDataTrie[Count]);
		TrieDestroy(g_UserItemTrie[Count]);
		
		for(Count2 = 0; Count2 < HUD_NUM; Count2++)
			ArrayDestroy(g_UserHudArray[Count][Count2])
		
		ArrayDestroy(g_UserAccessArray[Count]);
	}
	
	ArrayTrieClear(g_CommandArray);
	ArrayTrieClear(g_JobArray);
	ArrayTrieClear(g_PropertyArray);
	ArrayTrieClear(g_DoorArray);
	ArrayTrieClear(g_ItemsArray);
	ArrayTrieClear(g_EventArray);
	
	// Menus
	menu_destroy(g_MenuItemDrop);
	menu_destroy(g_MenuItemGive);
	menu_destroy(g_MenuItemOptions);
	menu_destroy(g_MenuName);
	menu_destroy(g_MenuProperty);
	
	// Forwards
	DestroyForward(g_HudForward);
	DestroyForward(g_EventForward);
	
	// SQL
	if(g_SqlHandle)
		SQL_FreeHandle(g_SqlHandle);
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
		UTIL_Event("Core_Save", "", 0);
	
	static iPlayers[32], Message[128]
	new iNum
	
	get_players(iPlayers, iNum);
	
	for(new Count;Count < iNum;Count++)
	{
		new id = iPlayers[Count]
		if(UTIL_UserIsLoaded(id))
			SaveUserData(id, false);
	}
	/*
	new InternalName[64], ExternalName[64], OwnerName[33], OwnerAuthid[36], Price, Locked, AccessStr[JOB_ACCESSES + 1], Access, Profit, Array:CurArray, Changed
	for(new Count;Count < g_PropertyNum;Count++)
	{		
	CurArray = ArrayGetCell(g_PropertyArray, Count), Changed = ArrayGetCell(CurArray, 9);
	if(!Changed)
		continue
	
	ArrayGetString(CurArray, 0, InternalName, 63);
	ArrayGetString(CurArray, 1, ExternalName, 63);
	ArrayGetString(CurArray, 2, OwnerName, 32);
	ArrayGetString(CurArray, 3, OwnerAuthid, 32);
	ArrayGetString(CurArray, 10, Message, 127);
	
	Price = ArrayGetCell(CurArray, 4);
	Locked = ArrayGetCell(CurArray, 5);
	Access = ArrayGetCell(CurArray, 6);
	Profit = ArrayGetCell(CurArray, 7);
	
	replace_all(ExternalName, 32, "'", "\'");
	replace_all(OwnerName, 32, "'", "\'");
	replace_all(Message, 127, "'", "\'");
	
	DRP_IntToAccess(Access, AccessStr, JOB_ACCESSES);
	
	format(g_Query, 4095, "INSERT INTO %s VALUES ('%s', '%s', '%s', '%s', '%d', '%s', '%d', '%s', '%d') ON DUPLICATE KEY UPDATE externalname='%s', ownername='%s', ownerauthid='%s', price='%d', access='%s', profit='%d', custommessage='%s', locked='%d'", g_PropertyTable, 
	InternalName, ExternalName, OwnerName, OwnerAuthid, Price, AccessStr, Profit, Message, Locked, 
	ExternalName, OwnerName, OwnerAuthid, Price, AccessStr, Profit, Message, Locked);
	
	UTIL_CleverQuery(g_Plugin, g_SqlHandle, "IgnoreHandle", g_Query);
	ArraySetCell(CurArray, 9, 0);
	
	#if defined DEBUG
	g_Querys++
	#endif
	}
	
	for(new Count;Count < g_DoorNum;Count++)
	{
	CurArray = ArrayGetCell(g_DoorArray, Count), Changed = ArrayGetCell(CurArray, 3);
	if(!Changed)
		continue
	
	ArrayGetString(CurArray, 0, OwnerName, 32); // Targetname actually
	Changed = ArrayGetCell(CurArray, 1);
	ArrayGetString(CurArray, 2, InternalName, 32);
	
	Changed ? 
	formatex(OwnerName, 32, "e|%d", Changed) : format(OwnerName, 32, "t|%s", OwnerName);
	
	Changed = ArrayGetCell(CurArray, 4);
	
	format(g_Query, 4095, "INSERT INTO %s VALUES ('%s', '%s', '%d') ON DUPLICATE KEY UPDATE internalname='%s', Locked='%d'", g_DoorsTable, OwnerName, InternalName, Changed, InternalName, Changed);
	UTIL_CleverQuery(g_Plugin, g_SqlHandle, "IgnoreHandle", g_Query);
	
	ArraySetCell(CurArray, 3, 0);
	

	formatex(Message, 127, "%d %d %d %d %d %d", 
	g_WorldTime[1], g_WorldTime[2], 
	g_WorldTime[4], g_WorldTime[5], 
	g_WorldTime[6], g_WorldTime[3]);
	
	format(g_Query, 4095, "UPDATE `time` SET `CurrentTime`='%s'", Message);
	UTIL_CleverQuery(g_Plugin, g_SqlHandle, "IgnoreHandle", g_Query);
	*/
}
SaveUserItems(id)
{
	new Snapshot:Iter = TrieSnapshotCreate(g_UserItemTrie[id])
	new Size = TrieSnapshotLength(Iter);
	
	if(!Size)
	{
		TrieSnapshotDestroy(Iter);
		return
	}
	
	new AuthID[36], ItemName[33], ItemIDEx[5]
	get_user_authid(id, AuthID, 35);
	
	for(new Count; Count < Size; Count++)
	{
		TrieSnapshotGetKey(Iter, Count, ItemIDEx, 4);
		
		// ItemName = Item Num
		TrieGetString(g_UserItemTrie[id], ItemIDEx, ItemName, 35);
		
		new Num = str_to_num(ItemName);
		if(Num < 1)
			continue
		
		new ItemID = str_to_num(ItemIDEx);
		
		UTIL_GetItemName(ItemID, ItemName);
		DRP_SqlEscape(ItemName, 32);
		
		if(!ItemName[0])
			continue
		
		Num = abs(Num);
		formatex(g_Query, 4095, "INSERT INTO %s VALUES('%s|%s', '%d') ON duplicate KEY UPDATE quantity='%d'", g_ItemsTable, AuthID, ItemName, Num, Num);
		UTIL_CleverQuery(g_Plugin, g_SqlHandle, "IgnoreHandle", g_Query);
	}
	TrieSnapshotDestroy(Iter);
}
SaveUserPluginData(id)
{
	new Snapshot:Iter = TrieSnapshotCreate(g_UserDataTrie[id]);
	new Size = TrieSnapshotLength(Iter);
	
	server_print("SAVING PLUGIN DATA");
	
	if(Size > 0)
	{
		new Key[36], Value[128]
		for(new Count = 0; Count < Size; Count++)
		{
			TrieSnapshotGetKey(Iter, Count, Key, 35);
			TrieGetString(g_UserDataTrie[id], Key, Value, 127);
			
			formatex(g_Menu, 255, "%s|%s", g_UserAuthID[id], Key);
			formatex(g_Query, 4095, "INSERT INTO %s (steamid_key, value) VALUES('%s','%s') ON DUPLICATE KEY UPDATE value='%s'", g_DataTable, g_Menu, Value, Value);
			
			UTIL_CleverQuery(g_Plugin,g_SqlHandle, "IgnoreHandle", g_Query);
		}
	}
	
	TrieSnapshotDestroy(Iter);
}
SaveUserData(id, bool:Disconnected)
{
	new Data[2]
	Data[0] = id
	Data[1] = Disconnected
	
	get_user_authid(id, g_UserAuthID[id], 35);
	
	if(regex_match_c(g_UserAuthID[id], Regex:g_RegexPatterns[REGEX_STEAMID]) < 1)
		return
	
	new PlayTime = ( get_user_time(id) / 60 ) + g_UserTime[id]
	
	SaveUserItems(id);
	SaveUserPluginData(id);
	
	new Buffer[256], JobName[33]
	UTIL_UserBuildAccess(id, Buffer);
	UTIL_UserJobName(id, JobName);
	
	formatex(g_Query, 4095, "UPDATE %s SET `bank`=%d , `wallet`=%d , \
		`jobname`='%s' , `access`='%s'  , `playtime`=%d \
		WHERE `SteamID`='%s'",
		g_UserTable, g_UserBank[id], g_UserWallet[id],
		JobName, Buffer, PlayTime,
		g_UserAuthID[id]
	);
	
	g_Saving[id] = true
	UTIL_CleverQuery(g_Plugin, g_SqlHandle, "SaveUserDataHandle", g_Query, Data, 2);
}

public SaveUserDataHandle(FailState, Handle:Query, const Error[], Errcode, const Data[], DataSize) 
{
	if(FailState != TQUERY_SUCCESS || Errcode)
		return UTIL_Error(_, _, false, "SQL Error (Error: %s)", Error ? Error : "UNKNOWN");
	
	new const id = Data[0]
	g_Saving[id] = false
	
	if(g_PluginEnd)
		return PLUGIN_CONTINUE
	
	new AuthID[36]
	get_user_authid(id, AuthID, 35);
	
	if(Data[1] || !is_user_connected(id) || !equali(g_UserAuthID[id], AuthID))
		return ClearSettings(id);
	
	return PLUGIN_CONTINUE
}
ClearSettings(id)
{
	ArrayClear(g_UserAccessArray[id]);
	
	TrieClear(g_UserItemTrie[id]);
	TrieClear(g_UserDataTrie[id]);
	TrieClear(g_UserSpeedTrie[id]);
	
	// TODO
	// What is this for? Keys?
	/*
	new Count = 0, Array:CurArray
	for(Count = 0;Count < g_PropertyNum;Count++)
	{
	CurArray = ArrayGetCell(g_PropertyArray, Count);
	ArraySetCell(CurArray, 8, ArrayGetCell(CurArray, 8) & ~(1<<(id - 1)));
	}
	*/
	
	g_Saving[id] = false
	g_Display[id] = 1
	g_Joined[id] = false
	
	g_UserAuthID[id][0] = 0
	g_ConsoleTimeout[id] = 0.0
	g_DoorBellTime[id] = 0.0
	g_UserSpeedOverride[id] = 0.0
	g_UserMaxSpeed[id] = 0.0
	
	for(new Count = 0; Count < HUD_NUM; Count++)
		ArrayClear(g_UserHudArray[id][Count]);
}
_CreateItemDrop(id = 0, Float:Origin[3], const Num, const ItemName[])
{
	if(id)
	{
		if(!CheckTime(id))
			return FAILED
		
		new CurrentDrops, AuthID[36], ItemAuth[36]
		get_user_authid(id, AuthID, 35);
		
		new ItemNum
		while(( CurrentDrops = engfunc(EngFunc_FindEntityByString, CurrentDrops, "classname", g_drpEntItem)) != 0 )
		{
			pev(CurrentDrops, pev_noise1, ItemAuth, 35);
			if(equali(AuthID, ItemAuth))
				ItemNum++
		}
		if(ItemNum >= 3)
		{
			client_print(id, print_chat, "[DRP] You can only drop up to 3 items.");
			return FAILED
		}
	}
	
	new const Ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"));
	if(!Ent)
		return FAILED
	
	set_pev(Ent, pev_classname, g_drpEntItem);
	set_pev(Ent, pev_solid, SOLID_TRIGGER);
	set_pev(Ent, pev_movetype, MOVETYPE_TOSS);
	
	engfunc(EngFunc_SetModel, Ent, g_drpItemModel);
	engfunc(EngFunc_SetSize, Ent, Float:{-2.5, -2.5, -2.5}, Float:{2.5, 2.5, 2.5});
	engfunc(EngFunc_SetOrigin, Ent, Origin);
	
	if(id)
	{
		new AuthID[36]
		get_user_authid(id, AuthID, 35);
		
		velocity_by_aim(id, 400, Origin);
		
		set_pev(Ent, pev_velocity, Origin);
		set_pev(Ent, pev_noise1, AuthID);
	}
	
	set_pev(Ent, pev_noise, ItemName);
	set_pev(Ent, pev_iuser2, Num);
	
	return SUCCEEDED
}
_CallNPC(const id, const Ent)
{
	new const Plugin = pev(Ent, pev_iuser3);
	new Handler[32], Data[2]
	pev(Ent, pev_noise, Handler, 31);
	
	Data[0] = id
	Data[1] = Ent
	
	if(UTIL_Event("NPC_Use", Data, 2) == EVENT_HALT)
		return 0
	
	NPCUse(Handler, Plugin, id, Ent);
	return 1
}
TSWeaponOffsets()
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
// This traces your view,  and skips glass,  and check if we hit a NPC
// For MecklenburgD Series all NPC's needing a trace (behind a wall of sorts) are now func_illusionary()
// So this isn't needed. And I'm not going to use it. But I'll leave it here.
TraceNPC(id, EntityToIgnore, Float:r[3])
{
new Float:start[3], Float:view_ofs[3];

pev(id, pev_origin, start);
pev(id, pev_view_ofs, view_ofs);

xs_vec_add(start,  view_ofs,  start);

new Float:dest[3];
pev(id, pev_v_angle, dest);
engfunc(EngFunc_MakeVectors, dest);

global_get(glb_v_forward, dest);
xs_vec_mul_scalar(dest,  9999.0,  dest);
xs_vec_add(start,  dest,  dest);
engfunc(EngFunc_TraceLine, start, dest, IGNORE_GLASS, EntityToIgnore, 0);

new EntID = get_tr2(0, TR_pHit);
get_tr2(0, TR_vecEndPos, r);

if(pev_valid(EntID))
{
pev(EntID, pev_classname, g_Menu, 255);
if(equali(g_drpEntNpc, g_Menu))
	return EntID
}

return 0
}
*/
