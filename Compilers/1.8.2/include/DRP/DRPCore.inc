/*
* DRPCore.inc
* -------------------------------------
* Author(s):
* Drak
* Hawk - His 'DPRP' plugin helped a lot.
	Many of the functions are based from DPRP.
* 	Hell, it's basiclly a giant modification of it anyways.
* Harbu - His RP plugins
* -------------------------------------
*/


#if defined _DRP_INCLUDE
	#endinput
#endif
#define _DRP_INCLUDE

#if !defined chance
	#define chance(%1) ( %1 > random(100) ) // %1 = probability 

#include <DRP/DRPSQL>
#include <DRP/DRPConst>
#include <DRP/DRPUtil>
#include <DRP/DRPItems>
#include <DRP/DRPJobs>
#include <DRP/DRPData>
#include <DRP/DRPProperties>

#if AMXX_VERSION_NUM < 180
	#endinput
#endif

#pragma reqlib "DRPCore"

// HACKHACK
#define DRP_AccessToInt(%1) \
	read_flags(%1)
	
#define DEFAULT_PASS "-1"
#define DEFAULT_SET_PASS "-2"

// * Natives

// Throws an error at the core
// error - the error type (refer to amxconst.inc)
// fatal - whether or not this should shut the core down
// reason[] - reason for error
native DRP_ThrowError(Fatal,const Message[],any:...);

// Logs into the DRP Log Folder (located in <logsdir>/drp/)
// AdminLog - logs into a file tagged with "[ADMIN MESSAGE]" used for admin chat messages.
native DRP_Log(const Message[],any:...);

// Returns the map config dir (ex: <configsdir>/drp/mecklenburg/)
native DRP_GetConfigsDir(ConfigDir[],Len);

// id - index of player
// file[] - file (located in <configdir>/drp/motd/)
native DRP_ShowMOTDHelp(id,const File[]);

// Speed
native DRP_SetUserSpeed(id,Speed:mode,Float:value = 0.0);
native Float:DRP_GetUserSpeed(id,Speed:mode);

// MODES
// 1 = H:M AM/PM (M/D/Y)
// 2 = Hour only
// 3 = Minute Only
native DRP_GetWorldTime(String[],Len,Mode=1);

// Returns there current WeaponID (in there hands)
// This is an un-tested native, but has been added to replace,
// the tsxaddon module
native DRP_TSGetUserWeaponID(id,&Clip=0,&Ammo=0,&Mode=0,&Extra=0);
// This is an un-tested native, but has been added to replace,
// the tsxaddon module
native DRP_TSSetUserAmmo(id,WeaponID,Ammo);
// This is an un-tested native, but has been added to replace,
// the tsxaddon module
native DRP_TSGiveUserWeapon(id,WeaponID,ExtraClip,Spawnflags=0);

/*
// Returns Pointer to Message
// Use the pointer & "DRP_REMOVEUSERCMSG" to remove/clear the message
native DRP_AddUserCMsg(id,const Message[],any:...);

// Message[] - The message to remove, this uses CONTAINI
// So if you have two messages "Is really drunk" - "Is Drunk" and remove "Drunk" it would
// remove both lines
native DRP_RemoveUserCMsg(id,Msg);
*/

// Returns if g_Display[id] = 1/0
// This is when the hud/print messages are sent when looking at property/npc
native DRP_UserDisplay(id);

// There's a 1.5 second delay between console commands
// Use this native to check if they waited that 1.5 seconds
native DRP_CheckCmdTime(id,Float:CoolDown = 1.5);

// * Money

// amount - amount of cash to drop
// origin - origin of the cash entity
native DRP_DropCash(Amount,Float:Origin[3],id=0)

// Returns the users cash (in there wallet)
native DRP_GetUserWallet(id);

// Returns the users cash (in there bank)
native DRP_GetUserBank(id);

native DRP_GetPlayerInfo(id,PLY:From);
native DRP_PlayerReady(id);

// Tips
native DRP_RegToolTip(const Name[],const FileName[]);
native DRP_ShowToolTip(id,const Name[],Force=0);

// Returns the total time (in minutes) the user has played
// on the server
native DRP_GetUserTime(id);

native DRP_SetUserBank(id,amount);
native DRP_SetUserWallet(id,amount);

// Returns the amount of time the players get payed.
// this is the same time for all players
// - unless there is any event that can stop it
native DRP_GetPayDay();

// * Hunger

// Returns the percent level of the user's hunger.
native DRP_GetUserHunger(id);

// max hunger amount = 120
native DRP_SetUserHunger(id,Amount);

// This isn't important - player's can choose not to set a password
// Returns -1 on no password set (DEFAULT_PASS)
native DRP_GetUserPass(id,const Password[],Len);
native DRP_SetUserPass(id,const Password[]);

// Commmands
// Adds a command to the list, aids in user interfacing
// command[] - command to register, i.e. "say /users"
// description[] - the description, i.e. "Shows user list"
native DRP_AddCommand(const Command[],const Description[]);
native DRP_AddHudItem(id,Channel,const Message[],any:...);

// This forces a HUD Channel to update/refresh.
// Usefull when needing to show information quickly.
native DRP_ForceHUDUpdate(id,Hud);

// Adds a menu item to the master menu
// NOTE: Only call this during the "Menu_Display" event
// id - player to add the menu to
// const name[] - name of the menu item
// const handler[] - function to call when the key is pressed
native DRP_AddMenuItem(id,const Name[],const Handler[]);

// Access System
native DRP_GetUserAccess(id);
native DRP_SetUserAccess(id,Access,Add=0);

// Calls an interceptable forward throughout all of DRP
// const name[] - name of the forward
// data[] - data to pass
// len - length of data array
native DRP_CallEvent(const Name[],Data[],Len);

// Registers an event
// const name[] - name of the event
// const handler[] - the function to call when the event is called
native DRP_RegisterEvent(const Name[],const Handler[]);

// * Forwards

// Called when the SQL Function is loaded (In the core)
// This is also called after the config files have been loaded
forward DRP_Init();

// Called when a "fatal" error is called.
forward DRP_Error(const Reason[]);

// Called every 1.0 second. When the HUD Updates
// Add hud items in this function only
forward DRP_HudDisplay(id,Hud);

// called whenever an event happens
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
// Converts a string, i.e. "abc" to a number (in this case, "a" = 1, 
// "b" = 2, "c" = 4, so 7 in total).
// Returns the number.
// I think this is the same thing as "read_flags"
stock DRP_AccessToInt2(const string[])
{
	new Access
	for(new Count;Count < JOB_ACCESSES;Count++)
		if(containi(string,g_JobLiterals[Count]) != -1)
			Access |= (1<<Count);
	
	return Access
}

// Reverses the process of DRP_AccessToInt.
stock DRP_IntToAccess(access,string[],len)
{
	copy(string,len,"");
	
	for(new Count;Count < JOB_ACCESSES;Count++)
		if(access & (1<<Count))
			add(string,len,g_JobLiterals[Count]);
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
// If id is specified as a player that is connected,
// it will return whether or not the user is an admin.
stock DRP_AdminAccess(id = 0)
{
	new String[JOB_ACCESSES + 1]
	get_cvar_string(g_AdminAccessCvar,String,JOB_ACCESSES);
	
	new const Flag = DRP_AccessToInt(String);
	
	if(id)
		return is_user_connected(id) ? DRP_GetUserAccess(id) & Flag : FAILED
	
	return Flag
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
/*
stock DRP_GetWorldTimeMinute()
{
	new StrNum[4]
	DRP_GetWorldTime(StrNum,3,3);
	
	return str_to_num(StrNum);
}
stock DRP_GetWorldTimeHour()
{
	new StrNum[4]
	DRP_GetWorldTime(StrNum,3,2);
	
	return str_to_num(StrNum);
}
*/

stock ExplodeString(p_szOutput[][],p_iMax,const p_szInput[],p_iSize,p_szDelimiter)
{
	new iIdx = 0, l = strlen(p_szInput);
	new iLen = (1 + copyc( p_szOutput[iIdx], p_iSize, p_szInput, p_szDelimiter ))
	
	while( (iLen < l) && (++iIdx < p_iMax) )
		iLen += (1 + copyc( p_szOutput[iIdx], p_iSize, p_szInput[iLen], p_szDelimiter ))
	
	return iIdx
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