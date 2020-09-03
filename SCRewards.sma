#include <amxmodx>
#include <amxmisc>
#include <nvault>
#include <fun>
#include <fakemeta>
#include <hamsandwich>
#include <engine>

// These define how many hours a user must have
// to use the defined feature

#define CUSTOM_TITLE 50
#define VIP_HOUR 100
#define HOLO_HOUR 5
#define TELEPORT_HOUR_0 5
#define TELEPORT_HOUR_1 10
#define TELEPORT_HOUR_2 20
#define TELEPORT_HOUR_3 30

// Defines the time (in seconds) to pick a rage player
// The timeout define, defines (in seconds) how long the person rages
#define RAGE_TIME 900
#define RAGE_TIMEOUT 10.0

#define MAX_RANK 10

new const g_MonsterNames[][33] =
{
	"None"
}

new g_CurrentMonster

new const g_PowerNames[][12] = 
{
	"None"
}

// Ranks are changed, every 10 hours
new const g_RankNames[][33] =
{
	"Noob",
	"Regular",
	"Frequenter",
	"Dedicated",
	"Expert-Player",
	"IDontSleep",
	"GiveMeVIP",
	"Holy Fuck",
	"Attention Whore"
}

new const g_RageSound[] = "dsrv/join_wav.wav"

// User Data
new g_UserFrags[33]
new g_UserDeaths[33]
new g_UserTime[33]
new g_UserTitle[33][33]
new g_UserPower[33]

// Teleporting
new g_UserSaveLocations[4][33][3]

// CVars
new p_HudRed
new p_HudGreen
new p_HudBlue
new p_Free

new g_RageCounter
new g_RageUser

new g_Vault
new g_PluginEnd

public plugin_precache()
{
	// Vault
	g_Vault = nvault_open("SCRewards");
	if(g_Vault == INVALID_HANDLE)
		server_print("[SC-REWARDS] Unable to open nVault File.");
	
	// CVars
	p_HudRed = register_cvar("SCR_HUD_R","30");
	p_HudGreen = register_cvar("SCR_HUD_G","144");
	p_HudBlue = register_cvar("SCR_HUD_B","255");
	p_Free = register_cvar("SCR_FreeMode","0");
	
	// Models/Sounds/Etc
}

public plugin_init()
{
	// Main
	register_plugin("SC Rewards","0.1a","Drak");
	
	// Commands
	// Admin
	register_concmd("scr_givetitle","CmdGiveTitle",ADMIN_BAN,"<target> <title> - set's a users title");
	
	// Players
	register_clcmd("say","CmdSay");
	register_clcmd("say_team","CmdSay");
	
	// Events / Forwards
	register_forward(FM_Sys_Error,"plugin_end");
	
	// Tasks
	set_task(1.0,"RenderHud",_,_,_,"b");
}
/*==================================================================================================================================================*/
/*==================================================================================================================================================*/
public CmdGiveTitle(id,level,cid)
{
	if(!cmd_access(id,level,cid,2))
		return PLUGIN_HANDLED
	
	new Arg[33]
	read_argv(1,Arg,32);
	
	new Target = cmd_target(id,Arg,CMDTARGET_ALLOW_SELF);
	if(!Target)
		return PLUGIN_HANDLED
	
	read_argv(2,Arg,32);
	if(!Arg[0])
	{
		client_print(id,print_console,"[AMXX] Invalid Title.");
		return PLUGIN_HANDLED
	}
	
	new plName[33]
	copy(g_UserTitle[Target],32,Arg);
	
	get_user_name(Target,plName,32);
	
	client_print(Target,print_chat,"[AMXX] Your title has been changed.");
	client_print(id,print_console,"[AMXX] You have set %s's title to: %s",plName,Arg);
	
	return PLUGIN_HANDLED
}
// Commands
public CmdSay(id)
{
	static Arg[256],plName[33]
	get_user_name(id,plName,32);
	
	read_args(Arg,255);
	remove_quotes(Arg);
	
	if(!Arg[0])
		return PLUGIN_HANDLED
	
	if(Arg[0] == '/')
	{
		if(!is_user_alive(id))
			return PLUGIN_HANDLED
		
		new Command[12],Other[33]
		parse(Arg,Command,11,Other,32);
		
		new Access = 0
		if((access(id,ADMIN_KICK)) || (GetTotalHours(id) > VIP_HOUR) || (get_pcvar_num(p_Free)))
			Access = 1
		
		replace(Command,11,"/","");
		
		if(equali(Command,"mytime") || equali(Command,"time"))
		{
			new CurrentTime = (g_UserTime[id] + get_user_time(id))
			new TotalTime = CurrentTime
			new Days,Hours,Minutes,Seconds
			
			if( CurrentTime > 86400 )
			{
				Days = (CurrentTime / (60 * 60 * 24))
				CurrentTime = (CurrentTime % (60 * 60 * 24))
			}
			if( CurrentTime > 3600 )
			{
				Hours = CurrentTime / (60 * 60)
				
				CurrentTime = CurrentTime % (60 * 60)
			}
			if( CurrentTime > 60 )
			{	
				Minutes = CurrentTime / 60
				CurrentTime = CurrentTime % 60
			}
			Seconds = CurrentTime
			new TotalHours = (TotalTime / 3600)
			
			client_print(id,print_chat,"[AMXX] Your current time is: %d Hours. (%d days - %d hours - %d minutes - %d seconds)",TotalHours,Days,Hours,Minutes,Seconds);
			return PLUGIN_HANDLED
		}
		else if(equali(Command,"stats") || equali(Command,"mystats"))
		{
			new const Frags = (get_user_frags(id) + g_UserFrags[id]),Deaths = (get_user_deaths(id) + g_UserDeaths[id])
			client_print(id,print_chat,"[AMXX] You have: %d Total Frags - %d Total Deaths. Type /mytime to view your time stats.",Frags,Deaths);
			return PLUGIN_HANDLED
		}
		else if(equali(Command,"settitle"))
		{
			new Hours = GetTotalHours(id);
			if(Hours < CUSTOM_TITLE && !Access)
			{
				client_print(id,print_chat,"[AMXX] You must have %d hours. You have: %d",CUSTOM_TITLE,Hours);
				return PLUGIN_HANDLED
			}
			
			if(!Other[0])
			{
				client_print(id,print_chat,"[AMXX] Usage: /settitle <title>");
				return PLUGIN_HANDLED
			}
			
			if(strlen(Other) > 12)
			{
				client_print(id,print_chat,"[AMXX] Title to long. Max 12 chars.");
				return PLUGIN_HANDLED
			}
			
			copy(g_UserTitle[id],32,Other);
			client_print(id,print_chat,"[AMXX] Your title has been set to: %s",Other);
			
			return PLUGIN_HANDLED
		}
		else if(equali(Command,"holo"))
		{
			new Hours = GetTotalHours(id);
			if(Hours < HOLO_HOUR && !Access)
			{
				client_print(id,print_chat,"[AMXX] You must have %d hours. You have: %d",HOLO_HOUR,Hours);
				return PLUGIN_HANDLED
			}
			
			new TotalTime = get_user_time(id) + g_UserTime[id]
			
			new Mode = (pev(id,pev_rendermode) == kRenderFxHologram) ? 1 : 0
			client_print(id,print_chat,"[AMXX] Your hologram has been turned: %s %d" ,Mode ? "Off" : "On",((TotalTime / 60) % 600));
			
			if(Mode)
				set_user_rendering(id);
			else
				set_user_rendering(id,kRenderFxHologram,255,0,0,kRenderTransAdd,255);
				
			return PLUGIN_HANDLED
		}
		else if(equali(Command,"saveme"))
		{
			new Number = str_to_num(Other);
			if(Number > 4 || !Number)
			{
				client_print(id,print_chat,"[AMXX] Invalid Number. You're only allowed 4 save spots");
				return PLUGIN_HANDLED
			}
			
			new Hours = GetTotalHours(id),Allowed = 0
			
			switch(Number - 1)
			{
				case 0: 
					if(Hours > TELEPORT_HOUR_0 || Access)
						Allowed = 1
				case 1: 
					if(Hours > TELEPORT_HOUR_1 || Access)
						Allowed = 1
				case 2: 
					if(Hours > TELEPORT_HOUR_2 || Access)
						Allowed = 1
				case 3: 
					if(Hours > TELEPORT_HOUR_3 || Access)
						Allowed = 1
			}
			
			if(!Allowed)
			{
				client_print(id,print_chat,"[AMXX] You must have %d hour(s) for 1 slot, %d for two, %d for three, %d for four.",
				TELEPORT_HOUR_0,TELEPORT_HOUR_1,TELEPORT_HOUR_2,TELEPORT_HOUR_3);
				return PLUGIN_HANDLED
			}
			
			new Origin[3],Float:fOrigin[3]
			get_user_origin(id,Origin);
			
			IVecFVec(Origin,fOrigin);
			
			new eContent = engfunc(EngFunc_PointContents,fOrigin);
			if(eContent == CONTENTS_LADDER || eContent == CONTENTS_SOLID)
			{
				client_print(id,print_chat,"[AMXX] You can't save this location. You might be on a ladder, or stuck.");
				return PLUGIN_HANDLED
			}
			
			g_UserSaveLocations[Number - 1][id][0] = Origin[0]
			g_UserSaveLocations[Number - 1][id][1] = Origin[1]
			g_UserSaveLocations[Number - 1][id][2] = Origin[2]
			
			client_cmd(id,"spk ^"buttons/button8.wav^"");
			client_print(id,print_chat,"[AMXX] Location: %d saved",Number);
			
			return PLUGIN_HANDLED
		}
		else if(equali(Command,"posme"))
		{
			new Number = str_to_num(Other);
			if(Number > 4 || !Number)
			{
				client_print(id,print_chat,"[AMXX] Invalid Number. You're only allowed 4 save spots");
				return PLUGIN_HANDLED
			}
			
			if((!g_UserSaveLocations[Number - 1][id][0] && !g_UserSaveLocations[Number - 1][id][1] && !g_UserSaveLocations[Number - 1][id][2]))
			{
				client_print(id,print_chat,"[AMXX] Nothing saved at this location. #%d",Number);
				return PLUGIN_HANDLED
			}
			
			new Float:fOrigin[3]
			IVecFVec(g_UserSaveLocations[Number - 1][id],fOrigin);
			
			new eContent = engfunc(EngFunc_PointContents);
			if(eContent != CONTENTS_EMPTY)
			{
				client_print(id,print_chat,"[AMXX] Unable to teleport. A person might be blocking your location.");
				return PLUGIN_HANDLED
			}
			
			set_user_origin(id,g_UserSaveLocations[Number - 1][id]);
			client_print(id,print_chat,"[AMXX] Successfully Teleported.");
			
			return PLUGIN_HANDLED
		}
	}
	
	// After we take care of commands, add our rank into the chat
	// Yes, this is a rip off, of SnarkCafe'
	format(Arg,255,"[%s] %s: %s",g_UserTitle[id][0] ? g_UserTitle[id] : g_RankNames[GetUserRank(id)],plName,Arg);
	client_print(0,print_chat,Arg);
	
	return PLUGIN_HANDLED
}

/*==================================================================================================================================================*/
public client_authorized(id)
{
	if(g_PluginEnd)
		return PLUGIN_CONTINUE
	
	new AuthID[36]
	get_user_authid(id,AuthID,35);
	
	if(containi(AuthID,"PEND") != -1 || containi(AuthID,"LAN") != -1)
		return PLUGIN_CONTINUE
	
	new Buffer[128],Time
	new HaveData = nvault_lookup(g_Vault,AuthID,Buffer,127,Time);
	
	// DATA:
	// SecondsInt FragsInt DeathsInt Donator1/0Int CustomTitleString
	
	if(HaveData)
	{
		new szSeconds[12],szFrags[12],szDeath[12],szDonator[12],Title[33]
		parse(Buffer,szSeconds,11,szFrags,11,szDeath,11,szDonator,11,Title,32);
		
		g_UserTime[id] = str_to_num(szSeconds);
		g_UserFrags[id] = str_to_num(szFrags);
		g_UserDeaths[id] = str_to_num(szDeath);
		
		if(Title[0])
			copy(g_UserTitle[id],32,Title);
	}
	
	if( (access(id,ADMIN_KICK)) )
	{
		new const maxPlayers = get_maxplayers();
		for(new Count;Count <= maxPlayers;Count++)
			if(is_user_alive(Count) && !is_user_admin(Count))
				client_cmd(Count,"spk ^"buzwarn buzwarn. administration entry^"");
	}
	
	return PLUGIN_CONTINUE
}
public client_disconnect(id)
{
	if(!g_PluginEnd)
		SaveUserData(id);
	
	if(g_RageUser == id)
		EndRage();
}
/*==================================================================================================================================================*/
public RenderHud()
{
	static iPlayers[32],Buffer[256]
	
	new iNum,Player,GrabFrags = 0
	get_players(iPlayers,iNum);
	
	new UserFrags[33]
	
	// Y = UP/DOWN
	// X = LEFT/RIGHT
	
	set_hudmessage(get_pcvar_num(p_HudRed),get_pcvar_num(p_HudGreen),get_pcvar_num(p_HudBlue),0.0,0.70,_,_,999.0,_,_,3);
	
	if(++g_RageCounter >= RAGE_TIME)
	{
		//if( random(2) != 0)
			//GrabFrags = 1
		
		//client_print(0,print_chat,"atemmping: %d",GrabFrags);
		g_RageCounter = 0
	}
	
	for(new Count;Count < iNum;Count++)
	{
		Player = iPlayers[Count]
		
		if(!is_user_alive(Player))
			continue
		
		if(GrabFrags)
			UserFrags[Count] = get_user_frags(Player);
		else if(g_RageUser == Player)
			get_user_name(Player,UserFrags,32);
		
		formatex(Buffer,255,"Level: %d / 1800^nUpgraded Monsters: %s^nRage Player: %s",GetLevel(Player),g_MonsterNames[g_CurrentMonster],(g_RageUser == Player) ? UserFrags : "None");
		show_hudmessage(Player,Buffer);
	}
	
	// Rage Player
	if(GrabFrags)
	{
		new mostKills[2] = {0,0},Frags
		for(new Count;Count < iNum;Count++)
		{
			Player = iPlayers[Count]
			
			if(!is_user_alive(Player))
				continue
			
			Frags = get_user_frags(Player);
			if(Frags > mostKills[1])
			{
				mostKills[1] = Frags
				mostKills[0] = Player
			}
		}
		
		if(mostKills[1] < 1)
			return
		
		g_RageUser = Player
		get_user_name(Player,UserFrags,32);
		
		set_hudmessage(255,0,0,-1.0,-1.0,1,_,6.0,_,_,-1);
		show_hudmessage(0,"HOT DAMN %s IS SOME HOT SHIT",UserFrags);
		
		client_print(Player,print_chat,"[AMXX] You are raging. You will do more damage, run faster, and jump higher.");
		set_task(RAGE_TIMEOUT,"EndRage",Player);
		
		client_cmd(0,"spk ^"woop woop^"");
	}
}
  
public EndRage()
{
	new plName[33]
	get_user_name(g_RageUser,plName,32);
	
	set_hudmessage(255,0,0,-1.0,-1.0,1,_,6.0,_,_,-1);
	show_hudmessage(0,"%s rage has ended.",plName);
	
	if(is_user_alive(g_RageUser))
		client_print(g_RageUser,print_chat,"[AMXX] RAGE: Your rage time has ended.");
	
	g_RageUser = 0
}
/*==================================================================================================================================================*/
SaveUserData(const id)
{
	// DATA:
	// SecondsInt FragsInt DeathsInt Donator1/0Int CustomTitleString
	
	static Buffer[128],AuthID[36]
	get_user_authid(id,AuthID,35);
	
	if(!AuthID[0] || containi(AuthID,"PEND") != -1 || containi(AuthID,"LAN") != -1)
		return PLUGIN_CONTINUE
	
	formatex(Buffer,127,"%d %d %d 0 ^"%s^"",(g_UserTime[id] + get_user_time(id)),(g_UserFrags[id] + get_user_frags(id)),(g_UserDeaths[id] + get_user_deaths(id)),g_UserTitle[id]);
	nvault_set(g_Vault,AuthID,Buffer);
	
	g_UserDeaths[id] = 0
	g_UserFrags[id] = 0
	g_UserTime[id] = 0
	g_UserTitle[id] = ""
	
	for(new Count;Count < 4;Count++)
	{
		g_UserSaveLocations[Count][id][0] = 0
		g_UserSaveLocations[Count][id][1] = 0
		g_UserSaveLocations[Count][id][2] = 0
	}
	
	return PLUGIN_HANDLED
}

// Returns a number from 1-100 based on play hours
// Used to get the RANK NAME
GetUserRank(const id)
{
	new Rank,Hours = GetTotalHours(id);
	
	if(is_user_admin(id))
		Rank = MAX_RANK
	
	if(Hours < 5)
		Rank = 1
	else if(Hours <= 10)
		Rank = 2
	else if(Hours <= 20)
		Rank = 3
	else if(Hours <= 30)
		Rank = 4
	else if(Hours <= 40)
		Rank = 5
	else if(Hours <= 50)
		Rank = 6
	else if(Hours <= 60)
		Rank = 7
	else if(Hours <= 70)
		Rank = 8
	else
		Rank = 0
		
	return Rank
}

GetTotalHours(const id)
{
	new const TotalTime = (get_user_time(id) + g_UserTime[id])
	new TotalHours = (TotalTime / 3600)
	
	return TotalHours
}

// Level based off of Frags
// This is cheap, and fake, it won't really do anything. But please people
GetLevel(const id)
{
	new const TotalFrags = (get_user_frags(id) + g_UserFrags[id])
	new Level
	
	switch(TotalFrags)
	{
		case 0..100: Level = 1
		case 101..200: Level = 2
		case 201..301: Level = 3
		case 302..400: Level = 4
		case 401..500: Level = 5
	}
	
	return Level
}

/*==================================================================================================================================================*/
public plugin_end()
{
	// Player data won't save on disconnect
	// Save it here.
	g_PluginEnd = 1
	
	new iPlayers[32],iNum
	get_players(iPlayers,iNum);
	
	for(new Count;Count < iNum;Count++)
		SaveUserData(iPlayers[Count]);
	
	nvault_close(g_Vault);
}
