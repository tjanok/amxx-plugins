#if defined _DRP_PLAYERINFO_INCLUDE
	#endinput
#endif
#define _DRP_PLAYERINFO_INCLUDE

#include <DRP/DRPCore>

#pragma reqlib "DRPPlayerInfo"

// This displays a menu to show/set there information.
native DRP_ShowPlayerInfoMenu(id);

// Returns the contact information from the 'Contact' enum (See DRPConst.inc)
// If blank, string will be NULL
native DRP_GetPlayerContactInfo(id,Contact:From,String[],Len);

// Set's the players contact information, this updates a TravTrie Array, along with a SQL Table
// FROM Handle must be one of the CONTCT_* defines/enum struct
native DRP_SetPlayerContactInfo(id,Contact:From,const String[]);

// A Quick-Access way to check if information is stored
// Intead of doing DRP_GetPlayerContactInfo
stock bool:DRP_IsPlayerInfoStored(id,Contact:From)
{
	new String[12]
	DRP_GetPlayerContactInfo(id,From,String,11);
	
	if(String[0])
		return true
	
	return false
}