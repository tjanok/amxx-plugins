#include <amxmodx>
#include <fun>
#include <fakemeta>
#include <engine> // find_sphere_class();

#include <DRP/DRPCore>
#include <DRP/DRPChat>

#include <TSXWeapons>

#define IsPassedOut(%1) \
	(g_Alcohol[%1] >= 100)

#define MAX_LIGHTS 3
#define MAX_LIGHTS_UPDATE 180 // 1 hour

#define MAX_TEARGAS_UPDATE 5

#define chance(%1) ( %1 > random(100) ) // %1 = probability 

enum _:SMOKING
{
	ITEMID = 0,
	TIMELEFT,
	HPLOSS,
	IN_PROGRESS
}
enum WEAPON
{
	ITEMID = 0,
	ATTACHMENTS
}

new g_Smoking[33][SMOKING]
new g_Alcohol[33]

new g_Flashlight[33]
new g_Tazered[33]
new g_Eating[33]

new g_DrunkStopper[33]

new g_Attachments[33]
new g_Gun[33]
new g_Cell[33]
new g_Pick[33]

new Float:g_LastTazer[33]
new Float:g_MaxSpeed[33]

new g_UserLights[33]

// ItemID's
new g_FlashlightID
new g_Spray
new g_Tazer
new g_Reserva

new const g_Model[] = "models/woodgibs.mdl"
new g_ModelID

// Sounds
new const g_Lockpick[] = "buttons/latchlocked1.wav" // precached by half life
new const g_BombBeep[] = "OZDRP/phone/2.wav" // precached in talkarea
new const g_TazerSound[] = "OZDRP/tazer.wav"
new const g_HeartSound[] = "sound/OZDRP/heart.wav"
new const g_CoughSound[] = "OZDRP/cough.wav"
new const g_FlashSound[] = "weapons/sfire-inslow.wav" // precached by TS

new g_Smoke
new g_Lightning

new gmsgTSFade
new gmsgScreenShake

new const g_Lightbulb[] = "DRP_LBULB"
new const g_Grenade[] = "DRP_GNADE"
new const g_LightbulbMdl[] = "sprites/OZDRP/drpbulb.spr"

// Menus
new const g_LockMenu[] = "DRP_LockMenu"
new const g_AttachmentMenu[] = "DRP_WpnAttchMenu"

// What weapons can have
new const g_GunStats[TS_MAX_WEAPONS][WEAPON] = 
{
	{0,0},
	{50,TSA_FLASHLIGHT|TSA_LASERSIGHT|TSA_SILENCER},
	{0,0},
	{51,TSA_SILENCER},
	{52,TSA_FLASHLIGHT|TSA_LASERSIGHT|TSA_SCOPE},
	{53,TSA_FLASHLIGHT|TSA_LASERSIGHT|TSA_SCOPE|TSA_SILENCER},
	{54,TSA_FLASHLIGHT|TSA_LASERSIGHT|TSA_SCOPE},
	{55,TSA_FLASHLIGHT|TSA_LASERSIGHT|TSA_SCOPE|TSA_SILENCER},
	{56,TSA_FLASHLIGHT|TSA_LASERSIGHT|TSA_SILENCER},
	{57,TSA_FLASHLIGHT|TSA_LASERSIGHT|TSA_SILENCER},
	{0,0},
	{58,TSA_FLASHLIGHT|TSA_LASERSIGHT},
	{59,TSA_LASERSIGHT|TSA_SCOPE|TSA_SILENCER},
	{60,TSA_SCOPE},
	{61,TSA_LASERSIGHT|TSA_SCOPE|TSA_SILENCER},
	{62,TSA_LASERSIGHT|TSA_SILENCER},
	{0,0},
	{63,TSA_LASERSIGHT|TSA_SILENCER},
	{64,TSA_LASERSIGHT},
	{65,TSA_LASERSIGHT|TSA_SCOPE|TSA_SILENCER},
	{66,TSA_FLASHLIGHT|TSA_LASERSIGHT},
	{67,0},
	{68,TSA_FLASHLIGHT|TSA_LASERSIGHT|TSA_SILENCER},
	{69,TSA_FLASHLIGHT|TSA_LASERSIGHT|TSA_SCOPE|TSA_SILENCER},
	{70,0},
	{71,0},
	{72,TSA_FLASHLIGHT|TSA_LASERSIGHT},
	{73,TSA_FLASHLIGHT|TSA_LASERSIGHT|TSA_SCOPE},
	{74,TSA_LASERSIGHT},
	{0,0},
	{0,0},
	{75,TSA_LASERSIGHT|TSA_SCOPE},
	{76,0},
	{77,TSA_LASERSIGHT},
	{78,0},
	{79,0},
	{0,0},
	{0,0},
	{80,TSA_LASERSIGHT|TSA_SCOPE}
}

new const g_HornSounds[][] =
{
	"gonarch/gon_alert1.wav",
	"gonarch/gon_alert2.wav",
	"gonarch/gon_alert3.wav"
}

public plugin_precache()
{
	// Sprites
	g_Smoke = precache_model("sprites/steam1.spr");
	g_Lightning = precache_model("sprites/lgtning.spr");
	
	precache_model(g_LightbulbMdl);
	g_ModelID = precache_model(g_Model);
	
	// Sounds
	precache_sound(g_Lockpick);
	precache_sound(g_TazerSound);
	precache_sound(g_CoughSound);
	precache_sound(g_FlashSound);
	
	for(new Count;Count < sizeof(g_HornSounds);Count++)
		precache_sound(g_HornSounds[Count]);
	
	precache_generic(g_HeartSound);
}
	
public plugin_init()
{
	register_plugin("DRP - Items","0.1a","Drak");
	
	// Commands
	DRP_AddChat(_,"HandleSay");
	
	// Forwards
	register_forward(FM_PlayerPreThink,"forward_PreThink");
	register_forward(FM_Think,"forward_Think");
	register_forward(FM_CmdStart,"forward_CmdStart");
	
	// Events
	register_event("DeathMsg","EventDeathMsg","a");
	
	// DRP Events
	DRP_RegisterEvent("Item_Use","Player_UseItem");
	
	// Messages
	gmsgTSFade = get_user_msgid("TSFade");
	gmsgScreenShake = get_user_msgid("ScreenShake");
	
	// Menus
	register_menucmd(register_menuid(g_AttachmentMenu),g_Keys,"AttachMenuHandle");
	register_menucmd(register_menuid(g_LockMenu),g_Keys,"LockMenuHandle");
}

public DRP_Error(const Reason[])
	pause("d");

public Player_UseItem(const Name[],const Data[],const Len)
{
	new const id = Data[0]
	if(g_Tazered[id])
	{
		client_print(id,print_chat,"[DRP] You can't use this item because you have been tasered.");
		return PLUGIN_HANDLED
	}
	return PLUGIN_CONTINUE
}

public DRP_RegisterItems()
{
	// Weapons
	new TSWeaponNames[TS_MAX_WEAPONS][2][] =
	{
		{"",""},
		{"GLOCK-18","Handgun; 9mm Parabellum"},
		{"",""},
		{"Mini-Uzi","Sub-machine Gun; 9mm Parabellum"},
		{"Benelli M3","Shotgun; 12 gauge 2 3/4^""},
		{"Colt M4A1","Rifle; 5.56mm (NATO)"},
		{"MP5SDA5","Sub-machine Gun; 9mm Parabellum"},
		{"MP5K","Sub-machine Gun; 9mm Parabellum"},
		{"Akimbo Beretta 92Fs","Handgun(s); 9mm Parabellum"},
		{"SOCOM MK23","Handgun; .45 ACP"},
		{"",""},
		{"USAS-12","Shotgun; 12 gauge 2 3/4^""},
		{"Desert Eagle","Handgun; .50 AE"},
		{"Kalashnikova AK-47","Rifle; 7.62mm"},
		{"FN Five-seveN","Handgun; 5.7mm"},
		{"Steyr AUG","Rifle; 5.56mm (NATO)"},
		{"",""},
		{"vz. 61 ^"Skorpion^"","Sub-machine Gun; .32 ACP"},
		{"Barrett M82A1","Rifle; .50 BMG"},
		{"H&K MP7","Sub-machine Gun; 4.6mm"},
		{"SPAS-12","Shotgun; 12 gauge 2 3/4^""},
		{"Golden Colt","Handgun; .45 ACP"},
		{"GLOCK-20C","Handgun; 10mm Auto"},
		{"H&K UMP","Sub-machine Gun; .45 ACP"},
		{"M61 Grenade","Special"},
		{"Combat Knife","Special"},
		{"Mossberg 500","Shotgun; 12 gauge 2 3/4^""},
		{"Colt M16A4","Rifle; 5.56mm (NATO)"},
		{"Ruger MK1","Handgun; .22 LR"},
		{"",""},
		{"",""},
		{"Raging Bull","Handgun; .454 Casull"},
		{"M60E3","Machine-gun; 7.62mm (NATO)"},
		{"Sawed-Off Shotgun","Shotgun; 12 gauge 2 3/4^""},
		{"Katana","Special"},
		{"Seal Knife","Special"},
		{"G2 Contender","Handgun; 7.62mm NATO"},
		{"",""},
		{"",""}
	}
	
	new FormatName[64]
	for(new Count;Count < TS_MAX_WEAPONS;Count++)
	{
		if(TSWeaponNames[Count][0][0])
		{
			formatex(FormatName,63,"Packaged: %s",TSWeaponNames[Count][0]);
			g_GunStats[Count][ITEMID] = DRP_RegisterItem(FormatName,"_WeaponHandle",TSWeaponNames[Count][1],1);
		}
	}
	
	DRP_RegisterItem("ATM Card","_Atm","Allows you to use ATM's around the city.");
	DRP_RegisterItem("Credit Card","_CreditCard","A basic credit card. Used for loans and large banking.");
	
	g_FlashlightID = DRP_RegisterItem("Flashlight","_Flashlight","A small flashlight.");
	g_Spray = DRP_RegisterItem("Spray Can","_Spray","A Spraycan. You can use this to spray walls.",1);
	
	DRP_RegisterItem("Item Searcher","_Searcher","Allows you to view a users inventory.",0,0,0);
	DRP_RegisterItem("Diamond Ring","_Ring","18K White Gold Ring. Used for Marriage/Engagement. The ultimate status symbol.");
	
	DRP_RegisterItem("Lockpick","_Lockpick","A cheap bobby pin-like pick.",0);
	DRP_RegisterItem("Electric Lockpick","_ELockPick","Open doors. Without the hassel.");
	
	DRP_RegisterItem("Lighter","_Lighter","A small plastic lighter. One time use.",1);
	DRP_RegisterItem("Zippo Lighter","_Lighter","A large metal lighter with a wide flame.");
	
	DRP_RegisterItem("Door C2","_Doorbreak","A small bomb that blows doors open",1,0,0,1);
	DRP_RegisterItem("Battering Ram","_Doorbreak","A one man battering ram, capable of knocking down doors.",0,0,0,0);
	
	DRP_RegisterItem("Marlboro Cigarette","_Smoke","A Marlboro cigarette. Very fine quality.",1,_,_,60,5);
	DRP_RegisterItem("Camel Cigarette","_Smoke","Cheap Cigarette's",1,_,_,55,3);
	DRP_RegisterItem("Djarum Black Cigarette","_Smoke","Best Flavored Clove Cigarette.",1,_,_,65,6);
	DRP_RegisterItem("Cuban Cigar","_Smoke","A cigar ported straight from cuba.",1,_,_,120,10);
	
	g_Reserva = DRP_RegisterItem("Reserva Especial Cigar","_Smoke","One of the most finest cigars on the market.",1,_,_,200,20);
	
	DRP_RegisterItem("Beer","_Alcohol","Generic Can of American Beer",1,_,_,10);
	DRP_RegisterItem("Mikes Hard Lemonade","_Alcohol","Malt Liquor Lemonade Drink",1,_,_,20);
	DRP_RegisterItem("Strongbow Cider","_Alcohol","The UK's best alcoholic cider",1,_,_,25);
	DRP_RegisterItem("Wine Cooler","_Alcohol","A fruity wine cooler",1,_,_,20);
	DRP_RegisterItem("Captain Morgan's","_Alcohol","Rum. Got a little Captain in You?",1,_,_,45);
	DRP_RegisterItem("Absolut Vodka","_Alcohol","Vodka. The best you can get.",1,_,_,45);
	DRP_RegisterItem("Champagne","_Alcohol","A bottle of some Italian champagne.",1,_,_,35);
	
	DRP_RegisterItem("Viva La Drak","_Alcohol","A bottle of some extremly expensive wine.",1,_,_,70);
	DRP_RegisterItem("Spanky's XXX","_Alcohol","A bottle of some extremly expensive wine.",1,_,_,70);
	
	DRP_RegisterItem("Full Breakfast Meal","_Food","Egg's, Bacon, Pancakes, Fruit, and some coffee.",1,_,_,1,100,10);
	DRP_RegisterItem("Pizza","_Food","A single slice of pizza",1,_,_,1,30,5);
	DRP_RegisterItem("Cheeseburger","_Food","A 1/2lb cheeseburger",1,_,_,1,85,5);
	DRP_RegisterItem("Pasta","_Food","A bowl of some pasta with meat sauce",1,_,_,1,55,5);
	DRP_RegisterItem("Hotdog","_Food","A hotdog with some ketchup",1,_,_,1,25,5);
	DRP_RegisterItem("Steak","_Food","A large nice steak, very filling",1,_,_,1,95,5);
	DRP_RegisterItem("Bag of Cookies","_Food","A small bag of chocolate 'chip cookies",1,_,_,1,10,0);
	DRP_RegisterItem("Doritos","_Food","A small bag of Doritos",1,_,_,1,10,0);
	
	DRP_RegisterItem("Coke","_Food","A can of coke",1,_,_,0,5,0);
	DRP_RegisterItem("Pepsi","_Food","A can of pepsi",1,_,_,0,5,0);
	DRP_RegisterItem("Orange Pop","_Food","A bottle of orange pop",1,_,_,0,10,0);
	DRP_RegisterItem("Dr. Pepper","_Food","A bottle of Dr. Pepper",1,_,_,0,10,0);
	DRP_RegisterItem("Mountain Dew","_Food","A bottle of Mountain Dew",1,_,_,0,10,0);
	
	DRP_RegisterItem("Coffee","_Food","A cup of hot coffee",1,_,_,0,15,-1);
	DRP_RegisterItem("Hot Chocolate","_Food","A cup of Hot Chocolate",1,_,_,0,15,0);
	
	//Eating,HungerLoss,HPGain
	
	DRP_RegisterItem("Bandaids","_Heal","A simple bandage. Heals up to 5 HP",1,_,_,5);
	DRP_RegisterItem("Small Medkit","_Heal","A small medkit. Heals up to 15 HP",1,_,_,15);
	DRP_RegisterItem("Large Medkit","_Heal","A large medkit. Heals up to 35 HP",1,_,_,35);
	DRP_RegisterItem("Complex First Aid","_Heal","Complex First Aid. This requires knowledge of a medic. Heals up to 80 HP",1,_,_,80);
	DRP_RegisterItem("Operation Kit","_Heal","Operation Kit, allows full restoration of the user's HP.",1,_,_,100);
	
	DRP_RegisterItem("Body Armor","_Armor","A full set of body armor",1);
	
	DRP_RegisterItem("Red Lightbulb","_Light","A colored lightbulb",1,_,_,200,0,0);
	DRP_RegisterItem("Green Lightbulb","_Light","A colored lightbulb",1,_,_,0,200,0);
	DRP_RegisterItem("Blue Lightbulb","_Light","A colored lightbulb",1,_,_,0,0,200);
	DRP_RegisterItem("White Lightbulb","_Light","A colored lightbulb",1,_,_,160,160,160);
	DRP_RegisterItem("Purple Lightbulb","_Light","A colored lightbulb",1,_,_,160,32,240);
	
	g_Tazer = DRP_RegisterItem("Tazer","_Tazer","A weapon used to stun people.",0,0,0);
	
	DRP_RegisterItem("Flashbang","_Grenade","A flashbang grenade - blinds nearby people",1,1,1,0);
	DRP_RegisterItem("Tear Gas","_Grenade","A tear gas grenade - renders nearby people confused",1,1,1,1);
	DRP_RegisterItem("Pepper Spray","_PSpray","Pepper Spray. Blind your enemies.",1)
	
	DRP_RegisterItem("Vuvuzela Horn","_Horn","Oh dear god, make it stop. ONLY CAN BE USED ONCE",1);
	
	// Random Items
	// To be used in other plugins / just for fun / etc
	DRP_RegisterItem("Fortune Cookie","_FCookie","They taste good",1);
	
	//DRP_RegisterItem("Name","Handler","Description",Remove,Drop,Give,Val1,Val2,Val3);
}

public _Horn(id)
{ 
	emit_sound(id,CHAN_AUTO,g_HornSounds[random(sizeof(g_HornSounds))],VOL_NORM,ATTN_NORM,0,PITCH_NORM);
	client_cmd(id,"say /shout VUVUZELA!");
}

public DRP_HudDisplay(id,Hud)
{
	if(Hud != HUD_PRIM)
		return
	
	if(g_Eating[id])
		DRP_AddHudItem(id,HUD_PRIM,"Action: Eating/Drinking");
	
	if(g_Alcohol[id])
		DRP_AddHudItem(id,HUD_PRIM,"Alcohol Level: %d^%% %s",g_Alcohol[id],IsPassedOut(id) ? "(Passed out)" : "");
}

public client_putinserver(id)
{
	g_Tazered[id] = 0
	g_Eating[id] = 0

	g_LastTazer[id] = 0.0
	g_MaxSpeed[id] = 0.0
	
	g_Alcohol[id] = 0
	g_Flashlight[id] = 0
	g_DrunkStopper[id] = 0
	
	arrayset(g_Smoking[id],0,4);
}

public client_disconnect(id)
{
	if(g_UserLights[id])
		RemoveLights(id);
	
	RemoveSlowHack(id);
}
/*==================================================================================================================================================*/
SprayAttempt(id)
{
	new const Num = DRP_GetUserItemNum(id,g_Spray);
	
	if(!Num)
	{
		client_print(id,print_chat,"[DRP] You need a spraycan to spray.")
		return FAILED
	}
	
	DRP_SetUserItemNum(id,g_Spray,Num - 1);
	return SUCCEEDED
}
FlashlightAttempt(id)
{
	if(!DRP_GetUserItemNum(id,g_FlashlightID))
	{
		client_print(id,print_chat,"[DRP] You do not have a flashlight.")
		return FAILED
	}
	_Flashlight(id,g_FlashlightID);
	return SUCCEEDED
}
/*==================================================================================================================================================*/
public EventDeathMsg()
{
	new const id = read_data(2);
	if(!id)
		return
	
	g_Tazered[id] = 0
	g_MaxSpeed[id] = 0.0
	g_LastTazer[id] = 0.0
	
	g_Eating[id] = 0
	g_Alcohol[id] = 0
	g_Flashlight[id] = 0
	
	g_Smoking[id][TIMELEFT] = -1
	g_Smoking[id][IN_PROGRESS] = 0
}
/*==================================================================================================================================================*/
public HandleSay(id,const Args[])
{
	if(equali(Args,"/stopsmoking",12))
	{
		if(!g_Smoking[id][IN_PROGRESS])
		{
			client_print(id,print_chat,"[DRP] You are not currently smoking.");
			return PLUGIN_HANDLED
		}
		
		g_Smoking[id][TIMELEFT] = -1
		g_Smoking[id][IN_PROGRESS] = 0
		
		client_print(id,print_chat,"[DRP] You throw the burning smoke to the ground.");
		
		// We didn't finish it, let's give some of our health back
		new Health = pev(id,pev_health);
		if(g_Smoking[id][HPLOSS] >= 1 && Health < 100)
			set_pev(id,pev_health,Health + random_float(0.0,5.0));
		
		return PLUGIN_HANDLED
	}
	else if(equali(Args,"/removelight",12))
	{
		if(!g_UserLights[id])
		{
			client_print(id,print_chat,"[DRP] You currently don't have any lights.");
			return PLUGIN_HANDLED
		}
		
		new Menu = menu_create("Select the light to Remove","_LightMenu");
		new Ent = 0
		
		while(( Ent = engfunc(EngFunc_FindEntityByString,Ent,"classname",g_Lightbulb)) != 0)
		{
			if(pev(Ent,pev_owner) == id)
			{
				new ItemName[33],Info[12]
				DRP_GetItemName(pev(Ent,pev_iuser3),ItemName,32);
				
				num_to_str(Ent,Info,11);
				menu_additem(Menu,ItemName,Info);
			}
		}
		
		client_print(id,print_chat,"[DRP] There may be duplicate names. It goes in order, from which you spawned them.");
		menu_display(id,Menu);
		
		/*
		while
		new EntList[11],Num = find_sphere_class(id,g_Lightbulb,130.0,EntList,10);
		if(Num)
		{
			new Ent
			for(new Count;Count < Num;Count++)
			{
				Ent = EntList[Count]
				if(pev(Ent,pev_owner) == id)
				{
					client_print(id,print_chat,"[DRP] Light Removed. You now have %d lights left.",MAX_LIGHTS - (--g_UserLights[id]));
					
					new ItemID = pev(Ent,pev_iuser3);
					DRP_SetUserItemNum(id,ItemID,DRP_GetUserItemNum(id,ItemID) + 1)
					
					engfunc(EngFunc_RemoveEntity,Ent);
					return PLUGIN_HANDLED
				}
			}
			client_print(id,print_chat,"[DRP] Unable to find any lights that you own.");
		}
		else
		{
			client_print(id,print_chat,"[DRP] No Lights Found. Stand near the light you want removed.");
			return PLUGIN_HANDLED
		}
		*/
		return PLUGIN_HANDLED
	}
	else if(equali(Args,"/tazer",6))
	{
		if(DRP_IsCop(id))
			_Tazer(id,g_Tazer);
		else
			DRP_GetUserItemNum(id,g_Tazer) ? _Tazer(id,g_Tazer) : client_print(id,print_chat,"[DRP] You do not own a tazer.");
		
		return PLUGIN_HANDLED
	}
	else
	{
		// Kinda hacky
		// Kinda stupid - Oh well. It not's worth it.
		
		if(g_DrunkStopper[id])
			return PLUGIN_CONTINUE
		
		// To drunk to type
		if(g_Alcohol[id])
		{
			if(Args[0] == '/' && !(Args[0] == '/' && Args[1] == '/'))
				return PLUGIN_CONTINUE
			
			new newArgs[256]
			StringScramble(Args,newArgs,255);
			
			g_DrunkStopper[id] = 1
			
			client_cmd(id,"say ^"%s^"",newArgs);
			set_task(1.0,"DrunkStop",id);
			
			return PLUGIN_HANDLED
		}
	}
	return PLUGIN_CONTINUE
}
public DrunkStop(id)
	g_DrunkStopper[id] = 0
public _LightMenu(id,Menu,Item)
{
	if(Item == MENU_EXIT)
	{
		menu_destroy(Menu);
		return PLUGIN_HANDLED
	}
	
	new szEntID[12],Ent,Temp
	menu_item_getinfo(Menu,Item,Temp,szEntID,11,_,_,Temp);
	menu_destroy(Menu);
	
	Ent = str_to_num(szEntID);
	if(pev_valid(Ent))
	{
		new ItemID = pev(Ent,pev_iuser3);
		DRP_SetUserItemNum(id,ItemID,DRP_GetUserItemNum(id,ItemID) + 1)
		
		client_print(id,print_chat,"[DRP] Light Removed. You now have %d lights left.",MAX_LIGHTS - (--g_UserLights[id]));
		engfunc(EngFunc_RemoveEntity,Ent);
	}
	else
	{
		client_print(id,print_chat,"[DRP] Unable to remove light, please contact an administrator.");	
	}
	
	return PLUGIN_HANDLED
}
/*==================================================================================================================================================*/
// Items
public _Atm(id,ItemID)
	client_print(id,print_chat,"[DRP] This item cannot be used; walk up to an ATM to use it.");
public _CreditCard(id,ItemID)
	client_print(id,print_chat,"[DRP] This item cannot be used.");
public _Spray(id,ItemID)
	client_cmd(id,"impulse 201");

public _Searcher(id,ItemID)
{
	new Index,Body
	get_user_aiming(id,Index,Body,100);
	
	if(!Index || !is_user_alive(id))
	{
		client_print(id,print_chat,"[DRP] You must be looking at a player.");
		return PLUGIN_HANDLED
	}
	
	new Results[128],Pos
	new const Len = DRP_FetchUserItems(Index,Results);
	
	if(!Len)
	{
		client_print(id,print_chat,"[DRP] This user has zero items.");
		return PLUGIN_HANDLED
	}
	
	client_print(Index,print_chat,"[DRP] Your inventory is being searched.");
	
	new ItemName[33],Data[512],ItemID
	get_user_name(Index,ItemName,32);
	
	Pos += formatex(Data[Pos],511 - Pos,"Searching ^"%s^" Inventory^n^n",ItemName);
	
	for(new Count;Count < Len;Count++)
	{
		ItemID = Results[Count]
		if(!ItemID)
			continue
		
		DRP_GetItemName(ItemID,ItemName,32);
		Pos += formatex(Data[Pos],511 - Pos,"%s x %d^n",ItemName,DRP_GetUserItemNum(Index,ItemID));
	}
	show_motd(id,Data,"DRP");
	
	return PLUGIN_HANDLED
}
public _Flashlight(id,ItemID)
{
	g_Flashlight[id] = !g_Flashlight[id]
	
	if(g_Flashlight[id])
		set_pev(id,pev_effects,pev(id,pev_effects) | EF_DIMLIGHT);
	else
		set_pev(id,pev_effects,pev(id,pev_effects) & ~EF_DIMLIGHT);
	
	client_print(id,print_chat,"[DRP] You have turned your flashlight %s.",g_Flashlight[id] ? "on" : "off");
	client_cmd(id,"spk ^"items/flashlight1.wav^"");
}
public _Ring(id,ItemID)
{
	new Float:Origin[3]
	pev(id,pev_origin,Origin);
	
	UTIL_DLight(Origin,10,255,255,255,50,3);
	UTIL_ELight(id,Origin,50,255,255,255,35,50);
	
	// Don't use TalkArea to send this message
	// IE: client_cmd(id,"/me blah");
	
	new Name[33]
	get_user_name(id,Name,32);
	
	new iPlayers[32],iNum,Player
	get_players(iPlayers,iNum);
	
	new Float:tOrigin[3]
	for(new Count;Count < iNum;Count++)
	{
		Player = iPlayers[Count]
		
		if(!is_user_alive(Player))
			continue
		
		pev(Player,pev_origin,tOrigin);
		
		if(get_distance_f(tOrigin,Origin) > 300.0)
			continue
		
		client_print(Player,print_chat,"[DRP] %s show's off there diamond ring.",Name);
	}
	
	return ITEM_KEEP_RETURN
}
public _ELockPick(id,ItemID)
{
	if(chance(50))
	{
		client_print(id,print_chat,"[DRP] Your picklock has malfunctioned.");
		return DRP_SetUserItemNum(id,ItemID,DRP_GetUserItemNum(id,ItemID) - 1);
	}
	
	new Index,Body
	get_user_aiming(id,Index,Body,100);
	
	if(!Index)
	{
		client_print(id,print_chat,"[DRP] You must be looking at a door.");
		return ITEM_KEEP_RETURN
	}
	
	new Classname[12]
	pev(Index,pev_classname,Classname,11);
	
	if(containi(Classname,"func_door") == -1)
	{
		client_print(id,print_chat,"[DRP] You must be looking at a door.");
		return ITEM_KEEP_RETURN
	}
	
	emit_sound(Index,CHAN_AUTO,g_Lockpick,VOL_NORM,ATTN_NORM,0,PITCH_NORM);
	
	new EntData[3]
	EntData[0] = Index
	EntData[1] = id
	EntData[2] = 0
	
	set_task(1.0,"PicklockTask",_,EntData,3);
	client_print(id,print_chat,"[DRP] Picklocking.. Don't move away from this door.");
	
	return PLUGIN_HANDLED
}
public PicklockTask(EntData[3])
{
	new const id = EntData[1],Ent = EntData[0]
	
	if(!is_user_alive(id))
		return 1
	
	new Index,Body
	get_user_aiming(id,Index,Body,100);
	
	if(!Index || Index != Ent)
	{
		client_print(id,print_chat,"[DRP] You moved away from the door.");
		return 1
	}
	
	// Only try 5 times
	if(EntData[2] > 5)
	{
		client_print(id,print_chat,"[DRP] Lockpicking failed.");
		return 1
	}
	
	if(random_num(0,4) == 2)
		emit_sound(Index,CHAN_AUTO,g_Lockpick,VOL_NORM,ATTN_NORM,0,PITCH_NORM);
	
	if(chance(5))
	{
		client_print(id,print_chat,"[DRP] The lock has been picked.");
		return dllfunc(DLLFunc_Use,Index,id);
	}
	
	EntData[2]++
	set_task(1.0,"PicklockTask",_,EntData,3);
}
public _Lockpick(id,ItemID)
{
	g_Pick[id] = 0
	LockpickHandle(id,ItemID);
}
LockpickHandle(id,ItemID)
{
	new Index,Body
	get_user_aiming(id,Index,Body,100);
	
	if(!Index)
	{
		client_print(id,print_chat,"[DRP] You must be looking at a door.");
		return ITEM_KEEP_RETURN
	}
	
	new Classname[12]
	pev(Index,pev_classname,Classname,11);
	
	if(containi(Classname,"func_door") == -1)
	{
		client_print(id,print_chat,"[DRP] You must be looking at a door.");
		return ITEM_KEEP_RETURN
	}
	
	new Menu[128]
	format(Menu,127,"Lock Pick^n^n%s%s%s%s^n^n1. Up^n2. Down^n3. Left^n4. Right^n^n0. %s",g_Pick[id] & (1<<0) ? "-" : "|",g_Pick[id] & (1<<1) ? "-" : "|",g_Pick[id] & (1<<2) ? "-" : "|",g_Pick[id] & (1<<3) ? "-" : "|",g_Pick[id] & (1<<3) ? "Open Door" : "Exit");
	
	const Keys = MENU_KEY_0|MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4
	
	show_menu(id,Keys,Menu,-1,g_LockMenu);

	g_Attachments[id] = ItemID
	g_Gun[id] = Index

	return PLUGIN_CONTINUE
}
public LockMenuHandle(id,Key)
{
	if(!is_user_alive(id))
		return PLUGIN_HANDLED
	
	new Index,Body
	get_user_aiming(id,Index,Body,100);
	
	if(Index != g_Gun[id])
		return PLUGIN_HANDLED
	
	if(Key > 3 && Key != 9)
		return LockpickHandle(id,g_Attachments[id]);
	
	if(Key == 9)
	{
		if(g_Pick[id] & (1<<3))
		{
			client_print(id,print_chat,"[DRP] You have opened the door.");
			dllfunc(DLLFunc_Use,g_Gun[id],id);
			
			return PLUGIN_HANDLED
		}
		else
			return PLUGIN_HANDLED
	}
	
	if(Key == random_num(0,3))
	{
		for(new Count;Count < 4;Count++)
		{
			if(!(g_Pick[id] & (1<<Count)))
			{
				g_Pick[id] += (1<<Count)
				break
			}
		}
		
		client_print(id,print_chat,"[DRP] You get one prong on the lock.")
	}
	else if(random_num(1,6) == 1)
	{
		g_Pick[id] = 0
		client_print(id,print_chat,"[DRP] The lock reset with a false move.")
	}
	
	if(random_num(1,30) == 25)
	{
		DRP_SetUserItemNum(id,g_Attachments[id],DRP_GetUserItemNum(id,g_Attachments[id]) - 1);
		return client_print(id,print_chat,"[DRP] Your lock pick snapped.");
	}
	
	return LockpickHandle(id,g_Attachments[id])
}
public _Doorbreak(id,ItemID,Explode)
{
	new Index,Body
	get_user_aiming(id,Index,Body,100);
	
	if(!Index)
	{
		client_print(id,print_chat,"[DRP] You must be looking at a door.");
		return ITEM_KEEP_RETURN
	}
	
	new Classname[12]
	pev(Index,pev_classname,Classname,11);
	
	if(containi(Classname,"func_door") == -1)
	{
		client_print(id,print_chat,"[DRP] You must be looking at a door.");
		return ITEM_KEEP_RETURN
	}
	
	// It's a weapon (EX: Battering Ram)
	if(!Explode)
	{
		return PLUGIN_HANDLED
	}
	
	new Data[2]
	Data[0] = Index
	Data[1] = 0
	
	set_task(1.0,"DoorTimer",_,Data,2);
	client_print(id,print_center,"* Bomb Placed: Timer 8 Seconds *");
	
	return PLUGIN_HANDLED
}
public DoorTimer(Data[2])
{
	new Float:Vol
	new const Index = Data[0]
	
	switch(++Data[1])
	{
		case 1: Vol = 0.1
		case 2: Vol = 0.2
		case 3: Vol = 0.3
		case 4: Vol = 0.4
		case 5: Vol = 0.5
		case 6: Vol = 0.8
		case 7: Vol = 1.0
	}
	
	emit_sound(Index,CHAN_AUTO,g_BombBeep,Vol,ATTN_NORM,0,PITCH_NORM);
	
	if(Data[1] < 8)
		return set_task(1.0,"DoorTimer",_,Data,2);
	
	new Float:Origin[3]
	get_brush_entity_origin(Index,Origin);
	
	engfunc(EngFunc_MessageBegin,MSG_PVS,SVC_TEMPENTITY,Origin,0);
	
	write_byte(TE_EXPLOSION2);
	
	engfunc(EngFunc_WriteCoord,Origin[0]);
	engfunc(EngFunc_WriteCoord,Origin[1]);
	engfunc(EngFunc_WriteCoord,Origin[2]);
	
	write_byte(0);
	write_byte(255);
	message_end()
	
	// We use MSG_BROADCAST because when people first arrive to the broken door (the people outside the PVS)
	// I want the gibs on the ground to be seen
	engfunc(EngFunc_MessageBegin,MSG_BROADCAST,SVC_TEMPENTITY,Origin,0);
	write_byte(TE_BREAKMODEL);
	
	engfunc(EngFunc_WriteCoord,Origin[0]);
	engfunc(EngFunc_WriteCoord,Origin[1]);
	engfunc(EngFunc_WriteCoord,Origin[2] + 5.0);
	
	write_coord(16);
	write_coord(16);
	write_coord(16);
	
	write_coord(random_num(-50,50));
	write_coord(random_num(-50,50));
	write_coord(25);
	
	write_byte(100);
	write_short(g_ModelID);
	
	write_byte(25); // count
	write_byte(500); // life in 0.1s
	write_byte(BREAK_WOOD);
	
	message_end();
	
	set_pev(Index,pev_effects,pev(Index,pev_effects) | EF_NODRAW);
	set_pev(Index,pev_solid,SOLID_NOT);
	
	radius_damage(Origin,90,50);
	set_task(15.0,"ResetDoor",Index)
}
public ResetDoor(const Ent)
	{ set_pev(Ent,pev_effects,pev(Ent,pev_effects) & ~EF_NODRAW); set_pev(Ent,pev_solid,SOLID_BSP); }
/*==================================================================================================================================================*/
public _Food(id,ItemID,Eating,HungerLoss,HPGain)
{
	if(g_Eating[id])
	{
		client_print(id,print_chat,"[DRP] You are already eating/drinking something.");
		return ITEM_KEEP_RETURN
	}
	else if(DRP_GetUserHunger(id) < HungerLoss - 15)
	{
		client_print(id,print_chat,"[DRP] You don't feel like %s this right now.",Eating ? "eating" : "drinking");
		return ITEM_KEEP_RETURN
	}
	
	new ItemName[33],CurArray[5]
	DRP_GetItemName(ItemID,ItemName,32);
	
	g_MaxSpeed[id] = entity_get_float(id,EV_FL_maxspeed);
	g_Eating[id] = 1
	
	// Take away HP
	if(HPGain < 0)
	{
		new Float:Health
		pev(id,pev_health,Health);
		
		if(Health - float(HPGain) > 0)
			set_pev(id,pev_health,Health + HPGain); // adding will subtract
	}
	
	CurArray[0] = id
	CurArray[1] = ItemID
	CurArray[2] = HungerLoss
	CurArray[3] = Eating ? 1 : 0
	CurArray[4] = HPGain > 1 ? HPGain : 0
	
	client_print(id,print_chat,"[DRP] You begin %s the %s",Eating ? "eating" : "drinking",ItemName);
	set_task(5.0,"Eat",_,CurArray,5);
	
	return PLUGIN_CONTINUE
}
public Eat(CurArray[5])
{
	new id = CurArray[0],Food = CurArray[2],ItemHealth = CurArray[4]
	if(!is_user_alive(id))
		return
	
	new const Hunger = DRP_GetUserHunger(id);
	
	if(Food >= 5 && Hunger > 0)
	{
		if(ItemHealth)
		{
			new Float:Health
			pev(id,pev_health,Health);
			
			if(Health < 100)
			{
				ItemHealth -= 5
				
				set_pev(id,pev_health,Health + 5.0);
				CurArray[4] = ItemHealth
			}
		}
		Food -= 5
		DRP_SetUserHunger(id,Hunger - 5);
		
		CurArray[2] = Food
		set_task(6.0,"Eat",_,CurArray,5);
	}
	else
	{
		new ItemName[33]
		DRP_GetItemName(CurArray[1],ItemName,32);
		client_print(id,print_chat,"[DRP] You have finished %s the %s",CurArray[3] ? "eating" : "drinking",ItemName);
		
		entity_set_float(id,EV_FL_maxspeed,g_MaxSpeed[id]);
		
		g_Eating[id] = 0
		g_MaxSpeed[id] = 0.0
	}
}
/*==================================================================================================================================================*/
public _Grenade(id,ItemID,Type)
{
	UTIL_ThrowGrenade(id,Type);
	client_print(id,print_chat,"[DRP] You toss a %s grenade.",Type ? "Tear gas" : "Flashbang");
}
public _PSpray(id,ItemID)
{
	new Index,Body
	get_user_aiming(id,Index,Body,250);
	
	if(!Index || !is_user_alive(Index))
	{
		client_print(id,print_chat,"[DRP] You must be looking at a user.");
		return ITEM_KEEP_RETURN
	}
	
	new Names[33]
	get_user_name(Index,Names,32);
	client_print(id,print_chat,"[DRP] You just sprayed %s in the eyes.",Names);
	
	UTIL_ScreenFade(Index,seconds_to_screenfade_units(8),seconds_to_screenfade_units(8),177,177,20,250,FADE_IN_OUT);
	emit_sound(id,CHAN_ITEM,"player/sprayer.wav",VOL_NORM,ATTN_NORM,0,PITCH_NORM);
	
	get_user_name(id,Names,32);
	client_print(id,print_chat,"[DRP] %s just sprayed you in the eyes with pepper spray.",Names);
	
	set_task(8.0,"PSprayDizzy",Index);
	return PLUGIN_HANDLED
}
public PSprayDizzy(const id)
{
	new Float:Punchangle[3]
	for(new Count;Count < 3;Count++)
		Punchangle[Count] = random_float(-100.0,100.0);	
		
	set_pev(id,pev_punchangle,Punchangle);
}
/*==================================================================================================================================================*/
public _Alcohol(id,ItemID,Alcohol)
{
	// don't drink if we are eating / drinking
	if(g_Eating[id])
	{
		client_print(id,print_chat,"[DRP] You are already eating/drinking something.");
		return ITEM_KEEP_RETURN
	}
	else if(IsPassedOut(id))
	{
		client_print(id,print_chat,"[DRP] You can't handle anymore. You're already passed out.");
		return ITEM_KEEP_RETURN
	}
	
	if(!g_Alcohol[id])
	{
		set_user_rendering(id,kRenderFxGlowShell,160,32,240);
		g_MaxSpeed[id] = entity_get_float(id,EV_FL_maxspeed);
		set_task(1.0,"DrinkAlcohol",id);
	}
	
	g_Alcohol[id] += Alcohol + 5
	
	if(IsPassedOut(id))
	{
		client_print(id,print_chat,"[DRP] * You passed out from drinking to much.");
		DrinkAlcohol(id);
	}
	else
	{
		new ItemName[33]
		DRP_GetItemName(ItemID,ItemName,32);
		client_print(id,print_chat,"[DRP] You start drinking some %s.",ItemName);
	}
	
	return PLUGIN_HANDLED
}
public DrinkAlcohol(const id)
{
	if(g_Alcohol[id] <= 0 || !is_user_alive(id))
	{
		// Clear the purple
		if(is_user_connected(id))
		{
			new Float:Colors[3]
			pev(id,pev_rendercolor,Colors);
			
			if(Colors[0] == 160.000000 && Colors[1] == 32.000000 && Colors[2] == 240.000000)
				set_user_rendering(id);
		}
		
		entity_set_float(id,EV_FL_maxspeed,g_MaxSpeed[id]);
		g_MaxSpeed[id] = 0.0
		
		return PLUGIN_CONTINUE
	}
	
	g_Alcohol[id] -= 5
	
	if(IsPassedOut(id))
	{
		UTIL_ScreenFade(id,~0,~0,0,0,0,255,FFADE_IN);
		return set_task(5.0,"DrinkAlcohol",id);
	}
	else
	// Hacky
	entity_set_float(id,EV_FL_maxspeed,g_MaxSpeed[id]);
	
	if(chance(70))
	{
		new Float:Punchangle[3]
		for(new Count;Count < 3;Count++)
			Punchangle[Count] = random_float(-100.0,100.0);	
		
		set_pev(id,pev_punchangle,Punchangle);
		
		// Slow hacking?
		// Probably - but come on, it's not THAT bad
		client_cmd(id,"+right");
		set_task(1.5,"RemoveSlowHack",id);
	}
	
	if(random(2) == 1 && g_Alcohol[id] > 10)
		UTIL_ScreenFade(id,~0,seconds_to_screenfade_units(6),random_num(10,125),random_num(20,255),random_num(80,125),g_Alcohol[id] >= 80 ? 220 : 165,FFADE_IN);
	
	return (g_Alcohol[id] <= 0) ? DrinkAlcohol(id) : set_task(15.0,"DrinkAlcohol",id);
}
/*==================================================================================================================================================*/
public _Heal(id,ItemID,HealAmount)
{
	new Index,Body
	get_user_aiming(id,Index,Body,200);
	
	if(!Index || !is_user_alive(Index))
		Index = id
	
	new Float:Health
	pev(Index,pev_health,Health);
	
	if(Health > 99.0)
	{
		client_print(id,print_chat,"[DRP] %s health is already full.",Index == id ? "Your" : "That user's");
		return ITEM_KEEP_RETURN
	}
	
	if(HealAmount >= 80 && !DRP_IsMedic(id))
	{
		client_print(id,print_chat,"[DRP] This AID KIT is to complex for you to use. Get a doctor.");
		return ITEM_KEEP_RETURN
	}
	
	client_cmd(id,"spk ^"items/smallmedkit1.wav^"");
	set_pev(Index,pev_health,float(min(floatround(Health + HealAmount),100)));
	
	new Name[33]
	get_user_name(id,Name,32);
	
	if(Index != id)
		client_print(Index,print_chat,"[DRP] You have been healed by %s.",Name);
	
	get_user_name(Index,Name,32);
	client_print(id,print_chat,"[DRP] You have healed %s.",Index == id ? "yourself" : Name);
	
	return PLUGIN_HANDLED
}
public _Armor(id,ItemID,HealAmount)
{
	set_user_armor(id,get_user_armor(id) + 100);
}
/*==================================================================================================================================================*/
public _Light(id,ItemID,Red,Green,Blue)
{
	if(g_UserLights[id] >= MAX_LIGHTS)
	{
		client_print(id,print_chat,"[DRP] You have reached your maximum amount of lights. Use ^"/removelight^" to remove lights.");
		return ITEM_KEEP_RETURN
	}
	
	new Float:Origin[3],Float:EndOrigin[3]
	pev(id,pev_origin,Origin);
	pev(id,pev_origin,EndOrigin);
	
	EndOrigin[2] += 9999.0
	
	if(engfunc(EngFunc_PointContents,Origin) == CONTENTS_SKY)
	{
		client_print(id,print_chat,"[DRP] Unable to place a light here.");
		return ITEM_KEEP_RETURN
	}
	
	// Trace straight up
	new iTrace = create_tr2();
	engfunc(EngFunc_TraceLine,Origin,EndOrigin,IGNORE_MONSTERS,id,iTrace);
	
	get_tr2(iTrace,TR_vecEndPos,Origin);
	free_tr2(iTrace);
	
	if(engfunc(EngFunc_PointContents,Origin) != CONTENTS_EMPTY)
	{
		client_print(id,print_chat,"[DRP] Unable to place a light here.");
		return ITEM_KEEP_RETURN
	}
	
	Origin[2] -= 15.0
	
	new Ent = engfunc(EngFunc_CreateNamedEntity,engfunc(EngFunc_AllocString,"info_target"));
	if(!pev_valid(Ent))
	{
		client_print(id,print_chat,"[DRP] Unable to create the light. Contact an admin.");
		return ITEM_KEEP_RETURN
	}
	
	engfunc(EngFunc_SetModel,Ent,g_LightbulbMdl);
	engfunc(EngFunc_SetOrigin,Ent,Origin);
	engfunc(EngFunc_SetSize,Ent,Float:{-5.0,-5.0,-10.0},Float:{5.0,5.0,10.0});
	
	set_pev(Ent,pev_solid,SOLID_TRIGGER);
	set_pev(Ent,pev_classname,g_Lightbulb);
	set_pev(Ent,pev_scale,0.2);
	set_pev(Ent,pev_owner,id);
	set_pev(Ent,pev_iuser3,ItemID);
	
	new Float:Color[3]
	Color[0] = float(Red);
	Color[1] = float(Green);
	Color[2] = float(Blue);
	
	UTIL_DLight(Origin,25,Red,Green,Blue,200,0);
	
	set_pev(Ent,pev_rendermode,kRenderNormal);
	set_pev(Ent,pev_renderamt,150);
	set_pev(Ent,pev_rendercolor,Color);
	set_pev(Ent,pev_renderfx,0);
	
	// Update
	set_pev(Ent,pev_nextthink,get_gametime() + 20.0);
	client_print(id,print_chat,"[DRP] Lightbulb created. (%d left)",MAX_LIGHTS - ++g_UserLights[id]);
	
	return PLUGIN_HANDLED
}
/*==================================================================================================================================================*/
public _WeaponHandle(id,ItemID)
{
	g_Attachments[id] = 0
	g_Gun[id] = ItemID
	
	return _Weapon(id,ItemID);
}
_Weapon(id,ItemID)
{
	new Menu[256],ItemName[33],Pos,Cell = -1,Num
	DRP_GetItemName(ItemID,ItemName,32);
	
	Pos += formatex(Menu,511,"Attachments: %s^n",ItemName);
	
	for(new Count;Count < TS_MAX_WEAPONS;Count++)
	{
		if(g_GunStats[Count][ITEMID] == ItemID && g_GunStats[Count][ITEMID])
		{			
			Cell = Count
			g_Cell[id] = Count
			break
		}
	}
	
	if(Cell == -1)
		return 1
	
	// There's no attachments for this gun
	if(!g_GunStats[Cell][ATTACHMENTS])
	{
		GiveWeapon(id);
		return 1
	}
	
	if(g_GunStats[Cell][ATTACHMENTS] & TSA_FLASHLIGHT)
		Pos += formatex(Menu[Pos],255 - Pos,"%d. Flashlight %s^n",++Num,g_Attachments[id] & TSA_FLASHLIGHT ? "*" : "")
	if(g_GunStats[Cell][ATTACHMENTS] & TSA_LASERSIGHT)
		Pos += formatex(Menu[Pos],255 - Pos,"%d. Lasersight %s^n",++Num,g_Attachments[id] & TSA_LASERSIGHT ? "*" : "")
	if(g_GunStats[Cell][ATTACHMENTS] & TSA_SCOPE)
		Pos += formatex(Menu[Pos],255 - Pos,"%d. Scope %s^n",++Num,g_Attachments[id] & TSA_SCOPE ? "*" : "")
	if(g_GunStats[Cell][ATTACHMENTS] & TSA_SILENCER)
		Pos += formatex(Menu[Pos],255 - Pos,"%d. Suppressor %s^n",++Num,g_Attachments[id] & TSA_SILENCER ? "*" : "")
		
	formatex(Menu[Pos],511 - Pos,"^n0. Done");
	
	new Keys = (1<<9)
	for(new Count;Count < Num;Count++)	
		Keys |= (1<<Count)
	
	show_menu(id,Keys,Menu,-1,g_AttachmentMenu);
	return 1
}
public AttachMenuHandle(id,Key)
{
	new Attachments[4],Num,Temp
	Temp = g_GunStats[g_Cell[id]][ATTACHMENTS]
	
	for(new Count;Count < 4;Count++)
	{
		if(Temp & TSA_FLASHLIGHT)
		{
			Attachments[Num++] = TSA_FLASHLIGHT
			Temp -= TSA_FLASHLIGHT
		}
		else if(Temp & TSA_LASERSIGHT)
		{
			Attachments[Num++] = TSA_LASERSIGHT
			Temp -= TSA_LASERSIGHT
		}
		else if(Temp & TSA_SCOPE)
		{
			Attachments[Num++] = TSA_SCOPE
			Temp -= TSA_SCOPE
		}
		else if(Temp & TSA_SILENCER)
		{
			Attachments[Num++] = TSA_SILENCER
			Temp -= TSA_SILENCER
		}
	}
	
	if(Key != 9 && !Attachments[Key])
	{
		_Weapon(id,g_Gun[id]);
		return
	}
	
	if(Key == 9)
	{
		GiveWeapon(id);
		return
	}
	
	if(!(g_Attachments[id] & Attachments[Key]))
		g_Attachments[id] += Attachments[Key]
	else
		g_Attachments[id] -= Attachments[Key]
		
	_Weapon(id,g_Gun[id]);
}	

GiveWeapon(const id)
	DRP_TSGiveUserWeapon(id,g_Cell[id],250,g_Attachments[id]);
/*==================================================================================================================================================*/
public _Smoke(id,ItemID,Time,HPLose)
{
	if(g_Smoking[id][TIMELEFT] > 0 && !g_Smoking[id][IN_PROGRESS])
	{
		client_print(id,print_chat,"[DRP] You take the smoke out of your mouth, and replace it.");
		
		// Give back the previous one.
		DRP_SetUserItemNum(id,_:g_Smoking[id][ITEMID],DRP_GetUserItemNum(id,g_Smoking[id][ITEMID]) + 1);
	}
	else if(g_Smoking[id][IN_PROGRESS])
	{
		client_print(id,print_chat,"[DRP] You are already smoking something. Type ^"/stopsmoking^" to stop smoking.");
		return ITEM_KEEP_RETURN
	}
	
	g_Smoking[id][TIMELEFT] = Time
	g_Smoking[id][ITEMID] = ItemID
	g_Smoking[id][HPLOSS] = HPLose
	g_Smoking[id][IN_PROGRESS] = 0
	
	new ItemName[33]
	DRP_GetItemName(ItemID,ItemName,32);
	
	client_print(id,print_chat,"[DRP] You put a %s in your mouth.",ItemName);
	return PLUGIN_HANDLED
}
public _Lighter(id,ItemID)
{
	if(g_Smoking[id][TIMELEFT] <= 0)
	{
		client_print(id,print_chat,"[DRP] You have nothing in your mouth to light up.");
		return ITEM_KEEP_RETURN
	}
	
	if(g_Smoking[id][IN_PROGRESS])
	{
		client_print(id,print_chat,"[DRP] You are already smoking something. Type ^"/stopsmoking^" to stop smoking.");
		return ITEM_KEEP_RETURN
	}
	
	if(g_Smoking[id][HPLOSS] >= 1)
	{
		new const HPLoss = g_Smoking[id][HPLOSS],Health = pev(id,pev_health);
		if( (Health - HPLoss <= 1) )
		{
			client_print(id,print_chat,"[DRP] You are not healthy enough to smoke this.");
			return ITEM_KEEP_RETURN
		}
	}
	
	new ItemName[33],Float:Origin[3]
	pev(id,pev_origin,Origin);
	
	DRP_GetItemName(g_Smoking[id][ITEMID],ItemName,32);
	
	g_Smoking[id][IN_PROGRESS] = 1
	client_print(id,print_chat,"[DRP] You begin smoking a ^"%s^".",ItemName);
	
	UTIL_ELight(id,Origin,50,255,165,0,10,50);
	set_task(1.0,"SmokeItem",id);
	
	new Data[2]
	Data[0] = id
	Data[1] = g_Smoking[id][ITEMID]
	
	if(DRP_CallEvent("Player_SmokeItem",Data,2))
		return PLUGIN_HANDLED
	
	return PLUGIN_HANDLED
}
public _FCookie(id,ItemID)
{
	new const szFortunes[4][256] = 
	{
		"Black people, are refered as ^"niggers^"",
		"You have no fortune. You mad bro?",
		"You will see the end today.",
		"The one person, is thinking about you."
	}
	
	client_print(id,print_chat,"[DRP] Your Fortune: ^"%s^" Lucky Numbers: [ %d %d %d ]",szFortunes[random(sizeof(szFortunes))],random_num(0,10),random_num(0,10),random_num(0,10));
	return PLUGIN_HANDLED
}
public _Tazer(id,ItemID)
{
	if(g_Tazered[id] || !is_user_alive(id))
		return PLUGIN_HANDLED
	
	new Index,Body
	get_user_aiming(id,Index,Body,350);
	
	if(!Index || !is_user_alive(Index))
	{
		client_print(id,print_chat,"[DRP] You must be looking at another player.")
		return PLUGIN_HANDLED
	}
	
	new Float:Time = get_gametime();
	if(Time - g_LastTazer[id] < 60.0 && g_LastTazer[id])
	{
		client_print(id,print_chat,"[DRP] Your tazer is currently recharging.");
		return PLUGIN_HANDLED
	}
	
	if(g_Tazered[Index])
	{
		client_print(id,print_chat,"[DRP] That user is already tazered.");
		return PLUGIN_HANDLED
	}
	
	// This is kinda cheap - but it helps keeps the tazers from people who are not cops
	if(!DRP_IsCop(id))
	{
		if(chance(5))
		{
			client_print(id,print_chat,"[DRP] Your tazer has short-circuited.")
			return DRP_SetUserItemNum(id,ItemID,DRP_GetUserItemNum(id,ItemID) - 1);
		}
	}
	
	g_LastTazer[id] = Time
	g_Tazered[Index] = 1
	
	new Float:tOrigin[3]
	pev(Index,pev_origin,tOrigin);
	
	message_begin(MSG_BROADCAST,SVC_TEMPENTITY);
	write_byte(TE_BEAMENTPOINT);
	write_short(id);
	
	engfunc(EngFunc_WriteCoord,tOrigin[0]);
	engfunc(EngFunc_WriteCoord,tOrigin[1]);
	engfunc(EngFunc_WriteCoord,tOrigin[2]);
	
	write_short(g_Lightning);
	write_byte(1) // framestart
	write_byte(5) // framerate
	write_byte(15) // life
	write_byte(25) // width
	write_byte(30) // noise
	write_byte(125) // r, g, b
	write_byte(125) // r, g, b
	write_byte(225) // r, g, b
	write_byte(200) // brightness
	write_byte(200) // speed
	
	message_end();
	
	client_print(Index,print_center,"[DRP] You have been tasered.");
	emit_sound(id,CHAN_AUTO,g_TazerSound,0.8,ATTN_NORM,0,PITCH_NORM);
	
	UTIL_ScreenFade(Index,seconds_to_screenfade_units(8),seconds_to_screenfade_units(8),0,0,0,255);
	
	g_MaxSpeed[Index] = entity_get_float(id,EV_FL_maxspeed);
	set_rendering(Index,kRenderFxGlowShell,10,10,225,kRenderNormal,16);
	
	// Tazer's don't make the user drop there weapons
	// That is controlled by the cops "frisking" features
	
	set_task(8.0,"ClearEffects",Index);
	return PLUGIN_HANDLED
}
public ClearEffects(Index)
{
	new Float:Colors[3]
	pev(Index,pev_rendercolor,Colors);
	
	if(Colors[0] == 10.0 && Colors[1] == 10.0 && Colors[2] == 225.0)
		set_rendering(Index); // When you tazer a user, you usually cuff them. Remove the render only if we are still blue
	
	set_pev(Index,pev_maxspeed,g_MaxSpeed[Index]);
	
	g_MaxSpeed[Index] = 0.0
	g_Tazered[Index] = 0
}
/*==================================================================================================================================================*/
// Tasks
public SmokeItem(id)
{
	if(g_Smoking[id][TIMELEFT] <= 0)
	{
		g_Smoking[id][IN_PROGRESS] = 0
		
		new Data[2]
		Data[0] = id
		Data[1] = 0
		
		DRP_CallEvent("Player_SmokeItem",Data,2);
		
		if(g_Smoking[id][TIMELEFT] == -1)
			return arrayset(g_Smoking[id],0,4)
		
		new ItemName[33]
		DRP_GetItemName(_:g_Smoking[id][ITEMID],ItemName,32);
		
		client_print(id,print_chat,"[DRP] You finish the %s and toss it to the ground.",ItemName);
		arrayset(g_Smoking[id],0,4);
	}
	else
	{
		g_Smoking[id][TIMELEFT]--
		
		new Float:Origin[3]
		pev(id,pev_origin,Origin);
		
		engfunc(EngFunc_MessageBegin,MSG_PVS,SVC_TEMPENTITY,Origin,0);
		write_byte(TE_SMOKE);
		
		engfunc(EngFunc_WriteCoord,Origin[0] + random_num(-5,5));
		engfunc(EngFunc_WriteCoord,Origin[1] + random_num(-5,5));
		engfunc(EngFunc_WriteCoord,Origin[2] + 20);
	
		write_short(g_Smoke);
		write_byte(g_Smoking[id][ITEMID] == g_Reserva ? 18 : random_num(4,12));
		
		write_byte(12); // 15
		message_end();
		
		if(g_Smoking[id][HPLOSS]-- >= 1)
			set_pev(id,pev_health,pev(id,pev_health) - 1.0);
		
		// Second hand smoke
		if(random(5) == 2 && g_Smoking[id][ITEMID] == g_Reserva)
		{
			new iPlayers[32],iNum,Player
			get_players(iPlayers,iNum);
			
			new Float:Origin[3],Float:pOrigin[3]
			pev(id,pev_origin,Origin);
			
			for(new Count;Count < iNum;Count++)
			{
				Player = iPlayers[Count]
				
				if(!is_user_alive(Player) || Player == id)
					continue
				
				pev(Player,pev_origin,pOrigin);
				
				if(get_distance_f(Origin,pOrigin) > 300.0)
					continue
				
				emit_sound(Player,CHAN_AUTO,g_CoughSound,VOL_NORM,ATTN_NORM,0,PITCH_NORM);
				client_print(Player,print_chat,"[DRP] You cough from the nearby smoke.");
			}
		}
		
		switch(random(3))
		{
			case 0: set_task(2.5,"SmokeItem",id);
			case 1: set_task(3.5,"SmokeItem",id);
			case 2: 
			{ 
				UTIL_ELight(id,Origin,50,255,165,0,20,50);
				set_task(4.5,"SmokeItem",id);
			}
		}
	}
	return PLUGIN_HANDLED
}
/*==================================================================================================================================================*/
public forward_PreThink(const id)
{
	if(g_Eating[id] || g_Tazered[id] || g_Alcohol[id])
	{
		static Button
		Button = pev(id,pev_button);
		
		if(Button != 0)
			set_pev(id,pev_button,Button & ~IN_ALT1 & ~IN_JUMP);
		
		if(g_Alcohol[id])
			set_pev(id,pev_maxspeed,IsPassedOut(id) ? (g_MaxSpeed[id] / 4) : (g_MaxSpeed[id] / 1.2));
		else
			set_pev(id,pev_maxspeed,g_Tazered[id] ? (g_MaxSpeed[id] / 2.5) : (g_MaxSpeed[id] / 2.0));
	}
}
public forward_Think(const Ent)
{
	if(!Ent)
		return FMRES_IGNORED
	
	static Classname[12]
	pev(Ent,pev_classname,Classname,11);
	
	// Soon as we think - boom
	if(equali(Classname,g_Grenade))
	{
		new const Type = pev(Ent,pev_iuser2);
		
		switch(Type)
		{
			// Flashbang
			case 0:
			{
				new iPlayers[32],iNum,Player
				get_players(iPlayers,iNum);
				
				new Float:pOrigin[3],Float:Origin[3]
				pev(Ent,pev_origin,Origin);
				
				for(new Count;Count < iNum;Count++)
				{
					Player = iPlayers[Count]
					
					if(!is_user_alive(Player))
						continue
					
					pev(Player,pev_origin,pOrigin);
					
					if(get_distance_f(pOrigin,Origin) > 600.0)
						continue
						
					UTIL_ScreenFade(Player,~0,seconds_to_screenfade_units(15),255,255,255,225,FFADE_IN);
				}
				
				emit_sound(Ent,CHAN_AUTO,g_FlashSound,1.0,ATTN_NORM,0,PITCH_NORM);
				engfunc(EngFunc_RemoveEntity,Ent);
				
				engfunc(EngFunc_MessageBegin,MSG_PVS,SVC_TEMPENTITY,Origin,0);
				write_byte(TE_SPARKS);
				
				engfunc(EngFunc_WriteCoord,Origin[0]);
				engfunc(EngFunc_WriteCoord,Origin[1]);
				engfunc(EngFunc_WriteCoord,Origin[2] + 10.0);
				
				message_end();
			}
			// Tear Gas
			case 1:
			{
				new Float:Origin[3],Float:pOrigin[3],Num = pev(Ent,pev_iuser3);
				pev(Ent,pev_origin,Origin);
				
				if(Num > MAX_TEARGAS_UPDATE)
				{
					engfunc(EngFunc_RemoveEntity,Ent);
					return FMRES_HANDLED
				}
				else if(Num <= 0)
					emit_sound(Ent,CHAN_AUTO,g_FlashSound,1.0,ATTN_NORM,0,PITCH_NORM); // first boom
				
				engfunc(EngFunc_MessageBegin,MSG_PVS,SVC_TEMPENTITY,Origin,0);
				write_byte(TE_FIREFIELD);
				
				engfunc(EngFunc_WriteCoord,Origin[0] );
				engfunc(EngFunc_WriteCoord,Origin[1]);
				engfunc(EngFunc_WriteCoord,Origin[2]);
				
				write_short(100);
				write_short(g_Smoke);
				
				write_byte(100);
				write_byte(TEFIRE_FLAG_SOMEFLOAT|TEFIRE_FLAG_ALPHA|TEFIRE_FLAG_LOOP|TEFIRE_FLAG_PLANAR);
				write_byte(6 * 10);
				
				message_end();
				
				set_pev(Ent,pev_nextthink,get_gametime() + 5.0);
				set_pev(Ent,pev_iuser3,Num + 1);
				
				new iPlayers[32],iNum,Player
				get_players(iPlayers,iNum);
				
				for(new Count;Count < iNum;Count++)
				{
					Player = iPlayers[Count]
					
					pev(Player,pev_origin,pOrigin);
					
					if(!is_user_alive(Player))
						continue
					
					if(get_distance_f(pOrigin,Origin) > 600.0)
						continue
						
					UTIL_ScreenFade(Player,~0,seconds_to_screenfade_units(10),255,255,0,225,FFADE_IN);
					
					new Float:Health
					pev(Player,pev_health,Health);
					
					if(Health > 1.0)
						set_pev(Player,pev_health,Health - 1.0);
					
					for(new Count;Count < 3;Count++)
						Origin[Count] = random_float(-100.0,100.0);	
					
					set_pev(Player,pev_punchangle,Origin);
					emit_sound(Player,CHAN_AUTO,g_CoughSound,VOL_NORM,ATTN_NORM,0,PITCH_NORM);
				}
			}
		}
		
		return FMRES_IGNORED
	}
	
	if(!equali(Classname,g_Lightbulb))
		return FMRES_IGNORED
	
	static Float:Color[3],Float:Origin[3]
	pev(Ent,pev_rendercolor,Color);
	pev(Ent,pev_origin,Origin);
	
	UTIL_DLight(Origin,20,floatround(Color[0]),floatround(Color[1]),floatround(Color[2]),200,0);
	
	static UpdateNum
	UpdateNum = pev(Ent,pev_iuser2);
	
	if(UpdateNum >= MAX_LIGHTS_UPDATE)
	{
		// If the owner of this light is connected, give the light back to him.
		new id = pev(Ent,pev_owner),ItemID = pev(Ent,pev_iuser3);
		if(is_user_connected(id))
			DRP_SetUserItemNum(id,ItemID,DRP_GetUserItemNum(id,ItemID) + 1);
		
		engfunc(EngFunc_RemoveEntity,Ent);
		return FMRES_HANDLED
	}
	
	set_pev(Ent,pev_nextthink,get_gametime() + 20.0);
	set_pev(Ent,pev_iuser2,UpdateNum + 1);
	
	return FMRES_HANDLED
}
public forward_CmdStart(id,uc_handle,Seed)
{
	static Impulse
	Impulse = get_uc(uc_handle,UC_Impulse);
	
	switch(Impulse)
	{
		case 100:
		{
			if(!FlashlightAttempt(id))
				set_uc(uc_handle,UC_Impulse,0);
		}
		case 201:
		{
			if(!SprayAttempt(id))
				set_uc(uc_handle,UC_Impulse,0);
		}
	}
	return FMRES_IGNORED
}
/*==================================================================================================================================================*/
RemoveLights(const id)
{
	new Ent = 0
	while(( Ent = engfunc(EngFunc_FindEntityByString,Ent,"classname",g_Lightbulb)) != 0)
		if(pev(Ent,pev_owner) == id)
			engfunc(EngFunc_RemoveEntity,Ent);
		
	g_UserLights[id] = 0
}
// Stocks / UTILS
// DLIGHT - 200 (20 seconds) is the max life
UTIL_DLight(const Float:Origin[3],Radius,Red,Green,Blue,Life,Decay)
{
	message_begin(MSG_BROADCAST,SVC_TEMPENTITY);
	write_byte(TE_DLIGHT);
	
	engfunc(EngFunc_WriteCoord,Origin[0]);
	engfunc(EngFunc_WriteCoord,Origin[1]);
	engfunc(EngFunc_WriteCoord,Origin[2]);
	
	write_byte(Radius);
	write_byte(Red);
	write_byte(Green);
	write_byte(Blue);
	write_byte(Life); // 0.1's
	write_byte(Decay);
	
	message_end();
}
UTIL_ELight(id,const Float:Origin[3],Radius,Red,Green,Blue,Life,Decay)
{
	engfunc(EngFunc_MessageBegin,MSG_PVS,SVC_TEMPENTITY,Origin,0);
	write_byte(TE_ELIGHT);
	write_short(id);
	
	engfunc(EngFunc_WriteCoord,Origin[0]);
	engfunc(EngFunc_WriteCoord,Origin[1]);
	engfunc(EngFunc_WriteCoord,Origin[2]);
	
	write_coord(Radius);
	write_byte(Red);
	write_byte(Green);
	write_byte(Blue);
	write_byte(Life); // 10's
	write_coord(Decay); // 10's
	
	message_end();
}
UTIL_Funnel()
{
	engfunc(EngFunc_MessageBegin,MSG_PVS,SVC_TEMPENTITY,Origin,0);
	write_byte(TE_ELIGHT);
	write_short(id);
	
	engfunc(EngFunc_WriteCoord,Origin[0]);
	engfunc(EngFunc_WriteCoord,Origin[1]);
	engfunc(EngFunc_WriteCoord,Origin[2]);
	
	write_coord(Radius);
	write_byte(Red);
	write_byte(Green);
	write_byte(Blue);
	write_byte(Life); // 10's
	write_coord(Decay); // 10's
	
	message_end();
}
UTIL_ScreenShake(id,Amount,Length)
{
	message_begin(MSG_ONE_UNRELIABLE,gmsgScreenShake,_,id);
	
	write_short(seconds_to_screenfade_units(Amount)); // Shake Amount
	write_short(10<<Length); // Last this long
	write_short(255<<14); // Shake Noise Frequency
	
	message_end();
}
UTIL_ScreenFade(id,Duration,HoldTime,Red,Green,Blue,Alpha,Flags = 0)
{
	message_begin(MSG_ONE_UNRELIABLE,gmsgTSFade,_,id);
	
	write_short(Duration); // Duration
	write_short(HoldTime); // Hold Time
	write_short(Flags ? FFADE_OUT : Flags);
	
	write_byte(Red);
	write_byte(Green);
	write_byte(Blue);
	write_byte(Alpha);
	
	message_end();
}
UTIL_ThrowGrenade(const id,Type)
{
	if(!is_user_alive(id))
		return FAILED
	
	new Ent = create_entity("info_target");
	if(!Ent)
		return FAILED
	
	set_pev(Ent,pev_movetype,MOVETYPE_TOSS);
	set_pev(Ent,pev_classname,g_Grenade);
	set_pev(Ent,pev_solid,SOLID_TRIGGER);
	set_pev(Ent,pev_iuser2,Type);
	
	new Float:Velo[3]
	pev(id,pev_origin,Velo);
	
	engfunc(EngFunc_SetModel,Ent,"models/w_m61.mdl");
	engfunc(EngFunc_SetOrigin,Ent,Velo);
	
	velocity_by_aim(id,1000,Velo);
	
	set_pev(Ent,pev_velocity,Velo);
	set_pev(Ent,pev_nextthink,get_gametime() + 3.5);
	
	// Easier to see
	set_rendering(Ent,kRenderFxGlowShell,192,192,192);
	
	return SUCCEEDED
}

// I only use "+left" "+right"
// I wanna be extra careful nobody leaves with this on
public RemoveSlowHack(const id)
	{ client_cmd(id,"-left"); client_cmd(id,"-right"); }
	
	
stock StringScramble(const input[],output[],output_len) 
{
	new Array:aNumbers = ArrayCreate(1); 
	new input_len = strlen(input); 
    
	for(new i = 0;i < input_len;i++) 
       ArrayPushCell(aNumbers,i);
     
    new iLastIndex = min(input_len,output_len); 
    new iRand,Changed
	
	for(new i = 0; i < iLastIndex; i++ ) 
    {
		Changed = chance(5);
		if(Changed)
			iRand = random(input_len); 
		
        output[i] = input[ArrayGetCell(aNumbers,Changed ? iRand : i)]; 
        ArrayDeleteItem(aNumbers,Changed ? iRand : i);
        input_len--; 
    }
    
	ArrayDestroy( aNumbers ); 
    return iLastIndex; 
}