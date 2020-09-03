/*
* DRPBlockModels.sma
* ---------------------------
* This plugin will block models via SteamID, Job Access, along
* with precache models with the wildcard "*p"
* 
* UPDATE:
* We now set models based by job (make sure we precache them!)
* 
* NOTES:
* The model information is not cached, it reads the file each time a player
* changes his/her model. (This might be changed in the future)
*/

#include <amxmodx>
#include <DRP/DRPCore>
#include <hamsandwich>
#include <cellarray>

new const DEFAULT_MODEL[] = "gordon"
new g_ConfigDir[256]

new Array:g_Models
new g_ModelNum

// PCvars
new p_Enable

public plugin_precache()
{
	g_Models = ArrayCreate(64);
	
	DRP_GetConfigsDir(g_ConfigDir,255);
	add(g_ConfigDir,255,"/DRP-Models.ini");
	
	if(!file_exists(g_ConfigDir))
	{
		server_print("[DRP-BlockModels] Creating Config File..");
		write_file(g_ConfigDir,"");
		
		return
	}
	
	new pFile = fopen(g_ConfigDir,"rt");
	if(!pFile)
	{
		DRP_ThrowError(0,"Unable to open file. (%s)",g_ConfigDir);
		return
	}
	
	// Check if we should precache a model
	new Data[128],Temp[2],Left[65]
	while(!feof(pFile))
	{
		fgets(pFile,Data,127);
		
		if(!Data[0] || Data[0] == ';')
			continue
		
		ArrayPushString(g_Models,Data);
		g_ModelNum++
		
		if(containi(Data,"*P") == -1)
			continue
		
		// Add the file path
		strbreak(Data,Left,64,Temp,1);
		format(Data,127,"models/player/%s/%s.mdl",Left,Left);
		
		if(!file_exists(Data))
		{
			server_print("[DRP-BlockModels] Unable to precache model (%s)",Left);
			continue
		}
		
		server_print("[DRP-BlockModels] Precaching Model: %s",Data);
		precache_generic(Data);
	}
	fclose(pFile);
}
public plugin_init()
{
	// Main
	register_plugin("DRP - Block Models","0.1a","Drak");
	
	// Events
	RegisterHam(Ham_Spawn,"player","EventPlayerSpawn",1);
}

public DRP_Error(const Reason[])
	pause("d");

public DRP_Init()
{
	// CVars
	p_Enable = register_cvar("DRP_BlockModels","1");
}
/*==================================================================================================================================================*/
public EventPlayerSpawn(const id)
	if(is_user_alive(id))
		client_infochanged(id);
	
public client_infochanged(id)
{
	if(!is_user_alive(id))
		return PLUGIN_CONTINUE
	
	if(!get_pcvar_num(p_Enable)  || DRP_IsAdmin(id))
		return PLUGIN_CONTINUE
	
	static Model[33]
	get_user_info(id,"model",Model,32);
	
	if(!CheckAccess(id,Model))
	{
		client_print(id,print_chat,"[DRP] Sorry, you do not have access to this model.");
		set_user_info(id,"model",DEFAULT_MODEL);
		return PLUGIN_HANDLED
	}
	
	return PLUGIN_CONTINUE
}
/*==================================================================================================================================================*/
bool:CheckAccess(id,const Model[])
{
	if(!is_user_connected(id))
		return false
	
	static Data[128],szModel[33],Access[33]
	new bool:Valid = false,bool:Found = false
	
	for(new Count;Count < g_ModelNum;Count++)
	{
		ArrayGetString(g_Models,Count,Data,127);
		strbreak(Data,szModel,32,Access,32);
		
		// It's a precache model
		if(Access[0] == '*')
			continue
		
		if(equali(szModel,Model))
		{
			new AccessStr = DRP_AccessToInt(Access);
			if((DRP_GetUserAccess(id) & AccessStr) || (DRP_GetUserJobRight(id) & AccessStr))
				Valid = true;
			
			Found = true
			break
		}
	}
	
	return Found ? Valid : true
}

public plugin_end()
	ArrayDestroy(g_Models);