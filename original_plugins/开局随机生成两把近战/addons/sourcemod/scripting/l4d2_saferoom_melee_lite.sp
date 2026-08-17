#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "1.1.0"
#define MAX_MELEE_CLASSES 64
#define FALLBACK_MELEE_COUNT 9

static const char g_sFallbackMelee[FALLBACK_MELEE_COUNT][32] =
{
    "fireaxe",
    "frying_pan",
    "machete",
    "baseball_bat",
    "crowbar",
    "cricket_bat",
    "electric_guitar",
    "katana",
    "tonfa"
};

ConVar g_cvEnabled;
ConVar g_cvThreshold;
ConVar g_cvLowAmount;
ConVar g_cvHighAmount;

bool g_bSpawnedThisRound;
int g_iRoundSerial;

char g_sMeleeClasses[MAX_MELEE_CLASSES][32];
int g_iMeleeClassCount;
bool g_bUsingFallbackList;

public Plugin myinfo =
{
    name = "L4D2 Saferoom Melee Lite",
    author = "N3wton, night",
    description = "Spawns 1 or 2 random melee weapons near survivors at round start based on survivor count.",
    version = PLUGIN_VERSION,
    url = ""
};

public void OnPluginStart()
{
    char game[16];
    GetGameFolderName(game, sizeof(game));
    if (!StrEqual(game, "left4dead2", false))
    {
        SetFailState("This plugin only supports Left 4 Dead 2.");
    }

    CreateConVar("l4d2_mitsr_lite_version", PLUGIN_VERSION, "Plugin version.", FCVAR_NOTIFY | FCVAR_DONTRECORD);
    g_cvEnabled = CreateConVar("l4d2_mitsr_lite_enabled", "1", "Enable saferoom melee spawning. 0=Off, 1=On.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvThreshold = CreateConVar("l4d2_mitsr_lite_threshold", "6", "At or below this survivor count, use the low amount; above it, use the high amount.", FCVAR_NOTIFY, true, 1.0);
    g_cvLowAmount = CreateConVar("l4d2_mitsr_lite_low_amount", "1", "Number of melee weapons to spawn when survivor count is at or below the threshold.", FCVAR_NOTIFY, true, 0.0, true, 2.0);
    g_cvHighAmount = CreateConVar("l4d2_mitsr_lite_high_amount", "2", "Number of melee weapons to spawn when survivor count is above the threshold.", FCVAR_NOTIFY, true, 0.0, true, 2.0);

    HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
    HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);

    RegAdminCmd("sm_melee", Command_ListMelee, ADMFLAG_KICK, "Lists melee weapon scripts available on the current map.");

    AutoExecConfig(true, "l4d2_saferoom_melee_lite");
}

public void OnMapStart()
{
    g_bSpawnedThisRound = false;
    g_iRoundSerial++;
    RefreshMeleeClasses();
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_cvEnabled.BoolValue)
        return;

    g_bSpawnedThisRound = false;
    g_iRoundSerial++;
    RefreshMeleeClasses();

    // Usually survivors already exist shortly after round_start.
    // player_spawn below is kept only as a lightweight fallback.
    CreateTimer(1.0, Timer_TrySpawn, g_iRoundSerial, TIMER_FLAG_NO_MAPCHANGE);
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_cvEnabled.BoolValue || g_bSpawnedThisRound)
        return;

    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!IsSurvivor(client))
        return;

    CreateTimer(0.3, Timer_TrySpawn, g_iRoundSerial, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_TrySpawn(Handle timer, any serial)
{
    if (serial != g_iRoundSerial || g_bSpawnedThisRound || !g_cvEnabled.BoolValue)
        return Plugin_Stop;

    int anchor = GetAliveSurvivor();
    if (anchor == 0)
        return Plugin_Stop;

    if (g_iMeleeClassCount <= 0)
        RefreshMeleeClasses();

    if (g_iMeleeClassCount <= 0)
    {
        LogError("No melee scripts are available, including the built-in fallback list; nothing was spawned.");
        return Plugin_Stop;
    }

    int survivorCount = GetSurvivorCount();
    int amount = (survivorCount <= g_cvThreshold.IntValue) ? g_cvLowAmount.IntValue : g_cvHighAmount.IntValue;

    if (amount <= 0)
    {
        g_bSpawnedThisRound = true;
        return Plugin_Stop;
    }

    float pos[3];
    float ang[3];
    GetClientAbsOrigin(anchor, pos);
    pos[2] += 20.0;
    ang[0] = 90.0;

    int first = GetRandomInt(0, g_iMeleeClassCount - 1);
    SpawnMelee(g_sMeleeClasses[first], pos, ang);

    if (amount >= 2)
    {
        int second = first;

        // Prefer two different melee types when the map offers more than one.
        if (g_iMeleeClassCount > 1)
        {
            while (second == first)
            {
                second = GetRandomInt(0, g_iMeleeClassCount - 1);
            }
        }

        SpawnMelee(g_sMeleeClasses[second], pos, ang);
    }

    g_bSpawnedThisRound = true;
    LogMessage("Spawned %d saferoom melee weapon(s) for %d survivor(s).", amount, survivorCount);

    return Plugin_Stop;
}

public Action Command_ListMelee(int client, int args)
{
    RefreshMeleeClasses();

    if (g_iMeleeClassCount <= 0)
    {
        ReplyToCommand(client, "[MITSR Lite] No melee scripts found on this map.");
        return Plugin_Handled;
    }

    ReplyToCommand(client, "[MITSR Lite] Available melee scripts: %d%s", g_iMeleeClassCount, g_bUsingFallbackList ? " (built-in fallback)" : "");
    for (int i = 0; i < g_iMeleeClassCount; i++)
    {
        ReplyToCommand(client, "%d: %s", i, g_sMeleeClasses[i]);
    }

    return Plugin_Handled;
}

void SpawnMelee(const char[] scriptName, const float basePos[3], const float baseAng[3])
{
    float pos[3];
    float ang[3];

    pos = basePos;
    ang = baseAng;

    pos[0] += GetRandomFloat(-10.0, 10.0);
    pos[1] += GetRandomFloat(-10.0, 10.0);
    pos[2] += GetRandomFloat(0.0, 10.0);
    ang[1] = GetRandomFloat(0.0, 360.0);

    int weapon = CreateEntityByName("weapon_melee");
    if (weapon == -1)
    {
        LogError("Failed to create weapon_melee for script '%s'.", scriptName);
        return;
    }

    DispatchKeyValue(weapon, "melee_script_name", scriptName);

    if (!DispatchSpawn(weapon))
    {
        LogError("Failed to spawn weapon_melee for script '%s'.", scriptName);
        RemoveEntity(weapon);
        return;
    }

    TeleportEntity(weapon, pos, ang, NULL_VECTOR);
}

void RefreshMeleeClasses()
{
    g_iMeleeClassCount = 0;
    g_bUsingFallbackList = false;

    int table = FindStringTable("MeleeWeapons");
    if (table != INVALID_STRING_TABLE)
    {
        int count = GetStringTableNumStrings(table);
        char melee[32];

        for (int i = 0; i < count && g_iMeleeClassCount < MAX_MELEE_CLASSES; i++)
        {
            ReadStringTable(table, i, melee, sizeof(melee));
            AddMeleeClass(melee);
        }
    }

    // Secondary source for servers that expose an explicit melee list.
    if (g_iMeleeClassCount == 0)
    {
        ConVar meleeSpawn = FindConVar("l4d2_melee_spawn");
        if (meleeSpawn != null)
        {
            char list[1024];
            meleeSpawn.GetString(list, sizeof(list));
            ReplaceString(list, sizeof(list), " ", "");

            if (list[0] != '\0')
            {
                char parts[MAX_MELEE_CLASSES][32];
                int count = ExplodeString(list, ",", parts, sizeof(parts), sizeof(parts[]));

                for (int i = 0; i < count && g_iMeleeClassCount < MAX_MELEE_CLASSES; i++)
                {
                    AddMeleeClass(parts[i]);
                }
            }
        }
    }

    // If the map exposes no melee list at all, guarantee our round-start bonus
    // by falling back to a conservative set of stock L4D2 melee scripts.
    if (g_iMeleeClassCount == 0)
    {
        g_bUsingFallbackList = true;

        for (int i = 0; i < FALLBACK_MELEE_COUNT; i++)
        {
            AddMeleeClass(g_sFallbackMelee[i]);
        }

        LogMessage("No map melee list found; using built-in fallback melee pool (%d scripts).", g_iMeleeClassCount);
    }
}

void AddMeleeClass(const char[] melee)
{
    if (melee[0] == '\0' || g_iMeleeClassCount >= MAX_MELEE_CLASSES)
        return;

    for (int i = 0; i < g_iMeleeClassCount; i++)
    {
        if (StrEqual(g_sMeleeClasses[i], melee, false))
            return;
    }

    strcopy(g_sMeleeClasses[g_iMeleeClassCount], sizeof(g_sMeleeClasses[]), melee);
    g_iMeleeClassCount++;
}

int GetAliveSurvivor()
{
    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsSurvivor(client) && IsPlayerAlive(client))
            return client;
    }

    return 0;
}

int GetSurvivorCount()
{
    int count = 0;

    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsSurvivor(client))
            count++;
    }

    return count;
}

bool IsSurvivor(int client)
{
    return client > 0
        && client <= MaxClients
        && IsClientInGame(client)
        && GetClientTeam(client) == 2;
}
