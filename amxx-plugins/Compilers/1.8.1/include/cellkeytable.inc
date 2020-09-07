#if defined _cell_Keytable_included
	#endinput
#endif

#define _cell_Keytable_included

/**
 * These keytables are intended to be used for a form of global storage without 
 * requiring a full nVault, and hopefully will soon be much faster as a form of temp
 * storage.
 * 
 * The difference between these and nVault is the fact they are sorted, and traversable.
 * In addition, they are truely meant for temporary usage (though they can be adapted to permanent usages).
 * This makes them much faster, as they only operate in RAM.
 *
 */

/**
 * Creates a handle to a dynamically sized sparse array.
 *
 * @return 			Handle to the sparse array.
 */
native Keytable:KeytableCreate();

/**
 * Destroys the array, and resets the handle to 0 to prevent accidental usage after it is destroyed.
 *
 * @param which			The array to destroy.
 */
native KeytableDestroy(&Keytable:which);

/**
 * Clears all entries from the sparse array.
 *
 * @param which		The sparse array to clear.
 * @return				1 on success, 0 on failure.
 */
native KeytableClear(Keytable:which);

/**
 * Returns the number of elements in the sparse array.
 *
 * @param which		The sparse array to check.
 * @return				How many elements are in the array.
 */
native KeytableSize(Keytable:which);

/**
 * Deletes an item from the sparse array. No items are touched besides the indexed one.
 *
 * @param which			The array that contains the item to delete.
 * @param item			The item to delete.
 */
native KeytableDelete(Keytable:which, item[]);

/**
 * Gets whether an items exists in the sparse array.
 *
 * @param which			The array that contains the item to access.
 * @param item			The item to access.
 * @ return				1 on success, 0 on no item
 */
native KeytableExists(Keytable:which, item[]);


/**
 * Gets an items type from the sparse array.
 *
 * @param which			The array that contains the item to access.
 * @param item			The item to access.
 * @param type			The variable to set the type into
 * @ return				1 on success, 0 on no item
 */
native KeytableGetType(Keytable:which, item[], &type);


/** GET functions
 * 
 * All Get style functions have the following style:
 *
 * @param which 			The array that contains the item to get;
 * @param item			The item to get.
 * @param value			The variable to put it into (passed by reference)
 * @return				1 on success, 0 on failure
 *
 * Failure modes:
 *	Item Does Not Exist: Non-stopping (plugin will continue after this error occurs)
 * 		Get style functions will fail if you attempt to retrieve from an item not in the sparse array.
 *		Please use KeytableExists to check if the item exists if you are not certain it will be in the sparse array.
 *
 *	Item is of incorrect type: Stopping (plugin will not continue after this error occurs)
 *		Failure may occur if the type you request from the item is not the type originally inserted.
 *		Use SparceArrayGetType if there is any doubt about the type of item you are attempting to retrieve.
 */

native KeytableGetBool	(Keytable:which, item[], &bool:value)
native KeytableGetInt	(Keytable:which, item[], &value)
native KeytableGetFloat	(Keytable:which, item[], &Float:value)
native KeytableGetString(Keytable:which, item[], value[], len)
native KeytableGetVector(Keytable:which, item[], Float:value[3])
native KeytableGetArray	(Keytable:which, item[], value[], len)


/** SET functions
 * 
 * All Set style functions have the following style:
 *
 * @param which 			The array that contains the item to set;
 * @param item			The item to set.
 * @param value			The value to set it to
 * @return				1 on success (should always be 1)
 *
 * Please note that Set will overwrite an index if it already exists with the new provided value.
 */

native KeytableSetBool	(Keytable:which, item[], bool:value)
native KeytableSetInt	(Keytable:which, item[], value)
native KeytableSetFloat	(Keytable:which, item[], Float:value)
native KeytableSetString(Keytable:which, item[], value[])
native KeytableSetVector(Keytable:which, item[], Float:value[3])
native KeytableSetArray	(Keytable:which, item[], value[], len)

/** TRAVERSALS
 * Definitions of function types:
 *
 * First: Find smallest present index greater than or equal to start
 * Next: Find smallest present index greater than to start
 * Prev: Find smallest present index less than to start
 * Last: Find smallest present index less than or equal to start
 */


/**
 * Gets an items N existing places from start
 *
 * @param which			The array that contains the item to access.
 * @param Nth			The item to access.
 * @param start			The starting location
 * @param ret			Returning index
 * @ return				1 on success, 0 on no item
 */
native KeytableNth(Keytable:which, Nth, start[], &ret);


/** EXISTING TRAVERSAL functions
 * 
 * Because some indexes into a sparse array may not even exist, we need a way to retrieve all existing indexes
 * We do this through traversal functions, which have the following format:
 *
 * @param which 			The array that contains the item to set;
 * @param start			The item to start from.
 * @param found			The item found
 * @return				1 on success, 0 on failure.
 *
 * Please note that indexes will be pulled out in sorted order.
 *
 */

native KeytableFirst	(Keytable:which, start[], found[], len)
native KeytableNext	(Keytable:which, start[], found[], len)
native KeytablePrev	(Keytable:which, start[], found[], len)
native KeytableLast	(Keytable:which, start[], found[], len)