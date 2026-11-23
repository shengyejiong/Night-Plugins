// Ellis 被 Hunter 扑后的起身时长统一。参考 Sir（Rena 提供建议）的实现，整合：night。
// 原实现：SirPlease/L4D2-Competitive-Rework 的 l4d2_ellis_hunter_bandaid_fix。
#define ELLIS_HUNTER_GETUP_GENDER 10
#define ELLIS_HUNTER_GETUP_SEQUENCE 625
#define ELLIS_HUNTER_GETUP_RATE 1.234375 // Ellis 79 帧，其它角色 64 帧。
#define ELLIS_HUNTER_GETUP_WAIT 1.0
#define ELLIS_HUNTER_GETUP_LIMIT 5.0

enum struct EllisHunterGetupState
{
	bool hooked;
	float waitUntil;
	float stopAt;
	float originalRate;
}

ConVar g_cvEllisHunterGetupFix;
EllisHunterGetupState g_EllisHunterGetup[MAXPLAYERS + 1];

void InitializeEllisHunterGetupFix()
{
	g_cvEllisHunterGetupFix = CreateConVar("l4d2_difficulty_ellis_hunter_getup_fix", "1",
		"1=对齐 Ellis 被 Hunter 扑后的起身时长，0=关闭", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvEllisHunterGetupFix.AddChangeHook(OnEllisHunterGetupChanged);
	HookEvent("pounce_end", Event_EllisHunterPounceEnd, EventHookMode_Post);
}

void OnEllisHunterGetupChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (!convar.BoolValue)
	{
		ClearAllEllisHunterGetups();
	}
}

bool IsEllisSurvivor(int client)
{
	return client > 0 && client <= MaxClients && IsSurvivor(client)
		&& GetEntProp(client, Prop_Send, "m_Gender") == ELLIS_HUNTER_GETUP_GENDER;
}

bool CanTrackEllisHunterGetup(int client)
{
	return IsEllisSurvivor(client) && IsPlayerAlive(client) && !L4D_IsPlayerIncapacitated(client);
}

void Event_EllisHunterPounceEnd(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_cvEllisHunterGetupFix.BoolValue)
	{
		return;
	}

	int victim = GetClientOfUserId(event.GetInt("victim"));
	if (!CanTrackEllisHunterGetup(victim))
	{
		return;
	}

	ClearEllisHunterGetup(victim);
	if (SDKHookEx(victim, SDKHook_PostThinkPost, EllisHunterGetupPostThink))
	{
		float now = GetGameTime();
		g_EllisHunterGetup[victim].hooked = true;
		g_EllisHunterGetup[victim].waitUntil = now + ELLIS_HUNTER_GETUP_WAIT;
		g_EllisHunterGetup[victim].stopAt = now + ELLIS_HUNTER_GETUP_LIMIT;
	}
}

void EllisHunterGetupPostThink(int client)
{
	float now = GetGameTime();
	if (!g_cvEllisHunterGetupFix.BoolValue || !CanTrackEllisHunterGetup(client)
		|| now >= g_EllisHunterGetup[client].stopAt)
	{
		ClearEllisHunterGetup(client);
		return;
	}

	int sequence = GetEntProp(client, Prop_Send, "m_nSequence");
	if (sequence != ELLIS_HUNTER_GETUP_SEQUENCE)
	{
		if (g_EllisHunterGetup[client].originalRate > 0.0 || now >= g_EllisHunterGetup[client].waitUntil)
		{
			ClearEllisHunterGetup(client);
		}
		return;
	}

	float rate = GetEntPropFloat(client, Prop_Send, "m_flPlaybackRate");
	if (rate <= 0.0)
	{
		// 不用本选项解除引擎或其它插件的暂停状态。
		return;
	}
	if (g_EllisHunterGetup[client].originalRate <= 0.0)
	{
		g_EllisHunterGetup[client].originalRate = rate;
	}
	if (rate != ELLIS_HUNTER_GETUP_RATE)
	{
		SetEntPropFloat(client, Prop_Send, "m_flPlaybackRate", ELLIS_HUNTER_GETUP_RATE);
	}
}

void RestoreEllisHunterGetupRate(int client, float originalRate)
{
	// 只恢复仍处在该动画且仍为本修复速率的实体，避免影响下一段动画。
	if (originalRate > 0.0 && originalRate != ELLIS_HUNTER_GETUP_RATE && IsEllisSurvivor(client)
		&& GetEntProp(client, Prop_Send, "m_nSequence") == ELLIS_HUNTER_GETUP_SEQUENCE
		&& GetEntPropFloat(client, Prop_Send, "m_flPlaybackRate") == ELLIS_HUNTER_GETUP_RATE)
	{
		SetEntPropFloat(client, Prop_Send, "m_flPlaybackRate", originalRate);
	}
}

void ClearEllisHunterGetup(int client)
{
	if (client <= 0 || client > MaxClients || !g_EllisHunterGetup[client].hooked)
	{
		return;
	}

	g_EllisHunterGetup[client].hooked = false;
	if (IsClientInGame(client))
	{
		SDKUnhook(client, SDKHook_PostThinkPost, EllisHunterGetupPostThink);
		RestoreEllisHunterGetupRate(client, g_EllisHunterGetup[client].originalRate);
	}

	g_EllisHunterGetup[client].originalRate = 0.0;
	g_EllisHunterGetup[client].waitUntil = 0.0;
	g_EllisHunterGetup[client].stopAt = 0.0;
}

void ClearAllEllisHunterGetups()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		ClearEllisHunterGetup(client);
	}
}

void EllisHunterGetupOnReplace(int replacer, int replacee)
{
	float originalRate = 0.0;
	if (replacee > 0 && replacee <= MaxClients)
	{
		originalRate = g_EllisHunterGetup[replacee].originalRate;
	}

	ClearEllisHunterGetup(replacee);
	ClearEllisHunterGetup(replacer);
	// 若引擎把正在播放的动画拷给接管者，也只还原该动画的临时倍率。
	RestoreEllisHunterGetupRate(replacer, originalRate);
}

