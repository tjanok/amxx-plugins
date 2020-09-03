#include <amxmodx>
#include <amxmisc>
#include <DRP/DRPCore>

public plugin_init() 
{
	register_plugin("PxRP - Say Items","1.0","Hawk552")
	
	register_clcmd("say","CmdSay")
}

public PxRP_Init()
	DRP_AddCommand("say /item <itemname>","Allows usage of items in binds or chat")

public PxRP_Error(const Reason[])
	pause("d")

public CmdSay(id)
{
	if(!is_user_alive(id))
		return PLUGIN_CONTINUE
	
	static Args[128]
	read_args(Args,127)
	
	remove_quotes(Args)
	trim(Args)
	
	if(!equali(Args,"/item",5))
		return PLUGIN_CONTINUE
	
	static ItemName[64],Dummy[2]
	parse(Args,Dummy,1,ItemName,63)
	
	new Items[2],Num = DRP_FindItemID(ItemName,Items,2);
	switch(Num)
	{
		case 0 :
			client_print(id,print_chat,"[DRP] Item ^"%s^" does not exist.",ItemName)
		case 1 :
		{
			UseItem(id,Items[0]);
		}
		default :
		{
			client_print(id,print_chat,"[DRP] There is more than one item matching ^"%s^". You are using the first result.",ItemName)
			UseItem(id,Items[0])
		}
	}
	
	return PLUGIN_HANDLED
}

UseItem(id,ItemId)
{
	new ItemName[64]
	DRP_GetItemName(ItemId,ItemName,63)
	
	if(!DRP_GetUserItemNum(id,ItemId))
		return client_print(id,print_chat,"[DRP] You have no %ss.",ItemName)
	
	client_print(id,print_chat,"[DRP] Using %s.",ItemName)
	
	return DRP_ForceUseItem(id,ItemId,1);
}