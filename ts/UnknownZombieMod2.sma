/*

				ZombieMod for The Specialists 3.0
					by stupok69

		This is a very simple bot-adder for TS. You can customize
		the bots' speed and health. You can also join the bots'
		team and play as a Zombie. Zombies are not allowed to use
		weapons.


========INSTRUCTIONS

1)	Add the modified mp.dll to your dlls folder. Make sure that you backup the original.

2)	* * * PLEASE NOTE * * *

	This plugin will automatically configure your server.cfg and game.cfg.
	
	If you wish, you can manually edit these files, but it is unnecessary:

>		server.cfg

		Add these lines if they do not exist already:

			mp_teamlist "Humans;Zombies"
			mp_teammodels "gordon;laurence;merc;seal|domo;zombie1"
			bottalk 0

		NOTE:
		You can use any player models you'd like for mp_teammodels.
		However, you should not change the names or the order of the teams.

>		game.cfg

		Add this line if it does not exist already:

			"mp_teamplay" "1"


========CVARS

* * * PLEASE NOTE * * *

You can add any of these cvars to your server.cfg with the settings you prefer.

>		zm_notify

			Display messages to clients when health/speed is changed. 0 = no, 1 = yes

>		zm_zombies

			Number of zombies in the server.

>		zm_zombiehp

			Amount of health zombies will have.

>		zm_lights

			How bright do you want the map to be?
			Values range from 0 to 26. 0 = pitch black, 26 = regular

>		zm_clientzombies

			Allows clients to join the Zombies team. 0 = no, 1 = yes

>		zm_clientzombiehp

			Amount of health clients on the Zombies team will have.

>		zm_zombiespeed

			The zombies' movement speed. 330.0 = normal
			
>		zm_knockback

			The amount zombies will fly back when you shoot them. Shotguns are much
			more powerful than regular guns. 0 = off


========CHANGELOG

>	08/19/07 - V1.4

		Minor changes to file-writing functions.

>	08/18/07 - V1.3

		Added "say /zombie"

>	08/15/07 - V1.2

		Made use of the mp_teammodels functionality for the zombies.

>	08/14/07 - V1.1

		Added zm_knockback

>	08/14/07 - V1.0

		Initial release.

*/

/*
Updated part of tsconst.inc
*/
enum
{
	TSW_KUNGFU,
	TSW_GLOCK18,
	TSW_BERETTA,
	TSW_UZI,
	TSW_M3,
	TSW_M4A1,
	TSW_MP5SD,
	TSW_MP5K,
	TSW_ABERETTA,
	TSW_MK23,
	TSW_AMK23,
	TSW_USAS,
	TSW_DEAGLE,
	TSW_AK47,
	TSW_57,
	TSW_AUG,
	TSW_AUZI,
	TSW_SKORPION,
	TSW_M82A1,
	TSW_MP7,
	TSW_SPAS,
	TSW_GCOLTS,
	TSW_GLOCK20,
	TSW_UMP,
	TSW_M61GRENADE,
	TSW_CKNIFE,
	TSW_MOSSBERG,
	TSW_M16A4,
	TSW_MK1,
	TSW_C4,
	TSW_A57,
	TSW_RBULL,
	TSW_M60E3,
	TSW_SAWED_OFF,
	TSW_KATANA,
	TSW_SKNIFE,
	TSW_G2,
	TSW_ASKORPION
}

#include <amxmodx>
#include <fakemeta>

new const PLUGIN[]	=	"ZombieMod"
new const VERSION[]	=	"1.4"
new const AUTHOR[]	=	"stupok69"

enum
{
	NOTE_FILECHANGED,
	NOTE_TEAMSWRONG,
	NOTE_HEALTHCHANGED,
	NOTE_SPEEDCHANGED,
	NOTE_CLZOMBIES,
	NOTE_MAX
}

new const gc_notification[NOTE_MAX][] =
{
	"File has been edited to work with ZombieMod (%s)",
	"Team #1 must be the human team! Server is restarting...",
	"* ZombieMod - Your health has been changed to %s.",
	"* ZombieMod - Your speed has been changed to %s.",
	"* ZombieMod - You are not allowed to join the Zombie team."
}

new cvar_notify
new cvar_zombies
new cvar_zombiehp
new cvar_lights
new cvar_clzombies
new cvar_clzombiehp
new cvar_zombiespeed
new cvar_knockback

new g_zombiemodel[16][32]
new g_zombiemodel_num

new g_curweapon[33]

new g_damage_dealt

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_clcmd("say /zombie",	"show_zombie_info", -1, "Shows zombie info")
	
	cvar_notify		=	register_cvar("zm_notify",		"1")
	cvar_zombies		=	register_cvar("zm_zombies",		"10")
	cvar_zombiehp		=	register_cvar("zm_zombiehp",		"1")
	cvar_clzombies		=	register_cvar("zm_clientzombies",	"1")
	cvar_clzombiehp		=	register_cvar("zm_clientzombiehp",	"133")
	cvar_zombiespeed	=	register_cvar("zm_zombiespeed",		"1030.0")
	cvar_lights		=	register_cvar("zm_lights",		"26")
	cvar_knockback		=	register_cvar("zm_knockback",		"100")
	
	register_event("ScoreInfo",	"event_ScoreInfo",	"a",	"5=2")
	register_event("ResetHUD",	"event_ResetHUD",	"b")
	register_event("WeaponInfo",	"event_WeaponInfo",	"b")
	register_event("PTakeDam",	"event_PTakeDam",	"a")
	
	register_message(50, "message_50")
	
	register_forward(FM_SetClientMaxspeed, "forward_SetClientMaxspeed")
	
	exec_cvar_zombiespeed()
	exec_cvar_lights()
	exec_cvar_zombies()
	
	check_gamecfg()
	check_servercfg()
	
	set_task(2.0, "check_teams")
	set_task(120.0, "zombie_advertise", 0, _, _, "b")
}

public check_teams()
{
	if(ts_team_has_bots(1))
	{
		zm_notify(0, NOTE_TEAMSWRONG)
		server_cmd("restart")
	}
}

public zombie_advertise()
{
	client_print(0, print_chat, "* ZombieMod - Say /zombie to see the current settings!")
}

/*
********************************	COMMAND {
*/

public show_zombie_info(id)
{
	client_print(id, print_chat, "zombiehp: %i,clientzombies: %i,clientzombiehp: %i,zombiespeed: %i,lights: %i,knockback: %i",
		get_pcvar_num(cvar_zombiehp),
		get_pcvar_num(cvar_clzombies),
		get_pcvar_num(cvar_clzombiehp),
		get_pcvar_num(cvar_zombiespeed),
		get_pcvar_num(cvar_lights),
		get_pcvar_num(cvar_knockback))
}

/*
********************************	} COMMAND
*/

/*
********************************	FORWARD {
*/

public forward_SetClientMaxspeed(id, Float:speed)
{
	static Float:f_zs, str_zs[8]
	
	if(get_user_team(id) == 2)
	{
		f_zs = get_pcvar_float(cvar_zombiespeed)
		
		set_pev(id, pev_maxspeed, f_zs)
		
		if(!is_user_bot(id))
		{
			float_to_str(f_zs, str_zs, 7)
			
			zm_notify(id, NOTE_SPEEDCHANGED, str_zs)
		}
		
		return FMRES_SUPERCEDE
	}
	
	return FMRES_IGNORED
}

/*
********************************	} FORWARD
*/

/*
********************************	MESSAGE {
*/

public message_50(msg_id, msg_dest, msg_entity)
{
	static victim, attacker, Float:aimvelocity[3]
	
	victim = get_msg_arg_int(2)
	attacker = get_msg_arg_int(3)
	
	if(!is_user_alive(attacker))
	{
		return PLUGIN_HANDLED
	}
	
	switch(g_curweapon[attacker])
	{
		case TSW_KUNGFU:
		{
			return PLUGIN_HANDLED
		}
		case TSW_MOSSBERG, TSW_SAWED_OFF, TSW_M3, TSW_SPAS, TSW_USAS:
		{
			velocity_by_aim(attacker, g_damage_dealt * get_pcvar_num(cvar_knockback), aimvelocity)
			set_pev(victim, pev_velocity, aimvelocity)
			set_task(0.3, "hold_position", victim)
		}
		default:
		{
			velocity_by_aim(attacker, g_damage_dealt * get_pcvar_num(cvar_knockback) / 3, aimvelocity)
			set_pev(victim, pev_velocity, aimvelocity)
			set_task(0.3, "hold_position", victim)
		}
	}
	
	return PLUGIN_HANDLED
}

/*
********************************	} MESSAGE
*/

/*
********************************	EVENT {
*/

public event_ResetHUD(id)
{
	static clhp, str_clhp[8]
	
	if(!is_user_alive(id))
		return PLUGIN_HANDLED
	
	if(get_user_team(id) == 2)
	{
		if(is_user_bot(id))
		{
			set_pev(id, pev_health, get_pcvar_float(cvar_zombiehp))
			
			set_task(0.1, "delay_change_model", id)
		}
		else
		{
			clhp = get_pcvar_num(cvar_clzombiehp)
			
			set_pev(id, pev_health, float(clhp))
			
			num_to_str(clhp, str_clhp, 7)
			
			zm_notify(id, NOTE_HEALTHCHANGED, str_clhp)
		}
	}
	
	return PLUGIN_HANDLED
}

public delay_change_model(id)
{
	engclient_cmd(id, "model", g_zombiemodel[random_num(0, g_zombiemodel_num)])
}

public event_WeaponInfo(id)
{
	g_curweapon[id] = read_data(1)
	
	if(get_user_team(id) == 2)
	{
		if(is_user_bot(id))
		{
			set_task(0.1, "delay_drop", id)
		}
		else
		{
			console_cmd(id, "drop")
		}
	}
}

public delay_drop(id)
{
	engclient_cmd(id, "drop")
}

public event_ScoreInfo(id)
{	
	if(!get_pcvar_num(cvar_clzombies))
	{
		client_cmd(id, "jointeam 1")
		
		zm_notify(id, NOTE_CLZOMBIES)
	}
}

public event_PTakeDam()
{
	g_damage_dealt = read_data(7)
}

/*
********************************	} EVENT
*/

/*
********************************	CVAR {
*/

stock exec_cvar_zombiespeed()
{
	server_cmd("sv_maxspeed %f", get_pcvar_float(cvar_zombiespeed))
}

stock exec_cvar_lights()
{
	//necessary for the fakemeta lights to work
	server_cmd("sv_skycolor_r 0;sv_skycolor_g 0;sv_skycolor_b 0")
	server_exec()
	
	new lights[2]
	new level = (1<<get_pcvar_num(cvar_lights))
	get_flags(level, lights, 1)
	engfunc(EngFunc_LightStyle, 0, lights)
}

stock exec_cvar_zombies()
{
	new amount = get_pcvar_num(cvar_zombies)
	
	for(new i = 1; i <= amount; i++)
	{
		set_task(float(i) * 0.2, "delay_add_zombie")
	}
}

public delay_add_zombie()
{
	server_cmd("addcustombot Zombie Zombies 9.9")
}

/*
********************************	} CVAR
*/

/*
********************************	TOOLS {
*/

stock zm_notify(id, notification_id, extra[]="")
{
	if(id)
	{
		if(get_pcvar_num(cvar_notify))
		{
			client_print(id, print_chat, gc_notification[notification_id], extra)
		}
	}
	else
	{
		log_amx(gc_notification[notification_id], extra)
	}
}

stock bool:ts_team_has_bots(team)
{
	static i, maxplayers
	
	maxplayers = get_maxplayers()
	
	for(i = 1; i <= maxplayers; i++)
	{
		if(is_user_bot(i))
		{
			if(get_user_team(i) == team)
			{
				return true
			}
		}
	}
	
	return false
}

public hold_position(id)
{
	set_pev(id, pev_maxspeed, -1.0)
	
	set_task(0.4, "release_position", id)
}

public release_position(id)
{
	set_pev(id, pev_maxspeed, get_pcvar_float(cvar_zombiespeed))
}

/*
********************************	} TOOLS
*/

/*
********************************	FILE {
*/

stock check_gamecfg()
{
	new fh = fopen("game.cfg", "rt")
	
	new bool:b_file_changed
	
	if(fh)
	{
		new buffer[128], counter
		
		while(!feof(fh))
		{
			fgets(fh, buffer, 127)
			
			if(equal(buffer, "^"mp_teamplay^"", 13))
			{
				parse(buffer, buffer, 127, buffer, 127)
				
				if(!str_to_num(buffer))
				{
					write_file("game.cfg", "^n;ZombieMod requires mp_teamplay to be 1^n^n^"mp_teamplay^" ^"1^"^n", counter)
					b_file_changed = true
				}
			}
			
			counter++
		}
		
		fclose(fh)
	}
	else if(!b_file_changed)
	{
		write_file("game.cfg", "^"mp_teamplay^"	^"1^"")
		b_file_changed = true
	}
	
	if(b_file_changed)
		zm_notify(0, NOTE_FILECHANGED, "game.cfg")
}

stock check_servercfg()
{
	new fh = fopen("server.cfg", "rt")
	
	new bool:b_file_changed
	new bool:b_bottalk_found
	new bool:b_mp_teammodels_found
	new bool:b_mp_teamlist_found
	
	if(fh)
	{
		new buffer[128], counter
		
		while(!feof(fh))
		{
			fgets(fh, buffer, 127)
			
			if(contain(buffer, "mp_teamlist") != -1)
			{
				parse(buffer, buffer, 127, buffer, 127)
				
				if(!equal(buffer, "Humans;Zombies"))
				{
					write_file("server.cfg", "mp_teamlist ^"Humans;Zombies^"", counter)
					b_file_changed = true
				}
				
				b_mp_teamlist_found = true
			}
			else if(contain(buffer, "bottalk") != -1)
			{
				b_bottalk_found = true
			}
			else if(contain(buffer, "mp_teammodels") != -1)
			{
				parse(buffer, buffer, 127, buffer, 127)
				strtok(buffer, buffer, 127, buffer, 127, '|')
				
				new char_count, model_count, model_char_count
				
				while(buffer[char_count])
				{
					if(buffer[char_count] == '|')
					{
						break
					}
					else if(buffer[char_count] == ';')
					{
						model_count++
						model_char_count = 0
						char_count++
						continue
					}
					
					g_zombiemodel[model_count][model_char_count] = buffer[char_count]
					
					model_char_count++
					char_count++
				}
				
				g_zombiemodel_num = model_count
				
				b_mp_teammodels_found = true
			}
			
			counter++
		}
		
		if(!b_bottalk_found)
		{
			write_file("server.cfg", "^n^nbottalk 0", -1)
			b_file_changed = true
		}
		
		if(!b_mp_teamlist_found)
		{
			write_file("server.cfg", "^n^nmp_teamlist ^"Humans;Zombies^"", -1)
			b_file_changed = true
		}
		
		if(!b_mp_teammodels_found)
		{
			write_file("server.cfg", "^n^nmp_teammodels ^"gordon|seal;merc|agent^"", -1)
			b_file_changed = true
		}
		
		fclose(fh)
	}
	
	if(b_file_changed)
		zm_notify(0, NOTE_FILECHANGED, "server.cfg")
}

/*
********************************	} FILE
*/
