#include <amxmodx>
#include <fakemeta>

#include <DRP/DRPChat>
#include <DRP/DRPCore>
#include <DRP/DRPChat>
#include <DRP/DRPSMod>

// Thanks fysiks
#define chance(%1) ( %1 > random(100) ) // %1 = probability 

#define _SKILLSMOD
#define BACKSTAB_ANGLE 45.0

new g_BlockedItems[256]
new g_BlockedNum

new g_PickedNum[33]
new Float:g_Cooldown[33]

public plugin_init()
{
	// Main
	register_plugin("DRP - Pick Pocket","0.1a","Drak");
	
	// Load up the blocked items (items you can't pickpocket)
	new File[256]
	DRP_GetConfigsDir(File,255);
	
	add(File,255,"/PickPocket.ini");
	new Exist = file_exists(File);
	
	if(!Exist)
		write_file(File,"; Add a list of items in this file, that cannot be pickpockted");
	else
	{
		new pFile = fopen(File,"r"),Num,Results[1],Buffer[128]
		if(pFile)
		{
			while(!feof(pFile))
			{
				fgets(pFile,Buffer,127);
				
				if(Buffer[0] == ';' || !Buffer[0])
					continue
				
				Num = DRP_FindItemID(Buffer,Results,1);
				if(!Num || Num > 1)
				{
					server_print("[DRP - PickPocket] Unable to block item ^"%s^" (Returned: %d)",Buffer,Num);
					continue
				}
				
				g_BlockedItems[g_BlockedNum++] = Results[0]
			}
		}
		fclose(pFile);
	}
	
	// Commands
	DRP_RegisterChat("/pickpocket","CmdPocket","Attempts to pickpocket the user you are looking at");
}

public client_disconnect(id)
{
	g_PickedNum[id] = 0
	g_Cooldown[id] = 0.0
}

// TODO:
// Use the "SkillsMod" 'Basic' Skill to have a higher success rate
public CmdPocket(id)
{
	if(!is_user_alive(id))
		return PLUGIN_HANDLED
	
	new const Float:Time = get_gametime();
	if(Time - g_Cooldown[id] < 120.0)
	{
		client_print(id,print_chat,"[DRP] You can only pickpocket so often.");
		return PLUGIN_HANDLED
	}
	
	new Index,Body
	get_user_aiming(id,Index,Body,100);
	
	if(!Index || !is_user_alive(Index))
	{
		client_print(id,print_chat,"[DRP] You must be facing a user.");
		return PLUGIN_HANDLED
	}
	
	#if defined _SKILLSMOD
	new const UserBasicSkill = DRP_GetUserSkill(id,S_BASIC);
	new bool:Stop = false
	
	switch(UserBasicSkill)
	{
		// 50%
		case 0..20: if(!(chance(10))) Stop = true;
		case 21..40: if(!(chance(20))) Stop = true;
		case 41..50: if(!(chance(30))) Stop = true;
		case 51..60: if(!(chance(40))) Stop = true;
		case 61..70: if(!(chance(50))) Stop = true;
		case 81..90: if(!(chance(60))) Stop = true;
		case 91..100: if(!(chance(90))) Stop = true;
		
		// We should never get here. Since SMod only goes up to 100
		// but if we are higher than 100, don't stop
		default: Stop = false;
	}
	
	g_Cooldown[id] = Time
	
	if(Stop)
	{
		client_print(id,print_chat,"[DRP] Pickpocket Failed.");
		return PLUGIN_HANDLED
	}
	
	#else
	if((!chance(10)))
	{
		client_print(id,print_chat,"[DRP] Pickpocket Failed.");
		return PLUGIN_HANDLED
	}
	#endif
	
	new Float:tViewAngles[3],Float:ViewAngles[3]
	pev(id,pev_v_angle,ViewAngles);
	pev(Index,pev_v_angle,tViewAngles);
	
	new Float:minAngle,Float:maxAngle
	minAngle = ViewAngles[1] - BACKSTAB_ANGLE;
	maxAngle = ViewAngles[1] + BACKSTAB_ANGLE;
	
	if(minAngle <= tViewAngles[1] <= maxAngle)
	{
		new const UserCash = DRP_GetUserWallet(Index);
		if(UserCash < 1)
		{
			client_print(id,print_chat,"[DRP] You retrieved no cash/items.");
			return PLUGIN_HANDLED
			/*
			// We have no cash. Attempt to take an item. Possability should be really hard
			// 5% chance
			if(!(chance(5))
			{
				client_print(id,print_chat,"[DRP] You retrieved no cash/items.");
				return PLUGIN_HANDLED
			}
			
			new Num = DRP_FetchUserItems(id,Items);
			for(new Count;Count < Num;Count++)
			*/
		}
		else
		{
			new Amount;
			
			#if defined _SKILLSMOD
			switch(UserBasicSkill)
			{
				case 0..10: Amount = 5
				case 11..20: Amount = 10
				case 21..45: Amount = 15
				case 46..60: Amount = 20
				case 61..90: Amount = 25
				default:
				{
					Amount = 50
				}
			}
			
			Amount = random_num((UserBasicSkill >= 91) ? 25 : 1,Amount);
			if((UserCash - Amount) < 1)
				Amount = 0
			
			if(Amount)
			{
				DRP_SetUserWallet(Index,UserCash - Amount);
				DRP_SetUserWallet(id,DRP_GetUserWallet(id) + Amount);
			}
			
			client_print(id,print_chat,"[DRP] You have stolen $%d and no items.",Amount);
			
			#else
			Amount = random_num(1,5);
			if((UserCash - Amount) < 1)
				Amount = 0
			
			DRP_SetUserWallet(Index,UserCash - Amount);
			
			DRP_SetUserWallet(id,DRP_GetUserWallet(id) + Amount);
			client_print(id,print_chat,"[DRP] You have stolen $%d and no items.",Amount);
			#endif
		}
	}
	else
	{
		client_print(Index,print_chat,"[DRP] Somebody has attempted to pickpocket you.");
		client_print(id,print_chat,"[DRP] Pickpocket Failed. You have been seen.");
	}
	
	// Just to scare them
	switch(g_PickedNum[id]++)
	{
		case 10..20: client_print(id,print_chat,"[DRP] If you keep pickpocketing, you will be frowned upon.");
		case 21..50: client_print(id,print_chat,"[DRP] Your ^"Basic^" skill has dropped by one, from pickpocketing to much.");
	}
	
	return PLUGIN_HANDLED
}