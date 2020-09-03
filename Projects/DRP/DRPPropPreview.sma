#include <amxmodx>
#include <DRP/DRPChat>
#include <DRP/DRPCore>
#include <engine>

#define RENT_TIME 5 // In Minutes

public plugin_init()
{
	// Main
	register_plugin("DRP - Property Preview","0.1a","Drak");
	
	// Commands
	DRP_RegisterChat("/preview","CmdPreview","- aim at a property, this allows you to preview it");
}

public CmdPreview(const id)
{
	if(!is_user_alive(id))
		return PLUGIN_HANDLED
	
	new Property,Body
	get_user_aiming(id,Property,Body,100);
	
	if(!Property)
		return PLUGIN_HANDLED
	
	Property = DRP_PropertyMatch(_,Property);
	if(!Property)
	{
		client_print(id,print_chat,"[DRP] You must be looking at a property.");
		return PLUGIN_HANDLED
	}
	
	// TODO:
	// This does not take in-account for rentable property's
	if(DRP_PropertyGetOwner(Property) || (DRP_PropertyGetPrice(Property) > 0))
	{
		client_print(id,print_chat,"[DRP] Unable to preview this property.");
		return PLUGIN_HANDLED
	}
}
	
	