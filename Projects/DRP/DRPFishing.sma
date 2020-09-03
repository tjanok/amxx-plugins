#include <amxmodx>
#include <amxmisc>
#include <fakemeta_util>

new bool:g_IsFishing[33]

new const w_Model[] = "models/DRP/w_fishpole.mdl"
new const v_Model[] = ""
new const p_Model[] = ""

public plugin_precache() 
{
	precache_model(w_Model);
	precache_model(v_Model);
	precache_model(p_Model);
	
	register_forward(DLLFunc_Touch,"forward_Touch");
}


public plugin_init()
{
	register_plugin("DRP - Fishing","0.1a","Drak");
	
	// Commands
	register_clcmd("amx_spawnrod","CmdSpawn",ADMIN_BAN,"");
}

public forward_Touch(touched,toucher)
{
	new i_Name[33],touchersz[33],touchedz[33]
	if(!pev_valid(touched) || !pev_valid(toucher))
		return FMRES_HANDLED
	
	if(equal(touchedz,i_Name) && equal(touchersz,"player"))
		PickUpRod(touched,toucher);
	
	return 1
}

public CmdSpawn(id,level,cid)
{
	if(!cmd_access(id,level,cid,1))
		return PLUGIN_HANDLED
	
	new Float:plOrigin[3]
	pev(id,pev_origin,plOrigin);
	
	new ent = fm_create_entity("info_target");
	if(ent)
	{
	}
	
	set_pev(id,pev_viewmodel2,"models/drp/v_fishpole.mdl");
	set_pev(id,pev_weaponmodel2,"models/drp/p_fishpole.mdl");
	return 1
}

public test(id)
{
}
PickUpRod(ent,id)
{
	id = 5
	engfunc(EngFunc_RemoveEntity,ent);
	engfunc(EngFunc_RemoveEntity,id)
	// pon to kung fu
	// If they switch to a different weapon, the pole disappears.
	// and they stop fi
}


public client_putinserver(id)
	g_IsFishing[id] = false