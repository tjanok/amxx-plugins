/* keytable data type
*
* by Twilight Suzuka
* 
*
* This file is provided as is (no warranties).
*/
// keytables used to be tries, and are now wrappers around the new format.
//	Are mostly backwards compatible (besides a few esoteric features

#if defined _arrayx_keytable_included
    #endinput
#endif
#define _arrayx_keytable_included

#include <cellkeytable>

////* keytable 

//* &success
// create a variable and pass it into success. This variable will be 0 if the function failed, 1 if it did not

//* disable_check
// If this variable is 1, then when a few errors occur, the plugin will not render an error, it will handle it safely.

///* Master Edit Functions

// Creates a new keytable
stock keytable_create() { return _:KeytableCreate(); }

// Destroys a created keytable, and sets the pointer back to NULL. You MUST destroy all keytable's you create.
stock keytable_destroy(keytable_id) { return KeytableDestroy(Keytable:keytable_id); }

// Clears a keytable without deleting it
stock keytable_clear(keytable_id) { return KeytableClear(Keytable:keytable_id); }

// Saves/loads keytables from file. keytable_id must be to an already created keytable.
stock keytable_save(keytable_id,file[]) {}
stock keytable_load(keytable_id,file[]) {}

///* Slave Amount Functions

// Returns how many indexes are in the keytable
stock keytable_size(keytable_id) { return KeytableSize(Keytable:keytable_id); }

// Returns the nth index in the keytable. 
// NOTE: After success, use get format ( [ret_val,len] ) to retrieve index. See keytable_const for details.
stock keytable_get_nth(keytable_id, nth, start[] = "",&success = 0)
{
	new ret;
	success = KeytableNth(Keytable:keytable_id, nth, start, ret);
	return ret;
}

///* Slave Edit Functions

// Returns the amount of memory this keytable has used
stock keytable_memory(keytable_id) { return keytable_size() * 4; }

// Returns if index is used or not.
stock keytable_isfilled(keytable_id, index[]) { return KeytableExists(Keytable:keytable_id, index); }
stock keytable_isempty(keytable_id, index[]) { return !KeytableExists(Keytable:keytable_id, index); }

///* Slave Set/Get/Delete Functions
// These don't need explaining.

// Gets the type of value stored in index. Uses pawn_type_* enum, see keytable_const for details.
stock keytable_get_type(Keytable:keytable_id, index[], disable_check = 0) { new ret; KeytableGetType(Keytable:keytable_id, index, ret); return ret; }

// Deletes an index from keytable
stock keytable_delete(keytable_id, index[]) { return KeytableDelete(Keytable:keytable_id, index);} 

stock keytable_set_bool(keytable_id, index[], bool:set_bool) { return KeytableSetBool(Keytable:keytable_id,index,set_bool); }
stock bool:keytable_get_bool(keytable_id, index[], disable_check = 0) { new get_bool; KeytableGetBool(Keytable:keytable_id,index,get_bool); return get_bool; }

stock keytable_set_int(keytable_id, index[], set_int) { return KeytableSetInt(Keytable:keytable_id,index,set_int); }
stock keytable_get_int(keytable_id, index[], disable_check = 0) { new get_int; KeytableGetInt(Keytable:keytable_id,index,get_int); return get_int; }

stock keytable_set_float(keytable_id, index[], Float:set_float) { return KeytableSetFloat(Keytable:keytable_id,index,set_float); }
stock Float:keytable_get_float(keytable_id, index[], disable_check = 0) { new get_Float; KeytableGetFloat(Keytable:keytable_id,index,get_Float); return get_Float; }

stock keytable_set_string(keytable_id, index[], str[]) { return KeytableSetString(Keytable:keytable_id,index,str); }
stock keytable_get_string(keytable_id, index[], val[], len, disable_check = 0) { return KeytableGetBool(Keytable:keytable_id,index,val,len); }

stock keytable_set_vector(keytable_id, index[], Float:str[3]) { return KeytableSetVector(Keytable:keytable_id,index,str); }
stock keytable_get_vector(keytable_id, index[], Float:val[3], disable_check = 0) { return KeytableGetVector(Keytable:keytable_id,index,val); }

stock keytable_set_array(keytable_id, index[], str[], len) { return KeytableSetkeytable(Keytable:keytable_id,index,str,len); }
stock keytable_get_array(keytable_id, index[], val[], len, disable_check = 0) { return KeytableGetkeytable(Keytable:keytable_id,index,val,len); }

///* Slave Search Functions

//* Filled Index Search Functions

// Finds the first filled index starting at provkeytable_ided index, returns value is found key.
stock keytable_first(keytable_id, index[], ret[], len, &success = 0) { return KeytableFirst (Keytable:keytable_id, index, ret, len); }

// Finds the filled index after provkeytable_ided index, return value is found key.
stock keytable_next(keytable_id, index[], ret[], len, &success = 0) { return KeytableNext (Keytable:keytable_id, index, ret, len); }

// Finds the filled index before provkeytable_ided index, return value is found key.
stock keytable_prev(keytable_id, index[], ret[], len, &success = 0) { return KeytablePrev (Keytable:keytable_id, index, ret, len); }

// Finds the last filled index starting at provkeytable_ided index, return value is found key.
stock keytable_last(keytable_id, index[], ret[], len, &success = 0) { return KeytableLast (Keytable:keytable_id, index, ret, len); }