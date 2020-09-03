#include <amxmodx>
#include <fakemeta>

#include <engine>

#include <DRP/DRPCore>
#include <arrayx_travtrie>

enum NPC_DATA
{
	QUEST = 0, // are we doing a quest for the NPC
	SAID_SOMETHING // are we talking to the NPC
}

new g_aMission
new g_aMissionNum

new const g_aMissionClass[] = "DRP_MISSIONNPC"

new g_UserNPC[33][NPC_DATA]

public DRP_Init()
{
	// Main
	register_plugin("DRP - NPC Missions","0.1a","Drak");
	register_think(g_aMissionClass,"Forward_NPCThink");
	
	// Forwards
	register_forward(FM_PlayerPreThink,"Forward_PreThink");
	
	// Arrays
	g_aMission = array_create();
	
	// Tasks
	LoadNPCData();
}

// ------------
public Forward_NPCThink(const Ent)
{
	// I'm a slow thinker - DERP DERP
	set_pev(Ent,pev_nextthink,halflife_time() + 1.0);

	if(random(100) <= 80)
		return
	
	new const ArrayIndex = GetNPCArray(Ent),CurArray = array_get_int(g_aMission,ArrayIndex),Dialog = array_get_int(CurArray,2);
	if(!Dialog)
		return
	
	static DialogString[512],EntList[33],npcName[33],Cache[33]
	
	new Num = find_sphere_class(Ent,"player",100.0,EntList,32)
	if(!Num)
		return
	
	new id
	
	// Loop through all the found players
	for(new Count;Count < Num;Count++)
	{
		id = EntList[Count]
		
		// We are currently doing a mission
		// or they already said something to us
		if(g_UserNPC[id][SAID_SOMETHING] || g_UserNPC[id][QUEST])
			continue
		
		new plName[33]
		get_user_name(id,plName,32);
		
		array_get_string(CurArray,0,npcName,32);
		array_get_string(CurArray,3,DialogString,511);
		client_print(id,print_chat,"[NPC: %s] Hey %s!",npcName,DialogString);
		
	//	g_UserNPC[id][SAID_SOMETHING] = 1
	}
}
public Forward_PreThink(const id)
{
	if(!is_user_alive(id))
		return FMRES_IGNORED
		
	if(!(pev(id,pev_button) & IN_USE && !(pev(id,pev_oldbuttons) & IN_USE)))
		return FMRES_IGNORED
	
	new Index,Body
	get_user_aiming(id,Index,Body,80);
	
	if(!Index)
		return FMRES_IGNORED
	
	static Classname[33]
	pev(Index,pev_classname,Classname,32);
	
	if(!equal(Classname,g_aMissionClass))
		return FMRES_IGNORED
	
	RunNPC(id,Index);
	return FMRES_HANDLED
}
// ------------
RunNPC(const Player,const Ent)
{
	new const ArrayIndex = GetNPCArray(Ent),CurArray = array_get_int(g_aMission,ArrayIndex);
	client_print(0,print_chat,"[NPC DEBUG] Running NPC (Ent: %d - ArrayIndex: %d)",Ent,ArrayIndex);
	
	static Message[512],NPCName[36]
	array_get_string(CurArray,0,NPCName,35);
	array_get_string(CurArray,1,Message,511);
	
	server_print("L: %d",GetNPCType(Ent))
	
	if(Message[0])
		FormatString(Player,Message,511);
	
	switch(GetNPCType(Ent))
	{
		// Generic NPC - Only show an MOTD Window
		case 0:
		{
			if(Message[0])
				show_motd(Player,Message,NPCName);
		}
		case 1:
		{
			format(NPCName,35,"NPC: %s",NPCName);
			
			new Menu = menu_create(NPCName,"_NPCHandle");
			
			// Three options is dialog / npc questions
			menu_additem(Menu,"Something 1");
			menu_additem(Menu,"Something 2");
			menu_additem(Menu,"Something 3");
			
			// The last one is the MOTD window
			menu_additem(Menu,"Why");
		}
	}
}
// ------------
public _NPCHandle()
{
}
// ------------
LoadNPCData()
{
	new File[128],Buffer[128],cBuff[256],Cache[3][12],CurArray
	DRP_GetConfigsDir(File,127);
	
	add(File,127,"/NPCMissions.ini");
	
	new pFile = fopen(File,"r");
	if(!pFile)
		return DRP_ThrowError(1,"Unable to open NPCMission.ini File. (%s)",File);
	
	// NPC Data Strings
	new Name[33],szModel[64],Float:Origin[3],Message[256],DialogString[4][512],Dialog
	
	while(!feof(pFile))
	{
		fgets(pFile,Buffer,127);
		
		if(!Buffer[0] || Buffer[0] == ';')
			continue
		
		if(containi(Buffer,"[END]") != -1)
		{
			CurArray = array_create();
			array_set_int(g_aMission,++g_aMissionNum,CurArray);
			
			// NPC Data
			array_set_string(CurArray,0,Name);
			array_set_string(CurArray,1,Message);
			
			array_set_int(CurArray,2,Dialog);
			
			for(new Count;Count < Dialog;Count++)
				array_set_string(CurArray,3 + Count,DialogString[Count]);
			
			// NPC Model
			sModel(g_aMissionNum,1,szModel,Origin);
		}
		else if(containi(Buffer,"npcname") != -1)
		{
			parse(Buffer,File,1,cBuff,255);
			trim(cBuff);
			remove_quotes(cBuff);
			
			copy(Name,32,cBuff);
		}
		else if(containi(Buffer,"model") != -1)
		{
			parse(Buffer,File,1,cBuff,255);
			trim(cBuff);
			remove_quotes(cBuff);
			
			copy(szModel,32,cBuff);
			
			if(file_exists(szModel))
				precache_model(szModel);
		}
		else if(containi(Buffer,"message") != -1)
		{
			parse(Buffer,File,1,Message,255);
			trim(Message);
			remove_quotes(Message);
		}
		else if(containi(Buffer,"origin") != -1)
		{
			parse(Buffer,File,1,cBuff,255);
			remove_quotes(cBuff);
			
			parse(cBuff,Cache[0],11,Cache[1],11,Cache[2],11);
			
			for(new Count;Count < 3;Count++)
				Origin[Count] = str_to_float(Cache[Count]);
		}
		else if(containi(Buffer,"dialog") != -1)
		{
			if(Dialog > 4)
				return DRP_ThrowError(1,"[MissionNPCs] You can only have 4 dialogs for each NPC.");
			
			parse(Buffer,File,1,DialogString[Dialog++],511);
			remove_quotes(DialogString[Dialog]);

		}
	}
	fclose(pFile);
}
sModel(const NPCNumber,const Type,const szModel[],const Float:Origin[3])
{
	new Ent = engfunc(EngFunc_CreateNamedEntity,engfunc(EngFunc_AllocString,"info_target"));
	if(!Ent)
		return DRP_ThrowError(1,"Unable to create Mission NPC. Stopping");
	
	engfunc(EngFunc_SetModel,Ent,szModel);
	engfunc(EngFunc_SetOrigin,Ent,Origin);
	engfunc(EngFunc_SetSize,Ent,Float:{-16.0,-16.0,-36.0},Float:{16.0,16.0,36.0});
	
	set_pev(Ent,pev_solid,SOLID_BBOX);
	set_pev(Ent,pev_iuser3,NPCNumber);
	
	set_pev(Ent,pev_iuser2,Type);
	set_pev(Ent,pev_classname,g_aMissionClass);
	
	set_pev(Ent,pev_controller_0,125);
	set_pev(Ent,pev_controller_1,125);
	set_pev(Ent,pev_controller_2,125);
	set_pev(Ent,pev_controller_3,125);
	
	set_pev(Ent,pev_sequence,1);
	set_pev(Ent,pev_framerate,1.0);
	set_pev(Ent,pev_nextthink,halflife_time() + 1.0)
	
	engfunc(EngFunc_DropToFloor,Ent);
}
GetNPCArray(Ent)
	return pev(Ent,pev_iuser3);
GetNPCType(Ent)
	return pev(Ent,pev_iuser2);
	
// -------------
// Current tags:
// #player
FormatString(id,String[],Len)
{
	static Cache[33]
	if(containi(String,"#player") != -1)
	{
		get_user_name(id,Cache,32);
		replace_all(String,Len,"#player",Cache);
	}
}