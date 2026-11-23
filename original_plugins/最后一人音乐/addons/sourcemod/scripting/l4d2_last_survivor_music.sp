#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <clientprefs>

#define PLUGIN_VERSION "1.2.0-night"
#define TEAM_SURVIVOR 2
#define STATE_CHECK_INTERVAL 0.25
#define VOLUME_FADE_INTERVAL 0.1
#define MUSIC_CHANNEL SNDCHAN_STATIC

public Plugin myinfo =
{
    name = "[L4D2] Last Survivor Music",
    author = "night",
    description = "只剩一名未倒地生还者时，向全体真人随机播放一首曲库音乐",
    version = PLUGIN_VERSION,
    url = "https://github.com/shengyejiong/Night-Plugins"
};

ConVar g_cvEnable;
ConVar g_cvVolume;
ConVar g_cvFadeIn;
ConVar g_cvFadeOut;
ConVar g_cvAnnounce;
ConVar g_cvRepeat;
Cookie g_cMuted;
ArrayList g_aTrackPaths;
ArrayList g_aTrackNames;
ArrayList g_aTrackDurations;
Handle g_hCheckTimer;
Handle g_hFadeTimer;

bool g_bMapActive;
bool g_bRoundEnded;
bool g_bPlaylistReady;
bool g_bLastStandActive;
bool g_bEpisodePlayed;
bool g_bCheckQueued;
bool g_bListening[MAXPLAYERS + 1];
bool g_bMuted[MAXPLAYERS + 1];
bool g_bPreferenceReady[MAXPLAYERS + 1];
bool g_bPreferenceChanged[MAXPLAYERS + 1];
bool g_bFadingOut;
int g_iStateEpoch;
int g_iLastTrack = -1;
float g_fCurrentVolume;
float g_fFadeStartVolume;
float g_fFadeTargetVolume;
float g_fFadeStartTime;
float g_fFadeDuration;
float g_fTrackEndTime;
char g_sPlayingSample[PLATFORM_MAX_PATH];

public void OnPluginStart()
{
    if (GetEngineVersion() != Engine_Left4Dead2)
    {
        SetFailState("本插件仅支持 Left 4 Dead 2。");
    }

    g_aTrackPaths = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
    g_aTrackNames = new ArrayList(ByteCountToCells(128));
    g_aTrackDurations = new ArrayList();
    g_cMuted = new Cookie("night_lsm_muted", "是否关闭最后一人音乐", CookieAccess_Private);
    g_cvEnable = CreateConVar("l4d2_lsm_enable", "1", "是否启用最后一人音乐。0=关闭，1=开启。", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvVolume = CreateConVar("l4d2_lsm_volume", "0.45", "播放音量，范围 0.0 到 1.0；下次播放生效。", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvFadeIn = CreateConVar("l4d2_lsm_fade_in", "1.5", "音乐淡入秒数，0=直接播放。", FCVAR_NOTIFY, true, 0.0, true, 15.0);
    g_cvFadeOut = CreateConVar("l4d2_lsm_fade_out", "1.0", "音乐淡出秒数，0=立即停止。", FCVAR_NOTIFY, true, 0.0, true, 15.0);
    g_cvAnnounce = CreateConVar("l4d2_lsm_announce", "1", "触发时是否向全体真人提示歌曲名。", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvRepeat = CreateConVar("l4d2_lsm_repeat", "1", "最后一人状态持续时，曲目播完是否自动随机下一首；只有一首时重播。0=只播一首。", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    CreateConVar("l4d2_last_survivor_music_version", PLUGIN_VERSION, "最后一人音乐插件版本。", FCVAR_NOTIFY | FCVAR_DONTRECORD);
    g_cvEnable.AddChangeHook(CvarChanged_Enable);

    HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
    HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
    HookEvent("mission_lost", Event_RoundEnd, EventHookMode_PostNoCopy);
    HookEvent("map_transition", Event_RoundEnd, EventHookMode_PostNoCopy);
    HookEvent("finale_vehicle_leaving", Event_RoundEnd, EventHookMode_PostNoCopy);

    HookEvent("player_incapacitated", Event_PlayerStateChanged, EventHookMode_PostNoCopy);
    HookEvent("player_death", Event_PlayerStateChanged, EventHookMode_PostNoCopy);
    HookEvent("player_spawn", Event_PlayerStateChanged, EventHookMode_PostNoCopy);
    HookEvent("player_team", Event_PlayerStateChanged, EventHookMode_PostNoCopy);
    HookEvent("revive_success", Event_PlayerStateChanged, EventHookMode_PostNoCopy);
    HookEvent("defibrillator_used", Event_PlayerStateChanged, EventHookMode_PostNoCopy);
    HookEvent("player_bot_replace", Event_PlayerStateChanged, EventHookMode_PostNoCopy);
    HookEvent("bot_player_replace", Event_PlayerStateChanged, EventHookMode_PostNoCopy);
    HookEventEx("player_ledge_grab", Event_PlayerStateChanged, EventHookMode_PostNoCopy);

    RegConsoleCmd("sm_lsm_status", Command_Status, "查看最后一人音乐的曲库和人数状态。");
    RegConsoleCmd("sm_musicoff", Command_MusicOff, "关闭自己听到的最后一人音乐。");
    RegConsoleCmd("sm_musicon", Command_MusicOn, "恢复自己听到的最后一人音乐。");
    RegAdminCmd("sm_lsmoff", Command_GlobalMusicOff, ADMFLAG_CONFIG, "关闭全服最后一人音乐。");
    RegAdminCmd("sm_lsmon", Command_GlobalMusicOn, ADMFLAG_CONFIG, "开启全服最后一人音乐。");
    AutoExecConfig(true, "l4d2_last_survivor_music");

    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsClientInGame(client) && !IsFakeClient(client) && AreClientCookiesCached(client))
        {
            LoadMusicPreference(client);
        }
    }
}

public void OnMapStart()
{
    g_bMapActive = true;
    g_bPlaylistReady = false;
    g_iLastTrack = -1;
    ResetRoundState();

    delete g_hCheckTimer;
    g_hCheckTimer = CreateTimer(STATE_CHECK_INTERVAL, Timer_CheckState, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public void OnConfigsExecuted()
{
    LoadPlaylist();
    g_bPlaylistReady = true;
    QueueStateCheck();
}

public void OnMapEnd()
{
    g_bMapActive = false;
    g_bPlaylistReady = false;
    EndRound(false);
    delete g_hCheckTimer;
    g_hCheckTimer = null;
}

public void OnPluginEnd()
{
    StopMusicImmediately();
    delete g_hCheckTimer;
    delete g_aTrackPaths;
    delete g_aTrackNames;
    delete g_aTrackDurations;
    delete g_cMuted;
}

public void OnClientConnected(int client)
{
    g_bListening[client] = false;
    g_bMuted[client] = false;
    g_bPreferenceReady[client] = false;
    g_bPreferenceChanged[client] = false;
}

public void OnClientPutInServer(int client)
{
    g_bListening[client] = false;
    if (!IsFakeClient(client) && AreClientCookiesCached(client))
    {
        LoadMusicPreference(client);
    }
    QueueStateCheck();
}

public void OnClientDisconnect(int client)
{
    g_bListening[client] = false;
    g_bMuted[client] = false;
    g_bPreferenceReady[client] = false;
    g_bPreferenceChanged[client] = false;
    QueueStateCheck();
}

public void OnClientCookiesCached(int client)
{
    LoadMusicPreference(client);
    QueueStateCheck();
}

void LoadMusicPreference(int client)
{
    if (client < 1 || client > MaxClients || !IsClientConnected(client) || IsFakeClient(client))
    {
        return;
    }
    g_bPreferenceReady[client] = true;
    if (g_bPreferenceChanged[client])
    {
        // Cookie 异步载入前已经手动设置时，以本次手动选择为准。
        g_cMuted.Set(client, g_bMuted[client] ? "1" : "0");
        g_bPreferenceChanged[client] = false;
    }
    else
    {
        char value[8];
        g_cMuted.Get(client, value, sizeof(value));
        g_bMuted[client] = StrEqual(value, "1");
    }
    if (g_bMuted[client])
    {
        StopMusicForClient(client);
    }
}

public void CvarChanged_Enable(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (!convar.BoolValue)
    {
        FadeOutMusic();
        g_bLastStandActive = false;
        g_bEpisodePlayed = false;
    }
    QueueStateCheck();
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    ResetRoundState();
    QueueStateCheck();
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    EndRound();
}

void ResetRoundState()
{
    StopMusicImmediately();
    g_bRoundEnded = false;
    g_bLastStandActive = false;
    g_bEpisodePlayed = false;
    g_bCheckQueued = false;
    g_iStateEpoch++;
}

void EndRound(bool fadeOut = true)
{
    if (fadeOut)
    {
        FadeOutMusic();
    }
    else
    {
        StopMusicImmediately();
    }
    g_bRoundEnded = true;
    g_bLastStandActive = false;
    g_bEpisodePlayed = false;
    g_bCheckQueued = false;
    g_iStateEpoch++;
}

public void Event_PlayerStateChanged(Event event, const char[] name, bool dontBroadcast)
{
    QueueStateCheck();
}

public Action Timer_CheckState(Handle timer)
{
    CheckTrackEnd();
    QueueStateCheck();
    return Plugin_Continue;
}

void QueueStateCheck()
{
    if (!g_bMapActive || g_bRoundEnded || g_bCheckQueued)
    {
        return;
    }

    // 合并同一帧的多次倒地/死亡事件，读取最终状态，避免全员同时倒地时误播。
    g_bCheckQueued = true;
    RequestFrame(Frame_CheckState, g_iStateEpoch);
}

public void Frame_CheckState(any epoch)
{
    if (epoch != g_iStateEpoch)
    {
        return;
    }
    g_bCheckQueued = false;

    if (!g_bMapActive || g_bRoundEnded || !g_bPlaylistReady || !g_cvEnable.BoolValue)
    {
        return;
    }

    int survivors, standing, lastSurvivor;
    CountSurvivors(survivors, standing, lastSurvivor);
    bool lastStand = survivors >= 2 && standing == 1;
    if (!lastStand)
    {
        FadeOutMusic();
        g_bLastStandActive = false;
        g_bEpisodePlayed = false;
        return;
    }

    bool entering = !g_bLastStandActive;
    g_bLastStandActive = true;
    if (CountMusicListeners() <= 0)
    {
        // 全体关闭或偏好尚未载入时，不创建不可听见的播放和循环。
        StopMusicImmediately();
        return;
    }

    if (entering || (g_sPlayingSample[0] == '\0' && (!g_bEpisodePlayed || g_cvRepeat.BoolValue)))
    {
        if (PlayRandomTrack(lastSurvivor))
        {
            g_bEpisodePlayed = true;
        }
    }
}

void CountSurvivors(int &survivors, int &standing, int &lastSurvivor)
{
    survivors = 0;
    standing = 0;
    lastSurvivor = 0;
    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsClientInGame(client) || IsClientInKickQueue(client) || GetClientTeam(client) != TEAM_SURVIVOR)
        {
            continue;
        }

        survivors++;
        if (IsPlayerAlive(client)
            && !GetEntProp(client, Prop_Send, "m_isIncapacitated")
            && !GetEntProp(client, Prop_Send, "m_isHangingFromLedge"))
        {
            standing++;
            lastSurvivor = client;
        }
    }
}

bool IsMusicListener(int client)
{
    return IsClientInGame(client) && !IsFakeClient(client) && !IsClientInKickQueue(client)
        && g_bPreferenceReady[client] && !g_bMuted[client];
}

int CountMusicListeners()
{
    int listeners = 0;
    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsMusicListener(client))
        {
            listeners++;
        }
    }
    return listeners;
}

bool PlayRandomTrack(int lastSurvivor)
{
    int count = g_aTrackPaths.Length;
    if (count <= 0 || g_cvVolume.FloatValue <= 0.0)
    {
        return false;
    }

    if (CountMusicListeners() <= 0)
    {
        return false;
    }

    // 状态短暂恢复后又只剩一人：取消淡出并沿当前进度淡入，不重播歌曲。
    if (g_sPlayingSample[0] != '\0' && g_bFadingOut
        && (g_fTrackEndTime <= 0.0 || GetGameTime() < g_fTrackEndTime))
    {
        StartVolumeFade(g_cvVolume.FloatValue, g_cvFadeIn.FloatValue);
        return true;
    }

    StopMusicImmediately();
    int index;
    if (count > 1 && g_iLastTrack >= 0 && g_iLastTrack < count)
    {
        index = GetRandomInt(0, count - 2);
        if (index >= g_iLastTrack)
        {
            index++;
        }
    }
    else
    {
        index = GetRandomInt(0, count - 1);
    }

    g_aTrackPaths.GetString(index, g_sPlayingSample, sizeof(g_sPlayingSample));
    g_iLastTrack = index;
    float duration = g_aTrackDurations.Get(index);
    g_fTrackEndTime = duration > 0.0 ? GetGameTime() + duration : 0.0;
    float targetVolume = g_cvVolume.FloatValue;
    // 新声道以非零低音量启动，避免引擎忽略音量为零的首次播放。
    g_fCurrentVolume = g_cvFadeIn.FloatValue > 0.0 && targetVolume > 0.01 ? 0.01 : targetVolume;
    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsMusicListener(client))
        {
            EmitSoundToClient(client, g_sPlayingSample, client, MUSIC_CHANNEL, SNDLEVEL_NONE, SND_NOFLAGS, g_fCurrentVolume);
            g_bListening[client] = true;
        }
    }

    StartVolumeFade(targetVolume, g_cvFadeIn.FloatValue);

    if (g_cvAnnounce.BoolValue)
    {
        char title[128];
        g_aTrackNames.GetString(index, title, sizeof(title));
        for (int client = 1; client <= MaxClients; client++)
        {
            if (g_bListening[client] && IsMusicListener(client))
            {
                PrintToChat(client, "\x04[最后一人音乐]\x05 仅剩 \x03%N\x05 站立，播放：\x03%s\x05。", lastSurvivor, title);
            }
        }
    }
    return true;
}

void FadeOutMusic()
{
    // 人数轮询可能每 0.25 秒重复请求停止，不能反复重置淡出起点。
    if (g_sPlayingSample[0] == '\0' || g_bFadingOut)
    {
        return;
    }

    StartVolumeFade(0.0, g_cvFadeOut.FloatValue);
}

void StartVolumeFade(float targetVolume, float duration)
{
    delete g_hFadeTimer;
    g_hFadeTimer = null;
    if (g_sPlayingSample[0] == '\0')
    {
        return;
    }

    g_bFadingOut = targetVolume <= 0.0;
    if (duration <= 0.0 || FloatAbs(targetVolume - g_fCurrentVolume) < 0.0001)
    {
        if (g_bFadingOut)
        {
            StopMusicImmediately();
        }
        else
        {
            ApplyMusicVolume(targetVolume);
        }
        return;
    }

    g_fFadeStartVolume = g_fCurrentVolume;
    g_fFadeTargetVolume = targetVolume;
    g_fFadeStartTime = GetGameTime();
    g_fFadeDuration = duration;
    g_hFadeTimer = CreateTimer(VOLUME_FADE_INTERVAL, Timer_FadeMusic, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_FadeMusic(Handle timer)
{
    if (timer != g_hFadeTimer)
    {
        return Plugin_Stop;
    }
    if (g_sPlayingSample[0] == '\0' || (g_fTrackEndTime > 0.0 && GetGameTime() >= g_fTrackEndTime))
    {
        g_hFadeTimer = null;
        StopMusicImmediately();
        return Plugin_Stop;
    }

    float progress = (GetGameTime() - g_fFadeStartTime) / g_fFadeDuration;
    if (progress > 1.0)
    {
        progress = 1.0;
    }
    ApplyMusicVolume(g_fFadeStartVolume + (g_fFadeTargetVolume - g_fFadeStartVolume) * progress);

    if (progress >= 1.0)
    {
        g_hFadeTimer = null;
        if (g_bFadingOut)
        {
            StopMusicImmediately();
        }
        return Plugin_Stop;
    }
    return Plugin_Continue;
}

void ApplyMusicVolume(float volume)
{
    g_fCurrentVolume = volume;
    for (int client = 1; client <= MaxClients; client++)
    {
        if (g_bListening[client] && IsMusicListener(client))
        {
            // 使用同一实体、声道和歌曲，只改音量，不从头发起播放。
            EmitSoundToClient(client, g_sPlayingSample, client, MUSIC_CHANNEL, SNDLEVEL_NONE, SND_CHANGEVOL, volume);
        }
    }
}

void CheckTrackEnd()
{
    if (g_sPlayingSample[0] == '\0' || g_fTrackEndTime <= 0.0)
    {
        return;
    }

    float remaining = g_fTrackEndTime - GetGameTime();
    if (remaining <= 0.0)
    {
        StopMusicImmediately();
    }
    else if (!g_bFadingOut && g_cvFadeOut.FloatValue > 0.0 && remaining <= g_cvFadeOut.FloatValue)
    {
        StartVolumeFade(0.0, remaining);
    }
}

void StopMusicImmediately()
{
    delete g_hFadeTimer;
    g_hFadeTimer = null;
    for (int client = 1; client <= MaxClients; client++)
    {
        if (g_sPlayingSample[0] != '\0' && g_bListening[client] && IsClientInGame(client) && !IsFakeClient(client))
        {
            StopSound(client, MUSIC_CHANNEL, g_sPlayingSample);
        }
        g_bListening[client] = false;
    }
    g_sPlayingSample[0] = '\0';
    g_bFadingOut = false;
    g_fCurrentVolume = 0.0;
    g_fTrackEndTime = 0.0;
}

void StopMusicForClient(int client)
{
    if (g_sPlayingSample[0] != '\0' && g_bListening[client]
        && IsClientInGame(client) && !IsFakeClient(client))
    {
        StopSound(client, MUSIC_CHANNEL, g_sPlayingSample);
    }
    g_bListening[client] = false;
}

void SetMusicPreference(int client, bool muted)
{
    g_bMuted[client] = muted;
    g_bPreferenceReady[client] = true;
    g_bPreferenceChanged[client] = true;
    if (AreClientCookiesCached(client))
    {
        g_cMuted.Set(client, muted ? "1" : "0");
        g_bPreferenceChanged[client] = false;
    }
}

public Action Command_MusicOff(int client, int args)
{
    if (client < 1 || client > MaxClients || !IsClientInGame(client) || IsFakeClient(client))
    {
        ReplyToCommand(client, "[最后一人音乐] 个人开关请在游戏中使用，全服开关为 sm_lsmoff / sm_lsmon。");
        return Plugin_Handled;
    }

    SetMusicPreference(client, true);
    StopMusicForClient(client);
    QueueStateCheck();
    ReplyToCommand(client, "[最后一人音乐] 已关闭你的音乐，不影响其他人；输入 !musicon 恢复。该设置会记住。");
    return Plugin_Handled;
}

public Action Command_MusicOn(int client, int args)
{
    if (client < 1 || client > MaxClients || !IsClientInGame(client) || IsFakeClient(client))
    {
        ReplyToCommand(client, "[最后一人音乐] 个人开关请在游戏中使用，全服开关为 sm_lsmoff / sm_lsmon。");
        return Plugin_Handled;
    }

    SetMusicPreference(client, false);
    QueueStateCheck();
    if (!g_cvEnable.BoolValue)
    {
        ReplyToCommand(client, "[最后一人音乐] 已开启你的收听偏好；目前全服开关已关闭，等待管理员开启后生效。");
    }
    else if (g_bListening[client])
    {
        ReplyToCommand(client, "[最后一人音乐] 你的音乐已开启，当前正在收听。");
    }
    else
    {
        ReplyToCommand(client, "[最后一人音乐] 已开启你的音乐，从下一首或下次触发时恢复，不会从歌曲中途接入。");
    }
    return Plugin_Handled;
}

public Action Command_GlobalMusicOff(int client, int args)
{
    g_cvEnable.BoolValue = false;
    ReplyToCommand(client, "[最后一人音乐] 全服播放已关闭，个人偏好保留。");
    LogAction(client, -1, "关闭了全服最后一人音乐。");
    return Plugin_Handled;
}

public Action Command_GlobalMusicOn(int client, int args)
{
    g_cvEnable.BoolValue = true;
    QueueStateCheck();
    ReplyToCommand(client, "[最后一人音乐] 全服播放已开启，个人关闭设置仍然生效。");
    LogAction(client, -1, "开启了全服最后一人音乐。");
    return Plugin_Handled;
}

void LoadPlaylist()
{
    StopMusicImmediately();
    g_aTrackPaths.Clear();
    g_aTrackNames.Clear();
    g_aTrackDurations.Clear();
    g_iLastTrack = -1;

    char configPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, configPath, sizeof(configPath), "configs/l4d2_last_survivor_music.cfg");
    KeyValues playlist = new KeyValues("LastSurvivorMusic");
    if (!playlist.ImportFromFile(configPath))
    {
        LogError("无法读取曲库：%s；本地图不会播放音乐。", configPath);
        delete playlist;
        return;
    }

    if (playlist.GotoFirstSubKey())
    {
        do
        {
            char sample[PLATFORM_MAX_PATH];
            char title[128];
            playlist.GetString("path", sample, sizeof(sample));
            playlist.GetSectionName(title, sizeof(title));
            if (!IsValidSamplePath(sample))
            {
                LogError("跳过歌曲 %s：path 必须是 sound 下的相对 MP3/WAV 路径，只使用英文、数字、下划线、连字符和斜线。", title);
                continue;
            }

            char downloadPath[PLATFORM_MAX_PATH + 8];
            FormatEx(downloadPath, sizeof(downloadPath), "sound/%s", sample);
            if (!FileExists(downloadPath, true))
            {
                LogError("跳过歌曲 %s：服务器缺少 %s。", title, downloadPath);
                continue;
            }
            if (g_aTrackPaths.FindString(sample) != -1)
            {
                continue;
            }
            if (!PrecacheSound(sample, true))
            {
                LogError("跳过歌曲 %s：预缓存失败 %s。", title, sample);
                continue;
            }

            AddFileToDownloadsTable(downloadPath);
            g_aTrackPaths.PushString(sample);
            g_aTrackNames.PushString(title);
            float duration = playlist.GetFloat("duration", 0.0);
            g_aTrackDurations.Push(duration > 0.0 ? duration : 0.0);
            if (duration <= 0.0)
            {
                LogMessage("歌曲 %s 未配置 duration，无法判断结束时间或自动重播；其他停止条件仍生效。", title);
            }
        }
        while (playlist.GotoNextKey());
    }
    delete playlist;

    LogMessage("本地图已加载 %d 首音乐；空曲库时仅检测状态，不播放。", g_aTrackPaths.Length);
}

bool IsValidSamplePath(const char[] sample)
{
    int length = strlen(sample);
    if (length < 5 || sample[0] == '/' || StrContains(sample, "..") != -1
        || StrContains(sample, "sound/", false) == 0)
    {
        return false;
    }
    if (!StrEqual(sample[length - 4], ".mp3", false) && !StrEqual(sample[length - 4], ".wav", false))
    {
        return false;
    }

    for (int i = 0; i < length; i++)
    {
        char c = sample[i];
        if (!(c >= 'a' && c <= 'z') && !(c >= 'A' && c <= 'Z') && !(c >= '0' && c <= '9')
            && c != '_' && c != '-' && c != '/' && c != '.')
        {
            return false;
        }
    }
    return true;
}

public Action Command_Status(int client, int args)
{
    int survivors, standing, lastSurvivor;
    CountSurvivors(survivors, standing, lastSurvivor);
    ReplyToCommand(client, "[最后一人音乐] 开关:%d | 曲库:%d | 生还者:%d | 站立:%d", g_cvEnable.BoolValue, g_aTrackPaths.Length, survivors, standing);
    ReplyToCommand(client, "[最后一人音乐] 回合结束:%d | 最后一人状态:%d | 歌曲:%s", g_bRoundEnded, g_bLastStandActive, g_sPlayingSample[0] != '\0' ? g_sPlayingSample : "无");
    ReplyToCommand(client, "[最后一人音乐] 当前音量:%.2f | 淡入:%.1f秒 | 淡出:%.1f秒 | 正在淡出:%d", g_fCurrentVolume, g_cvFadeIn.FloatValue, g_cvFadeOut.FloatValue, g_bFadingOut);
    ReplyToCommand(client, "[最后一人音乐] 自动重播:%d | 允许收听人数:%d", g_cvRepeat.BoolValue, CountMusicListeners());
    if (client >= 1 && client <= MaxClients && IsClientInGame(client))
    {
        ReplyToCommand(client, "[最后一人音乐] 你的收听开关:%d | 当前正在收听:%d", !g_bMuted[client], g_bListening[client]);
    }
    return Plugin_Handled;
}
