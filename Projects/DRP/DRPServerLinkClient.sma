#include <amxmodx>
#include <sockets>

// Connection
new const g_szConnectionIP[] = "" // IP of the DRP server
new const g_szConnectionPort = 50

new g_MainSocket
new g_MainError
new g_MainData[256]

// Using ARP by default
#define USING_DRP

#ifdef USING_DRP
#include <DRP/DRPCore>
#else
#include <ARPCore>
#endif

public plugin_init()
{
	// Main
	register_plugin("DRP Server Linking","0.1a","Drak");
	
	// Connect to DRP
	g_MainSocket = socket_open(g_szConnectionIP,g_szConnectionPort,SOCKET_UDP,g_MainError);
	if(g_MainError || !g_MainSocket)
	{
		server_print("[DRP SLink] Unable to open socket. Error #%d (Pausing)",g_MainError);
		pause("d");
	}
	set_task(1.0,"CheckReply");
}

#ifdef USING_DRP
public DRP_HudDisplay(id,Hud)
{
}
#else
public ARP_HudDisplay(const Name[],const Data[],const Len)
{
}
#endif

// Returns 1 if replyed "okay" returns  -1 if returned nothing
public CheckReply()
{
}

//#ifdef USING_DRP