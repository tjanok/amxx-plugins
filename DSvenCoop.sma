/////////////////////////////////////////////////////
// DSvenCoop.sma
// ----------------------------------
// This plugin:
// Admin System
//   - I didn't want to use AMXX's default system, it's more a VIP list.
//   - Features can be limited to VIP (Admins)
//   - There are two flags: a or b.
//
// Add's simple glowing (/glow <color>)
//   - Colors are defined in "amxmodx/configs/dcoop/glow_colors.ini"
//   - Can create they're own colors
//
// Rules
//   - Display's a list of rules upon connecting


#include <amxmodx>
#include <amxmisc>
#include <cellarray>
#include <fakemeta>
#include <engine>
#include <geoip>

new const g_SpawnSound[] = "dcoop/teleport.wav"
new g_ConnectSound[64]

#define MAX_RULES_SIZE 512
#define MAX_USER_GLOWS 3

new Array:g_GlowArray
new g_GlowNum

new g_RulesArray[MAX_RULES_SIZE]

// Player Bools
new bool:g_ShowedRules[33]
new g_GlowHardCoded[33]

// CVars
new p_Rules[6]

new m_Sprite;

public plugin_precache()
{
	new ConfigFile[256]
	get_configsdir(ConfigFile,255);
	add(ConfigFile,255,"/dcoop");
	
	if(!dir_exists(ConfigFile))
		if(mkdir(ConfigFile) != 0)
			server_print("[DSC] Unable to create DIR - This will cause problems. (%s)",ConfigFile);
	
	add(ConfigFile,255,"/rules.ini");
	
	m_Sprite = precache_model("sprites/smoke.spr");
	
	// random hl media sound
	new hlMedia[33]
	formatex(hlMedia,32,"media/Half-Life0%d.mp3",random_num(1,17));
	copy(g_ConnectSound,63,hlMedia);
	
	precache_sound(g_SpawnSound);
	
	// Load up rules
	new pFile = fopen(ConfigFile,"r+"),Buffer[256]
	if(!pFile)
		server_print("[DSC] Unable to open rules file. (%s)",ConfigFile);
	else
	{
		while(!feof(pFile))
		{
			fgets(pFile,Buffer,255);
			
			if(!Buffer[0])
				continue
			
			add(g_RulesArray,MAX_RULES_SIZE - 1,Buffer);
		}
		fclose(pFile);
	}
	
	// Lol
	replace_all(ConfigFile,255,"rules.ini","glow_colors.ini");
	pFile = fopen(ConfigFile,"r+");
	if(!pFile)
		server_print("[DSC] Unable to open glow colors file. (%s)",ConfigFile);
	else
	{
		// usa "255 255 255"
		new Color[20],ColorRGB[64],ColorR[4],ColorG[4],ColorB[4],SteamID[36]
		g_GlowArray = ArrayCreate();
		
		while(!feof(pFile))
		{
			fgets(pFile,Buffer,255);
			
			if(!Buffer[0] || Buffer[0] == '-')
				continue
			
			strbreak(Buffer,Color,19,ColorRGB,63)
			remove_quotes(ColorRGB);
			parse(ColorRGB,ColorR,3,ColorG,3,ColorB,3,SteamID,35);
			
			new Array:CurArray = ArrayCreate(24);
			ArrayPushCell(g_GlowArray,CurArray);
			
			ArrayPushString(CurArray,Color);
			ArrayPushCell(CurArray,str_to_num(ColorR));
			ArrayPushCell(CurArray,str_to_num(ColorG));
			ArrayPushCell(CurArray,str_to_num(ColorB));
			
			// even if this doesn't have a steam id, we gotta push something
			ArrayPushString(CurArray,SteamID);
			
			g_GlowNum++
		}
	}
	fclose(pFile);
	
	// CVars
	p_Rules[0] = register_cvar("SCD_ShowRules","1");
	p_Rules[1] = register_cvar("SCD_RulesR","200");
	p_Rules[2] = register_cvar("SCD_RulesG","26");
	p_Rules[3] = register_cvar("SCD_RulesB","26");
	p_Rules[4] = register_cvar("SCD_RulesX","0.65");
	p_Rules[5] = register_cvar("SCD_RulesY","-0.70");
}

public plugin_init()
{
	// Main
	register_plugin("DCoop Addon","0.1a","Drak");
	
	// Commmands
	register_concmd("amx_showrules","CmdShowRules",ADMIN_BAN,"Shows the list of rules in a HUD Message");
	register_srvcmd("amx_dumpmaps","CmdMapDump");
	
	// Chat Commands
	register_clcmd("say","CmdSay");
	register_clcmd("say_team","CmdSay");

	// Events
	register_event("ResetHUD","Event_ResetHUD","be");
	
	register_forward(FM_SetModel,"Forward_SetModel",0);
	
	// hardcoded
	server_cmd("exec addons/amxmodx/configs/dcoop/config.cfg");
}

public Forward_SetModel(Ent,const Model[])
{
	// set RPG rocket trail some color we are glowing
	// or if we are not glowing, random!
	
	if(equali(Model,"models/rpgrocket.mdl"))
	{
		message_begin(MSG_BROADCAST,SVC_TEMPENTITY,_,Ent);
		write_byte(TE_BEAMFOLLOW);
		write_short(Ent);
		write_short(m_Sprite);
		write_byte(20);
		write_byte(20);
		write_byte(random_num(1,255));
		write_byte(random_num(1,255));
		write_byte(random_num(1,255));
		write_byte(255);
		message_end();
	}
	
}

public client_disconnect(id)
{
	g_ShowedRules[id] = false
	g_GlowHardCoded[id] = 0
}

public client_putinserver(id)
{
	if(g_ConnectSound[0])
	{
		client_cmd(id,"mp3 stop");
		client_cmd(id,"stopsound");
	}
	
	g_ShowedRules[id] = false
	g_GlowHardCoded[id] = 0
}
public CmdMapDump(id)
{
	// your not the server
	if(id != 0)
		return PLUGIN_HANDLED
	
	if(file_exists("map_list.txt"))
		delete_file("map_list.txt");
		
	new pFile = fopen("map_list.txt","w+");
	new pBuffer[128]
	new handleDir = open_dir("maps",pBuffer,127);
	
	while(next_file(handleDir,pBuffer,127))
	{
		if(containi(pBuffer,".bsp") != -1)
		{
			replace_all(pBuffer,127,".bsp","");
			add(pBuffer,127,"^n");
			fputs(pFile,pBuffer);
		}
	}
	
	fclose(pFile);
	close_dir(handleDir);
	server_print("[AMXX] Maps dumped to map_list.txt in the game dir");
	
	return PLUGIN_HANDLED
}
/*==================================================================================================================================================*/
// Player Commands
public CmdSay(id)
{
	if(!is_user_alive(id))
		return PLUGIN_CONTINUE
	
	static Arg[64]
	read_args(Arg,63);
	
	trim(Arg);
	remove_quotes(Arg);
	
	if(Arg[0] == '/')
	{
		if(equali(Arg,"/glow ",6))
		{
			new Temp[2],Colors[25]
			parse(Arg,Temp,1,Colors,23);
			
			// We are giving a R G B value
			if(is_str_num(Colors))
			{
				new ColorRGB[4][3]
				parse(Arg,Temp,1,ColorRGB[0],3,ColorRGB[1],3,ColorRGB[2],3);
				
				if(!ColorRGB[0][0] || !ColorRGB[1][0] || !ColorRGB[2][0])
				{
					client_print(id,print_chat,"[AMXX] Usage: /glow <color name> or /glow <#red> <#green> <#blue>^nExample: (ie: /glow 255 0 0) or /glow list");
					return PLUGIN_HANDLED
				}
				
				set_rendering(id,kRenderFxGlowShell,str_to_num(ColorRGB[0]),str_to_num(ColorRGB[1]),str_to_num(ColorRGB[2]));
				client_print(id,print_chat,"[AMXX] You are now glowing! Type /glow off to stop!");
				
				return PLUGIN_HANDLED
			}
			else
			{
				new ColorName[25],Found = 0
				if(equali(Colors,"list"))
				{
					new ColorList[256],Pos
					
					for(new Count;Count < g_GlowNum;Count++)
					{
						ArrayGetString(ArrayGetCell(g_GlowArray,Count),0,ColorName,24);
						Pos += formatex(ColorList[Pos],255 - Pos,"%d. %s^n",Count + 1,ColorName);
					}
					
					Pos += formatex(ColorList[Pos],255 - Pos,"Type /glow <namehere> to start glowing that color!");
					show_motd(id,ColorList,"Glow Names");
					
					return PLUGIN_HANDLED
				}
				else if(equali(Colors,"off") || equali(Colors,"stop"))
				{
					set_rendering(id);
					client_print(id,print_chat,"[AMXX] You have stopped glowing.");
					
					g_GlowHardCoded[id] = 0
					
					return PLUGIN_HANDLED
				}
				else if(equali(Colors,"help"))
				{
					show_motd(id,"addons/amxmodx/configs/glow_help.txt","Glow Help")
					return PLUGIN_HANDLED
				}
				else if(equali(Colors,"add"))
				{
					new SteamID[36],ASteamID[36]
					get_user_authid(id,SteamID,35);
					
					new IDCount = 0
					new ColorR[12],ColorG[12],ColorB[12]
					new ColorName[33],AColorName[33]
					
					remove_quotes(Arg);
					trim(Arg);
					
					parse(Arg,Temp,1,Temp,1,ColorName,32,ColorR,11,ColorG,11,ColorB,11);
					
					if(!ColorName[0] || !ColorR[0] || !ColorG[0] || !ColorB[0])
					{
						client_print(id,print_chat,"[AMXX] Usage: /glow add <color name> <red> <green> <blue>");
						return PLUGIN_HANDLED
					}
					
					if(equali(ColorName,"help") || equali(ColorName,"usa") || equali(ColorName,"police"))
					{
						client_print(id,print_chat,"[AMXX] Invalid glow name. Name is taken or invalid");
						return PLUGIN_HANDLED
					}
					
					for(new Count;Count < g_GlowNum;Count++)
					{
						new Array:CurArray = ArrayGetCell(g_GlowArray,Count);
						ArrayGetString(CurArray,4,ASteamID,35);
						ArrayGetString(CurArray,0,AColorName,32);
						
						if(equali(SteamID,ASteamID))
							IDCount++
						
						if(equali(ColorName,AColorName))
						{
							client_print(id,print_chat,"[AMXX] Unable to add. ^"%s^" glow color already exists.",ColorName);
							return PLUGIN_HANDLED
						}
					}
					
					if(IDCount >= MAX_USER_GLOWS)
					{
						client_print(id,print_chat,"[AMXX] You're only allowed a max of %d custom glows. Type /glow remove <name> to remove a color you added",MAX_USER_GLOWS);
						return PLUGIN_HANDLED
					}
					
					client_print(id,print_chat,"[AMXX] You added color ^"%s^" to the glow list!",ColorName);
					
					new Array:CurArray = ArrayCreate(24);
					ArrayPushCell(g_GlowArray,CurArray);
					
					ArrayPushString(CurArray,ColorName);
					ArrayPushCell(CurArray,str_to_num(ColorR));
					ArrayPushCell(CurArray,str_to_num(ColorG));
					ArrayPushCell(CurArray,str_to_num(ColorB));
					
					ArrayPushString(CurArray,SteamID);
					g_GlowNum++
					
					SaveGlowFile();
					
					return PLUGIN_HANDLED
					
				}
				
				// Glow a name
				// Check for hard-coded colors first
				else if(equali(Colors,"usa"))
					{ HardGlow(id,1); Found = 1; }
				else if(equali(Colors,"police"))
					{ HardGlow(id,2); Found = 1; }
				
				else
				{
					for(new Count;Count < g_GlowNum;Count++)
					{
						new Array:CurArray = ArrayGetCell(g_GlowArray,Count);
						ArrayGetString(CurArray,0,ColorName,25);
						
						if(equali(ColorName,Colors))
						{
							set_rendering(id,kRenderFxGlowShell,ArrayGetCell(CurArray,1),ArrayGetCell(CurArray,2),ArrayGetCell(CurArray,3));
							Found = 1
						}
					}
				}
				
				if(Found)
					client_print(id,print_chat,"[AMXX] You are now glowing color: %s - You can also glow /glow <red> <green> <blue>",Colors);
				else
					client_print(id,print_chat,"[AMXX] Color ^"%s^" not found. Use /glow list to find a color.",Colors);
				
				return PLUGIN_HANDLED
			}
		}
		else if(equali(Arg,"/help"))
			return show_motd(id,"addons/amxmodx/configs/dcoop/help.txt","Help");
	}
	
	if(containi(Arg,"glow") != -1)
		client_print(id,print_chat,"[AMXX] Are you trying to glow? Type /glow <color>");
	
	return PLUGIN_CONTINUE
}

public GlowTask(Params[])
{
	new id = Params[2]
	
	if(!g_GlowHardCoded[id] || !is_user_alive(id))
	{
		g_GlowHardCoded[id] = 0
		return
	}
	
	new Mode = Params[0],Step = Params[1]
	Params[1]++
	
	switch(Mode)
	{
		// USA
		case 1:
		{
			if(Step == 0)
				set_rendering(id,kRenderFxGlowShell,200,15,15);
			else if(Step == 1)
				set_rendering(id,kRenderFxGlowShell,200,200,200);
			else if(Step == 2)
			{
				set_rendering(id,kRenderFxGlowShell,15,15,200);
				Params[1] = 0
			}
		}
		
		// Police
		case 2:
		{
			if(!Step)
				set_rendering(id,kRenderFxGlowShell,200,15,15);
			else
			{
				set_rendering(id,kRenderFxGlowShell,15,15,200);
				Params[1] = 0
			}
		}
	}
	set_task(Mode == 1 ? 1.0 : 0.2,"GlowTask",id + 366,Params,3);
}
HardGlow(id,Color)
{
	new Params[3]
	Params[0] = Color
	Params[1] = 0
	Params[2] = id
	
	g_GlowHardCoded[id] = 1
	
	set_task(1.0,"GlowTask",id + 366,Params,3);
	return PLUGIN_HANDLED
}
SaveGlowFile()
{
	new const fFile[] = "addons/amxmodx/configs/dcoop/glow_colors.ini"
	if(file_exists(fFile))
		delete_file(fFile);
	
	new pFile = fopen(fFile,"w+");
	new ColorName[25],ColorRGB[3],SteamID[36]
	new pBuffer[128]
	
	for(new Count;Count < g_GlowNum;Count++)
	{
		new Array:CurArray = ArrayGetCell(g_GlowArray,Count);
		
		ArrayGetString(CurArray,0,ColorName,25);
		ColorRGB[0] = ArrayGetCell(CurArray,1);
		ColorRGB[1] = ArrayGetCell(CurArray,2);
		ColorRGB[2] = ArrayGetCell(CurArray,3)
		ArrayGetString(CurArray,4,SteamID,35);
		
		formatex(pBuffer,127,"%s %d %d %d %s^n",ColorName,ColorRGB[0],ColorRGB[1],ColorRGB[2],SteamID);
		fputs(pFile,pBuffer);
	}
	fclose(pFile);
}
/*==================================================================================================================================================*/
// Admins Commands
public CmdShowRules(id,level,cid)
{
	if(!cmd_access(id,level,cid,1))
		return PLUGIN_HANDLED
	
	new iPlayers[32],iNum
	get_players(iPlayers,iNum);
	
	for(new Count;Count < iNum;Count++)
		ShowRules(iPlayers[Count]);
	
	client_print(id,print_console,"[AMXX] Rules Shown.");
	return PLUGIN_HANDLED
}
/*==================================================================================================================================================*/
// Player Connecting
public client_connect(id)
{
	if(is_user_bot(id))
		return
	
	// Join Sound
	if(g_ConnectSound[0])
		client_cmd(id,"mp3 play ^"%s^"",g_ConnectSound);
	
	static UserIP[36],Country[46]
	get_user_ip(id,UserIP,25,1);
	
	if(!UserIP[0] || containi(UserIP,"192.168.1") != -1)
		return
	
	geoip_country(UserIP,Country);
	get_user_name(id,UserIP,35);
	
	client_print(0,print_chat,"Player: %s - Connecting From: %s",UserIP,Country);
	server_print("[AMXX] User: %s Connecting From: %s",UserIP,Country);
}
/*==================================================================================================================================================*/
public Event_ResetHUD(id)
{
	if(!is_user_alive(id))
		return
	
	static Origin[3]
	get_user_origin(id,Origin);
	
	message_begin(MSG_PVS,SVC_TEMPENTITY,Origin,id);
	write_byte(TE_TELEPORT);
	
	write_coord(Origin[0]);
	write_coord(Origin[1]);
	write_coord(Origin[2]);
	
	message_end();
	
	if(g_SpawnSound[0])
		emit_sound(id,CHAN_AUTO,g_SpawnSound,VOL_NORM,ATTN_NORM,0,PITCH_NORM);
	
	if(!g_ShowedRules[id])
		set_task(8.0,"ShowRules",id);
}
	
public ShowRules(id)
{
	g_ShowedRules[id] = true
	
	if(!get_pcvar_num(p_Rules[0]))
		return PLUGIN_HANDLED
	
	set_hudmessage(get_pcvar_num(p_Rules[1]),get_pcvar_num(p_Rules[2]),get_pcvar_num(p_Rules[3]),get_pcvar_float(p_Rules[4]),get_pcvar_float(p_Rules[5]),2,10.0,20.0,_,_,-1);
	show_hudmessage(id,"%s",g_RulesArray);
	
	new plName[33]
	get_user_name(id,plName,32);
	
	client_print(id,print_chat,"Welcome, %s. Please enjoy your stay. Type /help for more information",plName);
	return PLUGIN_HANDLED
}

public plugin_end()
{
}