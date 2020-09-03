#if defined _DRP_ITEMS_INCLUDE
	#endinput
#endif
#define _DRP_ITEMS_INCLUDE

#include <DRP/DRPCore>

// Return this value in any of the Item functions, to keep the user item in there inventory
// EX: DRP_RegisterItem("Some Item","SomeFunc");
// public SomeFunc(id,ItemID)
//        return ITEM_KEEP_RETURN // Instead of: return DRP_SetUserItemNum(id,ItemID,DRP_GetUserItemNum(id,ItemID) + 1)

#define ITEM_KEEP_RETURN 3
#define MAX_ITEMS 256

// This will register an item that can be used in game.
// This MUST be run during DRP_RegisterItems and no other time.
// Returns FAILED (0) on failure, or an item id on success
// name[] - name of item, ex. "Lamp Shade"
// handler[] - function to call when it is used
// description - what the item is like, i.e. "Tastes like chicken."
// remove - whether or not the item should be taken away once used, if it is
// disposable
// dropable - whether or not this item can be dropped.
// giveable - wheater or nt this item can be gived transfered to other
// ItemID - The given ItemID (Core will warn if there is a duplicate ItemID)
// Val 1,2,3 - Can store up 3 different int values (For extra parameters)
native DRP_RegisterItem(const Name[],const Handler[],const Description[],remove = 0,dropable = 1,giveable = 1,Val1 = 0,Val2 = 0,Val3 = 0);

// Returns FAILED if invalid
native DRP_ValidItemID(ItemID);

// Forces a user to use an item.
// Note that they must possess at least 1 of the item with the specified
// itemid.
// Setting useup to 1 makes it such that it will both check if the user has the item,
// and that if it's disposable is on, it gets used up
// Setting it to 0 both ignores whether or not the user has the item, as well as
// the disposable setting
native DRP_ForceUseItem(id,ItemID,UseUp = 1);

// Will get an item's name based on an item id.
// itemid - id of the item
// name - where to store the name
// len - length of name
native DRP_GetItemName(ItemID,Name[],Len);

// Displays an MOTD window with the ItemID description
native DRP_ItemInfo(id,ItemID);

// Gets user item num
native DRP_GetUserItemNum(id,ItemID);
native DRP_SetUserItemNum(id,ItemID,num);

// Returns the amount of items a user has
native DRP_GetUserTotalItems(id);

// Will find an item based on search string, with the same method as FindJobId.
native DRP_FindItemID(const Searchstring[],Results[],Maxresults);

// Returns the ItemID based on a name (must be the EXACT name)
// Returns FAILED on not found
native DRP_FindItemID2(const ItemName[]);

// Stores all the users ItemID's in there inventory, in an array.
// This will return ONLY valid ItemID's
// Returns "Len" the amount of items the user has
native DRP_FetchUserItems(id,Result[]);

// Drops an "Item Package" on the ground with the given ItemID
// ItemID - the itemid of the item
// ItemNum - the item amount that will be in the "package"
// Origin[3] - origin of the "item package" entity 
// Returns FAILED on error
native DRP_DropItem(ItemID,ItemNum,const Float:Origin[3]);

// All new items created should be in this function.
forward DRP_RegisterItems();

stock DRP_FindItem(const searchstring[])
{
	new Results[1]
	DRP_FindItemID(searchstring,Results,1)
	
	return (Results[0] > 0) ? Results[0] : FAILED
}

stock DRP_GiveUserItem(id,itemid,num)
{
	if(!is_user_connected(id) || itemid < 0)
		return FAILED
	
	return DRP_SetUserItemNum(id,itemid,max(DRP_GetUserItemNum(id,itemid) + num,0));
}

stock DRP_TakeUserItem(id,itemid,num)
{
	if(!is_user_connected(id) || itemid < 0)
		return FAILED
	
	new CurrentAmount = DRP_GetUserItemNum(id,itemid);
	if(CurrentAmount < num) 
		return FAILED
	
	return DRP_SetUserItemNum(id,itemid,max(CurrentAmount - num,0));
}