#include <amxmodx>
#include <DRP/DRPCore>

new g_Cache[256]
new g_UserNewProfile[33]

new Array:g_UserProfile[33]
new const g_HelpText[] = "1 = Edit Name^n2 = Edit Age^n3 = Edit Gender^n4 = Edit About Me^nNote: Use ^"\n^" to make a new line"

new Handle:g_SqlHandle
new g_ProfileMenu

public DRP_Init()
{
	g_SqlHandle = DRP_SqlHandle();
	SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle","CREATE TABLE IF NOT EXISTS `PlayerProfiles` (AuthID VARCHAR(36),Name VARCHAR(33),Age INT(11),Gender VARCHAR(24),AboutMe TEXT,PRIMARY KEY (AuthID))");
}
	
public plugin_init()
{
	// Main
	register_plugin("DRP - Profiles","0.1a","Drak");
	
	// Commands
	DRP_RegisterCmd("say /profile","CmdProfile","View your profile");
	DRP_RegisterCmd("drp_pedit","CmdEdit","drp_pedit <edit #> <text> - edit's your players profile (this is your players persona)");
	
	// Events
	DRP_RegisterEvent("Menu_Display","Event_MenuDisplay");
	
	// Menu
	g_ProfileMenu = menu_create("Profiles","ProfileMenuHandle");
	menu_additem(g_ProfileMenu,"View my Profile");
	menu_additem(g_ProfileMenu,"View somebody's Profile");
	menu_additem(g_ProfileMenu,"Help");
	menu_additem(g_ProfileMenu,"I don't want a profile^n");
	menu_addtext(g_ProfileMenu,"NOTE:^nAnybody can view your profile",0);
}
/*==================================================================================================================================================*/
public Event_MenuDisplay(const Name[],const Data[])
	DRP_AddMenuItem(Data[0],"Profiles","CmdProfile");

public client_authorized(id)
{
	g_UserProfile[id] = Invalid_Array
	g_UserNewProfile[id] = 0
	
	new AuthID[36]
	get_user_authid(id,AuthID,35);
	
	new Data[1]
	Data[0] = id
	
	format(g_Cache,255,"SELECT * FROM `PlayerProfiles` WHERE `AuthID`='%s'",AuthID);
	SQL_ThreadQuery(g_SqlHandle,"LoadPlayerProfile",g_Cache,Data,1);
}
public client_disconnect(id)
{
	if(g_UserProfile[id] != Invalid_Array)
	{
		ArrayDestroy(g_UserProfile[id]);
		g_UserProfile[id] = Invalid_Array
	}
}
/*==================================================================================================================================================*/
public DRP_HudDisplay(id,Hud)
{
	if(Hud != HUD_PRIM)
		return
	
	if(g_UserNewProfile[id])
		DRP_AddHudItem(id,HUD_PRIM,"You have not setup a profile^nType ^"/profile^" to start.");
}
/*==================================================================================================================================================*/
public CmdProfile(id)
{	
	menu_display(id,g_ProfileMenu);
	return PLUGIN_HANDLED
}
public CmdEdit(id)
{
	if(read_argc() != 3)
	{
		client_print(id,print_console,"Usage: drp_pedit <edit #> <text> - the edit numbers are listed below");
		client_print(id,print_console,"%s",g_HelpText);
		return PLUGIN_HANDLED
	}
	
	new Arg[4]
	read_argv(1,Arg,3);
	
	// 1 = NAME
	// 2 = AGE
	// 3 = GENDER
	// 4 = ABOUTME
	
	replace_all(Arg,3,"#","");
	
	new Num = str_to_num(Arg);
	if(!Num || Num > 4)
	{
		client_print(id,print_console,"Invalid Edit Number^n%s",g_HelpText);
		return PLUGIN_HANDLED
	}
	
	new AuthID[36]
	get_user_authid(id,AuthID,35);
	
	read_argv(2,g_Cache,255);
	if(strlen(g_Cache) > (Num == 4 ? 255 : 32))
	{
		client_print(id,print_console,"[DRP] Your input is to long / to much text. Max: %d",Num == 4 ? 255 : 32);
		return PLUGIN_HANDLED
	}
	
	if(Num == 2)
	{
		if(!is_str_num(g_Cache))
		{
			client_print(id,print_console,"[DRP] Your age must be a number");
			return PLUGIN_HANDLED
		}
	}
	
	replace_all(g_Cache,255,"\n","^n");
	
	remove_quotes(g_Cache);
	trim(g_Cache);
	
	if(g_UserNewProfile[id])
		BlankValues(id);
	
	new Query[512]
	switch(Num)
	{
		case 1:
		{
			ArraySetString(g_UserProfile[id],0,g_Cache);
			replace_all(g_Cache,255,"'","\'");
			formatex(Query,511,"INSERT INTO `PlayerProfiles` VALUES('%s','%s','0','0','') ON DUPLICATE KEY UPDATE `Name`='%s'",AuthID,g_Cache,g_Cache);
		}
		case 2: 
		{
			Num = str_to_num(g_Cache);
			ArraySetCell(g_UserProfile[id],1,Num)
			
			replace_all(g_Cache,255,"'","\'");
			formatex(Query,511,"INSERT INTO `PlayerProfiles` VALUES('%s','','%d','0','') ON DUPLICATE KEY UPDATE `Age`='%d'",AuthID,Num,Num);
		}
		case 3:
		{
			ArraySetString(g_UserProfile[id],2,g_Cache);
			replace_all(g_Cache,255,"'","\'");
			formatex(Query,511,"INSERT INTO `PlayerProfiles` VALUES('%s','','0','%s','') ON DUPLICATE KEY UPDATE `Gender`='%s'",AuthID,g_Cache,g_Cache);
		}
		case 4: 
		{
			ArraySetString(g_UserProfile[id],3,g_Cache);
			replace_all(g_Cache,255,"'","\'");
			formatex(Query,511,"INSERT INTO `PlayerProfiles` VALUES('%s','','0','0','%s') ON DUPLICATE KEY UPDATE `AboutMe`='%s'",AuthID,g_Cache,g_Cache);
		}
	}
	
	g_UserNewProfile[id] = 0
	
	client_print(id,print_console,"[DRP] You have successfully edited your profile.");
	SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",Query);
	
	return PLUGIN_HANDLED
}
/*==================================================================================================================================================*/
public ProfileMenuHandle(id,Menu,Item)
{
	if(Menu == MENU_EXIT)
		return PLUGIN_HANDLED
	
	if(Item == 2)
	{
		if(!DRP_ShowMOTDHelp(id,"DRPProfiles_Help.txt"))
			client_print(id,print_chat,"[DRP] Unable to show help file.");
		
		return PLUGIN_HANDLED
	}
	
	switch(Item)
	{
		case 0:
		{
			if(g_UserProfile[id] == Invalid_Array || ArrayGetCell(g_UserProfile[id],1) == -1)
			{
				client_print(id,print_chat,"[DRP] You do not have a profile / it's empty. Use ^"drp_pedit^" to set it up.");
				return PLUGIN_HANDLED
			}
			ViewProfile(id,id);
		}
		case 1:
		{
			new Index,Body
			get_user_aiming(id,Index,Body,100);
			
			if(!Index || !is_user_alive(Index))
			{
				client_print(id,print_chat,"[DRP] You must be looking at a user.");
				return PLUGIN_HANDLED
			}
			
			if(g_UserProfile[Index] == Invalid_Array || ArrayGetCell(g_UserProfile[Index],1) == -1)
			{
				client_print(id,print_chat,"[DRP] This user does not have a profile");
				return PLUGIN_HANDLED
			}
			
			new plName[33]
			get_user_name(id,plName,32);
			
			client_print(Index,print_chat,"[DRP] %s is viewing your profile.",plName);
			ViewProfile(id,Index);
		}
		case 3:
		{
			// They have one
			if(!g_UserNewProfile[id])
			{
				client_print(id,print_chat,"[DRP] You already created a profile. Contact an administrator to delete it.");
				return PLUGIN_HANDLED
			}
			
			BlankValues(id,1);
			client_print(id,print_chat,"[DRP] You chose to not make a profile. Type ^"/profile^" at any time to make one.");
			
			g_UserNewProfile[id] = 0
		}
	}
	return PLUGIN_HANDLED
}
/*==================================================================================================================================================*/
ViewProfile(ShowToID,ProfileUserID)
{
	if(g_UserProfile[ProfileUserID] == Invalid_Array)
		return
	
	if(!is_user_alive(ShowToID) || !is_user_alive(ProfileUserID))
		return
	
	new Menu[512],Pos
	ArrayGetString(g_UserProfile[ProfileUserID],0,g_Cache,255);
	Pos += formatex(Menu[Pos],511 - Pos,"Name: %s^n",g_Cache);
	
	ArrayGetString(g_UserProfile[ProfileUserID],2,g_Cache,255)
	Pos += formatex(Menu[Pos],511 - Pos,"Gender: %s^nAge: %d^n",g_Cache,ArrayGetCell(g_UserProfile[ProfileUserID],1));
	
	ArrayGetString(g_UserProfile[ProfileUserID],3,g_Cache,255);
	Pos += formatex(Menu[Pos],511 - Pos,"About Them:^n%s",g_Cache);
	
	show_motd(ShowToID,Menu,"Profile");
	return
}
/*==================================================================================================================================================*/
public LoadPlayerProfile(FailState,Handle:Query,const Error[],Errcode,const Data[],DataSize) 
{
	if(FailState != TQUERY_SUCCESS)
		return log_amx("[DRP-CORE] [SQL ERROR] Unable to connect to SQL Database. (Error: %s)",Error ? Error : "UNKNOWN");
	
	new id = Data[0]
	
	if(!SQL_NumResults(Query))
	{
		g_UserNewProfile[id] = 1
		return PLUGIN_CONTINUE
	}
	
	new Temp[256]
	g_UserProfile[id] = ArrayCreate(256);
	
	while(SQL_MoreResults(Query))
	{
		SQL_ReadResult(Query,1,Temp,255);
		ArrayPushString(g_UserProfile[id],Temp); // Name
		ArrayPushCell(g_UserProfile[id],SQL_ReadResult(Query,2)); // Age
		
		SQL_ReadResult(Query,3,Temp,255);
		ArrayPushString(g_UserProfile[id],Temp); // Gender
		
		SQL_ReadResult(Query,4,Temp,255);
		ArrayPushString(g_UserProfile[id],Temp); // About me
		
		SQL_NextRow(Query);
	}
	return PLUGIN_CONTINUE
}
public IgnoreHandle(FailState,Handle:Query,const Error[],Errcode,const Data[],DataSize) 
{
	if(FailState != TQUERY_SUCCESS)
	{
		SQL_QueryError(Query,g_Cache,255);
		return log_amx("[DRP-CORE] [SQL ERROR] Unable to connect to SQL Database. (Error: %s)",g_Cache);
	}
	
	return PLUGIN_CONTINUE
}

BlankValues(id,SQLPost=0)
{
	g_UserProfile[id] = ArrayCreate(256);
	
	ArrayPushString(g_UserProfile[id],"");
	ArrayPushCell(g_UserProfile[id],SQLPost ? -1 : 0);
	ArrayPushString(g_UserProfile[id],"");
	ArrayPushString(g_UserProfile[id],"");
	
	if(SQLPost)
	{
		new Query[128],AuthID[36]
		get_user_authid(id,AuthID,35);
		
		format(Query,127,"INSERT INTO `PlayerProfiles` VALUES('%s','','-1','','')",AuthID);
		SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",Query);
	}
}

public plugin_end()
	menu_destroy(g_ProfileMenu);