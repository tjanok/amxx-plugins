//////////////////////////////////////////////////
// DRPAI.sma
// ----------------
// Author(s):
// Drak
//

#include <amxmodx>
#include <DRP/DRPCore>
#include <engine>

public plugin_precache()
{
}

public plugin_init()
{
	// Main
	register_plugin("DRP - AI","0.1a","Drak");

	// TEST
	LoadPersonality("Test.txt");
}

LoadPersonality(const File[])
{
	new pFile = fopen(File,"r");
	if(!pFile)
		return FAILED
	
	new TravTrie:CurArray = TravTrieCreate(),TextLen,Line
	new Buffer[256],Key[33]
	
	// code blocks
	new doDialog
	
	while(!feof(pFile))
	{
		fgets(pFile,Buffer,255);
		if(!Buffer[0] || Buffer[0] == ';' || Buffer[0] == '/')
			continue
		
		trim(Buffer);
		remove_quotes(Buffer);
		
		//server_print("b: %s",Buffer);
		
		// ----
		if(!doDialog && doDialog != -1)
		{
			if(containi(Buffer,"dialog") != -1)
			{
				server_print("got dialog - currently at: %d",ftell(pFile));
				fseek(pFile,ftell(pFile) + 1,SEEK_SET);
				doDialog = 1
				continue
			}
		}
		else if(doDialog >= 1)
		{
			if(Buffer[0] == '}')
			{
				doDialog = -1
				continue
			}
			
			if(Buffer[0])
				server_print("given sentence: %s",Buffer);
	
		}
		// ----
	}
}