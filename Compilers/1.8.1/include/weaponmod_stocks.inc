/* Copyright (C) 2006-2008 Space Headed Productions
* 
* WeaponMod is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public License
* as published by the Free Software Foundation.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with WeaponMod; if not, write to the Free Software
* Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
*/

#if defined _weaponmod_stocks_included
  #endinput
#endif
#define _weaponmod_stocks_included

#if !defined _amxmodx_included
  #include <amxmodx>
#endif

#if !defined _weaponmod_included
	#include <weaponmod>
#endif


/* Gets weaponmod's config directory (automically creates if not existent)
* 
*   returns	0 when dir doesn't exist and creation failed
*/
stock get_weaponmoddir(name[], len)
{
	new configsdir[64];
	get_localinfo("amxx_configsdir", configsdir, 63);
	formatex(name, len, "%s/weaponmod", configsdir);
	
	if(!dir_exists(name))
	{
		if(mkdir(name) != 0)
		{
			return 0;
		}
	}
	
	// We successed
	return 1;
}

/* Gets weaponmod's log directory (automically creates if not existent)
* 
*   returns	0 when dir doesn't exist and creation failed
*/
stock get_weaponmod_logdir(name[], len)
{
	new weaponmoddir[64];
	get_weaponmoddir(weaponmoddir, 63);
	formatex(name, len, "%s/logs", weaponmoddir);
	
	if(!dir_exists(name))
	{
		if(mkdir(name) != 0)
		{
			return 0;
		}
	}
	
	return 1;
}

/* Gets the weapon id of the current hold weapon
* 
*   returns	Real weapon id (-1 if no WeaponMod weapon used)
*/
stock wpn_get_user_weapon_real(id)
{
	new usrwpn = wpn_get_user_weapon(id);
	if(usrwpn != -1)
	{
		return wpn_get_userinfo(id, usr_wpn_index, usrwpn);
	}
	
	return -1;
}

/* Removes weapon from a user by its real weapon id
*
*   returns	0 if user doesn't own the given weapon
*/
stock wpn_remove_weapon_real(id, wpnid)
{
	new usrwpn = wpn_has_weapon(id, wpnid);
	if(usrwpn != -1)
	{
		wpn_remove_weapon(id, usrwpn);
		return 1;
	}
	
	return 0;
}

/* Drops weapon from a user by its real weapon id
*
*   returns	0 if user doesn't own the given weapon
*/
stock wpn_drop_weapon_real(id, wpnid)
{
	new usrwpn = wpn_has_weapon(id, wpnid);
	if(usrwpn != -1)
	{
		wpn_drop_weapon(id, usrwpn);
		return 1;
	}
	
	return 0;
}
