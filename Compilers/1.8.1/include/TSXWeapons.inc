// Copied from the TSX Module and Avalanche's TS Weapon Functions
// ******************************************************************

#if defined _TSWeapons_Include
#endinput
#endif
#define _TSWeapons_Include

#include <amxmodx>
#include <fakemeta>

#define TS_MAX_WEAPONS 39

#define TSA_SILENCER			1
#define TSA_LASERSIGHT			2
#define TSA_FLASHLIGHT			4
#define TSA_SCOPE				8
#define TSA_LAYONWALL			16

// The maximum amount of ammo each weapon can have
// as of TS 3.0
stock const g_WeaponAmmo[TS_MAX_WEAPONS] =
{
	0,//"",
	210,//"glock18",
	185,//"berettas",
	210,//"uzi",
	60,//"m3",
	120,//"m4a1",
	210,//"mp5sd",
	210,//"mp5k",
	185,//"aberettas",
	175,//"mk23",
	175,//"amk23", // akimbo mk23's - id: 10 - spawning this only spawns 1 mk23
	60,//"usas",
	70,//"deagle",
	90,//"ak47",
	160,//"57",
	120,//"aug",
	210,//"auzi", // akimbo uzi - id: 16 - spawning this only spawns 1 uzi
	300,//"skorpion",
	30,//"m82a1",
	160,//"mp7",
	60,//"spas",
	175,//"gcolts",
	90,//"glock20",
	175,//"ump",
	0,//"m61grenade", // grenade - can hold a max of 2 with no weapons
	1,//"cknife", // combat knife - can hold a max of 1 with no weapons
	60,//"mossberg",
	120,//"m16a4",
	150,//"mk1",
	0,//"c4",
	160,//"a57", // akimbo 57 - id: 30 - spawning this only spawns 1 57
	50,//"rbull",
	120,//"m60e3",
	60,//"sawed_off",
	0,//"katana",
	10,//"sknife", // seal knife - can hold a max of 10 knifes
	35,//"contender",
	300//"akimbo skorpions"
};

// Updated with TS 3.0
enum 
{
  TSW_GLOCK18 = 1,
  TSW_BERETTA,
  TSW_UZI,
  TSW_M3,
  TSW_M4A1,
  TSW_MP5SD,
  TSW_MP5K,
  TSW_ABERETTAS,
  TSW_MK23,
  TSW_AMK23,
  TSW_USAS,
  TSW_DEAGLE,
  TSW_AK47,
  TSW_57,
  TSW_AUG,
  TSW_AUZI,
  TSW_SKORP,
  TSW_M82A1,
  TSW_MP7,
  TSW_SPAS,
  TSW_GCOLTS,
  TSW_GLOCK20,
  TSW_UMP,
  TSW_M61GRENADE,
  TSW_CKNIFE,
  TSW_MOSSBERG,
  TSW_M16A4,
  TSW_MK1,
  TSW_C4,
  TSW_A57,
  TSW_RBULL,
  TSW_M60E3,
  TSW_SAWED_OFF,
  TSW_KATANA,
  TSW_SKNIFE,
  TSW_CONTENDER,
  TSW_ASKORP
};

// --------------------------------------------------
// ts_get_user_tsgun
//
// gets the entity index of the player's weapon_tsgun.
//
//     id:	player id
//
// returns tsgun index on success, 0 on failure.
// --------------------------------------------------
stock ts_get_user_tsgun(id)
{
	// invalid player
	if(!is_user_alive(id))
		return 0;
	
	// get our tsgun
	new tsgun;
	while((tsgun = engfunc(EngFunc_FindEntityByString,tsgun,"classname","weapon_tsgun")) != 0)
	{
		// we own this one
		if(pev(tsgun,pev_owner) == id)
			return tsgun;
	}
	
	return 0;
}

/*
// --------------------------------------------------
// ts_getwpn_maxammo
// returns the maximum amount of ammo the given WeaponID can hold
// --------------------------------------------------
stock ts_getwpn_maxammo(const WeaponID)
{
	if(WeaponID < 0 || WeaponID > TS_MAX_WEAPONS)
		return 0;
	
	return g_WeaponAmmo[WeaponID]
}
*/