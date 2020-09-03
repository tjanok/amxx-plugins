#include <amxmodx>
#include <fakemeta_util>

new g_Counter

new const g_DRPModels[1][64] = 
{
	"models/mecklenburg/MeckTubAndToil.mdl"
}

public plugin_precache()
	{ register_forward(FM_SetModel,"fw_SetModel"); register_clcmd("amx_s","S"); register_forward(FM_PrecacheModel,"f"); }

public fw_SetModel(ent,const szModel[])
{
	for(new Count;Count<sizeof(g_DRPModels);Count++)
	{
		if(equal(szModel,g_DRPModels[Count]))
		{
			new EntityName[33]
			pev(ent,pev_targetname,EntityName,32);
		
			set_pev(ent,pev_body,1);
			server_print("CHANGED");
		}
	}
}

public f()
	g_Counter++

public S(id)
{
	server_print("DD");
	
	new Arg[32]
	read_argv(1,Arg,31);
	
	server_print("LOL: %d",g_Counter);
	
	new Num = str_to_num(Arg);
	new ENt2 = fm_find_ent_by_tname(-1,"diner_sign_2");
	if(pev_valid(ENt2))
	{
		dllfunc(DLLFunc_Use,ENt2,ENt2);
		client_print(id,print_console,"PENIS");
	}
	
	client_print(id,print_console,"I");
	new Ent,Name[32]
	while(( Ent = engfunc(EngFunc_FindEntityByString,Ent,"classname","func_wall_toggle")) != 0)
	{
		pev(Ent,pev_targetname,Name,32);
		if(contain(Name,"first_"))
		{
			dllfunc(DLLFunc_Use,Ent,Ent);
			client_print(id,print_console,"USED");
			switch(Num)
			{
				case 1: 
				{
					client_print(id,print_console,"CHANGED TO 1");
					return dllfunc(DLLFunc_Use,id,Ent);
				}
			}
		}
	}
	return 1
}