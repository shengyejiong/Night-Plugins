#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#pragma semicolon 1

#define TEAM_SURVIVOR 2

// ConVar：友伤阈值（达到此值后封禁）
Handle g_cvFFThreshold = INVALID_HANDLE;

// 每个玩家的友伤统计（索引 1~MaxClients）
int g_iFriendlyFire[MAXPLAYERS + 1];

// 记录每次伤害发生前，受害者是否已经处于倒地状态。
// 不能只在 player_hurt 中检查，否则可能把造成倒地的那一下也排除。
bool g_bVictimWasIncapacitated[MAXPLAYERS + 1];

public Plugin myinfo =
{
    name = "L4D2 Friendly Fire Ban",
    author = "night",
    description = "每关统计站立生还者受到的友伤，达到阈值后封禁非管理员玩家5分钟",
    version = "1.2.0",
    url = ""
};

public void OnPluginStart()
{
    // 创建 ConVar，可在 server.cfg 或控制台修改
    g_cvFFThreshold = CreateConVar("sm_ff_ban_threshold", "100", "友伤达到多少点伤害后封禁（0=禁用功能）", FCVAR_NOTIFY);
    
    // 钩子伤害事件
    HookEvent("player_hurt", Event_PlayerHurt);
    
    // 每关开始时重置所有统计
    HookEvent("round_start", Event_RoundStart);

    // 支持插件在地图中途加载，为当前已经在线的玩家补上伤害前置钩子。
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
        {
            SDKHook(i, SDKHook_OnTakeDamageAlive, OnTakeDamageAlive);
        }
    }
}

public void OnMapStart()
{
    // 新地图开始时清零所有玩家的友伤统计
    for (int i = 1; i <= MaxClients; i++)
    {
        g_iFriendlyFire[i] = 0;
        g_bVictimWasIncapacitated[i] = false;
    }
}

public void OnClientPutInServer(int client)
{
    g_iFriendlyFire[client] = 0;
    g_bVictimWasIncapacitated[client] = false;
    SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamageAlive);
}

public void OnClientDisconnect(int client)
{
    g_iFriendlyFire[client] = 0;
    g_bVictimWasIncapacitated[client] = false;
}

public void Event_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
        {
            g_iFriendlyFire[i] = 0;
            g_bVictimWasIncapacitated[i] = false;
        }
    }
}

public Action OnTakeDamageAlive(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
    if (victim >= 1 && victim <= MaxClients && IsClientInGame(victim) && GetClientTeam(victim) == TEAM_SURVIVOR)
    {
        g_bVictimWasIncapacitated[victim] = IsGroundIncapacitated(victim);
    }
    return Plugin_Continue;
}

public void Event_PlayerHurt(Handle event, const char[] name, bool dontBroadcast)
{
    int victim = GetClientOfUserId(GetEventInt(event, "userid"));
    int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
    int damage = GetEventInt(event, "dmg_health");

    // 基本验证
    if (victim == 0 || attacker == 0 || damage <= 0)
        return;

    if (!IsClientInGame(victim) || !IsClientInGame(attacker))
        return;

    // 必须双方都是幸存者队伍，且不是自伤
    if (GetClientTeam(victim) != TEAM_SURVIVOR || GetClientTeam(attacker) != TEAM_SURVIVOR || attacker == victim)
        return;

    // 伤害发生前已经倒地的玩家不计入友伤；造成倒地的那一下仍会正常累计。
    if (g_bVictimWasIncapacitated[victim])
        return;

    // 累计友伤
    g_iFriendlyFire[attacker] += damage;

    int threshold = GetConVarInt(g_cvFFThreshold);
    if (threshold <= 0)
        return; // 功能已关闭

    // 检查是否达到阈值
    if (g_iFriendlyFire[attacker] >= threshold)
    {
        // 检查是否为管理员（有任意 Admin Flag 就算管理员）
        AdminId admin = GetUserAdmin(attacker);
        if (admin == INVALID_ADMIN_ID || !GetAdminFlag(admin, Admin_Generic))
        {
            // 不是管理员 → 封禁5分钟
            int userid = GetClientUserId(attacker);
            char command[128];
            Format(command, sizeof(command), "banid 5 %d kick", userid);
            ServerCommand(command);
            
            // 广播消息
            PrintToChatAll("\x04[友伤封禁]\x01 玩家 \x05%N\x01 友伤已达 \x03%d\x01 点，被临时封禁5分钟。", attacker, g_iFriendlyFire[attacker]);
            
            // 日志
            LogAction(attacker, -1, "[FF Ban] Player %L banned for 5 minutes (FF damage: %d)", attacker, g_iFriendlyFire[attacker]);
        }
        else
        {
            // 管理员达到阈值只提示，不封禁
            PrintHintText(attacker, "你的友伤已达 %d 点（管理员豁免）", g_iFriendlyFire[attacker]);
        }
    }
}

bool IsGroundIncapacitated(int client)
{
    return GetEntProp(client, Prop_Send, "m_isIncapacitated") != 0
        && GetEntProp(client, Prop_Send, "m_isHangingFromLedge") == 0;
}

public void OnPluginEnd()
{
    // 插件卸载时关闭 ConVar（好习惯）
    if (g_cvFFThreshold != INVALID_HANDLE)
    {
        CloseHandle(g_cvFFThreshold);
        g_cvFFThreshold = INVALID_HANDLE;
    }
}
