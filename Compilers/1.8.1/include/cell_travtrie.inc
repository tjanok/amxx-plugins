#if defined _cell_travtrie_included
 #endinput
#endif
#define _cell_travtrie_included

#include <cellarray>
#include <celltrie>

#define TRAVTRIE_MAX_KEY_LEN 1024

stock g_Key[1024]

stock TravTrie:TravTrieCreate(keylength = 64, startsize = 0)
{
	new Trie:tmp = TrieCreate();
	TrieSetCell(tmp, "", _:ArrayCreate(keylength, startsize));
	return TravTrie:tmp;
}

stock bool:TravTrieSetCell(TravTrie:trie, const key[], any:value)
{
	if(key[0] == '^n') return false;
	
	new any:val;
	if(!TravTrieGetCell(trie, key, val) )
	{
		new Array:iter;
		if(!TrieGetCell(Trie:trie,"",any:iter)) return false;
	
		ArrayPushString(Array:iter,key);
	}
	if(key[0] == '^n') return false;
	
	TrieSetCell(Trie:trie,key,value);
	return true;
}

stock bool:TravTrieSetArray(TravTrie:trie, const key[], const array[], num_items)
{
	if(key[0] == '^n') return false;
	
	new val[2];
	if(!TravTrieGetArray(trie, key, val,sizeof(val)) )
	{
		new Array:iter;
		if(!TrieGetCell(Trie:trie,"",any:iter)) return false;
	
		ArrayPushString(iter,key);
	}
	
	if(key[0] == '^n') return false;
	
	TrieSetArray(Trie:trie,key,array,num_items);
	return true;
}

stock bool:TravTrieSetString(TravTrie:trie, const key[], value[])
{
	if(key[0] == '^n') return false;
	
	new val[4];
	if(!TravTrieGetString(trie, key, val,sizeof(val)) )
	{
		new Array:iter;
		if(!TrieGetCell(Trie:trie,"",any:iter)) return false;
	
		ArrayPushString(iter,key);
	}
	
	if(key[0] == '^n') return false;
	
	TrieSetString(Trie:trie,key,value);
	return true;
}

stock bool:TravTrieGetCell(TravTrie:trie, const key[], &any:value)
{
	return (key[0] == '^n') ? false : TrieGetCell(Trie:trie,key,value);
}

stock bool:TravTrieGetArray(TravTrie:trie, const key[], any:array[], num_items)
{
	return (key[0] == '^n') ? false : TrieGetArray(Trie:trie,key,array,num_items);
}

stock bool:TravTrieGetString(TravTrie:trie, const key[], value[], max_size)
{
	return (key[0] == '^n') ? false : TrieGetString(Trie:trie,key,value,max_size);
}

stock bool:TravTrieDeleteKey(TravTrie:trie, const key[])
{
	if(key[0] != '^n' && TrieDeleteKey(Trie:trie,key) )
	{
		new Array:iter;
		if(!TrieGetCell(Trie:trie,"",any:iter)) return false;
	
		static tmp[TRAVTRIE_MAX_KEY_LEN];
		new index = 0;

		while(index < ArraySize() )
		{
			ArrayGetString(iter, index, tmp, TRAVTRIE_MAX_KEY_LEN - 1);
			if(equal(tmp,key)) return (ArrayDeleteItem(iter, index) == 1);
			index++;
		}
	}
	return false;
}

stock TravTrieDestroy(&TravTrie:trie)
{
	new Array:iter;
	if(!TrieGetCell(Trie:trie,"",any:iter)) { TrieDestroy(Trie:trie); return; }

	ArrayDestroy(iter);
	TrieDestroy(Trie:trie);
}

stock TravTrieClear(TravTrie:trie)
{
	new Array:iter;
	if(!TrieGetCell(Trie:trie,"",any:iter)) { TrieClear(Trie:trie); return; }

	ArrayClear(iter);
	TrieClear(Trie:trie);
}

//stock TravTrieSize(TravTrie:trie) return TrieGetSize(trie) - 1;

// Rukia: Use this to prepare the TravTrie for SORTED traversal
//	If you do not use this, it will be traversed in FIFO order
stock bool:PrepareTravTrie(TravTrie:trie) 
{
	new Array:iter;
	if(!TrieGetCell(Trie:trie,"",any:iter)) { TrieClear(Trie:trie); return; }

	ArraySort(iter, "SortADTArrayDesc");
}

public SortADTArrayDesc(Array:array, item1, item2, const data[], data_size)
{
	static item1str[TRAVTRIE_MAX_KEY_LEN], item2str[TRAVTRIE_MAX_KEY_LEN]
	ArrayGetString(array,item1,item1str,TRAVTRIE_MAX_KEY_LEN - 1);
	ArrayGetString(array,item2,item2str,TRAVTRIE_MAX_KEY_LEN - 1);

	return strcmp ( item2str, item1str );
}

// Rukia: Get a mutable iterator to the travtrie
//	This Handle MUST be closed using CloseHandle, and delete/insert will invalidate iterator
stock travTrieIter:GetTravTrieIterator(TravTrie:trie)
{
	new Array:dp = ArrayCreate();
	ArrayPushCell(dp,_:trie);
	ArrayPushCell(dp,0);
	return travTrieIter:dp;
}

stock TravTrieIterDestroy(&travTrieIter:dp)
{
	ArrayDestroy(_:dp);
}

// Rukia: Read the string key that the iterator points to.
//	WILL NOT INCREMENT ITERATOR
stock ReadTravTrieKey(travTrieIter:dp,key[],len)
{
	new Trie:trie = Trie:ArrayGetCell(Array:dp,0);
	
	new Array:iter;
	if(!TrieGetCell(trie,"",_:iter)) return;
	
	new index = ArrayGetCell(Array:dp,1);
	ArrayGetString(iter,index,key,len);
}

// Rukia: These functions read from the travtrie via the iterator
//	They WILL INCREMENT THE ITERATOR

stock bool:ReadTravTrieCell(travTrieIter:dp,&any:value)
{
	static tmp[TRAVTRIE_MAX_KEY_LEN];
	new TravTrie:trie = TraveTrieIteratorHandler(Array:dp,tmp,TRAVTRIE_MAX_KEY_LEN - 1);
	
	return TravTrieGetCell(trie,tmp,value);
}

stock bool:ReadTravTrieArray(travTrieIter:dp, value[], max_num)
{
	static tmp[TRAVTRIE_MAX_KEY_LEN];
	new TravTrie:trie = TraveTrieIteratorHandler(Array:dp,tmp,TRAVTRIE_MAX_KEY_LEN - 1);
	
	return TravTrieGetArray(trie,tmp,value,max_num);
}

stock bool:ReadTravTrieString(travTrieIter:dp, value[], max_num)
{
	static tmp[TRAVTRIE_MAX_KEY_LEN];
	new TravTrie:trie = TraveTrieIteratorHandler(Array:dp,tmp,TRAVTRIE_MAX_KEY_LEN - 1);
	
	return TravTrieGetString(trie,tmp,value,max_num);
}

stock TravTrie:TravTrieIteratorHandler(Array:dp,pos[],len)
{
	new Trie:trie = Trie:ArrayGetCell(dp,0);
	
	new Array:iter;
	if(!TrieGetCell(trie,"",any:iter)) return TravTrie:Invalid_Trie;
	
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
	if(!TrieGetCell(trie,"",any:iter)) return false;
	
	new index = _:ArrayGetCell(Array:dp,1);
	if(ArraySize(iter) <= index) return false;
	
	return true;
}

// Hawk: Gets the nth key, starting at 1

stock bool:TravTrieNth(TravTrie:trie, nth, key[], len)
{
	new travTrieIter:dp = GetTravTrieIter(trie), i = 1;
	if(!dp)	return false;

	for(; i <= nth && MoreTravTrie(dp); i++) ReadTravTrieKey(dp,key,len);

	return i == nth;
}
	

// Hawk: Extended stocks for passing an integer as a key
	
stock bool:TravTrieSetCellEx(TravTrie:trie, const key, any:value)
{
	formatex(g_Key,1024,"%d",key);

	return TravTrieSetCell(trie,g_Key,value);
}

stock bool:TravTrieSetArrayEx(TravTrie:trie, const key, const array[], num_items)
{
	formatex(g_Key,1024,"%d",key);

	return TravTrieSetArray(trie,g_Key,array,num_items);
}

stock bool:TravTrieSetStringEx(TravTrie:trie, const key, value[])
{
	formatex(g_Key,1024,"%d",key);

	return TravTrieSetString(trie,g_Key,value);
}

stock bool:TravTrieDeleteKeyEx(TravTrie:trie, const key)
{
	formatex(g_Key,1024,"%d",key);

	return TravTrieDeleteKey(trie,g_Key);
}

stock bool:TravTrieGetCellEx(TravTrie:trie, const key, &any:value)
{
	formatex(g_Key,1024,"%d",key);

	return TravTrieGetCell(trie,g_Key,value);
}

stock bool:TravTrieGetArrayEx(TravTrie:trie, const key, any:array[], num_items)
{
	formatex(g_Key,1024,"%d",key);

	return TravTrieGetArray(trie,g_Key,array,num_items);
}

stock bool:TravTrieGetStringEx(TravTrie:trie, const key[], value[], max_size)
{
	formatex(g_Key,1024,"%d",key);

	return TravTrieGetString(trie,g_Key,value,max_size);
}

stock bool:ReadTravTrieKeyEx(travTrieIter:dp,&key)
{
	new result = ReadTravTrieKey(dp,g_Key,1024);
	key = str_to_num(g_Key);

	return bool:result;
}

// Hawk: Gets the number of elements in a travtrie

stock bool:TravTrieGetNum(TravTrie:trie,&num)
{
	new travTrieIter:dp = GetTravTrieIter(trie);
	if(!dp)	return false;

	for(; MoreTravTrie(dp); num++) { }

	return true;
}
