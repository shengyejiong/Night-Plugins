#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "0.2.0"
#define MAX_EDICTS_L4D2 2048

public Plugin myinfo =
{
    name        = "[L4D2] Rescue Door Marker",
    author      = "OpenAI / ChatGPT",
    description = "Highlights unopened rescue-closet doors without changing door or rescue behavior.",
    version     = PLUGIN_VERSION,
    url         = ""
};

ConVar g_cvEnable;
ConVar g_cvColor;
ConVar g_cvGlowRange;
ConVar g_cvSearchRadius;
ConVar g_cvSinglePointDistance;
ConVar g_cvIncludeCheckpoint;
ConVar g_cvDebug;

int   g_iDoorVotes[MAX_EDICTS_L4D2 + 1];
float g_fDoorMinDistance[MAX_EDICTS_L4D2 + 1];

bool g_bMarked[MAX_EDICTS_L4D2 + 1];
bool g_bOpenedThisRound[MAX_EDICTS_L4D2 + 1];
bool g_bOpenOutputHooked[MAX_EDICTS_L4D2 + 1];

int  g_iOldGlowType[MAX_EDICTS_L4D2 + 1];
int  g_iOldGlowColor[MAX_EDICTS_L4D2 + 1];
int  g_iOldGlowRange[MAX_EDICTS_L4D2 + 1];
int  g_iOldGlowRangeMin[MAX_EDICTS_L4D2 + 1];

Handle g_hScanTimer = null;

public void OnPluginStart()
{
    char game[32];
    GetGameFolderName(game, sizeof(game));
    if (!StrEqual(game, "left4dead2", false))
    {
        SetFailState("This plugin supports Left 4 Dead 2 only.");
    }

    g_cvEnable = CreateConVar(
        "rdm_enable", "1",
        "Enable Rescue Door Marker. 0=Off, 1=On.",
        FCVAR_NOTIFY, true, 0.0, true, 1.0);

    g_cvColor = CreateConVar(
        "rdm_color", "255 180 0",
        "Rescue door outline color in RGB, e.g. '255 180 0'.");

    g_cvGlowRange = CreateConVar(
        "rdm_glow_range", "1200",
        "Maximum distance at which the rescue-door outline is visible. 0 = unlimited/game default.",
        FCVAR_NOTIFY, true, 0.0, true, 10000.0);

    g_cvSearchRadius = CreateConVar(
        "rdm_search_radius", "450",
        "Maximum distance from an info_survivor_rescue point to its nearest candidate door.",
        FCVAR_NOTIFY, true, 64.0, true, 1200.0);

    g_cvSinglePointDistance = CreateConVar(
        "rdm_single_point_distance", "220",
        "If only one rescue point votes for a door, it is still accepted when this close or closer. Set 0 to require 2+ votes.",
        FCVAR_NOTIFY, true, 0.0, true, 600.0);

    g_cvIncludeCheckpoint = CreateConVar(
        "rdm_include_checkpoint_doors", "0",
        "Also consider prop_door_rotating_checkpoint as rescue-door candidates. Usually keep this 0 to avoid saferoom doors.",
        FCVAR_NOTIFY, true, 0.0, true, 1.0);

    g_cvDebug = CreateConVar(
        "rdm_debug", "0",
        "Print rescue-point/door scan and open-event details to the server console. 0=Off, 1=On.",
        FCVAR_NOTIFY, true, 0.0, true, 1.0);

    HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);

    g_cvEnable.AddChangeHook(CvarChanged);
    g_cvColor.AddChangeHook(CvarChanged);
    g_cvGlowRange.AddChangeHook(CvarChanged);
    g_cvSearchRadius.AddChangeHook(CvarChanged);
    g_cvSinglePointDistance.AddChangeHook(CvarChanged);
    g_cvIncludeCheckpoint.AddChangeHook(CvarChanged);

    RegAdminCmd("sm_rdm_rescan", Cmd_Rescan, ADMFLAG_ROOT,
        "Rescan the map and reapply markers only to rescue doors that have not been opened this round.");

    AutoExecConfig(true, "l4d2_rescue_door_marker");
}

public void OnMapStart()
{
    ResetTrackingArrays();
}

public void OnConfigsExecuted()
{
    ScheduleScan(1.0);
}

public void OnMapEnd()
{
    CancelScanTimer();
    // Map entities are about to be destroyed, so there is no need to restore them here.
    ResetTrackingArrays();
}

public void OnEntityDestroyed(int entity)
{
    if (entity <= MaxClients || entity > MAX_EDICTS_L4D2)
    {
        return;
    }

    // Static map doors normally survive for the whole round, but custom maps or
    // other plugins may remove them. Clear index-based state before that edict
    // index can be reused by an unrelated entity.
    ClearEntityTracking(entity);
}

public void OnPluginEnd()
{
    CancelScanTimer();
    RestoreAllDoorGlows();
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    // A new round gives every rescue door a fresh "unopened" state.
    RestoreAllDoorGlows();
    ResetOpenedState();
    ScheduleScan(1.0);
}

public void CvarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (!g_cvEnable.BoolValue)
    {
        CancelScanTimer();
        RestoreAllDoorGlows();
        return;
    }

    // Visual/recognition changes must not make a door that was already opened this round glow again.
    ScheduleScan(0.2);
}

public Action Cmd_Rescan(int client, int args)
{
    if (!g_cvEnable.BoolValue)
    {
        ReplyToCommand(client, "[RDM] Plugin is disabled (rdm_enable 0).");
        return Plugin_Handled;
    }

    ScanAndMarkDoors();
    ReplyToCommand(client,
        "[RDM] Rescue-door scan complete. Doors already opened this round remain unmarked. Check server console if rdm_debug 1.");
    return Plugin_Handled;
}

void ScheduleScan(float delay)
{
    CancelScanTimer();
    g_hScanTimer = CreateTimer(delay, Timer_Scan, 0, TIMER_FLAG_NO_MAPCHANGE);
}

void CancelScanTimer()
{
    if (g_hScanTimer != null)
    {
        delete g_hScanTimer;
        g_hScanTimer = null;
    }
}

public Action Timer_Scan(Handle timer, any data)
{
    g_hScanTimer = null;

    if (g_cvEnable.BoolValue)
    {
        ScanAndMarkDoors();
    }

    return Plugin_Stop;
}

void ScanAndMarkDoors()
{
    RestoreAllDoorGlows();
    ResetVoteArrays();

    float searchRadius = g_cvSearchRadius.FloatValue;
    int rescueCount = 0;
    int voteCount = 0;

    int rescue = -1;
    while ((rescue = FindEntityByClassname(rescue, "info_survivor_rescue")) != -1)
    {
        if (!IsValidEntity(rescue))
        {
            continue;
        }

        rescueCount++;

        float rescuePos[3];
        GetEntPropVector(rescue, Prop_Send, "m_vecOrigin", rescuePos);

        float nearestDistance = 0.0;
        int door = FindNearestCandidateDoor(rescuePos, searchRadius, nearestDistance);
        if (door <= MaxClients || door > MAX_EDICTS_L4D2)
        {
            if (g_cvDebug.BoolValue)
            {
                LogMessage("[RDM] Rescue point #%d: no candidate door within %.1f units.", rescue, searchRadius);
            }
            continue;
        }

        g_iDoorVotes[door]++;
        voteCount++;

        if (nearestDistance < g_fDoorMinDistance[door])
        {
            g_fDoorMinDistance[door] = nearestDistance;
        }

        if (g_cvDebug.BoolValue)
        {
            LogMessage("[RDM] Rescue point #%d -> door #%d (distance %.1f).",
                rescue, door, nearestDistance);
        }
    }

    int markedCount = 0;
    int openedSkippedCount = 0;
    float singlePointDistance = g_cvSinglePointDistance.FloatValue;
    int maxEntities = GetMaxEntities() - 1;
    if (maxEntities > MAX_EDICTS_L4D2)
    {
        maxEntities = MAX_EDICTS_L4D2;
    }

    for (int door = MaxClients + 1; door <= maxEntities; door++)
    {
        if (g_iDoorVotes[door] <= 0 || !IsValidEntity(door))
        {
            continue;
        }

        // Normal closet: multiple rescue points vote for the same door.
        // Compatibility fallback: one rescue point is enough if the door is very close.
        bool accepted = (g_iDoorVotes[door] >= 2);
        if (!accepted && singlePointDistance > 0.0 && g_fDoorMinDistance[door] <= singlePointDistance)
        {
            accepted = true;
        }

        if (!accepted)
        {
            if (g_cvDebug.BoolValue)
            {
                LogMessage("[RDM] Skipped door #%d: votes=%d, nearest=%.1f (single-point limit %.1f).",
                    door, g_iDoorVotes[door], g_fDoorMinDistance[door], singlePointDistance);
            }
            continue;
        }

        // If we know this door was opened earlier in the round, never reapply the warning marker.
        if (g_bOpenedThisRound[door])
        {
            openedSkippedCount++;

            if (g_cvDebug.BoolValue)
            {
                LogMessage("[RDM] Skipped door #%d: already opened earlier this round.", door);
            }
            continue;
        }

        // Useful for late plugin loads / late rescans: if the door is already open or moving,
        // treat it as already used instead of adding a misleading warning marker.
        if (!IsDoorClosed(door))
        {
            g_bOpenedThisRound[door] = true;
            openedSkippedCount++;

            if (g_cvDebug.BoolValue)
            {
                LogMessage("[RDM] Skipped door #%d: current door state is not closed; treating it as already opened.", door);
            }
            continue;
        }

        if (ApplyDoorGlow(door))
        {
            markedCount++;

            if (g_cvDebug.BoolValue)
            {
                char classname[64];
                GetEntityClassname(door, classname, sizeof(classname));

                char model[PLATFORM_MAX_PATH];
                model[0] = '\0';
                GetEntPropString(door, Prop_Data, "m_ModelName", model, sizeof(model));

                int hammerId = -1;
                if (HasEntProp(door, Prop_Data, "m_iHammerID"))
                {
                    hammerId = GetEntProp(door, Prop_Data, "m_iHammerID");
                }

                LogMessage("[RDM] MARKED door #%d hammerid=%d class=%s votes=%d nearest=%.1f model=%s",
                    door, hammerId, classname, g_iDoorVotes[door], g_fDoorMinDistance[door], model);
            }
        }
    }

    LogMessage("[RDM] Scan complete: rescue points=%d, votes=%d, marked doors=%d, opened doors skipped=%d.",
        rescueCount, voteCount, markedCount, openedSkippedCount);
}

int FindNearestCandidateDoor(const float rescuePos[3], float maxDistance, float &nearestDistance)
{
    int nearestDoor = -1;
    nearestDistance = maxDistance + 1.0;

    FindNearestDoorOfClass("prop_door_rotating", rescuePos, maxDistance, nearestDoor, nearestDistance);

    if (g_cvIncludeCheckpoint.BoolValue)
    {
        FindNearestDoorOfClass("prop_door_rotating_checkpoint", rescuePos, maxDistance, nearestDoor, nearestDistance);
    }

    return nearestDoor;
}

void FindNearestDoorOfClass(const char[] classname, const float rescuePos[3], float maxDistance,
    int &nearestDoor, float &nearestDistance)
{
    int door = -1;
    while ((door = FindEntityByClassname(door, classname)) != -1)
    {
        if (!IsValidEntity(door) || door > MAX_EDICTS_L4D2)
        {
            continue;
        }

        float doorPos[3];
        GetEntPropVector(door, Prop_Send, "m_vecOrigin", doorPos);

        float distance = GetVectorDistance(rescuePos, doorPos);
        if (distance <= maxDistance && distance < nearestDistance)
        {
            nearestDoor = door;
            nearestDistance = distance;
        }
    }
}

bool ApplyDoorGlow(int door)
{
    if (!IsValidEntity(door) || door <= MaxClients || door > MAX_EDICTS_L4D2)
    {
        return false;
    }

    if (!HasEntProp(door, Prop_Send, "m_iGlowType") ||
        !HasEntProp(door, Prop_Send, "m_glowColorOverride") ||
        !HasEntProp(door, Prop_Send, "m_nGlowRange"))
    {
        if (g_cvDebug.BoolValue)
        {
            LogMessage("[RDM] Door #%d does not expose the required glow netprops; skipped.", door);
        }
        return false;
    }

    // Save the original visual state so opening the door, disabling the plugin,
    // rescanning, or unloading the plugin restores whatever was there before us.
    g_iOldGlowType[door] = GetEntProp(door, Prop_Send, "m_iGlowType");
    g_iOldGlowColor[door] = GetEntProp(door, Prop_Send, "m_glowColorOverride");
    g_iOldGlowRange[door] = GetEntProp(door, Prop_Send, "m_nGlowRange");

    if (HasEntProp(door, Prop_Send, "m_nGlowRangeMin"))
    {
        g_iOldGlowRangeMin[door] = GetEntProp(door, Prop_Send, "m_nGlowRangeMin");
    }
    else
    {
        g_iOldGlowRangeMin[door] = 0;
    }

    g_bMarked[door] = true;

    int color = ParseColorConVar();
    SetEntProp(door, Prop_Send, "m_glowColorOverride", color);
    SetEntProp(door, Prop_Send, "m_iGlowType", 3); // Constant outline glow.
    SetEntProp(door, Prop_Send, "m_nGlowRange", g_cvGlowRange.IntValue);

    if (HasEntProp(door, Prop_Send, "m_nGlowRangeMin"))
    {
        SetEntProp(door, Prop_Send, "m_nGlowRangeMin", 0);
    }

    // On the first open attempt, immediately remove the warning marker.
    // "once = true" ensures this callback only fires once for this hook instance.
    HookSingleEntityOutput(door, "OnOpen", OnRescueDoorOpen, true);
    g_bOpenOutputHooked[door] = true;

    return true;
}

public void OnRescueDoorOpen(const char[] output, int caller, int activator, float delay)
{
    if (caller <= MaxClients || caller > MAX_EDICTS_L4D2 || !IsValidEntity(caller))
    {
        return;
    }

    // Because HookSingleEntityOutput used once=true, the engine has consumed this hook.
    g_bOpenOutputHooked[caller] = false;
    g_bOpenedThisRound[caller] = true;

    RestoreSingleDoorGlow(caller);

    if (g_cvDebug.BoolValue)
    {
        int hammerId = -1;
        if (HasEntProp(caller, Prop_Data, "m_iHammerID"))
        {
            hammerId = GetEntProp(caller, Prop_Data, "m_iHammerID");
        }

        LogMessage("[RDM] Door #%d hammerid=%d opened: marker removed for the rest of this round.",
            caller, hammerId);
    }
}

bool IsDoorClosed(int door)
{
    // CBasePropDoor exposes m_eDoorState in L4D2. State 0 is closed.
    // If a custom door does not expose the property, assume closed and let OnOpen handle it.
    if (HasEntProp(door, Prop_Send, "m_eDoorState"))
    {
        return GetEntProp(door, Prop_Send, "m_eDoorState") == 0;
    }

    if (HasEntProp(door, Prop_Data, "m_eDoorState"))
    {
        return GetEntProp(door, Prop_Data, "m_eDoorState") == 0;
    }

    return true;
}

void RestoreSingleDoorGlow(int door)
{
    if (door <= MaxClients || door > MAX_EDICTS_L4D2 || !g_bMarked[door])
    {
        return;
    }

    if (IsValidEntity(door))
    {
        if (HasEntProp(door, Prop_Send, "m_iGlowType"))
        {
            SetEntProp(door, Prop_Send, "m_iGlowType", g_iOldGlowType[door]);
        }

        if (HasEntProp(door, Prop_Send, "m_glowColorOverride"))
        {
            SetEntProp(door, Prop_Send, "m_glowColorOverride", g_iOldGlowColor[door]);
        }

        if (HasEntProp(door, Prop_Send, "m_nGlowRange"))
        {
            SetEntProp(door, Prop_Send, "m_nGlowRange", g_iOldGlowRange[door]);
        }

        if (HasEntProp(door, Prop_Send, "m_nGlowRangeMin"))
        {
            SetEntProp(door, Prop_Send, "m_nGlowRangeMin", g_iOldGlowRangeMin[door]);
        }
    }

    g_bMarked[door] = false;
    g_iOldGlowType[door] = 0;
    g_iOldGlowColor[door] = 0;
    g_iOldGlowRange[door] = 0;
    g_iOldGlowRangeMin[door] = 0;
}

void RestoreAllDoorGlows()
{
    int maxEntities = GetMaxEntities() - 1;
    if (maxEntities > MAX_EDICTS_L4D2)
    {
        maxEntities = MAX_EDICTS_L4D2;
    }

    for (int door = MaxClients + 1; door <= maxEntities; door++)
    {
        // A rescan/disable/unload must not leave stale entity-output hooks behind.
        if (g_bOpenOutputHooked[door])
        {
            if (IsValidEntity(door))
            {
                UnhookSingleEntityOutput(door, "OnOpen", OnRescueDoorOpen);
            }
            g_bOpenOutputHooked[door] = false;
        }

        if (g_bMarked[door])
        {
            RestoreSingleDoorGlow(door);
        }
    }
}

void ResetOpenedState()
{
    for (int i = 0; i <= MAX_EDICTS_L4D2; i++)
    {
        g_bOpenedThisRound[i] = false;
    }
}

void ResetTrackingArrays()
{
    for (int i = 0; i <= MAX_EDICTS_L4D2; i++)
    {
        ClearEntityTracking(i);
    }
}

void ClearEntityTracking(int entity)
{
    g_iDoorVotes[entity] = 0;
    g_fDoorMinDistance[entity] = 999999.0;

    g_bMarked[entity] = false;
    g_bOpenedThisRound[entity] = false;
    g_bOpenOutputHooked[entity] = false;

    g_iOldGlowType[entity] = 0;
    g_iOldGlowColor[entity] = 0;
    g_iOldGlowRange[entity] = 0;
    g_iOldGlowRangeMin[entity] = 0;
}

void ResetVoteArrays()
{
    for (int i = 0; i <= MAX_EDICTS_L4D2; i++)
    {
        g_iDoorVotes[i] = 0;
        g_fDoorMinDistance[i] = 999999.0;
    }
}

int ParseColorConVar()
{
    char colorString[64];
    g_cvColor.GetString(colorString, sizeof(colorString));
    TrimString(colorString);

    char parts[3][12];
    int count = ExplodeString(colorString, " ", parts, sizeof(parts), sizeof(parts[]));

    int r = 255;
    int g = 180;
    int b = 0;

    if (count >= 3)
    {
        r = ClampByte(StringToInt(parts[0]));
        g = ClampByte(StringToInt(parts[1]));
        b = ClampByte(StringToInt(parts[2]));
    }

    // L4D2 glow color is packed as R + (G << 8) + (B << 16).
    return r | (g << 8) | (b << 16);
}

int ClampByte(int value)
{
    if (value < 0)
    {
        return 0;
    }
    if (value > 255)
    {
        return 255;
    }
    return value;
}
