#include <amxmodx>
#include <engine>

#include <DRP/DRPCore>
#include <DRP/DRPChat>

#include <hamsandwich>

#define MAX_JAILS 6
#define USE_MAPBASED_JAILS

// PCvars
new p_Reconnect
new p_Cuffs
new p_CopsOnly
new p_DragPlayers
new p_Confiscate
new g_ShowPlayers[33] = {1,...}
new g_Jailed[33] = {-1,...}

new g_TimeIn[33]
new g_DataGathered[33]
new g_MapName[64]
new g_Cuffed[33]
new g_iFrisker[33]

// Jail
new g_JailNames[MAX_JAILS][33]
new Float:g_JailOrigins[MAX_JAILS][3]
new Float:g_MaxSpeed[33]
new g_JailNum

// Where we are automatically put when our time is up, or let out of jail
// This is optional
new Float:g_ExitLocation[3]

new g_Flag
new g_Cuffs

// SQL
new Handle:g_SqlHandle
new g_Query[256]

new g_MaxPlayers
new g_Trainee

#if defined USE_MAPBASED_JAILS
new g_Jails[MAX_JAILS]
#else
new p_Distance
#endif

new g_MessageModeTarget[33]
new g_FriskMenu

new const g_PoliceSounds[3][] =
{
	"OZDRP/police/police1.wav",
	"OZDRP/police/police2.wav",
	"OZDRP/police/police5.wav"
}

new Float:g_SoundDelay[33]

public CheckCuffed(const Name[],const Data[],Len)
{
	if(g_Cuffed[Data[0]])
	{
		client_print(Data[0],print_chat,"[DRP] You can't use items while cuffed.");
		return PLUGIN_HANDLED
	}
	return PLUGIN_CONTINUE
}

// Sounds
public plugin_precache()
	for(new Count;Count < sizeof(g_PoliceSounds);Count++)
		precache_sound(g_PoliceSounds[Count]);

public plugin_init()
{
	// Main
	register_plugin("DRP - Jail Mod","Drak","0.1a");
	
	// Events & Forwards
	DRP_RegisterEvent("Player_Cuffed","EventCuffed");
	DRP_RegisterEvent("Item_Use","CheckCuffed");
	DRP_RegisterEvent("Player_ChangeJobID","EventChangeJobID");
	DRP_RegisterEvent("Player_Salary","EventPlayerSalary");
	
	register_event("DeathMsg","EventDeathMsg","a");
	register_clcmd("Set_Jail_Time","CmdSetJailTime");
	
	DRP_AddCommand("say /jailtime","(COP) - <mintes> - set's the minutes for a user in jail (use ^"0^" for no time)");
	DRP_AddCommand("say /jailrelease","(COP) - releases the user you are looking at (uncuff's/jails)");
	DRP_AddCommand("say /jail","(COP) - Show's the jail menu");
	
	DRP_RegisterChat("/showjail","CmdShowJail","(COP) - Shows the users (on the hud) who are in jail.");
	DRP_RegisterChat("/cuff","CmdCuff","(COP) - Cuffs the user you are looking at.");
	
	DRP_AddChat("","CmdSay");
	
	RegisterHam(Ham_Spawn,"player","EventPlayerSpawn",1);
	RegisterHam(Ham_TakeDamage,"player","EventTakeDamage");
	
	// Menus
	g_FriskMenu = menu_create("","FriskMenuHandle");
	menu_additem(g_FriskMenu,"Allow");
	menu_additem(g_FriskMenu,"Decline");
	menu_setprop(g_FriskMenu,MPROP_EXIT,MEXIT_NEVER);
	
	g_MaxPlayers = get_maxplayers();
	
	#if defined USE_MAPBASED_JAILS
	
	new Ent = -1
	new Targetname[33]
	new Float:Origin[3]
	
	while(( Ent = find_ent_by_class(Ent,"trigger_multiple")) != 0)
	{
		entity_get_string(Ent,EV_SZ_targetname,Targetname,32);
		
		if(containi(Targetname,"prison_") == -1)
			continue
		
		// Hack hack
		// Fill "g_Jails" by the number following "prision_####"
		
		new Temp[1]
		strtok(Targetname,Temp,1,Targetname,32,'_',1);
		
		new Cell = str_to_num(Targetname);
		
		g_JailNum++
		g_Jails[Cell] = Ent
		
		get_brush_entity_origin(Ent,Origin);
		for(new Count;Count < 3;Count++)
			g_JailOrigins[Cell][Count] = Origin[Count]
		
		entity_get_string(Ent,EV_SZ_message,Targetname,32);
		copy(g_JailNames[Cell],32,Targetname);
	}
	#endif
}

public CmdSetJailTime(id)
{
	if(!g_MessageModeTarget[id] || !DRP_IsCop(id))
		return PLUGIN_HANDLED
	
	new Args[12],Index = g_MessageModeTarget[id]
	read_args(Args,11);
	
	remove_quotes(Args);
	trim(Args);
	
	server_print("Args: %s",Args);
	
	g_MessageModeTarget[id] = 0
	
	if(!is_user_alive(Index))
	{
		client_print(id,print_chat,"[DRP] User has disconnected / died.");
		return PLUGIN_HANDLED
	}
	
	if(!is_str_num(Args))
	{
		client_print(id,print_chat,"[DRP] You must enter a number, the time is in minutes.");
		return PLUGIN_HANDLED
	}
	
	new JailTime = str_to_num(Args);
	if(JailTime < 1 || JailTime > 100)
	{
		client_print(id,print_chat,"[DRP] You must enter a valid number. Between 1-100 Minutes.");
		return PLUGIN_HANDLED
	}
	
	new plName[33]
	get_user_name(Index,plName,32);
	
	g_TimeIn[Index] = (JailTime * 60);
	client_print(id,print_chat,"[DRP] You have set %s's jailtime to %d minutes",plName,JailTime);
	
	UpdateJailTime(Index,g_TimeIn[Index]);
	
	return PLUGIN_HANDLED
}

public CmdSay(id,const Args[])
{
	if(Args[0] != '/')
		return PLUGIN_CONTINUE
	
	if(equali(Args,"/jailtime ",10))
	{
		if(!DRP_IsCop(id))
			return PLUGIN_HANDLED
		
		new Index,Body
		get_user_aiming(id,Index,Body,100);
		
		if(!Index || !is_user_alive(Index))
		{
			client_print(id,print_chat,"[DRP] You must be looking at a player.");
			return PLUGIN_HANDLED
		}
		
		new szTime[12]
		parse(Args,Args,1,szTime,11);
		
		new Time = str_to_num(szTime);
		if(Time < 0 || Time > 100)
		{
			client_print(id,print_chat,"[DRP] The time must be zero (no-time) or higher. (Max: 100 Minutes)");
			return PLUGIN_HANDLED
		}
		
		if(g_TimeIn[Index] == (Time * 60))
		{
			client_print(id,print_chat,"[DRP] The user's time is the same time you are setting.");
			return PLUGIN_HANDLED
		}
		
		new plName[33]
		get_user_name(Index,plName,32);
		
		if(Time == 0)
			client_print(id,print_chat,"[DRP] You have set %s's jail time to zero. They will NOT be automatically released.",plName);
		else
			client_print(id,print_chat,"[DRP] You have %s %s's jail time to: %d minutes",(g_TimeIn[Index] > 0) ? "changed" : "set",plName,Time);
		
		client_print(Index,print_chat,"[DRP] Your Jail Timer has been set to: %d Minutes. You will be automatically released.",Time);
		
		// Convert to seconds
		g_TimeIn[Index] = (Time * 60);
		UpdateJailTime(Index,g_TimeIn[Index]);
		
		return PLUGIN_HANDLED
	}
	
	else if(equali(Args,"/jailrelease",12) || equali(Args,"/release",8))
	{
		if(!DRP_IsCop(id))
			return PLUGIN_HANDLED
		
		new Temp[12]
		parse(Args,Args,1,Temp,11);
		
		if(is_str_num(Temp))
		{
			new Cell = str_to_num(Temp);
			if(Cell < 0 || Cell > MAX_JAILS)
			{
				client_print(id,print_chat,"[DRP] Invalid Jail Cell. Unable to release player.");
				return PLUGIN_HANDLED
			}
			
			new Found,PlayerID
			for(new Count;Count <= g_MaxPlayers;Count++)
			{
				if(g_Jailed[Count] == Cell)
				{
					Found++
					PlayerID = Count
				}
			}
			
			if(!Found)
			{
				client_print(id,print_chat,"[DRP] No player's found in cell #%d",Cell);
				return PLUGIN_HANDLED
			}
			if(Found > 1)
			{
				client_print(id,print_chat,"[DRP] Mulitple people are in this cell. Look at a specfic player instead.");
				return PLUGIN_HANDLED
			}
			
			new Name[33],JailerName[33]
			get_user_name(PlayerID,JailerName,32)
			client_print(id,print_chat,"[DRP] You have freed %s from jail.",JailerName)
			
			get_user_name(id,Name,32)
			client_print(PlayerID,print_chat,"[DRP] You have been freed from jail by %s.",Name)
			
			new AuthID[36],JailerAuthID[36]
			get_user_authid(id,AuthID,35)
			get_user_authid(PlayerID,JailerAuthID,35)
			
			DRP_Log("Jail: ^"%s<%d><%s><> freed player ^"%s<%d><%s><>^"",JailerName,get_user_userid(id),JailerAuthID,Name,get_user_userid(PlayerID),AuthID);
			
			entity_set_origin(PlayerID,g_ExitLocation);
			
			FreePlayer(PlayerID);
			return PLUGIN_HANDLED
		}
		
		new Index,Body
		get_user_aiming(id,Index,Body,100);
		
		if(!Index || !is_user_alive(Index))
		{
			client_print(id,print_chat,"[DRP] You must be looking at a player.");
			return PLUGIN_HANDLED
		}
		
		new Name[33],JailerName[33]
		get_user_name(Index,JailerName,32)
		client_print(id,print_chat,"[DRP] You have freed %s from jail.",JailerName)
		
		get_user_name(id,Name,32)
		client_print(Index,print_chat,"[DRP] You have been freed from jail by %s.",Name)
		
		new AuthID[36],JailerAuthID[36]
		get_user_authid(id,AuthID,35)
		get_user_authid(Index,JailerAuthID,35)
		
		DRP_Log("Jail: ^"%s<%d><%s><> freed player ^"%s<%d><%s><>^"",JailerName,get_user_userid(id),JailerAuthID,Name,get_user_userid(Index),AuthID);
		
		entity_set_origin(Index,g_ExitLocation);
		FreePlayer(Index);
		
		return PLUGIN_HANDLED
	}
	else if(equali(Args,"/jail",5))
	{
		if(!DRP_IsCop(id))
			return PLUGIN_HANDLED
		
		if(DRP_GetUserJobID(id) == g_Trainee)
		{
			client_print(id,print_chat,"[DRP] You must be a higher ranked officer to use this.");
			return PLUGIN_HANDLED
		}
		
		new Menu = menu_create("Jail Menu","_HandleJailMenu");
		
		new MenuTitle[64],plName[33]
		new NumID[12]
		new bool:Found
		
		for(new Count,Count2;Count < g_JailNum;Count++)
		{
			for(Count2=0;Count2 <= g_MaxPlayers;Count2++)
			{
				if(g_Jailed[Count2] == Count)
				{
					get_user_name(Count2,plName,32);
					(g_TimeIn[Count2] > 0) ? 
						formatex(MenuTitle,63,"%s -^n(%s - %d %s)^n",g_JailNames[Count],plName,(g_TimeIn[Count2] > 60) ? (g_TimeIn[Count2] / 60) : g_TimeIn[Count2],(g_TimeIn[Count2] > 60) ? "Mins" : "Secs") :
						formatex(MenuTitle,63,"%s -^n%s - NO TIME SET^n",g_JailNames[Count],plName);
					
					num_to_str(Count2,NumID,11);
					menu_addblank(Menu,0);
					menu_additem(Menu,MenuTitle,NumID);
					
					Found = true
				}
			}
			
			// Nobody was in this cell
			if(!Found)
			{
				formatex(MenuTitle,63,"%s: Empty",g_JailNames[Count]);
				menu_additem(Menu,MenuTitle,"-1");
			}
			
			Found = false
		}
		menu_display(id,Menu);
		
		return PLUGIN_HANDLED
	}
	else if(equali(Args,"/frisk",6) || equali(Args,"/search",7))
	{
		if(!DRP_IsCop(id))
		{
			client_print(id,print_chat,"[DRP] You are not an officer.");
			return PLUGIN_HANDLED
		}
		
		new Temp[12]
		parse(Args,Args,1,Temp,11);
		
		new FriskerName[33]
		get_user_name(id,FriskerName,32);
		
		if(is_str_num(Temp))
		{
			new Cell = str_to_num(Temp);
			if(Cell < 0 || Cell > MAX_JAILS)
			{
				client_print(id,print_chat,"[DRP] Invalid Jail Cell. Unable to search.");
				return PLUGIN_HANDLED
			}
			
			new Found,PlayerID
			for(new Count;Count <= g_MaxPlayers;Count++)
			{
				if(g_Jailed[Count] == Cell)
				{
					Found++
					PlayerID = Count
				}
			}
			
			if(!Found)
			{
				client_print(id,print_chat,"[DRP] No player's found in cell #%d",Cell);
				return PLUGIN_HANDLED
			}
			if(Found > 1)
			{
				client_print(id,print_chat,"[DRP] Mulitple people are in this cell. Look at a specfic player instead.");
				return PLUGIN_HANDLED
			}
			
			new plName[33]
			get_user_name(PlayerID,plName,32);
			
			new szTitle[64]
			g_iFrisker[PlayerID] = id
			
			formatex(szTitle,63,"%s would like to search you,^nfor weapons",FriskerName);
			menu_setprop(g_FriskMenu,MPROP_TITLE,szTitle);
			
			client_print(id,print_chat,"[DRP] Weapon search sent to player: %s",plName);
			menu_display(PlayerID,g_FriskMenu);
			
			return PLUGIN_HANDLED
		}
		
		new Index,Body
		get_user_aiming(id,Index,Body,200);
		
		if(!Index || !is_user_alive(Index))
		{
			client_print(id,print_chat,"[DRP] You must enter a cell number, or be looking at a player.");
			return PLUGIN_HANDLED
		}
		
		new szTitle[64]
		g_iFrisker[Index] = id
		
		formatex(szTitle,63,"%s would like to search you,^nfor weapons",FriskerName);
		menu_setprop(g_FriskMenu,MPROP_TITLE,szTitle);
		
		get_user_name(Index,FriskerName,32);
		client_print(id,print_chat,"[DRP] Weapon search sent to player: %s",FriskerName)
		
		menu_display(Index,g_FriskMenu);
		return PLUGIN_HANDLED
	}
	else if(equali(Args,"/handsup"))
	{
		new Float:Time = get_gametime();
		
		if(Time - g_SoundDelay[id] < 2.0 || !DRP_IsCop(id))
			return PLUGIN_HANDLED
			
		new const Random = random(sizeof(g_PoliceSounds))
		emit_sound(id,CHAN_AUTO,g_PoliceSounds[Random],VOL_NORM,ATTN_NONE,0,PITCH_NORM);
		g_SoundDelay[id] = get_gametime();
		
		switch(Random)
		{
			case 0: client_cmd(id,"^"say /shout You are under arrest. Get down and put your hands in the air^"");
			case 1: client_cmd(id,"^"say /shout Get down. Put your hands in the air^"");
			case 2: client_cmd(id,"^"say /shout You are under arrest. Please do not resist.^"");
		}
		
		return PLUGIN_HANDLED
	}
	return PLUGIN_CONTINUE
}
public FriskMenuHandle(id,Menu,Item)
{
	if(Item == MENU_EXIT)
		return PLUGIN_HANDLED
	
	new Names[2][33]
	get_user_name(id,Names[0],32);
	get_user_name(g_iFrisker[id],Names[1],32);
	
	switch(Item)
	{
		case 0:
		{
			client_print(id,print_chat,"[DRP] You are being searched for weapons.");
			client_print(g_iFrisker[id],print_chat,"[DRP] %s has accepted. Searching for weapons..",Names[0]);
			
			new Data[2]
			Data[0] = g_iFrisker[id]
			Data[1] = id
			
			client_cmd(id,"spk ^"weapons/mine_charge.wav^"");
			client_cmd(g_iFrisker[id],"spk ^"weapons/mine_charge.wav^"");
			
			set_task(5.0,"fnFrisk",_,Data,2);
		}
		default:
		{
			client_print(id,print_chat,"[DRP] You have declined the weapon search.");
			client_print(g_iFrisker[id],print_chat,"[DRP] %s has declined the weapon search",Names[0]);
		}
	}
	return PLUGIN_HANDLED
}
public _HandleJailMenu(id,Menu,Item)
{
	if(Item == MENU_EXIT)
	{
		menu_destroy(Menu);
		return PLUGIN_HANDLED
	}
	
	new Info[12],Temp
	menu_item_getinfo(Menu,Item,Temp,Info,11,_,_,Temp);
	menu_destroy(Menu);
	
	new const Index = str_to_num(Info);
	if(Index != -1 && !is_user_alive(Index))
	{
		client_print(id,print_chat,"[DRP] The user has died/disconnected.");
		return PLUGIN_HANDLED
	}
	
	// TODO:
	// Make this do something?
	
	if(Index == -1)
	{
		client_print(id,print_chat,"[DRP] This cell is empty. Teleporting player's is disabled.");
		return PLUGIN_HANDLED
	}
	
	Menu = menu_create("Cell Menu","_HandleJailCellMenu");
	menu_additem(Menu,"Set Jail Time",Info);
	menu_additem(Menu,"Remove player from Jail",Info);
	
	menu_display(id,Menu);
	return PLUGIN_HANDLED
}
public _HandleJailCellMenu(id,Menu,Item)
{
	if(Item == MENU_EXIT)
	{
		menu_destroy(Menu);
		return PLUGIN_HANDLED
	}
	
	new Info[12],Temp
	menu_item_getinfo(Menu,Item,Temp,Info,11,_,_,Temp);
	menu_destroy(Menu);
	
	new const Index = str_to_num(Info);
	if(!is_user_alive(Index))
	{
		client_print(id,print_chat,"[DRP] The user has died/disconnected.");
		return PLUGIN_HANDLED
	}
	
	switch(Item)
	{
		case 0:
		{
			g_MessageModeTarget[id] = Index
			client_cmd(id,"messagemode Set_Jail_Time");
			client_print(id,print_chat,"[DRP] Please type a number for the user's jailtime. (in minutes) then press enter.");
		}
		case 1:
			FreePlayer(Index,id,1);
	}
	return PLUGIN_HANDLED
}

public DRP_Error(const Reason[])
	pause("d");

public DRP_JobsInit()
{
	new Results[1],Found = DRP_FindJobID("MCPD Trainee",Results,1);
	if(!Found || Found > 1)
		return PLUGIN_CONTINUE
	
	if(DRP_ValidJobID(Results[0]))
		g_Trainee = Results[0]
	
	return PLUGIN_CONTINUE
}

public DRP_RegisterItems()
	g_Cuffs = DRP_RegisterItem("Handcuffs","_Cuffs","Used for cuffing players.",0,0,0);

public DRP_Init()
{
	// CVars
	// 0 = don't jail on reconnect
	// 1 = jail on reconnect
	// 2 = jail and cuff on reconnect
	p_Reconnect = register_cvar("DRP_Jail_Reconnect","1");
	
	#if !defined USE_MAPBASED_JAILS
	p_Distance = register_cvar("DRP_Jail_Distance","95.0");
	#endif
	
	p_Cuffs = register_cvar("DRP_Jail_CuffItems","0");
	
	p_CopsOnly = register_cvar("DRP_Jail_CopsOnly","0");
	p_DragPlayers = register_cvar("DRP_Jail_DragPlayers","1");
	p_Confiscate = register_cvar("DRP_Jail_FriskWeapons","1");
	
	new FileName[128]
	DRP_GetConfigsDir(FileName,127);
	add(FileName,127,"/JailMod.ini");
	
	new pFile = fopen(FileName,"r");
	if(!pFile)
		return DRP_ThrowError(1,"Unable to open JailMod.ini File. (%s)",FileName);
	
	new Buffer[128],Left[33],Right[33],Origins[3][11]
	while(!feof(pFile) && g_JailNum < MAX_JAILS)
	{
		fgets(pFile,Buffer,127);
		
		if(Buffer[0] == ';')
			continue
		
		#if defined USE_MAPBASED_JAILS
		if(containi(Buffer,"exit") != -1)
		{
			parse(Buffer,Left,32,Right,32);
			remove_quotes(Right);
			trim(Right);
			
			parse(Right,Origins[0],10,Origins[1],10,Origins[2],10);
			
			for(new Count;Count < 3;Count++)
				g_ExitLocation[Count] = str_to_float(Origins[Count]);
		}
		
		#else
		
		if(containi(Buffer,"[") != -1 && containi(Buffer,"]") != -1)
		{
			replace(Buffer,127,"[","");
			replace(Buffer,127,"]","");
			
			remove_quotes(Buffer);
			trim(Buffer);
			
			copy(g_JailNames[g_JailNum++],32,Buffer);
		}
		else if(containi(Buffer,"origin") != -1)
		{
			parse(Buffer,Left,32,Right,32);
			remove_quotes(Right);
			trim(Right);
			
			parse(Right,Origins[0],10,Origins[1],10,Origins[2],10);
			for(new Count;Count < 3;Count++)
				g_JailOrigins[g_JailNum - 1][Count] = str_to_float(Origins[Count]);
		}
		else if(containi(Buffer,"exit") != -1)
		{
			parse(Buffer,Left,32,Right,32);
			remove_quotes(Right);
			trim(Right);
			
			parse(Right,Origins[0],10,Origins[1],10,Origins[2],10);
			
			for(new Count;Count < 3;Count++)
				g_ExitLocation[Count] = str_to_float(Origins[Count]);
		}
		
		#endif
	}
	fclose(pFile);
	
	g_SqlHandle = DRP_SqlHandle();
	get_mapname(g_MapName,63);
	
	format(g_Query,255,"CREATE TABLE IF NOT EXISTS `JailUsers` (AuthID VARCHAR(36), Cell INT(11), Time INT(11), Map VARCHAR(33), Cuffed INT(11), PRIMARY KEY (AuthID))");
	SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",g_Query);
	
	return PLUGIN_CONTINUE
}
public DRP_HudDisplay(id,Hud)
{
	switch(Hud)
	{
		// HUD for players
		case HUD_PRIM:
		{
			//if(!g_DataGathered[id] || DRP_IsCop(id))
				//return
			
			static JailCell
			JailCell = Proximity(id);
			
			// We are now out of jail - set the SQL
			if((g_Jailed[id] != -1) && (JailCell == -1))
			{
				FreePlayer(id);
				return
			}
			if(JailCell != -1)
			{
				PutInJail(id,JailCell);
				JailCell = (g_TimeIn[id] > 60) ? 1 : 0
				
				// We have time - let's show mins/seconds
				if(g_TimeIn[id] > 0)
					DRP_AddHudItem(id,HUD_PRIM,"Jailed: No Salary (Time: %d %s)",JailCell ? (g_TimeIn[id] / 60) : g_TimeIn[id],JailCell ? "Mins" : "Seconds");
				
				// We won't have time - let's just show the basic's
				else
					DRP_AddHudItem(id,HUD_PRIM,"Jailed: No Salary - %d",g_Jailed[id]);
				
				// Jail Time
				if(g_TimeIn[id] > 0)
				{
					if(--g_TimeIn[id] <= 0)
					{
						FreePlayer(id,_,1);
						return
					}
				}
			}
			if(g_Cuffed[id])
				DRP_AddHudItem(id,HUD_PRIM,"Cuffed");
			
			return
		}
		// HUD for cops to show who's in jail
		case HUD_SEC:
		{
			if(!g_ShowPlayers[id] || !DRP_IsCop(id))
				return
			
			new plName[33]
			DRP_AddHudItem(id,HUD_SEC,"Jail Stats:");
			
			for(new Count;Count <= g_MaxPlayers;Count++)
			{
				if(g_Jailed[Count] == -1 || !is_user_alive(Count))
					continue
				
				get_user_name(Count,plName,32);
				
				if(g_TimeIn[Count] > 0)
				{
					new Mins = (g_TimeIn[Count] > 60) ? 1 : 0
					DRP_AddHudItem(id,HUD_SEC,"%s (#%d - Time: %d %s)",plName,g_Jailed[Count],Mins ? (g_TimeIn[Count] / 60) : g_TimeIn[Count],Mins ? "Mins" : "Secs");
				}
				else
				{
					DRP_AddHudItem(id,HUD_SEC,"%s (Cell: #%d)",plName,g_Jailed[Count]);
				}
			}
		}
	}
}
/*==================================================================================================================================================*/
public client_authorized(id)
{
	if(!get_pcvar_num(p_Reconnect))
		return
	
	g_ShowPlayers[id] = 1
	
	// Delay. For checking if they're a cop
	set_task(5.0,"DelayLoad",id);
}

public DelayLoad(id)
{
	if(DRP_IsCop(id))
		return
	
	new AuthID[36],Data[1]
	get_user_authid(id,AuthID,35);
	Data[0] = id
	
	format(g_Query,255,"SELECT * FROM `JailUsers` WHERE AuthID='%s' AND Map='%s'",AuthID,g_MapName);
	SQL_ThreadQuery(g_SqlHandle,"CheckJail",g_Query,Data,1);
}

public client_disconnect(id)
{
	g_MaxSpeed[id] = 0.0
	
	// Save to SQL - Not on plugin_end tho - since the savedata will do that for us
	if(!DRP_IsCop(id) && g_DataGathered[id])
	{
		if(g_Jailed[id] == -1 && is_user_alive(id))
			g_Jailed[id] = Proximity(id);
		
		if(g_Jailed[id] != -1)
			PutInJail(id,g_Jailed[id]);
	}
	
	g_Jailed[id] = -1
	g_TimeIn[id] = 0
	g_Cuffed[id] = 0
	g_DataGathered[id] = 0
	g_MessageModeTarget[id] = 0
	g_iFrisker[id] = 0
	g_SoundDelay[id] = 0.0
}
/*==================================================================================================================================================*/
public EventPlayerSpawn(const id)
{
	new const mReconnect = get_pcvar_num(p_Reconnect);
	if(g_Jailed[id] == -1 || !is_user_alive(id) || !mReconnect)
		return HAM_IGNORED
	
	entity_set_origin(id,g_JailOrigins[g_Jailed[id]]);
	client_print(id,print_chat,"[DRP] You are in jail%s",g_Cuffed[id] ? " and you are cuffed." : ".");
	
	// Always cuff them when they are in jail
	// we don't want people killing eachother
	if(g_Cuffed[id] || mReconnect < 2)
		return HAM_IGNORED
	
	new Data[3]
	Data[0] = id
	Data[1] = 0
	Data[2] = 1
	
	g_Flag = 1
	
	if(DRP_CallEvent("Player_Cuffed",Data,3))
		return HAM_IGNORED
	
	g_Flag = 0
	
	EventCuffed("",Data,3);
	return HAM_IGNORED
}
public EventTakeDamage(id,inflictor,attacker,Float:damage,Bits)
{
	if(!g_Cuffed[id])
		return HAM_IGNORED
	
	if(Bits & DMG_FALL)
		return HAM_SUPERCEDE
	
	return HAM_IGNORED
}
public EventDeathMsg()
{
	new const id = read_data(2);
	if(!is_user_connected(id))
		return
	
	g_MaxSpeed[id] = 0.0
	g_Cuffed[id] = 0
	
	// If we were in jail - we're not now. I removed the CVar to check this.
	// I might change this based on opnion
	
	if(g_Jailed[id] != -1)
		FreePlayer(id);
}
/*==================================================================================================================================================*/
public _Cuffs(id,ItemID)
	CmdCuff(id,0,"");

public CmdShowJail(id)
{
	if(!DRP_IsCop(id))
	{
		client_print(id,print_chat,"[DRP] You are not a cop.");
		return PLUGIN_HANDLED
	}
	
	g_ShowPlayers[id] = !g_ShowPlayers[id]
	
	client_print(id,print_chat,"[DRP] Jail Status is now %s",g_ShowPlayers[id] ? "on" : "off");
	return PLUGIN_HANDLED
}

public CmdCuff(id,Mode,const Args[])
{
	if(!is_user_alive(id))
	{
		client_print(id,print_chat,"[DRP] You must be alive to cuff.")
		return PLUGIN_HANDLED
	}
	
	if(!DRP_IsCop(id))
	{
		client_print(id,print_chat,"[DRP] You are not a police officer.");
		return PLUGIN_HANDLED
	}
	
	new Index,Body
	get_user_aiming(id,Index,Body,200);
	
	if(!Index || !is_user_alive(Index))
	{
		client_print(id,print_chat,"[DRP] You must be looking at a player.");
		return PLUGIN_HANDLED
	}
	
	new pCuffs = get_pcvar_num(p_Cuffs);
	if(pCuffs > 0 && !DRP_GetUserItemNum(id,g_Cuffs) && !g_MaxSpeed[Index]) // If we need cuffs, and we don't have them, AND the user IS NOT Cuffed
	{
		client_print(id,print_chat,"[DRP] You have no Handcuffs in your inventory.");
		return PLUGIN_HANDLED
	}
	
	if(DRP_IsCop(Index))
	{
		client_print(id,print_chat,"[DRP] You cannot cuff other police officers.")
		return PLUGIN_HANDLED
	}
	
	new Data[3]
	Data[0] = Index
	Data[1] = id
	Data[2] = !g_Cuffed[Index]
	
	g_Flag = 1
	
	if(DRP_CallEvent("Player_Cuffed",Data,3))
		return PLUGIN_HANDLED
	
	g_Flag = 0
	
	EventCuffed("",Data,3);
	
	return PLUGIN_HANDLED
}
/*==================================================================================================================================================*/
public EventPlayerSalary(const Name,const Data[],Len)
{
	if(g_Jailed[Data[0]] != -1)
		return PLUGIN_HANDLED
	
	return PLUGIN_CONTINUE
}
public EventChangeJobID(const Name[],const Data[],Len)
{
	new const id = Data[0]
	if(DRP_IsCop(id))
		g_ShowPlayers[id] = 1
	else
		g_ShowPlayers[id] = 0
}
public EventCuffed(const Name[],const Data[],Len)
{
	if(g_Flag)
		return PLUGIN_CONTINUE
	
	new Index = Data[0],id = Data[1],Cuffed = Data[2]
	if(!Cuffed)
	{
		entity_set_float(Index,EV_FL_maxspeed,g_MaxSpeed[Index]);
		
		g_MaxSpeed[Index] = 0.0
		g_Cuffed[Index] = 0
		
		set_rendering(Index);
		
		if(id)
		{
			new CufferName[33],Name[33]
			get_user_name(id,CufferName,32);
			client_print(Index,print_chat,"[DRP] You have been uncuffed by %s.",CufferName);
			
			get_user_name(Index,Name,32);
			client_print(id,print_chat,"[DRP] You have uncuffed %s.",Name);
			
			if(get_pcvar_num(p_Cuffs) == 1)
				DRP_SetUserItemNum(id,g_Cuffs,DRP_GetUserItemNum(id,g_Cuffs) + 1);
			
			new AuthID[36],CufferAuthID[36]
			get_user_authid(Index,AuthID,35);
			get_user_authid(id,CufferAuthID,35);
			
			DRP_Log("Cuff: ^"%s<%d><%s><> uncuffed player ^"%s<%d><%s><>^"",CufferName,get_user_userid(id),CufferAuthID,Name,get_user_userid(Index),AuthID);
		}
		return PLUGIN_HANDLED
	}
	
	// TODO: We might use something like a "frisk" mod todo this
	// We don't really just poop our weapoms because we got handcuffed
	
	//for(new Count = 1;Count <= 35;Count++)
		//client_cmd(Index,"weapon_%d;drop",Count);
	
	set_rendering(Index,kRenderFxGlowShell,255,0,0,kRenderNormal,16);
	g_MaxSpeed[Index] = (g_MaxSpeed[Index] > 0) ? entity_get_float(id,EV_FL_maxspeed) : 320.0
	g_Cuffed[Index] = 1
	
	if(id)
	{
		new CufferName[33],Name[33]
		get_user_name(id,CufferName,32);
		client_print(Index,print_chat,"[DRP] You have been cuffed by %s.",CufferName);
		
		get_user_name(Index,Name,32);
		client_print(id,print_chat,"[DRP] You have cuffed %s.",Name);
		
		if(get_pcvar_num(p_Cuffs) == 1)
			DRP_SetUserItemNum(id,g_Cuffs,DRP_GetUserItemNum(id,g_Cuffs) - 1);
		
		if(get_pcvar_num(p_DragPlayers))
			set_task(0.1,"CuffFollow",_,Data,2);
		
		new AuthID[36],CufferAuthID[36]
		get_user_authid(Index,AuthID,35);
		get_user_authid(id,CufferAuthID,35);
		
		DRP_Log("Cuff: ^"%s<%d><%s><> cuffed player ^"%s<%d><%s><>^"",CufferName,get_user_userid(id),CufferAuthID,Name,get_user_userid(Index),AuthID);	
	}
	
	return PLUGIN_HANDLED
}
public client_PreThink(id)
{
	if(!(g_MaxSpeed[id] && g_Cuffed[id]) || !is_user_alive(id))
		return
	
	// We have a maxspeed set. slow us down (we are cuffed)
	// If we have cuff follow on - make us alitte bit faster
	
	static Buttons
	Buttons = entity_get_int(id,EV_INT_button);
	
	if(Buttons != 0)
		entity_set_int(id,EV_INT_button,Buttons & ~IN_ATTACK & ~IN_ATTACK2 & ~IN_ALT1 & ~IN_USE & ~IN_JUMP);
	
	// I don't know if there's a better way (probably hook curweapon) - butttt no.
	if(DRP_TSGetUserWeaponID(id))
		engclient_cmd(id,"drop");
	
	// Slow down
	entity_set_float(id,EV_FL_maxspeed,g_MaxSpeed[id] / 2);
}

public CuffFollow(const Params[2])
{
	new const Index = Params[0],id = Params[1]
	
	// This task stops when we enter the jail (but there still cuffed)
	if(!g_MaxSpeed[Index] || g_Jailed[Index] != -1 || !get_pcvar_num(p_DragPlayers))
		return
	
	static Float:Origin[3],Float:IndexOrigin[3]
	entity_get_vector(id,EV_VEC_origin,Origin);
	entity_get_vector(Index,EV_VEC_origin,IndexOrigin);
	
	new Float:Distance = vector_distance(Origin,IndexOrigin);
	if(Distance > 100.0)
	{
		new Float:Velocity[3],Float:Factor
		
		for(new Count;Count < 3;Count++)
		{
			Velocity[Count] = 20.0 * (Origin[Count] - IndexOrigin[Count]);
			
			if(floatabs(Velocity[Count]) > 280.0 && floatabs(Velocity[Count]) >= floatabs(Velocity[0]) && floatabs(Velocity[Count]) >= floatabs(Velocity[1]) && floatabs(Velocity[Count]) >= floatabs(Velocity[2]))
				Factor = floatabs(Velocity[Count]) / 280.0
		}
		if(Factor)
			for(new Count;Count < 3;Count++)
				Velocity[Count] /= Factor
		
		if(Velocity[2] > 0.0)
			Velocity[2] = -floatabs(Velocity[2]);
		
		entity_set_vector(Index,EV_VEC_velocity,Velocity);
	}
	set_task(0.1,"CuffFollow",_,Params,2);
}
/*==================================================================================================================================================*/
public fnFrisk(const iData[])
{
	new const id = iData[0],tid = iData[1]
	if(!is_user_connected(tid))
	{
		client_print(id,print_chat,"[DRP] User has disconnected. Unable to search.");
		return PLUGIN_HANDLED
	}
	
	new Float:fpOrigin[3]
	entity_get_vector(id,EV_VEC_origin,fpOrigin);
	
	new Float:fpTargetOrigin[3]
	entity_get_vector(tid,EV_VEC_origin,fpTargetOrigin);
	
	new szTargetName[32]
	get_user_name(tid,szTargetName,31);
	
	if(vector_distance(fpOrigin,fpTargetOrigin) > 250.0)
	{
		client_print(id,print_chat,"[DRP] You have moved out of %s's range.", szTargetName);
		return PLUGIN_HANDLED
	}

	for(new i = 1; i < 37; i++)
		client_cmd(tid,"weapon_%d;drop",i);

	// Pick these weapons up
	if(!get_pcvar_num(p_Confiscate))
		return PLUGIN_HANDLED
	
	new iData[2]
	iData[0] = id
	iData[1] = tid

	set_task(1.0,"fnConfiscate",_,iData,2);
	return PLUGIN_HANDLED
}
public fnConfiscate(const iData[])
{
	new const id = iData[0],tid = iData[1]

	new Float:fpOrigin[3]
	entity_get_vector(tid,EV_VEC_origin,fpOrigin);

	new szModel[12],iEnt,iConfiscated
	
	while((iEnt = find_ent_in_sphere(iEnt,fpOrigin,250.0)) != 0)
	{
		entity_get_string(iEnt,EV_SZ_model,szModel,11);
		
		if(containi(szModel,"w_") != -1)
		{
			remove_entity(iEnt)
			iConfiscated++
		}
	}
	
	new szName[32]
	get_user_name(id,szName,31);

	new szTargetName[32]
	get_user_name(tid,szTargetName,31);

	if(iConfiscated)
	{
		client_print(id,print_chat,"[DRP] You confiscated %d weapon%s from %s.",iConfiscated,iConfiscated > 1 ? "s" : "",szTargetName);
		client_print(tid,print_chat,"[DRP] %d weapon%s %s been confiscated.",iConfiscated,iConfiscated > 1 ? "s" : "",iConfiscated > 1 ? "have" : "has");
	}
	else
	{
		client_print(id,print_chat,"[DRP] You found no weapons on %s.",szTargetName);
		client_print(tid,print_chat,"[DRP] %s has found zero weapons",szName);
	}
}
/*==================================================================================================================================================*/
public IgnoreHandle(FailState,Handle:Query,const Error[],Errcode,const Data[],DataSize)
	if(FailState != TQUERY_SUCCESS)
		DRP_ThrowError(0,"Error on Query. (ERROR: %s)",Error ? Error : "UNKNOWN");

public CheckJail(FailState,Handle:Query,const Error[],Errcode,const Data[],DataSize) 
{
	if(FailState != TQUERY_SUCCESS)
		DRP_ThrowError(0,"Error on Query. (ERROR: %s)",Error ? Error : "UNKNOWN");
	
	new const id = Data[0]
	g_DataGathered[id] = 1
	
	if(!SQL_NumResults(Query))
		return PLUGIN_CONTINUE
	
	new JailCell = SQL_ReadResult(Query,1);
	if(JailCell == -1 || JailCell > g_JailNum)
		return DRP_ThrowError(0,"Invalid Jail Cell (Max: %d - Got: %d)",g_JailNum,JailCell);
	
	g_Jailed[id] = JailCell
	g_TimeIn[id] = SQL_ReadResult(Query,2);
	g_Cuffed[id] = SQL_ReadResult(Query,4);
	
	return PLUGIN_CONTINUE
}

#if defined USE_MAPBASED_JAILS

Proximity(const id)
{
	new List[1]
	
	if(find_sphere_class(id,"trigger_multiple",1.0,List,1))
	{
		new const FoundEnt = List[0]
		for(new Count;Count < g_JailNum;Count++)
		{
			if(g_Jails[Count] == FoundEnt)
				return Count
		}
	}
	return -1
}

#else

Proximity(const id)
{
	static Float:Origin[3]
	entity_get_vector(id,EV_VEC_origin,Origin);
	
	for(new Count;Count < g_JailNum;Count++)
	{
		if(vector_distance(Origin,g_JailOrigins[Count]) < get_pcvar_float(p_Distance))
			return Count
	}
	return -1
}

#endif

FreePlayer(Index,Releaser=0,Teleport=0)
{
	if(g_Jailed[Index] == -1)
		return PLUGIN_HANDLED
	
	new AuthID[36]
	get_user_authid(Index,AuthID,35);
	
	server_print("Free; %s",AuthID);
	
	format(g_Query,255,"DELETE FROM `JailUsers` WHERE AuthID='%s' AND `Map`='%s'",AuthID,g_MapName);
	SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",g_Query);
	
	g_Jailed[Index] = -1
	g_TimeIn[Index] = 0
	
	if(Teleport)
		entity_set_origin(Index,g_ExitLocation);
	
	// Make sure we get uncuffed too
	if(g_Cuffed[Index] && Teleport)
	{
		new Data[3]
		Data[0] = Index
		Data[1] = 0
		Data[2] = 0
		
		g_Flag = 1
		
		if(DRP_CallEvent("Player_Cuffed",Data,3))
			return PLUGIN_HANDLED
		
		g_Flag = 0
		
		EventCuffed("",Data,3);
	}
	
	if(Releaser)
	{
		new id = Releaser
		
		new Name[33],JailerName[33]
		get_user_name(Index,JailerName,32)
		client_print(id,print_chat,"[DRP] You have freed %s from jail.",JailerName)
		
		get_user_name(id,Name,32)
		client_print(Index,print_chat,"[DRP] You have been freed from jail by %s.",Name)
		
		new AuthID[36],JailerAuthID[36]
		get_user_authid(id,AuthID,35)
		get_user_authid(Index,JailerAuthID,35)
		
		DRP_Log("Jail: ^"%s<%d><%s><> freed player ^"%s<%d><%s><>^"",JailerName,get_user_userid(id),JailerAuthID,Name,get_user_userid(Index),AuthID);
		
		entity_set_origin(Index,g_ExitLocation);
	}
	
	return PLUGIN_HANDLED
}

PutInJail(const id,const JailCell)
{
	if(g_Jailed[id] == JailCell)
		return
	
	new SteamID[36]
	get_user_authid(id,SteamID,35);
	
	g_Jailed[id] = JailCell
	
	formatex(g_Query,255,"INSERT INTO `JailUsers` VALUES('%s','%d','%d','%s','%d') ON DUPLICATE KEY UPDATE `Cell`='%d',`Cuffed`='%d',`Time`='%d'",
	SteamID,JailCell,g_TimeIn[id],g_MapName,g_Cuffed[id],JailCell,g_Cuffed[id],g_TimeIn[id]);
	
	SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",g_Query);
	
	server_print("QUERY");
}

UpdateJailTime(Target,TimeInSeconds)
{
	if(!is_user_connected(Target))
		return
	
	new AuthID[36]
	get_user_authid(Target,AuthID,35);
	
	format(g_Query,255,"UPDATE `jailusers` SET `Time`='%d' WHERE `AuthID`='%s'",TimeInSeconds,AuthID);
	SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",g_Query);
}