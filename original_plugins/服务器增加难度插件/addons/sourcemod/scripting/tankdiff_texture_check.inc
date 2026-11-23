// 材质调试项检查：参考 Sir、Visor 的 Mathack Block；权限、会话校验和踢出提示：night。
#define TEXTURE_CHECK_CVAR "mat_texture_list"
#define TEXTURE_CHECK_QUERY_RETRY 10.0

ConVar g_cvTextureCheck;
Handle g_hTextureCheckTimer;
bool g_bTextureCheckMapReady;
QueryCookie g_iTextureCheckQueries[MAXPLAYERS + 1];
float g_fTextureCheckRetryAt[MAXPLAYERS + 1];

void InitializeTextureCheck()
{
	g_cvTextureCheck = CreateConVar("l4d2_difficulty_texture_check", "1",
		"1=踢出材质调试值异常或客户端拒绝读取的在队玩家，0=关闭",
		FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvTextureCheck.AddChangeHook(OnTextureCheckChanged);
}

bool CanToggleTextureCheck(int client)
{
	return CheckCommandAccess(client, "tankdiff_texture_check", ADMFLAG_CONVARS, true);
}

void ResetClientTextureQuery(int client)
{
	g_iTextureCheckQueries[client] = QUERYCOOKIE_FAILED;
	g_fTextureCheckRetryAt[client] = 0.0;
}

void OnTextureCheckChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	RefreshTextureCheck();
}

void RefreshTextureCheck()
{
	if (g_bTextureCheckMapReady && g_cvTextureCheck.BoolValue)
	{
		if (g_hTextureCheckTimer == null)
		{
			g_hTextureCheckTimer = CreateTimer(GetRandomFloat(2.5, 3.5), Timer_TextureCheck, _,
				TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	else
	{
		delete g_hTextureCheckTimer;
		for (int client = 1; client <= MaxClients; client++)
		{
			ResetClientTextureQuery(client);
		}
	}
}

void SetTextureCheckMapReady(bool ready)
{
	g_bTextureCheckMapReady = ready;
	RefreshTextureCheck();
}

bool IsTextureCheckClient(int client)
{
	if (client < 1 || client > MaxClients || !IsClientInGame(client)
		|| IsFakeClient(client) || IsClientInKickQueue(client))
	{
		return false;
	}
	int team = GetClientTeam(client);
	return team == TEAM_SURVIVOR || team == TEAM_INFECTED;
}

Action Timer_TextureCheck(Handle timer)
{
	if (timer != g_hTextureCheckTimer)
	{
		return Plugin_Stop;
	}
	if (!IsServerProcessing())
	{
		return Plugin_Continue;
	}

	float now = GetGameTime();
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsTextureCheckClient(client) || now < g_fTextureCheckRetryAt[client])
		{
			continue;
		}
		// 未收到有效回调时重试。服务器没发出查询不等于客户端拒绝读取。
		g_iTextureCheckQueries[client] = QueryClientConVar(client, TEXTURE_CHECK_CVAR,
			TextureCheckQueryFinished, GetClientUserId(client));
		g_fTextureCheckRetryAt[client] = g_iTextureCheckQueries[client] == QUERYCOOKIE_FAILED
			? 0.0 : now + TEXTURE_CHECK_QUERY_RETRY;
	}
	return Plugin_Continue;
}

void TextureCheckQueryFinished(QueryCookie cookie, int client, ConVarQueryResult result,
	const char[] cvarName, const char[] cvarValue, any userid)
{
	// 玩家离开、槽位被复用、切换开关或换图后，不接受旧回包。
	if (g_hTextureCheckTimer == null || client < 1 || client > MaxClients
		|| cookie == QUERYCOOKIE_FAILED || cookie != g_iTextureCheckQueries[client]
		|| GetClientOfUserId(userid) != client)
	{
		return;
	}
	ResetClientTextureQuery(client);
	if (!IsTextureCheckClient(client))
	{
		return;
	}

	switch (result)
	{
		case ConVarQuery_Okay:
		{
			int value = StringToInt(cvarValue);
			if (value > 0)
			{
				LogMessage("[材质检查] %L：%s=%d，已踢出。", client, TEXTURE_CHECK_CVAR, value);
				KickClient(client, "材质检查：%s 异常（读到 %d）。请关闭材质调试列表后重连。",
					TEXTURE_CHECK_CVAR, value);
			}
			return;
		}
		case ConVarQuery_NotFound:
		{
			KickUnreadableTextureCheck(client, "客户端未找到变量");
			return;
		}
		case ConVarQuery_NotValid:
		{
			KickUnreadableTextureCheck(client, "客户端返回变量无效");
			return;
		}
		case ConVarQuery_Protected:
		{
			KickUnreadableTextureCheck(client, "客户端变量受保护");
			return;
		}
	}
}

void KickUnreadableTextureCheck(int client, const char[] reason)
{
	LogMessage("[材质检查] %L：无法读取 %s（%s），已踢出。", client, TEXTURE_CHECK_CVAR, reason);
	KickClient(client, "材质检查：无法读取 %s（%s）。请检查客户端后重连。", TEXTURE_CHECK_CVAR, reason);
}
