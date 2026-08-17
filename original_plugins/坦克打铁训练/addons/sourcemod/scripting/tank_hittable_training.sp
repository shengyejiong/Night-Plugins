#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>

#define PLUGIN_VERSION "1.1.0"

enum struct HittableSnapshot
{
	int entRef;
	char model[PLATFORM_MAX_PATH];
	float origin[3];
	float angles[3];
	int skin;
	float modelScale;
}

public Plugin myinfo =
{
	name = "Tank Hittable Training",
	author = "night",
	description = "Tank 打铁训练：重置物件、控制 Bot 与训练辅助",
	version = PLUGIN_VERSION,
	url = ""
};

ArrayList g_Hittables;
ArrayList g_GlowRefs;
StringMap g_GlowByTarget;

ConVar g_cvEnable;
ConVar g_cvDisplayOnSpawn;

ConVar g_cvSurvivorBotStop;
ConVar g_cvFrustrationSpawnDelay;
ConVar g_cvFrustrationLosDelay;

bool g_bSnapshotsReady;
bool g_bSurvivorBotsFrozen;
bool g_bSurvivorsInvulnerable;
bool g_bFrustrationDisabled;
bool g_bNoclip[MAXPLAYERS + 1];
MoveType g_eOriginalMoveType[MAXPLAYERS + 1];

char g_sOriginalSurvivorBotStop[32];
char g_sOriginalFrustrationSpawnDelay[32];
char g_sOriginalFrustrationLosDelay[32];

public void OnPluginStart()
{
	g_Hittables = new ArrayList(sizeof(HittableSnapshot));
	g_GlowRefs = new ArrayList();
	g_GlowByTarget = new StringMap();

	// 默认关闭：正常比赛不会弹出菜单，也不会修改任何游戏行为。
	g_cvEnable = CreateConVar("tank_hittable_training_enable", "0", "0=关闭训练插件，1=启用训练插件。", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvDisplayOnSpawn = CreateConVar("tank_hittable_training_display_on_spawn", "1", "1=训练开启时，Tank 出生后自动打开训练菜单。", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvEnable.AddChangeHook(CvarChanged_Enable);

	RegConsoleCmd("sm_hittable", Command_OpenTrainingMenu, "打开 Tank 打铁训练菜单。");
	RegConsoleCmd("sm_tk", Command_OpenTrainingMenu, "打开 Tank 打铁训练菜单。");
	RegAdminCmd("sm_tanktraining", Command_ToggleTraining, ADMFLAG_CONFIG, "sm_tanktraining [0/1]：开关 Tank 打铁训练。");

	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("map_transition", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("tank_spawn", Event_TankSpawn, EventHookMode_Post);

	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
		{
			SDKHook(client, SDKHook_OnTakeDamage, Hook_SurvivorTakeDamage);
		}
	}

	AutoExecConfig(true, "tank_hittable_training");
}

public void OnConfigsExecuted()
{
	g_cvSurvivorBotStop = FindConVar("sb_stop");
	g_cvFrustrationSpawnDelay = FindConVar("z_frustration_spawn_delay");
	g_cvFrustrationLosDelay = FindConVar("z_frustration_los_delay");
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, Hook_SurvivorTakeDamage);
}

public void OnClientDisconnect(int client)
{
	g_bNoclip[client] = false;
}

public void OnMapStart()
{
	RemoveAllHittableGlows();
	ClearSnapshots();
	RestoreTrainingState();
}

public void OnPluginEnd()
{
	RemoveAllHittableGlows();
	RestoreTrainingState();
}

public void CvarChanged_Enable(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (!convar.BoolValue)
	{
		RemoveAllHittableGlows();
		RestoreTrainingState();
		ClearSnapshots();
		return;
	}

	ClearSnapshots();
	CreateTimer(1.0, Timer_CaptureInitialHittables, _, TIMER_FLAG_NO_MAPCHANGE);
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	RemoveAllHittableGlows();
	ClearSnapshots();
	RestoreTrainingState();

	if (g_cvEnable.BoolValue)
	{
		CreateTimer(2.0, Timer_CaptureInitialHittables, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	RestoreTrainingState();
}

public void Event_TankSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_cvEnable.BoolValue)
	{
		return;
	}

	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!IsTankPlayer(client))
	{
		return;
	}

	if (!g_bSnapshotsReady)
	{
		CaptureInitialHittables();
	}

	if (g_cvDisplayOnSpawn.BoolValue)
	{
		CreateTimer(0.4, Timer_ShowTrainingMenu, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action Timer_CaptureInitialHittables(Handle timer)
{
	if (g_cvEnable.BoolValue)
	{
		CaptureInitialHittables();
	}
	return Plugin_Stop;
}

public Action Timer_ShowTrainingMenu(Handle timer, int userId)
{
	int client = GetClientOfUserId(userId);
	if (g_cvEnable.BoolValue && IsTankPlayer(client))
	{
		ShowTrainingMenu(client);
	}
	return Plugin_Stop;
}

public Action Command_ToggleTraining(int client, int args)
{
	bool enable = !g_cvEnable.BoolValue;
	if (args > 0)
	{
		char value[8];
		GetCmdArg(1, value, sizeof(value));
		enable = StringToInt(value) != 0;
	}

	g_cvEnable.BoolValue = enable;
	ReplyToCommand(client, "[Tank训练] 训练模式已%s。", enable ? "开启" : "关闭");
	return Plugin_Handled;
}

public Action Command_OpenTrainingMenu(int client, int args)
{
	if (!g_cvEnable.BoolValue)
	{
		ReplyToCommand(client, "[Tank训练] 当前关闭。管理员可用 !tanktraining 1 开启；正常比赛请保持关闭。");
		return Plugin_Handled;
	}

	if (!IsTankPlayer(client))
	{
		ReplyToCommand(client, "[Tank训练] 只有存活的 Tank 玩家可以使用此菜单。");
		return Plugin_Handled;
	}

	if (!g_bSnapshotsReady)
	{
		CaptureInitialHittables();
	}

	ShowTrainingMenu(client);
	return Plugin_Handled;
}

void ShowTrainingMenu(int client)
{
	Menu menu = new Menu(MenuHandler_Training);
	menu.SetTitle("Tank 打铁训练");

	char resetLabel[96];
	FormatEx(resetLabel, sizeof(resetLabel), "重置全部可打物件（基准 %d 个）", g_Hittables.Length);
	menu.AddItem("reset_hittables", resetLabel);
	menu.AddItem("toggle_survivor_bots", g_bSurvivorBotsFrozen ? "生还者 Bot：恢复行动" : "生还者 Bot：原地待命");
	menu.AddItem("toggle_invulnerability", g_bSurvivorsInvulnerable ? "生还者：关闭训练免伤" : "生还者：开启训练免伤");
	menu.AddItem("heal_survivor_bots", "AI 生还者：复活并回满血");
	menu.AddItem("teleport_survivors", "传送所有生还者到我的准星位置");
	menu.AddItem("toggle_noclip", g_bNoclip[client] ? "Tank：关闭穿墙模式" : "Tank：开启穿墙模式");
	menu.AddItem("toggle_frustration", g_bFrustrationDisabled ? "Tank：恢复正常失控规则" : "Tank：训练期间不失控");

	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Training(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
	{
		delete menu;
		return 0;
	}

	if (action != MenuAction_Select)
	{
		return 0;
	}

	if (!g_cvEnable.BoolValue || !IsTankPlayer(client))
	{
		PrintToChat(client, "[Tank训练] 训练已关闭，或你不再是存活的 Tank。菜单已关闭。");
		return 0;
	}

	char info[32];
	menu.GetItem(item, info, sizeof(info));

	if (StrEqual(info, "reset_hittables"))
	{
		ResetHittables(client);
	}
	else if (StrEqual(info, "toggle_survivor_bots"))
	{
		ToggleSurvivorBots(client);
	}
	else if (StrEqual(info, "toggle_invulnerability"))
	{
		g_bSurvivorsInvulnerable = !g_bSurvivorsInvulnerable;
		PrintToChat(client, "[Tank训练] 生还者训练免伤已%s。", g_bSurvivorsInvulnerable ? "开启" : "关闭");
	}
	else if (StrEqual(info, "heal_survivor_bots"))
	{
		HealSurvivorBots(client);
	}
	else if (StrEqual(info, "teleport_survivors"))
	{
		TeleportSurvivorsToCrosshair(client);
	}
	else if (StrEqual(info, "toggle_noclip"))
	{
		ToggleNoclip(client);
	}
	else if (StrEqual(info, "toggle_frustration"))
	{
		ToggleTankFrustration(client);
	}

	if (g_cvEnable.BoolValue && IsTankPlayer(client))
	{
		ShowTrainingMenu(client);
	}
	return 0;
}

void CaptureInitialHittables()
{
	ClearSnapshots();

	int entity = INVALID_ENT_REFERENCE;
	while ((entity = FindEntityByClassname(entity, "prop_physics*")) != INVALID_ENT_REFERENCE)
	{
		TryStoreHittable(entity);
	}

	entity = INVALID_ENT_REFERENCE;
	while ((entity = FindEntityByClassname(entity, "prop_car_alarm")) != INVALID_ENT_REFERENCE)
	{
		TryStoreHittable(entity);
	}

	g_bSnapshotsReady = true;
}

void TryStoreHittable(int entity)
{
	if (!IsTrainableHittable(entity))
	{
		return;
	}

	HittableSnapshot snapshot;
	snapshot.entRef = EntIndexToEntRef(entity);
	GetEntPropString(entity, Prop_Data, "m_ModelName", snapshot.model, sizeof(snapshot.model));
	if (snapshot.model[0] == '\0')
	{
		return;
	}

	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", snapshot.origin);
	GetEntPropVector(entity, Prop_Data, "m_angRotation", snapshot.angles);

	if (HasEntProp(entity, Prop_Send, "m_nSkin"))
	{
		snapshot.skin = GetEntProp(entity, Prop_Send, "m_nSkin");
	}

	snapshot.modelScale = 1.0;
	if (HasEntProp(entity, Prop_Send, "m_flModelScale"))
	{
		snapshot.modelScale = GetEntPropFloat(entity, Prop_Send, "m_flModelScale");
	}

	g_Hittables.PushArray(snapshot);
	SDKHook(entity, SDKHook_OnTakeDamagePost, Hook_HittableDamaged);
}

bool IsTrainableHittable(int entity)
{
	if (entity == INVALID_ENT_REFERENCE || !IsValidEntity(entity))
	{
		return false;
	}

	char classname[32];
	GetEntityClassname(entity, classname, sizeof(classname));
	if (StrEqual(classname, "prop_car_alarm"))
	{
		return true;
	}

	return HasEntProp(entity, Prop_Send, "m_hasTankGlow") && GetEntProp(entity, Prop_Send, "m_hasTankGlow") != 0;
}

void ResetHittables(int client)
{
	if (!g_bSnapshotsReady)
	{
		CaptureInitialHittables();
	}

	int resetCount;
	int failedCount;
	HittableSnapshot snapshot;
	RemoveAllHittableGlows();

	for (int i = 0; i < g_Hittables.Length; i++)
	{
		g_Hittables.GetArray(i, snapshot);
		int current = EntRefToEntIndex(snapshot.entRef);
		if (current != INVALID_ENT_REFERENCE && IsValidEntity(current))
		{
			RemoveEntity(current);
		}

		int replacement = CreateTrainingHittable(snapshot);
		if (replacement == INVALID_ENT_REFERENCE)
		{
			failedCount++;
			continue;
		}

		snapshot.entRef = EntIndexToEntRef(replacement);
		g_Hittables.SetArray(i, snapshot);
		resetCount++;
	}

	PrintToChat(client, "[Tank训练] 已按回合初始基准重新生成 %d 个可打物件。", resetCount);
	if (failedCount > 0)
	{
		PrintToChat(client, "[Tank训练] 有 %d 个物件模型重建失败；请告诉我地图名和物件类型。", failedCount);
	}
}

int CreateTrainingHittable(HittableSnapshot snapshot)
{
	// 统一重建为可被 Tank 挥打的物理实体，避免叉车/箱子保留旧的物理速度或碰撞状态。
	int entity = CreateEntityByName("prop_physics_override");
	if (entity == INVALID_ENT_REFERENCE)
	{
		return INVALID_ENT_REFERENCE;
	}

	// 部分车辆模型会忽略 model 键值；必须在 Spawn 前直接设置模型，才能保留原本的车型。
	SetEntityModel(entity, snapshot.model);
	DispatchKeyValue(entity, "model", snapshot.model);
	DispatchKeyValue(entity, "solid", "6");
	DispatchSpawn(entity);
	SetEntityModel(entity, snapshot.model);
	TeleportEntity(entity, snapshot.origin, snapshot.angles, NULL_VECTOR);

	if (HasEntProp(entity, Prop_Send, "m_hasTankGlow"))
	{
		SetEntProp(entity, Prop_Send, "m_hasTankGlow", 1);
	}
	if (HasEntProp(entity, Prop_Send, "m_nSkin"))
	{
		SetEntProp(entity, Prop_Send, "m_nSkin", snapshot.skin);
	}
	if (snapshot.modelScale != 1.0 && HasEntProp(entity, Prop_Send, "m_flModelScale"))
	{
		SetEntPropFloat(entity, Prop_Send, "m_flModelScale", snapshot.modelScale);
	}

	AcceptEntityInput(entity, "EnableMotion");
	AcceptEntityInput(entity, "Wake");
	SDKHook(entity, SDKHook_OnTakeDamagePost, Hook_HittableDamaged);
	return entity;
}

void Hook_HittableDamaged(int victim, int attacker, int inflictor, float damage, int damageType)
{
	if (!g_cvEnable.BoolValue || !IsTankPlayer(attacker) || !IsValidEntity(victim))
	{
		return;
	}

	CreateHittableGlow(victim);
}

void CreateHittableGlow(int target)
{
	char key[16];
	IntToString(EntIndexToEntRef(target), key, sizeof(key));

	int existingRef;
	if (g_GlowByTarget.GetValue(key, existingRef) && EntRefToEntIndex(existingRef) != INVALID_ENT_REFERENCE)
	{
		return;
	}

	char model[PLATFORM_MAX_PATH];
	GetEntPropString(target, Prop_Data, "m_ModelName", model, sizeof(model));
	if (model[0] == '\0')
	{
		return;
	}

	int glow = CreateEntityByName("prop_dynamic_override");
	if (glow == INVALID_ENT_REFERENCE)
	{
		return;
	}

	SetEntityModel(glow, model);
	DispatchSpawn(glow);
	SetEntityModel(glow, model);

	if (HasEntProp(glow, Prop_Send, "m_CollisionGroup"))
	{
		SetEntProp(glow, Prop_Send, "m_CollisionGroup", 0);
	}
	if (HasEntProp(glow, Prop_Send, "m_nSolidType"))
	{
		SetEntProp(glow, Prop_Send, "m_nSolidType", 0);
	}
	if (HasEntProp(glow, Prop_Send, "m_nGlowRange"))
	{
		SetEntProp(glow, Prop_Send, "m_nGlowRange", 0); // 0 = 不限距离
	}
	if (HasEntProp(glow, Prop_Send, "m_nGlowRangeMin"))
	{
		SetEntProp(glow, Prop_Send, "m_nGlowRangeMin", 0);
	}
	if (HasEntProp(glow, Prop_Send, "m_iGlowType"))
	{
		SetEntProp(glow, Prop_Send, "m_iGlowType", 3); // 常亮
	}
	if (HasEntProp(glow, Prop_Send, "m_glowColorOverride"))
	{
		SetEntProp(glow, Prop_Send, "m_glowColorOverride", 0xFFFFFF);
	}

	AcceptEntityInput(glow, "StartGlowing");
	SetEntityRenderMode(glow, RENDER_NONE);
	SetEntityRenderColor(glow, 0, 0, 0, 0);

	SetVariantString("!activator");
	AcceptEntityInput(glow, "SetParent", target);
	SDKHook(glow, SDKHook_SetTransmit, Hook_GlowTransmit);

	int glowRef = EntIndexToEntRef(glow);
	g_GlowByTarget.SetValue(key, glowRef);
	g_GlowRefs.Push(glowRef);
}

public Action Hook_GlowTransmit(int entity, int client)
{
	return GetClientTeam(client) == 3 ? Plugin_Continue : Plugin_Handled;
}

void RemoveAllHittableGlows()
{
	for (int i = 0; i < g_GlowRefs.Length; i++)
	{
		int entity = EntRefToEntIndex(g_GlowRefs.Get(i));
		if (entity != INVALID_ENT_REFERENCE && IsValidEntity(entity))
		{
			RemoveEntity(entity);
		}
	}

	g_GlowRefs.Clear();
	g_GlowByTarget.Clear();
}

void ToggleSurvivorBots(int client)
{
	if (g_cvSurvivorBotStop == null)
	{
		PrintToChat(client, "[Tank训练] 找不到官方 cvar：sb_stop。");
		return;
	}

	if (g_bSurvivorBotsFrozen)
	{
		g_cvSurvivorBotStop.SetString(g_sOriginalSurvivorBotStop);
		g_bSurvivorBotsFrozen = false;
		PrintToChat(client, "[Tank训练] 生还者 Bot 已恢复行动。");
	}
	else
	{
		g_cvSurvivorBotStop.GetString(g_sOriginalSurvivorBotStop, sizeof(g_sOriginalSurvivorBotStop));
		g_cvSurvivorBotStop.SetBool(true);
		g_bSurvivorBotsFrozen = true;
		PrintToChat(client, "[Tank训练] 生还者 Bot 已原地待命（同时不再攻击）。");
	}
}

void HealSurvivorBots(int client)
{
	int healedCount;
	for (int target = 1; target <= MaxClients; target++)
	{
		if (!IsClientInGame(target) || !IsFakeClient(target) || GetClientTeam(target) != 2 || !IsPlayerAlive(target))
		{
			continue;
		}

		if (IsPlayerIncapacitated(target))
		{
			L4D_ReviveSurvivor(target);
		}

		SetEntityHealth(target, 100);
		SetEntPropFloat(target, Prop_Send, "m_healthBuffer", 0.0);
		SetEntPropFloat(target, Prop_Send, "m_healthBufferTime", GetGameTime());
		healedCount++;
	}

	PrintToChat(client, "[Tank训练] 已将 %d 名 AI 生还者复活并回满血。", healedCount);
}

void TeleportSurvivorsToCrosshair(int client)
{
	float destination[3];
	if (!GetCrosshairDestination(client, destination))
	{
		PrintToChat(client, "[Tank训练] 准星前方没有可用落点，请对准地面或墙面后重试。");
		return;
	}

	int teleportedCount;
	for (int target = 1; target <= MaxClients; target++)
	{
		if (!IsClientInGame(target) || !IsPlayerAlive(target) || GetClientTeam(target) != 2)
		{
			continue;
		}

		TeleportEntity(target, destination, NULL_VECTOR, NULL_VECTOR);
		teleportedCount++;
	}

	PrintToChat(client, "[Tank训练] 已将 %d 名生还者传送到准星位置。", teleportedCount);
}

bool GetCrosshairDestination(int client, float destination[3])
{
	float start[3], angles[3], direction[3];
	GetClientEyePosition(client, start);
	GetClientEyeAngles(client, angles);

	Handle trace = TR_TraceRayFilterEx(start, angles, MASK_PLAYERSOLID, RayType_Infinite, TraceFilter_IgnorePlayers, client);
	if (!TR_DidHit(trace))
	{
		delete trace;
		return false;
	}

	TR_GetEndPosition(destination, trace);
	delete trace;

	// 放在命中平面的近侧，避免把生还者塞进墙面或地面。
	GetAngleVectors(angles, direction, NULL_VECTOR, NULL_VECTOR);
	destination[0] -= direction[0] * 24.0;
	destination[1] -= direction[1] * 24.0;
	destination[2] -= direction[2] * 24.0;
	return true;
}

public bool TraceFilter_IgnorePlayers(int entity, int contentsMask, any data)
{
	return entity == 0 || entity > MaxClients;
}

void ToggleNoclip(int client)
{
	if (g_bNoclip[client])
	{
		SetEntityMoveType(client, g_eOriginalMoveType[client]);
		g_bNoclip[client] = false;
		PrintToChat(client, "[Tank训练] 穿墙模式已关闭。");
	}
	else
	{
		g_eOriginalMoveType[client] = GetEntityMoveType(client);
		SetEntityMoveType(client, MOVETYPE_NOCLIP);
		g_bNoclip[client] = true;
		PrintToChat(client, "[Tank训练] 穿墙模式已开启。");
	}
}

void ToggleTankFrustration(int client)
{
	if (g_cvFrustrationSpawnDelay == null || g_cvFrustrationLosDelay == null)
	{
		PrintToChat(client, "[Tank训练] 找不到 Tank 失控相关官方 cvar。");
		return;
	}

	if (g_bFrustrationDisabled)
	{
		RestoreTankFrustration();
		PrintToChat(client, "[Tank训练] Tank 已恢复正常失控规则。");
	}
	else
	{
		g_cvFrustrationSpawnDelay.GetString(g_sOriginalFrustrationSpawnDelay, sizeof(g_sOriginalFrustrationSpawnDelay));
		g_cvFrustrationLosDelay.GetString(g_sOriginalFrustrationLosDelay, sizeof(g_sOriginalFrustrationLosDelay));
		g_cvFrustrationSpawnDelay.SetInt(99999999);
		g_cvFrustrationLosDelay.SetInt(99999999);
		g_bFrustrationDisabled = true;
		PrintToChat(client, "[Tank训练] 本回合 Tank 不会因距离或视线失控。");
	}
}

public Action Hook_SurvivorTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damageType)
{
	if (g_cvEnable.BoolValue && g_bSurvivorsInvulnerable && IsSurvivorPlayer(victim))
	{
		damage = 0.0;
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

void RestoreTrainingState()
{
	if (g_bSurvivorBotsFrozen && g_cvSurvivorBotStop != null)
	{
		g_cvSurvivorBotStop.SetString(g_sOriginalSurvivorBotStop);
		g_bSurvivorBotsFrozen = false;
	}

	g_bSurvivorsInvulnerable = false;
	RestoreTankFrustration();

	for (int client = 1; client <= MaxClients; client++)
	{
		if (g_bNoclip[client] && IsClientInGame(client) && IsPlayerAlive(client))
		{
			SetEntityMoveType(client, g_eOriginalMoveType[client]);
		}
		g_bNoclip[client] = false;
	}
}

void RestoreTankFrustration()
{
	if (!g_bFrustrationDisabled)
	{
		return;
	}

	if (g_cvFrustrationSpawnDelay != null)
	{
		g_cvFrustrationSpawnDelay.SetString(g_sOriginalFrustrationSpawnDelay);
	}
	if (g_cvFrustrationLosDelay != null)
	{
		g_cvFrustrationLosDelay.SetString(g_sOriginalFrustrationLosDelay);
	}
	g_bFrustrationDisabled = false;
}

void ClearSnapshots()
{
	g_Hittables.Clear();
	g_bSnapshotsReady = false;
}

bool IsPlayerIncapacitated(int client)
{
	return GetEntProp(client, Prop_Send, "m_isIncapacitated") != 0;
}

bool IsSurvivorPlayer(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2;
}

bool IsTankPlayer(int client)
{
	return IsSurvivorPlayer(client) == false
		&& client > 0
		&& client <= MaxClients
		&& IsClientInGame(client)
		&& IsPlayerAlive(client)
		&& GetClientTeam(client) == 3
		&& GetEntProp(client, Prop_Send, "m_zombieClass") == 8;
}
