#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <engine> // find_sphere_class()
#include <DRP/DRPCore>

#define PRETHINK_ANTI_SPAM 1
#define ORE_DISTANCE 70.0

new TravTrie:g_Materials
new TravTrie:g_Material[33]

new g_LightSprite

new g_LastUse[33]
new g_AntiSpam[33]

new Float:g_FailChance[33]

new g_HarvestTime[33]
new g_Harvesting[33]

public plugin_init()
{
	// Main
	register_plugin("DRP - Mining Mod","0.1a","Drak (Based off of ARP)");
	
	// Events
	register_event("DeathMsg","EventDeathMsg","a");
}

public DRP_HudDisplay(id,Hud)
{
	if(Hud != HUD_PRIM)
		return
	
	if(g_Harvesting[id])
		DRP_AddHudItem(id,HUD_PRIM,"Mining / Harvesting");
}

public plugin_precache()
{
	g_LightSprite = precache_model("sprites/steam1.spr");
	
	new ConfigFile[256]
	DRP_GetConfigsDir(ConfigFile,255);
	
	add(ConfigFile,255,"/MiningMod.ini");
	
	new pFile = fopen(ConfigFile,"rt+");
	if(!pFile)
	{
		DRP_ThrowError(0,"Unable to open config file (%s)",ConfigFile);
		return
	}
	
	g_Materials = TravTrieCreate();
	
	new Buffer[128],Name[33],TravTrie:Reading,Left[33],Right[33]
	while(!feof(pFile))
	{
		fgets(pFile,Buffer,127);
		
		if(!Buffer[0] || Buffer[0] == ';') 
			continue
		
		if(!Reading && Buffer[0] != '{') 
			copy(Name,32,Buffer);
		
		if(Buffer[0] == '{')
		{
			Reading = TravTrieCreate();
			continue
		}
		
		else if(Buffer[0] == '}')
		{
			trim(Name);
			remove_quotes(Name);
			
			TravTrieSetString(Reading,"last_time","0");
			
			TravTrieGetString(Reading,"num",Buffer,127);
			TravTrieSetString(Reading,"current_num",Buffer);
			
			TravTrieGetString(Reading,"model",Buffer,127);
			if(Buffer[0])
				CreateModelEntity(TravTrie:Reading,Buffer);
			
			TravTrieSetCell(g_Materials,Name,Reading);
			
			Reading = Invalid_TravTrie
			continue
		}
		
		if(Reading)
		{						
			parse(Buffer,Left,32,Right,32);
			trim(Left);
			remove_quotes(Left);
			
			TravTrieSetString(Reading,Left,Right);
		}
	}
	
	fclose(pFile);
	set_task(1.0,"FCheckMines",_,_,_,"b");
}

public FCheckMines()
	CheckMines();

CheckMines()
{
	static Temp[64],Float:Origin[3]
	new travTrieIter:Iter = GetTravTrieIterator(g_Materials),TravTrie:Material,Active,Float:LastTime,Float:RespawnTime
	
	while(MoreTravTrie(Iter))
	{
		ReadTravTrieCell(Iter,Material);
		
		TravTrieGetString(Material,"active",Temp,63);
		Active = str_to_num(Temp);
		
		if(Active)
		{
			TravTrieGetString(Material,"model",Temp,63);
			if(!Temp[0])
			{
				GetSpotOrigin(Material,Origin);
				
				engfunc(EngFunc_MessageBegin,MSG_PVS,SVC_TEMPENTITY,Origin,0);
				write_byte(TE_BEAMCYLINDER);
				
				engfunc(EngFunc_WriteCoord,Origin[0]);
				engfunc(EngFunc_WriteCoord,Origin[1]);
				engfunc(EngFunc_WriteCoord,Origin[2] + -30); // up/down
				
				engfunc(EngFunc_WriteCoord,Origin[0] + 24);
				engfunc(EngFunc_WriteCoord,Origin[1] + 45);
				engfunc(EngFunc_WriteCoord,Origin[2] + -77);
				
				write_short(g_LightSprite);
				
				write_byte(0); // starting frame
				write_byte(15); // frame rate in 0.1s
				write_byte(12); // life in 0.1s
				write_byte(10); // line width in 0.1s
				write_byte(1); // noise amplitude in 0.01s
				write_byte(250);
				write_byte(55);
				write_byte(25);
				write_byte(300); // brightness
				write_byte(1); // scroll speed in 0.1s
				
				message_end();
			}
		}
		else
		{
			TravTrieGetString(Material,"last_time",Temp,63);
			LastTime = str_to_float(Temp);
			
			TravTrieGetString(Material,"respawn_time",Temp,63);
			RespawnTime = str_to_float(Temp);
			
			if(get_systime() - LastTime > RespawnTime)
			{
				TravTrieGetString(Material,"respawn_chance",Temp,63);
				LastTime = str_to_float(Temp);
				
				if(random_float(0.0,1.0) > LastTime)
				{
					formatex(Temp,63,"%d",get_systime());
					TravTrieSetString(Material,"last_time",Temp);
					
					DestroyTravTrieIterator(Iter);
					continue
				}
				
				TravTrieSetString(Material,"active","1");
				TravTrieGetString(Material,"num",Temp,63);
				TravTrieSetString(Material,"current_num",Temp);
			}
		}
	}
	DestroyTravTrieIterator(Iter);
}
/*==================================================================================================================================================*/
public client_disconnect(id)
{
	g_LastUse[id] = 0
	g_AntiSpam[id] = 0
	g_HarvestTime[id] = 0
	g_Harvesting[id] = 0
}
public EventDeathMsg()
{
	new const id = read_data(2);
	
	if(!id)
		return PLUGIN_HANDLED
	
	g_Harvesting[id] = 0
	return PLUGIN_CONTINUE
}
/*==================================================================================================================================================*/
public client_PreThink(id)
{
	if(!is_user_alive(id) || g_Harvesting[id])
		return
	
	if(!(entity_get_int(id,EV_INT_button) & IN_USE && !(entity_get_int(id,EV_INT_oldbuttons) & IN_USE)))
		return
	
	new SysTime = get_systime();
	if(SysTime - g_AntiSpam[id] < PRETHINK_ANTI_SPAM)
		return 
	
	g_AntiSpam[id] = get_systime();
	
	static TravTrie:Material,Temp[64],Float:Origin[3],Float:PlayerOrigin[3],Name[33]
	new travTrieIter:Iter = GetTravTrieIterator(g_Materials),Time,Active
	
	entity_get_vector(id,EV_VEC_origin,PlayerOrigin);
	
	while(MoreTravTrie(Iter))
	{
		ReadTravTrieKey(Iter,Name,32);
		ReadTravTrieCell(Iter,Material);
		
		TravTrieGetString(Material,"active",Temp,63);
		Active = str_to_num(Temp);
		
		if(Active)
		{
			GetSpotOrigin(Material,Origin);
			
			if(get_distance_f(Origin,PlayerOrigin) > ORE_DISTANCE)
				continue
			
			TravTrieGetString(Material,"cooldown_time",Temp,63);
			Time = str_to_num(Temp);
			
			SysTime = get_systime();
			
			if(SysTime - g_LastUse[id] < Time)
			{
				client_print(id,print_chat,"[DRP] Please wait %d seconds before mining this ore spot again.",Time - SysTime + g_LastUse[id]);
				DestroyTravTrieIterator(Iter);
				return
			}
			
			formatex(Temp,63,"- Mining Menu -^nMining Item:%s",Name);
			new Menu = menu_create(Temp,"MineMenuHandle");
			
			switch(random(2))
			{
				case 0:
				{
					menu_additem(Menu,"Begin Mining");
					menu_additem(Menu,"Don't Mine");
				}
				case 1:
				{
					menu_additem(Menu,"Don't Mine");
					menu_additem(Menu,"Begin Mining");
				}
			}
			
			menu_addblank(Menu,0);
			menu_additem(Menu,"Items Required");
			
			menu_additem(Menu,"Help");
			menu_display(id,Menu);
			
			g_Material[id] = Material
			break
		}
	}
	DestroyTravTrieIterator(Iter);
}
public MineMenuHandle(id,Menu,Item)
{
	if(Item == MENU_EXIT)
	{
		menu_destroy(Menu)
		return PLUGIN_HANDLED
	}
	
	new Garbage[2],Name[2]
	menu_item_getinfo(Menu,Item,Garbage[0],Garbage,1,Name,1,Garbage[0]);
	menu_destroy(Menu);
	
	// Help
	if(Item == 3)
	{
		if(!DRP_ShowMOTDHelp(id,"DRPMiningMod_Help.txt"))
			client_print(id,print_chat,"[DRP] Unable to show help file.");
		
		return PLUGIN_HANDLED
	}
	
	new Temp[64]
	TravTrieGetString(g_Material[id],"active",Temp,63);
	
	if(!str_to_num(Temp))
	{
		client_print(id,print_chat,"[DRP] This spot has been completely harvested. Please wait abit.")
		return PLUGIN_HANDLED
	}
	
	new Float:Origin[3]
	GetSpotOrigin(g_Material[id],Origin);
	
	new Float:PlayerOrigin[3]
	entity_get_vector(id,EV_VEC_origin,PlayerOrigin);
	
	if(get_distance_f(Origin,PlayerOrigin) > ORE_DISTANCE)
	{
		client_print(id,print_chat,"[DRP] You have moved to far from the mining spot.")
		return PLUGIN_HANDLED
	}
	
	if(Name[0] == 'D')
	{
		client_print(id,print_chat,"[DRP] You pressed the wrong button.");
		return PLUGIN_HANDLED
	}
	
	g_FailChance[id] = 0.0
	
	new ItemID,Flag,Key[33],Results[1],ItemsNeeded,UserItems
	Temp[0] = 0
	
	if(Item != 2)
	{
		for(new Count = 1;Count < 5;Count++)
		{
			Temp[0] = 0
			if(Count == 1) 
			{
				TravTrieGetString(g_Material[id],"item1_name",Temp,63);
				
				if(!Temp[0])
				{
					TravTrieGetString(g_Material[id],"harvest_time",Temp,63);
					g_HarvestTime[id] = str_to_num(Temp);
					
					Temp[0] = 0
					TravTrieGetString(g_Material[id],"failchance",Temp,63);
					g_FailChance[id] = str_to_float(Temp);
					
					Flag = 1
					break
				}
				
				// We only use the failchance for the first item (if we require item(s))
				// There is no point for each item to have a fail chance - we require all items - to mine
				TravTrieGetString(g_Material[id],"item1_failchance",Temp,63);
				g_FailChance[id] = str_to_float(Temp);
				
				// Same thing with time
				// This is the time required to mine the spot with all the required items
				TravTrieGetString(g_Material[id],"item1_time",Temp,63);
				g_HarvestTime[id] = str_to_num(Temp);
			}
			
			formatex(Key,32,"item%d_name",Count);
			TravTrieGetString(g_Material[id],Key,Temp,63);
			
			// This location doesn't require any more items
			if(!Temp[0])
				break
			
			ItemsNeeded++
			
			DRP_FindItemID(Temp,Results,1);
			ItemID = Results[0]
			
			if(!DRP_GetUserItemNum(id,ItemID))
				continue
			
			UserItems++
			
			formatex(Key,32,"item%d_useup",Count);
			TravTrieGetString(g_Material[id],Key,Temp,63);
			
			if(str_to_num(Temp))
				DRP_TakeUserItem(id,ItemID,1);
		}
	}
	
	if(UserItems >= ItemsNeeded)
		Flag = 1
	
	if(!Flag)
	{
		new Message[512],Pos,ItemName[33]
		Pos += formatex(Message[Pos],511 - Pos,"The following items are required to harvest this item:^n^n");
		
		for(new Count = 1;Count < 5;Count++)
		{
			ItemName[0] = 0
			
			formatex(Key,32,"item%d_name",Count);
			TravTrieGetString(g_Material[id],Key,ItemName,32);
			
			if(!ItemName[0])
				break
			
			Pos += formatex(Message[Pos],511 - Pos,"%d.  %s  - Remove: %s^n",Count,ItemName,Temp[0] == '1' ? "Yes" : "No");
		}
		
		show_motd(id,Message,"Items Required");
		return PLUGIN_HANDLED
	}
	
	new Params[2]
	Params[0] = id
	Params[1] = 0
	
	client_print(id,print_chat,"[DRP] You are now harvesting this spot. Please stand still");
	g_Harvesting[id] = 1
	HarvestMaterial(Params);
	
	return PLUGIN_HANDLED
}

public HarvestMaterial(Params[2])
{
	new const id = Params[0],ElapsedTime = Params[1]
	Params[1]++
	
	if(random_float(0.0,1.0) < g_FailChance[id])
	{
		client_print(id,print_chat,"[DRP] You failed to mine this location.");
		
		g_LastUse[id] = get_systime();
		g_Harvesting[id] = 0
		
		return
	}
	
	new Float:Origin[3]
	GetSpotOrigin(g_Material[id],Origin);
	
	new Float:PlayerOrigin[3]
	entity_get_vector(id,EV_VEC_origin,PlayerOrigin);
	
	if(get_distance_f(Origin,PlayerOrigin) > ORE_DISTANCE)
	{
		client_print(id,print_chat,"[DRP] You have moved to far from the mining spot.");
		
		g_LastUse[id] = get_systime();
		g_Harvesting[id] = 0
		
		return
	}
	
	// Stop untill we reached our time
	if(ElapsedTime <= g_HarvestTime[id])
	{
		if(g_HarvestTime[id] <= 10)
			client_print(id,print_center,"[DRP]^n- Harvesting -^nPercent: %d%s",(ElapsedTime * 10),"%%");//,(g_HarvestTime[id] * 10),"%%");
		else
			client_print(id,print_center,"[DRP]^n- Harvesting -^nPercent: %d / %d%s",ElapsedTime,g_HarvestTime[id],"%%");
		
		set_task(1.5,"HarvestMaterial",_,Params,2);
		return
	}
	
	new travTrieIter:Iter = GetTravTrieIterator(g_Materials),Name[33],TravTrie:Material,Temp[64]
	
	while(MoreTravTrie(Iter))
	{
		ReadTravTrieKey(Iter,Name,32);
		ReadTravTrieCell(Iter,Material);
		
		if(Material == g_Material[id]) 
			break
	}
	
	DestroyTravTrieIterator(Iter);
	
	new ItemID = DRP_FindItem(Name);
	if(!DRP_ValidItemID(ItemID) || !Material)
	{
		client_print(id,print_chat,"[DRP] Internal error; please contact administrator. Your mining has been cancelled.");
		g_Harvesting[id] = 0
		return
	}
	
	TravTrieGetString(Material,"mine_amount",Temp,63);
	new ItemNum = str_to_num(Temp);
	TravTrieGetString(Material,"mine_amount_random",Temp,63);
	new ItemNumRand = str_to_num(Temp),Rand = ItemNumRand ? random_num(0,str_to_num(Temp)) : 0,Total = ItemNum + Rand
	
	TravTrieGetString(Material,"current_num",Temp,63);
	new AmountLeft = str_to_num(Temp);
	
	if(AmountLeft <= Total)
	{
		Total = AmountLeft
		client_print(id,print_chat,"[DRP] This location/ore is now empty. It will respawn shortly.")
		
		TravTrieSetString(Material,"active","0");
		formatex(Temp,63,"%d",get_systime());
		TravTrieSetString(Material,"last_time",Temp);
	}
	
	DRP_GiveUserItem(id,ItemID,Total);
	g_LastUse[id] = get_systime()
	
	formatex(Temp,63,"%d",AmountLeft - Total);
	TravTrieSetString(Material,"current_num",Temp);
	
	client_print(id,print_chat,"[DRP] You have successfully harvested %d %ss.",Total,Name);
	g_Harvesting[id] = 0
}


// Places a model where the mining spot is located
CreateModelEntity(TravTrie:OreSpot,const Model[])
{
	if(OreSpot && Model[0])
		cvar_exists("");
}

GetSpotOrigin(const TravTrie:Location,Float:Origin[3])
{
	new Temp[26],Exploded[3][8]
	
	TravTrieGetString(Location,"origin",Temp,25);
	parse(Temp,Exploded[0],7,Exploded[1],7,Exploded[2],7);
	
	for(new Count;Count < 3;Count++)
		Origin[Count] = str_to_float(Exploded[Count]);
}