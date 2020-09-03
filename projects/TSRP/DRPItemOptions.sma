// DRPItemOptions.sma
// --------------------------------
// Author: Drak

#include <amxmodx>
#include <DRP/DRPCore>

new Handle:g_SqlHandle
new g_Query[256]

public DRP_Init()
{
	// Main
	register_plugin("DRP - Item Options","0.1a","Drak");
	
	// SQL
	g_SqlHandle = DRP_SqlHandle();
	
	format(g_Query,255,"CREATE TABLE IF NOT EXIST