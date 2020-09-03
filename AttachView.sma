//////////////////////////////////////////////////
// AttachView.sma
// -----------------------------------
// Author(s):
// Drak
//
// Known Bugs:
// Some mods have "anti-wallhack" type things. So when you attach your view, you can't see other players 
// (but you can see what the player is seeing)
//
//
//

#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>

#define HUD_RED 255
#define HUD_GREEN 0
#define HUD_BLUE 0

#define HUD_X -100.0
#define HUD_Y -0.10

new g_AttachedViews[33]
new const g_ViewModel[] = "models/rpgrocket.mdl" // this model is ALWAYS precached by the HL MOD TS - change this to something that doesn't need to be precached
new const g_ViewClass[] = "D_VIEW"

new g_MaxPlayers
new bool:gOtPlugin

new p_Enable

public plugin_precache()
	precache_model(g_ViewModel);

public plugin_init()
{
	// Main
	register_plugin("Attach View / Admin Eye","0.3a","Drak");
	
	g_MaxPlayers = get_maxplayers();
	p_Enable = register_cvar("AMX_View_Enable","1");
	
	// Commands
	register_concmd("amx_attachview","CmdAttach",ADMIN_BAN,"(ADMIN) - <player name> attaches your view; jump cycles other players");
	register_concmd("amx_removeview","CmdRemove",ADMIN_BAN,"(ADMIN) - resets your attached camera");
	
	// Forwards / Events
	register_forward(FM_EmitSound,"Forward_EmitSound");
	register_event("DeathMsg","Event_DeathMsg","a");
	
	if(is_running("cstrike"))
		register_event("HLTV","Event_NewRound","a","1=0","2=0");
	
	// Add a delay
	// This plugin might be called before the anti-wallhack plugin
	set_task(5.0,"CheckCVar");
}

public CheckCVar()
	gOtPlugin = cvar_exists("wallblocker_version") ? true : false

public Event_DeathMsg()
{
	new const id = read_data(2);
	RemoveAttach(id,true);
}

public Event_NewRound()
{
	new const id = read_data(1);
	RemoveAttach(id,true);
}
	
public Forward_EmitSound(const ent,iChannel,const szSample[],Float:fVolume,Float:fAttenuation)
{
	// Array to hold the list of ids that have views attached to them
	static AttachedPlayers[33],Viewers[33]
	new ViewEnt,NumAttached,Count,Count2
	
	while(( ViewEnt = find_ent_by_class(ViewEnt,g_ViewClass)) != 0)
	{
		AttachedPlayers[NumAttached] = entity_get_edict(ViewEnt,EV_ENT_aiment);
		Viewers[NumAttached] = entity_get_int(ViewEnt,EV_INT_iuser2);
		NumAttached++
	}
	
	static Float:fOrigin[3],Float:sOrigin[3]
	entity_get_vector(ent,EV_VEC_origin,sOrigin);
	
	for(Count = 0; Count <= g_MaxPlayers;Count++)
	{
		for(Count2 = 0; Count2 < NumAttached; Count2++)
		{
			// We have a view attached to us - if we can hear the sound - play it to our viewer(s)
			if(AttachedPlayers[Count2] == Count)
			{
				entity_get_vector(Count,EV_VEC_origin,fOrigin);
				if(get_distance_f(fOrigin,sOrigin) <= fAttenuation)
				{
					// We can hear this sound - play it to our viewer(s)
					new const Target = Viewers[Count2]
					if(Target && is_user_alive(Target))
						client_cmd(Target,"spk ^"%s^"",szSample);
				}
				
				return FMRES_HANDLED
			}
		}
	}
	return FMRES_IGNORED
}

public client_disconnect(id)
	RemoveAttach(id,true);

// Do not need to take in account admins here.
// It's just a waste of a check
public CmdRemove(id,level,cid)
{
	if(RemoveAttach(id))
		client_print(id,print_console,"[AMXX] Your view has been reset");
	else
		client_print(id,print_console,"[AMXX] Your view was not attached to any player(s).");
	
	return PLUGIN_HANDLED
}

public client_PreThink(id)
{
	if(!g_AttachedViews[id] || !is_user_alive(id))
		return
	
	// We have a view setup, but now the CVar says to disable
	if(!get_pcvar_num(p_Enable))
	{
		RemoveAttach(id,true);
		client_print(id,print_chat,"[AMXX] The view plugin is now disabled.");
	}
	
	if(!(entity_get_int(id,EV_INT_button) & IN_JUMP && !(entity_get_int(id,EV_INT_oldbuttons) & IN_JUMP)))
		return
	
	// They jumped, cycle player(s) - actually we're just grabbing random players
	new Target = GetRandomPlayer(),OldTarget = entity_get_edict(g_AttachedViews[id],EV_ENT_aiment);
	if(!Target || Target == id || Target == OldTarget)
	{
		client_print(id,print_chat,"[AMXX] No others players found; to attach view.");
		return
	}
	
	entity_set_edict(g_AttachedViews[id],EV_ENT_aiment,Target);
	
	new Name[33]
	get_user_name(Target,Name,32);
	
	client_print(id,print_chat,"[AMXX] Your view is now attached to: %s",Name);
}

// Each "viewer" get's there own task for this
// So we don't have a gaint looping task, when nobody is viewing anybody
public StatusHUD(const id)
{
	if(!g_AttachedViews[id] || !is_user_alive(id))
		return PLUGIN_HANDLED
	
	new Target = entity_get_edict(g_AttachedViews[id],EV_ENT_aiment);
	if(!Target || !is_user_alive(id))
		return PLUGIN_HANDLED
	
	new Name[33]
	get_user_name(Target,Name,32);
	
	set_hudmessage(HUD_RED,HUD_GREEN,HUD_BLUE,HUD_X,HUD_Y,0,_,1.2,_,_,-1);
	show_hudmessage(id,"Viewing: %s^nHealth: %d%%",Name,get_user_health(Target));
	
	return set_task(1.0,"StatusHUD",id);
}

public CmdAttach(id,level,cid)
{
	if(!cmd_access(id,level,cid,2) || !is_user_alive(id))
		return PLUGIN_HANDLED
	
	if(!get_pcvar_num(p_Enable))
	{
		client_print(id,print_console,"[AMXX] The view plugin has been disabled.");
		return PLUGIN_HANDLED
	}
	
	// Clean up
	RemoveAttach(id);
	
	new Arg[33]
	read_argv(1,Arg,32);
	
	new Target = cmd_target(id,Arg,CMDTARGET_ONLY_ALIVE);
	if(!Target)
		return PLUGIN_HANDLED
	
	g_AttachedViews[id] = create_entity("info_target");
	if(!g_AttachedViews[id])
	{
		client_print(id,print_console,"[AMXX] Unable to attach view. (Unable to create ^"info_target^"");
		g_AttachedViews[id] = 0
		return PLUGIN_HANDLED
	}
	
	entity_set_model(g_AttachedViews[id],g_ViewModel);
	entity_set_string(g_AttachedViews[id],EV_SZ_classname,g_ViewClass);
	entity_set_int(g_AttachedViews[id],EV_INT_movetype,MOVETYPE_FOLLOW);
	entity_set_int(g_AttachedViews[id],EV_INT_iuser2,id);
	
	entity_set_int(g_AttachedViews[id],EV_INT_solid,SOLID_NOT);
	set_rendering(g_AttachedViews[id],_,0,0,0,kRenderTransAlpha,1);
	entity_set_edict(g_AttachedViews[id],EV_ENT_aiment,Target);
	
	get_user_name(Target,Arg,32);
	client_print(id,print_console,"[AMXX] View attached to: %s - Type ^"amx_removeview^" to go back to yourself, or ^"jump^" to cycle through players",Arg);
	
	AttachView(id,g_AttachedViews[id]);
	StatusHUD(id);
	
	return PLUGIN_HANDLED
}

RemoveAttach(id,bool:RemoveTarget = false)
{
	if(RemoveTarget)
	{
		new ViewEnt
		while(( ViewEnt = find_ent_by_class(ViewEnt,g_ViewClass)) != 0)
		{
			if(entity_get_edict(ViewEnt,EV_ENT_aiment) == id)
			{
				// We have a camera attached to us. Remove this entity, and reset the viewers view
				new const Target = entity_get_int(ViewEnt,EV_INT_iuser2);
				if(Target && is_user_connected(Target))
				{
					AttachView(Target,Target);
					client_print(Target,print_chat,"[AMXX] The user has died / disconnected - View reset.");
				}
				
				remove_entity(ViewEnt);
			}
		}
	}
	
	if(g_AttachedViews[id])
	{
		if(is_valid_ent(g_AttachedViews[id]))
			remove_entity(g_AttachedViews[id]);
		
		if(is_user_connected(id))
			AttachView(id,id);
		
		g_AttachedViews[id] = 0
		return 1
	}
	
	return 0
}

GetRandomPlayer()
{	
	if(!get_playersnum())
		return 0
	
	new iPlayers[32],iNum
	get_players(iPlayers,iNum,"a");
	
	if(!iNum)
		return 0
	
	new Player = iPlayers[random(iNum)]
	return is_user_alive(Player) ? Player : 0
}

AttachView(const id,const Target)
{
	attach_view(id,Target);
	if(gOtPlugin)
		wb_setview(id,Target);
}

// This allows us "attach_view()" with ot_207 anti-wallhack plugin
stock wb_setview(id,attachent)
{
    callfunc_begin("fw_setview", cvar_exists("wallblocker_version") ? "block_wallhack.amxx" : "trblock.amxx")
    callfunc_push_int(id)
    callfunc_push_int(attachent)
    callfunc_end()
    
    return 1
}