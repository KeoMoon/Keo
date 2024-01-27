#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <colors>

#define iArray	4
#define CVAR_FLAGS	FCVAR_NOTIFY
#define TankSound	"ui/pickup_secret01.wav"
#define NON_FLAMMABLE 1
#define FLAMMABLE 2

int g_iMultiplesCount;
float g_fMultiples[iArray];
char g_sDifficultyName[iArray][32] = {"Dễ", "Thường", "Khó", "Chuyên gia"};
char g_sDifficultyCode[iArray][32] = {"Easy", "Normal", "Hard", "Impossible"};

bool TankSpawnFinaleVehicleLeaving, g_bTankSwitch, g_bWitchSwitch;
ConVar g_hMultiples;
int    g_iTankPrompt, g_iTankHealth, g_iWitchHealth;
ConVar g_hTankSwitch, g_hTankPrompt, g_hTankHealth, g_hWitchSwitch, g_hWitchHealth;

static int iCvar_IgnitionModes;
static bool bLeft4DeadTwo;

public Plugin myinfo = 
{
	name = "KM_Tank_Hp",
	author = "KeoMoon",
	description = "",
	version = "1.1",
	url = ""
};

public APLRes AskPluginLoad2(Handle hMyself, bool bLate, char[] sError, int Error_Max)
{
	EngineVersion Engine = GetEngineVersion();
	if (Engine != Engine_Left4Dead && Engine != Engine_Left4Dead2 /* || !IsDedicatedServer() */)
	{
		strcopy(sError, Error_Max, "This plugin \"HP Tank Multiplier\" only runs in the \"Left 4 Dead 1/2\" Games!");
		return APLRes_SilentFailure;
	}
	
	bLeft4DeadTwo = (Engine == Engine_Left4Dead2);
	return APLRes_Success;
}

public void OnPluginStart()
{
	g_hTankSwitch		= CreateConVar("l4d2_tank_Switch", 		"1", 	"Tank Hp theo player 0=Tắt, 1=Bật.", CVAR_FLAGS);
	g_hTankPrompt		= CreateConVar("l4d2_tank_prompt", 		"1", 	"Đặt loại lời nhắc khi xe tăng xuất hiện. 0=Tắt, 1=Chat, 2=Screen bottom + chat, 3=Giữa màn hình và dưới.", CVAR_FLAGS);
	g_hMultiples		= CreateConVar("l4d2_tank_Multiples", 	"2.5;2.0;1.5;1.0", "Đặt hệ số nhân tương ứng với độ khó của trò chơi (để trống = mặc định: 1.0).", CVAR_FLAGS);
	g_hTankHealth		= CreateConVar("l4d2_tank_health", 		"1000", "Hp Tank nhận được cho mỗi người sống sót.", CVAR_FLAGS);
	g_hWitchSwitch		= CreateConVar("l4d2_witch_Switch", 	"1", 	"Bật cài đặt HP và lời nhắc khi phù thủy xuất hiện 0=Tắt, 1=Đặt HP và lời nhắc của phù thủy.", CVAR_FLAGS);
	g_hWitchHealth		= CreateConVar("l4d2_witch_health", 	"1000",	"Hp witch.", CVAR_FLAGS);

	g_hTankSwitch.AddChangeHook(iHealthConVarChanged);
	g_hTankPrompt.AddChangeHook(iHealthConVarChanged);
	g_hMultiples.AddChangeHook(iHealthConVarChanged);
	g_hTankHealth.AddChangeHook(iHealthConVarChanged);
	g_hWitchSwitch.AddChangeHook(iHealthConVarChanged);
	g_hWitchHealth.AddChangeHook(iHealthConVarChanged);
	
	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("witch_spawn", Event_WitchSpawn);
	HookEvent("witch_harasser_set",	Event_WitchHarasserSet);
	HookEvent("tank_spawn", Event_TankSpawn);
	HookEvent("finale_vehicle_leaving", Event_FinaleVehicleLeaving);
	
	AutoExecConfig(true, "l4d2_tank_hp");
}

public void OnMapStart()
{
	iHealthCvars();
	PrecacheSound(TankSound);
	TankSpawnFinaleVehicleLeaving = false;
	
}

public void iHealthConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	iHealthCvars();
}

void iHealthCvars()
{
	g_bTankSwitch	= g_hTankSwitch.BoolValue;
	g_iTankPrompt	= g_hTankPrompt.IntValue;
	g_iTankHealth	= g_hTankHealth.IntValue;
	g_bWitchSwitch	= g_hWitchSwitch.BoolValue;
	g_iWitchHealth	= g_hWitchHealth.IntValue;

	char sCmds[512], g_sMultiples[iArray][32];
	g_hMultiples.GetString(sCmds, sizeof(sCmds));
	g_iMultiplesCount = ReplaceString(sCmds, sizeof(sCmds), ";", ";", false);
	ExplodeString(sCmds, ";", g_sMultiples, g_iMultiplesCount + 1, 32);
	
	for (int i = 0; i < iArray; i++)
		g_fMultiples[i] = sCmds[0] == '\0' || IsCharSpace(sCmds[0]) || g_sMultiples[i][0] == '\0' || IsCharSpace(g_sMultiples[i][0]) || !IsCharNumeric(g_sMultiples[i][0]) ? 1.0 : StringToFloat(g_sMultiples[i]);
}
public void OnMapEnd()
{
	TankSpawnFinaleVehicleLeaving = true;
}
public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	TankSpawnFinaleVehicleLeaving = true;
}
public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	TankSpawnFinaleVehicleLeaving = false;
}
public void Event_FinaleVehicleLeaving(Event event, const char[] name, bool dontBroadcast)
{
	TankSpawnFinaleVehicleLeaving = true;
}

public void Event_WitchSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (g_bWitchSwitch)
		SetWitchHealth(client, g_iWitchHealth);
}
void SetWitchHealth(int client, int iHealth)
{
	SetClientHealth(client, iHealth);
	if (!TankSpawnFinaleVehicleLeaving)
		CPrintToChatAll("{default}[{green}!{default}] front{blue} witch {default}spawn!");
}
void Event_WitchHarasserSet(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsClientInGame(client))
		return;

	switch (GetClientTeam(client)) {
		case 2: {
			int idleplayer = GetIdlePlayerOfBot(client);
			if (!idleplayer)
				CPrintToChatAll("{default}[{green}!{default}] {blue}%N{default} Alarm {blue}Witch", client);
			else
				CPrintToChatAll("{default}[{green}!{default}] ({olive}idle{default}){blue}%N{default} Alarm {blue}Witch", idleplayer);
		}

		case 3:
			CPrintToChatAll("{default}[{green}!{default}] {olive}%N{default} Alarm {blue}Witch", client);
	}
}
public void Event_TankSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bTankSwitch)
		return;
	
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (IsValidTank(client))
	{
		EmitSoundToAll(TankSound);
		for (int i = 0; i < iArray; i++)
			if (StrEqual(GetGameDifficulty(), g_sDifficultyCode[i], false))
				SetTankHealth(client, g_fMultiples[i] == 0 ? 1.0 : g_fMultiples[i], g_sDifficultyName[i]);
	}
}
void SetTankHealth(int client, float Multiples, char[] name)
{
    char sName[64];
    strcopy(sName, sizeof(sName), name);

    DataPack hPack = new DataPack();
    hPack.WriteCell(client);
    hPack.WriteString(name);
    RequestFrame(IsClientPrint, hPack);
    int maxHealth = RoundFloat(Multiples * (IsCountPlayersTeam() * g_iTankHealth));
    SetClientHealth(client, maxHealth);

    // Set the burn duration based on the max health of the tank
    if (iCvar_IgnitionModes == FLAMMABLE)
    {
        if (strncmp(sName, "Easy", sizeof(sName), false) == 0)
            FindConVar(bLeft4DeadTwo ? "tank_burn_duration" : "tank_burn_duration_normal").IntValue = maxHealth;
        else if (strncmp(sName, "Hard", sizeof(sName), false) == 0)
            FindConVar("tank_burn_duration_hard").IntValue = maxHealth;
        else if (strncmp(sName, "Impossible", sizeof(sName), false) == 0)
            FindConVar("tank_burn_duration_expert").IntValue = maxHealth;
        else
            FindConVar(bLeft4DeadTwo ? "tank_burn_duration" : "tank_burn_duration_normal").IntValue = maxHealth;
    }
}


void SetClientHealth(int client, int iHealth)
{
	SetEntProp(client, Prop_Data, "m_iHealth", iHealth);
	SetEntProp(client, Prop_Data, "m_iMaxHealth", iHealth);
}

void IsClientPrint(DataPack hPack)
{
	hPack.Reset();
	char name[64];
	int  client = hPack.ReadCell();
	hPack.ReadString(name, sizeof(name));
	if(IsValidTank(client) && g_iTankPrompt != 0 && !TankSpawnFinaleVehicleLeaving)
	{
		if(g_iTankPrompt == 1 || g_iTankPrompt == 2)
			CPrintToChatAll("{default}[{green}!{default}] {blue}Tank {default}({olive}controll: %s{default}) Spawn！\n{default}[{green}!{default}] {blue}difficulty:{green}%s {blue}Survive:{green}%d {blue}HP:{green}%d", GetSurvivorName(client), name, IsCountPlayersTeam(), GetClientHealth(client));
		if(g_iTankPrompt == 2 || g_iTankPrompt == 3)
			PrintHintTextToAll("Tank %s Spawn! difficulty:%s Survive:%d HP:%d", GetSurvivorName(client), name, IsCountPlayersTeam(), GetClientHealth(client));
	}
	delete hPack;
}

char[] GetSurvivorName(int tank)
{
	char sTankName[MAX_NAME_LENGTH];
	
	if (!IsFakeClient(tank) && IsClientInGame(tank) && GetClientTeam(tank) == 3 && GetEntProp(tank, Prop_Send, "m_zombieClass") == 8)
	{
		FormatEx(sTankName, sizeof(sTankName), "(player)%N", tank);
	}
	else if (tank != 0 && GetClientTeam(tank) == 3 && GetEntProp(tank, Prop_Send, "m_zombieClass") == 8)
	{
		FormatEx(sTankName, sizeof(sTankName), "(AI)%N", tank);
	}
	return sTankName;
}

char[] GetGameDifficulty()
{
	char sGameDifficulty[32];
	GetConVarString(FindConVar("z_difficulty"), sGameDifficulty, sizeof(sGameDifficulty));
	return sGameDifficulty;
}

stock bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client);
}

stock bool IsValidTank(int client)
{
	return IsValidClient(client) && GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_zombieClass") == 8 && IsPlayerAlive(client);
}

int IsCountPlayersTeam()
{
	int iCount = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 2)
			iCount++;
	}
	return iCount;
}

int GetIdlePlayerOfBot(int client) {
	if (!HasEntProp(client, Prop_Send, "m_humanSpectatorUserID"))
		return 0;

	return GetClientOfUserId(GetEntProp(client, Prop_Send, "m_humanSpectatorUserID"));
}
