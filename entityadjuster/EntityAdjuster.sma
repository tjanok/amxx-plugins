#include <amxmodx>
#include <amxmisc>
#include <textparse_ini>
#include <fakemeta>
#include <fakemeta_util>

#define DELAY_PARSE_FILE 5.0

// ConVars
new p_Enabled
new p_ShowActions

new const g_baseSections[8][33] =  {
    "[REMOVE]",
    "// Set Property Syntax",
    "// entity_id/targetname-entity_key-data_type=value"
    "// EX: my_door-speed-f=10.0 would mean my_door, set the entity speed to 10.0f",
    "// Some properties are floats, ints, etc. Refer to HLSDK for information",
    "[SET PROPERTY]",
    "[USE]"
}

new INIParser:g_iniParserHandle
new g_currentSection[128]
new g_currentIniMapFile[256]

public plugin_precache()
{
    // ConVars
    p_Enabled           = register_cvar( "amx_entity_adjuster_on", "1" );
    p_ShowActions       = register_cvar( "amx_entity_adjuster_log", "1" );

    // Parsers
    setupParse();
}

public plugin_end()
{
    if( g_iniParserHandle != Invalid_INIParser )
        INI_DestroyParser( g_iniParserHandle );
}

public plugin_init()
{
	// Main
	register_plugin( "Entity Adjuster", "0.1a", "Trevor 'Drak' J" );

    // Commands
    register_concmd( "amx_entity_adjuster_run", "cmdRunParser", ADMIN_BAN, "" );
}

setupParse()
{
    if( g_iniParserHandle != Invalid_INIParser )
        INI_DestroyParser( g_iniParserHandle );

    g_iniParserHandle = INI_CreateParser();

    if( g_iniParserHandle == Invalid_INIParser )
        notify( "unable to create INI parser, stopping plugin", true );

    INI_SetReaders( g_iniParserHandle, "iniOnKeyValue", "iniOnNewSection" );
    INI_SetParseEnd( g_iniParserHandle, "onParserFinished" );
}

public beginParse()
{
    if( !get_pcvar_bool( p_Enabled ) )
        return

    INI_ParseFile( g_iniParserHandle, g_currentIniMapFile );
    notify( "Running file '%s'", g_currentIniMapFile );
}

public plugin_cfg()
{
	new configDir[256]
	get_datadir( configDir, 255 );
    
    new mapName[33]
    get_mapname( mapName, 32 );

    format( configDir, 255, "%s/EntityAdjuster", configDir );

    if( !dir_exists( configDir ) )
        mkdir( configDir );

    format( configDir, 255, "%s/%s.ini", configDir, mapName );

    if( !file_exists( configDir ) )
        createDefaultFile( configDir );

    copy( g_currentIniMapFile, 255, configDir );
    set_task( DELAY_PARSE_FILE, "beginParse" );
}

public bool:iniOnNewSection( INIParser:handle, const section[], 
    bool:invalid_tokens, bool:close_bracket, bool:extra_tokens, curtok, any:data )
{
    new bool:bFoundSection = false;

    for( new i = 0; i < sizeof( g_baseSections ); i++ )
    {
        if( containi( g_baseSections[i], section ) != -1 )
        {
            bFoundSection = true;
            break;
        }
    }

    if( !bFoundSection )
    {
        notify( "invalid section found within file '%s'", false, section );
        return false;

    }

    copy( g_currentSection, 127, section );
    return true
}

public bool:iniOnKeyValue( INIParser:handle, const key[], 
    const value[], bool:invalid_tokens, bool:equal_token, bool:quotes, curtok, any:data )
{
    if( strcmp( g_currentSection, "USE" ) == 0 )
    {
        handleUseSection( key );
    }

    if( strcmp( g_currentSection, "SET PROPERTY" ) == 0 )
    {
        handlePropertySection( key, value );
    }

    if( strcmp( g_currentSection, "REMOVE" ) == 0 )
    {
        handleRemoveSection( key );
    }

    return true
}

public bool:onParserFinished()
    INI_DestroyParser( g_iniParserHandle );

notify( const msg[], bool:fatalError = false, any:... )
{
    new formattedMsg[255]

    if( msg[0] )
	{
		vformat( formattedMsg, sizeof( formattedMsg ) - 1, msg, 3 );

        // Always print to server
        server_print( "%s - Fatal Error: %s", formattedMsg, fatalError ? "Yes" : "No" );

        if( get_pcvar_bool( p_ShowActions ) )
		    log_amx( "%s - Fatal Error: %s", formattedMsg, fatalError ? "Yes" : "No" );

    }
    
    if( fatalError )
    {
        // This will pause the plugin
		set_fail_state( reason );
	}
	
	return PLUGIN_HANDLED
}

createDefaultFile( const file[] )
{
    new fileData[256]

    for( new i = 0; i < sizeof( g_baseSections ); i++ )
    {
        add( fileData, 255, g_baseSections[i] );
        add( fileData, 255, "^n^n" );
    }

    write_file( file, fileData );
}

public cmdRunParser( id, level, cid )
{
    if( !cmd_access( id, level, cid ) )
        return PLUGIN_HANDLED
    
    if( !get_pcvar_bool( p_Enabled ) )
    {
        client_print( id, print_console, "[AMXX] The plugin is currently disabled" );
        return PLUGIN_HANDLED
    }

    setupParse();
    beginParse();

    client_print( id, print_console, "[AMXX] Running entity adjustment for this map." );

    return PLUGIN_HANDLED
}

// -------------------------------------------------------------------------------
findEnt( const entityIdOrName[] )
{
    new entId = str_to_num( entityIdOrName );
    new ent = 0

    if( entId != 0 )
        ent = entId + get_maxplayers();
    else
        ent = fm_find_ent_by_tname( 0, entityIdOrName );
    
    return end
}
handleRemoveSection( const entityIdOrName[] )
{
    new ent = findEnt( entityIdOrName );

    if( fm_is_valid_ent( ent ) )
    {
        // Safe?
        // Might need to set "KILLME" flag instead - so we don't remove it durning a bad frame
        engfunc( EngFunc_RemoveEntity, ent );
    }
    else
    {
        notify( "unable to find entity id/name '%s'", entityIdOrName );
    }
}

handleUseSection( const entityIdOrName[] )
{
    new ent = findEnt( entityIdOrName );

    if( fm_is_valid_ent( ent ) )
    {
        // The ent will "use" itself
        // When used on some doors, the move sound keeps spamming on some mods (WHY??)
        dllfunc( DLLFunc_Use, ent, ent );
    }
    else
    {
        notify( "unable to find entity id/name '%s'", entityIdOrName );
    }
}

handlePropertySection( const propertyName[], const propertyValue[] )
{
    new propName[128]
    new entName[128]
    new dataType[1]

    split( propertyName, entName, 127, propName, 127, "-" );
    split( propName, propName, 127, dataType, 1, "-" );

    new test[3][128]
    explode_string( propertyName, "-", test, 3, 127 )

    server_print("buffer: %s %s %s", test[0], test[1], test[2])

    //ahideout_mcpd_door-speed-f=10.0-f

    server_print( "prop: %s - ent: %s - property data type: %s", propName, entName, dataType );

    new entId = str_to_num( entName );
    new ent = 0

    if( entId != 0 )
        ent = entId + get_maxplayers();
    else
        ent = fm_find_ent_by_tname( 0, entName );

    if( ent != 0 )
    {
        server_print("PROPER VALUE: %s", propertyValue );

        new pevProp = propertyToPev( propName );
        new Float:propertyNum = str_to_float( propertyValue );

        if( pevProp == -1 )
        {
            error( "unable to find entity property '%s'", false, propName );
            return
        }

        //set_pev( ent, pevProp, propertyNum );
        entity_set_float( ent, EV_FL_speed, propertyNum );

        server_print("SETTING PEV %f annd %f", propertyNum, entity_get_float(ent, EV_FL_speed) );
    }
    else
    {
        error( "unable to find, etc..." );
    }
}

propertyToPev( const prop[] )
{
    if( strcmp( prop, "speed" ) == 0 )
        return pev_speed;
    
    if( strcmp( prop, "dmg" ) == 0 )
        return pev_dmg;

    if( strcmp( prop, "takedamage" ) == 0 )
        return pev_takedamage

    return -1;
}