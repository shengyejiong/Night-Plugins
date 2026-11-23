#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#define PLUGIN_VERSION "1.8.3-night"
#define SAMPLE_COUNT 5
#define TEAM_SURVIVOR 2
#define SETUP_RETRY_LOG_INTERVAL 30
#define STARTER_WEAPON_COUNT 5
#define ASSIST_VOTE_PASS_PERCENT 60.0
#define REVIVE_SUPPLY_COUNT 4

static const char g_sStarterWeaponClassnames[STARTER_WEAPON_COUNT][] =
{
	"weapon_pumpshotgun",
	"weapon_shotgun_chrome",
	"weapon_sniper_scout",
	"weapon_smg",
	"weapon_smg_silenced"
};

static const char g_sStarterWeaponNames[STARTER_WEAPON_COUNT][] =
{
	"木喷",
	"铁喷",
	"鸟狙",
	"UZI",
	"消音冲锋枪"
};

// 顺序与武器候选池一致。鸟狙占 4/40，其余各占 9/40。
static const int g_iStarterWeaponWeights[STARTER_WEAPON_COUNT] = {9, 9, 4, 9, 9};

static const char g_sReviveSupplyClassnames[REVIVE_SUPPLY_COUNT][] =
{
	"weapon_pain_pills",
	"weapon_adrenaline",
	"weapon_first_aid_kit",
	"weapon_defibrillator"
};

static const char g_sReviveSupplyNames[REVIVE_SUPPLY_COUNT][] =
{
	"止痛药",
	"肾上腺素",
	"医疗包",
	"除颤器"
};

enum AssistVote
{
	AssistVote_None = 0,
	AssistVote_Tier1,
	AssistVote_Tier2,
	AssistVote_Tier3,
	AssistVote_Tier4,
	AssistVote_Tier5
};

enum AssistVoteChoice
{
	AssistVoteChoice_None = 0,
	AssistVoteChoice_Yes,
	AssistVoteChoice_No,
	AssistVoteChoice_Abstain
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
ConVar g_cvTier4Wipes;
ConVar g_cvTier5Wipes;
ConVar g_cvFallbackInvalidWipes;
ConVar g_cvFallbackTier1Wipes;
ConVar g_cvVoteTime;
ConVar g_cvReviveHealth;
ConVar g_cvAmmoShotgunMax;
ConVar g_cvAmmoSniperMax;
ConVar g_cvAmmoSmgMax;

Handle g_hFlowTimer;
Handle g_hRoundSetupTimer;
Handle g_hAssistVoteTimer;

bool g_bRoundActive;
bool g_bMissionLostHandled;
bool g_bAttemptFlowValid;
bool g_bTier1Enabled;
bool g_bTier2Enabled;
bool g_bTier3Enabled;
bool g_bTier4Enabled;
bool g_bTier5Enabled;
bool g_bTier1VotePending;
bool g_bTier2VotePending;
bool g_bTier3VotePending;
bool g_bTier4VotePending;
bool g_bTier5VotePending;
bool g_bPillsPending;
bool g_bTier2TargetValid;
bool g_bTier2Triggered;
bool g_bTier5Triggered;
bool g_bTier2TargetManual;
bool g_bTier2RoundNoticeSent;
bool g_bTier2NearNoticeSent;
bool g_bMapFlowDisabled;
bool g_bFlowFallbackActive;
bool g_bVoteClientVoted[MAXPLAYERS + 1];
bool g_bVoteClientAdmin[MAXPLAYERS + 1];
bool g_bStarterWeaponClaimed[MAXPLAYERS + 1];
bool g_bStarterWeaponMenuOpen[MAXPLAYERS + 1];
bool g_bRecentWipeValid[SAMPLE_COUNT];

int g_iRoundSerial;
int g_iSetupRetries;
int g_iTotalWipes;
int g_iWipeProgressOffset;
int g_iEarlyWipes;
int g_iWipeSampleCount;
int g_iWipeSampleNext;
int g_iRecentWipeCount;
int g_iRecentWipeNext;
int g_iConsecutiveInvalidWipes;
int g_iExpectedVoters;
int g_iReceivedVotes;
int g_iAssistVoteSerial;
int g_iAssistVoteYes;
int g_iAssistVoteNo;
int g_iAssistVoteAbstain;
AssistVoteChoice g_eVoteChoices[MAXPLAYERS + 1];
int g_iStarterWeaponMenuSerial[MAXPLAYERS + 1];

float g_fAttemptMaxPercent;
float g_fWipeSamples[SAMPLE_COUNT];
float g_fRecentWipePercents[SAMPLE_COUNT];
float g_fTier2Target;
float g_fTier2ManualTarget;
float g_fMapMaxFlowOverride;

char g_sLastWipeReason[96];
char g_sLastResetReason[64];

AssistVote g_eActiveVote = AssistVote_None;
AssistVote g_eManualVoteTarget = AssistVote_None;

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
	g_cvTier4Wipes = CreateConVar(
		"l4d2_flow_difficulty_tier4_wipes",
		"9",
		"触发第四阶复活医疗物资投票所需的总团灭次数。",
		FCVAR_NOTIFY,
		true,
		1.0
	);
	g_cvTier5Wipes = CreateConVar(
		"l4d2_flow_difficulty_tier5_wipes",
		"11",
		"触发第五阶孤立生还者复活投票所需的总团灭次数。",
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
		"每次减难投票持续时间，单位为秒；弃权不计入同意率分母。",
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
	g_cvAmmoShotgunMax = FindConVar("ammo_shotgun_max");
	g_cvAmmoSniperMax = FindConVar("ammo_sniperrifle_max");
	g_cvAmmoSmgMax = FindConVar("ammo_smg_max");

	CreateConVar(
		"l4d2_flow_difficulty_version",
		PLUGIN_VERSION,
		"根据路程动态减难插件版本。",
		FCVAR_NOTIFY | FCVAR_DONTRECORD
	);

	RegConsoleCmd("sm_flowassist_status", Command_Status, "查看动态减难状态。");
	RegConsoleCmd("sm_fd", Command_Status, "查看动态减难状态（简写）。");
	RegConsoleCmd("sm_flowassist", Command_OpenAssistStageMenu, "打开主动减难阶段投票菜单。");
	RegConsoleCmd("sm_flowassist_vote", Command_OpenAssistStageMenu, "打开主动减难阶段投票菜单（完整指令）。");
	RegConsoleCmd("sm_fa", Command_OpenAssistStageMenu, "打开主动减难阶段投票菜单（简写）。");
	RegConsoleCmd("sm_fr", Command_SetReviveFlow, "设置当前回合复活路程百分比。");
	RegConsoleCmd("sm_gun", Command_StarterWeaponMenu, "打开随机基础主武器领取菜单。");
	RegConsoleCmd("sm_sg", Command_StarterWeaponMenu, "打开随机基础主武器领取菜单（简写）。");
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

	delete g_hAssistVoteTimer;
	g_hAssistVoteTimer = null;
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
	g_bTier4Enabled = false;
	g_bTier5Enabled = false;
	g_bTier1VotePending = false;
	g_bTier2VotePending = false;
	g_bTier3VotePending = false;
	g_bTier4VotePending = false;
	g_bTier5VotePending = false;
	g_bPillsPending = false;
	g_bTier2TargetValid = false;
	g_bTier2Triggered = false;
	g_bTier5Triggered = false;
	g_bTier2TargetManual = false;
	g_bTier2RoundNoticeSent = false;
	g_bTier2NearNoticeSent = false;
	g_bFlowFallbackActive = false;
	g_iTotalWipes = 0;
	g_iWipeProgressOffset = 0;
	g_iEarlyWipes = 0;
	g_iWipeSampleCount = 0;
	g_iWipeSampleNext = 0;
	g_iRecentWipeCount = 0;
	g_iRecentWipeNext = 0;
	g_iConsecutiveInvalidWipes = 0;
	g_iExpectedVoters = 0;
	g_iReceivedVotes = 0;
	g_iAssistVoteYes = 0;
	g_iAssistVoteNo = 0;
	g_iAssistVoteAbstain = 0;
	g_fAttemptMaxPercent = 0.0;
	g_fTier2Target = 0.0;
	g_fTier2ManualTarget = 0.0;
	g_eActiveVote = AssistVote_None;
	g_eManualVoteTarget = AssistVote_None;
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
		g_bVoteClientAdmin[client] = false;
		g_eVoteChoices[client] = AssistVoteChoice_None;
		g_bStarterWeaponClaimed[client] = false;
		g_bStarterWeaponMenuOpen[client] = false;
		g_iStarterWeaponMenuSerial[client] = 0;
	}

	delete g_hRoundSetupTimer;
	g_hRoundSetupTimer = null;

	delete g_hAssistVoteTimer;
	g_hAssistVoteTimer = null;
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
	g_bTier5Triggered = false;
	g_bTier2TargetManual = false;
	g_fTier2ManualTarget = 0.0;
	g_fAttemptMaxPercent = 0.0;
	g_bTier2TargetValid = g_bTier2Enabled && !g_bFlowFallbackActive && CalculateWipeAverage(g_fTier2Target);
	g_bTier2RoundNoticeSent = false;
	g_bTier2NearNoticeSent = false;
	AnnounceTier2RoundTarget();

	delete g_hRoundSetupTimer;
	g_hRoundSetupTimer = CreateTimer(
		2.0,
		Timer_RoundSetup,
		g_iRoundSerial,
		TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE
	);

	delete g_hAssistVoteTimer;
	g_hAssistVoteTimer = null;
	g_eActiveVote = AssistVote_None;
	g_iExpectedVoters = 0;
	g_iReceivedVotes = 0;

	for (int client = 1; client <= MaxClients; client++)
	{
		g_bStarterWeaponClaimed[client] = false;
		g_bStarterWeaponMenuOpen[client] = false;
		g_iStarterWeaponMenuSerial[client] = 0;
		g_bVoteClientVoted[client] = false;
		g_bVoteClientAdmin[client] = false;
		g_eVoteChoices[client] = AssistVoteChoice_None;
	}
}

public void Event_MissionLost(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_cvEnable.BoolValue || g_bMissionLostHandled)
	{
		return;
	}

	g_bMissionLostHandled = true;
	delete g_hAssistVoteTimer;
	g_hAssistVoteTimer = null;
	g_eActiveVote = AssistVote_None;
	g_iExpectedVoters = 0;
	g_iReceivedVotes = 0;
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
			g_bTier4VotePending = false;
			g_bTier5VotePending = false;
			g_bTier2TargetValid = false;
			PrintToChatAll(
				"\x04[动态减难]\x05 连续 \x03%d\x05 次团灭无法取得路程，已启用导航备用模式；总团灭达到 \x03%d\x05 次可触发第一阶，第二至四阶暂停。",
				g_iConsecutiveInvalidWipes,
				g_cvFallbackTier1Wipes.IntValue
			);
			LogMessage(
				"连续 %d 次团灭无法取得路程，启用导航备用模式；第一阶改用总团灭阈值 %d，第二至五阶暂停。",
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
	else if (g_bTier1Enabled && !g_bTier2Enabled && !g_bFlowFallbackActive && GetProgressWipes() >= g_cvTier2Wipes.IntValue)
	{
		g_bTier2VotePending = true;
	}
	else if (g_bTier2Enabled && !g_bTier3Enabled && !g_bFlowFallbackActive && GetProgressWipes() >= g_cvTier3Wipes.IntValue)
	{
		g_bTier3VotePending = true;
	}
	else if (g_bTier3Enabled && !g_bTier4Enabled && !g_bFlowFallbackActive && GetProgressWipes() >= g_cvTier4Wipes.IntValue)
	{
		g_bTier4VotePending = true;
	}
	else if (g_bTier4Enabled && !g_bTier5Enabled && !g_bFlowFallbackActive && GetProgressWipes() >= g_cvTier5Wipes.IntValue)
	{
		g_bTier5VotePending = true;
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

	if (g_bTier2Enabled && !g_bFlowFallbackActive && g_bTier2TargetValid
		&& !g_bTier2NearNoticeSent && g_fTier2Target > 0.0
		&& percent >= g_fTier2Target - 5.0 && percent < g_fTier2Target)
	{
		g_bTier2NearNoticeSent = true;
		if (g_bTier4Enabled)
		{
			PrintToChatAll(
				"\x04[动态减难]\x05 距离本回合复活路程 \x03%.1f%%\x05 还剩约 \x03%.1f%%\x05，接近目标后会复活并随机给予医疗物资。",
				g_fTier2Target,
				g_fTier2Target - percent
			);
		}
		else
		{
			PrintToChatAll(
				"\x04[动态减难]\x05 距离本回合复活路程 \x03%.1f%%\x05 还剩约 \x03%.1f%%\x05，接近目标后会复活死亡真人。",
				g_fTier2Target,
				g_fTier2Target - percent
			);
		}
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

	if (g_bTier5Enabled && g_bTier2Triggered && !g_bTier5Triggered
		&& CountLivingSurvivors() == 1)
	{
		g_bTier5Triggered = true;
		int revived = ReviveDeadHumanSurvivors(g_bTier3Enabled);
		if (revived > 0)
		{
			PrintToChatAll(
				"\x04[动态减难]\x05 检测到仅剩 1 名存活生还者，已按第五阶复活 \x03%d\x05 名死亡真人。",
				revived
			);
		}
		else
		{
			LogMessage("第五阶触发：检测到仅剩 1 名存活生还者，但当前没有可复活的死亡真人。");
		}
	}

	return Plugin_Continue;
}

void AnnounceTier2RoundTarget()
{
	if (!g_bTier2TargetValid || g_bTier2RoundNoticeSent)
	{
		return;
	}

	g_bTier2RoundNoticeSent = true;
	if (!g_bTier2TargetManual && g_iWipeSampleCount <= 0)
	{
		if (g_bTier4Enabled)
		{
			PrintToChatAll("\x04[动态减难]\x05 本回合已启用路程复活，但暂时没有有效团灭路程；本回合先按 \x0350%%\x05 复活，并随机给予一件医疗物资。");
		}
		else if (g_bTier3Enabled)
		{
			PrintToChatAll("\x04[动态减难]\x05 本回合已启用路程复活，但暂时没有有效团灭路程；本回合先按 \x0350%%\x05 复活死亡真人，并给予满血。");
		}
		else
		{
			PrintToChatAll("\x04[动态减难]\x05 本回合已启用路程复活，但暂时没有有效团灭路程；本回合先按 \x0350%%\x05 复活死亡真人，给予 \x03%d\x05 实血。", g_cvReviveHealth.IntValue);
		}
		return;
	}
	if (g_bTier4Enabled)
	{
		PrintToChatAll(
			"\x04[动态减难]\x05 本回合已启用路程复活：到达 \x03%.1f%%\x05 时复活死亡真人、给予满血，并随机给予一件医疗物资。",
			g_fTier2Target
		);
	}
	else if (g_bTier3Enabled)
	{
		PrintToChatAll(
			"\x04[动态减难]\x05 本回合已启用路程复活：到达 \x03%.1f%%\x05 时复活死亡真人，并给予满血。",
			g_fTier2Target
		);
	}
	else
	{
		PrintToChatAll(
			"\x04[动态减难]\x05 本回合已启用路程复活：到达 \x03%.1f%%\x05 时复活死亡真人，给予 \x03%d\x05 实血。",
			g_fTier2Target,
			g_cvReviveHealth.IntValue
		);
	}
}

bool HasPendingAssistVote()
{
	return g_bTier1VotePending || g_bTier2VotePending || g_bTier3VotePending || g_bTier4VotePending;
}

public Action Command_OpenAssistStageMenu(int client, int args)
{
	if (client < 1 || !IsClientInGame(client) || IsFakeClient(client))
	{
		return Plugin_Handled;
	}
	if (!g_cvEnable.BoolValue)
	{
		ReplyToCommand(client, "[动态减难] 当前功能已关闭。");
		return Plugin_Handled;
	}
	if (g_eActiveVote != AssistVote_None || HasPendingAssistVote())
	{
		ReplyToCommand(client, "[动态减难] 当前已有阶段投票进行中或等待开始。");
		return Plugin_Handled;
	}

	ShowAssistStageMenu(client);
	return Plugin_Handled;
}

void ShowAssistStageMenu(int client)
{
	Menu menu = new Menu(MenuHandler_AssistStageMenu);
	menu.SetTitle("选择要发起的最高减难阶段");

	if (!g_bTier1Enabled)
	{
		menu.AddItem("tier|1", "第一阶：开局止痛药");
	}
	if (!g_bTier2Enabled && !g_bFlowFallbackActive)
	{
		menu.AddItem("tier|2", "第二阶：路程复活");
	}
	if (!g_bTier3Enabled && !g_bFlowFallbackActive)
	{
		menu.AddItem("tier|3", "第三阶：满血复活");
	}
	if (!g_bTier4Enabled && !g_bFlowFallbackActive)
	{
		menu.AddItem("tier|4", "第四阶：复活医疗物资");
	}
	if (!g_bTier5Enabled && !g_bFlowFallbackActive)
	{
		menu.AddItem("tier|5", "第五阶：孤立生还者复活");
	}
	if (menu.ItemCount <= 0)
	{
		menu.AddItem("none", "所有减难阶段均已开启", ITEMDRAW_DISABLED);
	}

	menu.ExitButton = true;
	if (!menu.Display(client, MENU_TIME_FOREVER))
	{
		delete menu;
	}
}

public int MenuHandler_AssistStageMenu(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(param2, info, sizeof(info));
		char data[2][16];
		if (ExplodeString(info, "|", data, sizeof(data), sizeof(data[])) == 2
			&& StrEqual(data[0], "tier", false))
		{
			AssistVote target = view_as<AssistVote>(StringToInt(data[1]));
			if (g_eActiveVote != AssistVote_None || HasPendingAssistVote())
			{
				PrintToChat(param1, "\x04[动态减难]\x05 当前已有阶段投票进行中或等待开始。");
			}
			else if ((target == AssistVote_Tier2 || target == AssistVote_Tier3 || target == AssistVote_Tier4 || target == AssistVote_Tier5)
				&& g_bFlowFallbackActive)
			{
				PrintToChat(param1, "\x04[动态减难]\x05 当前处于导航备用模式，第二至五阶暂不可发起。");
			}
			else
			{
				if (GetUserAdmin(param1) != INVALID_ADMIN_ID)
				{
					EnableAssistStagesThrough(target);
					PrintToChatAll("\x04[动态减难]\x05 管理员 \x03%N\x05 已直接开启目标阶段及所有前置减难阶段。", param1);
				}
				else
				{
					QueueAssistVoteChain(target);
					PrintToChat(param1, "\x04[动态减难]\x05 已发起目标阶段投票，前置阶段会一次性包含在本次投票中。");
					HandlePendingVote();
				}
			}
		}
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
	return 0;
}

void QueueAssistVoteChain(AssistVote target)
{
	g_eManualVoteTarget = target;
}

void EnableAssistStagesThrough(AssistVote target)
{
	SetStageProgressOffset(target);
	if (target >= AssistVote_Tier1)
	{
		g_bTier1Enabled = true;
	}
	if (target >= AssistVote_Tier3)
	{
		g_bTier3Enabled = true;
	}
	if (target >= AssistVote_Tier4)
	{
		g_bTier4Enabled = true;
	}
	if (target >= AssistVote_Tier5)
	{
		g_bTier5Enabled = true;
	}
	if (target >= AssistVote_Tier2)
	{
		g_bTier2Enabled = true;
		g_bTier2TargetValid = RefreshTier2Target();
		g_bTier2RoundNoticeSent = false;
		g_bTier2NearNoticeSent = false;
		AnnounceTier2RoundTarget();
	}
}

void SetStageProgressOffset(AssistVote target)
{
	if (target == AssistVote_Tier2)
	{
		g_iWipeProgressOffset = g_cvTier2Wipes.IntValue - g_iTotalWipes;
	}
	else if (target == AssistVote_Tier3)
	{
		g_iWipeProgressOffset = g_cvTier3Wipes.IntValue - g_iTotalWipes;
	}
	else if (target == AssistVote_Tier4)
	{
		g_iWipeProgressOffset = g_cvTier4Wipes.IntValue - g_iTotalWipes;
	}
	else if (target == AssistVote_Tier5)
	{
		g_iWipeProgressOffset = g_cvTier5Wipes.IntValue - g_iTotalWipes;
	}
}

int GetProgressWipes()
{
	return g_iTotalWipes + g_iWipeProgressOffset;
}

public Action Command_SetReviveFlow(int client, int args)
{
	if (client < 1 || !IsClientInGame(client) || IsFakeClient(client))
	{
		return Plugin_Handled;
	}
	if (!g_cvEnable.BoolValue)
	{
		ReplyToCommand(client, "[动态减难] 当前功能已关闭。");
		return Plugin_Handled;
	}
	if (g_bTier2Triggered)
	{
		ReplyToCommand(client, "[动态减难] 本回合已经完成路程复活，不能再修改目标。");
		return Plugin_Handled;
	}
	if (g_bMapFlowDisabled || g_bFlowFallbackActive)
	{
		ReplyToCommand(client, "[动态减难] 当前地图路程功能不可用，不能设置复活目标。");
		return Plugin_Handled;
	}
	if (args < 1)
	{
		ReplyToCommand(client, "用法：!fr <0-100>，例如 !fr 50。");
		return Plugin_Handled;
	}

	char valueText[32];
	GetCmdArg(1, valueText, sizeof(valueText));
	float target;
	if (StringToFloatEx(valueText, target) <= 0 || target < 0.0 || target > 100.0)
	{
		ReplyToCommand(client, "[动态减难] 复活路程必须是 0 到 100 之间的数字。");
		return Plugin_Handled;
	}

	g_bTier2TargetManual = true;
	g_fTier2ManualTarget = target;
	g_fTier2Target = target;
	g_bTier2TargetValid = true;
	g_bTier2RoundNoticeSent = false;
	g_bTier2NearNoticeSent = false;

	if (g_bTier2Enabled)
	{
		AnnounceTier2RoundTarget();
	}
	else
	{
		PrintToChatAll(
			"\x04[动态减难]\x05 玩家 \x03%N\x05 已将本回合复活路程手动设为 \x03%.1f%%\x05；第二阶开启后将使用该目标。",
			client,
			target
		);
	}
	return Plugin_Handled;
}

public Action Command_StarterWeaponMenu(int client, int args)
{
	if (client < 1 || !IsClientInGame(client) || IsFakeClient(client))
	{
		return Plugin_Handled;
	}
	if (!g_cvEnable.BoolValue)
	{
		ReplyToCommand(client, "[动态减难] 当前功能已关闭。");
		return Plugin_Handled;
	}
	if (GetClientTeam(client) != TEAM_SURVIVOR || !IsPlayerAlive(client))
	{
		ReplyToCommand(client, "[动态减难] 只有存活的真人生还者可以领取随机主武器。");
		return Plugin_Handled;
	}
	if (g_bStarterWeaponClaimed[client])
	{
		ReplyToCommand(client, "[动态减难] 本回合已经领取过随机主武器。");
		return Plugin_Handled;
	}
	if (g_bStarterWeaponMenuOpen[client])
	{
		ReplyToCommand(client, "[动态减难] 武器领取菜单已经打开。");
		return Plugin_Handled;
	}

	if (!ShowStarterWeaponOffer(client, g_iRoundSerial))
	{
		ReplyToCommand(client, "[动态减难] 菜单显示失败，请稍后重新输入指令。");
	}
	return Plugin_Handled;
}

bool ShowStarterWeaponOffer(int client, int serial)
{
	Menu menu = new Menu(MenuHandler_StarterWeaponOffer);
	menu.SetTitle("是否领取一把随机基础主武器？\n已有主武器时不会发放");

	char info[32];
	FormatEx(info, sizeof(info), "accept|%d", serial);
	menu.AddItem(info, "领取");
	FormatEx(info, sizeof(info), "decline|%d", serial);
	menu.AddItem(info, "取消");
	menu.ExitButton = false;

	if (!menu.Display(client, 15))
	{
		delete menu;
		return false;
	}

	g_bStarterWeaponMenuOpen[client] = true;
	g_iStarterWeaponMenuSerial[client] = serial;
	return true;
}

public int MenuHandler_StarterWeaponOffer(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(param2, info, sizeof(info));

		char data[2][16];
		if (ExplodeString(info, "|", data, sizeof(data), sizeof(data[])) == 2)
		{
			int serial = StringToInt(data[1]);
			if (param1 >= 1 && param1 <= MaxClients
				&& g_bStarterWeaponMenuOpen[param1]
				&& g_iStarterWeaponMenuSerial[param1] == serial)
			{
				g_bStarterWeaponMenuOpen[param1] = false;
				g_iStarterWeaponMenuSerial[param1] = 0;
			}

			if (StrEqual(data[0], "accept", false))
			{
				GiveRandomStarterWeapon(param1, serial);
			}
		}
	}
	else if (action == MenuAction_Cancel)
	{
		int client = param1;
		if (client >= 1 && client <= MaxClients && g_bStarterWeaponMenuOpen[client])
		{
			g_bStarterWeaponMenuOpen[client] = false;
			g_iStarterWeaponMenuSerial[client] = 0;
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
	if (client < 1 || client > MaxClients || !IsClientInGame(client) || IsFakeClient(client))
	{
		return;
	}
	if (serial != g_iRoundSerial || !g_cvEnable.BoolValue)
	{
		PrintToChat(client, "\x04[动态减难]\x05 本次武器领取菜单已经过期。");
		return;
	}
	if (GetClientTeam(client) != TEAM_SURVIVOR || !IsPlayerAlive(client))
	{
		PrintToChat(client, "\x04[动态减难]\x05 只有存活的真人生还者可以领取随机主武器。");
		return;
	}
	if (g_bStarterWeaponClaimed[client])
	{
		PrintToChat(client, "\x04[动态减难]\x05 本回合已经领取过随机主武器。");
		return;
	}
	if (GetPlayerWeaponSlot(client, 0) != -1)
	{
		PrintToChat(client, "\x04[动态减难]\x05 你已经拥有主武器，本次不会发放，也不会消耗领取资格。");
		return;
	}

	int weaponIndex = RollStarterWeaponIndex();
	int weapon = GivePlayerItem(client, g_sStarterWeaponClassnames[weaponIndex]);
	if (weapon == -1)
	{
		PrintToChat(client, "\x04[动态减难]\x05 随机主武器发放失败，请联系管理员。");
		LogError("无法为玩家 %N 发放随机主武器 %s。", client, g_sStarterWeaponClassnames[weaponIndex]);
		return;
	}

	EquipPlayerWeapon(client, weapon);
	FillStarterWeaponReserveAmmo(client, weapon, weaponIndex);

	g_bStarterWeaponClaimed[client] = true;
	PrintToChat(
		client,
		"\x04[动态减难]\x05 已领取随机主武器：\x03%s\x05，备弹已补至当前上限。",
		g_sStarterWeaponNames[weaponIndex]
	);
}

int RollStarterWeaponIndex()
{
	int totalWeight = 0;
	for (int i = 0; i < STARTER_WEAPON_COUNT; i++)
	{
		totalWeight += g_iStarterWeaponWeights[i];
	}

	int roll = GetRandomInt(1, totalWeight);
	for (int i = 0; i < STARTER_WEAPON_COUNT - 1; i++)
	{
		roll -= g_iStarterWeaponWeights[i];
		if (roll <= 0)
		{
			return i;
		}
	}
	return STARTER_WEAPON_COUNT - 1;
}

void FillStarterWeaponReserveAmmo(int client, int weapon, int weaponIndex)
{
	int ammoType = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
	if (ammoType < 0)
	{
		return;
	}

	ConVar ammoMaxCvar = g_cvAmmoSmgMax;
	if (weaponIndex < 2)
	{
		ammoMaxCvar = g_cvAmmoShotgunMax;
	}
	else if (weaponIndex == 2)
	{
		ammoMaxCvar = g_cvAmmoSniperMax;
	}
	if (ammoMaxCvar == null)
	{
		return;
	}

	int currentAmmo = GetEntProp(client, Prop_Send, "m_iAmmo", _, ammoType);
	int ammoNeeded = ammoMaxCvar.IntValue - currentAmmo;
	if (ammoNeeded > 0)
	{
		GivePlayerAmmo(client, ammoNeeded, ammoType, true);
	}
}

public void OnClientDisconnect(int client)
{
	g_bStarterWeaponClaimed[client] = false;
	g_bStarterWeaponMenuOpen[client] = false;
	g_iStarterWeaponMenuSerial[client] = 0;
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
	if (g_eManualVoteTarget != AssistVote_None)
	{
		voteType = g_eManualVoteTarget;
	}
	else if (g_bTier1VotePending && !g_bTier1Enabled)
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
	else if (g_bTier4VotePending && g_bTier3Enabled && !g_bTier4Enabled && !g_bFlowFallbackActive)
	{
		voteType = AssistVote_Tier4;
	}
	else if (g_bTier5VotePending && g_bTier4Enabled && !g_bTier5Enabled && !g_bFlowFallbackActive)
	{
		voteType = AssistVote_Tier5;
	}
	else
	{
		return true;
	}

	int clients[MAXPLAYERS + 1];
	int playerCount = 0;
	for (int client = 1; client <= MaxClients; client++)
	{
		g_bVoteClientVoted[client] = false;
		g_bVoteClientAdmin[client] = false;
		g_eVoteChoices[client] = AssistVoteChoice_None;
		if (!IsClientInGame(client) || IsFakeClient(client))
		{
			continue;
		}
		clients[playerCount++] = client;
		g_bVoteClientAdmin[client] = GetUserAdmin(client) != INVALID_ADMIN_ID;
	}

	if (playerCount <= 0)
	{
		return false;
	}

	g_iAssistVoteSerial++;
	g_eActiveVote = voteType;
	g_iExpectedVoters = playerCount;
	g_iReceivedVotes = 0;
	g_iAssistVoteYes = 0;
	g_iAssistVoteNo = 0;
	g_iAssistVoteAbstain = 0;

	for (int i = 0; i < playerCount; i++)
	{
		int client = clients[i];
		if (!ShowAssistVoteMenu(client, voteType, g_iAssistVoteSerial))
		{
			RecordAssistVote(client, AssistVoteChoice_Abstain, g_iAssistVoteSerial);
		}
	}

	g_hAssistVoteTimer = CreateTimer(
		float(g_cvVoteTime.IntValue),
		Timer_AssistVoteEnd,
		g_iAssistVoteSerial,
		TIMER_FLAG_NO_MAPCHANGE
	);

	if (voteType == AssistVote_Tier1)
	{
		g_bTier1VotePending = false;
		PrintToChatAll("\x04[动态减难]\x05 第一阶投票开始：左侧菜单选择 1 同意、2 反对、3 弃权、4 退出；同意率需超过 %.0f%%，管理员反对可否决。", ASSIST_VOTE_PASS_PERCENT);
	}
	else if (voteType == AssistVote_Tier2)
	{
		g_bTier2VotePending = false;
		PrintToChatAll("\x04[动态减难]\x05 第二阶投票开始：左侧菜单选择 1 同意、2 反对、3 弃权、4 退出；同意率需超过 %.0f%%，管理员反对可否决。", ASSIST_VOTE_PASS_PERCENT);
	}
	else if (voteType == AssistVote_Tier3)
	{
		g_bTier3VotePending = false;
		PrintToChatAll("\x04[动态减难]\x05 第三阶投票开始：左侧菜单选择 1 同意、2 反对、3 弃权、4 退出；同意率需超过 %.0f%%，管理员反对可否决。", ASSIST_VOTE_PASS_PERCENT);
	}
	else if (voteType == AssistVote_Tier4)
	{
		g_bTier4VotePending = false;
		PrintToChatAll("\x04[动态减难]\x05 第四阶投票开始：左侧菜单选择 1 同意、2 反对、3 弃权、4 退出；同意率需超过 %.0f%%，管理员反对可否决。", ASSIST_VOTE_PASS_PERCENT);
	}
	else if (voteType == AssistVote_Tier5)
	{
		g_bTier5VotePending = false;
		PrintToChatAll("\x04[动态减难]\x05 第五阶投票开始：左侧菜单选择 1 同意、2 反对、3 弃权、4 退出；同意率需超过 %.0f%%，管理员反对可否决。", ASSIST_VOTE_PASS_PERCENT);
	}

	return true;
}

bool ShowAssistVoteMenu(int client, AssistVote voteType, int serial)
{
	Menu menu = new Menu(MenuHandler_AssistanceMenu);
	if (voteType == AssistVote_Tier1)
	{
		menu.SetTitle("开启第一阶减难？\n同意率需超过 %.0f%%", ASSIST_VOTE_PASS_PERCENT);
	}
	else if (voteType == AssistVote_Tier2)
	{
		menu.SetTitle("开启第二阶路程复活？\n同意率需超过 %.0f%%", ASSIST_VOTE_PASS_PERCENT);
	}
	else if (voteType == AssistVote_Tier3)
	{
		menu.SetTitle("开启第三阶满血复活？\n同意率需超过 %.0f%%", ASSIST_VOTE_PASS_PERCENT);
	}
	else if (voteType == AssistVote_Tier4)
	{
		menu.SetTitle("开启第四阶复活医疗物资？\n同意率需超过 %.0f%%", ASSIST_VOTE_PASS_PERCENT);
	}
	else
	{
		menu.SetTitle("开启第五阶孤立生还者复活？\n同意率需超过 %.0f%%", ASSIST_VOTE_PASS_PERCENT);
	}

	char info[32];
	FormatEx(info, sizeof(info), "yes|%d", serial);
	menu.AddItem(info, "同意");
	FormatEx(info, sizeof(info), "no|%d", serial);
	menu.AddItem(info, "反对");
	FormatEx(info, sizeof(info), "abstain|%d", serial);
	menu.AddItem(info, "弃权");
	FormatEx(info, sizeof(info), "exit|%d", serial);
	menu.AddItem(info, "退出");
	menu.ExitButton = false;

	if (!menu.Display(client, g_cvVoteTime.IntValue))
	{
		delete menu;
		return false;
	}
	return true;
}

public int MenuHandler_AssistanceMenu(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(param2, info, sizeof(info));

		char data[2][16];
		if (ExplodeString(info, "|", data, sizeof(data), sizeof(data[])) == 2)
		{
			AssistVoteChoice choice = AssistVoteChoice_Abstain;
			if (StrEqual(data[0], "yes", false))
			{
				choice = AssistVoteChoice_Yes;
			}
			else if (StrEqual(data[0], "no", false))
			{
				choice = AssistVoteChoice_No;
			}

			RecordAssistVote(param1, choice, StringToInt(data[1]));
		}
	}
	else if (action == MenuAction_Cancel)
	{
		RecordAssistVote(param1, AssistVoteChoice_Abstain, g_iAssistVoteSerial);
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
	return 0;
}

void RecordAssistVote(int client, AssistVoteChoice choice, int serial)
{
	if (serial != g_iAssistVoteSerial || g_eActiveVote == AssistVote_None
		|| client < 1 || client > MaxClients || g_bVoteClientVoted[client])
	{
		return;
	}

	g_bVoteClientVoted[client] = true;
	g_eVoteChoices[client] = choice;
	g_iReceivedVotes++;
	switch (choice)
	{
		case AssistVoteChoice_Yes:
			g_iAssistVoteYes++;

		case AssistVoteChoice_No:
			g_iAssistVoteNo++;

		default:
			g_iAssistVoteAbstain++;
	}
}

public Action Timer_AssistVoteEnd(Handle timer, any serial)
{
	if (timer == g_hAssistVoteTimer)
	{
		g_hAssistVoteTimer = null;
	}

	if (serial == g_iAssistVoteSerial && g_eActiveVote != AssistVote_None)
	{
		FinishAssistVote();
	}
	return Plugin_Stop;
}

void FinishAssistVote()
{
	AssistVote voteType = g_eActiveVote;
	bool manualVote = g_eManualVoteTarget != AssistVote_None;
	int yesVotes = g_iAssistVoteYes;
	int noVotes = g_iAssistVoteNo;
	int unrecordedVotes = g_iExpectedVoters - g_iReceivedVotes;
	if (unrecordedVotes < 0)
	{
		unrecordedVotes = 0;
	}
	int abstainVotes = g_iAssistVoteAbstain + unrecordedVotes;
	int activeVotes = yesVotes + noVotes;
	bool adminVeto = false;
	for (int client = 1; client <= MaxClients; client++)
	{
		if (g_bVoteClientAdmin[client] && g_eVoteChoices[client] == AssistVoteChoice_No)
		{
			adminVeto = true;
			break;
		}
	}

	float yesPercent = activeVotes > 0 ? float(yesVotes) * 100.0 / float(activeVotes) : 0.0;
	bool passed = !adminVeto && activeVotes > 0 && yesPercent > ASSIST_VOTE_PASS_PERCENT;
	if (!passed)
	{
		ClearHigherPendingVotes(voteType);
	}
	if (adminVeto)
	{
		PrintToChatAll("\x04[动态减难]\x05 投票失败：有管理员投反对票，执行最高否决；同意 %d，反对 %d，弃权 %d。", yesVotes, noVotes, abstainVotes);
	}
	else if (!passed)
	{
		PrintToChatAll("\x04[动态减难]\x05 投票未通过：同意 %d，反对 %d，弃权 %d，同意率 %.1f%%（需超过 %.0f%%）。", yesVotes, noVotes, abstainVotes, yesPercent, ASSIST_VOTE_PASS_PERCENT);
	}
	else if (manualVote)
	{
		EnableAssistStagesThrough(voteType);
		PrintToChatAll("\x04[动态减难]\x05 主动阶段投票通过：目标阶段及所有前置阶段已一次开启。\n同意 %d，反对 %d，弃权 %d，同意率 %.1f%%。", yesVotes, noVotes, abstainVotes, yesPercent);
	}
	else if (voteType == AssistVote_Tier1)
	{
		g_bTier1Enabled = true;
		PrintToChatAll("\x04[动态减难]\x05 第一阶已开启：从下一次团灭重开开始，每次按真人数量生成止痛药。\n同意 %d，反对 %d，弃权 %d，同意率 %.1f%%。", yesVotes, noVotes, abstainVotes, yesPercent);
	}
	else if (voteType == AssistVote_Tier2)
	{
		g_bTier2Enabled = true;
		g_bTier2TargetValid = RefreshTier2Target();
		if (g_bTier2TargetValid)
		{
			g_bTier2RoundNoticeSent = false;
			g_bTier2NearNoticeSent = false;
			AnnounceTier2RoundTarget();
			PrintToChatAll("\x04[动态减难]\x05 第二阶投票通过：同意 %d，反对 %d，弃权 %d，同意率 %.1f%%。", yesVotes, noVotes, abstainVotes, yesPercent);
		}
		else
		{
			PrintToChatAll("\x04[动态减难]\x05 第二阶已开启，但有效团灭路程不足 5 次，本回合不会复活。\n同意 %d，反对 %d，弃权 %d，同意率 %.1f%%。", yesVotes, noVotes, abstainVotes, yesPercent);
		}
	}
	else if (voteType == AssistVote_Tier3)
	{
		g_bTier3Enabled = true;
		PrintToChatAll("\x04[动态减难]\x05 第三阶已开启：后续路程复活的死亡真人将以满血状态复活。\n同意 %d，反对 %d，弃权 %d，同意率 %.1f%%。", yesVotes, noVotes, abstainVotes, yesPercent);
	}
	else if (voteType == AssistVote_Tier4)
	{
		g_bTier4Enabled = true;
		PrintToChatAll("\x04[动态减难]\x05 第四阶已开启：后续路程复活的真人将随机获得一件医疗物资（止痛药、肾上腺素、医疗包或除颤器）。\n同意 %d，反对 %d，弃权 %d，同意率 %.1f%%。", yesVotes, noVotes, abstainVotes, yesPercent);
	}
	else if (voteType == AssistVote_Tier5)
	{
		g_bTier5Enabled = true;
		PrintToChatAll("\x04[动态减难]\x05 第五阶已开启：本回合路程复活后，若只剩 1 名存活生还者，将复活当前死亡真人。\n同意 %d，反对 %d，弃权 %d，同意率 %.1f%%。", yesVotes, noVotes, abstainVotes, yesPercent);
	}

	g_eActiveVote = AssistVote_None;
	g_iExpectedVoters = 0;
	g_iReceivedVotes = 0;
	g_iAssistVoteYes = 0;
	g_iAssistVoteNo = 0;
	g_iAssistVoteAbstain = 0;
	g_eManualVoteTarget = AssistVote_None;
}

void ClearHigherPendingVotes(AssistVote failedVote)
{
	g_eManualVoteTarget = AssistVote_None;
	if (failedVote <= AssistVote_Tier1)
	{
		g_bTier2VotePending = false;
		g_bTier3VotePending = false;
		g_bTier4VotePending = false;
		g_bTier5VotePending = false;
	}
	else if (failedVote == AssistVote_Tier2)
	{
		g_bTier3VotePending = false;
		g_bTier4VotePending = false;
		g_bTier5VotePending = false;
	}
	else if (failedVote == AssistVote_Tier3)
	{
		g_bTier4VotePending = false;
		g_bTier5VotePending = false;
	}
	else if (failedVote == AssistVote_Tier4)
	{
		g_bTier5VotePending = false;
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
	if (g_bMapFlowDisabled || g_bFlowFallbackActive)
	{
		return false;
	}
	if (g_iWipeSampleCount <= 0)
	{
		average = 50.0;
		return true;
	}

	float total = 0.0;
	for (int i = 0; i < g_iWipeSampleCount; i++)
	{
		total += g_fWipeSamples[i];
	}

	average = total / float(g_iWipeSampleCount);
	return average >= 0.0 && average <= 100.0;
}

bool RefreshTier2Target()
{
	if (g_bTier2TargetManual)
	{
		g_fTier2Target = g_fTier2ManualTarget;
		return true;
	}

	return CalculateWipeAverage(g_fTier2Target);
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
		if (g_bTier4Enabled)
		{
			GiveRandomReviveSupply(client);
		}
		revived++;
	}

	return revived;
}

void GiveRandomReviveSupply(int client)
{
	int supplyIndex = GetRandomInt(0, REVIVE_SUPPLY_COUNT - 1);
	int entity = GivePlayerItem(client, g_sReviveSupplyClassnames[supplyIndex]);
	if (entity == -1)
	{
		LogError("无法为玩家 %N 发放第四阶复活医疗物资 %s。", client, g_sReviveSupplyClassnames[supplyIndex]);
		return;
	}

	PrintToChat(
		client,
		"\x04[动态减难]\x05 第四阶复活援助：获得随机医疗物资 \x03%s\x05。",
		g_sReviveSupplyNames[supplyIndex]
	);
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

int CountLivingSurvivors()
{
	int count = 0;
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && GetClientTeam(client) == TEAM_SURVIVOR
			&& IsPlayerAlive(client) && !GetEntProp(client, Prop_Send, "m_isIncapacitated"))
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
	else if (g_eActiveVote == AssistVote_Tier4)
	{
		FormatEx(voteState, sizeof(voteState), "第四阶进行中 %d/%d", g_iReceivedVotes, g_iExpectedVoters);
	}
	else if (g_eActiveVote == AssistVote_Tier5)
	{
		FormatEx(voteState, sizeof(voteState), "第五阶进行中 %d/%d", g_iReceivedVotes, g_iExpectedVoters);
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
	else if (g_bTier4VotePending && !g_bFlowFallbackActive)
	{
		strcopy(voteState, sizeof(voteState), "第四阶等待");
	}
	else if (g_bTier5VotePending && !g_bFlowFallbackActive)
	{
		strcopy(voteState, sizeof(voteState), "第五阶等待");
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
		strcopy(nextStep, sizeof(nextStep), "第一阶已开启；第二至五阶因导航备用模式暂停");
	}
	else if (!g_bTier2Enabled)
	{
		FormatEx(nextStep, sizeof(nextStep), "第二阶：进度 %d/%d（实际团灭 %d）", GetProgressWipes(), g_cvTier2Wipes.IntValue, g_iTotalWipes);
	}
	else if (!g_bTier3Enabled)
	{
		FormatEx(nextStep, sizeof(nextStep), "第三阶：进度 %d/%d（实际团灭 %d）", GetProgressWipes(), g_cvTier3Wipes.IntValue, g_iTotalWipes);
	}
	else if (!g_bTier4Enabled)
	{
		FormatEx(nextStep, sizeof(nextStep), "第四阶：进度 %d/%d（实际团灭 %d）", GetProgressWipes(), g_cvTier4Wipes.IntValue, g_iTotalWipes);
	}
	else if (!g_bTier5Enabled)
	{
		FormatEx(nextStep, sizeof(nextStep), "第五阶：进度 %d/%d（实际团灭 %d）", GetProgressWipes(), g_cvTier5Wipes.IntValue, g_iTotalWipes);
	}
	else
	{
		strcopy(nextStep, sizeof(nextStep), "第一、二、三、四、五阶均已开启");
	}

	char stageState[64];
	if (g_bTier5Enabled)
	{
		strcopy(stageState, sizeof(stageState), "第五阶（孤立生还者复活）");
	}
	else if (g_bTier4Enabled)
	{
		strcopy(stageState, sizeof(stageState), "第四阶（满血复活+医疗物资）");
	}
	else if (g_bTier3Enabled)
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
