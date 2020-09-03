#include <amxmodx>
#include <fakemeta>

#include <drp/drp_core>

#define HUNGER_OFFSET 567478
#define VERSION "1.0"

new p_HungerEnabled
new p_HungerEffects
new p_HungerTimer

new gmsgScreenShake
new gmsgTSFade

new g_Timer

new const g_HungerKey[] = "hunger"

new bool:g_UserEating[33]

public plugin_init()
{
	register_plugin("DRP - Hunger", VERSION, "Drak");
	register_clcmd("drp_testhunger","CmdHungerTest");
	
	// Messages
	gmsgTSFade = get_user_msgid("TSFade");
	gmsgScreenShake = get_user_msgid("ScreenShake");
	
	// Events
	DRP_RegisterEvent("Player_Ready", "Event_Player_Ready");
	
	set_task(1.0, "SetHunger", _, _, _, "b");
}

public DRP_Init()
{
	// Settings
	p_HungerEnabled = register_cvar("DRP_HungerEnable", "1"); // Enabled
	p_HungerEffects = register_cvar("DRP_HungerEffects", "1"); // Show effects of Hunger
	p_HungerTimer = register_cvar("DRP_HungerTimer", "30"); // Base time (in seconds) on when to trigger hunger effects
	
	// Commands
	DRP_RegisterCmd("drp_sethunger", "_SetHunger", "");
}

public _SetHunger(id)
{
	new tt[11]
	read_argv(id, tt, 10);
	client_print(id, print_chat, "G: %s",tt);
	
	DRP_SetUserMaxSpeed(id, SPEED_MUL, 85.55);
	//DRP_SetUserDataInt(id, g_HungerKey, random(150));
}


public DRP_RegisterItems()
{
	DRP_RegisterItem("Full Breakfast Meal", "_Food", "Egg's, Bacon, Pancakes, Fruit, and some coffee.", { 1, 65, 15 }, 3, true);
	/*
	new Data[3]
	Data[0] = 1
	DRP_RegisterItem("Full Breakfast Meal", "_Food", "Egg's, Bacon, Pancakes, Fruit, and some coffee.", Data, 3, true);
	DRP_RegisterItem("Pizza","_Food","A single slice of pizza",1,_,_,1,30,5);
	DRP_RegisterItem("Cheeseburger","_Food","A 1/2lb cheeseburger",1,_,_,1,85,5);
	DRP_RegisterItem("Pasta","_Food","A bowl of some pasta with meat sauce",1,_,_,1,55,5);
	DRP_RegisterItem("Hotdog","_Food","A hotdog with some ketchup",1,_,_,1,25,5);
	DRP_RegisterItem("Steak","_Food","A large nice steak, very filling",1,_,_,1,95,5);
	
	DRP_RegisterItem("Coke","_Food","A can of coke",1,_,_,0,5,0);
	DRP_RegisterItem("Pepsi","_Food","A can of pepsi",1,_,_,0,5,0);
	DRP_RegisterItem("Orange Pop","_Food","A bottle of orange pop",1,_,_,0,10,0);
	DRP_RegisterItem("Dr. Pepper","_Food","A bottle of Dr. Pepper",1,_,_,0,10,0);
	DRP_RegisterItem("Mountain Dew","_Food","A bottle of Mountain Dew",1,_,_,0,10,0);
	
	DRP_RegisterItem("Coffee","_Food","A cup of hot coffee",1,_,_,0,15,-1);
	DRP_RegisterItem("Hot Chocolate","_Food","A cup of Hot Chocolate",1,_,_,0,15,0);
	*/
}

public DRP_HudDisplay(id, Hud)
{
	if(get_pcvar_num(p_HungerEnabled))
	{
		if(Hud == HUD_PRIM)
		{
			new Hunger = DRP_GetUserDataInt(id, g_HungerKey);
			DRP_AddHudItem(id, Hud, "Hunger: %d%%", Hunger);
		}
		else if(Hud == HUD_SEC)
		{
			if(g_UserEating[id])
				DRP_AddHudItem(id, Hud, "Action: Currently Eating/Drinking");
		}
	}
}

public Event_Player_Ready(const Data[])
{
	new id = Data[0]
	g_UserEating[id] = false
	
	new Results[1]
	new Num = DRP_FindItemID("Full Breakfast Meal", Results, 1);
	
	if(Num > 0)
	{
		server_print("GIVE");
		DRP_SetUserItemNum(id, Results[0], 1);
	}
	
	// Load the data for this plugin, which is our hunger level
	DRP_LoadUserData(id);
}


public _Food(id, ItemID, Data[], Len)
{
	if(!get_pcvar_num(p_HungerEnabled))
	{
		client_print(id, print_chat, "[DRP] Hunger is currently disabled. No need to eat/drink.");
		return ITEM_KEEP
	}
	
	new bool:isFood = Data[0]
	new hungerRecovered = Data[1], hpChange = Data[2]
	
	if(g_UserEating[id])
	{
		client_print(id, print_chat, "[DRP] You are already eating/drinking something.");
		return ITEM_KEEP
	}
	else if(DRP_GetUserDataInt(id, g_HungerKey) < hungerRecovered)
	{
		client_print(id, print_chat, "[DRP] You don't feel like %s this right now.", isFood ? "eating" : "drinking");
		return ITEM_KEEP
	}
	
	new ItemName[33]
	DRP_GetItemName(ItemID, ItemName, 32);
	
	// TODO:
	// Set players max speed here (through DRP core)
	
	g_UserEating[id] = true
	
	/*
	// Take away HP
	if(HPGain < 0)
	{
		new Float:Health
		pev(id,pev_health,Health);
		
		if(Health - float(HPGain) > 0)
			set_pev(id,pev_health,Health + HPGain);
	}
	*/
	
	new TaskArray[5]
	TaskArray[0] = id
	TaskArray[1] = ItemID
	TaskArray[2] = hungerRecovered
	TaskArray[3] = isFood
	TaskArray[4] = hpChange
	
	client_print(id, print_chat, "[DRP] You begin %s the %s", isFood ? "eating" : "drinking", ItemName);
	set_task(5.0, "Eat", _, TaskArray, 5);
	
	return PLUGIN_CONTINUE
}
public Eat(TaskArray[5])
{
	new id = TaskArray[0], itemId = TaskArray[1], hungerChange = TaskArray[2], healthChange = TaskArray[4]
	new currentHunger = DRP_GetUserDataInt(id, g_HungerKey);
	
	if(!is_user_alive(id))
	{
		g_UserEating[id] = false
		return
	}
	
	if(hungerChange > 0 && currentHunger > 0)
	{
		/*
		if(hpChange != 0)
		{
			new Float:Health
			pev(id, pev_health, Health);
			
			set_pev(id, pev_health, Health + healthChange)
			if(Health < 100)
			{
				ItemHealth -= 5
				
				set_pev(id,pev_health,Health + 5.0);
				CurArray[4] = ItemHealth
			}
		}
		*/
		
		new hungerRecovered = random_num(1, min(hungerChange, 5));
		TaskArray[2] -= hungerRecovered
		
		DRP_SetUserDataInt(id, g_HungerKey, currentHunger - hungerRecovered);
		set_task(5.0, "Eat", _, TaskArray, 5);
	}
	else
	{
		new ItemName[33]
		DRP_GetItemName(itemId, ItemName, 32);
		
		client_print(id, print_chat, "[DRP] You have finished %s the %s", TaskArray[3] ? "eating" : "drinking", ItemName);
		g_UserEating[id] = false
	}
}
public SetHunger()
{
	if(!get_pcvar_num(p_HungerEnabled))
		return
	
	if(!(++g_Timer >= get_pcvar_num(p_HungerTimer)))
		return
	
	static iPlayers[32],iNum
	get_players(iPlayers,iNum);
	
	for(new Count;Count < iNum;Count++)
		HandleHunger(iPlayers[Count]);
	
	g_Timer = 0
}

HandleHunger(id)
{
	if(!is_user_alive(id))
		return
	
	new currentHunger = DRP_GetUserDataInt(id, g_HungerKey);
	new addedHunger = random_num(0, (currentHunger >= 115) ? 1 : 3);
	
	if(!addedHunger)
		return
	
	new Data[2]
	Data[0] = id
	Data[1] = addedHunger
	
	if(DRP_DoEvent("Player_Hunger", Data, 2) == EVENT_HALT)
		return
	
	DRP_SetUserDataInt(id, g_HungerKey, currentHunger + addedHunger);
	
	new Random = random(3);
	if(!Random)
		return
	
	switch(currentHunger)
	{
		case 92..95:
		{
			switch(Random)
			{ 
				case 1: client_print(id,print_chat,"[HungerMod] You're feeling abit hungry."); 
				case 2: client_print(id,print_chat,"[HungerMod] You're getting hungry.");  
			}
		}
		case 115..120:
		{
			switch(Random)
			{
				case 1: client_print(id,print_chat,"[HungerMod] You are dehidrating. You need food.");
				case 2: client_print(id,print_chat,"[HungerMod] Your body is losing energy.");
			}
			
			if(!get_pcvar_num(p_HungerEffects))
				return
			
			if(currentHunger >= 117)
			{
				if(Random != 2)
				{
					if(is_user_alive(id))
					{
						message_begin(MSG_ONE_UNRELIABLE,gmsgScreenShake,_,id);
						
						write_short(1<<13);
						write_short(seconds_to_screenfade_units(10));
						write_short(5<<14);
						
						message_end();
						
						client_print(id,print_chat,"[HungerMod] You're getting dizzy. Eat something.");
					}
				}
				
				if(!task_exists(id + HUNGER_OFFSET))
					set_task(3.5,"HungerEffects",id + HUNGER_OFFSET,_,_,"a",4);
			}
		}
		case 121..130:
		{
			client_print(id,print_chat,"[HungerMod] You have died from hunger.");
			user_kill(id);
		}
	}
}
public HungerEffects(id)
{
	id -= HUNGER_OFFSET
	
	if(1>= 120 || !is_user_alive(id))
	{
		if(task_exists(id + HUNGER_OFFSET))
			remove_task(id + HUNGER_OFFSET);
		
		return
	}
	
	message_begin(MSG_ONE_UNRELIABLE,gmsgTSFade,_,id);
	
	write_short(seconds_to_screenfade_units(3)) // Duration
	write_short(seconds_to_screenfade_units(1)) // Hold Time
	write_short(FFADE_IN)
	
	write_byte(random_num(50,125));
	write_byte(random_num(80,115));
	write_byte(random(200));
	write_byte(175);
	
	message_end();
}

/*==================================================================================================================================================*/

public CmdHungerTest(id)
{
	/*
	if(!DRP_IsAdmin(id))
		return
	
	const MaxHunger = 120
	DRP_SetUserHunger(id,0);
	
	for(new Count;Count<MaxHunger;Count++)
	{
		if(DRP_GetUserHunger(id) >= MaxHunger)
		{
			server_print("STOPPED AT: %d (Total Time: %d Minutes)",Count,get_pcvar_num(p_HungerTimer) * Count / 60);
			break
		}
		HandleHunger(id);
	}
	DRP_SetUserHunger(id,0);
	* */
}
