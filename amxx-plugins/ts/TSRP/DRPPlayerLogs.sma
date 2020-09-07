#include <amxmodx>

#include <DRP/DRPCore>
#include <DRP/DRPChat>

new g_PlayerMOTD[1024][33]
new g_ConfigDir[256]
new g_Files[33]

public plugin_init()
{
	register_plugin("DRP - Player Logging","0.1a","Drak");
	DRP_RegisterChat("/viewlogs","CmdLogs","say /viewlogs <page #>");
	
	DRP_GetConfigsDir(g_ConfigDir,255);
	add(g_ConfigDir,255,"/PlayerLogs");
}
public client_authorized(id)
{
	new File[127],AuthID[36]
	get_user_name(id,AuthID,35);
	
	formatex(File,127,"%s/%s.log",g_ConfigDir,AuthID);
	g_Files[id] = fopen(File,"a+");
	
	LogEvent(id,"Hello World. My name is: #name");
}
public client_disconnect(id)
	fclose(g_Files[id]);

public CmdLogs(id)
{
	while(!feof(g_Files[id]))
		fgets(g_Files[id],g_PlayerMOTD[id],1023);
	
	if(ReturnLogLength(id) >= 1024)
		add(g_PlayerMOTD[id],1023,"type ^"/viewlogs 1^" for the next page.");
	
	show_motd(id,g_PlayerMOTD[id],"DRP");
}
/*==================================================================================================================================================*/
// LogEvent(id,"#name");
LogEvent(id,const Message[],any:...)
{
	if(!Message[0])
		return
	
	static FMessage[1024],Edit[64]
	vformat(FMessage,1023,Message,3);
	
	new String = containi(FMessage,"#");
	if(String != -1)
	{
		switch(FMessage[String + 1])
		{
			case 'n':
			{
				get_user_name(id,Edit,63);
				replace(FMessage,1023,"#name",Edit);
			}
		}
	}
	fputs(g_Files[id],FMessage);
}

ReturnLogLength(id)
{ 
	new LineData[256],CharLength
	
	while(!feof(g_Files[id])) 
	{ 
		fgets(g_Files[id],LineData,255); 
		CharLength += strlen(LineData) 
	} 
	
	return CharLength 
}