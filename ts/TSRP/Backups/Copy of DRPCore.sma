/*
* DRPCore.sma
* -------------------------------------
* Author(s):
* Drak
* Hawk - His 'DPRP' plugin helped a lot.
	Many of the functions are based from DPRP.
* 	Hell, it's basiclly a giant modification of it anyways.
* -------------------------------------
* Note(s):
* This plugin should be BEFORE all of the DRP addons (in plugins.ini)
* Or some things might fail to load
*/


#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <arrayx_array>
#include <arrayx_keytable>
#include <arrayx_const>
#include <sqlx>
#include <DRP/DRPCore>

// CAPTAIN! WE NEED MORE DILITHIUM CRYSTALS!
#pragma dynamic 32768

#define MAX_USER_ITEMS 100

// MOTD Files are located in DRP Config Folder
#define RULES_MOTD_FILE "Rules.txt"
#define LAWS_MOTD_FILE "Laws.txt"
#define HELP_MOTD_FILE "Help.txt"

#define seconds_to_screenfade_units(%1) ( ( 1 << 12 ) * ( %1 ) )

new const PLUGIN[] = "DRP Core"
new const VERSION[] = "0.1a BETA"
new const AUTHOR[] = "Drak"

// SQL Stuff
new Handle:g_SqlHandle
new g_Query[4096]

// Files
new g_MOTDFiles[64]
new g_ConfigDir[128]

// SQL Connection / Tables 
new const sql_Host[] = "DRP_SQL_Host"
new const sql_DB[] = "DRP_SQL_DB"
new const sql_Pass[] = "DRP_SQL_Pass"
new const sql_User[] = "DRP_SQL_User"

// SQL Tables
new g_UserTable[64] = "Users"
new g_JobsTable[64] = "Jobs"
new g_PropertyTable[64] = "Property"
new g_EconomyTable[64] = "Economy"
new g_KeysTable[64] = "PropertyKeys"

// Menus
new const g_ItemsMenu[] = "DRP_ItemsMenu"
new const g_ItemsDrop[] = "DRP_ItemsDrop"
new const g_ItemsGive[] = "DRP_ItemsGive"
new const g_ItemsOptions[] = "DRP_ItemsOptions"


// PCvars
new p_StartMoney
new p_WalletDeath
new p_HungerEnabled
new p_GodDoors
new p_GodBreakables
new p_RemoveButton
new p_HungerEffects
new p_ItemsPerPage
new p_Itemlimit
new p_ShowRobber
new p_HealMeds
new p_HealInterval
new p_SalaryToWallet
new p_711RobWait
new p_DinerRobWait
new p_BankRobWait
new p_OtherRobWait
new p_711MinPlayers
new p_DinerMinPlayers
new p_BankMinPlayers
new p_OtherMinPlayers
new p_711MinCops
new p_DinerMinCops
new p_BankMinCops
new p_OtherMinCops
new p_BankRobTime

// Arrays
new g_CommandArray
new g_CommandNum
new g_JobArray
new g_JobNum
new g_ItemsArray
new g_ItemsNum
new g_PropertyArray
new g_PropertyNum

// Items
new g_ItemIDs[MAX_USER_ITEMS]

new g_MenuPage[33]
new const g_Keys = MENU_KEY_0|MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6|MENU_KEY_7|MENU_KEY_8|MENU_KEY_9
new g_CurItem[33]

// User Data
new g_UserWallet[33]
new g_UserBank[33]
new g_UserHunger[33]
new g_UserJobID[33]
new g_UserSalary[33]
new g_UserAccess[33]
new g_UserJobAccess[33]


// Counters
new g_HealCounter
new g_HungerCounter

new g_UserItemUse[33] // The current item there using/used.
new bool:g_TouchTimeOut[33]
new Float:g_DropTimeOut[33]

new gmsgTSFade
new gmsgScreenShake


new g_UserItemArray[33] // This will store all there items in a large array
new g_UserItemNum[33]

new bool:g_ItemsRegistered

// NPCs
new const g_iNPCName[] = "DRP_NPC"
new const g_iDRPZone[] = "DRP_ZONE"
new const g_FillModel[] = "models/pellet.mdl"

new g_Time

enum _:HUD_CVARS
{
	X = 0,
	Y,
	R,
	G,
	B
}

new p_Hud[HUD_NUM][HUD_CVARS]
new g_HudArray[33][HUD_NUM]
new g_HudNum[33][HUD_NUM]
new g_HudObjects[HUD_NUM]
new g_HudPending


new g_RobInfo[33][5]
new Float:g_RobOrigin[33][3]
new g_WhosRobbing[ROB_PLACES]
new g_LastRob[ROB_PLACES]


new g_BagEnts[2]
new Float:g_BagOrigin[2][3]
new g_BankMoneyTaken


// Economy / Taxes
new g_EconomyPot
new g_EconomyLotto
new g_EconomyNPCTax
new g_EconomyPropertyTax

// Player Error Checking
new bool:g_GotInfo[33] = false
new bool:g_Joined[33] = false
new bool:g_BadJob[33] = false
new bool:g_Display[33] = false

// Native Forwards
new g_HudForward
new g_SalaryForward
new g_RobForward
new g_RobEndForward

// Variable CVars
new bool:g_DeathScreen = false


// TEST TEST TEST
new g_ServerTime[33]
stock TEST_LOG(const Msg[])
	log_amx("%s - %s",Msg,g_ServerTime);

// DO NOT EDIT ANYTHING BELOW THIS LINE
// UNLESS YOU KNOW WHAT YOU'RE DOING
public plugin_precache()
{
	get_time("%c",g_ServerTime,32); // TEST TEST TEST
	
	// CVars 
	p_StartMoney = register_cvar("DRP_StartBankCash","100");
	p_WalletDeath = register_cvar("DRP_WalletDeath","0");
	p_HungerEnabled = register_cvar("DRP_HungerEnable","1");
	p_HungerEffects = register_cvar("DRP_HungerEffects","1"); 
	p_GodDoors = register_cvar("DRP_GodDoors","0"); 
	p_GodBreakables = register_cvar("DRP_GodBreakables","0");
	p_RemoveButton = register_cvar("DRP_RemoveButtons","1");
	p_ItemsPerPage = register_cvar("DRP_ItemsPerPage","30");
	p_Itemlimit = register_cvar("DRP_ItemLimit","45");
	p_ShowRobber = register_cvar("DRP_ShowRobber","1");
	p_HealMeds = register_cvar("DRP_HealMedics","1");
	p_HealInterval = register_cvar("DRP_HealInterval","20");
	p_SalaryToWallet = register_cvar("DRP_SalaryToWallet","0");
	p_BankRobTime = register_cvar("DRP_BankRobtime","120");
	
	p_711RobWait = register_cvar("DRP_711RobWait","360");
	p_DinerRobWait = register_cvar("DRP_DinerRobWait","360");
	p_BankRobWait = register_cvar("DRP_BankRobWait","360");
	p_OtherRobWait = register_cvar("DRP_OtherRobWait","360");
	
	p_711MinPlayers = register_cvar("DRP_711MinPlayers","3");
	p_DinerMinPlayers = register_cvar("DRP_DinerMinPlayers","3");
	p_BankMinPlayers = register_cvar("DRP_BankMinPlayers","3");
	p_OtherMinPlayers = register_cvar("DRP_OtherMinPlayers","3");
	
	p_711MinCops = register_cvar("DRP_711MinCops","1");
	p_DinerMinCops = register_cvar("DRP_DinerMinCops","1");
	p_BankMinCops = register_cvar("DRP_BankMinCops","1");
	p_OtherMinCops = register_cvar("DRP_OtherMinCops","1");
	
	register_cvar(sql_Host,"",FCVAR_PROTECTED);
	register_cvar(sql_DB,"",FCVAR_PROTECTED);
	register_cvar(sql_Pass,"",FCVAR_PROTECTED);
	register_cvar(sql_User,"",FCVAR_PROTECTED);
	
	// Access
	register_cvar(g_PoliceAccessCvar,"a"); // Access Letter for Cops
	register_cvar(g_MedsAccessCvar,"b"); // Access Letter for Medics
	register_cvar(g_AdminAccessCvar,"z"); // Access Letter for DRP admins. (Rights to set job/create money, etc)
	
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
		format(g_Query,4095,"Item model missing: %s",g_ItemMdl)
		UTIL_Error(0,1,g_Query,0);
		return 
	}
	if(file_exists(g_MoneyMdl))
		precache_model(g_MoneyMdl);
	else
	{
		format(g_Query,4095,"Money model missing: %s",g_MoneyMdl)
		UTIL_Error(0,1,g_Query,0);
		return 
	}
	
	precache_model(g_FillModel);
	
	precache_sound("items/ammopickup1.wav");
	precache_sound("items/gunpickup2.wav");
	
	// Arrays
	g_CommandArray = array_create();
	g_JobArray = array_create();
	g_ItemsArray = array_create();
	g_PropertyArray = array_create();
	
	for(new Count,Count2;Count < 33;Count++)
	{
		g_UserItemArray[Count] = array_create();
		for(Count2 = 0;Count2 < HUD_NUM;Count2++)
			g_HudArray[Count][Count2] = array_create();
	}
	
	// Open the config file.
	get_configsdir(g_ConfigDir,127);
	format(g_ConfigDir,127,"%s/DRP",g_ConfigDir);
	
	if(!dir_exists(g_ConfigDir))
	{
		format(g_Query,4095,"Unable to open Core Config Dir (Folder). (%s)",g_ConfigDir);
		UTIL_Error(0,1,g_Query,0);
		return
	}
	
	// Forwards
	register_forward(FM_PlayerPreThink,"forward_PreThink");
	register_forward(FM_Touch,"forward_Touch");
	register_forward(FM_Sys_Error,"plugin_end");
	
	// Native Forwards
	g_HudForward = CreateMultiForward("DRP_HudDisplay",ET_IGNORE,FP_CELL);
	g_SalaryForward = CreateMultiForward("DRP_Salary",ET_STOP2,FP_CELL);
	g_RobForward = CreateMultiForward("DRP_UserRob",ET_STOP2,FP_CELL,FP_CELL,FP_CELL,FP_STRING,FP_CELL);
	g_RobEndForward = CreateMultiForward("DRP_RobEnd",ET_IGNORE,FP_CELL,FP_STRING);
	
	new ConfigFile[128]
	formatex(ConfigFile,127,"%s/DRPCore.cfg",g_ConfigDir);

	new pFile = fopen(ConfigFile,"r");
	if(!pFile)
	{
		format(g_Query,4095,"Unable to open Core Config File. (%s)",ConfigFile);
		UTIL_Error(0,1,g_Query,0);
		return
	}
	
	UTIL_LoadConfigFile(pFile);
	
	g_ItemsRegistered = true
	
	new Forward = CreateMultiForward("DRP_RegisterItems",ET_IGNORE),Return
	if(Forward <= 0 || !ExecuteForward(Forward,Return)) 
		UTIL_Error(1,1,"Could not execute ^"DRP_RegisterItems^" forward.",0);
	
	DestroyForward(Forward);
	
	g_ItemsRegistered = false
	
	SQLInit();
}
public plugin_init()
{	
	register_plugin(PLUGIN,VERSION,AUTHOR);
	register_cvar("DRP_Version",VERSION,FCVAR_SERVER);
	
	// Old HarbuRP Commands
	register_clcmd("amx_joblist","CmdJobList"); // REMOVE ME
	register_clcmd("amx_itemlist","CmdItemList"); // REMOVE ME
	register_clcmd("amx_help","CmdHelp"); // REMOVE ME
	
	register_clcmd("say","CmdSay");
	
	DRP_RegisterCmd("drp_joblist","CmdJobList","Shows the list of jobs");
	DRP_RegisterCmd("drp_itemlist","CmdItemList","Shows the list of items");
	
	DRP_RegisterCmd("say /buy","CmdBuy","Allows you to buy properties you're looking at");
	DRP_RegisterCmd("say /items","CmdItems","Shows your items and allows you to control them");
	
	DRP_RegisterCmd("say /help","CmdMOTDHelp","Shows a MOTD Help Window");
	DRP_RegisterCmd("say /laws","CmdMOTDHelp","Displays The Server's Laws");
	DRP_RegisterCmd("say /rules","CmdMOTDHelp","Shows the Server's Rules");
	DRP_RegisterCmd("say /commands","CmdMOTDHelp","Shows help on commands");
	
	DRP_RegisterCmd("drp_help","CmdHelp","Shows the help file");
	
	// DRP Admin Commands
	//DRP_RegisterCmd("drp_updateproperty","CmdPropUpdate","(ADMIN) Updates the Property Array with the SQL Info");
	//DRP_RegisterCmd("drp_updatejobs","CmdJobsUpdate","(ADMIN) Updates the Job Array with the SQL Info");
	DRP_RegisterCmd("drp_entinfo","CmdEnt","(ADMIN) Displays the current Entity's info you're looking at.");
	
	// Menus
	register_menucmd(register_menuid(g_ItemsMenu),g_Keys,"_ItemsHandle");
	register_menucmd(register_menuid(g_ItemsOptions),g_Keys,"ItemsOptions");
	register_menucmd(register_menuid(g_ItemsDrop),g_Keys,"ItemsDrop");
	register_menucmd(register_menuid(g_ItemsGive),g_Keys,"ItemsGive");
	
	register_clcmd("say !test","test");
	
	// REMOVE ME, BACKWORDS COMPATIABLE
	register_clcmd("say /trigger","OldInfo");
	register_clcmd("say /usedoor","OldInfo");
	
	new ConfigsFile[128]
	format(ConfigsFile,127,"%s/DRPCore.cfg",g_ConfigDir);
	server_cmd("exec %s",ConfigsFile);
	
	// Events
	register_event("DeathMsg","EventDeathMsg","a");
	register_event("ResetHUD","EventResetHUD","b");
	
	// Entity 'Godding'
	if(get_pcvar_num(p_GodDoors))
	{
		new Ent
		while(( Ent = engfunc(EngFunc_FindEntityByString,Ent,"classname","func_door")) != 0)
			set_pev(Ent,pev_takedamage,0.0);
				
		Ent = 0
		while(( Ent = engfunc(EngFunc_FindEntityByString,Ent,"classname","func_door_rotating")) != 0)
			set_pev(Ent,pev_takedamage,0.0);
	}
	new pGodBreakables = get_pcvar_num(p_GodBreakables);
	if(pGodBreakables)
	{
		new Ent,szData[36]
		while(( Ent = engfunc(EngFunc_FindEntityByString,Ent,"classname","func_breakable")) != 0)
		{
			if(pGodBreakables == 2)
			{
				pev(Ent,pev_targetname,szData,35);
				if(equali(szData,"DRPWinGod"))
					set_pev(Ent,pev_takedamage,0.0);
			}
			else if(pGodBreakables != 2)
				set_pev(Ent,pev_takedamage,0.0);
		}
	}
	if(get_pcvar_num(p_RemoveButton))
	{
		new Ent,TEnt,szData[36]
		while(( Ent = engfunc(EngFunc_FindEntityByString,Ent,"classname","func_button")) != 0)
		{
			pev(Ent,pev_target,szData,35);
			
			TEnt = engfunc(EngFunc_FindEntityByString,-1,"targetname",szData);
			
			if(pev_valid(TEnt))
			{
				pev(TEnt,pev_classname,szData,35);
			
				if(containi(szData,"func_door") != -1)
					engfunc(EngFunc_RemoveEntity,Ent);
			}
		}
	}
	
	for(new Count;Count < HUD_NUM;Count++)
		g_HudObjects[Count] = CreateHudSyncObj();
	
	gmsgTSFade = get_user_msgid("TSFade");
	gmsgScreenShake = get_user_msgid("ScreenShake");
	
	// Tasks
	set_task(1.0,"ShowHud",_,_,_,"b");
}
// REMOVE ME // REMOVE ME // REMOVE ME // REMOVE ME
public OldInfo(id)
{
	static Arg[36]
	read_argv(1,Arg,35);
	
	if(equali(Arg,"/usedoor") || equali(Arg,"/trigger"))
		client_print(id,print_chat,"[DoorMOD] Doors are opened via the USE KEY.");
	
	return PLUGIN_HANDLED
}
// REMOVE ME// REMOVE ME

public test(id) 
{
	UTIL_SetUserItemNum(id,2,2);
}
/*==================================================================================================================================================*/
// SQL Data Loading
SQLInit()
{
	new sqlHost[36],sqlDB[36],sqlPass[36],sqlUser[36]
	
	get_cvar_string(sql_Host,sqlHost,35);
	get_cvar_string(sql_DB,sqlDB,35);
	get_cvar_string(sql_User,sqlUser,35);
	get_cvar_string(sql_Pass,sqlPass,35);

	g_SqlHandle = SQL_MakeDbTuple(sqlHost,sqlUser,sqlPass,sqlDB);
	if(!g_SqlHandle || g_SqlHandle == Empty_Handle)
	{
		format(g_Query,4095,"Failed to create SQL tuple.");
		return UTIL_Error(0,1,g_Query,0);
	}
	
	// This calls the function in every plugin
	new Forward = CreateMultiForward("DRP_Init",ET_IGNORE),Return
	if(Forward <= 0 || !ExecuteForward(Forward,Return))
	{
		format(g_Query,4095,"Could not create SQL forward.");
		return UTIL_Error(0,1,g_Query,0);
	}
	
	/*
	// Create the tables
	format(g_Query,4095,"CREATE TABLE IF NOT EXISTS %s (JobID INT(11),JobName VARCHAR(32),JobSalary INT(11),JobAccess VARCHAR(32),UNIQUE KEY (JobID))",g_JobsTable);
	SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",g_Query);
	
	format(g_Query,4095,"CREATE TABLE IF NOT EXISTS %s (InternalName VARCHAR(66),ExternalName VARCHAR(66),OwnerName VARCHAR(40),OwnerAuthID VARCHAR(36),Price INT(11),Locked INT(11),Access VARCHAR(27),Profit INT(11),UNIQUE KEY (InternalName))",g_PropertyTable)
	SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",g_Query);
	
	format(g_Query,4095,"CREATE TABLE IF NOT EXISTS %s (SteamID VARCHAR(36),InternalName VARCHAR (36))",g_KeysTable);
	SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",g_Query);
	*/
	
	
	// Load the Data from the SQL DB
	format(g_Query,4095,"SELECT * FROM %s",g_JobsTable);
	SQL_ThreadQuery(g_SqlHandle,"FetchJobs",g_Query);
	
	format(g_Query,4095,"SELECT * FROM %s",g_PropertyTable);
	SQL_ThreadQuery(g_SqlHandle,"FetchProperty",g_Query);
	
	format(g_Query,4095,"SELECT * FROM %s",g_EconomyTable);
	SQL_ThreadQuery(g_SqlHandle,"FetchEconomy",g_Query);
	
	return DestroyForward(Forward);
}

public FetchEconomy(FailState,Handle:Query,Error[],Errcode,Data[],DataSize)
{
	if(FailState == TQUERY_CONNECT_FAILED)
	{
		format(g_Query,4095,"Could not connect to SQL database.");
		return UTIL_Error(0,1,g_Query,0)
	}
	else if(FailState == TQUERY_QUERY_FAILED)
	{
		format(g_Query,4095,"Internal error: consult developer.");
		return UTIL_Error(0,1,g_Query,0);
	}
	if(Errcode)
	{
		format(g_Query,4095,"Error on query: %s",Error);
		return UTIL_Error(0,1,g_Query,0);
	}
	
	g_EconomyPot = SQL_ReadResult(Query,0);
	g_EconomyLotto = SQL_ReadResult(Query,1);
	
	return PLUGIN_CONTINUE
}

public FetchProperty(FailState,Handle:Query,Error[],Errcode,Data[],DataSize)
{
	if(FailState == TQUERY_CONNECT_FAILED)
	{
		format(g_Query,4095,"Could not connect to SQL database.");
		return UTIL_Error(0,1,g_Query,0)
	}
	else if(FailState == TQUERY_QUERY_FAILED)
	{
		format(g_Query,4095,"Internal error: consult developer.");
		return UTIL_Error(0,1,g_Query,0);
	}
	if(Errcode)
	{
		format(g_Query,4095,"Error on query: %s",Error);
		return UTIL_Error(0,1,g_Query,0);
	}
	
	new InternalName[64],ExternalName[64],OwnerName[33],OwnerAuthid[36],Price,Locked,AccessStr[JOB_ACCESSES + 1],Access,Profit
	if(!SQL_NumResults(Query))
		return PLUGIN_CONTINUE
	
	while(SQL_MoreResults(Query))
	{
		SQL_ReadResult(Query,0,InternalName,63)
		SQL_ReadResult(Query,1,ExternalName,63)
		SQL_ReadResult(Query,2,OwnerName,32)
		SQL_ReadResult(Query,3,OwnerAuthid,35)
		Price = SQL_ReadResult(Query,4)
		Locked = SQL_ReadResult(Query,5)
		SQL_ReadResult(Query,6,AccessStr,JOB_ACCESSES)
		Access = DRP_AccessToInt(AccessStr)
		Profit = SQL_ReadResult(Query,7)
		
		new Array = array_create();
		array_set_int(g_PropertyArray,g_PropertyNum++,Array)
		array_set_string(Array,0,InternalName)
		array_set_string(Array,1,ExternalName)
		array_set_string(Array,2,OwnerName)
		array_set_string(Array,3,OwnerAuthid)
		array_set_int(Array,4,Price)
		array_set_int(Array,5,Locked)
		array_set_int(Array,6,Access)
		array_set_int(Array,7,Profit)	
		array_set_int(Array,8,0)
		array_set_int(Array,9,0)
		
		SQL_NextRow(Query)
	}
	return PLUGIN_CONTINUE
}
public FetchJobs(FailState,Handle:Query,Error[],Errcode,Data[],DataSize)
{
	if(FailState == TQUERY_CONNECT_FAILED)
	{
		format(g_Query,4095,"Could not connect to SQL database.");
		return UTIL_Error(0,1,g_Query,0)
	}
	else if(FailState == TQUERY_QUERY_FAILED)
	{
		format(g_Query,4095,"Internal error: consult developer.");
		return UTIL_Error(0,1,g_Query,0);
	}
	
	if(Errcode)
	{
		format(g_Query,4095,"Error on query: %s",Error);
		return UTIL_Error(0,1,g_Query,0);
	}
	
	new Temp[JOB_ACCESSES + 1],Array
	while(SQL_MoreResults(Query))
	{
		Array = array_create();
		array_set_int(g_JobArray,g_JobNum++,Array);
		
		SQL_ReadResult(Query,0,g_Query,4095);
		array_set_string(Array,1,g_Query);
		
		array_set_int(Array,2,SQL_ReadResult(Query,1));
		
		SQL_ReadResult(Query,2,Temp,JOB_ACCESSES);
		array_set_int(Array,3,DRP_AccessToInt(Temp));
		
		SQL_NextRow(Query);
	}
	
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
	
	if(Index)
	{
		new Targetname[33]
		pev(Index,pev_targetname,Targetname,32);
		
		new Property = UTIL_GetProperty(Targetname);
		if(Property == -1)
			return PLUGIN_HANDLED
	}
	
	return PLUGIN_HANDLED
}
public CmdItems(id)
{
	g_MenuPage[id] = 0
	_CmdItems(id);
	
	return PLUGIN_HANDLED
}
_CmdItems(id)
{	
	if(!is_user_alive(id))
		return PLUGIN_HANDLED
	
	new Success,Last = array_last(g_UserItemArray[id],-1,Success);
	if(!Success && !array_isfilled(g_UserItemArray[id],Last))
	{
		client_print(id,print_chat,"[DRP] You have no items in your inventory.");
		return PLUGIN_HANDLED
	}
	
	new Menu[512],Pos,Len = sizeof Menu - 1,MenuOptions = 7,Start = g_MenuPage[id] * MenuOptions,ItemName[33]
	Pos += formatex(Menu[Pos],Len - Pos,"Your Items^n^n");
	
	new ItemId,Num = Start,MenuItemNum,Keys = MENU_KEY_0|MENU_KEY_8|MENU_KEY_9
	while(Num < Start + MenuOptions && (ItemId = array_get_nth(g_UserItemArray[id],++Num,_,Success)) != 0 && Success)
	{
		Keys |= (1<<MenuItemNum)
		
		UTIL_ValidItemID(ItemId) ? UTIL_GetItemName(ItemId,ItemName,32) : copy(ItemName,32,"BAD ITEMID : Contact Admin");
		Pos += formatex(Menu[Pos],Len - Pos,"%d. %s x %d^n",++MenuItemNum,ItemName,UTIL_GetUserItemNum(id,ItemId));
	}
	
	Pos += formatex(Menu[Pos],Len - Pos,"^n8. Last Page^n9. Next Page^n^n0. Exit");
	
	show_menu(id,Keys,Menu,-1,g_ItemsMenu);
	
	return PLUGIN_HANDLED
}
public _ItemsHandle(id,Key)
{
	switch(Key)
	{
		case 7 :
		{
			if(g_MenuPage[id])
				g_MenuPage[id]--
			
			_CmdItems(id);
		}
		case 9:
			g_MenuPage[id] = 0
		
		default :
		{
			new Item = g_MenuPage[id] * 7 + Key,Success
			
			new ItemId = array_get_nth(g_UserItemArray[id],Item + 1,_,Success);		
			g_CurItem[id] = ItemId
			
			if(UTIL_ValidItemID(ItemId))
			{
				format(g_Query,4095,"Item Options^n^n1. Use^n2. Give^n3. Examine^n4. Show^n5. Drop^n^n0. Exit");
				show_menu(id,g_Keys,g_Query,-1,g_ItemsOptions);
			}
			else
				client_print(id,print_chat,"[DRP] This item is invalid. Please contact the administrator.");
			
			return
		}
	}	
}
public ItemsOptions(id,Key)
{
	switch(Key)
	{
		case 0: ItemUse(id,g_CurItem[id],1);
		case 1 :
		{
			format(g_Query,4095,"Give Items^n^n1. Give 1^n2. Give 5^n3. Give 20^n4. Give 50^n5. Give 100^n6. Give All^n^n0. Exit");
			show_menu(id,g_Keys,g_Query,-1,g_ItemsGive);
		}
		case 2 :
		{
			new ItemId = g_CurItem[id],Array = UTIL_ValidItemID(ItemId)
			if(!Array)
			{
				client_print(id,print_chat,"[DRP] This item is invalid. Please contact an administrator.");
				return
			}
			array_get_string(array_get_int(g_ItemsArray,Array),4,g_Query,63);
			client_print(id,print_chat,"[ItemMod] %s",g_Query);
		}
		case 3 :
		{
			new Index,Body
			get_user_aiming(id,Index,Body,100);
			
			if(!Index || !is_user_alive(Index)) 
			{
				client_print(id,print_chat,"[DRP] You are not looking at a user.");
				return 
			}
			new Array = UTIL_ValidItemID(g_CurItem[id]);
			if(!Array)
			{
				client_print(id,print_chat,"[DRP] This item is invalid. Please contact an administrator.");
				return
			}
	
			new Names[2][33],ItemId = g_CurItem[id],ItemName[33]
			get_user_name(id,Names[0],32);
			get_user_name(Index,Names[1],32);
			
			UTIL_GetItemName(ItemId,ItemName,32);
			
			client_print(id,print_chat,"[DRP] You show %s your %s.",Names[1],ItemName);
			client_print(Index,print_chat,"[DRP] %s shows you his %s.",Names[0],ItemName);
		}
		case 4 :
		{
			format(g_Query,4095,"Drop Items^n^n1. Drop 1^n2. Drop 5^n3. Drop 20^n4. Drop 50^n5. Drop 100^n6. Drop All^n^n0. Exit");
			show_menu(id,g_Keys,g_Query,-1,g_ItemsDrop);
		}
	}
}
public ItemsGive(id,Key)
{
	new Index,Body,Num
	get_user_aiming(id,Index,Body,200)
	
	if(!Index || !is_user_alive(Index))
	{
		client_print(id,print_chat,"[DRP] You are not looking at a user.")
		return
	}
	
	new ItemId = g_CurItem[id]
	
	switch(Key)
	{
		case 0 :
			Num = 1
		case 1 :
			Num = 5
		case 2 :
			Num = 20
		case 3 :
			Num = 50
		case 4 :
			Num = 100
		case 5 :
			Num = abs(array_get_int(g_UserItemArray[id],g_CurItem[id]));
	}
	
	if(ItemId < Num)
	{
		client_print(id,print_chat,"[DRP] You do not have enough of this item.")		
		return
	}
	
	new Array = UTIL_GetUserItemNum(id,ItemId);
	if(array_get_int(array_get_int(g_ItemsArray,Array),8) == 1)
	{
		client_print(id,print_chat,"[DRP] This item is not giveable.");
		return
	}
	
	if(!UTIL_SetUserItemNum(Index,ItemId,UTIL_GetUserItemNum(Index,ItemId) + Num))
	{
		client_print(id,print_chat,"[DRP] Sorry, that user cannot accept items right now.")
		return
	}
		
	UTIL_SetUserItemNum(id,ItemId,UTIL_GetUserItemNum(id,ItemId) - Num)
			
	new Name[33],ItemName[33]
	get_user_name(Index,Name,32);
	
	UTIL_GetItemName(ItemId,ItemName,32)
	
	client_print(id,print_chat,"[DRP] You have given %s %d %s%s.",Name,Num,ItemName,Num == 1 ? "" : "s")
	get_user_name(id,Name,32);
	client_print(Index,print_chat,"[DRP] %s has given you %d %s%s.",Name,Num,ItemName,Num == 1 ? "" : "s")
}

public ItemsDrop(id,Key)
{
	new Num,ItemNum = abs(array_get_int(g_UserItemArray[id],g_CurItem[id])),ItemId = g_CurItem[id]
	
	switch(Key)
	{
		case 0 :
			Num = 1
		case 1 :
			Num = 5
		case 2 :
			Num = 20
		case 3 :
			Num = 50
		case 4 :
			Num = 100
		case 5 :
			Num = ItemNum
	}
	
	if(ItemNum < Num)
	{
		client_print(id,print_chat,"[DRP] You do not have enough of this item.");	
		return
	}
			
	UTIL_SetUserItemNum(id,ItemId,UTIL_GetUserItemNum(id,ItemId) - Num);
	
	new Ent = engfunc(EngFunc_CreateNamedEntity,engfunc(EngFunc_AllocString,"info_target"))
	if(!Ent)
		return
	
	g_TouchTimeOut[id] = true
	
	new ItemName[33],Float:Origin[3],Float:iVelo[3]
	pev(id,pev_origin,Origin);
	
	UTIL_GetItemName(ItemId,ItemName,32);
	
	set_pev(Ent,pev_classname,g_szItem);
	set_pev(Ent,pev_solid,SOLID_TRIGGER);
	set_pev(Ent,pev_movetype,MOVETYPE_TOSS);
	
	engfunc(EngFunc_SetModel,Ent,g_ItemMdl);
	engfunc(EngFunc_SetSize,Ent,Float:{-2.5,-2.5,-2.5},Float:{2.5,2.5,2.5});
	
	velocity_by_aim(id,400,iVelo);
	set_pev(Ent,pev_velocity,iVelo);

	engfunc(EngFunc_SetOrigin,Ent,Origin);
	
	set_pev(Ent,pev_iuser1,ItemId);
	set_pev(Ent,pev_iuser2,Num);
	
	client_print(id,print_chat,"[DRP] You have dropped %i x %s",Num,ItemName);
	emit_sound(id,CHAN_ITEM,"items/ammopickup1.wav",1.0, ATTN_NORM,0,PITCH_NORM);
	
	set_task(1.5,"_TouchTimeout",id);
}

/*==================================================================================================================================================*/
public CmdHelp(id)
{
	new Arg[33]
	read_argv(1,Arg,32);
	
	new Start = str_to_num(Arg),Items = 10
	
	if(Start >= g_CommandNum || Start < 0)
	{
		client_print(id,print_console,"No help items to display at this area.");
		return PLUGIN_HANDLED
	}
	
	client_print(id,print_console,"DRP Help List (Starting at #%d)",Start);
	client_print(id,print_console,"NUMBER   COMMAND   DESCRIPTION");
	
	new Description[256],Array
	for(new Count = Start;Count < Start + Items;Count++)
	{
		if(Count >= g_CommandNum)
			break
		
		Array = array_get_int(g_CommandArray,Count + 1);
		
		array_get_string(Array,1,Arg,32);
		array_get_string(Array,2,Description,255);
		
		client_print(id,print_console,"#%d   %s   %s",Count + 1,Arg,Description);
	}
	
	if(Start + Items < g_CommandNum)
		client_print(id,print_console,"Type ^"drp_help %d^" to view next items.",Start + Items);
	
	return PLUGIN_HANDLED
}

public CmdJobList(id)
{
	new Arg[33]
	read_argv(1,Arg,32);
	
	new Start = str_to_num(Arg),Items = get_pcvar_num(p_ItemsPerPage);
	
	if(Start >= g_JobNum || Start < 0)
	{
		client_print(id,print_console,"No jobs to display at this area.");
		return PLUGIN_HANDLED
	}
	
	new JobName[33],JobAccess[JOB_ACCESSES + 1],Array
	client_print(id,print_console,"DRP Jobs List (Starting at #%d)",Start)
	client_print(id,print_console,"JOBID   NAME   SALARY   ACCESS");
	
	for(new Count = Start;Count < Start + Items;Count++)
	{
		if(Count >= g_JobNum)
			break
		
		Array = array_get_int(g_JobArray,Count);
		
		array_get_string(Array,1,JobName,32);
		DRP_IntToAccess(array_get_int(Array,3),JobAccess,JOB_ACCESSES);
		
		client_print(id,print_console,"#%d    %s    $%d    %s",Count + 1,JobName,array_get_int(Array,2),JobAccess);
	}
	
	if(Start + Items < g_JobNum)
		client_print(id,print_console,"Type ^"drp_joblist %d^" to view next jobs.",Start + Items);
	
	return PLUGIN_HANDLED
}
public CmdItemList(id)
{
	new Arg[33]
	read_argv(1,Arg,32);
	
	new Start = str_to_num(Arg) + 1,Items = get_pcvar_num(p_ItemsPerPage);
	
	if(Start > g_ItemsNum || Start < 1)
	{
		client_print(id,print_console,"No items to display at this area.")
		return PLUGIN_HANDLED
	}
	
	client_print(id,print_console,"DRP Items List (Starting at #%d)",Start);
	client_print(id,print_console,"ITEMID   NAME   DESCRIPTION");
	
	new Name[33],Description[128],Array
	for(new Count = Start;Count < Start + Items;Count++)
	{
		if(Count > g_ItemsNum)
			break
		
		Array = array_get_int(g_ItemsArray,Count);
		
		array_get_string(Array,1,Name,32);
		array_get_string(Array,4,Description,127);
		
		client_print(id,print_console,"#%d   %s   %s",array_get_int(Array,8),Name,Description);
	}
	
	if(Start + Items <= g_ItemsNum)
		client_print(id,print_console,"Type ^"drp_itemlist %d^" to view next items.",Start + Items - 1);
	
	return PLUGIN_HANDLED
}
// This is kinda dumb, I use "CmdSay"
// Just for the dropping of money
// Whatever
public CmdSay(id)
{
	if(!is_user_alive(id))
		return PLUGIN_HANDLED
	
	static Args[24]
	read_args(Args,23)
	
	remove_quotes(Args);
	trim(Args);
	
	if(equali(Args,"/drop",5))
	{
		new Float:Time = get_gametime();
		if(Time - g_DropTimeOut[id] < 1.5)
			return PLUGIN_HANDLED
		
		g_TouchTimeOut[id] = true
		g_DropTimeOut[id] = Time
		
		new StrAmount[10]
		parse(Args,StrAmount,9,StrAmount,9);
		
		new Amount = str_to_num(StrAmount);
		if(Amount <= 0) {
			client_print(id,print_chat,"[Economy] Usage: /drop <amount>");
			return PLUGIN_HANDLED
		}
		
		new iMoney = g_UserWallet[id]
		if(Amount > iMoney) {
			client_print(id,print_chat,"[Economy] You don't have that much money in your wallet.");
			return PLUGIN_HANDLED
		}
	
		new ent = engfunc(EngFunc_CreateNamedEntity,engfunc(EngFunc_AllocString,"info_target"))
		if(!ent) {
			client_print(id,print_chat,"[Economy] Failed to drop money. (Internal Error: Contact an admin)");
			return PLUGIN_HANDLED
		}
	
		new plOrigin[3],Float:Angles[3],Float:iVelo[3]
		pev(id,pev_origin,plOrigin);
	
		new const Float:iMins[3] = {-2.79, -0.0, -6.14}
		new const Float:iMaxs[3] = {2.42, 1.99, 6.35}
	
		Angles[1] = random_float(0.0,270.0);
	
		engfunc(EngFunc_SetModel,ent,g_MoneyMdl);
		engfunc(EngFunc_SetSize,ent,iMins,iMaxs);
	
		set_pev(ent,pev_movetype,MOVETYPE_TOSS);
		set_pev(ent,pev_solid,SOLID_TRIGGER);
	
		set_pev(ent,pev_takedamage,0.0);
		set_pev(ent,pev_owner,id);
		set_pev(ent,pev_angles,Angles);
	
		new iAmount[33]
		num_to_str(Amount,iAmount,32);
	
		set_pev(ent,pev_classname,g_szMoneyPile);
		set_pev(ent,pev_targetname,iAmount);
	
		engfunc(EngFunc_SetOrigin,ent,plOrigin);
	
		velocity_by_aim(id,400,iVelo);
		set_pev(ent,pev_velocity,iVelo);

		engfunc(EngFunc_SetOrigin,id,plOrigin);
	
		fm_set_user_rendering(ent,kRenderFxGlowShell,0,255,0,kRenderNormal,6.0);

		client_print(id,print_chat,"[Economy] You dropped $%d",Amount);
		UTIL_SetUserMoney(id,WALLET,iMoney-Amount);
		
		set_task(1.5,"_TouchTimeout",id);
	
		return PLUGIN_HANDLED
	}
	return PLUGIN_CONTINUE
}
public CmdMOTDHelp(id)
{
	new Cmd[33],pFile
	read_argv(1,Cmd,31);
	
	if(equal(Cmd,"/help"))
		formatex(g_MOTDFiles,sizeof g_MOTDFiles - 1,"%s/%s",g_ConfigDir,HELP_MOTD_FILE);
	else if(equal(Cmd,"/laws"))
		formatex(g_MOTDFiles,sizeof g_MOTDFiles - 1,"%s/%s",g_ConfigDir,LAWS_MOTD_FILE);
	else if(equal(Cmd,"/rules"))
		formatex(g_MOTDFiles,sizeof g_MOTDFiles - 1,"%s/%s",g_ConfigDir,RULES_MOTD_FILE);
	else if(equal(Cmd,"/commands")) // REMOVE ME (Commands are viewed via drp_help command.
		formatex(g_MOTDFiles,sizeof g_MOTDFiles - 1,"%s/Commands.txt",g_ConfigDir);
	else if(equal(Cmd,"/motd")) // REMOVE ME (Commands are viewed via drp_help command.
		formatex(g_MOTDFiles,sizeof g_MOTDFiles - 1,"motd.txt");
		
	pFile = fopen(g_MOTDFiles,"r");
	if(!pFile)
		return PLUGIN_HANDLED
	
	// Make sure the MOTD isn't to big.
	// Or stop and throw an error
	
	new Data[1536],CharCount
	while(!feof(pFile))
	{
		fgets(pFile,Data,1535);
		CharCount += strlen(Data);
		
		if(CharCount >= 1535) 
		{
			formatex(Data,1535,"MOTD File Size To Big. (MAX LEN: 1535) (FOUND: %d)",CharCount);
			UTIL_Error(0,0,Data,0);
			client_print(id,print_chat,"[DRP] Unable to show Help File. Please contact an admin.");
			
			fclose(pFile);
			
			return PLUGIN_HANDLED
		}
	}
	
	fclose(pFile);
	
	show_motd(id,g_MOTDFiles,"DRP");
	
	return PLUGIN_HANDLED
}

public CmdEnt(id,level,cid)
{
	if(!DRP_CmdAccess(id,cid,1))
		return PLUGIN_HANDLED
	
	new ent,body
	get_user_aiming(id,ent,body,300);
	if(!pev_valid(ent))
		return client_print(id,print_chat,"[DRP] Invalid Entity.");
	
	new iClass[36],iTargetName[36],iTarget[36]
	new Float:plOrigin[3]
	
	pev(ent,pev_classname,iClass,35);
	pev(ent,pev_targetname,iTargetName,35);
	pev(ent,pev_target,iTarget,35);
	
	pev(id,pev_origin,plOrigin);
	
	client_print(id,print_chat,"[Ent Info] ID: %d Class: %s TargetName: %s Target: %s",ent,iClass,iTargetName ? iTargetName : "N/A",iTarget ? iTarget : "N/A");
	client_print(id,print_chat,"[DRP] Origin: %f %f %f",plOrigin[0],plOrigin[1],plOrigin[2]);

	dllfunc(DLLFunc_Use,ent,ent);
	
	return PLUGIN_HANDLED
}

// Updates the job Array with the lastest SQL Information
public CmdJobsUpdate(id,level,cid)
{
	if(!DRP_CmdAccess(id,cid,1))
		return PLUGIN_HANDLED
	
	client_print(id,print_console,"[DRP] Updating Jobs Tables...");
	
	// We send the query with our ID.
	// The "FetchJobs" function handles the rest.
	new Data[1]
	format(g_Query,4095,"SELECT * FROM %s",g_JobsTable); //LIMIT %d,10000
	Data[0] = id
	SQL_ThreadQuery(g_SqlHandle,"FetchJobs",g_Query,Data);
	
	return PLUGIN_HANDLED
}

public CmdPropUpdate(id,level,cid)
{
	if(!DRP_CmdAccess(id,cid,1))
		return PLUGIN_HANDLED
	
	client_print(id,print_console,"[DRP] Updating Property Tables...");
	
	/*
	// We send the query with our ID.
	// The "FetchJobs" function handles the rest.
	new Data[1]
	format(g_Query,4095,"SELECT * FROM %s LIMIT %d,10000",g_PropertyTable);
	Data[0] = id
	SQL_ThreadQuery(g_SqlHandle,"FetchJobs",g_Query,Data);
	*/
	
	return PLUGIN_HANDLED
}

/*==================================================================================================================================================*/
public client_authorized(id)
{
	if(is_user_bot(id) || is_user_hltv(id))
		return
		
	new AuthID[36],Data[1]
	get_user_authid(id,AuthID,35);
	Data[0] = id
	
	g_GotInfo[id] = false
	g_Joined[id] = false
	g_Display[id] = true
	
	format(g_Query,4095,"SELECT * FROM %s WHERE SteamID='%s'",g_UserTable,AuthID);
	SQL_ThreadQuery(g_SqlHandle,"FetchClientData",g_Query,Data,1);
}

public client_disconnect(id)
{
	if(is_user_bot(id) || is_user_hltv(id))
		return
	
	g_UserItemNum[id] = 0
	g_BadJob[id] = false
	g_Display[id] = true
	
	// Arrays
	array_clear(g_UserItemArray[id]);
	
	for(new Count;Count < HUD_NUM;Count++)
		ClearHud(id,Count);
}

public FetchClientData(FailState,Handle:Query,Error[],Errcode,Data[],DataSize) 
{
	if(FailState == TQUERY_CONNECT_FAILED)
	{
		format(g_Query,4095,"Could not connect to SQL database.");
		return UTIL_Error(0,0,g_Query,0);
	}
	else if(FailState == TQUERY_QUERY_FAILED)
	{
		SQL_GetQueryString(Query,g_Query,4095);
		log_amx("Error On Query: %s",g_Query);
		
		SQL_QueryError(Query,g_Query,4095);
		return UTIL_Error(0,0,g_Query,0);
	}
	
	if(Errcode)
	{
		format(g_Query,4095,"Error on query: %s",Error);
		return UTIL_Error(1,0,g_Query,0);
	}
	
	new id = Data[0]
	if(SQL_NumResults(Query) < 1)
	{
		// The code get's here when the user isn't in the database
		new AuthID[36],StartBankMoney = get_pcvar_num(p_StartMoney);
		get_user_authid(id,AuthID,35);
	
		format(g_Query,4095,"INSERT INTO %s VALUES('%s','%d','0','Unemployed','0','0','0','','','')",g_UserTable,AuthID,StartBankMoney);
		SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",g_Query)
		
		new Results[1]
		DRP_FindJobID("Unemployed",Results,1);
		
		Results[0] -= 1
		
		// Unemployed doesn't exist, add it.
		if(!UTIL_ValidJobID(Results[0]))
			Results[0] = DRP_AddJob("Unemployed",5,ACCESS_E) - 1
		
		g_UserBank[id] = StartBankMoney
		g_UserWallet[id] = 0
		g_UserHunger[id] = 0
		g_UserAccess[id] = 0
		g_UserJobAccess[id] = 0
		g_UserSalary[id] = 0
		
		UTIL_SetUserJobID(id,Results[0]);
		
		array_clear(g_UserItemArray[id]);
		
		server_print("[DRP-CORE] Player %d (%s) was added to the database.",id,AuthID);
		
		g_GotInfo[id] = true
		
		return PLUGIN_CONTINUE
	}
	
	g_UserBank[id] = SQL_ReadResult(Query,1);
	g_UserWallet[id] = SQL_ReadResult(Query,2);
	
	new Results[2],Temp[256]
	SQL_ReadResult(Query,3,Temp,255);
	DRP_FindJobID(Temp,Results,2);
	
	UTIL_SetUserJobID(id,Results[0] - 1);
	
	// We can't find this job
	if((Results[0] && Results[1]) || !Results[0])
	{
		g_BadJob[id] = true
		DRP_FindJobID("Unemployed",Results,1);
		if(!UTIL_ValidJobID(Results[0] - 1))
			Results[0] = DRP_AddJob("Unemployed",5,ACCESS_E) - 1
		
		UTIL_SetUserJobID(id,Results[0] - 1);
	}
	else if(!UTIL_ValidJobID(g_UserJobID[id]))
		g_BadJob[id] = true
	
	g_UserHunger[id] = SQL_ReadResult(Query,4);
	
	SQL_ReadResult(Query,8,Temp,255);
	g_UserAccess[id] = DRP_AccessToInt(Temp);
	
	g_GotInfo[id] = true
	
	array_clear(g_UserItemArray[id]);
	
	// Load the users items.
	SQL_ReadResult(Query,7,Temp,255);
	if(Temp[0])
	{
		new Exploded[MAX_USER_ITEMS][32],Left[5],Right[5]
		new Num = ExplodeString(Exploded,31,Temp,MAX_USER_ITEMS,' ');
	
		for(new Count;Count <= Num;Count++)
		{
			strtok(Exploded[Count],Left,4,Right,4,'|',1);
			debugg("ItemID: %s - Num: %s",Left,Right);
			array_set_int(g_UserItemArray[id],str_to_num(Left),str_to_num(Right));
		}
	}
	
	return PLUGIN_CONTINUE
}
/*==================================================================================================================================================*/
// Saving - THIS FUNCTION IS CURRENTLY NOT USED/NEVER CALLED
public SaveUserData(id)
{
	new AuthID[36]
	get_user_authid(id,AuthID,35);
	if(containi(AuthID,"PENDING") != -1 || containi(AuthID,"LAN") != -1 || equali(AuthID,"STEAM_0:0") || containi(AuthID,"UNKNOWN") != -1)
		return
	
	new Access[27]
	DRP_IntToAccess(g_UserAccess[id],Access,26);
	
	format(g_Query,4095,"UPDATE %s SET BankMoney='%d',WalletMoney='%d',Hunger='%d' Access='%s' WHERE SteamID='%s'",g_UserTable,g_UserBank[id],g_UserWallet[id],g_UserHunger[id],Access,AuthID);
	SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",g_Query);
	
	// DEBUG
	debugg("AuthID Saved. (%s)",AuthID);
}

public SaveData()
{
	TEST_LOG("Save Data");
	
	// Save Economy Pot / Lotto
	format(g_Query,4095,"UPDATE %s SET EconomyPot='%d',Lotto='%d'",g_EconomyTable,g_EconomyPot,g_EconomyLotto);
	SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",g_Query);
}
/*==================================================================================================================================================*/
// HUD System
public ShowHud()
{
	g_HudPending = true
	
	new StartTime = 600
	g_Time -= 10
	
	if(g_Time <= 0)
		g_Time = StartTime
	
	if(!g_HudForward)
		return
	
	g_HealCounter++
	if(g_HungerCounter++ >= 20)
		HandleHunger();
	
	static iPlayers[32],iNum,id
	get_players(iPlayers,iNum);
	
	new Return,SalReturn
	
	new pCvar = get_pcvar_num(p_HealMeds);
	new pHealNum = get_pcvar_num(p_HealInterval);
	new pSalToWal = get_pcvar_num(p_SalaryToWallet);
	
	for(new Count,Count2;Count<iNum;Count++)
	{
		id = iPlayers[Count]
		
		if(pCvar && g_HealCounter >= pHealNum)
		{
			if(DRP_IsMedic(id))
			{
				new plHealth = pev(id,pev_health);
				if(plHealth < 90.0 && plHealth > 5.0)
					set_pev(id,pev_health,plHealth + random_float(0.0,2.0));
			}
		}
		
		if(g_Time == StartTime)
		{
			if(g_SalaryForward <= 0 || !ExecuteForward(g_SalaryForward,SalReturn,id))
				continue
			
			if(!SalReturn && g_EconomyPot > 0) 
			{
				if(pSalToWal)
					UTIL_SetUserMoney(id,WALLET,g_UserWallet[id]+g_UserSalary[id]);
				else
					UTIL_SetUserMoney(id,BANK,g_UserBank[id]+g_UserSalary[id]);
					
				g_EconomyPot -= g_UserSalary[id]
			}
		}
		
		// Clear the hud for the player.
		for(Count2 = 0;Count2<HUD_NUM;Count2++)
			ClearHud(id,Count2);
		
		if(!is_user_connected(id) || !is_user_alive(id) || is_user_bot(id) || !ExecuteForward(g_HudForward,Return,id))
			continue
		
		for(Count2 = 0;Count2 < HUD_NUM;Count2++)
			RenderHud(id,Count2);
	}
	if(g_HealCounter >= pHealNum)
		g_HealCounter = 0
	
	g_HudPending = false
}
ClearHud(id,Hud)
{
	for(new Count,Array;Count < g_HudNum[id][Hud];Count++)
	{
		Array = array_get_int(g_HudArray[id][Hud],Count)
		array_destroy(Array)
	}
	
	g_HudNum[id][Hud] = 0
}
RenderHud(id,Hud)
{
	static Temp[256]
	
	for(new Count,Array,Ticker;Count < g_HudNum[id][Hud];Count++)
	{
		Array = array_get_int(g_HudArray[id][Hud],Count)
		
		array_get_string(Array,0,Temp,255);
		Ticker += format(g_Query[Ticker],4095 - Ticker,Temp);
	}
	set_hudmessage(get_pcvar_num(p_Hud[Hud][R]),get_pcvar_num(p_Hud[Hud][G]),get_pcvar_num(p_Hud[Hud][B]),get_pcvar_float(p_Hud[Hud][X]),get_pcvar_float(p_Hud[Hud][Y]),0,0.0,99.9,0.0,0.0,-1);
	//set_hudmessage(r,g,b,x,y,e,fxtime,HOLDTIME)
	
	// The user's informaton hasn't loaded.
	// Display an error message on the HUD
	// REMOVE ME?
	if(!g_GotInfo[id] ) 
	{
		format(Temp,255,"Welcome to DRP^nYour information has failed to load/not loaded yet.^nTry Re-connecting^nOr contacting an admin.");
		ShowSyncHudMsg(id,g_HudObjects[Hud],"%s",Temp);
		return 
	}
	/// REMOVE ME?
	if(g_BadJob[id])
	{
		format(Temp,255,"Welcome to DRP^nBad Job!");
		ShowSyncHudMsg(id,g_HudObjects[Hud],"%s",Temp);
		return 
	}
	ShowSyncHudMsg(id,g_HudObjects[Hud],"%s",g_Query);
	g_Query[0] = 0
}
/*==================================================================================================================================================*/
public HandleHunger()
{
	if(get_pcvar_num(p_HungerEnabled) == 0 || random_num(1,3) != 2)
		return
	
	g_HungerCounter = 0
	
	new iPlayers[32],iNum,id
	get_players(iPlayers,iNum,"a");
	for(new Count;Count<iNum;Count++)
	{
		id = iPlayers[Count]
		
		// Hunger level of 120 = Death
		UTIL_SetUserHunger(id,g_UserHunger[id] + random_num(0,3));
		
		if(g_UserHunger[id] > 83 && g_UserHunger[id] < 90)
		{
			switch(random_num(0,3))
			{
				case 1: client_print(id,print_chat,"[HungerMod] You feel abit hungry.");
				case 2: client_print(id,print_chat,"[HungerMod] You're getting thirsty.");
				case 3: client_print(id,print_chat,"[HungerMod] You're getting hungry.");
			}
		}
		
		// We are getting close to starvation. (max = 120)
		else if(g_UserHunger[id] > 105 && g_UserHunger[id] < 110)
		{
			switch(random_num(0,3))
			{
				case 1: client_print(id,print_chat,"[HungerMod] You need to eat.");
				case 2: client_print(id,print_chat,"[HungerMod] Your body needs energy.");
				case 3: client_print(id,print_chat,"[HungerMod] You're hungry.");
			}
		}
		else if(g_UserHunger[id] > 112 && g_UserHunger[id] < 120)
		{
			switch(random_num(1,4))
			{
				case 1: client_print(id,print_chat,"[HungerMod] You're seeing colors, you need to eat.");
				case 2: client_print(id,print_chat,"[HungerMod] You are seeing things... Get something to eat.");
				case 3: client_print(id,print_chat,"[HungerMod] You are dehidrating. You need food.");
				case 4: client_print(id,print_chat,"[HungerMod] You're running out of energy.");
			}
				
			if(get_pcvar_num(p_HungerEffects))
			{
				// Fade there screen
				message_begin(MSG_ONE_UNRELIABLE,gmsgTSFade,_,id);
				
				write_short(seconds_to_screenfade_units(10)); // 15
				write_short(1<<13);
				write_short(FADE_IN_OUT);

				write_byte(random_num(0,125));
				write_byte(random_num(0,115));
				write_byte(random_num(0,200));
				write_byte(125);
				
				message_end();
				
				if(random_num(1,2) == 1 && g_UserHunger[id] > 115)
				{
					message_begin(MSG_ONE_UNRELIABLE,gmsgScreenShake,_,id);
					
					write_short(1<<13);
					write_short(seconds_to_screenfade_units(10))
					write_short(5<<14) 
					
					message_end()
				
					client_print(id,print_chat,"[HungerMod] You're getting dizzy. Eat something");
				}
			}
		}
		
		// They reached the max
		else if(g_UserHunger[id] >= 120)
		{
			client_print(id,print_chat,"[HungerMod] You died because of hunger.");
		}
	}
}
#include <engine>
/*==================================================================================================================================================*/
// Forwards
public forward_PreThink(id)
{
	if(!is_user_alive(id))
		return
	
	new Index,Body
	get_user_aiming(id,Index,Body,110);
	
	static Classname[33],Message[256]
	if(pev(id,pev_button) & IN_USE && !(pev(id,pev_oldbuttons) & IN_USE))
	{
		if(!Index)
			return
		
		pev(Index,pev_classname,Classname,32);
		if(equali(Classname,"func_door") || equali(Classname,"func_door_rotating"))
		{
			if(DRP_IsUserCuffed(id)) {
				client_print(id,print_chat,"[DRP] You can't open a door while cuffed.");
				return
			}
			pev(Index,pev_targetname,Classname,32);
			new Property = UTIL_GetProperty(Classname);
			if(Property == -1)
				return
				
			static AuthID[36],DoorAuthID[36]
			get_user_authid(id,AuthID,35);
				
			new Array = array_get_int(g_PropertyArray,Property);
			array_get_string(Array,3,DoorAuthID,35);
								
			if(!array_get_int(Array,5) || equali(AuthID,DoorAuthID))
			{
				dllfunc(DLLFunc_Use,Index,Index);
				client_print(id,print_chat,"[DRP] * You used the door.");
			}
			else
				client_print(id,print_chat,"[DRP] * This door is locked.");
				
			return
		}
		else if(equali(Classname,g_iNPCName))
		{
			new Plugin = pev(Index,pev_iuser3);
			new Handler[33]
			pev(Index,pev_noise,Handler,32);
			
			NpcUse(Handler,Plugin,id,Index);
		}
	}
	if(g_Display[id])
	{
		if(equali(Classname,"func_door") || equali(Classname,"func_door_rotating"))
		{
			pev(Index,pev_targetname,Classname,32);
			
			new Property = UTIL_GetProperty(Classname);
			if(Property == -1) 
				return
				
			static Name[33],OwnerName[33],Purchase[64]
			
			new Array = array_get_int(g_PropertyArray,Property);
			array_get_string(Array,1,Name,32);
			array_get_string(Array,2,OwnerName,32);
			new Price = array_get_int(Array,4);
			
			UTIL_HUD_ClientPrint(id,"PROPERTY << Name: %s - Price: $%d - Owner: %s - Locked: %s >>",Name,Price,OwnerName,array_get_int(Array,5) ? "Locked" : "Unlocked");
		}
		else if(equali(Classname,g_iNPCName))
		{
			new NPC[33]
			pev(Index,pev_noise1,NPC,32);
			client_print(id,print_center,"NPC: %s^nPress use (default e)",NPC);
		}
		
		new EntList[50]
		new NumEnts = find_sphere_class(id,g_iDRPZone,50.0,EntList,50);
		for(new Count;Count < NumEnts;Count++)
		{		
			Index = EntList[Count]
			
			new Zone = pev(Index,pev_iuser3);
			switch(Zone)
			{
				case ZONE_UNCUFF: UTIL_AddHudItem(id,HUD_SEC,"You are in a uncuff zone.",0);
			}
			debugg("ZONE: %i",Zone);
		}
		g_Display[id] = false
		set_task(0.1,"ResetDisplay",id);
	}
}

public ResetDisplay(id)
{
	g_Display[id] = true
	ClearHud(id,HUD_SEC);
}

public forward_Touch(ent,id)
{
	if(!ent || !id)
		return
	
	static Classname[33]
	pev(id,pev_classname,Classname,32);
	if(!equal(Classname,"player"))
		return
	
	if(g_TouchTimeOut[id] || !is_user_alive(id))
		return
	
	pev(ent,pev_classname,Classname,32);
	if(equali(Classname,g_szItem))
	{
		new ItemID = pev(ent,pev_iuser1);
		new ItemNum = pev(ent,pev_iuser2);
		
		UTIL_SetUserItemNum(id,ItemID,UTIL_GetUserItemNum(id,ItemID) + ItemNum);
		UTIL_GetItemName(ItemID,Classname,32);
	
		client_print(id,print_chat,"[DRP] You have picked up %d %s%s.",ItemNum,Classname,ItemNum == 1 ? "" : "s");
		emit_sound(id,CHAN_ITEM,"items/gunpickup2.wav",1.0,ATTN_NORM,0,PITCH_NORM);
		
		engfunc(EngFunc_RemoveEntity,ent);
		
		return
	}
	else if(equali(Classname,g_szMoneyPile))
	{
		new Amount[15]
		pev(ent,pev_targetname,Amount,14);
		
		new Money = str_to_num(Amount);
		if(!Money)
			return
		
		client_print(id,print_chat,"[Economy] You picked up $%d %s",Money,Money == 1 ? "dollar" : "dollars");
		
		UTIL_SetUserMoney(id,WALLET,g_UserWallet[id] + Money);
		engfunc(EngFunc_RemoveEntity,ent);
		
		return
	}
}
public _TouchTimeout(id)
	g_TouchTimeOut[id] = false

/*==================================================================================================================================================*/
// Events
public EventDeathMsg()
{
	new id = read_data(2);
	if(!is_user_connected(id))
		return UTIL_Error(0,0,"EventDeathMessage Error. (User Not Connected)",0);
	
	if(get_pcvar_num(p_WalletDeath))
		UTIL_SetUserMoney(id,WALLET,0);
	
	UTIL_SetUserHunger(id,0);
	
	
	static Message[33]
	if(g_WhosRobbing[SEVEN_ELEVEN] == id)
		Message = "7/11 Gas Station"
	else if(g_WhosRobbing[MECK_DINER] == id)
		Message = "Diner"
	else if(g_WhosRobbing[MECK_BANK] == id)
		Message = "Bank"
	
	if(Message[0])
	{
		new plNames[2][36],Killer = read_data(2),KillerMsg[64]
		if(Killer && Killer != id)
		{
			get_user_name(Killer,plNames[0],35);
			format(KillerMsg,63,"by %s",plNames[0]);
		}
		new RobMessage[128]
		format(RobMessage,127,"#name# has been stopped robbing the %s^n%s",plNames[1],Message,KillerMsg);
		EndRob(id,RobMessage);
	}
	
	if(g_DeathScreen)
	{
		// Turn there screen black
		message_begin(MSG_ONE,gmsgTSFade, _, id)

		write_short(~0); // duration
		write_short(~0); // hold time
		write_short(FFADE_STAYOUT)   // fade type HOLD

		write_byte(0)
		write_byte(0)
		write_byte(0)
		write_byte(255)
		message_end();
	}
	
	return PLUGIN_CONTINUE
}


public EventResetHUD(id)
{
	/*
	if(g_DeathScreen)
	{
		message_begin(MSG_ONE,gmsgTSFade, _, id)

		write_short(seconds_to_screenfade_units(25));
		write_short(seconds_to_screenfade_units(15));
		write_short(FFADE_STAYOUT);

		write_byte(0)
		write_byte(0)
		write_byte(0)
		write_byte(255)
		message_end();
	}
	*/
	
	if(g_Joined[id])
		return
	
	set_task(1.0,"WelcomeMsg",id);
}

public WelcomeMsg(id)
{
	if(is_user_alive(id))
	{
		new plName[36],AuthID[36]
		get_user_name(id,plName,35);
		client_print(id,print_chat,"[DRP] Welcome %s. Enjoy your stay.",plName);
		client_print(id,print_chat,"[DRP] Need Help? Type ^"drp_help^" in your console.");

		g_Joined[id] = true
		
		get_user_authid(id,AuthID,35);
		if(containi(AuthID,"PENDING") != -1 || containi(AuthID,"LAN") != -1 || equali(AuthID,"STEAM_0:0")) {
			client_print(id,print_chat,"[DRP] Your Steam identification has failed to load. Your user data will not be saved.");
			UTIL_Error(0,0,"Player Authorization Error (WelcomeMsg Func)",0);
		}
		engclient_print(id,engprint_console,"------------------------------------------");
		engclient_print(id,engprint_console,"Server Powered by DRPCore (Version %s)",VERSION);
		engclient_print(id,engprint_console,"By Drak (STEAM_0:0:5932780)");
		engclient_print(id,engprint_console,"------------------------------------------");
	}
}
/*==================================================================================================================================================*/
NpcUse(Handler[],Plugin,id,Index)
{
	new Forward = CreateOneForward(Plugin,Handler,FP_CELL,FP_CELL),Return
	if(Forward <= 0 || !ExecuteForward(Forward,Return,id,Index))
	{
		format(g_Query,255,"Function does not exist: %s",Handler)
		return UTIL_Error(0,0,g_Query,Plugin)
	}
	
	DestroyForward(Forward)
	
	return SUCCEEDED
}
ItemUse(id,ItemId,UseUp)
{
	new Array = array_get_int(g_ItemsArray,UTIL_ValidItemID(ItemId))
	if(!Array)
		return FAILED
	
	static FuncHandler[33],Extra[5]
	array_get_string(Array,3,FuncHandler,32);
	array_get_array(Array,9,Extra,4);
	
	/*
	for(new Count;Count < g_ItemsNum;Count++)
	{
		Array = array_get_int(g_ItemsArray,Count + 1);
		if(ItemId == array_get_int(Array,8)) 
		{
			array_get_string(Array,3,FuncHandler,32);
			array_get_array(Array,9,Extra,4);
		}
	}
	*/
	new iArrayPass = PrepareArray(Extra,4);
	
	g_UserItemUse[id] = array_get_int(Array,2);
	
	new Forward = CreateOneForward(g_UserItemUse[id],FuncHandler,FP_CELL,FP_CELL,FP_ARRAY),Return
	if(Forward <= 0 || !ExecuteForward(Forward,Return,id,ItemId,iArrayPass))
	{
		format(g_Query,4095,"Error Calling Forward. Function ^"%s^" does not exist in plugin %d.",FuncHandler,g_UserItemUse[id]);
		return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,0);
	}
	
	// if disposable
	if(UseUp && array_get_int(Array,5))
		UTIL_SetUserItemNum(id,ItemId,UTIL_GetUserItemNum(id,ItemId) - 1);
	
	DestroyForward(Forward);
	
	return SUCCEEDED
}
/*==================================================================================================================================================*/
EndRob(id,const Reason[])
{
	if(g_WhosRobbing[SEVEN_ELEVEN] == id)
		g_WhosRobbing[SEVEN_ELEVEN] = 0
	else if(g_WhosRobbing[MECK_DINER] == id)
		g_WhosRobbing[MECK_DINER] = 0
	else if(g_WhosRobbing[MECK_BANK] == id)
		g_WhosRobbing[MECK_BANK] = 0
	else if(g_WhosRobbing[OTHER] == id)
		g_WhosRobbing[OTHER] = 0
	else
		return FAILED
		
	fm_set_user_rendering(id);
	
	new Name[36],Msg[256]
	copy(Msg,255,Reason);
	get_user_name(id,Name,35);
	
	replace_all(Msg,255,"#name#",Name);
	
	set_hudmessage(255,255,0,-1.0,0.35,0,0.0,8.0,0.0,0.0,-1);
	show_hudmessage(0,"%s",Msg);
	
	new Return
	if(g_RobEndForward <= 0 || !ExecuteForward(g_RobEndForward,Return,id,Msg))
	{
		format(g_Query,4095,"Error calling DRP_RobEnd forward.");
		return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,0);
	}
	return SUCCEEDED
}
RobForward(id,CashSecond,CashMax,const Targetname[],Type)
{
	new Return
	if(g_RobForward <= 0 || !ExecuteForward(g_RobForward,Return,id,CashSecond,CashMax,Targetname,Type))
	{
		format(g_Query,4095,"Could not call DRP_UserRob forward.");
		return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,0);
	}
	return SUCCEEDED
}
/*==================================================================================================================================================*/
// Dynamic Natives
public plugin_natives()
{
	register_library("DRPCore");
	
	register_native("DRP_ThrowError","_DRP_ThrowError");
	register_native("DRP_SqlHandle","_DRP_SqlHandle");
	register_native("DRP_GetConfigsDir","_DRP_GetConfigsDir");
	
	register_native("DRP_GetUserWallet","_DRP_GetUserWallet");
	register_native("DRP_SetUserWallet","_DRP_SetUserWallet");
	register_native("DRP_GetUserBank","_DRP_GetUserBank");
	register_native("DRP_SetUserBank","_DRP_SetUserBank");
	
	register_native("DRP_GetUserJobID","_DRP_GetUserJobID");
	register_native("DRP_SetUserJobID","_DRP_SetUserJobID");
	register_native("DRP_GetJobSalary","_DRP_GetJobSalary");
	
	register_native("DRP_FindJobID","_DRP_FindJobID");
	register_native("DRP_FindItemID","_DRP_FindItemID");
	
	register_native("DRP_ValidJobID","_DRP_ValidJobID");
	register_native("DRP_ValidItemID","_DRP_ValidItemID");
	
	register_native("DRP_GetUserHunger","_DRP_GetUserHunger");
	register_native("DRP_SetUserHunger","_DRP_SetUserHunger");
	
	register_native("DRP_AddCommand","_DRP_AddCommand");
	register_native("DRP_AddHudItem","_DRP_AddHudItem");
	register_native("DRP_AddJob","_DRP_AddJob");
	
	register_native("DRP_RegisterNpc","_DRP_RegisterNpc");
	
	register_native("DRP_GetPayDay","_DRP_GetPayDay");
	register_native("DRP_GetEconomyPot","_DRP_GetEconomyPot");
	
	register_native("DRP_RegisterItem","_DRP_RegisterItem");
	register_native("DRP_GetItemName","_DRP_GetItemName");
	
	register_native("DRP_GetUserItemNum","_DRP_GetUserItemNum");
	register_native("DRP_SetUserItemNum","_DRP_SetUserItemNum");
	register_native("DRP_ForceUseItem","_DRP_ForceUseItem");
	
	register_native("DRP_GetUserAccess","_DRP_GetUserAccess");
	register_native("DRP_SetUserAccess","_DRP_SetUserAccess");
	
	register_native("DRP_SetUserJobRights","_DRP_SetUserJobRights");
	register_native("DRP_GetUserJobRights","_DRP_GetUserJobRights");
	
	register_native("DRP_GetJobName","_DRP_GetJobName");
	
	register_native("DRP_GetRob","_DRP_GetRob");
	register_native("DRP_StartRob","_DRP_StartRob");
	register_native("DRP_EndRob","_DRP_EndRob");
	
	register_native("DRP_AddProperty","_DRP_AddProperty");
}

// DRP_Error(Fatal,Message,any:...)
public _DRP_ThrowError(Plugin,Params)
{
	if(Params < 2)
	{
		format(g_Query,4095,"Parameters do not match. Expected: 2 or more, Found: %d",Params);
		return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,Plugin);
	}
	
	new Mode = get_param(1);
	vdformat(g_Query,4095,2,3);
	
	UTIL_Error(0,Mode,g_Query,Plugin);
	
	return SUCCEEDED
}
public _DRP_SqlHandle(Plugin,Params)
{
	return _:g_SqlHandle
}
public _DRP_GetConfigsDir(Plugin,Params)
{
	if(Params != 2)
	{
		format(g_Query,4095,"Parameters do not match. Expected: 2, Found: %d",Params);
		return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,Plugin);
	}
	
	set_string(1,g_ConfigDir,get_param(2));
	
	return SUCCEEDED
}
/*==================================================================================================================================================*/
public _DRP_GetUserWallet(Plugin,Params)
{
	if(Params != 1)
	{
		format(g_Query,4095,"Parameters do not match. Expected: 1, Found: %d",Params);
		return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,Plugin);
	}
	new id = get_param(1);
	
	if(is_user_connected(id))
		return g_UserWallet[id]
	else
	{
		format(g_Query,4095,"User not connected: %d",id);
		return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,Plugin);
	}
	return FAILED
}
public _DRP_SetUserWallet(Plugin,Params)
{
	if(Params != 2)
	{
		format(g_Query,4095,"Parameters do not match. Expected: 1, Found: %d",Params)
		return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,Plugin)
	}
	
	new id = get_param(1);
	new amount = get_param(2);
	
	if(is_user_connected(id))
		UTIL_SetUserMoney(id,WALLET,amount);
	else
	{
		format(g_Query,4095,"User not connected: %d",id);
		return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,Plugin);
	}
	
	return FAILED
}
public _DRP_GetUserBank(Plugin,Params)
{
	if(Params != 1)
	{
		format(g_Query,4095,"Parameters do not match. Expected: 1, Found: %d",Params);
		return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,Plugin)
	}
	new id = get_param(1);
	
	if(is_user_connected(id))
		return g_UserBank[id]
	else
	{
		format(g_Query,4095,"User not connected: %d",id);
		return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,Plugin);
	}
	
	return FAILED
}
public _DRP_SetUserBank(Plugin,Params)
{
	if(Params != 2)
	{
		format(g_Query,4095,"Parameters do not match. Expected: 1, Found: %d",Params);
		return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,Plugin);
	}
	
	new id = get_param(1);
	new amount = get_param(2);
	
	if(is_user_connected(id))
		UTIL_SetUserMoney(id,BANK,amount);
	else
	{
		format(g_Query,4095,"User not connected: %d",id);
		return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,Plugin);
	}
	
	return FAILED
}
/*==================================================================================================================================================*/
public _DRP_GetUserJobID(Plugin,Params)
{
	if(Params != 1)
	{
		format(g_Query,4095,"Parameters do not match. Expected: 1, Found: %d",Params);
		return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,Plugin);
	}
	new id = get_param(1);
	
	if(is_user_connected(id))
		return g_UserJobID[id] + 1
	else
	{
		format(g_Query,4095,"User not connected: %d",id)
		return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,Plugin)
	}
	return SUCCEEDED
}
public _DRP_SetUserJobID(Plugin,Params)
{
	if(Params != 2)
	{
		format(g_Query,4095,"Parameters do not match. Expected: 2, Found: %d",Params);
		return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,Plugin);
	}
	
	new JobID = get_param(2) - 1
	
	if(!UTIL_ValidJobID(JobID))
	{
		format(g_Query,4095,"Invalid JobID %d",JobID);
		return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,Plugin);
	}
	new id = get_param(1);
	
	if(is_user_connected(id))
		UTIL_SetUserJobID(id,JobID);
	else
	{
		format(g_Query,4095,"User not connected: %d",id);
		return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,Plugin);
	}
	return SUCCEEDED
}
public _DRP_GetJobSalary(Plugin,Params)
{
	if(Params != 1)
	{
		format(g_Query,4095,"Parameters do not match. Expected: 1, Found: %d",Params);
		return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,Plugin);
	}
	
	new JobId = get_param(1) - 1;
	if(!UTIL_ValidJobID(JobId))
	{
		format(g_Query,4095,"Invalid job id: %d",JobId);
		return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,Plugin);
	}
	
	return array_get_int(array_get_int(g_JobArray,JobId),2);
}
/*==================================================================================================================================================*/
public _DRP_FindJobID(Plugin,Params)
{
	if(Params != 3)
	{
		format(g_Query,4095,"Parameters do not match. Expected: 3, Found: %d",Params);
		return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,Plugin);
	}
		
	new SearchString[64],Results[256],MaxResults = get_param(3),Num,Name[33]
	get_string(1,SearchString,63);
	
	for(new Count;Count < g_JobNum;Count++)
	{		
		if(Num >= MaxResults)
			break
		
		array_get_string(array_get_int(g_JobArray,Count),1,Name,32);
		if(containi(Name,SearchString) != -1)
			Results[Num++] = Count + 1
	}
	
	set_array(2,Results,MaxResults);
	
	return Num
}
public _DRP_FindItemID(Plugin,Params)
{
	if(Params != 3)
	{
		format(g_Query,4095,"Parameters do not match. Expected: 3, Found: %d",Params);
		return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,Plugin);
	}
	
	new SearchString[64],Results[256],MaxResults = get_param(3),Num,Name[33]
	get_string(1,SearchString,63);
	for(new Count = 1;Count <= g_ItemsNum;Count++)
	{
		if(Num >= MaxResults)
			break
		
		array_get_string(array_get_int(g_ItemsArray,Count),1,Name,32);
		if(containi(Name,SearchString) != -1)
			Results[Num++] = Count //+ 1
	}
	set_array(2,Results,MaxResults);
	return Num
}
public _DRP_ValidJobID(Plugin,Params)
{
	if(Params != 1 && Plugin)
	{
		format(g_Query,4095,"Parameters do not match. Expected: 1, Found: %d",Params);
		return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,Plugin);
	}
	
	new JobId = get_param(1) - 1
	
	return UTIL_ValidJobID(JobId);
}
public _DRP_ValidItemID(Plugin,Params)
{
	if(Params != 1 && Plugin)
	{
		format(g_Query,4095,"Parameters do not match. Expected: 1, Found: %d",Params);
		return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,Plugin);
	}
	
	new ItemID = get_param(1);
	
	return UTIL_ValidItemID(ItemID);
}	
/*==================================================================================================================================================*/
public _DRP_GetUserHunger(Plugin,Params)
{
	if(Params != 1)
	{
		format(g_Query,4095,"Parameters do not match. Expected: 2 or more, Found: %d",Params);
		return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,Plugin);
	}
	
	if(get_pcvar_num(p_HungerEnabled) == 0)
		return FAILED
	
	new id = get_param(1);
	
	if(is_user_connected(id))
		return g_UserHunger[id]
	else
	{
		format(g_Query,4095,"User not connected: %d",id)
		return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,Plugin)
	}
	return SUCCEEDED
}
public _DRP_SetUserHunger(Plugin,Params)
{
	if(Params != 2)
	{
		format(g_Query,4095,"Parameters do not match. Expected: 2, Found: %d",Params);
		return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,Plugin);
	}
	
	if(get_pcvar_num(p_HungerEnabled) == 0)
		return FAILED
	
	new id = get_param(1);
	
	if(is_user_connected(id))
		UTIL_SetUserHunger(id,get_param(2));
	else
	{
		format(g_Query,4095,"User not connected: %d",id)
		return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,Plugin)
	}
	return SUCCEEDED
}
/*==================================================================================================================================================*/
public _DRP_AddCommand(Plugin,Params)
{
	if(Params != 2)
	{
		format(g_Query,4095,"Parameters do not match. Expected: 2, Found: %d",Params);
		return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,Plugin);
	}
	
	new Array =  array_create();
	array_set_int(g_CommandArray,++g_CommandNum,Array);
	
	get_string(1,g_Query,4095);
	array_set_string(Array,1,g_Query);
		
	get_string(2,g_Query,4095);
	array_set_string(Array,2,g_Query);
	
	return SUCCEEDED
}
public _DRP_AddHudItem(Plugin,Params)
{
	if(Params < 4)
	{
		format(g_Query,4095,"Parameters do not match. Expected: 4, Found: %d",Params)
		return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,Plugin)
	}
	
	new id = get_param(1);
	if(!is_user_connected(id) && id != -1)
	{
		format(g_Query,4095,"User not connected: %d",id);
		return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,Plugin);
	}
	new Channel = get_param(2),Refresh = get_param(3)
	if(Channel < 0 || Channel > HUD_NUM)
	{
		format(g_Query,4095,"Invalid channel: %d",Channel);
		return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,Plugin);
	}

	vdformat(g_Query,4095,4,5);
	add(g_Query,4095,"^n");

	if(g_HudPending)
		Refresh = 0
	
	UTIL_AddHudItem(id,Channel,g_Query,Refresh);
	
	return SUCCEEDED
}
public _DRP_AddJob(Plugin,Params)
{
	if(Params != 3)
	{
		format(g_Query,4095,"Parameters do not match. Expected: 3, Found: %d",Params);
		return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,Plugin);
	}
	
	new Name[33],Salary,IntAccess
	get_string(1,Name,32);
	Salary = get_param(2);
	IntAccess = get_param(3);
	
	new Results[1]
	DRP_FindJobID(Name,Results,1);
	
	if(Results[0])
	{
		Results[0] -= 1
		
		new TempName[33]
		array_get_string(array_get_int(g_JobArray,Results[0]),1,TempName,32);
		
		format(g_Query,4095,"A job with a similar name already exists. User input: %s - Existing job: %s",Name,TempName);
		return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,Plugin);
	}
	
	new Access[JOB_ACCESSES + 1]
	DRP_IntToAccess(IntAccess,Access,JOB_ACCESSES);
	
	format(g_Query,4095,"INSERT INTO %s VALUES ('%s','%d','%s')",g_JobsTable,Name,Salary,Access)
	SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",g_Query)
	
	new Array = array_create();
	array_set_int(g_JobArray,g_JobNum++,Array);
	
	array_set_string(Array,1,Name);
	array_set_int(Array,2,Salary);
	array_set_int(Array,3,IntAccess);
	
	return g_JobNum
}
/*==================================================================================================================================================*/
public _DRP_RegisterNpc(Plugin,Params)
{
	if(Params != 7)
	{
		format(g_Query,4095,"Parameters do not match. Expected: 7, Found: %d",Params);
		return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,Plugin);
	}
	
	new Float:Origin[3],Float:Angles[3],Model[64],Name[33],Handler[32],Zone,Property[64]
	
	get_string(1,Name,32);
	get_array_f(2,Origin,3);
	Angles[1] = get_param_f(3) - 180
	get_string(4,Model,63);
	get_string(5,Handler,31);
	Zone = get_param(6);
	get_string(7,Property,63)
	
	new Ent = engfunc(EngFunc_CreateNamedEntity,engfunc(EngFunc_AllocString,"info_target"));
	if(!pev_valid(Ent))
	{
		format(g_Query,4095,"Unable to spawn NPC.",Params);
		return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,0);
	}
	if(Zone)
	{
		set_pev(Ent,pev_classname,g_iDRPZone);
		engfunc(EngFunc_SetModel,Ent,g_FillModel);
	}
	else
	{
		set_pev(Ent,pev_classname,g_iNPCName);
		engfunc(EngFunc_SetModel,Ent,Model)
		
		Origin[2] += 36.1
		if(engfunc(EngFunc_PointContents,Origin) != CONTENTS_EMPTY)
			Origin[2] -= 36.1;
	}
	engfunc(EngFunc_SetOrigin,Ent,Origin);
	engfunc(EngFunc_SetSize,Ent,Float:{-16.0,-16.0,-36.0},Float:{16.0,16.0,36.0});
	
	if(Zone)
		set_pev(Ent,pev_solid,SOLID_TRIGGER);
	else
		set_pev(Ent,pev_solid,SOLID_BBOX);
	
	set_pev(Ent,pev_controller_0,125);
	set_pev(Ent,pev_controller_1,125);
	set_pev(Ent,pev_controller_2,125);
	set_pev(Ent,pev_controller_3,125);
	
	set_pev(Ent,pev_sequence,1);
	set_pev(Ent,pev_framerate,1.0);
	
	set_pev(Ent,pev_angles,Angles);
	
	set_pev(Ent,pev_iuser3,Plugin);
	
	set_pev(Ent,pev_noise,Handler);
	set_pev(Ent,pev_noise1,Name);
	set_pev(Ent,pev_noise2,Property);
	
	if(Zone)
		set_pev(Ent,pev_iuser3,Zone);
		
	if(!Zone)
		engfunc(EngFunc_DropToFloor,Ent);
		
	return Ent
}
/*==================================================================================================================================================*/
public _DRP_GetPayDay(Plugin,Params)
	return g_Time / 10
public _DRP_GetEconomyPot(Plugin,Params)
{
	if(get_param(1)) 
		return g_EconomyLotto
	else
		return g_EconomyPot
		
	return FAILED
}
/*==================================================================================================================================================*/
public _DRP_GetJobName(Plugin,Params)
{
	if(Params != 3)
	{
		format(g_Query,4095,"Parameters do not match. Expected: 3, Found: %d",Params);
		return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,Plugin);
	}
	
	new JobId = get_param(1) - 1,JobName[36]
	
	if(!UTIL_ValidJobID(JobId))
	{
		format(g_Query,4095,"Invalid job id: %d",JobId);
		return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,Plugin);
	}
	
	array_get_string(array_get_int(g_JobArray,JobId),1,JobName,35);	
	set_string(2,JobName,get_param(3));
	
	return SUCCEEDED
}
/*==================================================================================================================================================*/
public _DRP_GetRob(Plugin,Params)
{
	if(Params != 5)
	{
		format(g_Query,4095,"Parameters do not match. Expected: 5, Found: %d",Params);
		return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,Plugin);
	}
	
	new id = get_param(1);
	
	if(!is_user_connected(id))
	{
		format(g_Query,4095,"User not connected: %d",id);
		return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,Plugin);
	}
	
	for(new Count;Count < ROB_PLACES;Count++)
	{
		if(g_WhosRobbing[Count] != id)
		{
			format(g_Query,4095,"User %d is not robbing any place.",id);
			return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,Plugin);
		}
	}
	
	set_param_byref(2,g_RobInfo[id][1]);
	set_param_byref(3,g_RobInfo[id][2]);
	set_param_byref(4,g_RobInfo[id][3]);
	set_param_byref(5,g_RobInfo[id][4]);
	
	return SUCCEEDED
}
public _DRP_StartRob(Plugin,Params)
{	
	if(Params != 7)
	{
		format(g_Query,4095,"Parameters do not match. Expected: 7, Found: %d",Params);
		return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,Plugin);
	}
		
	new id = get_param(1)
	if(!is_user_connected(id))
	{
		format(g_Query,4095,"User not connected: %d",id);
		return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,Plugin);
	}
	
	new CashSecond = get_param(2),CashMax = get_param(3),Targetname[33],Extra[33],Float:TimeReset = get_param_f(4),Type = get_param(7)
	get_string(5,Targetname,32);
	get_string(6,Extra,32);
	
	if(CashSecond < 1)
	{
		format(g_Query,4095,"CashSecond must be greater than 0, value: %d",CashSecond);
		return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,Plugin);
	}
	
	if(CashMax < 1)
	{
		format(g_Query,4095,"CashMax must be greater than 0, value: %d",CashMax);
		return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,Plugin);
	}
	
	new Ent = engfunc(EngFunc_FindEntityByString,-1,"targetname",Targetname);
	if(!pev_valid(Ent))
	{
		format(g_Query,4095,"Invalid targetname: %s",Targetname);
		return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,Plugin);
	}
	
	if(DRP_IsCop(id))
	{
		client_print(id,print_chat,"[RobMOD] Police and SWAT Officers cannot rob.");
		return FAILED
	}
	if(DRP_IsUserCuffed(id))
	{
		client_print(id,print_chat,"[RobMOD] You cannot rob when cuffed.");
		return FAILED
	}
	
	new Time = floatround(get_gametime()),Name[36]
	get_user_name(id,Name,35);
	
	set_hudmessage(210,210,0,-1.0,0.35,0,0.0,8.0,0.0,0.0,-1);
	
	new Cops
	for(new Count = 1;Count <= 32;Count++)
		if(is_user_connected(Count) && DRP_IsCop(Count))
			Cops++
	
	static iPlayers[32],iNum
	switch(Type)
	{
		case SEVEN_ELEVEN:
		{
			if(Time - g_LastRob[SEVEN_ELEVEN] < get_pcvar_num(p_711RobWait) && g_LastRob[SEVEN_ELEVEN])
			{
				client_print(id,print_chat,"[RobMOD] The 711 has already been robbed recently.");
				return FAILED
			}
			if(get_pcvar_num(p_711MinPlayers) > get_playersnum())
			{
				client_print(id,print_chat,"[RobMOD] There are not enough players to rob the 711.");
				return FAILED
			}
			if(Cops < get_pcvar_num(p_711MinCops))
			{
				client_print(id,print_chat,"[RobMOD] There are not enough Police/SWAT/Army Officers to rob the 711.");
				return FAILED
			}
			
			if(!RobForward(id,CashSecond,CashMax,Targetname,Type))
				return FAILED
			
			g_WhosRobbing[SEVEN_ELEVEN] = id
			g_LastRob[SEVEN_ELEVEN] = Time
			
			switch(get_pcvar_num(p_ShowRobber))
			{
				case 0 : { }
				case 1 :
					show_hudmessage(0,"Attention All Police Units!^nThe 711 Gas Station is being emptied");
				case 2 :
					show_hudmessage(0,"Attention All Police Units!^n%s is Emptying The 711!",Name);
			}
			client_print(id,print_chat,"[RobMOD] You are robbing the 711. Stay close to the cash register or the rob will be aborted");
		}
		case MECK_DINER:
		{
			if(Time - g_LastRob[MECK_DINER] < get_pcvar_num(p_DinerRobWait) && g_LastRob[MECK_DINER])
			{
				client_print(id,print_chat,"[RobMOD] The Diner has already been robbed recently.");
				return FAILED
			}
			if(get_pcvar_num(p_DinerMinPlayers) > get_playersnum())
			{
				client_print(id,print_chat,"[RobMOD] There are not enough players to rob the Diner.");
				return FAILED
			}
			if(Cops < get_pcvar_num(p_DinerMinCops))
			{
				client_print(id,print_chat,"[RobMOD] There are not enough Police/SWAT/Army Officers to rob the diner.");
				return FAILED
			}
			
			if(!RobForward(id,CashSecond,CashMax,Targetname,Type))
				return FAILED
			
			g_WhosRobbing[MECK_DINER] = id
			g_LastRob[MECK_DINER] = Time
			
			switch(get_pcvar_num(p_ShowRobber))
			{
				case 0 : { }
				case 1 :
					show_hudmessage(0,"Attention All Police Units!^nThe diner is being emptied");
				case 2 :
					show_hudmessage(0,"Attention All Police Units!^n%s is emptying the diner!",Name);
			}
			client_print(id,print_chat,"[RobMOD] You are robbing the diner. Stay close to the cash register or the rob will be aborted");
		}
		case MECK_BANK:
		{
			if(Time - g_LastRob[MECK_BANK] < get_pcvar_num(p_BankRobWait) && g_LastRob[MECK_BANK])
			{
				client_print(id,print_chat,"[RobMOD] The Bank has already been robbed recently.");
				return FAILED
			}
			if(get_pcvar_num(p_BankMinPlayers) > get_playersnum())
			{
				client_print(id,print_chat,"[RobMOD] There are not enough players to rob the bank.");
				return FAILED
			}
			if(Cops < get_pcvar_num(p_BankMinCops))
			{
				client_print(id,print_chat,"[RobMOD] There are not enough Police/SWAT/Army Officers to rob the bank.");
				return FAILED
			}
			
			g_BagEnts[0] = engfunc(EngFunc_FindEntityByString,-1,"targetname","money_bag_1");
			g_BagEnts[1] = engfunc(EngFunc_FindEntityByString,-1,"targetname","money_bag_2");
			if(!pev_valid(g_BagEnts[0]) || !pev_valid(g_BagEnts[1]))
				return FAILED
			
			if(!RobForward(id,CashSecond,CashMax,Targetname,Type))
				return FAILED
			
			fm_get_brush_entity_origin(g_BagEnts[0],g_RobOrigin[id]);
			
			g_WhosRobbing[MECK_BANK] = id
			g_LastRob[MECK_BANK] = Time
			
			new Array[2]
			Array[0] = id
			Array[1] = 0
			
			g_BankMoneyTaken = 0
			
			set_task(1.0,"BankRob",_,Array,2);
			
			set_hudmessage(255,0,255,-1.0,0.35,1,0.0,12.0,0.0,0.0,-1);
			switch(get_pcvar_num(p_ShowRobber))
			{
				case 0: {}
				case 1:
					show_hudmessage(0,"Attention ALL Police, SWAT and Army Units!^nSomeone is robbing the bank");
				case 2:
					show_hudmessage(0,"Attention ALL Police, SWAT and Army Units!^n%s is robbing the bank",Name)
			}
			client_print(id,print_chat,"[RobMOD] You are robbing the bank. Take the money bags to a safe distance away from the bank");
		}
		case OTHER:
		{
			if(Time - g_LastRob[OTHER] < get_pcvar_num(p_OtherRobWait) && g_LastRob[OTHER])
			{
				client_print(id,print_chat,"[RobMOD] This place has already been robbed recently.");
				return FAILED
			}
			if(get_pcvar_num(p_OtherMinPlayers) > get_playersnum())
			{
				client_print(id,print_chat,"[RobMOD] There are not enough players to rob this place.");
				return FAILED
			}
			if(Cops < get_pcvar_num(p_OtherMinCops))
			{
				client_print(id,print_chat,"[RobMOD] There are not enough Police/SWAT/Army Officers to rob this place.");
				return FAILED
			}
			
			if(!RobForward(id,CashSecond,CashMax,Targetname,Type))
				return FAILED
			
			g_WhosRobbing[OTHER] = id
			g_LastRob[OTHER] = Time
			
			switch(get_pcvar_num(p_ShowRobber))
			{
			}
			client_print(id,print_chat,"[RobMOD] Stay close to the cash register or the rob will be aborted");
		}
	}
	
	if(Type != MECK_BANK)
	{
		get_players(iPlayers,iNum,"a");
		for(new Count;Count < iNum;Count++)
			UTIL_RadiusMessage(id,iPlayers[Count],300.0,"* [RobMOD] %s opens and checks the cash register!",Name);
	}
	
	dllfunc(DLLFunc_Use,Ent,Ent);
	if(Extra[0])
	{
		new ExtraEnt = engfunc(EngFunc_FindEntityByString,-1,"targetname",Targetname);
		if(pev_valid(ExtraEnt))
			dllfunc(DLLFunc_Use,ExtraEnt,ExtraEnt);
	}
	
	fm_set_user_rendering(id,kRenderFxGlowShell,255,128,0,kRenderNormal,16.0);
	
	if(Type == MECK_BANK)
		return SUCCEEDED
	
	pev(id,pev_origin,g_RobOrigin[id]);
	
	new Array[5]
	Array[0] = id
	Array[1] = CashSecond
	Array[2] = CashMax
	Array[3] = 0
	Array[4] = Type
	
	g_RobInfo[id] = Array
	
	set_task(1.0,"AddCash",_,Array,5);
	
	return SUCCEEDED
}
public AddCash(Array[5])
{
	new id = Array[0]
	
	g_RobInfo[id] = Array
	
	new Float:Origin[3]
	pev(id,pev_origin,Origin);
	
	if(get_distance_f(g_RobOrigin[id],Origin) > 100.0)
	{
		client_print(id,print_chat,"[RobMOD] You have strayed too far from the register, run!")
		EndRob(id,"#name# is running away, catch him!");
		return
	}
	
//	Array[3] += Array[1]
	UTIL_SetUserMoney(id,WALLET,g_UserWallet[id]+Array[1]);
	
	if(Array[3] >= Array[2])
	{
		client_print(Array[0],print_chat,"[RobMOD] You have finished robbing, run!");
		EndRob(id,"#name# is running away, catch him!")
		return
	}
	set_task(1.0,"AddCash",_,Array,5);
}
#include <engine>
public BankRob(Array[2])
{
	new id = Array[0]
	if(g_WhosRobbing[MECK_BANK] != id)
		return
	
	new Ents[1],bool:InRange
	find_sphere_class(0,"func_pushable",500.0,Ents,1,g_RobOrigin[id]);
	if(Ents[0] == g_BagEnts[0] || Ents[0] == g_BagEnts[1])
		InRange = true
	else
		InRange = false
	
	new RobTime = get_pcvar_num(p_BankRobTime);
	if(Array[1] >= RobTime)
	{
		client_print(id,print_chat,"[RobMOD] You have ran out of time to rob the bank.");
		if(get_pcvar_num(p_ShowRobber) == 2)
			EndRob(id,"#name# who robbed the vault is hiding!^nFind him and eliminate him!");
		else
			EndRob(id,"Attention ALL Police^nThe robber who robbed the vault is hiding. Find Him.");
		return
	}
	
	Array[1] += 1
	
	set_hudmessage(150,25,125,-0.85,-0.85,0,0.0,8.0,0.0,0.0,4);
	show_hudmessage(0,"Timeleft: %ds^nDistance: %s",RobTime - Array[1],InRange ? "BAGS WITHIN RANGE" : "SAFE DISTANCE");
	
	/*
	new iPlayers[32],iNum
	get_players(iPlayers,iNum);
	for(new Count;Count<iNum;Count++)
		ClearHud(iPlayers[Count],HUD_TER);
	
	DRP_AddHudItem(-1,HUD_TER,0,"Timeleft: %ds^nDistance: %s",RobTime - Array[1],InRange ? "BAGS WITHIN RANGE" : "SAFE DISTANCE");
	*/
	
	set_task(1.0,"BankRob",_,Array,2);
}
public _DRP_EndRob(Plugin,Params)
{
	if(Params < 2)
	{
		format(g_Query,4095,"Parameters do not match. Expected: < 2, Found: %d",Params);
		return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,Plugin);
	}
	
	new id = get_param(1),Reason[128]
	get_string(2,Reason,127);
	
	if(!is_user_connected(id))
	{
		format(g_Query,4095,"User not connected: %d",id);
		return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,Plugin);
	}
	
	vdformat(Reason,127,2,3);
	return EndRob(id,Reason);
}
/*==================================================================================================================================================*/
public _DRP_GetUserAccess(Plugin,Params)
{
	if(Params != 1)
	{
		format(g_Query,4095,"Parameters do not match. Expected: 1, Found: %d",Params);
		return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,Plugin);
	}
	
	new id = get_param(1)
	if(is_user_connected(id))
		return g_UserAccess[id]
	else
	{
		format(g_Query,4095,"User not connected: %d",id);
		return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,Plugin);
	}
	
	return FAILED
}
public _DRP_SetUserAccess(Plugin,Params)
{
	if(Params != 2)
	{
		format(g_Query,4095,"Parameters do not match. Expected: 2, Found: %d",Params);
		return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,Plugin);
	}
	
	new id = get_param(1)
	
	if(is_user_connected(id))
	{
		new Access[27],nAccess = get_param(2);
		DRP_IntToAccess(nAccess,Access,26);
		
		g_UserAccess[id] = nAccess
		
		// Update the SQL
		new AuthID[36]
		get_user_authid(id,AuthID,35);
		format(g_Query,4095,"UPDATE %s SET Access='%s' WHERE SteamID='%s'",g_UserTable,Access,AuthID);
		SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",g_Query);
	}
	else
	{
		format(g_Query,4095,"User not connected: %d",id);
		return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,Plugin);
	}
	
	return FAILED
}
public _DRP_SetUserJobRights(Plugin,Params)
{
	if(Params != 2)
	{
		format(g_Query,4095,"Parameters do not match. Expected: 2, Found: %d",Params);
		return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,Plugin);
	}
	
	new id = get_param(1),Rights = get_param(2),Set
	for(new Count;Count < JOB_ACCESSES;Count++)
		if(Rights & (1<<Count))
			Set |= (1<<Count)
	
	if(is_user_connected(id))
		return g_UserJobAccess[id] = Set
	else
	{
		format(g_Query,4095,"User not connected: %d",id);
		return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,Plugin);
	}
		
	return FAILED
}
public _DRP_GetUserJobRights(Plugin,Params)
{
	if(Params != 1)
	{
		format(g_Query,4095,"Parameters do not match. Expected: 1, Found: %d",Params);
		return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,Plugin);
	}
	
	new id = get_param(1)
	if(is_user_connected(id))
		return g_UserJobAccess[id]
	else
	{
		format(g_Query,4095,"User not connected: %d",id);
		return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,Plugin);
	}
	
	return FAILED
}
public _DRP_RegisterItem(Plugin,Params)
{
	if(Params != 8)
	{
		format(g_Query,4095,"Parameters do not match. Expected: 6, Found: %d",Params);
		return UTIL_Error(1,0,g_Query,Plugin);
	}
	
	if(!g_ItemsRegistered)
		return UTIL_Error(AMX_ERR_NATIVE,0,"DRP_RegisterItem can only be run in the ^"DRP_RegisterItems^" forward.",Plugin);
		
	new Name[33],Handler[33],Description[64],ArrayPerm[5]
	get_string(1,Name,32);
	get_string(2,Handler,32);
	get_string(3,Description,63);
	get_array(8,ArrayPerm,4);
	
	new Len = strlen(Name);
	if(!Len)
	{
		format(g_Query,4095,"Name must have a length.",Params);
		return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,Plugin);
	}
	
	new CheckName[33]
	for(new Count = 1;Count <= g_ItemsNum;Count++)
	{
		array_get_string(array_get_int(g_ItemsArray,Count),1,CheckName,32)
		if(equali(Name,CheckName))
		{
			format(g_Query,4095,"Item collision detected, name: %s",Name);
			return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,Plugin);
		}
	}
	
	new ItemId = get_param(7);
	for(new Count;Count < g_ItemsNum;Count++)
	{
		if(get_param(7) == g_ItemIDs[Count])
		{
			format(g_Query,4095,"ItemID Collision Detected, Item Name: %s ItemID: %d",Name,ItemId);
			return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,Plugin);
		}
	}
			
	new Array = array_create();
	
	array_set_int(g_ItemsArray,++g_ItemsNum,Array);
	array_set_string(Array,1,Name);
	array_set_int(Array,2,Plugin);
	array_set_string(Array,3,Handler);
	array_set_string(Array,4,Description);
	array_set_int(Array,5,get_param(4) ? 1 : 0); // Use up?
	array_set_int(Array,6,get_param(5) ? 1 : 0); // Droppable?
	array_set_int(Array,7,get_param(6) ? 1 : 0); // Giveable?
	array_set_int(Array,8,ItemId); // ItemID (I added this because it's so much easier when saving)
	array_set_array(Array,9,ArrayPerm,4);
	
	
//	native DRP_RegisterItem(name[],handler[],description[],remove = 0,dropable = 1,giveable = 1,ItemID,Array[5]); 
	
	g_ItemIDs[g_ItemsNum] = ItemId
	
	return ItemId
}
public _DRP_GetUserItemNum(Plugin,Params)
{
	if(Params != 2)
	{
		format(g_Query,4095,"Parameters do not match. Expected: 2, Found: %d",Params);
		return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,Plugin);
	}
		
	new id = get_param(1),ItemId = get_param(2)
	
	if(!is_user_connected(id))
	{
		format(g_Query,4095,"User not connected: %d",id);
		return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,Plugin);
	}
	
	if(!UTIL_ValidItemID(ItemId))
	{
		format(g_Query,4095,"Invalid item id: %d",ItemId);
		return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,Plugin);
	}
	
	return UTIL_GetUserItemNum(id,ItemId);
}

public _DRP_SetUserItemNum(Plugin,Params)
{
	if(Params != 3)
	{
		format(g_Query,4095,"Parameters do not match. Expected: 3, Found: %d",Params);
		return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,Plugin);
	}
	
	new id = get_param(1),ItemId = get_param(2),ItemNum = get_param(3);
	
	if(ItemNum < 0)
	{
		format(g_Query,4095,"Invalid item number, must be more than 0. Num: %d",ItemNum);
		return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,Plugin);
	}
	
	
	if(!UTIL_ValidItemID(ItemId))
	{
		format(g_Query,4095,"Invalid item id: %d",ItemId);
		return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,Plugin);
	}
	
	
	return UTIL_SetUserItemNum(id,ItemId,ItemNum);
}
public _DRP_ForceUseItem(Plugin,Params)
{
	if(Params != 3)
	{
		format(g_Query,4095,"Parameters do not match. Expected: 3, Found: %d",Params);
		return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,Plugin);
	}
	
	new id = get_param(1),ItemId = get_param(2),UseUp = get_param(3)
	
	if(!is_user_connected(id))
	{
		format(g_Query,4095,"User not connected: %d",id)
		return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,Plugin)
	}
	
	if(UseUp && !UTIL_GetUserItemNum(id,ItemId))
	{
		format(g_Query,4095,"User %d has none of item: %d",id,ItemId)
		return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,Plugin)
	}
	if(g_UserItemUse[id] && UseUp)
		return FAILED
	
	if(UTIL_ValidItemID(ItemId))
		return ItemUse(id,ItemId,UseUp ? 1 : 0)
	
	format(g_Query,4095,"Invalid item id: %d",ItemId)
	return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,Plugin)
}
public _DRP_GetItemName(Plugin,Params)
{
	if(Params != 3)
	{
		format(g_Query,4095,"Parameters do not match. Expected: 3, Found: %d",Params);
		return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,Plugin);
	}
		
	new ItemId = get_param(1),Name[33]
		
	UTIL_GetItemName(ItemId,Name,32);
	
	if(!Name[0])
	{
		format(g_Query,4095,"Invalid ItemID: %d",ItemId);
		return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,Plugin);
	}
	
	set_string(2,Name,get_param(3));
	
	return SUCCEEDED
}
/*==================================================================================================================================================*/
public _DRP_AddProperty(Plugin,Params)
{
	if(Params != 8)
	{
		format(g_Query,4095,"Parameters do not match. Expected: 5, Found: %d",Params);
		return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,Plugin);
	}
	
	new InternalName[64],ExternalName[64],OwnerName[33],OwnerAuth[36],Price,Locked,Access,Profit
	get_string(1,InternalName,63)
	get_string(2,ExternalName,63)
	get_string(3,OwnerName,32)
	get_string(4,OwnerAuth,35)
	Price = get_param(5)
	Locked = get_param(6)
	Access = get_param(7)
	Profit = get_param(8)
	
	if(UTIL_GetProperty(InternalName))
	{
		format(g_Query,4095,"Property already exists: %s",InternalName);
		return UTIL_Error(AMX_ERR_NATIVE,0,g_Query,Plugin);
	}
	
	new Array = array_create()
	array_set_int(g_PropertyArray,g_PropertyNum++,Array)
	
	array_set_string(Array,0,InternalName)
	array_set_string(Array,1,ExternalName)
	array_set_string(Array,2,OwnerName)
	array_set_string(Array,3,OwnerAuth)
	array_set_int(Array,4,Price)
	array_set_int(Array,5,Locked)
	array_set_int(Array,6,Access)
	array_set_int(Array,7,Profit)
	array_set_int(Array,8,0)
	array_set_int(Array,9,1)
	
	format(g_Query,4095,"INSERT INTO %s VALUES ('%s','%s','%s','%s','%d','%d','%d','%d')",g_PropertyTable,InternalName,ExternalName,OwnerName,OwnerAuth,Price,Locked,Access,Profit);
	SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",g_Query);
	
	return g_PropertyNum
}
/*==================================================================================================================================================*/
// UTIL Functions
UTIL_Error(Error,Fatal,const Message[],Plugin)
{
	if(Plugin)
	{
		new Name[64],Filename[64],Temp[2]
		get_plugin(Plugin,Filename,63,Name,63,Temp,1,Temp,1,Temp,1);
		
		if(Error)
			log_error(Error,"[DRP] [PLUGIN: %s - %s ] %s",Name,Filename,Message);
		else
			log_amx("[DRP] [PLUGIN: %s - %s] %s",Name,Filename,Message);
	}
	else
	{
		if(Error)
			log_error(Error,Message);
		else
			log_amx("[DRP-CORE] [ERROR] %s",Message);
	}
		
	if(Fatal)
	{
		new Forward = CreateMultiForward("DRP_Error",ET_IGNORE,FP_STRING),Return
		if(Forward < 0 || !ExecuteForward(Forward,Return,Message))
			return SUCCEEDED
		
		DestroyForward(Forward);
		pause("d");
	}
	
	return FAILED
}

UTIL_ValidItemID(ItemID)
{
	for(new Count;Count < g_ItemsNum + 1;Count++)
		if(ItemID == g_ItemIDs[Count] && ItemID >= 0)
			return Count
	
	return FAILED
}
UTIL_ValidJobID(JobID)
{
	if(JobID < g_JobNum && JobID >= 0)
		return SUCCEEDED
	
	return FAILED
}

UTIL_GetUserItemNum(id,ItemID)
	return array_isfilled(g_UserItemArray[id],ItemID) ? abs(array_get_int(g_UserItemArray[id],ItemID)) : 0
	
UTIL_GetItemName(ItemID,Name[],Len)
{
	new Array = UTIL_ValidItemID(ItemID)
	if(!Array)
		return FAILED
	
	array_get_string(array_get_int(g_ItemsArray,Array),1,Name,Len);
	
	return SUCCEEDED
}

UTIL_SetUserItemNum(id,ItemID,Num)
{
	if(!UTIL_ValidItemID(ItemID))
		return FAILED
	
	Num ? array_set_int(g_UserItemArray[id],ItemID,Num) : array_delete(g_UserItemArray[id],ItemID);
	
	return SUCCEEDED
	
	static AuthID[36],Query[256],Query2[256]
	get_user_authid(id,AuthID,35);
	
	new ItemIDNum = UTIL_GetUserItemNum(id,ItemID);
	
	// Grab there current items, and build the string.
	new ItemNum,Success,ItemQuery
	while(ItemNum < g_ItemsNum && (ItemQuery = array_get_nth(g_UserItemArray[id],++ItemNum,_,Success)) != 0)
	{
		if(UTIL_GetUserItemNum(id,ItemQuery) == 0)
		{
			format(Query,255," %d|%d",ItemQuery,(ItemIDNum + 1))
			add(Query2,255,Query);
		}
		else
		{
			if(ItemIDNum > 0)
			{
			}
			else
				debugg("FAILED")
		}
	}

	debugg("Item Query: %s",Query2);
	
	/*
	static Query[256],AuthID[36]
	get_user_authid(id,AuthID,35);
	
	new ItemNum,Success,ItemQuery
	while(ItemNum < g_ItemsNum && (ItemQuery = array_get_nth(g_UserItemArray[id],++ItemNum,_,Success)) != 0)
	{
		format(g_Query,4095,"%d|%d|",ItemQuery,UTIL_GetUserItemNum(id,ItemQuery))
		add(Query,255,g_Query);
	}
	format(g_Query,4095,"UPDATE %s SET Items='%s' WHERE SteamID='%s'",g_UserTable,Query,AuthID);
	SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",g_Query);
	*/
}

/*
stock set_item_amount(id,func[],itemid,amount,table[],customid[]="")
{
	new authid[32], query[256], itemfield[MAXIUMSTR]
	if(equali(customid,"")) get_user_authid(id,authid,31)
	else format(authid,31,customid)
	new currentamount = get_item_amount(id,itemid,table,customid)
	format(query,255,"SELECT items FROM %s WHERE steamid='%s'",table,authid)
	result = dbi_query(dbc,query)
	if(dbi_nextrow(result) > 0)
	{
		dbi_field(result,1,itemfield,MAXIUMSTR-1)
		dbi_free_result(result)

		if(equali(func,"-"))
		{
			new string[32]
			format(string,31," %i|%i",itemid,currentamount)
			if(containi(itemfield,string) != -1)
			{
				if((currentamount - amount) <= 0)
				{
					replace(itemfield,MAXIUMSTR-1,string,"")
				}
				else
				{
					new newstring[32]
					format(newstring,31," %i|%i",itemid,currentamount-amount)
					replace(itemfield,MAXIUMSTR-1,string,newstring)
				}
				format(query,255,"UPDATE %s SET items='%s' WHERE steamid='%s'",table,itemfield,authid)
				dbi_query(dbc,query)
			}
			else
			{
				client_print(id,print_chat,"[ItemMod] Error #150 LOOP. Please contact an administrator^n")
				dbi_free_result(result)
				return PLUGIN_HANDLED
			}
		}
		if(equali(func,"+"))
		{
			if(get_item_amount(id,itemid,table,authid) == 0)
			{
				new str[32]
				format(str,31," %i|%i",itemid,(currentamount +amount))
				add(itemfield,sizeof(itemfield),str)
				format(query,MAXIUMSTR-1,"UPDATE %s SET items='%s' WHERE steamid='%s'",table,itemfield,authid)
				dbi_query(dbc,query)
			}
			else
			{
				if(currentamount > 0)
				{
					new newstr[32], oldstr[32]
					format(oldstr,31," %i|%i",itemid,currentamount)
					format(newstr,31," %i|%i",itemid,(currentamount +amount))
					replace(itemfield,255,oldstr,newstr)
					format(query,MAXIUMSTR-1,"UPDATE %s SET items='%s' WHERE steamid='%s'",table,itemfield,authid)
					dbi_query(dbc,query)
				}
				else
				{
					client_print(id,print_chat,"[ItemMod] Error #200. Please contact an administrator^n")
					dbi_free_result(result)
					return PLUGIN_HANDLED
				}
			}
		}
	}
	dbi_free_result(result)
	return PLUGIN_HANDLED
}
*/
UTIL_FindItemID(const ItemName[])
{
	static Name[36]
	for(new Count = 1;Count <= g_ItemsNum;Count++)
	{
		array_get_string(array_get_int(g_ItemsArray,Count),1,Name,35)
		if(equali(Name,ItemName)
			return Count
	}
	return -1
}

UTIL_GetProperty(const Targetname[] = "")
{
	static PropertyTargetName[36]
	for(new Count;Count < g_PropertyNum;Count++)
	{
		if(array_isfilled(array_get_int(g_PropertyArray,Count),0))
			array_get_string(array_get_int(g_PropertyArray,Count),0,PropertyTargetName,35);
		
		if(equali(Targetname,PropertyTargetName) && Targetname[0])
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
			else if(equal(Left,"DRP_UserTable"))
				copy(g_UserTable,sizeof g_UserTable-1,Right);
			else if(equal(Left,"DRP_JobsTable"))
				copy(g_JobsTable,sizeof g_JobsTable-1,Right);
			else if(equal(Left,"DRP_PropertyTable"))
				copy(g_PropertyTable,sizeof g_PropertyTable-1,Right);
			else if(equal(Left,"DRP_EconomyTable"))
				copy(g_EconomyTable,sizeof g_EconomyTable - 1,Right);
			else if(equal(Left,"DRP_NPCTaxRate"))
				g_EconomyNPCTax = str_to_num(Right);
			else if(equal(Left,"DRP_PropertyTaxRate"))
				g_EconomyPropertyTax = str_to_num(Right);
			else if(equal(Left,"DRP_DeathScreen"))
			{
				if(str_to_num(Right) == 1)
					g_DeathScreen = true
				else
					g_DeathScreen = false
			}
		}
	}
	fclose(File);
}

UTIL_SetUserMoney(id,from,amount)
{
	new AuthID[36]
	get_user_authid(id,AuthID,35);
	if(from == WALLET) {
		g_UserWallet[id] = amount
		format(g_Query,4095,"UPDATE %s SET WalletMoney=%i WHERE SteamID='%s'",g_UserTable,amount,AuthID);
	}
	else if(from == BANK) {
		g_UserBank[id] = amount
		format(g_Query,4095,"UPDATE %s SET BankMoney=%i WHERE SteamID='%s'",g_UserTable,amount,AuthID);
	}
	SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",g_Query);
}
UTIL_SetUserHunger(id,Amount)
{
	new AuthID[36]
	get_user_authid(id,AuthID,35);
	
	g_UserHunger[id] = Amount
	
	format(g_Query,4095,"UPDATE %s SET Hunger=%i WHERE SteamID='%s'",g_UserTable,g_UserHunger[id],AuthID);
	SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",g_Query);
}
// Set's the users JobID
// And Updates the SQL with the JobName
UTIL_SetUserJobID(id,JobID)
{
	new AuthID[36],JobName[33],JobAccess[JOB_ACCESSES + 1]
	get_user_authid(id,AuthID,35);
	
	g_UserJobID[id] = JobID
	g_UserSalary[id] = array_get_int(array_get_int(g_JobArray,JobID),2);
	g_UserJobAccess[id] |= array_get_int(array_get_int(g_JobArray,JobID),3);
	
	array_get_string(array_get_int(g_JobArray,JobID),1,JobName,32);
	DRP_IntToAccess(g_UserJobAccess[id],JobAccess,JOB_ACCESSES);
	
	format(g_Query,4095,"UPDATE %s SET JobName='%s',JobAccess='%s' WHERE SteamID='%s'",g_UserTable,JobName,JobAccess,AuthID);
	SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",g_Query);
}
UTIL_RandomPlayer()
{
	new iPlayers[32],iNum
	get_players(iPlayers,iNum,"a");
	
	return iPlayers[random(iNum)]
}
// Thanks to the harbu code for this, was too lazy to rewrite it
// And Thanks to Hawk
UTIL_RadiusMessage(sender,reciever,Float:Dist,const Msg[],any:...)
{
	static Message[128]
	vformat(Message,127,Msg,5);
	
	new Float:SndOrigin[3],Float:RcvOrigin[3]
	pev(reciever,pev_origin,RcvOrigin);
	pev(sender,pev_origin,SndOrigin);
	
	if(get_distance_f(RcvOrigin,SndOrigin) <= Dist)
		client_print(reciever,print_chat,"%s",Message);
}
UTIL_HUD_ClientPrint(id,Message[],any:...)
{
	static Msg[256]
	vformat(Msg,sizeof Msg - 1,Message,3);
	
	ClearHud(id,HUD_SEC);
	UTIL_AddHudItem(id,HUD_SEC,Msg,1);
}
UTIL_AddHudItem(id,Channel,Message[],Refresh)
{
	// All players
	if(id == -1)
	{
		new iPlayers[32],iNum
		get_players(iPlayers,iNum);
		for(new Count;Count<iNum;Count++)
			AddItem(iPlayers[Count],Channel,Message,Refresh);
	}
	else
		AddItem(id,Channel,Message,Refresh);
}

AddItem(id,Channel,Message[],Refresh)
{
	new Array = array_create();
	array_set_int(g_HudArray[id][Channel],g_HudNum[id][Channel]++,Array);
	
	array_set_string(Array,0,Message);
	
	if(Refresh)
		RenderHud(id,Channel);
}

public IgnoreHandle(FailState,Handle:Query,Error[],Errcode,Data[],DataSize) 
{
	if(FailState == TQUERY_CONNECT_FAILED)
	{
		format(g_Query,4095,"Could not connect to SQL database.");
		return UTIL_Error(0,0,g_Query,0);
	}
	else if(FailState == TQUERY_QUERY_FAILED)
	{
		SQL_GetQueryString(Query,g_Query,4095);
		log_amx("[DRP CORE] ERROR ON Query: %s",g_Query);
		
		SQL_QueryError(Query,g_Query,4095);
		return UTIL_Error(0,0,g_Query,0);
	}
	
	if(Errcode)
	{
		format(g_Query,4095,"[DRP Core] Error on query: %s",Error);
		return UTIL_Error(1,0,g_Query,0);
	}	
	
	return PLUGIN_CONTINUE
}
/*==================================================================================================================================================*/
public plugin_end()
{
	TEST_LOG("Plugin End");
	
	SaveData();
	
	array_destroy(g_ItemsArray);

	new iPlayers[32],iNum,id
	get_players(iPlayers,iNum);
	for(new Count,Count2,Count3,Array;Count<iNum;Count++)
	{
		id = iPlayers[Count]
		for(Count2 = 0;Count2 < HUD_NUM;Count2++)
			ClearHud(id,Count2);
		
		for(Count3 = 0;Count3 < g_HudNum[id][Count2];Count3++)
		{
				Array = array_get_int(g_HudArray[id][Count2],Count3);
				array_destroy(Array);
		}
	}
	
	for(new Count,Count2;Count < 33;Count++)	
	{
		array_destroy(g_UserItemArray[Count]);
		for(Count2 = 0;Count2 < HUD_NUM;Count2++)
			array_destroy(g_HudArray[Count][Count2]);
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
		Num = array_get_int(g_PropertyArray,Count)
		array_destroy(Num)
	}
	
	// Arrays
	array_destroy(g_JobArray);
	array_destroy(g_CommandArray);
	array_destroy(g_PropertyArray);
	
	// Forwards
	DestroyForward(g_HudForward);
	DestroyForward(g_SalaryForward);
	DestroyForward(g_RobForward);
	DestroyForward(g_RobEndForward);
	
	// SQL
	SQL_FreeHandle(g_SqlHandle);
}

// Thanks to Xeroblood / BAILOPAN
stock ExplodeString( p_szOutput[][], p_iMax, const p_szInput[], p_iSize, p_szDelimiter )
{
	new iIdx = 0, l = strlen(p_szInput);
	new iLen = (1 + copyc( p_szOutput[iIdx], p_iSize, p_szInput, p_szDelimiter ))
	while( (iLen < l) && (++iIdx < p_iMax) )
		iLen += (1 + copyc( p_szOutput[iIdx], p_iSize, p_szInput[iLen], p_szDelimiter ))
	return iIdx
}

// Copied from fakemeta_util.inc
stock fm_set_user_rendering(entity, fx = kRenderFxNone, r = 255, g = 255, b = 255, render = kRenderNormal, Float:amount = 16.0) 
{
	new Float:RenderColor[3]
	RenderColor[0] = float(r)
	RenderColor[1] = float(g)
	RenderColor[2] = float(b)

	set_pev(entity, pev_renderfx, fx)
	set_pev(entity, pev_rendercolor, RenderColor)
	set_pev(entity, pev_rendermode, render)
	set_pev(entity, pev_renderamt, amount);

	return 1
}
// Copied from fakemeta_util.inc
stock fm_get_brush_entity_origin(index, Float:origin[3]) 
{
	new Float:mins[3], Float:maxs[3]
	pev(index, pev_mins, mins)
	pev(index, pev_maxs, maxs)

	origin[0] = (mins[0] + maxs[0]) * 0.5
	origin[1] = (mins[1] + maxs[1]) * 0.5
	origin[2] = (mins[2] + maxs[2]) * 0.5

	return 1
}