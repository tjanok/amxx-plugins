#include <amxmodx>
new p_Message

public plugin_precache()
	p_Message = register_cvar("DRP_DisconnectMsg","");
public plugin_init()
	register_plugin("DRP - Disconnect Msg","0.1a","Drak");

public client_putinserver(id)
{
	static Message[128]
	get_pcvar_string(p_Message,Message,127);
	
	// Use amx_kick :)
	if(Message[0])
		server_cmd("kick #%d ^"%s^"",get_user_userid(id),Message);
}