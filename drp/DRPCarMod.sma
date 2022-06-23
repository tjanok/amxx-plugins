#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <engine>
#include <sqlx>
#include <DRP/DRPCore>
#include <DRP/DRPChat>
#include <cellarray>

// Upgrades
#define UPGRADE_NOS (1<<0)

#define MAX_CARS 12
#define MAX_SPEED 5000.0
#define MAX_PASSENGERS 4

new g_Query[256]
new Handle:g_sqlHandle

// This is in the order of the array
// DO NOT CHANGE
enum
{
	FUEL = 0,
	LOCKED,
	FINE,
	DAMAGE,
	FLAGS,
	OWNER_AUTHID,
	PASSENGERS,
	CAMERA_OFFSET
}

new const g_CarClassname[] = "DRP_CAR"
new const g_HornSound[] = "OZDRP/carmod/horn.wav"
new const g_EngineIdle[] = "OZDRP/carmod/engine_idle.wav"
new const g_EngineStartup[] = "OZDRP/carmod/engine_startup.wav"

new g_UserDriving[33]
new g_UserPassenger[33]

new Float:g_HornSoundCoolDown[33]
new Float:g_EngineSoundCoolDown[33]

new p_Distance

public DRP_Init()
	g_sqlHandle = DRP_SqlHandle();

// Precaches models
// From the config file
public plugin_precache()
{
	new ConfigFile[256]
	DRP_GetConfigsDir(ConfigFile,255);
	add(ConfigFile,255,"/CarMod.ini");
	
	new pFile = fopen(ConfigFile,"r+");
	if(!pFile)
	{
		DRP_ThrowError(0,"Unable to open carmod config file (%s)",ConfigFile);
		return
	}
	
	new Buffer[256],NumCars
	new File[64],Temp[1]
	
	while(!feof(pFile))
	{
		fgets(pFile,Buffer,255);
		if(!Buffer[0] || Buffer[0] == ';')
			continue
		
		strtok(Buffer,Buffer,255,Temp,1,'-');
		
		remove_quotes(Buffer);
		trim(Buffer)
		
		if(!file_exists(Buffer))
		{
			DRP_ThrowError(0,"Unable to precache car model (%s)",Buffer);
			continue
		}
		
		precache_model(Buffer);
		NumCars++
		
		remove_filepath(Buffer,File,63);
		set_task(5.0,"QueryCar",_,File,63);
	}
	
	fclose(pFile);
	server_print("[DRP-CARMOD] Precached %d Car(s)",NumCars);
	
	// Precaches
	precache_sound(g_HornSound);
	precache_sound(g_EngineIdle);
	precache_sound(g_EngineStartup);
	
	// CVars
	p_Distance = register_cvar("DRP_CMod_Distance","15.0"); // the "distance" before 1% of gas is taken away
}

public QueryCar(const Model[])
{
	format(g_Query,255,"SELECT * FROM `CarMod` WHERE `Model`='%s'",Model);
	SQL_ThreadQuery(g_sqlHandle,"LoadCarsFromSQL",g_Query);
}

public plugin_init()
{
	// Main
	register_plugin("DRP - CarMod","0.1a","Drak");
	
	// Commands
	DRP_AddChat("","CmdSay");
	
	// DRP Events
	DRP_RegisterEvent("Player_UseEntity","Event_UseEntity");
	register_event("DeathMsg","EventDeathMsg","a");
	
	// Entity Thinks / Forwards
	register_think(g_CarClassname,"Event_CarThink");
	register_touch(g_CarClassname,"*","Event_CarTouched");
	
	// SQL
	format(g_Query,255,"CREATE TABLE IF NOT EXISTS `CarMod` (SpawnMe INT(11),Model VARCHAR(36),Origin VARCHAR(24),Angle INT(11),Fuel INT(11),OwnerID VARCHAR(36),AccessFlag VARCHAR(27),Flags VARCHAR(12),Locked INT(11),Fine INT(11),Damage INT(11),PRIMARY KEY(OwnerID))");
	SQL_ThreadQuery(g_sqlHandle,"IgnoreHandle",g_Query);
}

public DRP_Error(const Reason[])
	pause("d");

public DRP_HudDisplay(id,Hud)
{
	if(Hud != HUD_SEC)
		return
	
	if(g_UserPassenger[id])
	{
		new DriverName[33]
		entity_get_string(g_UserPassenger[id],EV_SZ_noise1,DriverName,32);
		
		DRP_AddHudItem(id,HUD_SEC,"\n[CarMod]\nPassenger in Vehicle");
		DRP_AddHudItem(id,HUD_SEC,"Driver: %s",DriverName[0] ? DriverName : "NONE");
	}
	else if(g_UserDriving[id])
	{
		new const Ent = g_UserDriving[id]
		if(!is_valid_ent(Ent))
			return
		
		new Float:Origin[3]
		entity_get_vector(Ent,EV_VEC_velocity,Origin);
		
		DRP_AddHudItem(id,HUD_SEC,"\n[CarMod]\nPassengers: %d/%d",GetCarPassengers(Ent),MAX_PASSENGERS);
		DRP_AddHudItem(id,HUD_SEC,"Fuel: %d/100\nSpeed: %d MPH\nDistance: %f",GetCarCellData(Ent,FUEL),floatround(GetSpeed(Origin) / 5.0),GetCarDriveDistance(g_UserDriving[id]));
		
		// Gas
		new const VehicleFuel = GetCarCellData(Ent,FUEL);
		if(VehicleFuel)
		{
			if(GetSpeed(Origin) > 0.0)
			{
				new const Float:Distance = GetCarDriveDistance(Ent);
				SetCarDrivingDistance(Ent,Distance + 1);
				
				if(Distance >= get_pcvar_float(p_Distance))
				{
					new const Total = VehicleFuel - 1
					if(!Total)
						client_print(id,print_chat,"[DRP] This vehicle has run out of gas.");
					
					SetCarCellData(id,Ent,FUEL,Total);
					SetCarDrivingDistance(Ent,0.0);
				}
			}
		}
		
		// Hack to avoid overlapping sounds from the startup
		if(g_EngineSoundCoolDown[id] == -1 || !VehicleFuel)
			return
		
		new Float:Time = get_gametime();
		if(Time - g_EngineSoundCoolDown[id] < 0.9 && g_EngineSoundCoolDown[id])
			return
		
		g_EngineSoundCoolDown[id] = Time
		emit_sound_wrapper(id,Ent,g_EngineIdle);
	}
}

public DRP_RegisterItems()
{
	DRP_RegisterItem("25 Percent Gas Can","_GasCan","Fills your tank by 25 percent",1,_,_,25);
	DRP_RegisterItem("50 Percent Gas Can","_GasCan","Fills your tank by 50 percent",1,_,_,50);
	DRP_RegisterItem("100 Percent Gas Can","_GasCan","Fills your tank, till it's full",1,_,_,100);
}
/*==================================================================================================================================================*/
// Items
public _GasCan(id,ItemID,Amount)
{
	new Index,Body
	get_user_aiming(id,Index,Body,150);
	
	if(!Index)
	{
		client_print(id,print_chat,"[DRP] You must be looking at a vehicle.");
		return ITEM_KEEP_RETURN
	}
	
	new Classname[8]
	entity_get_string(Index,EV_SZ_classname,Classname,7);
	
	if(!equali(Classname,g_CarClassname))
	{
		client_print(id,print_chat,"[DRP] You must be looking at a vehicle.");
		return ITEM_KEEP_RETURN
	}
	
	new Fuel = GetCarCellData(Index,FUEL);
	if(Fuel >= 100)
	{
		client_print(id,print_chat,"[DRP] This vehicles tank is already full.");
		return ITEM_KEEP_RETURN
	}
	
	new const Total = clamp((Fuel + Amount),0,100);
	SetCarCellData(Index,FUEL,Total);
	
	client_print(id,print_chat,"[DRP] You have filled this vehicles tank up by: %d Percent (Total: %d)",Amount,Total);
	return PLUGIN_HANDLED
}
/*==================================================================================================================================================*/
public client_disconnect(id)
{
	if(g_UserPassenger[id] || g_UserDriving[id])
		GetOut(id,g_UserPassenger[id] ? g_UserPassenger[id] : g_UserDriving[id],g_UserPassenger[id] ? 1 : 0,0);
	
	g_HornSoundCoolDown[id] = 0.0
	g_EngineSoundCoolDown[id] = 0.0
}
/*==================================================================================================================================================*/
// Commands
public CmdSay(id,Args[])
{
	if(!equali(Args,"/car ",5))
		return PLUGIN_CONTINUE
	
	new Command[8]
	parse(Args,Args,1,Command,7);
	
	switch(Command[0])
	{
		case 'm':
		{
			if(g_UserDriving[id])
				CarMenu(id,g_UserDriving[id]);
			else if(g_UserPassenger[id])
				CarMenu(id,g_UserPassenger[id]);
			else
			{
				new Index,Body
				get_user_aiming(id,Index,Body,150);
				
				if(!Index)
				{
					client_print(id,print_chat,"[DRP] You must be looking at a vehicle.");
					return PLUGIN_HANDLED
				}
				
				entity_get_string(Index,EV_SZ_classname,Command,7);
				if(!equali(Command,g_CarClassname))
				{
					client_print(id,print_chat,"[DRP] You must be looking at a vehicle.");
					return PLUGIN_HANDLED
				}
				
				CarMenu(id,Index);
				return PLUGIN_HANDLED
			}
		}
		case 'h':
		{
			if(!g_UserDriving[id])
				return PLUGIN_HANDLED
			
			new Float:Time = get_gametime();
			if(Time - g_HornSoundCoolDown[id] < 3.0 && g_HornSoundCoolDown[id])
				return PLUGIN_HANDLED
			
			emit_sound_wrapper(id,g_UserDriving[id],g_HornSound);
			
			g_HornSoundCoolDown[id] = Time
			return PLUGIN_HANDLED
		}
		case 'g':
		{
			if(!g_UserDriving[id] && !g_UserPassenger[id])
			{
				client_print(id,print_chat,"[DRP] You are not in a vehicle.");
				return PLUGIN_HANDLED
			}
			
			GetOut(id,g_UserDriving[id] ? g_UserDriving[id] : g_UserPassenger[id],g_UserPassenger[id] ? 1 : 0);
			return PLUGIN_HANDLED
		}
		case 's':
		{
			if(!g_UserDriving[id])
				return PLUGIN_HANDLED
			
			new AccessFlags[JOB_ACCESSES + 1]
			entity_get_string(g_UserDriving[id],EV_SZ_message,AccessFlags,JOB_ACCESSES);
			
			if(!(read_flags(AccessFlags) & DRP_GetCopAccess()))
			{
				client_print(id,print_chat,"[DRP] This vehicle does not have a siren.");
				return PLUGIN_HANDLED
			}
			
			return PLUGIN_HANDLED
		}
	}
	
	return PLUGIN_HANDLED
}
/*==================================================================================================================================================*/
// Entity / Player Think
public client_PreThink(id)
{
	if(!g_UserDriving[id] || !is_user_alive(id))
		return
	
	static Ent,Button,onGround,Float:Speed
	Ent = g_UserDriving[id]
	
	if(!GetCarCellData(Ent,FUEL))
		return
	
	Button = entity_get_int(id,EV_INT_button);
	onGround = (entity_get_int(Ent,EV_INT_flags) & FL_ONGROUND)
	
	if(!onGround)
		return
	
	static Float:Angles[3],Float:Velo[3]
	entity_get_vector(Ent,EV_VEC_velocity,Velo);
	//entity_get_vector(Ent,EV_VEC_angles,Angles);
	Speed = GetSpeed(Velo);
	
	new Float:SetSpeed
	const Float:MaxSpeed = 5000.0
	
	if(Button & IN_FORWARD)
	{
		SetSpeed = Speed + floatsqroot(MaxSpeed / 6 )
		SetSpeed = 500.0
	}
	else if(Button & IN_BACK)
	{
		SetSpeed = Speed + floatsqroot(MaxSpeed / 6 )
		SetSpeed = -500.0
	}
	if(Button & IN_MOVELEFT)// && Speed)
	{
		Angles[1] += 1.5
		entity_set_vector(Ent,EV_VEC_angles,Angles);
	}
	if(Button & IN_MOVERIGHT)// && Speed)
	{
		Angles[1] -= 1.5
		entity_set_vector(Ent,EV_VEC_angles,Angles);
	}
	if(SetSpeed > 0.0 || SetSpeed < 0.0)
		set_speed(Ent,SetSpeed);
}
/*==================================================================================================================================================*/
public Event_CarThink(const Ent)
{
	if(!Ent)
		return PLUGIN_CONTINUE
	
	static Float:Origin[3],Float:Angles[3]
	static Camera
	
	entity_get_vector(Ent,EV_VEC_origin,Origin);
	entity_get_vector(Ent,EV_VEC_angles,Angles);
	
	Camera = entity_get_int(Ent,EV_INT_iuser3);
	Origin[2] += GetCarCellData(Ent,CAMERA_OFFSET);
	
	entity_set_origin(Camera,Origin);
	entity_set_vector(Camera,EV_VEC_angles,Angles);
	
	(IsCarDriving(Ent) && GetCarCellData(Ent,FUEL) >= 1) ?
		entity_set_float(Ent,EV_FL_nextthink,halflife_time() + 0.01) : entity_set_float(Ent,EV_FL_nextthink,halflife_time() + 1.0);
	
	return PLUGIN_HANDLED
}
public Event_CarTouched(const Car,const TouchedObject)
{
	if(!Car || !TouchedObject)
		return PLUGIN_CONTINUE
	
	new const CarOwner = IsCarDriving(Car);
	if(!CarOwner)
		return PLUGIN_CONTINUE
	
	new Float:Velo[3]
	entity_get_vector(TouchedObject,EV_VEC_velocity,Velo);
	Velo[2] += 500.0
	entity_set_vector(TouchedObject,EV_VEC_velocity,Velo);
	
	server_print("TOUCHED: %d",TouchedObject);
}
public Event_UseEntity(const Name[],const Data[])
{
	new id = Data[0],EntID = Data[1]
	new Classname[8]
	
	entity_get_string(EntID,EV_SZ_classname,Classname,7);
	
	if(!equali(Classname,g_CarClassname))
		return PLUGIN_CONTINUE
	
	CarMenu(id,EntID);
	return PLUGIN_HANDLED
}
public EventDeathMsg()
{
	new const id = read_data(2);
	
	if(!id)
		return PLUGIN_HANDLED
	
	client_disconnect(id);
	return PLUGIN_HANDLED
}
/*==================================================================================================================================================*/
// Car Data
// Use one of the ENUM definitons here
GetCarCellData(Ent,enumData)
{
	new Array:CurArray = GetCarArray(Ent);
	if(CurArray == Invalid_Array)
		return -1
	
	return ArrayGetCell(CurArray,enumData);
}
GetCarOwnerAuthID(Ent,String[],Len)
{
	new Array:CurArray = GetCarArray(Ent);
	if(CurArray == Invalid_Array)
		return -1
	
	ArrayGetString(CurArray,OWNER_AUTHID,String,Len);
	return SUCCEEDED
}
Array:GetCarArray(const Ent)
{
	new Array:Check = Array:entity_get_int(Ent,EV_INT_iuser2);
	return (Check == Invalid_Array) ? Invalid_Array : Check
}

// DON'T USE THIS TO SET PASSENGERS
// if setting "flags" flagmode is:
// 1: add to current flags
// 2: remove flag
// 3: replace all flags with this one
SetCarCellData(Ent,enumData,Value,FlagMode=0)
{
	new Array:CurArray = GetCarArray(Ent);
	if(CurArray == Invalid_Array)
		return -1
	
	static AuthID[36]
	GetCarOwnerAuthID(Ent,AuthID,35);
	
	new szFlags[12]
	if(FlagMode)
	{
		switch(FlagMode)
		{
			case 1..2:
			{
				new Flags = GetCarCellData(Ent,FLAGS);
				
				if(FlagMode == 2)
					Flags = (Flags & ~Value)
				else
					Flags |= Value
				
				ArraySetCell(CurArray,FLAGS,Flags);
				DRP_IntToAccess(Flags,szFlags,11);
			}
			case 3:
			{
				ArraySetCell(CurArray,FLAGS,Value);
				DRP_IntToAccess(Value,szFlags,11)
			}
		}
	}
	
	switch(enumData)
	{
		case FUEL:
		{
			new const Total = clamp(Value,0,100);
			Value = Total
			
			formatex(g_Query,255,"UPDATE `CarMod` SET `Fuel`='%d' WHERE `OwnerID`='%s'",Value,AuthID);
		}
		case LOCKED: formatex(g_Query,255,"UPDATE `CarMod` SET `Locked`='%d' WHERE `OwnerID`='%s'",Value,AuthID);
		case DAMAGE: formatex(g_Query,255,"UPDATE `CarMod` SET `Damage`='%d' WHERE `OwnerID`='%s'",Value,AuthID);
		case FLAGS: formatex(g_Query,255,"UPDATE `CarMod` SET `Flags`='%s' WHERE `OwnerID`='%s'",szFlags,AuthID);
		case FINE: formatex(g_Query,255,"UPDATE `CarMod` SET `Fine`='%d' WHERE `OwnerID`='%s'",Value,AuthID);
	}
	
	if(!FlagMode)
		ArraySetCell(CurArray,enumData,Value);
	
	SQL_ThreadQuery(g_sqlHandle,"IgnoreHandle",g_Query);
	return PLUGIN_HANDLED
}
SetCarPassengers(CarEnt,Num)
{
	new Array:CurArray = GetCarArray(CarEnt);
	if(CurArray == Invalid_Array)
		return -1
	
	return ArraySetCell(CurArray,PASSENGERS,Num);
}
GetCarPassengers(CarEnt)
{
	new Array:CurArray = GetCarArray(CarEnt);
	if(CurArray == Invalid_Array)
		return -1
	
	return ArrayGetCell(CurArray,PASSENGERS);
}
IsCarDriving(const CarEnt)
	return (entity_get_int(CarEnt,EV_INT_iuser1)) ? entity_get_edict(CarEnt,EV_ENT_owner) : 0
Float:GetCarDriveDistance(const CarEnt)
	return (entity_get_float(CarEnt,EV_FL_fuser2))
Float:SetCarDrivingDistance(const CarEnt,const Float:Value)
	return (entity_set_float(CarEnt,EV_FL_fuser2,Value))
/*==================================================================================================================================================*/
// This only creates the entity and returns a newly created Array (to hold it's data)
// This checks size based on model, and (tries) to make sure it can be spawned in the origin
Array:CreateCar(const Model[],const Float:Angles[3],Float:Origin[3],const AccessFlags[],&ByEnt)
{
	new Ent = create_entity("info_target");
	if(!Ent)
	{
		DRP_ThrowError(0,"[DRP-CARMOD] Unable to create car entity.");
		return Invalid_Array
	}
	ByEnt = Ent
	
	new Camera = create_entity("info_target");
	if(!Camera)
	{
		remove_entity(Ent);
		DRP_ThrowError(0,"[DRP-CARMOD] Unable to create car camera entity.");
		return Invalid_Array
	}
	
	Origin[2] += 10.0
	
	entity_set_int(Camera,EV_INT_solid,SOLID_NOT);
	entity_set_int(Camera,EV_INT_movetype,MOVETYPE_NOCLIP);
	
	entity_set_model(Camera,"sprites/glow01.spr");
	//entity_set_int(Camera,EV_INT_flags,(entity_get_int(Camera,EV_INT_flags) & EF_NODRAW))

	// Max String Len = 36 (AuthID)
	new Array:CurArray = ArrayCreate(36);
	entity_set_string(Ent,EV_SZ_classname,g_CarClassname);
	entity_set_model(Ent,Model);
	
	if(AccessFlags[0])
		entity_set_string(Ent,EV_SZ_message,AccessFlags);
	
	// As Hawk552 said. Apperently GoldSrc doesn't support a rotated bounding box
	// Which makes sense, since everything in the game is proportioned (all equally square)
	// So make a even square, that will pretty much me enough for any average sized car.
	
	entity_set_size(Ent,Float:{-46.0,-46.0,0.0},Float:{46.0,46.0,46.0});
	
	entity_set_int(Ent,EV_INT_solid,SOLID_BBOX);
	entity_set_int(Ent,EV_INT_movetype,MOVETYPE_PUSHSTEP);
	
	entity_set_int(Ent,EV_INT_iuser2,_:CurArray);
	entity_set_int(Ent,EV_INT_iuser3,Camera);
	
	entity_set_float(Ent,EV_FL_friction,0.1);
	entity_set_float(Ent,EV_FL_nextthink,halflife_time() + 1.0);
	entity_set_vector(Ent,EV_VEC_angles,Angles);
	entity_set_origin(Ent,Origin);
	
	// Debug
	RenderBox(Ent);
	return Array:CurArray
}
public RenderBox(const Ent)
{
	new Float:Origin[3],Float:Mins[3],Float:Maxs[3]
	entity_get_vector(Ent,EV_VEC_origin,Origin);
	
	entity_get_vector(Ent,EV_VEC_absmax,Maxs);
	entity_get_vector(Ent,EV_VEC_absmin,Mins);
	
	message_begin(MSG_BROADCAST,SVC_TEMPENTITY);
	write_byte(TE_BOX);
	
	write_coord(floatround(Mins[0]));
	write_coord(floatround(Mins[1]));
	write_coord(floatround(Mins[2]));
	
	write_coord(floatround(Maxs[0]));
	write_coord(floatround(Maxs[1]));
	write_coord(floatround(Maxs[2]));

	write_short(15);
	
	write_byte(10);
	write_byte(100);
	write_byte(150);
	
	message_end();
	
	set_task(1.0,"RenderBox",Ent);
}
/*==================================================================================================================================================*/
CarMenu(id,CarEnt)
{
	new Menu,Info[24]
	new bool:DriverAccess = HasAccess(id,CarEnt);
	
	if((DriverAccess && IsCarDriving(CarEnt) && g_UserDriving[id] != CarEnt) || !DriverAccess)
	{
		Menu = menu_create("Passenger Car Menu","_CarMenu");
		formatex(Info,23,"%d-1",CarEnt);
		
		g_UserPassenger[id] ? 
			menu_additem(Menu,"Get out",Info) : menu_additem(Menu,"Enter",Info);
			
		if(DriverAccess)
			menu_addtext(Menu,"^nSomebody is currently driving^nYou may enter only as a^npassenger",0);
		
		menu_display(id,Menu);
		return PLUGIN_HANDLED
	}
	
	new Upgrades[33],Flags = GetCarCellData(CarEnt,FLAGS),Locked = GetCarCellData(CarEnt,LOCKED);
	formatex(Info,23,"%d-0",CarEnt);
	
	if(Flags & UPGRADE_NOS)
		add(Upgrades,32,"NOS^n");
	
	Menu = menu_create("Car Menu","_CarMenu");
	
	g_UserDriving[id] ? 
		menu_additem(Menu,"Get out",Info) : menu_additem(Menu,"Enter",Info);
	
	menu_additem(Menu,Locked ? "Un-Lock" : "Lock",Info);
	menu_additem(Menu,"Help");
	
	formatex(g_Query,255,"^nGas: %d / 100^nDamage: %d / 100^nPassengers: %d / %d^nFine: $%d^nLocked: %s^n^nUpgrades:^n%s",
	GetCarCellData(CarEnt,FUEL),GetCarCellData(CarEnt,DAMAGE),GetCarCellData(CarEnt,PASSENGERS),MAX_PASSENGERS,GetCarCellData(CarEnt,FINE),Locked ? "Yes" : "No",Upgrades[0] ? Upgrades : "NONE");
	
	menu_addtext(Menu,g_Query,0);
	menu_display(id,Menu);
	
	return PLUGIN_HANDLED
}

GetIn(id,const EntID,IsPassenger=0)
{
	if(g_UserDriving[id] || g_UserPassenger[id])
		return PLUGIN_HANDLED
	
	new Float:cOrigin[3],Float:pOrigin[3]
	
	entity_get_vector(id,EV_VEC_origin,pOrigin);
	entity_get_vector(EntID,EV_VEC_origin,cOrigin);
	
	if(get_distance_f(cOrigin,pOrigin) > 100.0)
	{
		client_print(id,print_chat,"[DRP] You have moved to far from the car.");
		return PLUGIN_HANDLED
	}
	
	new Camera = entity_get_int(EntID,EV_INT_iuser3);
	if(!Camera)
	{
		client_print(id,print_chat,"[DRP] There was a problem entering the car; please contact an administrator");
		return PLUGIN_HANDLED
	}
	
	if(IsPassenger)
	{
		new Passengers = GetCarPassengers(EntID);
		
		if(Passengers >= MAX_PASSENGERS)
		{
			client_print(id,print_chat,"[DRP] There is already a max of %d passengers in this vehicle.",MAX_PASSENGERS);
			return PLUGIN_HANDLED
		}
		if(GetCarCellData(EntID,LOCKED))
		{
			client_print(id,print_chat,"[DRP] This car is currently locked.");
			return PLUGIN_HANDLED
		}
		
		SetPlayerOutside(id);
		new CarOwner = IsCarDriving(EntID);
		
		g_UserPassenger[id] = EntID
		SetCarPassengers(EntID,Passengers + 1);
		
		client_print(id,print_chat,"[DRP] You enter the vehicle%s",CarOwner ? "." : "; there is nobody currently driving.");
		
		if(CarOwner)
		{
			new Name[33]
			get_user_name(id,Name,32);
			client_print(CarOwner,print_chat,"[DRP] %s has gotten into your vehicle.",Name);
		}
		
		attach_view(id,Camera);
		
		return PLUGIN_HANDLED
	}
	
	new Fuel = GetCarCellData(EntID,FUEL);
	if(!Fuel)
		client_print(id,print_chat,"[DRP] This vehicle is out of gas.");
	
	g_UserDriving[id] = EntID
	attach_view(id,Camera);
	
	SetPlayerOutside(id);
	
	// tell the car we want to drive it.
	entity_set_int(EntID,EV_INT_iuser1,1);
	
	new Name[33]
	get_user_name(id,Name,32);
	
	entity_set_string(EntID,EV_SZ_noise1,Name);
	entity_set_edict(EntID,EV_ENT_owner,id);
	
	if(Fuel)
	{
		emit_sound_wrapper(id,EntID,g_EngineStartup);
		g_EngineSoundCoolDown[id] = -1.0
		set_task(2.5,"ClearCoolDown",id);
	}
	
	return PLUGIN_HANDLED
}
public ClearCoolDown(const id)
	g_EngineSoundCoolDown[id] = 0.0

GetOut(id,const EntID,IsPassenger=0,SendMessages=1)
{
	new Float:cOrigin[3],num
	entity_get_vector(EntID,EV_VEC_origin,cOrigin);
	
	FindEmptyLoc(EntID,cOrigin,num,100.0);
	cOrigin[2] += 100.0
	
	if(IsPassenger)
	{
		new CarOwner = entity_get_edict(g_UserPassenger[id],EV_ENT_owner);
		g_UserPassenger[id] = 0
		
		if(SendMessages && CarOwner)
		{
			if(is_user_alive(CarOwner))
			{
				new plName[33]
				get_user_name(id,plName,32);
				client_print(CarOwner,print_chat,"[DRP] %s has gotten out of your car.",plName);
			}
		}
		
		g_UserPassenger[id] = 0
		
		if(SendMessages)
			client_print(id,print_chat,"[DRP] You have gotten out of the car.");
		
		SetCarPassengers(EntID,GetCarPassengers(EntID) - 1);
		
		attach_view(id,id);
		ReturnPlayer(id,cOrigin);
		
		return PLUGIN_HANDLED
	}
	
	g_UserDriving[id] = 0
	
	attach_view(id,id);
	ReturnPlayer(id,cOrigin);
	
	entity_set_string(EntID,EV_SZ_noise1,"");
	entity_set_edict(EntID,EV_ENT_owner,0);
	entity_set_int(EntID,EV_INT_iuser1,0);
	
	SetCarDrivingDistance(EntID,0.0);
	
	new AuthID[36]
	GetCarOwnerAuthID(EntID,AuthID,35);
	
	new sqlOrigin[33],Float:Angles[3]
	entity_get_vector(EntID,EV_VEC_origin,cOrigin);
	entity_get_vector(EntID,EV_VEC_angles,Angles);
	
	formatex(sqlOrigin,32,"%d %d %d",floatround(cOrigin[0]),floatround(cOrigin[1]),floatround(cOrigin[2]));
	formatex(g_Query,255,"UPDATE `carmod` SET `Origin`='%s',`Angle`='%d' WHERE `OwnerID`='%s'",sqlOrigin,floatround(Angles[1]),AuthID);
	
	SQL_ThreadQuery(g_sqlHandle,"IgnoreHandle",g_Query);
	return PLUGIN_HANDLED
}

public _CarMenu(id,Menu,Item)
{
	if(Item == MENU_EXIT)
	{
		menu_destroy(Menu);
		return PLUGIN_HANDLED
	}
	
	new szEntID[12],szPassenger[12],Info[24],Temp
	menu_item_getinfo(Menu,Item,Temp,Info,23,_,_,Temp);
	menu_destroy(Menu);
	
	if(!is_user_alive(id))
		return PLUGIN_HANDLED
	
	strtok(Info,szEntID,11,szPassenger,11,'-',1);
	
	new EntID = str_to_num(szEntID);
	if(!is_valid_ent(EntID))
		return PLUGIN_HANDLED
	
	new Passenger = str_to_num(szPassenger);
	
	switch(Item)
	{
		case 0:
		{
			if(g_UserDriving[id] || g_UserPassenger[id])
			{
				GetOut(id,EntID,g_UserPassenger[id] ? 1 : 0);
				return PLUGIN_HANDLED
			}
			
			GetIn(id,EntID,Passenger);
			return PLUGIN_HANDLED
		}
		case 1:
		{
			new Locked = GetCarCellData(EntID,LOCKED)
			Locked = !Locked
			
			SetCarCellData(EntID,LOCKED,Locked,0);
			
			client_print(id,print_chat,"[DRP] You have %slocked your car.",Locked ? "" : "un");
			return PLUGIN_HANDLED
		}
	}
	return PLUGIN_HANDLED
}
/*==================================================================================================================================================*/
// SQL
public LoadCarsFromSQL(FailState,Handle:Query,const Error[],Errcode,const Data[],DataSize)
{
	if(FailState != TQUERY_SUCCESS)
		return DRP_ThrowError(0,"Error in CarMod Query. (%s)",Error ? Error : "UNKNOWN");
	
	if(!SQL_NumResults(Query))
		return PLUGIN_CONTINUE
	
	new Model[128],Temp[65],Cache[3][12],Float:vAngles[3],Float:Origin[3]
	new AccessFlags[JOB_ACCESSES + 1]
	new Ent
	
	while(SQL_MoreResults(Query))
	{
		if(!SQL_ReadResult(Query,0))
		{
			SQL_NextRow(Query);
			continue
		}
		
		SQL_ReadResult(Query,1,Model,35);
		format(Model,127,"models/OZDRP/Cars/%s",Model);
		SQL_ReadResult(Query,2,Temp,64);
		
		if(!Temp[0])
		{
			DRP_ThrowError(0,"[DRP-CARMOD] Null Origin. Skipping car spawn. DEBUG: (Model: %s)",Model);
			SQL_NextRow(Query); continue;
		}
		
		parse(Temp,Cache[0],11,Cache[1],11,Cache[2],11);
		
		for(new Count;Count < 3;Count++)
			Origin[Count] = str_to_float(Cache[Count]);
		
		SQL_ReadResult(Query,3,vAngles[1]);
		SQL_ReadResult(Query,6,AccessFlags,JOB_ACCESSES);
		
		new Array:CurArray = CreateCar(Model,vAngles,Origin,AccessFlags,Ent);
		
		if(CurArray == Invalid_Array)		
		{
			DRP_ThrowError(0,"[DRP-CARMOD] Error creating car. Skipping car spawn. DEBUG: (Model: %s)",Model);
			SQL_NextRow(Query); continue;
		}
		
		ArrayPushCell(CurArray,SQL_ReadResult(Query,4)); // FUEL
		ArrayPushCell(CurArray,SQL_ReadResult(Query,8)); // LOCKED
		ArrayPushCell(CurArray,SQL_ReadResult(Query,9)); // FINE
		ArrayPushCell(CurArray,SQL_ReadResult(Query,10)); // DAMAGE
		
		SQL_ReadResult(Query,7,Temp,64);
		ArrayPushCell(CurArray,read_flags(Temp)); // FLAGS
		
		SQL_ReadResult(Query,5,Temp,64);
		ArrayPushString(CurArray,Temp); // OWNER
		
		// Hack Hack
		// Drak n Spanky's delorean
		if(containi(Model,"car_drp_dalorean.mdl") != -1)
		{
			if(equali(Temp,"STEAM_0:0:2483037"))
				entity_set_int(Ent,EV_INT_skin,4);
			else if(equali(Temp,"STEAM_0:0:5932780"))
				entity_set_int(Ent,EV_INT_skin,5);
		}
		
		ArrayPushCell(CurArray,0); // PASSENGERS
		ArrayPushCell(CurArray,FindModelOffset(Model))
		
		SQL_NextRow(Query);
	}
	return PLUGIN_CONTINUE
}
public IgnoreHandle(FailState,Handle:Query,const Error[],Errcode,const Data[],DataSize) 
{
	if(FailState != TQUERY_SUCCESS)
		DRP_ThrowError(0,"Error in CarMod Query. (%s)",Error ? Error : "UNKNOWN");
}
/*==================================================================================================================================================*/
// Extra Stocks from "CHR_Engine.inc"
Float:GetSpeed(const Float:Vector[3])
	return floatsqroot(Vector[0] * Vector[0] + Vector[1] * Vector[1])

set_speed(const ent,const Float:speed)
{
	if(!ent)
		return 0
	
	static Float:vangle[3]
	entity_get_vector(ent,EV_VEC_angles,vangle);
	static Float:new_velo[3]

	entity_get_vector(ent,EV_VEC_velocity,new_velo);
	angle_vector(vangle,1,new_velo);
	
	if(GetSpeed(new_velo) >= MAX_SPEED)
	{
		server_print("stopped");
		return 0
	}

	new Float:y
	y = new_velo[0]*new_velo[0] + new_velo[1]*new_velo[1]

	new Float:x
	if(y) x = floatsqroot(speed*speed / y)

	new_velo[0] *= x
	new_velo[1] *= x

	if(speed<0.0)
	{
		new_velo[0] *= -1
		new_velo[1] *= -1
	}
	
	entity_set_vector(ent,EV_VEC_velocity,new_velo);
	return 1;
}

SetPlayerOutside(id)
{
	if(!is_user_alive(id))
		return
	
	entity_set_int(id,EV_INT_flags,entity_get_int(id,EV_INT_flags) & EF_NODRAW);
	entity_set_float(id,EV_FL_takedamage,DAMAGE_NO);
	entity_set_vector(id,EV_VEC_origin,Float:{4095.0,4095.0,4095.0});
}
ReturnPlayer(id,const Float:Origin[3])
{
	entity_set_int(id,EV_INT_flags,entity_get_int(id,EV_INT_flags) & ~EF_NODRAW);
	entity_set_float(id,EV_FL_takedamage,DAMAGE_YES);
	entity_set_vector(id,EV_VEC_origin,Origin);
}

// Hawk
FindEmptyLoc(id,Float:Origin[3],&Num,const Float:Radius)
{
	if(Num++ > 50)
		return FAILED
	
	static Float:pOrigin[3]
	entity_get_vector(id,EV_VEC_origin,pOrigin);
	
	for(new Count;Count < 2;Count++)
		pOrigin[Count] += random_float(-Radius,Radius);
	
	if(PointContents(pOrigin) != CONTENTS_EMPTY && PointContents(pOrigin) != CONTENTS_SKY)
		return FindEmptyLoc(id,Origin,Num,Radius);
	
	Origin = pOrigin
    return PLUGIN_HANDLED
}

// Opens the file, and finds the offset for the given model
// This shouldn't be used anytime other than the startup (i'm sure it lags)
FindModelOffset(const Model[])
{
	new ConfigFile[256]
	DRP_GetConfigsDir(ConfigFile,255);
	add(ConfigFile,255,"/CarMod.ini");
	
	new pFile = fopen(ConfigFile,"r+");
	if(!pFile)
	{
		DRP_ThrowError(0,"Unable to open carmod config file (%s)",ConfigFile);
		return FAILED
	}
	
	new Buffer[256],szOffset[12]
	new Offset
	
	while(!feof(pFile))
	{
		fgets(pFile,Buffer,255);
		if(!Buffer[0] || Buffer[0] == ';')
			continue
		
		strtok(Buffer,Buffer,255,szOffset,11,'-');
		
		remove_quotes(Buffer);
		trim(Buffer);
		remove_quotes(szOffset);
		trim(szOffset);
		
		if(!equali(Buffer,Model))
			continue
		
		Offset = str_to_num(szOffset);
		break;
	}
	
	fclose(pFile);
	return (Offset >= 1) ? Offset : FAILED
}

emit_sound_wrapper(const id,const CarEnt,const Sound[],Local=1)
{
	if(Local)
		client_cmd(id,"spk ^"%s^"",Sound);
	
	emit_sound(CarEnt,CHAN_AUTO,Sound,0.8,ATTN_NORM,0,PITCH_NORM);
}

bool:HasAccess(const id,const Ent)
{
	new AuthID[36]
	get_user_authid(id,AuthID,35);
	
	new CarAuthID[36]
	GetCarOwnerAuthID(Ent,CarAuthID,35);
	
	new AccessFlags[JOB_ACCESSES + 1]
	entity_get_string(Ent,EV_SZ_noise1,AccessFlags,JOB_ACCESSES);
	
	if(equali(AuthID,CarAuthID) || read_flags(AuthID) & DRP_GetUserAccess(id))
		return true
	
	return false
}