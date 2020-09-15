////////////////////////////////////////////////////
// DZombie.sma
// --------------------------
// Zombie MOD for TS - Author: Drak
// This is kinda quick and dirty. I wasn't planning on releasing this, but I kept as much settings/configs un-hardcoded as possable
// The only thing that would be difficult to change is the max level of 30.
// -------------
// Some of the ideas / features are from stupok69's ZombieMOD for TS
// Don't accuse me of "stealing" or "copying" anybody. This was released free of charge, and he get's proper credit

#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <fakemeta_util>
#include <engine>
#include <nvault>
#include <hamsandwich>
#include <tse>

new const g_GameName[] = "TS Zombies"

new g_ZombieTeamName[33]
new g_HumanTeamName[33]

#define HUD_RED 45
#define HUD_GREEN 164
#define HUD_BLUE 232
#define HUD_X -1.0
#define HUD_Y 1.0

#define MAX_ZOMBIE_MODELS 5
#define MAX_ZOMBIE_HP 250
#define MAX_PLAYER_HP 250
#define MAX_ZOMBIE_SKILL 5.0
#define BOSS_ZOMBIE_SKILL 9.9

// End Settings

#define NUM_OF_PERKS 1
#define PW_HEALTHBOOST (1<<0)
#define PW_HEALTHREGEN (1<<2)

new g_PerkNeededLevel[NUM_OF_PERKS + 1]

new g_VaultFile
new g_Cache[256]
new g_MaxPlayers

// Player saved variables
new g_UserFrags[33]
new g_UserPerks[33]
new g_UserLoaded[33]
new g_UserWeaponID[33]
new g_UserShowMessage[33]
new g_UserWeapons[33][45]
new g_UserGodtime[33]

new const g_Time[4][33] =
{
	"Morning",
	"Noon",
	"Afternoon",
	"Midnight till morning"
}

new g_TimePeriod
new g_TimePeriodNum
new g_CurrentLightLevel

new const g_LightLookup[] = "abcdefghijklmnopqrstuvwxyz";

new g_BonusZombie
new g_MainMenu
new g_GunMenu

new g_ZombieModels[MAX_ZOMBIE_MODELS][33]
new g_ZombieModelsNum
new g_ZombieCount

new p_Zombies
new p_TimePeriod
new p_ClientZombies
new p_ZombieHealth
new p_ChangeLights
new p_BaseLights
new p_KnockBack
new p_PlayerHealth
new p_SpawnGodTime
new p_StartWeapon
new p_MonsterMod

// TS Weapons
enum
{
	TSW_KUNGFU,
	TSW_GLOCK18,
	TSW_BERETTA,
	TSW_UZI,
	TSW_M3,
	TSW_M4A1,
	TSW_MP5SD,
	TSW_MP5K,
	TSW_ABERETTA,
	TSW_MK23,
	TSW_AMK23,
	TSW_USAS,
	TSW_DEAGLE,
	TSW_AK47,
	TSW_57,
	TSW_AUG,
	TSW_AUZI,
	TSW_SKORPION,
	TSW_M82A1,
	TSW_MP7,
	TSW_SPAS,
	TSW_GCOLTS,
	TSW_GLOCK20,
	TSW_UMP,
	TSW_M61GRENADE,
	TSW_CKNIFE,
	TSW_MOSSBERG,
	TSW_M16A4,
	TSW_MK1,
	TSW_C4,
	TSW_A57,
	TSW_RBULL,
	TSW_M60E3,
	TSW_SAWED_OFF,
	TSW_KATANA,
	TSW_SKNIFE,
	TSW_G2,
	TSW_ASKORPION
}

#define TSX_MAX_WEAPONID 45

new const g_ZombieNoises[3][33] = 
{
	"nihilanth/nil_alone.wav",
	"nihilanth/nil_die.wav",
	"nihilanth/nil_comes.wav"
}

new g_ZombieTalkDelay
new g_Monsters[12][33]

public plugin_precache()
{
	g_VaultFile = nvault_open( "DZombieVault" );
	if(g_VaultFile == INVALID_HANDLE)
		error( "unable to open nvault file", true );
	
	g_MaxPlayers = get_maxplayers();
	
	for( new Count; Count < sizeof(g_ZombieNoises); Count++ )
		precache_sound(g_ZombieNoises[Count]);
	
	p_Zombies			= register_cvar( "dz_zombies", "50" );
	p_TimePeriod 		= register_cvar( "dz_phasetime","8");
	p_ClientZombies 	= register_cvar( "dz_allowclientzombies", "0" );
	p_ZombieHealth 		= register_cvar( "dz_zombiehp", "200" );
	p_PlayerHealth		= register_cvar( "dz_playerhp", "125" );
	p_ChangeLights 		= register_cvar( "dz_dynamiclights", "1" );
	p_BaseLights 		= register_cvar( "dz_baselight", "0" ); 		// 1 = darkest, 25 = brightest
	p_KnockBack 		= register_cvar( "dz_knockforce", "8500" );
	p_SpawnGodTime		= register_cvar( "dz_postspawngod", "5" );
	p_StartWeapon		= register_cvar( "dz_startwpn", "22" );
	p_MonsterMod		= register_cvar( "dz_monstermod", "zombie headcrab" );

	hook_cvar_change( p_BaseLights, "cvar_baseLightsChanged" );
	
	// This isn't the best idea. But it helps solves some issues 
	// Such as settings CVars in-time.
	// The correct way of doing this is to read the file ourselves. But that's not needed
	get_cvar_string( "servercfgfile", g_Cache, 255 );
	
	server_cmd( "exec %s", g_Cache );
	server_exec();
	
	if( get_cvar_num( "mp_teamplay" ) == 0 ) {
		error( "server does not have mp_teamplay = 1, please set and restart", true );
	}

	new leftTeam[33];
	new rightTeam[33];

	get_cvar_string( "mp_teamlist", g_Cache, 255 );
	strtok( g_Cache, leftTeam, 32, rightTeam, 32, ';' );

	if( containi( rightTeam, "zombies" ) == -1 ) {
		formatex( g_Cache, 255, "did not find the team name ^"Zombies^" in ^"mp_teamlist^"\nThe Zombies team MUST be located as the second team only\nSecond team found as: ", rightTeam );
		set_fail_state( g_Cache );
	} else {
		copy( g_ZombieTeamName, 32, rightTeam );
		copy( g_HumanTeamName, 32, leftTeam );
		server_print( "[DZ] Found teams. Human '%s' and Zombie '%s'", g_HumanTeamName, g_ZombieTeamName );
	}
	
	// Filling the zombie models
	// Hopfully like the info says, the team for the zombies is team two, so the model list, will be to the right

	get_cvar_string( "mp_teammodels", g_Cache, 255 );
	strtok( g_Cache, g_Cache, 255, g_Cache, 255, '|' );

	// loop each char, building the zombie model
	new index = 0;
	new modelIndex = 0;
	new modelCount = 0;

	while( g_Cache[index] )
	{
		if( g_Cache[index] == ';' )
		{
			modelCount++
			modelIndex = 0
			index++;
			continue
		}
		
		g_ZombieModels[modelCount][modelIndex] = g_Cache[index];
		
		modelIndex++
		index++;
	}
	g_ZombieModelsNum = modelCount;

	// send the models to the clients
	for( new Count; Count <= g_ZombieModelsNum; Count++)
	{
		formatex( g_Cache, 255, "models/player/%s/%s.mdl", g_ZombieModels[Count], g_ZombieModels[Count] );
		precache_model( g_Cache );
	}

	//
	get_pcvar_string( p_MonsterMod, g_Cache, 255 );
	if( g_Cache[0] )
	{
		new index = 0;
		new count = 0
		new monster[33]

		while( index != - 1 )
		{
			index = argparse( g_Cache, index, monster, 32 );
			if( monster[0] ) 
				copy(g_Monsters[count++], 32, monster );
		}
	}
}

public plugin_init()
{
	// Main
	register_plugin( "TS Zombies (DZombies)", "1.0", "TJ" );
	
	// Events
	register_event( "DeathMsg", "Event_DeathMSG", "a" );
	register_event( "ResetHUD", "Event_ResetHUD", "b" );
	register_event( "WeaponInfo", "Event_WeaponInfo", "b" );
	register_message( 50, "Message_TS50" );

	//register_forward( FM_SetClientMaxspeed,  "fwd_SetClientMaxspeed" );
	register_forward( FM_GetGameDescription, "fwd_GetGameDescription" );
	
	// Used for player spawning
	RegisterHam( Ham_Spawn, "player", "Event_PlayerSpawn", 1 );
	
	// Commands
	register_concmd( "dz_removebot", "cmdRemoveBot", ADMIN_BAN, "removes a zombie bot from the server" );
	register_concmd( "dz_addbot", "cmdAddBot", ADMIN_BAN, "adds a zombie bot to the server" );
	//register_srvcmd("DZ_PerkLevel","CmdUpdatePerk",_,"<perk> <level> - set's what level you need to be (or higher) to have this perk");
	//register_concmd("DZ_PerkLevel","CmdUpdatePerk",_,"<perk> <level> - set's what level you need to be (or higher) to have this perk");
	//register_srvcmd("DZ_AddBot","CmdAddBot",_,"- adds a bot to the zombie team. use this instead of ^"addbot^"");
	
	// Client Commands
	register_clcmd("say","CmdSay");
	register_clcmd("say /menu","CmdMenu",_,"- shows the main zombie menu");
	
	// Menus
	g_MainMenu = menu_create("DZombieMOD Main Menu","_DMainMenu");
	menu_additem(g_MainMenu,"View my Perks");
	menu_additem(g_MainMenu,"Guns");
	menu_additem(g_MainMenu,"Help");
	
	g_GunMenu = menu_create("[GunMenu]^nYou can hold more guns^nthe higher level you are^n^nPage:","_DGunMenu");
	menu_additem( g_GunMenu, "Last Used Weapons" );
	menu_additem( g_GunMenu, "Glock18" );
	menu_additem( g_GunMenu, "Glock20" );
	menu_additem( g_GunMenu, "Five-Seven" );
	menu_additem( g_GunMenu, "Deagle" );
	menu_additem( g_GunMenu, "RagingBull" );
	menu_additem( g_GunMenu, "CKnife" );
	menu_additem( g_GunMenu, "Katana" );
	menu_additem( g_GunMenu, "Mossberg" );
	menu_additem( g_GunMenu, "Sawed Off" );
	menu_additem( g_GunMenu, "M3" );
	menu_additem( g_GunMenu, "MP7" );
	
	// Tasks
	set_task(1.0,"HUDTask",_,_,_,"b");

	// Lighting bug fix
	server_cmd( "sv_skycolor_r 0;sv_skycolor_g 0;sv_skycolor_b 0" );
	server_exec();

	g_CurrentLightLevel = get_pcvar_num( p_BaseLights );
}

public fwd_GetGameDescription()
{
	forward_return( FMV_STRING, g_GameName );
	return FMRES_SUPERCEDE
}

public cvar_baseLightsChanged( pcvar, const oldValue[], const newValue[] )
{
	new intLevel = 0;
	intLevel = str_to_num( newValue );

	if( intLevel <= 0 || intLevel >= 26 ) {
		set_lights( "#OFF" );
		notify( 0, "[DZ] Baselights have been reset to the default" );
		g_CurrentLightLevel = 0
	} else {
		new letter[2]
		formatex( letter, 1, "%c", g_LightLookup[ intLevel ] );

		set_lights( letter );
		g_CurrentLightLevel = intLevel

		notify( 0, "[DZ] Baselights have been updated to %i/26", intLevel );
	}
}
// --------------------------------------------------------------------------------------
// Commands

public CmdMenu(id)
	return menu_display(id,g_MainMenu);

public CmdSay(id)
{
	if(!is_user_alive(id))
		return PLUGIN_CONTINUE
	
	static Args[256]
	read_args(Args,255);
	
	remove_quotes(Args);
	trim(Args);
	
	if(equali(Args,"/guns",5))
	{
		new WeaponName[33]
		parse(Args,Args,255,WeaponName,32);
		
		if(!WeaponName[0])
		{
			client_print(id,print_chat,"[DZ] You can also type: /guns <gun here> ie: /guns glock18 - to spawn a weapon");
			menu_display(id,g_GunMenu);
			return PLUGIN_HANDLED
		}
		
		switch(WeaponName[0])
		{
			case 'a': ts_giveweaponspawn(id,TSW_AK47,100);
			case 'g':
			{
				if(containi(WeaponName,"18") != -1)
					ts_giveweaponspawn(id,TSW_GLOCK18,100);
				else if(containi(WeaponName,"20") != -1)
					ts_giveweaponspawn(id,TSW_GLOCK20,100);
			}
			case 'f': ts_giveweaponspawn(id,TSW_57,100);
			case '5': ts_giveweaponspawn(id,TSW_57,100);
			case 'r': ts_giveweaponspawn(id,TSW_RBULL,100);
			case 'k': 
			{
				if(containi(WeaponName,"knife") != -1)
					ts_giveweaponspawn(id,TSW_SKNIFE,100);
				else
					ts_giveweaponspawn(id,TSW_KATANA,100);
			}
			case 'm':
			{
				if(containi(WeaponName,"M3") != -1)
					ts_giveweaponspawn(id,TSW_M3,100);
				else if(containi(WeaponName,"MP7") != -1)
					ts_giveweaponspawn(id,TSW_MP7,100);
				else if(containi(WeaponName,"MP5") != -1)
					ts_giveweaponspawn(id,TSW_MP5SD,100)
				else if(containi(WeaponName,"M4") != -1)
					ts_giveweaponspawn(id,TSW_M4A1,100)
				else if(containi(WeaponName,"M16") != -1)
					ts_giveweaponspawn(id,TSW_M16A4,100)
			}
			case 's':
			{
				if(containi(WeaponName,"skorp") != -1)
					ts_giveweaponspawn(id,TSW_SKORPION,100);
				else
					ts_giveweaponspawn(id,TSW_SAWED_OFF,100);
			}
			default:
				client_print(id,print_chat,"[DZ] Sorry, unable to find that weapon.");
		}
		
		return PLUGIN_HANDLED
	}
	
	return PLUGIN_CONTINUE
}

public _DMainMenu(id,Menu,Item)
{
	if(Item == MENU_EXIT || !is_user_alive(id))
		return PLUGIN_HANDLED
	
	switch(Item)
	{
		case 0:
		{
			g_Cache[0] = 0
			
			add(g_Cache,255,"This is the list of your enabled perks:^n");
			add(g_Cache,255,"You will gain more perks, the more kills you have.");
			
			show_motd(id,g_Cache,"Your Perks");
		}
		case 1:
		{
			menu_display(id,g_GunMenu);
			client_print(id,print_chat,"[DZ] You can access this menu by: /guns");
		}
		case 3:
			show_motd(id,"zombie_motd.txt");
	}
	
	return PLUGIN_HANDLED
}

public _DGunMenu(id,Menu,Item)
{
	if(Item == MENU_EXIT)
		return PLUGIN_HANDLED
	
	switch(Item)
	{
		case 0: ts_giveweaponspawn(id,TSW_GLOCK18,100);
		case 1: ts_giveweaponspawn(id,TSW_GLOCK20,100);
		case 2: ts_giveweaponspawn(id,TSW_57,100);
		case 3: ts_giveweaponspawn(id,TSW_RBULL,100);
		case 4: ts_giveweaponspawn(id,TSW_CKNIFE,100);
		case 5: ts_giveweaponspawn(id,TSW_KATANA,100);
		case 6: ts_giveweaponspawn(id,TSW_MOSSBERG,100);
		case 7: ts_giveweaponspawn(id,TSW_SAWED_OFF,100);
		case 8: ts_giveweaponspawn(id,TSW_M3,100);
		case 9: ts_giveweaponspawn(id,TSW_MP7,100);
		case 10: ts_giveweaponspawn(id,TSW_SKORPION,100);
		case 11: ts_giveweaponspawn(id,TSW_MP5SD,100);
		case 12: ts_giveweaponspawn(id,TSW_M4A1,100);
		case 13: ts_giveweaponspawn(id,TSW_AK47,100);
		case 14: ts_giveweaponspawn(id,TSW_M16A4,100);
	}
	
	return PLUGIN_HANDLED
}

public CmdUpdatePerk(id,level,cid)
{
	new bool:ServerCommand = bool:is_dedicated_server();
	if(!ServerCommand && !cmd_access(id,level,cid,2))
		return PLUGIN_HANDLED
	
	new Arg[33],Arg2[12]
	read_argv(1,Arg,32);
	read_argv(2,Arg2,11);
	
	new PerkLevel = clamp(str_to_num(Arg2),0,30);
	
	switch(Arg[0])
	{
		case 'h':
		{
			g_PerkNeededLevel[PW_HEALTHBOOST] = PerkLevel
			ServerCommand ? 
				server_print("[DZombie] Updated ^"Health Boost^" perk. Level needed to activate: %s",Arg2) : console_print(id,"[DZombie] Updated ^"Health Boost^" perk. Level needed to activate: %s",Arg2);
		}
		default:
		{
			ServerCommand ? 
				server_print("[DZombie] Invalid Perk. Perk names:") : console_print(id,"[DZ] Invalid Perk. Perk names:");
				
			return PLUGIN_HANDLED
		}
	}
	
	return PLUGIN_HANDLED
}			
public cmdAddBot( id, level, cid )
{
	new bool:ServerCommand = bool:is_dedicated_server();
	
	if( !ServerCommand && !cmd_access( id, level, cid, 2 ) )
		return PLUGIN_HANDLED
	
	set_task( 2.0, "addBotPlayer" );
}

public cmdRemoveBot( id, level, cid )
{
	new bool:ServerCommand = bool:is_dedicated_server();
	
	if( !ServerCommand && !cmd_access( id, level, cid, 2 ) )
		return PLUGIN_HANDLED

	removeBotPlayer( getRandomBot() );
}

public addBotPlayer()
{
	notify( 0, "[DZ] Adding zombie to server" );
	server_cmd( "addcustombot Zombie %s %f", g_ZombieTeamName, random_float( 1.0, MAX_ZOMBIE_SKILL ) );
}

public removeBotPlayer(idx)
{
	if( idx )
	{
		notify( 0, "[DZ] Removing zombie from server" );
		server_cmd( "kick #%i", get_user_userid( idx ) );
	}
}
// --------------------------------------------------------------------------------------
// I would rather not do this. But there isn't a better way to delay the load
// The nature of most mods, sometimes there steamid is still not valid in client_authorized();
public client_authorized(id)
{
	g_UserLoaded[id] = 0
	if(!is_user_bot(id))
		set_task(2.0,"DelayLoad",id);
}

public DelayLoad(id)
{
	if(!is_user_connected(id))
		return set_task(2.0,"DelayLoad",id);
	
	static AuthID[36]
	get_user_authid(id,AuthID,35);
	
	if(!CheckAuthID(AuthID))
		return error("Invalid SteamID on Connecting (%s)",_,AuthID);
	
	if(nvault_get(g_VaultFile,AuthID,g_Cache,255))
	{
		new szFrags[12]
		parse(g_Cache,szFrags,11);
		g_UserFrags[id] = str_to_num(szFrags);
	}
	
	g_UserLoaded[id] = 1
	set_task( 5.0, "fixLights" );
	
	return PLUGIN_HANDLED
}

public fixLights()
{
	// HACK!
	// Everytime a client joins, his light flags are going to be messed up. Reset engine light level to fix the "flashing" bug
	new letter[2]
	formatex( letter, 1, "%c", g_LightLookup[ g_CurrentLightLevel ] );

	if( g_CurrentLightLevel <= 0 || g_CurrentLightLevel >= 26 )
		set_lights( "#OFF" );
	else
		set_lights( letter );

	server_print( "[DZ] Applying lighting value of '%s' (%i)", letter, g_CurrentLightLevel );
}
public client_disconnected(id)
{
	g_UserLoaded[id] = 0
	g_UserShowMessage[id] = 0
	
	if(!is_user_bot(id) && is_user_connected(id))
		SaveUserData(id);
}

public client_infochanged(id)
{
	if(is_user_bot(id) || get_pcvar_num(p_ClientZombies))
		return PLUGIN_CONTINUE
	
	new Team[33]
	get_user_team(id,Team,32);
	
	if(equali(Team,g_ZombieTeamName))
	{
		client_cmd(id,"jointeam 1");
		client_print(id,print_chat,"[DZ] Client's are currently not allowed to join the zombie team.");
		return PLUGIN_HANDLED
	}
	
	return PLUGIN_CONTINUE
}

// --------------------------------------------------------------------------------------
// HUD
public HUDTask()
{
	populateBots();
	RenderHUD()
}

new botLastAddded = 0

populateBots()
{
	if( ( get_systime() - botLastAddded ) < 5.0 )
		return

	new humanPlayers = getHumanCount();
	new Float:numberOfZombies = ( g_MaxPlayers - humanPlayers ) * ( get_pcvar_num( p_Zombies ) * 0.01 )
	new num = floatround( numberOfZombies );

	if( num > g_ZombieCount )
	{
		botLastAddded = get_systime();
		set_task( 2.0, "addBotPlayer" )
	}

	if( ( g_ZombieCount + 1 )  > ( g_MaxPlayers - humanPlayers ) )
	{
		removeBotPlayer( getRandomBot() );
	}
}

RenderHUD()
{
	if(++g_TimePeriodNum >= (get_pcvar_num(p_TimePeriod) * 60))
	{
		new LightLevel = get_pcvar_num(p_ChangeLights);
		switch(++g_TimePeriod)
		{
			case 1:
			{			
				if(LightLevel) { 
				set_lights("h") 
				g_CurrentLightLevel = 8 
				}
			}
			case 2: 
			{
				if(LightLevel) { 
					set_lights("f") 
					g_CurrentLightLevel = 6 
				}
			}
			case 3:
			{
				// Latest time. Bonus Zombie
				if(LightLevel)
				{					
					set_lights("c");
					g_CurrentLightLevel = 3
				}
				
				//g_BonusZombie = GetRandomBot();
				
				if(g_BonusZombie)
				{
					// Give the zombie perks (removed upon death)
				}
			}
			
			// Reset
			default: 
			{
				g_TimePeriod = 0
				set_lights("#OFF");
			}
		}
		g_TimePeriodNum = 0
	}
	
	new TalkingZombies
	
	if(++g_ZombieTalkDelay > 30)
	{
		TalkingZombies = 1
		g_ZombieTalkDelay = 0
	}
	
	new idx,Float:UserHealth
	new ZombieName[33]
	
	if(g_BonusZombie)
		get_user_name(g_BonusZombie,ZombieName,32);
	
	static team[33]
	g_ZombieCount = 0

	for( idx = 0; idx <= g_MaxPlayers; idx++ )
	{
		if( !is_user_connected( idx ) )
			continue

		// dirty way of counting how many "zombies" exist on the server
		// counts both bots and clients
		get_user_team( idx, team, 32 );
		
		if( equali( team, g_ZombieTeamName ) )
			g_ZombieCount++

		if(!is_user_alive(idx))
			continue

		// Godmode handling
		if( g_UserGodtime[idx] > 0 )
		{
			new curTime = get_systime();
			client_print( idx, print_chat, "[DZ] Spawn Invincibility Ending %i secs...", ( g_UserGodtime[idx] - curTime ) );
			
			if( g_UserGodtime[idx] - curTime <= 0 ) {
				fm_set_user_godmode( idx, 0 );
				g_UserGodtime[idx] = 0
			}
		}
		
		// Bot Origin Fixing
		// HACK HACK:
		// When they're Z origin is less then 450 (or higher since we use abs()) they are in the sewer / fell under the map, so we fix there origin
		if(is_user_bot( idx ))
		{
			new Origin[3]
			get_user_origin(idx,Origin);
			
			if(abs(Origin[2]) > 450)
				FixZombieLocation(idx,200.0);
			
			if(TalkingZombies)
				emit_sound(idx,CHAN_AUTO,g_ZombieNoises[random(sizeof(g_ZombieNoises))],VOL_NORM,ATTN_NORM,0,PITCH_NORM);
			
			//if(random(100) < 15)
			//	FixZombieLocation(idx,200.0);
			
			continue
		}
		
		UserHealth = entity_get_float(idx,EV_FL_health);
		if(UserHealth < 100.0)
			entity_set_float(idx,EV_FL_health,UserHealth + 1.0);

		if( random( 50 ) > 35 && g_TimePeriod >= 3 ) {
			new ply = getRandomHuman();
			if( ply && is_user_alive( ply ) == true )
			{
				new name[33]
				get_user_name( ply, name, 32 );

				server_cmd( "monster headcrab %s", name )
				server_print( "[TS Zombies] Spawning a MonsterMod entity.." );
			}
		}
		
		set_hudmessage(HUD_RED,HUD_GREEN,HUD_BLUE,HUD_X,HUD_Y,_,_,99.0,_,_,1);
		
		formatex(g_Cache,255,"Zombies Killed: %d - Level: %d/%d - Phase: %s",
			g_UserFrags[idx],FragsToLevel(idx),30,g_Time[g_TimePeriod]);
		
		show_hudmessage(idx,g_Cache);
	}
}

// --------------------------------------------------------------------------------------
public Message_TS50(msg_id,msg_dest,msg_entity)
{
	static victim, attacker, Float:aimvelocity[3]
	
	victim = get_msg_arg_int(2);
	attacker = get_msg_arg_int(3);
	
	if(!is_user_alive(attacker) || !is_user_bot(victim))
		return PLUGIN_HANDLED
	
	switch(g_UserWeaponID[attacker])
	{
		case TSW_KUNGFU:
			return PLUGIN_HANDLED
			
		case TSW_MOSSBERG, TSW_SAWED_OFF, TSW_M3, TSW_SPAS, TSW_USAS:
		{
			velocity_by_aim(attacker,get_pcvar_num(p_KnockBack),aimvelocity);
			entity_set_vector(victim,EV_VEC_velocity,aimvelocity);
		}
		default:
		{
			velocity_by_aim(attacker,get_pcvar_num(p_KnockBack) / 3,aimvelocity);
			entity_set_vector(victim,EV_VEC_velocity,aimvelocity);
		}
	}
	
	return PLUGIN_HANDLED
}
// NOTE NOTE NOTE:
// This does not take in-account for kills on "client" zombies.
// Todo so, you would have to use "get_user_team" and see if the victim was on g_ZombieTeamName[]
// I'm not going todo that, but just letting anybody else know.
public Event_DeathMSG()
{
	// Used for:
	// Actual frag count
	new const Killer = read_data(1),Victim = read_data(2);
	new const IsBotVictim = is_user_bot(Victim);
	
	if(is_user_connected(Killer) && IsBotVictim)
		g_UserFrags[Killer]++
	
	if(IsBotVictim)
	{
		// Zombie death
	}
}

// ResetHUD takes care of bots (as Ham_Spawn isn't called for them)
public Event_ResetHUD(id)
{
	if(!is_user_alive(id))
		return PLUGIN_HANDLED

	static teamName[33]
	get_user_team( id, teamName, 32 );
	
	if( equali( teamName, g_ZombieTeamName ) )
	{
		new Float:pZombieHealth = get_pcvar_float(p_ZombieHealth);
		
		if( pZombieHealth > 0 && p_ZombieHealth <= MAX_ZOMBIE_HP )
			entity_set_float( id, EV_FL_health, pZombieHealth );
		
		// Model settings
		set_task(2.0,"DelayModelChange");
	}
	
	return PLUGIN_HANDLED
}

public DelayModelChange(id)
{
	engclient_cmd(id,"model",g_ZombieModels[random(g_ZombieModelsNum + 1)]);
	return PLUGIN_HANDLED
}

public Event_PlayerSpawn(id)
{
	if(!is_user_alive(id))
		return HAM_HANDLED
	
	client_infochanged(id);

	new Float:playerStartHealth = get_pcvar_float(p_PlayerHealth);

	if( playerStartHealth > 0 && playerStartHealth <= MAX_PLAYER_HP )
		entity_set_float( id, EV_FL_health, playerStartHealth );
	
	if(!g_UserShowMessage[id])
	{
		client_print(id,print_chat,"[DZ] You can access the main menu by: /menu");
		g_UserShowMessage[id] = 1
	}

	// HP Boost Perk
	if(g_UserPerks[id] & PW_HEALTHBOOST)
	{
		new Float:Health
		
		switch(FragsToLevel(id))
		{
			case 0..5: Health = 5.0
			case 6..10: Health = 15.0
			case 11..18: Health = 20.0
			default: Health = 50.0
		}
		
		entity_set_float(id,EV_FL_health,entity_get_float(id,EV_FL_health) + Health);
		client_print(id,print_chat,"[DZ] Your health boost is currently at: +%d",floatround(Health));
	}

	new godTime = get_pcvar_num( p_SpawnGodTime );
	if( godTime > 0 )
	{
		g_UserGodtime[id] = godTime + get_systime();
		new idData[1]

		idData[0] = id
		fm_set_user_godmode( id, 1 );

		//set_task( float( godTime ), "clearGodmode", random(200) + id, idData, 1 );
	}

	new startWeapon = get_pcvar_num( p_StartWeapon );
	if( startWeapon > 0 && startWeapon <= TSX_MAX_WEAPONID )
	{
		tse_giveuserweap( id, startWeapon, 1000, TSE_ATM_LASERSIGHT + TSE_ATM_FLASHLIGHT );
	}
	
	return HAM_IGNORED
}

public clearGodmode( const idData[])
{
	new id = idData[0]
	if( id && is_user_connected( id ) )
	{
		fm_set_user_godmode( id, 0 );
	}
}

// Forces weapons to be dropped if you're on the zombie team
public Event_WeaponInfo(id)
{
	static TeamName[23]
	get_user_team(id,TeamName,22);
	
	g_UserWeaponID[id] = read_data(1);
	
	if(equali(TeamName,g_ZombieTeamName))
	{
		if(is_user_bot(id))
			set_task(0.5,"DelayWeaponDrop",id);
		else
			console_cmd(id,"drop");
	}
}

public DelayWeaponDrop(id)
	engclient_cmd(id,"drop");

// --------------------------------------------------------------------------------------


// Will save everybody's data to the vault file.
// This needs to be profiled, to see how often I should call it
SaveAllUserData()
{
	new Count
	for(Count = 0;Count <= g_MaxPlayers;Count++)
	{
		if(!is_user_connected(Count) || is_user_bot(Count))
			continue;
		
		SaveUserData(Count);
	}
}

SaveUserData(const id)
{
	static AuthID[36]
	get_user_authid(id,AuthID,35);
	
	if(CheckAuthID(AuthID))
	{
		formatex(g_Cache,255,"%d",g_UserFrags[id]);
		nvault_set(g_VaultFile,AuthID,g_Cache);
	}
	else
		error("Saved User Data, with Invalid AuthID (%s)",_,AuthID);
}

bool:CheckAuthID(const AuthID[])
{
	if(!AuthID[0])
		return false
	
	if(containi(AuthID,"PENDING") != -1 || containi(AuthID,"") != -1)
		return false
	
	return true
}

// Hard-coded level / max level
// You can change the amount of frags for each level (they need x frags for x level)
// You change what addons/powers/perks they get with a cvar
FragsToLevel(id)
{
	new Level
	
	switch(g_UserFrags[id])
	{
		default: Level = 30
	}
	
	return Level;
}

AddPerk(id,Perk)
	g_UserPerks[id] |= Perk
RemovePerk(id,Perk,All=0)
{
	if(All)
		g_UserPerks[id] = 0
	else
		g_UserPerks[id] = (g_UserPerks[id] & ~Perk)
}

error( const reason[], bool:fatal=false, any:... )
{
	if( reason[0] )
	{
		vformat( g_Cache, 255, reason, 3 );
		log_amx( "Error called: Reason: %s - Fatal: %s", g_Cache, fatal ? "Yes" : "No" );
	}
	if( fatal )
	{
		nvault_close( g_VaultFile );
		set_fail_state( reason );
	}
	
	return PLUGIN_HANDLED
}

notify( id, const message[], any:... )
{
	vformat( g_Cache, 255, message, 3 );
	client_print( id, print_chat, g_Cache );
	log_amx( g_Cache );
}

getRandomBot()
{
	if(!get_playersnum())
		return 0

	new players[MAX_PLAYERS]
	new playerIndex

	get_players( players, playerIndex, "de", g_ZombieTeamName );

	if( playerIndex < 1 )
		return 0

	return players[random( playerIndex )]
}

getRandomHuman()
{
	if(!get_playersnum())
		return 0

	new players[MAX_PLAYERS]
	new playerIndex

	get_players( players, playerIndex, "c" );

	if( playerIndex < 1 )
		return 0

	return players[random( playerIndex )]
}

getHumanCount()
{
	static players[MAX_PLAYERS]

	new humanCount = 0
	get_players( players, humanCount, "c" );

	return humanCount
}

// Hawk
// Will be used to teleport "stuck" zombies to a random location
// They will attempt to teleport to players, if that fails x amount of times, they go back to the spawn point
FixZombieLocation(ZombieID,Float:Radius,Reset=0)
{
	if(!is_user_bot(ZombieID) || !is_user_alive(ZombieID))
		return 0
	
	static Num
	static Ent
	static RandomPlayer
	static Float:pOrigin[3]
	
	if(++Num > 10 || Reset)
	{
		Num = 0
		RandomPlayer = 0
		
		pOrigin[0] = 0.0
		Ent = -1
		
		return 0
	}
	
	if(!RandomPlayer)
		RandomPlayer = getRandomHuman();
	
	if(!RandomPlayer)
	{
		while((Ent = find_ent_by_class(Ent,"info_player_deathmatch")) != 0)
		{
			entity_get_vector(Ent,EV_VEC_origin,pOrigin);
			if(PointContents(pOrigin) != CONTENTS_EMPTY && PointContents(pOrigin) != CONTENTS_SKY)
				return FixZombieLocation(ZombieID,Radius);
			
			entity_set_vector(ZombieID,EV_VEC_origin,pOrigin);
			FixZombieLocation(ZombieID,Radius,1);
			break
		}
		
		return FixZombieLocation(ZombieID,Radius,1);
	}
	
	if(!is_user_alive(RandomPlayer))
		return FixZombieLocation(ZombieID,Radius,1);
	
	if(!pOrigin[0])
		entity_get_vector(RandomPlayer,EV_VEC_origin,pOrigin);
	
	for(new Count;Count < 2;Count++)
		pOrigin[Count] += random_float(-Radius,Radius);
	
	if(PointContents(pOrigin) != CONTENTS_EMPTY && PointContents(pOrigin) != CONTENTS_SKY)
		return FixZombieLocation(ZombieID,Radius)
	
	entity_set_vector(ZombieID,EV_VEC_origin,pOrigin);
	return FixZombieLocation(ZombieID,Radius,1);
}

TS_GetUserSlots(const id)
{
	if(!id)
		return 0
	
	return get_pdata_int(id,333);
}

TS_SetUserSlots(const id,const Slots)
{
	if(!id || Slots < 0 || Slots > 100)
		return 0
	
	set_pdata_int(id,333,Slots);
	set_pdata_int(id,334,Slots);
	
	// Update HUD
	message_begin(MSG_ONE_UNRELIABLE,get_user_msgid("TSSpace"),_,id);
	write_byte(Slots);
	message_end();
	
	return 1
}

/*==================================================================================================================================================*/
// Functions below are copied from "fakemeta_util" by VEN
ts_giveweaponspawn(id,const WeaponID,const ExtraClip)
{
	g_UserWeapons[id][WeaponID]=1
	tse_giveuserweap(id, WeaponID, ExtraClip );
	/*
	new ent = engfunc(EngFunc_CreateNamedEntity,engfunc(EngFunc_AllocString,"ts_groundweapon"))
	if(!ent)
		return PLUGIN_CONTINUE
	
	new WeaponIDSZ[12]
	num_to_str(WeaponID,WeaponIDSZ,11);
	
	new ExtraClipSZ[12]
	num_to_str(ExtraClip,ExtraClipSZ,11);
	
	fm_set_kvd(ent,"tsweaponid",WeaponIDSZ,"ts_groundweapon");
	fm_set_kvd(ent,"wextraclip",ExtraClipSZ,"ts_groundweapon");
	fm_set_kvd(ent,"spawnflags","2","ts_groundweapon");
	
	dllfunc(DLLFunc_Spawn,ent);
	dllfunc(DLLFunc_Use,ent,id);
	
	engfunc(EngFunc_RemoveEntity,ent);

	new wep[32]
	new num = 0;

	get_user_weapons(id, wep, num);

	server_print("WEAPONS: %d", wep );
	return ent
	*/
}
public plugin_end()
	nvault_close(g_VaultFile)