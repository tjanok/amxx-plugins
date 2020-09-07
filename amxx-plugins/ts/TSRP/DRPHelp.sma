#include <amxmodx>
#include <DRP/DRPCore>

new g_MotdDir[256]
new g_Menu

public plugin_init()
{
	// Main
	register_plugin("DRP - Help Menu","0.1a","Drak");
	
	// Commands
	DRP_RegisterCmd("say /help","CmdHelp","Displays a help menu");
	
	LoadMenu();
}
/*==================================================================================================================================================*/
public CmdHelp(id)
{
	if(g_Menu == INVALID_HANDLE)
	{
		client_print(id,print_chat,"[DRP] There are currently no help files.");
		return PLUGIN_HANDLED
	}
	menu_display(id,g_Menu);
	return PLUGIN_HANDLED
}
/*==================================================================================================================================================*/
public _HelpMenu(id,Menu,Item)
{
	if(Item == MENU_EXIT)
		return PLUGIN_HANDLED
	
	static File[256],Temp
	menu_item_getinfo(Menu,Item,Temp,File,255,_,_,Temp);
	
	format(File,255,"%s/Help-%s.txt",g_MotdDir,File);
	show_motd(id,File,"DRP");
	
	return PLUGIN_HANDLED
}
/*==================================================================================================================================================*/
LoadMenu()
{
	g_Menu = menu_create("Choose a Help File","_HelpMenu");
	
	new Buffer[64],Temp[33]
	get_localinfo("amxx_configsdir",g_MotdDir,255);
	
	// This DIR is created by the core - no need to check if it exists
	add(g_MotdDir,255,"/DRP/MOTD");
	
	new OpenDIR = open_dir(g_MotdDir,Temp,32),bool:Found = false
	while(next_file(OpenDIR,Buffer,63))
	{
		if(!(containi(Buffer,"Help-") != -1))
			continue
		
		Found = true
		strtok(Buffer,Buffer,63,Temp,32,'-');
		
		// Remove .txt
		while(replace(Temp,32,".txt","")) {}
		menu_additem(g_Menu,Temp,Temp);
	}
	if(!Found)
		{ menu_destroy(g_Menu); g_Menu = INVALID_HANDLE; }
}

public plugin_end()
	if(g_Menu != INVALID_HANDLE)
		menu_destroy(g_Menu);