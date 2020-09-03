/////////////////////////////////////////////////////////////////////////////////////
// Change log:
// 11/5/06
// Added support for taxes (Your money lost goes into the economy pot) - OLD/REMOVED
// --------------------------------------------------------------------------------
// 5/15/08 (I can't belive i'm working on this two years later)
// Plugin Created/Re-Made
// --------------------------------------------------------------------------------
// Author(s):
// Drak - Main Author
//////////////////////////////////////////////////////////////////////////////////////

#include <amxmodx>
#include <fakemeta>
#include <DRP/DRPCore>
#include <DRP/DRPNpc>

// Comment this out if you don't want the highscore system used
#define _USE_HIGHSCORES

#define NPC_DISTANCE 1000.0
#define MAX_CARDS 52 // 52 cards in a deck (no jokers)
#define MAX_SCORES 10 // the maximum amount of scores to keep track of

#define MAX_DICE_BET 100
#define MAX_SLOTS_BET 100
#define MAX_BLACKJACK_BET 100

#define SLOTS_JACKPOT 1500
#define SLOTS_BONUS 100 // if they get a "$" or "#" - they get this much more

// PCVars
new g_Npc
new Float:g_UserPlaying[33]
new g_UserGame[33]

new g_Menu
new g_BettingMenu
#if defined _USE_HIGHSCORES
new g_HighScoreMenu
#endif

// Hard-Coded Origin
// I'm not going to make this plugin public anyways. It was quick 'n dirty
new Float:Origin[3] = {-32.314739,542.031250,-403.9687}
new const g_BetMessage[] = "Betting Menu^nCurrent Bet: $0"

// Game Data
new g_UserBet[33]

new const g_SlotMachine[][1] =
{
	'A',
	'B',
	'#',
	'D',
	'$',
	'F',
	'Q',
	'G',
	'X'
}

new const g_GameNames[][10] =
{
	"",
	"Blackjack",
	"Dice",
	"Slots"
}

enum
{
	GAME_BJACK = 1,
	GAME_DICE,
	GAME_SLOTS
}

new g_SlotMachineShow[3][33][1]
new g_SlotInProgress[33]

// Dice
new g_DealerDice[33][2]
new g_UserDice[33][2]

// Blackjack
// 52 cards (no jokers)
new g_UserCards[33][MAX_CARDS]
new g_DealerCards[33][MAX_CARDS]

new Handle:g_SqlHandle

// We store the highscores into a SQL table
public DRP_Init()
{
	g_SqlHandle = DRP_SqlHandle();
	SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle","CREATE TABLE IF NOT EXISTS `CasinoScores` (AuthID VARCHAR(36),Game INT(11),Name VARCHAR(33),Score INT(11),PRIMARY KEY(AuthID))");
}

public plugin_init()
{
	// Main
	register_plugin("DRP - Casino","0.1a","Drak");
	
	// Menu
	g_Menu = menu_create("Mini Casino","_CasinoMenu");
	menu_additem(g_Menu,"Blackjack (Made by: Johnny)");
	menu_additem(g_Menu,"Simple Dice");
	menu_additem(g_Menu,"Slots");
	#if defined _USE_HIGHSCORES
	menu_additem(g_Menu,"High Scores^n");
	#endif
	menu_addtext(g_Menu,"You are able to move 1000 feet from this^nNPC",0);
	
	g_BettingMenu = menu_create("Betting Menu^nCurrent Bet: $0","_BetMenu");
	menu_additem(g_BettingMenu,"$20")
	menu_additem(g_BettingMenu,"$10");
	menu_additem(g_BettingMenu,"$5");
	menu_additem(g_BettingMenu,"$1^n");
	menu_additem(g_BettingMenu,"Reset");
	menu_additem(g_BettingMenu,"Done^n");
	
	#if defined _USE_HIGHSCORES
	g_HighScoreMenu = menu_create("Select a game:","_HScoreMenu");
	menu_additem(g_HighScoreMenu,"Blackjack (Made by: Johnny)");
	menu_additem(g_HighScoreMenu,"Simple Dice");
	menu_additem(g_HighScoreMenu,"Slots");
	#endif
	
	// Old Menu
	register_menucmd(register_menuid("[DICE] Game state:"),MENU_KEY_1|MENU_KEY_2,"_DiceFinish");
	
	// Create the NPC
	g_Npc = DRP_RegisterNPC("Mini Casino",Origin,90.0,"models/mecklenburg/bankerd_new.mdl","CmdCasino",0,"Bar",1);
}

public DRP_Error(const Reason[])
	pause("d");

public client_disconnect(id)
{
	g_UserPlaying[id] = 0.0
	g_UserGame[id] = 0
	g_SlotInProgress[id] = 0
}

public CmdCasino(id)
{
	if(!is_user_alive(id) || !DRP_NPCDistance(id,g_Npc,1,NPC_DISTANCE))
		return PLUGIN_HANDLED
	
	// Slots is the only game that has a task
	// So we don't want to bet / play a game while we are "spinning"
	
	if(g_SlotInProgress[id])
	{
		client_print(id,print_chat,"[DRP] You're already playing a game of slots.");
		return PLUGIN_HANDLED
	}
	
	menu_display(id,g_Menu);
	return PLUGIN_HANDLED
}
/*==================================================================================================================================================*/
public _CasinoMenu(id,Menu,Item)
{
	if(Item == MENU_EXIT || !DRP_NPCDistance(id,g_Npc,1,NPC_DISTANCE))
		return PLUGIN_HANDLED
	
	new Float:Time = get_gametime();
	g_UserBet[id] = 0
	
	// A very *small* time limit between playing should limit how much people play
	// Even if it's not alot
	if((Time - g_UserPlaying[id] < 30.0) && !DRP_IsAdmin(id))
	{
		client_print(id,print_chat,"[DRP] You must wait abit before playing again.");
		return PLUGIN_HANDLED
	}
	
	if(Item != 3)
	{
		g_UserGame[id] = Item + 1
		g_UserPlaying[id] = Time
		
		menu_setprop(g_BettingMenu,MPROP_TITLE,g_BetMessage);
		menu_display(id,g_BettingMenu);
		
		return PLUGIN_HANDLED
	}
	#if defined _USE_HIGHSCORES
	else
		menu_display(id,g_HighScoreMenu);
	#endif
	
	return PLUGIN_HANDLED
}

#if defined _USE_HIGHSCORES
public _HScoreMenu(id,Menu,Item)
{
	if(Item == MENU_EXIT)
		return PLUGIN_HANDLED
	
	new Query[126]
	
	switch(Item + 1)
	{
		case GAME_BJACK: formatex(Query,125,"SELECT Name,BJack FROM `CasinoScores` ORDER BY `BJack` DESC LIMIT 0,%d",MAX_SCORES);
		case GAME_DICE: formatex(Query,125,"SELECT Name,Dice FROM `CasinoScores` ORDER BY `Dice` DESC LIMIT 0,%d",MAX_SCORES);
		case GAME_SLOTS: formatex(Query,125,"SELECT Name,Slots FROM `CasinoScores` ORDER BY `Slots` DESC LIMIT 0,%d",MAX_SCORES);
	}
	
	new Data[2]
	Data[0] = id
	Data[1] = Item + 1
	
	client_print(id,print_chat,"[DRP] Fetching Top%d...",MAX_SCORES);
	SQL_ThreadQuery(g_SqlHandle,"FetchTopScores",Query,Data,2);
	
	return PLUGIN_HANDLED
}

public FetchTopScores(FailState,Handle:Query,const Error[],Errcode,const Data[],DataSize) 
{
	if(FailState != TQUERY_SUCCESS)
		return log_amx("[SQL ERROR] Unable to connect to SQL Database. (Error: %s)",Error ? Error : "UNKNOWN");
	
	new id = Data[0]
	
	if(!SQL_NumResults(Query))
	{
		client_print(id,print_chat,"[DRP] There are no high scores.");
		return PLUGIN_CONTINUE
	}
	
	new Menu[512],Temp[33],Cash,Pos,Num
	while(SQL_MoreResults(Query))
	{
		Cash = SQL_ReadResult(Query,1);
		
		if(!Cash)
		{
			SQL_NextRow(Query);
			continue
		}
		
		SQL_ReadResult(Query,0,Temp,32);
		Pos += formatex(Menu[Pos],511 - Pos,"Name: %s - $%d Cash Out^n",Temp,Cash)
		
		Num++
		SQL_NextRow(Query);
	}
	
	if(!Num)
	{
		client_print(id,print_chat,"[DRP] There are no high scores.");
		return PLUGIN_CONTINUE
	}
	
	Pos += formatex(Menu[Pos],511 - Pos,"^nThese are the top%d scores",MAX_SCORES);
	show_motd(id,Menu,g_GameNames[Data[1]]);
	
	return PLUGIN_CONTINUE
}
#endif
/*==================================================================================================================================================*/
public _BetMenu(id,Menu,Item)
{
	if(Item == MENU_EXIT || !DRP_NPCDistance(id,g_Npc,1,NPC_DISTANCE))
		return PLUGIN_HANDLED
	
	new Amount
	switch(Item)
	{
		case 0:
			Amount = 20
		case 1:
			Amount = 10
		case 2:
			Amount = 5
		case 3:
			Amount = 1
		case 4:
			Amount = 0
		case 5:
		{
			if(g_UserBet[id] <= 0)
			{
				client_print(id,print_chat,"[DRP] You must bet atleast $1 dollar.");
				return menu_display(id,Menu);
			}
			
			if(g_UserBet[id] > DRP_GetUserWallet(id))
			{
				client_print(id,print_chat,"[DRP] You don't have enough cash in your wallet for this bet.");
				g_UserBet[id] = 0
			}
			
			if(g_UserBet[id] > 0)
			{
				switch(g_UserGame[id])
				{
					case 1: BlackJack(id);
					case 2: Dice(id);
					case 3: Slots(id);
				}
				
				return PLUGIN_HANDLED
			}
		}
	}
	
	new MaxBet
	switch(g_UserGame[id])
	{
		case 1: MaxBet = MAX_BLACKJACK_BET
		case 2: MaxBet = MAX_DICE_BET
		case 3: MaxBet = MAX_SLOTS_BET
	}
	
	if((g_UserBet[id] + Amount) > MaxBet)
	{
		client_print(id,print_chat,"[DRP] You can only bet up to $%d for this game.",MaxBet);
		return menu_display(id,Menu);
	}
	
	if(!Amount)
		g_UserBet[id] = 0
	else
		g_UserBet[id] += Amount
	
	static szTitle[36]
	formatex(szTitle,35,"Betting Menu^nCurrent Bet: $%d",g_UserBet[id]);
	
	menu_setprop(Menu,MPROP_TITLE,szTitle);
	menu_display(id,Menu);
	
	return PLUGIN_HANDLED
}
/*==================================================================================================================================================*/
// BLACKJACK:
BlackJack(id)
{
	for(new Count;Count < MAX_CARDS;Count++)
	{
		g_UserCards[id][Count] = 0
		g_DealerCards[id][Count] = 0
	}
	
	g_UserCards[id][0] = random_num(1,13)
	g_UserCards[id][1] = random_num(1,13)
	
	g_DealerCards[id][0] = random_num(1,13)
	g_DealerCards[id][1] = random_num(1,13);
	
	BlackJackMainMenu(id);
}
DealerPlay(id,PlayerTotal)
{
	new Empty
	new DealerTotal,bool:DealerAce,bool:done_playing

	while(!done_playing)
	{
		for(new Count;Count < MAX_CARDS;Count++)
		{
			switch(g_DealerCards[id][Count])
			{
				case 0:
				{
					if(Empty == 0)
						Empty = Count
				}
				case 1:
				{
					// An ace.
					DealerAce = true
					DealerTotal += 1
				}
				case 11:
				{
					// A Jack.
					DealerTotal += 10
				}
				case 12:
				{
					// A Queen.
					DealerTotal += 10
				}
				case 13:
				{
					// A King.
					DealerTotal += 10
				}
				default:
				{
					// Just a simple number.
					DealerTotal += g_DealerCards[id][Count]
				}
			}
		}
		
		if(DealerTotal >= PlayerTotal)
		{
			// Dealers don't attempt to go over the value they need to.
			done_playing = true
		}
		else
		{
			if(DealerAce && (DealerTotal < 12))
			{
				// Dealer has a significant ambiguous ace.
				if(DealerTotal + 10 >= PlayerTotal)
				{
					// Dealer + ace value (as 11) is over player's value.
					done_playing = true
				}
				else
				{
					// Dealer's gonna risk not using the ace.
					g_DealerCards[id][Empty] = random_num(1,13);
				}
			}
			else
			{
				// Dealer decides to hit.
				g_DealerCards[id][Empty] = random_num(1,13);
			}
		}
	}
}
BlackJackMainMenu(id,Done = 0)
{
	// Vals
	new DealerTotal,bool:DealerAce
	new PlayerTotal,bool:PlayerAce
	
	// Strings
	new PlayerCards[33],DealerCards[33],Temp[4]
	
	for(new Count;Count < MAX_CARDS;Count++)
	{
		switch(g_UserCards[id][Count])
		{
			case 0:
			{
			}
			case 1:
			{
				PlayerTotal += 1
				PlayerAce = true
				add(PlayerCards,32,"A ");
			}
			case 11:
			{
				// A Jack.
				PlayerTotal += 10
				add(PlayerCards,32,"J ");
			}
			case 12:
			{
				// A Queen.
				PlayerTotal += 10
				add(PlayerCards,32,"Q ");
			}
			case 13:
			{
				// A King.
				PlayerTotal += 10
				add(PlayerCards,32,"K ");
			}
			case 10:
			{
				// A Ten.
				PlayerTotal += 10
				add(PlayerCards,32,"10 ");
			}
			default:
			{
				PlayerTotal += g_UserCards[id][Count]
				formatex(Temp,3,"%d ",g_UserCards[id][Count]);
				add(PlayerCards,32,Temp);
			}
		}
	}
	
	if(PlayerTotal > 21)
		Done = 1
	
	else if(Done)
	{
		// Player didn't bust, and the game's over
		// The dealer needs to play
		if(PlayerAce && (PlayerTotal < 12))
			DealerPlay(id,PlayerTotal + 10);
		else
			DealerPlay(id,PlayerTotal);
	}
	
	for(new Count;Count < MAX_CARDS;Count++)
	{
		switch(g_DealerCards[id][Count])
		{
			case 0:
			{
			}
			case 1:
			{
				// An ace.
				DealerAce = true
				DealerTotal += 1
				
				if(Count == 0 && !Done)
					add(DealerCards,32,"# ");
				else
					add(DealerCards,32,"A ");
			}
			case 11:
			{
				// A Jack.
				DealerTotal += 10
				if(Count == 0 && !Done)
					add(DealerCards,32,"# ");
				else
					add(DealerCards,32,"J ");
			}
			case 12:
			{
				// A Queen.
				DealerTotal += 10
				if(Count == 0 && !Done)
					add(DealerCards,32,"# ");
				else
					add(DealerCards,32,"Q ");
			}
			case 13:
			{
				// A King.
				DealerTotal += 10
				if(Count == 0 && !Done)
					add(DealerCards,32,"# ");
				else
					add(DealerCards,32,"K ");
			}
			case 10:
			{
				// A Ten.
				DealerTotal += 10
				if(Count == 0 && !Done)
					add(DealerCards,32,"# ");
				else
					add(DealerCards,32,"10 ");
			}
			default:
			{
				// Just a simple number.
				DealerTotal += g_DealerCards[id][Count]
				if(Count == 0 && !Done)
					add(DealerCards,32,"# ");
				else
				{
					formatex(Temp,3,"%d ",g_DealerCards[id][Count]);
					add(DealerCards,32,Temp);
				}
			}
		}
	}
	
	new szMenu[128],Won
	
	if(Done)
	{
		if(PlayerAce && (PlayerTotal < 12))
			PlayerTotal += 10
		if(DealerAce && (DealerTotal < 12))
			DealerTotal += 10
		
		// They lost
		if(PlayerTotal > 21)
			formatex(szMenu,127,"[BJACK]^nGame Status:^n^nDealer's Cards:  %s^nDealer's Total:  %d^n^nYour Cards:  %s^nYour Total:  %d^n^nYou Lost (Busted)^n",DealerCards,DealerTotal,PlayerCards,PlayerTotal);
		else if(DealerTotal > 21)
			{ Won = 2; formatex(szMenu,127,"[BJACK]^nGame Status:^n^nDealer's Cards:  %s^nDealer's Total:  %d^n^nYour Cards:  %s^nYour Total:  %d^n^nYou Won (Dealer Busted)^n",DealerCards,DealerTotal,PlayerCards,PlayerTotal); }
		else
		{
			if(PlayerTotal > DealerTotal)
				{ Won = 1; formatex(szMenu,127,"[BJACK]^nGame Status:^n^nDealer's Cards:  %s^nDealer's Total:  %d^n^nYour Cards:  %s^nYour Total:  %d^n^nYou Won^n",DealerCards,DealerTotal,PlayerCards,PlayerTotal); }
			else if(PlayerTotal < DealerTotal)
				formatex(szMenu,127,"[BJACK]^nGame Status:^n^nDealer's Cards:  %s^nDealer's Total:  %d^n^nYour Cards:  %s^nYour Total:  %d^n^nYou Lost^n",DealerCards,DealerTotal,PlayerCards,PlayerTotal);
			else
			{
				formatex(szMenu,127,"[BJACK]^nGame Status:^n^nDealer's Cards:  %s^nDealer's Total:  %d^n^nYour Cards:  %s^nYour Total:  %d^n^nYou Tied^n",DealerCards,DealerTotal,PlayerCards,PlayerTotal);
				Won = 1
			}
		}
		
		switch(Won)
		{
			case 1:
				DRP_SetUserWallet(id,(g_UserBet[id]  / 2) + DRP_GetUserWallet(id));
			case 2:
				DRP_SetUserWallet(id, g_UserBet[id] + DRP_GetUserWallet(id));
			default:
				DRP_SetUserWallet(id,DRP_GetUserWallet(id) - g_UserBet[id]);
		}
	}
	else
	{
		if(PlayerAce && (PlayerTotal <12))
			formatex(szMenu,127,"[BJACK]^nGame Status:^n^nDealer's Cards:  %s^n^nYour Cards:  %s^nYour Total:  %d (or %d)^n^n",DealerCards,PlayerCards,PlayerTotal,PlayerTotal + 10);
		else
			formatex(szMenu,127,"[BJACK]^nGame Status:^n^nDealer's Cards:  %s^n^nYour Cards:  %s^nYour Total:  %d^n^n",DealerCards,PlayerCards,PlayerTotal);
	}
	
	new Menu = menu_create(szMenu,"_BJackHandle");
	if(!Done)
	{
		menu_additem(Menu,"Hit");
		menu_additem(Menu,"Stand");
	}
	else
	{
		menu_additem(Menu,"Play Again");
		g_UserGame[id] = -1
	}
	
	menu_display(id,Menu);
}
public _BJackHandle(id,Menu,Item)
{
	menu_destroy(Menu);
	
	if(Item == MENU_EXIT)
		return PLUGIN_HANDLED
	
	switch(Item)
	{
		case 0:
		{
			// We are done
			if(g_UserGame[id] == -1)
			{
				ResetBetting(id,GAME_BJACK);
				return PLUGIN_HANDLED
			}
			
			// They're hitting.
			new Empty
			for(new Count;Count < MAX_CARDS;Count++)
			{
				if(g_UserCards[id][Count] == 0 && Empty == 0)
					Empty = Count
			}
			
			g_UserCards[id][Empty] = random_num(1,13);
			BlackJackMainMenu(id,0);
		}
		case 1: BlackJackMainMenu(id,1);
	}
	
	return PLUGIN_HANDLED
}
/*==================================================================================================================================================*/
// DICE:
// We roll two dices - we have to roll higher than the dealer to win
// Extremely Simple
Dice(id)
{
	g_DealerDice[id][0] = random_num(1,6);
	g_DealerDice[id][1] = random_num(1,6);
	g_UserDice[id][0] = random_num(1,6);
	g_UserDice[id][1] = random_num(1,6);
	
	// Make the outcome menu
	new Dealer = (g_DealerDice[id][0] + g_DealerDice[id][1]),Total = (g_UserDice[id][0] + g_UserDice[id][1])
	new Menu[256],State[6],Wallet = DRP_GetUserWallet(id);
	
	if(Dealer == Total)
		copy(State,5,"Tie");
	else if(Dealer > Total)
	{
		copy(State,5,"Lost");
		DRP_SetUserWallet(id,Wallet - g_UserBet[id]);
	}
	else
	{
		copy(State,5,"Won");
		DRP_SetUserWallet(id,Wallet + g_UserBet[id]);
	}
	formatex(Menu,255,"[DICE] Game state:^n^nDealers roll: %i/%i^nDealers Total: %i^n^nMoney bet: $%i^nYou: %s^n^nYour roll: %i/%i^nTotal: %i^n^n1. Exit^n2. Play Again",
	g_DealerDice[id][0],g_DealerDice[id][1],Dealer,g_UserBet[id],State,g_UserDice[id][0],g_UserDice[id][1],Total);
	
	#if defined _USE_HIGHSCORES
	if(State[0] == 'W')
		UpdateScore(id,GAME_DICE,g_UserBet[id]);
	#endif
	
	show_menu(id,MENU_KEY_1|MENU_KEY_2,Menu);
}
public _DiceFinish(id,Key)
{
	if(!DRP_NPCDistance(id,g_Npc,1,NPC_DISTANCE))
		return
	
	server_print("Key dice: %d",Key);
	switch(Key)
	{
		case 0: return
		case 1: ResetBetting(id,GAME_DICE);
	}
}
/*==================================================================================================================================================*/
// SLOTS:
Slots(id)
{
	if(g_SlotInProgress[id])
		return
	
	for(new Count = 0;Count < 3;Count++)
		g_SlotMachineShow[Count][id][0] = 0
	
	new szBet[128]
	formatex(szBet,127,"-------^n-  -  -^n-------^n^nBet: $%d",g_UserBet[id]);
	new Menu = menu_create(szBet,"_SlotsHandle");
	
	menu_additem(Menu,"Spin Wheel");
	menu_additem(Menu,"Change Bet^n");
	
	formatex(szBet,127,"If you score ^"X X X^" you win,^nthe jackpot of: $%d",SLOTS_JACKPOT);
	
	menu_addtext(Menu,szBet,0);
	menu_display(id,Menu);
}
public _SlotsHandle(id,Menu,Item)
{
	menu_destroy(Menu);
	
	if(Item == MENU_EXIT)
		return PLUGIN_HANDLED
	
	switch(Item)
	{
		case 0:
		{
			new Params[3]
			Params[0] = id
			Params[1] = 0
			Params[2] = 0
			
			set_task(0.1,"AnimateWheel",_,Params,3);
			client_print(id,print_chat,"[DRP] Spinning Wheel..");
			
			g_SlotInProgress[id] = 1
		}
		case 1: ResetBetting(id,GAME_SLOTS);
	}
	return PLUGIN_HANDLED
}

public AnimateWheel(Params[3])
{
	new id = Params[0],Menu = Params[1],Wheel = Params[2]
	new szTitle[128]
	
	if(!is_user_alive(id))
	{
		if(Menu)
			menu_destroy(Menu);
		
		g_SlotInProgress[id] = 0
		return
	}
	
	if(!Menu)
	{
		Menu = menu_create(szTitle,"_DummySlots");
		
		menu_additem(Menu,"Exit");
		menu_additem(Menu,"Play Again^n");
		menu_setprop(Menu,MPROP_EXIT,MEXIT_NEVER);
		
		Params[1] = Menu
	}
	
	switch(Wheel)
	{
		case 0:
		{
			Wheel = 1
			copy(g_SlotMachineShow[0][id],1,g_SlotMachine[random(sizeof(g_SlotMachine))]);
		}
		case 1:
		{
			Wheel = 2
			copy(g_SlotMachineShow[1][id],1,g_SlotMachine[random(sizeof(g_SlotMachine))]);
		}
		case 2:
		{
			Wheel = 3
			copy(g_SlotMachineShow[2][id],1,g_SlotMachine[random(sizeof(g_SlotMachine))]);
		}
	}
	
	Params[2] = Wheel
	
	if(Wheel != 3)
	{
		formatex(szTitle,127,"---------^n%s  %s  %s^n---------^n^nBet: $%d",g_SlotMachineShow[0][id],g_SlotMachineShow[1][id],g_SlotMachineShow[2][id],g_UserBet[id]);
		menu_setprop(Menu,MPROP_TITLE,szTitle);
		
		menu_display(id,Menu);
		set_task(3.0,"AnimateWheel",_,Params,3);
	}
	else
	{
		new Matches,Bonus
		if(g_SlotMachineShow[0][id][0] == 'X' && g_SlotMachineShow[1][id][0] == 'X' && g_SlotMachineShow[2][id][0] == 'X')
			Matches = -1
		else if(g_SlotMachineShow[0][id][0] == g_SlotMachineShow[1][id][0] && g_SlotMachineShow[1][id][0] == g_SlotMachineShow[2][id][0])
			Matches = 3
		else if(g_SlotMachineShow[0][id][0] == g_SlotMachineShow[1][id][0] || g_SlotMachineShow[1][id][0] == g_SlotMachineShow[2][id][0] || g_SlotMachineShow[0][id][0] == g_SlotMachineShow[2][id][0])
			Matches = 2
		
		new Count
		for(Count = 0;Count < 3;Count++)
			if(g_SlotMachineShow[Count][id][0] == '$' || g_SlotMachineShow[Count][id][0] == '#')
				Bonus = 1
		
		new WonAmount,State[10]
		switch(Matches)
		{
			case -1:
			{
				new plName[33]
				get_user_name(id,plName,32);
				
				BarAnnouncement("[DRP][BAR CASINO] %s has just won the slot jackpot of $%d!",plName,SLOTS_JACKPOT);
				WonAmount = SLOTS_JACKPOT
				
				copy(State,9,"Won");
			}
			case 0..1:
			{
				WonAmount = 0
				copy(State,9,"Lost");
			}
			case 2:
			{
				WonAmount = (g_UserBet[id] / 2)
				copy(State,9,"Won half");
			}
			case 3: 
			{
				WonAmount = g_UserBet[id]
				copy(State,9,"Won");
			}
		}
		WonAmount > 0 ?
			DRP_SetUserWallet(id,DRP_GetUserWallet(id) + WonAmount) : DRP_SetUserWallet(id,DRP_GetUserWallet(id) - g_UserBet[id]);
		
		formatex(szTitle,127,"---------^n%s  %s  %s^n---------^n^nBet: $%d^nYou: %s (With%s Bonus)",g_SlotMachineShow[0][id],g_SlotMachineShow[1][id],g_SlotMachineShow[2][id],g_UserBet[id],State,Bonus ? "" : "out");
		
		menu_setprop(Menu,MPROP_TITLE,szTitle);
		menu_display(id,Menu);
		
		#if defined _USE_HIGHSCORES
		if(WonAmount > 0)
			UpdateScore(id,GAME_SLOTS,WonAmount);
		#endif
		
		g_SlotInProgress[id] = 0
	}
}
public _DummySlots(id,Menu,Item)
{
	if(g_SlotInProgress[id])
		return PLUGIN_HANDLED
	
	menu_destroy(Menu);
	
	if(Item == 1)
	{
		if(!DRP_NPCDistance(id,g_Npc,1,NPC_DISTANCE))
			return PLUGIN_HANDLED
		
		ResetBetting(id,GAME_SLOTS);
	}
	
	return PLUGIN_HANDLED
}
/*==================================================================================================================================================*/
// Anyone within "NPC_DISTANCE" of the bar NPC will hear this message (in-chat)
// I used it to announce high-scores and such
BarAnnouncement(const Message[],any:...)
{
	new vMessage[128]
	vformat(vMessage,127,Message,2);
	
	new iPlayers[32],iNum,Index
	get_players(iPlayers,iNum);
	
	for(new Count;Count < iNum;Count++)
	{
		Index = iPlayers[Count]
		if(DRP_NPCDistance(Index,g_Npc,0,NPC_DISTANCE))
			client_print(Index,print_chat,"%s",vMessage);
	}
}
ResetBetting(id,Game)
{
	g_UserBet[id] = 0
	g_UserGame[id] = Game
	
	menu_setprop(g_BettingMenu,MPROP_TITLE,g_BetMessage);
	menu_display(id,g_BettingMenu);
}
	
public plugin_end()
{
	menu_destroy(g_Menu);
	menu_destroy(g_BettingMenu);
	#if defined _USE_HIGHSCORES
	menu_destroy(g_HighScoreMenu);
	#endif
}

#if defined _USE_HIGHSCORES
UpdateScore(id,Game,Score_Cash)
{
	if(!is_user_connected(id))
		return
	
	new AuthID[36],Query[256],plName[64]
	get_user_authid(id,AuthID,35);
	
	get_user_name(id,plName,63);
	replace_all(plName,63,"'","\'");
	
	switch(Game)
	{
		case GAME_BJACK: formatex(Query,255,"INSERT INTO `CasinoScores` VALUES('%s','%s','%d','0','0') ON DUPLICATE KEY UPDATE `BJack`='%d',`Name`='%s'",AuthID,plName,Score_Cash,Score_Cash,plName);
		case GAME_DICE: formatex(Query,255,"INSERT INTO `CasinoScores` VALUES('%s','%s','0','%d','0') ON DUPLICATE KEY UPDATE `Dice`='%d',`Name`='%s'",AuthID,plName,Score_Cash,Score_Cash,plName);
		case GAME_SLOTS: formatex(Query,255,"INSERT INTO `CasinoScores` VALUES('%s','%s','0','0','%d') ON DUPLICATE KEY UPDATE `Slots`='%d',`Name`='%s'",AuthID,plName,Score_Cash,Score_Cash,plName);
	}
	
	SQL_ThreadQuery(g_SqlHandle,"IgnoreHandle",Query);
}
#endif

public IgnoreHandle(FailState,Handle:Query,const Error[],Errcode,const Data[],DataSize) 
{
	if(FailState != TQUERY_SUCCESS)
		return log_amx("[SQL ERROR] Unable to connect to SQL Database. (Error: %s)",Error ? Error : "UNKNOWN");
	
	return PLUGIN_CONTINUE
}

/*

#define PLUGIN "CasinoMod"
#define VERSION "1.5"
#define AUTHOR "Drak"

#define MAX_CARDS 22
#define MAX_MENU_CHARS 256


#define DICE_LIMIT 80 // Max bet for dice
#define BLACK_LIMIT 1000 // Max bet for blackjack


new player_cards[32][MAX_CARDS]
new dealer_cards[32][MAX_CARDS]
new player_bet[32]

new dealer_dice[33][2]
new player_dice[33][2]
new dice_bet[33]
new allow_casino[33] 

new BarOrigin[3] = { 100, 637, -411 } 

// PCvars
new p_Enable

/////////////////////////////////////////////
// Initialization
/////////////////////////////////////////////
public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_clcmd("say /casino","Casino_Main_Menu",0,"- Allows you to play casino games in the bar")

	// This registers the menus.
	register_menucmd(register_menuid("[BLKJK] Set your bet:"),1023,"SetBet")
	register_menucmd(register_menuid("[Dice] Set your bet:"),1023,"DiceSetBet")
	register_menucmd(register_menuid("[Dice] Game state:"),1023,"DiceMainMenu2")
	register_menucmd(register_menuid("[BLKJK] Game state:"),1023,"PlayGame")
	register_menucmd(register_menuid("Choose a game"),1023,"Casino_Main_Action")

	// This registers the CVARS used.
	p_Enable = register_cvar("DRP_Casino","1"); // 0 = Disabled 1 = Allow Everybody 2 = Rights only (Set via)
	
}

////////////////////
// Timers/Resets
////////////////////
// The timer were they can play again
public reset_time(id)
{
	id -=204
	allow_casino[id] = 1
}
public client_disconnect(id) { 
	allow_casino[id] = 1
	if(task_exists(id+204)) remove_task(id+204)
}
public client_putinserver(id) { 
	allow_casino[id] = 1
}


public Casino_Main_Menu(id)
{
	// Blah, blah. Basic Checking
	if(!is_user_alive(id)) 
		return PLUGIN_HANDLED
		
	if(!get_pcvar_num(p_Enable)) {
		client_print(id,print_chat,"[Casino] Sorry, The Casino is disabled.")
		return PLUGIN_HANDLED
	}
	
	if(allow_casino[id] <= 0) { 
		client_print(id,print_chat,"[Casino] Please wait abit before playing again...^n")
		return PLUGIN_HANDLED
	}
	
	new menu[256],myorigin[3]
	
	get_user_origin(id,myorigin)
	if(get_distance(myorigin,BarOrigin) < 300)
	{
		new key = (1<<0|1<<1|1<<2|1<<3|1<<4)
		new len = format(menu,sizeof(menu),"Choose a game to play^n^n")
		
		len += format(menu[len],sizeof(menu)-len,"1. Blackjack (Made by: Johnny)^n")
		len += format(menu[len],sizeof(menu)-len,"2. Dice (Made by: Drak)^n^n")
		len += format(menu[len],sizeof(menu)-len,"3. Close Menu^n^n")
		len += format(menu[len],sizeof(menu)-len,"** All games use you're wallet balance.^n")
		len += format(menu[len],sizeof(menu)-len,"** Your wallet can go negative.^n")
		show_menu(id,key,menu)
		
		return PLUGIN_HANDLED
	}
	else client_print(id,print_chat,"[Casino] You must be in the bar^n")
		
	return PLUGIN_HANDLED
}


public Casino_Main_Action(id,key)
{
	switch(key)
	{
		case 0:
		{
			if(!user_in_bar(id)) {
				client_print(id,print_chat,"[Casino] You must be in the bar!")
				return PLUGIN_HANDLED
			}
			client_print(id,print_chat,"[Casino] Game of blackjack started!")
			StartBlackJack(id)
		}
		case 1:
		{
			if(!user_in_bar(id)) {
				client_print(id,print_chat,"[Casino] You must be in the bar!")
				return PLUGIN_HANDLED
			}
			client_print(id,print_chat,"[Casino] Game of dice started!^n")
			startdice(id)
		}
		case 3: return PLUGIN_HANDLED
	}
	return PLUGIN_HANDLED
}
// =============
// Dice
// =============
public startdice(id)
{
	if(!user_in_bar(id)) {
		client_print(id,print_chat,"[Casino] You must be in the bar!")
		return PLUGIN_HANDLED
	}
	
	dealer_dice[id][0] = random_num(2,6)
	dealer_dice[id][1] = random_num(2,6)
	player_dice[id][0] = random_num(2,6)
	player_dice[id][1] = random_num(2,6)
		
	dice_bet[id] = 0
		
	DiceBetMenu(id)
	
	return PLUGIN_CONTINUE
}

public DiceBetMenu(id)
{
	if(!is_user_alive(id)) 
		return PLUGIN_HANDLED
	
	new menu_body[257]
	new balance = get_user_rpmoney(id,"wallet")
	new menu_keys = (1<<0|1<<1|1<<2|1<<3|1<<4|1<<5)
	
	// Put it all together in a big string.
	formatex(menu_body,256,"[Dice] Set your bet:^n^nCurrent funds: $%d^nCurrent bet: $%d^n^n1. 10^n2. 5^n3. 1^n^n4. Done^n^n5. Exit",balance,dice_bet[id])
	
	// Send it to the player.
	show_menu(id,menu_keys,menu_body)  
	
	return PLUGIN_CONTINUE
}

public DiceSetBet(id,key){ 
	switch(key)
	{
		case 0:
		{
			// Add to their bet.
			dice_bet[id] += 10
			DiceBetMenu(id)
		}
		case 1:
		{
			// Add to their bet.
			dice_bet[id] += 5
			DiceBetMenu(id)
		}
		case 2:
		{
			// Add to their bet.
			dice_bet[id] += 1
			DiceBetMenu(id)
		}
		case 3:
		{
			new balance = get_user_rpmoney(id,"wallet")
			
			if(dice_bet[id] > balance)
			{
				client_print(id,print_chat,"[Casino] You don't have that money to bet!")
				return PLUGIN_HANDLED
			}
			if(dice_bet[id] <= 0)
			{
				client_print(id,print_chat,"[Casino] You must atleast bet $1.00^n")
				DiceBetMenu(id)
				return PLUGIN_HANDLED
			}
			if(dice_bet[id] > DICE_LIMIT)
			{
				client_print(id,print_chat,"[Casino] You bet to much, limit is $%i (You bet $%i)",DICE_LIMIT,dice_bet[id])
				dice_bet[id] = 0
				DiceBetMenu(id)
				return PLUGIN_HANDLED
			}
			// They're done betting.
			DiceGameMenu(id)
		}
		case 4: return PLUGIN_HANDLED
	}
	return PLUGIN_HANDLED
}

public DiceGameMenu(id)
{
	new menu_body[256]
	new menu_keys = (1<<0|1<<1|1<<2|1<<3|1<<4)
	new total = dealer_dice[id][0] + dealer_dice[id][1]
	new player_roll = player_dice[id][0] + player_dice[id][1]
	
	if(player_roll > total)
	{
		native_edit_value(id,"money","wallet","+",dice_bet[id])
		formatex(menu_body,256,"[Dice] Game state:^n^nDealers roll: %i/%i^nDealers Total: %i^n^nMoney bet: $%i^n^nYour roll: %i/%i^nTotal: %i^nState: You Won!^n^n1. Roll Again^n2. Quit^n",dealer_dice[id][0],dealer_dice[id][1],total,dice_bet[id],player_dice[id][0],player_dice[id][1],player_roll)
	}
	if(player_roll == total)
	{
		formatex(menu_body,256,"[Dice] Game state:^n^nDealers roll: %i/%i^nDealers Total: %i^n^nMoney bet: $%i^n^nYour roll: %i/%i^nTotal: %i^nState: Tie Game!^n^n1. Roll Again^n2. Quit^n",dealer_dice[id][0],dealer_dice[id][1],total,dice_bet[id],player_dice[id][0],player_dice[id][1],player_roll)	
	}
	if(player_roll < total)
	{
		if(dice_bet[id] > 2) {
			new tax = dice_bet[id] / 2
			native_economy_add("economypot","val",tax)
			client_print(id,print_chat,"[Casino] DEBUG: Tax added: %i",tax)
		}
		
		native_edit_value(id,"money","wallet","-",dice_bet[id])
		formatex(menu_body,256,"[Dice] Game state:^n^nDealers roll: %i/%i^nDealers Total: %i^n^nMoney bet: $%i^n^nYour roll: %i/%i^nTotal: %i^nState: You Lost!^n^n1. Roll Again^n2. Quit^n",dealer_dice[id][0],dealer_dice[id][1],total,dice_bet[id],player_dice[id][0],player_dice[id][1],player_roll)
	}	
	show_menu(id,menu_keys,menu_body)
	return PLUGIN_HANDLED
}

public DiceMainMenu2(id,key) {
	switch(key)
	{
		case 0: startdice(id)
		case 1:
		{
			client_print(id,print_chat,"[Dice] Thanks for playing!^n")
			allow_casino[id] = 0
			set_task(100.0,"reset_time",id+204,"",0)
		}
	}
	return PLUGIN_HANDLED
}

// -----------------
// BlackJack
// -----------------
public StartBlackJack(id)
{
	if(!user_in_bar(id)) {
		client_print(id,print_chat,"[Casino] You have moved away from the bar stools!")
		return PLUGIN_HANDLED
	}
	new card_num
	
	// Reset the cards for this player (and their dealer)
	for(card_num=0; card_num < MAX_CARDS; card_num++)
	{
		player_cards[id][card_num] = 0
		dealer_cards[id][card_num] = 0
	}

	// Give this player (and their dealer) a couple random cards.
	player_cards[id][0] = random_num(1,13)
	player_cards[id][1] = random_num(1,13)
	dealer_cards[id][0] = random_num(1,13)
	dealer_cards[id][1] = random_num(1,13)
		
	// This player has bet no money yet, yo.
	player_bet[id] = 0

	// Show the betting menu.
	ShowBetMenu(id)
	
	return PLUGIN_CONTINUE
}

public ShowBetMenu(id)
{
	if(!is_user_alive(id)) 
		return PLUGIN_HANDLED
	
	new menu_body[256]

	new balance = get_user_rpmoney(id,"wallet")
	new menu_keys = (1<<0|1<<1|1<<2|1<<3|1<<4|1<<5)
	
	// Put it all together in a big string.
	formatex(menu_body,256,"[BLKJK] Set your bet:^n^nCurrent funds: $%d^nCurrent bet: $%d^n^n1. 100^n2. 10^n3. 5^n4. 1^n5. Done^n^n6. Exit",balance,player_bet[id])
	
	// Send it to the player.
	show_menu(id,menu_keys,menu_body,100) 
	
	return PLUGIN_CONTINUE
}

public SetBet(id,key){ 
	switch(key)
	{
		case 0:
		{
			// Add to their bet.
			player_bet[id] += 100
			ShowBetMenu(id)
		}
		case 1:
		{
			// Add to their bet.
			player_bet[id] += 10
			ShowBetMenu(id)
		}
		case 2:
		{
			// Add to their bet.
			player_bet[id] += 5
			ShowBetMenu(id)
		}
		case 3:
		{
			// Add to their bet.
			player_bet[id] += 1
			ShowBetMenu(id)
		}
		case 4:
		{
			new balance = get_user_rpmoney(id,"wallet")
			if(player_bet[id] <= 0)
			{
				client_print(id,print_chat,"[Dealer] You must bet atleast $1.00!^n")
				ShowBetMenu(id)
				return PLUGIN_HANDLED
			}
			if(player_bet[id] > balance)
			{
				client_print(id,print_chat,"[Dealer] You don't have that money to bet!")
				return PLUGIN_HANDLED
			}
			if(player_bet[id] > BLACK_LIMIT)
			{
				client_print(id,print_chat,"[Dealer] Bet to high! Max $%i (You bet $%i)",BLACK_LIMIT,player_bet[id])
				player_bet[id] = 0
				ShowBetMenu(id)
				return PLUGIN_HANDLED
			}
			//allow_casino[id] = 0
			//set_task(120.0,"reset_time",id)
			ShowGameMenu(id, false)
		}
		case 5: client_print(id,print_chat,"[Casino] Thanks for playing!^n")
	}
	return PLUGIN_HANDLED
}

public ShowGameMenu(id, game_done)
{
	new player_total = 0 // Player's total (of card values).
	new dealer_total = 0 // Dealer's total (of card values).
	new card_num          // Card incrementer.
	new player_has_ace   // Does the player have an ace?
	new dealer_has_ace   // Does the dealer have an ace?
	new player_cards_string[MAX_CARDS * 3]   // A string for the player's cards.
	new dealer_cards_string[MAX_CARDS * 3]   // A string for the dealer's cards.
	new card_temp_player[3] // A temporary card string.
	new card_temp_dealer[3] // A temporary card string.
	new menu_body[MAX_MENU_CHARS]  // The menu body message.
	new menu_keys       // The menu keys.

	player_has_ace = false
	dealer_has_ace = false

	for (card_num = 0; card_num < MAX_CARDS; card_num++)
	{
		switch(player_cards[id][card_num])
		{
			case 0:
			{
				// No card in this slot.
			}
			case 1:
			{
				// An ace.
				player_has_ace = true
				player_total += 1
				add(player_cards_string, MAX_CARDS * 3, "A ");
			}
			case 11:
			{
				// A Jack.
				player_total += 10
				add(player_cards_string, MAX_CARDS * 3, "J ");
			}
			case 12:
			{
				// A Queen.
				player_total += 10
				add(player_cards_string, MAX_CARDS * 3, "Q ");
			}
			case 13:
			{
				// A King.
				player_total += 10
				add(player_cards_string, MAX_CARDS * 3, "K ");
			}
			case 10:
			{
				// A Ten.
				player_total += 10
				add(player_cards_string, MAX_CARDS * 3, "10 ");
			}
			default:
			{
				// Just a simple number.
				player_total += player_cards[id][card_num]
				format(card_temp_player,3,"%d ",player_cards[id][card_num])
				add(player_cards_string, MAX_CARDS * 3, card_temp_player)
			}
		}
	}

	if (player_total > 21)
	{
		game_done = true
	}
	else if(game_done)
	{
		// Player didn't bust, and the game's over.
		// The dealer needs to play.
		if (player_has_ace && (player_total < 12))
		{
			DealerPlay(id, player_total + 10)
		}
		else
		{
			DealerPlay(id, player_total)
		}
	}

	for (card_num = 0; card_num < MAX_CARDS; card_num++)
	{
		switch(dealer_cards[id][card_num])
		{
			case 0:
			{
				// No card in this slot.
			}
			case 1:
			{
				// An ace.
				dealer_has_ace = true
				dealer_total += 1
				if(card_num==0 && !game_done)
				{
					add(dealer_cards_string, MAX_CARDS * 3, "# ");
				}
				else
				{
					add(dealer_cards_string, MAX_CARDS * 3, "A ");
				}
			}
			case 11:
			{
				// A Jack.
				dealer_total += 10
				if(card_num==0 && !game_done)
				{
					add(dealer_cards_string, MAX_CARDS * 3, "# ");
				}
				else
				{
					add(dealer_cards_string, MAX_CARDS * 3, "J ");
				}
			}
			case 12:
			{
				// A Queen.
				dealer_total += 10
				if(card_num==0 && !game_done)
				{
					add(dealer_cards_string, MAX_CARDS * 3, "# ");
				}
				else
				{
					add(dealer_cards_string, MAX_CARDS * 3, "Q ");
				}
			}
			case 13:
			{
				// A King.
				dealer_total += 10
				if(card_num==0 && !game_done)
				{
					add(dealer_cards_string, MAX_CARDS * 3, "# ");
				}
				else
				{
					add(dealer_cards_string, MAX_CARDS * 3, "K ");
				}
			}
			case 10:
			{
				// A Ten.
				dealer_total += 10
				if(card_num==0 && !game_done)
				{
					add(dealer_cards_string, MAX_CARDS * 3, "# ");
				}
				else
				{
					add(dealer_cards_string, MAX_CARDS * 3, "10 ");
				}
			}
			default:
			{
				// Just a simple number.
				dealer_total += dealer_cards[id][card_num]
				if(card_num==0 && !game_done)
				{
					add(dealer_cards_string, MAX_CARDS * 3, "# ");
				}
				else
				{
					format(card_temp_dealer,3,"%d ",dealer_cards[id][card_num])
					add(dealer_cards_string, MAX_CARDS * 3, card_temp_dealer)
				}
			}
		}
	}

	/////////////////		
	// Format the game menu.
	/////////////////

	if (game_done)
	{
		if (player_has_ace && (player_total < 12))
		{
			player_total += 10
		}

		if (dealer_has_ace && (dealer_total < 12))
		{
			dealer_total += 10
		}

		// They can only restart or exit.
		menu_keys = (1<<8)|(1<<9)


		if (player_total > 21)
		{
			//They busted!
			format(menu_body,MAX_MENU_CHARS,"[BLKJK] Game state:^n^nDealer's cards:   %s^nDealer's total:   %d^n^nYour cards:     %s^nYour total:      %d^n^nYou lost! (You busted)^n^n9. Play again!^n0. Exit", dealer_cards_string, dealer_total, player_cards_string, player_total)
			native_edit_value(id,"money","wallet","-",player_bet[id])
		}
		else if (dealer_total > 21)
		{
			//Dealer busted!
			format(menu_body,MAX_MENU_CHARS,"[BLKJK] Game state:^n^nDealer's cards:   %s^nDealer's total:   %d^n^nYour cards:     %s^nYour total:      %d^n^nYou won! (Dealer busted)^n^n9. Play again!^n0. Exit", dealer_cards_string, dealer_total, player_cards_string, player_total)
			native_edit_value(id,"money","wallet","+",player_bet[id])
		}
		else
		{
			if (player_total > dealer_total)
			{
				//They won
				format(menu_body,MAX_MENU_CHARS,"[BLKJK] Game state:^n^nDealer's cards:   %s^nDealer's total:   %d^n^nYour cards:     %s^nYour total:      %d^n^nYou won!^n^n9. Play again!^n0. Exit", dealer_cards_string, dealer_total, player_cards_string, player_total)
				native_edit_value(id,"money","wallet","+",player_bet[id])
			}
			else if(player_total < dealer_total)
			{
				//Dealer won.
				format(menu_body,MAX_MENU_CHARS,"[BLKJK] Game state:^n^nDealer's cards:   %s^nDealer's total:   %d^n^nYour cards:     %s^nYour total:      %d^n^nYou lost!^n^n9. Play again!^n0. Exit", dealer_cards_string, dealer_total, player_cards_string, player_total)
				native_edit_value(id,"money","wallet","-",player_bet[id])
			}
			else
			{
				//Tie game.
				format(menu_body,MAX_MENU_CHARS,"[BLKJK] Game state:^n^nDealer's cards:   %s^nDealer's total:   %d^n^nYour cards:     %s^nYour total:      %d^n^nTie game!^n^n9. Play again!^n0. Exit", dealer_cards_string, dealer_total, player_cards_string, player_total)
			}
		}
	}
	else
	{
		// They can hit or stand.
		menu_keys = (1<<0)|(1<<1)
		
		// Format the game board and stuff.
		if (player_has_ace && (player_total < 12))
		{
			format(menu_body,MAX_MENU_CHARS,"[BLKJK] Game state:^n^nDealer's cards:   %s^n^nYour cards:     %s^nYour total:      %d (or %d)^n^n1. Hit^n2. Stand", dealer_cards_string, player_cards_string, player_total, player_total + 10)
		}
		else
		{
			format(menu_body,MAX_MENU_CHARS,"[BLKJK] Game state:^n^nDealer's cards:   %s^n^nYour cards:     %s^nYour total:      %d^n^n1. Hit^n2. Stand", dealer_cards_string, player_cards_string, player_total)
		}
	}

	// Send it to the player.
	show_menu(id,menu_keys,menu_body)
}

public DealerPlay(id, player_total)
{
	new has_ace
	new dealer_total
	new card_num
	new done_playing
	new empty_slot = 0

	done_playing = false

	while(!done_playing)
	{
		for (card_num = 0; card_num < MAX_CARDS; card_num++)
		{
			switch(dealer_cards[id][card_num])
			{
				case 0:
				{
					// No card in this slot.
					if (empty_slot == 0)
					{
						empty_slot = card_num;
					}
				}
				case 1:
				{
					// An ace.
					has_ace = true;
					dealer_total += 1
				}
				case 11:
				{
					// A Jack.
					dealer_total += 10
				}
				case 12:
				{
					// A Queen.
					dealer_total += 10
				}
				case 13:
				{
					// A King.
					dealer_total += 10
				}
				default:
				{
					// Just a simple number.
					dealer_total += dealer_cards[id][card_num]
				}
			}
		}

		if (dealer_total >= player_total)
		{
			// Dealers don't attempt to go over the value they need to.
			done_playing = true
		}
		else
		{
			if (has_ace && (dealer_total < 12))
			{
				// Dealer has a significant ambiguous ace.
				if (dealer_total + 10 >= player_total)
				{
					// Dealer + ace value (as 11) is over player's value.
					done_playing = true
				}
				else
				{
					// Dealer's gonna risk not using the ace.
					dealer_cards[id][empty_slot] = random_num(1,13)
				}
			}
			else
			{
				// Dealer decides to hit.
				dealer_cards[id][empty_slot] = random_num(1,13)
			}
		}
	}
}

public PlayGame(id,key){ 
	new card_num       // A card number incrementer.
	new empty_slot = 0 // An empty card slot (to add a card to).

	switch(key)
	{
		case 0:
		{
			// They're hitting.
			for (card_num = 0; card_num < MAX_CARDS; card_num++)
			{
				if (player_cards[id][card_num] == 0 && empty_slot == 0)
				{
					empty_slot = card_num;
				}
			}
			player_cards[id][empty_slot] = random_num(1,13)
			ShowGameMenu(id, false)
		}
		case 1:
		{
			// They're standing.
			ShowGameMenu(id, true)
		}
		case 8:
		{
			//They want to play again! :D
			StartBlackJack(id)
		}
	}
	return PLUGIN_HANDLED
}
// -----------------
// End BlackJack
// -----------------

// This will check to see if there in the bar
// NOTE: FIX THIS
stock user_in_bar(id)
{
	new myorigin[3]
	get_user_origin(id,myorigin)
	if(get_distance(myorigin,BarOrigin) < 300)
		return 1
	else 
		return 0
}
*/
