#include <amxmodx>

#define MAX_ATTEMPTS 2

new g_Attempts[33]
new p_Password

public plugin_precache()
	p_Password = get_cvar_pointer("rcon_password");

public plugin_init()
	register_plugin("DRP - Rcon Blocker","0.1a","Drak");

public client_disconnect(id)
	g_Attempts[id] = 0

public client_command(id)
{
	static Command[6]
	read_argv(0,Command,5);
	
	server_print("C: %s",Command);
	
	if(!equali(Command,"rcon"))
		return PLUGIN_CONTINUE
	
	new Password[24]
	parse(Command,5,Command,1,Password,23);
	
	server_print("Typed Rcon: %s",Password);
	
	new cvarPassword[24]
	get_pcvar_string(p_Password,cvarPassword,23);
	
	if(!equali(Password,cvarPassword))
	{
		if(++g_Attempts[id] >= MAX_ATTEMPTS)
		{
		}
	}
	
	return PLUGIN_CONTINUE
}