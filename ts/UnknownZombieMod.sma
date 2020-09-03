//////////////////////////////////////////////////////
//                                                  //
//         ______                _                  //
//	  /___  /               | |    O            //
//           / /    ___         | |    _   ____     //
//          / /    | _ | |\  /| | |_  | | /___/     //
//         / /___  ||_|| | \/ | | o | | | \         //
//        /______| |___| |    | |__/  |_|  \___     //
//       =======================================    //
//                                                  //
//              __    __      ___     ___           //
//            /   \  /  \    /   \   |   \          //
//            | |\ \/ /| |  | / \ |  | || |         //
//            | | \__/ | |  | | | |  | || |         //
//            | |      | |  | \_/ |  | || |         //
//            |_|      |_|   \___/   |___/          //
//           ===============================        //
//                                                  //
//     Created By Jake (Blackops7799)               //
//      Support - Cobra, Wonsae                     //
//                                                  //
//////////////////////////////////////////////////////

#include <amxmodx>
#include <amxmisc>
#include <dbi>
#include <engine>
#include <tsx>
#include <engine_stocks>
#include <fun>
#include <fakemeta>

new xp[33]
new level[33]
new kills[33]
//new money[33]

new gmsgItems

new nightvision[33] = 0
new flashlight[33] = 0

new Sql:dbc
new Result:result

new zombiemodel[] = "zombies"
new humanmodel[] = "human"

new const LEVELS[15] = { 
    100,  
    200,  
    400,  
    800, 
    1600, 
    3200,
    6400,
    12800,
    25600,
    51200,
    102400,
    204800,
    409600,
    819200,
    1638400
} 
public plugin_precache()
{
	// Zombie Moan sounds
	precache_sound("nihilanth/nil_done.wav")
	precache_sound("nihilanth/nil_freeman.wav")
	precache_sound("nihilanth/nil_last.wav")
	precache_sound("nihilanth/nil_man_notman.wav")
	precache_sound("nihilanth/nil_now_die.wav")
	precache_sound("nihilanth/nil_slaves.wav")
	precache_sound("nihilanth/nil_alone.wav")
	precache_sound("nihilanth/nil_thelast.wav")
	precache_sound("nihilanth/nil_comes.wav")
	precache_sound("nihilanth/nil_thetruth.wav")
	precache_sound("nihilanth/nil_deceive.wav")
	precache_sound("nihilanth/nil_thieves.wav")
	precache_sound("nihilanth/nil_die.wav")
	precache_sound("nihilanth/nil_win.wav")

	precache_sound("zombiemod/nvg_on.wav")
	precache_sound("zombiemod/nvg_off.wav")
}
public plugin_init()
{
	new mapname[32]
	get_mapname( mapname, 31 )

	register_plugin("Zombie Mod","1","Jake (Blackops7799)")

	register_clcmd("say","say_handle")

	register_clcmd("say /nightvision","nightvistoggle")
	register_clcmd("nightvis","nightvistoggle")
	register_clcmd("say /bindnightvision","nightvisionbind")

	register_clcmd("say /flashlight","flashlighttoggle")
	register_clcmd("flashlight","flashlighttoggle")
	register_clcmd("say /bindflashlight","flashlightbind")

	register_event("ResetHUD","spawn_msg", "be")

	register_cvar("zm_mysql_host","",FCVAR_PROTECTED)
	register_cvar("zm_mysql_user","",FCVAR_PROTECTED)
	register_cvar("zm_mysql_pass","",FCVAR_PROTECTED)
	register_cvar("zm_mysql_db","zombiemod",FCVAR_PROTECTED)
	register_cvar("zm_gamename","Zombie Mod");
	register_cvar("zm_xp_per_kill", "5")
	register_cvar("zm_remove_doors", "1")
	register_cvar("zm_zombie_health", "200")
	register_cvar("zm_hud_pos_x","-1.9")
	register_cvar("zm_hud_pos_y","0.55")
	register_cvar("zm_hud_red","175")
	register_cvar("zm_hud_green","0")
	register_cvar("zm_hud_blue","0")

	set_task(2.0,"activehud",0,"",0,"b")
	set_task(1.0,"sql_init")
	set_task(1.0,"removedoors");

	gmsgItems = get_user_msgid("ActItems")

	register_forward(FM_GetGameDescription,"GameDesc");

	server_cmd("exec addons/amxmodx/configs/zombiemod/zm_config.cfg")	// loads all of your custom settings
	server_cmd("exec addons/amxmodx/configs/zombiemod/zm_botlist.cfg")	// loads the bots

	// I added this because for some reason my servercomp would freeze when these doors were opened.
	if(equal(mapname,"Mecklenburg_b5"))
	{
		remove_entity(223+get_maxplayers())
		remove_entity(225+get_maxplayers())
		remove_entity(226+get_maxplayers())
		remove_entity(224+get_maxplayers())
		remove_entity(228+get_maxplayers())
		remove_entity(229+get_maxplayers())
		remove_entity(230+get_maxplayers())
		remove_entity(231+get_maxplayers())
		remove_entity(272+get_maxplayers())
		remove_entity(273+get_maxplayers())
		remove_entity(274+get_maxplayers())
		remove_entity(275+get_maxplayers())
		remove_entity(267+get_maxplayers())
		remove_entity(269+get_maxplayers())
		remove_entity(280+get_maxplayers())
		remove_entity(281+get_maxplayers())
		remove_entity(60+get_maxplayers())
		remove_entity(61+get_maxplayers())
		remove_entity(62+get_maxplayers())
		remove_entity(63+get_maxplayers())
		remove_entity(74+get_maxplayers())
		remove_entity(75+get_maxplayers())
		remove_entity(76+get_maxplayers())
		remove_entity(77+get_maxplayers())
		remove_entity(79+get_maxplayers())
		remove_entity(80+get_maxplayers())
		remove_entity(81+get_maxplayers())
		remove_entity(82+get_maxplayers())
	}
	if(equal(mapname,"Mecklenburgv3_b1"))
	{
		//Removes the first set of pd doors
		remove_entity(78+get_maxplayers())
		remove_entity(79+get_maxplayers())
		remove_entity(80+get_maxplayers())
		remove_entity(81+get_maxplayers())
		//removes the second set of pd doors
		remove_entity(83+get_maxplayers())
		remove_entity(84+get_maxplayers())
		remove_entity(85+get_maxplayers())
		remove_entity(86+get_maxplayers())
		//removes the MD doors
		remove_entity(269+get_maxplayers())
		remove_entity(270+get_maxplayers())
		remove_entity(271+get_maxplayers())
		remove_entity(272+get_maxplayers())

		remove_entity(159+get_maxplayers())
		remove_entity(159+get_maxplayers())
	}
}
public client_PreThink(id)
{
	if(!is_user_alive(id))
	{
		return PLUGIN_HANDLED
	}
	if(nightvision[id] == 1)
	{
		message_begin(MSG_ONE,get_user_msgid("ScreenFade"),{0,0,0},id);
		write_short(~0);
		write_short(~0);
		write_short(1<<2);
		write_byte(0);
		write_byte(255);
		write_byte(0);
		write_byte(70);
		message_end();
		return PLUGIN_HANDLED
	}
	if(nightvision[id] == 0)
	{
		message_begin(MSG_ONE,get_user_msgid("ScreenFade"),{0,0,0},id);
		write_short(~0);
		write_short(~0);
		write_short(1<<2);
		write_byte(0);
		write_byte(0);
		write_byte(0);
		write_byte(0);
		message_end();
		return PLUGIN_HANDLED
	}
	return PLUGIN_HANDLED
}
public nightvisionbind(id)
{
	client_print(id, print_chat, "[Zombie Mod] Your night-vision key has been bound to ''n''!")
	client_cmd(id,"bind n nightvis")
	return PLUGIN_HANDLED
}
public flashlightbind(id)
{
	client_print(id, print_chat, "[Zombie Mod] Your flashlight key has been bound to ''f''!")
	client_cmd(id,"bind f flashlight")
	return PLUGIN_HANDLED
}
public printcommercial(id)
{
	engclient_print(id,engprint_console,"--------------------------------------------------------------------------------^n")
	engclient_print(id,engprint_console,"  This Server is Powered By: Jake's ZombieMod ^n")
	engclient_print(id,engprint_console,"  Made by Jake aka (blackops777999|blackops7799) ^n")
	engclient_print(id,engprint_console,"  E-mail (blackosp777999@gmail.com) ^n")
	engclient_print(id,engprint_console,"--------------------------------------------------------------------------------^n")
	return PLUGIN_HANDLED
}
// connect to the SQL
public sql_init()
{
	new host[64], username[33], password[32], dbname[32], error[32]
 	get_cvar_string("zm_mysql_host",host,64) 
    	get_cvar_string("zm_mysql_user",username,32) 
    	get_cvar_string("zm_mysql_pass",password,32) 
    	get_cvar_string("zm_mysql_db",dbname,32)
	dbc = dbi_connect(host,username,password,dbname,error,32)
	if (dbc == SQL_FAILED)
	{
		server_print("[ZombieMod] Could Not Connect To SQL Database^n")
	}
	else
	{
		server_print("[ZombieMod] Connected To SQL, Have A Nice Day!^n")
	}
}
// MOTD
public say_handle(id)
{
	new buffer[256], buffer1[33]
	read_argv(1,buffer,255)
	parse(buffer, buffer1, 32)
	if(equali(buffer1,"/motd"))
	{
		show_motd(id,"motd.txt","Message of the Day")
		return PLUGIN_HANDLED
	}
	return PLUGIN_CONTINUE 
}
//how the zombie moan works
public zombiemoan(id)
{
	new model[32]
	get_user_info(id,"model",model,32)
	new moan = (random_num(0,13))
	//new hpvalue = get_cvar_num("zm_zombie_health")
	if(equali(model,"zombies"))
	{
		//set_user_health(id,hpvalue)
		set_user_health(id,200)
		switch(moan)
		{
			case 0: emit_sound(id, CHAN_ITEM, "nihilanth/nil_done.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
			case 1: emit_sound(id, CHAN_ITEM, "nihilanth/nil_freeman.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
			case 2: emit_sound(id, CHAN_ITEM, "nihilanth/nil_last.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
			case 3: emit_sound(id, CHAN_ITEM, "nihilanth/nil_man_notman.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
			case 4: emit_sound(id, CHAN_ITEM, "nihilanth/nil_now_die.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
			case 5: emit_sound(id, CHAN_ITEM, "nihilanth/nil_slaves.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
			case 6: emit_sound(id, CHAN_ITEM, "nihilanth/nil_alone.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
			case 7: emit_sound(id, CHAN_ITEM, "nihilanth/nil_thelast.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
			case 8: emit_sound(id, CHAN_ITEM, "nihilanth/nil_comes.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
			case 9: emit_sound(id, CHAN_ITEM, "nihilanth/nil_thetruth.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
			case 10: emit_sound(id, CHAN_ITEM, "nihilanth/nil_deceive.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
			case 11: emit_sound(id, CHAN_ITEM, "nihilanth/nil_thieves.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
			case 12: emit_sound(id, CHAN_ITEM, "nihilanth/nil_die.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
			case 13: emit_sound(id, CHAN_ITEM, "nihilanth/nil_win.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
		}
	}
	set_task(25.0,"zombiemoan",id)
	return PLUGIN_HANDLED;
}
public edit_value(id,table[],index[],func[],amount)
{
	if(dbc < SQL_OK) return PLUGIN_HANDLED
	new authid[32], query[256]
	get_user_authid(id,authid,31)
	if(equali(func,"="))
	{
		format(query,255,"UPDATE %s SET %s=%i WHERE steamid='%s'",table,index,amount,authid)
	}
	else
	{
		format(query,255,"UPDATE %s SET %s=%s%s%i WHERE steamid='%s'",table,index,index,func,amount,authid)
	}
	dbi_query(dbc,query)
	return PLUGIN_HANDLED
}
// where the hud is started
public activehud()
{
	new num, players[32]
	get_players(players,num,"ac")
	for( new i = 0;  i < num; i++ )
	{
		set_hudmessage(get_cvar_num("zm_hud_red"),get_cvar_num("zm_hud_green"),get_cvar_num("zm_hud_blue"),get_cvar_float("zm_hud_pos_x"),get_cvar_float("zm_hud_pos_y"),0,0.0,99.9,0.0,0.0,-1)
		show_hudmessage(players[i], "|Zombie Mod| ^n^n Level: %i ^n Exp: %i ^n Kills: %i",level[players[i]],xp[players[i]],kills[players[i]])
	}
	return PLUGIN_HANDLED
}
public GameDesc()
{
	new gamename[32];
	get_cvar_string("zm_gamename",gamename,31);
	forward_return(FMV_STRING,gamename);
	return FMRES_SUPERCEDE;
}
// Checks to see if player is in the sql database.
public is_user_database(id)
{
	if(dbc < SQL_OK) return 0
	new authid[32], query[256]
	get_user_authid(id,authid,31)
	format(query,255,"SELECT steamid FROM users WHERE steamid='%s'",authid)
	result = dbi_query(dbc,query)
	if(dbi_nextrow(result) > 0)
	{
		dbi_free_result(result)
		return 1
	}
	else dbi_free_result(result)
	return 0
}
// registers the player
public register(id)
{
	if(is_user_database(id) == 0)
	{
		new query[256], authid[32], name[33]
		get_user_authid(id,authid,31)
		get_user_name(id,name,sizeof(name))
		format(query,255,"INSERT INTO users (steamid,exp,level,kills,money) VALUES('%s','5','1','1','50')",authid)
		dbi_query(dbc,query)
		client_print(id, print_console, "[ZombieMod] Thank you for registering!")
		server_print("[ZombieMod] %s has been added to the database^n",authid)
		client_print(id, print_chat, "[ZombieMod] Enjoy your stay %s!",name)
		return PLUGIN_HANDLED
	}
	return PLUGIN_HANDLED
}
// recieves players stats and sets them
public getstats(id)
{
	new authid[32], query[265]
	get_user_authid(id,authid,31)
	format(query,255,"SELECT exp,level,kills FROM users WHERE steamid='%s'",authid)
	result = dbi_query(dbc,query)

	xp[id] = dbi_field(result,1)
	level[id] = dbi_field(result,2)
	kills[id] = dbi_field(result,3)
	//money[id] = dbi_field(result,5)

	client_print(id, print_console, "[Zombie Mod] Received stats from the SQL server")

	return PLUGIN_HANDLED
}
// double checks players model, starts other stuff...
public client_connect(id)
{
	new model[32]
	get_user_info(id,"model",model,32)
	if(containi(model, zombiemodel) != -1)
	{
		client_print(id, print_chat, "[ZombieMod] Sorry, but you are only allowed to be %s.", humanmodel)
		client_cmd( id, "model %s", humanmodel)
	}
	if(is_user_bot(id))
	{
		return PLUGIN_HANDLED;
	}
	set_task(9.0,"getstats",id)
	set_task(8.0,"printcommercial",id)
	set_task(8.0,"register",id)
	set_task(5.0,"securitymessage",id)
	return PLUGIN_HANDLED
}
// Used for getting a players steamid...
public securitymessage(id)
{
	new  authid[32], name[33]
	get_user_authid(id,authid,31)
	get_user_name(id,name,sizeof(name))
	client_print(0, print_chat, "(%s | %s) has connected",name,authid)
	client_print(0, print_console, "(%s | %s) has connected",name,authid)
	server_print("(%s | %s) has connected",name,authid)
	return PLUGIN_HANDLED
}
// experince and levels
public client_death(killer,victim,wpnindex,hitplace,TK)
{
	nightvision[victim] = 0
	edit_value(killer,"users","kills","+",1)
	kills[killer] += 1
	/*
	edit_value(killer,"users","money","+",50)
	money[killer] += 50
	*/
	if(level[killer] == 15)
	{
		return PLUGIN_HANDLED
	}
	edit_value(killer,"users","exp","+",get_cvar_num("zm_XP_per_kill"))
	xp[killer] += get_cvar_num("zm_XP_per_kill")
	if(xp[killer] >= LEVELS[level[killer]])
	{
		edit_value(killer,"users","level","+",1)
		level[killer] += 1
		set_user_rendering(killer, kRenderFxGlowShell,255,198,0,kRenderNormal,25)
		set_task(10.0,"removeglow",killer)
		client_print(killer, print_chat, "[Zombie Mod] Congratulations! You are now level %i!", level[killer])
	}       
	return PLUGIN_CONTINUE
}
public removeglow(id)
{
	set_user_rendering(id, kRenderFxGlowShell,0,0,0,kRenderNormal,25)
	return PLUGIN_HANDLED
}
// Checks if the player is admin or not, if not admin then restrict team.
public client_infochanged(id)
{
	new model[32]
	get_user_info(id,"model",model,32)
	set_task(0.5,"zombiemoan",id)
	if((get_user_flags(id) & ADMIN_LEVEL_A))
	{
		return PLUGIN_HANDLED
	}
	if(containi(model, zombiemodel) != -1)
	{
		client_print(id, print_chat, "[ZombieMod] Sorry, but you are only allowed to be %s.", humanmodel)
		client_cmd( id, "model %s", humanmodel)
	}
	return PLUGIN_HANDLED;
}
// Finds the players level, the higher the level the higher your HP :)
public spawn_msg(id)
{
	if(level[id] == 2)
	{
		set_user_health(id, 105)
	}
	if(level[id] == 3)
	{
		set_user_health(id, 110)
	}
	if(level[id] == 4)
	{
		set_user_health(id, 115)
	}
	if(level[id] == 5)
	{
		set_user_health(id, 120)
	}
	if(level[id] == 6)
	{
		set_user_health(id, 125)
	}
	if(level[id] == 7)
	{
		set_user_health(id, 130)
	}
	if(level[id] == 8)
	{
		set_user_health(id, 135)
	}
	if(level[id] == 9)
	{
		set_user_health(id, 140)
	}
	if(level[id] == 10)
	{
		set_user_health(id, 145)
	}
	if(level[id] == 11)
	{
		set_user_health(id, 150)
	}
	if(level[id] == 12)
	{
		set_user_health(id, 155)
	}
	if(level[id] == 13)
	{
		set_user_health(id, 160)
	}
	if(level[id] == 14)
	{
		set_user_health(id, 165)
	}
	if(level[id] == 15)
	{
		set_user_health(id, 200)
	}
}
public nightvistoggle(id)
{
	if(!is_user_alive(id))
	{
		return PLUGIN_HANDLED
	}
	if(nightvision[id] == 0)
	{
		emit_sound(id, CHAN_ITEM, "zombiemod/nvg_on.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
		client_print(id, print_chat, "[ZombieMod] Night Vision On.")
		nightvision[id] = 1
		return PLUGIN_HANDLED
	}
	if(nightvision[id] == 1)
	{
		client_print(id, print_chat, "[ZombieMod] Night Vision Off.")
		emit_sound(id, CHAN_ITEM, "zombiemod/nvg_off.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
		nightvision[id] = 0
		return PLUGIN_HANDLED
	}
	return PLUGIN_HANDLED
}
public flashlighttoggle(id)
{
	if(flashlight[id] == 0)
	{
		message_begin(MSG_ALL, gmsgItems, {0,0,0}) 
		write_byte(id)
		write_byte(4)
		message_end()
		
		flashlight[id] = 1
		
		entity_set_int(id,EV_INT_effects,entity_get_int(id,EV_INT_effects) | EF_DIMLIGHT);
		client_print(id,print_chat,"[ZombieMod] You turned on your flashlight.")
		return PLUGIN_HANDLED
	}
	if(flashlight[id] == 1)
	{
		message_begin(MSG_ALL, gmsgItems, {0,0,0}) 
		write_byte(id)
		write_byte(0)
		message_end()
		
		flashlight[id] = 0
		
		entity_set_int(id,EV_INT_effects,entity_get_int(id,EV_INT_effects) & ~EF_DIMLIGHT);
		client_print(id,print_chat,"[ZombieMod] You turned off your flashlight.")
		return PLUGIN_HANDLED
	}
	return PLUGIN_HANDLED
}
public removedoors()
{
	new on_off = get_cvar_num("zm_remove_doors")
	if(on_off == 0)
	{
		return PLUGIN_HANDLED
	}
	new door
	while((door = find_ent_by_class(door,"func_door_rotating")))
	{
		remove_entity(door)
	}
	while((door = find_ent_by_class(door,"func_door")))
	{
		remove_entity(door)
	}
	return PLUGIN_HANDLED
}