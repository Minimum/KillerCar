#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <fakemeta_stocks>
#include <fakemeta_util>
#include <engine>
#include <hamsandwich>
#include <xs>
#include <gabionkernel3>
#include <fun>

#define VERSION "3"

#define CARMODEL "models/gabion/killercar/van1.mdl"

#define MUSICSOUND "gabion/mus/inception2.wav"
#define SURPRISEDSOUND "gabion/clip/doakes_surprise.wav"
#define LASERSOUND "gabion/wep/LaserCharge.wav"
#define JUMPSOUND "gabion/sfx/jump.wav"
#define PRIXSOUND "gabion/sfx/98grandprix.wav"
#define JUSTSOUND "gabion/vo/shia_just.wav"
#define DOITSOUND "gabion/vo/shia_doit.wav"
#define IMPOSSIBLESOUND "gabion/vo/shia_impossible.wav"
#define SLVSCREAM "gabion/vo/slv_scream.wav"

#define LASERSPRITE "sprites/laserbeam.spr"
#define EXPLODESPRITE "sprites/explode1.spr"

#define MUSICLEN 11.0
#define PRIXLEN 35.56

#define LASERRECURSIONLIMIT 10

#define CARCLASSNAME "killer_car"

enum
{
	CAR_DISABLED = 0,
	CAR_CHASE,
	CAR_CONTROL,
	CAR_WEEPING,
	CAR_LASER,
	CAR_SHIA
};

enum
{
	LASER_WEAK = 0,
	LASER_STRONG,
	LASER_FIRE
};

new const Float:CARSIZEMIN[3] = {-164.0, -58.0, 20.0};
new const Float:CARSIZEMAX[3] = {130.0, 54.0, 140.0};

new const Float:CARLASERFORWARD = 130.0;
new const Float:CARLASERLEFT = 40.0;
new const Float:CARLASERRIGHT = -37.0;
new const Float:CARLASERVERTICAL = 41.0;

new const Float:CARFRONTTOP = 85.0;
new const Float:CARFRONTBOTTOM = 130.0;

new cv_carSpeed;			// carspeed				- [Float] The car's top speed in units per second.
new cv_carAcceleration;		// carmovement			- [Float] The car's acceleration in units per second.
new cv_carRate;				// carrate				- [Float] How many FPS the car thinks at.
new cv_carLaserRate;		// carlaserrate			- [Float] How many seconds the car can fire its laser.
new cv_carExplodeDamage;	// carexplodedamage		- [Int]	  How much damage car explosions do.
new cv_carDebug;			// cardebug				- [Bool]  Turns debug messages on or off.
new cv_carWeaponName

new cv_carSndChase			// carsndchase			- [Bool]  Turns the chase music on or off.
new cv_carSndSurprise		// carsndsurprise		- [Bool]  Turns the surprise sound on or off.
new cv_carSndPrix			// carsndprix			- [Bool]  Turns the Grand Prix sound on or off.

new sv_car = -1;
new sv_carMode;
new sv_carPrevMode;
new sv_carTarget;
new sv_carOwner;
new Float:sv_soundPlay = 0.0;
new Float:sv_prixPlay = 0.0;
new sv_surprised = 0;
new sv_carTeleportEnabled = false;
new sv_carLaserEnabled = false;
new sv_carShiaEnabled = false;
new Float:sv_carLaserTime = 0.0;
new sv_carLaserMode = 0;
new sv_carLaserTarget;
new sv_carLaser[2];
new Float:sv_carLaserLeft[3];
new Float:sv_carLaserRight[3];
new sv_carControlPreset = false;
new Float:sv_carControlVelocity[3];
new sv_gibCount = 160;
new sv_gibSpread = 77;

new Float:cl_useCooldown[33];

new laserSprite;
new explodeSprite;
new fleshGibs;

public plugin_init()
{
	register_plugin("Killer Car", VERSION, "Matthew Ross & Ivan De Dios");
	
	cv_carSpeed = register_cvar("carspeedplayer", "200");
	cv_carAcceleration = register_cvar("carspeedai", "75.0");
	cv_carRate = register_cvar("carrate", "60.0");
	cv_carLaserRate = register_cvar("carlaserrate", "30.0");
	cv_carExplodeDamage = register_cvar("carexplodedamage", "100");
	cv_carDebug = register_cvar("carhuddebug", "0");
	cv_carWeaponName = register_cvar("carweaponname", "Killer Car");
	
	cv_carSndChase = register_cvar("carsndchase", "1");
	cv_carSndSurprise = register_cvar("carsndsurprise", "1");
	cv_carSndPrix = register_cvar("carsndprix", "1");
	
	register_concmd("car_spawn", "cmdSpawnCar");
	register_concmd("car_set", "cmdSetCar");
	register_concmd("car_getid", "cmdGetId");
	register_concmd("car_setlaser", "cmdSetLaser");
	register_concmd("car_testlaser", "cmdTestLaser");
	register_concmd("car_setteleport", "cmdSetTeleport");
	register_concmd("car_setshia", "cmdSetShia");
	register_concmd("car_setgibs", "cmdSetGibs");
	register_concmd("car_setspread", "cmdSetSpread");
	register_concmd("car_testgibs", "cmdTestGibs");
	
	register_forward(FM_Think, "forwardThink");
	register_forward(FM_Touch, "forwardTouch");
	register_forward(FM_Use, "forwardUse");
	
	register_event("DeathMsg","hookDeath","a");
	
	//RegisterHam(Ham_Touch, "player", "forwardTouch");
	
	//register_forward(FM_AddToFullPack, "forwardFullPack");
	
	//EnableHamForward(RegisterHam(Ham_TakeDamage, "player", "hookDamage", 1));
}

public plugin_precache()
{
	precache_model(CARMODEL);
	precache_sound(MUSICSOUND);
	precache_sound(SURPRISEDSOUND);
	precache_sound(LASERSOUND);
	precache_sound(JUMPSOUND);
	precache_sound(PRIXSOUND);
	precache_sound(JUSTSOUND);
	precache_sound(DOITSOUND);
	precache_sound(IMPOSSIBLESOUND);
	precache_sound(SLVSCREAM);
	
	laserSprite = precache_model(LASERSPRITE);
	explodeSprite = precache_model(EXPLODESPRITE);
	fleshGibs = precache_model("models/hgibs.mdl");
}

public plugin_cfg()
{
	server_cmd("exec addons/amxmodx/configs/gabionkernel/killercar.cfg");
}

public gabHudPrint()
{
	if(pev_valid(sv_car) != 0 && get_pcvar_num(cv_carDebug) > 0)
	{
		new Float:origin[3];
		new Float:angles[3];
		new Float:velocity[3];
		new Float:speed;
		
		pev(sv_car, pev_origin, origin);
		pev(sv_car, pev_angles, angles);
		pev(sv_car, pev_velocity, velocity);
		
		speed = floatabs(velocity[0]) + floatabs(velocity[1]) + floatabs(velocity[2]);
		
		static hudFormat1[128];
		static hudFormat2[128];
		static hudFormat3[128];
		
		formatex(hudFormat1, 127, "X:%.2f Y:%.2f Z:%.2f", origin[0], origin[1], origin[2]);
		formatex(hudFormat2, 127, "PI:%.2f YA:%.2f RO:%.2f", angles[0], angles[1], angles[2]);
		formatex(hudFormat3, 127, "VX:%.2f VY:%.2f VZ:%.2f S:%.2f", velocity[0], velocity[1], velocity[2], speed);
		
		for(new x=0; x < 33; x++)
		{
			if(is_user_connected(x))
			{
				hudPrint(x, hudFormat1);
				hudPrint(x, hudFormat2);
				hudPrint(x, hudFormat3);
			}
		}
	}
}

public client_PreThink(id)
{
	new Float:currentTime = get_gametime();
	
	if(cl_useCooldown[id] <= currentTime && sv_car != -1 && pev_valid(sv_car) && (get_user_button(id) & IN_USE) && is_user_alive(id))
	{
		// check range
		new Float:carOrigin[3], Float:clientOrigin[3];
		
		pev(sv_car, pev_origin, carOrigin);
		pev(id, pev_origin, clientOrigin);
		
		if(get_distance_f(carOrigin, clientOrigin) < 200)
		{
			if(sv_carMode == CAR_DISABLED || sv_carMode == CAR_CHASE || sv_carMode == CAR_WEEPING)
			{
				sv_carOwner = id;
				sv_carPrevMode = sv_carMode;
				sv_carMode = CAR_CONTROL;
				
				set_user_health(id, 5000);
				set_user_noclip(id, 1);
				
				cl_useCooldown[id] = currentTime + 2.0;
				
				emit_sound(id, CHAN_AUTO, SLVSCREAM, 1.0, ATTN_NORM, 0, PITCH_NORM);
				
				client_print(0, print_chat, "Irvan's doritos have arrived!");
			}
			else if(sv_carOwner == id)
			{
				sv_carOwner = 0;
				sv_carMode = sv_carPrevMode;
				
				set_user_health(id, 400);
				set_user_noclip(id, 0);
				
				cl_useCooldown[id] = currentTime + 2.0;
				
				client_print(0, print_chat, "Irvan's doritos have fled!");
			}
		}
	}
	
	return PLUGIN_CONTINUE;
}

public forwardThink(ent)
{
	if(ent == sv_car)
	{
		carThink();
	}
	
	return FMRES_IGNORED;
}

public forwardTouch(ent, id)
{
	if(sv_car == ent && is_user_alive(id) && id != sv_carOwner)
	{
		if(sv_carMode == CAR_CONTROL)
		{
			if(is_user_connected(sv_carOwner))
			{
				set_user_frags(sv_carOwner, get_user_frags(sv_carOwner) + 2);
			}
		}
		
		if(pev(id, pev_health) <= 6)
		{
			new killer = (sv_carMode == CAR_CONTROL) ? sv_carOwner : ent;
			new weapon[24];
			
			get_pcvar_string(cv_carWeaponName, weapon, 23);
			
			// Gib player
			fakedamage(id, "KILLER_CAR", 9001.0, 2);
			
			// Death message
			message_begin(MSG_ALL, get_user_msgid("DeathMsg"),{0,0,0},0);
			write_byte(killer);
			write_byte(id);
			write_byte(0);
			write_string(weapon);
			message_end();
			
			new targetOrigin[3];
			
			get_user_origin(id, targetOrigin);
			
			spawnFleshGibs(targetOrigin, sv_gibSpread, sv_gibCount, 150);
		}
		else
		{
			fakedamage(id, "KILLER_CAR", 5.0, 2);
		}
		
		if(sv_surprised == 0)
		{
			playSurprise(sv_carTarget);
			
			sv_surprised = 2;
		}
	}
	
	return PLUGIN_CONTINUE;
}

public forwardUse(id, ent)
{
	if(ent == sv_car && (sv_carMode == CAR_DISABLED || sv_carMode == CAR_CHASE || sv_carMode == CAR_WEEPING))
	{
		
	}
	else if(sv_carMode == CAR_CONTROL && sv_carOwner == id)
	{
		
	}
	
	return PLUGIN_CONTINUE;
}

public hookDeath()
{
	new victim = read_data(2);
	
	if(sv_carMode == CAR_CONTROL && sv_carOwner == victim)
	{
		client_print(0, print_chat, "Irvan's doritos have been defeated!");
		
		sv_carMode = sv_carPrevMode;
		sv_carOwner = 0;
	}
	
	return PLUGIN_CONTINUE;
}

public hookDamage(id, weapon, attacker, Float:damage, bits)
{
	server_print("carDamage called: %i", id)
	if(id == sv_car && pev_valid(id))
	{
		new health;
		pev(id, pev_health, health);
		
		if(float(health) - damage <= 0.0)
		{
			carExplode();
		}
	}
	
	return HAM_HANDLED;
}

public cmdSpawnCar(id)
{
	new origin[3];
	new Float:origin2[3];
	get_user_origin(id,origin,3);
	
	origin2[0] = float(origin[0]);
	origin2[1] = float(origin[1]);
	origin2[2] = float(origin[2]);
	
	if(carSpawn(origin2))
	{
		client_print(id, print_console, "Car successfully spawned!");
	}
	else
	{
		client_print(id, print_console, "Car spawn unsuccessful!");
	}
	
	return PLUGIN_HANDLED;
}

public cmdSetCar(id)
{
	new arg[4];
	new setting = 0;
	
	read_argv(1, arg, 3);
	
	setting = str_to_num(arg);
	
	switch(setting)
	{
		case CAR_DISABLED:
		{
			sv_carMode = CAR_DISABLED;
			sv_carPrevMode = CAR_DISABLED;
		}
		
		case CAR_CHASE:
		{
			sv_carMode = CAR_CHASE;
			sv_carPrevMode = CAR_CHASE;
		}
		
		case CAR_CONTROL:
		{
			sv_carMode = CAR_CONTROL;
			sv_carPrevMode = CAR_CONTROL;
		}
		
		case CAR_WEEPING:
		{
			sv_carMode = CAR_WEEPING;
			sv_carPrevMode = CAR_WEEPING;
		}
		
		default:
		{
			if(id == 0)
			{
				server_print("car_set <mode>^n0 - Disabled^n1 - Chase^n2 - Player Controlled (not done)^n3 - Weeping");
			}
			else
			{
				client_print(id, print_console, "car_set <mode>^n0 - Disabled^n1 - Chase^n2 - Player Controlled (not done)^n3 - Weeping");
			}
			
		}
	}
	
	return PLUGIN_HANDLED;
}

public cmdGetId(id)
{
	client_print(id, print_console, "Car ID: %i", sv_car);
	
	return PLUGIN_HANDLED;
}

public cmdSetTeleport(id)
{
	if(sv_carTeleportEnabled)
	{
		client_print(id, print_chat, "Jumping jacks have been disabled!");
	}
	else
	{
		client_print(0, print_chat, "Jumping jacks have been enabled!");
	}
	
	sv_carTeleportEnabled = !sv_carTeleportEnabled;
	
	return PLUGIN_HANDLED;
}

public cmdSetLaser(id)
{
	if(sv_carLaserEnabled)
	{
		sv_carLaserEnabled = false;
		
		client_print(id, print_chat, "Super duper laser light show has been disabled!");
	}
	else
	{
		sv_carLaserEnabled = true;
		
		client_print(0, print_chat, "Super duper laser light show has been enabled!");
	}
	
	return PLUGIN_HANDLED;
}

public cmdSetShia(id)
{
	if(sv_carShiaEnabled)
	{
		client_print(id, print_chat, "Shia mode has been disabled!");
	}
	else
	{
		client_print(0, print_chat, "Shia mode has been enabled!");
	}
	
	sv_carShiaEnabled = !sv_carShiaEnabled;
	
	return PLUGIN_HANDLED;
}

public cmdSetSpread(id)
{
	new spread;
	new arg[8];
	
	read_argv(1, arg, 7);
	
	spread = str_to_num(arg);
	
	if(spread > 255)
	{
		spread = 255;
	}
	else if(spread < 0)
	{
		spread = 0;
	}
	
	sv_gibSpread = spread;
	
	client_print(0, print_chat, "Spread range has to been set to %i!", spread);
	
	return PLUGIN_HANDLED;
}

public cmdSetGibs(id)
{
	new spread;
	new arg[8];
	
	read_argv(1, arg, 7);
	
	spread = str_to_num(arg);
	
	if(spread > 255)
	{
		spread = 255;
	}
	else if(spread < 0)
	{
		spread = 0;
	}
	
	sv_gibCount = spread;
	
	client_print(0, print_chat, "Spread packets have to been set to %i!", spread);
	
	return PLUGIN_HANDLED;
}

public cmdTestGibs(id)
{
	new origin[3];
	
	get_user_origin(id, origin, 3);
	
	spawnFleshGibs(origin, sv_gibSpread, sv_gibCount, 80);
	
	return PLUGIN_HANDLED;
}

public cmdTestLaser(id)
{
	new Float:origin[3];
	new args[4];
	new mode;
	
	read_argv(1, args, 3);
	mode = str_to_num(args);
	
	switch(mode)
	{
		case 1:
		{
			new iOrigin[3];
			get_user_origin(id, iOrigin, 3);
			
			origin[0] = float(iOrigin[0]);
			origin[1] = float(iOrigin[1]);
			origin[2] = float(iOrigin[2]);
		}
		
		default:
		{
			if(sv_carTarget > 0 && is_user_connected(sv_carTarget) && is_user_alive(sv_carTarget))
			{
				pev(sv_carTarget, pev_origin, origin);
			}
			else
			{
				pev(id, pev_origin, origin);
			}
		}
	}
	
	carLaserInit(origin);
	
	return PLUGIN_HANDLED;
}

public carSpawn(Float:origin[3])
{
	new success = false;
	
	if(pev_valid(sv_car) == 0)
	{
		/*car = create_entity("info_target");
		entity_set_string(car, EV_SZ_classname, CARCLASSNAME);
		entity_set_model(car, CARMODEL);
		entity_set_int(car, EV_INT_solid, SOLID_TRIGGER);
		entity_set_int(car, EV_INT_movetype, MOVETYPE_NOCLIP);
		entity_set_size(car, CARSIZEMIN, CARSIZEMAX);
		entity_set_edict(car, EV_ENT_owner, 0);
		entity_set_float(car, EV_FL_health, 100.0);
		entity_set_float(car, EV_FL_takedamage, DAMAGE_YES);
		entity_set_int(car,EV_INT_effects, EF_DIMLIGHT);
		entity_set_origin(car, origin);
		
		dllfunc(DLLFunc_Spawn, car);
		
		set_pev(car, pev_nextthink, get_gametime() + 0.01);*/
		
		// FM
		
		new car;
		
		car = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))  
		
		set_pev(car, pev_movetype, MOVETYPE_NOCLIP);
		set_pev(car, pev_nextthink, halflife_time() + 0.01);
		
		entity_set_string(car, EV_SZ_classname, CARCLASSNAME);
		engfunc(EngFunc_SetModel, car, CARMODEL);
		set_pev(car, pev_mins, CARSIZEMIN);
		set_pev(car, pev_maxs, CARSIZEMAX);
		set_pev(car, pev_origin, origin);
		set_pev(car, pev_gravity, 0.0);  
		set_pev(car, pev_solid, SOLID_TRIGGER);
		set_pev(car, pev_frame, 0.0);
		set_pev(car, pev_health, 100.0);
		set_pev(car, pev_takedamage, DAMAGE_YES);
		set_pev(car, pev_effects, EF_DIMLIGHT);
		set_pev(car, pev_targetname, "MORNAP_JR");
		
		sv_car = car;
		success = true;
	}
	
	return success;
}

public carDestroy()
{
	if(pev_valid(sv_car) != 0)
	{
		stopPrix();
		
		engfunc(EngFunc_RemoveEntity, sv_car);
	}

	sv_car = -1;
	
	return;
}

public carExplode()
{
	new Float:origin[3];
	pev(sv_car, pev_origin, origin)
	
	explosionAttack(origin, 200, 75);
	
	carDestroy();
	
	return;
}

public carThink()
{	
	new Float:health;
	pev(sv_car, pev_health, health);
	
	if(health > 0)
	{
		switch(sv_carMode)
		{
			case CAR_DISABLED:
			{
				carDisabled();
			}
			
			case CAR_CHASE:
			{
				carChase();
			}
			
			case CAR_CONTROL:
			{
				carControlled();
			}
			
			case CAR_WEEPING:
			{
				carWeeping();
			}
			
			case CAR_LASER:
			{
				carLaser();
			}
			
			case CAR_SHIA:
			{
				carShia();
			}
			
			default:
			{
				server_print("[KillerCar] Unhandled Mode ID!");
			}
		}
		
		playPrix();
		
		set_pev(sv_car, pev_nextthink, get_gametime() + (1.0/get_pcvar_float(cv_carRate)));
	}
	else
	{
		client_print(0, print_chat, "BIG BROWN BOX has left the building!");
		
		if(sv_carMode == CAR_CONTROL)
		{
			user_kill(sv_carOwner);
		}
		
		carExplode();
	}
	
	return;
}

public carDisabled()
{
	new Float:velocity[3];
	
	pev(sv_car, pev_velocity, velocity);
	
	if((velocity[0] + velocity[1] + velocity[2]) <= 0.005)
	{
		velocity[0] = 0.0;
		velocity[1] = 0.0;
		velocity[2] = 0.0;
	}
	else
	{
		velocity[0] *= 0.99;
		velocity[1] *= 0.99;
		velocity[2] *= 0.99;
	}
	
	set_pev(sv_car, pev_velocity, velocity);
	
	if(sv_carPrevMode != CAR_DISABLED)
	{
		for(new x=0; x < 33; x++)
		{
			if(is_user_alive(x))
			{
				sv_carMode = sv_carPrevMode;
			}
		}
	}
	
	return;
}

public carChase()
{	
	new Float:velocity[3];
	new Float:angle[3];
	new Float:origin[3];
	new Float:origin2[3];
	
	if(!is_user_alive(sv_carTarget))
	{
		// Player is dead, find new target.
		sv_carTarget = acquireTarget();
	}
	
	if(sv_carTarget > 0)
	{
		pev(sv_car, pev_velocity, velocity);
		pev(sv_car, pev_origin, origin);
		pev(sv_carTarget, pev_origin, origin2);
		
		xs_vec_sub(origin2, origin, angle);
		
		changeVelocity(velocity, angle);
		
		vector_to_angle(angle, angle);
		
		set_pev(sv_car, pev_angles, angle);
		set_pev(sv_car, pev_velocity, velocity);
		
		playMusic();
	}
	else
	{
		stopMusic();
		
		sv_carMode = CAR_DISABLED;
		sv_carPrevMode = CAR_CHASE;
	}
	
	return;
}

public carWeeping()
{
	new Float:velocity[3];
	new Float:angle[3];
	new Float:origin[3];
	new Float:origin2[3];
	new Float:distance;
	
	if(!is_user_alive(sv_carTarget))
	{
		// Player is dead, find new target.
		sv_carTarget = acquireTarget();
		
		stopMusic();
		
		sv_surprised = 0;
	}
	
	if(sv_carTarget > 0)
	{	
		// Car has a viable target.
		pev(sv_car, pev_origin, origin);
		pev(sv_carTarget, pev_origin, origin2);
		
		distance = get_distance_f(origin, origin2);
		
		new playerEyes[3];
		new Float:eyes[3];
		
		get_user_origin(sv_carTarget, playerEyes, 1);
		
		eyes[0] = float(playerEyes[0]);
		eyes[1] = float(playerEyes[1]);
		eyes[2] = float(playerEyes[2]);
		
		if(targetVisibility(eyes))
		{
			// Car is visible by player.
			velocity[0] = 0.0;
			velocity[1] = 0.0;
			velocity[2] = 0.0;
			
			if(sv_soundPlay != 0.0)
			{
				stopMusic();
			}
			
			if(sv_surprised == 0 && distance <= 350)
			{
				playSurprise(sv_car);
				
				sv_surprised = 1;
			}
			
			if(sv_carLaserEnabled || sv_carTeleportEnabled || sv_carShiaEnabled)
			{
				if(sv_carLaserTime == 0.0)
				{
					sv_carLaserTime = get_gametime();
				}
				else if(get_gametime() >= sv_carLaserTime + get_pcvar_float(cv_carLaserRate))
				{
					// old code
					if(sv_carTeleportEnabled || sv_carShiaEnabled)
					{
						new Float:playerAngle[3];
						pev(sv_carTarget, pev_angles, playerAngle);
						
						if(sv_carLaserEnabled)
						{
							if(random_num(1, 100) % 10 >= 7)
							{
								if(sv_carShiaEnabled)
								{
									carShiaInit();
								}
								else
								{
									carTeleport(eyes, playerAngle);
								}
							}
							else
							{
								carLaserInit(origin2);
							}
						}
						else
						{
							if(sv_carShiaEnabled)
							{
								carShiaInit();
							}
							else
							{
								carTeleport(eyes, playerAngle);
							}
							
						}
					}
					else
					{
						carLaserInit(origin2);
					}
					
				}
			}
		}
		else
		{
			// Car is NOT visible by player.
			pev(sv_car, pev_velocity, velocity);
			
			xs_vec_sub(origin2, origin, angle);
			
			changeVelocity(velocity, angle);
			
			vector_to_angle(angle, angle);
			
			set_pev(sv_car, pev_angles, angle);
			
			playMusic();
			
			if(sv_surprised != 2)
				sv_surprised = 0;
			
			sv_carLaserTime = 0.0;
		}
		
		set_pev(sv_car, pev_velocity, velocity);
	}
	else
	{
		// Car has no target left.
		sv_carMode = CAR_DISABLED;
		sv_carPrevMode = CAR_WEEPING;
	}
	
	return;
}

public carControlled()
{
	// Play Control Sound, Apply Velocity Towards Player Aim
	if(is_user_connected(sv_carOwner) && is_user_alive(sv_carOwner))
	{
		if(get_user_button(sv_carOwner) & IN_DUCK)
		{
			if(sv_carControlPreset)
			{
				new Float:origin[3];
				
				pev(sv_car, pev_origin, origin);
				
				origin[2] += 70.0;
				
				set_pev(sv_carOwner, pev_origin, origin);
				set_pev(sv_carOwner, pev_velocity, sv_carControlVelocity);
				set_pev(sv_car, pev_velocity, sv_carControlVelocity);
			}
			else
			{
				new Float:vec[3], Float:ang[3], Float:velocity[3];
				new Float:origin[3];
				
				pev(sv_carOwner, pev_angles, ang);
				pev(sv_car, pev_origin, origin);
				
				angle_vector(ang, ANGLEVECTOR_FORWARD, vec);
				
				changeVelocity(velocity, vec);
				
				velocity_by_aim(sv_carOwner, get_pcvar_num(cv_carSpeed), velocity);
				
				origin[2] += 70.0;
				
				set_pev(sv_car, pev_velocity, velocity);
				
				set_pev(sv_carOwner, pev_velocity, velocity);
				set_pev(sv_carOwner, pev_origin, origin);
				set_pev(sv_car, pev_angles, ang);
				
				sv_carControlVelocity = velocity;
				sv_carControlPreset = true;
			}
		}
		else
		{
			new Float:vec[3], Float:ang[3], Float:velocity[3];
			new Float:origin[3];
			
			pev(sv_carOwner, pev_angles, ang);
			pev(sv_car, pev_origin, origin);
			
			angle_vector(ang, ANGLEVECTOR_FORWARD, vec);
			
			changeVelocity(velocity, vec);
			
			velocity_by_aim(sv_carOwner, get_pcvar_num(cv_carSpeed), velocity);
			
			origin[2] += 70.0;
			
			set_pev(sv_car, pev_velocity, velocity);
			
			set_pev(sv_carOwner, pev_velocity, velocity);
			set_pev(sv_carOwner, pev_origin, origin);
			set_pev(sv_car, pev_angles, ang);
			
			sv_carControlPreset = false;
		}
		
		playMusic();
	}
	else
	{
		sv_carMode = sv_carPrevMode;
	}
	
	return;
}

public carTeleport(Float:targetOrigin[3], Float:targetAngle[3])
{
	new Float:angle[3];
	new Float:origin[3];
	
	// Play sound
	client_cmd(0, "speak gabion/sfx/jump.wav");
	
	// Reverse player angle
	angle[0] = floatMod(targetAngle[0] + 180.0 + random_float(-45.0, 45.0), 360);
	angle[1] = floatMod(targetAngle[1] + 180.0 + random_float(-45.0, 45.0), 360);
	angle[2] = floatMod(targetAngle[2] + 180.0 + random_float(-45.0, 45.0), 360);
	
	// Convert angle to move vector
	angle_vector(angle, ANGLEVECTOR_FORWARD, origin);
	
	// Apply distance to move vector
	xs_vec_mul_scalar(origin, 500.0, origin);
	
	// Add move vector to player position
	xs_vec_sub(targetOrigin, origin, origin);
	
	// Set car's new position
	set_pev(sv_car, pev_origin, origin);
	
	// Reset camping time
	sv_carLaserTime = 0.0;
	
	return;
}

public carShiaInit()
{
	client_cmd(0, "speak gabion/vo/shia_just.wav");
	
	sv_carLaserTime = get_gametime();
	sv_carPrevMode = sv_carMode;
	sv_carMode = CAR_SHIA;
	
	return;
}

public carShia()
{
	if(get_gametime() < sv_carLaserTime + 1.0)
	{
		return;
	}
	
	new Float:targetAngle[3];
	new Float:targetOrigin[3];
	
	pev(sv_carTarget, pev_angles, targetAngle);
	pev(sv_carTarget, pev_origin, targetOrigin);
	
	new Float:angle[3];
	new Float:origin[3];
	
	// Play sound
	client_cmd(0, "speak gabion/vo/shia_doit.wav");
	
	// Reverse player angle
	angle[0] = floatMod(targetAngle[0] + 180.0 + random_float(-45.0, 45.0), 360);
	angle[1] = floatMod(targetAngle[1] + 180.0 + random_float(-45.0, 45.0), 360);
	angle[2] = floatMod(targetAngle[2] + 180.0 + random_float(-45.0, 45.0), 360);
	
	// Convert angle to move vector
	angle_vector(angle, ANGLEVECTOR_FORWARD, origin);
	
	// Apply distance to move vector
	xs_vec_mul_scalar(origin, 200.0, origin);
	
	// Add move vector to player position
	xs_vec_sub(targetOrigin, origin, origin);
	
	// Set car's new position
	set_pev(sv_car, pev_origin, origin);
	
	// Reset camping time
	sv_carLaserTime = 0.0;
	
	// Set car back to previous mode
	sv_carMode = sv_carPrevMode;
	
	return;
}

public carLaser()
{
	new Float:gameTime = get_gametime();
	
	switch(sv_carLaserMode)
	{
		case LASER_STRONG:
		{
			if(gameTime >= sv_carLaserTime + 4.0)
			{
				// Change to Fire
				new Float:target[3];
				
				pev(sv_carLaserTarget, pev_origin, target);
				
				explosionAttack(target, get_pcvar_num(cv_carExplodeDamage), 75);
				
				laserCleanup();
				
				sv_carLaserMode = LASER_FIRE;
			}
		}
		
		case LASER_FIRE:
		{
			if(gameTime >= sv_carLaserTime + 5.0)
			{
				// Switch to previous mode
				sv_carLaserTime = 0.0;
				sv_carMode = sv_carPrevMode;
				sv_carPrevMode = CAR_LASER;
			}
		}
		
		default:
		{
			if(gameTime >= sv_carLaserTime + 2.9)
			{
				// Change to Strong Laser
				sv_carLaser[0] = laserStrong(sv_carLaser[0], sv_carLaserLeft);
				sv_carLaser[1] = laserStrong(sv_carLaser[1], sv_carLaserRight);
				
				sv_carLaserMode = LASER_STRONG;
			}
		}
	}
}

public carLaserInit(Float:target[3])
{
	new Float:angles[3];
	new Float:origin[3];
	
	new Float:fwd[3];
	new Float:right[3];
	new Float:up[3];
	
	new Float:vec_fwd[3];
	new Float:vec_vert[3];
	
	laserCleanup();
	
	pev(sv_car, pev_origin, origin);
	
	xs_vec_sub(target, origin, angles);
	
	vector_to_angle(angles, angles);
	
	set_pev(sv_car, pev_angles, angles);
	set_pev(sv_car, pev_velocity, {0.0, 0.0, 0.0});
	
	angles[0] *= -1.0;
	
	xs_anglevectors(angles, fwd, right, up);
	
	// Side Vectors
	xs_vec_mul_scalar(fwd, CARLASERFORWARD, vec_fwd);
	xs_vec_mul_scalar(right, CARLASERLEFT, sv_carLaserLeft);
	xs_vec_mul_scalar(right, CARLASERRIGHT, sv_carLaserRight);
	xs_vec_mul_scalar(up, CARLASERVERTICAL, vec_vert);
	
	// Left laser
	xs_vec_add(sv_carLaserLeft, vec_fwd, sv_carLaserLeft);
	xs_vec_add(sv_carLaserLeft, vec_vert, sv_carLaserLeft);
	xs_vec_add(sv_carLaserLeft, origin, sv_carLaserLeft);
	
	// Right laser
	xs_vec_add(sv_carLaserRight, vec_fwd, sv_carLaserRight);
	xs_vec_add(sv_carLaserRight, vec_vert, sv_carLaserRight);
	xs_vec_add(sv_carLaserRight, origin, sv_carLaserRight);
	
	// Find Target Position
	laserFindTarget(sv_carLaserLeft, sv_carLaserRight, target, target, sv_car, 0);
	
	sv_carLaserTarget = create_entity("info_target");
	set_pev(sv_carLaserTarget, pev_origin, target);
	DispatchKeyValue(sv_carLaserTarget,"targetname","carLaserTarget");
	DispatchSpawn(sv_carLaserTarget);
	
	// Create Laser Ents
	sv_carLaser[0] = laserWeak(sv_carLaser[0], sv_carLaserLeft);
	sv_carLaser[1] = laserWeak(sv_carLaser[1], sv_carLaserRight);
	
	// Play Sound
	client_cmd(0, "speak gabion/wep/LaserCharge.wav");
	
	sv_carLaserMode = LASER_WEAK;
	sv_carLaserTime = get_gametime();
	
	sv_carPrevMode = sv_carMode;
	sv_carMode = CAR_LASER;
	
	return;
}

public changeVelocity(Float:velocity[3], const Float:vector[3])
{
	//new Float:speed;
	new Float:acceleration;
	//new Float:limiter;
	new Float:length;
	
	//speed = get_pcvar_float(cv_carSpeed) / 100.0;
	acceleration = get_pcvar_float(cv_carAcceleration) / 100.0;
	
	length = vector_length(vector);
	
	if(length > 0.0)
	{
		velocity[0] = vector[0] * (acceleration / length);
		velocity[1] = vector[1] * (acceleration / length);
		velocity[2] = vector[2] * (acceleration / length);
	}
	
	/*limiter = (velocity[0] + velocity[1] + velocity[2]) / speed;
	
	if(limiter > 1.0)
	{
		velocity[0] /= limiter;
		velocity[1] /= limiter;
		velocity[2] /= limiter;
	}*/
	
	return;
}

public acquireTarget()
{
	new id = 0;
	new Float:origin[3];
	new Float:distance = 0.0;
	new Float:distance2;
	new Float:origin2[3];
	
	pev(sv_car, pev_origin, origin);
	
	for(new player=1; player < 33; player++)
	{
		if(is_user_alive(player))
		{
			pev(player, pev_origin, origin2);
			
			distance2 = get_distance_f(origin, origin2);
			
			if(distance2 < distance || id == 0)
			{
				id = player;
				
				distance = distance2;
			}
		}
	}
	
	return id;
}

public targetVisibility(Float:target[3])
{
	new visible;
	new testNum;
	new trace;
	new Float:fraction;
	
	static Float:tarvis_origin[3];
	static Float:tarvis_angles[3];
	static Float:tarvis_fwd[3];
	static Float:tarvis_side[3];
	static Float:tarvis_vert[3];
	
	static Float:tarvis_top[3];
	static Float:tarvis_bottom[3];
	static Float:tarvis_left[3];
	static Float:tarvis_right[3];
	static Float:tarvis_frontTop[3];
	static Float:tarvis_frontBottom[3];
	static Float:tarvis_back[3];
	
	new Float:tarvis_corners[8][3];
	
	testNum = 0;
	trace = 0;
	visible = false;
	
	pev(sv_car, pev_origin, tarvis_origin);
	pev(sv_car, pev_angles, tarvis_angles);
	
	xs_anglevectors(tarvis_angles, tarvis_fwd, tarvis_side, tarvis_vert);
	
	// Side Vectors
	xs_vec_mul_scalar(tarvis_fwd, CARFRONTTOP, tarvis_frontTop);
	xs_vec_mul_scalar(tarvis_fwd, CARFRONTBOTTOM, tarvis_frontBottom);
	xs_vec_mul_scalar(tarvis_fwd, CARSIZEMIN[0], tarvis_back);
	xs_vec_mul_scalar(tarvis_side, CARSIZEMAX[1], tarvis_left);
	xs_vec_mul_scalar(tarvis_side, CARSIZEMIN[1], tarvis_right);
	xs_vec_mul_scalar(tarvis_vert, CARSIZEMAX[2], tarvis_top);
	xs_vec_mul_scalar(tarvis_vert, CARSIZEMIN[2], tarvis_bottom);

	// Positions
	
	// Front Left Top
	xs_vec_add(tarvis_frontTop, tarvis_left, tarvis_corners[0]);
	xs_vec_add(tarvis_corners[0], tarvis_top, tarvis_corners[0]);
	
	xs_vec_add(tarvis_corners[0], tarvis_origin, tarvis_corners[0]);
	
	// Front Right Top
	xs_vec_add(tarvis_frontTop, tarvis_right, tarvis_corners[1]);
	xs_vec_add(tarvis_corners[1], tarvis_top, tarvis_corners[1]);
	
	xs_vec_add(tarvis_corners[1], tarvis_origin, tarvis_corners[1]);
	
	// Back Left Top
	xs_vec_add(tarvis_back, tarvis_left, tarvis_corners[2]);
	xs_vec_add(tarvis_corners[2], tarvis_top, tarvis_corners[2]);
	
	xs_vec_add(tarvis_corners[2], tarvis_origin, tarvis_corners[2]);
	
	// Back Right Top
	xs_vec_add(tarvis_back, tarvis_right, tarvis_corners[3]);
	xs_vec_add(tarvis_corners[3], tarvis_top, tarvis_corners[3]);
	
	xs_vec_add(tarvis_corners[3], tarvis_origin, tarvis_corners[3]);
	
	// Front Left Bottom
	xs_vec_add(tarvis_frontBottom, tarvis_left, tarvis_corners[4]);
	xs_vec_add(tarvis_corners[4], tarvis_bottom, tarvis_corners[4]);
	
	xs_vec_add(tarvis_corners[4], tarvis_origin, tarvis_corners[4]);
	
	// Front Right Bottom
	xs_vec_add(tarvis_frontBottom, tarvis_right, tarvis_corners[5]);
	xs_vec_add(tarvis_corners[5], tarvis_bottom, tarvis_corners[5]);
	
	xs_vec_add(tarvis_corners[5], tarvis_origin, tarvis_corners[5]);
	
	// Back Left Bottom
	xs_vec_add(tarvis_back, tarvis_left, tarvis_corners[6]);
	xs_vec_add(tarvis_corners[6], tarvis_bottom, tarvis_corners[6]);
	
	xs_vec_add(tarvis_corners[6], tarvis_origin, tarvis_corners[6]);
	
	// Back Right Bottom
	xs_vec_add(tarvis_back, tarvis_right, tarvis_corners[7]);
	xs_vec_add(tarvis_corners[7], tarvis_bottom, tarvis_corners[7]);
	
	xs_vec_add(tarvis_corners[7], tarvis_origin, tarvis_corners[7]);
	
	while(!visible && testNum < 8)
	{
		engfunc(EngFunc_TraceLine, target, tarvis_corners[testNum], IGNORE_MONSTERS, sv_car, trace);
		get_tr2(trace, TR_flFraction, fraction);
		
		if(fraction == 1.0)
		{
			visible = true;
		}
		else
		{
			testNum++;
		}
	}
	
	if(visible)
	{
		visible = ts_is_in_viewcone(sv_carTarget, tarvis_corners[3]) ? true : ts_is_in_viewcone(sv_carTarget, tarvis_corners[4]);
	}
	
	return visible;
}

public playMusic()
{
	if(get_pcvar_num(cv_carSndChase) > 0)
	{
		new Float:gameTime = get_gametime();
		
		if(sv_soundPlay + MUSICLEN <= gameTime || sv_soundPlay == 0.0)
		{
			sv_soundPlay = gameTime;
			
			emit_sound(sv_carTarget, CHAN_AUTO, MUSICSOUND, 1.0, ATTN_NORM, SND_STOP, PITCH_NORM);
			
			emit_sound(sv_carTarget, CHAN_AUTO, MUSICSOUND, 1.0, ATTN_NORM, 0, PITCH_NORM);
		}
	}
	
	return;
}

public stopMusic()
{
	emit_sound(sv_carTarget, CHAN_AUTO, MUSICSOUND, 1.0, ATTN_NORM, SND_STOP, PITCH_NORM);
	
	sv_soundPlay = 0.0;
	
	return;
}

public playPrix()
{
	if(get_pcvar_num(cv_carSndPrix) > 0)
	{
		new Float:gameTime = get_gametime();
		
		if(sv_prixPlay + PRIXLEN <= gameTime || sv_prixPlay == 0.0)
		{
			sv_prixPlay = gameTime;
			
			emit_sound(sv_car, CHAN_AUTO, PRIXSOUND, 1.0, ATTN_NORM, SND_STOP, PITCH_NORM);
			
			emit_sound(sv_car, CHAN_AUTO, PRIXSOUND, 1.0, ATTN_NORM, 0, PITCH_NORM);
		}
	}
	
	return;
}

public stopPrix()
{
	emit_sound(sv_car, CHAN_AUTO, PRIXSOUND, 1.0, ATTN_NORM, SND_STOP, PITCH_NORM);
	
	sv_soundPlay = 0.0;
	
	return;
}

public playSurprise(id)
{
	if(get_pcvar_num(cv_carSndSurprise) > 0)
	{
		if(sv_carShiaEnabled)
		{
			emit_sound(id, CHAN_AUTO, IMPOSSIBLESOUND, 1.0, ATTN_NORM, 0, PITCH_NORM);
		}
		else
		{
			emit_sound(id, CHAN_AUTO, SURPRISEDSOUND, 1.0, ATTN_NORM, 0, PITCH_NORM);
		}
	}
	
	return;
}

public laserFindTarget(Float:leftLaser[3], Float:rightLaser[3], Float:target[3], Float:newTarget[3], ignoreent, scans)
{
	new trace = 0;
	new Float:leftFraction;
	new Float:rightFraction;
	
	engfunc(EngFunc_TraceLine, leftLaser, target, DONT_IGNORE_MONSTERS, ignoreent, trace);
	get_tr2(trace, TR_flFraction, leftFraction);
	
	engfunc(EngFunc_TraceLine, rightLaser, target, DONT_IGNORE_MONSTERS, ignoreent, trace);
	get_tr2(trace, TR_flFraction, rightFraction);
	
	if((leftFraction < 1.0 || rightFraction < 1.0) && scans < LASERRECURSIONLIMIT)
	{
		
		if(leftFraction < rightFraction)
		{
			target[0] = leftLaser[0] + leftFraction * (target[0] - leftLaser[0]);
			target[1] = leftLaser[1] + leftFraction * (target[1] - leftLaser[1]);
			target[2] = leftLaser[2] + leftFraction * (target[2] - leftLaser[2]);
		}
		else
		{
			target[0] = rightLaser[0] + rightFraction * (target[0] - rightLaser[0]);
			target[1] = rightLaser[1] + rightFraction * (target[1] - rightLaser[1]);
			target[2] = rightLaser[2] + rightFraction * (target[2] - rightLaser[2]);
		}
		
		scans++;
		laserFindTarget(leftLaser, rightLaser, target, newTarget, ignoreent, scans);
	}
	else
	{
		newTarget[0] = target[0];
		newTarget[1] = target[1];
		newTarget[2] = target[2];
	}
	
	return;
}

public drawLine(Float:start[3], Float:end[3], life)
{
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
	write_byte(TE_BEAMPOINTS);				// beam type
	write_coord(floatround(start[0]));		// start pos X
	write_coord(floatround(start[1]));		// start pos Y
	write_coord(floatround(start[2]));		// start pos Z
	write_coord(floatround(end[0]));		// end pos X
	write_coord(floatround(end[1]));		// end pos Y
	write_coord(floatround(end[2]));		// end pos Z
	write_short(laserSprite); 	// sprite index
	write_byte(1); 				// starting frame
	write_byte(1); 				// frame rate in 0.1's
	write_byte(life);			// life in 0.1's
	write_byte(100); 			// line width in 0.1's
	write_byte(1); 				// noise amplitude in 0.01's
	write_byte(255);			// red
	write_byte(255);			// green
	write_byte(255);			// blue
	write_byte(255);			// brightness
	write_byte(1);				// scroll speed in 0.1's
	message_end();
	
	return;
}

public laserWeak(ent, Float:origin[3])
{
	if(ent > 0 && pev_valid(ent))
	{
		engfunc(EngFunc_RemoveEntity, ent);
	}
	
	ent = create_entity("env_laser");
	
	set_pev(ent, pev_origin, origin);
	DispatchKeyValue(ent, "spawnflags", "49");
	DispatchKeyValue(ent, "targetname", "carLaser");
	DispatchKeyValue(ent, "renderfx", "0");
	DispatchKeyValue(ent, "LaserTarget", "carLaserTarget");
	DispatchKeyValue(ent, "renderamt", "188");
	DispatchKeyValue(ent, "rendercolor", "255 0 0");
	DispatchKeyValue(ent, "Radius", "256");
	DispatchKeyValue(ent, "life", "0");
	DispatchKeyValue(ent, "width", "10");
	DispatchKeyValue(ent, "NoiseAmplitude", "0");
	DispatchKeyValue(ent, "texture", LASERSPRITE);
	DispatchKeyValue(ent, "TextureScroll", "35");
	DispatchKeyValue(ent, "framerate", "0");
	DispatchKeyValue(ent, "framestart", "0");
	DispatchKeyValue(ent, "StrikeTime", "1");
	DispatchKeyValue(ent, "damage", "5");
	DispatchSpawn(ent);
	
	return ent;
}

public laserStrong(ent, Float:origin[3])
{
	if(ent > 0 && pev_valid(ent))
	{
		engfunc(EngFunc_RemoveEntity, ent);
	}
	
	ent = create_entity("env_laser");
	
	set_pev(ent, pev_origin, origin);
	DispatchKeyValue(ent, "spawnflags", "49");
	DispatchKeyValue(ent, "targetname", "carLaser");
	DispatchKeyValue(ent, "renderfx", "0");
	DispatchKeyValue(ent, "LaserTarget", "carLaserTarget");
	DispatchKeyValue(ent, "renderamt", "188");
	DispatchKeyValue(ent, "rendercolor", "255 0 0");
	DispatchKeyValue(ent, "Radius", "256");
	DispatchKeyValue(ent, "life", "0");
	DispatchKeyValue(ent, "width", "100");
	DispatchKeyValue(ent, "NoiseAmplitude", "2");
	DispatchKeyValue(ent, "texture", LASERSPRITE);
	DispatchKeyValue(ent, "TextureScroll", "35");
	DispatchKeyValue(ent, "framerate", "0");
	DispatchKeyValue(ent, "framestart", "0");
	DispatchKeyValue(ent, "StrikeTime", "1");
	DispatchKeyValue(ent, "damage", "50");
	DispatchSpawn(ent);
	
	return ent;
}

public laserCleanup()
{
	// Remove lasers
	if(sv_carLaser[0] > 0 && pev_valid(sv_carLaser[0]))
	{
		engfunc(EngFunc_RemoveEntity, sv_carLaser[0]);
		
		sv_carLaser[0] = 0;
	}
	
	if(sv_carLaser[1] > 0 && pev_valid(sv_carLaser[1]))
	{
		engfunc(EngFunc_RemoveEntity, sv_carLaser[1]);
		
		sv_carLaser[1] = 0;
	}
	
	// Remove target
	if(sv_carLaserTarget > 0 && pev_valid(sv_carLaserTarget))
	{
		engfunc(EngFunc_RemoveEntity, sv_carLaserTarget);
		
		sv_carLaserTarget = 0;
	}
	
	return;
}

public explosionAttack(Float:origin[3], damage, radius) {
	new iOrigin[3];
	
	iOrigin[0] = floatround(origin[0]);
	iOrigin[1] = floatround(origin[1]);
	iOrigin[2] = floatround(origin[2]);
	
	radius_damage(origin, damage, radius);
	
	// Explosion
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
	write_byte(TE_EXPLOSION);
	write_coord(iOrigin[0]);
	write_coord(iOrigin[1]);
	write_coord(iOrigin[2]);
	write_short(explodeSprite);
	write_byte(50);
	write_byte(15);
	write_byte(0);
	message_end();
	
	return;
}

public Float:get_distance2_f(const Float:origin[3], const Float:origin2[3], const firstVal, const secondVal)
{
	return floatsqroot(floatpower(origin[firstVal]-origin2[firstVal],2.0)+floatpower(origin[secondVal]-origin2[secondVal],2.0));
}

public Float:floatMod(Float:num, div) {
	new rounded = floatround(num,floatround_floor);
	
	return float(rounded % div) + num - float(rounded);
}

public spawnFleshGibs(origin[3], spread, count, life)
{
	// defaults: spread: 10: count: 8 life: 30
	
	message_begin(MSG_PVS,SVC_TEMPENTITY, origin)
	{
		write_byte(TE_BREAKMODEL)
		
		write_coord(origin[0])
		write_coord(origin[1])
		write_coord(origin[2] + 16)
		
		write_coord(32)
		write_coord(32)
		write_coord(32)
		
		write_coord(0)
		write_coord(0)
		write_coord(25)
		
		write_byte(spread)
		
		write_short(fleshGibs)
		
		write_byte(count)
		write_byte(life)
		
		write_byte(0x04)
	}
	message_end()
}

stock bool:ts_is_in_viewcone(index, const Float:point[3]) {
	new Float:angles[3];
	pev(index, pev_angles, angles);
	engfunc(EngFunc_MakeVectors, angles);
	global_get(glb_v_forward, angles);
	angles[2] = 0.0;

	new Float:origin[3], Float:diff[3], Float:norm[3];
	pev(index, pev_origin, origin);
	xs_vec_sub(point, origin, diff);
	diff[2] = 0.0;
	xs_vec_normalize(diff, norm);

	new Float:dot;
	dot = xs_vec_dot(norm, angles);
	if (dot >= floatcos(85.0 * M_PI / 360))
		return true;

	return false;
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1033\\ f0\\ fs16 \n\\ par }
*/
