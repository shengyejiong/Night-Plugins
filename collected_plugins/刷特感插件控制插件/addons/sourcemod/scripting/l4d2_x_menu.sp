#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <l4d2_nativevote>

#define MULTISI_PLUGIN_PRIMARY_FILE "specialspawner_fullslots.smx"
#define MULTISI_PLUGIN_PRIMARY_NAME "specialspawner_fullslots"
#define MULTISI_PLUGIN_LEGACY_FILE "specialspawner.smx"
#define MULTISI_PLUGIN_LEGACY_NAME "specialspawner"
#define MULTISI_STATE_ENABLED 1
#define MULTISI_STATE_RETRIED 2
#define SI_CLASS_COUNT 6

static const char g_sSIClassConVars[SI_CLASS_COUNT][] = {
    "ss_smoker_limit",
    "ss_boomer_limit",
    "ss_hunter_limit",
    "ss_spitter_limit",
    "ss_jockey_limit",
    "ss_charger_limit"
};

static const char g_sSIClassNames[SI_CLASS_COUNT][] = {
    "Smoker（舌头）",
    "Boomer（胖子）",
    "Hunter（猎人）",
    "Spitter（口水）",
    "Jockey（猴子）",
    "Charger（牛）"
};

public Plugin myinfo = {
    name = "L4D2 Multi-Function X Menu",
    author = "らくらく安楽死 & night",
    description = "多功能控制菜单 (!x)",
    version = "3.1.0-night",
};

bool g_bMultiSI_Enabled = false;
int g_iCurrentLimit = 0;
int g_iCurrentSpawnSize = 0;
int g_iCurrentSILimit = 0;
int g_iCurrentTime = 0;
float g_fCurrentTimeMin = 0.0;
float g_fCurrentTimeMax = 0.0;
float g_fExtraLimit = 0.0;
float g_fExtraSize = 1.0;

bool g_bHasVotedToggle = false;
bool g_bSavedToggleState = false;

bool g_bHasVotedLimit = false;
int g_iSavedLimit = 0;

bool g_bHasVotedTime = false;
int g_iSavedTime = 0;

public void OnPluginStart() {
    RegConsoleCmd("sm_x", Command_XMenu, "打开多功能控制菜单");
}

public void OnConfigsExecuted() {
    if (g_bHasVotedToggle || g_bHasVotedLimit || g_bHasVotedTime) {
        CreateTimer(1.0, Timer_EnforceOverrides, _, TIMER_FLAG_NO_MAPCHANGE);
    }
}

public Action Timer_EnforceOverrides(Handle timer) {
    if (g_bHasVotedToggle) {
        SetMultiSIPluginState(g_bSavedToggleState);
        if (!g_bSavedToggleState) {
            return Plugin_Continue; 
        }
    }
    
    CreateTimer(0.5, Timer_EnforceCvars, _, TIMER_FLAG_NO_MAPCHANGE);
    return Plugin_Continue;
}

public Action Timer_EnforceCvars(Handle timer) {
    UpdateCurrentState();
    if (g_bMultiSI_Enabled) {
        if (g_bHasVotedLimit) {
            ServerCommand("sm_cvar ss_base_limit %d", g_iSavedLimit);
            ServerCommand("sm_cvar ss_base_size %d", g_iSavedLimit);
        }
        if (g_bHasVotedTime) {
            ServerCommand("sm_cvar ss_time_min %d", g_iSavedTime);
            ServerCommand("sm_cvar ss_time_max %d", g_iSavedTime + 1);
        }
        ServerExecute();
        ApplyPopulationScaling(false);
    }
    return Plugin_Continue;
}

public void OnClientPutInServer(int client) {
    if (!IsFakeClient(client)) {
        CreateTimer(8.5, Timer_WelcomeAnnounce, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
    }
}

public Action Timer_WelcomeAnnounce(Handle timer, any userid) {
    int client = GetClientOfUserId(userid);
    if (client && IsClientInGame(client)) {
        UpdateCurrentState();
        if (g_bMultiSI_Enabled) {
            PrintCurrentState(client);
        }
    }
    return Plugin_Continue;
}

void UpdateCurrentState() {
    g_bMultiSI_Enabled = IsMultiSIPluginRunning();

    if (g_bMultiSI_Enabled) {
        ConVar cvBaseLimit = FindConVar("ss_base_limit");
        ConVar cvSpawnSize = FindConVar("ss_spawn_size");
        ConVar cvSILimit = FindConVar("ss_si_limit");
        ConVar cvTimeMin = FindConVar("ss_time_min");
        ConVar cvTimeMax = FindConVar("ss_time_max");
        ConVar cvExtraLimit = FindConVar("ss_extra_limit");
        ConVar cvExtraSize = FindConVar("ss_extra_size");

        if (cvBaseLimit != null) g_iCurrentLimit = cvBaseLimit.IntValue;
        if (cvSpawnSize != null) g_iCurrentSpawnSize = cvSpawnSize.IntValue;
        if (cvSILimit != null) g_iCurrentSILimit = cvSILimit.IntValue;
        if (cvTimeMin != null) {
            g_fCurrentTimeMin = cvTimeMin.FloatValue;
            g_iCurrentTime = RoundToNearest(g_fCurrentTimeMin);
        }
        if (cvTimeMax != null) g_fCurrentTimeMax = cvTimeMax.FloatValue;
        if (cvExtraLimit != null) g_fExtraLimit = cvExtraLimit.FloatValue;
        if (cvExtraSize != null) g_fExtraSize = cvExtraSize.FloatValue;
    }
}

bool IsMultiSIPluginRunning() {
    return IsPluginFileRunning(MULTISI_PLUGIN_PRIMARY_FILE) || IsPluginFileRunning(MULTISI_PLUGIN_LEGACY_FILE);
}

bool IsPluginFileRunning(const char[] filename) {
    Handle plugin = FindPluginByFile(filename);
    return plugin != null && GetPluginStatus(plugin) == Plugin_Running;
}

bool IsPluginFileLoaded(const char[] filename) {
    return FindPluginByFile(filename) != null;
}

void SetMultiSIPluginState(bool enabled) {
    if (enabled) {
        if (!IsMultiSIPluginRunning()) {
            ServerCommand("sm plugins load %s", MULTISI_PLUGIN_PRIMARY_NAME);
        }
    } else {
        if (IsPluginFileLoaded(MULTISI_PLUGIN_PRIMARY_FILE)) {
            ServerCommand("sm plugins unload %s", MULTISI_PLUGIN_PRIMARY_NAME);
        }
        if (IsPluginFileLoaded(MULTISI_PLUGIN_LEGACY_FILE)) {
            ServerCommand("sm plugins unload %s", MULTISI_PLUGIN_LEGACY_NAME);
        }
    }
    ServerExecute();
}

void ScheduleMultiSIStateCheck(bool enabled, bool retried = false) {
    int stateData = enabled ? MULTISI_STATE_ENABLED : 0;
    if (retried) {
        stateData |= MULTISI_STATE_RETRIED;
    }

    CreateTimer(retried ? 0.5 : 0.3, Timer_ConfirmMultiSIState, stateData, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_ConfirmMultiSIState(Handle timer, any stateData) {
    bool enabled = (stateData & MULTISI_STATE_ENABLED) != 0;
    bool retried = (stateData & MULTISI_STATE_RETRIED) != 0;

    // 新投票已经改变目标状态时，丢弃旧确认，避免过期 Timer 误报。
    if (enabled != g_bSavedToggleState) {
        return Plugin_Stop;
    }

    UpdateCurrentState();
    if (g_bMultiSI_Enabled == enabled) {
        if (enabled) {
            CreateTimer(0.2, Timer_EnforceCvars, _, TIMER_FLAG_NO_MAPCHANGE);
            CreateTimer(0.5, Timer_BroadcastState_All, _, TIMER_FLAG_NO_MAPCHANGE);
        } else {
            PrintToChatAll("\x04[系统]\x01 多特模式已关闭，交还系统导演控制。");
        }
        return Plugin_Stop;
    }

    if (!retried) {
        SetMultiSIPluginState(enabled);
        ScheduleMultiSIStateCheck(enabled, true);
        return Plugin_Stop;
    }

    if (enabled) {
        g_bHasVotedToggle = false;
        PrintToChatAll("\x04[系统]\x01 多特插件加载失败，请管理员检查 \x05%s\x01。", MULTISI_PLUGIN_PRIMARY_FILE);
    } else {
        PrintToChatAll("\x04[系统]\x01 多特插件卸载失败，请管理员检查插件状态。");
    }
    return Plugin_Stop;
}

void PrintCurrentState(int client) {
    PrintToChat(client,
        "\x04[系统]\x01 当前多特：每批\x05%d\x01特，场上上限\x05%d\x01特，刷新\x05%.1f~%.1f\x01秒；输入 \x03!x\x01 更改配置",
        g_iCurrentSpawnSize, g_iCurrentSILimit, g_fCurrentTimeMin, g_fCurrentTimeMax);
}

void PrintCurrentStateAll() {
    PrintToChatAll(
        "\x04[系统]\x01 当前多特：每批\x05%d\x01特，场上上限\x05%d\x01特，刷新\x05%.1f~%.1f\x01秒；输入 \x03!x\x01 更改配置",
        g_iCurrentSpawnSize, g_iCurrentSILimit, g_fCurrentTimeMin, g_fCurrentTimeMax);
}

public Action Command_XMenu(int client, int args) {
    if (client == 0) return Plugin_Handled;
    ShowMenu_Level1(client);
    return Plugin_Handled;
}

void ShowMenu_Level1(int client) {
    Menu menu = new Menu(MenuHandler_Level1);
    menu.SetTitle("★ 综合多功能控制菜单 ★\n-------------------");
    menu.AddItem("1", "特感配置");
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Level1(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        char info[32];
        menu.GetItem(param2, info, sizeof(info));
        if (strcmp(info, "1") == 0) {
            ShowMenu_Level2_SI(param1);
        }
    }
    else if (action == MenuAction_End) {
        delete menu;
    }
    return 0;
}

void ShowMenu_Level2_SI(int client) {
    UpdateCurrentState(); 
    
    Menu menu = new Menu(MenuHandler_Level2_SI);
    if (g_bMultiSI_Enabled) {
        menu.SetTitle("★ 特感配置 ★\n当前：%d特/次，上限%d特，%.1f~%.1f秒\n动态：每多1人上限+%.1f，每%.1f人每批+1\n-------------------",
            g_iCurrentSpawnSize, g_iCurrentSILimit, g_fCurrentTimeMin, g_fCurrentTimeMax,
            g_fExtraLimit, g_fExtraSize);
    } else {
        menu.SetTitle("★ 特感配置 ★\n当前：多特已关闭\n-------------------");
    }
    menu.AddItem("toggle", "开关多特");
    
    if (g_bMultiSI_Enabled) {
        menu.AddItem("limit", "基础特感数量");
        menu.AddItem("class_limits", "各类特感上限");
        menu.AddItem("time", "刷特时间");
    }
    
    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Level2_SI(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        char info[32];
        menu.GetItem(param2, info, sizeof(info));
        
        if (strcmp(info, "toggle") == 0) ShowMenu_Level3_Toggle(param1);
        else if (strcmp(info, "limit") == 0) ShowMenu_Level3_Limit(param1);
        else if (strcmp(info, "class_limits") == 0) ShowMenu_Level3_ClassLimits(param1);
        else if (strcmp(info, "time") == 0) ShowMenu_Level3_Time(param1);
    }
    else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
        ShowMenu_Level1(param1);
    }
    else if (action == MenuAction_End) {
        delete menu;
    }
    return 0;
}

void ShowMenu_Level3_Toggle(int client) {
    UpdateCurrentState(); 
    Menu menu = new Menu(MenuHandler_Level3_Toggle);
    menu.SetTitle("★ 开关多特 ★\n当前：%s\n-------------------", g_bMultiSI_Enabled ? "已开启" : "已关闭");
    
    char item1[64], item2[64];
    Format(item1, sizeof(item1), "[%s] 开启多特", g_bMultiSI_Enabled ? "✓" : "  ");
    Format(item2, sizeof(item2), "[%s] 关闭多特", !g_bMultiSI_Enabled ? "✓" : "  ");
    
    menu.AddItem("toggle|on", item1);
    menu.AddItem("toggle|off", item2);
    
    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Level3_Toggle(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        char info[32];
        menu.GetItem(param2, info, sizeof(info));
        
        if (strcmp(info, "toggle|on") == 0 && !g_bMultiSI_Enabled) {
            StartXVote(param1, info, "开启多特模式");
        }
        else if (strcmp(info, "toggle|off") == 0 && g_bMultiSI_Enabled) {
            StartXVote(param1, info, "关闭多特模式");
        } else {
            ShowMenu_Level3_Toggle(param1); 
        }
    }
    else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
        ShowMenu_Level2_SI(param1);
    }
    else if (action == MenuAction_End) delete menu;
    return 0;
}

void ShowMenu_Level3_Limit(int client) {
    UpdateCurrentState();
    
    Menu menu = new Menu(MenuHandler_Level3_Limit);
    menu.SetTitle("★ 基础特感数量 ★\n-------------------");
    
    for (int i = 1; i <= 15; i++) {
        char info[32], disp[64];
        Format(info, sizeof(info), "limit|%d", i);
        Format(disp, sizeof(disp), "[%s] %d特", (g_iCurrentLimit == i) ? "✓" : "  ", i);
        menu.AddItem(info, disp);
    }
    
    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Level3_Limit(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        char info[32];
        menu.GetItem(param2, info, sizeof(info));
        
        char sData[2][16];
        ExplodeString(info, "|", sData, sizeof(sData), sizeof(sData[]));
        int selectedLimit = StringToInt(sData[1]);
        
        if (g_iCurrentLimit != selectedLimit) {
            char voteTitle[64];
            Format(voteTitle, sizeof(voteTitle), "基础特感数量更改为 %d 特", selectedLimit);
            StartXVote(param1, info, voteTitle);
        } else {
            ShowMenu_Level3_Limit(param1);
        }
    }
    else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) ShowMenu_Level2_SI(param1);
    else if (action == MenuAction_End) delete menu;
    return 0;
}

void ShowMenu_Level3_ClassLimits(int client) {
    UpdateCurrentState();
    if (!g_bMultiSI_Enabled) {
        PrintToChat(client, "\x04[提示]\x01 多特插件未运行，无法调整各类特感上限。");
        ShowMenu_Level2_SI(client);
        return;
    }

    Menu menu = new Menu(MenuHandler_Level3_ClassLimits);
    menu.SetTitle("★ 各类特感上限 ★\n修改后立即生效，无需投票\n-------------------");

    for (int i = 0; i < SI_CLASS_COUNT; i++) {
        char info[32], display[64];
        ConVar classLimit = FindConVar(g_sSIClassConVars[i]);
        Format(info, sizeof(info), "%d", i);

        if (classLimit != null) {
            Format(display, sizeof(display), "%s：%d", g_sSIClassNames[i], classLimit.IntValue);
            menu.AddItem(info, display);
        } else {
            Format(display, sizeof(display), "%s：不可用", g_sSIClassNames[i]);
            menu.AddItem(info, display, ITEMDRAW_DISABLED);
        }
    }

    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Level3_ClassLimits(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        char info[32];
        menu.GetItem(param2, info, sizeof(info));
        ShowMenu_Level4_ClassLimit(param1, StringToInt(info));
    }
    else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
        ShowMenu_Level2_SI(param1);
    }
    else if (action == MenuAction_End) {
        delete menu;
    }
    return 0;
}

void ShowMenu_Level4_ClassLimit(int client, int classIndex) {
    if (classIndex < 0 || classIndex >= SI_CLASS_COUNT) {
        ShowMenu_Level3_ClassLimits(client);
        return;
    }

    ConVar classLimit = FindConVar(g_sSIClassConVars[classIndex]);
    if (classLimit == null) {
        PrintToChat(client, "\x04[提示]\x01 找不到配置项 \x05%s\x01。", g_sSIClassConVars[classIndex]);
        ShowMenu_Level3_ClassLimits(client);
        return;
    }

    Menu menu = new Menu(MenuHandler_Level4_ClassLimit);
    menu.SetTitle("★ %s 上限 ★\n当前：%d；0 表示禁止生成\n-------------------",
        g_sSIClassNames[classIndex], classLimit.IntValue);

    for (int limit = 0; limit <= 15; limit++) {
        char info[32], display[32];
        Format(info, sizeof(info), "%d|%d", classIndex, limit);
        Format(display, sizeof(display), "[%s] %d", classLimit.IntValue == limit ? "✓" : "  ", limit);
        menu.AddItem(info, display);
    }

    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Level4_ClassLimit(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        char info[32], data[2][16];
        menu.GetItem(param2, info, sizeof(info));
        ExplodeString(info, "|", data, sizeof(data), sizeof(data[]));

        int classIndex = StringToInt(data[0]);
        int selectedLimit = StringToInt(data[1]);
        SetSIClassLimit(param1, classIndex, selectedLimit);
        ShowMenu_Level3_ClassLimits(param1);
    }
    else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
        ShowMenu_Level3_ClassLimits(param1);
    }
    else if (action == MenuAction_End) {
        delete menu;
    }
    return 0;
}

void SetSIClassLimit(int client, int classIndex, int selectedLimit) {
    if (classIndex < 0 || classIndex >= SI_CLASS_COUNT || selectedLimit < 0 || selectedLimit > 15) {
        PrintToChat(client, "\x04[提示]\x01 无效的特感上限设置。");
        return;
    }

    ConVar classLimit = FindConVar(g_sSIClassConVars[classIndex]);
    if (classLimit == null) {
        PrintToChat(client, "\x04[提示]\x01 找不到配置项 \x05%s\x01。", g_sSIClassConVars[classIndex]);
        return;
    }

    int oldLimit = classLimit.IntValue;
    if (oldLimit == selectedLimit) {
        return;
    }

    classLimit.IntValue = selectedLimit;
    PrintToChatAll("\x04[系统]\x01 玩家 \x03%N\x01 将 \x05%s\x01 上限从 \x05%d\x01 调整为 \x05%d\x01。",
        client, g_sSIClassNames[classIndex], oldLimit, selectedLimit);

    if (AreAllSIClassLimitsZero()) {
        PrintToChatAll("\x04[系统]\x01 六类特感上限均为 \x050\x01，普通特感将暂停生成。");
    }
}

bool AreAllSIClassLimitsZero() {
    for (int i = 0; i < SI_CLASS_COUNT; i++) {
        ConVar classLimit = FindConVar(g_sSIClassConVars[i]);
        if (classLimit == null || classLimit.IntValue != 0) {
            return false;
        }
    }
    return true;
}

void ShowMenu_Level3_Time(int client) {
    UpdateCurrentState();
    Menu menu = new Menu(MenuHandler_Level3_Time);
    menu.SetTitle("★ 刷特时间 ★\n-------------------");
    
    for (int i = 5; i <= 60; i += 5) {
        char info[32], disp[64];
        Format(info, sizeof(info), "time|%d", i);
        Format(disp, sizeof(disp), "[%s] %d秒", (g_iCurrentTime == i) ? "✓" : "  ", i);
        menu.AddItem(info, disp);
    }
    
    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Level3_Time(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        char info[32];
        menu.GetItem(param2, info, sizeof(info));
        
        char sData[2][16];
        ExplodeString(info, "|", sData, sizeof(sData), sizeof(sData[]));
        int selectedTime = StringToInt(sData[1]);
        
        if (g_iCurrentTime != selectedTime) {
            char voteTitle[64];
            Format(voteTitle, sizeof(voteTitle), "刷特时间更改为 %d 秒", selectedTime);
            StartXVote(param1, info, voteTitle);
        } else {
            ShowMenu_Level3_Time(param1);
        }
    }
    else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) ShowMenu_Level2_SI(param1);
    else if (action == MenuAction_End) delete menu;
    return 0;
}

void StartXVote(int client, const char[] actionData, const char[] voteTitle) {
    if (!L4D2NativeVote_IsAllowNewVote()) {
        PrintToChat(client, "\x04[提示]\x01 当前正在进行投票，请稍后再试。");
        return;
    }

    L4D2NativeVote vote = L4D2NativeVote(Menu_HandlerXVote);
    vote.Initiator = client;
    vote.SetInfo(actionData);

    int playerCount = 0;
    int[] clients = new int[MaxClients];
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && !IsFakeClient(i)) {
            clients[playerCount++] = i;
        }
    }

    vote.SetTitle("%s?", voteTitle);
    vote.DisplayVote(clients, playerCount, 20);
    PrintToChatAll("\x04[提示]\x01 玩家 \x03%N\x01 发起了更改特感配置的投票！", client);
}

public void Menu_HandlerXVote(L4D2NativeVote vote, VoteAction action, int param1, int param2) {
    if (action == VoteAction_End) {
        if (param1 == VOTEEND_FULLVOTED || param1 == VOTEEND_TIMEEND) {
            if (vote.YesCount > vote.NoCount) {
                vote.SetPass("投票通过...");
                char sInfo[64];
                vote.GetInfo(sInfo, sizeof(sInfo));
                ExecuteXAction(sInfo);
            } else {
                vote.SetFail();
                PrintToChatAll("\x04[提示]\x01 投票未通过 (同意 \x05%d\x01 票，反对 \x05%d\x01 票)。", vote.YesCount, vote.NoCount);
            }
        }
    }
}

void ExecuteXAction(const char[] sInfo) {
    char sData[2][32];
    ExplodeString(sInfo, "|", sData, sizeof(sData), sizeof(sData[]));

    if (strcmp(sData[0], "toggle") == 0) {
        g_bHasVotedToggle = true; 
        g_bSavedToggleState = strcmp(sData[1], "on") == 0;
        SetMultiSIPluginState(g_bSavedToggleState);
        ScheduleMultiSIStateCheck(g_bSavedToggleState);
        return;
    }
    else if (strcmp(sData[0], "limit") == 0) {
        g_bHasVotedLimit = true; 
        int limit = StringToInt(sData[1]);
        g_iSavedLimit = limit;
        
        ServerCommand("sm_cvar ss_base_limit %d", limit);
        ServerCommand("sm_cvar ss_base_size %d", limit);
        ServerExecute();
        ApplyPopulationScaling(true);
    }
    else if (strcmp(sData[0], "time") == 0) {
        g_bHasVotedTime = true; 
        int time = StringToInt(sData[1]);
        g_iSavedTime = time;

        ServerCommand("sm_cvar ss_time_min %d", time);
        ServerCommand("sm_cvar ss_time_max %d", time + 1);
        ServerCommand("sm_resetspawn");
        ServerExecute();
    }

    if (strcmp(sData[0], "toggle") != 0) {
        CreateTimer(0.3, Timer_BroadcastState_All, _, TIMER_FLAG_NO_MAPCHANGE);
    }
}

void ApplyPopulationScaling(bool resetSpawn) {
    if (!IsMultiSIPluginRunning()) {
        return;
    }

    ConVar cvBaseLimit = FindConVar("ss_base_limit");
    ConVar cvExtraLimit = FindConVar("ss_extra_limit");
    ConVar cvBaseSize = FindConVar("ss_base_size");
    ConVar cvExtraSize = FindConVar("ss_extra_size");
    ConVar cvSILimit = FindConVar("ss_si_limit");
    ConVar cvSpawnSize = FindConVar("ss_spawn_size");
    if (cvBaseLimit == null || cvExtraLimit == null || cvBaseSize == null || cvExtraSize == null
        || cvSILimit == null || cvSpawnSize == null) {
        return;
    }

    int survivors = 0;
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && GetClientTeam(i) == 2) {
            survivors++;
        }
    }

    int extraPlayers = survivors - 4;
    if (extraPlayers < 0) {
        extraPlayers = 0;
    }

    float extraSize = cvExtraSize.FloatValue;
    if (extraSize < 1.0) {
        extraSize = 1.0;
    }

    int finalLimit = cvBaseLimit.IntValue + RoundToNearest(cvExtraLimit.FloatValue * float(extraPlayers));
    int finalSize = cvBaseSize.IntValue + RoundToNearest(float(extraPlayers) / extraSize);
    if (finalLimit < 1) finalLimit = 1;
    if (finalLimit > 32) finalLimit = 32;
    if (finalSize < 1) finalSize = 1;
    if (finalSize > 32) finalSize = 32;

    cvSILimit.IntValue = finalLimit;
    cvSpawnSize.IntValue = finalSize;

    if (resetSpawn && CommandExists("sm_resetspawn")) {
        ServerCommand("sm_resetspawn");
        ServerExecute();
    }

    UpdateCurrentState();
}

public Action Timer_BroadcastState_All(Handle timer) {
    UpdateCurrentState();
    if (g_bMultiSI_Enabled) {
        PrintCurrentStateAll();
    }
    return Plugin_Continue;
}
