#include <amxmodx>
#include <drp/drp_core>

new const PLUGIN[] = "DRP - Hud"
new const VERSION[] = "0.1a"
new const AUTHOR[] = "Drak"

new p_HudTitles[HUD_NUM]
new g_HudTitles[HUD_NUM][128]

public DRP_Init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	new VarName[18]
	for(new Count; Count < HUD_NUM; Count++)
	{
		new pCvar = p_HudTitles[Count]
		formatex(VarName, 17, "DRP_HudTitle%d", Count + 1);
		
		pCvar = register_cvar(VarName, "TITLE");
		
		copy(g_HudTitles[Count], 127, "");
		bind_pcvar_string(pCvar, g_HudTitles[Count], 127);
	}
}

public DRP_Error(const Reason[])
	pause("d");

public DRP_HudDisplay(id, Hud)
{
	static Temp[36], bool:isReady
	
	switch(Hud)
	{
		case HUD_PRIM:
		{
			if(g_HudTitles[HUD_PRIM][0])
				DRP_AddHudItem(id, HUD_PRIM, g_HudTitles[HUD_PRIM]);
			
			if(!isReady)
			{
				isReady = DRP_PlayerReady(id);
				if(!isReady)
				{
					DRP_AddHudItem(id, HUD_PRIM, "Your information is currently being loaded");
					return
				}
			}
			
			DRP_AddHudItem(id, HUD_PRIM, "Wallet: $%d", DRP_GetUserWallet(id));
			DRP_AddHudItem(id, HUD_PRIM, "Bank: $%d", DRP_GetUserBank(id));
			
			new JobID = DRP_GetUserJobName(id, Temp, 35);
			
			if(Temp[0])
				DRP_AddHudItem(id, HUD_PRIM, "Job: %s @ $%d/hr", Temp, DRP_GetJobSalary(JobID));
			else
				DRP_AddHudItem(id, HUD_PRIM, "Invalid Job / JobID (Contact an Admin)");
				
			DRP_AddHudItem(id, HUD_PRIM, "Pay: %d", DRP_GetPayDay() );
			DRP_AddHudItem(id, HUD_PRIM, "Time Played: %d Mins", DRP_GetUserTime(id));
			
			DRP_GetWorldTime(Temp, 35);
			DRP_AddHudItem(id, HUD_PRIM, "Time: %s", Temp);
			
			if(DRP_IsAdmin(id))
				DRP_AddHudItem(id, HUD_PRIM, "Admin Active");
		}
		case HUD_SEC:
		{
			if(g_HudTitles[HUD_SEC][0])
				DRP_AddHudItem(id, HUD_SEC, g_HudTitles[HUD_SEC]);
		}
		case HUD_TALKAREA:
		{
			if(g_HudTitles[HUD_TALKAREA][0])
				DRP_AddHudItem(id, HUD_TALKAREA, g_HudTitles[HUD_TALKAREA]);
		}
	}
}