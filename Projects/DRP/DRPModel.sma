//////////////////////////////////////////
// DRPModels.sma
// -------------------------
// Forces player's to wear a specific model - if they are a specfic job
//

#include <amxmodx>
#include <DRP/DRPCore>

new const g_CopModels[3][] =
{
	"models/player/collector-cop/collector-cop.mdl",
	"models/player/collector-cop/collector-cop1.mdl",
	"models/player/collector-cop/collector-cop2.mdl"
};

new const g_DoctorModels[][] =
{
};

public plugin_init()
{
	// Main
	register_plugin("DRP - Force Models","0.1a","Drak");
	
	// Tasks
	set_task(1.0,"CheckPlayers",_,_,"b");
}

public CheckPlayers()
{
	new iPlayers[32],iNum
	get_players(iPlayers,iNum);
	
	for(new Count;Count


// Old
// Dynamic - User Friendly. Well, I'm lazy and this needs to be done now. So we're not doing it this way
/*

#define MAX_MODELS 12

enum DATA
{
	MODEL = 0,
	FLAGS
}

new g_Models[MAX_MODELS][DATA][33]
new g_ModelsNum

new const g_ModelString[] = "model"

public plugin_init()
{
	// Main
	register_plugin("DRP - Model Helper","0.1a","Drak");
	
	// Tasks
	set_task(1.0,"CheckPlayers",_,_,"b");
}

public DRP_Error(const Reason[])
	pause("d");

public DRP_Init()
{
	p_Enable = register_cvar("DRP_BlockModels","1");
	
	DRP_GetConfigsDir(g_ModelFile,127);
	add(g_ModelFile,127,"/DRPModels.ini");
	if(!file_exists(g_ModelFile))
		write_file(g_ModelFile,"");
}
public CheckPlayers()
{
	static Access,ModelAccess
	static PlayerModel[33]
	
	for(new Count,Count2;Count <= g_MaxPlayers;Count++)
	{
		if(!is_user_alive(Count))
			continue
		
		Access = DRP_GetUserAccess(Count);
		get_user_info(Count,g_ModelString,PlayerModel,32);
		
		for(Count2=0;Count2 < g_ModelNum;Count2++)
		{
			ModelAccess = DRP_AccessToInt(g_Models[Count2][FLAGS]);
			if(ModelAccess & Access)
			{
				// Okay - We found en entry with our access
				// Make sure our model, matches the model in the entry
				if(!equali(g_Models[Count2][MODEL],PlayerModel))
				{
					set_user_info(Count,g_ModelString,g_Models[Count2][MODEL]);
					client_print(id,print_chat,"[DRP] Your model has been changed because of your job.");
		}
	}
}
/*==================================================================================================================================================*/