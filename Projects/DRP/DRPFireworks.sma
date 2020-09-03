#include <amxmodx>
#include <fakemeta>
#include <engine> // for touch
#include <DRP/DRPCore>

// The maximum fireworks a user can spawn
#define MAX_SPAWN_FIREWORKS 3

new g_TrailModel
new g_GlowModel

new const g_Firework[] = "DRP_FWORK"
new const g_LauncherMDL[] = "models/rpgrocket.mdl"
new const g_EffectMDL[] = "sprites/glow01.spr"

// Sounds
new const g_LaunchSound[] = "weapons/rocketfire1.wav"
new const g_ExplodeSound[] = "weapons/explode5.wav"

// User data
new g_DroppedNum[33]

public plugin_precache()
{
	// Models
	precache_model(g_LauncherMDL);
	g_TrailModel = precache_model("sprites/smoke.spr");
	g_GlowModel = precache_model(g_EffectMDL);
	
	// Sounds
	precache_sound(g_LaunchSound);
	precache_sound(g_ExplodeSound);
}

public plugin_init()
{
	// Main
	register_plugin("DRP - Fireworks","0.1a","Drak");
	
	// Forwards
	register_forward(FM_PlayerPreThink,"forward_PreThink");
	register_forward(FM_Think,"forward_Think");
	
	// Engine
	register_touch("*",g_Firework,"forward_Touch");
}

public DRP_Error(const Reason[])
	pause("d");

// TODO: Add more
// Before 4th of july
public DRP_RegisterItems()
{
	DRP_RegisterItem("Basic Firework","_Firework","Shoots up. Explodes.",1);
}

/*==================================================================================================================================================*/
public client_disconnect(id)
	if(g_DroppedNum[id])
		RemoveFireworks(id);
	
/*==================================================================================================================================================*/
public forward_PreThink(const id)
{
	if(g_DroppedNum[id] <= 0)
		return PLUGIN_HANDLED
	
	// we pushed the use key once
	if(!(pev(id,pev_button) & IN_USE && !(pev(id,pev_oldbuttons) & IN_USE)))
		return PLUGIN_HANDLED
	
	new Index = find_ent_by_class(-1,g_Firework);
	if(pev_valid(Index))
	{
		if(entity_get_int(Index,EV_INT_iuser3) == id)
		{
			set_pev(Index,pev_nextthink,get_gametime() + 0.1);
			client_print(id,print_chat,"[DRP] Launched.");
		}
	}
	
	return PLUGIN_HANDLED
}
public forward_Think(const Ent)
{
	if(!Ent)
		return FMRES_IGNORED
	
	static Classname[12]
	pev(Ent,pev_classname,Classname,11);
	
	if(!equali(Classname,g_Firework))
		return FMRES_IGNORED
	
	new Trail = pev(Ent,pev_iuser2);
	if(!Trail)
	{
		new Float:Colors[3]
		pev(Ent,pev_rendercolor,Colors);
		
		emit_sound(Ent,CHAN_AUTO,g_LaunchSound,1.0,ATTN_NORM,0,PITCH_NORM);
		
		message_begin(MSG_BROADCAST,SVC_TEMPENTITY);
		write_byte(TE_BEAMFOLLOW);
		write_short(Ent);
		write_short(g_TrailModel);
		write_byte(10);
		write_byte(10);
		write_byte(floatround(Colors[0]));
		write_byte(floatround(Colors[1]));
		write_byte(floatround(Colors[2]));
		write_byte(125);
		message_end();
		
		pev(Ent,pev_origin,Colors);
		
		message_begin(MSG_BROADCAST,SVC_TEMPENTITY);
		write_byte(TE_LARGEFUNNEL);
		
		write_coord(floatround(Colors[0]));
		write_coord(floatround(Colors[1]));
		write_coord(floatround(Colors[2]));
		
		write_short(g_TrailModel);
		write_short(1);
		
		message_end();
		
		set_pev(Ent,pev_iuser2,1);
	}
	
	static Float:fVelocity[3]
	pev(Ent,pev_velocity,fVelocity);
	
	fVelocity[2] += 400.0 // up/down
	
	set_pev(Ent,pev_velocity,fVelocity);
	set_pev(Ent,pev_nextthink,get_gametime() + 0.1);
	
	return FMRES_HANDLED
}

public forward_Touch(const Touched,const id)
{
	static Classname[8]
	entity_get_string(Touched,EV_SZ_classname,Classname,7);
	
	if(equali(Classname,"player"))
		return PLUGIN_CONTINUE
	
	Explode(id);
}
	
Explode(const id)
{
	if(!(pev(id,pev_iuser2)))
		return
	
	new Owner
	Owner = pev(id,pev_owner);
	
	if(is_user_connected(Owner))
		g_DroppedNum[Owner]--
	
	new Float:Origin[3],Float:fColors[3]
	new Colors[3]
	pev(id,pev_origin,Origin);
	pev(id,pev_rendercolor,fColors);
	
	Colors[0] = floatround(fColors[0]);
	Colors[1] = floatround(fColors[1]);
	Colors[2] = floatround(fColors[2]);
	
	Origin[2] -= 300.0
	
	// --
	message_begin(MSG_BROADCAST,SVC_TEMPENTITY)
	write_byte(TE_BEAMDISK) 				// TE_BEAMDISK
	
	engfunc(EngFunc_WriteCoord,Origin[0]);
	engfunc(EngFunc_WriteCoord,Origin[1]);
	engfunc(EngFunc_WriteCoord,Origin[2]);
	engfunc(EngFunc_WriteCoord,0.0);
	engfunc(EngFunc_WriteCoord,0.0);
	engfunc(EngFunc_WriteCoord,80.0);
	
	write_short(g_TrailModel);
	
	write_byte(0)				// byte (starting frame)
	write_byte(0)				// byte (frame rate in 0.1's)
	write_byte(50)				// byte (life in 0.1's)
	write_byte(0)				// byte (line width in 0.1's)
	write_byte(150)				// byte (noise amplitude in 0.01's)
	write_byte(Colors[0])				// byte,byte,byte (color)
	write_byte(Colors[1])
	write_byte(Colors[2])
	write_byte(255)				// byte (brightness)
	write_byte(0)				// byte (scroll speed in 0.1's)
	message_end()
	// --
	
	// -

	//TE_SPRITETRAIL
	message_begin(MSG_BROADCAST,SVC_TEMPENTITY)
	write_byte (15)	// line of moving glow sprites with gravity, fadeout, and collisions
	
	engfunc(EngFunc_WriteCoord,Origin[0]);
	engfunc(EngFunc_WriteCoord,Origin[1]);
	engfunc(EngFunc_WriteCoord,Origin[2]);
	engfunc(EngFunc_WriteCoord,Origin[0]);
	engfunc(EngFunc_WriteCoord,Origin[1]);
	engfunc(EngFunc_WriteCoord,Origin[2] - 80.0);
	
	write_short(g_GlowModel) // (sprite index)
	write_byte(50) // (count)
	write_byte(2) // (life in 0.1's) 
	write_byte(10) // byte (scale in 0.1's) 
	write_byte(50) // (velocity along vector in 10's)
	write_byte(40) // (randomness of velocity in 10's)

	message_end()
	
	//--
	
	new iPlayers[32],iNum,Index
	get_players(iPlayers,iNum);

	new Float:plOrigin[3]
	// push down
	Origin[2] -= 500.0
	
	for(new Count;Count < iNum;Count++)
	{
		Index = iPlayers[Count]
		
		if(!is_user_alive(Index))
			continue
		
		pev(Index,pev_origin,plOrigin);
		if(get_distance_f(Origin,plOrigin) < 800.0)
			client_cmd(Index,"spk ^"%s^"",g_ExplodeSound);
	}
	
	engfunc(EngFunc_RemoveEntity,id);
}
/*==================================================================================================================================================*/
public _Firework(id,ItemID,Type)
{
	if(g_DroppedNum[id] + 1 > MAX_SPAWN_FIREWORKS)
	{
		client_print(id,print_chat,"[DRP] You can only spawn up to %d fireworks",MAX_SPAWN_FIREWORKS);
		return ITEM_KEEP_RETURN
	}
	
	new Float:pOrigin[3],Origin[3]
	get_user_origin(id,Origin,3);
	IVecFVec(Origin,pOrigin);
	
	new Float:newOrigin[3]
	entity_get_vector(id,EV_VEC_origin,newOrigin);
	
	if(vector_distance(newOrigin,pOrigin) > 200.0)
	{
		client_print(id,print_chat,"[DRP] Placement to far. The firework is placed where you are aiming.");
		return PLUGIN_HANDLED
	}
	
	pOrigin[2] += 10
	
	new Ent = create_entity("info_target");
	if(!Ent)
	{
		client_print(id,print_chat,"[DRP] Unable to create firework; please contact an administrator.");
		return ITEM_KEEP_RETURN
	}
	
	g_DroppedNum[id]++
	
	entity_set_string(Ent,EV_SZ_classname,g_Firework);
	entity_set_int(Ent,EV_INT_solid,SOLID_BBOX);
	entity_set_int(Ent,EV_INT_movetype,MOVETYPE_TOSS);
	entity_set_int(Ent,EV_INT_iuser3,id);
	
	entity_set_origin(Ent,pOrigin);
	entity_set_model(Ent,g_LauncherMDL);
	entity_set_size(Ent,Float:{-8.0,-8.0,-10.0},Float:{8.0,8.0,10.0});
	
	new Float:Color[3]
	Color[0] = random_float(50.0,255.0);
	Color[1] = random_float(50.0,255.0);
	Color[2] = random_float(50.0,255.0);
	
	set_pev(Ent,pev_rendermode,kRenderNormal);
	set_pev(Ent,pev_renderfx,kRenderFxGlowShell);
	set_pev(Ent,pev_rendercolor,Color);
	set_pev(Ent,pev_renderamt,16);
	
	pOrigin[0] = 90.0
	pOrigin[1] = random_float(0.0,360.0);
	pOrigin[2] = 0.0
	
	entity_set_vector(Ent,EV_VEC_angles,pOrigin);
	
	/*
	entity_set_string(Ent,EV_SZ_classname,g_Firework);
	entity_set_edict(Ent,EV_ENT_owner,id);
	entity_set_int(Ent,EV_INT_solid,SOLID_BBOX);
	
	new Float:Color[3]
	Color[0] = random_float(50.0,255.0);
	Color[1] = random_float(50.0,255.0);
	Color[2] = random_float(50.0,255.0);
	
	set_pev(Ent,pev_rendermode,kRenderNormal);
	set_pev(Ent,pev_renderfx,kRenderFxGlowShell);
	set_pev(Ent,pev_rendercolor,Color);
	set_pev(Ent,pev_renderamt,16);
	
	new Float:plOrigin[3]
	pev(id,pev_origin,plOrigin);
	plOrigin[2] += 50.0
	
	engfunc(EngFunc_SetOrigin,Ent,plOrigin);
	engfunc(EngFunc_SetModel,Ent,g_LauncherMDL);
	entity_set_size(Ent,Float:{-8.0,-8.0,-8.0},Float:{8.0,8.0,36.0});
	
	//engfunc(EngFunc_DropToFloor,Ent);
	plOrigin[0] = 90.0
	plOrigin[1] = random_float(0.0,360.0);
	plOrigin[2] = 0.0
	
	//set_pev(Ent,pev_angles,plOrigin);
	
	DrawBox(Ent);
	
	client_cmd(id,"spk ^"items/ammopickup1.wav^"");
	client_print(id,print_chat,"[DRP] You have dropped a firework, press the ^"use^" key to start firing.");
	*/
	
	return PLUGIN_HANDLED
}
/*==================================================================================================================================================*/
RemoveFireworks(id)
{
	new Ent = 0
	while(( Ent = engfunc(EngFunc_FindEntityByString,-1,"classname",g_Firework)) != 0)
		if(pev(Ent,pev_owner) == id)
			engfunc(EngFunc_RemoveEntity,Ent);
		
	g_DroppedNum[id] = 0
}