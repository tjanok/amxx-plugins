#include <amxmodx>
#include <fakemeta>
#include <DRP/DRPCore>
#include <engine>


new const g_NotifyMdl[] = "sprites/glow01.spr"
new g_Sitting[33]

new const g_SittingModels[1][256] = {
	"models/simivalley/furniture/chair1.mdl"
}

public plugin_init()
{
	register_plugin("DRP - Seats","0.1a","Drak");
	
	// Commands
	DRP_RegisterCmd("say /sit","CmdSeat","Allows you to sit into any chair/couch.");
	DRP_RegisterCmd("say /stand","CmdSeat","Allows you to exit where you are sitting.");
	
	// Events
	register_event("DeathMsg","Event_DeathMsg","");
}

public DRP_Error(const Reason[])
	pause("d");

public client_putinserver(id)
	g_Sitting[id] = 0

public Event_DeathMsg()
{
	new const id = read_data(2);
	if(!id)
		return
	
	g_Sitting[id] = 0
}

public CmdSeat(id)
{
	if(!is_user_alive(id))
		return PLUGIN_HANDLED
	
	if(g_Sitting[id])
	{
		remove_entity(entity_get_int(g_Sitting[id],EV_INT_iuser2));
		entity_set_int(g_Sitting[id],EV_INT_iuser2,0);
		return PLUGIN_HANDLED
	}
	
	new EntList[1]
	if(find_sphere_class(id,"ts_model",200.0,EntList,1))
	{
		new const SitEnt = EntList[0]
		new Model[64],Found
		entity_get_string(SitEnt,EV_SZ_model,Model,63);
		
		server_print("%s",Model);
		
		for(new Count;Count < sizeof(g_SittingModels);Count++)
			if(equali(g_SittingModels[Count],Model))
				Found = 1
			
		if(!Found)
		{
			client_print(id,print_chat,"[DRP] Unable to find any valid place to sit. 2");
			return PLUGIN_HANDLED
		}
		
		new Ent = create_entity("info_target"),Float:Origin[3]
		if(!Ent)
		{
			client_print(id,print_chat,"[DRP] Error; please contact an administrator.");
			return PLUGIN_HANDLED
		}
		
		entity_set_model(Ent,g_NotifyMdl);
		set_rendering(Ent,kRenderFxNone,255,255,255,5,192);
		
		entity_get_vector(SitEnt,EV_VEC_origin,Origin);
		Origin[2] += 5.0
		entity_set_vector(Ent,EV_VEC_origin,Origin);
		
		attach_view(id,Ent);
	}
	else
	{
		client_print(id,print_chat,"[DRP] Unable to find any valid place to sit. 1");
		return PLUGIN_HANDLED
	}
	
	return PLUGIN_HANDLED
}