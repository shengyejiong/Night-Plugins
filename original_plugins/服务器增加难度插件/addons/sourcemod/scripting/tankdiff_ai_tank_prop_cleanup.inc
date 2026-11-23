// 仅抽取战后清理思路，参考 Harry Potter、Sir、A1m`、Derpduck 的 Tank Hittable Glow；实现：night。
#define AI_TANK_PROP_CLEANUP_DELAY 15.0

static const char g_sAiTankCleanupPropClasses[][] =
{
	"prop_physics",
	"prop_physics_override",
	"prop_physics_multiplayer",
	"prop_car_alarm"
};

ConVar g_cvAiTankPropCleanup;
ArrayList g_aAiTankPropHooks;
ArrayList g_aAiTankPropHits;
Handle g_hAiTankPropCleanupTimer;
bool g_bAiTankPropWatching;
int g_iAiTankPropSwingClaw[MAXPLAYERS + 1];

void InitializeAiTankPropCleanup()
{
	g_aAiTankPropHooks = new ArrayList();
	g_aAiTankPropHits = new ArrayList();
	g_cvAiTankPropCleanup = CreateConVar("l4d2_difficulty_ai_tank_prop_cleanup", "1",
		"1=最后一只 Tank 死后 15 秒清理 AI Tank 直接打过的可打物件，0=关闭",
		FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvAiTankPropCleanup.AddChangeHook(OnAiTankPropCleanupChanged);
	HookEvent("round_end", Event_AiTankPropCleanupRoundEnd, EventHookMode_PostNoCopy);
}

void OnAiTankPropCleanupChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (!convar.BoolValue)
	{
		ResetAiTankPropCleanup();
	}
}

void Event_AiTankPropCleanupRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	ResetAiTankPropCleanup();
}

void CancelAiTankPropCleanupTimer()
{
	delete g_hAiTankPropCleanupTimer;
}

void StopWatchingAiTankProps()
{
	if (!g_bAiTankPropWatching)
	{
		return;
	}
	g_bAiTankPropWatching = false;
	for (int i = 0; i < g_aAiTankPropHooks.Length; i++)
	{
		int entity = EntRefToEntIndex(g_aAiTankPropHooks.Get(i));
		if (entity != INVALID_ENT_REFERENCE && IsValidEntity(entity))
		{
			SDKUnhook(entity, SDKHook_OnTakeDamagePost, Hook_AiTankPropDamage);
		}
	}
	g_aAiTankPropHooks.Clear();
	for (int client = 1; client <= MaxClients; client++)
	{
		g_iAiTankPropSwingClaw[client] = 0;
	}
}

void ResetAiTankPropCleanup()
{
	CancelAiTankPropCleanupTimer();
	StopWatchingAiTankProps();
	if (g_aAiTankPropHits != null)
	{
		g_aAiTankPropHits.Clear();
	}
}

void ShutdownAiTankPropCleanup()
{
	ResetAiTankPropCleanup();
	delete g_aAiTankPropHooks;
	delete g_aAiTankPropHits;
}

bool IsAiTankCleanupHittable(int entity)
{
	return entity > MaxClients && IsValidEntity(entity)
		&& HasEntProp(entity, Prop_Send, "m_hasTankGlow")
		&& GetEntProp(entity, Prop_Send, "m_hasTankGlow") != 0;
}

void WatchAiTankProp(int entity)
{
	if (!IsAiTankCleanupHittable(entity))
	{
		return;
	}
	int ref = EntIndexToEntRef(entity);
	if (g_aAiTankPropHooks.FindValue(ref) == -1
		&& SDKHookEx(entity, SDKHook_OnTakeDamagePost, Hook_AiTankPropDamage))
	{
		g_aAiTankPropHooks.Push(ref);
	}
}

void StartWatchingAiTankProps()
{
	if (g_bAiTankPropWatching)
	{
		return;
	}
	g_bAiTankPropWatching = true;
	// 等第一次 AI 挥拳再登记，只查可打物件所在的物理实体类。
	for (int i = 0; i < sizeof(g_sAiTankCleanupPropClasses); i++)
	{
		int entity = -1;
		while ((entity = FindEntityByClassname(entity, g_sAiTankCleanupPropClasses[i])) != -1)
		{
			WatchAiTankProp(entity);
		}
	}
}

void TrackAiTankCleanupPropCreated(int entity, const char[] classname)
{
	if (!g_bAiTankPropWatching || entity <= MaxClients)
	{
		return;
	}
	for (int i = 0; i < sizeof(g_sAiTankCleanupPropClasses); i++)
	{
		if (StrEqual(classname, g_sAiTankCleanupPropClasses[i]))
		{
			SDKHook(entity, SDKHook_SpawnPost, Hook_AiTankCleanupPropSpawned);
			return;
		}
	}
}

void Hook_AiTankCleanupPropSpawned(int entity)
{
	SDKUnhook(entity, SDKHook_SpawnPost, Hook_AiTankCleanupPropSpawned);
	if (g_bAiTankPropWatching)
	{
		WatchAiTankProp(entity);
	}
}

public void L4D_TankClaw_DoSwing_Pre(int tank, int claw)
{
	if (!g_cvAiTankPropCleanup.BoolValue || claw <= MaxClients || !IsAiTank(tank))
	{
		return;
	}
	CancelAiTankPropCleanupTimer();
	StartWatchingAiTankProps();
	g_iAiTankPropSwingClaw[tank] = claw;
}

public void L4D_TankClaw_DoSwing_Post(int tank, int claw)
{
	if (tank > 0 && tank <= MaxClients)
	{
		g_iAiTankPropSwingClaw[tank] = 0;
	}
}

void Hook_AiTankPropDamage(int victim, int attacker, int inflictor, float damage, int damageType)
{
	if (!g_bAiTankPropWatching || attacker <= 0 || attacker > MaxClients)
	{
		return;
	}
	int claw = g_iAiTankPropSwingClaw[attacker];
	// 只认本次 AI 拳击直接命中：石头、连锁碰撞或之前被 Tank 打飞的物件不算。
	if (claw == 0 || (inflictor != attacker && inflictor != claw) || !IsAiTankCleanupHittable(victim))
	{
		return;
	}
	int ref = EntIndexToEntRef(victim);
	if (g_aAiTankPropHits.FindValue(ref) == -1)
	{
		g_aAiTankPropHits.Push(ref);
	}
}

bool HasLivingTankForPropCleanup(int excluded = 0)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (client != excluded && IsTank(client))
		{
			return true;
		}
	}
	return false;
}

void AiTankPropCleanupOnTankDeath(int tank)
{
	if (!g_cvAiTankPropCleanup.BoolValue || HasLivingTankForPropCleanup(tank))
	{
		return;
	}
	StopWatchingAiTankProps();
	CancelAiTankPropCleanupTimer();
	if (g_aAiTankPropHits.Length > 0)
	{
		g_hAiTankPropCleanupTimer = CreateTimer(AI_TANK_PROP_CLEANUP_DELAY, Timer_AiTankPropCleanup, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

Action Timer_AiTankPropCleanup(Handle timer)
{
	if (timer != g_hAiTankPropCleanupTimer)
	{
		return Plugin_Stop;
	}
	g_hAiTankPropCleanupTimer = null;
	if (!g_cvAiTankPropCleanup.BoolValue || HasLivingTankForPropCleanup())
	{
		return Plugin_Stop;
	}
	while (g_aAiTankPropHits.Length > 0)
	{
		int last = g_aAiTankPropHits.Length - 1;
		int entity = EntRefToEntIndex(g_aAiTankPropHits.Get(last));
		g_aAiTankPropHits.Erase(last);
		if (entity != INVALID_ENT_REFERENCE && IsAiTankCleanupHittable(entity))
		{
			RemoveEntity(entity);
		}
	}
	return Plugin_Stop;
}
