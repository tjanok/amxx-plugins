#include <amxmodx>
#include <DRP/DRPCore>

new g_ConfigDir[256]

public plugin_init()
{
	// Main
	register_plugin("DRP - Job Addons","0.1a","Drak");
	
	// Commands
	DRP_RegisterCmd("say /jobinfo","CmdJobInfo","Returns information about your job. Along with it's perks");
}

public DRP_Init()
{
	DRP_GetConfigsDir(g_ConfigDir,255);
	add(g_ConfigDir,255,"/JobInfo");
	
	if(!dir_exists(g_ConfigDir))
		mkdir(g_ConfigDir);
}

public DRP_Error(const Reason[])
	pause("d");

/*==================================================================================================================================================*/
public CmdJobInfo(id)
{
	new JobName[33],File[256]
	DRP_GetJobName(DRP_GetUserJobID(id),JobName,32);
	
	formatex(File,255,"%s/%s.txt",g_ConfigDir,JobName);
	if(!file_exists(File))
		copy(File,255,"This job currently has no info^nPlease check back later.");
	
	show_motd(id,File,"Job Info");
	return PLUGIN_HANDLED
}
	