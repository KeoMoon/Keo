#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
//#include <colors>

#pragma tabsize 0

#define TANK_RAGE_SPEED 1.5
#define TANK_RAGE_DAMAGE 1.5
#define TANK_RAGE_ATTACK_RATE 1.5
#define TANK_RAGE_GLOW_COLOR "255 0 0 255"

#define INFECTED_TEAM 3
#define ZC_TANK		8

new bool:g_bTankRage[MAXPLAYERS+1];
float g_flTankDamage[MAXPLAYERS+1];
float g_flTankRageDamage[MAXPLAYERS+1];
int g_hTankGlow[MAXPLAYERS+1];
int g_iNumTanks = 0;

public Plugin:myinfo =
{
	name = "tank rage",
	version = "1.1",
	author = "KeoMoon",
	description = "Make the tank stronger",
};

public OnPluginStart()
{
	RegConsoleCmd("sm_tankrage_version", Command_TankRageVersion, "Show the version of the tank rage plugin");
	RegConsoleCmd("sm_tankrage_reload", Command_TankRageReload, "Reload the tank rage plugin", ADMFLAG_CONFIG);
	RegAdminCmd("sm_tankrage_enable", Command_TankRageEnable, ADMFLAG_CONFIG, "Enable or disable the tank rage plugin (1/0)");
	CreateConVar("sm_tankrage_enabled", "1", "Enable or disable the tank rage plugin (1/0)", FCVAR_NOTIFY);
	
	HookEvent("tank_spawn", Event_TankSpawn, EventHookMode_PostNoCopy);
	HookEvent("player_death", Event_TankDeath, EventHookMode_PostNoCopy);
	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_PostNoCopy);
}

public OnMapStart()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		g_bTankRage[i] = false;
		g_flTankRageDamage[i] = 0.0;
	}
	g_iNumTanks = 0;
}

public OnPluginEnd()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		g_hTankGlow[i] = 0;
	}
}

public Action:Command_TankRageVersion(client, args)
{
	return Plugin_Handled;
}

public Action:Command_TankRageReload(client, args)
{
	if (GetCmdArgs() == 0)
	{
		return Plugin_Handled;
	}
	
	char sPassword[64];
	GetCmdArg(1, sPassword, sizeof(sPassword));
	
	if (StrEqual(sPassword, "keo"))
	{
	}
	else
	{
	}
	
	return Plugin_Handled;
}

public Action:Command_TankRageEnable(client, args)
{
	if (GetCmdArgs() == 0)
	{
		return Plugin_Handled;
	}
	char str[32];
	 GetCmdArg(1,str,sizeof(str))
	int iEnabled = StringToInt(str);
	
	if (iEnabled == 0)
	{
		SetConVarInt(FindConVar("sm_tankrage_enabled"), 0);
	}
	else if (iEnabled == 1)
	{
		SetConVarInt(FindConVar("sm_tankrage_enabled"), 1);
	}
	else
	{
	}
	
	return Plugin_Handled;
}

public Action:Event_TankSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	int iTank = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (IsValidClient(iTank))
	{
		g_bTankRage[iTank] = true;
		g_iNumTanks++;
	}
	
	return Plugin_Continue;
}

public Action:Event_TankDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	int iTank = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (IsValidClient(iTank))
	{
		g_bTankRage[iTank] = false;
		g_flTankDamage[iTank] = 0.0;
		g_flTankRageDamage[iTank] = 0.0;
		for (int sur = 1; sur <= MaxClients; sur++)
		{
			if (IsValidSurvivor(sur))
			{
				SDKUnhook(sur, SDKHook_OnTakeDamage, OnTakeDamage);
			}
		}
		
		g_iNumTanks--;
		if (g_iNumTanks == 1)
		{
			for (int i = 1; i <= MaxClients; i++)
			{
				if (g_bTankRage[i])
				{
					ForcePlayerSuicide(i);
					break;
				}
			}
		}
	}
	
	return Plugin_Continue;
}

public Action:Event_PlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (GetConVarInt(FindConVar("sm_tankrage_enabled")) == 0)
	{
		return Plugin_Continue;
	}
	
	int iAttacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	int iVictim = GetClientOfUserId(GetEventInt(event, "userid"));
	if(IsValidSurvivor(iAttacker))
	{
		if (IsClientTank(iVictim))
		{
			int iHealth = GetEntProp(iVictim, Prop_Data, "m_iHealth");
			int iMaxHealth = GetEntProp(iVictim, Prop_Data, "m_iMaxHealth");
			
			if (iHealth <= iMaxHealth * 0.3) // Check if tank's health is below 30%
			{
				if (!g_bTankRage[iVictim])
				{
					g_bTankRage[iVictim] = true;
					ApplyTankRage(iVictim);
				}
				else
				{
					ChangeGlowColor(iVictim); // Change glow color when tank takes damage in rage mode
				}
			}
		}
	}
	return Plugin_Continue;
}

public void ApplyTankRage(int iTank)
{
	if (IsValidClient(iTank))
	{
		SetEntPropFloat(iTank, Prop_Send, "m_flLaggedMovementValue", 1.0 * TANK_RAGE_SPEED);
		g_flTankDamage[iTank] = 30.0;
		for (int sur = 1; sur <= MaxClients; sur++)
		{
			if (IsValidSurvivor(sur))
			{
				SDKHook(sur, SDKHook_OnTakeDamage, OnTakeDamage);
			}
		}
		ChangeGlowColor(iTank); // Change glow color when tank enters rage mode

		int iClosestSurvivor = GetClosestSurvivor(iTank);
		if (iClosestSurvivor != -1)
		{
			CreateTimer(2.0, Timer_CreateShockwave, iClosestSurvivor, TIMER_FLAG_NO_MAPCHANGE); // Create a shockwave after 2 seconds
		}
	}
}

public void ChangeGlowColor(int iTank)
{
    if (IsValidClient(iTank) && g_bTankRage[iTank])
    {
        char buffer[64];
        int A = GetRandomInt(0, 255);
        int B =	GetRandomInt(0, 255);
        int C = GetRandomInt(0, 255);
        Format(buffer, sizeof(buffer), "%i %i %i",A,B,C);

        SetEntProp(iTank, Prop_Send, "m_glowColorOverride", A + (B * 256) + (C * 65536));
    }
}

public Action:Timer_CreateShockwave(Handle:hTimer, any:iSurvivor)
{
	CreateShockwave(iSurvivor);
	return Plugin_Stop;
}

public void CreateShockwave(int iSurvivor)
{
	if (IsValidSurvivor(iSurvivor))
	{
		float vecSurvivorPos[3];
		GetClientAbsOrigin(iSurvivor, vecSurvivorPos);
		
		int iEntity = CreateEntityByName("env_shockwave");
		DispatchKeyValue(iEntity, "targetname", "shockwave");
		DispatchKeyValueVector (iEntity, "origin", vecSurvivorPos);//sao ?,chat dís>3 đấy
		DispatchKeyValue(iEntity, "spawnflags", "8");
		DispatchKeyValue(iEntity, "ShockwaveRadius", "200");
		DispatchKeyValue(iEntity, "ShockwaveDuration", "1");
		DispatchKeyValue(iEntity, "ShockwaveEndTime", "1");
		DispatchSpawn(iEntity);
		AcceptEntityInput(iEntity, "StartShockwave");
		
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidSurvivor(i))
			{
				float vecSurvivorPos2[3];
				GetClientAbsOrigin(i, vecSurvivorPos2);
				
				if (GetVectorDistance(vecSurvivorPos, vecSurvivorPos2) <= 200)
				{
					SDKHooks_TakeDamage(i, iSurvivor,iSurvivor, 30.0, DMG_GENERIC);//roi day
				}
			}
		}
	}
}

stock int GetClosestSurvivor(int iTank)
{
	float vecTankPos[3];
	GetClientAbsOrigin(iTank, vecTankPos);
	float flClosestDistance = 9999999999999999999999999999999999999999999999999999999999999999999999999.9; //=))
	int iClosestSurvivor = -1;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidSurvivor(i))
		{
			float vecSurvivorPos[3];
			GetClientAbsOrigin(i, vecSurvivorPos);
			
			float flDistance = GetVectorDistance(vecTankPos, vecSurvivorPos);
			if (flDistance < flClosestDistance)
			{
				flClosestDistance = flDistance;
				iClosestSurvivor = i;
			}
		}
	}
	
	return iClosestSurvivor;
}

Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if(IsClientTank(attacker)&& IsValidSurvivor(victim))
	{
		damage = g_flTankDamage[attacker] * 1.0;
		return Plugin_Changed;
	}
	return Plugin_Continue;
}	

stock bool IsValidClient(int client){
	return (client > 0 && client <= MaxClients && IsClientInGame(client));
}

stock bool IsValidSurvivor(int client){
	return (IsValidClient(client) && GetClientTeam(client) == 2);
}

stock bool IsClientTank(int client)
{
	
	if (!IsValidClient(client)) return false;
	if (GetClientTeam(client) == INFECTED_TEAM) {
		int zombieClass = GetEntProp(client, Prop_Send, "m_zombieClass");
		if (zombieClass == ZC_TANK) {
			if(IsFakeClient(client)) { 
				return true;
			}
		}
	}
	return false; 
}
