#include <amxmodx>
#include <DRP/DRPCore>

new g_LoadHack[33]

new Handle:g_SqlHandle
new g_Query[256]

enum RANKS
{
	MEMBER = 0,
	RECRUITER,
	BANKER,
	FOUNDER
}

new const g_Ranks[RANKS][] =
{
	"Member",
	"Recruiter",
	"Banker",
	"Founder"
}

new Array:g_Organizations
new g_OrganizationsNum

// 0 = Array of org
// 1 = Salary of player in org
// 2 = Position in org (int)
new Array:g_UserOrg[33]

public plugin_init()
{
	// Main
	register_plugin("DRP - Organizations","0.1a","Drak");
	
	// Array
	g_Organizations = ArrayCreate();
}

public DRP_Error(const Reason[])
	pause("d");

public DRP_Init()
{
	g_SqlHandle = DRP_SqlHandle();
	SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle","CREATE TABLE IF NOT EXISTS `Organizations` (OrgName VARCHAR(36),OrgBank INT(12),FounderID VARCHAR(36),PRIMARY KEY(OrgName))");
	SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle","CREATE TABLE IF NOT EXISTS `OrganizationUsers` (AuthID VARCHAR(36),OrgName VARCHAR(36),Position INT(11),Salary INT(11),PRIMARY KEY(AuthID))");
	
	format(g_Query,255,"SELECT * FROM `Organizations`");
	SQL_ThreadQuery(g_SqlHandle,"FetchOrganizations",g_Query);
}
public DRP_HudDisplay(id,Hud)
{
	if(Hud != HUD_SEC)
		return
	
	if(g_UserOrg[id] != Invalid_Array)
	{
		new Name[36],Array:CurArray = ArrayGetCell(g_UserOrg[id],0);
		ArrayGetString(CurArray,0,Name,35);
		DRP_AddHudItem(id,HUD_SEC,"Organization:\nName: %s\nPosition: %s @ $%d",Name,g_Ranks[ArrayGetCell(g_UserOrg[id],2)],ArrayGetCell(g_UserOrg[id],1));
	}
}
/*==================================================================================================================================================*/
public client_authorized(id)
{
	if(is_user_bot(id))
		return PLUGIN_CONTINUE
	
	new AuthID[36]
	get_user_authid(id,AuthID,35);
	
	// Issue?
	// This will keep looping for invalid steamids - core will warn the player if they have an invalid steamid
	if(g_LoadHack[id]++ < 5)
		if(containi(AuthID,"STEAM_") == -1)
			return set_task(2.0,"client_authorized",id);
		
	g_LoadHack[id] = 0
	
	new Data[1]
	Data[0] = id
	
	format(g_Query,255,"SELECT * FROM `OrganizationUsers` WHERE `AuthID`='%s'",AuthID);
	SQL_ThreadQuery(g_SqlHandle,"FetchUserData",g_Query,Data,1);
	
	return PLUGIN_CONTINUE
}
public client_disconnect(id)
{
	g_LoadHack[id] = 0
}
/*==================================================================================================================================================*/
public FetchUserData(FailState,Handle:Query,const Error[],Errcode,const Data[],DataSize) 
{
	if(FailState != TQUERY_SUCCESS)
		return DRP_Log("[SQL ERROR] Query Failed. (Sent Error: %s)",Error);
	
	if(!SQL_NumResults(Query))
		return PLUGIN_CONTINUE
	
	new const id = Data[0]
	
	new OrgName[36],Temp[36],Found
	new Array:CurArray
	SQL_ReadResult(Query,1,Temp,35);
	
	server_print("before loop: %d",g_OrganizationsNum);
	
	for(new Count;Count < g_OrganizationsNum;Count++)
	{
		CurArray = ArrayGetCell(g_Organizations,Count);
		ArrayGetString(CurArray,0,OrgName,35);
		
		if(equali(Temp,OrgName))
		{
			Found = 1
			break
		}
	}
	
	if(!Found)
	{
		return PLUGIN_CONTINUE
	}
	
	g_UserOrg[id] = ArrayCreate();
	ArrayPushCell(g_UserOrg[id],CurArray);
	ArrayPushCell(g_UserOrg[id],SQL_ReadResult(Query,3));
	ArrayPushCell(g_UserOrg[id],SQL_ReadResult(Query,2));
	
	return PLUGIN_CONTINUE
}
public FetchOrganizations(FailState,Handle:Query,const Error[],Errcode,const Data[],DataSize) 
{
	if(FailState != TQUERY_SUCCESS)
		return DRP_Log("[SQL ERROR] Query Failed. (Sent Error: %s)",Error);
	
	if(!SQL_NumResults(Query))
		return PLUGIN_CONTINUE
	
	new Array:CurArray,Temp[36]
	while(SQL_MoreResults(Query))
	{
		CurArray = ArrayCreate(36);
		ArrayPushCell(g_Organizations,CurArray);
		g_OrganizationsNum++
		
		SQL_ReadResult(Query,0,Temp,35);
		ArrayPushString(CurArray,Temp);
		
		ArrayPushCell(CurArray,SQL_ReadResult(Query,1));
		
		SQL_ReadResult(Query,2,Temp,35);
		ArrayPushString(CurArray,Temp);
		
		SQL_NextRow(Query);
	}
	
	return PLUGIN_CONTINUE
}
public IgnoreHandle(FailState,Handle:Query,const Error[],Errcode,const Data[],DataSize) 
{
	if(FailState == TQUERY_CONNECT_FAILED)
		return DRP_Log("[SQL ERROR] Unable to connect to SQL Database. (Error: %s)",Error ? Error : "UNKNOWN");
	
	else if(FailState == TQUERY_QUERY_FAILED)
	{
		SQL_QueryError(Query,g_Query,255);
		return DRP_Log("[SQL ERROR] Query Failed. (Error: %s - Sent Error: %s)",g_Query,Error);
	}
	if(Errcode)
		return DRP_Log("[SQL ERROR] %s",Error);
	
	return PLUGIN_CONTINUE
}

public plugin_end()
{
	new Array:CurArray
	for(new Count;Count < g_OrganizationsNum;Count++)
	{
		CurArray = ArrayGetCell(g_Organizations,Count);
		if(CurArray != Invalid_Array)
			ArrayDestroy(Array:Count);
	}
	ArrayDestroy(g_Organizations);
}