#if defined _DRP_CORE_INCLUDE
	#endinput
#endif

#define _DRP_CORE_INCLUDE

#include <drp/drp_const>
#include <drp/drp_sql>
#include <drp/drp_const>
#include <drp/drp_items>
#include <drp/drp_jobs>
#include <drp/drp_property>

#pragma reqlib "drp_core"

/**
 * Throws an error, to be logged
 *
 * @param fatal     is fatal, if true the core will shutdown, and the server will need a restart
 * @param error     error message to be logged
 * @param ...       Variable number of formatting parameters
 *
 * @noreturn
 *
 */
native DRP_ThrowError(bool:fatal, const error[], any:...);

/**
 * Logs to the current (non-error) log file
 *
 * @param msg    	Message to be logged
 * @param ...       Variable number of formatting parameters
 *
 * @noreturn
 *
 */
native DRP_Log(const msg[], any:...);

/**
 * Gets the current config directory
 *
 * @param output	buffer to copy the config directory
 * @param len     	maximum buffer size
 *
 * @noreturn
 *
 */
native DRP_GetConfigsDir(output[], len);

/**
 * Displays an MOTD window to a client, with the specfied help file
 * Located in <configdir>/drp/motd
 *
 * @param id		Client index
 * @param fileName	File name of the MOTD help file
 *
 * @noreturn
 *
 */
native DRP_ShowMOTDHelp(id, const fileName[]);

/**
 * Returns the world clock time, in a formatted string
 *
 * @param buffer		Buffer for the world time string
 * @param len     		Maximum buffer size
 * @param format		The type of string to be copied to the buffer
 *							TIME_WORLD 		- HOUR:MINUTE AM/PM (MONTH/DAY/YEAR)
 *							TIME_MINUTES 	- MINUTES
 *							TIME_HOURS 		- HOURS
 *
 * @noreturn
 *
 */
native DRP_GetWorldTime(buffer[], len, TIME:format = TIME_WORLD);

/**
 * The Specialist Mod Only!!
 *
 * @param id		Client index
 * @param clip
 * @param ammo
 * @param mode
 * @param extra
 *
 * @return			WeaponID that the client currently is equipped with (TSW_*)
 * @error			If the mod/game is anything but TS, will report an error.
 *
 */
native DRP_TSGetUserWeaponID(id, &clip=0, &ammo=0, &mode=0, &extra=0);

/**
 * The Specialist Mod Only!!
 *
 * @param id		Client index
 * @param wpnId		Weapon ID (TSW_*) of the weapon, which the ammo will be set for
 * @param ammo		Amount of ammo to be given
 *
 * @noreturn
 * @error			If the mod/game is anything but TS, will report an error.
 *
 */
native DRP_TSSetUserAmmo(id, wpnId, ammo);

/**
 * The Specialist Mod Only!!
 *
 * @param id		Client index
 * @param clip
 * @param ammo
 * @param mode
 * @param extra
 *
 * @return			WeaponID that the client currently is equipped with (TSW_*)
 * @error			If the mod/game is anything but TS, will report an error.
 *
 */
native DRP_TSGiveUserWeapon(id, wpnId, extraClip, flags=0);

/**
 * Sets a users maximum speed, you can control the mode at which this speed is applied
 *
 * @param id		Client index
 * @param mode     	Mode at which to control the speed (SPEED_*)
 *						SPEED_NONE -
 *						SPEED_OVERRIDE -
 *						SPEED_MUL -
 * @param value		?
 *
 * @noreturn
 *
 */
native DRP_SetUserMaxSpeed(id, SPEED:mode, Float:value = 0.0);


/**
 * Checks if the user can submit another command
 * Used to avoid spam
 *
 * @param id		Client index
 * @param cooldown	How many seconds between the last command and this one
 *
 * @return			SUCCEEDED/FAILED
 *
 */
native DRP_CheckCmdTime(id, Float:cooldown = 1.5);

/**
 * Creates and spawns a "money bag"
 * This entity can be pickedup/used by other players
 *
 * @param amount	Amount of cash to be included in the bag
 * @param origin	Origin for the entity
 * @param id		Client index of the player this money bag is attached too (optional)
 *
 * @return			EntID (or 0 if failed) of the dropped entity
 *
 */
native DRP_CreateMoneyBag(amount, Float:origin[3], id=0)

/**
 * Gets the players current wallet funds
 *
 * @param id	Client index
 *
 * @return		Amount of money located in the players wallet
 *
 */
native DRP_GetUserWallet(id);

/**
 * Gets the players current bank funds
 *
 * @param id	Client index
 *
 * @return		Amount of money located in the players bank
 *
 */
native DRP_GetUserBank(id);

/**
 * Sets the players current bank funds
 *
 * @param id	Client index
 *
 * @noreturn
 *
 */
native DRP_SetUserBank(id, amount);

/**
 * Sets the players current wallet funds
 *
 * @param id	Client index
 *
 * @noreturn
 *
 */
native DRP_SetUserWallet(id, amount);

/**
 * Returns if the player is loaded and ready
 *
 * @param id	Client index
 *
 * @return		SUCCEEDED/FAILED
 *
 */
native bool:DRP_PlayerReady(id);

/**
 * Returns the total amount of time (in minutes) the player has on the server
 *
 * @param id	Client index
 *
 * @return		Time (in minutes) of the total server playtime
 *
 */
native DRP_GetUserTime(id);

/**
 * Returns the amount of time left before all users are paid
 * This value is based on the world timer, and can be altered.
 *
 *
 * @return		Time left before everyone is paid
 *
 */
native DRP_GetPayDay();


/**
 * Adds (but does not register) a drp specific command
 * To register, use DRP_RegisterCmd()
 *
 * @param command
 * @param description
 *
 * @noreturn
 *
 */
native DRP_AddCommand(const command[], const description[]);

/**
 * Adds a message to the users hud. Must be added in DRP_HudDisplay event only
 *
 * @param id		Client index (0 for everyone)
 * @param channel	HUD Channel (HUD_*)
 * @param display	String to be displayed
 * @param ...		Variable number of formatting parameters
 *
 * @noreturn
 *
 */
native DRP_AddHudItem(id, channel, const display[], any:...);

/**
 * Forces a users hud to be updated immediately
 * The hud doesn't always update every second, this will force a refresh
 *
 * @param id	Client index
 * @param hud	Hud channel to be refreshed
 *
 * @noreturn
 *
 */
native DRP_ForceHUDUpdate(id, hud);

/**
 * Adds a menu item to a clients menu. Must be added in Menu_Display event only
 *
 * @param id		Client index (0 for everyone)
 * @param menuItem	Menu item text entry
 * @param callback	Function to be called when the menu item is selected
 *
 * @noreturn
 *
 */
native DRP_AddMenuItem(id, const menuItem[], const callback[]);

/**
 * Returns if the user has the passed access key
 *
 * @param id		Client index (0 for everyone)
 * @param key		The access string to check
 *
 * @return			SUCCEEDED/FAILED
 *
 */
native DRP_GetUserAccess(id, const key[]);

/**
 * Returns if the user has the passed access key
 *
 * @param id		Client index (0 for everyone)
 * @param key		The access string to check
 *
 * @return			SUCCEEDED/FAILED
 *
 */
native DRP_RegToolTip(const Name[],const FileName[]);
native DRP_ShowToolTip(id,const Name[],Force=0);

/**
 * Calls an interceptable forward throughout all of DRP
 *
 * @param name		Event name
 * @param data		Buffer of data to be sent through the forward
 * @param len		Maximum buffer size
 *
 * @return 			EVENT_CONTINUE	- 	Continue operation
 *					EVENT_HALT		- 	A hook is requesting this operation to be stopped
 *
 */
native DRP_DoEvent(const name[], data[], len);

/**
 * Hooks an event to a fucntion
 *
 * @param name			Event name
 * @param callback		Function to be called when an event is raised
 *							my_callback(const data[], len)
 *
 * @noreturn
 *
 */
native DRP_RegisterEvent(const name[], const callback[]);

/**
 * Sets a key/value pair on a client
 * This data is plugin specific. Other plugins CANNOT access the same key
 * If the name of the plugin changes, the data will not available anymore.
 *
 * @param id		Client index
 * @param key		Key
 * @param value		String value to be saved
 *
 * @noreturn
 *
 */
native DRP_SetUserData(id, const key[], const value[]);

/**
 * Loads all the data for the calling plugin on a player
 * Best to be called in the "Player_Ready" event
 * 
 * @param id		Client index
 * @param callback	Fucntion to call when the data is loaded
 *						my_callback(id)
 *
 * @noreturn
 *
 */
 
native DRP_LoadUserData(id, const callback[] = "");

/**
 * Returns a saved string value, based on a key
 * The data must of been set with the calling plugin, be sure to also load
 * the clients data ebfore attempting to access it
 *
 * @param id		Client index
 * @param key		Key
 * @param value		Output buffer for the returned data
 * @param len		Maximum buffer size
 *
 * @noreturn
 *
 */
native DRP_GetUserData(id, const key[], output[], len);

stock DRP_GetUserDataInt(id, const Key[])
{
	new Data[256];
	DRP_GetUserData(id, Key, Data, 255);
	
	return str_to_num( Data );
}
stock DRP_SetUserDataInt(id, const Key[], Value)
{
	new Data[8]
	num_to_str(Value, Data, 7);
	
	DRP_SetUserData(id, Key, Data);
	return SUCCEEDED
}

/**
 * Called when the core has finished the SQL queries, and after the config file is loaded
 * 
 * @note	The config file is loaded again AFTER DRP_Init() is called
 * 			you should create any cvars here, because of this.	
 * 
 * @noreturn
 */
 
forward DRP_Init();

/**
 * Called when a fatal error has occured (and the server will need a restart)
 * 
 * @note	Cleanup/Save any data here, the server is assumed to be shutdown/restarted
 *
 * @noreturn
 */
forward DRP_Error(const Reason[]);

/**
 * Called everytime the HUD message(s) are updated
 *
 * @note	Add any HUD items here
 *
 * @noreturn
 */
forward DRP_HudDisplay(id, Hud);

/**
 * Called everytime an event is raised
 *
 * @note	You can return "FAILED" 
 *
 * @noreturn
 */
forward DRP_Event(const Name[],Data[],Len);

/*==================================================================================================================================================*/
// Stock Functions
stock DRP_RegisterCmd(const Command[],const Handler[],const Description[])
{
	DRP_AddCommand(Command,Description);
	register_clcmd(Command,Handler,_,Description);
}
stock DRP_LoadConfigFile()
{
	new ConfigFile[128]
	get_localinfo("amxx_configsdir",ConfigFile,127);
	format(ConfigFile,127,"%s/DRP/DRPCore.cfg",ConfigFile);
	
	server_cmd("exec %s",ConfigFile);
	server_exec();
}
// This is simply for DRP Admins
// Nothing more.
stock DRP_CmdAccess(id,cid,num)
{
	new bool:HasAccess = false
	if(id == (is_dedicated_server() ? 0 : 1) )
		HasAccess = true
	else if(DRP_IsAdmin(id))
		HasAccess = true
	
	if(!HasAccess) {
		console_print(id,"%L",id,"NO_ACC_COM");
		return 0
	}
	if(read_argc() < num) {
		new hcmd[64], hinfo[256], hflag
		get_concmd(cid,hcmd,63,hflag,hinfo,255,0)
		console_print(id,"%L:  %s %s",id,"USAGE",hcmd,hinfo)
		return 0
	}
	return 1
}

// emit_sound(); you must use a prechached file
// with this - it plays the sound to all the players within "id"'s radius - without a precached sound
// the only downside is you can't control the volume, or have sound DSP effects
stock DRP_EmitSound(id,const File[],Radius)
{
	if(!is_user_alive(id))
		return FAILED
	
	new iPlayers[32],iNum
	get_players(iPlayers,iNum);
	
	new Origin[3],tOrigin[3]
	get_user_origin(id,Origin); // don't use engine/fakemeta
	
	for(new Count;Count < iNum;Count++)
	{
		Player = iPlayers[Count]
		
		if(!is_user_alive(Player))
			continue
		
		get_user_origin(Player,tOrigin);
		
		if(get_distance(Origin,tOrigin) <= Radius)
			client_cmd(Player,"spk ^"%s^"",File);
	}
	return SUCCEEDED
}

stock ExplodeString2(p_szOutput[][],p_iMax,const p_szInput[],p_iSize,p_szDelimiter)
{
	new iIdx = 0, l = strlen(p_szInput);
	new iLen = (1 + copyc( p_szOutput[iIdx], p_iSize, p_szInput, p_szDelimiter ))
	
	while( (iLen < l) && (++iIdx < p_iMax) )
		iLen += (1 + copyc( p_szOutput[iIdx], p_iSize, p_szInput[iLen], p_szDelimiter ))
	
	return iIdx
}

stock ExplodeString( Output[][], Max, Size, Input[], Delimiter )
{
    new Idx, l = strlen(Input), Len;
    do Len += (1 + copyc( Output[Idx], Size, Input[Len], Delimiter ));
    while( (Len < l) && (++Idx < Max) )
    return Idx;
}

// I use this mainly for dev commands
// or some type of testing command
stock IsUserDrak(id)
{
	new AuthID[36]
	get_user_authid(id,AuthID,35);
	
	return equali(AuthID,"STEAM_0:0:5932780") ? SUCCEEDED : FAILED
}

// Attempts to get the name from the SQL Database
// Useful when wanting to know a person's name, who's not online
stock DRP_GetUserName(const SteamID[],Name[],Len)
{
	if(!SteamID[0])
		return FAILED
	
	new Error,Temp[1]
	new Handle:Connect = SQL_Connect(DRP_SqlHandle(),Error,Temp,1);
	
	if(Connect == Empty_Handle)
		return FAILED
	
	new Handle:Query = SQL_PrepareQuery(Connect,"SELECT `PlayerName` FROM `Users` WHERE `SteamID`='%s'",SteamID);
	
	if(!SQL_Execute(Query) || Query == Empty_Handle)
	{
		SQL_FreeHandle(Connect);
		SQL_FreeHandle(Query);
		return FAILED
	}
	
	SQL_ReadResult(Query,0,Name,Len);
	
	SQL_FreeHandle(Connect);
	SQL_FreeHandle(Query);
	
	return Name[0] ? SUCCEEDED : FAILED
}

stock DRP_GetCopAccess()
{
	new Pointer = get_cvar_pointer(g_CopAccessCvar);
	if(Pointer)
	{
		new AccessFlags[JOB_ACCESSES + 1]
		get_pcvar_string(Pointer,AccessFlags,JOB_ACCESSES);
		
		return (read_flags(AccessFlags));
	}
	return FAILED
}

// This returns true if the player is inside a menu
// I *think* this only works for VGUI / Menus created with "menu_create()" (the new natives)
stock DRP_IsPlayerInMenu(id)
{
	new Menu,NewMenu,Temp,InMenu = player_menu_info(id,Menu,NewMenu,Temp);
	return InMenu
}

stock UTIL_RadiusMessage(Sender,Float:Dist,const Message[],any:...)
{
	new Float:SndOrigin[3],Float:RcvOrigin[3]
	pev(Sender,pev_origin,SndOrigin);
	
	new MessageV[128]
	vformat(MessageV,127,Message,4);
	
	new iPlayers[32],iNum,id
	get_players(iPlayers,iNum);
	for(new Count;Count<iNum;Count++)
	{
		id = iPlayers[Count]
		
		if(!is_user_alive(id))
			continue
		
		pev(id,pev_origin,RcvOrigin);
		
		if(get_distance_f(RcvOrigin,SndOrigin) <= Dist)
			client_print(id,print_chat,"%s",MessageV);
	}
}