//////////////////////////////////////////////////
// AttachView.sma
// -----------------------------------
// See through another players eye's!
//
// Author(s):
// Trevor 'Drak' J

#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <fakemeta_util>

#define TASK_ID 133766

new const AUTHOR[] = "Trevor 'Drak' J"
new const VERSION[] = "1.0"

// Holds the entity we created that's attached to the player we are viewing
new g_AttachedViews[MAX_PLAYERS]

new const g_ViewModel[] = "models/rpgrocket.mdl"
new const g_ViewClass[] = "TJD_VIEW_ENT"

new g_MaxPlayers
new g_WallBlocker

new p_Enable
new p_HideViewer

public plugin_precache()
	precache_model(g_ViewModel);

public plugin_init()
{
	// Main
	register_plugin("Attach View / Admin Eye", VERSION, AUTHOR);
	g_MaxPlayers = get_maxplayers();
	
	// Cvars
	p_Enable = register_cvar("tjd_view_allow", "1");
	p_HideViewer = register_cvar("tjd_view_hideviewer", "1");
	
	// Commands
	register_concmd("tjd_view_attach", "CmdAttach", ADMIN_BAN, "(ADMIN) - <player> attaches your view. press JUMP to cycle other players");
	register_concmd("tjd_view_reset", "CmdRemove", ADMIN_BAN, "(ADMIN) - resets your attached camera");
	register_concmd("tjd_view_switch", "CmdSwitch");
	
	register_clcmd("say", "CmdSay");
	register_clcmd("say_team", "CmdSay");
	
	// Forwards / Events
	register_forward(FM_EmitSound, "fw_EmitSound");
	register_forward(FM_AddToFullPack, "fw_AddToFullPack");
	
	register_event("DeathMsg", "Event_DeathMsg", "a");
	
	new modName[33]
	get_modname(modName, 32);
	
	if(equali(modName, "cstrike"))
		register_event("HLTV", "Event_NewRound", "a", "1=0", "2=0");
	
	// Add a delay
	// This plugin might be called before the anti-wallhack plugin
	set_task(1.0, "CheckCVar");
}
public CmdSay(id)
{
	new Args[33]
	read_args(Args, 32);
	
	remove_quotes(Args);
	trim(Args);
	
	if(Args[0] != '/')
		return PLUGIN_CONTINUE
	
	new Command[12], Target[33]
	parse(Args, Command, 11, Target, 32);
	
	if(equali(Command, "/viewattach"))
	{
		CmdAttach(id, ADMIN_BAN, 0, Target);
		return PLUGIN_HANDLED
	}
	else if(equali(Command, "/viewreset"))
	{
		CmdRemove(id, ADMIN_BAN, 0);
		return PLUGIN_HANDLED
	}
	else if(equali(Command, "/viewswitch"))
	{
		CmdSwitch(id, ADMIN_BAN, 0);
		return PLUGIN_HANDLED
	}
	
	return PLUGIN_CONTINUE
}

public CheckCVar()
	g_WallBlocker = get_cvar_pointer("wallblocker_version");

public Event_DeathMsg()
{
	new const id = read_data(2);
	RemoveAttach(id);
}

public Event_NewRound()
{
	new const id = read_data(1);
	RemoveAttach(id);
}

FreezePlayer(id, bool:frozen)
{
	new flags = pev(id, pev_flags);
	new effects = pev(id, pev_effects);
	
	if(frozen && !(flags & FL_FROZEN))
	{
		set_pev(id, pev_flags, (flags | FL_FROZEN));
		
		if(!(effects & EF_NODRAW))
			set_pev(id, pev_effects, (effects | EF_NODRAW));
		
		set_pev(id, pev_solid, SOLID_NOT);
	}
	else if(!frozen && (flags & FL_FROZEN))
	{
		set_pev(id, pev_flags, (flags & ~FL_FROZEN));
		
		if(!(flags & EF_NODRAW))
			set_pev(id, pev_effects, (effects & ~EF_NODRAW));
		
		set_pev(id, pev_solid, SOLID_BBOX);
	}
}
public CmdSwitch(id, level, cid)
{
	if(!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED
	
	if(!g_AttachedViews[id] || !fm_is_valid_ent(g_AttachedViews[id]))
	{
		Print(id, "You are not currently viewing anybody");
		return PLUGIN_HANDLED
	}
	
	new currentTarget = pev(g_AttachedViews[id], pev_aiment);
	new nextTarget = GetRandomPlayer(id, currentTarget);
	
	if(!nextTarget)
	{
		Print(id, "No other players found.");
		return FMRES_IGNORED
	}
	
	set_pev(g_AttachedViews[id], pev_aiment, currentTarget);
	return PLUGIN_HANDLED
	
}
public fw_EmitSound(const ent,iChannel,const szSample[],Float:fVolume,Float:fAttenuation)
{
	// Array to hold the list of ids that have views attached to them
	static AttachedPlayers[33],Viewers[33]
	new ViewEnt,NumAttached,Count,Count2
	
	while(( ViewEnt = fm_find_ent_by_class(ViewEnt,g_ViewClass)) != 0)
	{
		AttachedPlayers[NumAttached] = pev(ViewEnt, pev_aiment); //entity_get_edict(ViewEnt,EV_ENT_aiment);
		Viewers[NumAttached] = pev(ViewEnt, pev_iuser2); //entity_get_int(ViewEnt,EV_INT_iuser2);
		NumAttached++
	}
	
	static Float:fOrigin[3],Float:sOrigin[3]
	pev(ent,pev_origin,sOrigin);
	
	for(Count = 0; Count <= g_MaxPlayers;Count++)
	{
		for(Count2 = 0; Count2 < NumAttached; Count2++)
		{
			// We have a view attached to us - if we can hear the sound - play it to our viewer(s)
			if(AttachedPlayers[Count2] == Count)
			{
				pev(Count,pev_origin,fOrigin);
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
public fw_AddToFullPack(es, e, iEntity, iHost, iHostFlags, iPlayer, pSet)
{
	if(!iPlayer)
		return FMRES_IGNORED
	
	new ent = g_AttachedViews[iEntity]
	if(ent && fm_is_valid_ent(ent))
	{
		set_es(es, ES_RenderMode, kRenderTransAdd);
		set_es(es, ES_RenderAmt, 0);
		return FMRES_HANDLED
	}
	
	return FMRES_IGNORED
}

public client_disconnected(id)
	RemoveAttach(id);

public CmdRemove(id, level, cid)
{
	if(!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED
	
	if(RemoveAttach(id))
		Print(id, "Your view has been reset.");
	
	return PLUGIN_HANDLED
}
public CmdAttach(id, level, cid, Arg[33])
{
	if(!cmd_access(id, level, cid, 2) || !is_user_alive(id))
		return PLUGIN_HANDLED
	
	if(!get_pcvar_num(p_Enable))
	{
		Print(id, "Plugin is currently disabled.");
		return PLUGIN_HANDLED
	}
	
	// Clean up
	RemoveAttach(id);
	
	if(!Arg[0])
		read_argv(1, Arg, 32);
	
	new Target = cmd_target(id, Arg, CMDTARGET_ONLY_ALIVE);
	if(!Target || Target == id)
		return PLUGIN_HANDLED
	
	new ent = fm_create_entity("info_target");
	if(!ent)
	{
		Print(id, "Unable to attach view. (Unable to create ^"info_target^" entity)");
		return PLUGIN_HANDLED
	}
	
	fm_entity_set_model(ent, g_ViewModel);
	
	set_pev(ent, pev_classname, g_ViewClass);
	set_pev(ent, pev_movetype, MOVETYPE_FOLLOW);
	set_pev(ent, pev_iuser2, id);
	
	set_pev(ent, pev_solid, SOLID_NOT);
	set_pev(ent, pev_aiment, Target);
	
	fm_set_rendering(ent, _, 0, 0, 0, kRenderTransAlpha , 1);
	
	AttachView(id, ent);
	query_client_cvar(id, "scr_centertime", "FetchCenterTime");
	
	new hideViewer = get_pcvar_num(p_HideViewer);
	if(hideViewer > 0)
		FreezePlayer(id, true);
	
	g_AttachedViews[id] = ent
	
	return PLUGIN_HANDLED
}

public FetchCenterTime(id, const cvar[], const value[], const param[])
{
	new Float:timer = str_to_float(value);
	
	if(!timer)
		timer = 1.0
	else
		timer -= 0.5
	
	new Float:data[1]
	data[0] = timer
	
	set_task(timer, "ViewerInfo", id + TASK_ID, data, 1);
}

public ViewerInfo(Float:data[], id)
{
	new Float:timer = data[0]
	id -= TASK_ID
	
	if(!is_user_connected(id) || !g_AttachedViews[id] || !fm_is_valid_ent(g_AttachedViews[id]))
		return
	
	new Name[33]
	new targetId = pev(g_AttachedViews[id], pev_aiment);
	
	if(!targetId || !is_user_alive(targetId))
		return
	
	get_user_name(targetId, Name, 32);
	client_print(id, print_center, "Viewing: %s^n%i/%i", Name, pev(targetId, pev_health), pev(targetId, pev_armorvalue));
	
	set_task(timer, "ViewerInfo", id + TASK_ID, data, 1);
}

RemoveAttach(id)
{
	new ViewEnts
	while((ViewEnts = fm_find_ent_by_class(ViewEnts, g_ViewClass)) != 0)
	{
		if(pev(ViewEnts, pev_aiment) == id)
		{
			new owner = pev(ViewEnts, pev_iuser2);
			
			if(owner && is_user_connected(owner))
			{
				AttachView(owner, owner);
				FreezePlayer(owner, false);
				
				Print(id, "View lost. Player died/disconnected.");
				g_AttachedViews[owner] = 0
			}
			
			fm_remove_entity(ViewEnts);
			break
		}
	}
	
	if(g_AttachedViews[id])
	{
		if(fm_is_valid_ent(g_AttachedViews[id]))
			fm_remove_entity(g_AttachedViews[id]);
		
		if(is_user_connected(id))
			AttachView(id, id);
		
		FreezePlayer(id, false);
		g_AttachedViews[id] = 0
		
		return 1
	}
	
	return 0
}

GetRandomPlayer(ignoreId1, ignoreId2)
{
	new iPlayers[MAX_PLAYERS], iNum
	get_players(iPlayers, iNum);
	
	if(!iNum)
		return 0
	
	new fixed[MAX_PLAYERS], fixedNum = 0
	
	for(new Count; Count < iNum; Count++)
	{
		new id = iPlayers[Count]
		if(id != ignoreId1 && ignoreId2 != ignoreId2 && is_user_alive(id))
			fixed[fixedNum++] = id
	}
	
	return fixedNum > 0 ? fixed[random(fixedNum-1)] : 0
}

AttachView(id, Target)
{
	fm_attach_view(id, Target);
	
	// anti-wallhack plugin is currently enabled
	if(g_WallBlocker > 0)
		wb_setview(id, Target);
}

// Work around for "attach_view()" with ot_207 anti-wallhack plugin
stock wb_setview(id,attachent)
{
	// plugin not found
	if(!g_WallBlocker)
		return 0

	callfunc_begin("fw_setview", get_pcvar_num(g_WallBlocker) ? "block_wallhack.amxx" : "trblock.amxx")
	callfunc_push_int(id)
	callfunc_push_int(attachent)
	callfunc_end()

	return 1
}

stock Print(id, const Message[])
{
	client_print(id, print_console, "[TJD Views] %s", Message);
	client_print(id, print_chat, "[TJD Views] %s", Message);
}