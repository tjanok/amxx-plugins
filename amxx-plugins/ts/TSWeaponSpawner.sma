/*
* TSWeaponSpawner.sma
* Author(s): Drak
* -------------------------------
* Adds and saves weapons entities for The Specialists v3.0
* -------------------------------
* Commands (requires ADMIN_BAN)
* amx_ts_addwpn <weaponid> <ammo> <spawnflags> <save> - Adds a weapon where you are currently looking. You can also pass spawn flags to attachments
* amx_ts_addwpnmenu - Opens a menu, easier to managing spawning weapons
* amx_ts_delwpn - Deletes the nearest weapon spawn, which also removes it from the vault if saved.
* amx_ts_listweapons - Dumps a list of weapon names with their associated id
* -------------------------------
* Convars
* amx_ts_removewpns 1/0 - If enabled, will remove all the default weapon entities on the loaded map
*/

#include <amxmodx>
#include <amxmisc>
#include <nvault>
#include <fakemeta>
#include <engine> // find_sphere_class

#define SEARCH_RADIUS 50.0
#define MAXIMUM_ENTRIES 100

#define TSA_SILENCER			1
#define TSA_LASERSIGHT			2
#define TSA_FLASHLIGHT			4
#define TSA_SCOPE				8
#define TSA_LAYONWALL			16

// Attachments
enum {
	TSE_ATM_NONE = 0,
	TSE_ATM_SILENCER,
	TSE_ATM_LASERSIGHT,
	TSE_ATM_FLASHLIGHT = 4,
	TSE_ATM_SCOPE = 8
};

// Fire modes
enum {
	TSE_FM_FULLAUTO = 0,
	TSE_FM_SEMIAUTO,
	TSE_FM_BURST,
	TSE_FM_PUMP,
	TSE_FM_FREESEMI,
	TSE_FM_FREEFULL
};

// Weapon names
new gWeaponNames[37][] = {
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
// Weapons
enum {
	TSE_WPN_GLOCK18 = 1,
	TSE_WPN_92F_BERETTA,
	TSE_WPN_UZI,
	TSE_WPN_M3,
	TSE_WPN_M4A1,
	TSE_WPN_MP5SD,
	TSE_WPN_MP5K,
	TSE_WPN_ABERETTAS,
	TSE_WPN_MK23,
	TSE_WPN_AMK23,
	TSE_WPN_USAS,
	TSE_WPN_DEAGLE,
	TSE_WPN_AK47,
	TSE_WPN_57,
	TSE_WPN_AUG,
	TSE_WPN_AUZI,
	TSE_WPN_SKORP,
	TSE_WPN_M82A1,
	TSE_WPN_MP7,
	TSE_WPN_SPAS,
	TSE_WPN_GCOLTS,
	TSE_WPN_GLOCK20,
	TSE_WPN_UMP,
	TSE_WPN_M61GRENADE,
	TSE_WPN_CKNIFE,
	TSE_WPN_MOSSBERG,
	TSE_WPN_M16A4,
	TSE_WPN_MK1,
	TSE_WPN_C4,
	TSE_WPN_A57,
	TSE_WPN_RBULL,
	TSE_WPN_M60E3,
	TSE_WPN_SAWED_OFF,
	TSE_WPN_KATANA,
	TSE_WPN_SKNIFE,
	TSE_WPN_CONTENDER,
	TSE_WPN_ASKORP
};

new const gVaultFilename[] = "tsweaponspawns"
new gVaultFile
new gVaultWeaponCount

new gMenuAttachments[33]
new gMenuWeaponID[33]
new gMenuSaveToVault[33]

new gWeaponMenu

new gMapName[128]

// convars
new pRemoveDefaultWeapons

public plugin_precache()
{
	pRemoveDefaultWeapons = register_cvar( "amx_ts_removewpns", "1" );
	buildWeaponMenu();
}

public plugin_init() 
{
	register_plugin( "TS Weapon Spawns","1.0", "TJ Drak" );

	register_clcmd( "amx_ts_addwpn", "cmdSpawnWpn", ADMIN_BAN, "<wpnid> <ammo> <extra> <save 1/0> - adds gun to wall" );
	register_clcmd( "amx_ts_addwpnmenu", "cmdSpawnWpnMenu", ADMIN_BAN, "opens the weapon spawn menu" );
	register_clcmd( "amx_ts_delwpn", "cmdRemoveWpn", ADMIN_BAN, "removes the nearest weapon spawn near you" );
	register_clcmd( "amx_ts_listweapons", "cmdListWeapons", ADMIN_BAN, "prints a list of all weapon names with their ids" );

	get_mapname( gMapName, 127 );
	gVaultWeaponCount = getVaultWeaponCount();

	set_task( 2.0, "spawnWeapons" );
}

public cmdSpawnWpnMenu(id, level, cid )
{
	if( !cmd_access( id, level, cid, 0 ) )
		return PLUGIN_HANDLED

	gMenuAttachments[id] = 0
	gMenuWeaponID[id] = 0
	gMenuSaveToVault[id] = 0

	menu_display( id, gWeaponMenu );
	client_print( id, print_console, "[TS Weapon Spawner] Menu Opened..." );

	return PLUGIN_HANDLED
}
public cmdSpawnWpn( id, level, cid )
{
	if( !cmd_access( id, level, cid, 3 ) )
		return PLUGIN_HANDLED
	
	new wpnId[256], extraAmmo[33], spawnFlags[33], saveSpawn[33]
	new origin[3]
	get_user_origin( id, origin );
	
	read_argv( 1, wpnId, 255 );
	read_argv( 2, extraAmmo, 32 );
	read_argv( 3, spawnFlags, 32) ;
	read_argv( 4, saveSpawn, 32 );

	new const invalidIds = str_to_num( wpnId );
	
	if( invalidIds == 2 || invalidIds == 10 || invalidIds == 16 || invalidIds == 30 || invalidIds > 36 )
	{
		client_print( id, print_console, "[TS Weapon Spawner] Invalid weapon id" );
		return PLUGIN_HANDLED
	}
	
	new ent = ts_weaponspawn( wpnId, "15", extraAmmo, spawnFlags, origin );

	if( is_valid_ent( ent ) ) {
		client_print( id, print_console, "[TS Weapon Spawner] Weapon created" );

		if( str_to_num( saveSpawn ) == 1 ) {
			writeVaultWeapon( invalidIds, str_to_num( extraAmmo ), str_to_num( spawnFlags ), origin, ent )
			client_print( id, print_console, "[TS Weapon Spawner] Saving..." );
		}
	}
	
	return PLUGIN_HANDLED
}

public cmdRemoveWpn( id, level, cid )
{
	if( !cmd_access( id, level, cid, 0 ) )
		return PLUGIN_HANDLED
	
	new foundEnts[2]
	new foundWeapons = find_sphere_class( id, "ts_groundweapon", SEARCH_RADIUS, foundEnts, 1 );

	if( foundWeapons > 1 || !foundWeapons )
	{
		if( !foundWeapons )
			client_print( id, print_console, "[TS Weapon Spawner] Unable to find a nearby weapon spawn" );
		else
			client_print( id, print_console, "[TS Weapon Spawner] Too many weapon spawns nearby, move closer." );
		
		return PLUGIN_HANDLED
	}
	
	new ent = foundEnts[0]
	removeVaultWeapon( ent );

	client_print(id, print_console, "[TS Weapon Spawner] Weapon removed" );
	engfunc( EngFunc_RemoveEntity, ent );
	
	return PLUGIN_HANDLED
}

public cmdListWeapons( id, level, cid )
{
	if( !cmd_access( id, level, cid, 0 ) )
		return PLUGIN_HANDLED

	new names[1024]
	new temp[128]

	for( new i = 0; i < sizeof( gWeaponNames ); i++ )
	{
		formatex( temp, 126, "%i. %s", i+1, gWeaponNames[i] );

		add( names, 1023, temp );
		add( names, 1023, "^n" );

		// delay the output to avoid any overflows
		temp[127] = id
		set_task( i * 0.01, "printWeaponLine", i+random(1024), temp, 128 );
	}

	names[1023] = id
	set_task( 1.0, "showWeaponMOTD", 0, names, 1024 );

	return PLUGIN_HANDLED
}

public showWeaponMOTD( const motd[1024] )
{
	new const id = motd[1023]
	if( is_user_connected( id ) )
		show_motd( id, motd, "TS Weapons" );
}

public printWeaponLine( const line[128] )
{
	new const id = line[127]
	if( is_user_connected( id ) )
		client_print( id, print_console, line );
}

removeAllWeapons()
{
	if( get_pcvar_num( pRemoveDefaultWeapons ) == 1 )
	{
		server_print( "[TS Weapon Spawner] Removing default map weapons.." );
		
		new ent
		while(( ent = engfunc( EngFunc_FindEntityByString, ent, "classname", "ts_groundweapon" ) ) != 0 )
			engfunc( EngFunc_RemoveEntity, ent );
	}
}

public spawnWeapons()
{
	spawnVaultWeapons();
	server_print( "[TS Weapon Spawner] Loading %i weapons from storage", gVaultWeaponCount );

	if( gVaultWeaponCount >= MAXIMUM_ENTRIES )
		server_print("[TS Weapon Spawner] Maximum number of saved weapons has been reached. %i", MAXIMUM_ENTRIES );
}

getVaultWeaponCount()
{
	new count = 0;
	gVaultFile = nvault_open( gVaultFilename );

	if( gVaultFile != INVALID_HANDLE )
	{
		new key[128]
		new value[1], timestamp

		for( new i = 1; i < MAXIMUM_ENTRIES; i++ )
		{
			formatex( key, 127, "%s-%i", gMapName, i );
			if( nvault_lookup( gVaultFile, key, value, 1, timestamp ) == 1) 
				count++
		}

		nvault_close( gVaultFile );
	}

	return count
}

writeVaultWeapon( wpnId, clip, attachments, origin[3], ent )
{
	new index = getNextFreeIndex();
	gVaultFile = nvault_open( gVaultFilename );

	if( gVaultFile != INVALID_HANDLE )
	{
		new value[128]
		new key[128]

		formatex( key, 127, "%s-%i", gMapName, index );
		formatex( value, 127, "%i %i %i %i %i %i", wpnId, clip, attachments, origin[0], origin[1], origin[2] );

		nvault_pset( gVaultFile, key, value );
		nvault_close( gVaultFile );

		if( is_valid_ent( ent ) )
			set_pev( ent, pev_iuser2, gVaultWeaponCount );
	}
}

getNextFreeIndex()
{
	gVaultFile = nvault_open( gVaultFilename );
	
	if( gVaultFile != INVALID_HANDLE )
	{
		new key[128]
		new value[1], timestamp

		for( new i = 1; i < MAXIMUM_ENTRIES; i++ )
		{
			formatex( key, 127, "%s-%i", gMapName, i );
			if( nvault_lookup( gVaultFile, key, value, 1, timestamp ) == 0)
				return i
		}

		nvault_close( gVaultFile );
	}

	return -1;
}

removeVaultWeapon( ent )
{
	new keyId = pev( ent, pev_iuser2 );

	if( !keyId || keyId == 0 )
		return

	new key[128]
	formatex( key, 127, "%s-%i", gMapName, keyId );

	gVaultFile = nvault_open( gVaultFilename );
	if( gVaultFile != INVALID_HANDLE )
	{
		nvault_remove( gVaultFile, key );
		nvault_close( gVaultFile );
	}
}
spawnVaultWeapons()
{
	removeAllWeapons();

	gVaultWeaponCount = getVaultWeaponCount();
	gVaultFile = nvault_open( gVaultFilename )

	if( gVaultFile != INVALID_HANDLE )
	{
		new key[128]
		new value[128]
		new spawnCount = 0

		for( new i = 0; i <= MAXIMUM_ENTRIES; i++ )
		{
			formatex( key, 127, "%s-%i", gMapName, i );
			new strLen = nvault_get( gVaultFile, key, value, 127 );

			if( strLen > 0 )
			{
				new index = 0;
				new phase = 0;
				new wpnId[12], clip[12], attachments[12], origin[3]

				spawnCount++

				while( index != -1 ) 
				{
					new arg[33]
					index = argparse( value, index, arg, 32 );

					switch( phase ) 
					{
						case 0: {
						copy( wpnId, 11, arg );
						}
						case 1: {
						copy( clip, 11, arg );
						}
						case 2: {
						copy( attachments, 11, arg );
						}
						case 3: {
						origin[0] = str_to_num( arg );
						}
						case 4: {
						origin[1] = str_to_num( arg ); 
						}
						case 5: {
						origin[2] = str_to_num( arg ); 
						}
					}
					phase++
				}

				if( origin[0] != 0 && origin[1] != 0 && origin[2] != 0 )
					ts_weaponspawn( wpnId, "15", clip, attachments, origin, i );

				if( spawnCount > gVaultWeaponCount )
					break;		
			}
		}

		if( spawnCount == gVaultWeaponCount )
			server_print( "[TS Weapon Spawner] All weapons successfully spawned" );

		nvault_close( gVaultFile );
	}
}

/*==================================================================================================================================================*/
public _spawnWpnHandler( id, menu, item )
{
	if( item == MENU_EXIT )
		return PLUGIN_HANDLED
	
	new info[12], access
	menu_item_getinfo( menu, item, access, info, 11,_ , _, access );
	
	new wpnId = str_to_num( info );
	if( !wpnId || wpnId > 37 )
		return PLUGIN_HANDLED
	
	new title[64]
	formatex( title, 63, "Weapon ID: %d^nSpawnFlags", wpnId );
	gMenuWeaponID[id] = wpnId
	
	new subMenu = menu_create( title, "_spawnWpnHandler2" );
	
	menu_additem( subMenu, "Silencer" );
	menu_additem( subMenu, "Lasersight" );
	menu_additem( subMenu, "Flashlight" );
	
	menu_additem( subMenu, "Scope" );
	menu_additem( subMenu, "Lay on Wall" );
	menu_additem( subMenu, "Save to Vault" );

	menu_addblank( subMenu, 0 );

	menu_additem( subMenu, "Done" );
	menu_additem( subMenu, "Exit" );
	menu_setprop( subMenu, MPROP_EXIT, MEXIT_NEVER ); 
	
	menu_display(id,subMenu);
	return PLUGIN_HANDLED
}
public _spawnWpnHandler2( id, Menu, Item )
{
	if( Item == MENU_EXIT )
		return PLUGIN_HANDLED
	
	switch(Item)
	{
		case 0:
		{
			if(gMenuAttachments[id] & TSA_SILENCER)
			{
				gMenuAttachments[id] -= TSA_SILENCER
			}
			else
			{
				gMenuAttachments[id] += TSA_SILENCER
			}
			
			(gMenuAttachments[id] & TSA_SILENCER) ? 
				menu_item_setname(Menu,Item,"Silencer *") : menu_item_setname(Menu,Item,"Silencer");
		}
		case 1:
		{
			if(gMenuAttachments[id] & TSA_LASERSIGHT)
			{
				gMenuAttachments[id] -= TSA_LASERSIGHT
			}
			else
			{
				gMenuAttachments[id] += TSA_LASERSIGHT
			}
			
			(gMenuAttachments[id] & TSA_LASERSIGHT) ? 
				menu_item_setname(Menu,Item,"Lasersight *") : menu_item_setname(Menu,Item,"Lasersight");
		}
		case 2:
		{
			if(gMenuAttachments[id] & TSA_FLASHLIGHT)
			{
				gMenuAttachments[id] -= TSA_FLASHLIGHT
			}
			else
			{
				gMenuAttachments[id] += TSA_FLASHLIGHT
			}
			
			(gMenuAttachments[id] & TSA_FLASHLIGHT) ? 
				menu_item_setname(Menu,Item,"Flashlight *") : menu_item_setname(Menu,Item,"Flashlight");
		}
		case 3:
		{
			if(gMenuAttachments[id] & TSA_SCOPE)
			{
				gMenuAttachments[id] -= TSA_SCOPE
			}
			else
			{
				gMenuAttachments[id] += TSA_SCOPE
			}
			
			(gMenuAttachments[id] & TSA_SCOPE) ? 
				menu_item_setname(Menu,Item,"Scope *") : menu_item_setname(Menu,Item,"Scope");
		}
		case 4:
		{
			if(gMenuAttachments[id] & TSA_LAYONWALL)
			{
				gMenuAttachments[id] -= TSA_LAYONWALL
			}
			else
			{
				gMenuAttachments[id] += TSA_LAYONWALL
			}
			
			(gMenuAttachments[id] & TSA_LAYONWALL) ? 
				menu_item_setname(Menu,Item,"Lay On Wall *") : menu_item_setname(Menu,Item,"Lay On Wall");
		}
		case 5:
		{
			gMenuSaveToVault[id] = !gMenuSaveToVault[id]
			(gMenuSaveToVault[id]) ? 
				menu_item_setname( Menu, Item, "Save to Vault *" ) : menu_item_setname( Menu, Item, "Save to Vault ");
		}
		case 6:
		{
			new origin[3]
			get_user_origin( id, origin );
			
			new szwpnId[12],szFlags[12]
			num_to_str(gMenuWeaponID[id],szwpnId,11);
			num_to_str(gMenuAttachments[id],szFlags,11);
			
			menu_destroy(Menu);
			
			new ent = ts_weaponspawn(szwpnId,"15","100",szFlags,origin);
			
			if( is_valid_ent( ent ) )
			{
				client_print(id, print_chat, "[TS Weapon Spawner] Created TS Weapon Spawn" );
				if( gMenuSaveToVault[id] )
				{
					writeVaultWeapon( gMenuWeaponID[id], 100, gMenuAttachments[id], origin, ent );
					client_print( id, print_chat, "[TS Weapon Spawner] Saved to vault..." );
				}
			}
			
			return PLUGIN_HANDLED
		}
		case 7:
		{
			menu_destroy(Menu);
			return PLUGIN_HANDLED
		}
	}
	
	menu_display(id,Menu);
	return PLUGIN_HANDLED
}
/*==================================================================================================================================================*/
buildWeaponMenu()
{
	gWeaponMenu = menu_create( "TS Weapon Spawner", "_spawnWpnHandler" );

	new info[12]
	for( new i = 0; i < sizeof( gWeaponNames ); i++ )
	{
		num_to_str( i+1, info, 11 );
		menu_additem( gWeaponMenu, gWeaponNames[i], info );
	}
}
/*==================================================================================================================================================*/
ts_weaponspawn( const wpnId[], const duration[], const extraclip[], const spawnflags[], const Origin[3], vaultKey = 0 )
{
	new ent = engfunc(EngFunc_CreateNamedEntity,engfunc(EngFunc_AllocString,"ts_groundweapon"))
	if(!ent)
		return PLUGIN_CONTINUE
		
	fm_set_kvd(ent,"tsweaponid",wpnId,"ts_groundweapon");
	fm_set_kvd(ent,"wduration",duration,"ts_groundweapon");
	fm_set_kvd(ent,"wextraclip",extraclip,"ts_groundweapon");
	fm_set_kvd(ent,"spawnflags",spawnflags,"ts_groundweapon");

	new Float:flOrigin[3]
	IVecFVec( Origin, flOrigin );

	engfunc(EngFunc_SetOrigin,ent, flOrigin);
	dllfunc(DLLFunc_Spawn,ent);

	set_pev( ent, pev_iuser2, vaultKey );
	
	return ent
}
fm_set_kvd(Entity,const key[],const value[],const classname[]) 
{
	set_kvd(0,KV_ClassName,classname);
	set_kvd(0,KV_KeyName,key);
	set_kvd(0,KV_Value,value);
	set_kvd(0,KV_fHandled,0);
	
	return dllfunc(DLLFunc_KeyValue,Entity,0);
}