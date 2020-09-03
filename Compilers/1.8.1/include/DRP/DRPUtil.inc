#if defined _DRP_UTIL_INCLUDE
	#endinput
#endif
#define _DRP_UTIL_INCLUDE

#include <amxmodx>

stock UTIL_RadiusMessage(Sender,Float:Dist,const Message[],any:...)
{
	new Float:SndOrigin[3],Float:RcvOrigin[3]
	pev(Sender,pev_origin,SndOrigin);
	
	new MessageV[128]
	vformat(MessageV,127,Message,4);
	
	new iPlayers[32],iNum,id
	get_players(iPlayers,iNum);
	for(new Count;Count<iNum;Count++)
	{
		id = iPlayers[Count]
		
		if(!is_user_alive(id))
			continue
		
		pev(id,pev_origin,RcvOrigin);
		
		if(get_distance_f(RcvOrigin,SndOrigin) <= Dist)
			client_print(id,print_chat,"%s",MessageV);
	}
}
