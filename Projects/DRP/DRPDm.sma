#include <amxmodx>
#include <fakemeta>
#include <DRP/DRPCore>
#include <DRP/DRPChat>

new Handle:g_SqlHandle
new g_dmMenu

new g_myKiller[33]
new g_allowKill[33]
new g_myKills[33]

public plugin_init()
{
	// Main
	register_plugin("DRP - DM Control","0.1a","Drak");
	
	// Commands
	DRP_RegisterCmd("DRP_ShowDMLevels","CmdViewDM","(ADMIN) - Shows a window with players, and there DM Level");
	DRP_RegisterChat("/allowkilling","CmdAllowKill","This allows you to not be monitored by ^"dm control^". Useful for fights/goofing around");
	
	// Menu
	g_dmMenu = menu_create("","EventHandleMenu");
	menu_additem(g_dmMenu,"Yes");
	menu_additem(g_dmMenu,"No");
	menu_setprop(g_dmMenu,MPROP_EXIT,MEXIT_NEVER);
	
	// Events
	register_event("DeathMsg","EventDeathMsg","a","1>0");
}

public DRP_Error(const Reason[])
	pause("d");

public DRP_HudDisplay(id,Hud)
{
	if(Hud != HUD_PRIM)
		return
	
	if(g_myKills[id])
		DRP_AddHudItem(id,HUD_PRIM,"DM Level: %d",g_myKills[id]);
}

public DRP_Init()
{
	g_SqlHandle = DRP_SqlHandle();
}

/*==================================================================================================================================================*/
public CmdViewDM(id)
{
	if(!DRP_IsAdmin(id))
		return PLUGIN_HANDLED
	
	new iPlayers[32],plName[33],szMenu[256],iNum,Player,Pos
	get_players(iPlayers,iNum);
	
	for(new Count;Count < iNum;Count++)
	{
		Player = iPlayers[Count]
		get_user_name(Player,plName,32);
		
		Pos += formatex(szMenu[Pos],255 - Pos,"%s: Level: #%d^n",plName,g_myKills[Player]);
	}
	
	show_motd(id,szMenu,"Deathmatch Levels");
	return PLUGIN_HANDLED
}
public CmdAllowKill(id)
{
	g_allowKill[id] = !g_allowKill[id]
	client_print(id,print_chat,"[DRP] DM Control: You are%sbeing monitored",g_allowKill[id] ? " not " : " ");
	return PLUGIN_HANDLED
}
/*==================================================================================================================================================*/
public EventHandleMenu(id,Menu,Item)
{
	if(!is_user_connected(g_myKiller[id]))
	{
		client_print(id,print_chat,"[DRP] DM Control: Your ^"killer^" has disconnected.");
		g_myKiller[id] = 0
		return PLUGIN_HANDLED
	}
	
	switch(Item)
	{
		case 1:
		{
			new Names[33]
			get_user_name(id,Names,32);
			
			client_print(g_myKiller[id],print_chat,"[DRP] You have been excused for killing: %s",Names);
			get_user_name(g_myKiller[id],Names,32);
			client_print(id,print_chat,"[DRP] You have excused ^"%s^" for killing you.",Names);
			
			g_myKiller[id] = 0
		}
		case 0:
		{
		}
	}
	return PLUGIN_HANDLED
}
public EventDeathMsg()
{
	new Killer = read_data(1),Victim = read_data(2);
	
	//if(g_allowKill[Victim] || DRP_IsCop(Killer) || DRP_IsAdmin(Killer))
	//	return PLUGIN_CONTINUE
	
	g_myKiller[Victim] = Killer
	
	// Show DM Menu
	static Title[128],plName[33]
	get_user_name(Killer,plName,32);
	
	formatex(Title,127,"You have died^nWere you ^"Deathmatched^" (DM) by^n%s?",plName);
	menu_setprop(g_dmMenu,MPROP_TITLE,Title);
	
	menu_display(Victim,g_dmMenu);
	return PLUGIN_CONTINUE
}