#include <amxmodx>
#include <amxmisc>

#define MAX_ADS 14

new p_ShowTime

new g_UserHelp[33]

new g_Timer
new g_NumAds

// I like to use memory - is this bad?
new g_DisplayAds[MAX_ADS][128]

public plugin_init()
{
	register_plugin("DRP - Help Messages","0.1a","Drak");
	
	// Cvars
	p_ShowTime = register_cvar("DRP_HelpMessagesFreq","15"); // Minutes
	
	// Tasks
	set_task(1.0,"Counter",_,_,_,"b");
	
	register_clcmd("amx_l","CmdShowMsg");
	
	// File
	LoadAds();
}
/*==================================================================================================================================================*/
public CmdShowMsg(id,level,cid)
{
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
			
			client_print(Index,print_chat,"[Help] %s",g_DisplayAds[Random]);
		}
		g_Timer = 0
	}
	else
		g_Timer++
}
/*==================================================================================================================================================*/
LoadAds()
{
	new HelpFile[128]
	get_configsdir(HelpFile,127);
	add(HelpFile,127,"/dcoop/helpmsgs.txt");
	
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