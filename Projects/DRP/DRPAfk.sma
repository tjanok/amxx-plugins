#include <amxmodx>
#include <engine>
#include <DRP/DRPCore>

new gUserAFK[33]

new Float:gLastCheck[33]
new Float:gMenuShown[33] = {-1.0,...}
new Float:gOrigin[33][3]

new g_Menu

// Cvars
new p_CheckTime
new p_Distance
new p_MenuTime

// Admin cache *hack*
new gAdmin[33]

public DRP_Init()
{
	// Main
	register_plugin("DRP - AFK Kicker","0.1a","Drak");
	
	// CVars
	p_CheckTime = register_cvar("DRP_AFK_CheckTime","60.0"); // how often to check
	p_Distance = register_cvar("DRP_AFK_Distance","600.0"); // the distance they have to move before the warning goes off
	p_MenuTime = register_cvar("DRP_AFK_MenuTime","20.0"); // the amount of time they have (in seconds) to answer
	
	// Events
	DRP_RegisterEvent("Player_Salary","Event_PlayerSalary");
	DRP_RegisterEvent("Player_Spawn","Event_PlayerSpawn");
	DRP_RegisterEvent("Player_SetAccess","Event_PlayerSpawn"); // hack to check for admin
	
	// Commands
	DRP_RegisterCmd("say /afk","CmdGoAfk","Allows you to go Away from Keyboard (to avoid being kicked)");
	
	// Menus
	g_Menu = menu_create("[AFK Menu]^n^nYou haven't moved in awhile^nAre you AFK?^n^n(Away from Keyboard)","_AFKHandle");
	menu_additem(g_Menu,"Yes, I'm Here");
	menu_addtext(g_Menu,"^nYou must reply or you will be kicked^nYou can type ^"/afk^" to avoid this");
	menu_setprop(g_Menu,MPROP_EXIT,MEXIT_NEVER);
}

public DRP_Error(const Reason[])
	pause("d");

public client_disconnect(id)
{
	gUserAFK[id] = 0
	gAdmin[id] = 0
	gMenuShown[id] = -1.0
	
	gOrigin[id][0] = 0.0
	gOrigin[id][1] = 0.0
	gOrigin[id][2] = 0.0
}

public DRP_HudDisplay(id,Hud)
{
	if(Hud != HUD_SEC)
		return
	
	if(gUserAFK[id])
		DRP_AddHudItem(id,HUD_SEC,"\nAway from Keyboard");
}

public Event_PlayerSalary(const Name[],const Data[],const Len)
{
	if(gUserAFK[Data[0]])
		return PLUGIN_HANDLED
	
	return PLUGIN_CONTINUE
}
public Event_PlayerSpawn(const Name[],const Data[],const Len)
{
	if(DRP_IsAdmin(Data[0]))
		gAdmin[Data[0]] = 1
	
	return PLUGIN_CONTINUE
}
	
/*==================================================================================================================================================*/
public CmdGoAfk(id)
{
	if(!is_user_alive(id))
		return PLUGIN_HANDLED
	
	gUserAFK[id] = !gUserAFK[id]
	client_print(id,print_chat,"[DRP] You have %s AFK%s",gUserAFK[id] ? "gone" : "returned from being",gUserAFK[id] ? " (You will not be kicked - but you will not get payed/be able to move)" : ".");
	
	if(gUserAFK[id])
	{
		entity_get_vector(id,EV_VEC_origin,gOrigin[id]);
	}
	else
	{
		gOrigin[id][0] = 0.0
		gOrigin[id][1] = 0.0
		gOrigin[id][2] = 0.0
	}
	
	return PLUGIN_HANDLED
}

public client_PreThink(id)
{
	if(gAdmin[id] || is_user_bot(id) || !is_user_alive(id))
		return
	
	static Float:CurOrigin[3]
	
	// We told the server we are AFK
	// make us not be able to move (we are also not getting payed) but we can't be kicked now
	if(gUserAFK[id])
	{
		// Instead of messing with the maxspeed (and having to set it back)
		// we will just set the origin if they leave the spot that went afk at
		
		// work around to not die when jumping (it sets your origin and you get "crushed")
		// not sure of a better way
		if(!(entity_get_int(id,EV_INT_flags) & FL_ONGROUND))
			return
		
		entity_get_vector(id,EV_VEC_origin,CurOrigin);
		if(get_distance_f(CurOrigin,gOrigin[id]) >= 1.0)
		{
			entity_set_vector(id,EV_VEC_origin,gOrigin[id]);
			entity_set_vector(id,EV_VEC_velocity,Float:{0.0,0.0,0.0});
		}
		
		return
	}
	
	static Float:Time
	Time = halflife_time();
	
	if(gMenuShown[id] > -1.0)
	{
		if(!(Time - get_pcvar_float(p_MenuTime) < gMenuShown[id]))
		{
			// Kick them for not selecting anything
			console_print(id,"^n[KICKED] Reason: Being AFK^nYou can type ^"/afk^" to prevent this^n");
			server_cmd("amx_kick ^"#%d^" ^"Being AFK (Away From Keyboard)",get_user_userid(id));
			
			gMenuShown[id] = -1.0
			return
		}
	}
	
	if(Time - get_pcvar_num(p_CheckTime) < gLastCheck[id])
		return
	
	gLastCheck[id] = Time
	entity_get_vector(id,EV_VEC_origin,CurOrigin);
	
	// only calls once - we need to fill up our origin for the first time
	if(!gOrigin[id][0])
	{
		entity_get_vector(id,EV_VEC_origin,gOrigin[id]);
		return
	}
	
	new Float:Distance = get_distance_f(gOrigin[id],CurOrigin);
	if(Distance < get_pcvar_float(p_Distance))
	{
		new plName[33]
		get_user_name(id,plName,32);
		server_print("[AFK CHECKER] Attemping to check player ^"%s^" for being AFK",plName);
		
		gMenuShown[id] = Time
		menu_display(id,g_Menu);
	}
	else
	{
		entity_get_vector(id,EV_VEC_origin,gOrigin[id]);
	}
}

public _AFKHandle(id,Menu,Item)
{
	gMenuShown[id] = -1.0
	return PLUGIN_HANDLED
}