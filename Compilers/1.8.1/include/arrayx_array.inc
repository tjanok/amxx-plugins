/* Array data type
*
* by Twilight Suzuka
* 
*
* This file is provided as is (no warranties).
*/
// Arrays used to be tries, and are now wrappers around the new format.
//	Are mostly backwards compatible (besides a few esoteric features

#if defined _array_array_included
    #endinput
#endif
#define _array_array_included

#include <cellsparsearray>

////* Array 

//* &success
// create a variable and pass it into success. This variable will be 0 if the function failed, 1 if it did not

//* disable_check
// If this variable is 1, then when a few errors occur, the plugin will not render an error, it will handle it safely.

///* Master Edit Functions

// Creates a new array
stock array_create() { return _:SparseArrayCreate(); }

// Destroys a created array, and sets the pointer back to NULL. You MUST destroy all array's you create.
stock array_destroy(array_id) { return SparseArrayDestroy(SparseArray:array_id); }

// Clears a array without deleting it
stock array_clear(array_id) { return SparseArrayClear(SparseArray:array_id); }

// Saves/loads arrays from file. array_id must be to an already created array.
stock array_save(array_id,file[]) {}
stock array_load(array_id,file[]) {}

///* Slave Amount Functions

// Returns how many indexes are in the array
stock array_size(array_id) { return SparseArraySize(SparseArray:array_id); }

// Returns the nth index in the array. 
// NOTE: After success, use get format ( [ret_val,len] ) to retrieve index. See array_const for details.
stock array_get_nth(array_id, nth, start = -1,&success = 0)
{
	new ret;
	success = SparseArrayNth(SparseArray:array_id, nth, start, ret);
	return ret;
}

///* Slave Edit Functions

// Returns the amount of memory this array has used
stock array_memory(array_id) { return array_size() * 4; }

// Returns if index is used or not.
stock array_isfilled(array_id, index) { return SparseArrayExists(SparseArray:array_id, index); }
stock array_isempty(array_id, index) { return !SparseArrayExists(SparseArray:array_id, index); }

///* Slave Set/Get/Delete Functions
// These don't need explaining.

// Gets the type of value stored in index. Uses pawn_type_* enum, see array_const for details.
stock array_get_type(array_idid, index, disable_check = 0) { new ret; SparseArrayGetType(SparseArray:array_id, index, ret); return ret; }

// Deletes an index from array
stock array_delete(array_id, index) { return SparseArrayDelete(SparseArray:array_id, index);} 

stock array_set_bool(array_id, index, bool:set_bool) { return SparseArraySetBool(SparseArray:array_id,index,set_bool); }
stock bool:array_get_bool(array_id, index, disable_check = 0) { new get_bool; SparseArrayGetBool(SparseArray:array_id,index,get_bool); return get_bool; }

stock array_set_int(array_id, index, set_int) { return SparseArraySetInt(SparseArray:array_id,index,set_int); }
stock array_get_int(array_id, index, disable_check = 0) { new get_int; SparseArrayGetInt(SparseArray:array_id,index,get_int); return get_int; }

stock array_set_float(array_id, index, Float:set_float) { return SparseArraySetFloat(SparseArray:array_id,index,set_float); }
stock Float:array_get_float(array_id, index, disable_check = 0) { new get_Float; SparseArrayGetFloat(SparseArray:array_id,index,get_Float); return get_Float; }

stock array_set_string(array_id, index, str[]) { return SparseArraySetString(SparseArray:array_id,index,str); }
//stock array_get_string(array_id, index, val[], len, disable_check = 0) { return SparseArrayGetBool(SparseArray:array_id,index,val,len); }
stock array_get_string(array_id, index, val[], len, disable_check = 0) { return SparseArrayGetString(SparseArray:array_id,index,val,len); }
stock array_set_vector(array_id, index, Float:str[3]) { return SparseArraySetVector(SparseArray:array_id,index,str); }
stock array_get_vector(array_id, index, Float:val[3], disable_check = 0) { return SparseArrayGetVector(SparseArray:array_id,index,val); }

stock array_set_array(array_id, index, str[], len) { return SparseArraySetArray(SparseArray:array_id,index,str,len); }
stock array_get_array(array_id, index, val[], len, disable_check = 0) { return SparseArrayGetArray(SparseArray:array_id,index,val,len); }

///* Slave Search Functions

//* Filled Index Search Functions

// Finds the first filled index starting at provarray_ided index, returns value is found key.
stock array_first(array_id, index, &success = 0) { new found; success = SparseArrayFirst (SparseArray:array_id, index, found); return found; }

// Finds the filled index after provarray_ided index, return value is found key.
stock array_next(array_id, index, &success = 0) { new found; success = SparseArrayNext (SparseArray:array_id, index, found); return found; }

// Finds the filled index before provarray_ided index, return value is found key.
stock array_prev(array_id, index, &success = 0) { new found; success = SparseArrayPrev (SparseArray:array_id, index, found); return found; }

// Finds the last filled index starting at provarray_ided index, return value is found key.
stock array_last(array_id, index, &success = 0) { new found; success = SparseArrayLast (SparseArray:array_id, index, found); return found; }

//* Empty Index Search Functions

// Returns the first empty index starting at provarray_ided index.
stock array_firstempty(array_id, index, &success = 0) { new found; success = SparseArrayFirstEmpty (SparseArray:array_id, index, found); return found; }

// Returns the first empty index after provarray_ided index.
stock array_nextempty(array_id, index, &success = 0) { new found; success = SparseArrayNextEmpty (SparseArray:array_id, index, found); return found; }

// Returns the first empty index before provarray_ided index.
stock array_prevempty(array_id, index, &success = 0) { new found; success = SparseArrayPrevEmpty (SparseArray:array_id, index, found); return found; }

// Returns the last empty index starting at provarray_ided index.
stock array_lastempty(array_id, index, &success = 0) { new found; success = SparseArrayLastEmpty (SparseArray:array_id, index, found); return found; }