#include <amxmodx>
#include <DRP/DRPCore>
#include <engine>
#include <amxmisc>

new const g_Trees[2][] = {
	"models/OZDRP/christmas/tree1.mdl",
	"models/OZDRP/christmas/tree2.mdl"
}

new const g_SnowMan[] = "models/OZDRP/christmas/snowman.mdl"
new const g_EntName[] = "DRP_CHRISTMAS"

public plugin_precache()
{
	for(new Count;Count < sizeof(g_Trees);Count++)
		precache_model(g_Trees[Count]);
	
	precache_model(g_SnowMan);
	
	new File[128]
	DRP_GetConfigsDir(File,127);
	add(File,127,"/Christmas.ini");
	
	new pFile = fopen(File,"r");
	if(!pFile)
		return
	
	new Buffer[128],Type[33],Origin[33],Exploded[3][12],ItemName[33],Angle[11]
	new Float:vOrigin[3]
	
	while(!feof(pFile))
	{
		fgets(pFile,Buffer,127);
		
		if(!Buffer[0] || Buffer[0] == ';')
			continue
		
		Type[0] = 0
		ItemName[0] = 0
		Angle[0] = 0
		Origin[0] = 0
		
		parse(Buffer,Type,32,Origin,32,ItemName,32,Angle,10);
		
		remove_quotes(Type);
		remove_quotes(Origin);
		remove_quotes(ItemName);
		remove_quotes(Angle);
		
		parse(Origin,Exploded[0],11,Exploded[1],11,Exploded[2],11);
		
		for(new Count;Count < 3;Count++)
			vOrigin[Count] = str_to_float(Exploded[Count]);
		
		CreateProp(str_to_num(Type),vOrigin,ItemName,str_to_float(Angle));
	}
	fclose(pFile);
	register_clcmd("drp_moveprops","CmdMove");
}

public plugin_init()
{
	// Main
	register_plugin("DRP - Christmas","0.1a","Drak");
	
	// Events
	DRP_RegisterEvent("Player_UseEntity","EventUseEntity");

	// Thinks
	register_think(g_EntName,"EventEntityThink");
}

CreateProp(Type,Float:Origin[3],const ItemName[],Float:Angle)
{
	new Ent = create_entity("info_target");
	if(!Ent)
		return
	
	switch(Type)
	{
		case 1:
		{
			new Random = random(2);
			entity_set_model(Ent,g_Trees[Random]);
			set_rendering(Ent,kRenderFxGlowShell,0,125,0);
			if(Random == 1)
				entity_set_size(Ent,Float:{-10.0,-10.0,-10.0},Float:{10.0,10.0,21.0});
			else
				entity_set_size(Ent,Float:{-10.0,-10.0,-1.0},Float:{10.0,10.0,21.0});
		}
		case 2:
		{
			entity_set_model(Ent,g_SnowMan);
			entity_set_size(Ent,Float:{-8.0,-8.0,-5.0},Float:{8.0,8.0,25.0});
		}
	}
	
	entity_set_int(Ent,EV_INT_solid,SOLID_BBOX);
	entity_set_int(Ent,EV_INT_movetype,MOVETYPE_PUSHSTEP);
	entity_set_float(Ent,EV_FL_friction,0.1);
	
	entity_set_string(Ent,EV_SZ_message,ItemName);
	entity_set_string(Ent,EV_SZ_classname,g_EntName);
	entity_set_float(Ent,EV_FL_nextthink,get_gametime() + 100.0);
	
	entity_set_origin(Ent,Origin);
	
	Origin[0] = 0.0
	Origin[1] = Angle - 180
	Origin[2] = 0.0
	
	entity_set_vector(Ent,EV_VEC_angles,Origin);
	drop_to_floor(Ent);
}

public EventUseEntity(const Name[],const Data[],Len)
{
	new const id = Data[0],Index = Data[1]
	if(!is_user_connected(id))
		return PLUGIN_CONTINUE
	
	static Classname[16]
	entity_get_string(Index,EV_SZ_classname,Classname,15);
	
	if(!equali(Classname,g_EntName))
		return PLUGIN_CONTINUE
	
	client_print(id,print_chat,"[DRP] Merry Christmas!");
	return PLUGIN_HANDLED
}

public EventEntityThink(const ent)
{
	new iPlayers[32],iNum,Player
	get_players(iPlayers,iNum);
	
	new Float:Origin[3],Float:IndexOrigin[3]
	entity_get_vector(ent,EV_VEC_origin,IndexOrigin);
	
	for(new Count;Count < iNum;Count++)
	{
		Player = iPlayers[Count]
		
		if(!is_user_alive(Player))
			continue
		
		entity_get_vector(Player,EV_VEC_origin,Origin);
		
		// He might be close enough
		if(vector_distance(Origin,IndexOrigin) <= 400.0)
		{
			new Float:Velocity[3],Float:Factor
			
			for(new Count;Count < 3;Count++)
			{
				Velocity[Count] = 20.0 * (Origin[Count] - IndexOrigin[Count]);
				
				if(floatabs(Velocity[Count]) > 280.0 && floatabs(Velocity[Count]) >= floatabs(Velocity[0]) && floatabs(Velocity[Count]) >= floatabs(Velocity[1]) && floatabs(Velocity[Count]) >= floatabs(Velocity[2]))
					Factor = floatabs(Velocity[Count]) / 280.0
			}
			if(Factor)
				for(new Count;Count < 3;Count++)
					Velocity[Count] /= Factor
			
			if(Velocity[2] > 0.0)
				Velocity[2] = -floatabs(Velocity[2]);
			
			entity_set_vector(ent,EV_VEC_velocity,Velocity);
			break
		}
	}
	
	entity_set_float(ent,EV_FL_nextthink,get_gametime() + 100.0);
}

public CmdMove(id,level,cid)
{
	if(!DRP_CmdAccess(id,cid,1))
		return PLUGIN_HANDLED
	
	new Arg[33],Task
	read_argv(1,Arg,32);
	
	new Index,Body
	get_user_aiming(id,Index,Body);
	
	new Classname[33]
	entity_get_string(Index,EV_SZ_classname,Classname,32);
	
	if(containi(Classname,"func_") != -1)
		return PLUGIN_HANDLED
	
	if(Arg[0])
	{
		new Data[2]
		Data[0] = id
		Data[1] = Index
		
		set_task(0.1,"Follow",_,Data,2);
		return PLUGIN_HANDLED
	}
	
	new Float:Origin[3],Float:IndexOrigin[3]
	entity_get_vector(id,EV_VEC_origin,Origin);
	entity_get_vector(Index,EV_VEC_origin,IndexOrigin);
	
	new Float:Velocity[3],Float:Factor
	
	for(new Count;Count < 3;Count++)
	{
		Velocity[Count] = 20.0 * (Origin[Count] - IndexOrigin[Count]);
		
		if(floatabs(Velocity[Count]) > 280.0 && floatabs(Velocity[Count]) >= floatabs(Velocity[0]) && floatabs(Velocity[Count]) >= floatabs(Velocity[1]) && floatabs(Velocity[Count]) >= floatabs(Velocity[2]))
			Factor = floatabs(Velocity[Count]) / 280.0
	}
	if(Factor)
		for(new Count;Count < 3;Count++)
			Velocity[Count] /= Factor
	
	if(Velocity[2] > 0.0)
		Velocity[2] = -floatabs(Velocity[2]);
	
	entity_set_vector(Index,EV_VEC_velocity,Velocity);
	
	return PLUGIN_HANDLED
}

public Follow(const Params[])
{
	new const id = Params[0],Ent = Params[1]
	if(!is_user_alive(id) || !is_valid_ent(Ent))
		return
	
	static Float:Origin[3],Float:IndexOrigin[3]
	entity_get_vector(id,EV_VEC_origin,Origin);
	entity_get_vector(Ent,EV_VEC_origin,IndexOrigin);
	
	new Float:Velocity[3],Float:Factor
	
	for(new Count;Count < 3;Count++)
	{
		Velocity[Count] = 20.0 * (Origin[Count] - IndexOrigin[Count]);
		
		if(floatabs(Velocity[Count]) > 280.0 && floatabs(Velocity[Count]) >= floatabs(Velocity[0]) && floatabs(Velocity[Count]) >= floatabs(Velocity[1]) && floatabs(Velocity[Count]) >= floatabs(Velocity[2]))
			Factor = floatabs(Velocity[Count]) / 280.0
	}
	if(Factor)
		for(new Count;Count < 3;Count++)
			Velocity[Count] /= Factor
	
	if(Velocity[2] > 0.0)
		Velocity[2] = -floatabs(Velocity[2]);
	
	entity_set_vector(Ent,EV_VEC_velocity,Velocity);
	set_task(0.1,"Follow",_,Params,2);
}