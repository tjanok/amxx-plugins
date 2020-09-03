#include <amxmodx>
#include <fakemeta>

#include <DRP/DRPCore>

#define MAP_NAME "meck_tutv1"
new const Float:g_MainOrigin[3] = {-5.0,-41.0,36.0}

new g_Cache[128]

public plugin_precache()
{
	precache_model("models/DRP/DRPDrakRobo.mdl");
	
	new Ent = engfunc(EngFunc_CreateNamedEntity,engfunc(EngFunc_AllocString,"info_target"));
	
	engfunc(EngFunc_SetModel,Ent,"models/DRP/DRPDrakRobo.mdl");
	engfunc(EngFunc_SetOrigin,Ent,g_MainOrigin);
	engfunc(EngFunc_SetSize,Ent,Float:{-16.0,-16.0,-36.0},Float:{16.0,16.0,36.0});
	
	set_pev(Ent,pev_solid,SOLID_BBOX) //Zone ? SOLID_TRIGGER : SOLID_BBOX);
	
	set_pev(Ent,pev_controller_0,125);
	set_pev(Ent,pev_controller_1,125);
	set_pev(Ent,pev_controller_2,125);
	set_pev(Ent,pev_controller_3,125);
	
	new Float:Angles[3]
	Angles[1] = -90.0
	set_pev(Ent,pev_angles,Angles);
	
	set_pev(Ent,pev_sequence,1);
	set_pev(Ent,pev_framerate,1.0);
	engfunc(EngFunc_DropToFloor,Ent);
}

public plugin_init()
{
	new Mapname[33]
	get_mapname(Mapname,32);
	
	if(!equali(Mapname,MAP_NAME))
		set_fail_state("Not the correct map");
	
	register_forward(FM_PlayerPreThink,"forward_PreThink");
}
public forward_PreThink(id)
{
	if(!is_user_alive(id))
		return
	
	if(!(pev(id,pev_button) & IN_USE && !(pev(id,pev_oldbuttons) & IN_USE)))
		return
	
	static Float:Origin[3]
	pev(id,pev_origin,Origin);
	
	if(get_distance_f(Origin,g_MainOrigin) > 85.0)
		return
	
	new Name[33]
	get_user_name(id,Name,32);
	
	format(g_Cache,127,"Hello %s,^nMy name is Drak.^nHow may I help you?",Name);
	
	new Menu = menu_create(g_Cache,"_MainMenu");
	menu_additem(Menu,"What am I doing here?");
	menu_additem(Menu,"Who am I?");
	menu_additem(Menu,"Teleport me to the mainland (Main Server)");
	menu_display(id,Menu);
}
public _MainMenu(id,Menu,Item)
{
	menu_destroy(Menu);
	
	if(Item == MENU_EXIT)
		return PLUGIN_HANDLED
	
	switch(Item)
	{
		case 0: DRP_ShowMOTDHelp(id,"TUT1.txt");
		case 1: DRP_ShowMOTDHelp(id,"TUT2.txt");
		case 2: DRP_ShowMOTDHelp(id,"TUT3.txt");
	}
	return PLUGIN_HANDLED
}