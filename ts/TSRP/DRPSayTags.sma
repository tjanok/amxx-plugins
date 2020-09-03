#include <amxmodx>
#include <DRP/DRPCore>
#include <DRP/DRPChat>

#define MAX_TAGS 10

new g_Tags[MAX_TAGS][2][128]
new g_TagsNum

public plugin_init()
{
	// Main
	register_plugin("DRP - Say Tags","0.1a","Drak");
	
	// Commands
	register_clcmd("say","CmdSay");
}

public DRP_Init()
{
	new File[256]
	DRP_GetConfigsDir(File,255);
	add(File,255,"/SayTags.ini");
	
	new pFile = fopen(File,"r");
	if(!pFile)
		return
	
	new Tag[33],Message[128]
	while(!feof(pFile))
	{
		fgets(pFile,File,255);
		if(!File[0] || File[0] == ';')
			continue
		
		strtok(File,Tag,32,Message,127,' ');
		
		if(Tag[0] && Message[0])
		{
			strtolower(Tag);
			
			trim(Tag);
			trim(Message);
			
			remove_quotes(Tag);
			remove_quotes(Message);
			
			copy(g_Tags[g_TagsNum++][0],127,Tag);
			copy(g_Tags[g_TagsNum-1][1],127,Message);
		}
	}
	
	fclose(pFile);
}

public DRP_Error(const Reason[])
	pause("d");

/*==================================================================================================================================================*/
public CmdSay(id)
{
	new Args[128]
	read_args(Args,127);

	if(Args[1] == '/')
		return PLUGIN_CONTINUE
	
	for(new Count;Count < g_TagsNum;Count++)
	{
		if(containi(Args,g_Tags[Count][0]) != -1)
		{
			client_print(id,print_chat,"[DRP] %s",g_Tags[Count][1]);
			break
		}
	}
	
	return PLUGIN_CONTINUE
}