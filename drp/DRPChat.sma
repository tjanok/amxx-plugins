/*
* DRPTalkarea.sma
* -------------------------------------
* Author(s):
* Drak - Main Auhtor
* Hawk - Everything
* ---------------------------------
* Changelog:
* -----------------------------------------------------------------------------
* 0/0/00
* -----------------------------------------------------------------------------
*/

#include <amxmodx>
#include <amxmisc>
#include <fakemeta>

#include <drp/drp_core>

#define MAX_LINES 6
#define MAX_CALLS 6

#define MAX_ADS 3 // how many ads can a person have
#define MAX_ADS_TIME 4 // the time in days an ad will remain saved
#define MAX_ARTICLE_TIME 8 // the time in days before a newspaper story get's pushed into an archive

#define BASE_DISTANCE 310.0

#define ANSWER_ITEMS 3
#define STATUS_SETTINGS 2
#define RING_SETTINGS 4

#define MODE_DEACTIVATING -1

#define PHONE_RING_OFFSET 1983712739

#define REGISTER 0
#define CALL 1
#define PAYPHONE 2

#define EX_TEXTING (1<<0)
#define EX_CUSTOM_RINGTONES (1<<1)
#define EX_CALLER_ID (1<<2)
#define EX_BLOCK_CALLER_ID (1<<3)
#define EX_BLOCK_PHONEBOOK (1<<4)

new g_Query[256]
new Handle:g_SqlHandle

new const g_PhoneTable[] = "Phones"

new g_OOCText[MAX_LINES][128]
new g_911Calls[MAX_CALLS][128]

new Float:g_LastCnn[33]

enum _:PHONE
{
	MODE = 0,
	RING,
	CALLER,
	CALLING,
	TALKING,
	RINGING,
	TIME,
	EXTRA
}

new const g_RingSettings[RING_SETTINGS][] =
{
	"Ring",
	"Vibrate",
	"Silent",
	"Custom"
}

// PCvars
new p_Ooc
new p_Cnn
new p_911
new p_AdvertPrice[2]
new p_Capscom
new p_Printconsole
new p_Printmode
new p_OocTitle
new p_Range
new p_FeaturePrices[5]
new p_Refresh

// Items
new g_iPhone
new g_Aria
new g_Droid
new g_Radio
new g_Subscription

// Menus
new g_MenuPhone
new g_MenuDialNumber

new g_UserBugged[33]
new g_UserNumber[33][7]

new g_UserPhone[33][PHONE]
new g_UserPNum[33][12]
new g_UserFunc[33]

new g_UserTalkTimer[2][33]

new Trie:g_SayTrie

new g_DMenu
new g_CMenu
new g_NewspaperMenu

// HACK-HACK
new bool:g_PhoneCache[33]
new bool:g_EmergencyHud[33]

new g_911Reply[33]
new g_Reporter

// I don't feel like re-nameing these, but
// g_NewspaperArray is for Advertisments - and g_WorldNews is the newspaper
new Array:g_NewspaperArray
new Array:g_WorldNews

new g_UserRadioChannel[33]

public plugin_precache()
{
	// Sounds
	precache_sound(g_SmsSound);
	precache_sound(g_RingSound);
	precache_sound(g_ScanSound);
	precache_sound(g_FoundSound);
	precache_sound(g_VibrateSound);
	precache_sound(g_NotFoundSound);
	
	precache_generic("sound/OZDRP/phone/1.wav");
	precache_sound("OZDRP/phone/2.wav"); // used in emit_sound() by items
	precache_generic("sound/OZDRP/phone/3.wav");
	precache_generic("sound/OZDRP/phone/4.wav");
	precache_generic("sound/OZDRP/phone/5.wav");
	precache_generic("sound/OZDRP/phone/6.wav");
	precache_generic("sound/OZDRP/phone/7.wav");
	precache_generic("sound/OZDRP/phone/8.wav");
	precache_generic("sound/OZDRP/phone/9.wav");
	precache_generic("sound/OZDRP/phone/0.wav");
	
	precache_generic("sound/OZDRP/phone/busy_doriginal.wav");
	precache_generic("sound/OZDRP/phone/error_doriginal.wav");
	
	precache_generic(g_OOCSound);
	
	// Models
	precache_model(g_szVPhoneMdl);
	precache_model(g_szPPhoneMdl);
	
	// Custom ringtones (always precache_generic())
	
	new Dir[128]
	copy(Dir,127,"sound/OZDRP/ringtones");
	
	//if(!dir_exists(Dir))
	//	if(mkdir(Dir) != 0)
		//	DRP_Log("Unable to make `RingTone` Dir (%s) - Please Fix.",Dir);
	
	new File[128]
	new FileDir = open_dir(Dir,File,127);
	
	while(next_file(FileDir,File,127))
	{
		if(containi(File,".wav") == -1)
			continue
		
		format(File,127,"sound/OZDRP/ringtones/%s",File);
		//precache_generic(File);
		
		server_print("%s",File);
	}
	
	close_dir(FileDir);
	
	g_SayTrie = TrieCreate();
	//g_NewspaperArray = ArrayCreate(512);
	//g_WorldNews = ArrayCreate(512);
}

public plugin_natives()
{
	register_library("drp_chat");
	register_native("DRP_AddChat","_DRP_AddChat");
}

public _DRP_AddChat(Plugin,Params)
{
	if(Params != 2)
	{
		log_error(AMX_ERR_NATIVE,"Parameters do not match. Expected: 2, Found: %d",Params);
		return FAILED
	}
	
	new Temp[64],Params[64]
	get_string(1,Params,63);
	get_string(2,Temp,63);
	
	format(Temp,63,"%d|%s",Plugin,Temp);
	TrieSetString(g_SayTrie,Temp,Params);
	
	return SUCCEEDED
}
public plugin_init()
{
	register_plugin("DRP - Talkarea","0.1a","Drak");
	
	// Commands
	register_clcmd("say","Say_Handle");
	register_clcmd("say_team","Say_Handle");
	
	DRP_AddCommand("say_team","<text> - chatting in ^"team say^" types in OOC");
	
	DRP_AddCommand("say /shout","<message> - shouts message");
	DRP_AddCommand("say /cnn","<message> - sends news headline");
	DRP_AddCommand("say /advert","<message> - place an advertisment (Advertising Charges May Apply)");
	DRP_AddCommand("say /ooc","<message> - sends message as OOC (Out Of Character)");
	DRP_AddCommand("say /me","<action> - performs action");
	DRP_AddCommand("say /quiet","<message> - whispers a message (can only be heard a very short distance)");
	DRP_AddCommand("say //","<message> - types a message in OOC (only nearby players can hear this ooc message)");
	DRP_AddCommand("say /radio","<message> - sends a message to the radio channel you're connected to.");
	
	// Menus
	//register_menucmd(register_menuid(g_MainPhoneMenu),g_Keys,"_PhoneMenu");
	//register_menucmd(register_menuid(g_DialPhoneMenu),g_Keys,"_DialNumberMenu");
	//register_menucmd(register_menuid(g_FeatureMenu),MENU_KEY_0|MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4,"_FeatureMenu");
	g_MenuDialNumber = menu_create("", "_PhoneMenu");
	menu_additem(g_MenuDialNumber, "1. One"); menu_additem(g_MenuDialNumber, "2. One"); menu_additem(g_MenuDialNumber, "3. One"); menu_additem(g_MenuDialNumber, "4. One");
	menu_additem(g_MenuDialNumber, "5. One"); menu_additem(g_MenuDialNumber, "6. One"); menu_additem(g_MenuDialNumber, "7. One"); menu_additem(g_MenuDialNumber, "8. One");
	menu_additem(g_MenuDialNumber, "9. One");
	
	DRP_AddCommand("say /a","<message> - sends a message to the admin team");
	DRP_AddCommand("say /com","(COP/MEDIC) <message> - sends message to all cops (or medics)");
	DRP_AddCommand("say /emhud","(COP/MEDIC) - toggles the emergency hud on/off.");
	DRP_AddCommand("say /911","- place/reply to a 911 call");
	DRP_AddCommand("say /hangup","- hangs up phone");
	DRP_AddCommand("say /phone"," - brings up the phone menu");
	DRP_AddCommand("say /sms","<user> <message> - sends a sms/txt message to the user");
	DRP_AddCommand("say /dial","<number> - quick dials a number.");
	
	CreateMenus();
	
	// Forwards
	register_forward(FM_PlayerPreThink,"forward_PreThink");
	
	// Events
	register_event("DeathMsg","EventDeathMsg","a");
	
	DRP_RegisterEvent("Player_Ready","Player_Ready");
	DRP_RegisterEvent("Player_ChangeJobID","Player_ChangeJobID");
	
	// Tasks
	set_task(get_cvar_float("DRP_OOCRefresh"),"OOCRefresh",_,_,_,"b");
}

public DRP_Error(const Reason[])
	pause("d");

public EventDeathMsg()
{
	new const id = read_data(2);
	if(!id)
		return
	
	g_UserBugged[id] = 0
	g_UserFunc[id] = 0
	g_PhoneCache[id] = false
	
	BreakLine(id,"'s line has gone dead.");
	End911Call(id);
}
public client_disconnect(id)
{
	BreakLine(id," has disconnected. The phone call has been canceled.");
	End911Call(id);
}
End911Call(id)
{
	if(g_911Reply[id])
	{
		if(is_user_connected(g_911Reply[id]))
			client_print(g_911Reply[id],print_chat,"[DRP] The emergency call has been ended.");
		
		g_911Reply[g_911Reply[id]] = 0
		g_911Reply[id] = 0
		
		new Cache[33]
		get_user_name(id,Cache,32);
		
		for(new Count;Count < MAX_CALLS;Count++)
			if(containi(g_911Calls[Count],Cache) != -1)
				g_911Calls[Count] = ""
	}
}
public client_authorized(id)
{
	if(is_user_bot(id))
		return
	
	arrayset(g_UserPhone[id],0,8);
	
	g_UserBugged[id] = 0
	g_UserFunc[id] = 0
	g_UserRadioChannel[id] = 0
	
	g_UserTalkTimer[0][id] = 0
	g_UserTalkTimer[1][id] = 0
	
	g_PhoneCache[id] = false
	g_EmergencyHud[id] = false
	
	new AuthID[36],Data[1]
	get_user_authid(id,AuthID,35);
	
	Data[0] = id
	
	format(g_Query,sizeof g_Query - 1,"SELECT * FROM %s WHERE SteamID='%s'",g_PhoneTable,AuthID);
	SQL_ThreadQuery(g_SqlHandle,"FetchPhoneData",g_Query,Data,1);
}
public FetchPhoneData(FailState,Handle:Query,const Error[],Errcode,const Data[],DataSize) 
{
	if(FailState != TQUERY_SUCCESS || Errcode)
		return log_amx("[DRP-TALKAREA] SQL Failure (Error: %s)",Error ? Error : "UNKNOWN");
	
	new const id = Data[0]
	
	if(!SQL_NumResults(Query))
	{
		new AuthID[36]
		get_user_authid(id,AuthID,35);
		
		format(g_Query,sizeof g_Query - 1,"INSERT INTO `%s` VALUES('%s','','0','','','')",g_PhoneTable,AuthID);
		SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",g_Query);
		
		return PLUGIN_CONTINUE
	}
	
	new Cache[12]
	SQL_ReadResult(Query,1,g_UserPNum[id],11);
	g_UserPhone[id][TIME] = SQL_ReadResult(Query,2);
	
	SQL_ReadResult(Query,3,Cache,11);
	g_UserPhone[id][EXTRA] = read_flags(Cache);
	
	return PLUGIN_CONTINUE
}

public forward_PreThink(id)
{
	if(!g_PhoneCache[id] || !is_user_alive(id))
		return
	
	static WeaponMDL[36],Button
	pev(id,pev_viewmodel2,WeaponMDL,35);
	
	Button = pev(id,pev_button);

	if(!equal(WeaponMDL,g_szVPhoneMdl))
		UTIL_SetPhoneModel(id);
	
	if(Button != 0)
		set_pev(id,pev_button,Button & ~IN_ATTACK & ~IN_ATTACK2 & ~IN_ALT1);
}

// Turn on when we connect (and we are a cop/medic)
// Turn on when we change job to a cop/medic
public Player_Ready(const Name[],const Data[],const Len)
{
	new const id = Data[0]
	if(DRP_IsCop(id) || DRP_IsMedic(id)) //override is_player_connected()
		g_EmergencyHud[id] = true
	else
		g_EmergencyHud[id] = false
}
public Player_ChangeJobID(const Name[],const Data[],const Len)
{
	new const id = Data[0]
	if(DRP_IsCop(id) || DRP_IsMedic(id))
		g_EmergencyHud[id] = true
	else
		g_EmergencyHud[id] = false
}
/*==================================================================================================================================================*/
public DRP_Init()
{
	g_SqlHandle = DRP_SqlHandle();
	
	// CVars
	register_cvar("DRP_OOCRefresh","10");
	
	p_Ooc = register_cvar("DRP_OOC","1");
	p_Cnn = register_cvar("DRP_CNN","120"); 
	p_911 = register_cvar("DRP_911Hud","1");
	
	p_Capscom = register_cvar("DRP_CapsCom","1");
	p_Printconsole = register_cvar("DRP_PrintToConsole","1");
	p_Printmode = register_cvar("DRP_PrintMode","1");
	p_Range = register_cvar("DRP_MessageRange","1.0");
	p_OocTitle = register_cvar("DRP_OOCTitle","<< OOC Chat >>");
	
	p_FeaturePrices[0] = register_cvar("DRP_EX_SMSPrice","10");
	p_FeaturePrices[1] = register_cvar("DRP_EX_RingTonePrice","11");
	p_FeaturePrices[2] = register_cvar("DRP_EX_CallerIDPrice","12");
	p_FeaturePrices[3] = register_cvar("DRP_EX_CIDBlockerPrice","13");
	
	p_AdvertPrice[0] = register_cvar("DRP_AdvertChatPrice","100");
	p_AdvertPrice[1] = register_cvar("DRP_AdvertPaperPrice","105");
	
	
	format(g_Query,sizeof g_Query - 1,"CREATE TABLE IF NOT EXISTS %s (SteamID VARCHAR(36),PhoneNumber VARCHAR(32),PhoneTime INT(12),ExtraFeatures VARCHAR(32),PlayerName VARCHAR(32),Ringtone VARCHAR(32),PRIMARY KEY (SteamID))",g_PhoneTable);
	SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",g_Query);
	
	format(g_Query,sizeof g_Query - 1,"SELECT * FROM `newspaper_ads`");
	SQL_ThreadQuery(g_SqlHandle,"FetchNewspaperAds",g_Query);
	
	format(g_Query,sizeof g_Query - 1,"SELECT * FROM `newspaper`");
	SQL_ThreadQuery(g_SqlHandle,"FetchNewspaperData",g_Query);
}
public FetchNewspaperData(FailState,Handle:Query,const Error[],Errcode,const Data[],DataSize)
{
	if(FailState != TQUERY_SUCCESS)
		return log_amx("Unable to Query. Error: %s",Error ? Error : "UNKNOWN");
	
	if(!SQL_NumResults(Query))
		return PLUGIN_CONTINUE
	
	new Message[256],plName[33]
	new Date[24],szYear[12],szMonth[12],szDay[12]
	new iYear,iMonth,iDay
	
	DRP_GetWorldTime(Date,23,4);
	parse(Date,szYear,11,szMonth,11,szDay,11);
	
	iYear = str_to_num(szYear);
	iMonth = str_to_num(szMonth);
	iDay = str_to_num(szDay);
	
	new sqlYear[12],sqlMonth[12],sqlDay[12],Delete = 0
	
	while(SQL_MoreResults(Query))
	{
		// Check date
		SQL_ReadResult(Query,2,Message,255);
		parse(Message,sqlYear,11,sqlMonth,11,sqlDay,11);
		
		//sDay = str_to_num(sqlDay);
		
		if(iYear > str_to_num(sqlYear))
			Delete = 1
		else if( (iMonth == str_to_num(sqlMonth)) && (iDay - str_to_num(sqlDay)) > MAX_ADS_TIME )
			Delete = 1
		else if( (iMonth != str_to_num(sqlMonth)) && (iDay + str_to_num(sqlDay) ) - (str_to_num(sqlDay)) > MAX_ADS_TIME )
			Delete = 1
		else
			Delete = 0
		
		if(Delete)
		{
			format(g_Query,sizeof g_Query - 1,"DELETE FROM `newspaper` WHERE `DatePosted`='%s %s %s'",sqlYear,sqlMonth,sqlDay);
			SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",g_Query);
			
			SQL_ReadResult(Query,0,plName,32)
			SQL_ReadResult(Query,1,g_Query,255);
			
			// Copy to archive
			format(g_Query,sizeof g_Query - 1,"INSERT INTO `newspaper_archive` VALUES('%s','%s','%s')",plName,g_Query,Message);
			SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",g_Query);
			
			SQL_NextRow(Query);
			return PLUGIN_HANDLED
		}
		
		SQL_ReadResult(Query,2,plName,32);
		SQL_ReadResult(Query,1,g_Query,255);
		
		formatex(Message,255,"%s| %s",plName,g_Query);
		ArrayPushString(g_WorldNews,Message);
		
		SQL_NextRow(Query);
	}
}

public FetchNewspaperAds(FailState,Handle:Query,const Error[],Errcode,const Data[],DataSize)
{
	if(FailState != TQUERY_SUCCESS)
		return log_amx("Unable to Query. Error: %s",Error ? Error : "UNKNOWN");
	
	if(!SQL_NumResults(Query))
		return PLUGIN_CONTINUE
	
	new Message[256],plName[33]
	new Date[24],szYear[12],szMonth[12],szDay[12]
	new iYear,iMonth,iDay
	
	DRP_GetWorldTime(Date,23,4);
	parse(Date,szYear,11,szMonth,11,szDay,11);
	
	iYear = str_to_num(szYear);
	iMonth = str_to_num(szMonth);
	iDay = str_to_num(szDay);
	
	new sqlYear[12],sqlMonth[12],sqlDay[12],Delete = 0
	
	while(SQL_MoreResults(Query))
	{
		// Check date
		SQL_ReadResult(Query,3,Message,255);
		parse(Message,sqlYear,11,sqlMonth,11,sqlDay,11);
		
		//sDay = str_to_num(sqlDay);
		
		if(iYear > str_to_num(sqlYear))
			Delete = 1
		else if( (iMonth == str_to_num(sqlMonth)) && (iDay - str_to_num(sqlDay)) > MAX_ADS_TIME )
			Delete = 1
		else if( (iMonth != str_to_num(sqlMonth)) && (iDay + str_to_num(sqlDay) ) - (str_to_num(sqlDay)) > MAX_ADS_TIME )
			Delete = 1
		else
			Delete = 0
		
		if(Delete)
		{
			format(g_Query,sizeof g_Query - 1,"DELETE FROM `newspaper_ads` WHERE `AdvertDate`='%s %s %s'",sqlYear,sqlMonth,sqlDay);
			SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",g_Query);
			
			SQL_NextRow(Query);
			return PLUGIN_HANDLED
		}
		
		SQL_ReadResult(Query,0,Message,255);
		SQL_ReadResult(Query,1,g_Query,255);
		SQL_ReadResult(Query,2,plName,32);
		
		format(Message,255,"%s|%s: %s",g_Query,plName,Message);
		ArrayPushString(g_NewspaperArray,Message);
		
		SQL_NextRow(Query);
	}
	
	return PLUGIN_CONTINUE
}

public DRP_JobInit()
{
	new Results[1]
	DRP_FindJobID("Reporter",Results,1); // should be default with sql
	
	if(DRP_ValidJobID(Results[0]))
		g_Reporter = Results[0]
	else
		DRP_ThrowError(0,"Unable to Find the ^"Reporter^" Job.");
}

public DRP_RegisterItems()
{
	/*
	g_iPhone = DRP_RegisterItem("Apple iPhone","_Phone","Theres probably an app for it",_,_,_);
	g_Aria = DRP_RegisterItem("Samsung Galaxy","_Phone","Smallest, sexiest Andriod phone on the market",_,_,_);
	g_Droid = DRP_RegisterItem("Motorola Droid X","_Phone","Droid Does",_,_,_);
	
	DRP_RegisterItem("Newspaper","_Newspaper","A newspaper of advertisements and latest information in the world.");
	g_Subscription = DRP_RegisterItem("Cell-Phone Subscription","_Contract","You can call as much as you want. The expenses are automaticly taken off your bank account.",0,0,0);
	g_Radio = DRP_RegisterItem("Com Radio","_Radio","Allows you to talk in a radio channel. Only the people in that channel can hear you.");
	DRP_RegisterItem("Com Radio Scanner","_RadioScan","Scans the current radio station you are connected to");
	
	DRP_RegisterItem("$80 Prepaid Phone Card","_Prepaid","A prepaid card. Lets you call for 80 mins or send 800 SMS/TXT Msgs. Minutes are in ^"Real Time^"",1,0,0,80);
	DRP_RegisterItem("$50 Prepaid Phone Card","_Prepaid","A prepaid card. Lets you call for 30 mins or send 500 SMS/TXT Msgs. Minutes are in ^"Real Time^"",1,0,0,50);
	DRP_RegisterItem("$20 Prepaid Phone Card","_Prepaid","A prepaid card. Lets you call for 10 mins or send 200 SMS/TXT Msgs. Minutes are in ^"Real Time^"",1,0,0,20);
	DRP_RegisterItem("Phonebook G2","_Phonebook","A list of all the phone numbers that are registered.",_,_,_);
	
	DRP_RegisterItem("Bug Scanner","_Scanner","Used to detect bugs",_,_,_);
	DRP_RegisterItem("Bug","_Bug","Used to tap into a user's communications and talking",_,_,_);
	*/
}
public DRP_HudDisplay(id,Hud)
{
	if(!is_user_alive(id))
		return
	
	static Title[64]
	switch(Hud)
	{
		case HUD_SEC:
		{
			if(!g_EmergencyHud[id])
				return
			
			if(!(DRP_IsCop(id) || DRP_IsMedic(id)))
				return
			
			new Title = 0
			for(new Count = 0;Count < MAX_LINES;Count++)
			{
				if(g_911Calls[Count][0])
				{
					if(!Title)
					{
						DRP_AddHudItem(id,HUD_SEC,"[911 CALLS]");
						Title = 1
					}
					DRP_AddHudItem(id,HUD_SEC,g_911Calls[Count]);
				}
			}
		}
		
		// PhoneTimer shows in HUD_PRIM
		case HUD_PRIM:
		{
			if(g_UserRadioChannel[id])
				DRP_AddHudItem(id,HUD_PRIM,"Radio Channel: #%d",g_UserRadioChannel[id]);
			
			if(!g_UserPhone[id][TALKING])
				return
			
			new const TakeFromBank = DRP_GetUserItemNum(id,g_Subscription);
			if(!TakeFromBank && g_UserPhone[id][TIME])
				DRP_AddHudItem(id,HUD_PRIM,"Phone Minutes Left: %d",g_UserPhone[id][TIME])
			
			if(++g_UserTalkTimer[0][id] < 60)
				return
				
			g_UserTalkTimer[0][id] = 0
			g_UserTalkTimer[1][id]++
			
			// we reached a minute of talking - let's take some $$$
			
			if(!TakeFromBank)
			{
				if(g_UserPhone[id][TIME] < 1)
				{
					BreakLine(id," 's phone has been cut off");
					client_print(id,print_chat,"[DRP] You have no prepaid time to continue this call.");
					return
				}
				else
				{
					g_UserPhone[id][TIME] -= 1
					SaveUserInfo(id);
				}
			}
			else
			{
				new const UserBank = DRP_GetUserBank(id);
				if(!UserBank || (UserBank - 2 < 1))
				{
					// we have a subscription - but we have no money maybe we might have prepaid time, let's check
					if(g_UserPhone[id][TIME] < 1)
					{
						BreakLine(id," 's phone has been cut off");
						client_print(id,print_chat,"[DRP] You have no prepaid time to continue this call.");
					}
					else
					{
						g_UserPhone[id][TIME] -= 1
						SaveUserInfo(id);
					}
				}
				else
				{
					DRP_SetUserBank(id,UserBank - 2);
				}
			}
		}
		case HUD_TALKAREA:
		{
			get_pcvar_string(p_OocTitle,Title,63);
			
			DRP_AddHudItem(id,HUD_TALKAREA,Title);
			
			for(new Count;Count < MAX_LINES;Count++)
				if(g_OOCText[Count][0])
					DRP_AddHudItem(id,HUD_TALKAREA,g_OOCText[Count]);
		}
	}
}
public OOCRefresh()
	RefreshMessages();
/*==================================================================================================================================================*/
// Items
public _Bug(id,ItemID)
{
	new Index,Body
	get_user_aiming(id,Index,Body,150);
	
	if(!Index || !is_user_alive(Index))
		return client_print(id,print_chat,"[DRP] You must be facing a player.");
	
	
	new Name[33],Random = random(6);
	get_user_name(Index,Name,32);
	
	if(Random < 3 || !UTIL_UserHavePhone(Index))
		return client_print(id,print_chat,"[DRP] Bug attachment failed.");
	
	if(Random == 2)
		client_print(Index,print_chat,"[DRP] Your phone flickers on and off.");
	else
		client_cmd(Index,"spk ambience/antro_projector.wav");
	
	g_UserBugged[Index] |= (1<<id);
	return client_print(id,print_chat,"[DRP] You have bugged %s.",Name)
}

public _Scanner(id,ItemID)
{
	new Index,Body
	get_user_aiming(id,Index,Body,100);
	
	if(!Index || !is_user_alive(Index))
		Index = id
	
	emit_sound(id,CHAN_ITEM,g_ScanSound,VOL_NORM,ATTN_NORM,0,PITCH_NORM);
	
	if(Index == id)
		client_print(id,print_chat,"[DRP] You begin scanning yourself.");
	else
	{
		new Name[33]
		get_user_name(id,Name,32)
		client_print(Index,print_chat,"[DRP] %s is scanning you for bugs.",Name);
		
		get_user_name(Index,Name,32)
		client_print(id,print_chat,"[DRP] You are scanning %s for bugs.",Name);
	}
	
	new Params[2]
	Params[0] = id
	Params[1] = Index
	set_task(5.0,"Scan",_,Params,2);
}

public Scan(Params[2])
{
	new id = Params[0],Index = Params[1],Players[32],Playersnum,Bugsnum
	get_players(Players,Playersnum)
	
	for(new Count;Count < Playersnum;Count++)
		if(g_UserBugged[Index] & (1<<Players[Count]))
			Bugsnum++
	
	if(Bugsnum)
	{
		emit_sound(id,CHAN_ITEM,g_FoundSound,VOL_NORM,ATTN_NORM,0,PITCH_NORM);
		
		if(Index == id)
			client_print(id,print_chat,"[DRP] You found %d %s on yourself and removed them.",Bugsnum,Bugsnum == 1 ? "bug" : "bugs");
		else
		{
			new Name[33]
			get_user_name(id,Name,32)
			client_print(Index,print_chat,"[DRP] %s scanned you and found %d %s, which was removed.",Name,Bugsnum,Bugsnum == 1 ? "bug" : "bugs");
			
			get_user_name(Index,Name,32)
			client_print(id,print_chat,"[DRP] You scanned %s and found %d %s which you removed.",Name,Bugsnum,Bugsnum == 1 ? "bug" : "bugs");
		}
	}
	else
	{
		emit_sound(id,CHAN_ITEM,g_NotFoundSound,VOL_NORM,ATTN_NORM,0,PITCH_NORM);
		
		if(Index == id)
			client_print(id,print_chat,"[DRP] You found no bugs on yourself.");
		else
		{
			new Name[33]
			get_user_name(id,Name,32);
			client_print(Index,print_chat,"[DRP] %s scanned you and found no bugs.",Name);
			
			get_user_name(Index,Name,32);
			client_print(id,print_chat,"[DRP] You scanned %s and found no bugs.",Name);
		}
	}
	
	g_UserBugged[Index] = 0
}
public _Newspaper(id)
	menu_display(id,g_NewspaperMenu);

public _Phone(id,ItemID)
{
	PhoneMenu(id);
	return ITEM_KEEP
}

public _Contract(id,ItemID)
	client_print(id,print_chat,"[DRP] Aslong as you own this item. Your phone charges will be deducted from your bank.");

public _Prepaid(id,ItemID,Amount)
{
	client_print(id,print_chat,"[DRP] You have added $%d into your phone account. (Thats %d TXT/SMS Messages)",Amount,Amount);
	g_UserPhone[id][TIME] += Amount
	
	SaveUserInfo(id);
	return
}
public _Phonebook(id)
{
	new Data[1]
	Data[0] = id
	
	format(g_Query,sizeof g_Query - 1,"SELECT * FROM %s",g_PhoneTable);
	SQL_ThreadQuery(g_SqlHandle,"GetPhoneListings",g_Query,Data,1);
	
	client_print(id,print_chat,"[DRP] Fetching Phone Information..");
}
public _Radio(id)
{
	client_print(id,print_chat,"[DRP] Join a channel by typing: /setradio <####>  -  Talk by using: /radio <message>");
	return ITEM_KEEP
}
public _RadioScan(id)
{
	if(!g_UserRadioChannel[id])
	{
		client_print(id,print_chat,"[DRP] You must be connected to a radio channel. Type /setradio <####>");
		return ITEM_KEEP
	}
	
	new Message[256],iPlayers[32],plName[33]
	new Index,iNum,Found,Pos
	get_players(iPlayers,iNum);
	
	for(new Count;Count < iNum;Count++)
	{
		Index = iPlayers[Count]
		if(!(g_UserRadioChannel[Index] == g_UserRadioChannel[id]) || Index == id)
			continue
		
		Found = 1
		get_user_name(Index,plName,32);
		
		Pos += formatex(Message[Pos],255 - Pos,"%s^n",plName);
	}
	if(!Found)
	{
		client_print(id,print_chat,"[DRP] Nobody is currently connected to this station.");
		return ITEM_KEEP
	}
	
	Pos += formatex(Message[Pos],255 - Pos,"^nAbove is the list of players connected to station:^n#%d",g_UserRadioChannel[id]);
	show_motd(id,Message,"Radio Scan");
	
	return ITEM_KEEP
}
/*==================================================================================================================================================*/
public Say_Handle(id)
{
	if(!is_user_alive(id)) 
		return PLUGIN_HANDLED
	
	static Args[256],plName[38],Message[512]
	
	read_args(Args,255);
	remove_quotes(Args);
	trim(Args);
	
	replace_all(Args,255,"%","%%");
	
	if(!Args[0])
		return PLUGIN_CONTINUE
	
	read_argv(0,plName,37);
	new const Mode = equali(plName,"say_team") ? 1 : 0
	
	/*
	new travTrieIter:Iter = GetTravTrieIterator(g_SayTrie);
	new PluginStr[12],Handler[26],Plugin,Forward,Return
	
	while(MoreTravTrie(Iter))
	{
		ReadTravTrieKey(Iter,plName,37);
		Message[0] = 0
		ReadTravTrieString(Iter,Message,511);
		
		if(!equali(Args,Message) && Message[0])
			continue
		
		strtok(plName,PluginStr,11,Handler,25,'|');
		
		Plugin = str_to_num(PluginStr);
		Forward = CreateOneForward(Plugin,Handler,FP_CELL,FP_STRING);
		
		if(Forward <= 0 || !ExecuteForward(Forward,Return,id,Args))
		{
			get_plugin(Plugin,PluginStr,11);
			DRP_ThrowError(0,"Could not execute forward to %s: %s",PluginStr,Handler);
			return PLUGIN_HANDLED
		}
		DestroyForward(Forward);
		
		switch(Return)
		{
			case PLUGIN_CONTINUE: continue;
			case PLUGIN_HANDLED: 
			{ 
				DestroyTravTrieIterator(Iter); 
				return PLUGIN_HANDLED; 
			}
		}
	}
	DestroyTravTrieIterator(Iter);
	*/
	
	get_user_name(id,plName,37);
	
	if(equali(Args,"//",2))
	{
		new const Float:Range = get_pcvar_float(p_Range) * BASE_DISTANCE
		replace(Args,255,"// ","");
		
		if(Args[0] == '/' && Args[1] == '/')
			replace(Args,255,"//","");
		
		formatex(Message,511,"(OOC) %s: (( %s ))",plName,Args);
		ChatMessage(id,Range,Message);
		
		return End(Message);
	}
	else if(equali(Args,"/cnn ",5))
	{
		new Float:Cnn = get_pcvar_float(p_Cnn);
		if(!Cnn)
		{
			client_print(id,print_chat,"[DRP] CNN is currently disabled.");
			return PLUGIN_HANDLED
		}
		else if(get_gametime() - g_LastCnn[id] < Cnn)
		{
			client_print(id,print_chat,"[DRP] You must wait before you issue another headline.");
			return PLUGIN_HANDLED
		}
		
		if(!DRP_IsAdmin(id))
		{
			if(!(DRP_GetUserJobID(id) == g_Reporter))
			{
				client_print(id,print_chat,"[DRP] You must be a reporter to place news messages.");
				return PLUGIN_HANDLED
			}
		}
		
		g_LastCnn[id] = get_gametime();
		
		replace(Args,255,"/cnn ","");
		
		if(!strlen(Args))
			return PLUGIN_HANDLED
		
		formatex(Message,511,"<NEWSFLASH> - %s: (( %s ))",plName,Args);
		client_print(0,print_chat,"%s",Message);
		
		client_cmd(0,"spk fvox/alert");
		return End(Message);
	}
	else if(equali(Args,"/setradio ",10))
	{
		if(!DRP_GetUserItemNum(id,g_Radio))
		{
			client_print(id,print_chat,"[DRP] You must own a com-radio to use this.");
			return PLUGIN_HANDLED
		}
		
		replace(Args,255,"/setradio ","");
		
		if(!Args[0])
			return PLUGIN_HANDLED
		
		remove_quotes(Args);
		trim(Args);
		
		new ChannelNum = str_to_num(Args);
		if(!ChannelNum)
		{
			client_print(id,print_chat,"[DRP] You have shut your radio off.");
			g_UserRadioChannel[id] = 0
			return PLUGIN_HANDLED
		}
		
		if(strlen(Args) != 4)
		{
			client_print(id,print_chat,"[DRP] The channel must be 4 digits long.");
			return PLUGIN_HANDLED
		}
		
		g_UserRadioChannel[id] = ChannelNum
		
		client_print(id,print_chat,"[DRP] You have joined channel num: %d - Use /radio <message> to talk.",ChannelNum);
		return PLUGIN_HANDLED
	}
	else if(equali(Args,"/radio ",7))
	{
		if(!DRP_GetUserItemNum(id,g_Radio))
		{
			client_print(id,print_chat,"[DRP] You must own a com-radio to use this.");
			return PLUGIN_HANDLED
		}
		else if(!g_UserRadioChannel[id])
		{
			client_print(id,print_chat,"[DRP] You are not in a radio channel. Type /setradio <####>");
			return PLUGIN_HANDLED
		}
		
		replace(Args,255,"/radio ","");
		
		if(!Args[0])
			return PLUGIN_HANDLED
		
		new plName[33]
		get_user_name(id,plName,32);
		
		for(new Count;Count <= get_maxplayers();Count++)
		{
			if(g_UserRadioChannel[Count] != g_UserRadioChannel[id] || !is_user_alive(Count))
				continue
			
			client_print(Count,print_chat,"[DRP][RADIO: #%d] %s: %s",g_UserRadioChannel[id],plName,Args);
		}
		return PLUGIN_HANDLED
	}
	else if(equali(Args,"/a ",3) || equali(Args,"/suggest",8))
	{
		replace(Args,255,"/a ","");
		
		if(!strlen(Args))
			return PLUGIN_HANDLED
		
		format(Message,511,"[PLAYER-TO-ADMIN] %s: %s",plName,Args);
		
		if(DRP_AdminNum())
		{
			new iPlayers[32],iNum,Index
			get_players(iPlayers,iNum);
			
			for(new Count;Count < iNum;Count++)
			{
				Index = iPlayers[Count]
				
				if(DRP_IsAdmin(Index) || is_user_admin(id))
					client_print(Index,print_chat,"%s",Message);
			}
		}
		else
		{
			get_user_authid(id,Args,255);
			DRP_Log("Admin Sent Message: %s (%s) %s",plName,Args,Message);
		}
		
		client_print(id,print_chat,"[DRP] Your message has been sent to the administration team.");
		return End(Message);
	}
	else if(equali(Args,"/advert ",8) || equali(Args,"/ad ",4))
	{
		replace(Args,255,"/ad ","");
		replace(Args,255,"/advert ","");
		
		// Max Message = 126
		// PlayerName = 26
		new Len = strlen(Args);
		if(!Len || Len > 100)
		{
			client_print(id,print_chat,"[DRP] Advert to large (Max: %d - Yours: %d)",100,Len);
			return PLUGIN_HANDLED
		}
		
		// We create the menu now, because the ad we placed can always be different
		// Is this method okay?
		
		new Menu = menu_create("Place Ad: How:","_PlaceAd");
		menu_additem(Menu,"Place in Newspaper",Args);
		menu_additem(Menu,"Display in Chat",Args);
		menu_additem(Menu,"Help");
		
		formatex(Message,511,"^nNewspaper - $%d^nIn Chat - $%d",get_pcvar_num(p_AdvertPrice[1]),get_pcvar_num(p_AdvertPrice[0]));
		menu_addtext(Menu,Message,0);
		
		menu_display(id,Menu);
		return PLUGIN_HANDLED
	}
	else if(equali(Args,"/ooc ",5))
	{
		if(!get_pcvar_num(p_Ooc))
		{
			client_print(id,print_chat,"[DRP] OOC chat is currently disabled.")
			return PLUGIN_HANDLED
		}
		
		replace(Args,255,"/ooc ","")
		
		if(!strlen(Args))
			return PLUGIN_HANDLED
		
		OOCMessage(plName,Args);
		formatex(Message,511,"(OOC) %s: %s",plName,Args);
		
		return End(Message);
	}
	else if(equali(Args,"/me ",4) || equali(Args,"/action ",8))
	{
		replace(Args,255,"/me ","");
		replace(Args,255,"/action ","");
		
		if(!strlen(Args))
			return PLUGIN_HANDLED
		
		format(Message,255,"(ACTION) %s %s",plName,Args);
		ChatMessage(id,BASE_DISTANCE * get_pcvar_float(p_Range),Message);
		
		return End(Message);
	}
	else if(equali(Args,"/emhud",6))
	{
		if(!(DRP_IsCop(id) || DRP_IsMedic(id)))
		{
			client_print(id,print_chat,"[DRP] You are not a cop or a medic.");
			return PLUGIN_HANDLED
		}
		g_EmergencyHud[id] = !g_EmergencyHud[id]
		client_print(id,print_chat,"[DRP] The emergency hud has been toggled %s.",g_EmergencyHud[id] ? "on" : "off");
	}
	else if(equali(Args,"/shout ",7))
	{
		replace(Args,255,"/shout ","");
		
		new Len = strlen(Args)
		
		if(!Len)
			return PLUGIN_HANDLED
		
		for(new Count;Count < Len;Count++)
			Args[Count] = toupper(Args[Count]);
		
		Len--
			
		switch(get_pcvar_num(p_Printmode))
		{
			case 0:
				return PLUGIN_HANDLED
			case 1:
				format(Message,255,"(SHOUT) %s: %s",plName,Args);
			case 2:
			{
				new Len = strlen(Args) - 1
				if(Args[Len] == '.' || Args[Len] == '?' || Args[Len] == '!')
					Args[Len] = 0
						
				format(Message,255,"%s shouts, ^"%s!^"",plName,Args);
			}
		}
		ChatMessage(id,3.2 * BASE_DISTANCE * get_pcvar_float(p_Range),Message);
		
		return End(Message);
	}
	else if(equali(Args,"/quiet ",7) || equali(Args,"/whisper ",9))
	{
		replace(Args,255,"/quiet ","");
		replace(Args,255,"/whisper ","");
		
		new Len = strlen(Args);
		if(!Len)
			return PLUGIN_HANDLED
		
		for(new Count;Count < Len;Count++)
			Args[Count] = tolower(Args[Count]);
		
		Len--
		
		switch(get_pcvar_num(p_Printmode))
		{
			case 0:
				return PLUGIN_HANDLED
			case 1:
				format(Message,255,"(Whisper) %s: ... %s",plName,Args);
			case 2:
			{
				new Len = strlen(Args) - 1
				if(Args[Len] == '.' || Args[Len] == '?' || Args[Len] == '!')
					Args[Len] = 0
				
				strtolower(Args);
				format(Message,255,"%s: whispers, ^"...%s...^"",plName,Args);
			}
		}
		ChatMessage(id,0.2 * BASE_DISTANCE * get_pcvar_float(p_Range),Message);
		
		return End(Message);
	}
	else if(equali(Args,"/sms ",5) || equali(Args,"/txt ",5))
	{
		if(!UTIL_UserHavePhone(id))
		{
			client_print(id,print_chat,"[DRP] You need a phone to send SMS/TXT messages.");
			return PLUGIN_HANDLED
		}
		else if(!(g_UserPhone[id][EXTRA] & EX_TEXTING))
		{
			client_print(id,print_chat,"[DRP] Your phone does not allow for this feature.");
			return PLUGIN_HANDLED
		}
		else if(g_UserPhone[id][MODE] == MODE_DEACTIVATING)
		{
			client_print(id,print_chat,"[DRP] Your phone is currently turned off.");
			return PLUGIN_HANDLED
		}
		
		replace(Args,255,"/sms ","");
		replace(Args,255,"/txt ","");
		remove_quotes(Args);
		trim(Args);
		
		new szTarget[33],Target,Flag = 0
		parse(Args,szTarget,32,Message,1);
		
		// We are texting a number
		if(is_str_num(szTarget))
			{ Target = PhoneNumber2ID(szTarget); Flag = 1; }
		else
			Target = cmd_target(id,szTarget,0);
		
		if(!Target || !is_user_alive(Target))
		{
			client_print(id,print_chat,"[DRP] Could not find a user matching your input.");
			return PLUGIN_HANDLED
		}
		
		copy(Message,255,Args);
		replace(Message,255,szTarget,"");
		trim(Message);
		
		if(!g_UserPNum[Target][0] || !(g_UserPhone[Target][EXTRA] & EX_TEXTING) || !UTIL_UserHavePhone(Target))
		{
			client_print(id,print_chat,"[DRP] There was a problem with the targets phone. Message not sent.");
			return PLUGIN_HANDLED
		}
		
		new const UserBank = DRP_GetUserBank(id);
		if(DRP_GetUserItemNum(id,g_Subscription))
		{
			if(UserBank < 1)
			{
				if(g_UserPhone[id][TIME] < 1)
				{
					client_print(id,print_chat,"[DRP] You do not have enough prepaid time, or money in your bank, to send a message.");
					return PLUGIN_HANDLED
				}
				g_UserPhone[id][TIME] -= 1
				SaveUserInfo(id);
			}
			else
				DRP_SetUserBank(id,UserBank - 2);
		}
		else
		{
			if(g_UserPhone[id][TIME] < 1)
			{
				client_print(id,print_chat,"[DRP] You do not have enough prepaid time. Maybe buy a subscription?");
				return PLUGIN_HANDLED
			}
			g_UserPhone[id][TIME] -= 1
			SaveUserInfo(id);
		}
		
		if(!Flag)
			get_user_name(Target,szTarget,32);
		
		client_print(Target,print_chat,"(SMS FROM: %s): %s",Flag ? g_UserPNum[id] : plName,Message);
		client_print(id,print_chat,"(SMS TO: %s): %s",Flag ? g_UserPNum[Target] : szTarget,Message);
		
		emit_sound(Target,CHAN_AUTO,g_SmsSound,0.2,ATTN_NORM,0,PITCH_NORM);
		PrintBugMessage(id,Message);
		
		return End(Message);
	}
	else if(equali(Args,"/phone",6) || equali(Args,"phone"))
	{
		new const PhoneID = UTIL_UserHavePhone(id);
		if(!PhoneID)
			client_print(id,print_chat,"[DRP] You must own a cell phone, or go to the nearest payphone.");
		else
			_Phone(id,PhoneID);
			
		return PLUGIN_HANDLED
	}
	else if(equali(Args,"/hangup",7))
	{
		if(!g_UserPhone[id][CALLER] && !g_UserPhone[id][CALLING] || !g_UserPhone[id][TALKING])
		{
			client_print(id,print_chat,"[DRP] You are not on the phone.")
			return PLUGIN_HANDLED
		}
		
		BreakLine(id," has hungup the phone");
		client_print(id,print_chat,"[DRP] You have hung up the phone.");
		
		return PLUGIN_HANDLED
	}
	else if(equali(Args,"/dial ",6))
	{
		if(!UTIL_UserHavePhone(id))
		{
			client_print(id,print_chat,"[DRP] You must own a phone.");
			return PLUGIN_HANDLED
		}
		replace(Args,255,"/dial ","");
		trim(Args);
		
		if(!is_str_num(Args))
		{
			client_print(id,print_chat,"[DRP] Invalid Phone Number.");
			return PLUGIN_HANDLED
		}
		
		CallNumber(id,Args);
		return PLUGIN_HANDLED
	}
	else if(equali(Args,"/com ",5))
	{
		if(!DRP_IsCop(id) && !DRP_IsMedic(id))
		{
			client_print(id,print_chat,"[DRP] Your job doesn't allow for an intercom channel.")
			return PLUGIN_HANDLED
		}
	
		replace(Args,255,"/com ","");
		
		new Len = strlen(Args)
		if(!Len)
			return PLUGIN_HANDLED
		
		if(get_pcvar_num(p_Capscom))
			for(new Count;Count < Len;Count++)
				Args[Count] = toupper(Args[Count])
			
		Len--
			
		switch(get_pcvar_num(p_Printmode))
		{
			case 0:
				return PLUGIN_HANDLED
			case 1:
				format(Message,255,"(Emergency-Com) %s: <%s>",plName,Args)
			case 2:
			{
				new Len = strlen(Args) - 1
				if(Args[Len] == '.' || Args[Len] == '?' || Args[Len] == '!')
					Args[Len] = ' '
				
				format(Message,255,"%s says over the Emergency radio, ^"%s.^"",plName,Args)
			}
		}
		
		new iPlayers[32],iNum;
		get_players(iPlayers,iNum);
		
		for(new Count;Count < iNum;Count++)
		{
			Len = iPlayers[Count]
			if(DRP_IsCop(Len) || DRP_IsMedic(Len))
				client_print(Len,print_chat,"%s",Message);
		}
		
		PrintBugMessage(id,Message);
		return End(Message);
	}
	else if(equali(Args,"/911",4))
	{
		replace(Args,255,"/911 ","");
		remove_quotes(Args);
		trim(Args);
		
		if(!DRP_CopNum())
		{
			client_print(id,print_chat,"[DRP] There is currently no active cops on the server.");
			return PLUGIN_HANDLED
		}
		
		new Cache[32]
		parse(Args,Cache,31,Message,1);
		
		if(equali(Cache,"end"))
		{
			if(!g_911Reply[id] && (DRP_IsCop(id) || DRP_IsMedic(id)))
			{
				client_print(id,print_chat,"[DRP] You are not responding to any emergency's.");
				return PLUGIN_HANDLED
			}
			else if(!g_911Reply[id])
			{
				client_print(id,print_chat,"[DRP] Nobody has responded to your emergency call.");
				return PLUGIN_HANDLED
			}
			client_print(id,print_chat,"[DRP] You have ended the emergency call.");
			End911Call(id);
			
			return PLUGIN_HANDLED
		}
		else if(equali(Cache,"reply"))
		{
			if(!(DRP_IsCop(id) || DRP_IsMedic(id)))
			{
				client_print(id,print_chat,"[DRP] Only Cops/Medics can respond to calls.");
				return PLUGIN_HANDLED
			}
			if(g_911Reply[id])
			{
				client_print(id,print_chat,"[DRP] You are already in a emergency call.");
				return PLUGIN_HANDLED
			}
			
			new Menu = menu_create("Emergency Reply","Reply911"),Target
			new Name[33],CallerName[33],Str[12],Temp[2]
			
			new iNum,Names,bool:Found = false
			get_players(Cache,iNum);
			
			for(new Count,Count2;Count < iNum;Count++)
			{
				Target = Cache[Count]
				get_user_name(Target,Name,32);
				
				for(Count2 = 0;Count2 < MAX_CALLS;Count2++)
				{
					strtok(g_911Calls[Count2],CallerName,32,Temp,1,':');
					if(equali(CallerName,Name))
					{
						if(++Names > 1)
							continue
						
						num_to_str(Target,Str,11);
						menu_additem(Menu,Name,Str);
						
						Found = true
					}
				}
				Names = 0
			}
			if(!Found)
			{
				client_print(id,print_chat,"[DRP] There is no emergency calls to respond too.");
				menu_destroy(Menu);
			}
			else
			{
				menu_display(id,Menu);
			}
			return PLUGIN_HANDLED
		}
		else if(g_911Reply[id])
		{
			if(!is_user_alive(g_911Reply[id]))
			{
				client_print(id,print_chat,"[DRP] The emergency call has been ended. User has died / disconnected.");
				End911Call(id);
				
				return PLUGIN_HANDLED
			}
			switch(get_pcvar_num(p_Printmode))
			{
				case 0:
					return PLUGIN_HANDLED
				case 1:
					format(Message,511,"(9/11 RESPOND) %s: %s",plName,Args);
				case 2:
					format(Message,511,"%s calls over 9/11 respond call, ^"%s^"",plName,Args);
			}
			client_print(id,print_chat,"%s",Message);
			client_print(g_911Reply[id],print_chat,"%s",Message);
			
			return PLUGIN_HANDLED
		}
		else if(!(DRP_IsCop(id) || DRP_IsMedic(id)))
		{
			// We already called - don't send another message (to avoid spamming)
			new CallerName[33],Temp[2]
			for(new Count;Count < MAX_CALLS;Count++)
			{
				strtok(g_911Calls[Count],CallerName,32,Temp,1,':');
				if(equal(plName,CallerName))
				{
					client_print(id,print_chat,"[DRP] You already placed an emergency call. Please wait for a response.");
					return PLUGIN_HANDLED
				}
			}
			if(!get_pcvar_num(p_911))
			{
				switch(get_pcvar_num(p_Printmode))
				{
					case 0:
						return PLUGIN_HANDLED
					case 1:
						format(Message,511,"(9/11 EMERGENCY) %s: %s",plName,Args);
					case 2:
						format(Message,511,"%s calls over 9/11, ^"%s^"",plName,Args);
				}
			}
			else
			{
				format(g_911Calls[MAX_CALLS - 1],127,"%s: %s",plName,Args);
				RefreshCalls();
			}
			
			new iPlayers[32],iNum,Target
			get_players(iPlayers,iNum);
			
			for(new Count;Count < iNum;Count++)
			{
				Target = iPlayers[Count]
				
				if(g_EmergencyHud[Target])
					continue
				
				if(DRP_IsCop(Target) || DRP_IsMedic(Target))
					client_print(Target,print_chat,"[DRP] An Emergency call has been placed. Use the cmd ^"/emhud^" to view.",Message);
			}
			client_print(id,print_chat,"[DRP] Your 911 call has been dispatched to the police/medical department. Please wait for a reply.");
			return End(Message);
		}
		else
		{
			client_print(id,print_chat,"[DRP] Cops/Medics cannot call 911. Only reply. ^"/911 reply^"");
			return PLUGIN_HANDLED
		}
	}
	else if(!Mode)
	{
		new const Call = GetCaller(id);
		if(Call && (g_UserPhone[Call][CALLER] == id || g_UserPhone[Call][CALLING] == id) && g_UserPhone[Call][TALKING] == 1 && g_UserPhone[id][TALKING] == 1)
		{
			client_print(Call,print_chat,"(PHONE) %s: %s",(g_UserPhone[Call][EXTRA] & EX_CALLER_ID && !(g_UserPhone[id][EXTRA] & EX_BLOCK_CALLER_ID)) ? plName : "Unknown",Args);
			client_print(id,print_chat,"(PHONE) You say: %s",Args);
			
			PrintBugMessage(id,Message);
			return PLUGIN_HANDLED //End(Message);
		}

		new Mode[10]
		switch(get_pcvar_num(p_Printmode))
		{
			case 0:
				return PLUGIN_HANDLED
			case 1:
				formatex(Message,511,"(Nearby) %s: %s",plName,Args);
			case 2:
			{
				new Len = strlen(Args) - 1
				if(Args[Len] != '.' && Args[Len] != '?' && Args[Len] != '!' && Args[Len] != ',' && Len < 255)
				{
					Args[Len += 1] = '.'
					Args[Len + 1] = 0
				}
				else if(Len > 255)
				{
					Args[Len] = '.'
					Args[Len + 1] = 0
				}
				
				switch(Args[Len])
				{
					case '.': Mode = "says"
					case '?': Mode = "asks"
					case '!': Mode = "yells"
					case ',': Mode = "continues"
				}
				
				Args[0] = toupper(Args[0]);
				format(Message,511,"%s %s, ^"%s^"",plName,Mode,Args);
			}
		}
		ChatMessage(id,BASE_DISTANCE * get_pcvar_float(p_Range) * (equali(Mode,"yells") ? 1.5 : 1.0),Message);
	}
	else
	{
		if(!get_pcvar_num(p_Ooc))
		{
			client_print(id,print_chat,"[DRP] OOC is currently disabled.");
			return PLUGIN_HANDLED
		}
		
		formatex(Message,511,"(OOC) %s: %s",plName,Args);
		OOCMessage(plName,Args);
	}
	return End(Message);
}
/*==================================================================================================================================================*/
public Reply911(id,Menu,Item)
{
	if(Item == MENU_EXIT)
	{
		menu_destroy(Menu);
		return PLUGIN_HANDLED
	}
	new Cache[33],Temp
	
	menu_item_getinfo(Menu,Item,Temp,Cache,32,_,_,Temp);
	menu_destroy(Menu);
	
	new const Target = str_to_num(Cache);
	if(!is_user_alive(Target))
	{
		client_print(id,print_chat,"[DRP] The user has disconnected or is not alive.");
		return PLUGIN_HANDLED
	}
	if(g_911Reply[Target])
	{
		client_print(id,print_chat,"[DRP] Somebody has already answered this call.");
		return PLUGIN_HANDLED
	}
	get_user_name(id,Cache,32);
	client_print(Target,print_chat,"[DRP] %s has answered your emergency call. Reply with ^"/911 <chat>^"",Cache);
	get_user_name(Target,Cache,32);
	client_print(id,print_chat,"[DRP] You are now directly talking to: %s. Reply with ^"/911 <chat>^"",Cache);
	
	g_911Reply[id] = Target
	g_911Reply[Target] = id
	
	// Remove the 911 'caller'
	for(new Count;Count < MAX_CALLS;Count++)
		if(containi(g_911Calls[Count],Cache) != -1)
			g_911Calls[Count] = ""
	
	return PLUGIN_HANDLED
}
/*==================================================================================================================================================*/
PhoneMenu(id,PayPhone = 0)
{
	static Menu[256],Info[24]
	if(!PayPhone)
	{
		if(g_UserPhone[id][CALLING] && !g_UserPhone[id][CALLER] && !g_UserPhone[id][TALKING])
			copy(Info,23,"Calling");
		else if(g_UserPhone[id][CALLER] && !g_UserPhone[id][CALLING] && !g_UserPhone[id][TALKING])
			copy(Info,23,"Call Waiting");
		else if(g_UserPhone[id][TALKING])
			copy(Info,23,"In-Call");
		else if(g_UserPhone[id][MODE] == MODE_DEACTIVATING)
			copy(Info,23,"Phone Off");
		else
			copy(Info,23,"Idle");
	}
	else if(PayPhone)
		g_UserFunc[id] = PAYPHONE
	
	new Pos,Keys = (1<<0|1<<9)
	new const HasContract = DRP_GetUserItemNum(id,g_Subscription) ? 1 : 0
	
	Pos += formatex(Menu[Pos],255 - Pos,"Status: %s^nYour Number: %s^n^n",PayPhone ? "Open Phone" : Info,
		g_UserPNum[id][0] ? g_UserPNum[id] : "N/A");
	
	if(!HasContract)
		Pos += formatex(Menu[Pos],255 - Pos,"Prepaid Time: $%d^n^n",g_UserPhone[id][TIME]);
	else
		Pos += formatex(Menu[Pos],255 - Pos,"Billing from Bank^n^n");
	
	if(!g_UserPNum[id][0])
		Pos += formatex(Menu[Pos],255 - Pos,"You do not have a phone number^nYou may register one now^n^n1. Register Number");
	
	else if(g_UserPhone[id][MODE] == MODE_DEACTIVATING)
		Pos += formatex(Menu[Pos],255 - Pos,"Your phone is being deactivated.");
	
	// Calling
	else if(g_UserPhone[id][CALLING] && !g_UserPhone[id][CALLER] && !g_UserPhone[id][TALKING])
		Pos += formatex(Menu[Pos],255 - Pos,"1. Cancel Call");
	
	// In-Call
	else if(g_UserPhone[id][TALKING])
		Pos += formatex(Menu[Pos],255 - Pos,"1. End Phone Call");
	
	// Being Called
	else if(g_UserPhone[id][CALLER] && !g_UserPhone[id][CALLING])
	{
		new Call = g_UserPhone[id][CALLER] ? g_UserPhone[id][CALLER] : g_UserPhone[id][CALLING]
		if(g_UserPhone[id][EXTRA] & EX_CALLER_ID)
		{
			new plName[33],Number[24]
			if(g_UserPhone[Call][EXTRA] & EX_BLOCK_CALLER_ID && !DRP_IsAdmin(id))
			{
				copy(plName,32,"* PROTECTED *");
				copy(Number,23,"* PROTECTED *");
			}
			else
			{
				get_user_name(Call,plName,32);
				copy(Number,23,g_UserPNum[Call]);
			}
			
			Pos += formatex(Menu[Pos],255 - Pos,"-----------------------^nCaller Name: %s^nCaller Number: %s^n-----------------------^n^n",plName,Number);
		}
		Pos += formatex(Menu[Pos],255 - Pos,"1. Answer Phone^n2. Ignore Call");
		Keys += (1<<1)
	}
	
	else
	{
		for(new Count;Count < 6;Count++)
			g_UserNumber[id][Count] = 0
		
		Keys = (1<<0|1<<1|1<<2|1<<9);
		
		Pos += formatex(Menu[Pos],255 - Pos,"1. Call Number^n2. Deactivate Phone^n^n3. Ring Type ( %s )",g_RingSettings[g_UserPhone[id][RING]]);
		
		if(g_UserPhone[id][RING] == 3)
		{
			Pos += formatex(Menu[Pos],255 - Pos,"^n4. Custom Ringtone ( %s )","N/A");
			Keys += (1<<3);
		}
		if(HasContract)
		{
			Pos += formatex(Menu[Pos],255 - Pos,"^n5. Cancel Phone Contract");
			Keys += (1<<4);
		}
	}
	
	if(!PayPhone)
	{
		Pos += formatex(Menu[Pos],255 - Pos,"^n^n6. Phone Features");
		Keys += (1<<5)
	}
	
	Pos += formatex(Menu[Pos],255 - Pos,"^n0. Exit");
	//show_menu(id,Keys,Menu,-1,g_MainPhoneMenu);
	
	if(!PayPhone)
		UTIL_SetPhoneModel(id);
}
public _PhoneMenu(id,Key)
{
	if(!is_user_alive(id))
		return
	
	switch(Key)
	{
		case 0:
		{
			if(g_UserPhone[id][MODE] == MODE_DEACTIVATING)
			{
				UTIL_SetPhoneModel(id,0);
				return
			}
			
			if(g_UserFunc[id] == PAYPHONE)
			{
				DialNumber(id,CALL);
				return
			}
			
			// Calling
			if(g_UserPhone[id][CALLING] && !g_UserPhone[id][CALLER] && !g_UserPhone[id][TALKING])
			{
				new CallingTarget = BreakLine(id,"");
				client_print(id,print_chat,"[DRP] You have cancelled the call.");
				
				if(CallingTarget)
					client_print(CallingTarget,print_chat,"[DRP] The phone call has stopped.");
				
				UTIL_SetPhoneModel(id,0);
				return
			}
			
			// Hangup
			else if(g_UserPhone[id][TALKING])
			{
				BreakLine(id," has hung up the phone.");
				client_print(id,print_chat,"[DRP] You have hung up the phone.");
				
				UTIL_SetPhoneModel(id,0);
				return
			}
			
			// Being called.
			else if(g_UserPhone[id][CALLER] && !g_UserPhone[id][CALLING])
			{
				if(task_exists(g_UserPhone[id][CALLER] + PHONE_RING_OFFSET))
					remove_task(g_UserPhone[id][CALLER] + PHONE_RING_OFFSET);
				
				if(task_exists(id + PHONE_RING_OFFSET))
					remove_task(id + PHONE_RING_OFFSET)
				
				new Call = GetCaller(id);
				
				client_print(id,print_chat,"[DRP] You have answered the phone.");
				client_print(Call,print_chat,"[DRP] The phone has been answered.");
				
				g_UserPhone[g_UserPhone[id][CALLER]][TALKING] = 1
				g_UserPhone[id][TALKING] = 1
				return
			}
			
			if(g_UserPNum[id][0])
				DialNumber(id,CALL);
			else
				DialNumber(id,REGISTER);
		}
		case 1:
		{
			// Ignore Call
			if(g_UserPhone[id][CALLER] && !g_UserPhone[id][CALLING])
			{
				new CallerID = GetCaller(id);
				
				if(task_exists(id + PHONE_RING_OFFSET))
					remove_task(id + PHONE_RING_OFFSET)
				
				g_UserPhone[id][CALLING] = 0
				g_UserPhone[id][CALLER] = 0
				
				client_print(id,print_chat,"[DRP] You have ignored the call.");
				set_task(5.0,"NoAnswerRing",CallerID);
				
				UTIL_SetPhoneModel(id,0);
				return
			}
			menu_display(id,g_DMenu);
		}
		case 2:
		{
			if(g_UserPhone[id][RING] == RING_SETTINGS - 1)
				g_UserPhone[id][RING] = 0
			else
				g_UserPhone[id][RING]++
				
			PhoneMenu(id);
		}
		case 3:
		{	
			if(!(g_UserPhone[id][EXTRA] & EX_CUSTOM_RINGTONES))
			{
				client_print(id,print_chat,"[DRP] Your phone does not allow for this feature.");
				return
			}
			
			// HACKHACK - Static DIR - So... Fuck it.
			show_motd(id,"addons/amxmodx/DRP/MOTD/Ringtones.txt","");
			UTIL_SetPhoneModel(id,0);
		}
		case 4:
		{
			menu_display(id,g_CMenu);
			UTIL_SetPhoneModel(id,0);
		}
		case 5:
		{
			if(!g_UserPNum[id][0])
			{
				client_print(id,print_chat,"[DRP] Your phone must be activated to buy features.");
				return
			}
			if(!UTIL_IsPhoneIdle(id))
			{
				client_print(id,print_chat,"[DRP] You cannot buy features, while in a call.");
				return
			}
			
			format(g_Query,sizeof g_Query - 1,"Feature Packs^n^n1. Texting (SMS) - $%d^n2. Custom Ring Tones - $%d^n3. CallerID - $%d^n4. CallerID Blocker - $%d^n^n0. Exit",
			get_pcvar_num(p_FeaturePrices[0]),
			get_pcvar_num(p_FeaturePrices[1]),
			get_pcvar_num(p_FeaturePrices[2]),
			get_pcvar_num(p_FeaturePrices[3]));
			
			//show_menu(id,MENU_KEY_0|MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4,g_Query,-1,g_FeatureMenu);
			UTIL_SetPhoneModel(id,0);
		}
		case 9:
			UTIL_SetPhoneModel(id,0);
	}
}

public _NewspaperMenu(id,Menu,Item)
{
	if(Item == MENU_EXIT)
		return PLUGIN_HANDLED
	
	switch(Item)
	{
		case 0:
		{
			client_print(id,print_chat,"[DRP] There is no current news to show.");
		}
		case 1:
		{
			ShowAds(id);
		}
	}
	return PLUGIN_HANDLED
}

// ADDS FUNCTION
public _PlaceAd(id,Menu,Item)
{
	if(Item == MENU_EXIT)
	{
		menu_destroy(Menu);
		return PLUGIN_HANDLED
	}
	
	new Message[256],Temp
	menu_item_getinfo(Menu,Item,Temp,Message,255,_,_,Temp);
	menu_destroy(Menu);
	
	if(!Message[0] && Item != 2)
		return PLUGIN_HANDLED
	
	new const Price = Item == 0 ? get_pcvar_num(p_AdvertPrice[1]) : get_pcvar_num(p_AdvertPrice[0]),Bank = DRP_GetUserBank(id);
	if(Price > Bank && Item != 2)
	{
		client_print(id,print_chat,"[DRP] You do not have enough cash in the bank for the ad.");
		return PLUGIN_HANDLED
	}
	
	new plName[33]
	get_user_name(id,plName,32);
	
	switch(Item)
	{
		case 0:
		{
			new AuthID[36],ArrayAuthID[36],Temp[2],Num,First,Size = ArraySize(g_NewspaperArray);
			get_user_authid(id,AuthID,35);
			
			new OldMessage[256]
			copy(OldMessage,255,Message);
			
			// Remove sensitive chars
			replace_all(OldMessage,255,"|","");
			replace_all(OldMessage,255,":","-");
			
			// Delete our previous one
			for(new Count;Count < Size;Count++)
			{
				ArrayGetString(g_NewspaperArray,Count,Message,255);
				strtok(Message,ArrayAuthID,35,Message,255,'|');
				
				trim(ArrayAuthID);
				remove_quotes(ArrayAuthID);
				
				if(equali(AuthID,ArrayAuthID))
				{
					if(First < 1)
						First = Count + 1
					
					if(++Num >= MAX_ADS)
					{
						ArrayGetString(g_NewspaperArray,First - 1,Message,255);
						ArrayDeleteItem(g_NewspaperArray,First - 1);
						
						// Delete from SQL
						strtok(Message,Temp,1,Message,255,'|');
						strtok(Message,Temp,1,Message,255,':');
						
						trim(Message);
						remove_quotes(Message);
						
						format(g_Query,sizeof g_Query - 1,"DELETE FROM `newspaper` WHERE `Advert`='%s' AND `SteamID`='%s'",Message,AuthID);
						SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",g_Query);
						break
					}
				}
			}
			
			format(g_Query,sizeof g_Query - 1,"%s|%s: %s",AuthID,plName,OldMessage);
			ArrayPushString(g_NewspaperArray,g_Query);
			
			new Date[24],szYear[5],szMonth[3],szDay[3]
			DRP_GetWorldTime(Date,23,4)
			
			parse(Date,szYear,4,szMonth,2,szDay,2);
			
			new Year,Month,Day
			Year = str_to_num(szYear);
			Month = str_to_num(szMonth);
			Day = str_to_num(szDay);
			
			format(g_Query,sizeof g_Query - 1,"INSERT INTO `newspaper_ads` VALUES('%s','%s','%s','%d %d %d')",OldMessage,AuthID,plName,Year,Month,Day);
			SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",g_Query);
		}
		case 1:
		{
			client_print(0,print_chat,"[Advert] %s: %s",plName,Message);
			
			if(g_AdSound[0])
				client_cmd(0,"spk ^"%s^"",g_AdSound);
		}
		case 2:
		{
			if(!DRP_ShowMOTDHelp(id,"DRPTalkArea_Adhelp.txt"))
				client_print(id,print_chat,"[DRP] Unable to show help file.");
			
			return PLUGIN_HANDLED
		}
	}
	
	client_print(id,print_chat,"[DRP] You were charged $%d for the ad.",Price);
	
	if(!Item)
		client_print(id,print_chat,"[DRP] You can have a max of %d ads in the newspaper at a time",MAX_ADS);
	
	DRP_SetUserBank(id,Bank - Price);
	
	return PLUGIN_HANDLED
}

ShowAds(id)
{
	new const Size = ArraySize(g_NewspaperArray);
	new Message[512],Temp[2],Pos,szLen
	
	if(!Size)
	{
		client_print(id,print_chat,"[DRP] There are currently no Advertisements.");
		return PLUGIN_HANDLED
	}
	
	for(new Count;Count < Size;Count++)
	{
		// Format: SteamID|PlayerName: Messaage
		ArrayGetString(g_NewspaperArray,Count,g_Query,sizeof g_Query - 1);
		strtok(g_Query,Temp,1,g_Query,sizeof g_Query - 1,'|');
		
		// We should actually never get here
		if(!g_Query[0])
			continue
		
		Pos += format(Message[Pos],511 - Pos,"%s^n",g_Query);
		szLen += strlen(Message);
	}
	
	if(szLen >= MAX_MOTD_MESSAGELEN)
	{
		client_print(id,print_chat,"[DRP] The Ads Window is to large to view - please contact an administrator.");
		return DRP_Log("TalkArea Ads to large - Len: %d",szLen);
	}
	
	return show_motd(id,Message,"Ads");
}
// End ads

public _DPhone(id,Menu,Item)
{
	if(Item == MENU_EXIT)
		return PLUGIN_HANDLED
	
	switch(Item)
	{
		case 0: DPhone(id);
		case 1: client_print(id,print_chat,"[DRP] You have selected to NOT deactivate your phone.");
	}
	return PLUGIN_HANDLED
}
public _PhoneContract(id,Menu,Item)
{
	if(Item == MENU_EXIT)
		return PLUGIN_HANDLED
	
	switch(Item)
	{
		case 0:
		{
			DRP_SetUserItemNum(id,g_Subscription,0);
			client_print(id,print_chat,"[DRP] You have cancelled your contract/subscription.");
		}
		case 1:
		{
			client_print(id,print_chat,"[DRP] You have selected to NOT to cancel your contract.");
		}
	}
	return PLUGIN_HANDLED
}
public _DialNumberMenu(id,Key)
{
	if(!is_user_alive(id))
		return
	
	client_cmd(id,"spk ^"OZDRP/phone/%i^"",Key + 1);
	switch(Key)
	{
		case 9:
		{
			for(new Count;Count < 6;Count++)
				g_UserNumber[id][Count] = 0
			
			g_UserFunc[id] = 0
		}
		default:
		{
			for(new Count;Count < 6;Count++)
			{
				if(g_UserNumber[id][Count] == 0)
				{
					g_UserNumber[id][Count] = Key + 1
					break
				}
			}
			if(g_UserNumber[id][5] != 0)
			{
				new Number[12]
				UTIL_FormatNumber(id,Number,11);
				
				switch(g_UserFunc[id])
				{
					case REGISTER: RegisterNumber(id,Number);
					case CALL..PAYPHONE: CallNumber(id,Number);
				}
			}
			else
			{
				DialNumber(id,g_UserFunc[id]);
			}
		}
	}
}
public _FeatureMenu(id,Key)
{
	if(!is_user_alive(id))
		return PLUGIN_HANDLED
	
	switch(Key)
	{
		case 6..9:
			return PLUGIN_HANDLED
		
		default:
		{
			new Bank = DRP_GetUserBank(id);
			if(Bank < get_pcvar_num(p_FeaturePrices[Key]))
			{
				client_print(id,print_chat,"[DRP] You do not have enough cash (in your bank) to buy this feature.");
				return PLUGIN_HANDLED
			}
			
			switch(Key)
			{
				case 0: 
				{
					if(g_UserPhone[id][EXTRA] & EX_TEXTING)
						return client_print(id,print_chat,"[DRP] Your phone already has this feature.");
					
					g_UserPhone[id][EXTRA] |= EX_TEXTING
				}
				case 1:
				{
					if(g_UserPhone[id][EXTRA] & EX_CUSTOM_RINGTONES)
						return client_print(id,print_chat,"[DRP] Your phone already has this feature.");
					
					g_UserPhone[id][EXTRA] |= EX_CUSTOM_RINGTONES
				}
				case 2:
				{
					if(g_UserPhone[id][EXTRA] & EX_CALLER_ID)
						return client_print(id,print_chat,"[DRP] Your phone already has this feature.");
					
					g_UserPhone[id][EXTRA] |= EX_CALLER_ID
				}
				case 3:
				{
					if(g_UserPhone[id][EXTRA] & EX_BLOCK_CALLER_ID)
						return client_print(id,print_chat,"[DRP] Your phone already has this feature.");
					
					g_UserPhone[id][EXTRA] |= EX_BLOCK_CALLER_ID
				}
				
			}
			
			DRP_SetUserBank(id,Bank - get_pcvar_num(p_FeaturePrices[Key]));
			client_print(id,print_chat,"[DRP] You have successfully bought that feature.");
			SaveUserInfo(id);
		}
	}
	return PLUGIN_HANDLED
}
/*==================================================================================================================================================*/
GetCaller(id)
	return g_UserPhone[id][CALLER] ? g_UserPhone[id][CALLER] : g_UserPhone[id][CALLING]
	
BreakLine(id,const Msg[],Model=1)
{
	if(task_exists(id + PHONE_RING_OFFSET))
		remove_task(id + PHONE_RING_OFFSET)
	
	new Call = g_UserPhone[id][CALLER] ? g_UserPhone[id][CALLER] : g_UserPhone[id][CALLING]
	if(!Call)
		return FAILED
	
	if(g_UserTalkTimer[1][id])
		client_print(id,print_chat,"[DRP] That call lasted: %d Minute(s) ",g_UserTalkTimer[1][id]);
	
	if(g_UserTalkTimer[1][Call])
		client_print(Call,print_chat,"[DRP] That call lasted: %d Minute(s) ",g_UserTalkTimer[1][Call]);
	
	if(task_exists(Call + PHONE_RING_OFFSET))
		remove_task(Call + PHONE_RING_OFFSET)
	
	if(Msg[0])
	{
		new Name[33]
		if((g_UserPhone[id][EXTRA] & EX_BLOCK_CALLER_ID) && (g_UserPhone[Call][EXTRA] & EX_CALLER_ID))
			copy(Name,32,"User");
		else
			get_user_name(id,Name,32);
		
		client_print(Call,print_chat,"[DRP] %s%s",Name,Msg);
	}
	
	g_UserPhone[id][CALLER] = 0
	g_UserPhone[id][CALLING] = 0
	g_UserPhone[id][TALKING] = 0
	g_UserPhone[Call][CALLER] = 0
	g_UserPhone[Call][CALLING] = 0
	g_UserPhone[Call][TALKING] = 0
	
	g_UserTalkTimer[0][id] = 0
	g_UserTalkTimer[1][id] = 0
	g_UserTalkTimer[0][Call] = 0
	g_UserTalkTimer[1][Call] = 0
	
	if(Model)
	{
		UTIL_SetPhoneModel(id,0);
		UTIL_SetPhoneModel(Call,0);
	}
	
	return Call
}

DialNumber(id, bool:isCalling = true)
{
	new Title[128]
	formatex(Title, 127, "Enter Number (%s)----------------------^n       %d%d%d-%d%d%d        ^n----------------------^n^n", isCalling ? "Calling" : "Registering", g_UserNumber[id][0], \
		g_UserNumber[id][1],g_UserNumber[id][2],g_UserNumber[id][3],g_UserNumber[id][4],g_UserNumber[id][5]);
	
	g_UserFunc[id] = isCalling
	menu_display(id, g_MenuDialNumber);
}
public DPhone(id)
{
	if(g_UserPhone[id][MODE] == MODE_DEACTIVATING)
	{
		g_UserPhone[id][MODE] = 0
		client_print(id,print_chat,"[DRP] Your phone has been successfully deactivated.");
		
		return
	}
	
	new AuthID[36]
	get_user_authid(id,AuthID,35);
	
	BreakLine(id,"");
	
	for(new Count;Count < PHONE;Count++)
		g_UserPhone[id][Count] = 0
	
	g_UserPNum[id] = ""
	
	client_print(id,print_chat,"[DRP] Your phone is currently being deactivated. Please wait a moment.");
	
	g_UserPhone[id][MODE] = MODE_DEACTIVATING
	set_task(5.0,"DPhone",id);
	
	format(g_Query,sizeof g_Query - 1,"UPDATE %s SET `PhoneNumber`='',`PhoneTime`=0,`ExtraFeatures`='' WHERE SteamID='%s'",g_PhoneTable,AuthID);
	SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",g_Query);
}
RegisterNumber(id,const Number[])
{
	new AuthID[36],Data[1]
	get_user_authid(id,AuthID,35);
	
	Data[0] = id
	client_print(id,print_chat,"[DRP] Attempting to register number %s. Please hold.",Number);
	
	format(g_Query,sizeof g_Query - 1,"SELECT * FROM %s WHERE PhoneNumber='%s'",g_PhoneTable,Number);
	SQL_ThreadQuery(g_SqlHandle,"RegisterPNumber",g_Query,Data,1);
}
CallNumber(id,const Number[])
{
	if(g_UserPhone[id][CALLER] || g_UserPhone[id][CALLING])
	{
		client_print(id,print_chat,"[DRP] You are already in a phone call.");
		return PLUGIN_HANDLED
	}
	
	new iPlayers[32],iNum,Target,bool:Found = false
	get_players(iPlayers,iNum);
	
	for(new Count;Count < iNum;Count++)
	{
		Target = iPlayers[Count]
		if(equali(g_UserPNum[Target],Number))
		{
			Found = true
			break
		}
	}
	if(!Found || !UTIL_UserHavePhone(Target))
	{
		client_print(id,print_chat,"[DRP] Unable to resolve number. Number may not exist or the user is unavailable.");
		client_cmd(id,"spk ^"OZDRP/phone/error_doriginal.wav^"");
		
		return PLUGIN_HANDLED
	}
	if(Target == id)
	{
		client_print(id,print_chat,"[DRP] You cannot call yourself.");
		return PLUGIN_HANDLED
	}
	if(g_UserPhone[Target][CALLER] || g_UserPhone[Target][CALLING])
	{
		client_print(id,print_chat,"[DRP] The line is busy, try again later...");
		client_cmd(id,"spk ^"OZDRP/phone/busy_doriginal.wav^"");
		
		return PLUGIN_HANDLED
	}
	if(!is_user_alive(Target))
	{
		client_print(id,print_chat,"[DRP] User is not in the city range or is dead.");
		return PLUGIN_HANDLED
	}
	
	g_UserPhone[Target][CALLER] = id
	g_UserPhone[Target][RINGING] = 0
	g_UserPhone[id][CALLING] = Target
	
	set_task(5.0,"Ring",Target + PHONE_RING_OFFSET,_,_,"a",8);
	
	client_print(id,print_chat,"[DRP] Calling %s",Number);
	return PLUGIN_HANDLED
}
public Ring(id)
{
	id -= PHONE_RING_OFFSET
	
	// Ring 8 times - give a no answer to the caller
	if(++g_UserPhone[id][RINGING] >= 8)
	{
		if(task_exists(id + PHONE_RING_OFFSET))
			remove_task(id + PHONE_RING_OFFSET)
		
		NoAnswer(g_UserPhone[id][CALLER]);
		BreakLine(id,"",0);
		
		g_UserPhone[id][RING] = 0
		
		return
	}
	
	/*
	new const g_RingSettings[RING_SETTINGS][] =
	{
		"Ring",
		"Vibrate",
		"Silent",
		"Custom"
	}
	*/
	
	switch(g_UserPhone[id][RING])
	{
		case 0:
			emit_sound(id,CHAN_AUTO,g_RingSound,0.7,ATTN_NORM,0,PITCH_NORM);
		case 1:
			emit_sound(id,CHAN_AUTO,g_VibrateSound,0.1,ATTN_NORM,0,PITCH_NORM);
		case 3:
			emit_sound(id,CHAN_AUTO,g_RingSound,0.7,ATTN_NORM,0,PITCH_NORM); // Ring Normal
	}
	
	// If we have it on vibrate - we might not be able to feel it
	// don't tell them - the point is other people not being able to hear it.
	
	// If we have it on silent - don't say we are ringing ether
	if(g_UserPhone[id][RING] != 1 && g_UserPhone[id][RING] != 2)
		client_print(id,print_chat,"[DRP] Your phone is ringing.");
}
public NoAnswerRing(id)
{
	// Because the caller got no answer - he might be still in the phone menu
	// Set Model = 0 on BreakLine(); Just Incase
	BreakLine(id,"",0);
	NoAnswer(id);
}

NoAnswer(id)
	if(is_user_connected(id))
		client_print(id,print_chat,"[DRP] You received no answer.");
/*==================================================================================================================================================*/
End(const Message[])
{
	if(get_pcvar_num(p_Printconsole))
		server_print("%s",Message);
	
	return PLUGIN_HANDLED
}
PrintBugMessage(id,const Message[])
{
	new iPlayers[32],iNum,Target
	get_players(iPlayers,iNum);
	
	new plName[32]
	get_user_name(id,plName,32);
	
	for(new Count;Count < iNum;Count++)
	{
		Target = iPlayers[Count]
		
		if(g_UserBugged[id] & (1<<Target))
			client_print(Target,print_chat,"[BUG (%s)] %s",plName,Message);
	}
}
ChatMessage(Sender,Float:Dist,const Message[],SendToDead = 0)
{
	static iPlayers[32]
	new Target,iNum,Float:SndOrigin[3],Float:RecvOrigin[3]
	
	get_players(iPlayers,iNum);
	pev(Sender,pev_origin,SndOrigin);
	
	if(DRP_IsAdmin(Sender))
		Dist += 50.0
	
	for(new Count;Count < iNum;Count++)
	{
		Target = iPlayers[Count]
		
		if(!is_user_connected(Target) || SendToDead ? false : !is_user_alive(Target))
			continue
		
		pev(Target,pev_origin,RecvOrigin);
	
		if(get_distance_f(RecvOrigin,SndOrigin) <= Dist)
			client_print(Target,print_chat,"%s",Message);
	}
	return PLUGIN_CONTINUE
}
OOCMessage(const Name[],const Args[])
{
	switch(get_pcvar_num(p_Ooc))
	{
		case 1:
			client_print(0,print_chat,"%s: (( %s ))",Name,Args);
		case 2:
		{
			client_print(0,print_console,"%s: (( %s ))",Name,Args);
			
			formatex(g_OOCText[MAX_LINES - 1],127,"%s: %s",Name,Args);
			RefreshMessages();
			
			DRP_ForceHUDUpdate(-1,HUD_TALKAREA);
			client_cmd(0,"spk ^"%s^"",g_OOCSound);
		}
	}
	return PLUGIN_HANDLED
}
RefreshMessages()
	for(new Count;Count < MAX_LINES;Count++)
		copy(g_OOCText[Count],127,Count == MAX_LINES - 1 ? "" : g_OOCText[Count + 1]);

RefreshCalls()
	for(new Count;Count < MAX_CALLS;Count++)
		copy(g_911Calls[Count],127,Count == MAX_CALLS - 1 ? "" : g_911Calls[Count + 1]);
/*==================================================================================================================================================*/
UTIL_UserHavePhone(id)
{
	if(DRP_GetUserItemNum(id,g_iPhone))
		return g_iPhone
	else if (DRP_GetUserItemNum(id,g_Aria))
		return g_Aria
	else if(DRP_GetUserItemNum(id,g_Droid))
		return g_Droid
	else
		return FAILED
	
	return FAILED
}
UTIL_SetPhoneModel(id,On = 1)
{
	client_cmd(id,"weapon_0");
	
	if(On)
	{
		static vModel[36]
		pev(id,pev_viewmodel2,vModel,35);
		
		if(equali(vModel,g_szVPhoneMdl))
			return
		
		set_pev(id,pev_viewmodel2,g_szVPhoneMdl);
		set_pev(id,pev_weaponmodel2,g_szPPhoneMdl);
		set_pev(id,pev_weaponanim,1);
		
		message_begin(MSG_ONE_UNRELIABLE,SVC_WEAPONANIM,_,id);
		write_byte(1);
		write_byte(pev(id,pev_body));
		message_end();
		
		g_PhoneCache[id] = true
	}
	else
	{
		set_pev(id,pev_viewmodel2,"models/v_melee.mdl");
		set_pev(id,pev_weaponmodel2,"");
		
		g_PhoneCache[id] = false
	}
}
UTIL_FormatNumber(id,Number[],Len)
{
	formatex(Number,Len,"%d%d%d%d%d%d",
	g_UserNumber[id][0],g_UserNumber[id][1],
	g_UserNumber[id][2],g_UserNumber[id][3],
	g_UserNumber[id][4],g_UserNumber[id][5]);
}
UTIL_IsPhoneIdle(id)
{
	if(g_UserPhone[id][CALLING] && !g_UserPhone[id][CALLER] && !g_UserPhone[id][TALKING])
		return FAILED
	else if(g_UserPhone[id][CALLER] && !g_UserPhone[id][CALLING])
		return FAILED
	else if(g_UserPhone[id][TALKING])
		return FAILED
	else if(g_UserPhone[id][MODE] == MODE_DEACTIVATING)
		return FAILED
	else
		return SUCCEEDED
		
	return FAILED
}
// Not Used
// Simply makes the text white
UTIL_ColorChat(Receiver,const Message[])
{
	new Buffer[256]
	copy(Buffer[1],255,Message);

	Buffer[0] = ''
	Buffer[strlen(Buffer)] = '^n'
	Buffer[strlen(Buffer)] = '^0'
	
	if(!Receiver)
		message_begin(MSG_BROADCAST,gmsgSayText,_,Receiver);
	else
		message_begin(MSG_ONE_UNRELIABLE,gmsgSayText,_,Receiver);
	
	write_byte(Receiver);
	write_string(Buffer);
	message_end()
}
/*==================================================================================================================================================*/
CreateMenus()
{
	// Deactive Phone
	g_DMenu = menu_create("Deactivate Phone^n^nWARNING","_DPhone");
	menu_additem(g_DMenu,"Yes");
	menu_additem(g_DMenu,"No");
	menu_addtext(g_DMenu,"^nAre you sure you,^nwish to deactivate your phone?^n^nYou will lose your, phone number,^nfeatures and contacts^n");
	menu_addtext(g_DMenu,"You will still keep your current phone.^nBut it must be re-activated.");
	
	g_CMenu = menu_create("Cancel Contract?","_PhoneContract");
	menu_additem(g_CMenu,"Yes");
	menu_additem(g_CMenu,"No");
	menu_addtext(g_CMenu,"^nDo you wish to cancel the contract?^n^nYou must ethier get a new contract,^nor buy prepaid cards..");
	
	g_NewspaperMenu = menu_create("What would you like to view?","_NewspaperMenu");
	menu_additem(g_NewspaperMenu,"World News");
	menu_additem(g_NewspaperMenu,"Advertisements");
}
SaveUserInfo(id)
{
	// We never save on disconnect
	if(!is_user_connected(id))
		return
	
	static AuthID[36]
	get_user_authid(id,AuthID,35);
	
	new Features[24]
	//DRP_IntToAccess(g_UserPhone[id][EXTRA],Features,23);
	
	format(g_Query,sizeof g_Query - 1,"UPDATE %s SET `PhoneTime`='%d',`ExtraFeatures`='%s' WHERE SteamID='%s'",g_PhoneTable,g_UserPhone[id][TIME],Features,AuthID);
	DRP_CleverQuery(g_SqlHandle,"IgnoreHandle",g_Query);
}
public IgnoreHandle(FailState,Handle:Query,const Error[],Errcode,const Data[],DataSize) 
{
	if(FailState != TQUERY_SUCCESS || Errcode)
		return log_amx("[DRP-TALKAREA] SQL Connection Failed (Error: %s)",Error ? Error : "UNKNOWN");
	
	return PLUGIN_CONTINUE
}
public RegisterPNumber(FailState,Handle:Query,const Error[],Errcode,const Data[],DataSize)
{
	if(FailState != TQUERY_SUCCESS)
		return log_amx("Unable to Query. Error: %s",Error ? Error : "UNKNOWN");
	
	new id = Data[0],Number[12]
	UTIL_FormatNumber(id,Number,11);
	
	// reset
	for(new Count;Count < 6;Count++)
		g_UserNumber[id][Count] = 0
	
	if(SQL_NumResults(Query) >= 1)
	{
		client_print(id,print_chat,"[DRP] The Phone Number %s has already been taken.",Number);
		return PLUGIN_HANDLED
	}
	
	new AuthID[36],plName[64]
	get_user_authid(id,AuthID,35);
	get_user_name(id,plName,63);
	
	copy(g_UserPNum[id],11,Number);
	//DRP_SQLRemoveKey(plName,63);
	
	format(g_Query,sizeof g_Query - 1,"UPDATE %s SET `PhoneNumber`='%s',`PlayerName`='%s' WHERE SteamID='%s'",g_PhoneTable,Number,plName,AuthID);
	SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",g_Query);
	
	client_print(id,print_chat,"[DRP] The Phone Number %s has been successfully registered.",Number);
	
	return PLUGIN_CONTINUE
}
// TODO:
// Fix this - Unknown Issue (???)
public GetPhoneListings(FailState,Handle:Query,const Error[],Errcode,const Data[],DataSize)
{
	if(FailState != TQUERY_SUCCESS)
		return log_amx("Unable to Query. Error: %s",Error ? Error : "UNKNOWN");
	
	new const id = Data[0]
	
	if(!is_user_alive(id))
		return FAILED
	
	if(!SQL_NumResults(Query))
	{
		client_print(id,print_chat,"[DRP] The phonebook is currently empty.");
		return FAILED
	}
	
	new Message[2028],Cache[36],AuthID[36],Pos,Len,Target
	new Number[12]
	
	while(SQL_MoreResults(Query))
	{
		Target = 0
		SQL_ReadResult(Query,3,Cache,35);
		
		if(read_flags(Cache) & EX_BLOCK_PHONEBOOK)
		{
			SQL_NextRow(Query);
			continue
		}
		
		SQL_ReadResult(Query,1,Number,11);
		
		if(!Number[0])
		{
			SQL_NextRow(Query);
			continue
		}
		
		SQL_ReadResult(Query,4,Cache,35);
		
		Pos += formatex(Message[Pos],2027 - Pos,"%s: %c%c%c-%c%c%c^n",Cache[0] ? Cache : "UNKNOWN",
		Number[0],Number[1],Number[2],Number[3],Number[4],Number[5]);
		
		Len += strlen(Message);
		SQL_NextRow(Query);
	}
	
	get_user_name(id,Cache,35);
	server_print("[DRP] SHOWING PHONEBOOK TO PLAYER: %s",Cache);
	
	/*
	if(!DRP_IsAdmin(id))
	{
		if(Len >= 1535)
		{
			DRP_ThrowError(0,"MOTD Phonebook to large. (Size: %d)",Len);
			return FAILED
		}
	}
	*/
	
	show_motd(id,Message,"Phonebook");
	return SUCCEEDED
}
/*==================================================================================================================================================*/
// Shows an MOTD window to the clients that would be able to hear your message
// Mainly used this for dev testing
ChatRadius(id,const Float:Radius)
{
	new iPlayers[32],Name[33],iNum,Target,Pos,Dist
	get_players(iPlayers,iNum);
	
	new Float:Origin[3],Float:Origin2[3]
	pev(id,pev_origin,Origin);
	
	for(new Count;Count < iNum;Count++)
	{
		Target = iPlayers[Count]
		
		if(!is_user_alive(Target))
			continue
		
		pev(Target,pev_origin,Origin2);
		
		if(!(Dist = get_distance_f(Origin,Origin2) <= Radius))
			continue
		
		get_user_name(Target,Name,32);
		Pos += formatex(g_Query,sizeof g_Query - 1,"%s - %d distance^n",Name,floatround(Dist));
	}
	show_motd(id,g_Query,"List of Clients to Hear your Message");
}

SteamIDConnected(const SteamID[])
{
	new iPlayers[32],AuthID[36],iNum,Target
	get_players(iPlayers,iNum);
	
	for(new Count;Count < iNum;Count++)
	{
		Target = iPlayers[Count]
		get_user_authid(Target,AuthID,35);
		
		if(equali(SteamID,AuthID))
			return Target
	}
	return FAILED
}

PhoneNumber2ID(const Number[])
{
	new iPlayers[32],iNum,Target
	get_players(iPlayers,iNum);
	
	for(new Count;Count < iNum;Count++)
	{
		Target = iPlayers[Count]
		
		if(equali(Number,g_UserPNum[Target]))
			return Target
	}
	return FAILED
}

public plugin_end()
{
	ArrayDestroy(g_NewspaperArray);
	TrieDestroy(g_SayTrie);
	
	menu_destroy(g_DMenu);
	menu_destroy(g_CMenu);
	menu_destroy(g_NewspaperMenu);
}