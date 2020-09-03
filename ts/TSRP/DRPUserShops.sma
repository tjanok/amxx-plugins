/*
===========================================================
// DRPUserShops.sma
* --------------------------
* Author(s):
* Drak - Main Author
===========================================================
*/

#include <amxmodx>
#include <DRP/DRPCore>

// Menus
new const g_ShopMenu[] = "DRP_ShopMenu"
new const g_ShopKeys = MENU_KEY_0|MENU_KEY_1|MENU_KEY_2

enum
{
	SHOP_NONE = 0,
	SHOP_SETTINGUP,
	SHOP_OPEN
}

new g_UserItems[33][128]
new g_UserShop[33]
new g_Menu[256]

public plugin_init()
{
	register_plugin("DRP - User Shops","Drak","0.1a");
	
	// Menus
	register_menucmd(register_menuid(g_ShopMenu),g_ShopKeys,"_ShopOptions");
	
	// Events
	DRP_RegisterEvent("Menu_Display","Shop_Menu");
}

public DRP_Error(const Reason[])
	pause("d");

public Shop_Menu(const Name[],const Data[],Len)
{
	new id = Data[0]
	if(!is_user_connected(id) || !is_user_alive(id))
		return
	
	DRP_AddMenuItem(id,"Shop (Trading) Menu","_Shop_Menu");
}
public _Shop_Menu(id)
{
	GetShopStatus(id,g_Menu,255);
	format(g_Menu,255,"Shop Menu^nStatus: %s^n^n",g_Menu);
	
	switch(g_UserShop[id])
	{
		case SHOP_NONE:
			add(g_Menu,255,"1. Open Shop^n");
		case SHOP_OPEN:
			add(g_Menu,255,"1. Close Shop^n2. Change Shop Settings^n")
		case SHOP_SETTINGUP:
			add(g_Menu,255,"1. Continue Setting Up^n2. Close Shop^n");
	}
	
	add(g_Menu,255,"^n0. Exit");
	
	show_menu(id,g_ShopKeys,g_Menu,-1,g_ShopMenu);
}
public _ShopOptions(id,Key)
{
	if(!is_user_alive(id))
		return
	
	new Title[64]
	GetShopStatus(id,Title,63);
	
	new Menu = menu_create(Title,"SecShopOptions");
	switch(Key)
	{
		case 0:
		{
			menu_additem(Menu,"Select Shop Items","sItems");
			menu_additem(Menu,"Change Item Prices","sPrices");
			
			if(g_UserShop[id] != SHOP_OPEN)
				menu_additem(Menu,"Open Shop (Select Me When Done)");
		}
		case 1:
		{
			if(g_UserShop[id] != SHOP_OPEN)
				client_print(id,print_chat,"CLOSE SHOP");
			else
			{
				menu_additem(Menu,"Select Shop Items");
				menu_additem(Menu,"Change Item Prices");
			}
		}
	}
	menu_display(id,Menu);
}
new g_Items
public SecShopOptions(id,Menu,Item)
{
	if(Item == MENU_EXIT)
	{
		menu_destroy(Menu);
		return PLUGIN_HANDLED
	}
	
	static Info[33],Access
	menu_item_getinfo(Menu,Item,Access,Info,32,_,_,Access);
	
	// We want to set our items up, in the store.
	if(equal(Info,"sItems"))
	{
		new Results[128],itemName[33],Info[33],Temp = 0
		new Menu = menu_create("Select Items","SecShopOptions"),Len = DRP_FetchUserItems(id,Results)
		for(new Count;Count < Len;Count++)
		{
			DRP_GetItemName(Results[Count],itemName,32);
			
			if(g_UserItems[id][Count] == Results[Count])
				add(itemName,32,"- Already Have");
			
			format(Info,32,"sItem|%d",Results[Count]);
			menu_additem(Menu,itemName,Info);
		}
		menu_display(id,Menu);
		server_print("LOL");
	}
	else if(equal(Info,"sPrices"))
	{
	}
	else if(containi(Info,"sItem") != -1)
	{
		new itemName[33],Results[128]
		strtok(Info,itemName,32,Results,127,'|');
		
		new ItemID = str_to_num(Results);
		server_print("ITEM ID: %d",ItemID);
		
		g_UserItems[id][++g_Items] = ItemID
		menu_display(id,Menu);
	}
	return PLUGIN_HANDLED
}
/*==================================================================================================================================================*/
public client_putinserver(id)
{
	g_UserShop[id] = SHOP_NONE;
}
/*==================================================================================================================================================*/
GetShopStatus(id,String[],Len)
{
	switch(g_UserShop[id])
	{
		case SHOP_NONE:
			copy(String,Len,"No Shop Opened");
		case SHOP_SETTINGUP:
			copy(String,Len,"Shop Setup");
		case SHOP_OPEN:
			copy(String,Len,"Shop Opened");
	}
}
