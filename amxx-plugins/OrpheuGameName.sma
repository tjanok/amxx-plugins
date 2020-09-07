#include <amxmodx>
#include <orpheu>
#include <orpheu_memory>

new p_OriginalName
new p_NewName
 
public plugin_precache()
{
	p_OriginalName = register_cvar("amxx_game_name","");
	p_NewName = register_cvar("amxx_game_newname","My Game");
	
	new OrpheuFunction:Game = OrpheuGetFunction(
}

public plugin_init()
{
	// Main
	register_plugin("Orpheu GameName Changer","0.1a","Drak");
	
	// Hooks
	new OriginalName[33],NewName[33]
	get_pcvar_string(p_OriginalName,OriginalName,32);
	get_pcvar_string(p_NewName,NewName,32);
	
	// No name given - try to detect
	if(!OriginalName[0])
	{
		get_modname(OriginalName,32);
		if(containi(OriginalName,"cstrike") != -1)
			copy(OriginalName,32,"Counter-Strike");
		else if(containi(OriginalName,"dod") != -1)
			copy(OriginalName,32,"Day of Defeat");
		else if(containi(OriginalName,"tfc") != -1)
			copy(OriginalName,32,"Team Fortress Classic");
		else if(containi(OriginalName,"ts") != -1)
			copy(OriginalName,32,"The Specialists (DM)");
		else
		{
			server_print("[OrpheuGameName] Unable to find mod name. Please set ^"amx_game_name^" to the default name of the game.");
			return
		}
	}
	server_print("[OrpheuGameName] Name: %ssuccessfully changed", (OrpheuMemoryReplace("nameString",0,OriginalName,NewName)) ? "" : "un");
	return
}