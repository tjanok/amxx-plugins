#if defined _DRP_PROPERTIES_INCLUDE
#endinput
#endif
#define _DRP_PROPERTIES_INCLUDE

#include <drp/drp_core>

// Checks to be sure a property is valid.
native DRP_ValidPropertyName(const InternalName[]);

// Checks to be sure a property is valid.
native DRP_ValidProperty(Property);

// Checks to be sure a door is valid.
native DRP_ValidDoorName(const Targetname[] = "",EntID = 0);

// Checks to be sure a door is valid.
native DRP_ValidDoor(Door);

// Returns the amount of property's
native DRP_PropertyNum();

// Returns the amount of doors (connected to property's)
native DRP_DoorNum();

// Adds a property.
// const internalname[] - what it will be called inside ARP
// const externalname[] - what it appears as to players
// const ownername[] - owner name as it appears on the door
// const ownerauth[] - steamid of the owner
// price - how much it costs (0 to disable)
// profit - how much money the property has made
native DRP_AddProperty(const internalname[],const externalname[],const ownername[],const ownerauth[],price,const AccessStr[],Profit,Locked);

// Removes a property.
// property - the property to remove
native DRP_DeleteProperty(Property);

// Adds a door.
// NOTE: You only need to specify targetname OR entid, not both
// const targetname[] - targetname of the door
// entid - entid of the door
// const internalname[] - internal name of the door
// return: 0 = Door Already Exists -1 = Property Does not Exist > 1 Door Num
native DRP_AddDoor(const TargetName[],EntID=0,const InternalName[]);

// Removes a door.
// door - the door to remove
native DRP_DeleteDoor(door);

native DRP_PropertyMatch(const TargetName[] = "",EntID = 0,const InternalName[] = "");
native DRP_DoorMatch(const TargetName[] = "",EntID = 0);

native DRP_PropertyGetInternalName(Property,ExternalName[],Len);
native DRP_PropertyGetExternalName(Property,ExternalName[],Len);
native DRP_PropertySetExternalName(Property,const ExternalName[]);

native DRP_PropertyGetOwnerName(Property,OwnerName[],Len);
native DRP_PropertySetOwnerName(Property,OwnerName[]);
native DRP_PropertyGetOwnerAuth(Property,OwnerAuth[],Len);
native DRP_PropertySetOwnerAuth(Property,OwnerAuth[]);

native DRP_PropertyAddAccess(Property,const AuthID[]);
native DRP_PropertyRemoveAccess(Property,const AuthID[]);

native DRP_PropertyGetProfit(Property);
native DRP_PropertySetProfit(Property,Profit);
native DRP_PropertyGetPrice(Property);
native DRP_PropertySetPrice(Property,Price);

// This is the message that shows when a user is facing a property
native DRP_PropertySetMessage(Property,const String[]);

// This is the message that shows when a user is facing a property
native DRP_PropertyGetMessage(Property,String[],Len);

native DRP_PropertyGetLocked(Property);
native DRP_PropertySetLocked(Property,Locked);

native DRP_PropertyDoorGetLocked(EntID);
native DRP_PropertyDoorSetLocked(EntID,Locked);

// Returns the Property's Access Letter (in INT Form)
native DRP_PropertyGetAccess(Property);

stock DRP_GiveKey(Property,id)
{
	new AuthID[36]
	get_user_authid(id,AuthID,35)
	
	DRP_PropertyAddAccess(Property,AuthID);
}

stock DRP_TakeKey(Property,id)
{
	new AuthID[36]
	get_user_authid(id,AuthID,35)
	
	DRP_PropertyRemoveAccess(Property,AuthID);
}

stock DRP_PropertyGetOwner(Property)
{
	new AuthID[36]
	DRP_PropertyGetOwnerAuth(Property,AuthID,35);
	
	new PlayerAuthID[36],iPlayers[32],iNum,Index
	get_players(iPlayers,iNum);
	
	for(new Count;Count < iNum;Count++)
	{
		Index = iPlayers[Count]
		get_user_authid(Index,PlayerAuthID,35);
		
		if(equali(AuthID,PlayerAuthID))
			return Index
	}
	
	return FAILED
}