#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>

#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3

#define ZC_SMOKER  1
#define ZC_BOOMER  2
#define ZC_HUNTER  3
#define ZC_SPITTER 4
#define ZC_JOCKEY  5
#define ZC_CHARGER 6

#define MAX_BOOMER_RECORDS 16

#if !defined DMG_BURN
#define DMG_BURN (1 << 3)
#endif

ConVar g_hEnable;
ConVar g_hIncludeBots;

ConVar g_hBoomerEnable;
ConVar g_hBoomerWindow;
ConVar g_hBoomerMinVictims;
ConVar g_hBoomerMaxDistance;

ConVar g_hChargerEnable;
ConVar g_hChargerMinBumps;
ConVar g_hChargerDelay;

ConVar g_hWitchEnable;
ConVar g_hWitchWindow;
ConVar g_hWitchDamageWindow;

ConVar g_hFireEnable;
ConVar g_hFireWindow;
ConVar g_hFireThreshold;

ConVar g_hFFEnable;
ConVar g_hFFWindow;
ConVar g_hFFThreshold;

ConVar g_hBileJarEnable;

bool g_bBoomerActive[MAX_BOOMER_RECORDS];
int g_iBoomerKiller[MAX_BOOMER_RECORDS];
float g_fBoomerTime[MAX_BOOMER_RECORDS];
float g_fBoomerPos[MAX_BOOMER_RECORDS][3];
bool g_bBoomerVictims[MAX_BOOMER_RECORDS][MAXPLAYERS + 1];
Handle g_hBoomerTimer[MAX_BOOMER_RECORDS];

bool g_bChargerActive[MAXPLAYERS + 1];
bool g_bChargerAnnounced[MAXPLAYERS + 1];
bool g_bChargerBumped[MAXPLAYERS + 1][MAXPLAYERS + 1];
int g_iChargerMainVictim[MAXPLAYERS + 1];
Handle g_hChargerTimer[MAXPLAYERS + 1];

int g_iWitchHarasser;
int g_iWitchEnt;
float g_fWitchHarassTime;
float g_fLastWitchDamageTime[MAXPLAYERS + 1];
int g_iLastWitchEntity[MAXPLAYERS + 1];
float g_fLastWitchAnnounceTime[MAXPLAYERS + 1];

float g_fFireDamage[MAXPLAYERS + 1];
bool g_bFireVictims[MAXPLAYERS + 1][MAXPLAYERS + 1];
Handle g_hFireTimer[MAXPLAYERS + 1];

float g_fFFDamage[MAXPLAYERS + 1];
bool g_bFFVictims[MAXPLAYERS + 1][MAXPLAYERS + 1];
Handle g_hFFTimer[MAXPLAYERS + 1];

public Plugin myinfo =
{
    name = "L4D2 Funny Moments Announce",
    author = "night",
    description = "Announces funny survivor mishaps: Boomer splash, bile jar hits, Charger multi-bumps, Witch blame, fire FF and high FF.",
    version = "1.1.0",
    url = ""
};

public void OnPluginStart()
{
    g_hEnable = CreateConVar("l4d2_fma_enable", "1", "0=Disable, 1=Enable funny moments announcements.");
    g_hIncludeBots = CreateConVar("l4d2_fma_include_bots", "0", "0=Ignore survivor bots as actors/victims, 1=Include bots.");

    g_hBoomerEnable = CreateConVar("l4d2_fma_boomer_enable", "1", "0=Disable, 1=Enable Boomer splash teammate announcement.");
    g_hBoomerWindow = CreateConVar("l4d2_fma_boomer_window", "0.5", "Seconds after a survivor-killed Boomer death to attribute biled teammates to that Boomer.");
    g_hBoomerMinVictims = CreateConVar("l4d2_fma_boomer_min_victims", "1", "Minimum teammate victims biled by Boomer explosion required to announce.");
    g_hBoomerMaxDistance = CreateConVar("l4d2_fma_boomer_max_distance", "450.0", "Maximum distance from Boomer death position to biled survivor for attribution. 0=No distance check.");

    g_hChargerEnable = CreateConVar("l4d2_fma_charger_enable", "1", "0=Disable, 1=Enable Charger multi-bump announcement.");
    g_hChargerMinBumps = CreateConVar("l4d2_fma_charger_min_bumps", "2", "Minimum side victims bumped by one charge required to announce.");
    g_hChargerDelay = CreateConVar("l4d2_fma_charger_delay", "0.4", "Delay after pummel/charge end before announcing Charger multi-bumps.");

    g_hWitchEnable = CreateConVar("l4d2_fma_witch_enable", "1", "0=Disable, 1=Enable Witch teammate blame announcement.");
    g_hWitchWindow = CreateConVar("l4d2_fma_witch_window", "20.0", "Seconds after a player startles Witch to blame them if Witch incaps/kills a teammate.");
    g_hWitchDamageWindow = CreateConVar("l4d2_fma_witch_damage_window", "1.0", "Seconds after Witch damage to treat an incap/death event as caused by Witch.");

    g_hFireEnable = CreateConVar("l4d2_fma_fire_enable", "1", "0=Disable, 1=Enable fire friendly-fire announcement.");
    g_hFireWindow = CreateConVar("l4d2_fma_fire_window", "5.0", "Seconds to accumulate fire friendly-fire before checking threshold.");
    g_hFireThreshold = CreateConVar("l4d2_fma_fire_threshold", "15.0", "Minimum accumulated fire friendly-fire damage required to announce.");

    g_hFFEnable = CreateConVar("l4d2_fma_ff_enable", "1", "0=Disable, 1=Enable non-fire high friendly-fire announcement.");
    g_hFFWindow = CreateConVar("l4d2_fma_ff_window", "8.0", "Seconds to accumulate non-fire friendly-fire before checking threshold.");
    g_hFFThreshold = CreateConVar("l4d2_fma_ff_threshold", "40.0", "Minimum accumulated non-fire friendly-fire damage required to announce.");

    g_hBileJarEnable = CreateConVar("l4d2_fma_bilejar_enable", "1", "0=Disable, 1=Enable bile jar teammate announcement.");

    HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
    HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
    HookEvent("player_now_it", Event_PlayerNowIt, EventHookMode_Post);

    HookEvent("charger_charge_start", Event_ChargerChargeStart, EventHookMode_Post);
    HookEvent("charger_impact", Event_ChargerImpact, EventHookMode_Post);
    HookEvent("charger_carry_start", Event_ChargerCarryOrPummelStart, EventHookMode_Post);
    HookEvent("charger_pummel_start", Event_ChargerCarryOrPummelStart, EventHookMode_Post);
    HookEvent("charger_charge_end", Event_ChargerChargeEnd, EventHookMode_Post);

    HookEvent("witch_harasser_set", Event_WitchHarasserSet, EventHookMode_Post);
    HookEvent("player_incapacitated", Event_PlayerIncapOrDeath, EventHookMode_Post);

    AutoExecConfig(true, "l4d2_funny_moments_announce");

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
        {
            SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
        }
    }
}

public void OnClientPutInServer(int client)
{
    SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public void OnClientDisconnect(int client)
{
    SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public void OnMapEnd()
{
    ResetAllState();
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    ResetAllState();
}

void ResetAllState()
{
    for (int i = 0; i < MAX_BOOMER_RECORDS; i++)
    {
        ResetBoomerRecord(i);
    }

    for (int i = 1; i <= MaxClients; i++)
    {
        ResetChargerRecord(i);
        ResetFireRecord(i);
        ResetFFRecord(i);
        g_fLastWitchDamageTime[i] = 0.0;
        g_iLastWitchEntity[i] = -1;
        g_fLastWitchAnnounceTime[i] = 0.0;
    }

    g_iWitchHarasser = 0;
    g_iWitchEnt = -1;
    g_fWitchHarassTime = 0.0;
}

void ResetBoomerRecord(int slot)
{
    g_bBoomerActive[slot] = false;
    g_iBoomerKiller[slot] = 0;
    g_fBoomerTime[slot] = 0.0;
    g_fBoomerPos[slot][0] = 0.0;
    g_fBoomerPos[slot][1] = 0.0;
    g_fBoomerPos[slot][2] = 0.0;

    for (int i = 1; i <= MaxClients; i++)
    {
        g_bBoomerVictims[slot][i] = false;
    }

    SafeCloseHandle(g_hBoomerTimer[slot]);
}

void ResetChargerRecord(int charger)
{
    if (charger < 1 || charger > MaxClients)
    {
        return;
    }

    g_bChargerActive[charger] = false;
    g_bChargerAnnounced[charger] = false;
    g_iChargerMainVictim[charger] = 0;

    for (int i = 1; i <= MaxClients; i++)
    {
        g_bChargerBumped[charger][i] = false;
    }

    SafeCloseHandle(g_hChargerTimer[charger]);
}

void ResetFireRecord(int attacker)
{
    if (attacker < 1 || attacker > MaxClients)
    {
        return;
    }

    g_fFireDamage[attacker] = 0.0;

    for (int i = 1; i <= MaxClients; i++)
    {
        g_bFireVictims[attacker][i] = false;
    }

    SafeCloseHandle(g_hFireTimer[attacker]);
}

void ResetFFRecord(int attacker)
{
    if (attacker < 1 || attacker > MaxClients)
    {
        return;
    }

    g_fFFDamage[attacker] = 0.0;

    for (int i = 1; i <= MaxClients; i++)
    {
        g_bFFVictims[attacker][i] = false;
    }

    SafeCloseHandle(g_hFFTimer[attacker]);
}

void SafeCloseHandle(Handle &handle)
{
    if (handle == null)
    {
        return;
    }

    if (IsValidHandle(handle))
    {
        delete handle;
    }

    handle = null;
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_hEnable.BoolValue)
    {
        return;
    }

    HandleBoomerDeath(event);
    HandlePlayerWitchDeath(event);
}

void HandleBoomerDeath(Event event)
{
    if (!g_hBoomerEnable.BoolValue)
    {
        return;
    }

    int victim = GetClientOfUserId(event.GetInt("userid", 0));
    int attacker = GetClientOfUserId(event.GetInt("attacker", 0));

    if (!IsValidClient(victim) || !IsValidSurvivor(attacker))
    {
        return;
    }

    if (!ShouldUseSurvivor(attacker))
    {
        return;
    }

    if (GetClientTeam(victim) != TEAM_INFECTED)
    {
        return;
    }

    if (GetZombieClass(victim) != ZC_BOOMER)
    {
        return;
    }

    int slot = GetBoomerSlot();
    ResetBoomerRecord(slot);

    g_bBoomerActive[slot] = true;
    g_iBoomerKiller[slot] = attacker;
    g_fBoomerTime[slot] = GetEngineTime();
    GetClientAbsOrigin(victim, g_fBoomerPos[slot]);

    float delay = g_hBoomerWindow.FloatValue;
    if (delay < 0.1)
    {
        delay = 0.1;
    }

    g_hBoomerTimer[slot] = CreateTimer(delay, Timer_AnnounceBoomer, slot, TIMER_FLAG_NO_MAPCHANGE);
}

int GetBoomerSlot()
{
    int oldest = 0;
    float oldestTime = 999999999.0;

    for (int i = 0; i < MAX_BOOMER_RECORDS; i++)
    {
        if (!g_bBoomerActive[i])
        {
            return i;
        }

        if (g_fBoomerTime[i] < oldestTime)
        {
            oldestTime = g_fBoomerTime[i];
            oldest = i;
        }
    }

    return oldest;
}

public void Event_PlayerNowIt(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_hEnable.BoolValue || !g_hBoomerEnable.BoolValue)
    {
        return;
    }

    int victim = GetClientOfUserId(event.GetInt("userid", 0));
    if (!IsValidSurvivor(victim) || !ShouldUseSurvivor(victim))
    {
        return;
    }

    float now = GetEngineTime();
    float victimPos[3];
    GetClientAbsOrigin(victim, victimPos);

    int bestSlot = -1;
    float bestDist = 999999999.0;
    float window = g_hBoomerWindow.FloatValue + 0.05;
    float maxDist = g_hBoomerMaxDistance.FloatValue;

    for (int i = 0; i < MAX_BOOMER_RECORDS; i++)
    {
        if (!g_bBoomerActive[i])
        {
            continue;
        }

        if (now - g_fBoomerTime[i] > window)
        {
            continue;
        }

        int killer = g_iBoomerKiller[i];
        if (!IsValidSurvivor(killer) || killer == victim)
        {
            continue;
        }

        float dist = GetVectorDistance(victimPos, g_fBoomerPos[i]);
        if (maxDist > 0.0 && dist > maxDist)
        {
            continue;
        }

        if (dist < bestDist)
        {
            bestDist = dist;
            bestSlot = i;
        }
    }

    if (bestSlot != -1)
    {
        g_bBoomerVictims[bestSlot][victim] = true;
    }
}

public void L4D_OnVomitedUpon_Post(int victim, int attacker, bool boomerExplosion)
{
    // The friendly bile-jar plugin invokes this with boomerExplosion=false.
    // Keep the existing Boomer-death attribution independent from this announcement.
    if (!g_hEnable.BoolValue || !g_hBileJarEnable.BoolValue || boomerExplosion)
    {
        return;
    }

    if (!IsValidSurvivor(attacker) || !IsValidSurvivor(victim) || attacker == victim)
    {
        return;
    }

    if (!ShouldUseSurvivor(attacker) || !ShouldUseSurvivor(victim))
    {
        return;
    }

    PrintToChatAll("\x05%N\x01的胆汁瓶砸到了队友 \x03%N\x01！", attacker, victim);
}

public Action Timer_AnnounceBoomer(Handle timer, any slot)
{
    g_hBoomerTimer[slot] = null;

    if (!g_hEnable.BoolValue || !g_hBoomerEnable.BoolValue || !g_bBoomerActive[slot])
    {
        ResetBoomerRecord(slot);
        return Plugin_Stop;
    }

    int killer = g_iBoomerKiller[slot];
    if (!IsValidSurvivor(killer) || !ShouldUseSurvivor(killer))
    {
        ResetBoomerRecord(slot);
        return Plugin_Stop;
    }

    char list[256];
    int count = BuildBoomerVictimList(slot, list, sizeof(list));

    if (count >= g_hBoomerMinVictims.IntValue)
    {
        PrintToChatAll("\x05%N\x01打爆了 \x04Boomer\x01，顺手给 \x03%d\x01 个队友洗了澡：\x05%s", killer, count, list);
    }

    ResetBoomerRecord(slot);
    return Plugin_Stop;
}

int BuildBoomerVictimList(int slot, char[] buffer, int maxlen)
{
    buffer[0] = '\0';
    int count = 0;
    char name[MAX_NAME_LENGTH];

    for (int i = 1; i <= MaxClients; i++)
    {
        if (!g_bBoomerVictims[slot][i])
        {
            continue;
        }

        if (!IsValidSurvivor(i) || !ShouldUseSurvivor(i))
        {
            continue;
        }

        GetClientName(i, name, sizeof(name));

        if (count > 0)
        {
            StrCat(buffer, maxlen, "、");
        }

        StrCat(buffer, maxlen, name);
        count++;
    }

    return count;
}

public void Event_ChargerChargeStart(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_hEnable.BoolValue || !g_hChargerEnable.BoolValue)
    {
        return;
    }

    int charger = GetLikelyCharger(event);
    if (!IsValidInfected(charger) || GetZombieClass(charger) != ZC_CHARGER)
    {
        return;
    }

    ResetChargerRecord(charger);
    g_bChargerActive[charger] = true;
}

public void Event_ChargerImpact(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_hEnable.BoolValue || !g_hChargerEnable.BoolValue)
    {
        return;
    }

    int charger = GetLikelyCharger(event);
    int victim = GetLikelySurvivorVictim(event);

    if (!IsValidInfected(charger) || GetZombieClass(charger) != ZC_CHARGER)
    {
        return;
    }

    if (!IsValidSurvivor(victim) || !ShouldUseSurvivor(victim))
    {
        return;
    }

    if (!g_bChargerActive[charger])
    {
        g_bChargerActive[charger] = true;
    }

    g_bChargerBumped[charger][victim] = true;
}

public void Event_ChargerCarryOrPummelStart(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_hEnable.BoolValue || !g_hChargerEnable.BoolValue)
    {
        return;
    }

    int charger = GetLikelyCharger(event);
    int victim = GetLikelySurvivorVictim(event);

    if (!IsValidInfected(charger) || GetZombieClass(charger) != ZC_CHARGER)
    {
        return;
    }

    if (!g_bChargerActive[charger])
    {
        g_bChargerActive[charger] = true;
    }

    if (IsValidSurvivor(victim))
    {
        g_iChargerMainVictim[charger] = victim;
    }

    ScheduleChargerAnnouncement(charger);
}

public void Event_ChargerChargeEnd(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_hEnable.BoolValue || !g_hChargerEnable.BoolValue)
    {
        return;
    }

    int charger = GetLikelyCharger(event);
    if (!IsValidInfected(charger) || GetZombieClass(charger) != ZC_CHARGER)
    {
        return;
    }

    ScheduleChargerAnnouncement(charger);
}

void ScheduleChargerAnnouncement(int charger)
{
    if (charger < 1 || charger > MaxClients)
    {
        return;
    }

    if (g_bChargerAnnounced[charger])
    {
        return;
    }

    if (g_hChargerTimer[charger] != null)
    {
        return;
    }

    float delay = g_hChargerDelay.FloatValue;
    if (delay < 0.1)
    {
        delay = 0.1;
    }

    DataPack pack;
    g_hChargerTimer[charger] = CreateDataTimer(delay, Timer_AnnounceCharger, pack, TIMER_FLAG_NO_MAPCHANGE);
    pack.WriteCell(charger);
    pack.WriteCell(GetClientUserId(charger));
}

public Action Timer_AnnounceCharger(Handle timer, DataPack pack)
{
    pack.Reset();
    int charger = pack.ReadCell();
    int userid = pack.ReadCell();

    if (charger >= 1 && charger <= MaxClients)
    {
        if (g_hChargerTimer[charger] == timer)
        {
            g_hChargerTimer[charger] = null;
        }
        else if (g_hChargerTimer[charger] != null && !IsValidHandle(g_hChargerTimer[charger]))
        {
            g_hChargerTimer[charger] = null;
        }
    }

    if (!g_hEnable.BoolValue || !g_hChargerEnable.BoolValue)
    {
        return Plugin_Stop;
    }

    if (GetClientOfUserId(userid) != charger || !IsValidInfected(charger) || GetZombieClass(charger) != ZC_CHARGER)
    {
        return Plugin_Stop;
    }

    if (g_bChargerAnnounced[charger])
    {
        return Plugin_Stop;
    }

    char list[256];
    int count = BuildChargerBumpList(charger, list, sizeof(list));

    if (count >= g_hChargerMinBumps.IntValue)
    {
        int mainVictim = g_iChargerMainVictim[charger];
        if (IsValidSurvivor(mainVictim))
        {
            PrintToChatAll("\x04Charger\x01抓走了\x05%N\x01，顺路撞飞了 \x03%d\x01 个倒霉蛋：\x05%s", mainVictim, count, list);
        }
        else
        {
            PrintToChatAll("\x04Charger\x01一路横冲直撞，撞飞了 \x03%d\x01 个倒霉蛋：\x05%s", count, list);
        }
        g_bChargerAnnounced[charger] = true;
    }

    return Plugin_Stop;
}

int BuildChargerBumpList(int charger, char[] buffer, int maxlen)
{
    buffer[0] = '\0';
    int count = 0;
    int mainVictim = g_iChargerMainVictim[charger];
    char name[MAX_NAME_LENGTH];

    for (int i = 1; i <= MaxClients; i++)
    {
        if (!g_bChargerBumped[charger][i])
        {
            continue;
        }

        if (i == mainVictim)
        {
            continue;
        }

        if (!IsValidSurvivor(i) || !ShouldUseSurvivor(i))
        {
            continue;
        }

        GetClientName(i, name, sizeof(name));

        if (count > 0)
        {
            StrCat(buffer, maxlen, "、");
        }

        StrCat(buffer, maxlen, name);
        count++;
    }

    return count;
}

public void Event_WitchHarasserSet(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_hEnable.BoolValue || !g_hWitchEnable.BoolValue)
    {
        return;
    }

    int harasser = GetClientOfUserId(event.GetInt("userid", 0));
    if (!IsValidSurvivor(harasser) || !ShouldUseSurvivor(harasser))
    {
        return;
    }

    g_iWitchHarasser = harasser;
    g_iWitchEnt = event.GetInt("witchid", -1);
    g_fWitchHarassTime = GetEngineTime();
}

public void Event_PlayerIncapOrDeath(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_hEnable.BoolValue || !g_hWitchEnable.BoolValue)
    {
        return;
    }

    int victim = GetClientOfUserId(event.GetInt("userid", 0));
    TryAnnounceWitchBlame(victim);
}

void HandlePlayerWitchDeath(Event event)
{
    if (!g_hEnable.BoolValue || !g_hWitchEnable.BoolValue)
    {
        return;
    }

    int victim = GetClientOfUserId(event.GetInt("userid", 0));
    TryAnnounceWitchBlame(victim);
}

void TryAnnounceWitchBlame(int victim)
{
    if (!IsValidSurvivor(victim) || !ShouldUseSurvivor(victim))
    {
        return;
    }

    int harasser = g_iWitchHarasser;
    if (!IsValidSurvivor(harasser) || !ShouldUseSurvivor(harasser))
    {
        return;
    }

    if (harasser == victim)
    {
        return;
    }

    float now = GetEngineTime();

    if (now - g_fWitchHarassTime > g_hWitchWindow.FloatValue)
    {
        return;
    }

    if (now - g_fLastWitchDamageTime[victim] > g_hWitchDamageWindow.FloatValue)
    {
        return;
    }

    if (g_iWitchEnt > 0 && g_iLastWitchEntity[victim] > 0 && g_iWitchEnt != g_iLastWitchEntity[victim])
    {
        return;
    }

    if (now - g_fLastWitchAnnounceTime[victim] < 5.0)
    {
        return;
    }

    g_fLastWitchAnnounceTime[victim] = now;
    PrintToChatAll("\x05%N\x01惊扰了 \x04Witch\x01，结果\x05%N\x01替他付出了代价", harasser, victim);
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
    if (!g_hEnable.BoolValue || damage <= 0.0)
    {
        return Plugin_Continue;
    }

    TrackWitchDamage(victim, attacker, damage);
    TrackFriendlyFire(victim, attacker, damage, damagetype);

    return Plugin_Continue;
}

void TrackWitchDamage(int victim, int attacker, float damage)
{
    if (!g_hWitchEnable.BoolValue)
    {
        return;
    }

    if (!IsValidSurvivor(victim))
    {
        return;
    }

    if (attacker <= MaxClients || !IsValidEntity(attacker))
    {
        return;
    }

    char classname[64];
    GetEntityClassname(attacker, classname, sizeof(classname));

    if (StrContains(classname, "witch", false) == -1)
    {
        return;
    }

    g_fLastWitchDamageTime[victim] = GetEngineTime();
    g_iLastWitchEntity[victim] = attacker;
}

void TrackFriendlyFire(int victim, int attacker, float damage, int damagetype)
{
    if (!IsValidSurvivor(victim) || !IsValidSurvivor(attacker))
    {
        return;
    }

    if (victim == attacker)
    {
        return;
    }

    if (!ShouldUseSurvivor(attacker) || !ShouldUseSurvivor(victim))
    {
        return;
    }

    bool isFire = (damagetype & DMG_BURN) != 0;

    if (isFire)
    {
        if (!g_hFireEnable.BoolValue)
        {
            return;
        }

        g_fFireDamage[attacker] += damage;
        g_bFireVictims[attacker][victim] = true;

        if (g_hFireTimer[attacker] == null)
        {
            float window = g_hFireWindow.FloatValue;
            if (window < 0.1)
            {
                window = 0.1;
            }
            DataPack pack;
            g_hFireTimer[attacker] = CreateDataTimer(window, Timer_AnnounceFireFF, pack, TIMER_FLAG_NO_MAPCHANGE);
            pack.WriteCell(attacker);
            pack.WriteCell(GetClientUserId(attacker));
        }

        return;
    }

    if (!g_hFFEnable.BoolValue)
    {
        return;
    }

    g_fFFDamage[attacker] += damage;
    g_bFFVictims[attacker][victim] = true;

    if (g_hFFTimer[attacker] == null)
    {
        float window = g_hFFWindow.FloatValue;
        if (window < 0.1)
        {
            window = 0.1;
        }
        DataPack pack;
        g_hFFTimer[attacker] = CreateDataTimer(window, Timer_AnnounceHighFF, pack, TIMER_FLAG_NO_MAPCHANGE);
        pack.WriteCell(attacker);
        pack.WriteCell(GetClientUserId(attacker));
    }
}

public Action Timer_AnnounceFireFF(Handle timer, DataPack pack)
{
    pack.Reset();
    int attacker = pack.ReadCell();
    int userid = pack.ReadCell();

    if (attacker >= 1 && attacker <= MaxClients)
    {
        if (g_hFireTimer[attacker] == timer)
        {
            g_hFireTimer[attacker] = null;
        }
        else if (g_hFireTimer[attacker] != null && !IsValidHandle(g_hFireTimer[attacker]))
        {
            g_hFireTimer[attacker] = null;
        }
    }

    if (GetClientOfUserId(userid) != attacker || !g_hEnable.BoolValue || !g_hFireEnable.BoolValue || !IsValidSurvivor(attacker) || !ShouldUseSurvivor(attacker))
    {
        if (attacker >= 1 && attacker <= MaxClients)
        {
            ResetFireRecord(attacker);
        }
        return Plugin_Stop;
    }

    char list[256];
    int count = BuildFireVictimList(attacker, list, sizeof(list));
    float damage = g_fFireDamage[attacker];

    if (damage >= g_hFireThreshold.FloatValue && count > 0)
    {
        PrintToChatAll("\x05%N\x01这一把火烧得很有想法，\x03%d\x01 个队友合计吃了 \x03%.0f\x01 点火伤：\x05%s", attacker, count, damage, list);
    }

    ResetFireRecord(attacker);
    return Plugin_Stop;
}

public Action Timer_AnnounceHighFF(Handle timer, DataPack pack)
{
    pack.Reset();
    int attacker = pack.ReadCell();
    int userid = pack.ReadCell();

    if (attacker >= 1 && attacker <= MaxClients)
    {
        if (g_hFFTimer[attacker] == timer)
        {
            g_hFFTimer[attacker] = null;
        }
        else if (g_hFFTimer[attacker] != null && !IsValidHandle(g_hFFTimer[attacker]))
        {
            g_hFFTimer[attacker] = null;
        }
    }

    if (GetClientOfUserId(userid) != attacker || !g_hEnable.BoolValue || !g_hFFEnable.BoolValue || !IsValidSurvivor(attacker) || !ShouldUseSurvivor(attacker))
    {
        if (attacker >= 1 && attacker <= MaxClients)
        {
            ResetFFRecord(attacker);
        }
        return Plugin_Stop;
    }

    char list[256];
    int count = BuildFFVictimList(attacker, list, sizeof(list));
    float damage = g_fFFDamage[attacker];

    if (damage >= g_hFFThreshold.FloatValue && count > 0)
    {
        PrintToChatAll("\x05%N\x01火力全开，队友合计承受了 \x03%.0f\x01 点友伤：\x05%s", attacker, damage, list);
    }

    ResetFFRecord(attacker);
    return Plugin_Stop;
}

int BuildFireVictimList(int attacker, char[] buffer, int maxlen)
{
    buffer[0] = '\0';
    int count = 0;
    char name[MAX_NAME_LENGTH];

    for (int i = 1; i <= MaxClients; i++)
    {
        if (!g_bFireVictims[attacker][i])
        {
            continue;
        }

        if (!IsValidSurvivor(i) || !ShouldUseSurvivor(i))
        {
            continue;
        }

        GetClientName(i, name, sizeof(name));
        if (count > 0)
        {
            StrCat(buffer, maxlen, "、");
        }
        StrCat(buffer, maxlen, name);
        count++;
    }

    return count;
}

int BuildFFVictimList(int attacker, char[] buffer, int maxlen)
{
    buffer[0] = '\0';
    int count = 0;
    char name[MAX_NAME_LENGTH];

    for (int i = 1; i <= MaxClients; i++)
    {
        if (!g_bFFVictims[attacker][i])
        {
            continue;
        }

        if (!IsValidSurvivor(i) || !ShouldUseSurvivor(i))
        {
            continue;
        }

        GetClientName(i, name, sizeof(name));
        if (count > 0)
        {
            StrCat(buffer, maxlen, "、");
        }
        StrCat(buffer, maxlen, name);
        count++;
    }

    return count;
}

int GetLikelyCharger(Event event)
{
    int attacker = GetClientOfUserId(event.GetInt("attacker", 0));
    if (IsValidInfected(attacker) && GetZombieClass(attacker) == ZC_CHARGER)
    {
        return attacker;
    }

    int userid = GetClientOfUserId(event.GetInt("userid", 0));
    if (IsValidInfected(userid) && GetZombieClass(userid) == ZC_CHARGER)
    {
        return userid;
    }

    int charger = GetClientOfUserId(event.GetInt("charger", 0));
    if (IsValidInfected(charger) && GetZombieClass(charger) == ZC_CHARGER)
    {
        return charger;
    }

    return 0;
}

int GetLikelySurvivorVictim(Event event)
{
    int victim = GetClientOfUserId(event.GetInt("victim", 0));
    if (IsValidSurvivor(victim))
    {
        return victim;
    }

    int userid = GetClientOfUserId(event.GetInt("userid", 0));
    if (IsValidSurvivor(userid))
    {
        return userid;
    }

    return 0;
}

int GetZombieClass(int client)
{
    if (!IsValidClient(client))
    {
        return 0;
    }

    if (!HasEntProp(client, Prop_Send, "m_zombieClass"))
    {
        return 0;
    }

    return GetEntProp(client, Prop_Send, "m_zombieClass");
}

bool ShouldUseSurvivor(int client)
{
    if (!IsValidClient(client))
    {
        return false;
    }

    if (!g_hIncludeBots.BoolValue && IsFakeClient(client))
    {
        return false;
    }

    return true;
}

bool IsValidSurvivor(int client)
{
    return IsValidClient(client) && GetClientTeam(client) == TEAM_SURVIVOR;
}

bool IsValidInfected(int client)
{
    return IsValidClient(client) && GetClientTeam(client) == TEAM_INFECTED;
}

bool IsValidClient(int client)
{
    return client > 0 && client <= MaxClients && IsClientInGame(client);
}
