#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>

#define PLUGIN_VERSION "0.4.1"
#define SPRITE_BEAM "materials/sprites/laserbeam.vmt"

#define POINT_EPSILON 0.25
#define ENTITY_RESERVE 128
#define GROUND_TRACE_UP 48.0
#define GROUND_TRACE_DOWN 128.0

#define NAV_CORNER_NORTH_WEST 0
#define NAV_CORNER_NORTH_EAST 1
#define NAV_CORNER_SOUTH_EAST 2
#define NAV_CORNER_SOUTH_WEST 3

#define NAV_AREA_NORTH_EAST_Z_OFFSET 0x24
#define NAV_AREA_SOUTH_WEST_Z_OFFSET 0x28
#define NAV_AREA_CENTER_X_OFFSET 0x2C
#define NAV_AREA_CENTER_Y_OFFSET 0x30
#define NAV_AREA_CENTER_Z_OFFSET 0x34

public Plugin myinfo =
{
    name        = "[L4D2] Start Safe Area Marker",
    author      = "OpenAI / ChatGPT",
    description = "Draws a persistent Scavenge-style hull around the starting safe area and removes it when the first Survivor leaves.",
    version     = PLUGIN_VERSION,
    url         = ""
};

ConVar g_cvEnable;
ConVar g_cvStripeWidth;
ConVar g_cvStripeHeight;
ConVar g_cvStripeSpacing;
ConVar g_cvStripeSlant;
ConVar g_cvAlpha;
ConVar g_cvZOffset;
ConVar g_cvRefresh;
ConVar g_cvDrawDistance;
ConVar g_cvMaxStripes;
ConVar g_cvMaxBeams;
ConVar g_cvSurvivorsOnly;
ConVar g_cvDebug;

ArrayList g_aBoundaryEdges;
ArrayList g_aSafeNavAreas;
ArrayList g_aBeamEntities;
Handle g_hBuildTimer = null;

int g_iBeamSprite = -1;
bool g_bMarkerActive = false;
bool g_bLeftSafeArea = false;
bool g_bL4DHReady = false;

public void OnPluginStart()
{
    char game[32];
    GetGameFolderName(game, sizeof(game));
    if (!StrEqual(game, "left4dead2", false))
    {
        SetFailState("This plugin supports Left 4 Dead 2 only.");
    }

    // This is the newest Left4DHooks native this compatibility build needs.
    // NAV centers and corners are read from CNavArea locally.
    if (GetFeatureStatus(FeatureType_Native, "L4D_GetAllNavAreas") != FeatureStatus_Available)
    {
        SetFailState("Left4DHooks 1.128+ is required (missing L4D_GetAllNavAreas native).");
    }

    g_cvEnable = CreateConVar(
        "ssam_enable", "1",
        "Enable Start Safe Area Marker. 0=Off, 1=On.",
        FCVAR_NOTIFY, true, 0.0, true, 1.0);

    g_cvStripeWidth = CreateConVar(
        "ssam_stripe_width", "3.0",
        "Thickness of each white diagonal stripe beam.",
        FCVAR_NOTIFY, true, 0.5, true, 12.0);

    g_cvStripeHeight = CreateConVar(
        "ssam_stripe_height", "34.0",
        "Height of the Scavenge-style striped boundary, in units.",
        FCVAR_NOTIFY, true, 4.0, true, 128.0);

    g_cvStripeSpacing = CreateConVar(
        "ssam_stripe_spacing", "16.0",
        "Distance between diagonal stripes along the boundary, in units.",
        FCVAR_NOTIFY, true, 6.0, true, 64.0);

    g_cvStripeSlant = CreateConVar(
        "ssam_stripe_slant", "13.0",
        "Horizontal lean of each diagonal stripe along the boundary, in units.",
        FCVAR_NOTIFY, true, 0.0, true, 64.0);

    g_cvAlpha = CreateConVar(
        "ssam_alpha", "220",
        "Opacity of the white striped boundary (0-255).",
        FCVAR_NOTIFY, true, 0.0, true, 255.0);

    g_cvZOffset = CreateConVar(
        "ssam_z_offset", "2.0",
        "Vertical offset above the NAV floor before the stripes begin, in units.",
        FCVAR_NOTIFY, true, -16.0, true, 32.0);

    g_cvRefresh = CreateConVar(
        "ssam_refresh", "0.35",
        "Deprecated compatibility CVar. Persistent beams do not refresh.",
        FCVAR_NOTIFY, true, 0.10, true, 2.0);

    g_cvDrawDistance = CreateConVar(
        "ssam_draw_distance", "1400.0",
        "Deprecated compatibility CVar. Persistent beams use engine visibility/transmit handling.",
        FCVAR_NOTIFY, true, 256.0, true, 5000.0);

    g_cvMaxStripes = CreateConVar(
        "ssam_max_stripes", "160",
        "Deprecated compatibility CVar. Persistent rendering uses ssam_max_beams.",
        FCVAR_NOTIFY, true, 32.0, true, 400.0);

    g_cvMaxBeams = CreateConVar(
        "ssam_max_beams", "320",
        "Maximum persistent stripe entities for the complete boundary. Spacing is increased uniformly when needed.",
        FCVAR_NOTIFY, true, 32.0, true, 800.0);

    g_cvSurvivorsOnly = CreateConVar(
        "ssam_survivors_only", "1",
        "Who sees the boundary. 1=Survivors only, 0=Everyone.",
        FCVAR_NOTIFY, true, 0.0, true, 1.0);

    g_cvDebug = CreateConVar(
        "ssam_debug", "0",
        "Print safe-area scan/debug information to the server console. 0=Off, 1=On.",
        FCVAR_NOTIFY, true, 0.0, true, 1.0);

    HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
    HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
    HookEvent("map_transition", Event_RoundEnd, EventHookMode_PostNoCopy);
    HookEvent("mission_lost", Event_RoundEnd, EventHookMode_PostNoCopy);

    g_cvEnable.AddChangeHook(CvarChanged);
    g_cvStripeWidth.AddChangeHook(CvarChanged);
    g_cvStripeHeight.AddChangeHook(CvarChanged);
    g_cvStripeSpacing.AddChangeHook(CvarChanged);
    g_cvStripeSlant.AddChangeHook(CvarChanged);
    g_cvAlpha.AddChangeHook(CvarChanged);
    g_cvZOffset.AddChangeHook(CvarChanged);
    g_cvRefresh.AddChangeHook(CvarChanged);
    g_cvDrawDistance.AddChangeHook(CvarChanged);
    g_cvMaxStripes.AddChangeHook(CvarChanged);
    g_cvMaxBeams.AddChangeHook(CvarChanged);
    g_cvSurvivorsOnly.AddChangeHook(CvarChanged);

    RegAdminCmd("sm_ssam_rescan", Cmd_Rescan, ADMFLAG_ROOT,
        "Rebuild the starting safe-area striped boundary if Survivors have not left yet.");

    RegAdminCmd("sm_ssam_hide", Cmd_Hide, ADMFLAG_ROOT,
        "Hide the current starting safe-area marker for this round.");

    AutoExecConfig(true, "l4d2_start_safe_area_marker");

    // Each row stores start XYZ + end XYZ for one edge of the continuous
    // 2D convex hull around all starting-checkpoint NAV corners.
    g_aBoundaryEdges = new ArrayList(6);
    g_aSafeNavAreas = new ArrayList();
    g_aBeamEntities = new ArrayList();
}

public void OnMapStart()
{
    g_iBeamSprite = PrecacheModel(SPRITE_BEAM, true);
    g_bL4DHReady = false;
    ResetRoundState();
}

public void OnConfigsExecuted()
{
    // Left4DHooks has completed OnMapStart by the time configs execute. This
    // also handles loading the plugin after a map is already running.
    if (L4D_HasMapStarted())
    {
        g_bL4DHReady = true;
        ScheduleBuild(0.5);
    }
}

public void OnMapEnd()
{
    StopTimers();
    RemoveBoundaryEntities();
    ClearEdges();
    g_bMarkerActive = false;
    g_bLeftSafeArea = false;
    g_bL4DHReady = false;
}

public void OnPluginEnd()
{
    StopTimers();
    RemoveBoundaryEntities();
    ClearEdges();
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    ResetRoundState();

    if (g_cvEnable.BoolValue && g_bL4DHReady)
    {
        ScheduleBuild(1.0);
    }
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    g_bMarkerActive = false;
    RemoveBoundaryEntities();
}

public void CvarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (!g_cvEnable.BoolValue)
    {
        g_bMarkerActive = false;
        StopTimers();
        RemoveBoundaryEntities();
        return;
    }

    // Kept so old generated cfg files do not produce unknown-command errors.
    // Persistent beams do not refresh and are not distance-culled by the plugin.
    if (convar == g_cvRefresh || convar == g_cvDrawDistance || convar == g_cvMaxStripes)
    {
        return;
    }

    // Visual CVars do not change NAV geometry, so recreate only the persistent
    // render entities instead of rescanning the NAV mesh.
    if (convar == g_cvStripeWidth || convar == g_cvStripeHeight ||
        convar == g_cvStripeSpacing || convar == g_cvStripeSlant ||
        convar == g_cvAlpha || convar == g_cvZOffset ||
        convar == g_cvMaxBeams)
    {
        if (g_bMarkerActive)
        {
            if (CreateBoundaryEntities() <= 0)
            {
                g_bMarkerActive = false;
            }
        }
        return;
    }

    if (convar == g_cvSurvivorsOnly)
    {
        return;
    }

    if (g_bL4DHReady && !g_bLeftSafeArea)
    {
        ScheduleBuild(0.2);
    }
}

public Action Cmd_Rescan(int client, int args)
{
    if (!g_cvEnable.BoolValue)
    {
        ReplyToCommand(client, "[SSAM] Plugin is disabled (ssam_enable 0).");
        return Plugin_Handled;
    }

    if (!g_bL4DHReady || !L4D_HasMapStarted())
    {
        ReplyToCommand(client, "[SSAM] Left4DHooks/map NAV data is not ready yet.");
        return Plugin_Handled;
    }

    if (g_bLeftSafeArea || L4D_HasAnySurvivorLeftSafeArea())
    {
        ReplyToCommand(client, "[SSAM] Survivors already left the starting safe area; marker will stay hidden this round.");
        return Plugin_Handled;
    }

    BuildBoundary();
    ReplyToCommand(client, "[SSAM] Starting safe-area striped boundary rebuilt. Check server console if ssam_debug 1.");
    return Plugin_Handled;
}

public Action Cmd_Hide(int client, int args)
{
    g_bMarkerActive = false;
    g_bLeftSafeArea = true;
    RemoveBoundaryEntities();
    ReplyToCommand(client, "[SSAM] Starting safe-area marker hidden for this round.");
    return Plugin_Handled;
}

// This is the same Director transition many Special Infected spawners use.
// We never block or modify it; we only stop drawing our marker.
public Action L4D_OnFirstSurvivorLeftSafeArea(int client)
{
    HideMarkerAfterLeaving(client);
    return Plugin_Continue;
}

public void L4D_OnFirstSurvivorLeftSafeArea_Post(int client)
{
    // Fallback in case another plugin changes hook order/behavior.
    HideMarkerAfterLeaving(client);
}

void HideMarkerAfterLeaving(int client)
{
    if (g_bLeftSafeArea)
    {
        return;
    }

    g_bLeftSafeArea = true;
    g_bMarkerActive = false;
    RemoveBoundaryEntities();

    if (g_cvDebug.BoolValue)
    {
        if (client > 0 && client <= MaxClients && IsClientInGame(client))
        {
            LogMessage("[SSAM] First Survivor left starting safe area: client=%d (%N). Scavenge-style boundary stopped.", client, client);
        }
        else
        {
            LogMessage("[SSAM] First Survivor left starting safe area. Scavenge-style boundary stopped.");
        }
    }
}

void ResetRoundState()
{
    StopTimers();
    RemoveBoundaryEntities();
    ClearEdges();
    g_bMarkerActive = false;
    g_bLeftSafeArea = false;
}

void ScheduleBuild(float delay)
{
    StopBuildTimer();

    if (!g_cvEnable.BoolValue || g_bLeftSafeArea)
    {
        return;
    }

    g_hBuildTimer = CreateTimer(delay, Timer_Build, 0, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_Build(Handle timer, any data)
{
    g_hBuildTimer = null;

    if (!g_cvEnable.BoolValue || !g_bL4DHReady || g_bLeftSafeArea)
    {
        return Plugin_Stop;
    }

    if (L4D_HasAnySurvivorLeftSafeArea())
    {
        g_bLeftSafeArea = true;
        g_bMarkerActive = false;
        return Plugin_Stop;
    }

    BuildBoundary();
    return Plugin_Stop;
}

void BuildBoundary()
{
    RemoveBoundaryEntities();
    ClearEdges();
    g_bMarkerActive = false;

    ArrayList allAreas = new ArrayList();
    ArrayList safePoints = new ArrayList(3);
    ArrayList hullPoints = new ArrayList(3);

    L4D_GetAllNavAreas(allAreas);

    float center[3];
    float corner[3];
    Address area;
    int safeAreaCount = 0;

    for (int i = 0; i < allAreas.Length; i++)
    {
        area = view_as<Address>(allAreas.Get(i));
        if (area == Address_Null)
        {
            continue;
        }

        GetNavAreaCenterCompat(area, center);
        if (L4D_IsPositionInFirstCheckpoint(center))
        {
            safeAreaCount++;
            g_aSafeNavAreas.Push(area);

            for (int navCorner = NAV_CORNER_NORTH_WEST; navCorner <= NAV_CORNER_SOUTH_WEST; navCorner++)
            {
                GetNavAreaCornerCompat(area, navCorner, corner);
                PushUniquePoint(safePoints, corner);
            }
        }
    }

    if (g_cvDebug.BoolValue)
    {
        LogMessage("[SSAM] NAV scan: total=%d, first-checkpoint=%d, unique-corners=%d.",
            allAreas.Length, safeAreaCount, safePoints.Length);
    }

    if (safeAreaCount == 0)
    {
        LogMessage("[SSAM] No starting checkpoint NAV areas were found on this map. Marker not drawn.");
        delete hullPoints;
        delete safePoints;
        delete allAreas;
        return;
    }

    if (!BuildConvexHull(safePoints, hullPoints))
    {
        LogMessage("[SSAM] Starting checkpoint NAV data did not produce a valid outer hull. Marker not drawn.");
        delete hullPoints;
        delete safePoints;
        delete allAreas;
        return;
    }

    float edgeStart[3];
    float edgeEnd[3];

    for (int i = 0; i < hullPoints.Length; i++)
    {
        hullPoints.GetArray(i, edgeStart, sizeof(edgeStart));
        hullPoints.GetArray((i + 1) % hullPoints.Length, edgeEnd, sizeof(edgeEnd));
        AddBoundarySegment(edgeStart, edgeEnd);
    }

    delete hullPoints;
    delete safePoints;
    delete allAreas;

    if (g_aBoundaryEdges.Length <= 0)
    {
        LogMessage("[SSAM] Starting safe area was found, but no outer boundary edges were generated.");
        return;
    }

    if (L4D_HasAnySurvivorLeftSafeArea())
    {
        g_bLeftSafeArea = true;
        ClearEdges();
        return;
    }

    int created = CreateBoundaryEntities();
    if (created <= 0)
    {
        LogMessage("[SSAM] Boundary hull was generated, but no persistent beam entities could be created.");
        return;
    }

    g_bMarkerActive = true;

    if (g_cvDebug.BoolValue)
    {
        LogMessage("[SSAM] Boundary ready: %d continuous hull edges, %d persistent stripe entities. No refresh timer is used.",
            g_aBoundaryEdges.Length, created);
    }
}

void PushUniquePoint(ArrayList points, const float position[3])
{
    float existing[3];

    for (int i = 0; i < points.Length; i++)
    {
        points.GetArray(i, existing, sizeof(existing));
        if (FloatAbs(existing[0] - position[0]) <= POINT_EPSILON &&
            FloatAbs(existing[1] - position[1]) <= POINT_EPSILON)
        {
            // Adjacent sloped NAV areas can share XY while disagreeing by a
            // tiny amount on Z. Keep the higher point to avoid floor clipping.
            if (position[2] > existing[2])
            {
                existing[2] = position[2];
                points.SetArray(i, existing, sizeof(existing));
            }
            return;
        }
    }

    points.PushArray(position, 3);
}

bool BuildConvexHull(ArrayList points, ArrayList hull)
{
    hull.Clear();
    if (points.Length < 3)
    {
        return false;
    }

    float point[3];
    float startPoint[3];
    points.GetArray(0, startPoint, sizeof(startPoint));
    int start = 0;

    for (int i = 1; i < points.Length; i++)
    {
        points.GetArray(i, point, sizeof(point));
        if (point[0] < startPoint[0] - POINT_EPSILON ||
            (FloatAbs(point[0] - startPoint[0]) <= POINT_EPSILON && point[1] < startPoint[1]))
        {
            start = i;
            startPoint = point;
        }
    }

    int current = start;
    int guard = 0;
    float currentPoint[3];
    float nextPoint[3];
    float testPoint[3];

    do
    {
        points.GetArray(current, currentPoint, sizeof(currentPoint));
        hull.PushArray(currentPoint, sizeof(currentPoint));

        int next = -1;

        for (int i = 0; i < points.Length; i++)
        {
            if (i == current)
            {
                continue;
            }

            points.GetArray(i, testPoint, sizeof(testPoint));
            if (IsSamePoint2D(currentPoint, testPoint))
            {
                continue;
            }

            if (next == -1)
            {
                next = i;
                nextPoint = testPoint;
                continue;
            }

            float cross = Cross2D(currentPoint, nextPoint, testPoint);
            if (cross < -0.01 ||
                (FloatAbs(cross) <= 0.01 && DistanceSq2D(currentPoint, testPoint) > DistanceSq2D(currentPoint, nextPoint)))
            {
                next = i;
                nextPoint = testPoint;
            }
        }

        if (next == -1)
        {
            return false;
        }

        current = next;
        guard++;
    }
    while (current != start && guard <= points.Length);

    return current == start && hull.Length >= 3;
}

bool IsSamePoint2D(const float a[3], const float b[3])
{
    return FloatAbs(a[0] - b[0]) <= POINT_EPSILON &&
        FloatAbs(a[1] - b[1]) <= POINT_EPSILON;
}

float Cross2D(const float origin[3], const float a[3], const float b[3])
{
    return (a[0] - origin[0]) * (b[1] - origin[1]) -
        (a[1] - origin[1]) * (b[0] - origin[0]);
}

float DistanceSq2D(const float a[3], const float b[3])
{
    float dx = b[0] - a[0];
    float dy = b[1] - a[1];
    return dx * dx + dy * dy;
}

void AddBoundarySegment(const float start[3], const float end[3])
{
    float edge[6];

    // Ignore pathological/zero-length horizontal edges.
    float dx = end[0] - start[0];
    float dy = end[1] - start[1];
    if (SquareRoot(dx * dx + dy * dy) < 1.0)
    {
        return;
    }

    edge[0] = start[0];
    edge[1] = start[1];
    edge[2] = start[2];
    edge[3] = end[0];
    edge[4] = end[1];
    edge[5] = end[2];

    g_aBoundaryEdges.PushArray(edge, sizeof(edge));
}

void GetNavAreaCornerCompat(Address area, int corner, float position[3])
{
    switch (corner)
    {
        case NAV_CORNER_NORTH_WEST:
        {
            position[0] = ReadNavAreaFloat(area, 0x04);
            position[1] = ReadNavAreaFloat(area, 0x08);
            position[2] = ReadNavAreaFloat(area, 0x0C);
        }
        case NAV_CORNER_NORTH_EAST:
        {
            position[0] = ReadNavAreaFloat(area, 0x10);
            position[1] = ReadNavAreaFloat(area, 0x08);
            position[2] = ReadNavAreaFloat(area, NAV_AREA_NORTH_EAST_Z_OFFSET);
        }
        case NAV_CORNER_SOUTH_EAST:
        {
            position[0] = ReadNavAreaFloat(area, 0x10);
            position[1] = ReadNavAreaFloat(area, 0x14);
            position[2] = ReadNavAreaFloat(area, 0x18);
        }
        case NAV_CORNER_SOUTH_WEST:
        {
            position[0] = ReadNavAreaFloat(area, 0x04);
            position[1] = ReadNavAreaFloat(area, 0x14);
            position[2] = ReadNavAreaFloat(area, NAV_AREA_SOUTH_WEST_Z_OFFSET);
        }
    }
}

void GetNavAreaCenterCompat(Address area, float position[3])
{
    position[0] = ReadNavAreaFloat(area, NAV_AREA_CENTER_X_OFFSET);
    position[1] = ReadNavAreaFloat(area, NAV_AREA_CENTER_Y_OFFSET);
    position[2] = ReadNavAreaFloat(area, NAV_AREA_CENTER_Z_OFFSET);
}

float ReadNavAreaFloat(Address area, int offset)
{
    return view_as<float>(LoadFromAddress(
        area + view_as<Address>(offset), NumberType_Int32));
}

int CreateBoundaryEntities()
{
    RemoveBoundaryEntities();

    if (g_iBeamSprite <= 0 || g_aBoundaryEdges == null || g_aBoundaryEdges.Length == 0)
    {
        return 0;
    }

    float perimeter = GetBoundaryPerimeter();
    if (perimeter < 1.0)
    {
        return 0;
    }

    float configuredSpacing = g_cvStripeSpacing.FloatValue;
    if (configuredSpacing < 1.0)
    {
        configuredSpacing = 1.0;
    }

    int requested = RoundToFloor(perimeter / configuredSpacing);
    if (requested < 1)
    {
        requested = 1;
    }

    int headroom = GetMaxEntities() - GetEntityCount() - ENTITY_RESERVE;
    int budget = g_cvMaxBeams.IntValue;
    if (budget > headroom)
    {
        budget = headroom;
    }

    if (budget <= 0)
    {
        LogError("[SSAM] Not enough free edicts to create persistent boundary beams (entities=%d, max=%d, reserve=%d).",
            GetEntityCount(), GetMaxEntities(), ENTITY_RESERVE);
        return 0;
    }

    int stripeCount = requested < budget ? requested : budget;
    float effectiveSpacing = perimeter / float(stripeCount);
    float stripeHeight = g_cvStripeHeight.FloatValue;
    float slant = g_cvStripeSlant.FloatValue;
    float zOffset = g_cvZOffset.FloatValue;
    float width = g_cvStripeWidth.FloatValue;
    int alpha = g_cvAlpha.IntValue;

    float bottom[3];
    float top[3];
    int created = 0;

    for (int i = 0; i < stripeCount; i++)
    {
        float distance = float(i) * effectiveSpacing;
        if (!GetBoundaryPointAtDistance(distance, perimeter, bottom) ||
            !GetBoundaryPointAtDistance(distance + slant, perimeter, top))
        {
            continue;
        }

        FitBoundaryPointToGround(bottom);
        FitBoundaryPointToGround(top);
        bottom[2] += zOffset;
        top[2] += zOffset + stripeHeight;

        int entity = CreatePersistentBeam(bottom, top, width, alpha);
        if (entity == -1)
        {
            LogError("[SSAM] env_beam creation stopped at %d/%d. The map may be near its edict limit.",
                created, stripeCount);
            break;
        }

        g_aBeamEntities.Push(EntIndexToEntRef(entity));
        created++;
    }

    if (g_cvDebug.BoolValue)
    {
        LogMessage("[SSAM] Persistent render: perimeter=%.1f, requested=%d, budget=%d, created=%d, effective-spacing=%.1f, entities=%d/%d.",
            perimeter, requested, budget, created, effectiveSpacing, GetEntityCount(), GetMaxEntities());
    }

    return created;
}

float GetBoundaryPerimeter()
{
    float perimeter = 0.0;
    float edge[6];

    for (int i = 0; i < g_aBoundaryEdges.Length; i++)
    {
        g_aBoundaryEdges.GetArray(i, edge, sizeof(edge));
        float dx = edge[3] - edge[0];
        float dy = edge[4] - edge[1];
        perimeter += SquareRoot(dx * dx + dy * dy);
    }

    return perimeter;
}

bool GetBoundaryPointAtDistance(float distance, float perimeter, float point[3])
{
    while (distance >= perimeter)
    {
        distance -= perimeter;
    }

    while (distance < 0.0)
    {
        distance += perimeter;
    }

    float edge[6];

    for (int i = 0; i < g_aBoundaryEdges.Length; i++)
    {
        g_aBoundaryEdges.GetArray(i, edge, sizeof(edge));
        float dx = edge[3] - edge[0];
        float dy = edge[4] - edge[1];
        float edgeLength = SquareRoot(dx * dx + dy * dy);

        if (distance <= edgeLength || i == g_aBoundaryEdges.Length - 1)
        {
            float t = edgeLength > 0.0 ? distance / edgeLength : 0.0;
            if (t > 1.0)
            {
                t = 1.0;
            }

            point[0] = edge[0] + (edge[3] - edge[0]) * t;
            point[1] = edge[1] + (edge[4] - edge[1]) * t;
            point[2] = edge[2] + (edge[5] - edge[2]) * t;
            return true;
        }

        distance -= edgeLength;
    }

    return false;
}

void FitBoundaryPointToGround(float point[3])
{
    // A 2D hull deliberately discards intermediate collinear vertices. Recover
    // the local slope from the nearest starting-checkpoint NAV area first, then
    // snap to the actual world/brush surface with a short vertical trace.
    float navFloorZ;
    if (GetNearestSafeNavFloorZ(point, navFloorZ))
    {
        point[2] = navFloorZ;
    }

    float start[3];
    float end[3];
    start = point;
    end = point;
    start[2] += GROUND_TRACE_UP;
    end[2] -= GROUND_TRACE_DOWN;

    Handle trace = TR_TraceRayEx(start, end, MASK_SOLID_BRUSHONLY, RayType_EndPoint);
    if (TR_DidHit(trace) && !TR_StartSolid(trace))
    {
        float hit[3];
        TR_GetEndPosition(hit, trace);
        point[2] = hit[2];
    }
    delete trace;
}

bool GetNearestSafeNavFloorZ(const float point[3], float &floorZ)
{
    if (g_aSafeNavAreas == null || g_aSafeNavAreas.Length == 0)
    {
        return false;
    }

    bool found = false;
    float bestDistanceSq = 0.0;
    float bestHeightDelta = 0.0;
    float northWest[3];
    float northEast[3];
    float southEast[3];
    float southWest[3];

    for (int i = 0; i < g_aSafeNavAreas.Length; i++)
    {
        Address area = view_as<Address>(g_aSafeNavAreas.Get(i));
        if (area == Address_Null)
        {
            continue;
        }

        GetNavAreaCornerCompat(area, NAV_CORNER_NORTH_WEST, northWest);
        GetNavAreaCornerCompat(area, NAV_CORNER_NORTH_EAST, northEast);
        GetNavAreaCornerCompat(area, NAV_CORNER_SOUTH_EAST, southEast);
        GetNavAreaCornerCompat(area, NAV_CORNER_SOUTH_WEST, southWest);

        float minX = northWest[0] < southEast[0] ? northWest[0] : southEast[0];
        float maxX = northWest[0] > southEast[0] ? northWest[0] : southEast[0];
        float minY = northWest[1] < southEast[1] ? northWest[1] : southEast[1];
        float maxY = northWest[1] > southEast[1] ? northWest[1] : southEast[1];

        float sampleX = point[0];
        float sampleY = point[1];
        if (sampleX < minX)
        {
            sampleX = minX;
        }
        else if (sampleX > maxX)
        {
            sampleX = maxX;
        }
        if (sampleY < minY)
        {
            sampleY = minY;
        }
        else if (sampleY > maxY)
        {
            sampleY = maxY;
        }

        float dx = point[0] - sampleX;
        float dy = point[1] - sampleY;
        float distanceSq = dx * dx + dy * dy;

        float tx = maxX > minX ? (sampleX - minX) / (maxX - minX) : 0.0;
        float ty = maxY > minY ? (sampleY - minY) / (maxY - minY) : 0.0;
        float northZ = northWest[2] + (northEast[2] - northWest[2]) * tx;
        float southZ = southWest[2] + (southEast[2] - southWest[2]) * tx;
        float candidateZ = northZ + (southZ - northZ) * ty;
        float heightDelta = FloatAbs(candidateZ - point[2]);

        if (!found || distanceSq < bestDistanceSq - 0.01 ||
            (FloatAbs(distanceSq - bestDistanceSq) <= 0.01 && heightDelta < bestHeightDelta))
        {
            found = true;
            bestDistanceSq = distanceSq;
            bestHeightDelta = heightDelta;
            floorZ = candidateZ;
        }
    }

    return found;
}

int CreatePersistentBeam(const float start[3], const float end[3], float width, int alpha)
{
    int entity = CreateEntityByName("env_beam");
    if (entity == -1)
    {
        return -1;
    }

    char widthString[16];
    char alphaString[12];
    FloatToString(width, widthString, sizeof(widthString));
    IntToString(alpha, alphaString, sizeof(alphaString));

    TeleportEntity(entity, start, NULL_VECTOR, NULL_VECTOR);
    SetEntityModel(entity, SPRITE_BEAM);
    SetEntPropVector(entity, Prop_Data, "m_vecEndPos", end);

    DispatchKeyValue(entity, "targetname", "ssam_boundary_beam");
    DispatchKeyValue(entity, "texture", SPRITE_BEAM);
    DispatchKeyValue(entity, "rendercolor", "255 255 255");
    DispatchKeyValue(entity, "renderamt", alphaString);
    DispatchKeyValue(entity, "rendermode", "3");
    DispatchKeyValue(entity, "renderfx", "0");
    DispatchKeyValue(entity, "life", "0");
    DispatchKeyValue(entity, "BoltWidth", widthString);
    DispatchKeyValue(entity, "NoiseAmplitude", "0");
    DispatchKeyValue(entity, "TextureScroll", "0");
    DispatchKeyValue(entity, "TouchType", "0");
    DispatchKeyValue(entity, "damage", "0");
    DispatchKeyValue(entity, "spawnflags", "1");

    DispatchSpawn(entity);
    SetEntPropFloat(entity, Prop_Data, "m_fWidth", width);
    SetEntPropFloat(entity, Prop_Data, "m_fEndWidth", width);
    ActivateEntity(entity);
    AcceptEntityInput(entity, "TurnOn");
    SDKHook(entity, SDKHook_SetTransmit, OnBoundaryBeamTransmit);

    return entity;
}

public Action OnBoundaryBeamTransmit(int entity, int client)
{
    if (g_cvSurvivorsOnly.BoolValue &&
        (client < 1 || client > MaxClients || !IsClientInGame(client) || GetClientTeam(client) != 2))
    {
        return Plugin_Handled;
    }

    return Plugin_Continue;
}

void RemoveBoundaryEntities()
{
    if (g_aBeamEntities == null)
    {
        return;
    }

    for (int i = 0; i < g_aBeamEntities.Length; i++)
    {
        int entity = EntRefToEntIndex(g_aBeamEntities.Get(i));
        if (entity != INVALID_ENT_REFERENCE && IsValidEntity(entity))
        {
            AcceptEntityInput(entity, "Kill");
        }
    }

    g_aBeamEntities.Clear();
}

void ClearEdges()
{
    if (g_aBoundaryEdges != null)
    {
        g_aBoundaryEdges.Clear();
    }

    if (g_aSafeNavAreas != null)
    {
        g_aSafeNavAreas.Clear();
    }
}

void StopTimers()
{
    StopBuildTimer();
}

void StopBuildTimer()
{
    if (g_hBuildTimer != null)
    {
        delete g_hBuildTimer;
        g_hBuildTimer = null;
    }
}
