#if defined _DRP_CONST_INCLUDE
	#endinput
#endif

#define _DRP_CONST_INCLUDE

// Max items in the HUD display
#define MAX_HUD_ITEMS 30

// The maximum amount of jobs a user can have.
#define MAX_JOBS 100

#define MAX_MOTD_MESSAGELEN 1535

// Max accesses for jobs (1 per each letter of the alphabet)
#define JOB_ACCESSES 26

// TSFade / Screenfade
#define FFADE_IN			0x0000		// Just here so we don't pass 0 into the function
#define FFADE_OUT			0x0001		// Fade out (not in)
#define FFADE_MODULATE		0x0002		// Modulate (don't blend)
#define FFADE_STAYOUT		0x0004		// ignores the duration, stays faded out until new ScreenFade message received
#define FADE_IN_OUT 		1<<12

#define seconds_to_screenfade_units(%1) ( ( 1 << 12 ) * ( %1 ) )

stock const g_JobLiterals[JOB_ACCESSES][] = {"a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z"}
stock const g_Keys = MENU_KEY_0|MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6|MENU_KEY_7|MENU_KEY_8|MENU_KEY_9

// Access System
#define ACCESS_A (1<<0)
#define ACCESS_B (1<<1)
#define ACCESS_C (1<<2)
#define ACCESS_D (1<<3)
#define ACCESS_E (1<<4)
#define ACCESS_F (1<<5)
#define ACCESS_G (1<<6)
#define ACCESS_H (1<<7)
#define ACCESS_I (1<<8)
#define ACCESS_J (1<<9)
#define ACCESS_K (1<<10)
#define ACCESS_L (1<<11)
#define ACCESS_M (1<<12)
#define ACCESS_N (1<<13)
#define ACCESS_O (1<<14)
#define ACCESS_P (1<<15)
#define ACCESS_Q (1<<16)
#define ACCESS_R (1<<17)
#define ACCESS_S (1<<18)
#define	ACCESS_T (1<<19)
#define ACCESS_U (1<<20)
#define ACCESS_V (1<<21)
#define ACCESS_W (1<<22)
#define ACCESS_X (1<<23)
#define ACCESS_Y (1<<24)
#define ACCESS_Z (1<<25) // NOTE: ADMIN ONLY - ACCESS_ADMIN  ( NEVER CHANGE THIS FLAG )

// Return types
enum
{
	FAILED = 0,
	SUCCEEDED
}
enum _:HUD_NUM
{
	HUD_PRIM,
	HUD_SEC,
	HUD_TALKAREA
}
enum PLY
{
	PLY_GOT_INFO = 0,
	PLY_SAVING,
	PLY_JOINED,
	PLY_BADJOB
}

stock const g_MedicsAccessCvar[] = "DRP_Medical_Access"
stock const g_AdminAccessCvar[] = "DRP_Admin_Access"
stock const g_CopAccessCvar[] = "DRP_Police_Access"
stock const g_VIPAccessCvar[] = "DRP_VIP_Access"
stock const g_OtherAccessCvar[] = "DRP_Other_Access" // jobs like this, are reporters / lawyers that serve a purpose for role-play situations

// Model(s) / Precaches
// NOTE: These models are precached in 'DRPCore.amxx'
stock const g_MoneyMdl[] = "models/OZDRP/drpmoney.mdl"
stock const g_ItemMdl[] = "models/OZDRP/w_backpack.mdl"

// Entity Classnames
stock const g_szMoneyPile[] = "DRP_Money"
stock const g_szItem[] = "DRP_Item"

stock const g_szNPCName[] = "DRP_NPC"
stock const g_szDRPZone[] = "DRP_ZONE"

// Anytime we need a sprite for fire
// ALWAYS use this one (other plugins pick up on it)
stock const g_FireSprite[] = "sprites/mecklenburg/drak_mfire.spr"