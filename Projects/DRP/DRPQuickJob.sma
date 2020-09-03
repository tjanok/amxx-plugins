// Quick and Dirty
// Just the way I like it.

#include <amxmodx>

#include <DRP/DRPCore>
#include <DRP/DRPChat>
#include <DRP/DRPNpc>

new g_Menu

public plugin_precache()
	DRP_RegisterNPC("Job Manager",Float:{-1475.0, -2150.0, -370.0},-90.0,"models/mecklenburg/bankerd_new.mdl","_JobHandle");

public plugin_init()
{
	register_plugin("DRP - Job Guy","0.1a","Drak");
	register_clcmd("say /jobs","CmdJobs");
}

// Backwards-Compatable for ARP / Harbu Users
public CmdJobs(id)
	return client_print(id,print_chat,"[DRP] Please vist the Job Manager in the Government Building.");

public _JobHandle(id,Ent)
{
	if(!is_user_alive(id))
		return
	
	menu_display(id,g_Menu);
}

public _JobMenuHandle(id,Menu,Item)
{
	if(Item == MENU_EXIT)
		return PLUGIN_HANDLED
	
	new Temp,Info[2],JobName[33]
	menu_item_getinfo(Menu,Item,Temp,Info,1,JobName,32,Temp);
	
	new JobID = DRP_FindJobID2(JobName);
	if(!DRP_ValidJobID(JobID))
	{
		client_print(id,print_chat,"[DRP] An error has occured; please contact an Administrator.");
		return PLUGIN_HANDLED
	}
	
	client_print(id,print_chat,"[DRP] You have now been employed to: %s",JobName);
	DRP_SetUserJobID(id,JobID);
	
	return PLUGIN_HANDLED
}

// --------------------------------------------------
public DRP_JobsInit()
	SQL_ThreadQuery(DRP_SqlHandle(),"LoadJobsToMenu","SELECT * FROM `Jobs`");

public LoadJobsToMenu(FailState,Handle:Query,const Error[],Errcode,const Data[],DataSize) 
{
	if(FailState != TQUERY_SUCCESS || Errcode)
		return log_amx("[SQL] SQL Connection Failed (Error: %s)",Error ? Error : "UNKNOWN");
	
	new Temp[36]
	g_Menu = menu_create("Job Menu","_JobMenuHandle");
	
	while(SQL_MoreResults(Query))
	{
		SQL_ReadResult(Query,2,Temp,35);
		
		if(Temp[0] != 'e')
		{
			SQL_NextRow(Query);
			continue
		}
		
		SQL_ReadResult(Query,0,Temp,35);
		
		if(equali(Temp,"Unemployed"))
		{
			SQL_NextRow(Query);
			continue
		}
		
		menu_additem(g_Menu,Temp);
		
		SQL_NextRow(Query);
	}
	menu_addtext(g_Menu,"^nNOTE:^nSome jobs give perks,^nafter selecting a job type:^n^n/jobinfo");
	return PLUGIN_CONTINUE
}