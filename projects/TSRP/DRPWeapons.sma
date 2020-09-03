/*
* DRPWeapons.sma
* Author(s): Drak
* -------------------------------
* Desc:
* Loads the weapons spawns from the Database.
* Removes the weapons on map start. (Enabled via CVar)
* Commands to spawn TS Weapons (Optional save to Database)
* 
* Changelog:
* 6/12/08:
* Moved code around abit.
* Small optimizations
*/

#include <amxmodx>

#include <fakemeta>
#include <engine> // find_sphere_class

#include <DRP/DRPCore>
#include <TSXWeapons>

new Handle:g_SqlHandle

new const g_WeaponTable[] = "Weapons"
new g_Attachments[33]
new g_WeaponID[33]

new g_WeaponMenu
new g_WeaponIDs[128]

// PCVars
new p_Enable

public plugin_init() 
{
	register_plugin("DRP - Weapon Spawning","0.1a","Drak");
	
	// Commands 
	DRP_RegisterCmd("drp_addgun","CmdSpawnWpn","(ADMIN) <weaponid> <ammo> <extra> <save (0/1)> - adds gun to wall");
	DRP_RegisterCmd("drp_removegun","CmdRemoveOrigin","(ADMIN) <CheckSQL 1/0> - Removes the gun spawn closest to you.");
	DRP_RegisterCmd("drp_listweaponids","CmdListWpnIds","(ADMIN) - <1=Console/2=MOTD> Lists all the WeaponIDs, along with there names.");
	
	// Forwards
	
	// Events
	DRP_RegisterEvent("Menu_Display","Event_MenuDisplay");
}

public DRP_Error(const Reason[])
	pause("d");

public DRP_Init()
{
	p_Enable = register_cvar("DRP_RemoveWeapons","1");
	g_SqlHandle = DRP_SqlHandle();
	
	get_localinfo("amxx_configsdir",g_WeaponIDs,127);
	add(g_WeaponIDs,127,"/DRP/WeaponIDs.txt");
	
	if(!file_exists(g_WeaponIDs))
		return DRP_ThrowError(1,"Unable to open WeaponID's file. (%s)",g_WeaponIDs);
	
	new pFile = fopen(g_WeaponIDs,"r");
	if(!pFile)
		return DRP_ThrowError(1,"Unable to open WeaponID's file. (%s)",g_WeaponIDs);
	
	new Data[65],WeaponID[12],g_WeaponMenu = menu_create("Spawn Weapon","_SpawnWeapon");
	while(!feof(pFile))
	{
		fgets(pFile,Data,64);
		
		if(!Data[0] || Data[0] == '-')
			break
		
		strtok(Data,WeaponID,11,Data,127,'-');
		
		trim(WeaponID);
		trim(Data);
		
		menu_additem(g_WeaponMenu,Data,WeaponID);
	}
	fclose(pFile);
	
	return set_task(3.0,"RemoveWeapons");
}
/*==================================================================================================================================================*/
public Event_MenuDisplay(const Name[],const Data[],const Len)
{
	new const id = Data[0]
	if(!DRP_IsAdmin(id))
		return
	
	DRP_AddMenuItem(id,"(ADMIN) Weapon Spawning","WeaponSpawn_Menu");
}

public WeaponSpawn_Menu(id)
	menu_display(id,g_WeaponMenu);

public client_disconnect(id)
	g_Attachments[id] = 0

public _SpawnWeapon(id,Menu,Item)
{
	if(Item == MENU_EXIT)
		return PLUGIN_HANDLED
	
	new Info[12],Access
	menu_item_getinfo(Menu,Item,Access,Info,11,_,_,Access);
	
	new WeaponID = str_to_num(Info);
	if(!WeaponID || WeaponID > 36)
	{
		client_print(id,print_chat,"[DRP] Internal Error; Please contact an admin.");
		return PLUGIN_HANDLED
	}
	
	new Title[64]
	formatex(Title,63,"WeaponID: %d^nSpawnFlags",WeaponID);
	g_WeaponID[id] = WeaponID
	
	new Menu2 = menu_create(Title,"_SpawnWeapon2");
	
	menu_additem(Menu2,"Silencer");
	menu_additem(Menu2,"Lasersight");
	menu_additem(Menu2,"Flashlight");
	menu_additem(Menu2,"Scope");
	menu_additem(Menu2,"Lay on Wall");
	menu_addblank(Menu2,0);
	menu_additem(Menu2,"Done");
	menu_additem(Menu2,"Exit");
	menu_setprop(Menu2,MPROP_EXIT,MEXIT_NEVER);
	
	menu_display(id,Menu2);
	return PLUGIN_HANDLED
}
public _SpawnWeapon2(id,Menu,Item)
{
	if(Item == MENU_EXIT)
		return PLUGIN_HANDLED
	
	switch(Item)
	{
		case 0:
		{
			if(g_Attachments[id] & TSA_SILENCER)
			{
				g_Attachments[id] -= TSA_SILENCER
			}
			else
			{
				g_Attachments[id] += TSA_SILENCER
			}
			
			(g_Attachments[id] & TSA_SILENCER) ? 
				menu_item_setname(Menu,Item,"Silencer *") : menu_item_setname(Menu,Item,"Silencer");
		}
		case 1:
		{
			if(g_Attachments[id] & TSA_LASERSIGHT)
			{
				g_Attachments[id] -= TSA_LASERSIGHT
			}
			else
			{
				g_Attachments[id] += TSA_LASERSIGHT
			}
			
			(g_Attachments[id] & TSA_LASERSIGHT) ? 
				menu_item_setname(Menu,Item,"Lasersight *") : menu_item_setname(Menu,Item,"Lasersight");
		}
		case 2:
		{
			if(g_Attachments[id] & TSA_FLASHLIGHT)
			{
				g_Attachments[id] -= TSA_FLASHLIGHT
			}
			else
			{
				g_Attachments[id] += TSA_FLASHLIGHT
			}
			
			(g_Attachments[id] & TSA_FLASHLIGHT) ? 
				menu_item_setname(Menu,Item,"Flashlight *") : menu_item_setname(Menu,Item,"Flashlight");
		}
		case 3:
		{
			if(g_Attachments[id] & TSA_SCOPE)
			{
				g_Attachments[id] -= TSA_SCOPE
			}
			else
			{
				g_Attachments[id] += TSA_SCOPE
			}
			
			(g_Attachments[id] & TSA_SCOPE) ? 
				menu_item_setname(Menu,Item,"Scope *") : menu_item_setname(Menu,Item,"Scope");
		}
		case 4:
		{
			if(g_Attachments[id] & TSA_LAYONWALL)
			{
				g_Attachments[id] -= TSA_LAYONWALL
			}
			else
			{
				g_Attachments[id] += TSA_LAYONWALL
			}
			
			(g_Attachments[id] & TSA_LAYONWALL) ? 
				menu_item_setname(Menu,Item,"Lay On Wall *") : menu_item_setname(Menu,Item,"Lay On Wall");
		}
		case 5:
		{
			new Float:plOrigin[3]
			pev(id,pev_origin,plOrigin);
			
			new szWeaponID[12],szFlags[12]
			num_to_str(g_WeaponID[id],szWeaponID,11);
			num_to_str(g_Attachments[id],szFlags,11);
			
			menu_destroy(Menu);
			
			new Ent = ts_weaponspawn(szWeaponID,"15","100",szFlags,plOrigin,0);
			if(Ent)
				client_print(id,print_chat,"[DRP] Created Weapon.");
			else
				client_print(id,print_chat,"[DRP] There was an error creating the weapon.");
				
			if(Ent)
			{
				new Data[1],Query[256]
				Data[0] = Ent
				
				new SQLOrigin[3]
				FVecIVec(plOrigin,SQLOrigin);
				
				formatex(Query,255,"INSERT INTO %s (WeaponID,Clips,Flags,X,Y,Z) VALUES ('%d','%d','%s','%d','%d','%d')",g_WeaponTable,g_WeaponID[id],100,szFlags,SQLOrigin[0],SQLOrigin[1],SQLOrigin[2]);
				SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",Query);
				
				formatex(Query,255,"SELECT * FROM %s ORDER BY `SQLKey` DESC",g_WeaponTable);
				SQL_ThreadQuery(g_SqlHandle,"SetSQLPev",Query,Data,1);
			}
			
			return PLUGIN_HANDLED
		}
		case 6:
		{
			menu_destroy(Menu);
			return PLUGIN_HANDLED
		}
	}
	
	menu_display(id,Menu);
	return PLUGIN_HANDLED
}
	
/*==================================================================================================================================================*/
public CmdSpawnWpn(id,level,cid)
{
	if(!DRP_CmdAccess(id,cid,5))
		return PLUGIN_HANDLED
	
	new WeaponID[256],Ammo[33],Flags[33],Save[33],Float:plOrigin[3]
	pev(id,pev_origin,plOrigin);
	
	read_argv(1,WeaponID,255);
	read_argv(2,Ammo,32);
	read_argv(3,Flags,32);
	read_argv(4,Save,32);

	new const IWeaponID = str_to_num(WeaponID);
	
	if(IWeaponID == 2 || IWeaponID == 10 || IWeaponID == 16 || IWeaponID == 30 || IWeaponID > 36)
	{
		client_print(id,print_console,"[DRP] Invalid WeaponID");
		return PLUGIN_HANDLED
	}
	
	new SQLOrigin[3]
	FVecIVec(plOrigin,SQLOrigin);
	
	new Ent = ts_weaponspawn(WeaponID,"15",Ammo,Flags,plOrigin,0);
	
	if(!str_to_num(Save))
		return PLUGIN_HANDLED
	
	new Data[1]
	Data[0] = Ent
	
	format(WeaponID,255,"INSERT INTO %s (WeaponID,Clips,Flags,X,Y,Z) VALUES ('%d','%d','%s','%d','%d','%d')",g_WeaponTable,IWeaponID,str_to_num(Ammo),Flags,SQLOrigin[0],SQLOrigin[1],SQLOrigin[2]);
	SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",WeaponID);
	
	format(WeaponID,255,"SELECT * FROM %s ORDER BY `SQLKey` DESC",g_WeaponTable);
	SQL_ThreadQuery(g_SqlHandle,"SetSQLPev",WeaponID,Data,1);
	
	return PLUGIN_HANDLED
}
public CmdRemoveOrigin(id,level,cid)
{
	if(!DRP_CmdAccess(id,cid,2))
		return PLUGIN_HANDLED
	
	new Arg[33],EntList[5]
	read_argv(1,Arg,32);
	
	new Num = find_sphere_class(id,"ts_groundweapon",50.0,EntList,1),Ent
	if(Num > 1 || !Num)
	{
		client_print(id,print_console,"[DRP] No weapons found, or there is more then one around you. Found: %d",Num);
		return PLUGIN_HANDLED
	}
	
	Num = str_to_num(Arg);
	Ent = EntList[0]

	if(Num)
	{
		new Query[128]
		format(Query,127,"DELETE FROM %s WHERE `SQLKey`='%d'",g_WeaponTable,pev(Ent,pev_iuser2));
		SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",Query);
	}
	
	client_print(id,print_console,"[DRP] Weapon Removed %s",Num ? "(Deleted from SQL)" : "");
	engfunc(EngFunc_RemoveEntity,Ent);
	
	return PLUGIN_HANDLED
}
public CmdListWpnIds(id,level,cid)
{
	if(!DRP_CmdAccess(id,cid,1))
		return PLUGIN_HANDLED
	
	new Arg[33]
	read_argv(1,Arg,32);
	
	new iArg = str_to_num(Arg);
	
	switch(iArg)
	{
		case 0..1:
		{
			new pFile = fopen(g_WeaponIDs,"r");
			if(!pFile)
			{
				client_print(id,print_console,"[DRP] Unable to open WeaponIDs File. (%s)",g_WeaponIDs);
				return PLUGIN_HANDLED
			}
			
			new Data[128]
			while(!feof(pFile))
			{
				fgets(pFile,Data,127);
				trim(Data);
				
				client_print(id,print_console,"%s",Data);
			}
			fclose(pFile);
		}
		case 2:
		{
			client_print(id,print_console,"[DRP] A MOTD Window has been opened containing a list of weaponids.");
			show_motd(id,g_WeaponIDs,"DRP");
		}
	}
	
	return PLUGIN_HANDLED
}
/*==================================================================================================================================================*/
public RemoveWeapons()
{
	if(get_pcvar_num(p_Enable))
	{
		new Ent
		while(( Ent = engfunc(EngFunc_FindEntityByString,Ent,"classname","ts_groundweapon" )) != 0)
			engfunc(EngFunc_RemoveEntity,Ent);
	}
	
	new Query[256]
	
	format(Query,255,"CREATE TABLE IF NOT EXISTS %s (WeaponID INT(11),Clips INT(11),Flags INT(11),X INT(11),Y INT(11),Z INT(11),SQLKey INT(11) NOT NULL AUTO_INCREMENT,PRIMARY KEY (SQLKey))",g_WeaponTable);
	SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",Query);
	
	format(Query,255,"SELECT * FROM %s",g_WeaponTable);
	SQL_ThreadQuery(g_SqlHandle,"FetchSpawns",Query);
}

public FetchSpawns(FailState,Handle:Query,Error[],Errcode,Data[],DataSize)
{
	if(FailState == TQUERY_CONNECT_FAILED)
		return DRP_ThrowError(1,"Could not connect to SQL database. Error: %s",Error ? Error : "UNKNOWN");
	
	else if(FailState == TQUERY_QUERY_FAILED)
		return DRP_ThrowError(1,"Error on Query. (ERROR: %s)",Error ? Error : "UNKNOWN");
	
	if(Errcode)
		return DRP_ThrowError(1,"SQL Error. Error: %s",Error);
	
	new WeaponID[33],Clips[33],Flags[33],Origin[3],Float:SpawnOrigin[3]
	while(SQL_MoreResults(Query))
	{
		SQL_ReadResult(Query,0,WeaponID,32);
		SQL_ReadResult(Query,1,Clips,32);
		SQL_ReadResult(Query,2,Flags,32);
		
		Origin[0] = SQL_ReadResult(Query,3);
		Origin[1] = SQL_ReadResult(Query,4);
		Origin[2] = SQL_ReadResult(Query,5);
		
		IVecFVec(Origin,SpawnOrigin);
		ts_weaponspawn(WeaponID,"15",Clips,Flags,SpawnOrigin,SQL_ReadResult(Query,6));
		
		SQL_NextRow(Query);
	}
	
	return PLUGIN_CONTINUE
}

public IgnoreHandle(FailState,Handle:Query,Error[],Errcode,Data[],DataSize) 
{
	if(FailState == TQUERY_CONNECT_FAILED)
		return DRP_ThrowError(0,"Could not connect to SQL database. Error: %s",Error ? Error : "UNKNOWN");
	
	else if(FailState == TQUERY_QUERY_FAILED)
		return DRP_ThrowError(0,"Error on Query. (ERROR: %s)",Error ? Error : "UNKNOWN");
	
	if(Errcode)
		return DRP_ThrowError(0,"SQL Error. Error: %s",Error);
	
	return PLUGIN_CONTINUE
}
public SetSQLPev(FailState,Handle:Query,Error[],Errcode,Data[],DataSize)
{
	if(FailState != TQUERY_SUCCESS)
		return DRP_ThrowError(0,"Error on Query. (ERROR: %s)",Error ? Error : "UNKNOWN");
	
	new const Ent = Data[0],PevNum = SQL_ReadResult(Query,6);
	if(!pev_valid(Ent) || !PevNum)
		return PLUGIN_CONTINUE
	
	set_pev(Ent,pev_iuser2,PevNum);
	return PLUGIN_CONTINUE
}
/*==================================================================================================================================================*/
// Functions below are copied from "fakemeta_util" by VEN
ts_weaponspawn(const weaponid[],const duration[],const extraclip[],const spawnflags[],const Float:Origin[3] = {0.0,0.0,0.0},SQLKey)
{
	new ent = engfunc(EngFunc_CreateNamedEntity,engfunc(EngFunc_AllocString,"ts_groundweapon"))
	if(!ent)
		return PLUGIN_CONTINUE
		
	fm_set_kvd(ent,"tsweaponid",weaponid,"ts_groundweapon");
	fm_set_kvd(ent,"wduration",duration,"ts_groundweapon");
	fm_set_kvd(ent,"wextraclip",extraclip,"ts_groundweapon");
	fm_set_kvd(ent,"spawnflags",spawnflags,"ts_groundweapon");
	
	dllfunc(DLLFunc_Spawn,ent);
	engfunc(EngFunc_SetOrigin,ent,Origin);
	
	// We remove it from the database with this.
	set_pev(ent,pev_iuser2,SQLKey);
	
	return ent
}
fm_set_kvd(Entity,const key[],const value[],const classname[]) 
{
	set_kvd(0,KV_ClassName,classname);
	set_kvd(0,KV_KeyName,key);
	set_kvd(0,KV_Value,value);
	set_kvd(0,KV_fHandled,0);
	
	return dllfunc(DLLFunc_KeyValue,Entity,0);
}