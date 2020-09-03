/* Array const
*
* by Twilight Suzuka + Kuchiki Rukia + Urahara Kisuke
* 
*
* This file is provided as is (no warranties).
*/
// This file explains how to use some of the trickier portions of array.


#if defined _array_const_included
    #endinput
#endif
#define _array_const_included

//* Enumeration for *_get_type. pawn_type_none means it does not exist.
enum 
{
	pawn_type_none = 0,
	pawn_type_bool,
	pawn_type_int,
	pawn_type_flo,
	pawn_type_vec,
	pawn_type_str,
	pawn_type_array
};