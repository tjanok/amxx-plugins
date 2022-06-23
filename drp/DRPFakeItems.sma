#include <amxmodx>
#include <amxmisc>
#include <DRP/DRPCore>

public DRP_Init() 
	register_plugin("DRP - Fake Items","0.1a","Drak");

public DRP_RegisterItems()
{
	new szFile[256]
	DRP_GetConfigsDir(szFile,255);
	
	add(szFile,255,"/fakeitems.ini");
	if(!file_exists(szFile))
		write_file(szFile,"");
	
	new File = fopen(szFile,"r");
	if(!File)
		return
	
	new Buffer[256],Left[128],Right[128],Mode
	while(!feof(File))
	{
		fgets(File,Buffer,255);
		
		if(strlen(Buffer) < 2 || Buffer[0] == ';')
			continue
		
		replace(Buffer,255,"^n","");
		
		Mode = 0
		if(containi(Buffer,"(remove)") != -1)
		{
			replace(Buffer,255,"(remove)","")
			Mode = 1
		}
		
		parse(Buffer,Left,127,Right,127);
		remove_quotes(Left);
		trim(Left);
		remove_quotes(Right);
		trim(Right);
		
		DRP_RegisterItem(Left,"ItemHandle",Right,Mode,0,0);
	}
	
	fclose(File)
}

public ItemHandle(id,ItemID)
	client_print(id,print_chat,"[DRP] This item is unusable.")