#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3

#define ZC_SMOKER  1
#define ZC_BOOMER  2
#define ZC_HUNTER  3
#define ZC_SPITTER 4
#define ZC_JOCKEY  5
#define ZC_CHARGER 6

#define CHARGER_PUNCH_BASE_DAMAGE 10.0
#define DAMAGE_EPSILON 0.01

#if !defined DMG_SLASH
#define DMG_SLASH (1 << 2)
#endif

#if !defined DMG_CLUB
#define DMG_CLUB (1 << 7)
#endif

ConVar g_hEnable;
ConVar g_hModes;
ConVar g_hStrictInflictor;
ConVar g_hStrictDamageType;
ConVar g_hGameMode;

ConVar g_hSmoker;
ConVar g_hBoomer;
ConVar g_hHunter;
ConVar g_hSpitter;
ConVar g_hJockey;
ConVar g_hCharger;

public Plugin myinfo =
{
    name = "L4D2 Claw Damage Only",
    author = "night",
    description = "Modify only SI claw / Charger punch damage without touching pin/control damage.",
    version = "1.0.2",
    url = ""
};

public void OnPluginStart()
{
    g_hEnable = CreateConVar(
        "l4d2_clawdmg_enable",
        "1",
        "0=Disable, 1=Enable."
    );

    g_hModes = CreateConVar(
        "l4d2_clawdmg_modes",
        "coop,realism",
        "Game modes allowed. Empty = all modes. Example: coop,realism,survival"
    );

    g_hStrictInflictor = CreateConVar(
        "l4d2_clawdmg_strict_inflictor",
        "1",
        "1=Only modify damage when inflictor is the attacker itself. Safer. If plugin does not work, try 0."
    );

    g_hStrictDamageType = CreateConVar(
        "l4d2_clawdmg_strict_damagetype",
        "0",
        "1=Only modify DMG_SLASH/DMG_CLUB. Safer but may miss some L4D2 claw hits."
    );

    // -1.0 = do not modify this class
    g_hSmoker = CreateConVar("l4d2_clawdmg_smoker",  "4.0",  "Smoker normal claw damage. -1 = ignore.");
    g_hBoomer = CreateConVar("l4d2_clawdmg_boomer",  "4.0",  "Boomer normal claw damage. -1 = ignore.");
    g_hHunter = CreateConVar("l4d2_clawdmg_hunter",  "6.0",  "Hunter normal claw damage. -1 = ignore.");
    g_hSpitter = CreateConVar("l4d2_clawdmg_spitter", "4.0", "Spitter normal claw damage. -1 = ignore.");
    g_hJockey = CreateConVar("l4d2_clawdmg_jockey",  "4.0",  "Jockey normal claw damage. -1 = ignore.");
    g_hCharger = CreateConVar("l4d2_clawdmg_charger", "7.0", "Charger normal punch damage. -1 = ignore.");

    g_hGameMode = FindConVar("mp_gamemode");

    AutoExecConfig(true, "l4d2_claw_damage_only");

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

public Action OnTakeDamage(
    int victim,
    int &attacker,
    int &inflictor,
    float &damage,
    int &damagetype,
    int &weapon,
    float damageForce[3],
    float damagePosition[3]
)
{
    if (!g_hEnable.BoolValue || damage <= 0.0)
    {
        return Plugin_Continue;
    }

    if (!IsAllowedGameMode())
    {
        return Plugin_Continue;
    }

    if (!IsValidClient(victim) || !IsValidClient(attacker))
    {
        return Plugin_Continue;
    }

    if (GetClientTeam(victim) != TEAM_SURVIVOR || GetClientTeam(attacker) != TEAM_INFECTED)
    {
        return Plugin_Continue;
    }

    int zombieClass = GetEntProp(attacker, Prop_Send, "m_zombieClass");

    if (zombieClass < ZC_SMOKER || zombieClass > ZC_CHARGER)
    {
        return Plugin_Continue;
    }

    // 核心：如果这是控人/技能过程中的伤害，直接放行，不改。
    if (IsControlDamage(attacker, victim, zombieClass))
    {
        return Plugin_Continue;
    }

    // Charger 的 SDKHooks weapon 参数在普通拳击时也可能无效，不能据此识别。
    // 普通拳击的原始伤害是 10 且带有伤害力；以下技能伤害直接放行：
    // - 只撞墙震到附近玩家：原始 2 点；
    // - 抓人撞停：可能为 10 点，但伤害力向量为零；
    // - 锤击：由上面的控制状态检查排除。
    if (zombieClass == ZC_CHARGER && !IsChargerPunchDamage(damage, damageForce))
    {
        return Plugin_Continue;
    }

    // 更保守：普通爪击/拳击通常 inflictor 就是 attacker。
    // 如果你测试发现完全不生效，把 l4d2_clawdmg_strict_inflictor 改成 0。
    if (g_hStrictInflictor.BoolValue && inflictor != attacker)
    {
        return Plugin_Continue;
    }

    // 可选严格伤害类型判断。默认关闭，避免漏判。
    if (g_hStrictDamageType.BoolValue)
    {
        if ((damagetype & DMG_SLASH) == 0 && (damagetype & DMG_CLUB) == 0)
        {
            return Plugin_Continue;
        }
    }

    float newDamage = GetDamageForClass(zombieClass);

    if (newDamage < 0.0)
    {
        return Plugin_Continue;
    }

    damage = newDamage;
    return Plugin_Changed;
}

float GetDamageForClass(int zombieClass)
{
    switch (zombieClass)
    {
        case ZC_SMOKER:
        {
            return g_hSmoker.FloatValue;
        }
        case ZC_BOOMER:
        {
            return g_hBoomer.FloatValue;
        }
        case ZC_HUNTER:
        {
            return g_hHunter.FloatValue;
        }
        case ZC_SPITTER:
        {
            return g_hSpitter.FloatValue;
        }
        case ZC_JOCKEY:
        {
            return g_hJockey.FloatValue;
        }
        case ZC_CHARGER:
        {
            return g_hCharger.FloatValue;
        }
    }

    return -1.0;
}

bool IsControlDamage(int attacker, int victim, int zombieClass)
{
    switch (zombieClass)
    {
        case ZC_SMOKER:
        {
            if (GetClientPropEntSafe(attacker, "m_tongueVictim") == victim)
            {
                return true;
            }
        }

        case ZC_HUNTER:
        {
            if (GetClientPropEntSafe(attacker, "m_pounceVictim") == victim)
            {
                return true;
            }
        }

        case ZC_JOCKEY:
        {
            if (GetClientPropEntSafe(attacker, "m_jockeyVictim") == victim)
            {
                return true;
            }
        }

        case ZC_CHARGER:
        {
            if (GetClientPropEntSafe(attacker, "m_pummelVictim") == victim)
            {
                return true;
            }

            if (GetClientPropEntSafe(attacker, "m_carryVictim") == victim)
            {
                return true;
            }

            // Charger 正在冲锋时也不改，避免误伤 charge/carry/collision 伤害。
            int ability = GetEntPropEnt(attacker, Prop_Send, "m_customAbility");
            if (ability > MaxClients && IsValidEntity(ability))
            {
                if (HasEntProp(ability, Prop_Send, "m_isCharging"))
                {
                    if (GetEntProp(ability, Prop_Send, "m_isCharging") > 0)
                    {
                        return true;
                    }
                }
            }
        }
    }

    return false;
}

bool IsChargerPunchDamage(float damage, const float damageForce[3])
{
    if (FloatAbs(damage - CHARGER_PUNCH_BASE_DAMAGE) > DAMAGE_EPSILON)
    {
        return false;
    }

    return GetVectorLength(damageForce) > 0.0;
}

int GetClientPropEntSafe(int client, const char[] prop)
{
    if (!HasEntProp(client, Prop_Send, prop))
    {
        return -1;
    }

    return GetEntPropEnt(client, Prop_Send, prop);
}

bool IsAllowedGameMode()
{
    if (g_hGameMode == null)
    {
        return true;
    }

    char allowedModes[256];
    g_hModes.GetString(allowedModes, sizeof(allowedModes));

    if (allowedModes[0] == '\0')
    {
        return true;
    }

    char currentMode[64];
    g_hGameMode.GetString(currentMode, sizeof(currentMode));

    char haystack[300];
    char needle[80];

    Format(haystack, sizeof(haystack), ",%s,", allowedModes);
    Format(needle, sizeof(needle), ",%s,", currentMode);

    ReplaceString(haystack, sizeof(haystack), " ", "", false);

    return StrContains(haystack, needle, false) != -1;
}

bool IsValidClient(int client)
{
    return client > 0 && client <= MaxClients && IsClientInGame(client);
}
