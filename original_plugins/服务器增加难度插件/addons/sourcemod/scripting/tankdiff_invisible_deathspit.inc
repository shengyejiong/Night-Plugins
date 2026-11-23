// 隐形死酸位置修复：参考 Forgetest 的 Spit Spread Patch 1.21；摘取、限界与菜单整合：night。
// 只处理非吐酸弹生成、且来源为已死亡 Spitter 的酸液；不改伤害和正常扩散。
#define INVISIBLE_DEATHSPIT_GAMEDATA "l4d2_difficulty_invisible_deathspit"
#define INVISIBLE_DEATHSPIT_DETONATE "CSpitterProjectile::Detonate"
#define INVISIBLE_DEATHSPIT_TRACE_DEPTH 46.0

ConVar g_cvInvisibleDeathSpitFix;
DynamicDetour g_hDeathSpitDetonate;
ArrayList g_aPendingDeathSpitRefs;
bool g_bInvisibleDeathSpitAvailable;
bool g_bDeathSpitDetourEnabled;
int g_iDeathSpitProjectileDepth;

void InitializeInvisibleDeathSpitFix()
{
	g_cvInvisibleDeathSpitFix = CreateConVar("l4d2_difficulty_invisible_deathspit_fix", "1",
		"1=修正悬空的 Spitter 死酸，0=关闭；不改伤害和正常扩散", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_aPendingDeathSpitRefs = new ArrayList();
	g_cvInvisibleDeathSpitFix.AddChangeHook(OnInvisibleDeathSpitChanged);

	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "gamedata/%s.txt", INVISIBLE_DEATHSPIT_GAMEDATA);
	if (!FileExists(path))
	{
		LogError("缺少 %s.txt；仅停用隐形死酸修复。", INVISIBLE_DEATHSPIT_GAMEDATA);
		return;
	}

	GameData data = new GameData(INVISIBLE_DEATHSPIT_GAMEDATA);
	if (data == null)
	{
		LogError("无法读取 %s.txt；仅停用隐形死酸修复。", INVISIBLE_DEATHSPIT_GAMEDATA);
		return;
	}

	g_hDeathSpitDetonate = DynamicDetour.FromConf(data, INVISIBLE_DEATHSPIT_DETONATE);
	delete data;
	g_bInvisibleDeathSpitAvailable = g_hDeathSpitDetonate != null;
	if (!g_bInvisibleDeathSpitAvailable)
	{
		LogError("无法建立吐酸弹来源识别；仅停用隐形死酸修复。");
	}
}

bool IsInvisibleDeathSpitEnabled()
{
	return g_bInvisibleDeathSpitAvailable && g_bDeathSpitDetourEnabled && g_cvInvisibleDeathSpitFix.BoolValue;
}

void OnInvisibleDeathSpitChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	RefreshInvisibleDeathSpitFix();
}

void RefreshInvisibleDeathSpitFix()
{
	bool enable = g_bInvisibleDeathSpitAvailable && g_cvInvisibleDeathSpitFix.BoolValue;
	if (enable == g_bDeathSpitDetourEnabled)
	{
		return;
	}

	if (enable)
	{
		bool pre = g_hDeathSpitDetonate.Enable(Hook_Pre, DeathSpit_DetonatePre);
		bool post = pre && g_hDeathSpitDetonate.Enable(Hook_Post, DeathSpit_DetonatePost);
		if (!post)
		{
			if (pre)
			{
				g_hDeathSpitDetonate.Disable(Hook_Pre, DeathSpit_DetonatePre);
			}
			g_bInvisibleDeathSpitAvailable = false;
			LogError("吐酸弹来源识别启用失败；仅停用隐形死酸修复。");
			return;
		}
		g_bDeathSpitDetourEnabled = true;
	}
	else
	{
		g_hDeathSpitDetonate.Disable(Hook_Pre, DeathSpit_DetonatePre);
		g_hDeathSpitDetonate.Disable(Hook_Post, DeathSpit_DetonatePost);
		g_bDeathSpitDetourEnabled = false;
		ClearPendingInvisibleDeathSpit();
		g_iDeathSpitProjectileDepth = 0;
	}
}

MRESReturn DeathSpit_DetonatePre(int projectile)
{
	g_iDeathSpitProjectileDepth++;
	return MRES_Ignored;
}

MRESReturn DeathSpit_DetonatePost(int projectile)
{
	if (g_iDeathSpitProjectileDepth > 0)
	{
		g_iDeathSpitProjectileDepth--;
	}
	return MRES_Ignored;
}

void TrackInvisibleDeathSpit(int entity, const char[] classname)
{
	if (!IsInvisibleDeathSpitEnabled() || g_iDeathSpitProjectileDepth != 0 || !StrEqual(classname, "insect_swarm"))
	{
		return;
	}

	int ref = EntIndexToEntRef(entity);
	if (g_aPendingDeathSpitRefs.FindValue(ref) != -1)
	{
		return;
	}

	if (SDKHookEx(entity, SDKHook_SpawnPost, DeathSpit_OnSpawnPost))
	{
		g_aPendingDeathSpitRefs.Push(ref);
	}
}

void DeathSpit_OnSpawnPost(int entity)
{
	SDKUnhook(entity, SDKHook_SpawnPost, DeathSpit_OnSpawnPost);
	if (!IsInvisibleDeathSpitEnabled() || !SDKHookEx(entity, SDKHook_Think, DeathSpit_OnFirstThink))
	{
		ForgetInvisibleDeathSpitRef(EntIndexToEntRef(entity));
	}
}

Action DeathSpit_OnFirstThink(int entity)
{
	SDKUnhook(entity, SDKHook_Think, DeathSpit_OnFirstThink);
	int ref = EntIndexToEntRef(entity);
	if (!IsInvisibleDeathSpitEnabled() || g_aPendingDeathSpitRefs.FindValue(ref) == -1)
	{
		ForgetInvisibleDeathSpitRef(ref);
		return Plugin_Continue;
	}

	// 来源不明确则不动；正常吐酸弹即使原主人已死亡，也已在 Detonate 范围内被排除。
	int spitter = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	if (spitter <= 0 || spitter > MaxClients || !IsClientInGame(spitter) || IsPlayerAlive(spitter)
		|| GetClientTeam(spitter) != TEAM_INFECTED || GetEntProp(spitter, Prop_Send, "m_zombieClass") != 4)
	{
		ForgetInvisibleDeathSpitRef(ref);
		return Plugin_Continue;
	}

	if (CorrectFloatingDeathSpit(entity))
	{
		// 引擎初始化位置稳定后只复查一次；使用实体引用防止误操作复用的实体编号。
		CreateTimer(0.3, Timer_RecheckInvisibleDeathSpit, ref, TIMER_FLAG_NO_MAPCHANGE);
	}
	else
	{
		ForgetInvisibleDeathSpitRef(ref);
	}
	return Plugin_Continue;
}

Action Timer_RecheckInvisibleDeathSpit(Handle timer, any ref)
{
	if (IsInvisibleDeathSpitEnabled() && g_aPendingDeathSpitRefs.FindValue(ref) != -1)
	{
		int entity = EntRefToEntIndex(ref);
		if (entity != INVALID_ENT_REFERENCE && IsValidEntity(entity))
		{
			CorrectFloatingDeathSpit(entity);
		}
	}
	ForgetInvisibleDeathSpitRef(ref);
	return Plugin_Stop;
}

// true 表示已移动，需要延迟复查；找不到近距离落点时移除悬空死酸。
// 不修改 m_fireCount、池数、扩散上限、伤害或碰撞规则。
bool CorrectFloatingDeathSpit(int entity)
{
	float origin[3], end[3];
	GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", origin);
	if ((TR_GetPointContents(origin) & (CONTENTS_WATER | CONTENTS_SLIME | CONTENTS_SOLID)) != 0)
	{
		return false;
	}

	end = origin;
	end[2] -= INVISIBLE_DEATHSPIT_TRACE_DEPTH;
	Handle trace = TR_TraceRayFilterEx(origin, end, MASK_SHOT | MASK_WATER, RayType_EndPoint,
		TraceInvisibleDeathSpitFloor, entity);
	if (TR_StartSolid(trace) || TR_AllSolid(trace))
	{
		delete trace;
		return false;
	}

	if (!TR_DidHit(trace))
	{
		delete trace;
		RemoveEntity(entity);
		return false;
	}

	float normal[3], contentsPoint[3];
	TR_GetEndPosition(end, trace);
	TR_GetPlaneNormal(trace, normal);
	delete trace;

	contentsPoint = end;
	contentsPoint[2] -= 1.0;
	if (normal[2] < 0.5 || (TR_GetPointContents(contentsPoint) & (CONTENTS_WATER | CONTENTS_SLIME)) != 0)
	{
		return false;
	}

	if (origin[2] - end[2] <= 1.0)
	{
		return false;
	}

	TeleportEntity(entity, end, NULL_VECTOR, NULL_VECTOR);
	return true;
}

bool TraceInvisibleDeathSpitFloor(int entity, int contentsMask, any self)
{
	if (entity == self || (entity > 0 && entity <= MaxClients))
	{
		return false;
	}
	if (entity == 0)
	{
		return true;
	}

	char classname[64];
	GetEntityClassname(entity, classname, sizeof(classname));
	return !StrEqual(classname, "infected") && !StrEqual(classname, "witch")
		&& !StrEqual(classname, "insect_swarm") && !StrEqual(classname, "spitter_projectile")
		&& !StrEqual(classname, "tank_rock") && strncmp(classname, "weapon_", 7) != 0;
}

void ForgetInvisibleDeathSpitRef(int ref)
{
	if (g_aPendingDeathSpitRefs == null)
	{
		return;
	}
	int index = g_aPendingDeathSpitRefs.FindValue(ref);
	if (index != -1)
	{
		g_aPendingDeathSpitRefs.Erase(index);
	}
}

void InvisibleDeathSpitOnDestroyed(int entity)
{
	if (g_aPendingDeathSpitRefs == null || entity <= MaxClients)
	{
		return;
	}
	for (int i = g_aPendingDeathSpitRefs.Length - 1; i >= 0; i--)
	{
		int current = EntRefToEntIndex(g_aPendingDeathSpitRefs.Get(i));
		if (current == INVALID_ENT_REFERENCE || current == entity)
		{
			g_aPendingDeathSpitRefs.Erase(i);
		}
	}
}

void ClearPendingInvisibleDeathSpit()
{
	if (g_aPendingDeathSpitRefs == null)
	{
		return;
	}
	for (int i = 0; i < g_aPendingDeathSpitRefs.Length; i++)
	{
		int entity = EntRefToEntIndex(g_aPendingDeathSpitRefs.Get(i));
		if (entity != INVALID_ENT_REFERENCE && IsValidEntity(entity))
		{
			SDKUnhook(entity, SDKHook_SpawnPost, DeathSpit_OnSpawnPost);
			SDKUnhook(entity, SDKHook_Think, DeathSpit_OnFirstThink);
		}
	}
	g_aPendingDeathSpitRefs.Clear();
}

void ShutdownInvisibleDeathSpitFix()
{
	ClearPendingInvisibleDeathSpit();
	if (g_bDeathSpitDetourEnabled)
	{
		g_hDeathSpitDetonate.Disable(Hook_Pre, DeathSpit_DetonatePre);
		g_hDeathSpitDetonate.Disable(Hook_Post, DeathSpit_DetonatePost);
	}
	g_bDeathSpitDetourEnabled = false;
	g_bInvisibleDeathSpitAvailable = false;
	g_iDeathSpitProjectileDepth = 0;
	delete g_hDeathSpitDetonate;
	delete g_aPendingDeathSpitRefs;
}

