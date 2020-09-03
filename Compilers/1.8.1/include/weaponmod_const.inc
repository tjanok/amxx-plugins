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

#if defined _weaponmod_const_included
  #endinput
#endif
#define _weaponmod_const_included

/* GameInfos */
enum wpn_gi_integer
{
	gi_pluginid,	/* Plugin id (automically detected) */
	gi_available,	/* Identifies if there's a GameInfo plugin available */
	gi_teamplay	/* Identifies if the current played mod is a teamplay game or not */
}

/* Weapon data strings */
enum wpn_string
{
	/* Weapon information */
	wpn_name,
	wpn_short,
	wpn_file,	/* Automically detected */
	
	/* Models used */
	wpn_viewmodel,
	wpn_weaponmodel,
	wpn_worldmodel
}

/* Weapon data integers */
enum wpn_integer
{
	/* Cost of the weapon */
	wpn_cost,	
	
	/* Primary and secondary ammo */
	wpn_ammo1,
	wpn_ammo2,
	
	/* Bullets used by clicking attack 1/2 */
	wpn_bullets_per_shot1,
	wpn_bullets_per_shot2,
	
	/* Should bullets be counted by 3rd party mods (e.g. Stats) (default = 1)  */
	wpn_count_bullets1,
	wpn_count_bullets2,
	
	/* Identicates the plugin which registered the weapon (automically detected) */
	wpn_pluginid
}

/* Weapon data floats */
enum wpn_float
{
	/* Refire rate of attack 1/2 */
	Float:wpn_refire_rate1,
	Float:wpn_refire_rate2,
	
	/* Time of reloading */
	Float:wpn_reload_time,
	
	/* Maximum run speed if this weapon is hold */
	Float:wpn_run_speed,
	
	/* Recoil of attack 1/2 */
	Float:wpn_recoil1,
	Float:wpn_recoil2
}

/* Weapon events */
enum wpn_event
{
	event_attack1,		/* player, bullets used - returning PLUGIN_HANDLED will block WeaponMod actions */
	event_attack2,		/* player, bullets used - returning PLUGIN_HANDLED will block WeaponMod actions */
	event_reload,		/* player */
	event_pickup,		/* player */
	event_draw,		/* player */
	event_hide,		/* player */
	event_worldspawn,	/* entity */
	event_weapondrop	/* dropper, entity */
}

/* Player weapon information */
enum wpn_usr_info
{
	/* Real Weapon ID */
	usr_wpn_index,
	
	/* Primary and Secondary ammo */
	usr_wpn_ammo1,
	usr_wpn_ammo2
}

/* Entity Weapon Information */
enum wpn_ent_info
{
	/* Real Weapon ID */
	ent_wpn_index,
	
	/* Primary and Secondary ammo */
	ent_wpn_ammo1,
	ent_wpn_ammo2
}

/* Offsets */
enum wpn_offset
{
	offset_money,
	offset_deaths
}
