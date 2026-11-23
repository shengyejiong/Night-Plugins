// 骑乘命中框修复，参考 Forgetest 的 Fix Jockey Hitbox 2.2；整合及状态清理：night。
// https://github.com/Target5150/MoYu_Server_Stupid_Plugins
#define JOCKEY_RIDE_IK_OFFSET_FROM_MODEL_SCALE 24
#define JOCKEY_RIDE_HUMAN_HEIGHT 71.0

enum struct JockeyRideHitboxState
{
	bool hooked;
	bool clearedDucking;
	int jockeyUserId;
	float originalOffset;
	float adjustedOffset;
}

ConVar g_cvJockeyRideHitboxFix;
int g_iJockeyRideIkOffset = -1;
JockeyRideHitboxState g_JockeyRideHitbox[MAXPLAYERS + 1];
int g_iJockeyRideVictim[MAXPLAYERS + 1];

void InitializeJockeyRideHitboxFix()
{
	g_cvJockeyRideHitboxFix = CreateConVar("l4d2_difficulty_jockey_ride_hitbox_fix", "1",
		"1=修复 Jockey 骑人时的命中框，0=关闭", FCVAR_NOTIFY, true, 0.0, true, 1.0);

	int modelScaleOffset = FindSendPropInfo("CBaseAnimating", "m_flModelScale");
	if (modelScaleOffset <= 0)
	{
		LogError("找不到 CBaseAnimating::m_flModelScale；Jockey 骑人命中框修复已停用。");
		return;
	}

	g_iJockeyRideIkOffset = modelScaleOffset + JOCKEY_RIDE_IK_OFFSET_FROM_MODEL_SCALE;
	g_cvJockeyRideHitboxFix.AddChangeHook(OnJockeyRideHitboxChanged);
}

bool IsJockeyRideHitboxEnabled()
{
	return g_iJockeyRideIkOffset > 0 && g_cvJockeyRideHitboxFix.BoolValue;
}

void OnJockeyRideHitboxChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (IsJockeyRideHitboxEnabled())
	{
		RefreshJockeyRideHitboxes();
	}
	else
	{
		StopAllJockeyRideHitboxes();
	}
}

bool IsRideHitboxJockey(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && IsPlayerAlive(client)
		&& GetClientTeam(client) == TEAM_INFECTED && GetEntProp(client, Prop_Send, "m_zombieClass") == Z_JOCKEY;
}

int GetRideHitboxJockey(int victim)
{
	if (!IsSurvivor(victim) || !IsPlayerAlive(victim))
	{
		return 0;
	}

	int jockey = GetEntPropEnt(victim, Prop_Send, "m_jockeyAttacker");
	return IsRideHitboxJockey(jockey) ? jockey : 0;
}

float GetJockeyRideAdjustedOffset(int victim)
{
	static const float scale[] = {1.0, 0.888, 1.05, 0.955, 1.0, 0.888, 1.0, 1.0};
	int character = GetEntProp(victim, Prop_Send, "m_survivorCharacter");
	if (character >= 0 && character <= 3 && L4D2_GetSurvivorSetMod() == 1)
	{
		character += 4;
	}
	return (character >= 0 && character < sizeof(scale)) ? JOCKEY_RIDE_HUMAN_HEIGHT * (scale[character] - 1.0) : 0.0;
}

void RestoreJockeyRideOffset(int victim)
{
	int jockey = GetClientOfUserId(g_JockeyRideHitbox[victim].jockeyUserId);
	g_JockeyRideHitbox[victim].jockeyUserId = 0;
	if (jockey <= 0 || g_iJockeyRideVictim[jockey] != victim)
	{
		return;
	}

	g_iJockeyRideVictim[jockey] = 0;
	if (IsClientInGame(jockey) && GetEntDataFloat(jockey, g_iJockeyRideIkOffset) == g_JockeyRideHitbox[victim].adjustedOffset
		&& g_JockeyRideHitbox[victim].originalOffset != g_JockeyRideHitbox[victim].adjustedOffset)
	{
		SetEntDataFloat(jockey, g_iJockeyRideIkOffset, g_JockeyRideHitbox[victim].originalOffset);
	}
}

void StopJockeyRideHitbox(int victim)
{
	if (victim <= 0 || victim > MaxClients || !g_JockeyRideHitbox[victim].hooked)
	{
		return;
	}

	g_JockeyRideHitbox[victim].hooked = false;
	RestoreJockeyRideOffset(victim);

	if (IsClientInGame(victim))
	{
		SDKUnhook(victim, SDKHook_PostThink, OnJockeyRideHitboxPostThink);
		// 只恢复本修复清掉的蹲姿标记，并以游戏此刻的实际蹲姿为准。
		if (g_JockeyRideHitbox[victim].clearedDucking && IsSurvivor(victim) && IsPlayerAlive(victim)
			&& GetEntProp(victim, Prop_Send, "m_bDucked") != 0)
		{
			int flags = GetEntityFlags(victim);
			if ((flags & FL_DUCKING) == 0)
			{
				SetEntityFlags(victim, flags | FL_DUCKING);
			}
		}
	}

	g_JockeyRideHitbox[victim].clearedDucking = false;
}

void StopAllJockeyRideHitboxes()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		StopJockeyRideHitbox(client);
	}
	for (int client = 1; client <= MaxClients; client++)
	{
		g_iJockeyRideVictim[client] = 0;
	}
}

void ClearJockeyRideHitboxForClient(int client)
{
	if (client <= 0 || client > MaxClients)
	{
		return;
	}

	StopJockeyRideHitbox(client);
	StopJockeyRideHitbox(g_iJockeyRideVictim[client]);
	g_iJockeyRideVictim[client] = 0;
}

void ApplyJockeyRideHitbox(int victim, int jockey)
{
	int userId = GetClientUserId(jockey);
	if (g_JockeyRideHitbox[victim].jockeyUserId != userId)
	{
		RestoreJockeyRideOffset(victim);
		int oldVictim = g_iJockeyRideVictim[jockey];
		if (oldVictim > 0 && oldVictim != victim)
		{
			StopJockeyRideHitbox(oldVictim);
		}
		g_iJockeyRideVictim[jockey] = victim;
		g_JockeyRideHitbox[victim].jockeyUserId = userId;
		g_JockeyRideHitbox[victim].originalOffset = GetEntDataFloat(jockey, g_iJockeyRideIkOffset);
		g_JockeyRideHitbox[victim].adjustedOffset = GetJockeyRideAdjustedOffset(victim);
	}

	int flags = GetEntityFlags(victim);
	if ((flags & FL_DUCKING) != 0)
	{
		g_JockeyRideHitbox[victim].clearedDucking = true;
		SetEntityFlags(victim, flags & ~FL_DUCKING);
	}

	float adjusted = g_JockeyRideHitbox[victim].adjustedOffset;
	if (GetEntDataFloat(jockey, g_iJockeyRideIkOffset) != adjusted)
	{
		SetEntDataFloat(jockey, g_iJockeyRideIkOffset, adjusted);
	}
}

void StartJockeyRideHitbox(int victim)
{
	if (!IsJockeyRideHitboxEnabled())
	{
		return;
	}

	int jockey = GetRideHitboxJockey(victim);
	if (jockey == 0)
	{
		return;
	}

	if (!g_JockeyRideHitbox[victim].hooked)
	{
		if (!SDKHookEx(victim, SDKHook_PostThink, OnJockeyRideHitboxPostThink))
		{
			return;
		}
		g_JockeyRideHitbox[victim].hooked = true;
	}

	ApplyJockeyRideHitbox(victim, jockey);
}

void OnJockeyRideHitboxPostThink(int victim)
{
	int jockey = IsJockeyRideHitboxEnabled() ? GetRideHitboxJockey(victim) : 0;
	if (jockey == 0)
	{
		StopJockeyRideHitbox(victim);
		return;
	}

	ApplyJockeyRideHitbox(victim, jockey);
}

void RefreshJockeyRideHitboxes()
{
	if (IsJockeyRideHitboxEnabled())
	{
		for (int client = 1; client <= MaxClients; client++)
		{
			StartJockeyRideHitbox(client);
		}
	}
}

void JockeyRideHitboxOnRideStart(int victim)
{
	StartJockeyRideHitbox(victim);
	if (IsJockeyRideHitboxEnabled() && IsSurvivor(victim) && !g_JockeyRideHitbox[victim].hooked)
	{
		RequestFrame(Frame_RefreshJockeyRideHitbox, GetClientUserId(victim));
	}
}

void JockeyRideHitboxOnRideEnd(int victim, int jockeyUserId)
{
	int jockey = GetClientOfUserId(jockeyUserId);
	if (victim <= 0 && jockey > 0)
	{
		victim = g_iJockeyRideVictim[jockey];
	}
	if (victim > 0 && g_JockeyRideHitbox[victim].jockeyUserId == jockeyUserId)
	{
		StopJockeyRideHitbox(victim);
	}
}

void JockeyRideHitboxOnReplace(int replacer, int replacee)
{
	if (!IsJockeyRideHitboxEnabled())
	{
		return;
	}

	ClearJockeyRideHitboxForClient(replacee);
	if (replacer > 0 && IsClientInGame(replacer))
	{
		// 等引擎把骑乘关系转交给接管者再读取。
		RequestFrame(Frame_RefreshJockeyRideHitbox, GetClientUserId(replacer));
	}
}

void Frame_RefreshJockeyRideHitbox(any userId)
{
	if (!IsJockeyRideHitboxEnabled())
	{
		return;
	}

	int client = GetClientOfUserId(userId);
	int victim = IsRideHitboxJockey(client) ? GetEntPropEnt(client, Prop_Send, "m_jockeyVictim") : client;
	StartJockeyRideHitbox(victim);
}

