#include <amxmodx>
#include <DRP/drp_include>

#define PLUGIN	"DPRP User Trade"
#define AUTHOR	"Drak"
#define VERSION	"0.1a"

public plugin_precache()
{
}

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	// Commands
	DRP_RegisterCmd("say !trade"
}

public CmdTrade()
{
}