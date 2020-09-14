#if defined _DRP_SQL_INCLUDE
	#endinput
#endif

#define _DRP_SQL_INCLUDE

#include <DRP/DRPCore>
#include <sqlx>

// Returns the SQL Handle
native Handle:DRP_SqlHandle();

/*
 * Don't use this
 */
native DRP_CleverQueryBackend(Handle:db_tuple,const handler[],const query[],const data[]="",dataSize=0);

/**
 * Prepares and executes a query.
 * This will not interrupt gameplay in the event of a poor/lossed 
 *  connection, however, the interface is more complicated and 
 *  asynchronous.  Furthermore, a new connection/disconnection is 
 *  made for each query to simplify driver support. It will use
 *  non-threaded queries whenever possible such as when no players
 *  are in the server and when the map has ended.
 *
 * The handler should look like:
 *
 * @param failstate - One of the three TQUERY_ defines.
 * @param query - Handle to the query, do not free it.
 * @param error - An error message, if any.
 * @param errnum - An error code, if any.
 * @param data - Data array you passed in.
 * @param size - Size of the data array you passed in.
 * @param queuetime - Amount of gametime that passed while the query was resolving.
 * 
 * public QueryHandler(failstate, Handle:query, error[], errnum, data[], size, Float:queuetime)
 *
 * Note! The handle you pass in is a DB Tuple, NOT an active connection!
 * Note! The handle does not need to be freed.
 * Also note: This function is not guaranteed to be in another thread
 *  (in fact - it's not).  You're seeing data "after the fact", 
 *  and as such to execute another query you should run 
 *  DRP_CleverQuery again with new data.
 */
stock DRP_CleverQuery(Handle:db_tuple,const handler[],const query[],const data[]="", dataSize=0)
	return DRP_CleverQueryBackend(db_tuple,handler,query,data,dataSize) ? SQL_ThreadQuery(db_tuple,handler,query,data,dataSize) : PLUGIN_HANDLED

// Removes special keys from a query to avoid errors
// Make sure String[] & Len are atleast 63
stock DRP_SQLRemoveKey(String[],Len)
	replace_all(String,Len,"'","\'");