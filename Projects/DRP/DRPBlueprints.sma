#include <amxmodx>
#include <amxmisc>
#include <DRP/DRPCore>
#include <DRP/DRPChat>
#include <time>

#define TASK_ID 468

new TravTrie:g_Blueprints
new Trie:g_AllBlueprints

stock g_MaxPlayers

new pInventFactor
new pCopyFactor

new gItemId[33]
new Float:gTimeToMake[33]
new Float:gStartedTime[33]

new g_Cache[512]
new gMenu

public plugin_init() 
{
	// Main
	register_plugin("DRP - Blueprints","0.1a","Drak (Based off of ARP)");
	register_dictionary("time.txt");
	
	// Events
	register_event("DeathMsg","EventDeathMsg","a");
	DRP_RegisterEvent("Menu_Display","EventMenuDisplay");
	
	// Menu
	gMenu = menu_create("Blueprint Main Menu^n^nThis menu allows you to handle your^nblueprints. To see what each blueprint^nrequires, use it in your^ninventory.", "MenuBlueprintsHandle" )
	menu_additem(gMenu,"* Cancel Production",.callback = menu_makecallback( "IsProducing"));
	menu_addblank(gMenu,0);
	menu_additem(gMenu,"Craft")
	menu_additem(gMenu,"Study")
	menu_additem(gMenu,"Copy");
	menu_additem(gMenu,"Help");
	menu_addtext(gMenu,"^nNOTE:^nSome blueprints must be found");
	
	pInventFactor = register_cvar("arp_blueprint_invent_factor","20.0");
	pCopyFactor = register_cvar("arp_blueprint_copy_factor","5.0");
	
	g_MaxPlayers = get_maxplayers();
	
	DRP_RegisterCmd("DRP_ReloadBluePrints","CmdReload","(ADMIN) - reloads the blueprint file");
	DRP_RegisterChat("/blueprints","CmdBluePrints","Opens the blueprints menu");
}

public DRP_Error(const Reason[])
	pause("d");

public IsProducing( id, menu, item )
	return task_exists(id + TASK_ID) ? ITEM_IGNORE : ITEM_DISABLED

public client_disconnect(id) 
	if(task_exists(id + TASK_ID)) remove_task(id + TASK_ID);

public DRP_HudDisplay(id,Hud)
{
	if(Hud != HUD_PRIM)
		return
	
	/*
	static name[33], timeLeft[33]
	ARP_GetItemName( gItemId[id], name, 32 )
	ARP_AddHudItem( id, HUD_PRIM, 0, "Producing: %s", name )
	get_time_length( id, floatround( gStartedTime[id] + gTimeToMake[id] - get_gametime(), floatround_ceil ), timeunit_seconds, timeLeft, 32 )
	ARP_AddHudItem( id, HUD_PRIM, 0, "Time Left: %s", timeLeft )
	*/
}
public DRP_RegisterItems()
{
	g_AllBlueprints = TrieCreate();
	ReadConfig();
}
/*==================================================================================================================================================*/
public CmdReload(id,level,cid)
{
	if(!DRP_CmdAccess(id,cid,1))
		return PLUGIN_HANDLED
	
	new travTrieIter:Iter = GetTravTrieIterator(g_Blueprints),Key[64],Garbage[2],Blueprint[10],TravTrie:BlueprintNum
	while(MoreTravTrie(Iter))
	{
		ReadTravTrieKey(Iter,Garbage,1);
		ReadTravTrieString(Iter,Key,63);
		
		strtok(Key,Blueprint,9,Garbage,1,'|');
		BlueprintNum = TravTrie:str_to_num(Blueprint);
		
		TravTrieDestroy(BlueprintNum);
	}

	DestroyTravTrieIterator(Iter);
	TravTrieDestroy(g_Blueprints);
	
	ReadConfig();
	client_print(id,print_console,"[DRP] BluePrints config file has been reloaded.");
	
	return PLUGIN_HANDLED
}

public EventDeathMsg()
{
	new const id = read_data(2);
	if(!id)
		return PLUGIN_HANDLED
	
	if(task_exists(id + TASK_ID))
		remove_task(id + TASK_ID);
		
	return PLUGIN_CONTINUE
}

public EventMenuDisplay(const Name[],const Data[],Len)
	DRP_AddMenuItem(Data[0],"Blueprints","CmdBluePrints");

public CmdBluePrints(id)
{
	menu_display(id,gMenu);
	return PLUGIN_HANDLED
}

public MenuBlueprintsHandle(id,Menu,Item)
{
	switch(Item)
	{
		case 0:
		{
			new itemName[33]
			DRP_GetItemName(gItemId[id],itemName,32);
			client_print(id,print_chat,"[DRP] You have stopped your production of %s.",itemName);
			
			if(task_exists(id + TASK_ID))
				remove_task(id + TASK_ID);
		}
		case 1:
			UseBlueprints(id);
		case 2:
			InventBlueprints(id);
		case 3:
			CopyBlueprints(id);
	}
	return PLUGIN_HANDLED
}

ReadConfig()
{
	new ConfigFile[256]
	DRP_GetConfigsDir(ConfigFile,255);
	add(ConfigFile,255,"/Blueprints.ini");
	
	new pFile = fopen(ConfigFile,"r+");
	if(!pFile)
	{
		DRP_ThrowError(0,"Unable to open config file (%s)",ConfigFile);
		return
	}
	
	g_Blueprints = TravTrieCreate();
	
	new Buffer[128],Name[33],TravTrie:Reading,Results[1],Left[33],Right[33],Float:Time,CachedName[33]
	while(!feof(pFile))
	{
		fgets(pFile,Buffer,127);
		replace(Buffer,127,"^n","");
		
		if(!Buffer[0] || Buffer[0] == ';') 
			continue
		
		if(!Reading && Buffer[0] != '{') 
		{
			copy(Name,32,Buffer);
			copy(CachedName,32,Buffer);
		}
		
		if(Buffer[0] == '{')
		{
			Reading = TravTrieCreate();
			continue
		}
		else if(Buffer[0] == '}')
		{
			formatex(Buffer,127,"%d|%f",Reading,Time);
			trim(Name);
			remove_quotes(Name);
			
			if(equali(Name,""))
			{
				copy(Name,32,CachedName);
				trim(Name);
				remove_quotes(Name);
				
				DRP_ThrowError(0,"Breach detected. Attempted fix: %s",!equali(Name,"") ? "Succeeded" : "Failed");
				Reading = Invalid_TravTrie
				continue
			}
			
			TravTrieSetString(g_Blueprints,Name,Buffer);
			formatex(Buffer,127,"Blueprint - %s",Name);
			
			if(!TrieKeyExists(g_AllBlueprints,Buffer))
			{
				DRP_RegisterItem(Buffer,"_Blueprint","Allows you to craft an item",0);
				TrieSetString(g_AllBlueprints,Buffer,"");
			}
			
			Reading = Invalid_TravTrie
			continue
		}
		
		if(Reading)
		{
			parse(Buffer,Left,32,Right,32);
			trim(Left);
			remove_quotes(Left);
			
			if(equali(Left,"*time"))
			{
				Time = str_to_float(Right)
				continue
			}
			else if(strlen(Left) < 5 || Left[0] == 0)
				continue
			
			if(!DRP_FindItemID(Left,Results,1))
				DRP_ThrowError(0,"Unknown ItemName: %s",Left);
			
			TravTrieSetCellEx(Reading,Results[0],max(str_to_num(Right),0));
		}
	}
	
	fclose(pFile);
}
public _Blueprint(id,ItemID)
{
	new Name[33],Float:Time,TravTrie:ItemsRequired,Split[33],Left[10],Right[10]
	DRP_GetItemName(ItemID,Name,32);
	
	replace(Name,32,"Blueprint - ","");
	
	new Results[1]
	if(!DRP_FindItemID(Name,Results,1))
	{
		client_print(id,print_chat,"[DRP] Internal error; please contact an administrator.");
		return ITEM_KEEP_RETURN
	}
	
	TravTrieGetString(g_Blueprints,Name,Split,32);
	strtok(Split,Left,9,Right,9,'|');
	
	ItemsRequired = TravTrie:str_to_num(Left);
	Time = str_to_float(Right);
	
	new travTrieIter:Iter = GetTravTrieIterator(ItemsRequired),Temp[10],ItemName[33],Num
	new Pos = formatex(g_Cache,sizeof g_Cache - 1,"You require the following items:^n^n");
	
	if(!ItemsRequired || !Iter)
	{
		DRP_Log("Error getting iterator: %d / %d^nName:%s",_:ItemsRequired,_:Iter,Name);
		return
	}
	
	while(MoreTravTrie(Iter))
	{
		ReadTravTrieKey(Iter,Temp,9)
		ReadTravTrieCell(Iter,Num)
		
		DRP_GetItemName(str_to_num(Temp),ItemName,32);
		Pos += Num ? 
			formatex(g_Cache[Pos],(sizeof g_Cache - 1) - Pos,"%s: %d^n",ItemName,Num) : formatex(g_Cache[Pos],(sizeof g_Cache - 1) - Pos,"%s: (Not Consumed)",ItemName);
	}
	
	DestroyTravTrieIterator(Iter);
	
	new TimeLength[33]
	get_time_length(id,floatround(Time),timeunit_seconds,TimeLength,32);
	
	format(g_Cache[Pos],(sizeof g_Cache - 1) - Pos,"^n* Time required for production: %s^n^nSay /blueprints to open the blueprint menu.",TimeLength);
	show_motd(id,g_Cache,"Items Required");
}

UseBlueprints(id)
{
	if(task_exists(id + TASK_ID))
	{
		client_print(id,print_chat,"[DRP] You are already producing an item. Please wait for it to finish");
		return PLUGIN_HANDLED
	}
	
	new Menu = menu_create("Blueprints - Use^n^nThis menu allows you to use your^nblueprints for creating items.^n^n","MenuUseBlueprints");
	new travTrieIter:Iter = GetTravTrieIterator(g_Blueprints),Key[64],Garbage[2],Num,ItemName[64],ItemID,ItemIDs[1]
	
	while(MoreTravTrie(Iter))
	{
		ReadTravTrieKey(Iter,Key,63);
		ReadTravTrieString(Iter,Garbage,1);
		
		formatex(ItemName,63,"Blueprint - %s",Key);
		DRP_FindItemID(ItemName,ItemIDs,1);
		ItemID = ItemIDs[0]
		
		if(!DRP_ValidItemID(ItemID) || !DRP_GetUserItemNum(id,ItemID)) 
			continue
		
		menu_additem(Menu,Key,"");
		Num++
	}
	DestroyTravTrieIterator(Iter);
	
	Num ? 
		menu_display(id,Menu) : client_print(id,print_chat,"[DRP] You do not have any blueprints.");
	
	return PLUGIN_HANDLED
}

InventBlueprints( id )
{
	if(task_exists(id + TASK_ID))
	{
		client_print(id,print_chat,"[ARP] You are already producing an item.")
		return PLUGIN_HANDLED
	}
	
	new Menu = menu_create("Blueprints - Invent^n^nThis menu allows you to create^nnew blueprints.^n^n","MenuInventBlueprints"),travTrieIter:Iter = GetTravTrieIterator(g_Blueprints),Key[64],Garbage[2],Num,ItemName[64],ItemId,ItemIds[1],ItemIdStr[12]
	while(MoreTravTrie(Iter))
	{
		ReadTravTrieKey(Iter,Key,63)
		ReadTravTrieString(Iter,Garbage,1)
		
		DRP_FindItemID(ItemName,ItemIds,1)
		ItemId = ItemIds[0]
	
		num_to_str(ItemId,ItemIdStr,charsmax(ItemIdStr))
	
		menu_additem(Menu,Key,ItemIdStr)
		
		Num++
	}
	DestroyTravTrieIterator(Iter)
	
	Num ? menu_display(id,Menu) : client_print(id,print_chat,"[ARP] No blueprints exist.")
	
	return PLUGIN_HANDLED
}

CopyBlueprints( id )
{
	if(task_exists(id + TASK_ID))
	{
		client_print(id,print_chat,"[ARP] You are already producing an item.")
		return PLUGIN_HANDLED
	}
	
	new Menu = menu_create("Blueprints - Copy^n^nThis menu allows you to copy^nblueprints that you have.^n^n","MenuCopyBlueprints"),travTrieIter:Iter = GetTravTrieIterator(g_Blueprints),Key[64],Garbage[2],Num,ItemName[64],ItemId,ItemIds[1]
	while(MoreTravTrie(Iter))
	{
		ReadTravTrieKey(Iter,Key,63)
		ReadTravTrieString(Iter,Garbage,1)
		
		format(ItemName,63,"Blueprint - %s",Key)
		DRP_FindItemID(ItemName,ItemIds,1)
		ItemId = ItemIds[0]
		
		if(!DRP_ValidItemID(ItemId) || !DRP_GetUserItemNum(id,ItemId)) 
			continue
	
		menu_additem(Menu,Key,"")
		
		Num++
	}
	DestroyTravTrieIterator(Iter)
	
	Num ? menu_display(id,Menu) : client_print(id,print_chat,"[ARP] You do not have any blueprints.")
	
	return PLUGIN_HANDLED
}

public MenuInventBlueprints(id,Menu,Item)
{
	if(Item == MENU_EXIT)
	{
		menu_destroy(Menu)
		return
	}
	
	new Name[33],Float:Time,Split[33],Left[10],Right[10]
	menu_item_getinfo(Menu,Item,Split[0],Split,1,Name,32,Split[0])
	
	format(Name,32,"Blueprint - %s",Name)
	
	new Results[1]
	if(!DRP_FindItemID(Name,Results,1))
	{
		client_print(id,print_chat,"[ARP] Internal error; please contact an administrator.")
		menu_destroy(Menu)
		return
	}
	
	new Blueprint = Results[0]
	
	replace(Name,32,"Blueprint - ","")
	
	TravTrieGetString(g_Blueprints,Name,Split,32)
	
	strtok(Split,Left,9,Right,9,'|')
	Time = str_to_float(Right) * get_pcvar_float(pInventFactor)
	
	if(!DRP_FindItemID(Name,Results,1))
	{
		client_print(id,print_chat,"[ARP] The item you are producing could not be found. Please contact an administrator.")
		menu_destroy(Menu)
		return
	}
	
	ConfirmMenu( id, Blueprint, Time )
	
	menu_destroy(Menu)
}

public MenuUseBlueprints(id,Menu,Item)
{
	if(Item == MENU_EXIT)
	{
		menu_destroy(Menu)
		return
	}
	
	new Name[33],Float:Time,TravTrie:ItemsRequired,Split[33],Left[10],Right[10]
	menu_item_getinfo(Menu,Item,Split[0],Split,1,Name,32,Split[0])
	
	format(Name,32,"Blueprint - %s",Name)
	
	new Results[1]
	if(!DRP_FindItemID(Name,Results,1))
	{
		client_print(id,print_chat,"[ARP] Internal error; please contact an administrator.")
		menu_destroy(Menu)
		return
	}
	
	replace(Name,32,"Blueprint - ","")
	
	TravTrieGetString(g_Blueprints,Name,Split,32)
	
	strtok(Split,Left,9,Right,9,'|')
	ItemsRequired = TravTrie:str_to_num(Left)
	Time = str_to_float(Right)
	
	new Pos = formatex(g_Cache,(sizeof g_Cache - 1),"You lack the following items:^n^n"),PrevLen = Pos
	new travTrieIter:Iter = GetTravTrieIterator(ItemsRequired),Temp[10],ItemId,Num,PlayerNum,ItemName[33]
	
	while(MoreTravTrie(Iter))
	{
		ReadTravTrieKey(Iter,Temp,9)
		ItemId = str_to_num(Temp)
		
		PlayerNum = DRP_GetUserItemNum(id,ItemId)
		ReadTravTrieCell(Iter,Num)
		
		if(PlayerNum < Num || (!Num && !PlayerNum))
		{
			DRP_GetItemName(ItemId,ItemName,32)
			Pos += Num ? 
				formatex(g_Cache[Pos],(sizeof g_Cache - 1) - Pos,"%s: %d^n",ItemName,Num - PlayerNum) : formatex(g_Cache[Pos],(sizeof g_Cache - 1) - Pos,"%s: (Not Consumed)",ItemName)
		}
	}
	DestroyTravTrieIterator(Iter)
	
	if(Pos != PrevLen)
	{
		show_motd(id,g_Cache,"Items Required")
		menu_destroy(Menu)
		return
	}
	
	Iter = GetTravTrieIterator(ItemsRequired)
	while(MoreTravTrie(Iter))
	{
		ReadTravTrieKey(Iter,Temp,9)
		ItemId = str_to_num(Temp)
		ReadTravTrieCell(Iter,Num)
		
		DRP_SetUserItemNum(id,ItemId,DRP_GetUserItemNum(id,ItemId) - Num)
	}
	DestroyTravTrieIterator(Iter)
	
	DRP_SetUserItemNum(id,Results[0],DRP_GetUserItemNum(id,Results[0]) - 1)
	
	if(!DRP_FindItemID(Name,Results,1))
	{
		client_print(id,print_chat,"[ARP] The item you are producing could not be found. Please contact an administrator.")
		menu_destroy(Menu)
		return
	}
	
	ConfirmMenu( id, Results[0], Time )
	
	menu_destroy(Menu)
}

public MenuCopyBlueprints(id,Menu,Item)
{
	if(Item == MENU_EXIT)
	{
		menu_destroy(Menu)
		return
	}
	
	new Name[33],Float:Time,Split[33],Left[10],Right[10]
	menu_item_getinfo(Menu,Item,Split[0],Split,1,Name,32,Split[0])
	
	format(Name,32,"Blueprint - %s",Name)
	
	new Results[1]
	if(!DRP_FindItemID(Name,Results,1))
	{
		client_print(id,print_chat,"[ARP] Internal error; please contact an administrator.")
		menu_destroy(Menu)
		return
	}
	
	replace(Name,32,"Blueprint - ","")
	
	TravTrieGetString(g_Blueprints,Name,Split,32)
	
	strtok(Split,Left,9,Right,9,'|')
	Time = str_to_float(Right) * get_pcvar_float(pCopyFactor)
	
	ConfirmMenu( id, Results[0], Time )
	
	menu_destroy(Menu)
}

ConfirmMenu( id, itemId, Float:timeToMake )
{
	gItemId[id] = itemId
	gTimeToMake[id] = timeToMake
	
	new itemName[64], timeToMakeLine[64], title[256]
	DRP_GetItemName( itemId, itemName, charsmax( itemName ) )
	
	get_time_length( id, floatround( timeToMake ), timeunit_seconds, timeToMakeLine, charsmax( timeToMakeLine ) )
	
	format( itemName, charsmax( itemName ), "Item: %s", itemName )
	format( timeToMakeLine, charsmax( timeToMakeLine ), "Time to Make: %s", timeToMakeLine )
	formatex( title, charsmax( title ), "Confirm Item Creation^n^n%s^n%s", itemName, timeToMakeLine )
	
	new menu = menu_create( title, "ConfirmMenuHandle" )
	menu_additem( menu, "Confirm" )
	menu_display( id, menu )
}

public ConfirmMenuHandle( id, menu, item )
{
	menu_destroy( menu )
	
	if ( item == MENU_EXIT )
		return PLUGIN_HANDLED
	
	new itemName[33]
	DRP_GetItemName( gItemId[id], itemName, charsmax( itemName ) )
	
	client_print( id, print_chat, "[ARP] You begin producing a %s.", itemName )
	
	gStartedTime[id] = get_gametime()
	
	new data[1]
	data[0] = gItemId[id]
	set_task( gTimeToMake[id], "CreateItem", id + TASK_ID, data, 1 )
	
	return PLUGIN_HANDLED
}

public CreateItem(Params[],id)
{
	id -= TASK_ID
	new Name[33],ItemId = Params[0]
	DRP_GetItemName(ItemId,Name,32)
	
	client_print(id,print_chat,"[ARP] You have finished producing a %s.",Name)
	
	DRP_SetUserItemNum(id,ItemId,DRP_GetUserItemNum(id,ItemId) + 1)
}

/*==================================================================================================================================================*/
public plugin_end()
{
	new travTrieIter:Iter = GetTravTrieIterator(g_Blueprints),Temp[10],Garbage[2],Left[10],TravTrie:CurTrie
	
	while(MoreTravTrie(Iter))
	{
		ReadTravTrieString(Iter,Temp,9);
		strtok(Temp,Left,9,Garbage,1,'|');
		
		CurTrie = TravTrie:str_to_num(Left);
		TravTrieDestroy(CurTrie);
	}
	
	DestroyTravTrieIterator(Iter);
	TravTrieDestroy(g_Blueprints);
}