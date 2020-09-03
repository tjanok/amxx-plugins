#include <amxmodx>
#include <fakemeta>

#include <DRP/DRPCore>
#include <DRP/DRPChat>

#include <cellarray>

new Handle:g_SqlHandle

new Array:g_Propertys[128]
new g_PropertyInt

public plugin_init()
{
	// Main
	register_plugin("DRP - Renting","0.1a","Drak");
	
	// Events
	DRP_RegisterEvent("Print_PropDisplay","Event_PrintPropDisplay");
	DRP_RegisterEvent("Property_Buy","Event_PropertyBuy");
	DRP_RegisterEvent("Property_SetPrice","Event_PropertySetPrice");
	DRP_RegisterEvent("Core_Save","Event_CoreSave");
	
	// Commands
	DRP_AddChat("","CmdRent");
}

public DRP_Error(const Reason[])
	pause("d");

public DRP_Init()
{
	// SQL
	g_SqlHandle = DRP_SqlHandle();
	
	new Query[256]
	
	format(Query,255,"CREATE TABLE IF NOT EXISTS `Renting` (InternalName VARCHAR(36),RenterAuthID VARCHAR(36),RentCost INT(11),TimeLeft INT(11),PRIMARY KEY (InternalName))");
	SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",Query);
	
	// We need this, so the core can load the property's
	// or they will appear invalid/missing
	set_task(4.0,"DelayLoad");
}

// When we first load DRP (fresh install) we won't have any property's
// So this will keep looping
// Fixed!

new g_Counter
public DelayLoad()
{
	if(DRP_PropertyNum() >= 1)
		SQL_ThreadQuery(g_SqlHandle,"FetchRentableProperty","SELECT * FROM `Renting`");
	else
	{
		if(++g_Counter != 5)
			set_task(1.0,"DelayLoad");
	}
}

/*==================================================================================================================================================*/
// Take a property id
// and find it inside the rentable property array
FindProperty(const Property)
{
	new Array:CurArray,PropID
	new Found = 0
	
	for(new Count;Count < g_PropertyInt;Count++)
	{
		CurArray = g_Propertys[Count]
		
		if(CurArray == Invalid_Array)
			continue
		
		PropID = ArrayGetCell(CurArray,0);
		
		if(PropID == Property)
		{
			Found = Count + 1;
			break;
		}
	}
	return (Found >= 1) ? Found - 1 : -1
}
EndRent(const Property)
{
	new Found = FindProperty(Property),Array:CurArray = g_Propertys[Found]
	new Query[128],InternalName[33]
	DRP_PropertyGetInternalName(ArrayGetCell(CurArray,0),InternalName,32);
	
	formatex(Query,127,"UPDATE `Renting` SET `RenterAuthID`='',`TimeLeft`='0' WHERE `InternalName`='%s'",InternalName);
	SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",Query);
	
	new AuthID[36]
	ArrayGetString(CurArray,1,AuthID,35);
	
	ArraySetString(CurArray,1,"");
	ArraySetCell(CurArray,3,0);
	
	DRP_PropertyRemoveAccess(Property,AuthID);
	
	return PLUGIN_HANDLED
}
public Event_CoreSave()
{
	new Array:CurArray
	for(new Count;Count < g_PropertyInt;Count++)
	{
		CurArray = g_Propertys[Count]
		
		if(CurArray == Invalid_Array)
			continue
		
		new RentLeft = ArrayGetCell(CurArray,3);
		if(!RentLeft)
			continue
		
		new Float:CurrentTime = (get_gametime() / 60.0);
		new NewTime = (RentLeft - floatround(CurrentTime))
		
		if(NewTime <= 1)
		{
			EndRent(ArrayGetCell(CurArray,0));
			return PLUGIN_CONTINUE
		}
		
		new Query[256],InternalName[24]
		new const Property = ArrayGetCell(CurArray,0);
		
		DRP_PropertyGetInternalName(Property,InternalName,23);
		
		formatex(Query,255,"UPDATE `Renting` SET `TimeLeft`='%d' WHERE `InternalName`='%s'",NewTime,InternalName);
		SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",Query);
	}
	return PLUGIN_CONTINUE
}

public Event_PrintPropDisplay(const Name[],const Data[],Len)
{
	new const id = Data[0],Property = Data[1]
	if(Property < 0|| !is_user_alive(id))
		return PLUGIN_CONTINUE
	
	new Found = FindProperty(Property);
	
	if(Found != -1)
	{
		new Array:CurArray = g_Propertys[Found],Pos
		new PropertyName[23],OwnerName[33],Message[128],Renter[2]
		
		// AuthID of renter
		ArrayGetString(CurArray,1,Renter,1);
		
		DRP_PropertyGetExternalName(Property,PropertyName,23);
		DRP_PropertyGetOwnerName(Property,OwnerName,32);
		
		Pos += formatex(Message[Pos],127 - Pos,"Property: %s^nOwner: %s^n^n",PropertyName,OwnerName);
		
		if(Renter[0])
			Pos += formatex(Message[Pos],127 - Pos,"Currently Rented");
		else
		{
			new Price 
			Price = ArrayGetCell(CurArray,2);
			
			Pos += formatex(Message[Pos],127 - Pos,"For Rent: $%d^nSay /rent to rent",Price);
		}
		
		client_print(id,print_center,"^n^n^n^n^n^n^n^n^n^n^n%s",Message);
		return PLUGIN_HANDLED
	}
	
	return PLUGIN_CONTINUE
}
public Event_PropertyBuy(const Name[],const Data[],Len)
{
	new const id = Data[0],Afford = Data[2]
	if(!Afford || !is_user_alive(id))
		return PLUGIN_CONTINUE
	
	client_print(id,print_chat,"[DRP] You can also rent out your property. Type /rent <price> (price per day)");
	return PLUGIN_CONTINUE
}
public Event_PropertySetPrice(const Name[],const Data[],Len)
{
	new const Property = Data[0]
	new const Owner = DRP_PropertyGetOwner(Property);
	
	// We should never get here
	if(!Owner)
		return PLUGIN_CONTINUE
	
	new Found = FindProperty(Property);
	if(Found == -1)
		return PLUGIN_CONTINUE
	
	client_print(Owner,print_chat,"[DRP] You can't sell this property; it's being rented out. Stop the rent first.");
	return PLUGIN_HANDLED
}
/*==================================================================================================================================================*/
public DRP_HudDisplay(id,Hud)
{
	if(Hud != HUD_SEC)
		return
	
	static AuthID[36],PropertyName[36]
	
	new Array:CurArray
	new Property,Player,Owner = 0,Logo[33]
	
	for(new Count;Count < g_PropertyInt;Count++)
	{
		CurArray = g_Propertys[Count]
		
		if(CurArray == Invalid_Array)
			continue
		
		Property = ArrayGetCell(CurArray,0);
		Owner = DRP_PropertyGetOwner(Property);
		
		ArrayGetString(CurArray,1,AuthID,35);
		get_user_authid(id,PropertyName,35);
		
		if(!(Owner == id) && !(equali(AuthID,PropertyName)))
			continue
		
		if(!Logo[id])
			DRP_AddHudItem(id,HUD_SEC,"[RentMod]"); 
		
		Logo[id] = 1
		DRP_PropertyGetExternalName(Property,PropertyName,32);
		
		if(Owner == id)
		{
			Player = AuthID[0] ? CheckSteamID(AuthID) : 0
			
			if(Player)
				get_user_name(Player,AuthID,35);
			
			DRP_AddHudItem(id,HUD_SEC,"%s (Renter: %s)",PropertyName,Player ? AuthID : "N/A");
		}
		else
		{
			new TimeLeft = ArrayGetCell(CurArray,3);
			
			DRP_AddHudItem(id,HUD_SEC,"Renting: %s\nTimeleft: %d %s",PropertyName,
			(TimeLeft >= 60) ? (TimeLeft / 60) : (TimeLeft),
			(TimeLeft >= 60) ? "Hr" : "Mins" );
		}
	}
}
/*==================================================================================================================================================*/
public CmdRent(id,Args[])
{
	if(!equali(Args,"/rent",5))
		return PLUGIN_CONTINUE
	
	new Index,Body
	get_user_aiming(id,Index,Body,120);
	
	if(!Index)
	{
		client_print(id,print_chat,"[DRP] You must be looking at a property.");
		return PLUGIN_HANDLED
	}
	
	new TName[33],PropertyName[33]
	pev(Index,pev_targetname,TName,32);
	
	new const Property = DRP_PropertyMatch(TName);
	if(!Property)
	{
		client_print(id,print_chat,"[DRP] You must be looking at a property.");
		return PLUGIN_HANDLED
	}
	
	new Found = FindProperty(Property);
	DRP_PropertyGetExternalName(Property,PropertyName,32);
	
	if(DRP_PropertyGetOwner(Property) == id)
	{
		new StrPrice[12],Temp[1]
		parse(Args,Temp,1,StrPrice,11);
		
		new Price = str_to_num(StrPrice);
		
		if(Found != -1)
		{
			new Array:CurArray = g_Propertys[Found]
			if(Price < 1)
			{
				new RenterAuthID[36],AuthID[36]
				ArrayGetString(CurArray,1,RenterAuthID,35);
				
				// Notifiy the Renter
				new iPlayers[32],iNum,Player
				get_players(iPlayers,iNum);
				
				for(new Count; Count < iNum;Count++)
				{
					Player = iPlayers[Count]
					
					if(!is_user_alive(Player))
						continue
					
					get_user_authid(id,AuthID,35);
					
					if(equali(AuthID,RenterAuthID))
					{
						client_print(Player,print_chat,"[DRP] The owner of ^"%s^" has stopped the rent.",PropertyName);
						
						get_user_name(Player,PropertyName,32);
						client_print(id,print_chat,"[DRP] %s has been notified of the rent removal.",PropertyName);
						
						break;
					}
				}
				
				DRP_PropertyRemoveAccess(Property,RenterAuthID);
				client_print(id,print_chat,"[DRP] You have removed the property from being rented.");
				
				new Query[128]
				DRP_PropertyGetInternalName(Property,RenterAuthID,35);
				
				formatex(Query,127,"DELETE FROM `Renting` WHERE `InternalName`='%s'",RenterAuthID);
				SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",Query);
				
				// Array Rebuild
				
				g_Propertys[Found] = Invalid_Array
				ArrayDestroy(CurArray);
			}
			else
			{
				new Query[128],OldPrice = ArrayGetCell(CurArray,2);
				
				if(OldPrice == Price)
				{
					client_print(id,print_chat,"[DRP] Your prices are the same.");
					return PLUGIN_HANDLED
				}
				
				client_print(id,print_chat,"[DRP] You have changed the price from $%d to $%d (per/day)",OldPrice,Price);
				ArraySetCell(CurArray,2,Price);
				ArraySetCell(CurArray,4,Price);
				
				DRP_PropertyGetInternalName(Property,PropertyName,35);
				
				formatex(Query,127,"UPDATE `Renting` SET `RentCost`='%d' WHERE `InternalName`='%s'",Price,PropertyName);
				SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",Query);
			}
		}
		else
		{
			if(Price < 1)
			{
				client_print(id,print_chat,"[DRP] Usage: /rent <price> - Use zero to stop renting.");
				return PLUGIN_HANDLED
			}
			
			if(DRP_PropertyGetPrice(Property) >= 1)
			{
				client_print(id,print_chat,"[DRP] You can't put a property up for rent, while selling it.");
				return PLUGIN_HANDLED
			}
			
			// Check for previous deletions
			Found = 0
			for(new Count;Count < g_PropertyInt;Count++)
			{
				if(g_Propertys[Count] == Invalid_Array)
				{
					Found = Count + 1
					break;
				}
			}
			
			new Array:CurArray = g_Propertys[Found ? Found - 1 : g_PropertyInt++] = ArrayCreate(36);
			
			// we should never get here
			if(g_PropertyInt >= 126)
			{
				client_print(id,print_chat,"[DRP] There was an error; please contact an administrator.");
				return PLUGIN_HANDLED
			}
			
			client_print(id,print_chat,"[DRP] You placed ^"%s^" up for rent, for $%d per/day",PropertyName,Price);
			client_print(id,print_chat,"[DRP] Use /rent 0 to stop the renting.");
			
			ArrayPushCell(CurArray,Property);
			ArrayPushString(CurArray,""); // AuthID of Renter
			ArrayPushCell(CurArray,Price);
			ArrayPushCell(CurArray,0);
			
			new Query[128]
			DRP_PropertyGetInternalName(Property,PropertyName,32);
			
			formatex(Query,127,"INSERT INTO `Renting` VALUES('%s','','%d','0')",PropertyName,Price);
			SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",Query);
		}
		return PLUGIN_HANDLED
	}
	
	if(Found == -1)
	{
		client_print(id,print_chat,"[DRP] This property is not up for renting.");
		return PLUGIN_HANDLED
	}
	
	new szMenu[128]
	new Array:CurArray = g_Propertys[Found]
	
	ArrayGetString(CurArray,1,szMenu,127);
	
	if(szMenu[0])
	{
		new AuthID[36]
		get_user_authid(id,AuthID,35);
		
		if(equali(AuthID,szMenu))
		{
			EndRent(Property);
			client_print(id,print_chat,"[DRP] You have ended your rent.");
			return PLUGIN_HANDLED
		}
		
		client_print(id,print_chat,"[DRP] You can't stop this rent; you are not renting.");
		return PLUGIN_HANDLED
	}
	
	new RentPrice = ArrayGetCell(CurArray,2);
	formatex(szMenu,127,"%s^n$%d per day (from your bank)",PropertyName,RentPrice);
	
	new Menu = menu_create(szMenu,"_RentHandle"),Data[12]
	num_to_str(Property,Data,11);
	
	formatex(szMenu,127,"1 Day ($%d)",(RentPrice * 1));
	menu_additem(Menu,szMenu,Data);
	
	formatex(szMenu,127,"3 Days ($%d)",(RentPrice * 3));
	menu_additem(Menu,szMenu,Data);
	
	formatex(szMenu,127,"6 Days ($%d)",(RentPrice * 6));
	menu_additem(Menu,szMenu,Data)
	
	menu_display(id,Menu);
	return PLUGIN_HANDLED
}
/*==================================================================================================================================================*/
public _RentHandle(id,Menu,Item)
{
	if(Item == MENU_EXIT)
	{
		menu_destroy(Menu)
		return PLUGIN_HANDLED
	}
	
	new Data[12],Temp
	menu_item_getinfo(Menu,Item,Temp,Data,11,_,_,Temp);
	menu_destroy(Menu);
	
	new Array:CurArray
	new const Property = str_to_num(Data),Found = FindProperty(Property);
	
	if(Found == -1)
	{
		client_print(id,print_chat,"[DRP] There was an error; please contact an administrator.");
		return PLUGIN_HANDLED
	}
	
	CurArray = g_Propertys[Found]
	
	new Day,Minutes
	switch(Item)
	{
		case 0:
		{
			Day = 1;
			Minutes = 1440;
		}
		case 1:
		{
			Day = 3;
			Minutes = 4320;
		}
		case 2:
		{
			Day = 6;
			Minutes = 8640;
		}
	}
	
	new RentCost,Bank = DRP_GetUserBank(id);
	RentCost = (ArrayGetCell(CurArray,2) * Day)
	
	if(Bank < RentCost)
	{
		client_print(id,print_chat,"[DRP] You do not have enough money in the bank to afford these days.");
		return PLUGIN_HANDLED
	}
	
	new AuthID[36],ExternalName[33]
	get_user_authid(id,AuthID,35);
	
	new const Owner = DRP_PropertyGetOwner(Property);
	DRP_PropertyGetExternalName(Property,ExternalName,32);
	
	DRP_SetUserBank(id,Bank - RentCost);
	
	ArraySetCell(CurArray,3,Minutes);
	ArraySetString(CurArray,1,AuthID);
	
	client_print(id,print_chat,"[DRP] You are now renting ^"%s^" for %d day(s)",ExternalName,Day);
	
	// Update
	new Query[256]
	DRP_PropertyGetInternalName(Property,ExternalName,32);
	
	formatex(Query,255,"UPDATE `Renting` SET `RenterAuthID`='%s',`TimeLeft`='%d' WHERE `InternalName`='%s'",AuthID,Minutes,ExternalName);
	SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",Query);
	
	DRP_PropertyAddAccess(Property,AuthID);
	
	if(Owner)
	{
		get_user_name(id,AuthID,35);
		
		DRP_SetUserBank(Owner,DRP_GetUserBank(Owner) + RentCost);
		client_print(Owner,print_chat,"[DRP] You have been given $%d payed by %s for the property: ^"%s^"",RentCost,AuthID,ExternalName);
	}
	else
	{
		new Query[128]
		DRP_PropertyGetOwnerAuth(Property,AuthID,35);
		
		formatex(Query,255,"UPDATE `Users` SET `BankMoney` = BankMoney + %d WHERE `SteamID`='%s'",RentCost,AuthID);
		SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",Query);
	}
	return PLUGIN_HANDLED
}
/*==================================================================================================================================================*/
public FetchRentableProperty(FailState,Handle:Query,const Error[],Errcode,const Data[],DataSize) 
{
	if(FailState != TQUERY_SUCCESS)
		return DRP_ThrowError(0,"Problem with MySQL Query (%s)",Error ? Error : "UNKNOWN");
	
	new InternalName[36]
	while(SQL_MoreResults(Query))
	{
		new Price = SQL_ReadResult(Query,2),TimeLeft = SQL_ReadResult(Query,3);
		SQL_ReadResult(Query,0,InternalName,35);
		
		new Property = DRP_PropertyMatch("",_,InternalName);
		
		if(!Property)
		{
			// Property doesn't exist
			// We probably should delete it. but we'll just skip it for now
			
			SQL_NextRow(Query);
			continue
		}
		
		SQL_ReadResult(Query,1,InternalName,35);
		
		g_Propertys[g_PropertyInt]  = ArrayCreate(36);
		
		ArrayPushCell(g_Propertys[g_PropertyInt],Property); // 0
		ArrayPushString(g_Propertys[g_PropertyInt],InternalName); // 1
		ArrayPushCell(g_Propertys[g_PropertyInt],Price); // 2
		ArrayPushCell(g_Propertys[g_PropertyInt],TimeLeft); // 3
		
		g_PropertyInt++
		SQL_NextRow(Query);
	}
	return PLUGIN_CONTINUE
}

public IgnoreHandle(FailState,Handle:Query,const Error[],Errcode,const Data[],DataSize) 
{
	if(FailState != TQUERY_SUCCESS)
		return DRP_ThrowError(0,"Problem with MySQL Query (%s)",Error ? Error : "UNKNOWN");
	
	return PLUGIN_CONTINUE
}

public RemovePropertyRent(FailState,Handle:Query,const Error[],Errcode,const Data[],DataSize) 
{
	if(FailState != TQUERY_SUCCESS)
		return DRP_ThrowError(0,"Problem with MySQL Query (%s)",Error ? Error : "UNKNOWN");
	
	new szQuery[256],InternalName[36],AuthID[36],OldPrice = SQL_ReadResult(Query,5);
	SQL_ReadResult(Query,0,InternalName,35);
	SQL_ReadResult(Query,1,AuthID,35);
	
	new Property = DRP_PropertyMatch(_,_,InternalName);
	if(Property)
	{
		DRP_PropertyRemoveAccess(Property,AuthID);
		server_print("REMOVING ACCESS FOR : %s",AuthID);
	}
	
	formatex(szQuery,255,"UPDATE `Renting` SET `RenterAuthID`='',`RentCost`='%d',`DatedPosted`='',`DayRented`='' WHERE `InternalName`='%s'",InternalName,OldPrice);
	SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",szQuery);
	
	return PLUGIN_CONTINUE
}

CheckSteamID(const SteamID[])
{
	new iPlayers[32],iNum,Player
	get_players(iPlayers,iNum);
	
	new AuthID[36]
	for(new Count;Count < iNum;Count++)
	{
		Player = iPlayers[Count]
		get_user_authid(Player,AuthID,35);
		
		if(equal(SteamID,AuthID))
			return Player
	}
	return FAILED
}

public plugin_end()
	for(new Count;Count < g_PropertyInt;Count++)
		if(g_Propertys[Count] != Invalid_Array)
			ArrayDestroy(g_Propertys[Count]);