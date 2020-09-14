#include <amxmodx>
#include <tsxweapons>
#include <fakemeta>

// This plugin blocks all TS Message (EX: Drak fragged Spray)
// Not exactly needed in RP

// This also fixes the "fuck my ear, i just got stuck in a door" glitch
// where the sound spams over and over and over

new Float:g_LastPlayTime

// CVars
new p_BlockDeathMsg

public plugin_precache()
{
	// CVars
	p_BlockDeathMsg = register_cvar("DRP_BlockDeathMsg","1");
}

public plugin_init()
{
	// Main
	register_plugin("TS Engine Fixes","0.1a","Drak");
	
	// Messages / Events
	register_message(get_user_msgid("TSMessage"),"Event_TSMessage");
	register_message(get_user_msgid("DeathMsg"),"Event_DeathMessage");
	
	// MetaMod Events
	register_forward(FM_EmitSound,"Event_EmitSound");
}

public Event_DeathMessage()
{
	if(!get_pcvar_num(p_BlockDeathMsg))
		return PLUGIN_CONTINUE
	
	// Block
	// We block it here (instead of using "set_msg_block()" because,
	// Other (alot) plugins use the deathmsg event, and if it's not called, we break alot of stuff
	
	return PLUGIN_HANDLED
}

public Event_TSMessage()
{
	static Arg[64]
	get_msg_arg_string(6,Arg,63);
	
	if(!Arg[0])
		return PLUGIN_CONTINUE
	
	if(containi(Arg,"#TS") != -1)
		return PLUGIN_HANDLED
	
	return PLUGIN_CONTINUE
}

// This will disallow door sounds to "spam"
public Event_EmitSound(ent,iChannel,const szSample[])
{
	if(containi(szSample,"doormove") == -1)
		return FMRES_IGNORED
	
	static Float:CurtPlayTime
	CurtPlayTime = get_gametime();
	
	if(CurtPlayTime - g_LastPlayTime <= 1.0)
		return FMRES_SUPERCEDE
	
	g_LastPlayTime = CurtPlayTime
	
	return FMRES_IGNORED
}