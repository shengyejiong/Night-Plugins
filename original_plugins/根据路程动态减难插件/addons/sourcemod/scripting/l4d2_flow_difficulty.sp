#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <l4d2_nativevote>

#define PLUGIN_VERSION "1.4.0-night"
#define SAMPLE_COUNT 5
#define TEAM_SURVIVOR 2
#define SETUP_RETRY_LOG_INTERVAL 30
#define STARTER_WEAPON_COUNT 4

static const char g_sStarterWeaponClassnames[STARTER_WEAPON_COUNT][] =
{
	"weapon_pumpshotgun",
	"weapon_shotgun_chrome",
	"weapon_smg",
	"weapon_smg_silenced"
};

static const char g_sStarterWeaponNames[STARTER_WEAPON_COUNT][] =
{
	"木喷",
	"铁喷",
	"UZI",
	"消音冲锋枪"
};

enum AssistVote
{
	AssistVote_None = 0,
	AssistVote_Tier1,
	AssistVote_Tier2,
	AssistVote_Tier3
};

public Plugin myinfo =
{
	name = "[L4D2] Flow Difficulty Assistance",
	author = "night",
	description = "根据团灭次数和地图路程投票开启分阶减难",
	version = PLUGIN_VERSION,
	url = "https://github.com/shengyejiong/Night-Plugins"
};

ConVar g_cvEnable;
ConVar g_cvEarlyPercent;
ConVar g_cvTier1Wipes;
ConVar g_cvTier2Wipes;
ConVar g_cvTier3Wipes;
ConVar g_cvFallbackInvalidWipes;
ConVar g_cvFallbackTier1Wipes;
ConVar g_cvVoteTime;
ConVar g_cvReviveHealth;
ConVar g_cvWeaponOfferDelay;

Handle g_hFlowTimer;
Handle g_hRoundSetupTimer;
Handle g_hWeaponOfferTimer;

bool g_bRoundActive;
bool g_bMissionLostHandled;
bool g_bAttemptFlowValid;
bool g_bTier1Enabled;
bool g_bTier2Enabled;
bool g_bTier3Enabled;
bool g_bTier1VotePending;
bool g_bTier2VotePending;
bool g_bTier3VotePending;
bool g_bPillsPending;
bool g_bTier2TargetValid;
bool g_bTier2Triggered;
bool g_bMapFlowDisabled;
bool g_bFlowFallbackActive;
bool g_bWeaponOfferScheduled;
bool g_bVoteClientVoted[MAXPLAYERS + 1];
bool g_bStarterWeaponClaimed[MAXPLAYERS + 1];
bool g_bRecentWipeValid[SAMPLE_COUNT];

int g_iRoundSerial;
int g_iSetupRetries;
int g_iTotalWipes;
int g_iEarlyWipes;
int g_iWipeSampleCount;
int g_iWipeSampleNext;
int g_iRecentWipeCount;
int g_iRecentWipeNext;
int g_iConsecutiveInvalidWipes;
int g_iExpectedVoters;
int g_iReceivedVotes;

float g_fAttemptMaxPercent;
float g_fWipeSamples[SAMPLE_COUNT];
float g_fRecentWipePercents[SAMPLE_COUNT];
float g_fTier2Target;
float g_fMapMaxFlowOverride;

char g_sLastWipeReason[96];
char g_sLastResetReason[64];

AssistVote g_eActiveVote = AssistVote_None;

public void OnPluginStart()
{
	if (GetEngineVersion() != Engine_Left4Dead2)
	{
		SetFailState("本插件仅支持 Left 4 Dead 2。");
	}

	g_cvEnable = CreateConVar(
		"l4d2_flow_difficulty_enable",
		"1",
		"是否启用根据路程动态减难。0=关闭，1=开启。",
		FCVAR_NOTIFY,
		true,
		0.0,
		true,
		1.0
	);
	g_cvEarlyPercent = CreateConVar(
		"l4d2_flow_difficulty_early_percent",
		"75.0",
		"低于多少路程百分比的团灭计入第一阶阈值。",
		FCVAR_NOTIFY,
		true,
		1.0,
		true,
		100.0
	);
	g_cvTier1Wipes = CreateConVar(
		"l4d2_flow_difficulty_tier1_wipes",
		"2",
		"触发第一阶减难投票所需的早期团灭次数。",
		FCVAR_NOTIFY,
		true,
		1.0
	);
	g_cvTier2Wipes = CreateConVar(
		"l4d2_flow_difficulty_tier2_wipes",
		"5",
		"触发第二阶减难投票所需的总团灭次数。",
		FCVAR_NOTIFY,
		true,
		1.0
	);
	g_cvTier3Wipes = CreateConVar(
		"l4d2_flow_difficulty_tier3_wipes",
		"7",
		"触发第三阶满血复活投票所需的总团灭次数。",
		FCVAR_NOTIFY,
		true,
		1.0
	);
	g_cvFallbackInvalidWipes = CreateConVar(
		"l4d2_flow_difficulty_fallback_invalid_wipes",
		"3",
		"连续多少次团灭无法取得路程后，启用导航备用模式。",
		FCVAR_NOTIFY,
		true,
		1.0,
		true,
		20.0
	);
	g_cvFallbackTier1Wipes = CreateConVar(
		"l4d2_flow_difficulty_fallback_tier1_wipes",
		"4",
		"导航备用模式下触发第一阶投票所需的总团灭次数。",
		FCVAR_NOTIFY,
		true,
		1.0,
		true,
		100.0
	);
	g_cvVoteTime = CreateConVar(
		"l4d2_flow_difficulty_vote_time",
		"25",
		"每次减难投票持续时间，单位为秒。所有投票开始时在线的真人都投票才有效。",
		FCVAR_NOTIFY,
		true,
		5.0,
		true,
		60.0
	);
	g_cvReviveHealth = CreateConVar(
		"l4d2_flow_difficulty_revive_health",
		"50",
		"第二阶复活真人时给予的实血。",
		FCVAR_NOTIFY,
		true,
		1.0,
		true,
		100.0
	);
	g_cvWeaponOfferDelay = CreateConVar(
		"l4d2_flow_difficulty_weapon_offer_delay",
		"30.0",
		"每回合开始多少秒后，为没有主武器的存活真人显示随机基础主武器领取菜单。",
		FCVAR_NOTIFY,
		true,
		0.0,
		true,
		300.0
	);

	CreateConVar(
		"l4d2_flow_difficulty_version",
		PLUGIN_VERSION,
		"根据路程动态减难插件版本。",
		FCVAR_NOTIFY | FCVAR_DONTRECORD
	);

	RegConsoleCmd("sm_flowassist_status", Command_Status, "查看动态减难状态。");
	RegConsoleCmd("sm_fd", Command_Status, "查看动态减难状态（简写）。");
	RegAdminCmd("sm_flowassist_reset", Command_Reset, ADMFLAG_ROOT, "清空当前章节的动态减难状态。");

	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("mission_lost", Event_MissionLost, EventHookMode_PostNoCopy);
	HookEvent("vote_passed", Event_VotePassed, EventHookMode_Post);

	AutoExecConfig(true, "l4d2_flow_difficulty");
}

public void OnMapStart()
{
	ResetChapterState("地图开始或切换");
	g_bMapFlowDisabled = false;
	g_fMapMaxFlowOverride = 0.0;

	delete g_hFlowTimer;
	g_hFlowTimer = CreateTimer(1.0, Timer_TrackFlow, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public void OnMapEnd()
{
	delete g_hFlowTimer;
	g_hFlowTimer = null;

	delete g_hRoundSetupTimer;
	g_hRoundSetupTimer = null;

	delete g_hWeaponOfferTimer;
	g_hWeaponOfferTimer = null;
}

public void OnConfigsExecuted()
{
	LoadMapFlowConfig();
}

void ResetChapterState(const char[] reason)
{
	g_bRoundActive = false;
	g_bMissionLostHandled = false;
	g_bAttemptFlowValid = false;
	g_bTier1Enabled = false;
	g_bTier2Enabled = false;
	g_bTier3Enabled = false;
	g_bTier1VotePending = false;
	g_bTier2VotePending = false;
	g_bTier3VotePending = false;
	g_bPillsPending = false;
	g_bTier2TargetValid = false;
	g_bTier2Triggered = false;
	g_bFlowFallbackActive = false;
	g_bWeaponOfferScheduled = false;
	g_iTotalWipes = 0;
	g_iEarlyWipes = 0;
	g_iWipeSampleCount = 0;
	g_iWipeSampleNext = 0;
	g_iRecentWipeCount = 0;
	g_iRecentWipeNext = 0;
	g_iConsecutiveInvalidWipes = 0;
	g_iExpectedVoters = 0;
	g_iReceivedVotes = 0;
	g_fAttemptMaxPercent = 0.0;
	g_fTier2Target = 0.0;
	g_eActiveVote = AssistVote_None;
	strcopy(g_sLastWipeReason, sizeof(g_sLastWipeReason), "尚无团灭记录");
	strcopy(g_sLastResetReason, sizeof(g_sLastResetReason), reason);

	for (int i = 0; i < SAMPLE_COUNT; i++)
	{
		g_fWipeSamples[i] = 0.0;
		g_fRecentWipePercents[i] = 0.0;
		g_bRecentWipeValid[i] = false;
	}
	for (int client = 1; client <= MaxClients; client++)
	{
		g_bVoteClientVoted[client] = false;
		g_bStarterWeaponClaimed[client] = false;
	}

	delete g_hRoundSetupTimer;
	g_hRoundSetupTimer = null;

	delete g_hWeaponOfferTimer;
	g_hWeaponOfferTimer = null;
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_cvEnable.BoolValue)
	{
		return;
	}

	g_iRoundSerial++;
	g_iSetupRetries = 0;
	g_bRoundActive = true;
	g_bMissionLostHandled = false;
	g_bAttemptFlowValid = false;
	g_bTier2Triggered = false;
	g_bWeaponOfferScheduled = false;
	g_fAttemptMaxPercent = 0.0;
	g_bTier2TargetValid = g_bTier2Enabled && !g_bFlowFallbackActive && CalculateWipeAverage(g_fTier2Target);

	delete g_hRoundSetupTimer;
	g_hRoundSetupTimer = CreateTimer(
		2.0,
		Timer_RoundSetup,
		g_iRoundSerial,
		TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE
	);

	delete g_hWeaponOfferTimer;
	g_hWeaponOfferTimer = null;
	for (int client = 1; client <= MaxClients; client++)
	{
		g_bStarterWeaponClaimed[client] = false;
	}

	ScheduleStarterWeaponOffer();
}

public void Event_MissionLost(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_cvEnable.BoolValue || g_bMissionLostHandled)
	{
		return;
	}

	g_bMissionLostHandled = true;
	delete g_hWeaponOfferTimer;
	g_hWeaponOfferTimer = null;
	g_bWeaponOfferScheduled = false;
	float finalPercent;
	UpdateAttemptFlowSample(finalPercent);
	g_bRoundActive = false;
	g_iTotalWipes++;
	PushRecentWipeAttempt(g_bAttemptFlowValid, g_fAttemptMaxPercent);

	if (g_bAttemptFlowValid)
	{
		g_iConsecutiveInvalidWipes = 0;
		PushWipeSample(g_fAttemptMaxPercent);

		if (g_fAttemptMaxPercent < g_cvEarlyPercent.FloatValue)
		{
			g_iEarlyWipes++;
			FormatEx(
				g_sLastWipeReason,
				sizeof(g_sLastWipeReason),
				"%.1f%%，计入 %.0f%% 前有效团灭",
				g_fAttemptMaxPercent,
				g_cvEarlyPercent.FloatValue
			);
		}
		else
		{
			FormatEx(
				g_sLastWipeReason,
				sizeof(g_sLastWipeReason),
				"%.1f%%，达到或超过 %.0f%%，未计入第一阶",
				g_fAttemptMaxPercent,
				g_cvEarlyPercent.FloatValue
			);
		}
	}
	else
	{
		g_iConsecutiveInvalidWipes++;
		if (g_bMapFlowDisabled)
		{
			strcopy(g_sLastWipeReason, sizeof(g_sLastWipeReason), "地图配置已禁用路程，未计入第一阶");
		}
		else
		{
			strcopy(g_sLastWipeReason, sizeof(g_sLastWipeReason), "未取得有效路程，未计入第一阶");
		}
		LogMessage("本次团灭没有取得有效路程，未计入早期团灭和第二阶有效路程样本。");

		if (!g_bFlowFallbackActive && g_iConsecutiveInvalidWipes >= g_cvFallbackInvalidWipes.IntValue)
		{
			g_bFlowFallbackActive = true;
			g_bTier2VotePending = false;
			g_bTier3VotePending = false;
			g_bTier2TargetValid = false;
			PrintToChatAll(
				"\x04[动态减难]\x05 连续 \x03%d\x05 次团灭无法取得路程，已启用导航备用模式；总团灭达到 \x03%d\x05 次可触发第一阶，第二、三阶暂停。",
				g_iConsecutiveInvalidWipes,
				g_cvFallbackTier1Wipes.IntValue
			);
			LogMessage(
				"连续 %d 次团灭无法取得路程，启用导航备用模式；第一阶改用总团灭阈值 %d，第二、三阶暂停。",
				g_iConsecutiveInvalidWipes,
				g_cvFallbackTier1Wipes.IntValue
			);
		}
	}

	if (g_bTier1Enabled)
	{
		g_bPillsPending = true;
	}

	bool tier1NormalReady = g_iEarlyWipes >= g_cvTier1Wipes.IntValue;
	bool tier1FallbackReady = g_bFlowFallbackActive && g_iTotalWipes >= g_cvFallbackTier1Wipes.IntValue;
	if (!g_bTier1Enabled && (tier1NormalReady || tier1FallbackReady))
	{
		g_bTier1VotePending = true;
	}
	else if (g_bTier1Enabled && !g_bTier2Enabled && !g_bFlowFallbackActive && g_iTotalWipes >= g_cvTier2Wipes.IntValue)
	{
		g_bTier2VotePending = true;
	}
	else if (g_bTier2Enabled && !g_bTier3Enabled && !g_bFlowFallbackActive && g_iTotalWipes >= g_cvTier3Wipes.IntValue)
	{
		g_bTier3VotePending = true;
	}

	char percentText[16];
	if (g_bAttemptFlowValid)
	{
		FormatEx(percentText, sizeof(percentText), "%.1f%%", g_fAttemptMaxPercent);
	}
	else
	{
		strcopy(percentText, sizeof(percentText), "无效");
	}

	PrintToChatAll(
		"\x04[动态减难]\x05 本章已团灭 \x03%d\x05 次，75%% 前有效团灭：\x03%d/%d\x05，本次最远路程：\x03%s\x05。",
		g_iTotalWipes,
		g_iEarlyWipes,
		g_cvTier1Wipes.IntValue,
		percentText
	);
}

public void Event_VotePassed(Event event, const char[] name, bool dontBroadcast)
{
	char details[128];
	event.GetString("details", details, sizeof(details));

	if (StrEqual(details, "#L4D_vote_passed_restart_game", false))
	{
		ResetChapterState("官方重新开始战役投票");
		LogMessage("检测到官方重新开始战役投票通过，已清空动态减难状态。");
	}
}

public Action Timer_RoundSetup(Handle timer, any serial)
{
	if (timer != g_hRoundSetupTimer || serial != g_iRoundSerial || !g_bRoundActive)
	{
		if (timer == g_hRoundSetupTimer)
		{
			g_hRoundSetupTimer = null;
		}
		return Plugin_Stop;
	}

	g_iSetupRetries++;
	bool pillsHandled = HandlePendingPills();
	bool voteHandled = HandlePendingVote();

	if (pillsHandled && voteHandled)
	{
		g_hRoundSetupTimer = null;
		return Plugin_Stop;
	}

	if (g_iSetupRetries % SETUP_RETRY_LOG_INTERVAL == 0)
	{
		LogMessage(
			"回合开始后仍在等待真人、存活生还者或投票空档；已等待约 %d 秒，将继续重试。",
			g_iSetupRetries * 2
		);
	}

	return Plugin_Continue;
}

public Action Timer_TrackFlow(Handle timer)
{
	if (!g_cvEnable.BoolValue || !g_bRoundActive || g_bMapFlowDisabled)
	{
		return Plugin_Continue;
	}

	float percent;
	if (!UpdateAttemptFlowSample(percent))
	{
		return Plugin_Continue;
	}

	if (g_bTier2Enabled && !g_bFlowFallbackActive && g_bTier2TargetValid && !g_bTier2Triggered && percent >= g_fTier2Target)
	{
		g_bTier2Triggered = true;
		int revived = ReviveDeadHumanSurvivors(g_bTier3Enabled);

		if (revived > 0)
		{
			if (g_bTier3Enabled)
			{
				PrintToChatAll(
					"\x04[动态减难]\x05 已到达最近五次平均团灭路程 \x03%.1f%%\x05，满血复活了 \x03%d\x05 名死亡真人。",
					g_fTier2Target,
					revived
				);
			}
			else
			{
				PrintToChatAll(
					"\x04[动态减难]\x05 已到达最近五次平均团灭路程 \x03%.1f%%\x05，复活了 \x03%d\x05 名死亡真人。",
					g_fTier2Target,
					revived
				);
			}
		}
		else
		{
			LogMessage("到达第二阶复活路程 %.1f%%，本回合没有可复活的死亡真人。", g_fTier2Target);
		}
	}

	return Plugin_Continue;
}

void ScheduleStarterWeaponOffer()
{
	if (g_bWeaponOfferScheduled)
	{
		return;
	}

	g_bWeaponOfferScheduled = true;
	delete g_hWeaponOfferTimer;
	g_hWeaponOfferTimer = CreateTimer(
		g_cvWeaponOfferDelay.FloatValue,
		Timer_OfferStarterWeapons,
		g_iRoundSerial,
		TIMER_FLAG_NO_MAPCHANGE
	);
}

public Action Timer_OfferStarterWeapons(Handle timer, any serial)
{
	if (timer == g_hWeaponOfferTimer)
	{
		g_hWeaponOfferTimer = null;
	}

	if (serial != g_iRoundSerial || !g_cvEnable.BoolValue || !g_bRoundActive)
	{
		return Plugin_Stop;
	}

	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) != TEAM_SURVIVOR
			|| !IsPlayerAlive(client) || g_bStarterWeaponClaimed[client] || GetPlayerWeaponSlot(client, 0) != -1)
		{
			continue;
		}

		ShowStarterWeaponOffer(client, serial);
	}

	return Plugin_Stop;
}

void ShowStarterWeaponOffer(int client, int serial)
{
	Menu menu = new Menu(MenuHandler_StarterWeaponOffer);
	menu.SetTitle("你当前没有主武器\n是否领取一把随机基础主武器？");

	char info[32];
	FormatEx(info, sizeof(info), "accept|%d", serial);
	menu.AddItem(info, "接受");
	menu.AddItem("decline", "不接受");
	menu.ExitButton = false;
	menu.Display(client, 15);
}

public int MenuHandler_StarterWeaponOffer(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(param2, info, sizeof(info));
		if (strncmp(info, "accept|", 7, false) == 0)
		{
			char data[2][16];
			ExplodeString(info, "|", data, sizeof(data), sizeof(data[]));
			GiveRandomStarterWeapon(param1, StringToInt(data[1]));
		}
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
	return 0;
}

void GiveRandomStarterWeapon(int client, int serial)
{
	if (serial != g_iRoundSerial || !g_bRoundActive || !g_cvEnable.BoolValue)
	{
		PrintToChat(client, "\x04[动态减难]\x05 本次武器领取菜单已经过期。");
		return;
	}
	if (!IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) != TEAM_SURVIVOR || !IsPlayerAlive(client))
	{
		return;
	}
	if (g_bStarterWeaponClaimed[client])
	{
		PrintToChat(client, "\x04[动态减难]\x05 本回合已经领取过随机主武器。");
		return;
	}
	if (GetPlayerWeaponSlot(client, 0) != -1)
	{
		PrintToChat(client, "\x04[动态减难]\x05 你已经拥有主武器，本次不再发放。");
		return;
	}

	int weaponIndex = GetRandomInt(0, STARTER_WEAPON_COUNT - 1);
	int weapon = GivePlayerItem(client, g_sStarterWeaponClassnames[weaponIndex]);
	if (weapon == -1)
	{
		PrintToChat(client, "\x04[动态减难]\x05 随机主武器发放失败，请联系管理员。");
		LogError("无法为玩家 %N 发放随机主武器 %s。", client, g_sStarterWeaponClassnames[weaponIndex]);
		return;
	}

	EquipPlayerWeapon(client, weapon);
	g_bStarterWeaponClaimed[client] = true;
	PrintToChat(client, "\x04[动态减难]\x05 已领取随机主武器：\x03%s\x05。", g_sStarterWeaponNames[weaponIndex]);
}

public void OnClientDisconnect(int client)
{
	g_bStarterWeaponClaimed[client] = false;
}

bool UpdateAttemptFlowSample(float &percent)
{
	if (!GetCurrentFlowPercent(percent))
	{
		return false;
	}

	if (!g_bAttemptFlowValid || percent > g_fAttemptMaxPercent)
	{
		g_bAttemptFlowValid = true;
		g_fAttemptMaxPercent = percent;
	}
	return true;
}

bool HandlePendingPills()
{
	if (!g_bPillsPending)
	{
		return true;
	}

	int humans = CountHumanSurvivors();
	if (humans <= 0)
	{
		return false;
	}

	int count = humans / 2 - 1;
	if (count <= 0)
	{
		g_bPillsPending = false;
		LogMessage("第一阶减难已生效，但当前只有 %d 名真人生还者，按人数/2-1不生成止痛药。", humans);
		return true;
	}

	int anchor = FindRandomLivingSurvivor();
	if (anchor == 0)
	{
		return false;
	}

	int spawned = 0;
	for (int i = 0; i < count; i++)
	{
		float position[3];
		FindNearbyGroundPosition(anchor, position, 48.0 + float(i % 3) * 24.0);

		int entity = CreateEntityByName("weapon_pain_pills");
		if (entity == -1)
		{
			continue;
		}

		DispatchSpawn(entity);
		ActivateEntity(entity);
		TeleportEntity(entity, position, NULL_VECTOR, NULL_VECTOR);
		spawned++;
	}

	if (spawned <= 0)
	{
		return false;
	}

	g_bPillsPending = false;
	PrintToChatAll(
		"\x04[动态减难]\x05 第一阶减难生效：按 \x03%d\x05 名真人生成了 \x03%d\x05 瓶止痛药。",
		humans,
		spawned
	);
	return true;
}

bool HandlePendingVote()
{
	if (g_eActiveVote != AssistVote_None)
	{
		return true;
	}

	AssistVote voteType = AssistVote_None;
	if (g_bTier1VotePending && !g_bTier1Enabled)
	{
		voteType = AssistVote_Tier1;
	}
	else if (g_bTier2VotePending && g_bTier1Enabled && !g_bTier2Enabled && !g_bFlowFallbackActive)
	{
		voteType = AssistVote_Tier2;
	}
	else if (g_bTier3VotePending && g_bTier2Enabled && !g_bTier3Enabled && !g_bFlowFallbackActive)
	{
		voteType = AssistVote_Tier3;
	}
	else
	{
		return true;
	}

	if (!L4D2NativeVote_IsAllowNewVote())
	{
		return false;
	}

	int clients[MAXPLAYERS];
	int playerCount = 0;
	for (int client = 1; client <= MaxClients; client++)
	{
		g_bVoteClientVoted[client] = false;
		if (!IsClientInGame(client) || IsFakeClient(client))
		{
			continue;
		}
		clients[playerCount++] = client;
	}

	if (playerCount <= 0)
	{
		return false;
	}

	L4D2NativeVote vote = L4D2NativeVote(VoteHandler_Assistance);
	vote.Value = view_as<int>(voteType);
	vote.Initiator = 0;

	if (voteType == AssistVote_Tier1)
	{
		vote.SetTitle("检测到地图难度过高，开启第一阶减难？");
	}
	else if (voteType == AssistVote_Tier2)
	{
		vote.SetTitle("多次团灭，开启第二阶路程复活？");
	}
	else
	{
		vote.SetTitle("继续多次团灭，开启第三阶满血复活？");
	}

	g_eActiveVote = voteType;
	g_iExpectedVoters = playerCount;
	g_iReceivedVotes = 0;

	if (!vote.DisplayVote(clients, playerCount, g_cvVoteTime.IntValue))
	{
		g_eActiveVote = AssistVote_None;
		g_iExpectedVoters = 0;
		return false;
	}

	if (voteType == AssistVote_Tier1)
	{
		g_bTier1VotePending = false;
		PrintToChatAll("\x04[动态减难]\x05 第一阶投票开始；必须所有在线真人都投票，否则本次作废。");
	}
	else if (voteType == AssistVote_Tier2)
	{
		g_bTier2VotePending = false;
		PrintToChatAll("\x04[动态减难]\x05 第二阶投票开始；必须所有在线真人都投票，否则本次作废。");
	}
	else
	{
		g_bTier3VotePending = false;
		PrintToChatAll("\x04[动态减难]\x05 第三阶投票开始；必须所有在线真人都投票，否则本次作废。");
	}

	return true;
}

void VoteHandler_Assistance(L4D2NativeVote vote, VoteAction action, int param1, int param2)
{
	AssistVote voteType = view_as<AssistVote>(vote.Value);

	switch (action)
	{
		case VoteAction_PlayerVoted:
		{
			int client = param1;
			if (client >= 1 && client <= MaxClients && !g_bVoteClientVoted[client])
			{
				g_bVoteClientVoted[client] = true;
				g_iReceivedVotes++;
			}
		}
		case VoteAction_End:
		{
			int yesVotes = vote.YesCount;
			int noVotes = vote.NoCount;
			bool allVoted = g_iExpectedVoters > 0 && g_iReceivedVotes >= g_iExpectedVoters;
			bool passed = allVoted && yesVotes > noVotes;

			if (!allVoted)
			{
				vote.SetFail();
				PrintToChatAll(
					"\x04[动态减难]\x05 本次投票作废：只有 \x03%d/%d\x05 名真人完成投票。",
					g_iReceivedVotes,
					g_iExpectedVoters
				);
			}
			else if (!passed)
			{
				vote.SetFail();
				PrintToChatAll(
					"\x04[动态减难]\x05 投票未通过：同意 \x03%d\x05，反对 \x03%d\x05。",
					yesVotes,
					noVotes
				);
			}
			else if (voteType == AssistVote_Tier1)
			{
				vote.SetPass("第一阶减难已开启");
				g_bTier1Enabled = true;
				PrintToChatAll("\x04[动态减难]\x05 第一阶已开启：从下一次团灭重开开始，每次按真人数量生成止痛药。");
			}
			else if (voteType == AssistVote_Tier2)
			{
				vote.SetPass("第二阶减难已开启");
				g_bTier2Enabled = true;
				g_bTier2TargetValid = CalculateWipeAverage(g_fTier2Target);

				if (g_bTier2TargetValid)
				{
					PrintToChatAll(
						"\x04[动态减难]\x05 第二阶已开启：本回合在 \x03%.1f%%\x05 路程复活死亡真人。",
						g_fTier2Target
					);
				}
				else
				{
					PrintToChatAll("\x04[动态减难]\x05 第二阶已开启，但有效团灭路程不足 5 次，本回合不会复活。");
				}
			}
		else if (voteType == AssistVote_Tier3)
		{
			vote.SetPass("第三阶减难已开启");
			g_bTier3Enabled = true;
			PrintToChatAll("\x04[动态减难]\x05 第三阶已开启：后续路程复活的死亡真人将以满血状态复活。");
			}

			g_eActiveVote = AssistVote_None;
			g_iExpectedVoters = 0;
			g_iReceivedVotes = 0;
		}
	}
}

bool GetCurrentFlowPercent(float &percent)
{
	if (g_bMapFlowDisabled)
	{
		return false;
	}

	int client = L4D_GetHighestFlowSurvivor();
	if (client < 1 || client > MaxClients || !IsClientInGame(client) || !IsPlayerAlive(client))
	{
		return false;
	}

	float maxFlow = g_fMapMaxFlowOverride > 0.0
		? g_fMapMaxFlowOverride
		: L4D2Direct_GetMapMaxFlowDistance();

	if (maxFlow <= 0.0 || maxFlow > 10000000.0)
	{
		return false;
	}

	float currentFlow = L4D2Direct_GetFlowDistance(client);
	if (currentFlow < 0.0 || currentFlow > maxFlow * 1.25)
	{
		return false;
	}

	percent = currentFlow / maxFlow * 100.0;
	if (percent < 0.0 || percent > 125.0)
	{
		return false;
	}

	if (percent > 100.0)
	{
		percent = 100.0;
	}
	return true;
}

void PushWipeSample(float percent)
{
	if (percent < 0.0 || percent > 100.0)
	{
		return;
	}

	g_fWipeSamples[g_iWipeSampleNext] = percent;
	g_iWipeSampleNext = (g_iWipeSampleNext + 1) % SAMPLE_COUNT;
	if (g_iWipeSampleCount < SAMPLE_COUNT)
	{
		g_iWipeSampleCount++;
	}
}

void PushRecentWipeAttempt(bool valid, float percent)
{
	g_bRecentWipeValid[g_iRecentWipeNext] = valid;
	g_fRecentWipePercents[g_iRecentWipeNext] = valid ? percent : 0.0;
	g_iRecentWipeNext = (g_iRecentWipeNext + 1) % SAMPLE_COUNT;
	if (g_iRecentWipeCount < SAMPLE_COUNT)
	{
		g_iRecentWipeCount++;
	}
}

void FormatRecentWipes(char[] buffer, int maxlen)
{
	buffer[0] = '\0';
	if (g_iRecentWipeCount <= 0)
	{
		strcopy(buffer, maxlen, "无");
		return;
	}

	int start = g_iRecentWipeCount < SAMPLE_COUNT ? 0 : g_iRecentWipeNext;
	for (int i = 0; i < g_iRecentWipeCount; i++)
	{
		int index = (start + i) % SAMPLE_COUNT;
		char item[20];
		if (g_bRecentWipeValid[index])
		{
			FormatEx(item, sizeof(item), "%.1f%%", g_fRecentWipePercents[index]);
		}
		else
		{
			strcopy(item, sizeof(item), "无效");
		}

		if (i > 0)
		{
			StrCat(buffer, maxlen, "、");
		}
		StrCat(buffer, maxlen, item);
	}
}

bool CalculateWipeAverage(float &average)
{
	if (g_iWipeSampleCount < SAMPLE_COUNT || g_bMapFlowDisabled || g_bFlowFallbackActive)
	{
		return false;
	}

	float total = 0.0;
	for (int i = 0; i < SAMPLE_COUNT; i++)
	{
		total += g_fWipeSamples[i];
	}

	average = total / float(SAMPLE_COUNT);
	return average >= 0.0 && average <= 100.0;
}

int ReviveDeadHumanSurvivors(bool fullHealth)
{
	int anchors[MAXPLAYERS];
	int anchorCount = 0;

	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && GetClientTeam(client) == TEAM_SURVIVOR && IsPlayerAlive(client))
		{
			anchors[anchorCount++] = client;
		}
	}

	if (anchorCount <= 0)
	{
		return 0;
	}

	int revived = 0;
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) != TEAM_SURVIVOR || IsPlayerAlive(client))
		{
			continue;
		}

		int anchor = anchors[GetRandomInt(0, anchorCount - 1)];
		float position[3];
		FindNearbyGroundPosition(anchor, position, GetRandomFloat(72.0, 144.0));

		L4D_RespawnPlayer(client, true);
		if (!IsPlayerAlive(client))
		{
			continue;
		}

		TeleportEntity(client, position, NULL_VECTOR, NULL_VECTOR);
		L4D_WarpToValidPositionIfStuck(client);
		SetEntityHealth(client, fullHealth ? 100 : g_cvReviveHealth.IntValue);
		SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 0.0);
		SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());

		if (HasEntProp(client, Prop_Send, "m_currentReviveCount"))
		{
			SetEntProp(client, Prop_Send, "m_currentReviveCount", 0);
		}
		if (HasEntProp(client, Prop_Send, "m_isGoingToDie"))
		{
			SetEntProp(client, Prop_Send, "m_isGoingToDie", 0);
		}
		revived++;
	}

	return revived;
}

int CountHumanSurvivors()
{
	int count = 0;
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == TEAM_SURVIVOR)
		{
			count++;
		}
	}
	return count;
}

int FindRandomLivingSurvivor()
{
	int clients[MAXPLAYERS];
	int count = 0;

	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && GetClientTeam(client) == TEAM_SURVIVOR && IsPlayerAlive(client))
		{
			clients[count++] = client;
		}
	}

	return count > 0 ? clients[GetRandomInt(0, count - 1)] : 0;
}

bool FindNearbyGroundPosition(int anchor, float position[3], float radius)
{
	float origin[3];
	GetClientAbsOrigin(anchor, origin);

	for (int attempt = 0; attempt < 10; attempt++)
	{
		float angle = GetRandomFloat(0.0, 360.0);
		float start[3];
		float end[3];

		start[0] = origin[0] + Cosine(DegToRad(angle)) * radius;
		start[1] = origin[1] + Sine(DegToRad(angle)) * radius;
		start[2] = origin[2] + 48.0;
		end[0] = start[0];
		end[1] = start[1];
		end[2] = origin[2] - 96.0;

		Handle trace = TR_TraceRayEx(start, end, MASK_PLAYERSOLID_BRUSHONLY, RayType_EndPoint);
		if (TR_DidHit(trace))
		{
			TR_GetEndPosition(position, trace);
			position[2] += 6.0;
			delete trace;

			if (L4D_GetNearestNavArea(position, 150.0, true, false, true, TEAM_SURVIVOR) != 0)
			{
				return true;
			}
		}
		else
		{
			delete trace;
		}
	}

	position[0] = origin[0];
	position[1] = origin[1];
	position[2] = origin[2];
	return false;
}

void LoadMapFlowConfig()
{
	g_bMapFlowDisabled = false;
	g_fMapMaxFlowOverride = 0.0;

	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "configs/l4d2_flow_difficulty_maps.cfg");

	KeyValues kv = new KeyValues("FlowDifficultyMaps");
	if (!kv.ImportFromFile(path))
	{
		delete kv;
		LogMessage("未找到地图路程保护配置：%s，使用自动检测。", path);
		return;
	}

	char map[64];
	GetCurrentMap(map, sizeof(map));
	if (kv.JumpToKey(map, false))
	{
		g_bMapFlowDisabled = kv.GetNum("disable", 0) != 0;
		g_fMapMaxFlowOverride = kv.GetFloat("max_flow", 0.0);
	}
	delete kv;

	if (g_bMapFlowDisabled)
	{
		LogMessage("地图 %s 已在配置中禁用路程减难。", map);
	}
	else if (g_fMapMaxFlowOverride > 0.0)
	{
		LogMessage("地图 %s 使用手动最大路程 %.1f。", map, g_fMapMaxFlowOverride);
	}
}

public Action Command_Status(int client, int args)
{
	char recentWipes[96];
	FormatRecentWipes(recentWipes, sizeof(recentWipes));

	char target[32];
	if (g_bFlowFallbackActive)
	{
		strcopy(target, sizeof(target), "暂停");
	}
	else if (g_bTier2TargetValid)
	{
		FormatEx(target, sizeof(target), "%.1f%%", g_fTier2Target);
	}
	else
	{
		strcopy(target, sizeof(target), "暂无");
	}

	char voteState[96];
	if (g_eActiveVote == AssistVote_Tier1)
	{
		FormatEx(voteState, sizeof(voteState), "第一阶进行中 %d/%d", g_iReceivedVotes, g_iExpectedVoters);
	}
	else if (g_eActiveVote == AssistVote_Tier2)
	{
		FormatEx(voteState, sizeof(voteState), "第二阶进行中 %d/%d", g_iReceivedVotes, g_iExpectedVoters);
	}
	else if (g_eActiveVote == AssistVote_Tier3)
	{
		FormatEx(voteState, sizeof(voteState), "第三阶进行中 %d/%d", g_iReceivedVotes, g_iExpectedVoters);
	}
	else if (g_bTier1VotePending)
	{
		strcopy(voteState, sizeof(voteState), "第一阶等待");
	}
	else if (g_bTier2VotePending && !g_bFlowFallbackActive)
	{
		strcopy(voteState, sizeof(voteState), "第二阶等待");
	}
	else if (g_bTier3VotePending && !g_bFlowFallbackActive)
	{
		strcopy(voteState, sizeof(voteState), "第三阶等待");
	}
	else
	{
		strcopy(voteState, sizeof(voteState), "无");
	}

	char nextStep[128];
	if (!g_cvEnable.BoolValue)
	{
		strcopy(nextStep, sizeof(nextStep), "插件已关闭");
	}
	else if (!g_bTier1Enabled)
	{
		if (g_bTier1VotePending || g_eActiveVote == AssistVote_Tier1)
		{
			strcopy(nextStep, sizeof(nextStep), "第一阶条件已满足，等待投票结果");
		}
		else if (g_bFlowFallbackActive)
		{
			FormatEx(
				nextStep,
				sizeof(nextStep),
				"导航备用：总团灭 %d/%d",
				g_iTotalWipes,
				g_cvFallbackTier1Wipes.IntValue
			);
		}
		else
		{
			FormatEx(
				nextStep,
				sizeof(nextStep),
				"第一阶：%.0f%% 前有效团灭 %d/%d",
				g_cvEarlyPercent.FloatValue,
				g_iEarlyWipes,
				g_cvTier1Wipes.IntValue
			);
		}
	}
	else if (g_bFlowFallbackActive)
	{
		strcopy(nextStep, sizeof(nextStep), "第一阶已开启；第二、三阶因导航备用模式暂停");
	}
	else if (!g_bTier2Enabled)
	{
		FormatEx(nextStep, sizeof(nextStep), "第二阶：总团灭 %d/%d", g_iTotalWipes, g_cvTier2Wipes.IntValue);
	}
	else if (!g_bTier3Enabled)
	{
		FormatEx(nextStep, sizeof(nextStep), "第三阶：总团灭 %d/%d", g_iTotalWipes, g_cvTier3Wipes.IntValue);
	}
	else
	{
		strcopy(nextStep, sizeof(nextStep), "第一、二、三阶均已开启");
	}

	char stageState[64];
	if (g_bTier3Enabled)
	{
		strcopy(stageState, sizeof(stageState), "第三阶（满血复活）");
	}
	else if (g_bTier2Enabled)
	{
		strcopy(stageState, sizeof(stageState), "第二阶（路程复活）");
	}
	else if (g_bTier1Enabled)
	{
		strcopy(stageState, sizeof(stageState), "第一阶（开局止痛药）");
	}
	else
	{
		strcopy(stageState, sizeof(stageState), "未开启");
	}

	char fallbackState[32];
	if (g_bMapFlowDisabled)
	{
		strcopy(fallbackState, sizeof(fallbackState), "地图禁用");
	}
	else
	{
		strcopy(fallbackState, sizeof(fallbackState), g_bFlowFallbackActive ? "开启" : "关闭");
	}

	ReplyToCommand(client, "[动态减难] 团灭:%d | %.0f%%前:%d/%d | 最近5次:%s", g_iTotalWipes, g_cvEarlyPercent.FloatValue, g_iEarlyWipes, g_cvTier1Wipes.IntValue, recentWipes);
	ReplyToCommand(client, "[动态减难] 阶段:%s | 下一步:%s | 复活目标:%s", stageState, nextStep, target);
	ReplyToCommand(client, "[动态减难] 投票:%s | 导航备用:%s", voteState, fallbackState);
	return Plugin_Handled;
}

public Action Command_Reset(int client, int args)
{
	ResetChapterState("管理员手动重置");
	g_bRoundActive = true;
	g_iRoundSerial++;
	ReplyToCommand(client, "[动态减难] 已清空当前章节的所有计数和减难状态。");
	LogAction(client, -1, "\"%L\" 清空了当前章节的动态减难状态。", client);
	return Plugin_Handled;
}
