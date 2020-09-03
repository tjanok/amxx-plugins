#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <DRP/DRPCore>
#include <DRP/DRPSMod>

#define chance(%1) ( %1 > random(100) ) // %1 = probability 
#define SMOKE_TASK 134

// This plugin uses "callfunc_*" to tap into DRPItems.amxx
// Instead of making natives (really a waste of time)
// So you have to use a lighter, and such. (As if you were smoking an item from DRPItems.amxx)
// The drug screen effects will be handled here. (There's none in DRPItems.amxx)

new const g_Model[] = "models/OZDRP/drpcannabis.mdl"
new const g_EntName[] = "DRP_WEED"
new const g_BongModel[] = "models/OZDRP/bong/drp_bong.mdl"
new const g_EntNameBong[] = "DRP_BONG"

// true/false - are we smoking (not from a bong)
// to handle effects
new bool:g_UserSmoking[33]
new g_UsingDrugs[33]

new g_White
new g_Skunk
new g_Kush
new g_Bong
new g_Crack
new g_Ecstasy
new g_SalviaDrug
new g_WateringCan
new g_HarvestingTool

new Handle:g_SqlHandle

// Types of plants
enum
{
	PLANT_WEED = 0,
	PLANT_SALVIA
}

new p_GrowTime
new p_MaxPlants

new m_Smoke

public client_disconnect(id)
{
	g_UserSmoking[id] = false
	g_UsingDrugs[id] = 0
}

public DRP_Init()
{
	// Main
	register_plugin("DRP - Drugs / Drug Growing","0.1a","Drak");
	
	// CVars
	p_GrowTime = register_cvar("DRP_DrugGrowTime","300");
	p_MaxPlants = register_cvar("DRP_DrugMaxPlants","3");
	
	// Commands
	
	// Precaches
	precache_model(g_Model);
	precache_model(g_BongModel);
	m_Smoke = precache_model("sprites/steam1.spr");
	
	// Events
	DRP_RegisterEvent("Player_UseEntity","Event_UseEntity");
	DRP_RegisterEvent("Player_SmokeItem","Event_PlayerSmoke");
	
	register_think(g_EntName,"Event_EntityThink");
	register_think(g_EntNameBong,"Event_EntityThinkBong");
	
	if(!find_plugin_byfile("DRPItems.amxx"))
	{
		DRP_ThrowError(1,"Unable to find ^"DRPItems.amxx^" plugin. This will cause problems");
		return 1
	}
	
	// SQL
	new Query[256]
	g_SqlHandle = DRP_SqlHandle();
	
	format(Query,255,"CREATE TABLE IF NOT EXISTS `Drugs` (SteamID VARCHAR(36),PlantType INT(33),X FLOAT(8),Y FLOAT(8),Z FLOAT(8),Level INT(12),Health INT(12),PRIMARY KEY(SteamID))");
	SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",Query);
	
	format(Query,255,"SELECT * FROM `Drugs`");
	SQL_ThreadQuery(g_SqlHandle,"FetchDrugPlants",Query);
}

public DRP_RegisterItems()
{
	g_WateringCan = DRP_RegisterItem("Watering Can","_WaterCan","A watering can. Used on any type of plants.");
	g_HarvestingTool = DRP_RegisterItem("Harvesting Tool","_HarvestTool","A tool to harvest plants.");
	
	DRP_RegisterItem("Salvia Divinorum Seed","_Seed","A seed, that needs to be planted/watered - which grows into a Salvia plant.",1,_,_,PLANT_SALVIA);
	DRP_RegisterItem("Weed Seed","_Seed","A seed, that needs to be planted/watered - which grows into a Marijuana plant. The type depends on your Drug skill",1,_,_,PLANT_WEED);
	
	g_White = DRP_RegisterItem("White Widow Weed","_Drug","The best Marijuana ever to be sold.",1,_,_,1);
	g_Skunk = DRP_RegisterItem("Mass Skunk Weed","_Drug","Best sold at Amsterdam coffee shops",1,_,_,2);
	g_Kush = DRP_RegisterItem("OG Kush Weed","_Drug","Very high grade. Not as good as White Widow - but one of the best.",1,_,_,3);
	g_SalviaDrug = DRP_RegisterItem("Salvia Divinorum","_Drug","Salvia. It's like weed - but better.",1,_,_,4);
	
	g_Crack = DRP_RegisterItem("Crack Cocaine","_Drug","Cocaine, in crystal form. You can only smoke this.",1,_,_,5);
	g_Ecstasy = DRP_RegisterItem("Ecstasy","_Drug","Ecstasy / MDMA / X - You'll want todo everything",1,_,_,6);
	
	g_Bong = DRP_RegisterItem("Bong","_Bong","A bong. You can load any type of cannabis into it.",1);
}
/*==================================================================================================================================================*/
public _Bong(id,ItemID)
{	
	new Origin[3],Float:plOrigin[3],Float:fOrigin[3]
	get_user_origin(id,Origin,3);
	
	IVecFVec(Origin,fOrigin);
	entity_get_vector(id,EV_VEC_origin,plOrigin);
	
	if(point_contents(fOrigin) != CONTENTS_EMPTY || vector_distance(plOrigin,fOrigin) > 115.0 )
	{
		client_print(id,print_chat,"[DRP] Unable to place item here. The item is placed where you are aiming.");
		return ITEM_KEEP_RETURN
	}
	
	new Ent = create_entity("info_target");
	fOrigin[2] += 60.0
	
	if(!Ent)
	{
		client_print(id,print_chat,"[DRP] Unable to place item here. There was an internal problem. Contact an administrator.");
		return ITEM_KEEP_RETURN
	}
	
	new AuthID[36]
	get_user_authid(id,AuthID,35);
	
	entity_set_model(Ent,g_BongModel);
	
	entity_set_string(Ent,EV_SZ_classname,g_EntNameBong);
	entity_set_string(Ent,EV_SZ_noise1,AuthID);
	
	entity_set_size(Ent,Float:{-8.0,-8.0,-12.0},Float:{8.0,8.0,18.0});
	entity_set_int(Ent,EV_INT_solid,SOLID_BBOX);
	
	entity_set_origin(Ent,fOrigin);
	
	drop_to_floor(Ent);
	//DrawBox(Ent);
	
	client_print(id,print_chat,"[DRP] You have placed your bong.");
	return PLUGIN_HANDLED
}
public _WaterCan(id,ItemID)
{
	new Body,Index
	get_user_aiming(id,Index,Body,120);
	
	if(!Index)
	{
		client_print(id,print_chat,"[DRP] You must be looking at a plant.");
		return PLUGIN_HANDLED
	}
	
	new Classname[36]
	entity_get_string(Index,EV_SZ_classname,Classname,35);
	
	if(!equali(Classname,g_EntName))
	{
		client_print(id,print_chat,"[DRP] You must be looking at a plant.");
		return PLUGIN_HANDLED
	}
	
	new AuthID[36]
	get_user_authid(id,AuthID,35);
	entity_get_string(Index,EV_SZ_noise1,Classname,35);
	
	if(!equali(AuthID,Classname))
	{
		client_print(id,print_chat,"[DRP] This is not your plant.");
		return PLUGIN_HANDLED
	}
	
	new WaterAmount,DrugSkill = DRP_GetUserSkill(id,S_DRUGS);
	
	switch(DrugSkill)
	{
		case 0..20: WaterAmount = chance(90) ? 4 : 2
		
		case 21..50: WaterAmount = chance(60) ? 4 : 2
		case 51..70: WaterAmount = chance(40) ? 2 : 1
		case 71..90: WaterAmount = chance(10) ? 2 : 1
		
		default: 
			WaterAmount = 1
	}
	
	if(WaterAmount > 1)
		client_print(id,print_chat,"[DRP] You over watered your plant.");
	
	return PLUGIN_HANDLED
}
public _HarvestTool(id,ItemID)
{
	new Body,Index
	get_user_aiming(id,Index,Body,120);
	
	if(!Index)
	{
		client_print(id,print_chat,"[DRP] You must be looking at a plant.");
		return PLUGIN_HANDLED
	}
	
	new Classname[36]
	entity_get_string(Index,EV_SZ_classname,Classname,35);
	
	if(!equali(Classname,g_EntName))
	{
		client_print(id,print_chat,"[DRP] You must be looking at a plant.");
		return PLUGIN_HANDLED
	}
	
	new AuthID[36]
	get_user_authid(id,AuthID,35);
	entity_get_string(Index,EV_SZ_noise1,Classname,35);
	
	if(!equali(AuthID,Classname))
	{
		client_print(id,print_chat,"[DRP] This is not your plant.");
		return PLUGIN_HANDLED
	}
	
	new Level = entity_get_int(Index,EV_INT_body),DrugSkill = DRP_GetUserSkill(id,S_DRUGS);
	if(Level < 3)
	{
		client_print(id,print_chat,"[DRP] Your plant has not grown enough to harvest it.");
		return PLUGIN_HANDLED
	}
	
	// How many seeds we find - is based off of our Skill
	
	new Seeds,Amount,Item
	switch(DrugSkill)
	{
		case 1..20: 
		{
			Seeds = 0
			Amount = 5
		}
		case 21..40:
		{
			Seeds = 1
			Amount = 10
		}
		case 41..80: 
		{
			Seeds = 2
			Amount = 20
		}
		case 81..100: 
		{
			Seeds = 3
			Amount = 30
		}
	}
	
	if(entity_get_int(Index,EV_INT_iuser2) == PLANT_WEED)
	{
		if(Level >= 4 && DrugSkill >= 90)
		{ 
			DRP_GetItemName(g_White,AuthID,35); 
			Item = g_White; 
		}
		else
		{
			if(DrugSkill >= 50)
				{ DRP_GetItemName(g_Skunk,AuthID,35); Item = g_Skunk; }
			else
				{ DRP_GetItemName(g_Kush,AuthID,35); Item = g_Kush; }
		}
	}
	else
	{
		Item = g_SalviaDrug
		DRP_GetItemName(g_SalviaDrug,AuthID,35);
	}
	
	DeletePlant(id,Index);
	
	client_print(id,print_chat,"[DRP] You harvested ^"%s^" x %d and found: %d seeds.",AuthID,Amount,Seeds);
	DRP_SetUserItemNum(id,Item,DRP_GetUserItemNum(id,Item) + Amount);
	
	return PLUGIN_HANDLED
}
public _Drug(id,ItemID,Type)
{
	g_UsingDrug[id] = Type
	
	// Smoking Types
	if(Type <= 5)
	{
		// Check if we are looking at a bong first.
		new Body,Index
		get_user_aiming(id,Index,Body,120);
		
		if(Index)
		{
			new Classname[36],AuthID[36]
			entity_get_string(Index,EV_SZ_classname,Classname,35);
			
			if(equali(Classname,g_EntNameBong))
			{
				get_user_authid(id,AuthID,35);
				entity_get_string(Index,EV_SZ_noise1,Classname,35);
				
				if(equali(AuthID,Classname))
				{
					DRP_GetItemName(ItemID,Classname,35);
					entity_set_int(Index,EV_INT_iuser2,ItemID);
					
					client_print(id,print_chat,"[DRP] You put the %s into the bong. You can remove it by ^"using^" (default: e) the bong.",Classname);
					return PLUGIN_HANDLED
				}
			}
		}
		
		callfunc_begin("_Smoke","DRPItems.amxx");
		callfunc_push_int(id);
		callfunc_push_int(ItemID);
		
		new Time
		switch(Type)
		{
			case 1: Time = 300
			case 2: Time = 100
			case 3: Time = 80
			case 4: Time = 80
			case 5: Time = 300
			case 6: Time = 300
		}
		
		callfunc_push_int(Time);
		callfunc_push_int(0);
		callfunc_end();
		
		client_print(id,print_chat,"[DRP] NOTE: If you look at a bong, and use this item. You will place it into the bong.");
	}
	
	// MDMA
	if(Type == 6)
		client_print(id,print_chat,"[DRP] You gained strong feelings for your surroundings.");
	
	return PLUGIN_HANDLED
}
public _Seed(id,ItemID,Type)
{
	// Check how many plants they have out already.
	new AuthID[36],PlantAuthID[36],Num
	get_user_authid(id,AuthID,35);
	
	new CurrentPlants
	while(( CurrentPlants = find_ent_by_class(CurrentPlants,g_EntName)) != 0)
	{
		entity_get_string(CurrentPlants,EV_SZ_noise1,PlantAuthID,35);
		if(equali(AuthID,PlantAuthID))
			Num++
	}
	
	new Max = get_pcvar_num(p_MaxPlants)
	
	if(Num > Max)
	{
		client_print(id,print_chat,"[DRP] You are only allowed: %d number of plants.",Max);
		return ITEM_KEEP_RETURN
	}
	
	new DrugSkill = DRP_GetUserSkill(id,S_DRUGS),bool:Stop
	if(DrugSkill < 1)
	{
		client_print(id,print_chat,"[DRP] Your drug skill is to low to plant this.");
		return ITEM_KEEP_RETURN
	}
	
	switch(DrugSkill)
	{
		case 1..10: if(chance(90)) Stop = true
		case 11..20: if(chance(80)) Stop = true
		case 21..50: if(chance(50)) Stop = true
		case 51..80: if(chance(20)) Stop = true
		case 81..99: if(chance(5)) Stop = true
	}
	
	if(Stop && !DRP_IsAdmin(id))
	{
		new LoseSeed = chance(5) ? 1 : 0
		client_print(id,print_chat,"[DRP] You messed up planting the seed. You %s your seed.",LoseSeed ? "lost" : "kept");
		client_print(id,print_chat,"[DRP] The higher your drug skill, the less this will happen.");
		return LoseSeed ? PLUGIN_HANDLED : ITEM_KEEP_RETURN
	}
	
	new Origin[3],Float:plOrigin[3],Float:fOrigin[3]
	get_user_origin(id,Origin,3);
	
	IVecFVec(Origin,fOrigin);
	entity_get_vector(id,EV_VEC_origin,plOrigin);
	
	if(point_contents(fOrigin) != CONTENTS_EMPTY || vector_distance(plOrigin,fOrigin) > 115.0 )
	{
		client_print(id,print_chat,"[DRP] Unable to place item here. The item is placed where you are aiming.");
		return ITEM_KEEP_RETURN
	}
	
	new Ent = create_entity("info_target");
	
	if(!Ent)
	{
		client_print(id,print_chat,"[DRP] Unable to place item here. There was an internal problem. Contact an administrator.");
		return ITEM_KEEP_RETURN
	}
	
	entity_set_string(Ent,EV_SZ_classname,g_EntName);
	entity_set_string(Ent,EV_SZ_noise1,AuthID);
	
	entity_set_int(Ent,EV_INT_iuser2,Type);
	entity_set_int(Ent,EV_INT_iuser3,100);
	entity_set_int(Ent,EV_INT_body,0);
	entity_set_int(Ent,EV_INT_solid,SOLID_BBOX);
	entity_set_float(Ent,EV_FL_nextthink,halflife_time() + get_pcvar_float(p_GrowTime));
	
	entity_set_origin(Ent,fOrigin);
	entity_set_model(Ent,g_Model);
	entity_set_size(Ent,Float:{-16.0,-16.0,-36.0},Float:{16.0,16.0,36.0});
	
	//DrawBox(Ent);
	
	drop_to_floor(Ent);
	
	new Query[128]
	format(Query,127,"INSERT INTO `Drugs` VALUES('%s','%d','%f','%f','%f','0','100')",AuthID,Type,fOrigin[0],fOrigin[1],fOrigin[2]);
	SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",Query);
	
	client_print(id,print_chat,"[DRP] You have placed a %s seed. You must take care of this plant.",Type == PLANT_WEED ? "Marijuana" : "Salvia");
	return PLUGIN_HANDLED
}
/*==================================================================================================================================================*/
public client_PreThink(id)
{
	if(!is_user_alive(id))
		return
}
/*==================================================================================================================================================*/
public Event_PlayerSmoke(const Name[],const Data[])
{
	if(Data[0])
	{
		new const ItemID = Data[1]
		g_UserSmoking[Data[0]] = !g_UserSmoking[Data[0]]
		if(g_UserSmoking[Data[0]] && ItemID)
		{
			if(ItemID != g_Ecstasy && ItemID != g_Crack)
				WeedEffects(id);
		}
	}
}

public WeedEffects(id)
{
	if(!g_UserSmoking[id] || !is_user_alive(id))
		return
}
	
public Event_UseEntity(const Name[],const Data[])
{
	new id = Data[0],EntID = Data[1]
	if(!is_user_alive(id) || !is_valid_ent(EntID))
		return PLUGIN_HANDLED
	
	static Classname[9]
	entity_get_string(EntID,EV_SZ_classname,Classname,8);
	
	new Bong = equali(Classname,g_EntNameBong) ? 1 : 0
	
	if(!equali(Classname,g_EntName) && !Bong)
		return PLUGIN_CONTINUE
	
	// Compare SteamID's (Not id's - we might disconnect. The plant stays)
	new AuthID[36],EntAuthID[36]
	get_user_authid(id,AuthID,35);
	entity_get_string(EntID,EV_SZ_noise1,EntAuthID,35);
	
	if(!equali(EntAuthID,AuthID))
		return PLUGIN_HANDLED
	
	new StatusMessage[128],Info[6]
	num_to_str(EntID,Info,5)
	
	if(Bong)
	{
		new ItemName[33]
		new Menu = menu_create("Bong Menu","_BongMenu"),ItemID = entity_get_int(EntID,EV_INT_iuser2);
		
		if(ItemID)
			DRP_GetItemName(ItemID,ItemName,32);
		
		entity_get_int(EntID,EV_INT_iuser3) ? menu_additem(Menu,"",Info) : menu_additem(Menu,"Light the Bong",Info)
		menu_additem(Menu,"Put back into your inventory",Info);
		if(DRP_IsAdmin(id))
			menu_additem(Menu,"Change Color^n",Info);
		
		if(ItemID)
			formatex(StatusMessage,127,"Drug: %s",ItemName);
		else
			formatex(StatusMessage,127,"Drug: None^nYou can place any type of,^ncannabis plant into this^n^nUse the plant when looking,^nat the bong.^n");
		
		menu_addtext(Menu,StatusMessage,0);
		menu_display(id,Menu);
		
		return PLUGIN_HANDLED
	}
	
	new Menu = menu_create("Plant Menu^nWhat would you like todo?","_PlantMenu");
	new Health = entity_get_int(EntID,EV_INT_iuser3);
	
	if(Health > 0)
	{
		menu_additem(Menu,"Water Plant",Info);
		menu_additem(Menu,"Harvest Plant",Info);
		menu_additem(Menu,"Destory Plant",Info);
		menu_additem(Menu,"Help^n",Info);
		
		formatex(StatusMessage,127,"Plant Status:^nHealth: %d%%^nLevel: %d",Health,entity_get_int(EntID,EV_INT_body));
		menu_addtext(Menu,StatusMessage,0);
	}
	else
	{
		menu_setprop(Menu,MPROP_EXIT,MEXIT_NEVER);
		menu_additem(Menu,"Exit^n",Info);
		
		formatex(StatusMessage,127,"Your plant has died^nWhen you exit this menu,^nyour plant will be,^ndeleted");
		menu_addtext(Menu,StatusMessage,0);
	}
	
	menu_display(id,Menu);
	return PLUGIN_HANDLED
}
public Event_EntityThink(const Ent)
{
	if(!Ent)
		return PLUGIN_CONTINUE
	
	// Render the plant based on health
	new Query[256],AuthID[36],Float:fOrigin[3]
	new Health = GetPlantHealth(Ent),HealthChanged
	
	entity_get_string(Ent,EV_SZ_noise1,AuthID,35);
	entity_get_vector(Ent,EV_VEC_origin,fOrigin);
	
	if(Health <= 0)
	{
		// We died
		entity_set_int(Ent,EV_INT_body,0);
		
		// Update just one last time - we won't think again - so this won't query again
		format(Query,255,"UPDATE `Drugs` SET `Health`='0' WHERE `SteamID`='%s' AND X='%f' AND Y='%f' AND Z='%f'",AuthID,fOrigin[0],fOrigin[1],fOrigin[2]);
		SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",Query);
		
		// Don't render
		set_rendering(Ent);
		entity_set_float(Ent,EV_FL_nextthink,0.0); // we died. don't update
		
		return PLUGIN_CONTINUE
	}
	
	new Level = GetPlantLevel(Ent);
	if(Level < 4)
	{
		new Count = entity_get_int(Ent,EV_INT_iuser1) + 1
		if(Count >= 5)
		{
			entity_set_int(Ent,EV_INT_body,Level + 1)
			entity_set_int(Ent,EV_INT_iuser1,0);
		}
		else
			entity_set_int(Ent,EV_INT_iuser1,Count);
	}
	
	// Update SQL
	format(Query,255,"UPDATE `Drugs` SET `Level`='%d',`Health`='%d' WHERE `SteamID`='%s' AND X='%f' AND Y='%f' AND Z='%f'",Level,Health,AuthID,fOrigin[0],fOrigin[1],fOrigin[2]);
	SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",Query);
	
	entity_set_float(Ent,EV_FL_nextthink,halflife_time() + get_pcvar_float(p_GrowTime) + float((Health < 50) ? 15 : 0))
	return PLUGIN_CONTINUE
}
public Event_EntityThinkBong(const Ent)
{
	if(!Ent)
		return PLUGIN_CONTINUE
	
	new TurnedOn = entity_get_int(Ent,EV_INT_iuser3),iNum,Target
	if(!TurnedOn)
		return PLUGIN_CONTINUE
	
	static iPlayers[32],Float:pOrigin[3]
	get_players(iPlayers,iNum);
	
	static Float:tOrigin[3]
	entity_get_vector(Ent,EV_VEC_origin,tOrigin);
	
	for(new Count;Count < iNum;Count++)
	{
		Target = iPlayers[Count]
		entity_get_vector(Target,EV_VEC_origin,pOrigin);
		
		if(!is_user_alive(Target) || vector_distance(tOrigin,pOrigin) > 100.0)
			continue
		
		message_begin(MSG_ONE_UNRELIABLE,get_user_msgid("TSFade"),_,Target);
		
		write_short(seconds_to_screenfade_units(5)); // Duration
		write_short(seconds_to_screenfade_units(1)); // Hold Time
		write_short(FFADE_OUT);
		
		write_byte(0);
		write_byte(175);
		write_byte(0);
		write_byte(125);
		
		message_end();
	}
	
	engfunc(EngFunc_MessageBegin,MSG_PVS,SVC_TEMPENTITY,tOrigin);
	write_byte(TE_SMOKE);
	
	engfunc(EngFunc_WriteCoord,tOrigin[0]);
	engfunc(EngFunc_WriteCoord,tOrigin[1]);
	engfunc(EngFunc_WriteCoord,tOrigin[2]);
	
	write_short(m_Smoke);
	write_byte(random_num(8,10));
	write_byte(4);
	
	message_end();
	
	entity_set_float(Ent,EV_FL_nextthink,halflife_time() + 5.0);
	return PLUGIN_CONTINUE
}
/*==================================================================================================================================================*/
public _BongMenu(id,Menu,Item)
{
	if(Item == MENU_EXIT)
	{
		menu_destroy(Menu);
		return PLUGIN_HANDLED
	}
	
	new Data[6],Temp
	menu_item_getinfo(Menu,Item,Temp,Data,5,_,_,Temp);
	menu_destroy(Menu);
	
	new EntID = str_to_num(Data),Type = entity_get_int(EntID,EV_INT_iuser2);
	switch(Item)
	{
		case 0:
		{
			if(!Type)
			{
				client_print(id,print_chat,"[DRP] There is nothing in your bong.");
				return PLUGIN_HANDLED
			}
			
			new Current = entity_get_int(EntID,EV_INT_iuser3);
			Current = !Current
			
			if(Current)
				client_print(id,print_chat,"[DRP] You lit the bong. Anyone around it will get high.");
			else
				client_print(id,print_chat,"[DRP] You put out the bong.");
			
			entity_set_int(EntID,EV_INT_iuser3,Current);
			entity_set_float(EntID,EV_FL_nextthink,halflife_time() + 1.0);
		}
		case 1:
		{
			DRP_SetUserItemNum(id,g_Bong,DRP_GetUserItemNum(id,g_Bong) + 1);
			engfunc(EngFunc_RemoveEntity,EntID);
			
			client_print(id,print_chat,"[DRP] You have put your bong back into your inventory.");
		}
		case 2:
		{
			entity_set_int(EntID,EV_INT_skin,random(5));
			client_print(id,print_chat,"[DRP] Bong color randomized.");
		}
	}
	return PLUGIN_HANDLED
}
public _PlantMenu(id,Menu,Item)
{
	if(Item == MENU_EXIT)
	{
		menu_destroy(Menu);
		return PLUGIN_HANDLED
	}
	
	new Data[6],Temp
	menu_item_getinfo(Menu,Item,Temp,Data,5,_,_,Temp);
	menu_destroy(Menu);
	
	new EntID = str_to_num(Data),Health = entity_get_int(EntID,EV_INT_iuser3);
	
	if(Health <= 0)
	{
		DeletePlant(id,EntID);
		return PLUGIN_HANDLED
	}
	
	switch(Item)
	{
		case 0:
		{
			if(DRP_GetUserItemNum(id,g_WateringCan) <= 0)
			{
				client_print(id,print_chat,"[DRP] You must have a watering can to water this plant.");
				return PLUGIN_HANDLED
			}
			_WaterCan(id,g_WateringCan);
		}
		case 1:
		{
			if(DRP_GetUserItemNum(id,g_HarvestingTool) <= 0)
			{
				client_print(id,print_chat,"[DRP] You must have a harvesting tool.");
				return PLUGIN_HANDLED
			}
			_HarvestTool(id,g_HarvestingTool);
		}
		case 2:
		{
			client_print(id,print_chat,"[DRP] You have destoryed your plant. No seeds where found.");
			DeletePlant(id,EntID);
		}
		case 3:
		{
			if(!DRP_ShowMOTDHelp(id,"DRPDrugs_Help.txt"))
				client_print(id,print_chat,"[DRP] Unable to show help file.");
		}
			
	}
	
	return PLUGIN_HANDLED
}
/*==================================================================================================================================================*/
public IgnoreHandle(FailState,Handle:Query,const Error[],Errcode,const Data[],DataSize) 
{
	if(FailState != TQUERY_SUCCESS)
		return log_amx("[DRP-CORE] [SQL ERROR] Unable to connect to SQL Database. (Error: %s)",Error ? Error : "UNKNOWN");
	
	return PLUGIN_CONTINUE
}
public FetchDrugPlants(FailState,Handle:Query,const Error[],Errcode,const Data[],DataSize) 
{
	if(FailState != TQUERY_SUCCESS)
		return log_amx("[DRP-CORE] [SQL ERROR] Unable to connect to SQL Database. (Error: %s)",Error ? Error : "UNKNOWN");
	
	if(!SQL_NumResults(Query))
		return PLUGIN_CONTINUE
	
	new AuthID[36],Float:fOrigin[3]
	while(SQL_MoreResults(Query))
	{
		SQL_ReadResult(Query,0,AuthID,35);
		
		fOrigin[0] = float(SQL_ReadResult(Query,2));
		fOrigin[1] = float(SQL_ReadResult(Query,3));
		fOrigin[2] = float(SQL_ReadResult(Query,4));
		
		if(!AuthID[0])
		{
			server_print("[DRP-DRUGS] No AuthID. MAJOR PROBLEM.");
			SQL_NextRow(Query);
			continue;
		}
		
		new Ent = create_entity("info_target");
		if(!Ent)
		{
			server_print("[DRP-DRUGS] Unable to spawn entity. MAJOR PROBLEM.");
			SQL_NextRow(Query);
			continue
		}
		
		entity_set_string(Ent,EV_SZ_classname,g_EntName);
		entity_set_string(Ent,EV_SZ_noise1,AuthID);
		
		new Health = SQL_ReadResult(Query,6),Level = SQL_ReadResult(Query,5);
		
		entity_set_int(Ent,EV_INT_iuser2,SQL_ReadResult(Query,1));
		entity_set_int(Ent,EV_INT_iuser3,Health);
		
		entity_set_int(Ent,EV_INT_body,Level);
		entity_set_int(Ent,EV_INT_solid,SOLID_BBOX);
		
		if(Health > 0)
			entity_set_float(Ent,EV_FL_nextthink,halflife_time() + get_pcvar_float(p_GrowTime));
		
		entity_set_origin(Ent,fOrigin);
		entity_set_model(Ent,g_Model);
		entity_set_size(Ent,Float:{-16.0,-16.0,-36.0},Float:{16.0,16.0,36.0});
		
		drop_to_floor(Ent);
		SQL_NextRow(Query);
	}
	
	return PLUGIN_CONTINUE
}

GetPlantHealth(const EntID)
	return entity_get_int(EntID,EV_INT_iuser3);
GetPlantLevel(const EntID)
	return entity_get_int(EntID,EV_INT_body);

// Removes Entity / SQL Entry
DeletePlant(id,Ent)
{
	new Query[256],Float:fOrigin[3]
	entity_get_vector(Ent,EV_VEC_origin,fOrigin);
	
	new AuthID[36]
	get_user_authid(id,AuthID,35);
	
	formatex(Query,255,"DELETE FROM `Drugs` WHERE `SteamID`='%s' AND X='%f' AND Y='%f' AND Z='%f'",AuthID,fOrigin[0],fOrigin[1],fOrigin[2]);
	SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",Query);
	
	engfunc(EngFunc_RemoveEntity,Ent);
	return PLUGIN_HANDLED
}

public DrawBox(Ent)
{
	new Float:Mins[3],Float:Maxs[3]
	pev(Ent,pev_absmax,Maxs);
	pev(Ent,pev_absmin,Mins);
	
	message_begin(MSG_BROADCAST,SVC_TEMPENTITY);
	write_byte(TE_BOX);
	
	engfunc(EngFunc_WriteCoord,Mins[0]);
	engfunc(EngFunc_WriteCoord,Mins[1]);
	engfunc(EngFunc_WriteCoord,Mins[2]);
	
	engfunc(EngFunc_WriteCoord,Maxs[0]);
	engfunc(EngFunc_WriteCoord,Maxs[1]);
	engfunc(EngFunc_WriteCoord,Maxs[2]);
	
	write_short(10);
	write_byte(255)
	write_byte(25)
	write_byte(2)
	
	message_end();
	
	set_task(1.0,"DrawBox",Ent);
}

#define TE_BOX                      31
// write_byte(TE_BOX)
// write_coord(boxmins.x)
// write_coord(boxmins.y)
// write_coord(boxmins.z)
// write_coord(boxmaxs.x)
// write_coord(boxmaxs.y)
// write_coord(boxmaxs.z)
// write_short(life in 0.1 s)
// write_byte(red)
// write_byte(green)
// write_byte(blue)