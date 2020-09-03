#if defined _travtriex_included
	#endinput
#endif
#define _travtriex_included

#include <cellarray>
#include <celltrie>

//#define _ENABLE_ARRAYS

enum TravTrie
{
    Invalid_TravTrie = 0
}

#define TRAVTRIE_MAX_KEY_LEN 1024

new const TravTrieKeyConst[] = ""

stock TravTrie:TravTrieCreate( keyLength = 256, startSize = 32 )
{
	new Trie:trie = TrieCreate()
	TrieSetCell( trie, TravTrieKeyConst, _:ArrayCreate( keyLength, startSize ) )
	return TravTrie:trie
}

stock TravTrieDestroy( &TravTrie:travTrie )
{
	new Array:iter
	if ( !TrieKeyExists( Trie:travTrie, TravTrieKeyConst ) || !TrieGetCell( Trie:travTrie, TravTrieKeyConst, any:iter ) ) 
	{
		TrieDestroy( Trie:travTrie )
		return
	}

	ArrayDestroy( iter )
	TrieDestroy( Trie:travTrie )
}

stock bool:TravTrieSetCell( TravTrie:travTrie, const key[], any:value )
{
	if ( equali( key, TravTrieKeyConst ) ) 
		return false

	new any:val
	if ( !TrieKeyExists( Trie:travTrie, key ) || !TravTrieGetCell( travTrie, key, val ) )
	{
		new Array:iter
		if ( !TrieKeyExists( Trie:travTrie, TravTrieKeyConst ) || !TrieGetCell( Trie:travTrie, TravTrieKeyConst, any:iter ) ) 
			return false

		ArrayPushString( Array:iter, key )
	}

	TrieSetCell( Trie:travTrie, key, value )
	
	return true
}

#if defined _ENABLE_ARRAYS
stock bool:TravTrieSetArray( TravTrie:travTrie, const key[], const array[], num_items )
{
    if(key[0] == '^n') return false;
    
    new val[2];
    if(!TrieKeyExists(Trie:trie,key) || !TravTrieGetArray(trie, key, val,sizeof(val)) )
    {
        new Array:iter;
        if(!TrieGetCell(Trie:trie,"",any:iter)) return false;
    
        ArrayPushString(iter,key);
    }
    
    if(key[0] == '^n') return false;
    
    TrieSetArray(Trie:trie,key,array,num_items);
    return true;
}
#endif // _ENABLE_ARRAYS

stock bool:TravTrieSetString( TravTrie:travTrie, const key[], value[] )
{
    if ( equali( key, TravTrieKeyConst ) )
		return false
    
    new val[4]
    if ( !TrieKeyExists( Trie:travTrie, key ) || !TravTrieGetString( travTrie, key, val, charsmax( val ) ) )
    {
        new Array:iter
        if ( !TrieKeyExists( Trie:travTrie, TravTrieKeyConst ) || !TrieGetCell( Trie:travTrie, TravTrieKeyConst, any:iter ) ) 
			return false
    
        ArrayPushString( iter, key )
    }
    
    TrieSetString( Trie:travTrie, key, value )
	
    return true
}

stock bool:TravTrieGetCell( TravTrie:travTrie, const key[], &any:value )
{
	if ( equali( key, TravTrieKeyConst ) || !TrieKeyExists( Trie:travTrie, key ) )
		return false 

	return TrieGetCell( Trie:travTrie, key, value )
}

#if defined _ENABLE_ARRAYS
stock bool:TravTrieGetArray(TravTrie:trie, const key[], any:array[], num_items)
{
    return (!TrieKeyExists(Trie:trie,key) || key[0] == '^n') ? false : TrieGetArray(Trie:trie,key,array,num_items);
}
#endif // _ENABLE_ARRAYS

stock bool:TravTrieGetString( TravTrie:travTrie, const key[], value[], max_size )
{
	if ( equali( key, TravTrieKeyConst ) || !TrieKeyExists( Trie:travTrie, key ) )
		return false 

	return TrieGetString( Trie:travTrie, key, value, max_size )
}

stock bool:TravTrieDeleteKey( TravTrie:travTrie, const key[] )
{
	if ( equali( key, TravTrieKeyConst ) || !TrieKeyExists( Trie:travTrie, key ) ) 
		return false

	if ( TrieDeleteKey( Trie:travTrie, key ) )
	{
		new Array:iter
		if ( !TrieGetCell( Trie:travTrie, TravTrieKeyConst, any:iter ) ) 
			return false

		new arrayKey[TRAVTRIE_MAX_KEY_LEN], index

		while ( index < ArraySize( iter ) )
		{
			ArrayGetString( iter, index, arrayKey, charsmax( arrayKey ) )
			if ( equali( arrayKey, key ) ) 
				return ArrayDeleteItem( iter, index )
			index++
		}
	}
	
	return false
}

stock TravTrieClear( TravTrie:travTrie )
{
    new Array:iter
    if ( !TrieKeyExists( Trie:travTrie, TravTrieKeyConst ) || !TrieGetCell( Trie:travTrie, TravTrieKeyConst, any:iter ) ) 
	{ 
		TrieClear( TravTrie:travTrie ) 
		return 
	}

    ArrayClear( iter )
    TrieClear( TravTrie:travTrie )
}

// Rukia: Use this to prepare the TravTrie for SORTED traversal
//    If you do not use this, it will be traversed in FIFO order
stock bool:PrepareTravTrie( TravTrie:travTrie ) 
{
    new Array:iter
    if ( !TrieKeyExists( Trie:travTrie, TravTrieKeyConst ) || !TrieGetCell( Trie:travTrie, TravTrieKeyConst, any:iter ) ) 
	{
		TrieClear( Trie:travTrie )
		return 
	}

    ArraySort( iter, "SortADTArrayDesc" )
}

public SortADTArrayDesc( Array:array, item1, item2, const data[], data_size )
{
    new item1str[TRAVTRIE_MAX_KEY_LEN], item2str[TRAVTRIE_MAX_KEY_LEN]
    ArrayGetString( array, item1, item1str, charsmax( item1str ) )
    ArrayGetString( array, item2, item2str, charsmax( item2str ) )

    return strcmp( item2str, item1str )
}

// Rukia: Get a mutable iterator to the travtrie
//    This Handle MUST be closed using CloseHandle, and delete/insert will invalidate iterator
stock travTrieIter:GetTravTrieIterator( TravTrie:travTrie )
{
    new Array:dp = ArrayCreate()
    ArrayPushCell( dp, _:travTrie )
    ArrayPushCell( dp, 0 )
    return travTrieIter:dp
}

// Rukia: Read the string key that the iterator points to.
//    WILL NOT INCREMENT ITERATOR
stock bool:ReadTravTrieKey( travTrieIter:dp, key[], len )
{
    new Trie:trie = Trie:ArrayGetCell( Array:dp, 0 )
    
    new Array:iter
    if ( !TrieKeyExists( trie, TravTrieKeyConst ) || !TrieGetCell( trie, TravTrieKeyConst, _:iter ) ) 
		return false
    
    new index = ArrayGetCell( Array:dp, 1 )
    return bool:ArrayGetString( iter, index, key, len )
}

stock TravTrieSize( TravTrie:travTrie )
{
    new Array:iter
    if ( !TravTrieGetCell( travTrie, TravTrieKeyConst, _:iter ) ) 
		return false

    return ArraySize( iter )
}

stock bool:ReadTravTrieCell(travTrieIter:dp,&any:value)
{
    new tmp[TRAVTRIE_MAX_KEY_LEN];
    new TravTrie:trie = TravTrieIteratorHandler(Array:dp,tmp,TRAVTRIE_MAX_KEY_LEN - 1);
    
    return TravTrieGetCell(trie,tmp,value);
}

stock bool:ReadTravTrieArray(travTrieIter:dp, value[], max_num)
{
    new tmp[TRAVTRIE_MAX_KEY_LEN];
    new TravTrie:trie = TravTrieIteratorHandler(Array:dp,tmp,TRAVTRIE_MAX_KEY_LEN - 1);
    
    return TravTrieGetArray(trie,tmp,value,max_num);
}

stock bool:ReadTravTrieString(travTrieIter:dp, value[], max_num)
{
    new tmp[TRAVTRIE_MAX_KEY_LEN];
    new TravTrie:trie = TravTrieIteratorHandler(Array:dp,tmp,TRAVTRIE_MAX_KEY_LEN - 1);
    
    return TravTrieGetString(trie,tmp,value,max_num);
}

stock TravTrie:TravTrieIteratorHandler(Array:dp,pos[],len)
{
    new Trie:trie = Trie:ArrayGetCell(dp,0);
    
    new Array:iter;
    if(!TrieKeyExists(trie,TravTrieKeyConst) || !TrieGetCell(trie,TravTrieKeyConst,any:iter)) return TravTrie:Invalid_Trie;
    
    new index = ArrayGetCell(dp,1);
    ArrayGetString(iter,index,pos,len);
    
    ArraySetCell(dp,1,index + 1);
    
    return TravTrie:trie;
}

// Rukia: Returns true if there is more to read from the iterator

stock bool:MoreTravTrie(travTrieIter:dp)
{
    new Trie:trie = Trie:ArrayGetCell(Array:dp,0);
    
    new Array:iter;
    if(!TrieKeyExists(trie,TravTrieKeyConst) || !TrieGetCell(trie,TravTrieKeyConst,any:iter)) return false;
    
    new index = _:ArrayGetCell(Array:dp,1);
    if(ArraySize(iter) <= index) return false;
    
    return true;
}

stock DestroyTravTrieIterator(&travTrieIter:dp)
{
    ArrayDestroy(Array:dp);
}

stock bool:TravTrieDeleteKeyEx(TravTrie:trie, key)
{
	new tmp[TRAVTRIE_MAX_KEY_LEN];
    formatex(tmp,TRAVTRIE_MAX_KEY_LEN - 1,"%d",key);

    return TravTrieDeleteKey(trie,tmp);
}

// Hawk: Gets the nth key, starting at 0
stock bool:TravTrieNth(TravTrie:trie, nth, key[], len)
{
    new Array:iter;
    PrepareTravTrie(trie);
    if(!TravTrieGetCell(trie,TravTrieKeyConst,iter)) return false;
    
    new value[TRAVTRIE_MAX_KEY_LEN], result = ArrayGetString(iter,nth,value,charsmax(value));
    copy(key,len,value);

    return bool:result;
}

stock bool:TravTrieNthEx(TravTrie:trie,nth,&key)
{
	new tmp[TRAVTRIE_MAX_KEY_LEN];
    new bool:result = TravTrieNth(trie,nth,tmp,charsmax(tmp));
    key = str_to_num(tmp);
    
    return result;
}

// Hawk: Extended functions for passing an integer as a key

stock bool:TravTrieGetCellEx(TravTrie:trie, key, &any:value)
{
    new tmp[TRAVTRIE_MAX_KEY_LEN];
    formatex(tmp,charsmax(tmp),"%d",key);
    new tempvalue, bool:result = TravTrieGetCell(trie,tmp,tempvalue);
    value = tempvalue;
    return result;
}

stock bool:TravTrieGetStringEx(TravTrie:trie, key, value[], len)
{
    new tmp[TRAVTRIE_MAX_KEY_LEN], value[TRAVTRIE_MAX_KEY_LEN];
    formatex(tmp,charsmax(tmp),"%d",key);
    new bool:result = TravTrieGetString(trie,tmp,value,charsmax(value));
    copy(value,abs(min(len,charsmax(value))),value);

    return result;
}

#if defined _ENABLE_ARRAYS
stock bool:TravTrieGetArrayEx(TravTrie:trie, key, any:value[], len)
{
    new tmp[TRAVTRIE_MAX_KEY_LEN];
    formatex(tmp,charsmax(tmp),"%d",key);
    new result = TravTrieGetArray(trie,tmp,g_Value,abs(min(TRAVTRIE_MAX_KEY_LEN,len)));
    for(new count; count < len; count++)
        value[count] = g_Value[count];

    return result;
}
#endif // _ENABLE_ARRAYS

stock bool:TravTrieSetCellEx(TravTrie:trie, key, any:value)
{
    new tmp[TRAVTRIE_MAX_KEY_LEN];
    formatex(tmp,charsmax(tmp),"%d",key);
    return TravTrieSetCell(trie,tmp,value);
}

stock bool:TravTrieSetStringEx(TravTrie:trie, key, value[])
{
    new tmp[TRAVTRIE_MAX_KEY_LEN];
    formatex(tmp,charsmax(tmp),"%d",key);
    return TravTrieSetString(trie,tmp,value);
}

#if defined _ENABLE_ARRAYS
stock bool:TravTrieSetArrayEx(TravTrie:trie, key, any:value[], len)
{
    new tmp[TRAVTRIE_MAX_KEY_LEN];
    formatex(tmp,charsmax(tmp),"%d",key);
    return TravTrieSetArray(trie,tmp,value,len);
}
#endif // _ENABLE_ARRAYS

stock bool:ReadTravTrieKeyEx(travTrieIter:dp,&key)
{
	new tmp[TRAVTRIE_MAX_KEY_LEN];
    new bool:result = ReadTravTrieKey(dp,tmp,charsmax(tmp));
    key = str_to_num(tmp);

    return result;
}
