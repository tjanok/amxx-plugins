#if defined _DRPData_INCLUDE
	#endinput
#endif

#define _DRPData_INCLUDE

#include <DRP/DRPCore>
#include <celltravtrie>

// Loads a class
// Calls forward "DRP_ClassLoaded" when complete
// Also calls the "handler" string
// Note that if it's already loaded by another plugin,
// the forward will be called instantly
// const class[] - name of the class to load
// const handler[] - local function to call when done
// data[] - data to pass
// table[] = "" - table to load from (leave blank for data table)
native DRP_ClassLoad(const Class[],const Handler[],Data[],const Table[] = "");

// Saves a class
// Class:ClassID - class id as given in DRP_ClassLoaded
// close=0 - whether or not to also close the class
// Note that if another plugin is using it, close
// will not completely close it until the other stops
// If close = 1, ClassID will be set to 0
native DRP_ClassSave(&Class:ClassID,Close = 0);

// Sets a hook for saving a class
// This is the best time to set values
// Don't do it right before calling a class save;
// this is a bad idea because another plugin could start
// the save before you get a chance to set anything.
// This forward guarantees that you can save it properly.
// Also note that you can call it repeatedly in order to
// change the "data" parameter.
// Class:class_id - class id as given in DRP_ClassLoaded
// const handler[] - function called when the class is being saved
// data[] - data to pass
native DRP_ClassSaveHook(Class:ClassID,const Handler[],Data[]);

// Deletes a key
// This dispatches an SQL query on the spot, so avoid using it
// excessively.
// Class:class_id - class id as given in DRP_ClassLoaded
// const key[] - the key to delete
native DRP_ClassDeleteKey(Class:ClassID,const Key[]);

// Stocks
stock DRP_ClassSetChanged(Class:ClassID,const Key[],const Value[])
{
	if(Key[0] == '/' || Key[0] == '^n') 
		return FAILED

	new Forward = CreateMultiForward("DRP_ClassKeyChange",ET_CONTINUE,FP_CELL,FP_STRING,FP_STRING),Return
	if(!Forward || !ExecuteForward(Forward,Return,ClassID,Key,Value))
	{
		//DRP_ThrowError(0,"[DRP_ClassSetChanged] Could not execute forward");
		return FAILED
	}
	DestroyForward(Forward);

	if(Return)
		return FAILED

	new TravTrie:ChangedTrie
	TravTrieGetCell(TravTrie:ClassID,"/changed",ChangedTrie);
	TravTrieSetCell(ChangedTrie,Key,1);

	return SUCCEEDED
}

stock DRP_ClassGetInt(Class:ClassID,const Key[])
{
	if(Key[0] == '/' || Key[0] == '^n')
		return FAILED

	new Value[64],Success = TravTrieGetString(TravTrie:ClassID,Key,Value,63);

	return str_to_num(Value) * Success
}

stock DRP_ClassSetIntEx(Class:ClassID,KeyVal,Value) 
{ 
	new StrValue[12]
	formatex(StrValue,11,"%d",KeyVal); 
	
	return DRP_ClassSetInt(ClassID,StrValue,Value); 
}
stock DRP_ClassGetIntEx(Class:ClassID,KeyVal) 
{
	new StrValue[12]
	formatex(StrValue,11,"%d",KeyVal); 
	
	return DRP_ClassGetInt(ClassID,StrValue); 
}

stock DRP_ClassSetInt(Class:ClassID,const Key[],Value)
{
	if(Key[0] == '/' || Key[0] == '^n')
		return FAILED

	new NewValue[64],OldValue[64]
	formatex(NewValue,63,"%d",Value);

	TravTrieGetString(TravTrie:ClassID,Key,OldValue,63);

	if(str_to_num(OldValue) != Value && DRP_ClassSetChanged(ClassID,Key,NewValue))
		return TravTrieSetString(TravTrie:ClassID,Key,NewValue)

	return FAILED
}

stock DRP_ClassSetString(Class:ClassID,const Key[],String[])
{
	if(Key[0] == '/' || Key[0] == '^n')
		return FAILED

	static Temp[1024]
	TravTrieGetString(TravTrie:ClassID,Key,Temp,1023);

	if(!equal(Temp,String) && DRP_ClassSetChanged(ClassID,Key,String))
		return TravTrieSetString(TravTrie:ClassID,Key,String);

	return FAILED
}
stock DRP_ClassGetString(Class:ClassID,const Key[],String[],Len)
{
	if(Key[0] == '/' || Key[0] == '^n') 
		return FAILED

	return TravTrieGetString(TravTrie:ClassID,Key,String,Len);
}

// Forwards
forward DRP_ClassLoaded(Class:ClassID,const Class[]);

// return PLUGIN_HANDLED to block
forward DRP_ClassKeyChange(Class:ClassID,const Key[],const Value[]);