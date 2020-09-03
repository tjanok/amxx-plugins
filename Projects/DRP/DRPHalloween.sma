#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <DRP/DRPCore>
new g_Ent
new g_Ent2
public plugin_precache()
{
	new Float:fOrigin[3] = { 2316.0, 1483.0, -412.0}
	new const g_Model[] = "models/OZDRP/Cars/car_drp_daloreanv2.mdl"
	precache_model(g_Model);
	
	precache_model(g_Model);
	
	new Ent = create_entity("info_target");
	g_Ent = Ent
	entity_set_int(Ent,EV_INT_solid,SOLID_SLIDEBOX);
	entity_set_int(Ent,EV_INT_movetype,MOVETYPE_PUSHSTEP);
	entity_set_string(Ent,EV_SZ_classname,"derp");
	set_pev(Ent,pev_friction,0.1);
	
	entity_set_model(Ent,g_Model);
	entity_set_origin(Ent,fOrigin);
	
	RenderBox(Ent);
	entity_set_size(Ent,Float:{-75.0,-60.0,0.0},Float:{75.0,60.0,60.0});
	entity_set_float(Ent,EV_FL_nextthink,halflife_time() + 0.01)
	
	drop_to_floor(Ent);
	
	//register_think("derp","derpfunc");
	
	/*
	new sprite = create_entity("info_target");
	entity_set_model(sprite,"sprites/glow01.spr");
	entity_set_edict(sprite,EV_ENT_owner,Ent);
	set_rendering(sprite,kRenderFxNone,255,255,255,kRenderGlow,200);
	entity_set_origin(sprite,fOrigin);
	entity_set_int(sprite,EV_INT_skin,Ent);
	entity_set_int(sprite,EV_INT_body,1);
	entity_set_edict(sprite,EV_ENT_aiment,Ent);
	entity_set_int(sprite,EV_INT_movetype,MOVETYPE_FOLLOW);
	entity_set_int(sprite,EV_INT_solid,SOLID_NOT);
	entity_set_int(sprite,EV_INT_sequence,( entity_get_int(sprite,EV_INT_sequence) & 0x0FFF) | ((1 & 0xF) << 12))
	
	new sprite2 = create_entity("info_target");
	entity_set_model(sprite2,"sprites/glow01.spr");
	entity_set_edict(sprite2,EV_ENT_owner,Ent);
	set_rendering(sprite2,kRenderFxNone,255,255,255,kRenderGlow,200);
	entity_set_origin(sprite2,fOrigin);
	entity_set_int(sprite2,EV_INT_skin,Ent);
	entity_set_int(sprite2,EV_INT_body,2);
	entity_set_edict(sprite2,EV_ENT_aiment,Ent);
	entity_set_int(sprite2,EV_INT_movetype,MOVETYPE_FOLLOW);
	entity_set_int(sprite2,EV_INT_solid,SOLID_NOT);
	entity_set_int(sprite2,EV_INT_sequence,( entity_get_int(sprite2,EV_INT_sequence) & 0x0FFF) | ((2 & 0xF) << 12))
	*/
	//g_Ent2 = sprite
	
	
	register_clcmd("amx_v","velo");
	register_clcmd("amx_vv","cam");
}

public derpfunc(Ent)
{
	static Float:cOrigin[3],tOrigin[3],Camera
	entity_get_vector(Ent,EV_VEC_origin,cOrigin);
	
	Camera = entity_get_int(Ent,EV_INT_iuser2);
	if(Camera)
		entity_get_vector(Camera,EV_VEC_origin,tOrigin);
	
	cOrigin[2] += 45.0
	cOrigin[1] += 12.0
	cOrigin[0] -= 5.0
	
	entity_set_vector(Camera,EV_VEC_origin,cOrigin);
	entity_get_vector(Ent,EV_VEC_angles,cOrigin);
	entity_set_vector(Camera,EV_VEC_angles,cOrigin);
	entity_set_float(Ent,EV_FL_nextthink,halflife_time() + 0.01)
}


public cam(id)
	attach_view(id,g_Ent2);
public velo(id)
{
	new Index,Body
	get_user_aiming(id,Index,Body,200);
	
	new Ent = Index
	
	new sprite2 = create_entity("info_target");
	entity_set_model(sprite2,"sprites/glow01.spr");
	entity_set_edict(sprite2,EV_ENT_owner,Ent);
	set_rendering(sprite2,kRenderFxNone,255,255,255,kRenderGlow,200);
	entity_set_int(sprite2,EV_INT_skin,Ent);
	entity_set_int(sprite2,EV_INT_body,2);
	entity_set_edict(sprite2,EV_ENT_aiment,Ent);
	entity_set_int(sprite2,EV_INT_movetype,MOVETYPE_FOLLOW);
	entity_set_int(sprite2,EV_INT_solid,SOLID_NOT);
}

public RenderBox(const Ent)
{
	new Float:Origin[3],Float:Mins[3],Float:Maxs[3]
	pev(Ent,pev_origin,Origin);
	
	pev(Ent,pev_absmin,Mins);
	pev(Ent,pev_absmax,Maxs);
	
	engfunc(EngFunc_MessageBegin,MSG_BROADCAST,SVC_TEMPENTITY,Origin,0);
	write_byte(TE_BOX);
	
	engfunc(EngFunc_WriteCoord,Mins[0]);
	engfunc(EngFunc_WriteCoord,Mins[1]);
	engfunc(EngFunc_WriteCoord,Mins[2]);
	engfunc(EngFunc_WriteCoord,Maxs[0]);
	engfunc(EngFunc_WriteCoord,Maxs[1]);
	engfunc(EngFunc_WriteCoord,Maxs[2]);
	
	write_short(15);
	
	write_byte(10);
	write_byte(100);
	write_byte(150);
	
	message_end();
	
	set_task(1.0,"RenderBox",Ent);
}
