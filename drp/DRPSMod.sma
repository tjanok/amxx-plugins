#include <amxmodx>
#include <amxmisc>

#include <DRP/DRPCore>

enum
{
	S_BASIC = 0,
	S_COOKING,
	S_COMPUTER,
	S_LAW,
	S_FIGHTING,
	S_WEAPONS,
	S_DRUGS
}

new Array:g_UserSkillsArray[33]

new g_Cache[512]
new Handle:g_SqlHandle

public plugin_init()
{
	// Main
	register_plugin("DRP - SMod","0.1a","Drak");
	
	// Commands
	DRP_RegisterCmd("drp_setskill","CmdSetSkill","(ADMIN) <target> <skill name> <level> - set's a users skill level");
}

public DRP_Init()
{
	new ConfigFile[128]
	DRP_GetConfigsDir(ConfigFile,127);
	
	add(ConfigFile,127,"/SM_Settings.cfg");
	
	if(!file_exists(ConfigFile))
		write_file(ConfigFile,";This file contains any settings (Such as CVARS and Origins) for SkillsMod");
	
	g_SqlHandle = DRP_SqlHandle();
	
	format(g_Cache,511,"CREATE TABLE IF NOT EXISTS `SkillsMod` (SteamID VARCHAR(36),SBasic INT(11),SCooking INT(11),SComputer INT(11),SLaw INT(11),SFighting INT(11),SWeapons INT(11),SDrugs INT(11),Flags VARCHAR(12), PRIMARY KEY (SteamID))");
	SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",g_Cache);
}
/*==================================================================================================================================================*/
public DRP_Error(const Reason[])
	pause("d");

/*==================================================================================================================================================*/
public client_authorized(id)
{
	new Data[1]
	Data[0] = id
	
	format(g_Cache,511,"SELECT * FROM `SkillsMod`");
	SQL_ThreadQuery(g_SqlHandle,"FetchPlayerData",g_Cache,Data,1);
}
public client_disconnect(id)
{
	if(g_UserSkillsArray[id] != Invalid_Array)
		ArrayDestroy(g_UserSkillsArray[id]);
	
	g_UserSkillsArray[id] = Invalid_Array
}
public FetchPlayerData(FailState,Handle:Query,const Error[],Errcode,const Data[],DataSize)
{
	if(FailState != TQUERY_SUCCESS)
		return DRP_ThrowError(0,"QUERY FAILED (Error: %s)",Error[0] ? Error : "UNKNOWN");
	
	new const id = Data[0]
	if(!id)
		return PLUGIN_CONTINUE
	
	// Always create the array
	g_UserSkillsArray[id] = ArrayCreate();
	
	if(!SQL_NumResults(Query))
	{
		// Setup
		ArrayPushCell(g_UserSkillsArray[id],0); // S_BASIC
		ArrayPushCell(g_UserSkillsArray[id],0); // S_COOKING
		ArrayPushCell(g_UserSkillsArray[id],0); // S_COMPUTER
		ArrayPushCell(g_UserSkillsArray[id],0); // S_LAW
		ArrayPushCell(g_UserSkillsArray[id],0); // S_FIGHTING
		ArrayPushCell(g_UserSkillsArray[id],0); // S_WEAPONS
		ArrayPushCell(g_UserSkillsArray[id],0); // S_DRUGS
		
		return PLUGIN_CONTINUE
	}
	
	ArrayPushCell(g_UserSkillsArray[id],SQL_ReadResult(Query,1));
	ArrayPushCell(g_UserSkillsArray[id],SQL_ReadResult(Query,2));
	ArrayPushCell(g_UserSkillsArray[id],SQL_ReadResult(Query,3));
	ArrayPushCell(g_UserSkillsArray[id],SQL_ReadResult(Query,4));
	ArrayPushCell(g_UserSkillsArray[id],SQL_ReadResult(Query,5));
	ArrayPushCell(g_UserSkillsArray[id],SQL_ReadResult(Query,6));
	ArrayPushCell(g_UserSkillsArray[id],SQL_ReadResult(Query,7));
	
	return PLUGIN_CONTINUE
}
/*==================================================================================================================================================*/
// drp_setskill <name> <skill> <level>
public CmdSetSkill(id,level,cid)
{
	if(!DRP_CmdAccess(id,cid,2))
		return PLUGIN_HANDLED
	
	new Arg[36]
	read_argv(1,Arg,35);
	
	new Target = cmd_target(id,Arg,CMDTARGET_ALLOW_SELF);
	if(!Target)
		return PLUGIN_HANDLED
	
	read_argv(2,Arg,35);
	
	if(equali(Arg,"reset"))
	{
		get_user_name(Target,Arg,35);
		
		client_print(id,print_console,"[DRP] All of %s's skills have been set to zero.",Arg);
		client_print(Target,print_chat,"[DRP] All your skills have been reset.");
		
		get_user_authid(Target,Arg,35);
		
		format(g_Cache,511,"UPDATE `SkillsMod` SET `SBasic`='0',`SCooking`='0',`SComputer`='0',`SLaw`='0',`SFighting`='0',`SWeapons`='0',`SDrugs`='0',`Flags`='' WHERE `SteamID`='%s'",Arg);
		SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",g_Cache);
		
		for(new Count;Count < 8;Count++)
			ArraySetCell(g_UserSkillsArray[Target],Count,0);
		
		return PLUGIN_HANDLED
	}
	
	read_argv(3,Arg,35);
	
	new const Num = clamp(str_to_num(Arg),0,100);
	if(Num < 1)
	{
		client_print(id,print_console,"[DRP] Level must be higher or equal to one. Max of 100");
		return PLUGIN_HANDLED
	}
	
	read_argv(2,Arg,35);
	
	// Cooking and Computer both c's
	// Can't use a switch ):
	
	if(equali(Arg,"basic"))
	{
		client_print(id,print_console,"[DRP] The skill ^"Basic^" set to level: %d",Num);
		UTIL_SQLSetSkill(Target,S_BASIC,Num);
	}
	else if(equali(Arg,"cooking"))
	{
		client_print(id,print_console,"[DRP] The skill ^"Cooking^" set to level %d",Num);
		UTIL_SQLSetSkill(Target,S_COOKING,Num);
	}
	else if(equali(Arg,"computer"))
	{
		client_print(id,print_console,"[DRP] The skill ^"Computer^" set to level %d",Num);
		UTIL_SQLSetSkill(Target,S_COMPUTER,Num);
	}
	else if(equali(Arg,"law"))
	{
		client_print(id,print_console,"[DRP] The skill ^"Law^" set to level %d",Num);
		UTIL_SQLSetSkill(Target,S_LAW,Num);
	}
	else if(equali(Arg,"fighting"))
	{
		client_print(id,print_console,"[DRP] The skill ^"Fighting^" set to level %d",Num);
		UTIL_SQLSetSkill(Target,S_FIGHTING,Num);
	}
	else if(equali(Arg,"weapons"))
	{
		client_print(id,print_console,"[DRP] The skill ^"Weapons^" set to level %d",Num);
		UTIL_SQLSetSkill(Target,S_WEAPONS,Num);
	}
	else if(equali(Arg,"drugs"))
	{
		client_print(id,print_console,"[DRP] The skill ^"Drugs^" set to level %d",Num);
		UTIL_SQLSetSkill(Target,S_DRUGS,Num);
	}
	else
	{
		client_print(id,print_console,"[DRP] Invalid Skill (%s). The list is:",Arg);
		client_print(id,print_console,"^"basic^"^n^"cooking^"^n^"computer^"^n^"law^"^n^"fighting^"^n^"weapons^"^n^"drugs^"");
	}
	return PLUGIN_HANDLED
}
/*==================================================================================================================================================*/
public plugin_natives()
{
	register_library("DRPSMod");
	register_native("DRP_SetUserSkill","_DRP_SetUserSkill");
	register_native("DRP_GetUserSkill","_DRP_GetUserSkill");
	register_native("DRP_ShowUserSkills","_DRP_ShowUserSkills");
}
public _DRP_SetUserSkill(Plugin,Params)
{
	if(Params != 3)
		return DRP_ThrowError(0,"Invalid Params - Found: %d - Needed 3",Params);
	
	new const id = get_param(1),Skill = get_param(2),Level = clamp(get_param(3),0,100);
	if(!is_user_connected(id))
		return DRP_ThrowError(0,"User not connected (%d)",id);
	
	return UTIL_SQLSetSkill(id,Skill,Level);
}
public _DRP_GetUserSkill(Plugin,Params)
{
	if(Params != 2)
		return DRP_ThrowError(0,"Invalid Params - Found: %d - Needed 2",Params);
	
	new const id = get_param(1),Skill = get_param(2);
	if(!is_user_connected(id))
		return DRP_ThrowError(0,"User not connected (%d)",id);
	
	return ArrayGetCell(g_UserSkillsArray[id],Skill);
}
public _DRP_ShowUserSkills(Plugin,Params)
{
	if(Params != 2)
		return DRP_ThrowError(0,"Invalid Params - Found: %d - Needed 2",Params);
	
	new const id = get_param(1),Target = get_param(2);
	if(!is_user_connected(id))
		return DRP_ThrowError(0,"User not connected (%d)",id);
	
	return ViewSkills(id,Target);
}
/*==================================================================================================================================================*/
// UTIL / Basic Functions Below

// Set's the id's skill, to the given level then 
// updates the SQL
bool:UTIL_SQLSetSkill(const id,const Skill,const LevelSent)
{
	static AuthID[36]
	get_user_authid(id,AuthID,35);
	
	new Level = clamp(LevelSent,0,100);
	
	if(containi(AuthID,"LAN") != -1 || containi(AuthID,"PENDING") != -1)
		return false
	
	switch(Skill)
	{
		case S_BASIC: formatex(g_Cache,511,"INSERT INTO `SkillsMod` VALUES('%s','%d','0','0','0','0','0','0') ON DUPLICATE KEY UPDATE `SBasic`='%d'",AuthID,Level,Level); 
		case S_COOKING: formatex(g_Cache,511,"INSERT INTO `SkillsMod` VALUES('%s','0','%d','0','0','0','0','0') ON DUPLICATE KEY UPDATE `SCooking`='%d'",AuthID,Level); 
		case S_COMPUTER: formatex(g_Cache,511,"INSERT INTO `SkillsMod` VALUES('%s','0','0','%d','0','0','0','0') ON DUPLICATE KEY UPDATE `SComputer`='%d'",AuthID,Level,Level); 
		case S_LAW: formatex(g_Cache,511,"INSERT INTO `SkillsMod` VALUES('%s','0','0','0','%d','0','0','0') ON DUPLICATE KEY UPDATE `SLaw`='%d'",AuthID,Level,Level); 
		case S_FIGHTING: formatex(g_Cache,511,"INSERT INTO `SkillsMod` VALUES('%s','0','0','0','0','%d','0','0') ON DUPLICATE KEY UPDATE `SFighting`='%d'",AuthID,Level,Level); 
		case S_WEAPONS: formatex(g_Cache,511,"INSERT INTO `SkillsMod` VALUES('%s','0','0','0','0','0','%d','0') ON DUPLICATE KEY UPDATE `SWeapons`='%d'",AuthID,Level,Level); 
		case S_DRUGS: formatex(g_Cache,511,"INSERT INTO `SkillsMod` VALUES('%s','0','0','0','0','0','0','%d') ON DUPLICATE KEY UPDATE `SDrugs`='%d'",AuthID,Level,Level); 
		
		default: 
			return false
	}
	
	ArraySetCell(g_UserSkillsArray[id],Skill,Level);
	SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",g_Cache);
	
	return true
}

ViewSkills(const id,const Target)
{
	if(!is_user_connected(Target) || !is_user_alive(id))
		return FAILED
	
	new plName[33]
	get_user_name(Target,plName,32);
	
	new Pos
	Pos += formatex(g_Cache[Pos],511 - Pos,"[%s]^n^n",plName);
	
	new const Array:SArray = g_UserSkillsArray[Target]
	
	Pos += formatex(g_Cache[Pos],511 - Pos,"Basic: %d^n",ArrayGetCell(SArray,S_BASIC));
	Pos += formatex(g_Cache[Pos],511 - Pos,"Cooking: %d^n",ArrayGetCell(SArray,S_COOKING));
	Pos += formatex(g_Cache[Pos],511 - Pos,"Computer: %d^n",ArrayGetCell(SArray,S_COMPUTER));
	Pos += formatex(g_Cache[Pos],511 - Pos,"Law: %d^n",ArrayGetCell(SArray,S_LAW));
	Pos += formatex(g_Cache[Pos],511 - Pos,"Fighting: %d^n",ArrayGetCell(SArray,S_FIGHTING));
	Pos += formatex(g_Cache[Pos],511 - Pos,"Weapons: %d^n",ArrayGetCell(SArray,S_WEAPONS));
	Pos += formatex(g_Cache[Pos],511 - Pos,"Drugs: %d^n",ArrayGetCell(SArray,S_DRUGS));
	
	Pos += formatex(g_Cache[Pos],511 - Pos,"^nSkills are based from #0-100^nIf you need help, type ^"/skills^" and click on help.");
	show_motd(id,g_Cache,"Skills");
	
	return SUCCEEDED
}

public IgnoreHandle(FailState,Handle:Query,const Error[],Errcode,const Data[],DataSize) 
{
	if(FailState != TQUERY_SUCCESS)
		return DRP_ThrowError(0,"QUERY ERROR (ErroR: %s)",Error[0] ? Error : "UNKNOWN");
	
	return PLUGIN_CONTINUE
}	