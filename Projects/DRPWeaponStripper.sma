#include <amxmodx>
#include <TSXWeapons>
#include <fakemeta>
#include <engine>
#include <cellarray>
#include <hamsandwich>

#define TS_MAX_WEAPONS 39
new const g_TouchName[] = "DRP_WeaponStripper"

new Array:g_UserWeapons[33]
new Float:g_LastTouch[33]
new Offsets[38]

new g_Menu

public plugin_init()
{
	new Ent,Found
	while(( Ent = find_ent_by_tname(Ent,g_TouchName)) != 0)
		Found = 1
	
	if(!Found)
	{
		server_print("[DRP] Unable to find any DRP Weapon Strippers within the map.");
		pause("d");
	}
	
	// Main
	register_plugin("DRP - Weapon Stripper","0.1a","Drak");
	
	// Events / Forwards
	register_touch("trigger_multiple","player","Event_TouchedTrigger");
	register_forward(FM_CreateNamedEntity,"_Test");
	
	RegisterHam(Ham_Activate,"trigger_multiple","_Test");
	
	// Misc
	MakeOffsets();
	
	g_Menu = menu_create("Return Weapons?","_Handle");
	menu_additem(g_Menu,"Yes");
	menu_additem(g_Menu,"No");
}

public _Test()
	server_print("D");

public _Handle()
{
}

public client_disconnect(id)
{
	if(g_UserWeapons[id])
	{
		ArrayDestroy(g_UserWeapons[id]);
		g_UserWeapons[id] = Invalid_Array
	}
	g_LastTouch[id] = 0.0
}

public Event_TouchedTrigger(const pTouched,const pToucher)
{
	if(!pToucher || !pTouched)
		return
	
	static TName[26],Float:Time
	entity_get_string(pTouched,EV_SZ_targetname,TName,23);
	
	if(!equali(TName,g_TouchName))
		return
	
	new const id = pToucher
	if(!is_user_alive(id))
		return
	
	Time = get_gametime();
	
	if(Time - g_LastTouch[id] < 1.0)
		return
	
	g_LastTouch[id] = Time
	
	static Float:pOrigin[3],Float:tOrigin[3]
	entity_get_vector(id,EV_VEC_origin,pOrigin);
	get_brush_entity_origin(pTouched,tOrigin);
	
	if(g_UserWeapons[id])
	{
		menu_display(id,g_Menu);
		client_print(0,print_chat,"sent menu");
		return
	}

	new Weapons[38],iNum
	ts_get_user_weapons(pToucher,Weapons,iNum);
	
	if(!iNum)
		return
	
	g_UserWeapons[id] = ArrayCreate(_,39);
	
	// Push are weapon ID's
	// TODO: Get Ammo / Clip (i'm guessing using pdata)
	for(new Count;Count < iNum;Count++)
		ArrayPushCell(g_UserWeapons[id],Weapons[Count]);
	
	client_print(id,print_chat,"[DRP] Your weapons have been stripped, when you exit. They will be returned.");
}

ts_get_user_weapons(const id,Weapons[38],&iNum)
{
	new const TSWeapon = ts_get_user_tsgun(id);
	
	if(!TSWeapon)
		return 0
	
	for(new Count;Count < sizeof(Offsets);Count++)
	{
		if(Offsets[Count] <= 0)
			continue
		
		if(get_pdata_int(TSWeapon,Offsets[Count]) > 0)
			Weapons[iNum++] = Count
	}
	return 1
}

MakeOffsets()
{
	Offsets[1] = 80; // glock 18
	Offsets[2] = -1; // no weapon
	Offsets[3] = 108; // uzi
	Offsets[4] = 122; // shotgun m3
	Offsets[5] = 136; // m4a1
	Offsets[6] = 150; // mp5sd
	Offsets[7] = 164; // mp5k
	Offsets[8] = 94; // bretta
	Offsets[9] = 192; // socom
	Offsets[10] = 206; // akimbo socom
	Offsets[11] = 220; // usas
	Offsets[12] = 234; // degal
	Offsets[13] = 248; // ak47
	Offsets[14] = 262; // 57
	Offsets[15] = 276; // aug
	Offsets[16] = 290; // akimbo uzi
	Offsets[17] = 304; // skorpeon
	Offsets[18] = 318; // barret
	Offsets[19] = 332; // mp7
	Offsets[20] = 346; // spas
	Offsets[21] = 360; // colts
	Offsets[22] = 374; // glock 20
	Offsets[23] = 388; // ump
	Offsets[24] = 624; // m61 grenade
	Offsets[25] = -1; // combat knife
	Offsets[26] = 430; // mossberg
	Offsets[27] = 444; // m16a1
	Offsets[28] = 458; // rugar
	Offsets[29] = -1; // C4
	Offsets[30] = 486; // akimbo 57's
	Offsets[31] = 500; // bull
	Offsets[32] = 514; // m60
	Offsets[33] = 528; // sawed off
	Offsets[34] = -1; // Katana
	Offsets[35] = -1; // Seal Knife
	Offsets[36] = -1; // contender // unknown
	Offsets[37] = 584;
}