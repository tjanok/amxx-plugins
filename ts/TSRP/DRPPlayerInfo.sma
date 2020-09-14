/*
* DRPPlayerInfo.sma
* -------------------------------------
* Author(s):
* Drak - Main Author
* -------------------------------------
*/

#include <amxmodx>
#include <DRP/DRPCore>

new Class:g_PlayerInfo[33]
new const g_PlayerInfoTable[] = "PlayerInfo"

public plugin_natives()
{
	register_library("DRPPlayerInfo");
	
	register_native("DRP_SetPlayerContactInfo","_DRP_SetPlayerContactInfo");
	register_native("DRP_GetPlayerContactInfo","_DRP_GetPlayerContactInfo");
}
/*
native DRP_GetPlayerContactInfo(id,Contact:From,String[],Len);
native DRP_SetPlayerContactInfo(id,Contact:From,const String[]);
*/
public _DRP_SetPlayerContactInfo(Plugin,Params)
{
	if(Params != 3)
	{
		DRP_ThrowError(0,"Parameters do not match. Expected: 2, Found: %d",Params);
		return FAILED
	}
	new id = get_param(1);
	if(!is_user_connected(id))
	{
		DRP_ThrowError(0,"User not connected: %d",id);
		return FAILED
	}
	
	new String[64]
	get_string(3,String,63);
	
	switch(get_param(2))
	{
		case CONTCT_AIM:
			DRP_ClassSetString(g_PlayerInfo[id],"cAIM",String)
		
		default:
		{
			DRP_ThrowError(0,"Invalid 'FROM' Handle. Please check the 'CONTACT' enum");
			return FAILED
		}
	}
	return SUCCEEDED
}
public _DRP_GetPlayerContactInfo(Plugin,Params)
{
	if(Params != 4)
	{
		DRP_ThrowError(0,"Parameters do not match. Expected: 4, Found: %d",Params);
		return FAILED
	}
	
	new id = get_param(1),Len = get_param(4);
	if(!is_user_connected(id))
	{
		DRP_ThrowError(0,"User not connected: %d",id);
		return FAILED
	}
	
	new String[64]
	switch(get_param(2))
	{
		case CONTCT_AIM:
			DRP_ClassGetString(g_PlayerInfo[id],"cAIM",String,Len);
		
		default:
		{
			DRP_ThrowError(0,"Invalid 'FROM' Handle. Please check the CONTACT enum");
			return FAILED
		}
	}
	
	if(String[0])
		set_string(3,String,Len);
	
	return SUCCEEDED
}
/*==================================================================================================================================================*/
public plugin_init()
{
	register_plugin("DRP - Player About Me","0.1a","Drak");
}
public DRP_Error(const Reason[])
	pause("d");

/*==================================================================================================================================================*/
public client_authorized(id)
{
	new AuthID[36],Data[10]
	
	get_user_authid(id,AuthID,35);
	num_to_str(id,Data,9);
	
	DRP_ClassLoad(AuthID,"LoadHandle",Data,g_PlayerInfoTable);
}
public LoadHandle(Class:Class_id,const Class[],Data[])
{
	new id = str_to_num(Data);
	g_PlayerInfo[id] = Class_id
}
/*==================================================================================================================================================*/