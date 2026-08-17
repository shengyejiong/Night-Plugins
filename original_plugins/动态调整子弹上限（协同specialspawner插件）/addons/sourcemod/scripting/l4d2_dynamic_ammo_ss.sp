#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

#define PLUGIN_VERSION "1.1.0"

public Plugin myinfo =
{
    name        = "L4D2 Dynamic Ammo - Special Spawner",
    author      = "morzlee, night",
    description = "Adjusts reserve-ammo maximums from Special Spawner ss_spawn_size without refilling current ammo.",
    version     = PLUGIN_VERSION,
    url         = ""
};

// Special Spawner external cvar.
ConVar g_cvSpawnSize = null;
bool   g_bSpawnSizeHooked = false;
bool   g_bWarnedMissingSpawner = false;

// Plugin settings.
ConVar g_cvEnable;
ConVar g_cvBaseSpawnSize;       // Spawn size at which minimum multiplier is used.
ConVar g_cvMinMultiplier;       // Default 1.5x.
ConVar g_cvStepMultiplier;      // +0.2x for each SI above base spawn size.
ConVar g_cvMaxMultiplier;       // Default 2.5x.
ConVar g_cvSniperLowMultiplier; // Hunting/sniper multiplier below high-pressure threshold.
ConVar g_cvSniperHighMultiplier;// Hunting/sniper multiplier at/above high-pressure threshold.
ConVar g_cvSniperHighSpawnSize; // ss_spawn_size threshold for sniper high multiplier.
ConVar g_cvGrenadeFixedAmmo;    // Fixed grenade launcher reserve ammo while enabled.
ConVar g_cvHardCap;             // 0 = unlimited; useful if HUD >999 is undesirable.
ConVar g_cvDebug;

// Original/base reserve ammo values.
ConVar g_cvBaseRifle;
ConVar g_cvBaseAutoShotgun;
ConVar g_cvBaseGrenadeLauncher;
ConVar g_cvBaseShotgun;
ConVar g_cvBaseHuntingRifle;
ConVar g_cvBaseSMG;
ConVar g_cvBaseSniper;

// Game reserve-ammo maximum cvars.
ConVar g_cvAmmoRifle = null;
ConVar g_cvAmmoAutoShotgun = null;
ConVar g_cvAmmoGrenadeLauncher = null;
ConVar g_cvAmmoShotgun = null;
ConVar g_cvAmmoHuntingRifle = null;
ConVar g_cvAmmoSMG = null;
ConVar g_cvAmmoSniper = null;

float g_fCurrentMultiplier = 1.0;
float g_fCurrentSniperMultiplier = 1.0;
int   g_iCurrentSpawnSize = 0;

void DebugLog(const char[] format, any ...)
{
    if (g_cvDebug == null || !g_cvDebug.BoolValue)
        return;

    char buffer[256];
    VFormat(buffer, sizeof(buffer), format, 2);
    PrintToServer("[DynAmmoSS] %s", buffer);
}

public void OnPluginStart()
{
    CreateConVar(
        "l4d2_dynamic_ammo_ss_version",
        PLUGIN_VERSION,
        "L4D2 Dynamic Ammo - Special Spawner version",
        FCVAR_NOTIFY | FCVAR_DONTRECORD
    );

    g_cvEnable = CreateConVar(
        "l4d2_dynamic_ammo_ss_enable",
        "1",
        "Enable dynamic reserve-ammo maximums. 0=off, 1=on",
        FCVAR_NOTIFY,
        true, 0.0,
        true, 1.0
    );

    g_cvBaseSpawnSize = CreateConVar(
        "l4d2_dynamic_ammo_ss_base_spawn_size",
        "5",
        "ss_spawn_size that corresponds to the minimum ammo multiplier",
        FCVAR_NOTIFY,
        true, 1.0,
        true, 32.0
    );

    g_cvMinMultiplier = CreateConVar(
        "l4d2_dynamic_ammo_ss_min_mult",
        "1.5",
        "Minimum reserve-ammo multiplier for SMG/rifle/shotguns",
        FCVAR_NOTIFY,
        true, 0.1
    );

    g_cvStepMultiplier = CreateConVar(
        "l4d2_dynamic_ammo_ss_step_mult",
        "0.2",
        "Multiplier added for each +1 ss_spawn_size above base_spawn_size",
        FCVAR_NOTIFY,
        true, 0.0
    );

    g_cvMaxMultiplier = CreateConVar(
        "l4d2_dynamic_ammo_ss_max_mult",
        "2.5",
        "Maximum reserve-ammo multiplier for SMG/rifle/shotguns",
        FCVAR_NOTIFY,
        true, 0.1
    );

    g_cvSniperLowMultiplier = CreateConVar(
        "l4d2_dynamic_ammo_ss_sniper_low_mult",
        "1.5",
        "Hunting/sniper reserve-ammo multiplier below sniper_high_spawn_size",
        FCVAR_NOTIFY,
        true, 0.1
    );

    g_cvSniperHighMultiplier = CreateConVar(
        "l4d2_dynamic_ammo_ss_sniper_high_mult",
        "2.0",
        "Hunting/sniper reserve-ammo multiplier at or above sniper_high_spawn_size",
        FCVAR_NOTIFY,
        true, 0.1
    );

    g_cvSniperHighSpawnSize = CreateConVar(
        "l4d2_dynamic_ammo_ss_sniper_high_spawn_size",
        "9",
        "ss_spawn_size at which hunting/sniper reserve ammo switches to the high multiplier",
        FCVAR_NOTIFY,
        true, 1.0,
        true, 32.0
    );

    g_cvGrenadeFixedAmmo = CreateConVar(
        "l4d2_dynamic_ammo_ss_grenadelauncher_fixed",
        "20",
        "Fixed grenade launcher reserve ammo while dynamic ammo is enabled",
        FCVAR_NOTIFY,
        true, 0.0
    );

    g_cvHardCap = CreateConVar(
        "l4d2_dynamic_ammo_ss_hard_cap",
        "0",
        "Optional hard cap for every reserve-ammo maximum. 0=no cap; set 999 if HUD testing requires it",
        FCVAR_NOTIFY,
        true, 0.0
    );

    g_cvDebug = CreateConVar(
        "l4d2_dynamic_ammo_ss_debug",
        "0",
        "Print debug information to server console. 0=off, 1=on",
        FCVAR_NOTIFY,
        true, 0.0,
        true, 1.0
    );

    // L4D2 default reserve-ammo values.
    g_cvBaseRifle = CreateConVar(
        "l4d2_dynamic_ammo_ss_base_rifle",
        "360",
        "Base reserve ammo for assault rifles",
        FCVAR_NOTIFY,
        true, 0.0
    );

    g_cvBaseAutoShotgun = CreateConVar(
        "l4d2_dynamic_ammo_ss_base_autoshotgun",
        "90",
        "Base reserve ammo for auto shotguns / SPAS",
        FCVAR_NOTIFY,
        true, 0.0
    );

    g_cvBaseGrenadeLauncher = CreateConVar(
        "l4d2_dynamic_ammo_ss_base_grenadelauncher",
        "30",
        "Base reserve ammo for grenade launcher",
        FCVAR_NOTIFY,
        true, 0.0
    );

    g_cvBaseShotgun = CreateConVar(
        "l4d2_dynamic_ammo_ss_base_shotgun",
        "72",
        "Base reserve ammo for pump/chrome shotguns",
        FCVAR_NOTIFY,
        true, 0.0
    );

    g_cvBaseHuntingRifle = CreateConVar(
        "l4d2_dynamic_ammo_ss_base_huntingrifle",
        "150",
        "Base reserve ammo for hunting rifle",
        FCVAR_NOTIFY,
        true, 0.0
    );

    g_cvBaseSMG = CreateConVar(
        "l4d2_dynamic_ammo_ss_base_smg",
        "650",
        "Base reserve ammo for SMGs / MP5",
        FCVAR_NOTIFY,
        true, 0.0
    );

    g_cvBaseSniper = CreateConVar(
        "l4d2_dynamic_ammo_ss_base_sniperrifle",
        "180",
        "Base reserve ammo for military sniper / AWP / Scout",
        FCVAR_NOTIFY,
        true, 0.0
    );

    BindGameAmmoCvars();
    TryBindSpecialSpawner();

    // Recalculate if any of our settings change.
    g_cvEnable.AddChangeHook(OnSettingChanged);
    g_cvBaseSpawnSize.AddChangeHook(OnSettingChanged);
    g_cvMinMultiplier.AddChangeHook(OnSettingChanged);
    g_cvStepMultiplier.AddChangeHook(OnSettingChanged);
    g_cvMaxMultiplier.AddChangeHook(OnSettingChanged);
    g_cvSniperLowMultiplier.AddChangeHook(OnSettingChanged);
    g_cvSniperHighMultiplier.AddChangeHook(OnSettingChanged);
    g_cvSniperHighSpawnSize.AddChangeHook(OnSettingChanged);
    g_cvGrenadeFixedAmmo.AddChangeHook(OnSettingChanged);
    g_cvHardCap.AddChangeHook(OnSettingChanged);

    g_cvBaseRifle.AddChangeHook(OnSettingChanged);
    g_cvBaseAutoShotgun.AddChangeHook(OnSettingChanged);
    g_cvBaseGrenadeLauncher.AddChangeHook(OnSettingChanged);
    g_cvBaseShotgun.AddChangeHook(OnSettingChanged);
    g_cvBaseHuntingRifle.AddChangeHook(OnSettingChanged);
    g_cvBaseSMG.AddChangeHook(OnSettingChanged);
    g_cvBaseSniper.AddChangeHook(OnSettingChanged);

    RegAdminCmd("sm_da_status", Command_Status, ADMFLAG_GENERIC, "Show Special Spawner dynamic ammo status");
    RegAdminCmd("sm_da_recalc", Command_Recalc, ADMFLAG_GENERIC, "Rebind ss_spawn_size and recalculate ammo maximums");

    AutoExecConfig(true, "l4d2_dynamic_ammo_ss");
}

public void OnAllPluginsLoaded()
{
    TryBindSpecialSpawner();
}

public void OnMapStart()
{
    TryBindSpecialSpawner();
}

public void OnConfigsExecuted()
{
    // server.cfg and plugin cfg files have finished executing here.
    TryBindSpecialSpawner();
    ApplyDynamicAmmo();
}

public void OnPluginEnd()
{
    // Return the ammo maximums to configured base values when this plugin is unloaded.
    ApplyBaseAmmo();
}

void BindGameAmmoCvars()
{
    g_cvAmmoRifle           = FindConVar("ammo_assaultrifle_max");
    g_cvAmmoAutoShotgun     = FindConVar("ammo_autoshotgun_max");
    g_cvAmmoGrenadeLauncher = FindConVar("ammo_grenadelauncher_max");
    g_cvAmmoShotgun         = FindConVar("ammo_shotgun_max");
    g_cvAmmoHuntingRifle    = FindConVar("ammo_huntingrifle_max");
    g_cvAmmoSMG             = FindConVar("ammo_smg_max");
    g_cvAmmoSniper          = FindConVar("ammo_sniperrifle_max");
}

void TryBindSpecialSpawner()
{
    if (g_cvSpawnSize != null)
        return;

    ConVar cvar = FindConVar("ss_spawn_size");
    if (cvar == null)
    {
        if (!g_bWarnedMissingSpawner)
        {
            LogMessage("[DynAmmoSS] ss_spawn_size not found yet; using base_spawn_size until Special Spawner is available.");
            g_bWarnedMissingSpawner = true;
        }
        return;
    }

    g_cvSpawnSize = cvar;

    if (!g_bSpawnSizeHooked)
    {
        g_cvSpawnSize.AddChangeHook(OnSpawnSizeChanged);
        g_bSpawnSizeHooked = true;
    }

    g_bWarnedMissingSpawner = false;
    DebugLog("Bound to ss_spawn_size, current value = %d", g_cvSpawnSize.IntValue);
}

public void OnSpawnSizeChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    ApplyDynamicAmmo();
}

public void OnSettingChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (convar == g_cvEnable && !g_cvEnable.BoolValue)
    {
        ApplyBaseAmmo();
        return;
    }

    if (g_cvEnable.BoolValue)
        ApplyDynamicAmmo();
}

float CalculateMultiplier(int spawnSize)
{
    int baseSpawn = g_cvBaseSpawnSize.IntValue;
    float minMult = g_cvMinMultiplier.FloatValue;
    float maxMult = g_cvMaxMultiplier.FloatValue;
    float step = g_cvStepMultiplier.FloatValue;

    if (maxMult < minMult)
        maxMult = minMult;

    float multiplier = minMult;

    if (spawnSize > baseSpawn)
        multiplier += float(spawnSize - baseSpawn) * step;

    if (multiplier < minMult)
        multiplier = minMult;
    if (multiplier > maxMult)
        multiplier = maxMult;

    return multiplier;
}

float CalculateSniperMultiplier(int spawnSize)
{
    if (spawnSize >= g_cvSniperHighSpawnSize.IntValue)
        return g_cvSniperHighMultiplier.FloatValue;

    return g_cvSniperLowMultiplier.FloatValue;
}

int ApplyHardCap(int value)
{
    int hardCap = g_cvHardCap.IntValue;

    if (hardCap > 0 && value > hardCap)
        value = hardCap;

    if (value < 0)
        value = 0;

    return value;
}

int ScaleAmmo(int baseAmmo, float multiplier)
{
    return ApplyHardCap(RoundToNearest(float(baseAmmo) * multiplier));
}

void SetAmmoCvar(ConVar cvar, int value)
{
    if (cvar != null)
        cvar.IntValue = value;
}

void ApplyDynamicAmmo()
{
    if (g_cvEnable == null || !g_cvEnable.BoolValue)
        return;

    TryBindSpecialSpawner();

    int spawnSize = g_cvBaseSpawnSize.IntValue;
    if (g_cvSpawnSize != null)
        spawnSize = g_cvSpawnSize.IntValue;

    float multiplier = CalculateMultiplier(spawnSize);
    float sniperMultiplier = CalculateSniperMultiplier(spawnSize);

    g_iCurrentSpawnSize = spawnSize;
    g_fCurrentMultiplier = multiplier;
    g_fCurrentSniperMultiplier = sniperMultiplier;

    SetAmmoCvar(g_cvAmmoRifle,           ScaleAmmo(g_cvBaseRifle.IntValue, multiplier));
    SetAmmoCvar(g_cvAmmoAutoShotgun,     ScaleAmmo(g_cvBaseAutoShotgun.IntValue, multiplier));
    SetAmmoCvar(g_cvAmmoGrenadeLauncher, ApplyHardCap(g_cvGrenadeFixedAmmo.IntValue));
    SetAmmoCvar(g_cvAmmoShotgun,         ScaleAmmo(g_cvBaseShotgun.IntValue, multiplier));
    SetAmmoCvar(g_cvAmmoHuntingRifle,    ScaleAmmo(g_cvBaseHuntingRifle.IntValue, sniperMultiplier));
    SetAmmoCvar(g_cvAmmoSMG,             ScaleAmmo(g_cvBaseSMG.IntValue, multiplier));
    SetAmmoCvar(g_cvAmmoSniper,          ScaleAmmo(g_cvBaseSniper.IntValue, sniperMultiplier));

    DebugLog(
        "spawn_size=%d mult=%.2f sniper_mult=%.2f rifle=%d smg=%d shotgun=%d auto=%d hunting=%d sniper=%d gl=%d",
        spawnSize,
        multiplier,
        sniperMultiplier,
        GetCvarValue(g_cvAmmoRifle),
        GetCvarValue(g_cvAmmoSMG),
        GetCvarValue(g_cvAmmoShotgun),
        GetCvarValue(g_cvAmmoAutoShotgun),
        GetCvarValue(g_cvAmmoHuntingRifle),
        GetCvarValue(g_cvAmmoSniper),
        GetCvarValue(g_cvAmmoGrenadeLauncher)
    );
}

void ApplyBaseAmmo()
{
    if (g_cvBaseRifle == null)
        return;

    SetAmmoCvar(g_cvAmmoRifle,           g_cvBaseRifle.IntValue);
    SetAmmoCvar(g_cvAmmoAutoShotgun,     g_cvBaseAutoShotgun.IntValue);
    SetAmmoCvar(g_cvAmmoGrenadeLauncher, g_cvBaseGrenadeLauncher.IntValue);
    SetAmmoCvar(g_cvAmmoShotgun,         g_cvBaseShotgun.IntValue);
    SetAmmoCvar(g_cvAmmoHuntingRifle,    g_cvBaseHuntingRifle.IntValue);
    SetAmmoCvar(g_cvAmmoSMG,             g_cvBaseSMG.IntValue);
    SetAmmoCvar(g_cvAmmoSniper,          g_cvBaseSniper.IntValue);

    g_fCurrentMultiplier = 1.0;
    g_fCurrentSniperMultiplier = 1.0;
}

int GetCvarValue(ConVar cvar)
{
    if (cvar == null)
        return -1;

    return cvar.IntValue;
}

public Action Command_Recalc(int client, int args)
{
    TryBindSpecialSpawner();

    if (!g_cvEnable.BoolValue)
    {
        ReplyToCommand(client, "[DynAmmoSS] Plugin is disabled.");
        return Plugin_Handled;
    }

    ApplyDynamicAmmo();
    ReplyToCommand(client, "[DynAmmoSS] Recalculated: ss_spawn_size=%d, multiplier=%.2f, sniper_multiplier=%.2f", g_iCurrentSpawnSize, g_fCurrentMultiplier, g_fCurrentSniperMultiplier);
    return Plugin_Handled;
}

public Action Command_Status(int client, int args)
{
    int spawnSize = g_cvBaseSpawnSize.IntValue;
    bool bound = (g_cvSpawnSize != null);

    if (bound)
        spawnSize = g_cvSpawnSize.IntValue;

    float multiplier = CalculateMultiplier(spawnSize);
    float sniperMultiplier = CalculateSniperMultiplier(spawnSize);

    char bindStatus[16];
    if (bound)
        strcopy(bindStatus, sizeof(bindStatus), "bound");
    else
        strcopy(bindStatus, sizeof(bindStatus), "fallback");

    ReplyToCommand(client, "[DynAmmoSS] enabled=%d | ss_spawn_size=%d (%s) | multiplier=%.2f | sniper_multiplier=%.2f",
        g_cvEnable.BoolValue ? 1 : 0,
        spawnSize,
        bindStatus,
        multiplier,
        sniperMultiplier
    );

    ReplyToCommand(client, "[DynAmmoSS] rifle=%d | smg=%d | shotgun=%d | autoshotgun=%d",
        GetCvarValue(g_cvAmmoRifle),
        GetCvarValue(g_cvAmmoSMG),
        GetCvarValue(g_cvAmmoShotgun),
        GetCvarValue(g_cvAmmoAutoShotgun)
    );

    ReplyToCommand(client, "[DynAmmoSS] hunting=%d | sniper=%d | grenade_launcher=%d | sniper_high_at=%d | hard_cap=%d",
        GetCvarValue(g_cvAmmoHuntingRifle),
        GetCvarValue(g_cvAmmoSniper),
        GetCvarValue(g_cvAmmoGrenadeLauncher),
        g_cvSniperHighSpawnSize.IntValue,
        g_cvHardCap.IntValue
    );

    return Plugin_Handled;
}
