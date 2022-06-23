/*
* DRPRobbing.sma
* ------------------------
* 
*/

#include <amxmodx>
#include <amxmisc>
#include <DRP/DRPCore>
#include <engine>

#define MAX_PROFILES 20
#define MAX_STEPS 30

#define CUFFED (1<<0)
#define KILLED (1<<1)
#define LEAVE (1<<2)
#define CASH (1<<3)

//#define GLOW (1<<0)
//#define LIGHTS (1<<1)
//#define SIREN (1<<2)

#define SOUND_VOL VOL_NORM
#define SOUND_ATTN ATTN_NORM
#define SOUND_PITCH PITCH_NORM
#define SOUND_FLAGS 0

#define GetBackpackMoney(%1) entity_get_int(%1,EV_INT_iuser3)
#define SetBackpackMoney(%1,%2) entity_set_int(%1,EV_INT_iuser3,%2)

enum _:ROBPROFILE
{
	CASHSECOND = 0,
	CASHDELAY,
	CASHMAX,
	STOPON,
	NAME,
	COOLDOWN,
	DISTANCE,
	BACKPACK_END,
	ARRESTED_END,
	KILLED_END,
	LEAVE_END,
	DONE_END,
	START,
	RADIUS,
	ORIGIN,
	FLAGS,
	MINPLAYERS,
	MINCOPS,
	MAX_TIME
}

enum _:STEP_TYPE
{
	WAIT = 0,
	USE,
	EFFECTS,
	MESSAGEONE,
	MESSAGEALL,
	END,
	LOCK,
	UNLOCK,
	GLOW,
	LIGHTS,
	SOUND
}

new g_RobPattern[MAX_PROFILES][MAX_STEPS][33]
new g_RobSteps[MAX_PROFILES]
new g_RobProfile[MAX_PROFILES][ROBPROFILE][128]
new g_RobProfiles

new g_RobCurProfile
new g_RobCurStep
new g_RobCurPlayer
new g_RobLastTime
new g_RobTimeElapsed
new g_RobRealTime
new g_RobCashTime
new g_RobCashTaken
new g_RobProperty
new g_RobEnd

new const g_BackpackMdl[] = "models/OZDRP/p_drp_moneybag2.mdl"

// this is a hack to allow me to check the profile they "robbed"
// even after the rob is over (for the backpack)
new g_RobberProfile[33]
new g_RobberBackpack[33]

public DRP_Init()
{
	new ConfigFile[256]
	DRP_GetConfigsDir(ConfigFile,255);
	add(ConfigFile,255,"/Robbing.ini");
	
	new pFile = fopen(ConfigFile,"rt+");
	if(!pFile)
		return
	
	new Buffer[128],Left[64],Right[128]
	while(!feof(pFile))
	{
		Buffer[0] = 0
		
		fgets(pFile,Buffer,127);
		
		if(Buffer[0] == ';' || !Buffer[0])
			continue
		
		remove_quotes(Buffer);
		trim(Buffer);
		
		if(containi(Buffer,"[") != -1 && containi(Buffer,"]") != -1)
		{
			g_RobProfiles++
			replace(Buffer,127,"[","");
			replace(Buffer,127,"]","");
			
			trim(Buffer);
			copy(g_RobProfile[g_RobProfiles][NAME],127,Buffer);
		}
		else if(containi(Buffer,"cashsecond") != -1)
		{
			parse(Buffer,Left,63,Right,127);
			g_RobProfile[g_RobProfiles][CASHSECOND][0] = str_to_num(Right);
		}
		else if(containi(Buffer,"cashmax") != -1)
		{
			parse(Buffer,Left,63,Right,127);
			g_RobProfile[g_RobProfiles][CASHMAX][0] = str_to_num(Right);
		}
		else if(containi(Buffer,"cashdelay") != -1)
		{
			parse(Buffer,Left,63,Right,127);
			
			new Delay = str_to_num(Right);
			g_RobProfile[g_RobProfiles][CASHDELAY][0] = Delay <= 0 ? 1 : Delay
		}
		else if(containi(Buffer,"stopon") != -1)
		{
			parse(Buffer,Left,63,Right,127);
			g_RobProfile[g_RobProfiles][STOPON][0] = str_to_num(Right);
		}
		else if(containi(Buffer,"cooldown") != -1)
		{
			parse(Buffer,Left,63,Right,127);
			g_RobProfile[g_RobProfiles][COOLDOWN][0] = str_to_num(Right);
		}
		else if(containi(Buffer,"distance") != -1)
		{
			parse(Buffer,Left,63,Right,127);
			g_RobProfile[g_RobProfiles][DISTANCE][0] = str_to_num(Right);
		}
		else if(containi(Buffer,"maxtime") != -1)
		{
			parse(Buffer,Left,63,Right,127);
			g_RobProfile[g_RobProfiles][MAX_TIME][0] = str_to_num(Right);
		}
		else if(containi(Buffer,"radius") != -1)
		{
			parse(Buffer,Left,63,Right,127);
			g_RobProfile[g_RobProfiles][RADIUS][0] = str_to_num(Right);
		}
		else if(containi(Buffer,"origin") != -1)
		{
			parse(Buffer,Left,63,Right,127);
			
			new XS[10],YS[10],ZS[10]
			parse(Right,XS,9,YS,9,ZS,9);
			
			g_RobProfile[g_RobProfiles][ORIGIN][0] = str_to_num(XS);		
			g_RobProfile[g_RobProfiles][ORIGIN][1] = str_to_num(YS);
			g_RobProfile[g_RobProfiles][ORIGIN][2] = str_to_num(ZS);
		}
		
		// Fix the buffer skipping over these guys
		// not sure why
		if(containi(Buffer,"backpackend") != -1)
		{
			parse(Buffer,Left,63,g_RobProfile[g_RobProfiles][BACKPACK_END],127);
			remove_quotes(g_RobProfile[g_RobProfiles][BACKPACK_END]);
		}
		if(containi(Buffer,"cuffedend") != -1)
		{
			parse(Buffer,Left,63,g_RobProfile[g_RobProfiles][ARRESTED_END],127);
			remove_quotes(g_RobProfile[g_RobProfiles][ARRESTED_END]);
		}
		if(containi(Buffer,"killedend") != -1)
		{
			parse(Buffer,Left,63,g_RobProfile[g_RobProfiles][KILLED_END],127);
			remove_quotes(g_RobProfile[g_RobProfiles][KILLED_END]);
		}
		if(containi(Buffer,"leaveend") != -1)
		{
			parse(Buffer,Left,63,g_RobProfile[g_RobProfiles][LEAVE_END],127);
			remove_quotes(g_RobProfile[g_RobProfiles][LEAVE_END]);
		}
		
		else if(containi(Buffer,"doneend") != -1)
		{
			parse(Buffer,Left,63,g_RobProfile[g_RobProfiles][DONE_END],127);
			remove_quotes(g_RobProfile[g_RobProfiles][DONE_END]);
		}
		else if(containi(Buffer,"start") != -1)
		{
			parse(Buffer,Left,63,g_RobProfile[g_RobProfiles][START],127);
			remove_quotes(g_RobProfile[g_RobProfiles][START]);
		}
		else if(containi(Buffer,"flags") != -1)
		{
			parse(Buffer,Left,63,Right,127);
			g_RobProfile[g_RobProfiles][FLAGS][0] = DRP_AccessToInt(Right);
		}
		else if(containi(Buffer,"minplayers") != -1)
		{
			parse(Buffer,Left,63,Right,127);
			g_RobProfile[g_RobProfiles][MINPLAYERS][0] = str_to_num(Right);
		}
		else if(containi(Buffer,"mincops") != -1)
		{
			parse(Buffer,Left,63,Right,127);
			g_RobProfile[g_RobProfiles][MINCOPS][0] = str_to_num(Right);
		}
		else if(containi(Buffer,"!wait") != -1)
		{
			parse(Buffer,Left,63,Right,127);
			g_RobPattern[g_RobProfiles][g_RobSteps[g_RobProfiles]][0] = (1<<WAIT);
			g_RobPattern[g_RobProfiles][g_RobSteps[g_RobProfiles]++][1] = str_to_num(Right);
		}
		else if(containi(Buffer,"!use") != -1)
		{
			parse(Buffer,Left,63,Right,127);
			g_RobPattern[g_RobProfiles][g_RobSteps[g_RobProfiles]][0] = (1<<USE)
			remove_quotes(Right);
			copy(g_RobPattern[g_RobProfiles][g_RobSteps[g_RobProfiles]++][1],127,Right);
		}
		else if(containi(Buffer,"!messageone") != -1)
		{
			parse(Buffer,Left,63,Right,127);
			g_RobPattern[g_RobProfiles][g_RobSteps[g_RobProfiles]][0] = (1<<MESSAGEONE)
			remove_quotes(Right);
			copy(g_RobPattern[g_RobProfiles][g_RobSteps[g_RobProfiles]++][1],127,Right);
		}
		else if(containi(Buffer,"!messageall") != -1)
		{
			parse(Buffer,Left,63,Right,127);
			g_RobPattern[g_RobProfiles][g_RobSteps[g_RobProfiles]][0] = (1<<MESSAGEALL)
			remove_quotes(Right);
			copy(g_RobPattern[g_RobProfiles][g_RobSteps[g_RobProfiles]++][1],127,Right);
		}
		else if(containi(Buffer,"!glow") != -1)
		{
			parse(Buffer,Left,63,Right,127);
			g_RobPattern[g_RobProfiles][g_RobSteps[g_RobProfiles]][0] = (1<<GLOW)
			remove_quotes(Right);
			copy(g_RobPattern[g_RobProfiles][g_RobSteps[g_RobProfiles]++][1],127,Right);
		}
		else if(containi(Buffer,"!lights") != -1)
		{
			parse(Buffer,Left,63,Right,127);
			g_RobPattern[g_RobProfiles][g_RobSteps[g_RobProfiles]][0] = (1<<LIGHTS)
			remove_quotes(Right);
			copy(g_RobPattern[g_RobProfiles][g_RobSteps[g_RobProfiles]++][1],127,Right);
		}
		else if(containi(Buffer,"!end") != -1)
		{
			parse(Buffer,Left,63,Right,63);
			g_RobPattern[g_RobProfiles][g_RobSteps[g_RobProfiles]++][0] = (1<<END)
		}
		else if(containi(Buffer,"!lock") != -1)
		{
			parse(Buffer,Left,63,Right,127);
			g_RobPattern[g_RobProfiles][g_RobSteps[g_RobProfiles]][0] = (1<<LOCK)
			remove_quotes(Right);
			copy(g_RobPattern[g_RobProfiles][g_RobSteps[g_RobProfiles]++][1],127,Right);
		}
		else if(containi(Buffer,"!unlock") != -1)
		{
			parse(Buffer,Left,63,Right,127);
			g_RobPattern[g_RobProfiles][g_RobSteps[g_RobProfiles]][0] = (1<<UNLOCK)
			remove_quotes(Right);
			copy(g_RobPattern[g_RobProfiles][g_RobSteps[g_RobProfiles]++][1],127,Right);
		}
		if(containi(Buffer,"@!") != -1)
			g_RobPattern[g_RobProfiles][g_RobSteps[g_RobProfiles] - 1][0] |= (1<<STEP_TYPE)
	}
	fclose(pFile);
}

public plugin_precache()
{
	if(file_exists(g_BackpackMdl))
		precache_model(g_BackpackMdl);
}

public plugin_init()
{
	// Main
	register_plugin("DRP - Robbing","0.1a","Drak");
	
	// Events
	register_event("DeathMsg","EventDeathMsg","a");
	
	// Tips
	DRP_RegToolTip("Rob_Finish","RobbingFinish.txt");
	
	// Commands
	DRP_RegisterCmd("drp_rob","CmdRob","(ADMIN) <rob profile> - Forces a rob");
}

public DRP_Error(const Reason[])
	pause("d")

public DRP_HudDisplay(id,Hud)
{
	if(Hud != HUD_PRIM)
		return
	
	if(g_RobberProfile[id] && g_RobProfile[g_RobberProfile[id]][DISTANCE][0])
	{
		DRP_AddHudItem(id,HUD_PRIM,"\nMoney in backpack: $%d",GetBackpackMoney(g_RobberBackpack[id]));
		
		new Float:Distance,Float:pOrigin[3],Float:rOrigin[3]
		DRP_AddHudItem(id,HUD_PRIM,"You must run a total of %d yards\naway from the building to keep the cash\ndont lose the backpack",g_RobProfile[g_RobberProfile[id]][DISTANCE]);
		
		entity_get_vector(id,EV_VEC_origin,pOrigin);
		rOrigin[0] = float(g_RobProfile[g_RobberProfile[id]][ORIGIN][0]);
		rOrigin[1] = float(g_RobProfile[g_RobberProfile[id]][ORIGIN][1]);
		rOrigin[2] = float(g_RobProfile[g_RobberProfile[id]][ORIGIN][2]);
		
		Distance = get_distance_f(pOrigin,rOrigin);
		DRP_AddHudItem(id,HUD_PRIM,"Current Distance: %d Yards",floatround(Distance));
		
		// Check distance
		// they made it the distance, give them the money, remove the backpack
		if(vector_distance(pOrigin,rOrigin) >= float(g_RobProfile[g_RobberProfile[id]][DISTANCE][0]))
		{
			new Message[256],CashStr[12],plName[33],Money = GetBackpackMoney(g_RobberBackpack[id]);
			copy(Message,255,g_RobProfile[g_RobberProfile[id]][BACKPACK_END]);
			num_to_str(Money,CashStr,11);
			
			DRP_SetUserWallet(id,DRP_GetUserWallet(id) + Money);
			
			if(Message[0])
			{	
				replace_all(Message,255,"#name#",plName);
				replace_all(Message,255,"#cash#",CashStr);
				client_print(id,print_chat,"* [Robbing] %s",Message);
			}
			
			SetBackpack(id,false);
			g_RobberProfile[id] = 0
			
			if(is_user_alive(id))
				DRP_ShowToolTip(id,"Rob_Finish");
		}
	}
	
	else if(g_RobCurPlayer == id)
		DRP_AddHudItem(id,HUD_PRIM,"Robbing. Cash Stolen: $%d",g_RobCashTaken);
}

public CmdRob(id,level,cid)
{
	if(!DRP_CmdAccess(id,cid,2))
		return PLUGIN_HANDLED
	
	if(g_RobCurProfile || g_RobberProfile[id])
	{
		client_print(id,print_console,"[DRP] There is already a robbing in progress");
		return PLUGIN_HANDLED
	}
	
	new Arg[33]
	read_argv(1,Arg,32);
	
	remove_quotes(Arg);
	trim(Arg);
	
	for(new Count;Count <= g_RobProfiles;Count++)
		if(equali(Arg,g_RobProfile[Count][NAME]))
			g_RobCurProfile = Count
		
	if(!g_RobCurProfile)
	{
		client_print(id,print_console,"[DRP] Unable to find rob profile ^"%s^" List of profiles:",Arg);
		for(new Count;Count <= g_RobProfiles;Count++)
			if(g_RobProfile[Count][NAME][0])
				client_print(id,print_console,"#%d. %s",Count,g_RobProfile[Count][NAME]);
		
		return PLUGIN_HANDLED
	}
	
	new Float:Origin[3],Float:pOrigin[3]
	Origin[0] = float(g_RobProfile[g_RobCurProfile][ORIGIN][0]);
	Origin[1] = float(g_RobProfile[g_RobCurProfile][ORIGIN][1]);
	Origin[2] = float(g_RobProfile[g_RobCurProfile][ORIGIN][2]);
	
	entity_get_vector(id,EV_VEC_origin,pOrigin);
	
	if(vector_distance(Origin,pOrigin) > g_RobProfile[g_RobCurProfile][RADIUS][0])
	{
		client_print(id,print_console,"[DRP] To much distance between you and the rob location. Unable to start the robbing. (%f)",vector_distance(Origin,pOrigin));
		g_RobCurProfile = 0
		return PLUGIN_HANDLED
	}
	
	g_RobCurStep = 0
	g_RobTimeElapsed = 0
	g_RobEnd = 0
	g_RobCurPlayer = id
	g_RobCashTime = 0
	g_RobRealTime = 0
	g_RobCashTaken = 0
	
	ExecuteStep();
	set_task(1.0,"GiveMoney",id);
	
	if(g_RobProfile[g_RobCurProfile][DISTANCE][0])
	{
		g_RobberProfile[id] = g_RobCurProfile
		SetBackpack(id,true);
	}
	
	client_print(id,print_console,"[DRP] Robbing started.");
	return PLUGIN_HANDLED
}

/*==================================================================================================================================================*/
public EventDeathMsg()
{
	new const id = read_data(2);
	if(!id)
		return PLUGIN_CONTINUE
	
	if(g_RobCurProfile && id == g_RobCurPlayer && g_RobProfile[g_RobCurProfile][STOPON][0] & KILLED)
	{		
		new Data[2]
		Data[0] = id
		Data[1] = KILLED
		
		if(DRP_CallEvent("Rob_End",Data,2))
			return PLUGIN_CONTINUE
		
		new Name[33],Authid[36]
		get_user_name(id,Name,32)
		get_user_authid(id,Authid,35)
		
		DRP_Log("Rob: ^"%s<%d><%s><>^" dies while robbing the %s",Name,get_user_userid(id),Authid,g_RobProfile[g_RobCurProfile][NAME]);
		
		new Message[128]
		copy(Message,127,g_RobProfile[g_RobCurProfile][KILLED_END]);
		
		if(Message[0])
		{
			replace_all(Message,127,"#name#",Name);
			client_print(0,print_chat,"* [Robbing]: %s",Message);
		}
		
		RobEnd();
		g_RobCurProfile = 0
	}
	
	if(g_RobberProfile[id])
		SetBackpack(id,false);
	
	return PLUGIN_CONTINUE
}

public client_disconnect(id)
{
	if(g_RobCurProfile && id == g_RobCurPlayer && g_RobProfile[g_RobCurProfile][STOPON][0] & LEAVE)
	{
		new Data[2]
		Data[0] = id
		Data[1] = LEAVE
		
		if(DRP_CallEvent("Rob_End",Data,2))
			return
		
		new Name[33],Authid[36]
		get_user_name(id,Name,32)
		get_user_authid(id,Authid,35)
		
		DRP_Log("Rob: ^"%s<%d><%s><>^" disconnects while robbing the %s",Name,get_user_userid(id),Authid,g_RobProfile[g_RobCurProfile][NAME])
		
		new Message[128]
		copy(Message,127,g_RobProfile[g_RobCurProfile][LEAVE_END]);
		
		if(Message[0])
		{
			replace_all(Message,127,"#name#",Name);
			client_print(0,print_chat," * [Robbing] %s",Message);
		}
		
		RobEnd();
		g_RobCurProfile = 0
	}
	
	if(g_RobberProfile[id])
		SetBackpack(id,false);
}
public DRP_Event(const Name[],Data[],Len)
{	
	if((equali(Name,"Player_Cuffed")) && g_RobCurProfile && g_RobProfile[g_RobCurProfile][STOPON][0] & CUFFED && g_RobCurPlayer == Data[0])
	{
		new const id = Data[0]
		Data[2] = CUFFED
		
		if(DRP_CallEvent("Rob_End",Data,2))
			return
		
		new Name[33],Authid[36]
		get_user_name(id,Name,32);
		get_user_authid(id,Authid,35);
		
		DRP_Log("Rob: ^"%s<%d><%s><>^" is arrested while robbing the %s",Name,get_user_userid(id),Authid,g_RobProfile[g_RobCurProfile][NAME]);
		
		new Message[128]
		copy(Message,127,g_RobProfile[g_RobCurProfile][ARRESTED_END]);
		
		if(Message[0])
		{
			replace_all(Message,127,"#name#",Name);
			client_print(0,print_chat,"* [Robbing] %s",Message);
		}
		
		RobEnd();
		g_RobCurProfile = 0
		
		if(g_RobberProfile[id])
			SetBackpack(id,false);
		
		return
	}
	
	if(!equali(Name,"Rob_Begin"))
		return
	
	new const id = Data[0]
	new const Property = Data[1]
	
	if(g_RobCurProfile)
	{
		client_print(id,print_chat,"[DRP] You are currently unable to rob this place.");
		return
	}
	
	if(g_RobberProfile[id])
	{
		client_print(id,print_chat,"[DRP] You still have a backpack full of money.");
		return
	}
	
	for(new Count;Count <= g_RobProfiles;Count++)
		if(equali(Data[2],g_RobProfile[Count][NAME]))
			g_RobCurProfile = Count
	
	if(!g_RobCurProfile || !Property)
	{
		client_print(id,print_chat,"[DRP] Internal error; unable to find rob profile / property. Please contact an administrator. (%d-%d)",g_RobCurProfile,Property);
		return
	}
	
	if(floatround(get_gametime()) - g_RobLastTime < g_RobProfile[g_RobCurProfile][COOLDOWN][0] && g_RobLastTime)
		client_print(id,print_chat,"[DRP] This place has been robbed recently; please wait.");
	else if(g_RobProfile[g_RobCurProfile][FLAGS][0] & DRP_GetUserAccess(Data[0]))
		client_print(id,print_chat,"[DRP] You are currently unable to rob this place.");
	else if(get_playersnum() < g_RobProfile[g_RobCurProfile][MINPLAYERS][0])
		client_print(id,print_chat,"[DRP] There are not enough players in the server to rob this place.");
	else if(DRP_CopNum() < g_RobProfile[g_RobCurProfile][MINCOPS][0])
		client_print(id,print_chat,"[DRP] There are not enough cops in the server to rob this place.");
	else if(!DRP_PropertyGetProfit(Property))
		client_print(id,print_chat,"[DRP] This property hasn't made enough profit to rob.");
	else
	{
		new Name[33],Authid[36]
		get_user_name(id,Name,32)
		get_user_authid(id,Authid,35)
		
		DRP_Log("Rob: ^"%s<%d><%s><>^" begins robbing the %s",Name,get_user_userid(id),Authid,g_RobProfile[g_RobCurProfile][NAME]);
		
		new Message[128]
		copy(Message,127,g_RobProfile[g_RobCurProfile][START]);
		
		if(Message[0])
		{
			replace_all(Message,127,"#name#",Name);
			client_print(0,print_chat,"* [Robbing] %s",Message);
		}
		
		g_RobCurStep = 0
		g_RobTimeElapsed = 0
		g_RobEnd = 0
		g_RobCurPlayer = id
		g_RobCashTime = 0
		g_RobRealTime = 0
		g_RobCashTaken = 0
		g_RobProperty = Property
		
		ExecuteStep();
		set_task(1.0,"GiveMoney",id);
		
		if(g_RobProfile[g_RobCurProfile][DISTANCE][0])
		{
			g_RobberProfile[id] = g_RobCurProfile
			SetBackpack(id,true);
		}
	}
}
/*==================================================================================================================================================*/
public GiveMoney(const id)
{
	if(!g_RobCurProfile || !is_user_alive(id))
		return
	
	if(g_RobRealTime++ >= g_RobProfile[g_RobCurProfile][MAX_TIME][0])
	{
		new Data[2]
		Data[0] = id
		Data[1] = CASH
		
		if(DRP_CallEvent("Rob_End",Data,2))
			return
		
		new Name[33],Authid[36]
		get_user_name(id,Name,32);
		get_user_authid(id,Authid,35);
		
		DRP_Log("Rob: ^"%s<%d><%s><>^" finishes robbing the %s",Name,get_user_userid(id),Authid,g_RobProfile[g_RobCurProfile][NAME]);
		
		new Message[128]
		copy(Message,127,g_RobProfile[g_RobCurProfile][DONE_END]);
		
		if(Message[0])
		{
			replace_all(Message,127,"#name#",Name);
			client_print(0,print_chat,"* [Robbing] %s",Message)
		}
		
		RobEnd();
		g_RobCurProfile = 0
		
		return
	}
	
	new Float:Origin[3],Float:pOrigin[3]
	entity_get_vector(id,EV_VEC_origin,pOrigin);
	
	Origin[0] = float(g_RobProfile[g_RobCurProfile][ORIGIN][0]);
	Origin[1] = float(g_RobProfile[g_RobCurProfile][ORIGIN][1]);
	Origin[2] = float(g_RobProfile[g_RobCurProfile][ORIGIN][2]);
	
	if(vector_distance(Origin,pOrigin) > float(g_RobProfile[g_RobCurProfile][RADIUS][0]) && g_RobProfile[g_RobCurProfile][STOPON][0] & LEAVE)
	{
		new Data[2]
		Data[0] = id
		Data[1] = LEAVE
		
		if(DRP_CallEvent("Rob_End",Data,2))
			return
		
		new Name[33],Authid[36]
		get_user_name(id,Name,32);
		get_user_authid(id,Authid,35);
		
		DRP_Log("Rob: ^"%s<%d><%s><>^" leaves while robbing the %s",Name,get_user_userid(id),Authid,g_RobProfile[g_RobCurProfile][NAME])
		
		new Message[128]
		copy(Message,127,g_RobProfile[g_RobCurProfile][LEAVE_END]);
		
		if(Message[0])
		{
			replace_all(Message,127,"#name#",Name);
			client_print(0,print_chat,"* [Robbing] %s",Message);
		}
		
		RobEnd();
		g_RobCurProfile = 0
		
		return
	}
	
	if(++g_RobCashTime < g_RobProfile[g_RobCurProfile][CASHDELAY][0])
		set_task(1.0,"GiveMoney",id);
	else
	{
		g_RobCashTime = 0
		if(++g_RobTimeElapsed * g_RobProfile[g_RobCurProfile][CASHSECOND][0] > g_RobProfile[g_RobCurProfile][CASHMAX][0] && g_RobProfile[g_RobCurProfile][STOPON][0] & CASH)
		{
			new Data[2]
			Data[0] = id
			Data[1] = CASH
			
			if(DRP_CallEvent("Rob_End",Data,2))
				return
			
			new Name[33],Authid[36]
			get_user_name(id,Name,32);
			get_user_authid(id,Authid,35);
			
			DRP_Log("Rob: ^"%s<%d><%s><>^" finishes robbing the %s",Name,get_user_userid(id),Authid,g_RobProfile[g_RobCurProfile][NAME]);
			
			new Message[128]
			copy(Message,127,g_RobProfile[g_RobCurProfile][DONE_END]);
			
			if(Message[0])
			{
				replace_all(Message,127,"#name#",Name);
				client_print(0,print_chat,"* [Robbing] %s",Message)
			}
			
			RobEnd();
			g_RobCurProfile = 0
			
			return
		}
		
		if(g_RobProfile[g_RobCurProfile][DISTANCE][0])
			SetBackpackMoney(g_RobberBackpack[id],GetBackpackMoney(g_RobberBackpack[id]) + g_RobProfile[g_RobCurProfile][CASHSECOND][0]);
		else
		{
			DRP_SetUserWallet(id,DRP_GetUserWallet(id) + g_RobProfile[g_RobCurProfile][CASHSECOND][0]);
			
			new Profit = DRP_PropertyGetProfit(g_RobProperty);
			if(Profit > 0)
				DRP_PropertySetProfit(g_RobProperty,Profit - g_RobProfile[g_RobCurProfile][CASHSECOND][0]);
		}
		
		set_task(1.0,"GiveMoney",id);
	}
}

public ExecuteStep()
{
	if(!g_RobCurProfile || g_RobCurStep >= g_RobSteps[g_RobCurProfile])
		return
	
	new Repeat
	new const Step = g_RobPattern[g_RobCurProfile][g_RobCurStep][0]
	
	if(!(Step & (1<<STEP_TYPE)) || g_RobEnd)
	{
		if(Step & (1<<WAIT))
		{
			set_task(float(g_RobPattern[g_RobCurProfile][g_RobCurStep][1]),"ExecuteStep");
			Repeat = 1
		}
		else if(Step & (1<<USE))
		{
			new Ent = str_to_num(g_RobPattern[g_RobCurProfile][g_RobCurStep][1]);
			if(!Ent || floatround(floatlog(float(Ent)) + 0.5) < strlen(g_RobPattern[g_RobCurProfile][g_RobCurStep][1]))
			{
				Ent = 0
				while((Ent = find_ent_by_tname(Ent,g_RobPattern[g_RobCurProfile][g_RobCurStep][1])) != 0)
					force_use(Ent,Ent);
			}
			else
				force_use(Ent,Ent);
		}
		else if(Step & (1<<GLOW))
		{			
			new RS[10],GS[10],BS[10]
			parse(g_RobPattern[g_RobCurProfile][g_RobCurStep][1],RS,9,GS,9,BS,9);
			
			new const R = str_to_num(RS);
			new const G = str_to_num(GS);
			new const B = str_to_num(BS)
			
			set_rendering(g_RobCurPlayer,R != 255 || G != 255 || B != 255 ? kRenderFxGlowShell : kRenderFxNone,R,G,B);
		}
		else if(Step & (1<<LIGHTS))	//!lights "R G B Health Decay LightRadius"
		{
			new lightProperties[6][10]	//A single variable may not be bad if automatic looping is added.
			parse(g_RobPattern[g_RobCurProfile][g_RobCurStep][1],lightProperties[0],9,lightProperties[1],9,lightProperties[2],9,lightProperties[3],9,lightProperties[4],9,lightProperties[5],9);
			
			message_begin(MSG_BROADCAST,SVC_TEMPENTITY);
			write_byte(TE_DLIGHT); // TE_DLIGHT
			
			write_coord(g_RobProfile[g_RobCurProfile][ORIGIN][0]);	// x
			write_coord(g_RobProfile[g_RobCurProfile][ORIGIN][1]);	// y
			write_coord(g_RobProfile[g_RobCurProfile][ORIGIN][2]);	// z
			
			write_byte(str_to_num(lightProperties[5]));	// radius
			write_byte(str_to_num(lightProperties[0]));	// r
			write_byte(str_to_num(lightProperties[1]));	// g
			write_byte(str_to_num(lightProperties[2]));	// b
			write_byte(str_to_num(lightProperties[3]));	// life
			write_byte(str_to_num(lightProperties[4]));	// decay rate
			
			message_end();
		}
		
		else if(Step & (1<<MESSAGEONE))
		{
			if(is_user_connected(g_RobCurPlayer))
				client_print(g_RobCurPlayer,print_chat,"%s",g_RobPattern[g_RobCurProfile][g_RobCurStep][1]);
		}
		else if(Step & (1<<MESSAGEALL))
			client_print(0,print_chat,"%s",g_RobPattern[g_RobCurProfile][g_RobCurStep][1]);
		else if(Step & (1<<END))
		{
			new Data[2]
			Data[0] = g_RobCurPlayer
			Data[1] = CASH
			
			if(DRP_CallEvent("Rob_End",Data,2))
				return
			
			new Name[33],Authid[36]
			get_user_name(Data[0],Name,32)
			get_user_authid(Data[0],Authid,35)
			
			DRP_Log("Rob: ^"%s<%d><%s><>^" finishes robbing the %s",Name,get_user_userid(Data[0]),Authid,g_RobProfile[g_RobCurProfile][NAME])
			
			new Message[128]
			copy(Message,127,g_RobProfile[g_RobCurProfile][DONE_END]);
			
			if(Message[0])
			{
				replace_all(Message,127,"#name#",Name);
				client_print(0,print_chat,"* [Robbing] %s",Message);
			}
			
			RobEnd();
			g_RobCurProfile = 0
			
			return
		}
		else if(Step & (1<<LOCK))
		{
			new PropertyID
			new Temp[12]
			
			if(g_RobPattern[g_RobCurProfile][g_RobCurStep][2] == '|')
			{
				if(g_RobPattern[g_RobCurProfile][g_RobCurStep][1] == 'e')
				{
					copy(Temp,15,g_RobPattern[g_RobCurProfile][g_RobCurStep][1]);
					replace(Temp,11,"e|","");
					PropertyID = DRP_PropertyMatch(_,str_to_num(Temp));
				}
				else
				{
					copy(Temp,12,g_RobPattern[g_RobCurProfile][g_RobCurStep][1]);
					replace(Temp,12,"t|","");
				}
			}
			else
				PropertyID = DRP_PropertyMatch(_,_,g_RobPattern[g_RobCurProfile][g_RobCurStep][1])
			
			DRP_PropertySetLocked(PropertyID,1);
		}
		
		else if(Step & (1<<UNLOCK))
		{
			new PropertyID
			new Temp[12]
			
			if(g_RobPattern[g_RobCurProfile][g_RobCurStep][2] == '|')
			{
				if(g_RobPattern[g_RobCurProfile][g_RobCurStep][1] == 'e')
				{
					copy(Temp,15,g_RobPattern[g_RobCurProfile][g_RobCurStep][1]);
					replace(Temp,11,"e|","");
					PropertyID = DRP_PropertyMatch(_,str_to_num(Temp));
				}
				else
				{
					copy(Temp,12,g_RobPattern[g_RobCurProfile][g_RobCurStep][1]);
					replace(Temp,12,"t|","");
				}
			}
			else
				PropertyID = DRP_PropertyMatch(_,_,g_RobPattern[g_RobCurProfile][g_RobCurStep][1])
			
			DRP_PropertySetLocked(PropertyID,0);
		}
	}
	
	g_RobCurStep++
	
	if(!Repeat && !g_RobEnd)
		ExecuteStep();
}
/*==================================================================================================================================================*/
RobEnd()
{
	g_RobEnd = 1
	g_RobLastTime = floatround(get_gametime());
	
	new bool:SetGlow = false

	for(new Count;Count < g_RobSteps[g_RobCurProfile];Count++)
	{
		if(g_RobPattern[g_RobCurProfile][Count][0] & (1<<STEP_TYPE))
		{
			g_RobCurStep = Count
			ExecuteStep();
		}
		else if(g_RobPattern[g_RobCurProfile][Count][0] & (1<<GLOW) && !SetGlow)
		{
			SetGlow = true
			set_rendering(g_RobCurPlayer);
		}
	}
	
	if(is_user_alive(g_RobCurPlayer))
		DRP_ShowToolTip(g_RobCurPlayer,"Rob_Finish");
}
SetBackpack(id,bool:On)
{
	if(On)
	{
		if(!is_user_alive(id) || !g_RobberProfile[id])
		{
			if(is_valid_ent(g_RobberBackpack[id]))
				remove_entity(g_RobberBackpack[id]);
			
			return 0
		}
		
		if(!g_RobProfile[g_RobberProfile[id]][DISTANCE][0])
			return 0
		
		if(is_valid_ent(g_RobberBackpack[id]))
			remove_entity(g_RobberBackpack[id]);
		
		g_RobberBackpack[id] = create_entity("info_target");
		if(!g_RobberBackpack[id])
			return DRP_Log("Unable to create backpack ent. Robbing will continue.");
		
		entity_set_model(g_RobberBackpack[id],g_BackpackMdl);
		
		entity_set_int(g_RobberBackpack[id],EV_INT_movetype,MOVETYPE_FOLLOW);
		entity_set_int(g_RobberBackpack[id],EV_INT_solid,SOLID_NOT);
		
		entity_set_edict(g_RobberBackpack[id],EV_ENT_owner,id);
		entity_set_edict(g_RobberBackpack[id],EV_ENT_aiment,id);
	}
	else
	{
		if(is_valid_ent(g_RobberBackpack[id]))
			remove_entity(g_RobberBackpack[id]);
		
		g_RobberProfile[id] = 0
	}
	return 1
}