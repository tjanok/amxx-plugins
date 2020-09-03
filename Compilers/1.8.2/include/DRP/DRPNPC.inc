#if defined _DRPNpc_included
	#endinput
#endif

#define _DRPNpc_included

#pragma reqlib "DRPNPC"

#include <DRP/DRPCore>

// Registers an NPC or zone. Note that this actually creates
// the NPC for you and sets it up as well. If zone is set to 1,
// the NPC will have no model, and anyone passing through the area will see
// the message explaining how to talk to the NPC. This is useful for ATMs,
// or NPCs that already exist in the map that you don't want to strip out.
// name[] - name of the NPC, ex. "Edeka Cashier"
// Float:origin[3] - where to spawn the NPC
// Float:angle - which direction it should face (0.0-180.0)
// model[] - the model the NPC should use (if not a zone)
// handler[] - function to call when a user presses "e" next to it
// zone - whether or not the NPC is a zone or human-looking figure
// property[] - the internal name of the property that it belongs to
native DRP_RegisterNPC(const Name[],Float:origin[3],Float:angle,const Model[],const Handler[],zone = 0,const property[] = "",SkipTrace=0);

// This will return the user's currently used NPC
// Returns the NPC Entity Index else FAILED
// native DRP_GetUserNpc(id);

stock DRP_IsNPC(const Ent)
{
	if(!Ent)
		return FAILED
	
	new Classname[18]
	pev(Ent,pev_classname,Classname,17);
	
	if(equal(Classname,g_szNPCName))
		return SUCCEEDED
	
	return FAILED
}

// npcentid is returned by DRP_GetUserNPC()
stock DRP_NPCDistance(id,npcentid,showmessage = 1,Float:Distance = 100.0)
{
	if(!is_user_alive(id) || !npcentid)
		return FAILED
	
	new Float:plOrigin[3],Float:NpcOrigin[3]
	pev(id,pev_origin,plOrigin);
	pev(npcentid,pev_origin,NpcOrigin);

	// Do not change the value 100.0
	if(get_distance_f(plOrigin,NpcOrigin) > Distance)
	{
		if(showmessage)
			client_print(id,print_chat,"[DRP] You have moved to far from the NPC.");
		
		return FAILED
	}
	
	return SUCCEEDED
}

// Return the property pointer 
// to use with natives such as: DRP_PropertyGetAccess();
stock DRP_GetNpcProperty(const npcentindex)
{
	if(!DRP_IsNPC(npcentindex))
		return -1
	
	new Property[36],Index
	pev(npcentindex,pev_noise2,Property,35);
	
	if(!(Index = DRP_PropertyMatch(_,_,Property)))
		return -1
	
	return Index
}

stock DRP_GetNpcName(const npcentindex,String[],Len)
{
	if(!DRP_IsNPC(npcentindex))
		return -1
	
	pev(npcentindex,pev_noise1,String,Len);
	return SUCCEEDED
}