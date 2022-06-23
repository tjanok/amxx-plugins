#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <engine> // find_sphere_class();

#include <DRP/DRPCore>
#include <DRP/DRPChat>
#include <DRP/DRPNpc>

#include <TSXWeapons>

// Access Loans / Credit Cards
// Events that handle taxes will be handled by this plugin too
#define DRP_BANKING "DRPEconomy.amxx"

#define MAX_NPC 32 + 1
#define MAX_NPC_ITEMS 20 + 1

// Used for "UpdateNPCItems()"
#define NPC_SUBTRACT 1
#define NPC_ADD 2
#define NPC_SET 3

#define NPC_TYPES 7

// We use SQL for adding/subtracting items
// from an NPC
new Handle:g_SqlHandle

new const g_Npcs[NPC_TYPES][] = 
{
	"shop",
	"bank",
	"doctor",
	"gunshop",
	"atm",
	"pawn",
	"storage"
}
new const g_NpcHandlers[NPC_TYPES][] =
{
	"ShopHandle",
	"BankHandle",
	"DoctorHandle",
	"GunshopHandle",
	"ATMHandle",
	"PawnHandle",
	"StorageHandle"
}

enum SELLING
{
	ITEMID = 0,
	COST,
	ITEM_AMOUNT
}

new g_Selling[MAX_NPC][MAX_NPC_ITEMS][SELLING]
new g_ItemNum[MAX_NPC] = {1,...}
new g_NpcID[MAX_NPC]
new g_NpcNum

new g_NonRestricted[MAX_NPC][44][SELLING]
new g_Restricted[MAX_NPC][44][SELLING]
new g_WeaponNum[MAX_NPC][3]
new g_RobProfile[MAX_NPC][33]

new g_NPCExternalName[MAX_NPC][33]

new g_CurNpc[33]
new g_CurNpcID[33]
new g_Mode[33]

new g_ItemLicenses[2]
new g_itemPda
new g_itemATMCard

new g_DRPBankingID
new g_Plugin

// Menus
new const g_FillModel[] = "models/pellet.mdl"
new const g_ATMNoise[] = "ambience/computalk2.wav"
new const g_ScanSound[] = "items/suitcharge1.wav" // precached in the talkarea

new p_FillCost
new p_ATMCardPrice
new p_HealPrice

new g_Menu[256]
new g_ShopOwnerMenu
new g_StorageMenu
new g_ATMMenu
new g_ATMUseMenu
new g_GunShopMenu
new g_BankMenu

// Natives
public plugin_natives()
{
	register_library("DRPNPC");
	
	register_native("DRP_RegisterNPC","_DRP_RegisterNPC");
}
public _DRP_RegisterNPC(Plugin,Params)
{
	if(Params < 8)
	{
		DRP_ThrowError(1,"Parameters do not match. Expected: 8, Found: %d",Params);
		return FAILED
	}

	new Name[35],Float:Origin[3],Float:Angle,Model[36],Trace,Zone,Property[33],Handler[33]
	get_string(1,Name,32);
	get_string(5,Handler,32);
	
	get_array_f(2,Origin,3);
	
	get_string(4,Model,35);
	get_string(7,Property,32);
	
	Angle = get_param_f(3);
	Trace = get_param(8);
	Zone = get_param(6);
	
	if(!Name[0] || !Handler[0] || !Model[0])
	{
		DRP_ThrowError(1,"Missing Information on ^"DRP_RegisterNPC^"");
		return FAILED
	}
	
	return CreateNPC(Name,Handler,Origin,Angle,Model,Zone,Property,0,Trace,0,Plugin);
}
public plugin_init()
{
	// Commands
	DRP_AddCommand("say /deposit","Deposit's money if facing a banker/ATM");
	DRP_AddCommand("say /withdraw","Withdraw's money if facing a banker/ATM");
	DRP_AddCommand("say /transfer","Face a banker/ATM, and transfer money to a player.");
	
	DRP_RegisterCmd("drp_itempda","CmdPda","<itemid/namename> - searches the world for a specific item.");
	DRP_RegisterCmd("DRP_SetNPCItem","CmdSetNPCItems","");
	
	DRP_AddChat("","CmdSay");
	
	// Events
	register_event("DeathMsg","EventDeathMsg","a");
	
	new Results[1]
	DRP_FindItemID("ATM",Results,1);
	
	g_itemATMCard = Results[0]
	if(!DRP_ValidItemID(g_itemATMCard))
		DRP_ThrowError(0,"Unable to find the ATM Card Item. Are you sure ^"DRPItems Plugin^" is running?");
	
	g_DRPBankingID = find_plugin_byfile(DRP_BANKING);
	if(g_DRPBankingID == INVALID_PLUGIN_ID)
		DRP_ThrowError(0,"Unable to Find the DRP_Banking Plugin (%s). Some features such as loans and credit cards will not be available.",DRP_BANKING);
	
	CreateMenus();
}

public DRP_Error(const Reason[])
	pause("d");

public DRP_Init()
{
	g_SqlHandle = DRP_SqlHandle();
	
	format(g_Menu,255,"CREATE TABLE IF NOT EXISTS `NPCItems` (NPCItemName VARCHAR(36),Num INT(12),Price INT(12),PropertyOwnerAccessOnly INT(12),PRIMARY KEY(NPCItemName))");
	SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",g_Menu);
}

public DRP_RegisterItems()
{
	g_itemPda = DRP_RegisterItem("Item PDA","_ItemLook","This PDA (Personal Data Assistant) allows you to search the world for a specifc item.",0,0,0);
	g_ItemLicenses[0] = DRP_RegisterItem("Restricted License","_License","Allows you to purchase ^"Restricted Weapons^".",0,0,0);
	g_ItemLicenses[1] = DRP_RegisterItem("Permitted License","_License","Allows you to purchase ^"Permitted Weapons^".",0,0,0);
}

public client_disconnect(id)
{
	g_CurNpc[id] = 0
	g_CurNpcID[id] = 0
	g_Mode[id] = 0
}

public EventDeathMsg()
{
	new const id = read_data(2);
	if(!id)
		return
	
	g_CurNpc[id] = 0
	g_CurNpcID[id] = 0
	g_Mode[id] = 0
}

public plugin_precache()
{
	g_Plugin = register_plugin("DRP - NPCs","0.1a2","Drak");
	
	p_ATMCardPrice = register_cvar("DRP_ATMCardPrice","102");
	p_FillCost = register_cvar("DRP_AmmoRefillCost","50");
	p_HealPrice = register_cvar("DRP_HealPrice","100");
	
	precache_model(g_FillModel);
	precache_sound(g_ATMNoise);
	
	new FileName[128]
	DRP_GetConfigsDir(FileName,127);
	
	add(FileName,127,"/Npcs.ini");
	
	if(!file_exists(FileName))
	{
		// It's empty - stop now
		write_file(FileName,"");
		return
	}
	
	new pFile = fopen(FileName,"r"),Buffer[128]
	if(!pFile)
	{
		DRP_ThrowError(1,"Can't open NPC Config File (%s)",FileName);
		return
	}
	
	new ConfigsDir[64],Model[64],Float:Angle,Float:Origin[3],Cache[3][12],Type,Sell[64],Name[128],Zone,Animation,Property[64],Body,SkipTrace,ExternalName[33],RobProfile[26]
	while(!feof(pFile))
	{
		fgets(pFile,Buffer,127);
		
		if(!Buffer[0] || Buffer[0] == ';')
			continue
			
		new const End = strlen(Buffer) - 1
		if(Buffer[End] == '^n') Buffer[End] = '^0'
		
		if(containi(Buffer,"[END]") != -1)
		{
			if(g_NpcNum > MAX_NPC)
			{
				DRP_ThrowError(0,"Max NPC's Reached (Max: %d) - This limit is hardcoded.",MAX_NPC);
				break;
			}
			
			if(Model[0])
			{
				if((!Animation) && !file_exists(Model))
				{
					DRP_ThrowError(1,"Unable to open NPC Model (%s)",Model);
					break;
				}
				
				precache_model(Model);
			}
			
			g_NpcID[g_NpcNum++] = CreateNPC(Name,g_NpcHandlers[Type],Origin,Angle,Model,Zone,Property,Body,SkipTrace,Animation);
			
			if(ExternalName[0])
			{
				new Data[1]
				Data[0] = g_NpcNum - 1
				
				format(g_Menu,255,"SELECT * FROM `NPCItems` WHERE `NPCItemName` LIKE '%s|%%'",ExternalName);
				SQL_ThreadQuery(g_SqlHandle,"FetchNPCItems",g_Menu,Data,1);
				
				copy(g_NPCExternalName[Data[0]],35,ExternalName);
				ExternalName[0] = 0
			}
			
			// Reset
			Zone = 0
			Body = 0
			Angle = 0.0
			SkipTrace = 0
			Animation = 0
			
			RobProfile[0] = 0
			Model[0] = 0
			Property[0] = 0
		}
		else if(containi(Buffer,"external") != -1)
		{
			parse(Buffer,FileName,1,ConfigsDir,63);
			trim(ConfigsDir);
			remove_quotes(ConfigsDir);
			
			copy(ExternalName,127,ConfigsDir);
		}
		else if(containi(Buffer,"name") != -1)
		{
			parse(Buffer,FileName,1,Name,127);
			trim(Name)
			remove_quotes(Name);
		}
		else if(containi(Buffer,"body") != -1)
		{
			parse(Buffer,FileName,1,ConfigsDir,63);
			trim(ConfigsDir);
			remove_quotes(ConfigsDir);
			
			Body = str_to_num(ConfigsDir);
		}
		else if(containi(Buffer,"type") != -1)
		{
			parse(Buffer,ConfigsDir,1,FileName,127);
			trim(FileName);
			remove_quotes(FileName);
			
			for(new Count;Count < NPC_TYPES;Count++)
			{
				if(equal(g_Npcs[Count],FileName))
					Type = Count
			}
		}
		else if(containi(Buffer,"model") != -1)
		{
			parse(Buffer,ConfigsDir,1,Model,63);
			remove_quotes(Model);
		}
		else if(containi(Buffer,"angle") != -1)
		{
			parse(Buffer,ConfigsDir,1,FileName,127);
			remove_quotes(FileName);
			
			Angle = str_to_float(FileName);
		}
		else if(containi(Buffer,"animation") != -1)
		{
			parse(Buffer,ConfigsDir,1,FileName,127);
			remove_quotes(FileName);
			
			Animation = str_to_num(FileName);
		}
		else if(containi(Buffer,"origin") != -1)
		{
			parse(Buffer,FileName,1,ConfigsDir,63);
			remove_quotes(ConfigsDir);
			
			parse(ConfigsDir,Cache[0],11,Cache[1],11,Cache[2],11);
			
			for(new Count;Count < 3;Count++)
				Origin[Count] = str_to_float(Cache[Count]);
		}
		else if(containi(Buffer,"zone") != -1)
		{
			parse(Buffer,FileName,1,ConfigsDir,63);
			strtolower(ConfigsDir);
			
			Zone = 1
		}
		else if(containi(Buffer,"sell") != -1)
		{
			// This NPC is external - we don't sell here
			if(ExternalName[0])
				continue
			
			parse(Buffer,FileName,1,Sell,63);
			remove_quotes(Sell);
			
			parse(Sell,FileName,63,ConfigsDir,63,Buffer,127);
			
			if(is_str_num(FileName))
				g_Selling[g_NpcNum][g_ItemNum[g_NpcNum]][ITEMID] = str_to_num(FileName);
			else
			{
				remove_quotes(FileName);
				while(replace(FileName,63,"_"," ") || replace(FileName,63,"^n","")) { }
				
				new Results[1]
				DRP_FindItemID(FileName,Results,1);
				
				if(!DRP_ValidItemID(Results[0]))
				{
					server_print("[DRP] Invalid ItemID for NPC. (Name: %s)",FileName);
					continue
				}
				
				g_Selling[g_NpcNum][g_ItemNum[g_NpcNum]][ITEMID] = Results[0]
			}
			
			g_Selling[g_NpcNum][g_ItemNum[g_NpcNum]][COST] = str_to_num(ConfigsDir);
			g_Selling[g_NpcNum][g_ItemNum[g_NpcNum]++][ITEM_AMOUNT] = -1 // -1 = unlimited
		}
		else if(containi(Buffer,"addgun") != -1)
		{
			parse(Buffer,FileName,1,Sell,63);
			remove_quotes(Sell);
			
			parse(Sell,FileName,127,ConfigsDir,63,Buffer,127);
			
			remove_quotes(FileName);
			while(replace(FileName,127,"_"," ") || replace(FileName,127,"^n","")) { }
			
			new License = clamp(str_to_num(Buffer),0,2),Results[1]
			DRP_FindItemID(FileName,Results,1);
			
			if(!DRP_ValidItemID(Results[0]))
			{
				DRP_ThrowError(0,"Unable to Find ItemID for Item ^"%s^"",FileName);
				continue
			}
			
			switch(License)
			{
				case 0:
				{
					g_NonRestricted[g_NpcNum][g_WeaponNum[g_NpcNum][0]][COST] = str_to_num(ConfigsDir);
					g_NonRestricted[g_NpcNum][g_WeaponNum[g_NpcNum][0]][ITEMID] = Results[0]
					
					g_WeaponNum[g_NpcNum][0]++
				}
				case 1:
				{
					g_Restricted[g_NpcNum][g_WeaponNum[g_NpcNum][1]][COST] = str_to_num(ConfigsDir);
					g_Restricted[g_NpcNum][g_WeaponNum[g_NpcNum][1]][ITEMID] = Results[0]
					
					g_WeaponNum[g_NpcNum][1]++
				}
				case 2:
				{
					g_Selling[g_NpcNum][g_WeaponNum[g_NpcNum][2]][ITEMID] = Results[0]
					g_Selling[g_NpcNum][g_WeaponNum[g_NpcNum][2]][COST] = str_to_num(ConfigsDir);
					g_Selling[g_NpcNum][g_WeaponNum[g_NpcNum][2]][ITEM_AMOUNT] = -1 // -1 = unlimited
					
					// we loop with this
					g_WeaponNum[g_NpcNum][2]++
				}
			}
		}
		else if(containi(Buffer,"property") != -1)
		{
			parse(Buffer,ConfigsDir,1,Property,63);
			remove_quotes(Property);
		}
		else if(containi(Buffer,"robprofile") != -1)
		{
			parse(Buffer,ConfigsDir,1,RobProfile,25);
			remove_quotes(RobProfile);
			copy(g_RobProfile[g_NpcNum],25,RobProfile);
		}
		else if(containi(Buffer,"skiptrace") != -1)
		{
			SkipTrace = 1
		}
	}
	fclose(pFile);
}
/*==================================================================================================================================================*/
public BankHandle(const id,const Ent)
{
	new const Npc = FindNPC(Ent);
	
	g_CurNpc[id] = Npc
	g_CurNpcID[id] = Ent
	
	menu_display(id,g_BankMenu);
	return PLUGIN_HANDLED
}

public ShopHandle(const id,const Ent)
	Shop(id,Ent);
public DoctorHandle(const id,const Ent)
	Doctor(id,Ent);
public GunshopHandle(const id,const Ent)
	Gunshop(id,Ent);
public PawnHandle(const id,const Ent)
	Pawn(id,Ent);

public ATMHandle(const id,const Ent)
{
	if(!DRP_GetUserItemNum(id,g_itemATMCard))
	{
		client_print(id,print_chat,"[DRP] You do not have a ATM/Debit Card.");
		return
	}
	
	new const Npc = FindNPC(Ent);
	
	g_CurNpc[id] = Npc
	g_CurNpcID[id] = Ent
	
	menu_display(id,g_ATMMenu);
}
public StorageHandle(const id,const Ent)
{
	new Npc = FindNPC(Ent);

	if(!DRP_IsAdmin(id))
	{
		new Property = DRP_GetNpcProperty(Ent);
		
		if(!Property || Property == -1)
		{
			client_print(id,print_chat,"[DRP] This NPC is not linked to a property. Unable to check access.");
			return PLUGIN_HANDLED
		}
		
		// Owner only
		// If they have a rob profile (edited inside the npc's file)
		if(g_RobProfile[Npc][0])
		{
			if(!DRP_PropertyGetOwner(Property) == id)
			{
				client_print(id,print_chat,"[DRP] You are not able to access this storage unit.");
				return PLUGIN_HANDLED
			}
		}
		
		if(!(DRP_GetUserAccess(id) & DRP_PropertyGetAccess(Property)) && !(DRP_PropertyGetOwner(Property) == id))
		{
			client_print(id,print_chat,"[DRP] You are not able to access this storage unit.");
			return PLUGIN_HANDLED
		}
	}
	
	g_CurNpcID[id] = Ent
	g_CurNpc[id] = Npc
	
	menu_display(id,g_StorageMenu);
	return PLUGIN_HANDLED
}
/*==================================================================================================================================================*/
// BANK HANDLE
public BankMenuHandle(id,Menu,Item)
{
	if(Item == MENU_EXIT || !DRP_NPCDistance(id,g_CurNpcID[id]))
		return PLUGIN_HANDLED
	
	switch(Item)
	{
		case 0:
			client_print(id,print_chat,"[DRP] Type /withdraw or /deposit to withdraw/deposit. Or /transfer to transfer cash.");
		case 1:
		{
			if(DRP_GetUserItemNum(id,g_itemATMCard))
			{
				client_print(id,print_chat,"[DRP] You already own a debit/ATM card.");
				return PLUGIN_HANDLED
			}
			
			new const Cash = DRP_GetUserBank(id),Price = get_pcvar_num(p_ATMCardPrice);
			
			if(Cash < Price)
			{
				client_print(id,print_chat,"[DRP] You don't have enough money in your bank.")
				return PLUGIN_HANDLED
			}
			
			DRP_SetUserItemNum(id,g_itemATMCard,DRP_GetUserItemNum(id,g_itemATMCard) + 1);
			DRP_SetUserBank(id,Cash - Price);
			
			client_print(id,print_chat,"[DRP] You have successfully purchased an ATM Card.");
			return PLUGIN_HANDLED
		}
		
		// Loan
		case 2:
		{
			if(g_DRPBankingID == INVALID_PLUGIN_ID)
			{
				client_print(id,print_chat,"[DRP] This feature is not currently enabled.");
				return PLUGIN_HANDLED
			}
			
			new Forward = CreateOneForward(g_DRPBankingID,"Forward_Loans",ET_IGNORE,FP_CELL),Return
			if(!Forward || !ExecuteForward(Forward,Return,id))
			{
				client_print(id,print_chat,"[DRP] There was a problem calling the function. Please contact an administrator.");
				return PLUGIN_HANDLED
			}
		}
		
		// Credit Card
		case 3:
		{
			if(g_DRPBankingID == INVALID_PLUGIN_ID)
			{
				client_print(id,print_chat,"[DRP] This feature is not currently enabled.");
				return PLUGIN_HANDLED
			}
			
			new Forward = CreateOneForward(g_DRPBankingID,"Forward_CCard",ET_IGNORE,FP_CELL),Return
			if(!Forward || !ExecuteForward(Forward,Return,id))
			{
				client_print(id,print_chat,"[DRP] There was a problem calling the function. Please contact an administrator.");
				return PLUGIN_HANDLED
			}
		}
		
		case 4:
		{
			if(!DRP_ShowMOTDHelp(id,"DRPNPC_BankHelp.txt"))
				client_print(id,print_chat,"[DRP] Problem opening file. Please contact an administrator.");
			
			return PLUGIN_HANDLED
		}
		
		// Rob
		case 5:
		{
			if(!g_RobProfile[g_CurNpc[id]][0])
				return PLUGIN_HANDLED
			
			new Data[34]
			Data[0] = id
			Data[1] = DRP_GetNpcProperty(g_CurNpcID[id]);
			
			copy(Data[2],31,g_RobProfile[g_CurNpc[id]]);
			
			DRP_CallEvent("Rob_Begin",Data,34);
			return PLUGIN_HANDLED
		}
	}
	return PLUGIN_HANDLED
}
// END BANK HANDLE
/*==================================================================================================================================================*/
// SHOP HANDLE
Shop(id,Ent,OverRide = 0)
{
	new Name[33],Property
	new const Npc = FindNPC(Ent);
	
	if(!OverRide)
		Property = DRP_GetNpcProperty(Ent);
	
	g_CurNpc[id] = Npc
	g_CurNpcID[id] = Ent
	
	// Check if we have access to the NPC's Property. (Owner or Access)
	if(Property != -1 && !OverRide)
	{
		new const Access = DRP_PropertyGetAccess(Property),Owner = DRP_PropertyGetOwner(Property);
		if(Owner == id || Access & DRP_GetUserAccess(id))
		{
			menu_display(id,g_ShopOwnerMenu);
			return PLUGIN_HANDLED
		}
	}
	
	if(g_ItemNum[Npc] <= 1)
	{
		client_print(id,print_chat,"[DRP] This NPC currently has no items.");
		return PLUGIN_HANDLED
	}
	
	pev(Ent,pev_noise1,Name,32);
	formatex(g_Menu,255,"NPC: %s",Name);
	
	new Menu = menu_create(g_Menu,"ShopMenuHandle"),ItemName[33],Command[64]
	
	if(g_RobProfile[Npc][0])
	{
		menu_additem(Menu,"Rob","-1");
		menu_addblank(Menu,0);
	}
	
	for(new Count = 1;Count < g_ItemNum[Npc];Count++)
	{
		DRP_ValidItemID(g_Selling[Npc][Count][ITEMID]) ?
			DRP_GetItemName(g_Selling[Npc][Count][ITEMID],ItemName,32) : copy(ItemName,32,"BAD ITEM ID: Contact admin");
		
		if(g_Selling[Npc][Count][ITEM_AMOUNT] != -1)
			formatex(Command,63,"%s - $%d (x %d)",ItemName,g_Selling[Npc][Count][COST],g_Selling[Npc][Count][ITEM_AMOUNT]);
		else
			formatex(Command,63,"%s - $%d",ItemName,g_Selling[Npc][Count][COST]);
		
		//num_to_str(g_Selling[Npc][Count][ITEMID],ItemNum,9);
		menu_additem(Menu,Command);
	}
	
	menu_display(id,Menu);
	return PLUGIN_HANDLED
}
public ShopOwnerHandle(id,Menu,Item)
{
	if(Item == MENU_EXIT || !DRP_NPCDistance(id,g_CurNpcID[id]))
		return PLUGIN_HANDLED

	switch(Item)
	{
		case 0:
		{
			if(!DRP_ShowMOTDHelp(id,"DRPNPC_NPCItems.txt"))
				client_print(id,print_chat,"[DRP] Problem opening file. Please contact an administrator.");
		}
		case 1:
		{
			Shop(id,g_CurNpcID[id],1);
		}
	}
	return PLUGIN_HANDLED
}
public ShopMenuHandle(id,Menu,Item)
{
	menu_destroy(Menu);
	
	if(Item == MENU_EXIT || !DRP_NPCDistance(id,g_CurNpcID[id]))
		return PLUGIN_HANDLED
	
	// Robbing
	if(!Item  && g_RobProfile[g_CurNpc[id]][0])
	{
		new Data[34]
		Data[0] = id
		
		copy(Data[1],32,g_RobProfile[g_CurNpc[id]]);
		DRP_CallEvent("Rob_Begin",Data,34);
		
		return PLUGIN_HANDLED
	}
	else if(!g_RobProfile[g_CurNpc[id]][0]) 
		Item++
	
	// We are not robbing, we must be buying. Open a new menu asking how much to buy
	new Info[12]
	num_to_str(Item,Info,11);
	
	Menu = menu_create("Buy Amount:","ShopMenuHandle2");
	menu_additem(Menu,"x 1",Info);
	menu_additem(Menu,"x 5",Info);
	menu_additem(Menu,"x 10",Info);
	menu_additem(Menu,"x 20^n",Info);
	menu_additem(Menu,"Examine Item",Info);
	menu_display(id,Menu);
	
	return PLUGIN_HANDLED
}
public ShopMenuHandle2(id,Menu,Item)
{
	if(Item == MENU_EXIT || !DRP_NPCDistance(id,g_CurNpcID[id]))
	{
		menu_destroy(Menu);
		return PLUGIN_HANDLED
	}
	
	new Access,Info[12],Amount
	menu_item_getinfo(Menu,Item,Access,Info,11,_,_,Access);
	
	new NpcID = str_to_num(Info);
	new const UserCash = DRP_GetUserWallet(id),ItemID = g_Selling[g_CurNpc[id]][NpcID][ITEMID]
	
	switch(Item)
	{
		case 0: Amount = 1
		case 1: Amount = 5
		case 2: Amount = 10
		case 3: Amount = 20
		case 4: 
		{
			DRP_ItemInfo(id,ItemID);
			return menu_display(id,Menu);
		}
	}
	
	new const Cost = (g_Selling[g_CurNpc[id]][NpcID][COST] * Amount)
	menu_destroy(Menu);
	
	if(!DRP_ValidItemID(ItemID))
	{
		client_print(id,print_chat,"[DRP] Invalid ItemID - Please contact an administrator.");
		return PLUGIN_HANDLED
	}
	
	// Check if we have enough of the item in the npc
	new Num = g_Selling[g_CurNpc[id]][NpcID][ITEM_AMOUNT]
	if(Num != -1)
	{
		if(Amount > Num)
		{
			client_print(id,print_chat,"[DRP] There is not enough of that item in the NPC.");
			return PLUGIN_HANDLED
		}
	}
	
	if(Cost > UserCash)
	{
		client_print(id,print_chat,"[DRP] You do not have enough money in your wallet for this item.");
		return PLUGIN_HANDLED
	}
	
	// Update NPC Amount
	if(Num != -1)
	{
		new NewAmount = (g_Selling[g_CurNpc[id]][NpcID][ITEM_AMOUNT] - Amount)
		UpdateNPCItems(g_CurNpc[id],ItemID,NewAmount,_,NPC_SUBTRACT);
	}
	
	new ItemName[33]
	DRP_GetItemName(ItemID,ItemName,32);
	
	new Data[3]
	Data[0] = id
	Data[1] = ItemID
	Data[2] = Cost
	
	if(DRP_CallEvent("Player_BuyItem",Data,3))
		return PLUGIN_HANDLED
	
	DRP_SetUserWallet(id,DRP_GetUserWallet(id) - Cost);
	DRP_SetUserItemNum(id,ItemID,DRP_GetUserItemNum(id,ItemID) + Amount);
	
	client_print(id,print_chat,"[DRP] You have successfully bought %s x%d ($%d)",ItemName,Amount,Cost);
	
	return PLUGIN_HANDLED
}
// END SHOP HANDLE
/*==================================================================================================================================================*/
// GUNSHOP HANDLE
Gunshop(id,Ent)
{
	new Npc = FindNPC(Ent);
	
	g_CurNpc[id] = Npc
	g_CurNpcID[id] = Ent
	
	menu_display(id,g_GunShopMenu);
	return PLUGIN_HANDLED
}

public GunshopMenuHandle(id,Menu,Item)
{
	if(Item == MENU_EXIT || !DRP_NPCDistance(id,g_CurNpcID[id]))
		return PLUGIN_HANDLED
	
	switch(Item)
	{
		case 0..1:
		{
			if(!DRP_GetUserItemNum(id,Item == 0 ? g_ItemLicenses[1] : g_ItemLicenses[0]))
			{
				client_print(id,print_chat,"[DRP] You must have a ^"%s^" license to buy these type of weapons.",Item == 0 ? "Permitted" : "Restricted");
				return PLUGIN_HANDLED
			}
			
			g_Mode[id] = Item
		}
		case 2:
		{
			new const Cost = get_pcvar_num(p_FillCost),Money = DRP_GetUserWallet(id);
			if(Cost > Money)
			{
				client_print(id,print_chat,"[DRP] You do not have enough money for this. ($%d)",Cost);
				return PLUGIN_HANDLED
			}
			
			new Temp,Ammo,WeaponID = DRP_TSGetUserWeaponID(id,Temp,Ammo);
			if(WeaponID <= 0)
			{
				client_print(id,print_chat,"[DRP] You must be wielding a weapon that uses ammo. (If you do have a weapon - please contact an admin)");
				return PLUGIN_HANDLED
			}
			
			new const TSAmmo = g_WeaponAmmo[WeaponID]
			if(!TSAmmo)
			{
				client_print(id,print_chat,"[DRP] You must be wielding a weapon that uses ammo.");
				return PLUGIN_HANDLED
			}
			if(Ammo >= TSAmmo)
			{
				client_print(id,print_chat,"[DRP] Your ammo is full for this weapon.");
				return PLUGIN_HANDLED
			}
			
			DRP_SetUserWallet(id,Money - Cost);
			DRP_TSSetUserAmmo(id,WeaponID,TSAmmo);
			
			client_print(id,print_chat,"[DRP] Your ammo has been refilled.");
			return PLUGIN_HANDLED
		}
		case 3:
		{
			g_Mode[id] = 2
		}
	}
	
	if(!g_WeaponNum[g_CurNpc[id]][g_Mode[id]])
	{
		client_print(id,print_chat,"[DRP] There are no items in this category.");
		return PLUGIN_HANDLED
	}
	
	new Menu = menu_create("Gunshop Buying","GunshopUseMenuHandle"),ItemName[33],Command[64]
	for(new Count;Count < g_WeaponNum[g_CurNpc[id]][g_Mode[id]];Count++)
	{
		switch(g_Mode[id])
		{
			case 0:
			{
				if(DRP_ValidItemID(g_NonRestricted[g_CurNpc[id]][Count][ITEMID]))
				{	
					DRP_GetItemName(g_NonRestricted[g_CurNpc[id]][Count][ITEMID],ItemName,32);
					formatex(Command,63,"%s - $%d",ItemName,g_NonRestricted[g_CurNpc[id]][Count][COST]);
				}
				else
					copy(Command,63,"BAD ITEM ID: Contact admin");
			}
			case 1:
			{
				if(DRP_ValidItemID(g_Restricted[g_CurNpc[id]][Count][ITEMID]))
				{
					DRP_GetItemName(g_Restricted[g_CurNpc[id]][Count][ITEMID],ItemName,32);
					formatex(Command,63,"%s - $%d",ItemName,g_Restricted[g_CurNpc[id]][Count][COST]);
				}
				else
					copy(Command,63,"BAD ITEM ID: Contact admin");
			}
			case 2:
			{
				if(DRP_ValidItemID(g_Selling[g_CurNpc[id]][Count][ITEMID]))
				{
					DRP_GetItemName(g_Selling[g_CurNpc[id]][Count][ITEMID],ItemName,32);
					formatex(Command,63,"%s - $%d",ItemName,g_Selling[g_CurNpc[id]][Count][COST]);
				}
				else
					copy(Command,63,"BAD ITEM ID: Contact admin");
			}
		}
		menu_additem(Menu,Command,"");
	}
	menu_display(id,Menu);
	return PLUGIN_HANDLED
}
	
public GunshopUseMenuHandle(id,Menu,Item)
{
	menu_destroy(Menu);
	
	if(Item == MENU_EXIT || !DRP_NPCDistance(id,g_CurNpcID[id]))
		return
	
	new Cost,ItemName[33],ItemID
	switch(g_Mode[id])
	{
		case 0:
		{
			ItemID = g_NonRestricted[g_CurNpc[id]][Item][ITEMID]
			Cost = g_NonRestricted[g_CurNpc[id]][Item][COST]
		}
		case 1:
		{
			ItemID = g_Restricted[g_CurNpc[id]][Item][ITEMID]
			Cost = g_Restricted[g_CurNpc[id]][Item][COST]
		}
		case 2:
		{
			ItemID = g_Selling[g_CurNpc[id]][Item][ITEMID]
			Cost = g_Selling[g_CurNpc[id]][Item][COST]
		}
	}
	
	if(!DRP_ValidItemID(ItemID))
	{
		client_print(id,print_chat,"[DRP] Invalid ItemID (Please contact an admin)");
		return
	}
	
	new const Money = DRP_GetUserWallet(id),Total = Money - Cost
	
	if(Total < 0)
	{
		client_print(id,print_chat,"[DRP] You do not have enough money for this item.");
		return
	}
	
	DRP_GetItemName(ItemID,ItemName,32);
	DRP_SetUserItemNum(id,ItemID,DRP_GetUserItemNum(id,ItemID) + 1);
	
	client_print(id,print_chat,"[DRP] You have purchased a %s.",ItemName);
	DRP_SetUserWallet(id,Total);
}
// END GUNSHOP HANDLE
/*==================================================================================================================================================*/
// DOCTOR HANDLE
Doctor(const id,const Ent)
{
	new NPC = FindNPC(Ent),UserHealth = get_user_health(id);
	
	g_CurNpc[id] = NPC
	g_CurNpcID[id] = Ent
	
	new Command[64],ItemName[33]
	new Menu = menu_create("Doctor","DoctorMenuHandle"),Price = get_pcvar_num(p_HealPrice);
	
	if(Price)
	{
		switch(UserHealth)
		{
			case 1..50: Price += 50
			case 51..90: Price += 20
			case 91..99: Price += 10
		}
		
		formatex(Command,63,"Restore Health ($%d)^n",Price);
		menu_additem(Menu,Command,"-1");
	}
	
	for(new Count = 1;Count < g_ItemNum[NPC];Count++)
	{
		DRP_ValidItemID(g_Selling[NPC][Count][ITEMID]) ?
			DRP_GetItemName(g_Selling[NPC][Count][ITEMID],ItemName,32) : copy(ItemName,32,"BAD ITEM ID: Contact admin");
		
		formatex(Command,63,"%s - $%d",ItemName,g_Selling[NPC][Count][COST]);
		menu_additem(Menu,Command);
	}
	
	if(g_ItemNum[NPC] <= 1)
		menu_addtext(Menu,"^nThis NPC Currently has no items^nplease check back later",0);
	
	menu_display(id,Menu);
	return PLUGIN_HANDLED
}
public DoctorMenuHandle(id,Menu,Item)	
{
	if(Item == MENU_EXIT || !DRP_NPCDistance(id,g_CurNpcID[id]))
	{
		menu_destroy(Menu);
		return PLUGIN_HANDLED
	}
	
	new Info[12],Temp
	menu_item_getinfo(Menu,Item,Temp,Info,11,_,_,Temp);
	menu_destroy(Menu);
	
	new Cash = DRP_GetUserWallet(id);
	
	// Heal Me
	if(equali(Info,"-1"))
	{
		new Price = get_pcvar_num(p_HealPrice),Health = get_user_health(id);
		if(Health >= 100)
		{
			client_print(id,print_chat,"[DRP] Your health is already full.");
			return PLUGIN_HANDLED
		}
		
		switch(get_user_health(id))
		{
			case 1..50: Price += 50
			case 51..90: Price += 20
			case 91..99: Price += 10
		}
		
		if(Price > Cash)
		{
			client_print(id,print_chat,"[DRP] You do not have enough money for a full health restore.");
			return PLUGIN_HANDLED
		}
		
		HealPlayer(id);
		client_print(id,print_chat,"[DRP] MCMD Doctor: You are being healed, please stay still.");
		set_rendering(id,kRenderFxGlowShell,200,50,50);
		
		DRP_SetUserWallet(id,Cash - Price);
		return PLUGIN_HANDLED
	}
	
	if(DRP_GetUserWallet(id) < g_Selling[g_CurNpc[id]][Item][COST])
	{
		client_print(id,print_chat,"[DRP] You don't have enough money for that item.");
		return
	}
}
public HealPlayer(id)
{
	if(!DRP_NPCDistance(id,g_CurNpcID[id]))
		return set_rendering(id);
	
	if(get_user_health(id) >= 100)
	{
		new Float:RenderColors[3]
		pev(id,pev_rendercolor,RenderColors);
		
		if(RenderColors[0] == 200.000000 && RenderColors[1] == 50.000000 && RenderColors[2] == 50.000000)
			set_rendering(id);
		
		client_print(id,print_chat,"[DRP] You have been healed to full health.");
		return PLUGIN_HANDLED
	}
	
	new Float:Health
	pev(id,pev_health,Health);
	
	set_pev(id,pev_health,Health + 1.0);
	
	//if(chance(20))
	///	client_cmd(id,"spk ^"%s^"",g_ScanSound); //emit_sound(id,CHAN_ITEM,g_ScanSound,0.40,ATTN_NORM,0,PITCH_NORM);
	
	set_task(1.0,"HealPlayer",id);
	return PLUGIN_HANDLED
}
// END DOCTOR HANDLE
/*==================================================================================================================================================*/
Pawn(const id,const Ent,ByPass = 0)
{
	// Admin & VIP Feature Only
	if(!DRP_IsAdmin(id) && !DRP_IsVIP(id))
	{
		client_print(id,print_chat,"[DRP] Sorry, this feature is not completed.");
		return PLUGIN_HANDLED
	}
	
	new NPC = FindNPC(Ent);
	
	g_CurNpc[id] = NPC
	g_CurNpcID[id] = Ent
	
	if(!g_NPCExternalName[NPC][0])
	{
		client_print(id,print_chat,"[DRP] There was a problem with this NPC. Please contact an administrator.");
		return PLUGIN_HANDLED
	}
	
	new Menu
	
	if(!ByPass)
	{
		Menu = menu_create("What would you like todo?","_PawnMenu2");
		
		menu_additem(Menu,"Sell Items");
		menu_additem(Menu,"Buy Items");
		
		menu_display(id,Menu);
		return PLUGIN_HANDLED
	}
	
	new Results[256],ItemName[45],ItemID
	formatex(ItemName,44,"Please select the items,^nyou wish to sell");
	
	Menu = menu_create(ItemName,"_PawnMenu");
	new const Num = DRP_FetchUserItems(id,Results);
	
	if(!Num)
	{
		client_print(id,print_chat,"[DRP] You have no items to sell.");
		menu_destroy(Menu);
		
		return PLUGIN_HANDLED
	}
	
	menu_additem(Menu,"Done^n","a");
	
	for(new Count;Count < Num;Count++)
	{
		ItemID = Results[Count]
		
		if(!DRP_ValidItemID(ItemID))
			continue
		
		DRP_GetItemName(ItemID,ItemName,32);
		format(ItemName,32,"%s - ",ItemName);
		
		menu_additem(Menu,ItemName);
	}
	
	menu_display(id,Menu);
	
	client_print(id,print_chat,"[DRP] You can only sell one of each item(s) you select.");
	return PLUGIN_HANDLED
}
public _PawnMenu2(id,Menu,Item)
{
	menu_destroy(Menu);
	
	if(Item == MENU_EXIT)
		return PLUGIN_HANDLED
	
	if(Item == 0)
	{
		Pawn(id,g_CurNpcID[id],1);
		return PLUGIN_HANDLED
	}
	
	// Buy items
	return PLUGIN_HANDLED
}
public _PawnMenu(id,Menu,Item)
{
	if(Item == MENU_EXIT || !DRP_NPCDistance(id,g_CurNpcID[id]))
	{
		menu_destroy(Menu);
		return PLUGIN_HANDLED
	}
	
	new Info[36],szTemp[1],Temp
	menu_item_getinfo(Menu,Item,Temp,Info,35,_,_,Temp);
	
	if(Info[0] == 'a')
	{
		// This holds the ItemID's we are selling
		new Selling[256],Num = menu_items(Menu),ItemID,ItemNum
		for(new Count;Count < Num;Count++)
		{
			menu_item_getinfo(Menu,Count,Temp,szTemp,1,Info,35,Temp);
			
			if(containi(Info,"*") == -1)
				continue
			
			replace_all(Info,35,"*","");
			replace_all(Info,35,"-","");
			trim(Info);
			
			ItemID = DRP_FindItemID2(Info);
			if(ItemID < 0)
				continue
			
			Selling[ItemNum++] = ItemID
		}
		
		menu_destroy(Menu);
		
		//Info[] =  Will contain all the ItemID's we cannot sell
		//AcceptedItems[0] = ItemID
		//AcceptedItems[1] = Price
		
		new NPCItemName[33],AcceptedItems[2][256],NumAcceptedItems,Found
		for(new Count = 1;Count < g_ItemNum[g_CurNpc[id]];Count++)
		{
			ItemID = g_Selling[g_CurNpc[id]][Count][ITEMID]
			Found = 0
			
			for(new Count2;Count2 < ItemNum;Count2++)
			{
				DRP_GetItemName(ItemID,NPCItemName,32);
				DRP_GetItemName(Selling[Count2],Info,34);
				
				if(equali(NPCItemName,Info))
				{
					AcceptedItems[1][NumAcceptedItems] = g_Selling[g_CurNpc[id]][Count][COST]
					AcceptedItems[0][NumAcceptedItems++] = ItemID
				}
			}
		}
		
		new Pos,Total
		Pos += formatex(g_Menu[Pos],255 - Pos,"Below is a list of Item's I'll buy from you^n");
		
		for(new Count;Count < NumAcceptedItems;Count++)
		{
			DRP_GetItemName(AcceptedItems[0][Count],NPCItemName,32);
			Pos+= formatex(g_Menu[Pos],255 - Pos,"Item: %s - $%d^n",NPCItemName,AcceptedItems[1][Count])
			
			Total += AcceptedItems[1][Count]
		}
		show_motd(id,g_Menu);
		
		//g_Selling[id][g_ItemNum[id]][ITEMID] = ItemID
		//g_Selling[id][g_ItemNum[id]][COST] = SQL_ReadResult(Query,2);
		//g_Selling[id][g_ItemNum[id]++][ITEM_AMOUNT] = SQL_ReadResult(Query,1);
			
		return PLUGIN_HANDLED
	}
	
	// We check our prices
	// And confirm
	else if(Info[0] == 'b')
	{
	}
	
	else
	{
		menu_item_getinfo(Menu,Item,Temp,szTemp,1,Info,35,Temp);
		// select/deselect
		// we must set the name and the info
		if(contain(Info,"*") != -1)
		{
			replace_all(Info,35,"*","");
			menu_item_setname(Menu,Item,Info);
		}
		else
		{
			add(Info,35,"*");
			menu_item_setname(Menu,Item,Info);
		}
	}
	
	new Page
	switch(Item)
	{
		case 0..6: Page = 0;
		case 7..13: Page = 1;
		case 14..20: Page = 2;
		case 21..27: Page = 3;
	}
	
	menu_display(id,Menu,Page);
	
	return PLUGIN_HANDLED
}
/*==================================================================================================================================================*/
// ATM Handles
public ATMMenuHandle(id,Menu,Item)
{	
	if(!DRP_NPCDistance(id,g_CurNpcID[id]))
		return PLUGIN_HANDLED
	
	new const Len = sizeof g_Menu - 1
	g_Mode[id] = Item
	formatex(g_Menu,Len,"ATM Teller: %s",Item ? "Deposit" : "Withdraw");
	
	menu_setprop(g_ATMUseMenu,MPROP_TITLE,g_Menu);
	menu_display(id,g_ATMUseMenu);
	
	return PLUGIN_HANDLED
}
public ATMUseMenuHandle(id,Menu,Item)
{
	if(!DRP_NPCDistance(id,g_CurNpcID[id]))
		return PLUGIN_HANDLED
	
	new Amount,Bank = DRP_GetUserBank(id),Wallet = DRP_GetUserWallet(id);
	
	switch(Item)
	{
		case 0: Amount = 10
		case 1: Amount = 20
		case 2: Amount = 50
		case 3: Amount = 100
		case 4: Amount = 200
		case 5: Amount = 500
		case 6: Amount = 1000
	}
	
	new Cash = g_Mode[id] ? Wallet : Bank
	if(Amount > Cash)
	{
		client_print(id,print_chat,"[DRP] You don't have enough money in your %s.",g_Mode[id] ? "wallet" : "bank account");
		return PLUGIN_HANDLED
	}
	
	DRP_SetUserBank(id,g_Mode[id] ? Bank + Amount : Bank - Amount)
	DRP_SetUserWallet(id,g_Mode[id] ? Wallet - Amount : Wallet + Amount)
	
	client_print(id,print_chat,"[DRP] You have %s $%d %s your bank account.",g_Mode[id] ? "deposited" : "withdrawn",Amount,g_Mode[id] ? "into" : "from");
	return PLUGIN_HANDLED
}
// END ATM HANDLES
// STORAGE HANDLE
public StorageHandleMenu(id,Menu,Item)
{
	if(Item == MENU_EXIT || !DRP_NPCDistance(id,g_CurNpcID[id]))
		return PLUGIN_HANDLED
	
	switch(Item)
	{
		case 0:
		{
			if(g_ItemNum[g_CurNpc[id]] >= MAX_ITEMS)
			{
				client_print(id,print_chat,"[DRP] NPC Critical Error. To many items. Please contact an administrator.");
				return PLUGIN_HANDLED
			}
			
			if(g_ItemNum[g_CurNpc[id]] <= 1)
			{
				client_print(id,print_chat,"[DRP] This storage unit has no items.");
				return PLUGIN_HANDLED
			}
			
			new Menu2 = menu_create("Withdraw Item:","StorageHandleMenu2"),Command[64],ItemName[33]
			for(new Count = 1;Count < g_ItemNum[g_CurNpc[id]];Count++)
			{
				DRP_ValidItemID(g_Selling[g_CurNpc[id]][Count][ITEMID]) ?
					DRP_GetItemName(g_Selling[g_CurNpc[id]][Count][ITEMID],ItemName,32) : copy(ItemName,32,"BAD ITEM ID: Contact admin");
					
				// It should never be -1 
				if(g_Selling[g_CurNpc[id]][Count][ITEM_AMOUNT] != -1)
					formatex(Command,63,"%s (x %d)",ItemName,g_Selling[g_CurNpc[id]][Count][ITEM_AMOUNT]);
				else
					copy(Command,63,"Blank. [You can ignore this]");
					
				menu_additem(Menu2,Command);
			}
			menu_display(id,Menu2);
		}
		case 1:
		{
			new Menu2 = menu_create("Deposit Item:","StorageHandleMenu3");
			new Items[MAX_ITEMS],ItemName[33],Command[64],Num = DRP_FetchUserItems(id,Items),ItemID
			
			if(Num > MAX_ITEMS)
			{
				client_print(id,print_chat,"[DRP] Got to many items from player... Please contact an administrator.");
				return PLUGIN_HANDLED
			}
			
			for(new Count;Count < Num;Count++)
			{
				ItemID = Items[Count]
				DRP_GetItemName(ItemID,ItemName,32);
				
				formatex(Command,63,"%s - x%d",ItemName,DRP_GetUserItemNum(id,ItemID));
				menu_additem(Menu2,Command);
			}
			
			menu_display(id,Menu2);
		}
		case 2:
		{
			if(!DRP_ShowMOTDHelp(id,"DRPNPC_StorageNPC.txt"))
				client_print(id,print_chat,"[DRP] Unable to show help file.");
		}
	}
	
	return PLUGIN_HANDLED
}
public StorageHandleMenu3(id,Menu,Item)
{
	if(Item == MENU_EXIT || !DRP_NPCDistance(id,g_CurNpcID[id]))
	{
		menu_destroy(Menu);
		return PLUGIN_HANDLED
	}
	
	new Garbage[1],Temp
	menu_item_getinfo(Menu,Item,Temp,Garbage,0,g_Menu,255,Temp);
	menu_destroy(Menu);
	
	Menu = menu_create("Deposit Amount:","ShopMenuDeposit");
	
	menu_additem(Menu,"x 1",g_Menu);
	menu_additem(Menu,"x 5",g_Menu);
	menu_additem(Menu,"x 10",g_Menu);
	menu_additem(Menu,"x 20",g_Menu);
	
	menu_display(id,Menu);
	
	return PLUGIN_HANDLED
}
public ShopMenuDeposit(id,Menu,Item)
{
	if(Item == MENU_EXIT || !DRP_NPCDistance(id,g_CurNpcID[id]))
	{
		menu_destroy(Menu);
		return PLUGIN_HANDLED
	}
	
	new Amount
	switch(Item)
	{
		case 0: Amount = 1
		case 1: Amount = 5
		case 2: Amount = 10
		case 3: Amount = 20
	}
	
	new Temp,Garbage[1]
	menu_item_getinfo(Menu,Item,Temp,g_Menu,255,_,_,Temp);
	menu_destroy(Menu);
	
	new ItemName[33]
	strtok(g_Menu,ItemName,32,Garbage,0,'-');
	
	remove_quotes(ItemName);
	trim(ItemName);
	
	new const ItemID = DRP_FindItemID2(ItemName);
	
	if(ItemID < 1)
	{
		client_print(id,print_chat,"[DRP] Invalid ItemID. Unable to deposit.");
		return PLUGIN_HANDLED
	}
	
	new ItemNum = DRP_GetUserItemNum(id,ItemID);
	
	if(Amount > ItemNum)
	{
		client_print(id,print_chat,"[DRP] You do not own enough of this item.");
		return PLUGIN_HANDLED
	}
	
	if(!UpdateNPCItems(g_CurNpc[id],ItemID,Amount,_,NPC_ADD))
	{
		client_print(id,print_chat,"[DRP] Unable to deposit item. Please contact an administrator.");
		return PLUGIN_HANDLED
	}
	
	client_print(id,print_chat,"[DRP] You have deposited %s x %d",ItemName,Amount);
	DRP_SetUserItemNum(id,ItemID,ItemNum - Amount);
	
	new StorageName[33]
	DRP_GetNpcName(g_CurNpcID[id],StorageName,32);
	
	new AuthID[36],plName[33]
	get_user_name(id,plName,32);
	get_user_authid(id,AuthID,35);
	
	DRP_Log("%s: ^"%s<%d><%s><> deposited ^"%s<x%d><>^"",StorageName,plName,get_user_userid(id),AuthID,ItemName,Amount);
	
	return PLUGIN_HANDLED
}
public StorageHandleMenu2(id,Menu,Item)
{
	menu_destroy(Menu);
	
	if(Item == MENU_EXIT || !DRP_NPCDistance(id,g_CurNpcID[id]))
		return PLUGIN_HANDLED
	
	new szItem[12]
	num_to_str(Item,szItem,11);
	
	Menu = menu_create("Withdraw Amount:","ShopMenuWithdraw");
	
	menu_additem(Menu,"x 1",szItem);
	menu_additem(Menu,"x 5",szItem);
	menu_additem(Menu,"x 10",szItem);
	menu_additem(Menu,"x 20",szItem);
	
	menu_display(id,Menu);
	return PLUGIN_HANDLED
}

public ShopMenuWithdraw(id,Menu,Item)
{
	if(Item == MENU_EXIT || !DRP_NPCDistance(id,g_CurNpcID[id]))
	{
		menu_destroy(Menu);
		return PLUGIN_HANDLED
	}
	
	new Amount
	switch(Item)
	{
		case 0: Amount = 1
		case 1: Amount = 5
		case 2: Amount = 10
		case 3: Amount = 20
	}
	
	new Temp,szItem[12]
	menu_item_getinfo(Menu,Item,Temp,szItem,11,_,_,Temp);
	menu_destroy(Menu);
	
	new NpcID = str_to_num(szItem) + 1
	new ItemID = g_Selling[g_CurNpc[id]][NpcID][ITEMID]
	
	if(ItemID < 1)
	{
		client_print(id,print_chat,"[DRP] Invalid ItemID. Unable to withdraw item.");
		return PLUGIN_HANDLED
	}
	
	new Num = g_Selling[g_CurNpc[id]][NpcID][ITEM_AMOUNT]
	if(Amount > Num)
	{
		client_print(id,print_chat,"[DRP] There is not enough of that item in the NPC.");
		return PLUGIN_HANDLED
	}
	
	// Update NPC Amount
	if(Num != -1)
		UpdateNPCItems(g_CurNpc[id],ItemID,Amount,_,NPC_SUBTRACT,1);
	
	new ItemName[33]
	DRP_GetItemName(ItemID,ItemName,32);
	
	DRP_SetUserItemNum(id,ItemID,DRP_GetUserItemNum(id,ItemID) + Amount);
	client_print(id,print_chat,"[DRP] You have successfully withdrew %s x %d",ItemName,Amount);
	
	new StorageName[33]
	DRP_GetNpcName(g_CurNpcID[id],StorageName,32);
	
	new AuthID[36],plName[33]
	get_user_name(id,plName,32);
	get_user_authid(id,AuthID,35);
	
	DRP_Log("%s: ^"%s<%d><%s><> withdrew ^"%s<x%d><>^"",StorageName,plName,get_user_userid(id),AuthID,ItemName,Amount);
	
	return PLUGIN_HANDLED
}
/*==================================================================================================================================================*/
public CmdSay(id,Args[])
{
	static Index,Body,Mode = 0
	get_user_aiming(id,Index,Body,100);
	
	if(equali(Args,"/withdraw",9))
		Mode = 1
	else if(equali(Args,"/deposit",8))
		Mode = 2
	else if(equali(Args,"/transfer",9))
		Mode = 3
	else
		return PLUGIN_CONTINUE
	
	static Classname[26]
	
	if(Index)
	{
		pev(Index,pev_classname,Classname,25);
		if(equali(Classname,g_szNPCName))
		{
			pev(Index,pev_noise1,Classname,25)
			
			new ATM = containi(Classname,g_Npcs[4]) != -1 ? 1 : 0
			if(ATM || containi(Classname,g_Npcs[1]) != -1)
			{
				CashF(id,Args,Mode,ATM);
				return PLUGIN_HANDLED
			}
		}
	}
	
	Classname[0] = 0
	if(find_sphere_class(id,g_szNPCName,80.0,Classname,1))
	{
		new const Ent = Classname[0];
		pev(Ent,pev_noise1,Classname,25)
		
		new ATM = (containi(Classname,g_Npcs[4]) != -1) ? 1 : 0
		if(ATM || containi(Classname,g_Npcs[1]) != -1)
		{
			CashF(id,Args,Mode,ATM);
			return PLUGIN_HANDLED
		}
	}
	client_print(id,print_chat,"[DRP] You must be facing a banker, or be at an ATM machine.");
	return PLUGIN_HANDLED
	
}
	
CashF(id,Args[],Mode,ATM = 0)
{
	new StrAmount[36],Temp[1] // StrAmount is 36 because we might check for a SteamID
	if(Mode == 3)
	{
		new plName[36]
		parse(Args,Temp,1,plName,32,StrAmount,35);
		
		new Amount,Bank = DRP_GetUserBank(id);
		if(containi(StrAmount,"all") != -1)
			Amount = Bank
		else
			Amount = str_to_num(StrAmount);
		
		if(Amount > Bank)
		{
			client_print(id,print_chat,"[DRP] You do not have enough money in your bank account.");
			return PLUGIN_HANDLED
		}
		if(Amount < 1)
		{
			client_print(id,print_chat,"[DRP] Invalid amount; please enter a whole number.");
			return PLUGIN_HANDLED
		}
		
		// We typed an AuthID
		if(containi(plName,"STEAM_0:") != -1)
		{
			new Data[3]
			Data[0] = id
			Data[1] = Amount
			Data[2] = -1
			
			format(g_Menu,sizeof g_Menu - 1,"SELECT `SteamID`,`PlayerName` FROM `Users` WHERE `SteamID`='%s'",plName);
			SQL_ThreadQuery(g_SqlHandle,"TransferMoneyToSteamID",g_Menu,Data,3);
			
			return PLUGIN_HANDLED
		}
		
		// Offline Transfer v0.1
		if(containi(plName,"offline") != -1)
		{
			new Data[3]
			Data[0] = id
			Data[1] = Amount
			Data[2] = 0
			
			format(g_Menu,sizeof g_Menu - 1,"SELECT `SteamID`,`PlayerName` FROM `Users`");
			SQL_ThreadQuery(g_SqlHandle,"TransferMoneyToSteamID",g_Menu,Data,3);
			
			return PLUGIN_HANDLED
		}
		
		new Target = cmd_target(id,plName,0);
		if(!Target)
		{
			client_print(id,print_chat,"[DRP] Could not find a user matching your input.");
			return PLUGIN_HANDLED
		}
		
		if(ATM)
		{
			new Params[3]
			Params[0] = id
			Params[1] = Target
			Params[2] = Amount
			
			set_task(5.0,"SendMoney",_,Params,3);
			
			emit_sound(id,CHAN_ITEM,"ambience/computalk2.wav",0.5,ATTN_NORM,0,PITCH_NORM);
			client_print(id,print_chat,"[DRP] [ATM MACHINE] Please hold as your money is transferred.");
			
			return PLUGIN_HANDLED
		}
		
		DRP_SetUserBank(Target,DRP_GetUserBank(Target) + Amount);
		DRP_SetUserBank(id,Bank - Amount);
		
		get_user_name(Target,plName,32);
		client_print(id,print_chat,"[DRP] You have transferred %s $%d.",plName,Amount);
		get_user_name(id,plName,32);
		
		client_print(Target,print_chat,"[DRP] You have been transferred $%d by %s.",Amount,plName);
		client_print(id,print_chat,"[DRP] NOTE: You can now transfer money to offline players. /transfer offline");
		
		return PLUGIN_HANDLED
	}
	
	remove_quotes(Args);
	parse(Args,Temp,1,StrAmount,11);
	
	new Bank = DRP_GetUserBank(id),Wallet = DRP_GetUserWallet(id),Amount,Cash = Mode == 1 ? Bank : Wallet
	new All = (containi(StrAmount,"all") != -1) ? 1 : 0
	if(All)
		Amount = Mode == 1 ? Bank : Wallet
	else
		Amount = str_to_num(StrAmount);
	
	if(Amount > Cash)
	{
		client_print(id,print_chat,"[DRP] You do not have enough money in your %s.",Mode == 2 ? "wallet" : "bank account");
		return PLUGIN_HANDLED
	}
	if(Amount < 1)
	{
		client_print(id,print_chat,"[DRP] Invalid amount (or no cash was found in your %s); please enter a whole number.",Mode == 2 ? "wallet" : "bank account");
		return PLUGIN_HANDLED
	}
	
	DRP_SetUserWallet(id,Mode == 1 ? Wallet + Amount : Wallet - Amount);
	DRP_SetUserBank(id,Mode == 1 ? Bank - Amount : Bank + Amount);
	
	client_print(id,print_chat,"[DRP] You have %s $%d %s your bank account.",Mode == 1 ? "withdrawn" : "deposited",Amount,Mode == 1 ? "from" : "into");
	
	if(!All)
		client_print(id,print_chat,"[DRP] NOTE: You can quickly use ^"/withdraw all^" or ^"/deposit all^"");
	
	return PLUGIN_HANDLED
}
public SendMoney(Params[3])
{
	new const id = Params[0],Target = Params[1],Amount = Params[2]
	new plName[33]
	
	DRP_SetUserBank(Target,DRP_GetUserBank(Target) + Amount);
	DRP_SetUserBank(id,DRP_GetUserBank(id) - Amount);
	
	get_user_name(Target,plName,32);
	client_print(id,print_chat,"[DRP] You have transferred %s $%d.",plName,Amount);
	get_user_name(id,plName,32);
	client_print(Target,print_chat,"[DRP] You have been transferred $%d by %s.",Amount,plName);
	
	client_print(id,print_chat,"[DRP] [ATM MACHINE] Transfer Successful.");
}
public CmdPda(id)
{
	if(!DRP_GetUserItemNum(id,g_itemPda))
	{
		client_print(id,print_console,"[DRP] You must own the ItemPDA to use this command.");
		return PLUGIN_HANDLED
	}
	
	new Arg[33],ItemID,Results[2],Num
	read_argv(1,Arg,32);
	
	is_str_num(Arg) ? 
		(ItemID = str_to_num(Arg)) : (Num = DRP_FindItemID(Arg,Results,2))
	
	if(Num > 1)
	{
		client_print(id,print_console,"[DRP] Found more than one item with that name.")
		return PLUGIN_HANDLED
	}
	else if(!ItemID && !Num)
	{
		client_print(id,print_console,"[DRP] No items matching that Name/ItemID found.")
		return PLUGIN_HANDLED
	}
	
	if(!ItemID)
		ItemID = Results[0]
	
	if(!DRP_ValidItemID(ItemID))
	{
		client_print(id,print_console,"[DRP] No items matching that Name/ItemID found.")
		return PLUGIN_HANDLED
	}
	
	new Name[33],Message[128],Pos
	for(new Count,Count2;Count < g_NpcNum;Count++)
	{
		for(Count2 = 1;Count2 < g_ItemNum[Count];Count2++)
		{
			if(g_Selling[Count][Count2][ITEMID] == ItemID)
			{
				pev(g_NpcID[Count],pev_noise1,Name,32);
				Pos += formatex(Message[Pos],127 - Pos,"%d. %s^n",Count,Name);
			}
		}
	}
	client_print(id,print_console,"[DRP] An MOTD Windows has been opened that has the returned results.");
	
	Pos += formatex(Message[Pos],127 - Pos,"^nAbove is a list of NPC's that sell the item that has been searched. (%s)",Arg);
	show_motd(id,Message,"DRP");
	
	return PLUGIN_HANDLED
}
public CmdSetNPCItems(id)
{
	if(read_argc() != 4)
	{
		client_print(id,print_console,"[DRP] Usage: DRP_SetNPCItem <ItemName> <Num> <Price>");
		return PLUGIN_HANDLED
	}
	
	new Index,Body,Classname[26]
	get_user_aiming(id,Index,Body,200);
	
	if(Index)
	{
		pev(Index,pev_classname,Classname,25);
		if(!equali(Classname,g_szNPCName))
		{
			client_print(id,print_console,"[DRP] Unable to locate an NPC");
			return PLUGIN_HANDLED
		}
	}
	else
	{
		new EntList[2]
		if(find_sphere_class(id,g_szNPCName,80.0,EntList,1))
		{
			Index = EntList[0]
		}
		else
		{
			client_print(id,print_console,"[DRP] Unable to locate an NPC");
			return PLUGIN_HANDLED
		}
	}
	
	new const Property = DRP_GetNpcProperty(Index),NPC = FindNPC(Index);
	if(Property == -1)
	{
		client_print(id,print_console,"[DRP] This NPC is not linked to a property.");
		return PLUGIN_HANDLED
	}
	
	new Flag
	new const Access = DRP_PropertyGetAccess(Property),UserAccess = DRP_GetUserAccess(id);
	
	// Check for owner first - incase we have access and we own it
	if(id == DRP_PropertyGetOwner(Property))
		Flag = 2
	else if(Access & UserAccess)
		Flag = 1
	else
	{
		client_print(id,print_console,"[DRP] You do not have access to this NPC.");
		return PLUGIN_HANDLED
	}
	
	new Arg[12],ItemID,Results[3]
	read_argv(1,Classname,25);
	
	new Num = DRP_FindItemID(Classname,Results,2);
	
	if(Num > 1)
	{
		client_print(id,print_console,"[DRP] Found more than one item matching your input.");
		return PLUGIN_HANDLED
	}
	
	ItemID = Results[0]
	if(!DRP_ValidItemID(ItemID))
	{
		client_print(id,print_console,"[DRP] Invalid ItemID");
		return PLUGIN_HANDLED
	}
	
	read_argv(2,Arg,11);
	Num = DRP_GetUserItemNum(id,ItemID)
	new ItemNum = str_to_num(Arg);
	
	if(!Num || ItemNum < 0 || (ItemNum > Num))
	{
		client_print(id,print_chat,"[DRP] Invalid Amount (You do not have enough/or do not own this item)");
		return PLUGIN_HANDLED
	}
	
	new ItemName[33],Found = 0
	DRP_GetItemName(ItemID,Classname,25);
	
	for(new Count = 1;Count < g_ItemNum[NPC];Count++)
	{
		DRP_GetItemName(g_Selling[NPC][Count][ITEMID],ItemName,32);
		if(equali(ItemName,Classname))
		{
			Found = Count
			break;
		}
	}
	
	// Item not found and we are not an owner
	if(!Found && Flag == 1)
	{
		client_print(id,print_console,"[DRP] Unable to find ^"%s^" inside the NPC.",Classname);
		return PLUGIN_HANDLED
	}
	
	read_argv(3,Arg,11);
	new Price = str_to_num(Arg)
	

	
	return PLUGIN_HANDLED
}
/*==================================================================================================================================================*/
public _ItemLook(id)
	return client_print(id,print_chat,"[DRP] The PDA is used via your console. Please use the command ^"drp_itempda <itemid/itemname>^"");
public _License(id,ItemID)
	return client_print(id,print_chat,"[DRP] This License allows you to buy %s weapons.",ItemID == g_ItemLicenses[0] ? "Restricted" : "Permitted ");
/*==================================================================================================================================================*/
CreateNPC(const Name[],const Handler[],Float:Origin[3],Float:Angle,const Model[],Zone,const Property[],const Body,SkipTrace,const Animation = 0,Plugin = 0)
{
	new Ent = engfunc(EngFunc_CreateNamedEntity,engfunc(EngFunc_AllocString,"info_target"));
	if(!pev_valid(Ent))
		return DRP_ThrowError(1,"Unable to create NPC (Ent Returned: %d)",Ent);
	
	engfunc(EngFunc_SetModel,Ent,Zone ? g_FillModel : Model);
	engfunc(EngFunc_SetOrigin,Ent,Origin);
	engfunc(EngFunc_SetSize,Ent,Float:{-16.0,-16.0,-36.0},Float:{16.0,16.0,36.0});
	
	set_pev(Ent,pev_classname,g_szNPCName);
	set_pev(Ent,pev_solid,Zone ? SOLID_TRIGGER : SOLID_BBOX);
	
	set_pev(Ent,pev_controller_0,125);
	set_pev(Ent,pev_controller_1,125);
	set_pev(Ent,pev_controller_2,125);
	set_pev(Ent,pev_controller_3,125);
	
	set_pev(Ent,pev_framerate,1.0);
	set_pev(Ent,pev_sequence,Animation ? Animation : 1);
	
	if(Body)
		set_pev(Ent,pev_body,Body);
	if(Zone)
		set_pev(Ent,pev_effects,pev(Ent,pev_effects) | EF_NODRAW);
	
	Origin[0] = 0.0
	Origin[1] = Angle - 180
	Origin[2] = 0.0
	
	set_pev(Ent,pev_angles,Origin);
	
	if(SkipTrace)
		set_pev(Ent,pev_iuser2,SkipTrace);
	
	set_pev(Ent,pev_iuser3,Plugin ? Plugin : g_Plugin);
	
	set_pev(Ent,pev_noise,Handler);
	set_pev(Ent,pev_noise1,Name);
	set_pev(Ent,pev_noise2,Property);
	
	engfunc(EngFunc_DropToFloor,Ent);
	
	return Ent
}
FindNPC(const Ent)
{
	for(new Count;Count < MAX_NPC;Count++)
		if(Ent == g_NpcID[Count])
			return Count
		
	return FAILED
}

// We do query everytime we update the npc item list
// should we do this, or just query on "DRP_CoreSave" ?
// --
UpdateNPCItems(const Npc,const ItemID,const Amount,Price = -1,Type,DeleteRow=0)
{
	if(!Npc || !ItemID || !g_NPCExternalName[Npc][0])
		return FAILED
	
	new Found = 0
	for(new Count;Count < g_ItemNum[Npc];Count++)
	{
		if(g_Selling[Npc][Count][ITEMID] == ItemID)
		{
			Found = Count; 
			break;
		}
	}
	
	if(!Found)
	{	
		g_Selling[Npc][g_ItemNum[Npc]][ITEMID] = ItemID
		g_Selling[Npc][g_ItemNum[Npc]][COST] = Price
		g_Selling[Npc][g_ItemNum[Npc]++][ITEM_AMOUNT] = Amount
		Found = g_ItemNum[Npc] - 1
	}
	else
	{
		switch(Type)
		{
			case NPC_SUBTRACT: g_Selling[Npc][Found][ITEM_AMOUNT] = (g_Selling[Npc][Found][ITEM_AMOUNT] - Amount)
			case NPC_ADD..NPC_SET: g_Selling[Npc][Found][ITEM_AMOUNT] += Amount
		}
	}
	
	new ItemName[64]
	DRP_GetItemName(ItemID,ItemName,63);
	
	replace_all(ItemName,63,"'","\'");
	
	// We don't actually delete the SQL Row - when the num is zero
	// because the items that are in the npc, are the only ones that can be added
	// CHANGED:
	
	if(DeleteRow)
	{
		if(g_Selling[Npc][Found][ITEM_AMOUNT] <= 0)
		{
			format(g_Menu,sizeof g_Menu - 1,"DELETE FROM `NPCItems` WHERE `NPCItemName`='%s|%s'",g_NPCExternalName[Npc],ItemName);
			SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",g_Menu);
			
			// Don't allow this item to be used
			g_Selling[Npc][Found][ITEM_AMOUNT] = -1
			return SUCCEEDED
		}
	}
	
	// Query
	format(g_Menu,sizeof g_Menu - 1,"INSERT INTO `NPCItems` VALUES('%s|%s','%d','%d') ON duplicate KEY UPDATE Num='%d',Price='%d'",g_NPCExternalName[Npc],ItemName,Amount,Price ? Price : g_Selling[Npc][Found][COST],g_Selling[Npc][Found][ITEM_AMOUNT],Price);
	SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",g_Menu);
	
	return SUCCEEDED
}

CreateMenus()
{
	g_ShopOwnerMenu = menu_create("NPC Owner Control","ShopOwnerHandle");
	menu_additem(g_ShopOwnerMenu,"Control Item Help");
	menu_additem(g_ShopOwnerMenu,"Shop");
	
	g_StorageMenu = menu_create("Storage Unit","StorageHandleMenu");
	menu_additem(g_StorageMenu,"View Items");
	menu_additem(g_StorageMenu,"Deposit Items");
	menu_additem(g_StorageMenu,"Help");
	menu_addtext(g_StorageMenu,"^nNOTE:^nPlease check the help",0);
	
	g_ATMMenu = menu_create("ATM Machine","ATMMenuHandle");
	menu_additem(g_ATMMenu,"Withdraw");
	menu_additem(g_ATMMenu,"Deposit");
	
	g_ATMUseMenu = menu_create("","ATMUseMenuHandle");
	menu_additem(g_ATMUseMenu,"$10");
	menu_additem(g_ATMUseMenu,"$20");
	menu_additem(g_ATMUseMenu,"$50");
	menu_additem(g_ATMUseMenu,"$100");
	menu_additem(g_ATMUseMenu,"$200");
	menu_additem(g_ATMUseMenu,"$500");
	menu_additem(g_ATMUseMenu,"$1000");
	
	g_GunShopMenu = menu_create("Gunshop Menu","GunshopMenuHandle");
	menu_additem(g_GunShopMenu,"Permitted Weapons");
	menu_additem(g_GunShopMenu,"Restricted Weapons");
	
	formatex(g_Menu,255,"Buy Ammo ($%d)",get_pcvar_num(p_FillCost))
	menu_additem(g_GunShopMenu,g_Menu);
	
	menu_additem(g_GunShopMenu,"Buy Misc Items");
	menu_addtext(g_GunShopMenu,"^nNOTE:^nPlease keep up-to-date with the^ncurrent laws regarding weapons");
	
	g_BankMenu = menu_create("Bank","BankMenuHandle");
	menu_additem(g_BankMenu,"Withdraw/Deposit/Transfer");
	
	formatex(g_Menu,255,"Buy ATM/Debit Card ($%d)",get_pcvar_num(p_ATMCardPrice));
	menu_additem(g_BankMenu,g_Menu);
	
	menu_addblank(g_BankMenu,0);
	menu_additem(g_BankMenu,"Apply for a Loan");
	menu_additem(g_BankMenu,"Apply for a Credit Card");
	
	menu_addblank(g_BankMenu,0);
	menu_additem(g_BankMenu,"Help");
}

// ---
// SQL
public FetchNPCItems(FailState,Handle:Query,const Error[],Errcode,const Data[],DataSize) 
{
	if(FailState != TQUERY_SUCCESS || Errcode)
		return DRP_ThrowError(0,"SQL Error (Error: %s)",0,Error ? Error : "UNKNOWN");
		
	new const id = Data[0]
	new Temp[2][36],ItemID
	new Flag
	
	if(equali(g_RobProfile[id],"storage"))
		Flag = 1
	
	while(SQL_MoreResults(Query))
	{
		SQL_ReadResult(Query,0,g_Menu,255);
		strtok(g_Menu,Temp[0],35,Temp[1],35,'|',1);
		
		ItemID = DRP_FindItemID2(Temp[1]);
		
		if(!ItemID)
		{
			SQL_NextRow(Query);
			continue
		}
		
		g_Selling[id][g_ItemNum[id]][ITEMID] = ItemID
		g_Selling[id][g_ItemNum[id]][COST] = SQL_ReadResult(Query,2);
		g_Selling[id][g_ItemNum[id]++][ITEM_AMOUNT] = SQL_ReadResult(Query,1);
		
		if(Flag)
			(SQL_ReadResult(Query,2) > 0) ? copy(g_RobProfile[id],32,"1") : copy(g_RobProfile[id],32,"");
		
		SQL_NextRow(Query);
	}
	return PLUGIN_CONTINUE
}

// TODO:
// Finish(??)
public TransferMoneyToSteamID(FailState,Handle:Query,const Error[],Errcode,const Data[],DataSize)
{
	if(FailState != TQUERY_SUCCESS || Errcode)
		return DRP_ThrowError(0,"SQL Error (Error: %s)",0,Error ? Error : "UNKNOWN");
	
	new const id = Data[0],Amount = Data[1]
	new Num = SQL_NumResults(Query);
	if(!Num && Data[2] == -1)
	{
		client_print(id,print_chat,"[DRP] Unable to find this SteamID. Just type /transfer offline - to view a list.");
		return PLUGIN_CONTINUE
	}
	else if(!Num)
	{
		client_print(id,print_chat,"[DRP] There was a problem transfering. Please contact an administrator.");
		return PLUGIN_CONTINUE
	}
	
	new AuthID[36],plName[33],MenuText[156]
	if(Data[2] == -1)
	{
		SQL_ReadResult(Query,1,plName,32);
		SQL_ReadResult(Query,0,AuthID,35);
		
		new Target = cmd_target(id,AuthID,CMDTARGET_ALLOW_SELF);
		if(Target)
		{
			client_print(id,print_chat,"[DRP] This user is currently online. Offline transfer unavailable.");
			return PLUGIN_HANDLED
		}
		
		client_print(id,print_chat,"[DRP] Transfered (OFFLINE) $%d to SteamID: %s (Name: %s)",Amount,AuthID,plName[0] ? plName : "UNKNOWN");
		
		format(g_Menu,255,"UPDATE `Users` SET `BankMoney`='%d' WHERE `SteamID`='%s'",Amount,AuthID);
		SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",g_Menu);
		
		return PLUGIN_HANDLED
	}
	
	formatex(MenuText,155,"Transfer Amount: $%d^nPlease select a player:",Amount);
	new Menu = menu_create(MenuText,"_OfflineTransferHandle"),Info[64]
	
	while(SQL_MoreResults(Query))
	{
		SQL_ReadResult(Query,0,AuthID,35);
		SQL_ReadResult(Query,1,plName,32);
		
		if(containi(AuthID,"STEAM_0:") == -1)
		{
			SQL_NextRow(Query);
			continue
		}
		
		formatex(MenuText,127,"%s - %s",AuthID,plName);
		formatex(Info,32,"%s %d",AuthID,Amount);
		
		menu_additem(Menu,MenuText,Info);
		SQL_NextRow(Query);
	}
	
	menu_display(id,Menu);
	return PLUGIN_CONTINUE
}

public _OfflineTransferHandle(id,Menu,Item)
{
	if(Item == MENU_EXIT)
	{
		menu_destroy(Menu);
		return PLUGIN_HANDLED
	}
	
	new Info[64],szAmount[12],Temp
	menu_item_getinfo(Menu,Item,Temp,Info,63,_,_,Temp);
	menu_destroy(Menu);
	
	parse(Info,Info,63,szAmount,11);
	
	if(containi(Info,"STEAM_0:") == -1)
	{
		client_print(id,print_chat,"[DRP] Invalid SteamID. Unable to complete transfer.");
		return PLUGIN_HANDLED
	}
	
	new Target = cmd_target(id,Info,CMDTARGET_ALLOW_SELF);
	if(Target)
	{
		client_print(id,print_chat,"[DRP] This user is currently online. Offline transfer unavailable.");
		return PLUGIN_HANDLED
	}
	
	new Amount = str_to_num(szAmount);
	client_print(id,print_chat,"[DRP] Transfered (OFFLINE) $%s to %s",szAmount,Info);
	
	format(g_Menu,255,"UPDATE `Users` SET `BankMoney`='%d' WHERE `SteamID`='%s'",Amount,Info);
	SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",g_Menu);
	
	return PLUGIN_HANDLED
}

public IgnoreHandle(FailState,Handle:Query,const Error[],Errcode,const Data[],DataSize)
	if(FailState != TQUERY_SUCCESS || Errcode)
		DRP_ThrowError(0,"SQL Error (Error: %s)",Error[0] ? Error : "UNKNOWN");
	
public plugin_end()
{
	menu_destroy(g_ShopOwnerMenu);
	menu_destroy(g_StorageMenu);
}