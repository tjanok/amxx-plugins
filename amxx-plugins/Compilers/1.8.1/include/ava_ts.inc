/* Avalanche's TS Weapon Functions BETA V v3
*  xxavalanchexx at hotmail dot com
*  http://forums.alliedmods.net/showthread.php?t=46939
*
*  REQUIRES TSX/TSFUN AND FAKEMETA
*
*  This include file must remain as-is. You
*  are forbidden to merge the functions into
*  your own script or include file (ala Harbu).
*
*/

 #if defined _ava_ts_included
	#endinput
 #endif
 #define _ava_ts_included

 #define TSROF_FULLAUTO	0
 #define TSROF_SEMIAUTO	1
 #define TSROF_BURST	2
 #define TSROF_PUMP	3
 #define TSROF_FREESEMI	4
 #define TSROF_FREEFULL	5

 #include <amxmodx>
 #include <tsfun>
 #include <tsx>
 #include <fakemeta>

 new __def, __gmsgWeaponInfo, __gmsgActItems, __tsClipOffset[36], __tsAmmoOffset[36], __tsROFbase[36], __tsROFmods[6];

 //
 // ts_get_user_tsgun
 //
 // gets the entity index of the player's weapon_tsgun.
 //
 //     id:	player id
 //
 // returns tsgun index on success, 0 on failure.
 //
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

 //
 // ts_set_weapon_clip
 //
 // sets the amount of ammo in clip for a player's weapon. this doesn't
 // require the weapon to be out. see bottom of file for an explanation
 // of the akimbo flag.
 //
 //       id:	player id
 //   weapon:	weapon id (TSW_*)
 //     clip:	new clip amount
 //   akimbo:	0 for unspecific, 1 for right, 2 for left
 // emessage:	whether or not to use emessages for HUD update
 //
 // returns 1 on success, 0 on failure
 //
 stock ts_set_weapon_clip(id,weapon,clip,akimbo=0,emessage=1)
 {
	if(!__def) __load_def();

	// invalid player
	if(!is_user_alive(id))
		return 0;

	// invalid weapon
	if(weapon < 1 || weapon > 35 || weapon == TSW_KATANA)
		return 0;

	new offset = __tsClipOffset[weapon];

	// invalid weapon
	if(offset == -1)
		return 0;

	// get our tsgun
	new tsgun = ts_get_user_tsgun(id);

	// we did not find it
	if(!pev_valid(tsgun))
		return 0;

	// get some of their current settings
	new currweapon, currclip, currammo, currmode, currextra;
	currweapon = ts_getuserwpn(id,currclip,currammo,currmode,currextra);

	// if this is our current, set the special clip holders
	if(currweapon == weapon)
	{
		set_pdata_int(tsgun,41,clip,4);
		set_pdata_int(tsgun,839,clip,4);

		// hand-specific amounts are never shown
		if(!akimbo)
		{
			// update HUD
			if(emessage)
			{
				emessage_begin(MSG_ONE,__gmsgWeaponInfo,{0,0,0},id);
				ewrite_byte(weapon);
				ewrite_byte(clip);
				ewrite_short(currammo);
				ewrite_byte(currmode);
				ewrite_byte(currextra);
				emessage_end();
			}
			else
			{
				message_begin(MSG_ONE,__gmsgWeaponInfo,{0,0,0},id);
				write_byte(weapon);
				write_byte(clip);
				write_short(currammo);
				write_byte(currmode);
				write_byte(currextra);
				message_end();
			}
		}
	}

	//
	// set the clip ammo
	//

	// setting right akimbo (+6 from clip offset)
	if(akimbo == 1) set_pdata_int(tsgun,offset+6,clip,4);

	// setting left akimbo (+7 from clip offset)
	else if(akimbo == 2) set_pdata_int(tsgun,offset+7,clip,4);

	// not setting specific akimbo
	else set_pdata_int(tsgun,offset,clip,4);

	return 1;
 }

 //
 // ts_set_weapon_ammo
 //
 // sets the amount of backpack (not in clip) ammo for a player's weapon.
 // this is a clean up of my old ts_setuserammo. its functionality is
 // the same, except that it doesn't require you to switch to the
 // weapon that you are setting ammo for.
 //
 //       id:	player id
 //   weapon:	weapon id (TSW_*)
 //     ammo:	new backpack ammo amount
 // emessage:	whether or not to use emessages for HUD update
 //
 // returns 1 on success, 0 on failure
 //
 stock ts_set_weapon_ammo(id,weapon,ammo,emessage=1)
 {
	if(!__def) __load_def();

	// invalid player
	if(!is_user_alive(id))
		return 0;

	// invalid weapon
	if(weapon < 1 || weapon > 35 || weapon == TSW_KATANA)
		return 0;

	new offset = __tsAmmoOffset[weapon];

	// invalid weapon
	if(offset == -1)
		return 0;

	// get our tsgun
	new tsgun = ts_get_user_tsgun(id);

	// we did not find it
	if(!pev_valid(tsgun))
		return 0;

	// get some of their current settings
	new currweapon, currclip, currammo, currmode, currextra;
	currweapon = ts_getuserwpn(id,currclip,currammo,currmode,currextra);

	// if this is our current weapon
	if(currweapon == weapon)
	{
		// grenade or knife, set the special clip holders
		if(weapon == TSW_M61GRENADE || weapon == TSW_CKNIFE || weapon == TSW_SKNIFE)
		{
			set_pdata_int(tsgun,41,ammo,4); // special clip storage
			set_pdata_int(tsgun,839,ammo,4); // more special clip storage

			currclip = ammo; // change what we send to WeaponInfo
			ammo = 0; // once again, change what we send to WeaponInfo
		}
		else
		{
			// not a grenade or knife, set the special ammo holder instead
			set_pdata_int(tsgun,850,ammo,4); // special ammo storage
		}

		// update HUD
		if(emessage)
		{
			emessage_begin(MSG_ONE,__gmsgWeaponInfo,{0,0,0},id);
			ewrite_byte(weapon);
			ewrite_byte(currclip);
			ewrite_short(ammo);
			ewrite_byte(currmode);
			ewrite_byte(currextra);
			emessage_end()
		}
		else
		{
			message_begin(MSG_ONE,__gmsgWeaponInfo,{0,0,0},id);
			write_byte(weapon);
			write_byte(currclip);
			write_short(ammo);
			write_byte(currmode);
			write_byte(currextra);
			message_end()
		}
	}

	// set their weapon-specific ammo
	set_pdata_int(tsgun,offset,ammo,4);

	return 1;
 }

 //
 // ts_set_weapon_rof
 //
 // sets the rate of fire for a player's weapon. rate of fire constants
 // are defined at the top of script. this can be used to make the barret
 // fire in bursts, the raging bull fire in full auto, etcetera.
 //
 //       id:	player id
 //   weapon:	weapon id (TSW_*)
 //      rof:	new rate of fire (TSROF_*)
 // emessage:	whether or not to use emessages for HUD update
 //
 // returns 1 on success, 0 on failure
 //
 stock ts_set_weapon_rof(id,weapon,rof,emessage=1)
 {
	if(!__def) __load_def();

	// invalid rof
	if(rof < 0 || rof > 5)
		return 0;

	// invalid player
	if(!is_user_alive(id))
		return 0;

	// invalid weapon
	if(weapon < 1 || weapon > 35)
		return 0;

	// invalid weapon
	if(__tsROFbase[weapon] == -1)
		return 0;

	// get our tsgun
	new tsgun = ts_get_user_tsgun(id);

	// we did not find it
	if(!pev_valid(tsgun))
		return 0;

	new offset = __tsClipOffset[weapon];

	// all rof values start with 1<<0 (1)
	new value = (1<<0) + __tsROFbase[weapon] + __tsROFmods[rof];

	// get some of their current settings
	new currweapon, currclip, currammo, currmode, currextra;
	currweapon = ts_getuserwpn(id,currclip,currammo,currmode,currextra);

	// if this is our current, set the special rof holder and update HUD
	if(currweapon == weapon)
	{
		set_pdata_int(tsgun,838,value,4);

		// update HUD
		if(emessage)
		{
			emessage_begin(MSG_ONE,__gmsgWeaponInfo,{0,0,0},id);
			ewrite_byte(weapon);
			ewrite_byte(currclip);
			ewrite_short(currammo);
			ewrite_byte(rof);
			ewrite_byte(currextra);
			emessage_end()
		}
		else
		{
			message_begin(MSG_ONE,__gmsgWeaponInfo,{0,0,0},id);
			write_byte(weapon);
			write_byte(currclip);
			write_short(currammo);
			write_byte(rof);
			write_byte(currextra);
			message_end();
		}
	}

	// set rof offset (-1 from clip offset)
	set_pdata_int(tsgun,offset-1,value,4);

	return 1;
 }

 //
 // ts_set_weapon_extras
 //
 // sets the extras of a player's weapon.
 //
 //       id:	player id
 //   weapon:	weapon id (TSW_*)
 //   extras:	new extras (TSA_*)
 //   active:	0 to change what extras the weapon has available,
 //		1 to change what extras the weapon has currently active
 // emessage:	whether or not to use emessages for HUD update
 //
 // returns 1 on success, 0 on failure
 //
 stock ts_set_weapon_extras(id,weapon,extras,active=0,emessage=1)
 {
	if(!__def) __load_def();

	// invalid player
	if(!is_user_alive(id))
		return 0;

	// invalid weapon
	if(weapon < 1 || weapon > 35)
		return 0;

	new offset = __tsClipOffset[weapon];

	// invalid weapon
	if(offset == -1)
		return 0;

	// get our tsgun
	new tsgun = ts_get_user_tsgun(id);

	// we did not find it
	if(!pev_valid(tsgun))
		return 0;

	// get some of their current settings
	new currweapon, currclip, currammo, currmode, currextra;
	currweapon = ts_getuserwpn(id,currclip,currammo,currmode,currextra);

	// if this is our current, set the special extras holders and update HUD
	if(currweapon == weapon)
	{
		// these are wishy-washy
		set_pdata_int(tsgun,842,extras,4);
		set_pdata_int(tsgun,843,extras,4);
		set_pdata_int(tsgun,844,extras,4);

		// send our avaiable extras
		if(emessage)
		{
			emessage_begin(MSG_ONE,__gmsgWeaponInfo,{0,0,0},id);
			ewrite_byte(weapon);
			ewrite_byte(currclip);
			ewrite_short(currammo);
			ewrite_byte(currmode);
			ewrite_byte(extras);
			emessage_end();
		}
		else
		{
			message_begin(MSG_ONE,__gmsgWeaponInfo,{0,0,0},id);
			write_byte(weapon);
			write_byte(currclip);
			write_short(currammo);
			write_byte(currmode);
			write_byte(extras);
			message_end();
		}

		if(active)
		{
			// send our currently active extras
			if(emessage)
			{
				emessage_begin(MSG_ONE,__gmsgActItems,{0,0,0},id);
				ewrite_byte(1);
				ewrite_byte(extras);
				emessage_end();
			}
			else
			{
				message_begin(MSG_ONE,__gmsgActItems,{0,0,0},id);
				write_byte(1);
				write_byte(extras);
				message_end();
			}
		}
	}

	if(active)
	{
		// set the currently active extras (+4 from clip offset)
		set_pdata_int(tsgun,offset+4,extras,4);
	}
	else
	{
		// set the available extras (+3 from clip offset)
		set_pdata_int(tsgun,offset+3,extras,4);
	}

	return 1;
 }

 //
 // ts_get_weapon_info
 //
 // like ts_getuserwpn, except that you can specify a weapon
 // to get information about, so as to grab info of weapons
 // not currently drawn. also you can get the extras currently
 // active in addition to the available extras. if any field is
 // unavailable, it will be -1. also note that silencer and
 // scope are never considered "currently active."
 //
 //      id:	player id
 //  weapon:	weapon id to get information about
 //    clip:	variable to store clip ammo in
 //    ammo:	variable to store backpack ammo in
 //    mode:	variable to store firemode in
 //   extra:	variable to store available extras in
 //  extra2:	variable to store currently active extras in
 //
 // returns 1 success, 0 on failure
 //
 stock ts_get_weapon_info(id,weapon,&clip,&ammo,&mode,&extra,&extra2)
 {
	if(!__def) __load_def();

	// invalid player
	if(!is_user_alive(id))
		return 0;

	// invalid weapon
	if(weapon < 1 || weapon > 35)
		return 0;

	// get our tsgun
	new tsgun = ts_get_user_tsgun(id);

	// we did not find it
	if(!pev_valid(tsgun))
		return 0;

	// invalid weapon
	if(__tsClipOffset[weapon] == -1)
	{
		clip	= -1;
		mode	= -1;
		extra	= -1;
		extra2	= -1;
	}
	else
	{
		clip = get_pdata_int(tsgun,__tsClipOffset[weapon],4);

		// no ROF
		if(__tsROFbase[weapon] == -1) mode = -1;
		else mode = get_pdata_int(tsgun,__tsClipOffset[weapon]-1,4);

		// no extras available (clip offset == ammo offset, aka no
		// extra ammo, meaning nades, knives, katanas, etcetera)
		if(__tsAmmoOffset[weapon] == __tsClipOffset[weapon])
		{
			extra	= -1;
			extra2	= -1;
		}
		else
		{
			extra	= get_pdata_int(tsgun,__tsClipOffset[weapon]+3,4);
			extra2	= get_pdata_int(tsgun,__tsClipOffset[weapon]+4,4);
		}
	}

	// weapon has only clip, no ammo, or weapon is invalid
	if(__tsClipOffset[weapon] == __tsAmmoOffset[weapon] || __tsAmmoOffset[weapon] == -1) ammo = -1;
	else ammo = get_pdata_int(tsgun,__tsAmmoOffset[weapon],4);

	if(mode != -1)
	{
		// convert crazy bitsum ROF to our defines
		new i;
		for(i=0;i<=5;i++)
		{
			if(mode == __tsROFbase[weapon] + __tsROFmods[i] + (1<<0))
			{
				mode = i;
				break;
			}
		}
	}

	// could not convert
	if(mode > 5) mode = -1;

	return 1;
 }

 //
 // ts_get_user_weapons
 //
 // the TS equivalent to AMXx's base get_user_weapons. note that
 // the array size must be 35, not 32 as in regular get_user_weapons.
 //
 //      id:	player id
 // weapons:	array to store weapon ids in, must be 35 cells
 //     num:	variable to store number of weapons found
 //
 // returns 1 success, 0 on failure
 //
 stock ts_get_user_weapons(id,weapons[35],&num)
 {
	if(!__def) __load_def();

	// invalid player
	if(!is_user_alive(id))
		return 0;

	// get our tsgun
	new tsgun = ts_get_user_tsgun(id);

	// we did not find it
	if(!pev_valid(tsgun))
		return 0;

	new i;
	num = 0;

	for(i=1;i<=35;i++)
	{
		// invalid weapon
		if(__tsClipOffset[i] == -1)
			continue;

		// check ROF offset, because clip, ammo, and extras can
		// all be 0 when you have a weapon. however, since the
		// base for all ROF values is 1<<0 (1), as long as you
		// have that weapon it will be at least 1.

		// but first, does this weapon use ROF?
		if(__tsROFbase[i] != -1)
		{
			// ROF offset is clip offset -1
			if(get_pdata_int(tsgun,__tsClipOffset[i]-1,4) > 0)
				weapons[num++] = i;
		}

		// otherwise, compare clip ammo, because anything that
		// doesn't use ROF has to have at least 1 in clip to hold
		// (yes, I know this contradicts my first statement above)
		else
		{
			if(get_pdata_int(tsgun,__tsClipOffset[i],4) > 0)
				weapons[num++] = i;
		}
	}

	return 1;
 }

 //
 // ts_set_weapon_ready
 //
 // sets whether a weapon is "ready" or not. the only use that I have
 // found for this is for pump-action shotguns: setting them to ready
 // means that you have already pumped the next shot, whereas setting
 // them to not ready means that you still have to click once to eject
 // the shell.
 //
 //     id:	player id
 // weapon:	weapon id (TSW_*)
 //  ready:	1 if ready, 0 if not
 //
 // returns 1 on success, 0 on failure
 //
 stock ts_set_weapon_ready(id,weapon,ready=1)
 {
	if(!__def) __load_def();

	// invalid player
	if(!is_user_alive(id))
		return 0;

	// invalid weapon
	if(weapon < 1 || weapon > 35)
		return 0;

	new offset = __tsClipOffset[weapon];

	// invalid weapon
	if(offset == -1)
		return 0;

	// get our tsgun
	new tsgun = ts_get_user_tsgun(id);

	// we did not find it
	if(!pev_valid(tsgun))
		return 0;

	// set ready (+8 from clip offset)
	set_pdata_int(tsgun,offset+8,!ready,4);

	// note that this field is 1 if not ready, 0 if ready,
	// so we invert the value given to us to make it logical

	return 1;
 }

 //
 // loads up the pdata offset array and grabs
 // the WeaponInfo message id for the first time
 //
 stock __load_def()
 {
	// don't load again
	__def = 1;

	// TS CLIP OFFSETS
	__tsClipOffset[TSW_GLOCK18] = 78;
	__tsClipOffset[TSW_UNK1] = -1;
	__tsClipOffset[TSW_UZI] = 102;
	__tsClipOffset[TSW_M3] = 114;
	__tsClipOffset[TSW_M4A1] = 126;
	__tsClipOffset[TSW_MP5SD] = 138;
	__tsClipOffset[TSW_MP5K] = 150;
	__tsClipOffset[TSW_ABERETTAS] = 162;
	__tsClipOffset[TSW_MK23] = 174;
	__tsClipOffset[TSW_AMK23] = 186;
	__tsClipOffset[TSW_USAS] = 198;
	__tsClipOffset[TSW_DEAGLE] = 210;
	__tsClipOffset[TSW_AK47] = 222;
	__tsClipOffset[TSW_57] = 234;
	__tsClipOffset[TSW_AUG] = 246;
	__tsClipOffset[TSW_AUZI] = 258;
	__tsClipOffset[TSW_TMP] = 270;
	__tsClipOffset[TSW_M82A1] = 282;
	__tsClipOffset[TSW_MP7] = 294;
	__tsClipOffset[TSW_SPAS] = 306;
	__tsClipOffset[TSW_GCOLTS] = 318;
	__tsClipOffset[TSW_GLOCK20] = 330;
	__tsClipOffset[TSW_UMP] = 342;
	__tsClipOffset[TSW_M61GRENADE] = 354;
	__tsClipOffset[TSW_CKNIFE] = 366;
	__tsClipOffset[TSW_MOSSBERG] = 378;
	__tsClipOffset[TSW_M16A4] = 390;
	__tsClipOffset[TSW_MK1] = 402;
	__tsClipOffset[TSW_C4] = -1;
	__tsClipOffset[TSW_A57] = 426;
	__tsClipOffset[TSW_RBULL] = 438;
	__tsClipOffset[TSW_M60E3] = 450;
	__tsClipOffset[TSW_SAWED_OFF] = 462;
	__tsClipOffset[TSW_KATANA] = 474;
	__tsClipOffset[TSW_SKNIFE] = 486;

	// TS AMMO OFFSETS
	__tsAmmoOffset[TSW_GLOCK18] = 50;
	__tsAmmoOffset[TSW_UNK1] = -1;
	__tsAmmoOffset[TSW_UZI] = 50;
	__tsAmmoOffset[TSW_M3] = 52;
	__tsAmmoOffset[TSW_M4A1] = 53;
	__tsAmmoOffset[TSW_MP5SD] = 50;
	__tsAmmoOffset[TSW_MP5K] = 50;
	__tsAmmoOffset[TSW_ABERETTAS] = 50;
	__tsAmmoOffset[TSW_MK23] = 51;
	__tsAmmoOffset[TSW_AMK23] = 51;
	__tsAmmoOffset[TSW_USAS] = 52;
	__tsAmmoOffset[TSW_DEAGLE] = 54;
	__tsAmmoOffset[TSW_AK47] = 53;
	__tsAmmoOffset[TSW_57] = 56;
	__tsAmmoOffset[TSW_AUG] = 53;
	__tsAmmoOffset[TSW_AUZI] = 50;
	__tsAmmoOffset[TSW_TMP] = 50;
	__tsAmmoOffset[TSW_M82A1] = 57;
	__tsAmmoOffset[TSW_MP7] = 56;
	__tsAmmoOffset[TSW_SPAS] = 52;
	__tsAmmoOffset[TSW_GCOLTS] = 51;
	__tsAmmoOffset[TSW_GLOCK20] = 58;
	__tsAmmoOffset[TSW_UMP] = 51;
	__tsAmmoOffset[TSW_M61GRENADE] = __tsClipOffset[TSW_M61GRENADE];
	__tsAmmoOffset[TSW_CKNIFE] = __tsClipOffset[TSW_CKNIFE];
	__tsAmmoOffset[TSW_MOSSBERG] = 52;
	__tsAmmoOffset[TSW_M16A4] = 53;
	__tsAmmoOffset[TSW_MK1] = 59;
	__tsAmmoOffset[TSW_C4] = -1;
	__tsAmmoOffset[TSW_A57] = 56;
	__tsAmmoOffset[TSW_RBULL] = 61;
	__tsAmmoOffset[TSW_M60E3] = 53;
	__tsAmmoOffset[TSW_SAWED_OFF] = 52;
	__tsAmmoOffset[TSW_KATANA] = __tsClipOffset[TSW_KATANA];
	__tsAmmoOffset[TSW_SKNIFE] = __tsClipOffset[TSW_SKNIFE];

	// TS ROF VALUE BASES
	__tsROFbase[TSW_GLOCK18] = (1<<8);
	__tsROFbase[TSW_UNK1] = -1;
	__tsROFbase[TSW_UZI] = (1<<8);
	__tsROFbase[TSW_M3] = (1<<9) + (1<<8);
	__tsROFbase[TSW_M4A1] = (1<<10);
	__tsROFbase[TSW_MP5SD] = (1<<8);
	__tsROFbase[TSW_MP5K] = (1<<8);
	__tsROFbase[TSW_ABERETTAS] = (1<<8);
	__tsROFbase[TSW_MK23] = (1<<9);
	__tsROFbase[TSW_AMK23] = (1<<9);
	__tsROFbase[TSW_USAS] = (1<<9) + (1<<8);
	__tsROFbase[TSW_DEAGLE] = (1<<10) + (1<<8);
	__tsROFbase[TSW_AK47] = (1<<10) + (1<<9);
	__tsROFbase[TSW_57] = (1<<10) + (1<<9) + (1<<8);
	__tsROFbase[TSW_AUG] = (1<<10);
	__tsROFbase[TSW_AUZI] = (1<<8);
	__tsROFbase[TSW_TMP] = (1<<8);
	__tsROFbase[TSW_M82A1] = (1<<1);
	__tsROFbase[TSW_MP7] = (1<<10) + (1<<9) + (1<<8);
	__tsROFbase[TSW_SPAS] = (1<<9) + (1<<8);
	__tsROFbase[TSW_GCOLTS] = (1<<9);
	__tsROFbase[TSW_GLOCK20] = (1<<11) + (1<<8);
	__tsROFbase[TSW_UMP] = (1<<9);
	__tsROFbase[TSW_M61GRENADE] = -1;
	__tsROFbase[TSW_CKNIFE] = -1;
	__tsROFbase[TSW_MOSSBERG] = (1<<9) + (1<<8);
	__tsROFbase[TSW_M16A4] = (1<<10);
	__tsROFbase[TSW_MK1] = (1<<11) + (1<<9);
	__tsROFbase[TSW_C4] = -1;
	__tsROFbase[TSW_A57] = (1<<10) + (1<<9) + (1<<8);
	__tsROFbase[TSW_RBULL] = (1<<11) + (1<<10);
	__tsROFbase[TSW_M60E3] = (1<<10);
	__tsROFbase[TSW_SAWED_OFF] = (1<<9) + (1<<8);
	__tsROFbase[TSW_KATANA] = -1;
	__tsROFbase[TSW_SKNIFE] = -1;

	// TS ROF MODS
	__tsROFmods[TSROF_FULLAUTO]	= 0;
	__tsROFmods[TSROF_SEMIAUTO]	= (1<<16);
	__tsROFmods[TSROF_BURST]	= (1<<17);
	__tsROFmods[TSROF_PUMP]		= __tsROFmods[TSROF_SEMIAUTO] + __tsROFmods[TSROF_BURST];
	__tsROFmods[TSROF_FREESEMI]	= (1<<18);
	__tsROFmods[TSROF_FREEFULL]	= __tsROFmods[TSROF_FREESEMI] + __tsROFmods[TSROF_SEMIAUTO]

	// events
	__gmsgWeaponInfo = get_user_msgid("WeaponInfo");
	__gmsgActItems = get_user_msgid("ActItems");
 }

 /* An explanation of the akimbo flag for ts_set_weapon_clip:

	If you are setting clip ammo for a non-akimbo weapon, leave akimbo as 0.
	If you are setting clip ammo for an akimbo weapon, use the akimbo weapon id
	(ie: TSW_AMK23 instead of TSW_MK23), and leave akimbo as 0.

	Now the catch: TS stores the total (0) amount of clip ammo for your akimbo weapon,
	but it also stores the amount of clip ammo for the right hand (1) weapon and the left
	hand (2) weapon. So, for proper functionality, you must call the function twice more,
	once with akimbo as 1 (right hand), and again with akimbo as 2 (left hand).

	Theoretically, the sum of the right (1) and left (2) hand weapon clip ammo should add up
	to the non-hand-specific (0) clip ammo. Example: total (0) is 61, right hand (1) is 30,
	and left hand (2) is 31.

	Also note that you don't HAVE to set the hand-specific clip ammo,
	but the right hand will stop firing after several shots if you don't.

	EXAMPLE SCRIPT:
	ts_set_weapon_clip(id,TSW_AMK23,200);
	ts_set_weapon_clip(id,TSW_AMK23,100,1);
	ts_set_weapon_clip(id,TSW_AMK23,100,2);
 */
