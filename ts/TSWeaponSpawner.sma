/*
* DRPWeapons.sma
* Author(s): Drak
* -------------------------------
* Desc:
* Loads the weapons spawns from the Database.
* Removes the weapons on map start. (Enabled via CVar)
* Commands to spawn TS Weapons (Optional save to Database)
* 
* Changelog:
* 6/12/08:
* Moved code around abit.
* Small optimizations
*/

#include <amxmodx>
#include <nvault>
#include <fakemeta>
#include <engine> // find_sphere_class

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

// Weapons
enum {
	TSE_WPN_GLOCK18 = 1,
	TSE_WPN_92F,
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

new g_Attachments[33]
new g_WeaponID[33]

new g_WeaponMenu
new g_WeaponIDs[128]

new gMapName[128]

// PCVars
new p_Enable

public plugin_init() 
{
	register_plugin( "TS Weapon Spawns","1.0", "TJ Drak" );

    register_clcmd( "amx_ts_addwpn", "cmdSpawnWpn", ADMIN_BAN, "<ammo> <extra> <save (0/1)> - adds gun to wall" );
    register_clcmd( "amx_ts_delwpn", "cmdRemoveWpn", ADMIN_BAN, "removes the nearest weapon spawn near you" );
    register_clcmd( "amx_ts_listweapons", "cmdListWeapons", ADMIN_BAN, "prints a list of all weapon names with their ids" );

    get_mapname( gMapName, 127 );
    gVaultWeaponCount = getVaultWeaponCount();

    set_task( 2.0, "spawnWeapons" );
}

public cmdSpawnWpn( id, level, cid )
{
}

public cmdRemoveWpn( id, level, cid )
{
}

public cmdListWeapons( id, level, cid )
{
}

public spawnWeapons()
{
    spawnVaultWeapons();
    server_print( "[TS Weapon Spawners] Loading %i weapons from storage", gVaultWeaponCount );

    new Float:o[3]
    writeVaultWeapon( 1, 20, 200, o );
}

getVaultWeaponCount()
{
    new count = 0;
    new key[128]

    formatex( key, 127, "%s-numberofspawns", gMapName );
    gVaultFile = nvault_open( gVaultFilename );
    
    if( gVaultFile != INVALID_HANDLE )
        count = nvault_get( gVaultFile, key );

    nvault_close( gVaultFile );
    return count
}

writeVaultWeapon( weaponId, clip, attachments, Float:origin[3] )
{
    gVaultFile = nvault_open( gVaultFilename )
    if( gVaultFile != INVALID_HANDLE )
    {
        gVaultWeaponCount++

        new value[128]
        new key[128]

        formatex( key, 127, "%s-%i", gMapName, gVaultWeaponCount );
        formatex( value, 127, "%i %i %i %f %f %f", weaponId, clip, attachments, origin[0], origin[1], origin[2] );

        nvault_pset( gVaultFile, key, value );

        formatex( key, 127, "%s-numberofspawns", gMapName );
        formatex( value, 127, "%i", gVaultWeaponCount );

        nvault_pset( gVaultFile, key, value );
        nvault_close( gVaultFile );
    }
}

spawnVaultWeapons()
{
    gVaultWeaponCount = getVaultWeaponCount();
    gVaultFile = nvault_open( gVaultFilename )
    
    if( gVaultFile != INVALID_HANDLE )
    {
        new key[128]
        new value[128]

        for( new i = 0; i < gVaultWeaponCount; i++ )
        {
            formatex( key, 127, "%s-%i", gMapName, i );
            
            new strLen = nvault_get( gVaultFile, key, value, 127 );
            if( strLen > 0 )
            {
                new index = 0;
                new phase = 0;
                new wpnId, clip, attachments, Float:origin[3]

                while( index != -1 ) 
                {
                    new arg[33]
                    index = argparse( value, index, arg, 32 );
                    switch( phase ) 
                    {
                        case 0: {
                            wpnId = str_to_num( arg ); 
                        }
                        case 1: {
                            clip = str_to_num( arg ); 
                        }
                        case 2: {
                            attachments = str_to_num( arg ); 
                        }
                        case 3: {
                            origin[0] = str_to_float( arg ); 
                        }
                    }
                    phase++
                }
            }
        }
        nvault_close( gVaultFile );
    }
}

/*==================================================================================================================================================*/
public WeaponSpawn_Menu(id)
	menu_display(id,g_WeaponMenu);

public client_disconnected(id)
	g_Attachments[id] = 0

public _SpawnWeapon(id,Menu,Item)
{
	if(Item == MENU_EXIT)
		return PLUGIN_HANDLED
	
	new Info[12],Access
	menu_item_getinfo(Menu,Item,Access,Info,11,_,_,Access);
	
	new WeaponID = str_to_num(Info);
	if(!WeaponID || WeaponID > 36)
	{
		client_print(id,print_chat,"[DRP] Internal Error; Please contact an admin.");
		return PLUGIN_HANDLED
	}
	
	new Title[64]
	formatex(Title,63,"WeaponID: %d^nSpawnFlags",WeaponID);
	g_WeaponID[id] = WeaponID
	
	new Menu2 = menu_create(Title,"_SpawnWeapon2");
	
	menu_additem(Menu2,"Silencer");
	menu_additem(Menu2,"Lasersight");
	menu_additem(Menu2,"Flashlight");
	menu_additem(Menu2,"Scope");
	menu_additem(Menu2,"Lay on Wall");
	menu_addblank(Menu2,0);
	menu_additem(Menu2,"Done");
	menu_additem(Menu2,"Exit");
	menu_setprop(Menu2,MPROP_EXIT,MEXIT_NEVER);
	
	menu_display(id,Menu2);
	return PLUGIN_HANDLED
}
public _SpawnWeapon2(id,Menu,Item)
{
	if(Item == MENU_EXIT)
		return PLUGIN_HANDLED
	
	switch(Item)
	{
		case 0:
		{
			if(g_Attachments[id] & TSA_SILENCER)
			{
				g_Attachments[id] -= TSA_SILENCER
			}
			else
			{
				g_Attachments[id] += TSA_SILENCER
			}
			
			(g_Attachments[id] & TSA_SILENCER) ? 
				menu_item_setname(Menu,Item,"Silencer *") : menu_item_setname(Menu,Item,"Silencer");
		}
		case 1:
		{
			if(g_Attachments[id] & TSA_LASERSIGHT)
			{
				g_Attachments[id] -= TSA_LASERSIGHT
			}
			else
			{
				g_Attachments[id] += TSA_LASERSIGHT
			}
			
			(g_Attachments[id] & TSA_LASERSIGHT) ? 
				menu_item_setname(Menu,Item,"Lasersight *") : menu_item_setname(Menu,Item,"Lasersight");
		}
		case 2:
		{
			if(g_Attachments[id] & TSA_FLASHLIGHT)
			{
				g_Attachments[id] -= TSA_FLASHLIGHT
			}
			else
			{
				g_Attachments[id] += TSA_FLASHLIGHT
			}
			
			(g_Attachments[id] & TSA_FLASHLIGHT) ? 
				menu_item_setname(Menu,Item,"Flashlight *") : menu_item_setname(Menu,Item,"Flashlight");
		}
		case 3:
		{
			if(g_Attachments[id] & TSA_SCOPE)
			{
				g_Attachments[id] -= TSA_SCOPE
			}
			else
			{
				g_Attachments[id] += TSA_SCOPE
			}
			
			(g_Attachments[id] & TSA_SCOPE) ? 
				menu_item_setname(Menu,Item,"Scope *") : menu_item_setname(Menu,Item,"Scope");
		}
		case 4:
		{
			if(g_Attachments[id] & TSA_LAYONWALL)
			{
				g_Attachments[id] -= TSA_LAYONWALL
			}
			else
			{
				g_Attachments[id] += TSA_LAYONWALL
			}
			
			(g_Attachments[id] & TSA_LAYONWALL) ? 
				menu_item_setname(Menu,Item,"Lay On Wall *") : menu_item_setname(Menu,Item,"Lay On Wall");
		}
		case 5:
		{
			new Float:plOrigin[3]
			pev(id,pev_origin,plOrigin);
			
			new szWeaponID[12],szFlags[12]
			num_to_str(g_WeaponID[id],szWeaponID,11);
			num_to_str(g_Attachments[id],szFlags,11);
			
			menu_destroy(Menu);
			
			new Ent = ts_weaponspawn(szWeaponID,"15","100",szFlags,plOrigin,0);
			if(Ent)
				client_print(id,print_chat,"[DRP] Created Weapon.");
			else
				client_print(id,print_chat,"[DRP] There was an error creating the weapon.");
				
			if(Ent)
			{
				new Data[1],Query[256]
				Data[0] = Ent
				
				new SQLOrigin[3]
				FVecIVec(plOrigin,SQLOrigin);
				
				//formatex(Query,255,"INSERT INTO %s (WeaponID,Clips,Flags,X,Y,Z) VALUES ('%d','%d','%s','%d','%d','%d')",g_WeaponTable,g_WeaponID[id],100,szFlags,SQLOrigin[0],SQLOrigin[1],SQLOrigin[2]);
				//SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",Query);
				
				//formatex(Query,255,"SELECT * FROM %s ORDER BY `SQLKey` DESC",g_WeaponTable);
				//SQL_ThreadQuery(g_SqlHandle,"SetSQLPev",Query,Data,1);
			}
			
			return PLUGIN_HANDLED
		}
		case 6:
		{
			menu_destroy(Menu);
			return PLUGIN_HANDLED
		}
	}
	
	menu_display(id,Menu);
	return PLUGIN_HANDLED
}
	
/*==================================================================================================================================================*/
public CmdSpawnWpn(id,level,cid)
{

	new WeaponID[256],Ammo[33],Flags[33],Save[33],Float:plOrigin[3]
	pev(id,pev_origin,plOrigin);
	
	read_argv(1,WeaponID,255);
	read_argv(2,Ammo,32);
	read_argv(3,Flags,32);
	read_argv(4,Save,32);

	new const IWeaponID = str_to_num(WeaponID);
	
	if(IWeaponID == 2 || IWeaponID == 10 || IWeaponID == 16 || IWeaponID == 30 || IWeaponID > 36)
	{
		client_print(id,print_console,"[DRP] Invalid WeaponID");
		return PLUGIN_HANDLED
	}
	
	new SQLOrigin[3]
	FVecIVec(plOrigin,SQLOrigin);
	
	new Ent = ts_weaponspawn(WeaponID,"15",Ammo,Flags,plOrigin,0);
	
	if(!str_to_num(Save))
		return PLUGIN_HANDLED
	
	new Data[1]
	Data[0] = Ent
	
	//format(WeaponID,255,"INSERT INTO %s (WeaponID,Clips,Flags,X,Y,Z) VALUES ('%d','%d','%s','%d','%d','%d')",g_WeaponTable,IWeaponID,str_to_num(Ammo),Flags,SQLOrigin[0],SQLOrigin[1],SQLOrigin[2]);
	//SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",WeaponID);
	
	//format(WeaponID,255,"SELECT * FROM %s ORDER BY `SQLKey` DESC",g_WeaponTable);
	//SQL_ThreadQuery(g_SqlHandle,"SetSQLPev",WeaponID,Data,1);
	
	return PLUGIN_HANDLED
}
public CmdRemoveOrigin(id,level,cid)
{
	
	new Arg[33],EntList[5]
	read_argv(1,Arg,32);
	
	new Num = find_sphere_class(id,"ts_groundweapon",50.0,EntList,1),Ent
	if(Num > 1 || !Num)
	{
		client_print(id,print_console,"[DRP] No weapons found, or there is more then one around you. Found: %d",Num);
		return PLUGIN_HANDLED
	}
	
	Num = str_to_num(Arg);
	Ent = EntList[0]

	if(Num)
	{
		new Query[128]
		//format(Query,127,"DELETE FROM %s WHERE `SQLKey`='%d'",g_WeaponTable,pev(Ent,pev_iuser2));
		//SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",Query);
	}
	
	client_print(id,print_console,"[DRP] Weapon Removed %s",Num ? "(Deleted from SQL)" : "");
	engfunc(EngFunc_RemoveEntity,Ent);
	
	return PLUGIN_HANDLED
}
public CmdListWpnIds(id,level,cid)
{
	
	new Arg[33]
	read_argv(1,Arg,32);
	
	new iArg = str_to_num(Arg);
	
	switch(iArg)
	{
		case 0..1:
		{
			new pFile = fopen(g_WeaponIDs,"r");
			if(!pFile)
			{
				client_print(id,print_console,"[DRP] Unable to open WeaponIDs File. (%s)",g_WeaponIDs);
				return PLUGIN_HANDLED
			}
			
			new Data[128]
			while(!feof(pFile))
			{
				fgets(pFile,Data,127);
				trim(Data);
				
				client_print(id,print_console,"%s",Data);
			}
			fclose(pFile);
		}
		case 2:
		{
			client_print(id,print_console,"[DRP] A MOTD Window has been opened containing a list of weaponids.");
			show_motd(id,g_WeaponIDs,"DRP");
		}
	}
	
	return PLUGIN_HANDLED
}
/*==================================================================================================================================================*/
public RemoveWeapons()
{
	if(get_pcvar_num(p_Enable))
	{
		new Ent
		while(( Ent = engfunc(EngFunc_FindEntityByString,Ent,"classname","ts_groundweapon" )) != 0)
			engfunc(EngFunc_RemoveEntity,Ent);
	}
}

/*==================================================================================================================================================*/
ts_weaponspawn(const weaponid[],const duration[],const extraclip[],const spawnflags[],const Float:Origin[3] = {0.0,0.0,0.0},SQLKey)
{
	new ent = engfunc(EngFunc_CreateNamedEntity,engfunc(EngFunc_AllocString,"ts_groundweapon"))
	if(!ent)
		return PLUGIN_CONTINUE
		
	fm_set_kvd(ent,"tsweaponid",weaponid,"ts_groundweapon");
	fm_set_kvd(ent,"wduration",duration,"ts_groundweapon");
	fm_set_kvd(ent,"wextraclip",extraclip,"ts_groundweapon");
	fm_set_kvd(ent,"spawnflags",spawnflags,"ts_groundweapon");
	
	dllfunc(DLLFunc_Spawn,ent);
	engfunc(EngFunc_SetOrigin,ent,Origin);
	
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