/////////////////////////////////////////////
// DRPSpawn.sma
// ----------------------
//
// Used only for mecklenburgd_xxx series map(s)
// It will select a spawn point with the least amount of players around
//

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>

public plugin_init()
{
	register_plugin("DRP - Spawning","0.1a","Drak");
	
	new MapName[16]
	get_mapname(MapName,15);
	
	if(!(containi(MapName,"mecklenburgd_") != -1))
		return pause("d");
	
	RegisterHam(Ham_Spawn,"player","Player_Spawn",1);
	return PLUGIN_CONTINUE
}
54321
public Player_Spawn(const id)
{
	if(!is_user_alive(id))
		return
	
	client_print(id,print_chat,"Spawned - ID: %d",id);
}