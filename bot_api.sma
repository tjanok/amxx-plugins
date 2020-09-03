/*	<License>
		Copyright © 2006 Space Headed Productions

		AMXX Bot is free software; you can redistribute it and/or
		modify it under the terms of the GNU General Public License
		as published by the Free Software Foundation.

		This program is distributed in the hope that it will be useful,
		but WITHOUT ANY WARRANTY; without even the implied warranty of
		MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
		GNU General Public License for more details.

		You should have received a copy of the GNU General Public License
		along with AMXX Bot; if not, write to the Free Software
		Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
*/

// Edited to make it TS specific

#include <amxmodx>
#include <fakemeta>

#define PLUGIN "AMXX Bot"
#define VERSION "0.5.1"
#define AUTHOR "Space Headed"

#define MAX_BOT_INTEGER 2
#define MAX_BOT_FLOAT 3

new INT_OFFSET = 1
new FLOAT_OFFSET = 5

enum {
	bot_int_start,
	bot_buttons,
	bot_impulse,
	bot_int_end,
	bot_float_start,
	bot_forward_move,
	bot_side_move,
	bot_up_move,
	bot_float_end
}

// Misc Data
new gMaxplayers

// Bot Data
new iBotData[33][MAX_BOT_INTEGER]
new Float:fBotData[33][MAX_BOT_FLOAT]
new Float:BotAngles[33][3]
new bool:isBot[33]

// Bot Forwards
new gForwardBotConnect
new gForwardBotDisconnect
new gForwardBotDamage
new gForwardBotDeath
new gForwardBotSpawn
new gForwardBotThink
new gForwardTrashRet

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	new Temp[3]
	get_modname(Temp,2);
	
	if(!equali(Temp,"ts"))
	{
		set_fail_state("[BOT_API] This bot api version is for the mod TS ONLY.");
		return
	}
	
	register_event("DeathMsg","Event_DeathMsg","a");
	register_event("TSHealth","Event_Health","be");
	register_event("ResetHUD","Event_ResetHUD","be");

	register_forward(FM_ClientDisconnect,"Forward_ClientDisconnect");
	register_forward(FM_ClientPutInServer,"Forward_ClientPutInServer");
	register_forward(FM_StartFrame,"Forward_StartFrame");

	gForwardBotConnect = CreateMultiForward("bot_connect",ET_IGNORE,FP_CELL);
	gForwardBotDisconnect = CreateMultiForward("bot_disconnect",ET_IGNORE,FP_CELL);
	gForwardBotDamage = CreateMultiForward("bot_damage",ET_IGNORE,FP_CELL,FP_CELL);
	
	gForwardBotDeath = CreateMultiForward("bot_death",ET_IGNORE,FP_CELL);
	gForwardBotSpawn = CreateMultiForward("bot_spawn",ET_IGNORE,FP_CELL);
	gForwardBotThink = CreateMultiForward("bot_think",ET_IGNORE,FP_CELL);

	gMaxplayers = get_maxplayers();
}

public plugin_natives()
{
	register_library("botapi");
	register_native("create_bot","Native_create_bot");
	register_native("remove_bot","Native_remove_bot");
	
	register_native("is_bot","Native_is_bot");
	register_native("get_bot_data","Native_get_bot_data");
	register_native("set_bot_data", "Native_set_bot_data");
	
	register_native("set_bot_angles","Native_set_bot_angles");
	register_native("set_bot_chat","Native_set_bot_chat");
}

public Forward_ClientDisconnect(id)
{
	if(isBot[id])
	{
		ExecuteForward(gForwardBotDisconnect,gForwardTrashRet,id);
		isBot[id] = false
	}
}

public Forward_ClientPutInServer(id)
{
	if(isBot[id])
		ExecuteForward(gForwardBotConnect,gForwardTrashRet,id);
}

public Event_DeathMsg()
{
	static id
	id = read_data(2);
	
	if(isBot[id])
		ExecuteForward(gForwardBotDeath,gForwardTrashRet,id);
}

public Event_Health(id)
{
	if(isBot[id])
	{
		new const iDamage = read_data(1);
		if(iDamage > 0)
			ExecuteForward(gForwardBotDamage,gForwardTrashRet,id,iDamage);
	}
	return PLUGIN_CONTINUE
}

public Event_ResetHUD(id)
{
	if(isBot[id])
	{
		if(is_user_alive(id))
			ExecuteForward(gForwardBotSpawn,gForwardTrashRet,id);
	}
}

public Forward_StartFrame()
{
	static Counter
	for(Counter = 1;Counter <= gMaxplayers;Counter++)
		run_bot(Counter);
}

run_bot(const id)
{
	if(!isBot[id] || !pev_valid(id))
		return
	
	if(!is_user_alive(id))
	{
		// Force respawn (TODO: Should this be turned into a CVar?)
		dllfunc(DLLFunc_Spawn,id);
		return
	}
	
	ExecuteForward(gForwardBotThink,gForwardTrashRet,id);
	
	if(fBotData[id][bot_forward_move-FLOAT_OFFSET] > 1)
	{
		iBotData[id][bot_buttons-INT_OFFSET] &= ~IN_BACK
		iBotData[id][bot_buttons-INT_OFFSET] |= IN_FORWARD
	}
	else if(fBotData[id][bot_forward_move-FLOAT_OFFSET] < 0)
	{
		iBotData[id][bot_buttons-INT_OFFSET] &= ~IN_FORWARD
		iBotData[id][bot_buttons-INT_OFFSET] |= IN_BACK
	}
	else
	{
		iBotData[id][bot_buttons-INT_OFFSET] &= ~IN_FORWARD
		iBotData[id][bot_buttons-INT_OFFSET] &= ~IN_BACK
	}

	if(fBotData[id][bot_side_move-FLOAT_OFFSET] > 0)
	{
		iBotData[id][bot_buttons-INT_OFFSET] &= ~IN_MOVELEFT
		iBotData[id][bot_buttons-INT_OFFSET] |= IN_MOVERIGHT
	}
	else if(fBotData[id][bot_side_move-FLOAT_OFFSET] < 0)
	{
		iBotData[id][bot_buttons-INT_OFFSET] &= ~IN_MOVERIGHT
		iBotData[id][bot_buttons-INT_OFFSET] |= IN_MOVELEFT
	}
	else
	{
		iBotData[id][bot_buttons-INT_OFFSET] &= ~IN_MOVERIGHT
		iBotData[id][bot_buttons-INT_OFFSET] &= ~IN_MOVELEFT
	}
	
	static Float:mSeconds
	global_get(glb_frametime,mSeconds);
	
	mSeconds *= 1000.0
	engfunc(EngFunc_RunPlayerMove,id,BotAngles[id],fBotData[id][bot_forward_move-FLOAT_OFFSET],fBotData[id][bot_side_move-FLOAT_OFFSET],fBotData[id][bot_up_move-FLOAT_OFFSET],iBotData[id][bot_buttons-INT_OFFSET],iBotData[id][bot_impulse-INT_OFFSET],floatround(mSeconds));
}

public Native_create_bot()
{
	new id,plName[32]
	get_string(1,plName,31);
	id = engfunc(EngFunc_CreateFakeClient,plName);
	
	if(!pev_valid(id))
		return 0

	engfunc(EngFunc_FreeEntPrivateData,id);
	dllfunc(MetaFunc_CallGameEntity,"player",id);
	
	set_user_info(id,"rate","3500");
	set_user_info(id,"cl_updaerate","25");
	set_user_info(id,"cl_lw", "1");
	set_user_info(id,"cl_lc","1");
	set_user_info(id,"cl_dlmax","128");
		
	set_pev(id,pev_flags,pev(id,pev_flags) | FL_FAKECLIENT);
	set_pev(id,pev_colormap,id);
	
	new Temp[1]
	dllfunc(DLLFunc_ClientConnect,id,plName,"127.0.0.1",Temp);
	dllfunc(DLLFunc_ClientPutInServer,id);
	
	engfunc(EngFunc_RunPlayerMove,id,Float:{0.0,0.0,0.0},0.0,0.0,0.0,0,0,76);

	isBot[id] = true
	return id
}

public Native_remove_bot()
{
	new const id = get_param(1);
	if(!PassCheck(id))
		return 0
	
	ExecuteForward(gForwardBotDisconnect,gForwardTrashRet,id);
	isBot[id] = false
	
	new plName[32]
	pev(id,pev_netname,plName,31);
	server_cmd("kick ^"%s^"",plName);
	
	return 1
}

public Native_is_bot()
{
	new const id = get_param(1);
	if(PassCheck(id))
		return 1
	
	return 0
}

public Native_get_bot_data()
{
	new const id = get_param(1);
	if(!PassCheck(id))
		return 0
	
	new const data = get_param(2)
	
	if(data > bot_int_start && data < bot_int_end)
	{
		switch(data)
		{
			case bot_buttons: return iBotData[id][bot_buttons-INT_OFFSET]
			case bot_impulse: return iBotData[id][bot_impulse-INT_OFFSET]
		}
	}
	
	// Floats
	else if(data > bot_float_start && data < bot_float_end)
	{
		switch(data)
		{
			case bot_forward_move: set_float_byref(3,fBotData[id][bot_forward_move-FLOAT_OFFSET]);
			case bot_side_move: set_float_byref(3,fBotData[id][bot_side_move-FLOAT_OFFSET]);
			case bot_up_move: set_float_byref(3,fBotData[id][bot_up_move-FLOAT_OFFSET]);
		}
	}
	
	return 1
}

public Native_set_bot_data()
{
	new const id = get_param(1);
	if(!PassCheck(id))
		return 0

	new const data = get_param(2);
	
	// Integers
	if (data > bot_int_start && data < bot_int_end)
	{
		new iVal = get_param_byref(3);
		switch (data)
		{
			case bot_buttons: iBotData[id][bot_buttons-INT_OFFSET] = iVal
			case bot_impulse: iBotData[id][bot_impulse-INT_OFFSET] = iVal
		}
	}
	
	// Floats
	else if (data > bot_float_start && data < bot_float_end)
	{
		new Float:fVal = get_float_byref(3);
		switch (data)
		{
			case bot_forward_move: fBotData[id][bot_forward_move-FLOAT_OFFSET] = fVal
			case bot_side_move: fBotData[id][bot_side_move-FLOAT_OFFSET] = fVal
			case bot_up_move: fBotData[id][bot_up_move-FLOAT_OFFSET] = fVal
		}
	}
	
	return 1
}

public Native_set_bot_angles()
{
	new const id = get_param(1);
	if(!PassCheck(id))
		return 0
	
	new Float:vVec[3]
	get_array_f(2, vVec, 3)

	new Float:vOrig[3]
	pev(id, pev_origin, vOrig)

	new Float:dOrig[3]
	dOrig[0] = vVec[0] - vOrig[0]
	dOrig[1] = vVec[1] - vOrig[1]
	dOrig[2] = vVec[2] - vOrig[2]

	engfunc(EngFunc_VecToAngles, dOrig, BotAngles[id])
	BotAngles[id][0] = 0.0
	BotAngles[id][2] = 0.0
	set_pev(id, pev_angles, BotAngles[id])
	// Update View
	set_pev(id, pev_v_angle, BotAngles[id])
	
	return 1
}

public Native_set_bot_chat()
{
	new const id = get_param(1);
	if(!PassCheck(id))
		return 0
	
	// Very *hacky* but it allows plugins to manipulate the said thing
	// just as a player would chat
	
	new Message[128]
	get_string(2,Message,127);
	
	if(Message[0])
		engclient_cmd(id,"say",Message);
	
	return 0	
}

PassCheck(const id)
	return (id <= gMaxplayers && isBot[id]) ? 1 : 0