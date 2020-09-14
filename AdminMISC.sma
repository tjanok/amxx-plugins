#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fun>

public plugin_init()
{
	register_plugin("Admin Tools","0.1a","Drak");
	
	// Basic Admin Commands
	register_concmd("amx_noclip","CmdGeneral",ADMIN_BAN,"<target> - Un/Noclips the target.");
	register_concmd("amx_godmode","CmdGeneral",ADMIN_BAN,"<target> - Un/Gods the target.");
	register_concmd("amx_forceuse","CmdForceUse",ADMIN_BAN,"- Force uses the entity in your view.");
	register_concmd("amx_entinfo","CmdEntInfo",ADMIN_BAN,"- Lists off information about the entity you're looking at.");
	register_concmd("amx_myorigin","CmdMyOrigin",ADMIN_BAN,"- Returns YOUR Current origin");
	register_concmd("amx_slay","CmdSlay",ADMIN_BAN,"<target> - slays the target");
	register_concmd("amx_exec","CmdExec",ADMIN_BAN,"<target> <command> <argument 1> - forces a command");
	
}
public CmdExec(id,level,cid)
{
	if(!cmd_access(id,level,cid,4))
		return PLUGIN_HANDLED
	
	new Temp[64]
	read_argv(1,Temp,63);
	
	new Target = cmd_target(id,Temp,CMDTARGET_ALLOW_SELF);
	if(!Target)
		return PLUGIN_HANDLED
	
	read_argv(2,Temp,63);
	
	new Argument[33]
	read_argv(3,Argument,32);
	
	new plName[33]
	get_user_name(Target,plName,32);
	engclient_cmd(Target,Temp,Argument);
	
	client_print(id,print_console,"[AMXX] Command: ^"%s^" sent to %s",Temp,plName);
	return PLUGIN_HANDLED
}
public CmdGeneral(id,level,cid)
{
	if(!cmd_access(id,level,cid,2))
		return PLUGIN_HANDLED
	
	new Arg[33]
	read_argv(1,Arg,32);
	
	new Target = cmd_target(id,Arg,CMDTARGET_ALLOW_SELF);
	if(!Target)
		return PLUGIN_HANDLED
	
	read_argv(0,Arg,32);
	
	switch(Arg[4])
	{
		case 'n':
		{
			new Noclip = get_user_noclip(Target);
			if(Noclip)
				set_user_noclip(Target);
			else
				set_user_noclip(Target,1);
			
			get_user_name(Target,Arg,32);
			client_print(id,print_console,"[AMXX] Noclip for %s turned %s",Arg,Noclip ? "Off" : "On");
		}
		case 'g':
		{
			new Godmode = get_user_godmode(Target);
			if(Godmode)
				set_user_godmode(Target);
			else
				set_user_godmode(Target,1);
			
			get_user_name(Target,Arg,32);
			client_print(id,print_console,"[AMXX] God for %s turned %s",Arg,Godmode ? "Off" : "On");
		}
	}
	return PLUGIN_HANDLED
}
public CmdForceUse(id,level,cid)
{
	if(!cmd_access(id,level,cid,1))
		return PLUGIN_HANDLED
	
	new Index,Body
	get_user_aiming(id,Index,Body,200);
	
	new Arg[33]
	read_argv(1,Arg,32);
	
	if(Arg[0])
		Index = find_ent_by_tname(-1,Arg);
	
	if(!is_valid_ent(Index))
	{
		client_print(id,print_chat,"[AMXX] Invalid Entity");
		return PLUGIN_HANDLED
	}
	
	force_use(Index,Index);
	client_print(id,print_chat,"[AMXX] Entity Used");
	
	return PLUGIN_HANDLED
}
public CmdEntInfo(id,level,cid)
{
	if(!cmd_access(id,level,cid,2))
		return PLUGIN_HANDLED
	
	new Index,Body
	get_user_aiming(id,Index,Body,200);
	
	if(!Index)
	{
		client_print(id,print_console,"[AMXX] Invalid Entity");
		return PLUGIN_HANDLED
	}
	
	new Temp[33]
	entity_get_string(Index,EV_SZ_classname,Temp,32);
	client_print(id,print_console,"[AMXX] Entity Type (Classname): %s^n[AMXX] EntID: %d",Temp,Index);
	
	entity_get_string(Index,EV_SZ_targetname,Temp,32);
	client_print(id,print_console,"[AMXX] Targetname: %s",Temp[0] ? Temp : "NULL");

	entity_get_string(Index,EV_SZ_target,Temp,32);
	client_print(id,print_console,"[AMXX] Target: %s",Temp[0] ? Temp : "NULL");
	return PLUGIN_HANDLED
}
public CmdMyOrigin(id,level,cid)
{
	if(!cmd_access(id,level,cid,1))
		return PLUGIN_HANDLED
	
	new Float:plOrigin[3],Float:Angles[3],Arg[33]
	read_argv(1,Arg,32);
	
	entity_get_vector(id,EV_VEC_origin,plOrigin);
	entity_get_vector(id,EV_VEC_angles,Angles);
	
	if(Arg[0] == 'n')
		client_print(id,print_console,"[AMXX] Origin: %d %d %d (Angle: %f %f %f)",floatround(plOrigin[0]),floatround(plOrigin[1]),floatround(plOrigin[2]),Angles[0],Angles[1],Angles[2]);
	else
		client_print(id,print_console,"[AMXX] Origin: %f   %f   %f (Angle: %f %f %f)",plOrigin[0],plOrigin[1],plOrigin[2],Angles[0],Angles[1],Angles[2]);
		
	// set origin
	
	if(Arg[0] == 's')
	{
		read_argv(2,Arg,32);
		client_print(id,print_console,"ARG1: %f",str_to_float(Arg))
		plOrigin[0] = str_to_float(Arg);
		read_argv(3,Arg,32);
		client_print(id,print_console,"ARG2: %f",str_to_float(Arg))
		plOrigin[1] = str_to_float(Arg);
		read_argv(4,Arg,32);
		client_print(id,print_console,"ARG3: %f",str_to_float(Arg))
		plOrigin[2] = str_to_float(Arg);
		
		entity_set_origin(id,plOrigin);
	}
	
	return PLUGIN_HANDLED
}

public CmdSlay(id,level,cid)
{
	if(!cmd_access(id,level,cid,2))
		return PLUGIN_HANDLED
	
	new Arg[33]
	read_argv(1,Arg,32);
	
	new Target = cmd_target(id,Arg,CMDTARGET_ALLOW_SELF);
	if(!Target)
		return PLUGIN_HANDLED
	
	client_print(id,print_chat,"[AMXX] Slayed User.");
	
	new Float:fOrigin[3]
	entity_get_vector(Target,EV_VEC_origin,fOrigin);
	
	message_begin(MSG_BROADCAST,SVC_TEMPENTITY,fOrigin);
	write_byte(TE_EXPLOSION2);
	
	write_coord(floatround(fOrigin[0]));
	write_coord(floatround(fOrigin[1]));
	write_coord(floatround(fOrigin[2]));
	
	write_byte(1);
	write_byte(255);
	
	message_end();
	user_kill(Target);
	
	server_print("%f%f%f",fOrigin[0],fOrigin[1],fOrigin[2]);
	
	return PLUGIN_HANDLED
}