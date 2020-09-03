#include <amxmodx>
#include <DRP/DRPCore>

new p_Restart
new p_Delay

new g_FianlCounter
new g_Counter

public DRP_Init()
{
	// Main
	register_plugin("DRP - Restart","0.1a","Drak");
	
	// CVar
	p_Restart = register_cvar("DRP_RestartServer","200"); // Minutes
	p_Delay = register_cvar("DRP_RestartServerDelay","60"); // Seconds
	
	// DEBUG
	register_srvcmd("DRP_CheckRestartTimer","CmdTimer");
	
	// Task
	set_task(1.0,"Timer",_,"",_,"b");
}

public DRP_HudDisplay(id,Hud)
{
	if(Hud != HUD_PRIM)
		return
	
	if(g_Counter != -1)
		return
	
	DRP_AddHudItem(id,HUD_PRIM,"Server Daily Restart In: %d Seconds",g_FianlCounter);
}

public CmdTimer()
	return server_print("[DRP] Timer: %d (Restart in: %d)",g_Counter,(get_pcvar_num(p_Restart) - (g_Counter / 60)))

public Timer()
	Counter();

// --
Counter()
{
	// - we now count down untill the p_Delay is reached
	if(g_Counter == -1)
	{
		if(--g_FianlCounter < 0)
		{
			DRP_Log("Daily Server Restart - %d Minutes Total Run Time (%d Restart Time)",get_pcvar_num(p_Restart),get_pcvar_num(p_Delay));
			server_cmd("reload");
		}
		return
	}
	
	g_Counter = floatround(get_gametime());
	
	static Total,Time
	Time = get_pcvar_num(p_Restart),Total = (g_Counter / 60);
	
	if(!Time)
		return
	
	if(Total >= Time)
	{
		g_FianlCounter = get_pcvar_num(p_Delay);
		g_Counter = - 1
		client_print(0,print_chat,"[DRP] The server will be doing a restart in %d seconds",g_FianlCounter);
	}
}