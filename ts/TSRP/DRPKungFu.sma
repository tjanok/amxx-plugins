#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <tsfun>
#include <tsx>
#include <xs>
#include <bot_api>


new Bot1
new Bot2

new Float:Time
new bool:Fight = false

new Float:KungFuOrigin1[3] = {-2575.0, -1252.0, -303.0}
new Float:KungFuOrigin2[3] = {-2570.0, -1104.0, -303.0}

public plugin_init()
{
	register_plugin("DRP - KungFu Bots","0.1a","Drak");
	
	register_clcmd("amx_kungbot","CmdSpawn");
	
	register_event("DeathMsg","EventDeath","a");
}


public CmdSpawn(id)
{
	new Bot = create_bot("KungFu Bot #1");
	if(!Bot)
		return PLUGIN_HANDLED
	set_user_info(Bot,"model","Hitman")
	new Bot22 = create_bot("KungFu Bot #2");
	if(!Bot22)
		return PLUGIN_HANDLED
	set_user_info(Bot22,"model","Agent")
	
	Bot1 = Bot
	Bot2 = Bot22
	
	Time = get_gametime()
	
	return set_task(0.1,"_BotSpawn");
}

public _BotSpawn()
{
	DispatchSpawn(Bot1);
	DispatchSpawn(Bot2);
	
	new Float:Angles[3]
	entity_get_vector(Bot1,EV_VEC_angles,Angles);
	Angles[1] += 180.0
	entity_set_vector(Bot1,EV_VEC_angles,Angles);
	
	entity_set_vector(Bot1,EV_VEC_origin,KungFuOrigin1);
	entity_set_vector(Bot2,EV_VEC_origin,KungFuOrigin2);
	
	client_print(0,print_chat,"[KungFu] A Fight Will Begin Shorty. Place your bets!");
	
	set_task(10.0,"_SetUpArea");
	
	new Cage = find_ent_by_tname(-1,"fight_cage");
	//force_use(Bot1,Cage);

}

public _SetUpArea()
{
	//entity_set_float(Bot1,EV_FL_health,800.0);
	//entity_set_float(Bot2,EV_FL_health,800.0);
	
	ts_giveweapon(Bot1,TSW_SKNIFE,5,0);
	ts_giveweapon(Bot2,TSW_SKNIFE,5,0);
	
	set_task(4.0,"_StartFight");
	
	new Alarm = find_ent_by_tname(-1,"fight_count");
	force_use(Bot1,Alarm);
}

public _StartFight()
{
	client_print(0,print_chat,"[KungFu] Fighting has started.. Bets closed");
	Fight = true
}

public EventDeath()
{
	new id = read_data(2);
	if(!id || !Fight)
		return
	
	if(id == Bot1 || id == Bot2)
	{
		new Killer = read_data(1);
		
		new NameLoss[36]
		new NameWin[36]
		
		get_user_name(id,NameLoss,35);
		get_user_name(Killer,NameWin,35);
		client_print(0,print_chat,"[KungFU] %s has been defeated by %s",NameLoss,NameWin);
		
		new FightOver = find_ent_by_tname(-1,"fight_fightover");
		force_use(Killer,FightOver);
		
		Fight = false
	}
}

new g_Move = 1
new g_User = 1
public bot_think(id)
{
	if(!Fight)
		return
	
	new User
	
	static Float:Origin[3],Float:BotOrigin[3]
	entity_get_vector(id,EV_VEC_origin,BotOrigin)	
	
	new Players[32],Playersnum,Player
	get_players(Players,Playersnum,"a")
	
	for(new Count,Float:Distance = 9999999.0,Float:CmpDistance;Count < Playersnum;Count++)
	{
		Player = Players[Count]
		if(Player == id || !fm_is_ent_visible(id,Player))
			continue
		
		entity_get_vector(Player,EV_VEC_origin,Origin)
		
		CmpDistance = vector_distance(Origin,BotOrigin)
		
		if((CmpDistance < Distance))
		{
			Distance = CmpDistance
			User = Player
		}
	}
	
	if(!User)
		return
	
	entity_get_vector(User,EV_VEC_origin,Origin)
	new Float:Distance = vector_distance(Origin,BotOrigin),Buttons = random(2) == 1 ? IN_USE : 0
	
	Origin[2] -= 10.0
	set_bot_angles(id,Origin)
	
	if((User != g_User || g_Move) && is_user_alive(User) && ((User != g_User) || (User == g_User  && Distance > 200.0)))
	{
		new Float:Velocity[3],Float:Factor
		
		for(new Count;Count < 3;Count++)
		{
			Velocity[Count] = 20.0 * (Origin[Count] - BotOrigin[Count])
			
			if(floatabs(Velocity[Count]) > 280.0 && floatabs(Velocity[Count]) >= floatabs(Velocity[0]) && floatabs(Velocity[Count]) >= floatabs(Velocity[1]) && floatabs(Velocity[Count]) >= floatabs(Velocity[2]))
				Factor = floatabs(Velocity[Count]) / 280.0
		}
		
		if(Factor)
			for(new Count;Count < 3;Count++)
				Velocity[Count] /= Factor
			
		if(Velocity[2] > 0.0)
			Velocity[2] = -floatabs(Velocity[2])
			
		entity_set_vector(id,EV_VEC_velocity,Velocity)
	}
	new Dummy,Clip,Ammo,Weapon = ts_getuserwpn(id,Clip,Ammo,Dummy,Dummy)
	switch(Weapon)
	{
		/*
		case TSW_KATANA,TSW_KUNG_FU,TSW_CKNIFE,TSW_SKNIFE:
		{
			Buttons != (Distance < 75.0 && random(2) == 1) ? IN_ATTACK : 0
			if(Buttons & IN_ATTACK && random(2) == 1)
			{
				Buttons |= IN_ATTACK2
				Buttons -= IN_ATTACK
			}
		}
		*/
		default:
		{
			Buttons != (Distance < 75.0 && random(2) == 1) ? IN_ATTACK : 0
			if(Buttons & IN_ATTACK && random(2) == 1)
			{
				Buttons |= IN_ATTACK2
				Buttons -= IN_ATTACK
			}
			/*
			if(Clip == 0)
				Buttons = IN_RELOAD
			else
				Buttons |= random(2) == 1 ? IN_ATTACK : 0
				*/
		}
	}
	set_bot_data(id,bot_buttons,Buttons)
	
	/*
	new Dummy,Clip,Ammo,Weapon = ts_getuserwpn(id,Clip,Ammo,Dummy,Dummy)
	//if(Clip == 0 && Ammo == 0 && Weapon != TSW_KUNG_FU && get_gametime() -  > 5)
		//engclient_cmd(id,"drop")
	
	switch(Weapon)
	{
		case TSW_KATANA,TSW_KUNG_FU,TSW_CKNIFE,TSW_SKNIFE:
		{
			Buttons |= (Distance < 75.0 && random(2) == 1) ? IN_ATTACK : 0
			if(Buttons & IN_ATTACK && random(2) == 1)
			{
				Buttons |= IN_ATTACK2
				Buttons -= IN_ATTACK
			}
		}
		default:
		{			
			if(Clip == 0)
				Buttons = IN_RELOAD
			else
				Buttons |= random(2) == 1 ? IN_ATTACK : 0
		}
	}
		
	set_bot_data(id,bot_buttons,Buttons)
	*/
}

stock bool:fm_is_ent_visible(index, entity) 
{
    new Float:origin[3], Float:view_ofs[3], Float:eyespos[3]
    pev(index, pev_origin, origin)
    pev(index, pev_view_ofs, view_ofs)
    xs_vec_add(origin, view_ofs, eyespos)

    new Float:entpos[3]
    pev(entity, pev_origin, entpos)
    engfunc(EngFunc_TraceLine, eyespos, entpos, 0, index)

    switch (pev(entity, pev_solid)) {
        case SOLID_BBOX..SOLID_BSP: return global_get(glb_trace_ent) == entity
    }
    
    new Float:fraction
    global_get(glb_trace_fraction, fraction)
    if (fraction == 1.0)
        return true

    return false
}
