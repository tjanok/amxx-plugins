#include <amxmodx>
#include <amxmisc>
#include <DRP/DRPCore>
#include <DRP/DRPChat>

new g_LogFile[256]
new const g_MessageMode[] = "Type_Job_Description"

new Array:g_JobApps
new g_JobAppsNum

new g_UserJobName[33][33]
new g_Menu

public DRP_Init()
{
	g_JobApps = ArrayCreate();
	LoadFile();
	
	// Menus
	g_Menu = menu_create("","UserJobApply");
	menu_additem(g_Menu,"Stop");
	menu_addtext(g_Menu,"Please type (right now) a description^nof your job^n^nAfter which, press ^"enter^"",0);
	menu_setprop(g_Menu,MPROP_EXIT,MEXIT_NEVER);
	
	// Main
	register_plugin("DRP - In-Game Apps","0.1a","Drak");
	
	// Commands
	DRP_RegisterCmd("drp_reviewapps","CmdReview","(ADMIN) - Reviews current job apps");
	DRP_AddCommand("say /jobapply","<jobname> - apply's for a job. or creates a new one");
	
	// Internal
	register_clcmd(g_MessageMode,"CmdMessageMode");
}

public plugin_init()
	DRP_AddChat("","CmdApp");

public DRP_Error(const Reason[])
	pause("d");

public client_disconnect(id)
	g_UserJobName[id][0] = 0

/*==================================================================================================================================================*/
public CmdApp(id,Args[])
{
	if(!equali(Args,"/jobapply ",10))
		return PLUGIN_CONTINUE
	
	new SteamID[36],ArraySteamID[36]
	get_user_authid(id,SteamID,35);
	
	for(new Count;Count < g_JobAppsNum;Count++)
	{
		ArrayGetString(ArrayGetCell(g_JobApps,Count),0,ArraySteamID,35);
		if(equali(SteamID,ArraySteamID))
		{
			client_print(id,print_chat,"[DRP] You already submitted a job app. It's still waiting approval.");
			return PLUGIN_HANDLED
		}
	}
	
	new JobName[33]
	parse(Args,Args,1,JobName,32);
	
	remove_quotes(JobName);
	
	if(!JobName[0])
	{
		client_print(id,print_chat,"[DRP] Usage: /jobapply <jobname> - You can type an existing job name, or make your own");
		return PLUGIN_HANDLED
	}
	
	new Results[1],Num = DRP_FindJobID(JobName,Results,1);
	if(Num > 1)
	{
		client_print(id,print_chat,"[DRP] More than one job is matching that jobname. (If you're making your own, please change the name)");
		return PLUGIN_HANDLED
	}
	
	replace_all(JobName,32,":","");
	
	new JobID = Results[0]
	if(JobID > 1)
		DRP_GetJobName(JobID,JobName,32);
	
	new Title[128]
	formatex(Title,127,"JOB: %s^nYou can stop this at any time",JobName);
	
	copy(g_UserJobName[id],32,JobName)
	
	menu_display(id,g_Menu);
	client_cmd(id,"messagemode ^"%s^"",g_MessageMode);
	
	return PLUGIN_HANDLED
}
public CmdMessageMode(const id)
{
	new Args[512]
	read_args(Args,511);
	
	if(!Args[0])
	{
		client_print(id,print_chat,"[DRP] Your job description was blank. Unable to send job app.");
		return PLUGIN_HANDLED
	}
	
	new FinalFormat[1024]
	new SteamID[36],plName[36]
	
	get_user_authid(id,SteamID,35);
	get_user_name(id,plName,35);
	
	remove_quotes(Args);
	formatex(FinalFormat,1023,"^"%s^" ^"%s^" ^"%s^" ^"%s^"^n",plName,SteamID,g_UserJobName[id],Args);
	
//	fputs(pFile,FinalFormat);
	write_file(g_LogFile,FinalFormat);
	LoadFile(1);
	
	client_print(id,print_chat,"[DRP] Job application sent. You will be notified if approved.");
	
	return PLUGIN_HANDLED
}
public CmdReview(id,level,cid)
{
	if(!DRP_CmdAccess(id,cid,1))
		return PLUGIN_HANDLED
	
	new Menu = menu_create("Job Reviewing","JobReviewHandle"),ArrayNum[12],plName[33]
	new Array:CurArray
	
	for(new Count;Count < g_JobAppsNum;Count++)
	{
		CurArray = ArrayGetCell(g_JobApps,Count);
		if(CurArray == Invalid_Array)
			continue
		
		num_to_str(_:CurArray,ArrayNum,11);
		ArrayGetString(CurArray,1,plName,32);
		
		menu_additem(Menu,plName,ArrayNum);
	}
	
	if(menu_items(Menu) < 1)
	{
		client_print(id,print_console,"[DRP] There are currently no job apps on file.");
		menu_destroy(Menu);
		return PLUGIN_HANDLED
	}
	
	menu_display(id,Menu);
	client_print(id,print_console,"[DRP] A menu has been opened with the list of names.");
	
	return PLUGIN_HANDLED
}
/*==================================================================================================================================================*/
public UserJobApply(id,Menu,Item)
{
	if(Item == MENU_EXIT)
		return PLUGIN_HANDLED
	
	if(Item == 0)
		client_print(id,print_chat,"[DRP] Job app process closed.");
	
	return PLUGIN_HANDLED
}
public JobReviewHandle(id,Menu,Item)
{
	if(Item == MENU_EXIT)
	{
		menu_destroy(Menu);
		return PLUGIN_HANDLED
	}
	
	new _:ArrayNum[12],Temp
	menu_item_getinfo(Menu,Item,Temp,ArrayNum,11,_,_,Temp);
	menu_destroy(Menu);
	
	new Array:CurArray = Array:str_to_num(ArrayNum);
	if(CurArray == Invalid_Array)
	{
		client_print(id,print_chat,"[DRP] This Job App is now invalid.");
		return PLUGIN_HANDLED
	}
	
	new plName[128],JobName[33],SteamID[36]
	ArrayGetString(CurArray,1,plName,127);
	ArrayGetString(CurArray,0,SteamID,35);
	ArrayGetString(CurArray,2,JobName,32);
	
	format(plName,127,"%s's Job App^nJobName: %s",plName,JobName);
	Menu = menu_create(plName,"JobReviewHandle2");
	
	menu_additem(Menu,"Accept",ArrayNum);
	menu_additem(Menu,"Decline",ArrayNum);
	menu_additem(Menu,"View Description",ArrayNum);
	menu_additem(Menu,"Exit",ArrayNum);
	
	menu_setprop(Menu,MPROP_EXIT,MEXIT_NEVER);
	menu_display(id,Menu);
	
	return PLUGIN_HANDLED
}
public JobReviewHandle2(id,Menu,Item)
{
	if(Item == MENU_EXIT)
		return PLUGIN_HANDLED
	
	new ArrayNum[12],Temp
	menu_item_getinfo(Menu,Item,Temp,ArrayNum,11,_,_,Temp);
	
	new Array:CurArray = Array:str_to_num(ArrayNum);
	if(CurArray == Invalid_Array)
	{
		client_print(id,print_chat,"[DRP] This Job App is now invalid.");
		menu_destroy(Menu);
		return PLUGIN_HANDLED
	}
	
	switch(Item)
	{
		case 0..1:
		{
			new SteamID[36]
			ArrayGetString(CurArray,0,SteamID,35);
			
			new Target = cmd_target(id,SteamID,CMDTARGET_ALLOW_SELF);
			if(Target)
				client_print(id,print_chat,"[DRP] Your job app has been %s",Item == 0 ? "Accpeted" : "Denied");
		}
		case 2:
		{
			new WindowMessage[512]
			ArrayGetString(CurArray,3,WindowMessage,511);
			
			menu_display(id,Menu);
			show_motd(id,WindowMessage,"Job App");
		}
		case 3:
		{
			menu_destroy(Menu);
			return PLUGIN_HANDLED
		}
	}
	
	return PLUGIN_HANDLED
}
	
/*==================================================================================================================================================*/
LoadFile(Reload=0)
{
	if(Reload)
	{
		plugin_end();
		g_JobApps = ArrayCreate();
	}
	
	new ConfigFile[256]
	DRP_GetConfigsDir(ConfigFile,255);
	add(ConfigFile,255,"/JobApps.txt");
	
	copy(g_LogFile,255,ConfigFile);
	
	if(!file_exists(ConfigFile))
		return
	
	new pFile = fopen(ConfigFile,"r+");
	if(!pFile)
		return
	
	new Buffer[1025]
	new SteamID[36],JobName[36],JobDesc[512],plName[33]
	new Array:CurArray
	
	while(!feof(pFile))
	{
		fgets(pFile,Buffer,1024);
		if(!Buffer[0] || Buffer[0] == ';')
			continue
		
		parse(Buffer,plName,32,SteamID,35,JobName,35,JobDesc,511);
		
		remove_quotes(SteamID);
		remove_quotes(JobName);
		remove_quotes(JobDesc);
		remove_quotes(plName);
		
		if(!plName[0] || !SteamID[0] || !JobName[0] || !JobDesc[0])
			continue
		
		CurArray = ArrayCreate(1024);
		ArrayPushCell(g_JobApps,CurArray);
		g_JobAppsNum++
		
		ArrayPushString(CurArray,SteamID);
		ArrayPushString(CurArray,plName);
		ArrayPushString(CurArray,JobName);
		ArrayPushString(CurArray,JobDesc);
	}
	fclose(pFile);
}

public plugin_end()
{
	new Array:CurArray
	for(new Count;Count < g_JobAppsNum;Count++)
	{
		CurArray = ArrayGetCell(g_JobApps,Count);
		if(CurArray != Invalid_Array)
			ArrayDestroy(CurArray);
	}
	ArrayDestroy(g_JobApps);
}