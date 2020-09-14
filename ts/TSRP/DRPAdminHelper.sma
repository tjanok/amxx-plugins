#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <geoip>
#include <DRP/DRPCore>
#include <hamsandwich>

new g_MessageModeTarget[33]
new Float:g_OldOrigin[33][3]
new g_TeleportMenu
new g_MaxPlayers

new p_StopDamage

public plugin_init()
{
	// Main
	register_plugin("DRP - Admin Helper","0.1a","Drak");
	g_MaxPlayers = get_maxplayers();
	
	// Commands
	register_clcmd("drp_adminplayer","CmdAdminPlayer",ADMIN_BAN,"(ADMIN) <target> - opens a menu, showing player info, and allowing access to admin cmds");
	register_clcmd("drp_adminteleport","CmdTeleport",ADMIN_BAN,"(ADMIN) - opens the teleporting menu");
	register_clcmd("drp_teleportall","CmdTeleportAll",ADMIN_BAN,"(ADMIN) Teleports all players to the location you are looking at (aim point)");
	
	// Internal
	register_clcmd("set_players_bank","CmdSetCash");
	register_clcmd("set_players_wallet","CmdSetCash");
	
	// CVars
	p_StopDamage = register_cvar("DRP_StopPlayerDamage","0");
	
	// Events
	DRP_RegisterEvent("Player_UseEntity","EventUseEntity");
	DRP_RegisterEvent("Menu_Display","EventMainMenu");
	
	register_event("DeathMsg","EventDeathMsg","a");
	
	// Ham Events
	RegisterHam(Ham_TakeDamage,"player","EventTakeDamage");
}

public EventTakeDamage(id,inflictor,attacker,Float:damage,Bits)
{
	// Print this information to all admins - allows us to check if people are "trolling" or anything of the like
	new plName[2][33]
	get_user_name(attacker,plName[0],32);
	get_user_name(id,plName[1],32);
	
	server_print("[DRP] Player %s attacked %s (Damage: %d)",plName[0],plName[1],floatround(damage));
	
	for(new Count;Count <= g_MaxPlayers;Count++)
	{
		if(!DRP_IsAdmin(Count))
			continue
		
		client_print(Count,print_chat,"[DRP] Player %s attacked %s (Damage: %d)",plName[0],plName[1],floatround(damage));
	}
	
	if(!get_pcvar_num(p_StopDamage))
		return HAM_IGNORED
	
	SetHamParamFloat(4,0.0);
	
	return HAM_IGNORED
}

public DRP_Error(const Reason[])
	pause("d");

// "Name" "Origin"
public DRP_Init()
{
	new ConfigFile[256]
	DRP_GetConfigsDir(ConfigFile,255);
	add(ConfigFile,255,"/AdminTeleports.ini");
	
	g_TeleportMenu = INVALID_HANDLE
	
	new pFile = fopen(ConfigFile,"r+");
	if(!pFile)
		return
	
	g_TeleportMenu = menu_create("Teleport To:","TeleportHandle");
	
	new Buffer[128],Left[33],Right[33]
	while(!feof(pFile))
	{
		fgets(pFile,Buffer,127);
		
		if(!Buffer[0] || Buffer[0] == ';')
			continue
		
		parse(Buffer,Left,32,Right,32);
		
		remove_quotes(Left);
		trim(Left);
		
		menu_additem(g_TeleportMenu,Left,Right);
	}
	fclose(pFile);
}

public EventUseEntity(const Name[],const Data[],Len)
{
	static Classname[8]
	new const id = Data[0],Index = Data[1]
	
	if(!DRP_IsAdmin(id))
		return PLUGIN_CONTINUE
	
	if(!id || !Index)
		return PLUGIN_CONTINUE
	
	entity_get_string(Index,EV_SZ_classname,Classname,7);
	if(!equali(Classname,"player"))
		return PLUGIN_CONTINUE
	
	ShowMenu(id,Index);
	return PLUGIN_CONTINUE
}
public client_disconnect(id)
{
	g_MessageModeTarget[id] = 0
	for(new Count;Count < 3;Count++)
		g_OldOrigin[id][Count] = 0.0
}
public EventDeathMsg()
{
	new const Victim = read_data(2);
	new const Killer = read_data(1);
	
	if(!Victim || !Killer)
		return PLUGIN_HANDLED
	
	new Names[2][33]
	get_user_name(Victim,Names[1],32);
	get_user_name(Killer,Names[0],32);
	
	for(new Count;Count <= g_MaxPlayers;Count++)
		if(DRP_IsAdmin(Count))
			client_print(Count,print_chat,"[DRP] [PLAYER KILLS] %s KILLED %s",Names[0],Names[1]);
		
	server_print("[DRP] [PLAYER KILLS] %s KILLED %s",Names[0],Names[1]);
	
	return PLUGIN_CONTINUE
}
public EventMainMenu(const Name[],const Data[],Len)
{
	server_print("MENU");
	new const id = Data[0]
	DRP_AddMenuItem(id,"Hello World","TestHandle");
}

public TestHandle()
{
	client_print(0,print_chat,"FUCK");
}

/*==================================================================================================================================================*/
public CmdAdminPlayer(id,level,cid)
{
	if(!DRP_CmdAccess(id,cid,2) || !access(id,ADMIN_BAN))
		return PLUGIN_HANDLED
	
	new Arg[33]
	read_argv(1,Arg,32);
	
	new Target = cmd_target(id,Arg,CMDTARGET_ALLOW_SELF);
	if(!Target)
		return PLUGIN_HANDLED
	
	ShowMenu(id,Target);
	return PLUGIN_HANDLED
}
public CmdTeleport(id,level,cid)
{
	if(!DRP_CmdAccess(id,cid,1) || !access(id,ADMIN_BAN))
		return PLUGIN_HANDLED
	
	if(g_TeleportMenu == INVALID_HANDLE)
	{
		client_print(id,print_chat,"[DRP] Menu was not created. Unable to open.");
		return PLUGIN_HANDLED
	}
	
	menu_display(id,g_TeleportMenu);
	return PLUGIN_HANDLED
}
public CmdSetCash(id,level,cid)
{
	if(!DRP_CmdAccess(id,cid,1) || !access(id,ADMIN_BAN))
		return PLUGIN_HANDLED
	
	new Target = g_MessageModeTarget[id]
	g_MessageModeTarget[id] = 0
	
	new Args[24]
	read_argv(0,Args,23);
	new Flag = Args[12] == 'b' ? 1 : 0
	
	read_args(Args,23);
	
	remove_quotes(Args);
	trim(Args);
	
	new Amount = str_to_num(Args);
	if(Amount < 0)
	{
		client_print(id,print_chat,"[DRP] Amount needs to be 1 or greater.");
		return PLUGIN_HANDLED
	}
	
	read_argv(0,Args,23);
	
	Flag == 1 ? DRP_SetUserBank(Target,Amount) : DRP_SetUserWallet(Target,Amount);
	client_print(id,print_chat,"[DRP] User's cash set to: $%d",Amount);
	
	return PLUGIN_HANDLED
}
public CmdTeleportAll(id,level,cid)
{
	if(!DRP_CmdAccess(id,level,1))
		return PLUGIN_HANDLED
	
	new Float:vecOrigin[3],Num
	entity_get_vector(id,EV_VEC_origin,vecOrigin);
	
	for(new Count;Count <= get_maxplayers();Count++)
	{
		if(Count == id || !is_user_alive(Count))
			continue
		
		if(FindEmptyLoc(id,vecOrigin,Num,300.0))
			entity_set_vector(Count,EV_VEC_origin,vecOrigin);
	}
	
	client_print(id,print_console,"[DRP] Player's teleported..");
	return PLUGIN_HANDLED
}
/*==================================================================================================================================================*/
ShowMenu(id,Target)
{
	new Temp[256]
	get_user_name(Target,Temp,255);
	
	g_MessageModeTarget[id] = Target
	
	format(Temp,255,"%s's^nInformation",Temp);
	new Menu = menu_create(Temp,"_HandleMenu");
	
	menu_additem(Menu,"Set Bank");
	menu_additem(Menu,"Set Wallet^n");
	menu_additem(Menu,"Player Info");
	menu_additem(Menu,"View Items");
	
	if(g_OldOrigin[Target][0] > 0.0 || g_OldOrigin[Target][1] > 0.0 || g_OldOrigin[Target][2] > 0.0)
		menu_additem(Menu,"Teleport back^n");
	else 
	menu_additem(Menu,"Teleport to Me^n");
	
	menu_additem(Menu,"Teleport Menu");
	
	menu_display(id,Menu);
	return
}
public _HandleMenu(id,Menu,Item)
{
	new Target = g_MessageModeTarget[id]
	g_MessageModeTarget[id] = 0
	menu_destroy(Menu);
	
	if(Item == MENU_EXIT)
		return PLUGIN_HANDLED
	
	if(!is_user_connected(Target))
	{
		client_print(id,print_chat,"[DRP] The target player is not connected anymore");
		return PLUGIN_HANDLED
	}
	
	new AuthID[36],AdminAuthID[36]
	get_user_authid(Target,AuthID,35);
	get_user_authid(id,AdminAuthID,35);
	
	switch(Item)
	{
		case 0..1:
		{
			Item == 0 ? client_cmd(id,"messagemode set_players_bank") : client_cmd(id,"messagemode set_players_wallet");
			client_print(id,print_chat,"[DRP] Please type the amount you wish to set.");
		}
		case 2:
		{
			new Temp[256]
			new AccessStr[12],JobAccess[12]
			DRP_IntToAccess(DRP_GetUserAccess(Target),AccessStr,11);
			DRP_IntToAccess(DRP_GetUserJobRight(Target),JobAccess,11);
			
			new AuthID[36],IPAddress[36]
			get_user_authid(Target,AuthID,35);
			get_user_ip(Target,IPAddress,35,1);
			
			new Country[46]
			geoip_country(IPAddress,Country);
			
			new JobName[33]
			DRP_GetJobName(DRP_GetUserJobID(Target),JobName,32);
			
			formatex(Temp,255,"^nWallet: $%d^nBank: $%d^nJob: %s^nPlaytime: %d^nAccess: %s^nJob Access: %s^n^nIP: %s^nAuthID: %s^nCountry: %s",
			DRP_GetUserWallet(Target),DRP_GetUserBank(Target),JobName,DRP_GetUserTime(Target),AccessStr,JobAccess,IPAddress,AuthID,Country);
			
			show_motd(id,Temp,"DRP");
		}
		case 3:
		{
			new Temp[MAX_ITEMS],ItemName[33],Message[512]
			new ItemNum = DRP_FetchUserItems(Target,Temp),ItemID,Pos
			
			for(new Count;Count < ItemNum;Count++)
			{
				ItemID = Temp[Count]
				
				if(!ItemID)
					continue
				
				DRP_GetItemName(ItemID,ItemName,32);
				Pos += formatex(Message[Pos],511 - Pos,"%s - #%d^n",ItemName,DRP_GetUserItemNum(Target,ItemID));
			}
			show_motd(id,Message,"DRP");	
		}
		case 4:
		{
			if(g_OldOrigin[Target][0] > 0.0 || g_OldOrigin[Target][1] > 0.0 || g_OldOrigin[Target][2] > 0.0)
			{
				g_OldOrigin[Target][2] += 40.0
				entity_set_vector(Target,EV_VEC_origin,g_OldOrigin[Target]);
				
				for(new Count;Count < 3;Count++)
					g_OldOrigin[Target][Count] = 0.0
				
				return PLUGIN_HANDLED
			}
			
			new plOrigin[3],Float:vOrigin[3]
			get_user_origin(id,plOrigin,3);
			
			plOrigin[2] += 40
			
			IVecFVec(plOrigin,vOrigin);
			entity_get_vector(Target,EV_VEC_origin,g_OldOrigin[Target]);
			entity_set_vector(Target,EV_VEC_origin,vOrigin);
			
			new plName[33]
			get_user_name(id,plName,32);
			
			client_print(Target,print_chat,"[DRP] You have been teleported by admin: %s",plName);
			return PLUGIN_HANDLED
		}
		case 5:
		{
			if(g_TeleportMenu == INVALID_HANDLE)
			{
				client_print(id,print_chat,"[DRP] Menu was not created. Unable to open.");
				return PLUGIN_HANDLED
			}
			menu_display(id,g_TeleportMenu);
		}
	}
	return PLUGIN_HANDLED
}
public TeleportHandle(id,Menu,Item)
{
	if(Item == MENU_EXIT)
		return PLUGIN_HANDLED
	
	new Temp,szOrigin[33],Name[33]
	menu_item_getinfo(Menu,Item,Temp,szOrigin,32,Name,32,Temp);
	
	new Exploded[3][12]
	parse(szOrigin,Exploded[0],11,Exploded[1],11,Exploded[2],11);
	
	new Float:vOrigin[3]
	for(new Count;Count < 3;Count++)
		vOrigin[Count] = str_to_float(Exploded[Count]);
	
	entity_set_vector(id,EV_VEC_origin,vOrigin);
	client_print(id,print_chat,"[DRP] Teleported to: %s",Name);
	
	return PLUGIN_HANDLED
}

public plugin_end()
	if(g_TeleportMenu != INVALID_HANDLE)
		menu_destroy(g_TeleportMenu);
	
FindEmptyLoc(id,Float:Origin[3],&Num,const Float:Radius)
{
	if(Num++ > 100)
		return PLUGIN_CONTINUE
	
	new Float:pOrigin[3]
	entity_get_vector(id,EV_VEC_origin,pOrigin);
	
	for(new Count;Count < 2;Count++)
		pOrigin[Count] += random_float(-Radius,Radius);
	
	if(PointContents(pOrigin) != CONTENTS_EMPTY && PointContents(pOrigin) != CONTENTS_SKY)
		return FindEmptyLoc(id,Origin,Num,Radius);
	
	Origin = pOrigin
	return PLUGIN_HANDLED
}