#if defined _DRP_FILE_INCLUDE
	#endinput
#endif
#define _DRP_FILE_INCLUDE

// This is a simple vault system, for things that don't need to be saved
// via SQL

#include <amxmodx>
#include <DRP/DRPCore>

stock g_Vault
stock g_Data[256]

// Call this in `plugin_init` ONLY
// This must be called in the plugin, before usage.
stock DRP_VInit()
{
	new VaultFile[128]
	DRP_GetConfigsDir(VaultFile,127);
	
	if(!dir_exists(VaultFile))
		return DRP_ThrowError(1,"Unable to Open DRPVault Dir (%s)",VaultFile);
	
	add(VaultFile,127,"/DRPTxtData.vault");
	if(!file_exists(VaultFile))
		write_file(VaultFile,"");
	
	g_Vault = fopen(VaultFile,"t+");
	
	return g_Vault ? SUCCEEDED : FAILED
}
	

stock DRP_VLoadKey(const Key[],Data,Len)
{
	if(!g_Vault)
		return FAILED
}