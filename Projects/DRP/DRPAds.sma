#include <amxmodx>
#include <DRP/DRPCore>

#define MAX_ADS 26

new g_Query[128]
new Handle:g_SqlHandle

new p_ShowTime

new g_UserHelp[33]

new g_Timer
new g_NumAds

// I like to use memory - is this bad?
new g_DisplayAds[MAX_ADS][128]

public DRP_Init()
{
	register_plugin("DRP - Help Messages","0.1a","Drak");
	
	// Cvars
	p_ShowTime = register_cvar("DRP_HelpMessagesFreq","1"); // Minutes
	
	// Commands
	DRP_RegisterCmd("say /helpmsg","CmdHelp","- turns the help messages on/off");
	DRP_RegisterCmd("drp_forcehelpmsg","CmdShowMsg","(ADMIN) Forces a help message to be displayed");
	
	g_SqlHandle = DRP_SqlHandle();
	SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle","CREATE TABLE IF NOT EXISTS `PlayerAds` (SteamID VARCHAR(36),Val INT(11), PRIMARY KEY (SteamID))")
	
	// Tasks
	set_task(1.0,"Counter",_,_,_,"b");
	
	// File
	LoadAds();
}
/*==================================================================================================================================================*/
public client_authorized(id)
{
	// Default On
	g_UserHelp[id] = 1
	
	new Data[1]
	Data[0] = id
	
	new AuthID[36]
	get_user_authid(id,AuthID,35);
	
	format(g_Query,127,"SELECT `Val` FROM `PlayerAds` WHERE `SteamID`='%s'",AuthID);
	SQL_ThreadQuery(g_SqlHandle,"LoadPlayerAds",g_Query,Data,1);
}
/*==================================================================================================================================================*/
public CmdHelp(id)
{
	new const Curr = !HasHelpEnabled(id);
	g_UserHelp[id] = Curr
	
	static AuthID[36]
	get_user_authid(id,AuthID,35);
	
	format(g_Query,127,"INSERT INTO `PlayerAds` VALUES ('%s','%d') ON DUPLICATE KEY UPDATE `Val`='%d'",AuthID,g_UserHelp[id],g_UserHelp[id]);
	SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",g_Query);
	
	client_print(id,print_chat,"[DRP] You have turned the help messages %s.",Curr ? "on" : "off");
	return PLUGIN_HANDLED
}
public CmdShowMsg(id,level,cid)
{
	if(!DRP_CmdAccess(id,cid,1))
		return PLUGIN_HANDLED
	
	client_print(id,print_console,"[DRP] A random help message has been displayed.");
	ShowHelp(1);
	
	return PLUGIN_HANDLED
}	
/*==================================================================================================================================================*/
public Counter()
	ShowHelp(0);
	
ShowHelp(Override)
{
	static Time
	Time = get_pcvar_num(p_ShowTime);
	
	if(Time <= 0)
		return
	
	if((g_Timer / 60) >= Time || Override)
	{
		static iPlayers[32],iNum
		get_players(iPlayers,iNum);
		
		new Index
		new const Random = random(g_NumAds);
		
		for(new Count;Count < iNum;Count++)
		{
			Index = iPlayers[Count]
			
			if(!is_user_alive(Index))
				continue
			
			if(HasHelpEnabled(Index))
				client_print(Index,print_chat,"[DRP Help] %s",g_DisplayAds[Random]);
		}
		if(!Override)
			g_Timer = 0
	}
	else
		g_Timer++
}
/*==================================================================================================================================================*/
public LoadPlayerAds(FailState,Handle:Query,const Error[],Errcode,const Data[],DataSize) 
{
	if(FailState != TQUERY_SUCCESS)
		return log_amx("[SQL ERROR] (Error: %s)",Error ? Error : "UNKNOWN");
	
	new const id = Data[0]
	
	if(!SQL_NumResults(Query))
		return PLUGIN_CONTINUE
	
	g_UserHelp[id] = SQL_ReadResult(Query,0);
	return PLUGIN_CONTINUE
}
	
public IgnoreHandle(FailState,Handle:Query,const Error[],Errcode,const Data[],DataSize) 
{
	if(FailState != TQUERY_SUCCESS)
		log_amx("[SQL ERROR] Query Failed. (Error: %s)",Error ? Error : "UNKNOWN");
	
	return PLUGIN_CONTINUE
}

/*==================================================================================================================================================*/
LoadAds()
{
	new HelpFile[128]
	DRP_GetConfigsDir(HelpFile,127);
	add(HelpFile,127,"/helpmsgs.txt");
	
	if(!file_exists(HelpFile))
		set_fail_state("No help file found - shutting down plugin");
	
	new pFile = fopen(HelpFile,"r");
	if(!pFile)
		set_fail_state("Unable to open help file - shutting down plugin");
	
	new Buffer[128]
	while(!feof(pFile))
	{
		if(g_NumAds >= MAX_ADS)
		{
			server_print("[DRP Help] Max ad amount reached (%d)",MAX_ADS);
			break;
		}
		
		fgets(pFile,Buffer,127);
		trim(Buffer);
		
		if(!Buffer[0] || Buffer[0] == ';')
			continue
		
		replace_all(Buffer,127,"^"","");
		formatex(g_DisplayAds[g_NumAds++],127,Buffer);
	}
	fclose(pFile);
	server_print("[DRP Help] %d Help messages loaded.",g_NumAds);
}

static HasHelpEnabled(id)
	return g_UserHelp[id] ? 1 : 0