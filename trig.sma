#include <amxmodx>
#include <fakemeta>

public plugin_init() {
    register_plugin("test","0", "noone")
    
    register_clcmd("say /some_entity", "test");
    
}
public test(id) {
    
    some_entity(id,6);
    
}

public some_entity(id,numofents) {
    
    for(new i = 1; i <= numofents; i++) {
        
        new Float:radius = 50.0, Float:angle = float(i * 360/numofents);
        
        
        
    
        new ent = engfunc(EngFunc_CreateNamedEntity,engfunc(EngFunc_AllocString, "info_target"));
        
    
        
        
    
        npc_circle(id,ent,radius,angle);
    
        engfunc(EngFunc_SetModel,ent,"models/player.mdl");
    }
    
    
}

public npc_circle(id,ent,Float:radius, Float:angle) {
    
    new Float:offset[3],Float:origin[3];
    
    offset[0] = radius * floatcos(angle,degrees);
    offset[1] = radius * floatsin(angle,degrees);
    
    get_offset_origin(id,offset,origin);
    
    set_pev(ent,pev_origin,origin);
    
    return 1;
}
//This is taken from chr_engine.inc, which I highly recommend people to use


stock get_offset_origin(ent,const Float:offset[3],Float:origin[3])
{
    if(!pev_valid(ent))
        return 0;
    
    new Float:angle[3]
    pev(ent,pev_origin,origin)
    pev(ent,pev_angles,angle)
    
    origin[0] += floatcos(angle[1],degrees) * offset[0]
    origin[1] += floatsin(angle[1],degrees) * offset[0]
    
    origin[2] += floatsin(angle[0],degrees) * offset[0]
    origin[0] += floatcos(angle[0],degrees) * offset[0]
    
    origin[1] += floatcos(angle[1],degrees) * offset[1]
    origin[0] -= floatsin(angle[1],degrees) * offset[1]
    
    origin[2] += floatsin(angle[2],degrees) * offset[1]
    origin[1] += floatcos(angle[2],degrees) * offset[1]
    
    origin[2] += floatcos(angle[2],degrees) * offset[2]
    origin[1] -= floatsin(angle[2],degrees) * offset[2]
    
    origin[2] += floatcos(angle[0],degrees) * offset[2]
    origin[0] -= floatsin(angle[0],degrees) * offset[2]
    
    origin[0] -= offset[0]
    origin[1] -= offset[1]
    origin[2] -= offset[2]
    
    return 1;
}