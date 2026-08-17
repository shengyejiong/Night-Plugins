#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <l4d2_nativevote>

public Plugin myinfo = {
    name = "L4D2 Multi-Function X Menu",
    author = "らくらく安楽死 & Assistant",
    description = "多功能控制菜单 (!x)",
    version = "2.9",
};

bool g_bMultiSI_Enabled = false; 
int g_iCurrentLimit = 0;        
int g_iCurrentTime = 0;        
int g_iExtraLimit = 0;

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
        if (g_bSavedToggleState) {
            ServerCommand("sm plugins load specialspawner");
        } else {
            ServerCommand("sm plugins unload specialspawner");
            return Plugin_Continue; 
        }
    }
    
    CreateTimer(0.5, Timer_EnforceCvars, _, TIMER_FLAG_NO_MAPCHANGE);
    return Plugin_Continue;
}

public Action Timer_EnforceCvars(Handle timer) {
    if (CommandExists("sm_resetspawn")) {
        if (g_bHasVotedLimit) {
            ServerCommand("sm_cvar ss_base_limit %d", g_iSavedLimit);
            ServerCommand("sm_cvar ss_base_size %d", g_iSavedLimit);
        }
        if (g_bHasVotedTime) {
            ServerCommand("sm_cvar ss_time_min %d", g_iSavedTime);
            ServerCommand("sm_cvar ss_time_max %d", g_iSavedTime + 1);
        }
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
            PrintToChat(client, "\x04[系统]\x01 当前的多特配置为\x05%d\x01秒\x05%d\x01特，4人以上每多1人额外增加\x05%d\x01特，输入 \x03!x\x01 更改多特配置", g_iCurrentTime, g_iCurrentLimit, g_iExtraLimit);
        }
    }
    return Plugin_Continue;
}

void UpdateCurrentState() {
    g_bMultiSI_Enabled = CommandExists("sm_resetspawn");

    if (g_bMultiSI_Enabled) {
        ConVar cvLimit = FindConVar("ss_base_limit");
        ConVar cvTime = FindConVar("ss_time_min");
        ConVar cvExtra = FindConVar("ss_extra_limit");
        
        if (cvLimit != null) g_iCurrentLimit = cvLimit.IntValue;
        if (cvTime != null) g_iCurrentTime = cvTime.IntValue;
        if (cvExtra != null) g_iExtraLimit = cvExtra.IntValue;
    }
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
    menu.SetTitle("★ 特感配置 ★\n-------------------");
    menu.AddItem("toggle", "开关多特");
    
    if (g_bMultiSI_Enabled) {
        menu.AddItem("limit", "基础特感数量");
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
    menu.SetTitle("★ 开关多特 ★\n-------------------");
    
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
        if (strcmp(sData[1], "on") == 0) {
            g_bSavedToggleState = true;
            ServerCommand("sm plugins load specialspawner");
        } else {
            g_bSavedToggleState = false;
            ServerCommand("sm plugins unload specialspawner");
            PrintToChatAll("\x04[系统]\x01 多特模式已关闭，交还系统导演控制。");
            return; 
        }
    }
    else if (strcmp(sData[0], "limit") == 0) {
        g_bHasVotedLimit = true; 
        int limit = StringToInt(sData[1]);
        g_iSavedLimit = limit;
        
        ServerCommand("sm_cvar ss_base_limit %d", limit);
        ServerCommand("sm_cvar ss_base_size %d", limit);
        
        int extra_limit = 1, extra_size = 1;
        ConVar cvEL = FindConVar("ss_extra_limit");
        ConVar cvES = FindConVar("ss_extra_size");
        if (cvEL != null) extra_limit = cvEL.IntValue;
        if (cvES != null) extra_size = cvES.IntValue;
        
        int survivors = 0;
        for (int i = 1; i <= MaxClients; i++) {
            if (IsClientInGame(i) && GetClientTeam(i) == 2) {
                survivors++;
            }
        }
        
        int final_limit = limit;
        int final_size = limit;
        if (survivors > 4) {
            final_limit += (survivors - 4) * extra_limit;
            final_size += (survivors - 4) * extra_size;
        }
        
        ServerCommand("sm_cvar ss_si_limit %d", final_limit);
        ServerCommand("sm_cvar ss_spawn_size %d", final_size);
        
        ServerCommand("sm_resetspawn");
    }
    else if (strcmp(sData[0], "time") == 0) {
        g_bHasVotedTime = true; 
        int time = StringToInt(sData[1]);
        g_iSavedTime = time;

        ServerCommand("sm_cvar ss_time_min %d", time);
        ServerCommand("sm_cvar ss_time_max %d", time + 1);
        ServerCommand("sm_resetspawn");
    }

    CreateTimer(0.3, Timer_BroadcastState_All);
}

public Action Timer_BroadcastState_All(Handle timer) {
    UpdateCurrentState();
    if (g_bMultiSI_Enabled) {
        PrintToChatAll("\x04[系统]\x01 当前的多特配置为\x05%d\x01秒\x05%d\x01特，4人以上每多1人额外增加\x05%d\x01特，输入 \x03!x\x01 更改多特配置", g_iCurrentTime, g_iCurrentLimit, g_iExtraLimit);
    }
    return Plugin_Continue;
}