#include <amxmodx>
#include <amxmisc>
#include <DRP/DRPCore>

#define MAX_TIPS 33

new Array:g_ToolTips
new Array:g_UserToolTips[33]

new g_TipsDir[256]
new g_Query[128]

new Handle:g_SqlHandle

public plugin_natives()
{
	g_ToolTips = ArrayCreate(MAX_TIPS);
	for(new Count;Count < 32;Count++)
		g_UserToolTips[Count] = ArrayCreate(33);
	
	register_native("DRP_RegToolTip","_DRP_RegToolTip");
	register_native("DRP_ShowToolTip","_DRP_ShowToolTip");
	
	get_localinfo("amxx_configsdir",g_TipsDir,255);
	add(g_TipsDir,255,"/DRP/ToolTips");
	
	if(!dir_exists(g_TipsDir))
		mkdir(g_TipsDir);
}

public plugin_init()
{
	// Main
	register_plugin("DRP - Tool Tips","0.1a","Drak");
	
	// Commands (dev)
	DRP_RegisterCmd("drp_showtip","CmdShowTip","(ADMIN) <tip name> <target> - Forces a tip to be shown to a player");
}

public DRP_Error(const Reason[])
	pause("d");

public DRP_Init()
{
	g_SqlHandle = DRP_SqlHandle();
	SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle","CREATE TABLE IF NOT EXISTS `PlayerTips` (SteamIDTipName VARCHAR(64), PRIMARY KEY (SteamIDTipName))");
}

// To many things load on client_authorized()
public client_authorized(id)
	set_task(3.0,"_Load",id);

public _Load(id)
{
	new AuthID[36],Data[1]
	get_user_authid(id,AuthID,35);
	
	ArrayClear(g_UserToolTips[id]);
	Data[0] = id
	
	if(!AuthID[0] || containi(AuthID,"PENDING") != -1)
		return
	
	formatex(g_Query,127,"SELECT * FROM `PlayerTips` WHERE `SteamIDTipName` LIKE '%s|%%'",AuthID,Data,1);
	SQL_ThreadQuery(g_SqlHandle,"LoadPlayerTips",g_Query);
}

public CmdShowTip(id,level,cid)
{
	if(!DRP_CmdAccess(id,cid,3))
		return PLUGIN_HANDLED
	
	new Arg[33],Arg2[32]
	read_argv(2,Arg,32);
	read_argv(1,Arg2,32);
	
	new Target = cmd_target(id,Arg,CMDTARGET_ALLOW_SELF);
	if(!Target)
		return PLUGIN_HANDLED
	
	if(DRP_ShowToolTip(Target,Arg2,1))
		client_print(id,print_console,"[DRP] The tip was shown successfully.");
	else
		client_print(id,print_console,"[DRP] The tip was shown NOT successfully; that tip name was invalid");
	
	return PLUGIN_HANDLED
}
/*==================================================================================================================================================*/
public _DRP_ShowToolTip(Plugin,Params)
{
	if(Params != 3)
	{
		DRP_ThrowError(0,"Parameters do not match. Expected: 3, Found: %d",Plugin,Params);
		return FAILED
	}
	
	new id = get_param(1),Force = get_param(3);
	get_string(2,g_Query,127);
	
	if(!is_user_connected(id))
	{
		DRP_ThrowError(0,"User not connected: %d",Plugin,id);
		return FAILED
	}
	
	new Size = ArraySize(g_UserToolTips[id]);
	new ArrayName[33]
	
	if(!Force)
	{
		// Check if we have "seen" this tip before
		for(new Count;Count < Size;Count++)
		{
			ArrayGetString(g_UserToolTips[id],Count,ArrayName,32);
			if(equali(ArrayName,g_Query))
				return -1
		}
	}
	
	new Array:CurArray
	Size = ArraySize(g_ToolTips);
	
	for(new Count;Count < Size;Count++)
	{
		CurArray = ArrayGetCell(g_ToolTips,Count);
		ArrayGetString(CurArray,0,ArrayName,32);
		
		if(equali(ArrayName,g_Query))
		{
			if(!Force)
			{
				new AuthID[36]
				get_user_authid(id,AuthID,35);
				
				ArrayPushString(g_UserToolTips[id],g_Query);
				
				formatex(g_Query,127,"INSERT INTO `PlayerTips` VALUES('%s|%s')",AuthID,ArrayName);
				SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",g_Query);
			}
			
			ArrayGetString(CurArray,1,ArrayName,32);
			formatex(g_Query,127,"%s/%s",g_TipsDir,ArrayName);
			show_motd(id,g_Query,"DRP Help Tip");
			
			return SUCCEEDED
		}
	}
	
	return FAILED
}

public _DRP_RegToolTip(Plugin,Params)
{
	if(Params != 2)
	{
		DRP_ThrowError(0,"Parameters do not match. Expected: 2, Found: %d",Plugin,Params);
		return FAILED
	}
	
	
	new Name[35],FileName[35]
	get_string(1,Name,35);
	get_string(2,FileName,35);
	
	if(strlen(Name) > 32 || strlen(FileName) > 32)
	{
		DRP_ThrowError(0,"Tooltip name or file name to long, max of 32 chars");
		return FAILED
	}
	
	new ActualFile[256]
	formatex(ActualFile,255,"%s/%s",g_TipsDir,FileName);
	
	if(!file_exists(ActualFile))
	{
		DRP_ThrowError(0,"Unable to find tip file. (%s)",ActualFile);
		server_print("got here");
		return FAILED
	}
	
	server_print("%s asdas",ActualFile);
	log_amx("test");
	DRP_ThrowError(0,"test");
	
	new const Size = ArraySize(g_ToolTips);
	if(Size + 1 >= MAX_TIPS)
	{
		DRP_ThrowError(0,"Maximum amount of tips loaded (max: %d)",MAX_TIPS);
		return FAILED
	}
	
	new Array:CurArray
	new ArrayName[33]
	
	for(new Count;Count < Size;Count++)
	{
		CurArray = ArrayGetCell(g_ToolTips,Count);
		ArrayGetString(CurArray,0,ArrayName,32);
		
		if(equali(Name,ArrayName))
		{
			get_plugin(ArrayGetCell(CurArray,2),Name,35);
			DRP_ThrowError(0,"Tooltip name (%s) already exists, inside plugin: %s",ArrayName,Name);
			return FAILED
		}
	}
	
	new Array:NewArray = ArrayCreate(33);
	ArrayPushCell(g_ToolTips,NewArray);
	
	ArrayPushString(NewArray,Name);
	ArrayPushString(NewArray,FileName);
	ArrayPushCell(NewArray,Plugin);
	
	return SUCCEEDED
}

public plugin_end()
{
	for(new Count;Count < 32;Count++)
		ArrayDestroy(g_UserToolTips[Count]);
	
	ArrayDestroy(g_ToolTips);
}

public IgnoreHandle(FailState,Handle:Query,const Error[],Errcode,const Data[],DataSize)
{
	if(FailState != TQUERY_SUCCESS)
		return DRP_ThrowError(0,"Error in query (%s)",Error);
	
	return PLUGIN_CONTINUE
}

public LoadPlayerTips(FailState,Handle:Query,const Error[],Errcode,const Data[],DataSize)
{
	if(FailState != TQUERY_SUCCESS)
		return DRP_ThrowError(0,"Error in query (%s)",Error);
	
	if(!SQL_NumResults(Query))
		return PLUGIN_CONTINUE
	
	new const id = Data[0]
	new Temp[2][36]
	
	while(SQL_MoreResults(Query))
	{
		SQL_ReadResult(Query,0,g_Query,127);
		strtok(g_Query,Temp[0],35,Temp[1],35,'|',1);
		
		ArrayPushString(g_UserToolTips[id],Temp[1]);
		SQL_NextRow(Query);
	}
	
	return PLUGIN_CONTINUE
}
// array
// 0 = name (string)
// 1 = filename (string)
// 2 = plugin_id (cell)