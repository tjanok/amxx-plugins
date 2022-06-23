#include <amxmodx>
#include <hamsandwich>
#include <DRP/DRPCore>

new g_NewPlayer[33]
new g_Menu

public plugin_init()
{
	register_plugin("DRP - New Players","0.1a","Drak");
	
	// Commands
	DRP_RegisterCmd("say /binds","CmdBinds","Binds your numbers to use for menus. (USE IF YOU ARE UNABLE TO USE MENUS)");
	
	// Events
	DRP_RegisterEvent("DRP_NewPlayer","NewPlayerEvent");
	RegisterHam(Ham_Spawn,"player","PlayerSpawnEvent",1);
	
	g_Menu = menu_create("Welcome to DRP","_NewMenuHandle");
	
	menu_additem(g_Menu,"World Information");
	menu_additem(g_Menu,"Help");
	menu_additem(g_Menu,"Where am I? (About TSRP)");
	
	menu_addtext(g_Menu,"^nTips:^n^nIf you are unable to select any^nof these options,please^ntype ^"/binds^" in the chat.^n^nFor further help, type ^"/help^"",0);
	menu_addtext(g_Menu,"You must have a first and last name",0);
}

public client_disconnect(id)
{
	g_NewPlayer[id] = 0
	if(task_exists(id + 6468)) 
		remove_task(id + 6468);
}

public NewPlayerEvent(const Name[],const Data[],const Len)
	g_NewPlayer[Data[0]] = 1

public PlayerSpawnEvent(const id)
{
	if(!g_NewPlayer[id])
		return
	
	if(is_user_alive(id))
		if(!task_exists(id + 6468)) 
			set_task(2.0,"CheckForMenu",id + 6468,"",_,"a",10);
}

public CheckForMenu(id)
{
	id -= 6468
	
	new Menu,NewMenu,Temp,InMenu = player_menu_info(id,Menu,NewMenu,Temp);
	
	if(InMenu)
		return
	else
	{
		if(task_exists(id + 6468)) 
			remove_task(id + 6468);
		
		menu_display(id,g_Menu);
		g_NewPlayer[id] = 0; // don't show again
	}

}

/*==================================================================================================================================================*/
public _NewMenuHandle(id,Menu,Item)
{
	if(Item == MENU_EXIT || !is_user_alive(id))
		return PLUGIN_HANDLED
	
	
	switch(Item)
	{
		case 0: DRP_ShowMOTDHelp(id,"WorldInfo.txt");
		case 1: DRP_ShowMOTDHelp(id,"Help.txt");
		case 2: DRP_ShowMOTDHelp(id,"AboutTSRP.txt");
	}
	
	menu_display(id,Menu);
	return PLUGIN_HANDLED
}
/*==================================================================================================================================================*/
// Very Cheap - But needed??
public CmdBinds(id)
{
	client_cmd(id,"bind 0 slot10");
	
	for(new Count=1;Count < 9;Count++)
		client_cmd(id,"wait;wait;wait;bind %d slot%d",Count,Count);
	
	client_print(id,print_chat,"[DRP] You have binded your numbers 0-9. You will now be able to use menus.");
	return PLUGIN_HANDLED
}
public plugin_end()
	menu_destroy(g_Menu);