#if defined _DRPCHAT_INCLUDE
	#endinput
#endif

#define _DRPCHAT_INCLUDE

#include <DRP/DRPCore>

#pragma reqlib "DRPChat"

native DRP_AddChat(const param[] = "",const handler[]);
native DRP_AddTeamChat(const param[] = "",const handler[]);

// DRP_GetUserCRoom(id,Name[],Len);
// Returns FAILED if user is not in a room
// Name[] = Will be filled with the current name of the ChatRoom the user is in
native DRP_GetUserCRoom(id,Name[],Len);

stock DRP_RegisterChat(const param[] = "",const handler[],const description[])
{
	new Command[128]
	format(Command,127,"say %s",param);
	
	if(param[0])
		DRP_AddCommand(Command,description);

	DRP_AddChat(param,handler);
}

stock DRP_RegisterTeamChat(const param[] = "",const handler[],const description[])
{
	new Command[128]
	format(Command,127,"say_team %s",param);
	
	if(param[0])
		DRP_AddCommand(Command,description);

	DRP_AddTeamChat(param,handler);
}
