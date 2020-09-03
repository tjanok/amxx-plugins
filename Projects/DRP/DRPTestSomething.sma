/////////////////////////////////////////////////////
// DRPFriends.sma
// ------------------
//
//
//

#include <amxmodx>
#include <DRP/DRPCore>

#include <cellarray>
#include <engine>

new g_Cache[512]
new Handle:g_SqlHandle

new Array:g_UserProfile[33]
new Array:g_ArraySteamID[33]

new g_TakingRequests[33]
new g_UserFriends[33]

new g_Display[33]
new g_NewPlayer[33]

public plugin_natives()
{
}

public plugin_init()
{
	register_plugin("DRP - Friends","","");
	
	for(new Count;Count <= get_maxplayers();Count++)
	{
		g_ArraySteamID[Count] = ArrayCreate(36);
		g_UserProfile[Count] = ArrayCreate(345);
	}
	
	DRP_RegisterEvent("Player_Spawn","DRP_PlayerSpawn");
	DRP_RegisterEvent("Menu_Display","DRP_MenuHandle");
	
	DRP_RegisterCmd("drp_pedit","CmdEdit","drp_pedit <edit #> <text> - edit's your players profile (this is your players persona)");
}

public DRP_Error(const Error[])
{ 
	plugin_end();
	pause("d");
}

public DRP_Init()
{
	g_SqlHandle = DRP_SqlHandle();
	
	format(g_Cache,511,"CREATE TABLE IF NOT EXISTS `PlayerFriends` (FriendID VARCHAR(36),SteamID VARCHAR(36))");
	SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",g_Cache);
	
	format(g_Cache,511,"CREATE TABLE IF NOT EXISTS `PlayerPersona` (Name VARCHAR(32),Age VARCHAR(24),Interests TEXT,AboutMe TEXT,SteamID VARCHAR(36),Private INT(11))");
	SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",g_Cache);
}

public DRP_PlayerSpawn(const Name[],const Data[])
	if(g_NewPlayer[Data[0]])
		DRP_ShowMOTDHelp(Data[0],"NewPlayerPersona.txt");
	
public DRP_MenuHandle(const Name[],const Data[])
	DRP_AddMenuItem(Data[0],"DRP Friends v1","CmdFriends");

public plugin_end()
{
	for(new Count;Count <= get_maxplayers();Count++)
	{
		ArrayDestroy(g_ArraySteamID[Count]);
		ArrayDestroy(g_UserProfile[Count]);
	}
}

public cmd(id)
{
	ArrayGetString(g_UserProfile[id],0,g_Cache,511);
	server_print("%s",g_Cache);
	show_motd(id,g_Cache,"L");
	/*
	new iPlayers[32],Query[128],AuthID[36]
	new iNum,Target
	get_players(iPlayers,iNum);
	
	get_user_authid(id,AuthID,35);
	
	for(new Count,Count2,Size;Count < iNum;Count++)
	{
		Target = iPlayers[Count]
		Size = ArraySize(g_ArraySteamID[Target]);
		
		if(!Size)
			continue
		
		server_print("GOT HERE");
		
		for(Count2 = 0;Count2 < Size;Count2++)
		{
			ArrayGetString(g_ArraySteamID[Target],Count2,Query,127);
			
			if(equali(Query,AuthID))
			{
				g_UserFriends[Target] = (g_UserFriends[Target] | (1<<(id - 1)))
				break;
			}
		}
	}
	new Index,Body
	Index = id
	if(g_UserFriends[id] & Index)
		server_print("WE ARE FRIENDS LOL");
	else
		server_print("WE ARE NOT FRIENDS");
		*/
}
/*==================================================================================================================================================*/
public CmdFriends(id)
{
	if(!is_user_alive(id))
		return
	
	new Cache[64],Menu = menu_create("DRP Friends^nYour friends are listed below","_Friends"),Size = ArraySize(g_ArraySteamID[id]);
	if(Size)
	{
		new Num[3]
		for(new Count,UserID;Count <= Size;Count++)
		{
			ArrayGetString(g_ArraySteamID[id],Count,Cache,63);
			UserID = IsSteamIDConnected(Cache);
			
			if(UserID)
				get_user_name(UserID,Cache,63);
			else
				add(Cache,63," (OFFLINE)");
			
			num_to_str(UserID,Num,2);
			menu_additem(Menu,Cache,Num);
		}
	}
	else
		menu_additem(Menu,"You have no friends.");
		
	menu_addblank(Menu,0);
	
	formatex(Cache,63,"Toggle Friend Requests (%s)",g_TakingRequests[id] ? "On" : "Off");
	menu_additem(Menu,Cache);
	
	menu_additem(Menu,"View My Profile");
	menu_additem(Menu,"Edit My Profile");
	menu_additem(Menu,"Help");

	menu_display(id,Menu);
}
public _Friends(id,Menu,Item)
{
	switch(Item)
	{
		case 0:
		{
			if(!ArraySize(g_ArraySteamID[id]))
			{
				client_print(id,print_chat,"[DRP] You have no friends.");
				return PLUGIN_HANDLED
			}
			new StrID[33],Temp
			menu_item_getinfo(Menu,Item,Temp,StrID,32,_,_,Temp);
			menu_destroy(Menu);
			
			new Target = str_to_num(StrID);
			if(!Target || !is_user_connected(Target))
			{
				client_print(id,print_chat,"[DRP] This user is offline or is unavailable.");
				return PLUGIN_HANDLED
			}
			get_user_name(Target,StrID,32);
			Menu = menu_create(StrID,"_HandleFriend");
			
			menu_additem(Menu,"View User's Profile");
			menu_display(id,Menu);
			return PLUGIN_HANDLED
		}
		case 1:
		{
			g_TakingRequests[id] = !g_TakingRequests[id]
			client_print(id,print_chat,"[DRP] You have turned friend requests %s",g_TakingRequests[id] ? "on" : "off");
		}
		case 2:
		{
			ViewProfile(id,id);
			return menu_display(id,Menu);
		}
		case 3:
		{
			client_print(id,print_chat,"[DRP] Use the console command ^"drp_pedit^" to edit your profile.");
		}
		case 4:
		{
			DRP_ShowMOTDHelp(id,"FriendsHelp.txt");
			return menu_display(id,Menu);
		}
		case MENU_EXIT:
		{
			menu_destroy(Menu);
			return PLUGIN_HANDLED
		}
	}
	menu_destroy(Menu);
	return PLUGIN_HANDLED
}
public _HandleFriend(id,Menu,Item)
{
	switch(Item)
	{
	}
	return PLUGIN_HANDLED
}
/*==================================================================================================================================================*/
public CmdEdit(id)
{
	if(read_argc() != 3)
	{
		client_print(id,print_console,"Usage: drp_pedit <edit #> <text> - the edit numbers are listed below");
		client_print(id,print_console,"1 = Edit Name^n2 = Edit Age^n3 = Edit Interests^n4 = Edit About Me");
		return PLUGIN_HANDLED
	}
	
	new Arg[2]
	read_argv(1,Arg,1);
	
	// 0 = NAME
	// 1 = AGE
	// 2 = INTERESTS
	// 3 = ABOUTME
	
	new Num = str_to_num(Arg);
	if(!Num || Num > 4)
	{
		client_print(id,print_console,"Invalid Edit Number^n1 = Edit Name^n2 = Edit Age^n3 = Edit Interests^n4 = Edit About Me");
		return PLUGIN_HANDLED
	}
	
	new AuthID[36]
	get_user_authid(id,AuthID,35);
	
	read_argv(2,g_Cache,511);
	ArraySetString(g_UserProfile[id],Num - 1,g_Cache);
	
	replace_all(g_Cache,511,"'","\'");
	
	switch(Num)
	{
		case 1: format(g_Cache,511,"UPDATE `PlayerPersona` SET `Name`='%s' WHERE SteamID='%s'",g_Cache,AuthID);
		case 2: format(g_Cache,511,"UPDATE `PlayerPersona` SET `Age`='%s' WHERE SteamID='%s'",g_Cache,AuthID);
		case 3: format(g_Cache,511,"UPDATE `PlayerPersona` SET `Interests`='%s' WHERE SteamID='%s'",g_Cache,AuthID);
		case 4: format(g_Cache,511,"UPDATE `PlayerPersona` SET `AboutMe`='%s' WHERE SteamID='%s'",g_Cache,AuthID);
	}
	
	SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",g_Cache);
	client_print(id,print_console,"[DRP] You have successfully edited your profile.");
	
	return PLUGIN_HANDLED
}
/*==================================================================================================================================================*/
public client_authorized(id)
{
	new Data[1],AuthID[36]
	get_user_authid(id,AuthID,35);
	
	Data[0] = id
	
	g_Display[id] = 1
	g_NewPlayer[id] = 0
	g_UserFriends[id] = 0
	g_TakingRequests[id] = 1
	
	ArrayClear(g_UserFriends[id]);
	ArrayClear(g_UserProfile[id]);
	
	format(g_Cache,511,"SELECT `Friends` FROM `PlayerFriends` WHERE SteamID='%s'",AuthID);
	SQL_ThreadQuery(g_SqlHandle,"LoadPlayerFriends",g_Cache,Data,1);
	
	format(g_Cache,511,"SELECT * FROM `PlayerPersona` WHERE SteamID='%s'",AuthID);
	SQL_ThreadQuery(g_SqlHandle,"LoadPlayerPersona",g_Cache,Data,1);
}
/*==================================================================================================================================================*/
public client_PreThink(id)
{
	new Index,Body
	get_user_aiming(id,Index,Body,120);
	
	Index=id
	
	if(!Index)
		return
	
	static Classname[64],Friend
	entity_get_string(Index,EV_SZ_classname,Classname,63);
	
	if(!equali(Classname,"player"))
		return
	
	Friend = (g_UserFriends[id] & Index) ? 1 : 0
	
	if(g_Display[id])
	{
		Friend ? DRP_GetJobName(DRP_GetUserJobID(Index),Classname,63) : copy(Classname,63,"UNKNOWN");
		DRP_AddHudItem(id,HUD_EXTRA,0,"[%s]^nJob: %s^n%s",Friend ? "Friend" : "Random Citizen",Classname,Friend ? "" : "Press use (default e) for a friend invite");
		
		g_Display[id] = 0
		set_task(0.9,"ResetDisplay",id)
	}
	
	if(!(entity_get_int(id,EV_INT_button) & IN_USE && !(entity_get_int(id,EV_INT_oldbuttons) & IN_USE)))
		return
	
	if(!Friend)
	{
		if(!g_TakingRequests[Index])
			return
		
		get_user_name(Index,Classname,63);
		client_print(id,print_chat,"[DRP] Friend Request sent to: %s",Classname);
		
		get_user_name(id,Classname,63);
		format(Classname,63,"Friend Request^n^n%s,^nwants to be friends",Classname);
		
		new Menu = menu_create(Classname,"_Request");
		num_to_str(id,Classname,63);
		
		menu_additem(Menu,"Accept",Classname);
		menu_additem(Menu,"Ignore",Classname);
		menu_additem(Menu,"Shut off Friend Requests^n",Classname);
		menu_additem(Menu,"Help",Classname);
		
		menu_display(Index,Menu);
		return
	}
}
public ResetDisplay(id)
	g_Display[id] = 1
/*==================================================================================================================================================*/
public _Request(id,Menu,Item)
{
	new StrID[6],Temp
	menu_item_getinfo(Menu,Item,Temp,StrID,5,_,_,Temp);
	
	if(Item == MENU_EXIT)
	{
		menu_destroy(Menu);
		return PLUGIN_HANDLED
	}
	
	if(Item == 3)
	{
		DRP_ShowMOTDHelp(id,"FriendsHelp.txt");
		return menu_display(id,Menu);
	}
	menu_destroy(Menu);
	
	Temp = str_to_num(StrID);
	if(!Temp || !is_user_alive(Temp))
	{
		client_print(id,print_chat,"[DRP] Friend Request Failed. The asker has died/disconnected.");
		return PLUGIN_HANDLED
	}
	
	new Name[36]
	get_user_name(Temp,Name,35);
	
	switch(Item)
	{
		case 0:
		{
			client_print(id,print_chat,"[DRP] You have become friends with %s.",Name);
			get_user_name(id,Name,32);
			client_print(Temp,print_chat,"[DRP] You have become friends with %s.",Name);
			
			new AuthID[36]
			get_user_authid(Temp,AuthID,35);
			get_user_authid(id,Name,35);
			
			ArrayPushString(g_ArraySteamID[id],AuthID);
			
			format(g_Cache,511,"INSERT INTO `PlayerFriends` VALUES ('%s','%s')",AuthID,Name);
			SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",g_Cache);
			
			g_UserFriends[Temp] = (g_UserFriends[Temp] | (1<<(id - 1)))
			g_UserFriends[id] = (g_UserFriends[id] | (1<<(Temp - 1)))
		}
		case 1:
		{
			client_print(id,print_chat,"[DRP] You have ignored %s's friend offer.",Name);
			get_user_name(id,Name,32);
			client_print(Temp,print_chat,"[DRP] %s has ignored your friend offer.",Name);
		}
		case 2:
		{
			g_TakingRequests[id] = !g_TakingRequests[id]
			client_print(id,print_chat,"[DRP] You have turned friend requests %s",g_TakingRequests[id] ? "on" : "off");
		}
	}
	return PLUGIN_HANDLED
}
/*==================================================================================================================================================*/
public LoadPlayerPersona(FailState,Handle:Query,Error[],Errcode,Data[],DataSize)
{
	new const id = Data[0]
	if(FailState != TQUERY_SUCCESS || Error[0])
		return log_amx("[DRP FRIENDS] SQL Query Failed (Error: %s)",Error[0] ? Error : "UNKNOWN");
	
	if(!SQL_NumResults(Query))
		return g_NewPlayer[id] = 1
	
	while(SQL_MoreResults(Query))
	{
		// 0 = NAME
		// 1 = AGE
		// 2 = Interests
		// 3 = ABOUTME
		
		SQL_ReadResult(Query,0,g_Cache,511);
		ArrayPushString(g_UserProfile[id],g_Cache);
		SQL_ReadResult(Query,1,g_Cache,511);
		ArrayPushString(g_UserProfile[id],g_Cache);
		SQL_ReadResult(Query,2,g_Cache,511);
		ArrayPushString(g_UserProfile[id],g_Cache);
		SQL_ReadResult(Query,3,g_Cache,511);
		ArrayPushString(g_UserProfile[id],g_Cache);
		
		ArrayPushCell(g_UserProfile[id],SQL_ReadResult(Query,4) ? 1 : 0);
		SQL_NextRow(Query);
	}
	return PLUGIN_CONTINUE
}
public LoadPlayerFriends(FailState,Handle:Query,Error[],Errcode,Data[],DataSize)
{
	new const id = Data[0]
	if(FailState != TQUERY_SUCCESS || Error[0])
		return log_amx("[DRP FRIENDS] SQL Query Failed (Error: %s)",Error[0] ? Error : "UNKNOWN");
	
	new AuthID[36]
	if(SQL_NumResults(Query) >= 1)
	{
		while(SQL_MoreResults(Query))
		{
			SQL_ReadResult(Query,0,AuthID,35);
			ArrayPushString(g_ArraySteamID[id],AuthID);
			SQL_NextRow(Query);
		}
	}
	
	new OtherAuthID[36],Target,Size
	get_user_authid(id,AuthID,35);
	
	for(new Count,Count2;Count <= get_playersnum(1);Count++)
	{
		Target = Count
		if(g_UserFriends[id] & Target)
			continue
		//if(Target == id)
			//continue
		
		Size = ArraySize(g_ArraySteamID[Target]);
		if(!Size)
			continue
		
		for(Count2 = 0;Count2 <= Size;Count2++)
		{
			ArrayGetString(g_ArraySteamID[Target],Count2,OtherAuthID,35);
			if(equali(AuthID,OtherAuthID))
			{
				g_UserFriends[Target] = (g_UserFriends[Target] | (1<<(id - 1)))
				g_UserFriends[id] = (g_UserFriends[id] | (1<<(Target - 1)))
				break
			}
		}
	}
	return PLUGIN_CONTINUE
}
public IgnoreHandle(FailState,Handle:Query,Error[],Errcode,Data[],DataSize)
	if(FailState != TQUERY_SUCCESS || Error[0])
		log_amx("[DRP FRIENDS] SQL Query Failed (Error: %s)",Error[0] ? Error : "UNKNOWN");

IsSteamIDConnected(const AuthID[])
{
	new iPlayers[32],OtherAuthID[36],iNum,Target
	get_players(iPlayers,iNum);
	
	for(new Count;Count < iNum;Count++)
	{
		Target = iPlayers[Count]
		get_user_authid(Target,OtherAuthID,35);
		
		if(equali(AuthID,OtherAuthID))
			return Target;
	}
	return FAILED
}
ViewProfile(id,ProfileTargetID)
{
	if(!is_user_alive(id) || !ProfileTargetID)
		return
	
	new Temp[345],Pos
	
	ArrayGetString(g_UserProfile[id],0,Temp,345);
	Pos += formatex(g_Cache[Pos],511-Pos,"Name: %s^n",Temp);
	ArrayGetString(g_UserProfile[id],1,Temp,345);
	Pos += formatex(g_Cache[Pos],511-Pos,"Age: %s^n",Temp);
	ArrayGetString(g_UserProfile[id],2,Temp,345);
	Pos += formatex(g_Cache[Pos],511-Pos,"Interests: %s^n^n",Temp);
	ArrayGetString(g_UserProfile[id],3,Temp,345);
	Pos += formatex(g_Cache[Pos],511-Pos,"About Me:^n%s",Temp);
	
	show_motd(id,g_Cache,"DRP");
}