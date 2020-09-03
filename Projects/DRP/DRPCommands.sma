/* 
* DRPCommands.sma
* -------------------------
* Author(s):
* Drak - Main Author
*/

#include <amxmodx>
#include <amxmisc>
#include <fakemeta>

#include <drp/drp_core>
#include <drp/drp_chat>
#include <sqlx>

#define MAX_MONEY_DROP 5

new const PLUGIN[] = "DRP - Commands"
new const AUTHOR[] = "Drak"
new const VERSION[] = "0.1a"

new g_Finer[33]
new g_Employer[33]
new g_JobID[33]
new g_Amount[33]

// PCVars
new p_Log
new p_MaxEmploys

// Job ID's
new g_Unemployed

// Menus
new const g_FineMenu[] = "DRP_FineMenu"
new const g_EmployMenu[] = "DRP_EmployMenu"

new g_Menu[256]
new g_PlayerLogs[128]
new g_MoneyDropAmt[33]

// Shove
new g_ShoveAmount[33]
new Float:g_ShoveTime[33]

// Because morons can't use "/stand"
new g_UserSitting[33]

public plugin_init()
{
	register_plugin(PLUGIN,VERSION,AUTHOR);
	
	DRP_AddChat(_,"CmdSay");
	
	// Player Commands
	DRP_AddCommand("say /unemployme","Allows you to un-employ yourself.");
	DRP_AddCommand("say /drop","<amount> - drops a ^"block^" of cash onto the ground.");
	DRP_AddCommand("say /sell","<price> - set property for sale for price (0 - Stop Selling)");
	DRP_AddCommand("say /sellitem","<itemid/name> <price> - sells an item to the player you're looking at");
	DRP_AddCommand("say /addaccess","<user> - gives user access to the door you're looking at");
	DRP_AddCommand("say /delaccess","<user/steamid> - removes user's access from the door you're looking at");
	DRP_AddCommand("say /pmessage","<message> - sets the property's custom message.");
	DRP_AddCommand("say /powner","<owername> - changes the owner name of the property");
	DRP_AddCommand("say /pname","<property name> - allows you to set the property's name");
	DRP_AddCommand("say /hiredplayers","- display's all the current players you have hired. and allows you to fire them");
	DRP_AddCommand("say /givemoney","<amount> - gives money to a user from wallet");
	DRP_AddCommand("say /stopsound","- stops all sounds currently playing (usefull for bugs)");
	DRP_AddCommand("say /item","<itemid/name> - uses an item. useful for binds");
	
	// Admin Commands
	DRP_RegisterCmd("DRP_CreateMoney","CmdChangeMoney","(ADMIN) <user> <money> - adds money to the user's wallet");
	DRP_RegisterCmd("DRP_RemoveMoney","CmdChangeMoney","(ADMIN) <user> <money> - removes money fron the user's wallet");
	DRP_RegisterCmd("DRP_SetMoney","CmdChangeMoney","(ADMIN) <user> <money> - sets user's wallet money");
	
	DRP_RegisterCmd("DRP_CreateBank","CmdChangeBank","(ADMIN) <user> <money> - adds money to user's bank");
	DRP_RegisterCmd("DRP_RemoveBank","CmdChangeBank","(ADMIN) <user> <money> - removes money from user's bank");
	DRP_RegisterCmd("DRP_SetBank","CmdChangeBank","(ADMIN) <user> <money> - sets user's bank money");
	
	DRP_RegisterCmd("DRP_Additems","CmdChangeItems","(ADMIN) <user> <item> <amount> - gives items to user");
	DRP_RegisterCmd("DRP_Removeitems","CmdChangeItems","(ADMIN) <user> <item> <amount> - takes items from user");
	DRP_RegisterCmd("DRP_Setitems","CmdChangeItems","(ADMIN) <user> <item> <amount> - sets user items");
	
	DRP_RegisterCmd("DRP_AddJob","CmdAddJob","(ADMIN) <name> <salary> <access> - adds job");
	DRP_RegisterCmd("DRP_SetHunger","CmdSetHunger","(ADMIN) <user> <hunger amount> - sets a users hunger percent");
	
	DRP_RegisterCmd("DRP_DeleteJob","CmdDeleteJob","(ADMIN) <name> - deletes a job");
	DRP_RegisterCmd("DRP_DeleteDoor","CmdDeleteDoor","(ADMIN) - deletes door being looked at");
	DRP_RegisterCmd("DRP_DeleteProperty","CmdDeleteProperty","(ADMIN) - deletes property being looked at");
	
	DRP_RegisterCmd("DRP_SetJob","CmdSetJob","(ADMIN) <user> <jobid/jobname> - sets the user's job");
	DRP_RegisterCmd("DRP_Employ","CmdEmploy","(ADMIN) <user> <jobid/jobname> - offers a job to a user");
	DRP_RegisterCmd("DRP_Fire","CmdFire","(ADMIN) <user> - set's a user back to unemployed");
	DRP_RegisterCmd("DRP_SetJobRight","CmdSetJobRight","(ADMIN) <name> <rights> - sets user's job rights");
	DRP_RegisterCmd("DRP_SetAccess","CmdSetAccess","(ADMIN) <user> <access> <add 1/0> - sets (adds) user's access");
	
	// Server (Console) Set Access Command
	register_srvcmd("DRP_SetAccess","CmdSetAccess",ADMIN_BAN);
	register_srvcmd("DRP_Employ","CmdEmploy");
	
	DRP_RegisterCmd("DRP_AddProperty","CmdAddProperty","(ADMIN) <internalname> <externalname> <owner> <authid> <price> <access> <profit> <locked>");
	DRP_RegisterCmd("DRP_AddDoor","CmdAddDoor","(ADMIN) <internalname> - hooks a door to a property");
	
	// Menus
	register_menucmd(register_menuid(g_FineMenu),MENU_KEY_1|MENU_KEY_2,"_FineHandle");
	register_menucmd(register_menuid(g_EmployMenu),MENU_KEY_1|MENU_KEY_2,"_EmployHandle");
	
	DRP_GetConfigsDir(g_PlayerLogs,127);
	add(g_PlayerLogs,127,"/PlayerCommands.ini");
	
	// Events
	DRP_RegisterEvent("Player_PickupCash","_EventCashPickup");
}

// Below is temporary. I used this to check for abusers.
// Main logging is done with the "DRP_Log" native
public client_command(id)
{
	static Command[32]
	read_argv(0,Command,31);
	
	if(!Command[0])
		return PLUGIN_CONTINUE
	
	if(containi(Command,"DRP_") == -1)
		return PLUGIN_CONTINUE
	
	new Message[256]
	new plName[33],AuthID[36]
	
	get_user_name(id,plName,32);
	get_user_authid(id,AuthID,35);
	
	formatex(Message,255,"Name: %s - AuthID: %s - IsDRPAdmin: %s - Command: %s",plName,AuthID,DRP_IsAdmin(id) ? "Yes" : "No",Command);
	log_to_file(g_PlayerLogs,Message);
	
	return PLUGIN_CONTINUE
}

public client_disconnect(id)
{
	g_ShoveAmount[id] = 0
	g_ShoveTime[id] = 0.0
	g_UserSitting[id] = 0
	
	if(!g_MoneyDropAmt[id])
		return
	
	g_MoneyDropAmt[id] = 0
	
	// Delete all of our drop cash
	// if it's kept, they can reconnect and drop more (allowing them to crash the server)
	// if we don't reset 'g_moneydropamt' a new player (with the same id) won't be able to drop.
	
	new Ent
	while((Ent = engfunc(EngFunc_FindEntityByString,Ent,"classname",g_szMoneyPile)) != 0)
	{
		if(pev(Ent,pev_owner) == id)
			engfunc(EngFunc_RemoveEntity,Ent);
	}
}

public DRP_Error(const Reason[])
	pause("d");

public DRP_Init() 
{
	// Cvarrs
	p_Log = register_cvar("DRP_LogCommands","1");
	p_MaxEmploys = register_cvar("DRP_MaxPlayerEmploys","1");
}

public DRP_JobsInit()
{
	new Results[1]
	DRP_FindJobID("Unemployed",Results,1);
	
	if(DRP_ValidJobID(Results[0]))
		g_Unemployed = Results[0]
	else
		DRP_ThrowError(1,"Unable to find ^"Unemployed^" JobID (Results returned: %d)",Results[0]);
}
public _EventCashPickup(const Name[],const Data[],const Len)
{
	// 1st Data[0] = Owner of the Money DROP
	// 2nd Data[1] = User who picked it up
	new const id = Data[0]
	if(g_MoneyDropAmt[id] >= 1)
		g_MoneyDropAmt[id]--;
}
/*=======================================================================================================================================*/
public CmdSay(id,const Args[])
{
	// All commands start with a slash
	// don't check, if we don't have a slash
	if(Args[0] != '/')
		return PLUGIN_CONTINUE
	
	if(equali(Args,"/pass ",6))
	{
		new const Len = strlen(Args) - 6
		if(Len > 32)
		{
			client_print(id,print_chat,"[DRP] Max password length is 32 (put 0 for no password)");
			return PLUGIN_HANDLED
		}
		
		new szPassword[33]
		parse(Args,Args,1,szPassword,32);
		
		if(containi(szPassword,"-") != -1)
		{
			client_print(id,print_chat,"[DRP] Your password must not contain the symbol: ^"-^"");
			return PLUGIN_HANDLED
		}
		
		
		DRP_SetUserPass(id,szPassword[0] == '0' ? DEFAULT_SET_PASS : szPassword);
		
		if(szPassword[0] == '0')
		{
			client_print(id,print_chat,"[DRP] You decided not to set a password. You can change it at anytime.");
			return PLUGIN_HANDLED
		}
		
		client_print(id,print_chat,"[DRP] You have set your password to: ^"%s^" you can change this at anytime.",szPassword);
		return PLUGIN_HANDLED
	}
	
	else if(equali(Args,"/sell ",6))
	{
		new Index,Body
		get_user_aiming(id,Index,Body,200);
		
		if(!Index)
		{
			client_print(id,print_chat,"[DRP] You are not looking at a property.");
			return PLUGIN_HANDLED
		}
		
		new TargetName[33]
		pev(Index,pev_targetname,TargetName,32);
		
		if(!DRP_ValidDoorName(TargetName))
		{
			client_print(id,print_chat,"[DRP] You are not looking at a property.");
			return PLUGIN_HANDLED
		}
		
		new const Property = DRP_PropertyMatch(TargetName,Index);
		if(!Property)
			return PLUGIN_HANDLED
		
		if(DRP_PropertyGetOwner(Property) != id)
		{
			client_print(id,print_chat,"[DRP] You do not own this property.");
			return PLUGIN_HANDLED
		}
		
		parse(Args,Args,1,TargetName,32);
		new const Price = str_to_num(TargetName);
		
		if(Price < 0)
		{
			client_print(id,print_chat,"[DRP] You cannot set a property's price to a negative value.");
			return PLUGIN_HANDLED
		}
		
		if(!DRP_PropertySetPrice(Property,Price))
			return PLUGIN_HANDLED
		
		if(Price)
			client_print(id,print_chat,"[DRP] You have put this property for sale at $%d.",Price);
		else
			client_print(id,print_chat,"[DRP] This property is no longer for sale.")
		
		return PLUGIN_HANDLED
	}
	else if(equali(Args,"/sellitem ",10) || equali(Args,"/dealitem ",10))
	{
		new Index,Body
		get_user_aiming(id,Index,Body,200);
		
		if(!Index || !is_user_alive(Index))
		{
			client_print(id,print_chat,"[DRP] You must be facing a player. Usage: /sellitem (/dealitem) <itemname> <amount>")
			return PLUGIN_HANDLED
		}
		
		new Item[33],StrNum[12]
		parse(Args,Args,1,Item,32,StrNum,11);
		
		new const Price = str_to_num(StrNum);
		
		if(Price < 1)
		{
			client_print(id,print_chat,"[DRP] Invalid price amount. Usage: /sellitem (/dealitem) <itemname> <amount>");
			return PLUGIN_HANDLED
		}
		
		new Results[2],Name[33],Num = DRP_FindItemID(Item,Results,2);
		get_user_name(id,Name,32);
		
		if(Num > 1)
		{
			client_print(id,print_chat,"[DRP] More than one item was found matching your input.");
			return PLUGIN_HANDLED
		}
		
		if(!DRP_ValidItemID(Results[0]))
		{
			client_print(id,print_chat,"[DRP] Unable to find Item. Please try a different name.");
			return PLUGIN_HANDLED
		}
		
		new const ItemID = Results[0]
		if(DRP_GetUserItemNum(id,ItemID) < 1)
		{
			client_print(id,print_chat,"[DRP] You do not own this item.");
			return PLUGIN_HANDLED
		}
		
		DRP_GetItemName(ItemID,Item,32);
		format(g_Menu,255,"[Selling Offer]^n^nSeller: %s^nItem: %s^nPrice: $%d",Name,Item,Price);
		
		new Menu = menu_create(g_Menu,"_SellHandle");
		formatex(Name,32,"%d %d %d",id,ItemID,Price);
		
		menu_additem(Menu,"Accept",Name);
		menu_additem(Menu,"Decline",Name);
		
		menu_display(Index,Menu);
		get_user_name(Index,Name,32);
		
		client_print(id,print_chat,"[DRP] Selling Item ^"%s^" to %s for $%d",Item,Name,Price);
		return PLUGIN_HANDLED
	}
	else if(equali(Args,"/lock"))
	{
		new Index,Body
		get_user_aiming(id,Index,Body,200);
		
		if(!Index)
		{
			client_print(id,print_chat,"[DRP] You are not looking at a property.")
			return PLUGIN_HANDLED
		}
		
		new TargetName[33]
		pev(Index,pev_targetname,TargetName,32);
		
		if(!DRP_ValidDoorName(TargetName))
		{
			client_print(id,print_chat,"[DRP] You are not looking at a property.");
			return PLUGIN_HANDLED
		}
		
		new const Property = DRP_PropertyMatch(TargetName,Index);
		if(!Property)
			return PLUGIN_HANDLED
		
		if(DRP_PropertyGetOwner(Property) != id)
		{
			client_print(id,print_chat,"[DRP] You do not own this property.");
			return PLUGIN_HANDLED
		}
		
		new Num = DRP_PropertyGetLocked(Property) ? 0 : 1
		DRP_PropertySetLocked(Property,Num);
		
		client_print(id,print_chat,"[DRP] You have %slocked the property.",Num ? "" : "un");
		
		return PLUGIN_HANDLED
	}
	else if(equali(Args,"/lockdoor",9))
	{
		new Index,Body
		get_user_aiming(id,Index,Body,200);
		
		if(!Index)
		{
			client_print(id,print_chat,"[DRP] You are not looking at a door.")
			return PLUGIN_HANDLED
		}
		
		new TargetName[33]
		pev(Index,pev_targetname,TargetName,32);
		
		if(!DRP_ValidDoorName(TargetName))
		{
			client_print(id,print_chat,"[DRP] You are not looking at a property.");
			return PLUGIN_HANDLED
		}
		
		new const Property = DRP_PropertyMatch(TargetName,Index);
		if(!Property)
			return PLUGIN_HANDLED
		
		if(DRP_PropertyGetOwner(Property) != id)
		{
			client_print(id,print_chat,"[DRP] You do not own this property.");
			return PLUGIN_HANDLED
		}
		
		new Num = DRP_PropertyDoorGetLocked(Index) ? 0 : 1
		DRP_PropertyDoorSetLocked(Index,Num);
		
		client_print(id,print_chat,"[DRP] You have %slocked the door.",Num ? "" : "un");
		
		return PLUGIN_HANDLED
	}
	else if(equali(Args,"/pmessage ",10))
	{
		new Index,Body
		get_user_aiming(id,Index,Body,200);
		
		if(!Index)
		{
			client_print(id,print_chat,"[DRP] You are not looking at a property.")
			return PLUGIN_HANDLED
		}
		
		new TargetName[33]
		pev(Index,pev_targetname,TargetName,32);
		
		if(!DRP_ValidDoorName(TargetName))
		{
			client_print(id,print_chat,"[DRP] You are not looking at a property.");
			return PLUGIN_HANDLED
		}
		
		new const Property = DRP_PropertyMatch(TargetName,Index);
		if(!Property)
			return PLUGIN_HANDLED
		
		if(DRP_PropertyGetOwner(Property) != id)
		{
			client_print(id,print_chat,"[DRP] You do not own this property.");
			return PLUGIN_HANDLED
		}
		
		parse(Args,Args,1,g_Menu,256);
		
		if(strlen(g_Menu) > 128)
		{
			client_print(id,print_chat,"[DRP] That message is to long. Max is 128 Chars.");
			return PLUGIN_HANDLED
		}
		
		DRP_PropertySetMessage(Property,g_Menu);
		client_print(id,print_chat,"[DRP] Message Set. NOTE: You must use quotes /pmessage ^"hello world^"");
		
		return PLUGIN_HANDLED
	}
	else if(equali(Args,"/powner ",8))
	{
		new Index,Body
		get_user_aiming(id,Index,Body,200);
		
		if(!Index)
		{
			client_print(id,print_chat,"[DRP] You are not looking at a property.")
			return PLUGIN_HANDLED
		}
		
		new TargetName[33]
		pev(Index,pev_targetname,TargetName,32);
		
		if(!DRP_ValidDoorName(TargetName))
		{
			client_print(id,print_chat,"[DRP] You are not looking at a property.");
			return PLUGIN_HANDLED
		}
		
		new const Property = DRP_PropertyMatch(TargetName,Index);
		if(!Property)
			return PLUGIN_HANDLED
		
		if(DRP_PropertyGetOwner(Property) != id)
		{
			client_print(id,print_chat,"[DRP] You do not own this property.");
			return PLUGIN_HANDLED
		}
		
		parse(Args,Args,1,g_Menu,256);
		
		if(strlen(g_Menu) >= 33)
		{
			client_print(id,print_chat,"[DRP] That name is to long. Max is 32 Chars.");
			return PLUGIN_HANDLED
		}
		
		DRP_PropertySetOwnerName(Property,g_Menu);
		client_print(id,print_chat,"[DRP] Owner name set. NOTE: You must use quotes /powner ^"hello world^"");
		
		return PLUGIN_HANDLED
	}
	else if(equali(Args,"/pname ",7))
	{
		new Index,Body
		get_user_aiming(id,Index,Body,200);
		
		if(!Index)
		{
			client_print(id,print_chat,"[DRP] You are not looking at a property.")
			return PLUGIN_HANDLED
		}
		
		new TargetName[33]
		pev(Index,pev_targetname,TargetName,32);
		
		if(!DRP_ValidDoorName(TargetName))
		{
			client_print(id,print_chat,"[DRP] You are not looking at a property.");
			return PLUGIN_HANDLED
		}
		
		new const Property = DRP_PropertyMatch(TargetName,Index);
		if(!Property)
			return PLUGIN_HANDLED
		
		if(DRP_PropertyGetOwner(Property) != id)
		{
			client_print(id,print_chat,"[DRP] You do not own this property.");
			return PLUGIN_HANDLED
		}
		
		parse(Args,Args,1,g_Menu,256);
		
		if(strlen(g_Menu) >= 33)
		{
			client_print(id,print_chat,"[DRP] That name is to long. Max is 32 Chars.");
			return PLUGIN_HANDLED
		}
		
		DRP_PropertySetExternalName(Property,g_Menu);
		client_print(id,print_chat,"[DRP] Property Name Set. NOTE: You must use quotes /pname ^"hello world^"");
		
		return PLUGIN_HANDLED
	}
	else if(equali(Args,"/unemployme",11) || equali(Args,"/unemploy",9))
	{
		if(DRP_GetUserJobID(id) == g_Unemployed)
		{
			client_print(id,print_chat,"[DRP] You are already unemployed.");
			return PLUGIN_HANDLED
		}
		
		DRP_SetUserJobID(id,g_Unemployed,1);
		DRP_SetUserJobRight(id,0);
		
		client_print(id,print_chat,"[DRP] You have quit your job, you are now unemployed again.");
		return PLUGIN_HANDLED
	}
	else if(equali(Args,"/givemoney",10))
	{
		new Index,Body
		get_user_aiming(id,Index,Body,100);
		
		if(!Index || !is_user_alive(Index))
		{
			client_print(id,print_chat,"[DRP] You must be looking at a player.");
			return PLUGIN_HANDLED
		}
		
		new Temp[33]
		parse(Args,Args,1,Temp,32);
		
		new const Amount = str_to_num(Temp);
		if(Amount < 1)
		{
			client_print(id,print_chat,"[DRP] You must give a valid amount of money."); 
			return PLUGIN_HANDLED
		}
		
		new const Money = DRP_GetUserWallet(id);
		if(Amount > Money)
		{
			client_print(id,print_chat,"[DRP] You do not have enough money in your wallet.");
			return PLUGIN_HANDLED
		}
		
		DRP_SetUserWallet(id,Money - Amount);
		DRP_SetUserWallet(Index,DRP_GetUserWallet(Index) + Amount);
		
		get_user_name(id,Temp,32);
		client_print(Index,print_chat,"[DRP] %s has given you $%d dollar%s.",Temp,Amount,Amount == 1 ? "" : "s");
		
		get_user_name(Index,Temp,32);
		client_print(id,print_chat,"[DRP] You have given %s $%d dollar%s.",Temp,Amount,Amount == 1 ? "" : "s");
		
		return PLUGIN_HANDLED
	}
	else if(equali(Args,"/addaccess",10))
	{
		new Index,Body
		get_user_aiming(id,Index,Body,200);
		
		if(!Index)
		{
			client_print(id,print_chat,"[DRP] You are not looking at a property.")
			return PLUGIN_HANDLED
		}
		
		new TargetName[33]
		pev(Index,pev_targetname,TargetName,32);
		
		new const Property = DRP_PropertyMatch(TargetName,Index);
		if(!Property)
		{
			client_print(id,print_chat,"[DRP] You are not looking at a property.");
			return PLUGIN_HANDLED
		}
		
		if(DRP_PropertyGetOwner(Property) != id)
		{
			client_print(id,print_chat,"[DRP] You do not own this property.");
			return PLUGIN_HANDLED
		}
		
		parse(Args,Args,1,TargetName,32);
		remove_quotes(TargetName);
		trim(TargetName);
		
		new const Target = cmd_target(id,TargetName,0);
		
		if(!is_user_connected(Target))
		{
			client_print(id,print_chat,"[DRP] Unable to find a user match.");
			return PLUGIN_HANDLED
		}
		
		if(Target == id)
		{
			client_print(id,print_chat,"[DRP] You cannot give yourself access to a property you already own.");
			return PLUGIN_HANDLED
		}
		
		DRP_GiveKey(Property,Target);
		get_user_name(Target,TargetName,32);
		
		client_print(id,print_chat,"[DRP] You have given %s access to this property.",TargetName);
		
		get_user_name(id,TargetName,32);
		client_print(Target,print_chat,"[DRP] You have been given access to %s's property.",TargetName);
		
		return PLUGIN_HANDLED
	}
	else if(equali(Args,"/delaccess",10))
	{
		new Index,Body
		get_user_aiming(id,Index,Body,200);
		
		if(!Index)
		{
			client_print(id,print_chat,"[DRP] You are not looking at a property.")
			return PLUGIN_HANDLED
		}
		
		new TargetName[36]
		pev(Index,pev_targetname,TargetName,35);
		
		new const Property = DRP_PropertyMatch(TargetName,Index);
		if(!Property)
		{
			client_print(id,print_chat,"[DRP] You are not looking at a property.");
			return PLUGIN_HANDLED
		}
		
		if(DRP_PropertyGetOwner(Property) != id)
		{
			client_print(id,print_chat,"[DRP] You do not own this property.");
			return PLUGIN_HANDLED
		}
		
		parse(Args,Args,1,TargetName,35);
		remove_quotes(TargetName);
		trim(TargetName);
		
		if(containi(TargetName,"STEAM_0:") != -1)
		{
			client_print(id,print_chat,"[DRP] Access removed from SteamID: %s",TargetName);
			return DRP_PropertyRemoveAccess(Property,TargetName);
		}
		
		new const Target = cmd_target(id,TargetName,0);
		
		if(!is_user_connected(Target))
		{
			client_print(id,print_chat,"[DRP] Unable to find a user match.");
			return PLUGIN_HANDLED
		}
		
		if(Target == id)
		{
			client_print(id,print_chat,"[DRP] You cannot take away access from yourself to a property you already own.")
			return PLUGIN_HANDLED
		}
		
		DRP_TakeKey(Property,Target);
		get_user_name(Target,TargetName,32);
		
		client_print(id,print_chat,"[DRP] You have revoked %s's access to this property.",TargetName);
		client_print(id,print_chat,"[DRP] NOTE: You can also remove via SteamID (For offline players) /delaccess ^"STEAM_ID_HERE^"");
		
		return PLUGIN_HANDLED
	}
	else if(equali(Args,"/fine",5))
	{
		if(!DRP_IsCop(id))
		{
			client_print(id,print_chat,"[DRP] You are not part of the police force.");
			return PLUGIN_HANDLED
		}
		
		new Arg[33],Amount,Index,Body
		get_user_aiming(id,Index,Body,200);
		
		if(!Index || !is_user_alive(Index))
		{
			client_print(id,print_chat,"[DRP] You are not looking at a valid player.");
			return PLUGIN_HANDLED
		}
		
		parse(Args,Args,1,Arg,32);
		Amount = str_to_num(Arg);
		
		if(Amount < 1)
		{
			client_print(id,print_chat,"[DRP] You must fine a valid amount of money.")
			return PLUGIN_HANDLED
		}
		
		if(Amount > DRP_GetUserBank(Index) + DRP_GetUserWallet(Index))
		{
			client_print(id,print_chat,"[DRP] That user does not have enough money.");
			return PLUGIN_HANDLED
		}
		
		g_Finer[Index] = id
		g_Amount[Index] = Amount
		
		get_user_name(id,Arg,32);
		
		format(g_Menu,255,"Fine Order^n^nAmount: $%d^nIssuer: %s^n^n1. Pay^n2. Refuse",Amount,Arg);
		show_menu(Index,(1<<0|1<<1),g_Menu,-1,g_FineMenu);
		
		get_user_name(Index,Arg,32);
		client_print(id,print_chat,"[DRP] You have sent a fine order to %s",Arg);
		
		return PLUGIN_HANDLED
	}
	
	// TODO: Not sure what this can do
	else if(equali(Args,"/offduty",8))
	{
		if(!DRP_IsCop(id))
		{
			client_print(id,print_chat,"[DRP] You are not part of the police force.");
			return PLUGIN_HANDLED
		}
		client_print(id,print_chat,"[DRP] Function not implemented. Suggest what this could do: http://drp.hopto.org");
		return PLUGIN_HANDLED
	}
	// END
	
	else if(equali(Args,"/drop ",6))
	{
		if(g_MoneyDropAmt[id] > MAX_MONEY_DROP)
		{
			client_print(id,print_chat,"[DRP] You cannot drop more than %d ^"blocks^" of cash.",MAX_MONEY_DROP);
			return PLUGIN_HANDLED
		}
		new StrAmount[12],Amount
		parse(Args,Args,1,StrAmount,11);
		
		Amount = str_to_num(StrAmount);
		
		if(Amount < 1)
		{
			client_print(id,print_chat,"[DRP] Usage: /drop <#amount>"); 
			return PLUGIN_HANDLED
		}
		
		new const Money = DRP_GetUserWallet(id);
		if(Amount > Money)
		{
			client_print(id,print_chat,"[DRP] You do not have enough money in your wallet.");
			return PLUGIN_HANDLED
		}
		DRP_SetUserWallet(id,Money - Amount);
		
		new Float:Origin[3]
		pev(id,pev_origin,Origin);
		
		DRP_DropCash(Amount,Origin,id);
		client_print(id,print_chat,"[DRP] You have dropped $%d dollar%s.",Amount,Amount == 1 ? "" : "s");
		
		g_MoneyDropAmt[id]++
		return PLUGIN_HANDLED
	}
	
	else if(equali(Args,"/item",5))
	{
		new ItemName[33]
		parse(Args,Args,1,ItemName,32);
		
		new Results[2],Num = DRP_FindItemID(ItemName,Results,2);
		
		switch(Num)
		{
			case 0: client_print(id,print_chat,"[DRP] Item ^"%s^" could not be found.",ItemName);
			case 1:
			{
				new ItemID = Results[0]
				DRP_GetItemName(ItemID,ItemName,32);
				
				if(DRP_GetUserItemNum(id,ItemID))
				{
					DRP_ForceUseItem(id,ItemID,1);
					client_print(id,print_chat,"[DRP] You have used one ^"%s^"",ItemName);
				}
				else
					client_print(id,print_chat,"[DRP] You do not have any of ^"%s^" in your inventory.",ItemName);
			}
			default: client_print(id,print_chat,"[DRP] Found more than one item matching your input.");
		}
		return PLUGIN_HANDLED
	}
	
	// --
	else if(equali(Args,"/shove",6))
	{
		new tEnt,Body
		get_user_aiming(id,tEnt,Body,60);
		
		tEnt = id
		
		if(!tEnt)
			return PLUGIN_HANDLED
		
		new Classname[8]
		pev(tEnt,pev_classname,Classname,7);
		
		if(!equali(Classname,"player"))
			return PLUGIN_HANDLED
		
		if(!(pev(tEnt,pev_flags) & FL_ONGROUND) || !(pev(id,pev_flags) & FL_ONGROUND))
			return PLUGIN_HANDLED
		
		new Float:iVelo[3]
		pev(id,pev_size,iVelo);
		
		if(iVelo[2] < 72.0)
			return PLUGIN_HANDLED
		
		new IsCop = DRP_IsCop(id);
		if(!IsCop)
		{
			if(++g_ShoveAmount[id] > 3)
			{
				new const Float:Time = get_gametime();
				
				if(Time - g_ShoveTime[id] < 60.0 && g_ShoveTime[id])
				{
					client_print(id,print_chat,"[DRP] You're to weak to shove.");
					return PLUGIN_HANDLED
				}
				
				g_ShoveAmount[id] = 0
				g_ShoveTime[id] = Time
			}
		}
		
		new plName[2][33]
		get_user_name(id,plName[0],32);
		get_user_name(tEnt,plName[1],32);
		
		pev(tEnt,pev_size,iVelo);
		
		client_print(id,print_chat,"[DRP] You have just %s %s",iVelo[2] < 72.0 ? "kicked" : "shoved",plName[1]);
		client_print(tEnt,print_chat,"[DRP] You have just been %s by %s",iVelo[2] < 72.0 ? "kicked" : "shoved",plName[0]);
		
		velocity_by_aim(id,IsCop ? 500 : random_num(150,200),iVelo);
		set_pev(tEnt,pev_velocity,iVelo);
		
		emit_sound(id,CHAN_AUTO,"player/block.wav",VOL_NORM,ATTN_NORM,0,PITCH_NORM);
		return PLUGIN_HANDLED
	}
	else if(equali(Args,"/hiredplayers"))
	{
		client_print(id,print_chat,"[DRP] Fetching information...");
		return JobPlayers(id,DRP_GetJobAccess(DRP_GetUserJobID(id)));
	}
	// --
	
	// Random Usless commands
	else if(equali(Args,"/steamid",8))
	{
		new AuthID[36]
		get_user_authid(id,AuthID,35);
		
		client_print(id,print_chat,"[DRP] Your SteamID is - %s",AuthID);
		return PLUGIN_HANDLED
	}
	else if(equali(Args,"/stopsound",10))
	{
		client_cmd(id,"stopsound");
		client_print(id,print_chat,"[DRP] All surrounding sounds have been stopped.");
		return PLUGIN_HANDLED
	}
	
	else if(equali(Args,"/sit",4) || equali(Args,"/stand",6))
		return ToggleStanding(id);
	
	else if(equali(Args,"/motd"))
	{
		show_motd(id,"motd.txt","MOTD");
		return PLUGIN_HANDLED
	}
	// End
	
	return PLUGIN_CONTINUE
}

public CmdChangeMoney(id,level,cid)
{
	if(!DRP_CmdAccess(id,cid,3))
		return PLUGIN_HANDLED
	
	new Arg[33],Money,Target
	
	read_argv(1,Arg,32);
	Target = cmd_target(id,Arg,CMDTARGET_ALLOW_SELF);
	
	if(!Target)
		return PLUGIN_HANDLED
	
	read_argv(2,Arg,32);
	Money = str_to_num(Arg);
	
	if(Money < 1 && Money != 0)
	{
		client_print(id,print_console,"[DRP] Money value must be higher than $1.00");
		return PLUGIN_HANDLED
	}
	
	new Name[33],AdminName[33],Wallet = DRP_GetUserWallet(Target);
	get_user_name(Target,Name,32)
	get_user_name(id,AdminName,32)
	
	new Authid[36],AdminAuthid[36]
	get_user_authid(Target,Authid,35)
	get_user_authid(id,AdminAuthid,35)
	
	read_argv(0,Arg,32);
	switch(Arg[4])
	{
		case 'r':
		{
			if(Wallet < Money)
			{ 
				client_print(id,print_console,"[DRP] Unable to remove cash. Amount to high. (User has: $%d Removed: $%d)",Wallet,Money); 
				return PLUGIN_HANDLED; 
			}
			
			DRP_SetUserWallet(Target,Wallet - Money);
			client_print(id,print_console,"[DRP] You have removed $%d from %s's wallet.",Money,Name);
			
			if(get_pcvar_num(p_Log))
				DRP_Log("Cmd: ^"%s<%d><%s><>^" remove wallet money from player ^"%s<%d><%s><>^" (amount ^"$%d^")",AdminName,get_user_userid(id),AdminAuthid,Name,get_user_userid(Target),Authid,Money);
		}
		
		case 'c':
		{
			DRP_SetUserWallet(Target,Wallet + Money)
			client_print(id,print_console,"[DRP] You have added $%d to %s's wallet.",Money,Name);
			
			if(get_pcvar_num(p_Log))
				DRP_Log("Cmd: ^"%s<%d><%s><>^" add wallet money for player ^"%s<%d><%s><>^" (amount ^"$%d^")",AdminName,get_user_userid(id),AdminAuthid,Name,get_user_userid(Target),Authid,Money)
		}
		
		default:
		{
			DRP_SetUserWallet(Target,Money);
			client_print(id,print_console,"[DRP] You have set %s's wallet money to $%d.",Name,Money);
			
			if(get_pcvar_num(p_Log))
				DRP_Log("Cmd: ^"%s<%d><%s><>^" set wallet money for player ^"%s<%d><%s><>^" (amount ^"$%d^")",AdminName,get_user_userid(id),AdminAuthid,Name,get_user_userid(Target),Authid,Money)
		}
	}
	return PLUGIN_HANDLED
}
public CmdChangeBank(id,level,cid)
{
	if(!DRP_CmdAccess(id,cid,3))
		return PLUGIN_HANDLED
	
	new Arg[33],Money,Target
	
	read_argv(1,Arg,32);
	Target = cmd_target(id,Arg,CMDTARGET_ALLOW_SELF);
	
	if(!Target)
		return PLUGIN_HANDLED
	
	read_argv(2,Arg,32);
	Money = str_to_num(Arg);
	
	if(Money < 1 && Money != 0)
	{
		client_print(id,print_console,"[DRP] Money value must be higher than $1.00");
		return PLUGIN_HANDLED
	}
	
	new Name[33],AdminName[33],Bank = DRP_GetUserBank(Target);
	get_user_name(Target,Name,32);
	get_user_name(id,AdminName,32);
	
	new Authid[36],AdminAuthid[36]
	get_user_authid(Target,Authid,35);
	get_user_authid(id,AdminAuthid,35);
	
	read_argv(0,Arg,32);
	switch(Arg[4])
	{
		case 'r':
		{
			if(Bank < Money)
			{ 
				client_print(id,print_console,"[DRP] Unable to remove bank cash. Amount to high. (User has: $%d Removed: $%d)",Bank,Money)
				return PLUGIN_HANDLED
			}
			
			DRP_SetUserBank(Target,Bank - Money);
			client_print(id,print_console,"[DRP]You have removed $%d from %s's bank.",Money,Name);
			
			if(get_pcvar_num(p_Log))
				DRP_Log("Cmd: ^"%s<%d><%s><>^" remove bank money from player ^"%s<%d><%s><>^" (amount ^"$%d^")",AdminName,get_user_userid(id),AdminAuthid,Name,get_user_userid(Target),Authid,Money)
		}
		
		case 'c':
		{
			DRP_SetUserBank(Target,Bank + Money);
			client_print(id,print_console,"[DRP] You have added $%d to %s's bank.",Money,Name);
			
			if(get_pcvar_num(p_Log))
				DRP_Log("Cmd: ^"%s<%d><%s><>^" add bank money for player ^"%s<%d><%s><>^" (amount ^"$%d^")",AdminName,get_user_userid(id),AdminAuthid,Name,get_user_userid(Target),Authid,Money)
		}
		
		default:
		{
			DRP_SetUserBank(Target,Money);
			client_print(id,print_console,"[DRP] You have set %s's bank money to $%d.",Name,Money)
			
			if(get_pcvar_num(p_Log))
				DRP_Log("Cmd: ^"%s<%d><%s><>^" set bank money for player ^"%s<%d><%s><>^" (amount ^"$%d^")",AdminName,get_user_userid(id),AdminAuthid,Name,get_user_userid(Target),Authid,Money)
		}
	}
	return PLUGIN_HANDLED
}
public CmdChangeItems(id,level,cid)
{
	if(!DRP_CmdAccess(id,cid,4))
		return PLUGIN_HANDLED
	
	new Arg[33],ItemID,Results[2],Num
	read_argv(2,Arg,32);
	
	is_str_num(Arg) ? 
		(ItemID = str_to_num(Arg)) : (Num = DRP_FindItemID(Arg,Results,2))
	
	if(Num > 1)
	{
		// We found more than one item, try a direct search (will compare item names exactly)
		Num = DRP_FindItemID2(Arg);
		if(!Num)
		{
			client_print(id,print_console,"[DRP] Found more than one item with that name.")
			return PLUGIN_HANDLED
		}
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
	
	read_argv(3,Arg,32);
	new Amount = str_to_num(Arg);
	read_argv(1,Arg,32);
	
	if(Amount < 1)
	{
		client_print(id,print_console,"[DRP] Amount value must be higher than 1");
		return PLUGIN_HANDLED
	}
	
	new Target = cmd_target(id,Arg,CMDTARGET_ALLOW_SELF);
	if(!Target || !ItemID)
		return PLUGIN_HANDLED
	
	new Name[33],AdminName[33],OldNum = DRP_GetUserItemNum(Target,ItemID)
	get_user_name(Target,Name,32);
	get_user_name(id,AdminName,32);
	
	new Authid[36],AdminAuthid[36]
	get_user_authid(Target,Authid,35);
	get_user_authid(id,AdminAuthid,35);
	
	new ItemName[33]
	DRP_GetItemName(ItemID,ItemName,32);
	
	read_argv(0,Arg,32);
	switch(Arg[4])
	{
		case 'r':
		{
			if(OldNum < Amount)
			{
				client_print(id,print_console,"[DRP] Unable to remove item. Amount to high (User has: %d Removed: %d)",OldNum,Amount);
				return PLUGIN_HANDLED
			}
			
			DRP_SetUserItemNum(Target,ItemID,OldNum - Amount < 0 ? 0 : OldNum - Amount)
			client_print(id,print_console,"[DRP] You have removed %d of item ^"%s^" from %s's inventory.",Amount,ItemName,Name);
			
			if(get_pcvar_num(p_Log))
				DRP_Log("Cmd: ^"%s<%d><%s><>^" remove inventory item from player ^"%s<%d><%s><>^" (item ^"%s^") (itemid ^"%d^") (amount ^"%d^")",AdminName,get_user_userid(id),AdminAuthid,Name,get_user_userid(Target),Authid,ItemName,ItemID,Amount)
		}
		case 'a':
		{
			DRP_SetUserItemNum(Target,ItemID,OldNum + Amount < 0 ? 0 : OldNum + Amount)
			client_print(id,print_console,"[DRP] You have added %d of item ^"%s^" to %s's inventory.",Amount,ItemName,Name)
			
			if(get_pcvar_num(p_Log))
				DRP_Log("Cmd: ^"%s<%d><%s><>^" add inventory item for player ^"%s<%d><%s><>^" (item ^"%s^") (itemid ^"%d^") (amount ^"%d^")",AdminName,get_user_userid(id),AdminAuthid,Name,get_user_userid(Target),Authid,ItemName,ItemID,Amount)
		}
		default:
		{
			DRP_SetUserItemNum(Target,ItemID,Amount < 0 ? 0 : Amount)
			client_print(id,print_console,"[DRP] You have set %s's inventory quantity of item ^"%s^" to %d.",Name,ItemName,Amount)
			
			if(get_pcvar_num(p_Log))
				DRP_Log("Cmd: ^"%s<%d><%s><>^" set inventory item for player ^"%s<%d><%s><>^" (item ^"%s^") (itemid ^"%d^") (amount ^"%d^")",AdminName,get_user_userid(id),AdminAuthid,Name,get_user_userid(Target),Authid,ItemName,ItemID,Amount)
		}
	}
	
	return PLUGIN_HANDLED
}
/*=======================================================================================================================================*/
public CmdAddJob(id, level, cid)
{
	if(!DRP_CmdAccess(id,cid,4))
		return PLUGIN_HANDLED
	
	new Arg[33], Results[1]
	
	read_argv(2, Arg, 32) // Salary
	new Salary = str_to_num(Arg);
	
	new AccessString[16]
	read_argv(3, AccessString, 15); // Access String
	
	read_argv(1, Arg, 32); // Name
	remove_quotes(Arg);
	trim(Arg);
	
	DRP_FindJobID(Arg,Results,1);
	
	if(Results[0])
	{
		new TempName[33]
		DRP_GetJobName(Results[0],TempName,32);
		
		client_print(id,print_console,"[DRP] A similar job already exists. You entered: ^"%s^" - Existing job: ^"%s^"",Arg,TempName);
		return PLUGIN_HANDLED
	}
	
	if(DRP_AddJob(Arg,Salary,Access))
		client_print(id,print_console,"[DRP] Added Job %s to database with salary $%d and access %s.",Arg,Salary,AccessStr);
	else
		client_print(id,print_console,"[DRP] Unable to add job. (ERROR UNKNOWN)");
	
	if(!get_pcvar_num(p_Log))
		return PLUGIN_HANDLED
	
	new AuthID[36],Name[33]
	get_user_name(id,Name,32);
	get_user_authid(id,AuthID,35);
	
	DRP_Log("Cmd: ^"%s<%d><%s> add job ^"%s^" (salary ^"$%d/hr^") (access ^"%s^")",Name,get_user_userid(id),AuthID,Arg,Salary,AccessStr);
	
	return PLUGIN_HANDLED
}
public CmdDeleteJob(id,level,cid)
{
	if(!DRP_CmdAccess(id,cid,2))
		return PLUGIN_HANDLED
	
	new Arg[33],Results[1]
	
	read_argv(1,Arg,32);
	remove_quotes(Arg);
	trim(Arg);
	
	DRP_FindJobID(Arg,Results,1);
	
	if(!Results[0])
	{
		client_print(id,print_console,"[DRP] No job matching your input was found");
		return PLUGIN_HANDLED
	}
	
	new JobName[33],JobID = Results[0]
	DRP_GetJobName(JobID,JobName,32);
	
	new iPlayers[32],iNum,Index
	get_players(iPlayers,iNum);
	
	for(new Count;Count < iNum;Count++)
	{
		Index = iPlayers[Count]
		if(DRP_GetUserJobID(Index) == JobID)
			client_print(Index,print_chat,"[DRP] This Job has been deleted and you have been set back to Unemployed.");
	}
	
	DRP_DeleteJob(JobID);
	
	if(!get_pcvar_num(p_Log))
		return PLUGIN_HANDLED
	
	new Name[33],Authid[36]
	get_user_name(id,Name,32);
	get_user_authid(id,Authid,35);
	
	DRP_Log("Cmd: ^"%s<%d><%s> delete job ^"%s^"",Name,get_user_userid(id),Authid,JobName);
	return PLUGIN_HANDLED
}
public CmdDeleteDoor(id,level,cid)
{
	if(!DRP_CmdAccess(id,cid,1))
		return PLUGIN_HANDLED
	
	new Index,Body
	get_user_aiming(id,Index,Body,200);
	
	if(!Index)
	{
		client_print(id,print_console,"[DRP] You are not looking at a valid door");
		return PLUGIN_HANDLED
	}
	
	new Classname[33]
	pev(Index,pev_classname,Classname,32);
	
	if(!equali(Classname,"func_door") && !equali(Classname,"func_door_rotating"))
	{
		client_print(id,print_console,"[DRP] You are not looking at a valid door");
		return PLUGIN_HANDLED
	}
	
	pev(Index,pev_targetname,Classname,32);
	
	new Door = DRP_DoorMatch(Classname,Index);
	if(!DRP_ValidDoor(Door))
	{
		client_print(id,print_console,"[DRP] You are not looking at a registered door");
		return PLUGIN_HANDLED
	}
	
	new Property = DRP_PropertyMatch(Classname,Index);
	
	if(DRP_DeleteDoor(Door))
		client_print(id,print_console,"[DRP] Door successfully deleted.");
	else
		client_print(id,print_console,"[DRP] Unable to delete door.");
	
	if(!get_pcvar_num(p_Log))
		return PLUGIN_HANDLED
	
	new Name[33],Authid[36]
	get_user_name(id,Name,32)
	get_user_authid(id,Authid,35)
	
	new ExternalName[33]
	DRP_PropertyGetExternalName(Property,ExternalName,32);
	
	DRP_Log("Cmd: ^"%s<%d><%s> delete door attached to ^"%s^" (entid ^"%d^") (targetname ^"%s^")",Name,get_user_userid(id),Authid,ExternalName,Index,Classname);
	
	return PLUGIN_HANDLED
}
public CmdDeleteProperty(id,level,cid)
{
	if(!DRP_CmdAccess(id,cid,1))
		return PLUGIN_HANDLED
	
	new Index,Body
	get_user_aiming(id,Index,Body,200);
	
	if(!Index)
	{
		client_print(id,print_console,"[DRP] You are not looking at a valid door");
		return PLUGIN_HANDLED
	}
	
	new Classname[33]
	pev(Index,pev_classname,Classname,32);
	
	if(!equali(Classname,"func_door") && !equali(Classname,"func_door_rotating"))
	{
		client_print(id,print_console,"[DRP] You are not looking at a valid door");
		return PLUGIN_HANDLED
	}
	
	pev(Index,pev_targetname,Classname,32);
	
	new Property = DRP_PropertyMatch(Classname,Index);
	if(!DRP_ValidProperty(Property))
	{
		client_print(id,print_console,"[DRP] You are not looking at a registered property")
		return PLUGIN_HANDLED
	}
	
	if(get_pcvar_num(p_Log))
	{
		new ExternalName[33]
		DRP_PropertyGetExternalName(Property,ExternalName,32)
		
		new Name[33],Authid[36]
		get_user_name(id,Name,32);
		get_user_authid(id,Authid,35);
		
		DRP_Log("Cmd: ^"%s<%d><%s> delete property ^"%s^" (entid ^"%d^") (targetname ^"%s^")",Name,get_user_userid(id),Authid,ExternalName,Index,Classname);
	}
	DRP_DeleteProperty(Property);
	
	return PLUGIN_HANDLED
}
public CmdSetJob(id,level,cid)
{	
	if(!DRP_CmdAccess(id,cid,3))
		return PLUGIN_HANDLED
	
	new Arg[33],JobID,Results[2],Num
	read_argv(2,Arg,32);
	
	is_str_num(Arg) ? 
		(JobID = str_to_num(Arg)) : (Num = DRP_FindJobID(Arg,Results,2))
	
	if(Num > 1)
	{
		client_print(id,print_console,"[DRP] Found more than one job with that name.");
		return PLUGIN_HANDLED
	}
	
	if(!JobID)
		JobID = Results[0]
	
	if(!JobID || !DRP_ValidJobID(JobID))
	{
		client_print(id,print_console,"[DRP] That JobID/Name could not be found");
		return PLUGIN_HANDLED
	}
	
	read_argv(1,Arg,32);
	new Target = cmd_target(id,Arg,1|2);
	
	if(!Target)
		return PLUGIN_HANDLED
	
	new JobName[33]
	get_user_name(Target,Arg,32);
	
	DRP_GetJobName(JobID,JobName,32);
	DRP_SetUserJobID(Target,JobID,1);
	
	client_print(id,print_console,"[DRP] You have set %s's JobID to %d (%s).",Arg,JobID,JobName);
	
	if(!get_pcvar_num(p_Log))
		return PLUGIN_HANDLED
	
	new AdminName[33]
	get_user_name(id,AdminName,32);
	
	new Authid[36],AdminAuthid[36]
	get_user_authid(Target,Authid,35);
	get_user_authid(id,AdminAuthid,35);
	
	DRP_Log("Cmd: ^"%s<%d><%s><>^" set player ^"%s<%d><%s><>^" (job ^"%s^") (jobid ^"%d^")",AdminName,get_user_userid(id),AdminAuthid,Arg,get_user_userid(Target),Authid,JobName,JobID);
	
	return PLUGIN_HANDLED
}
public CmdEmploy(id,level,cid)
{
	if(id != 0)
	{
		if(read_argc() != 3)
			return DRP_CmdAccess(id,cid,9999) + 1
	}
	
	new Arg[36]
	read_argv(2,Arg,35);
	
	new Results[2],Result
	
	if((Result = DRP_FindJobID(Arg,Results,2)) > 1)
	{
		client_print(id,print_console,"[DRP] There is more than one job matching your input.");
		return PLUGIN_HANDLED
	}
	
	new JobID = Results[0]
	
	if(!Result)
		JobID = str_to_num(Arg);
	
	if(!JobID || !DRP_ValidJobID(JobID))
	{
		client_print(id,print_console,"[DRP] That JobID/Name could not be found");
		return PLUGIN_HANDLED
	}
	
	new JobAccess = DRP_GetJobAccess(JobID);
	new Admin = DRP_IsAdmin(id);
	
	if(!DRP_JobAccess(id,JobID) && !DRP_IsJobAdmin(id) && !Admin)
	{
		// Check Property Access.
		// If we own the property, with the same access as the job we are giving out. Then we should be allowed todo so (instead of an admin giving them the job right)
		
		new Size = DRP_PropertyNum(),Match,AuthID[36]
		get_user_authid(id,Arg,35);
		
		for(new Count;Count <= Size;Count++)
		{
			if(!DRP_ValidProperty(Count))
				continue
			
			DRP_PropertyGetOwnerAuth(Count,AuthID,35);
			if(equal(AuthID,Arg))
			{
				// Access Match.
				if(DRP_PropertyGetAccess(Count) & JobAccess)
				{
					Match = 1; 
					break;
				}
			}
		}
		
		if(!Match)
		{
			client_print(id,print_console,"[DRP] You do not have access to this job.");
			return PLUGIN_HANDLED
		}
	}
	
	new Error
	new Handle:Connection = SQL_Connect(DRP_SqlHandle(),Error,g_Menu,255);
	if(!Connection || Connection == Empty_Handle || Error)
	{
		client_print(id,print_console,"[DRP] This was a problem doing a query connection. Please contact an administrator.");
		SQL_FreeHandle(Connection);
		return PLUGIN_HANDLED
	}
	new Handle:Query = SQL_PrepareQuery(Connection,"SELECT `JobName` FROM `users`");
	if(!Query || !SQL_Execute(Query))
	{
		client_print(id,print_console,"[DRP] This was a problem doing a query. Please contact an administrator.");
		SQL_FreeHandle(Connection);
		SQL_FreeHandle(Query);
		return PLUGIN_HANDLED
	}
	
	if(!Admin)
	{
		new Count,Access = DRP_GetJobAccess(JobID),JobID2
		new szJob[33],szAccess[JOB_ACCESSES + 1],oldAccess[JOB_ACCESSES + 1]
		
		DRP_IntToAccess(Access,oldAccess,JOB_ACCESSES);
		
		while(SQL_MoreResults(Query))
		{
			SQL_ReadResult(Query,0,szJob,32);
			JobID2 = DRP_FindJobID2(szJob);
			
			if(!JobID2)
			{
				SQL_NextRow(Query);
				continue
			}
			
			JobAccess = DRP_GetJobAccess(JobID2);
			DRP_IntToAccess(JobAccess,szAccess,JOB_ACCESSES);
			
			if(JobAccess & Access)
				Count++
			
			SQL_NextRow(Query);
		}
		
		SQL_FreeHandle(Connection);
		SQL_FreeHandle(Query);
		
		new Max = get_pcvar_num(p_MaxEmploys);
		if(Count >= Max)
		{
			client_print(id,print_console,"[DRP] * ERROR: This Job's access letter (%s) has %d people hired. You're only allowed: %d",oldAccess,Count,Max);
			client_print(id,print_console,"[DRP] Help: Type /hiredplayers - to fire people with this job access");
			return PLUGIN_HANDLED
		}
	}
	
	read_argv(1,Arg,35);
	new Target = cmd_target(id,Arg,2);
	
	if(!Target)
		return PLUGIN_HANDLED
	
	new JobName[33],AdminName[33],Salary = DRP_GetJobSalary(JobID);
	get_user_name(id,AdminName,32);
	
	DRP_GetJobName(JobID,JobName,32);
	format(g_Menu,255,"Employment Offer^n^n%s has offered you^na job^n^nName: %s^nSalary: $%d/h^n^n1. Accept^n2. Decline",AdminName,JobName,Salary);
	
	g_JobID[Target] = JobID
	g_Employer[Target] = id
	
	show_menu(Target,MENU_KEY_1|MENU_KEY_2,g_Menu,-1,g_EmployMenu);
	
	if(!get_pcvar_num(p_Log))
		return PLUGIN_HANDLED
	
	new Authid[36],AdminAuthid[36]
	get_user_authid(Target,Authid,35);
	get_user_authid(id,AdminAuthid,35);
	get_user_name(Target,Arg,35);
	
	DRP_Log("Cmd: ^"%s<%d><%s><>^" offer job ^"%s<%d><%s><>^" (job ^"%s^") (jobid ^"%d^")",AdminName,get_user_userid(id),AdminAuthid,Arg,get_user_userid(Target),Authid,JobName,JobID);
	client_print(id,print_console,"[DRP] Asking player %s to accept job offer: %s - You will be notified in the chat",Arg,JobName);
	
	return PLUGIN_HANDLED
}
public CmdFire(id,level,cid)
{
	if(read_argc() != 2)
		return DRP_CmdAccess(id,cid,9999) + 1
	
	new Arg[33]
	read_argv(1,Arg,32);
	
	new Target = cmd_target(id,Arg,1|2),JobIDs[1]
	if(!Target)
		return PLUGIN_HANDLED
	
	get_user_name(Target,Arg,32);
	
	if(!DRP_JobAccess(id,DRP_GetUserJobID(id)) && !DRP_IsJobAdmin(id) && !DRP_IsAdmin(id))
	{
		client_print(id,print_console,"[DRP] You do not have access to this player's job.");
		return PLUGIN_HANDLED
	}
	
	if(!g_Unemployed)
	{
		if(!DRP_FindJobID("Unemployed",JobIDs,1))
		{
			client_print(id,print_console,"[DRP] Error finding the ^"Unemployed^" job.")
			return PLUGIN_HANDLED
		}
	}
	
	DRP_SetUserJobID(Target,g_Unemployed);
	
	client_print(id,print_console,"[DRP] You have fired player %s",Arg);
	client_print(Target,print_chat,"[DRP] You have been fired.");
	
	if(!get_pcvar_num(p_Log))
		return PLUGIN_HANDLED
	
	new AdminName[33]
	get_user_name(id,AdminName,32);
	
	new Authid[36],AdminAuthid[36]
	get_user_authid(Target,Authid,35);
	get_user_authid(id,AdminAuthid,35);
	
	DRP_Log("Cmd: ^"%s<%d><%s><>^" fire player ^"%s<%d><%s><>^"",AdminName,get_user_userid(id),AdminAuthid,Arg,get_user_userid(Target),Authid);
	
	return PLUGIN_HANDLED
}
public CmdSetJobRight(id,level,cid)
{
	if(!DRP_CmdAccess(id,cid,3))
		return PLUGIN_HANDLED
	
	new Arg[33]
	read_argv(1,Arg,32);
	
	new Target = cmd_target(id,Arg,1|2);
	if(!Target)
		return PLUGIN_HANDLED
	
	read_argv(2,Arg,32);
	new Access = DRP_AccessToInt(Arg);
	
	DRP_SetUserJobRight(Target,Access);
	
	new Name[33]
	get_user_name(Target,Name,32);
	
	client_print(id,print_console,"[DRP] You have set %s's job rights to %s",Name,Arg);
	
	if(!get_pcvar_num(p_Log))
		return PLUGIN_HANDLED
	
	new Authid[36],AdminAuthid[36],plName[33]
	get_user_authid(Target,Authid,35);
	get_user_authid(id,AdminAuthid,35);
	get_user_name(id,plName,32);
	
	DRP_Log("Cmd: ^"%s<%d><%s><>^" set player ^"%s<%d><%s><>^" (jobright ^"%s^")",plName,get_user_userid(id),AdminAuthid,Name,get_user_userid(Target),Authid,Arg)
	
	return PLUGIN_HANDLED
}
public CmdSetAccess(id,level,cid)
{
	if((!DRP_CmdAccess(id,cid,3)) && (!cmd_access(id,level,cid,3)))
		return PLUGIN_HANDLED
	
	new Arg[33],Name[33]
	read_argv(1,Arg,32);
	
	new Target = cmd_target(id,Arg,CMDTARGET_ALLOW_SELF);
	if(!Target)
		return PLUGIN_HANDLED
	
	read_argv(2,Arg,32);
	new Access = DRP_AccessToInt(Arg);
	
	get_user_name(Target,Name,32);
	client_print(id,print_console,"[DRP] You have set %s's access to %s",Name,Arg);
	
	read_argv(3,Arg,32);
	DRP_SetUserAccess(Target,Access,Arg[0] ? 1 : 0);
	
	if(!get_pcvar_num(p_Log))
		return PLUGIN_HANDLED
	
	new AdminName[33]
	get_user_name(id,AdminName,32)
	
	new Authid[36],AdminAuthid[36]
	get_user_authid(Target,Authid,35)
	get_user_authid(id,AdminAuthid,35)
	
	DRP_Log("Cmd: ^"%s<%d><%s><>^" set player ^"%s<%d><%s><>^" (access ^"%s^")",AdminName,get_user_userid(id),AdminAuthid,Name,get_user_userid(Target),Authid,Arg)
	
	return PLUGIN_HANDLED
}
public CmdAddProperty(id,level,cid)
{
	if(!DRP_CmdAccess(id,cid,9))
		return PLUGIN_HANDLED
	
	new InternalName[64],ExternalName[64],OwnerName[33],OwnerAuth[36],Price,AccessStr[JOB_ACCESSES + 1],Profit,Locked,Temp[33]
	read_argv(1,InternalName,63);
	
	if(DRP_ValidPropertyName(InternalName))
	{
		client_print(id,print_console,"[DRP] Property ^"%s^" already exists.",InternalName)
		return PLUGIN_HANDLED
	}
	
	read_argv(2,ExternalName,63);
	read_argv(3,OwnerName,32);
	read_argv(4,OwnerAuth,35);
	read_argv(5,Temp,32);
	Price = str_to_num(Temp);
	read_argv(6,AccessStr,JOB_ACCESSES);
	read_argv(7,Temp,32);
	Profit = str_to_num(Temp);
	read_argv(8,Temp,32);
	Locked = str_to_num(Temp);
	
	remove_quotes(InternalName);
	remove_quotes(ExternalName);
	remove_quotes(OwnerName);
	remove_quotes(OwnerAuth);
	
	trim(InternalName);
	trim(ExternalName);
	trim(OwnerName);
	trim(OwnerAuth);
	
	if(DRP_AddProperty(InternalName,ExternalName,OwnerName,OwnerAuth,Price,AccessStr,Profit,Locked))
	{
		client_print(id,print_console,"^n[Property Added]^nExternalName: %s^nInternalName: %s^nOwnerName: %s^nOwnerAuthID: %s",ExternalName,InternalName,OwnerName,OwnerAuth);
		client_print(id,print_console,"Price: $%d^nAccess: %s^nStarting Profit: %d^nLocked: %s^n[END]^n",Price,AccessStr,Profit,Locked ? "Yes" : "No");
	}
	else
	{
		client_print(id,print_console,"[DRP] An Error Occured when adding the property.");
	}
	
	if(!get_pcvar_num(p_Log))
		return PLUGIN_HANDLED
	
	new AuthID[36]
	get_user_name(id,Temp,32)
	get_user_authid(id,AuthID,35);
	
	DRP_Log("Cmd: ^"%s<%d><%s> add property ^"%s^" (externalname ^"%s^") (ownername ^"%s^") (ownerauth ^"%s^") (price ^"%d^") (access ^"%s^") (profit ^"$%d^")",Temp,get_user_userid(id),AuthID,InternalName,ExternalName,OwnerName,OwnerAuth,Price,AccessStr,Profit);
	
	return PLUGIN_HANDLED
}
public CmdAddDoor(id,level,cid)
{
	if(!DRP_CmdAccess(id,cid,2))
		return PLUGIN_HANDLED
	
	new Index,Body
	get_user_aiming(id,Index,Body,200);
	
	if(!Index || !pev_valid(Index))
	{
		client_print(id,print_console,"[DRP] You must be looking at a door.");
		return PLUGIN_HANDLED
	}
	
	new Targetname[33]
	pev(Index,pev_classname,Targetname,32);
	
	if(containi(Targetname,"door") == -1)
	{
		client_print(id,print_console,"[DRP] You must be looking at a door.");
		return PLUGIN_HANDLED
	}
	
	pev(Index,pev_targetname,Targetname,32);
	if(DRP_ValidDoorName(Targetname,Index))
	{
		client_print(id,print_console,"[DRP] This property is already in the database.");
		return PLUGIN_HANDLED
	}
	
	new Arg[33]
	read_argv(1,Arg,32);
	
	if(!DRP_ValidPropertyName(Arg))
	{
		client_print(id,print_console,"Property ^"%s^" does not exist.",Arg)
		return PLUGIN_HANDLED
	}
	
	new Property = DRP_PropertyMatch(_,_,Arg);
	
	DRP_AddDoor(Targetname[1] ? Targetname : "",Targetname[1] ? 0 : Index,Arg);
	client_print(id,print_console,"[DRP] You have added %s to the list of doors.",Targetname);
	
	if(!get_pcvar_num(p_Log))
		return PLUGIN_HANDLED
	
	new Name[33],Authid[36],ExternalName[33]
	get_user_name(id,Name,32)
	get_user_authid(id,Authid,35)
	
	DRP_PropertyGetExternalName(Property,ExternalName,32);
	DRP_Log("Cmd: ^"%s<%d><%s> add door (targetname ^"%s^") (entid ^"%d^") (externalname ^"%s^") (internalname ^"%s^")",Name,get_user_userid(id),Authid,Targetname,Index,ExternalName,Arg)
	
	return PLUGIN_HANDLED
}
/*==================================================================================================================================================*/
// Menus
public _FineHandle(id,Key)
{
	new plName[33]
	get_user_name(id,plName,32);
	
	if(Key)
	{
		client_print(g_Finer[id],print_chat,"[DRP] %s has refused to pay the fine.",plName);
		client_print(id,print_chat,"[DRP] You have refused to pay the fine.");
	}
	else
	{
		new Amount = g_Amount[id],Wallet = DRP_GetUserWallet(id),CashLeft = Wallet - Amount,Flag = 0
		if(CashLeft < 0)
		{
			DRP_SetUserWallet(id,0);
			CashLeft = abs(CashLeft);
			
			if(Wallet >= 1)
				Flag = 1
		}
		else
		{
			DRP_SetUserWallet(id,CashLeft);
			PrintPay(id,g_Finer[id],plName);
			return
		}
		
		new Bank = DRP_GetUserBank(id);
		Bank -= CashLeft
		
		DRP_SetUserBank(id,Bank);
		PrintPay(id,g_Finer[id],plName,Flag);
	}
}
public _EmployHandle(id,Key)
{
	new Name[33]
	get_user_name(id,Name,32);
	
	if(!Key)
	{
		client_print(g_Employer[id],print_chat,"[DRP] %s has accepted your employment offer.",Name);
		client_print(id,print_chat,"[DRP] You have accepted the employment offer. Salary: $%d/Min",DRP_GetJobSalary(g_JobID[id]));
		
		DRP_SetUserJobID(id,g_JobID[id]);
	}
	else
	{
		client_print(g_Employer[id],print_chat,"[DRP] %s has declined your employment offer.",Name);
		client_print(id,print_chat,"[DRP] You have declined the employment offer.");
	}
}
public _SellHandle(id,Menu,Item)
{
	if(Item == MENU_EXIT)
	{
		menu_destroy(Menu);
		return PLUGIN_HANDLED
	}
	
	new Data[33],Temp
	menu_item_getinfo(Menu,Item,Temp,Data,32,_,_,Temp);
	menu_destroy(Menu);
	
	new StrId[4],StrItem[4],StrPrice[4]
	parse(Data,StrId,3,StrItem,3,StrPrice,3);
	
	new const Index = str_to_num(StrId),ItemID = str_to_num(StrItem),Price = str_to_num(StrPrice);
	get_user_name(id,Data,32);
	
	if(!is_user_alive(Index))
	{
		client_print(id,print_chat,"[DRP] The seller is no longer alive.");
		return PLUGIN_HANDLED
	}
	
	new Float:Origin1[3],Float:Origin2[3]
	pev(Index,pev_origin,Origin1);
	pev(id,pev_origin,Origin2);
	
	if(get_distance_f(Origin1,Origin2) > 200.0)
	{
		client_print(id,print_chat,"[DRP] You have moved to far away from the player.");
		return PLUGIN_HANDLED
	}
	
	switch(Item)
	{
		case 0:
		{
			new const Wallet = DRP_GetUserWallet(id);
			if(Price > Wallet)
			{
				client_print(id,print_chat,"[DRP] You are unable to afford this offer.");
				client_print(Index,print_chat,"[DRP] Your target has declined the offer.");
				
				return PLUGIN_HANDLED
			}
			DRP_SetUserWallet(id,Wallet - Price);
			DRP_SetUserWallet(Index,DRP_GetUserWallet(Index) + Price);
			
			DRP_SetUserItemNum(id,ItemID,DRP_GetUserItemNum(id,ItemID) + 1);
			DRP_SetUserItemNum(Index,ItemID,DRP_GetUserItemNum(Index,ItemID) - 1);
			
			client_print(Index,print_chat,"[DRP] Buyer %s has bought your item. Price: $%d",Data,Price);
			DRP_GetItemName(ItemID,Data,32);
			client_print(id,print_chat,"[DRP] You have purchased the item %s. Price: $%d",Data,Price);
		}
		case 1:
		{
			client_print(id,print_chat,"[DRP] You have declined the offer.");
			client_print(Index,print_chat,"[DRP] %s has declined your offer.",Data);
		}
	}
	return PLUGIN_HANDLED
}
/*==================================================================================================================================================*/
PrintPay(id,Finer,const Name[],Extra = 0)
{
	client_print(id,print_chat,"[DRP] You have paid the fine.");
	
	if(Extra)
		client_print(id,print_chat,"[DRP] Money was taken from BOTH your Wallet and Bank to pay for the fine.");
	
	client_print(Finer,print_chat,"[DRP] %s payed the $%d fine you ordered.",Name,g_Amount[id]);
	
	// Event - Probably gonna be used for the economy
	new Data[2]
	Data[0] = id
	Data[1] = Finer
	DRP_CallEvent("Player_PayPoliceFine",Data,2);
}
ToggleStanding(id)
{
	g_UserSitting[id] = !g_UserSitting[id]
	
	if(g_UserSitting[id])
		client_cmd(id,"say /me ^"sits down^";wait;+duck");
	else
		client_cmd(id,"say /me ^"stands up^";wait;-duck");
	
	return PLUGIN_HANDLED
}

// Display's a menu with player's and that JobAccess
JobPlayers(const id,const Access)
{
	if(!(DRP_GetUserJobRight(id) & Access) && !DRP_IsAdmin(id))
	{
		client_print(id,print_chat,"[DRP] You do not own job rights - to your current job.");
		return PLUGIN_HANDLED
	}
	
	new Data[2]
	Data[0] = id
	Data[1] = Access
	
	SQL_ThreadQuery(DRP_SqlHandle(),"FetchJobInfo","SELECT `SteamID`,`JobName`,`PlayerName` FROM `users`",Data,2);
	return PLUGIN_HANDLED
}
public FetchJobInfo(FailState,Handle:Query,const Error[],Errcode,const Data[],DataSize) 
{
	if(FailState != TQUERY_SUCCESS)
		return log_amx("[SQL ERROR] Unable to connect to SQL Database. (Error: %s)",Error ? Error : "UNKNOWN");
	
	new const id = Data[0],Access = Data[1]
	if(id == -1)
		return PLUGIN_CONTINUE
	
	if(!is_user_alive(id))
		return PLUGIN_CONTINUE
	
	new JobName[33],JobID,JobAccess
	new Name[33],SteamID[34]
	
	new Menu = menu_create("This is the list of players who^nhave the same job letter as you.^nYou have job rights giving you the^nability to fire/hire them","HandleJobAccessMenu");
	while(SQL_MoreResults(Query))
	{
		SQL_ReadResult(Query,1,JobName,32);
		JobID = DRP_FindJobID2(JobName);
		
		if(!JobID)
		{
			SQL_NextRow(Query);
			continue
		}
		
		JobAccess = DRP_GetJobAccess(JobID);
		if(JobAccess & Access)
		{
			SQL_ReadResult(Query,0,SteamID,34);
			SQL_ReadResult(Query,2,Name,32);
			menu_additem(Menu,Name[0] ? Name : SteamID,SteamID);
		}
		
		SQL_NextRow(Query);
	}
	
	if(menu_items(Menu) < 1)
	{
		menu_destroy(Menu);
		client_print(id,print_chat,"[DRP] Nobody is currently hired with your job's access letter.");
		return PLUGIN_HANDLED
	}
	
	menu_addtext(Menu,"^nYou can fire them by selecting^nthere name/steamid",0);
	menu_display(id,Menu);
	
	return PLUGIN_CONTINUE
}
public HandleJobAccessMenu(id,Menu,Item)
{
	new SteamID[36],Temp
	menu_item_getinfo(Menu,Item,Temp,SteamID,35,_,_,Temp);
	menu_destroy(Menu);
	
	if(Item == MENU_EXIT)
		return PLUGIN_HANDLED
	
	new Target = cmd_target(id,SteamID,CMDTARGET_ALLOW_SELF);
	if(Target)
	{
		new plName[33]
		
		get_user_name(Target,plName,32);
		client_print(id,print_chat,"[DRP] You have fired player: %s",plName);
		
		get_user_name(id,plName,32);
		client_print(Target,print_chat,"[DRP] You have been fired by: %s",plName);
		
		DRP_SetUserJobID(Target,g_Unemployed);
		return PLUGIN_HANDLED
	}
	
	new Query[256],Data[1]
	formatex(Query,255,"UPDATE `Users` SET `JobName`='Unemployed' WHERE `SteamID`='%s'",SteamID);
	
	Data[0] = -1
	SQL_ThreadQuery(DRP_SqlHandle(),"FetchJobInfo",Query,Data,1);
	
	client_print(id,print_chat,"[DRP] User fired. They're job has been reset to Unemployed.");
	return PLUGIN_HANDLED
}