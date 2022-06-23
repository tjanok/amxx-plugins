////////////////////////////////////////////////////
// DZombieMod.sma
// --------------------------

#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <fakemeta_util>
#include <engine>
#include <nvault>
#include <hamsandwich>
#include <tsfun>

new const g_GameName[] = "TS Zombies"
new const g_Version[] = "0.1"
new const g_ModName[] = "DZombies"

new g_ZombieTeamName[33]
new g_HumanTeamName[33]

#define MAX_ZOMBIE_MODELS 5
#define MAX_ZOMBIE_HP 250
#define MAX_PLAYER_HP 250
#define MAX_LEVEL 100

// Perks
// -----------------------------------------------------
#define NUM_OF_PERKS 3
#define PW_HEALTHBOOST (1<<0)
#define PW_HEALTHREGEN (1<<2)
#define PW_NIGHTVISION (1<<4)

new const g_PerkNames[NUM_OF_PERKS][64] = {
	"Health Boost Level 1",
	"Health Regeneration Level 1",
	"Nightvision"
}

new const g_PerkNamesId[NUM_OF_PERKS][33] = {
	"hp_boost1",
	"hp_regen1",
	"nvision"
}
// -----------------------------------------------------

new g_VaultFile

new g_Cache[256]
new g_MaxPlayers

// Player saved variables
//new g_UserFrags[33]
new g_UserPerks[33]
new g_UserLoaded[33]
new g_UserWeaponID[33]
new g_UserShowMessage[33]
new g_UserWeapons[33][45]
new g_UserGodtime[33]
new g_UserPlayTime[33]

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

// Menus
new g_MainMenu
new g_GunMenu
new g_SpawnMenu

new g_ZombieModels[MAX_ZOMBIE_MODELS][33]
new g_ZombieModelsNum
new g_ZombieCount
new g_HumanBotCount

// ConVars
new p_Zombies
new p_Humans
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
new p_MonsterModEnabled
new p_MaxSelectPerks
new p_MaximumFrags
new p_HudColorR
new p_HudColorG
new p_HudColorB
new p_HudPosX
new p_HudPosY

// Game Messages
new g_msgScreenFade

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

#define TSX_MAX_WEAPONID 37
new gWeaponNames[TSX_MAX_WEAPONID][] = {
	"Glock 18",
	"Beretta 92F",
	"Uzi",
	"M3",
	"M4A1",
	"MP5D",
	"MP5K",
	"Akimbo Beretta",
	"MK23",
	"Akimbo MK23",
	"USAS",
	"Degale",
	"AK47",
	"Five-Seven",
	"Aug",
	"Akimbo Uzi",
	"Skorpion",
	"M82A1 Sniper",
	"MP7",
	"Spas",
	"Golden Colts",
	"Glock 20",
	"UMP",
	"M61 Grenade",
	"Combat Knife",
	"Mossberg",
	"M16A4",
	"MK1 Ruger",
	"C4",
	"A57",
	"Raging Bull Revolver",
	"M60E3",
	"Sawed Off",
	"Katana",
	"Seal Knife",
	"Contender",
	"Akimbo Skorpion"
}

new gWeaponRequiredLevel[TSX_MAX_WEAPONID]

new const g_ZombieNoises[3][33] = 
{
	"sound/nihilanth/nil_alone.wav",
	"sound/nihilanth/nil_die.wav",
	"sound/nihilanth/nil_comes.wav"
}

new const g_ZombieNoisesEmitting[3][33] = 
{
	"nihilanth/nil_alone.wav",
	"nihilanth/nil_die.wav",
	"nihilanth/nil_comes.wav"
}

new g_ZombieTalkDelay

// when did a zombie last seen a player (used to "unstick" bots)
new Float:g_ZombieLastSeenPlayer[33]

new g_Monsters[12][33]
new g_MonstersCount

loadWeaponLevels( const file[] )
{
	new f = fopen( file, "r" );
	if( !f )
		return

	new index = 0

	while( !feof( f ) )
	{
		fgets( f, g_Cache, sizeof( g_Cache ) - 1 );

		if( g_Cache[0] == '/' || !g_Cache[0] )
			continue

		if( containi( g_Cache, gWeaponNames[index] ) ) {
			new weaponName[33], weaponLevel[3]
			parse( g_Cache, weaponName, 32, weaponLevel, 2 );

			if( !weaponName[0] || !weaponLevel[0] )
				continue

			new lvl = str_to_num( weaponLevel );
			gWeaponRequiredLevel[index] = lvl
			index++
		}
	}

	fclose( f );
}

public plugin_cfg()
{
	new configDir[256]
	get_datadir( configDir, 255 );
    
    new mapName[33]
    get_mapname( mapName, 32 );

    format( configDir, 255, "%s/dzombies", configDir );

    if( !dir_exists( configDir ) )
        mkdir( configDir );

    format( configDir, 255, "%s/weapon_levels.txt", configDir );

    if( !file_exists( configDir ) )
        error( "unable to locate weapon file '%s'", true, configDir );

	loadWeaponLevels( configDir );
	buildWeaponMenu();

	// Game Messages
	// Must be called here, or could return 0
	g_msgScreenFade = get_user_msgid( "ScreenFade" );
}

public plugin_precache()
{
	g_VaultFile = nvault_open( "DZombieVault" );
	if(g_VaultFile == INVALID_HANDLE)
		error( "unable to open nvault file, unable to continue", true );

	g_MaxPlayers = get_maxplayers();
	
	// precache_generic() instead - can't use emit_sound()
	for( new Count; Count < sizeof(g_ZombieNoises); Count++ )
	{
		formatex( g_Cache, sizeof( g_Cache ) - 1, "sounds/%s", g_ZombieNoises[Count] );
		precache_generic( g_Cache );
	}

	// precache_generic() instead - can't use emit_sound()
	for( new Count; Count < sizeof(g_ZombieNoisesEmitting); Count++ )
	{
		formatex( g_Cache, sizeof( g_Cache ) - 1, "sounds/%s", g_ZombieNoisesEmitting[Count] );
		precache_sound( g_Cache );
	}
	
	p_Zombies			= register_cvar( "dz_zombies", "50" );
	p_Humans			= register_cvar( "dz_humanbots", "5" );
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
	p_MonsterModEnabled = register_cvar( "dz_monstermod_enable", "0" );
	p_MaxSelectPerks 	= register_cvar( "dz_maxselectableperks", "-1" );
	p_MaximumFrags		= register_cvar( "dz_maxperkfrag", "50000" ); // How many frags do we need to reach max level
	p_HudColorR			= register_cvar( "dz_hudcolor_r", "45" );
	p_HudColorG			= register_cvar( "dz_hudcolor_g", "164" );
	p_HudColorB			= register_cvar( "dz_hudcolor_b", "232" );
	p_HudPosX			= register_cvar( "dz_hudcolor_x", "-1.0" );
	p_HudPosY			= register_cvar( "dz_hudcolor_y", "1.0" );

	hook_cvar_change( p_BaseLights, "cvar_baseLightsChanged" );
	
	// This isn't the best idea. But it helps solves some issues 
	// Such as settings CVars in-time.
	// The correct way of doing this is to read the file ourselves. But that's not needed
	get_cvar_string( "servercfgfile", g_Cache, 255 );
	
	server_cmd( "exec %s", g_Cache );
	server_exec();
	
	// won't work unless we are setup for teamplay
	if( get_cvar_num( "mp_teamplay" ) == 0 )
		error( "server does not have mp_teamplay = 1, please set and restart", true );

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
	// Hopfully like the info says, the team for the zombies is team two, so the model list will be to the right

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

	// MonsterMod Support
	// TODO: Check if metamod plugin is actually installed/running
	get_pcvar_string( p_MonsterMod, g_Cache, sizeof( g_Cache ) - 1 );
	if( g_Cache[0] )
	{
		new index = 0;
		new count = 0
		new monster[33]

		while( index != - 1 )
		{
			index = argparse( g_Cache, index, monster, 32 );
			if( monster[0] ) {
				copy(g_Monsters[g_MonstersCount++], 32, monster );
				notify( 0, "MonsterMod Monster '%s' loaded", monster );
			}
		}
	}
}

hasPerk( id, perkBit )
	return ( g_UserPerks[id] & perkBit )

buildPerkMenu( id )
{
	if( !is_user_connected( id ) )
		return

	new menu = menu_create( "Perks", "_HandlePerks" );
	for( new i = 0; i < NUM_OF_PERKS; i++ )
	{
		copy( g_Cache, sizeof( g_Cache ) - 1, g_PerkNames[i] );
		
		if( hasPerk(id, ( 1 << (i*2) ) ) )
			add( g_Cache, sizeof( g_Cache ) - 1, " *" );
		
		menu_additem( menu, g_Cache );
	}

	menu_display( id, menu );
}

buildWeaponMenu()
{
	if( g_GunMenu )
		menu_destroy( g_GunMenu );

	g_GunMenu = menu_create( "Weapons", "_DGunMenu" );

	for( new i = 0; i < TSX_MAX_WEAPONID; i++ )
	{
		if( gWeaponRequiredLevel[i] > MAX_LEVEL )
			error( "Required weapon level '%i' is over the max defined level '%i' Please fix and recompile",
				false, gWeaponRequiredLevel[i], MAX_LEVEL );

		// -1 = do not add this weapon
		if( gWeaponRequiredLevel[i] == -1 )
			continue

		new info[3]
		num_to_str( i+1, info, 2 );

		formatex( g_Cache, sizeof( g_Cache ) - 1, "%s (Req. Level %i)", 
			gWeaponNames[i], gWeaponRequiredLevel[i] );

		menu_additem( g_GunMenu, g_Cache, info );
	}
}

public server_changelevel( map[] )
	closeVaultFiles();

public plugin_init()
{
	// Main
	register_plugin( "TS Zombies (DZombies)", g_Version, "Trevor 'Drak' J" );
	
	// Events
	register_event( "ResetHUD", "Event_ResetHUD", "b" );
	register_event( "WeaponInfo", "Event_WeaponInfo", "b" );
	register_message( 50, "Message_TS50" );

	register_forward( FM_SetClientMaxspeed,  "fwd_SetClientMaxspeed" );
	register_forward( FM_GetGameDescription, "fwd_GetGameDescription" );
	
	// Used for player spawning
	RegisterHam( Ham_Spawn, "player", "Event_PlayerSpawn", 1 );
	
	// Commands
	register_concmd( "dz_removebot", "cmdRemoveBot", ADMIN_BAN, "removes a zombie bot from the server" );
	register_concmd( "dz_addbot", "cmdAddBot", ADMIN_BAN, "<human true/false> adds a human or zombie bot to the server" );
	register_concmd( "dz_setperklevel", "cmdSetPerkLevel" );
	register_concmd( "dz_reload", "cmdReloadFiles" );
	//register_srvcmd("DZ_PerkLevel","CmdUpdatePerk",_,"<perk> <level> - set's what level you need to be (or higher) to have this perk");
	//register_concmd("DZ_PerkLevel","CmdUpdatePerk",_,"<perk> <level> - set's what level you need to be (or higher) to have this perk");
	//register_srvcmd("DZ_AddBot","CmdAddBot",_,"- adds a bot to the zombie team. use this instead of ^"addbot^"");
	
	// Client Commands
	register_clcmd( "say", "CmdSay" );
	register_clcmd( "say /menu", "CmdMenu",_,"- shows the main zombie menu");
	register_clcmd( "say /dtest", "CmdTest" );
	
	// Menus
	g_MainMenu = menu_create( g_ModName, "_DMainMenu" );
	menu_additem( g_MainMenu, "Perks" );
	menu_additem( g_MainMenu, "Guns" );
	menu_additem( g_MainMenu, "View High Scores" );
	menu_additem( g_MainMenu, "Help" );
	
	// Tasks
	// Delay 60 seconds, make sure clients have joined and loaded
	set_task( 60.0, "beginGameLogic" );

	// Lighting bug fix
	server_cmd( "sv_skycolor_r 0;sv_skycolor_g 0;sv_skycolor_b 0" );
	server_exec();

	g_CurrentLightLevel = get_pcvar_num( p_BaseLights );

	new fragsPerMinute = 4
	new maxFrags = get_pcvar_num( p_MaximumFrags );
	error( "At %i frags per min, max level would take an estimated %ihrs, based on dz_maxperkfrag value of %i",
		false,
		fragsPerMinute,
		( maxFrags / fragsPerMinute ) / 60,
		maxFrags
	);
}

public beginGameLogic()
	set_task( 1.0, "MainGameTask",_,_,_,"b" );

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
			case 'a': ts_giveweaponspawn( id, TSW_AK47, 100 );
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
			buildPerkMenu( id );
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

public _DGunMenu( id, menu, item )
{
	if( item == MENU_EXIT )
		return PLUGIN_HANDLED

	new info[3]
	menu_item_getinfo( g_GunMenu, item, _, info, 2 );

	new wpnId = str_to_num( info );
	
	if( wpnId > 0 && wpnId <= TSX_MAX_WEAPONID )
		ts_giveweaponspawn( id, wpnId, 100, 0 );
	else
		notify( id, "[DZ] Unable to give selected weapon." );
	
	return PLUGIN_HANDLED
}

public _HandlePerkMenu( id, menu, item )
{
	if( item == MENU_EXIT )
		return menu_destroy( menu );

	switch( item )
	{
	}
}

getPerkRequiredLevel( id, const perkId[] )
{

}

getPerkIndex( id, const perk[] )
{
	new i = 0;
	for( i = 0; i < MAX_PERKS; i++ ) {
		if( equali( perk, g_PerkNamesId[i] ) || equali( perk, g_PerkNames[i] ) ) {
			return i
		}
	}
}

public cmdReloadFiles( id, level, cid )
{

}

public cmdSetPerkLevel( id, level, cid )
{
	new bool:ServerCommand = bool:is_dedicated_server();
	if( !ServerCommand && !cmd_access( id, level, cid, 2 ) )
		return PLUGIN_HANDLED
	
	new args[33]
	read_argv( 1, args, 32 );

	new perkId[33], perkLevel[3]
	copy( perkId, 32, args );

	read_argv( 2, args, 32 );
	copy( perkLevel, 2, args );

	if( str_to_num( args ) < 0 || str_to_num( args ) > MAX_LEVEL ) {
		notify( id, "Perk level '%s' must be between 0 - %i (max level)", perkLevel, MAX_LEVEL );
		return PLUGIN_HANDLED
	}

	// store level required for this perk inside vault
	formatex( g_Cache, sizeof( g_Cache ) - 1, "perk-%s", g_PerkNamesId[0] );
	nvault_set( g_VaultFile, g_Cache, perkLevel );
	
	return PLUGIN_HANDLED
}			
public cmdAddBot( id, level, cid )
{
	new bool:ServerCommand = bool:is_dedicated_server();
	
	if( !ServerCommand && !cmd_access( id, level, cid, 2 ) )
		return PLUGIN_HANDLED
	
	new isHuman[6]
	read_argv( 1, isHuman, 5 );

	if( ( strcmp( isHuman, "true", true ) == 0 ) || ( strcmp( isHuman, "1", true ) == 0 ) )
		formatex( isHuman, 5, "1" )
	else
		formatex( isHuman, 5, "0" );

	set_task( 2.0, "addBotPlayer", 0, isHuman, 5 );
}

public cmdRemoveBot( id, level, cid )
{
	new bool:ServerCommand = bool:is_dedicated_server();
	
	if( !ServerCommand && !cmd_access( id, level, cid, 2 ) )
		return PLUGIN_HANDLED

	removeBotPlayer( getRandomBot() );
}

public addBotPlayer( data[6] )
{
	new isHuman = str_to_num( data );
	if( isHuman == 0 )
	{
		notify( 0, "[DZ] Adding zombie bot to server" );
		server_cmd( "rcbot addbot 2 0 %s", g_ZombieTeamName );
	}
	else
	{
		notify( 0, "[DZ] Adding human bot to server" );
		server_cmd( "rcbot addbot 1 0 %s", g_HumanTeamName );
	}
}

removeBotPlayer( idx, bool:isHumanTeamBot = false )
{
	if( idx )
	{
		notify( 0, "[DZ] Removing %s from server", isHumanTeamBot == true ? "Human Bot" : "Zombie Bot" );
		server_cmd( "kick #%i", get_user_userid( idx ) );
	}
}
// --------------------------------------------------------------------------------------
getUserDataAsString( id, const key[], value[], valueLen )
{
	getUserData( id, key, "", true, value, valueLen )
}

getUserData( id, const key[], defaultReturn = 0, value[]="", &valueLen=0 )
{
	if( is_user_bot( id ) )
		return defaultReturn;

	static AuthID[36+12]
	get_user_authid(id, AuthID, 35);

	// is format faster?
	add( AuthID, sizeof( AuthID ) - 1, "-" );
	add( AuthID, sizeof( AuthID ) - 1, key );

	new timestamp
	new result = nvault_lookup( g_VaultFile, AuthID, g_Cache, sizeof( g_Cache ) - 1, timestamp );

	if( result ==  0 )
		return defaultReturn

	// nvault_get() internally uses a hashmap
	// this should be decently quick, i think?
	return nvault_get( g_VaultFile, AuthID );
}

setUserDataAsString( id, const key[], const value[] )
{
	setUserData( id, key, -1, value );
}
setUserData( id, const key[], intValue = -1, strValue[] = "" )
{
	if( is_user_bot( id ) )
		return;

	static AuthID[36+12]
	get_user_authid(id, AuthID, 35);

	// is format faster?
	add( AuthID, sizeof( AuthID ) - 1, "-" );
	add( AuthID, sizeof( AuthID ) - 1, key );

	// we always pass a string to nvault_set
	static val[12];
	if( intValue != -1 )
	{
		static val[12];
		num_to_str( intValue, val, 11 );

		formatex( g_Cache, sizeof( g_Cache ) - 1, "%s", val );
	}
	else
	{
		formatex( g_Cache, sizeof( g_Cache ) - 1, "%s", strValue );
	}

	nvault_set( g_VaultFile, AuthID, g_Cache );
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

public client_authorized( id, const authid[] )
{
	g_UserPlayTime[id] = getUserData( id, "playtime", 0 );
}

public client_disconnected(id)
{
	g_UserLoaded[id] = 0
	g_UserShowMessage[id] = 0

	// Log playtime
	setUserData( id, "playtime", g_UserPlayTime[id] + floatround( get_gametime() ) )
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

	// Update the player name for this steamid
	get_user_name( id, Team, 32 );
	//setUserData( id, "plname", Team );
	
	return PLUGIN_CONTINUE
}

// --------------------------------------------------------------------------------------
// Game Logic
public MainGameTask()
{
	populateZombies()
	populateHumanBots();
	drawHUD();
	handleLights();
}

new zombieLastAdded = 0

populateZombies()
{
	if( ( get_systime() - zombieLastAdded ) < 5.0 + random( 5 ) )
		return
	
	zombieLastAdded = get_systime();

	new humanPlayers = getHumanCount();
	new Float:numberOfZombies = ( g_MaxPlayers - humanPlayers ) * ( get_pcvar_num( p_Zombies ) * 0.01 )
	new num = floatround( numberOfZombies );

	if( num > g_ZombieCount )
	{
		set_task( 2.0, "addBotPlayer" )
	}

	if( ( g_ZombieCount + 1 )  > ( g_MaxPlayers - humanPlayers ) )
	{
		removeBotPlayer( getRandomBot() );
	}
}

new humanLastCheckTime = 0

populateHumanBots()
{
	if( ( get_systime() - humanLastCheckTime ) < 5.0 + random( 5 ) )
		return

	humanLastCheckTime = get_systime();

	new humanPlayers = getHumanCount();
	new howManyHumanBotsWanted = get_pcvar_num( p_Humans );
	new howManyHumanBotsActive = getHumanBotCount();

	if( ( humanPlayers < howManyHumanBotsWanted ) && ( howManyHumanBotsActive < howManyHumanBotsWanted ) )
	{
		if( ( humanPlayers - ( howManyHumanBotsWanted - howManyHumanBotsActive) ) < 0 ) {
			new data[6]
			data = "1"
			set_task( 2.0, "addBotPlayer", _, data, 5 );
		}
	}
	else
	{
		if( ( humanPlayers + howManyHumanBotsActive ) > howManyHumanBotsWanted )
			removeBotPlayer( getRandomHumanBot(), true );
	}
}

buildHudString( id, str[], len )
{
	new Float:gameTime = get_gametime();
	new playTime = ( floatround( gameTime ) + g_UserPlayTime[id] )

	static topPlayer[ MAX_NAME_LENGTH ]
	getTopPlayer( topPlayer, sizeof( topPlayer ) - 1 );

	formatex(str, len, 
		"Zombies Killed: %d - Level: %d/%d - Playtime: %i mins - Time of Day: %s\nTop Player: %s",
		getUserData(id, "frags", 0),
		fragsToLevel(id),
		MAX_LEVEL,
		(playTime / 60),
		g_Time[g_TimePeriod],
		topPlayer
	);
}

handleLights()
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
}

drawHUD()
{
	
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

			new Float:gameTime = get_gametime();
			if( gameTime - g_ZombieLastSeenPlayer[idx] > 500 ) { 
				// do something
			}
			
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

				//server_cmd( "monster headcrab %s", name )
				//server_print( "[TS Zombies] Spawning a MonsterMod entity.." );
			}
		}

		set_hudmessage( get_pcvar_num( p_HudColorR ),
			get_pcvar_num( p_HudColorG ), get_pcvar_num( p_HudColorB ),
			get_pcvar_float( p_HudPosX ), get_pcvar_float( p_HudPosY ),
			_,_,99.0,_,_,1 );

		buildHudString( idx, g_Cache, sizeof( g_Cache ) - 1 );
		show_hudmessage(idx,g_Cache);
	}
}

spawnMonster()
{
	if( !get_pcvar_bool( p_MonsterModEnabled ) )
		return
}
getRandomMonsterMod()
{
	return g_Monsters[ random_num( 0 , g_MonstersCount - 1 ) ]
}
// --------------------------------------------------------------------------------------
public Message_TS50(msg_id,msg_dest,msg_entity)
{
	static victim, attacker, Float:aimvelocity[3]
	
	victim = get_msg_arg_int(2);
	attacker = get_msg_arg_int(3);

	// This bot (zombie) caused damage, use this to say we saw a player
	if( is_user_bot( attacker ) )
		g_ZombieLastSeenPlayer[attacker] = get_gametime();
	
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

/* from amxconst.inc
    #define HIT_GENERIC        0
    #define HIT_HEAD        1
    #define HIT_CHEST        2
    #define HIT_STOMACH        3
    #define HIT_LEFTARM        4
    #define HIT_RIGHTARM        5
    #define HIT_LEFTLEG        6
    #define HIT_RIGHTLEG        7 
*/

public client_death( killer, victim, wpnindex, hitplace, TK )
{
	server_print("a death has occured");
	if( is_user_bot( killer ) )
		return

	if( killer == victim )
		return

	server_print("dead");

	new curFrags = getUserData( killer, "frags", 0 );
	setUserData( killer, "frags", curFrags + 1 );
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

	// There's always an issue with "looping" sounds on some maps
	// especially when certin entities are forced, just send this every respawn...
	client_cmd( id, "stopsound" );
	
	// force an update on certin things
	client_infochanged( id );

	// spawn effect
	effect_lava( id );

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
		
		switch(fragsToLevel(id))
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
		//tse_giveuserweap( id, startWeapon, 1000, TSE_ATM_LASERSIGHT + TSE_ATM_FLASHLIGHT );
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
bool:CheckAuthID( const AuthID[] )
{
	if(!AuthID[0])
		return false
	
	if(containi( AuthID, "PENDING" ) != -1 || containi( AuthID, "" ) != -1 )
		return false
	
	return true
}

fragsToLevel( id )
{
	new level = 0
	new frags = getUserData( id, "frags" );
	new maxFrags = get_pcvar_num( p_MaximumFrags );

	level = getScaledValue( frags, 0, maxFrags, 0, MAX_LEVEL );

	return level
}

Float:getScaledValue(value, sourceRangeMin, sourceRangeMax, targetRangeMin, targetRangeMax) {
	new Float:targetRange = targetRangeMax - targetRangeMin;
	new Float:sourceRange = sourceRangeMax - sourceRangeMin;
    return (value - sourceRangeMin) * targetRange / sourceRange + targetRangeMin
}

FragsToPerks( id )
{
	new level = fragsToLevel( id );
	if( level )
		return 0

	// scale between 0-MAX LEVEL
	// to 0 (no perks) - MAX_PERKS (all perks)
	getScaledValue()

	level = clamp( NUM_OF_PERKS)
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

// Needs stats plugin running and enabled
// I think get_stats() returns them already sorted?
getTopPlayer( topName[], len ) {
	new stats[STATSX_MAX_STATS], body[MAX_BODYHITS], name[MAX_NAME_LENGTH]
	new imax = get_statsnum()
	new maxFrags = -1

	for(new a = 0; a < imax; ++a) {
		get_stats(a, stats, body, name, charsmax(name) )
		if( stats[STATSX_KILLS] > maxFrags ) {
			maxFrags = stats[STATSX_KILLS]
			copy( topName, len, name );
		}
	}
}

/*
getTop15(){
  new stats[STATSX_MAX_STATS], body[MAX_BODYHITS], name[MAX_NAME_LENGTH]
  new pos = copy(g_Buffer,charsmax(g_Buffer),"#   nick                           kills/deaths    TKs      hits/shots/headshots^n")
  new imax = get_statsnum()
  if (imax > 15) imax = 15
  for(new a = 0; a < imax; ++a){
    get_stats(a,stats,body,name,charsmax(name))
    replace_all(name, charsmax(name), "<", "[")
    replace_all(name, charsmax(name), ">", "]")
    pos += format(g_Buffer[pos],charsmax(g_Buffer)-pos,"%2d.  %-28.27s    %d/%d          %d            %d/%d/%d^n",a+1,name,stats[STATSX_KILLS],stats[STATSX_DEATHS],stats[STATSX_TEAMKILLS],stats[STATSX_HITS],stats[STATSX_SHOTS],stats[STATSX_HEADSHOTS])
  }
}
*/
/*
	Play a sound on client that is not emitted
	This helps keep the precache down, use precache_generic() instead when playing sounds this way
*/
playSound( id, file )
	client_cmd( id, "spk ^"%s^"", file );

/*
	Play a sound on all connected clients
*/
playSoundOnAll( file )
{
	new Count
	for(Count = 0;Count <= g_MaxPlayers;Count++)
	{
		if( !is_user_connected(Count) || is_user_bot(Count) || !is_user_alive(Count) )
			continue;

		playSound( count, file );
	}
}

getRandomBot()
{
	if(!get_playersnum())
		return 0

	static players[MAX_PLAYERS]
	new playerIndex

	get_players( players, playerIndex, "de", g_ZombieTeamName );

	if( playerIndex < 1 )
		return 0

	return players[random( playerIndex )]
}

getRandomHumanBot()
{
	if(!get_playersnum())
		return 0

	static players[MAX_PLAYERS]
	new playerIndex

	get_players_ex( players, playerIndex, GetPlayers_ExcludeHuman | GetPlayers_MatchTeam, g_HumanTeamName );

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
	get_players_ex( players, humanCount, GetPlayers_ExcludeBots );

	return humanCount
}

getHumanBotCount()
{
	static players[MAX_PLAYERS]

	new humanCount = 0
	get_players_ex( players, humanCount, GetPlayers_ExcludeHuman | GetPlayers_MatchTeam, g_HumanTeamName );

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
ts_giveweaponspawn( id, const wpnId, const extraClip, const wpnExtras = 0 )
{
	if( !is_user_connected( id ) )
		return

	if( !is_user_alive( id ) )
		return

	//g_UserWeapons[id][WeaponID]=1
	ts_giveweapon( id, wpnId, extraClip, wpnExtras )

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

new bool:n = false
public CmdTest(id)
{
	if( !is_user_admin(id ) )
		return
		
	effect_lava(id);
	effect_implosion( id );
	effect_nightVision( id, !n );
}

effect_lava( entId )
{
	if( !is_valid_ent( entId ) )
		return

	new Float:origin[3]
	entity_get_vector( entId, EV_VEC_origin, origin );

	message_begin_f( MSG_PVS, SVC_TEMPENTITY, origin );
	write_byte( TE_LAVASPLASH )
	write_coord( origin[0] );
	write_coord( origin[1] );
	write_coord( origin[2] );
	message_end();
}

effect_implosion( entId, radius = 2, count = 100, life = 10 )
{
	if( !is_valid_ent( entId ) )
		return

	new Float:origin[3]
	entity_get_vector( entId, EV_VEC_origin, origin );

	message_begin( MSG_BROADCAST, SVC_TEMPENTITY, origin );
	write_byte( TE_IMPLOSION )
	
	write_coord( origin[0] )
	write_coord( origin[1] )
	write_coord( origin[2] )

	write_byte(radius);
	write_byte(count);
	write_byte(life);

	message_end();
}

effect_nightVision( id, bool:On = false )
{
	if( On )
	{
		message_begin(MSG_ONE,g_msgScreenFade,{0,0,0},id);
		write_short(~0);
		write_short(~0);
		write_short(1<<2);
		write_byte(0);
		write_byte(255);
		write_byte(0);
		write_byte(70);
		message_end();
	}
	else
	{
		message_begin(MSG_ONE,g_msgScreenFade,{0,0,0},id);
		write_short(~0);
		write_short(~0);
		write_short(1<<2);
		write_byte(0);
		write_byte(0);
		write_byte(0);
		write_byte(0);
		message_end();
	}
}

closeVaultFiles()
{
	if( g_VaultFile != INVALID_HANDLE)
		nvault_close( g_VaultFile );
}

public plugin_end()
	closeVaultFiles();