////////////////////////////////////////////////////////////////////
// DRPSModExtras.sma
// ---------------------------
// Add's functionality to Skills Mod
// NOTES:
// I use nVault to control the timeouts (You must wait xx amount of seconds todo this again) (instead of something inside the database)

#include <amxmodx>
#include <engine>
#include <nvault>

#include <DRP/DRPCore>
#include <DRP/DRPChat>
#include <DRP/DRPSMod>
#include <DRP/DRPNpc>

#define BOOK_BASIC (1<<0)
#define BOOK_SCIENCE (1<<1)
#define BOOK_LAW (1<<2)
#define BOOK_COOKING (1<<3)

enum
{
	ACTION_NONE,
	ACTION_READING,
	ACTION_HACKING
}

new g_UserAction[33]

// Menus
new g_SkillMenu
new g_SkillUseMenu

// Items
new g_Laptop

// Teacher job
// This job is created within this plugin.
// If you have this job you are able to teach yourself (and other people) skills without the use of books
new g_Teacher

// Precaches
new m_Fire

public plugin_init()
{
	// Main
	register_plugin("DRP - SMod Extras","0.1a","Drak");
	
	// Commands
	DRP_AddCommand("say /skills","Opens the menu to Skills Mod");
	DRP_AddCommand("say /education","Allows teachers to teach themselves / others");
	DRP_AddChat("","CmdSay");
	
	// Menus
	g_SkillMenu = menu_create("Skills Menu","_SMenuHandle");
	menu_additem(g_SkillMenu,"View my Skills");
	menu_additem(g_SkillMenu,"Use my Skills");
	menu_additem(g_SkillMenu,"Help");
	
	g_SkillUseMenu = menu_create("Use Skills","_UseSkills");
	menu_additem(g_SkillUseMenu,"Job Opportunities");
	menu_additem(g_SkillUseMenu,"Item Creation");
	menu_additem(g_SkillUseMenu,"Weapon Creation");
	menu_additem(g_SkillUseMenu,"Cooking");
	menu_additem(g_SkillUseMenu,"Drugs");
	menu_addtext(g_SkillUseMenu,"^nNOTE: Some skills are passive^nIE: Running Faster / Doing more damage");
	
	// Events
	DRP_RegisterEvent("Menu_Display","EventMenuDisplay");
}

public plugin_precache()
{
	// Precaches
	m_Fire = precache_model(g_FireSprite);
	
	new ConfigsDir[256]
	DRP_GetConfigsDir(ConfigsDir,255);
	
	// File created inside "DRPSMod.amxx"
	add(ConfigsDir,255,"/SM_Settings.cfg");
	
	// LOAD FILE HERE
	// TODO: I hard-coded all the "zones"
	// I only exec the file to load the CVars
	// This is very very bad, but I'm in a rush
	
	// Zones
	new Float:Origins[3]
	// ApartG Books [Basic & Science]
	Origins = Float:{ 561.0,2732.0, -347.0 }
	new Ent = DRP_RegisterNPC("Book Shelf",Origins,0.0,"none","BookHandle",1,_,1);
	entity_set_string(Ent,EV_SZ_message,"ab");
	
	
	server_cmd("exec ^"%s^"",ConfigsDir);
}
	
public DRP_Error(const Reason[])
	pause("d");

public DRP_JobsInit()
{
	new Found = DRP_FindJobID2("Teacher");
	if(!Found)
		DRP_ThrowError(0,"Unable to find teacher job");
	else
		g_Teacher = Found
}

public DRP_HudDisplay(id,Hud)
{
}

public DRP_RegisterItems()
{
	g_Laptop = DRP_RegisterItem("Laptop","_Computer","A portable computer");
}

/*==================================================================================================================================================*/
// Commands
public CmdSay(id,Args[])
{
	if(Args[0] != '/')
		return PLUGIN_CONTINUE
	
	if(equali(Args,"/skills",7))
	{
		DRP_ShowUserSkills(id,id);
		return PLUGIN_HANDLED
	}
	else if(equali(Args,"/skillsmenu",11) || equali(Args,"/useskills",10))
	{
		menu_display(id,g_SkillMenu);
		return PLUGIN_HANDLED
	}
	else if(equali(Args,"/education",10) || equali(Args,"/offereducation",15))
	{
		if(DRP_GetUserJobID(id) != g_Teacher)
		{
			client_print(id,print_chat,"[DRP] You must be a teacher to use this.");
			return PLUGIN_HANDLED
		}
	}
	
	return PLUGIN_CONTINUE
}

/*==================================================================================================================================================*/
public EventMenuDisplay(const Name[],const Data[],Len)
	DRP_AddMenuItem(Data[0],"Skills Mod","Forward_Menu");

public Forward_Menu(id)
	menu_display(id,g_SkillMenu);

/*==================================================================================================================================================*/
// Menu Handles
public _SMenuHandle(id,Menu,Item)
{
	if(Item == MENU_EXIT)
		return PLUGIN_HANDLED
	
	switch(Item)
	{
		case 0: 
			DRP_ShowUserSkills(id,id);
		case 1:
			menu_display(id,g_SkillUseMenu);
		case 2: 
			DRP_ShowMOTDHelp(id,"DRPSMod_Help.txt");
	}
	
	return PLUGIN_HANDLED
}
public _UseSkills(id,Menu,Item)
{
}
public _BookHandle(id,Menu,Item)
{
}
/*==================================================================================================================================================*/
// NPC Handles
public BookHandle(id,Ent)
{
	new szFlags[12]
	entity_get_string(Ent,EV_SZ_message,szFlags,11);
	
	new Flags = read_flags(szFlags)
	new Menu = menu_create("Books^nSelect a book you wish to read","_BookHandle");
	
	if(Flags & BOOK_BASIC)
		menu_additem(Menu,"Basic Knowledge","1");
	if(Flags & BOOK_COOKING)
		menu_additem(Menu,"Cooking","2");
	if(Flags & BOOK_LAW)
		menu_additem(Menu,"Law","3");
	if(Flags & BOOK_SCIENCE)
		menu_additem(Menu,"Science","4");
	
	menu_display(id,Menu);
}
/*==================================================================================================================================================*/
public plugin_end()
	menu_destroy(g_SkillMenu);