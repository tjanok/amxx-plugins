#if defined _cell_sparsearray_included
	#endinput
#endif

#define _cell_sparsearray_included

/**
 * These arrays are intended to be used for a form of global storage without 
 * requiring a #define that needs to be increased each time a person needs more 
 * storage.
 * These are not designed to be used as a replacement for normal arrays, as
 * normal arrays are faster and should be used whenever possible.
 * 
 * The difference between these and typical cellarrays is the fact they are sparse.
 * Sparse means that a great deal of the values may be unset without wasting space.
 * This allows for easy and intuitive commands, at the cost of performance.
 *
 * The sparse array also functions more like a traditional static array.
 * The only difference is you may safely specify any index; the index will be created on the fly for you.
 */

/**
 * Creates a handle to a dynamically sized sparse array.
 *
 * @return 			Handle to the sparse array.
 */
native SparseArray:SparseArrayCreate();

/**
 * Destroys the array, and resets the handle to 0 to prevent accidental usage after it is destroyed.
 *
 * @param which			The array to destroy.
 */
native SparseArrayDestroy(&SparseArray:which);

/**
 * Clears all entries from the sparse array.
 *
 * @param which		The sparse array to clear.
 * @return				1 on success, 0 on failure.
 */
native SparseArrayClear(SparseArray:which);

/**
 * Returns the number of elements in the sparse array.
 *
 * @param which		The sparse array to check.
 * @return				How many elements are in the array.
 */
native SparseArraySize(SparseArray:which);

/**
 * Deletes an item from the sparse array. No items are touched besides the indexed one.
 *
 * @param which			The array that contains the item to delete.
 * @param item			The item to delete.
 */
native SparseArrayDelete(SparseArray:which, item);

/**
 * Gets whether an items exists in the sparse array.
 *
 * @param which			The array that contains the item to access.
 * @param item			The item to access.
 * @ return				1 on success, 0 on no item
 */
native SparseArrayExists(SparseArray:which, item);


/**
 * Gets an items type from the sparse array.
 *
 * @param which			The array that contains the item to access.
 * @param item			The item to access.
 * @param type			The variable to set the type into
 * @ return				1 on success, 0 on no item
 */
native SparseArrayGetType(SparseArray:which, item, &type);


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
 *		Please use SparseArrayExists to check if the item exists if you are not certain it will be in the sparse array.
 *
 *	Item is of incorrect type: Stopping (plugin will not continue after this error occurs)
 *		Failure may occur if the type you request from the item is not the type originally inserted.
 *		Use SparceArrayGetType if there is any doubt about the type of item you are attempting to retrieve.
 */

native SparseArrayGetBool	(SparseArray:which, item, &bool:value)
native SparseArrayGetInt	(SparseArray:which, item, &value)
native SparseArrayGetFloat	(SparseArray:which, item, &Float:value)
native SparseArrayGetString	(SparseArray:which, item, value[], len)
native SparseArrayGetVector	(SparseArray:which, item, Float:value[3])
native SparseArrayGetArray	(SparseArray:which, item, value[], len)


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

native SparseArraySetBool	(SparseArray:which, item, bool:value)
native SparseArraySetInt	(SparseArray:which, item, value)
native SparseArraySetFloat	(SparseArray:which, item, Float:value)
native SparseArraySetString	(SparseArray:which, item, value[])
native SparseArraySetVector	(SparseArray:which, item, Float:value[3])
native SparseArraySetArray	(SparseArray:which, item, value[], len)

/** TRAVERSALS
 * Definitions of function types:
 *
 * First: Find smallest present index greater than or equal to start
 * Next: Find smallest present index greater than to start
 * Prev: Find smallest present index less than to start
 * Last: Find smallest present index less than or equal to start
 */

/**
 * Gets the Nth item.
 *
 * @param which			The array that contains the item to access.
 * @param nth			How many to go over.
 * @param start			Where to start.
 * @param item			Item returned here
 * @ return				1 on success, 0 on no item
 */
native SparseArrayNth (SparseArray:which, nth, start, &item)

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

native SparseArrayFirst (SparseArray:which, start, &found)
native SparseArrayNext	(SparseArray:which, start, &found)
native SparseArrayPrev	(SparseArray:which, start, &found)
native SparseArrayLast	(SparseArray:which, start, &found)


/** EMPTY TRAVERSAL functions
 * 
 * We may also wish to retrieve non-existing, or empty, indexes.
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

native SparseArrayFirstEmpty (SparseArray:which, start, &found)
native SparseArrayNextEmpty	(SparseArray:which, start, &found)
native SparseArrayPrevEmpty	(SparseArray:which, start, &found)
native SparseArrayLastEmpty	(SparseArray:which, start, &found)
