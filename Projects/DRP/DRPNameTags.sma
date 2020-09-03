#include <amxmodx>
#include <DRP/DRPCore>

new g_MaxPlayers

new const g_NameTags[2][] =
{
	"[MCPD]",
	"[MCMD]"
}

// Follows g_NameTags
enum
{
	MCPD = 0,
	MCMD
}

public plugin_init()
{
	// Main
	register_plugin("DRP - Name Tags","0.1a","Drak");
	
	// Variables
	g_MaxPlayers = get_maxplayers();
	
	// Tasks
	set_task(2.0,"CheckNames",_,_,_,"b");
}

public CheckNames()
{
	new Name[33]
	new Count,Cop,Contain
	
	for(Count = 0;Count <= g_MaxPlayers;Count++)
	{
		if(!is_user_alive(Count))
			continue
		
		if(!DRP_IsAdmin(Count))
		{
			Cop = DRP_IsCop(Count);
			get_user_name(Count,Name,32);
			
			Contain = containi(Name,g_NameTags[MCPD]);
			
			// Cop -------------------------
			if(Contain != -1 && !Cop)
			{
				replace(Name,32,g_NameTags[MCPD],"");
				set_user_info(Count,"name",Name);
				continue
			}
			else if(Cop && Contain == -1)
			{
				format(Name,32,"%s %s",g_NameTags[MCPD],Name);
				set_user_info(Count,"name",Name);
				continue
			}
			// Cop -------------------------
			
			// Medic -------------------------
			Cop = DRP_IsMedic(Count);
			Contain = containi(Name,g_NameTags[MCMD]);
			
			if(containi(Name,g_NameTags[MCMD]) != -1 && !Cop)
			{
				replace(Name,32,g_NameTags[MCMD],"");
				set_user_info(Count,"name",Name)
				continue
			}
			else if(Cop && Contain == -1)
			{
				format(Name,32,"%s %s",g_NameTags[MCMD],Name);
				set_user_info(Count,"name",Name);
				continue
			}
			// Medic -------------------------
		}
	}
}