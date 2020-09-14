#include <amxmodx>
#include <DRP/DRPCore>

#define NUM_POTS 3

enum
{
	PRIMARY = 0,
	SECONDARY,
	RESERVE
}

// This will virtually hold all the money in the world
// If this runs dry, we're gonnna have problem
new g_WorldEconomy[NUM_POTS]
new bool:g_EconomyUpdate

new g_Query[256]
new g_LogDir[128]

new Handle:g_SqlHandle

// CVars
new p_TexPercent

public DRP_Init()
{
	// Main
	register_plugin("DRP - Economy","0.1a","Drak");
	
	// Commands
	//register_clcmd("drp_l","cmde");
	
	// Cvars
	p_TexPercent = register_cvar("DRP_EconomyTax","0.06");
	
	// Events
	DRP_RegisterEvent("Player_BuyItem","Event_PlayerBuyItem");
	DRP_RegisterEvent("Core_Save","Event_SaveData");
	
	// SQL
	g_SqlHandle = DRP_SqlHandle();
	
	format(g_Query,255,"CREATE TABLE IF NOT EXISTS `Economy` (PrimaryPot INT(11),Secondary INT(11),Reserve INT(11))");
	SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",g_Query);
	
	format(g_Query,255,"SELECT * FROM `Economy`");
	SQL_ThreadQuery(g_SqlHandle,"LoadPotHandle",g_Query);
	
	get_localinfo("amxx_logs",g_LogDir,127);
	format(g_LogDir,127,"%s/DRP/Economy",g_LogDir);
	
	if(!dir_exists(g_LogDir))
		mkdir(g_LogDir);
}
/*==================================================================================================================================================*/
// This event is only called when buying items from generic NPC's
// Everytime, there money is taken from there WALLET only
public Event_PlayerBuyItem(const Name[],const Data[])
{
	new id = Data[0],ItemID = Data[1],Total = Data[2]
	
	// The lowest the tax can go should be 6%
	// To even be a dollar it needs to be over 15 or so, but let's make it 20
	if(Total < 20)
		return PLUGIN_CONTINUE
	
	new Tax = floatround(get_pcvar_float(p_TexPercent) * Total),TotalPrice = (Tax + Total)
	
	if(DRP_GetUserWallet(id) < TotalPrice)
	{
		client_print(id,print_chat,"[DRP] You are unable to afford this item(s), with sales tax included. (Total (With Tax): $%d",TotalPrice);
		return PLUGIN_HANDLED
	}
	
	return PLUGIN_CONTINUE
}
public Event_SaveData()
{
	if(!g_EconomyUpdate)
		return
	
	format(g_Query,255,"UPDATE `Economy` SET `Primary`='%d',`Secondary`='%d',`Reserve`='%d',`Loans`='%d',`Reserve`='%d'",
	g_WorldEconomy[PRIMARY],g_WorldEconomy[SECONDARY],g_WorldEconomy[RESERVE]);
	SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",g_Query);
	
	g_EconomyUpdate = false
}
/*==================================================================================================================================================*/
public CmdEconInfo(id,cid)
{
	if(!DRP_CmdAccess(id,cid,1))
		return PLUGIN_HANDLED
	
	return PLUGIN_HANDLED
}
public CmdEditPot(id,cid)
{
	if(!DRP_CmdAccess(id,cid,1))
		return PLUGIN_HANDLED
	
	return PLUGIN_HANDLED
}
/*==================================================================================================================================================*/
RunTasks()
{
}
/*==================================================================================================================================================*/
// Quick Functions
//
// ----
// ReserveTransfer();
// Transfers all the money from the reserve into the main pot
// logs in detail.
// ----
// Returns how much money was Transferred
ReserveTransfer()
{
	new const Total = g_Pots[RESERVE],PotBefore = g_Pots[MAIN_POT]
	if(!Total)
		return 0
	
	g_Pots[RESERVE] = 0
	g_Pots[MAIN_POT] += Total
	
	// This is very important - so save now
	format(g_Query,255,"UPDATE `Economy` SET `Main`='%d',`Reserve`='%d'",g_Pots[MAIN_POT],0);
	SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",g_Query);
	
	Log("Transferred money from reserve ($%d) into the main pot ($%d) - Totaling: $%d (Main Pot)",Total,PotBefore,g_Pots[MAIN_POT]);
	return Total
}
// ----
// Log()
// Logs into a file, with MONTH/DATE/YEAR.txt - logs/drp/economy
// 
// We don't use "DRP_Log" because I would like to save the file into /economy/
// ----
Log(const Message[],any:...)
{
	static File[128],Date[26]
	get_time("%m-%d-%Y",Date,25);
	
	formatex(File,1277,"%s/%s.log",g_LogDir,Date);
	
	vformat(g_Query,255,Message,2);
	return log_to_file(File,"[Economy Log] %s",g_Query);
}

PotChanged()
	g_EconomyUpdate = true
	
/*==================================================================================================================================================*/
public LoadPotHandle(FailState,Handle:Query,const Error[],Errcode,const Data[],DataSize) 
{
	if(FailState != TQUERY_SUCCESS || Errcode)
		return DRP_ThrowError(0,"SQL Error (Error: %s)",0,Error ? Error : "UNKNOWN");
	
	// This should never get here.
	if(!SQL_NumResults(Query))
		return PLUGIN_HANDLED
	
	Log("Economy Loaded. Pots: Primary: $%d - Secondary: $%d - Reserve: $%d",
	g_WorldEconomy[PRIMARY],g_WorldEconomy[SECONDARY],g_WorldEconomy[RESERVE])
	
	return PLUGIN_CONTINUE
}
public IgnoreHandle(FailState,Handle:Query,const Error[],Errcode,const Data[],DataSize) 
{
	if(FailState != TQUERY_SUCCESS || Errcode)
		return DRP_ThrowError(0,"SQL Error (Error: %s)",Error[0] ? Error : "UNKNOWN");
	
	return PLUGIN_CONTINUE
}