#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#define TEAM_SURVIVOR 2
#define MAX_TRACKED_ENTS 2049

int g_iProjRef[MAX_TRACKED_ENTS];
int g_iProjOwner[MAX_TRACKED_ENTS];
float g_fProjLastPos[MAX_TRACKED_ENTS][3];

ConVar g_hEnable;
ConVar g_hRadius;
ConVar g_hAffectThrower;
ConVar g_hAffectBots;
ConVar g_hRequireLOS;
ConVar g_hAllowBotThrower;

public Plugin myinfo =
{
    name = "L4D2 Bile Jar Friendly Fire",
    author = "night",
    description = "Allows bile jar explosions to vomit nearby survivor teammates like normal Boomer bile.",
    version = "1.0.0",
    url = ""
};

public void OnPluginStart()
{
    EngineVersion engine = GetEngineVersion();
    if (engine != Engine_Left4Dead2)
    {
        SetFailState("This plugin only supports Left 4 Dead 2.");
    }

    g_hEnable = CreateConVar(
        "l4d2_bileff_enable",
        "1",
        "0=Disable, 1=Enable bile jar friendly vomit.",
        FCVAR_NOTIFY,
        true, 0.0,
        true, 1.0
    );

    g_hRadius = CreateConVar(
        "l4d2_bileff_radius",
        "250.0",
        "Explosion radius used to vomit survivor teammates.",
        FCVAR_NOTIFY,
        true, 1.0
    );

    g_hAffectThrower = CreateConVar(
        "l4d2_bileff_affect_thrower",
        "0",
        "0=Do not vomit the thrower, 1=Thrower can also be vomited.",
        FCVAR_NOTIFY,
        true, 0.0,
        true, 1.0
    );

    g_hAffectBots = CreateConVar(
        "l4d2_bileff_affect_bots",
        "1",
        "0=Ignore survivor bots as victims, 1=Survivor bots can be vomited.",
        FCVAR_NOTIFY,
        true, 0.0,
        true, 1.0
    );

    g_hAllowBotThrower = CreateConVar(
        "l4d2_bileff_allow_bot_thrower",
        "1",
        "0=Ignore bile jars thrown by survivor bots, 1=Allow bot throwers.",
        FCVAR_NOTIFY,
        true, 0.0,
        true, 1.0
    );

    g_hRequireLOS = CreateConVar(
        "l4d2_bileff_require_los",
        "0",
        "0=Radius only, 1=Require line of sight from bile explosion to survivor.",
        FCVAR_NOTIFY,
        true, 0.0,
        true, 1.0
    );

    AutoExecConfig(true, "l4d2_bile_jar_friendly_fire");
}

public void OnMapStart()
{
    ResetTrackedProjectiles();
}

public void OnMapEnd()
{
    ResetTrackedProjectiles();
}

public void OnEntityCreated(int entity, const char[] classname)
{
    if (!g_hEnable.BoolValue)
    {
        return;
    }

    if (entity <= MaxClients || entity >= MAX_TRACKED_ENTS)
    {
        return;
    }

    if (!StrEqual(classname, "vomitjar_projectile", false))
    {
        return;
    }

    g_iProjRef[entity] = EntIndexToEntRef(entity);
    g_iProjOwner[entity] = 0;
    g_fProjLastPos[entity][0] = 0.0;
    g_fProjLastPos[entity][1] = 0.0;
    g_fProjLastPos[entity][2] = 0.0;

    DataPack pack = new DataPack();
    pack.WriteCell(entity);
    pack.WriteCell(g_iProjRef[entity]);

    CreateTimer(0.05, Timer_TrackVomitJar, pack, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_TrackVomitJar(Handle timer, DataPack pack)
{
    pack.Reset();

    int index = pack.ReadCell();
    int ref = pack.ReadCell();

    if (index <= MaxClients || index >= MAX_TRACKED_ENTS)
    {
        delete pack;
        return Plugin_Stop;
    }

    // If this entity slot was reused by another projectile, stop this old timer.
    if (g_iProjRef[index] != ref)
    {
        delete pack;
        return Plugin_Stop;
    }

    int entity = EntRefToEntIndex(ref);

    if (entity != INVALID_ENT_REFERENCE && IsValidEntity(entity))
    {
        GetEntPropVector(entity, Prop_Send, "m_vecOrigin", g_fProjLastPos[index]);

        if (!IsValidSurvivor(g_iProjOwner[index]))
        {
            int owner = GetProjectileOwner(entity);
            if (IsValidSurvivor(owner))
            {
                g_iProjOwner[index] = owner;
            }
        }

        return Plugin_Continue;
    }

    int owner = g_iProjOwner[index];
    float pos[3];
    pos[0] = g_fProjLastPos[index][0];
    pos[1] = g_fProjLastPos[index][1];
    pos[2] = g_fProjLastPos[index][2];

    g_iProjRef[index] = 0;
    g_iProjOwner[index] = 0;
    g_fProjLastPos[index][0] = 0.0;
    g_fProjLastPos[index][1] = 0.0;
    g_fProjLastPos[index][2] = 0.0;

    delete pack;

    if (g_hEnable.BoolValue)
    {
        ApplyBileToSurvivors(owner, pos);
    }

    return Plugin_Stop;
}

void ApplyBileToSurvivors(int thrower, const float explosionPos[3])
{
    if (!IsValidSurvivor(thrower))
    {
        return;
    }

    if (IsFakeClient(thrower) && !g_hAllowBotThrower.BoolValue)
    {
        return;
    }

    if (explosionPos[0] == 0.0 && explosionPos[1] == 0.0 && explosionPos[2] == 0.0)
    {
        return;
    }

    float radius = g_hRadius.FloatValue;
    bool affectThrower = g_hAffectThrower.BoolValue;
    bool affectBots = g_hAffectBots.BoolValue;
    bool requireLOS = g_hRequireLOS.BoolValue;

    float targetPos[3];

    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsValidSurvivor(client))
        {
            continue;
        }

        if (!affectThrower && client == thrower)
        {
            continue;
        }

        if (!affectBots && IsFakeClient(client))
        {
            continue;
        }

        GetClientAbsOrigin(client, targetPos);

        if (GetVectorDistance(explosionPos, targetPos) > radius)
        {
            continue;
        }

        if (requireLOS && !HasExplosionLineOfSight(explosionPos, client))
        {
            continue;
        }

        // Left4DHooks native. This applies the same vomit/IT state used by Boomer bile.
        L4D_CTerrorPlayer_OnVomitedUpon(client, thrower);
    }
}

int GetProjectileOwner(int entity)
{
    int owner = -1;

    if (HasEntProp(entity, Prop_Send, "m_hOwnerEntity"))
    {
        owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
    }

    if (!IsValidSurvivor(owner) && HasEntProp(entity, Prop_Data, "m_hOwnerEntity"))
    {
        owner = GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity");
    }

    return owner;
}

bool HasExplosionLineOfSight(const float explosionPos[3], int client)
{
    float start[3];
    start[0] = explosionPos[0];
    start[1] = explosionPos[1];
    start[2] = explosionPos[2] + 10.0;

    float end[3];
    GetClientAbsOrigin(client, end);
    end[2] += 40.0;

    Handle trace = TR_TraceRayFilterEx(start, end, MASK_SOLID, RayType_EndPoint, TraceFilter_IgnorePlayers);
    bool blocked = TR_DidHit(trace);
    delete trace;

    return !blocked;
}

public bool TraceFilter_IgnorePlayers(int entity, int contentsMask)
{
    if (entity >= 1 && entity <= MaxClients)
    {
        return false;
    }

    return true;
}

bool IsValidSurvivor(int client)
{
    return client > 0
        && client <= MaxClients
        && IsClientInGame(client)
        && GetClientTeam(client) == TEAM_SURVIVOR
        && IsPlayerAlive(client);
}

void ResetTrackedProjectiles()
{
    for (int i = 0; i < MAX_TRACKED_ENTS; i++)
    {
        g_iProjRef[i] = 0;
        g_iProjOwner[i] = 0;
        g_fProjLastPos[i][0] = 0.0;
        g_fProjLastPos[i][1] = 0.0;
        g_fProjLastPos[i][2] = 0.0;
    }
}
