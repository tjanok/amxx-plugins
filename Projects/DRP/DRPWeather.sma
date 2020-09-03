#define DRP

#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <xs>
#include <hamsandwich>

#define PRETHINK_CHECK 00.05
#define STEP_COUNT 100
#define PLAYER_OFFSET_HEIGHT 25
#define MAX_HEIGHT 9999
#define DAMAGE_RADIUS 95
#define seconds_to_screenfade_units(%1) ( ( 1 << 12 ) * ( %1 ) )

new Float:g_UserThink[33]

new const VERSION[] = "0.1a"

new const g_SnowSprite[] = "sprites/drp/drp_snow.spr"
new const g_RainSprite[] = "sprites/drp/drp_rain2.spr"
new const g_ThunderSfx[] = "drp/thunder.wav"
new const g_HeartSfx[] = "drp/heart.wav"

enum
{
	W_NONE = 0,
	W_RAIN,
	W_STORM,
	W_SNOW
}
enum
{
	TR_OUTSIDE = -5,
	TR_INSIDE,
	TR_INSIDE_BUT_VIEW_OUT
}
enum
{
	PERF_LOW = 1,
	PERF_MEDIUM,
	PERF_HIGH
}

new g_SnowSpr
new g_RainSpr
new g_LightningSpr
new g_ScorchDecal

new g_MsgFade
new g_MsgShake
	
// Cvars
new p_Performance
new p_TakeDamage

public plugin_init()
{
	// Main
	register_plugin("TJ Weather Effects", VERSION, "Trevor 'Drak'");
	
	register_clcmd("tjw_lightning", "CmdLightning");
	
	// Cvars
	p_Performance = register_cvar("tjd_w_perf", "3"); // 0 = LOW 1 = MEDIUM 3 = HIGH
	p_TakeDamage = register_cvar("tjd_w_takedmg", "1"); // Amount of damage that can be taken when struck by lightning
	
	new modName[33]
	get_modname(modName, 32);
	
	server_print("%s",modName);
	
	// Messages
	if(equali(modName, "ts"))
		g_MsgFade = get_user_msgid("TSFade");
	else
		g_MsgFade = get_user_msgid("ScreenFade");
		
	g_MsgShake = get_user_msgid("ScreenShake");
	
	// Forwards
	register_forward(FM_PlayerPreThink, "fw_PreThink");
}
public CmdLightning(id)
{
	new origin[3]
	get_user_origin(id, origin, 3);
	
	new Float:o[3]
	IVecFVec(origin, o);
	
	fnWorldDecal(o);
	
	fnLightningEffect(id, o);
	client_print(id, print_console, "sent");
}

public plugin_precache()
{
	// Models
	g_SnowSpr = precache_model(g_SnowSprite);
	g_RainSpr = precache_model(g_RainSprite);
	g_LightningSpr = precache_model("sprites/lgtning.spr");
	
	g_ScorchDecal = engfunc(EngFunc_DecalIndex, "{scorch2");
	
	// Sounds
	precache_sound(g_ThunderSfx);
	precache_sound(g_HeartSfx);
}

public client_connect(id)
	g_UserThink[id] = 0.0

public client_disconnected(id)
	g_UserThink[id] = 0.0
	
public fw_PreThink(id)
{
	static Float:gameTime
	gameTime = get_gametime();
	
	if((gameTime - g_UserThink[id]) > PRETHINK_CHECK)
	{
		g_UserThink[id] = gameTime
		
		new tr = doPlayerTrace(id);
		if(tr == TR_OUTSIDE)
			for(new Count; Count < 3; Count++)
				fnWeatherEffect(id, false);
		
		//client_print(id, print_chat, "Outside: %d", doPlayerTrace(id))
	}
}


/**
 * Throws a shower of sprites or models
 *
 * @note
 * write_byte(TE_SPRAY)
 * write_coord(position.x)
 * write_coord(position.y)
 * write_coord(position.z)
 * write_coord(direction.x)
 * write_coord(direction.y)
 * write_coord(direction.z)
 * write_short(modelindex)
 * write_byte(count)
 * write_byte(speed)
 * write_byte(noise)
 * write_byte(rendermode)
 * */
fnWeatherEffect(id, bool:rain = true)
{
	static iOrigin[3]
	get_user_origin(id, iOrigin);
	
	static iAimOrigin[3]
	get_user_origin(id, iAimOrigin, 1);

	static iEffectOrigin[3]

	iEffectOrigin[0] = iAimOrigin[0] - iOrigin[0] + random_num(-500, 500)
	iEffectOrigin[1] = iAimOrigin[1] - iOrigin[1] + random_num(-500, 500)
	iEffectOrigin[2] = iAimOrigin[2] - iOrigin[2] + random_num(-100, 100)
	
	new const iLength = sqroot(iEffectOrigin[0] * iEffectOrigin[0] + iEffectOrigin[1] * iEffectOrigin[1] + iEffectOrigin[2] * iEffectOrigin[2])
	new const iSpeed = random_num(300, 1000)

	iEffectOrigin[0] = iEffectOrigin[0] * iSpeed / iLength
	iEffectOrigin[1] = iEffectOrigin[1] * iSpeed / iLength
	iEffectOrigin[2] = iEffectOrigin[2] * iSpeed / iLength
	
	message_begin(MSG_ONE_UNRELIABLE, SVC_TEMPENTITY, _, id)
	write_byte(TE_SPRITE)
	
	write_coord(iEffectOrigin[0] + iOrigin[0])
	write_coord(iEffectOrigin[1] + iOrigin[1])
	write_coord(iEffectOrigin[2] + iOrigin[2])
	
	if(rain)
	{
		write_short(g_RainSpr);
		write_byte(random_num(5, 20)) // scale
	}
	else
	{
		write_short(g_SnowSpr);
		write_byte(random_num(1, 5)) // scale
	}
	
	write_byte(100) // brightness
	
	message_end();
}

fnLightningEffect(id, Float:fOrigin[3])
{
	static trace = 0
	static Float:skyOrigin[3]
	
	xs_vec_copy(fOrigin, skyOrigin);
	skyOrigin[2] += MAX_HEIGHT
	
	engfunc(EngFunc_TraceLine, fOrigin, skyOrigin, IGNORE_MONSTERS, 0, trace);
	get_tr2(trace, TR_vecEndPos, skyOrigin);
	
	if(engfunc(EngFunc_PointContents, skyOrigin) != CONTENTS_SKY)
		return
	
	new perf = get_pcvar_num(p_Performance);
	
	if(perf >= PERF_HIGH)
	{
		new Float:start[3], Float:end[3]
		xs_vec_copy(fOrigin, start);
		xs_vec_copy(skyOrigin, end);

		new Float:i = 1.0;
		for(new Count;Count < 12; Count++)
		{
			i = (i * 2.0)
			new Float:cos = floatcos(i, degrees);
			new Float:sin = floatsin(i, degrees);
			
			start[0] += (cos * 150.0)
			start[1] += (sin * 150.0)
			
			fnBeamLightning(start, end);
		}
		fnWorldDecal(fOrigin);
	}
	else
	{
		fnBeamLightning(fOrigin, skyOrigin);
	}

	if(perf >= PERF_MEDIUM)
	{
		new ent = fm_create_entity("info_target");
		engfunc(EngFunc_SetOrigin, ent, fOrigin);
		dllfunc(DLLFunc_Spawn, ent);
		
		if(fm_is_valid_ent(ent))
		{
			emit_sound(ent, CHAN_AUTO, g_ThunderSfx, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
			engfunc(EngFunc_RemoveEntity, ent);
		}
		
		if(perf >= PERF_HIGH)
		{
			for(new Count; Count < 3; Count++)
			{
				if(Count > 0)
				{
					fOrigin[0] += random_num(-15, 15);
					fOrigin[1] += random_num(-25, 25);
				}
				fnSparks(fOrigin);
			}
		}
		else
			fnSparks(fOrigin);
	}
	
	new takeDamage = get_pcvar_num(p_TakeDamage);
	if(takeDamage > 0)
	{
		new players[MAX_PLAYERS], num, Float:plOrigin[3]
		get_players(players, num, "ac");
		
		for(new Count; Count < num; Count++)
		{
			new Target = players[Count]
			pev(Target, pev_origin, plOrigin);
			
			if(get_distance_f(plOrigin, fOrigin) <= DAMAGE_RADIUS)
			{
				new hp = pev(id, pev_health);
				new dmg = random_num(1, takeDamage)
				
				// TODO
				// this is going to kill them, stop (for now?)
				if((hp-dmg) <= 0)
					continue
				
				client_print(Target, print_chat, "[Weather] You've been struck my lightning!");
				fnScreenFade(id);
				
				if(perf >= PERF_MEDIUM)
				{
					fnShake(id);
					client_cmd(Target, "spk ^"sound/%s^"", g_HeartSfx);
				}
			}
		}
	}
}

fnWorldDecal(Float:fOrigin[3])
{
	if(!g_ScorchDecal)
		return
	
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
	write_byte(TE_WORLDDECAL);
	
	engfunc(EngFunc_WriteCoord, fOrigin[0]);
	engfunc(EngFunc_WriteCoord, fOrigin[1]);
	engfunc(EngFunc_WriteCoord, fOrigin[2]);
	
	write_byte(g_ScorchDecal);
	
	message_end();
}  
fnScreenFade(id)
{
	if(!g_MsgFade)
		return
	
	message_begin(MSG_ONE_UNRELIABLE, g_MsgFade, _, id);
	
	write_short(seconds_to_screenfade_units(4)) // Duration
	write_short(seconds_to_screenfade_units(2)) // Hold Time
	write_short(0x0001)
	
	write_byte(175);
	write_byte(175);
	write_byte(175);
	
	write_byte(255);
	
	message_end();
}

fnShake(id)
{
	if(!g_MsgShake)
		return
	
	message_begin(MSG_ONE_UNRELIABLE, g_MsgShake, _, id);

	write_short(seconds_to_screenfade_units(2)); // Amplitude
	write_short(seconds_to_screenfade_units(5)); // Duration
	write_short(seconds_to_screenfade_units(2)); // Frequency

	message_end();
}

fnSparks(Float:fOrigin[3])
{
	message_begin_f(MSG_PVS, SVC_TEMPENTITY, fOrigin);
	write_byte(TE_SPARKS);
	
	engfunc(EngFunc_WriteCoord, fOrigin[0]);
	engfunc(EngFunc_WriteCoord, fOrigin[1]);
	engfunc(EngFunc_WriteCoord, fOrigin[2]);
	
	message_end();
}

fnBeamLightning(Float:fOrigin[3], Float:skyOrigin[3])
{
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
	write_byte(TE_BEAMPOINTS);
	
	engfunc(EngFunc_WriteCoord, fOrigin[0]);
	engfunc(EngFunc_WriteCoord, fOrigin[1]);
	engfunc(EngFunc_WriteCoord, fOrigin[2]);
	
	engfunc(EngFunc_WriteCoord, skyOrigin[0]);
	engfunc(EngFunc_WriteCoord, skyOrigin[1]);
	engfunc(EngFunc_WriteCoord, skyOrigin[2]);
	
	write_short(g_LightningSpr);
	
	write_byte(0); // start frame
	write_byte(1); // famerate in 0.1's
	
	write_byte(random_num(5, 25)); // life in 0.1's
	write_byte(65); // width in 0.1's
	write_byte(random(100)); //amplitude in 0.01's
	
	switch(random_num(0, 2))
	{
		case 0:
		{
			write_byte(0); // r
			write_byte(76); // g
			write_byte(255); // b
		}
		case 1:
		{
			write_byte(150); // r
			write_byte(150); // g
			write_byte(150); // b
		}
		case 2:
		{
			write_byte(0); // r
			write_byte(0); // g
			write_byte(150); // b
		}
	}
	
	write_byte(100); // brightness
	write_byte(1); // scroll speed

	message_end();
}

bool:isOriginOutside(id = 0, Float:origin[3] = {0.0, 0.0, 0.0})
{
	if(id && is_user_connected(id))
		pev(id, pev_origin, origin)

	new step
	while(engfunc(EngFunc_PointContents, origin) == CONTENTS_EMPTY)
	{
		origin[2] += 0.5
		if(++step > STEP_COUNT)
			break
	}
	
	if(engfunc(EngFunc_PointContents, origin) == CONTENTS_SKY)
		return true
	
	client_print(0, print_chat, "[TJ] Step Count: %d", step);
	return false
}


doPlayerTrace(id)
{
	static trace = 0
	static Float:plOrigin[3], Float:skyOrigin[3]
	
	pev(id, pev_origin, plOrigin);
	
	plOrigin[2] += PLAYER_OFFSET_HEIGHT
	xs_vec_copy(plOrigin, skyOrigin);
	
	skyOrigin[2] += MAX_HEIGHT
	
	engfunc(EngFunc_TraceLine, plOrigin, skyOrigin, DONT_IGNORE_MONSTERS, 0, trace);
	get_tr2(trace, TR_vecEndPos, skyOrigin)
	
	if(engfunc(EngFunc_PointContents, skyOrigin) == CONTENTS_SKY)
		return TR_OUTSIDE
	
	new vOrigin[3]
	get_user_origin(id, vOrigin, 3);
	
	IVecFVec(vOrigin, plOrigin);
	vOrigin[2] += MAX_HEIGHT
	IVecFVec(vOrigin, skyOrigin);
	
	engfunc(EngFunc_TraceLine, plOrigin, skyOrigin, DONT_IGNORE_MONSTERS, 0, trace);
	get_tr2(trace, TR_vecEndPos, skyOrigin);
	
	if(engfunc(EngFunc_PointContents, skyOrigin) == CONTENTS_SKY)
		return TR_INSIDE_BUT_VIEW_OUT
	
	return TR_INSIDE
	
}  