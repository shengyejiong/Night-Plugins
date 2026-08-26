#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <l4d2_nativevote>

#define PLUGIN_VERSION "1.0.0"
#define SAMPLE_COUNT 5
#define TEAM_SURVIVOR 2
#define VOTE_RETRY_LIMIT 30

enum AssistVote
{
	AssistVote_None = 0,
	AssistVote_Tier1,
	AssistVote_Tier2
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
ConVar g_cvVoteTime;
ConVar g_cvReviveHealth;

Handle g_hFlowTimer;
Handle g_hRoundSetupTimer;

bool g_bRoundActive;
bool g_bMissionLostHandled;
bool g_bAttemptFlowValid;
bool g_bTier1Enabled;
bool g_bTier2Enabled;
bool g_bTier1VotePending;
bool g_bTier2VotePending;
bool g_bPillsPending;
bool g_bTier2TargetValid;
bool g_bTier2Triggered;
bool g_bMapFlowDisabled;
bool g_bVoteClientVoted[MAXPLAYERS + 1];

int g_iRoundSerial;
int g_iSetupRetries;
int g_iTotalWipes;
int g_iEarlyWipes;
int g_iWipeSampleCount;
int g_iWipeSampleNext;
int g_iExpectedVoters;
int g_iReceivedVotes;

float g_fAttemptMaxPercent;
float g_fWipeSamples[SAMPLE_COUNT];
float g_fTier2Target;
float g_fMapMaxFlowOverride;

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
		"3",
		"触发第一阶减难投票所需的早期团灭次数。",
		FCVAR_NOTIFY,
		true,
		1.0
	);
	g_cvTier2Wipes = CreateConVar(
		"l4d2_flow_difficulty_tier2_wipes",
		"7",
		"触发第二阶减难投票所需的总团灭次数。",
		FCVAR_NOTIFY,
		true,
		1.0
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

	CreateConVar(
		"l4d2_flow_difficulty_version",
		PLUGIN_VERSION,
		"根据路程动态减难插件版本。",
		FCVAR_NOTIFY | FCVAR_DONTRECORD
	);

	RegAdminCmd("sm_flowassist_status", Command_Status, ADMFLAG_GENERIC, "查看动态减难状态。");
	RegAdminCmd("sm_flowassist_reset", Command_Reset, ADMFLAG_ROOT, "清空当前章节的动态减难状态。");

	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("mission_lost", Event_MissionLost, EventHookMode_PostNoCopy);
	HookEvent("vote_passed", Event_VotePassed, EventHookMode_Post);

	AutoExecConfig(true, "l4d2_flow_difficulty");
}

public void OnMapStart()
{
	ResetChapterState();
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
}

public void OnConfigsExecuted()
{
	LoadMapFlowConfig();
}

void ResetChapterState()
{
	g_bRoundActive = false;
	g_bMissionLostHandled = false;
	g_bAttemptFlowValid = false;
	g_bTier1Enabled = false;
	g_bTier2Enabled = false;
	g_bTier1VotePending = false;
	g_bTier2VotePending = false;
	g_bPillsPending = false;
	g_bTier2TargetValid = false;
	g_bTier2Triggered = false;
	g_iTotalWipes = 0;
	g_iEarlyWipes = 0;
	g_iWipeSampleCount = 0;
	g_iWipeSampleNext = 0;
	g_iExpectedVoters = 0;
	g_iReceivedVotes = 0;
	g_fAttemptMaxPercent = 0.0;
	g_fTier2Target = 0.0;
	g_eActiveVote = AssistVote_None;

	for (int i = 0; i < SAMPLE_COUNT; i++)
	{
		g_fWipeSamples[i] = 0.0;
	}
	for (int client = 1; client <= MaxClients; client++)
	{
		g_bVoteClientVoted[client] = false;
	}

	delete g_hRoundSetupTimer;
	g_hRoundSetupTimer = null;
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
	g_fAttemptMaxPercent = 0.0;
	g_bTier2TargetValid = g_bTier2Enabled && CalculateWipeAverage(g_fTier2Target);

	delete g_hRoundSetupTimer;
	g_hRoundSetupTimer = CreateTimer(
		2.0,
		Timer_RoundSetup,
		g_iRoundSerial,
		TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE
	);
}

public void Event_MissionLost(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_cvEnable.BoolValue || g_bMissionLostHandled)
	{
		return;
	}

	g_bMissionLostHandled = true;
	g_bRoundActive = false;
	g_iTotalWipes++;

	if (g_bAttemptFlowValid)
	{
		PushWipeSample(g_fAttemptMaxPercent);

		if (g_fAttemptMaxPercent < g_cvEarlyPercent.FloatValue)
		{
			g_iEarlyWipes++;
		}
	}
	else
	{
		LogMessage("本次团灭没有取得有效路程，未计入早期团灭和最近五次路程。");
	}

	if (g_bTier1Enabled)
	{
		g_bPillsPending = true;
	}

	if (!g_bTier1Enabled && g_iEarlyWipes >= g_cvTier1Wipes.IntValue)
	{
		g_bTier1VotePending = true;
	}
	else if (g_bTier1Enabled && !g_bTier2Enabled && g_iTotalWipes >= g_cvTier2Wipes.IntValue)
	{
		g_bTier2VotePending = true;
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
		"\x04[动态减难]\x05 本章已团灭 \x03%d\x05 次，本次最远路程：\x03%s\x05。",
		g_iTotalWipes,
		percentText
	);
}

public void Event_VotePassed(Event event, const char[] name, bool dontBroadcast)
{
	char details[128];
	event.GetString("details", details, sizeof(details));

	if (StrEqual(details, "#L4D_vote_passed_restart_game", false))
	{
		ResetChapterState();
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

	if ((pillsHandled && voteHandled) || g_iSetupRetries >= VOTE_RETRY_LIMIT)
	{
		if (g_iSetupRetries >= VOTE_RETRY_LIMIT && (!pillsHandled || !voteHandled))
		{
			LogMessage("回合开始后等待真人、存活生还者或投票空档超时，未完成的效果保留到下一次重试。");
		}
		g_hRoundSetupTimer = null;
		return Plugin_Stop;
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
	if (!GetCurrentFlowPercent(percent))
	{
		return Plugin_Continue;
	}

	if (!g_bAttemptFlowValid || percent > g_fAttemptMaxPercent)
	{
		g_bAttemptFlowValid = true;
		g_fAttemptMaxPercent = percent;
	}

	if (g_bTier2Enabled && g_bTier2TargetValid && !g_bTier2Triggered && percent >= g_fTier2Target)
	{
		g_bTier2Triggered = true;
		int revived = ReviveDeadHumanSurvivors();

		if (revived > 0)
		{
			PrintToChatAll(
				"\x04[动态减难]\x05 已到达最近五次平均团灭路程 \x03%.1f%%\x05，复活了 \x03%d\x05 名死亡真人。",
				g_fTier2Target,
				revived
			);
		}
		else
		{
			LogMessage("到达第二阶复活路程 %.1f%%，本回合没有可复活的死亡真人。", g_fTier2Target);
		}
	}

	return Plugin_Continue;
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
	else if (g_bTier2VotePending && g_bTier1Enabled && !g_bTier2Enabled)
	{
		voteType = AssistVote_Tier2;
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
	else
	{
		vote.SetTitle("多次团灭，开启第二阶路程复活？");
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
	else
	{
		g_bTier2VotePending = false;
		PrintToChatAll("\x04[动态减难]\x05 第二阶投票开始；必须所有在线真人都投票，否则本次作废。");
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

bool CalculateWipeAverage(float &average)
{
	if (g_iWipeSampleCount < SAMPLE_COUNT || g_bMapFlowDisabled)
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

int ReviveDeadHumanSurvivors()
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
		SetEntityHealth(client, g_cvReviveHealth.IntValue);
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
	char target[32];
	if (g_bTier2TargetValid)
	{
		FormatEx(target, sizeof(target), "%.1f%%", g_fTier2Target);
	}
	else
	{
		strcopy(target, sizeof(target), "无");
	}

	ReplyToCommand(client, "[动态减难] 总团灭:%d 75%%前团灭:%d 有效样本:%d/5", g_iTotalWipes, g_iEarlyWipes, g_iWipeSampleCount);
	ReplyToCommand(client, "[动态减难] 第一阶:%s 第二阶:%s 本回合复活点:%s", g_bTier1Enabled ? "开" : "关", g_bTier2Enabled ? "开" : "关", target);
	ReplyToCommand(client, "[动态减难] 地图路程:%s 最大路程覆盖:%.1f", g_bMapFlowDisabled ? "禁用" : "启用", g_fMapMaxFlowOverride);
	return Plugin_Handled;
}

public Action Command_Reset(int client, int args)
{
	ResetChapterState();
	g_bRoundActive = true;
	g_iRoundSerial++;
	ReplyToCommand(client, "[动态减难] 已清空当前章节的所有计数和减难状态。");
	LogAction(client, -1, "\"%L\" 清空了当前章节的动态减难状态。", client);
	return Plugin_Handled;
}
