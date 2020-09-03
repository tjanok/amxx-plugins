/*

Ban Old Menu (yeah it could really use a better name)

Collects info from players who have left the server recently and gives the admin a menu from which the admin can auth/ip ban, name+auth+ip are collected and displayed, each ban requires a confirm which will help prevent annoying accidents.

50 most recent, reset on map change, when over 50 the old data gets over written slot by slot, while under 50 oldest first, just a little over 50 and the first few start to get over written.

used menu structure from:
http://www.amxmodx.org/forums/viewtopic.php?p=112762
*     Vote Kick/Ban Menu
*        by WaZZeR
*   Thanks to:
*     v3x       - helped me with the loose indentation error 
*     xeroblood - for the palyer menu template

todo: ban server cmd cvar, for diff ban systems; unban menu; reduce memory waste; see ip permissions; newest always go first

*/
#include <amxmodx>
#include <amxmisc>

#define MENU_SIZE    1024
#define MENU_PLAYERS 7
#define OLD_MAX 50

new g_iMenuPosition[33]; //position in menu list
new g_iMenuPlayers_auth[OLD_MAX+1][30]; //old player list
new g_iMenuPlayers_name[OLD_MAX+1][30]; 
new g_iMenuPlayers_ip[OLD_MAX+1][30]; 
new g_iMenuOption_auth[33][30]; //to confirm
new g_iMenuOption_name[33][30]; 
new g_iMenuOption_ip[33][30]; 
new g_iMenuSettings[33]; //auth/ip
new g_iMenuOldCounter; // up stop
new g_iMenuOldInsertPos; // up down up down

public plugin_init()
{
    register_plugin("Ban Old Menu","0.1","Seather");
    register_menucmd(register_menuid("Ban Old Menu"),1023,"actionBanOldMenu");
    register_clcmd("amx_banoldmenu","cmdBanOld",ADMIN_BAN,"- displays ban old menu");
    g_iMenuOldCounter = 0;
    g_iMenuOldInsertPos = 0;
}


public cmdBanOld( id, lvl, cid )
{
    if( cmd_access( id, lvl, cid, 0 ) )
    {
        g_iMenuOption_auth[id] = " ";
        g_iMenuSettings[id] = 0;
        g_iMenuPosition[id] = 0;

        showBanOldMenu(id);
    }
    return PLUGIN_HANDLED
}

public showBanOldMenu( id )
{
    if( g_iMenuPosition[id] < 0 ) return

    new i;
    new szMenuBody[MENU_SIZE];
    new iCurrKey = 0;
    new iStart = g_iMenuPosition[id] * MENU_PLAYERS;

    if( iStart >= g_iMenuOldCounter )
    {
        iStart = g_iMenuPosition[id] = 0;
    }
    new iLen = format( szMenuBody, MENU_SIZE-1, "Ban Old Menu %d/%d^n^n", g_iMenuPosition[id]+1, (g_iMenuOldCounter / MENU_PLAYERS + ((g_iMenuOldCounter % MENU_PLAYERS) ? 1 : 0 )) );
    new iEnd = iStart + MENU_PLAYERS;
    new iKeys = (1<<9|1<<7);

    if( iEnd > g_iMenuOldCounter )
        iEnd = g_iMenuOldCounter;

    for( i = iStart; i < iEnd; i++ )
    {
            iKeys |= (1<<iCurrKey++);
            iLen += format( szMenuBody[iLen], (MENU_SIZE-1-iLen), "%d. %s, %s, %s^n", iCurrKey, g_iMenuPlayers_auth[i], g_iMenuPlayers_name[i], g_iMenuPlayers_ip[i] );
    }
    //Check if it is auth or ip
    if (!equal(g_iMenuOption_auth[id]," "))
        iLen += format( szMenuBody[iLen], (MENU_SIZE-1-iLen), "^n8. CONFIRM,%s,%s,%s,%s^n" , g_iMenuSettings[id] ? "Ban IP" : "Ban Auth" , g_iMenuOption_auth[id] , g_iMenuOption_name[id] , g_iMenuOption_ip[id] );
    else if ( g_iMenuSettings[id] == 0)
        iLen += format( szMenuBody[iLen], (MENU_SIZE-1-iLen), "^n8. AUTH^n" );
	else
		iLen += format( szMenuBody[iLen], (MENU_SIZE-1-iLen), "^n8. IP^n" );
		
    //Cheack if there are more players left
    if( iEnd != g_iMenuOldCounter )
    {
        format( szMenuBody[iLen], (MENU_SIZE-1-iLen), "^n9. More...^n0. %s", g_iMenuPosition[id] ? "Back" : "Exit" );
        iKeys |= (1<<8);
    }
    else
        format( szMenuBody[iLen], (MENU_SIZE-1-iLen), "^n0. %s", g_iMenuPosition[id] ? "Back" : "Exit" );

    show_menu( id, iKeys, szMenuBody, -1 );

    return
}

public actionBanOldMenu( id, key )
{
    switch( key )
    {
        case 7: {
            if(!equal(g_iMenuOption_auth[id]," ")) //ban!
			{
				server_cmd("amx_addban ^"%s^" ^"%s^" ^"120^" ^"Generic Ban^"",g_iMenuOption_name[id],g_iMenuSettings[id] ? g_iMenuOption_auth[id] : g_iMenuOption_ip[id]);
				
				/////
				new l_name[30];
				get_user_name( id, l_name, 29 );
				new l_authid[30];
				get_user_authid(id,l_authid,29);
				console_print(id, "[AMXX] %s,%s,%s,%s", g_iMenuSettings[id] ? "Ban IP" : "Ban Auth", g_iMenuOption_auth[id],g_iMenuOption_ip[id],g_iMenuOption_name[id]);				
				
				log_amx("Cmd: ^"%s<%d><%s><>^" ban ^"%s,%s,%s,%s^"", l_name, get_user_userid(id), l_authid, g_iMenuSettings[id] ? "Ban IP" : "Ban Auth", g_iMenuOption_auth[id],g_iMenuOption_ip[id],g_iMenuOption_name[id]);

				/////
				g_iMenuOption_auth[id] = " ";
            }
			else if(g_iMenuSettings[id] == 0)
			{
			    g_iMenuSettings[id] = 1;
			}
			else
			{
			    g_iMenuSettings[id] = 0;
			}
                 
            showBanOldMenu( id );
        }
        case 8: {
			g_iMenuOption_auth[id] = " ";
			++g_iMenuPosition[id];
			showBanOldMenu( id ); // More Option
		}
        case 9: {
			g_iMenuOption_auth[id] = " ";
			--g_iMenuPosition[id];
			showBanOldMenu( id ); // Back Option
		}

        default:
        {
            new player = g_iMenuPosition[id] * MENU_PLAYERS + key;

            g_iMenuOption_auth[id] = g_iMenuPlayers_auth[player];
            g_iMenuOption_name[id] = g_iMenuPlayers_name[player];
            g_iMenuOption_ip[id] = g_iMenuPlayers_ip[player];

            showBanOldMenu( id );
        }
    }
    return PLUGIN_HANDLED
}

public client_disconnect(id)
{
   new l_authid[30];
   get_user_authid(id,l_authid,29);
   
   new l_name[30];
   get_user_name( id, l_name, 29 );
   
   new l_ip[30];
   get_user_ip( id, l_ip, 29, 1 );
   
   if( !(get_user_flags(id) & ADMIN_IMMUNITY) && !is_user_bot(id) )
   {
		copy(g_iMenuPlayers_auth[g_iMenuOldInsertPos],29,l_authid);
		copy(g_iMenuPlayers_name[g_iMenuOldInsertPos],29,l_name);
		copy(g_iMenuPlayers_ip[g_iMenuOldInsertPos],29,l_ip);
		
		g_iMenuOldCounter++;
		g_iMenuOldInsertPos++;
		
		if(g_iMenuOldInsertPos >= OLD_MAX)
			g_iMenuOldInsertPos = 0;
		if(g_iMenuOldCounter > OLD_MAX)
			g_iMenuOldCounter = OLD_MAX;
	}
}