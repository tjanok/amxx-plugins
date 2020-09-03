#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <DRP/DRPCore>

#define MAX_FIRES 10
#define LEVEL1_BONUSTIME 1 // the extra amount of minutes between level 0 and 1 (so they have a better chance to put out the fire)

// Level 0-3
// Higher the level, the more "flames", and the harder it is to put out
#define SetFireLevel(%1,%2) entity_set_int(%1,EV_INT_iuser2,%2)
#define GetFireLevel(%1) entity_get_int(%1,EV_INT_iuser2)
#define GetFireLifeSeconds(%1) entity_get_int(%1,EV_INT_iuser3)
#define SetFireLifeSeconds(%1,%2) entity_set_int(%1,EV_INT_iuser3,%2)

new const g_FireClass[] = "DRP_FIRE"
new const g_FireSprite2[] = "sprites/OZDRP/firemod_sprite.spr"

new g_Fire

new p_Life
new p_Level

new gmsgTSFade
new gmsgStatusIcon

new g_TotalFires

new Float:g_UserFadeMessageDelay[33]
new bool:g_UserIconDisplayed[33]

public client_disconnect(id)
	{ g_UserFadeMessageDelay[id] = 0.0; g_UserIconDisplayed[id] = false; }

public plugin_precache()
{
	// Precaches
	g_Fire = precache_model(g_FireSprite2);
	server_print("%s",g_FireSprite);
	
	// CVars
	p_Life = register_cvar("DRP_FMOD_FireLife","5"); // time in minutes before the fire goes out byitself (fires should be able to reach level 3 before this time)
	p_Level = register_cvar("DRP_FMOD_FireLevelTime","1"); // time in minutes before the fire "levels-up"
}

public plugin_init()
{
	// Main
	register_plugin("DRP - FireMod","0.1a","Drak");
	
	// Commands
	register_clcmd("amx_testfire","testfire");
	
	// Forwards
	register_think(g_FireClass,"forward_Thinkfire");
	
	// Messages
	gmsgTSFade = get_user_msgid("TSFade");
	gmsgStatusIcon = engfunc(EngFunc_RegUserMsg,"StatusIcon",-1);
	
}

public DRP_Error(const Reason[])
	pause("d");

public DRP_HudDisplay(id,Hud)
{
	DRP_RegisterItem("");
}

public testfire(id)
{
	new Origin[3]
	get_user_origin(id,Origin);
	
	createFire(Origin);
}
/*==================================================================================================================================================*/
// When a fire reaches level 3 (the max level)
public forward_Thinkfire(const Ent)
d// a new fire entity is created. but is given the same life time as the previous fire. so when "p_Life" is met, they're all removed
{
	new const Life = GetFireLifeSeconds(Ent);
	new const LevelLife = entity_get_int(Ent,EV_INT_iuser1);
	
	if((Life / 60) >= get_pcvar_num(p_Life) || g_TotalFires >= MAX_FIRE || )
	{
		g_TotalFires--
		return remove_entity(Ent);
	}

	static Float:fOrigin[3]
	entity_get_vector(Ent,EV_VEC_origin,fOrigin);
	entity_set_int(Ent,EV_INT_iuser1,LevelLife + 1);
	
	SetFireLifeSeconds(Ent,Life + 1);
	new const Level = GetFireLevel(Ent);
	
	if(Level < 3)
	{
		if((LevelLife / 60) >= get_pcvar_num(p_Level))
		{
			SetFireLevel(Ent,Level + 1);
			entity_set_int(Ent,EV_INT_iuser1,0);
		}
	}
	
	new const MessageTime = entity_get_int(Ent,EV_INT_iuser4);
	
	// Life == 1 (first start)
	if(MessageTime >= 10 || Life == 1)
	{
		new Radius,Count
		switch(Level)
		{
			case 0: { Radius = 25; Count = 2; }
			case 1: { Radius = 80; Count = 15; }
			case 2: { Radius = 125; Count = 25; }
			case 3: { Radius = 285; Count = 100; }
		}
		
		message_begin(MSG_BROADCAST,SVC_TEMPENTITY);
		write_byte(TE_FIREFIELD);
		
		write_coord(floatround(fOrigin[0]));
		write_coord(floatround(fOrigin[1]));
		write_coord(floatround(fOrigin[2]));
		
		write_short(Radius); // raidus
		write_short(g_Fire);
		write_byte(Count); // count
		
		write_byte(TEFIRE_FLAG_SOMEFLOAT|TEFIRE_FLAG_ALPHA|TEFIRE_FLAG_LOOP);
		write_byte(150); // time
		
		message_end();
		entity_set_int(Ent,EV_INT_iuser4,0);
	}
	else
		entity_set_int(Ent,EV_INT_iuser4,MessageTime + 1);
	
	entity_set_float(Ent,EV_FL_nextthink,halflife_time() + 1.0);
	server_print("thinking. level: %d lifeseconds: %d lifelevelseconds: %d",Level,Life,LevelLife);
	
	
	// Damage
	static iPlayers[32],Float:pOrigin[3]
	new iNum,Player,Float:Time = get_gametime();
	get_players(iPlayers,iNum);
	
	new Float:Distance,Float:Health
	switch(Level)
	{
		case 0: { Distance = 60.0; Health = 1.0; } // not used
		case 1: { Distance = 195.0; Health = 1.0; }
		case 2: { Distance = 300.0; Health = 2.0; }
		case 3: { Distance = 500.0; Health = 3.0; }
	}
	
	for(new Count;Count < iNum;Count++)
	{
		Player = iPlayers[Count]
		if(!is_user_alive(Player))
			continue
		
		entity_get_vector(Player,EV_VEC_origin,pOrigin);
		if(get_distance_f(fOrigin,pOrigin) <= Distance)
		{
			if(!(Time - g_UserFadeMessageDelay[Player] < 5.0 && g_UserFadeMessageDelay[Player]))
			{
				message_begin(MSG_ONE_UNRELIABLE,gmsgTSFade,_,Player);
				
				write_short(seconds_to_screenfade_units(5));
				write_short(seconds_to_screenfade_units(1));
				write_short(FADE_IN_OUT);
				
				write_byte(125);
				write_byte(10);
				write_byte(10);
				write_byte(125);
				
				message_end();
				g_UserFadeMessageDelay[Player] = Time
				
				if(chance(90))
					emit_sound(Player,CHAN_AUTO,"player/pain2.wav",VOL_NORM,ATTN_NORM,0,PITCH_NORM);
			}
			
			// Go easy on level 0
			if(Level != 0)
				entity_set_float(Player,EV_FL_health,entity_get_float(Player,EV_FL_health) - Health);
			
			if(!g_UserIconDisplayed[Player])
				FireIcon(Player);
		}
		else
			if(g_UserIconDisplayed[Player])
				FireIcon(Player,false);
		
		client_print(Player,print_chat,"DIS: %f",get_distance_f(fOrigin,pOrigin));
	}
	return PLUGIN_HANDLED
	
	/*
	radius_damage(fOrigin,80,10);
	entity_set_float(Ent,EV_FL_nextthink,halflife_time() + 1.0);
	*/
}
/*==================================================================================================================================================*/
public createFire_fw(const Origin[3],CurrentLifeTime)
	return createFire(Origin,CurrentLifeTime);

createFire(const Origin[3],CurrentLifeTime=0)
{
	if(g_TotalFires < MAX_FIRES)
	{
		new Ent = create_entity("info_target");
		if(!Ent)
			return 0
		
		new Float:fOrigin[3]
		IVecFVec(Origin,fOrigin);
		
		fOrigin[2] += 10.0
		g_TotalFires++
		
		entity_set_origin(Ent,fOrigin);
		entity_set_string(Ent,EV_SZ_classname,g_FireClass);
		entity_set_int(Ent,EV_INT_solid,SOLID_NOT);
		entity_set_int(Ent,EV_INT_movetype,MOVETYPE_NONE);
		entity_set_int(Ent,EV_INT_flags,entity_get_int(Ent,EV_INT_flags) | EF_NODRAW);
		
		if(CurrentLifeTime)
			SetFireLifeSeconds(Ent,CurrentLifeTime);
		
		DRP_Log("Fire created. Origin: %f %f %f - Current amount of fires (including this one): #%d (MAX: #%d)",fOrigin[0],fOrigin[1],fOrigin[2],g_TotalFires,MAX_FIRES);
		forward_Thinkfire(Ent);
		
		return Ent
	}
	
	return 0
}
FireIcon(id,bool:Show=true)
{
	new Float:Temp[1]
	engfunc(EngFunc_MessageBegin,MSG_ONE_UNRELIABLE,gmsgStatusIcon,Temp,id);
	
	write_byte(Show ? 1 : 0);
	write_string("dmg_heat");
	
	write_byte(255); // red
	write_byte(0); // green
	write_byte(0); // blue
	
	message_end();
	g_UserIconDisplayed[id] = Show
}

#define TE_FIREFIELD                123      // Makes a field of fire
// write_byte(TE_FIREFIELD)
// write_coord(origin)
// write_short(radius) (fire is made in a square around origin. -radius, -radius to radius, radius)
// write_short(modelindex)
// write_byte(count)
// write_byte(flags)
// write_byte(duration (in seconds) * 10) (will be randomized a bit)
//
// to keep network traffic low, this message has associated flags that fit into a byte:
#define TEFIRE_FLAG_ALLFLOAT        1        // All sprites will drift upwards as they animate
#define TEFIRE_FLAG_SOMEFLOAT       2        // Some of the sprites will drift upwards. (50% chance)
#define TEFIRE_FLAG_LOOP            4        // If set, sprite plays at 15 fps, otherwise plays at whatever rate stretches the animation over the sprite's duration.
#define TEFIRE_FLAG_ALPHA           8        // If set, sprite is rendered alpha blended at 50% else, opaque
#define TEFIRE_FLAG_PLANAR          16       // If set, all fire sprites have same initial Z instead of randomly filling a cube. 
