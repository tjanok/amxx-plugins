#include <amxmodx>
#include <fakemeta>
#include <cellarray>

new Array:g_PrecachedModels
new g_PrecachedModelNum

// Brushes
new g_PrecachedDoors
new g_PrecachedWalls
new g_PrecachedButtons
new g_PrecachedBreakables

new g_ForwardID
new g_ForwardID2

public plugin_precache()
{
	// Main
	register_plugin("DRP - Ent Stuff","0.1a","Drak");
	
	// Arrays
	g_PrecachedModels = ArrayCreate(64,64);
	
	// Commands
	register_srvcmd("DRP_EntInfo","CmdEntInfo");
	
	// Forwards
	g_ForwardID = register_forward(FM_SetModel,"forward_SetModel");
	g_ForwardID2 = register_forward(FM_PrecacheModel,"forward_PrecacheModel");
	
}

public plugin_init()
{
	// Entity's created "late" will set a model
	// We just want to cache brush models, which by the time this calls, there done spawning
	unregister_forward(FM_SetModel,g_ForwardID);
	unregister_forward(FM_PrecacheModel,g_ForwardID2);
}

public CmdEntInfo(id)
{
	new const totalPrecaches = (g_PrecachedModelNum + g_PrecachedBreakables + g_PrecachedButtons + g_PrecachedDoors + g_PrecachedWalls)
	server_print("^n[DRP-ENTINFO]^nTotal Model Based Precaches: #%d (#%d precaches left until limit)^nModels: #%d^nButtons: #%d^nDoors: #%d^nWalls: #%d^nBreakables: #%d^n[DRP-ENTINFO]^n",
	totalPrecaches,512-totalPrecaches,g_PrecachedModelNum,g_PrecachedButtons,g_PrecachedDoors,g_PrecachedWalls,g_PrecachedButtons);
	return PLUGIN_HANDLED
}
public forward_SetModel(const Ent,const Model[])
{
	// Brush based model
	static arrayModel[64]
	if(containi(Model,"*") != -1)
	{
		pev(Ent,pev_classname,arrayModel,63);
		if(containi(arrayModel,"func_door") != -1)
			g_PrecachedDoors++
		else if(containi(arrayModel,"func_wall") != -1 || containi(arrayModel,"func_illusionary") != -1)
			g_PrecachedWalls++
		else if(containi(arrayModel,"func_button") != -1)
			g_PrecachedButtons++
		else if(containi(arrayModel,"func_breakable") != -1)
			g_PrecachedBreakables++
		
		return
	}
}
public forward_PrecacheModel(const Model[])
{
	new arrayModel[64]
	new Found
	
	for(new Count;Count < g_PrecachedModelNum;Count++)
	{
		ArrayGetString(g_PrecachedModels,Count,arrayModel,63);
		if(equali(arrayModel,Model))
		{
			Found = 1
			break
		}
	}
	
	if(!Found)
	{
		ArrayPushString(g_PrecachedModels,Model);
		g_PrecachedModelNum++
	}
}