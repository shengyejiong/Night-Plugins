#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>
#include <left4dhooks_anim>
#include <actions>
#include <l4d2util_constants>
#undef REQUIRE_PLUGIN
#include <godframecontrol>

#define TEAM_INFECTED 3
#define Z_SMOKER 1
#define Z_HUNTER 3
#define Z_CHARGER 6
#define Z_TANK 8

#define HUNTER_ASSAULT_DURATION 5.0
#define HUNTER_REPEAT_ATTACK_CHANCE 4
#define HUNTER_ATTACK_COOLDOWN 0.5
#define HUNTER_AIR_SPEED 450.0
#define SMOKER_TONGUE_DISTANCE_PERCENT 0.80
#define SMOKER_TONGUE_COMMAND_INTERVAL 0.3
#define CHARGER_INCAP_PUMMEL_DAMAGE 30.0
#define SURVIVOR_RUNSPEED 220.0
#define ROCK_HISTORY_FRAMES 100
#define ROCK_HEALTH 100.0
#define COMMON_SHOVE_GAMEDATA "l4d_fix_common_shove"
#define STAGGER_DIRECTION_GAMEDATA "l4d_fix_stagger_dir"
#define GETUP_TIMER_INTERVAL 0.04
#define ANIM_TANK_PUNCH_GETUP 96
#define MERGED_GETUP_GAMEDATA "l4d2_getup_fixes"

#define ROCK_BLOCK_ENT_REF 0
#define ROCK_BLOCK_POS_HISTORY 1
#define ROCK_BLOCK_DAMAGE_DEALT 2
#define ROCK_BLOCK_SPAWN_TIME 3
#define ROCK_BLOCK_RELEASED 4
#define ROCK_BLOCK_DETONATING 5
#define ROCK_BLOCK_COUNT 6

static const int g_iDeadstopSequences[] = {64, 67, 11, 8};
static const int g_iTankFlySequences[] =
{
	628, // Nick
	636, // Rochelle
	628, // Coach
	633, // Ellis
	536, // Bill
	545, // Zoey
	539, // Francis
	536  // Louis
};

enum GetupState
{
	Getup_Upright = 0,
	Getup_Incapped,
	Getup_Smoked,
	Getup_Jockeyed,
	Getup_Hunter,
	Getup_InstantCharged,
	Getup_Charged,
	Getup_Charger,
	Getup_MultiCharged,
	Getup_TankRock,
	Getup_TankPunchFly,
	Getup_TankPunch,
	Getup_TankPunchAfterRock,
	Getup_TankPunchAfterJockey
};

enum MergedGetupAnimStateFlag
{
	MergedGetup_Charged = 0,
	MergedGetup_WallSlammed = 2,
	MergedGetup_GroundSlammed = 3,
	MergedGetup_Pounded = 5,
	MergedGetup_TankPunched = 7,
	MergedGetup_Pounced = 9,
	MergedGetup_RiddenByJockey = 14
};

ConVar g_cvSmartAiRock;
ConVar g_cvHunterNoDeadstop;
ConVar g_cvAiHunterPounce;
ConVar g_cvAiSmokerTongue;
ConVar g_cvTongueFloatFix;
ConVar g_cvSiShoveDirectionFix;
ConVar g_cvTongueRange;
ConVar g_cvChargerIncapPummel;
ConVar g_cvChargerPoundDamage;
ConVar g_cvTankChargerShoveFix;
ConVar g_cvTankMeleeFury;
ConVar g_cvTankSwingInterval;
ConVar g_cvTankWindupTime;
ConVar g_cvRockLagComp;
ConVar g_cvRockHitboxRadius;
ConVar g_cvRockGodframes;
ConVar g_cvRockGodframesRender;
ConVar g_cvRockRangeMin;
ConVar g_cvRockRangeMax;
ConVar g_cvTankWaterNoSlowdown;
ConVar g_cvTankFlyingIncap;
ConVar g_cvSurvivorLimpHealth;
ConVar g_cvJockeyMinMountedSpeed;
ConVar g_cvCommonShoveFix;
ConVar g_cvMultiGetupFix;
char g_sPersistentStatePath[PLATFORM_MAX_PATH];
float g_fHunterDelay[MAXPLAYERS + 1][3];
int g_iHunterState[MAXPLAYERS + 1][3];
float g_fSmokerNextTongue[MAXPLAYERS + 1];
ArrayList g_aRockEntities;
bool g_bTankWaterNoSlowdownActive;
int g_iIncapEventTick[MAXPLAYERS + 1];
int g_iSavedIncapState[MAXPLAYERS + 1];
bool g_bTemporarilyClearedIncap[MAXPLAYERS + 1];
GetupState g_eGetupState[MAXPLAYERS + 1];
int g_iPendingGetups[MAXPLAYERS + 1];
bool g_bGetupInterrupted[MAXPLAYERS + 1];
int g_iGetupSequence[MAXPLAYERS + 1];
Handle g_hMergedGetupResetMainActivity;
int g_iMergedGetupAnimStateOffset;
int g_iMergedGetupChargedOffset;
int g_iMergedGetupChargeVictim[MAXPLAYERS + 1] = {-1, ...};
int g_iMergedGetupChargeAttacker[MAXPLAYERS + 1] = {-1, ...};
float g_fMergedGetupLastChargedEndTime[MAXPLAYERS + 1];
ConVar g_cvMergedGetupLongChargeDuration;
ConVar g_cvMergedGetupKeepWallSlam;
ConVar g_cvMergedGetupKeepLongCharge;

Handle g_hCommonShoveMyNextBotPointer;
Handle g_hCommonShoveGetBodyInterface;
Handle g_hCommonShoveGetLocomotionInterface;
Handle g_hCommonShoveSetDesiredPosture;
int g_iCommonShoveLadderOffset;
int g_iStaggerDirectionPlayerAnimStateOffset;
int g_iStaggerDirectionEyeYawOffset;
bool g_bStaggerDirectionAvailable;

public Plugin myinfo =
{
	name = "L4D2 Campaign Difficulty Options",
	author = "Visor, A1m, Forgetest, CanadaRox, night",
	description = "AI Tank rock aim recovery and Special Infected options for campaign servers",
	version = "4.4.0",
	url = ""
};

enum CommonShoveActivityType
{
	CommonShove_ActivityUninterruptible = 0x0004
};

enum CommonShovePostureType
{
	CommonShove_PostureStand = 0
};

enum CommonShovePendingState
{
	CommonShovePending_Invalid = 0,
	CommonShovePending_Yes,
	CommonShovePending_Callback
};

methodmap CommonShoveNextBot
{
	public CommonShoveBotBody GetBodyInterface()
	{
		return SDKCall(g_hCommonShoveGetBodyInterface, this);
	}

	public CommonShoveBotLocomotion GetLocomotionInterface()
	{
		return SDKCall(g_hCommonShoveGetLocomotionInterface, this);
	}
};

methodmap CommonShoveBotBody
{
	public void SetDesiredPosture(CommonShovePostureType posture)
	{
		SDKCall(g_hCommonShoveSetDesiredPosture, this, posture);
	}

	property int Activity
	{
		public get()
		{
			return LoadFromAddress(view_as<Address>(this) + view_as<Address>(80), NumberType_Int32);
		}
	}

	property CommonShoveActivityType ActivityType
	{
		public get()
		{
			return LoadFromAddress(view_as<Address>(this) + view_as<Address>(84), NumberType_Int32);
		}
		public set(CommonShoveActivityType flags)
		{
			StoreToAddress(view_as<Address>(this) + view_as<Address>(84), flags, NumberType_Int32);
		}
	}
};

methodmap CommonShoveBotLocomotion
{
	property Address Ladder
	{
		public get()
		{
			return view_as<Address>(LoadFromAddress(view_as<Address>(this) + view_as<Address>(g_iCommonShoveLadderOffset), NumberType_Int32));
		}
		public set(Address pointer)
		{
			StoreToAddress(view_as<Address>(this) + view_as<Address>(g_iCommonShoveLadderOffset), view_as<int>(pointer), NumberType_Int32);
		}
	}
};

CommonShoveNextBot CommonShoveMyNextBotPointer(int entity)
{
	return SDKCall(g_hCommonShoveMyNextBotPointer, entity);
}

void InitializeCommonShoveFix()
{
	GameData gameData = new GameData(COMMON_SHOVE_GAMEDATA);
	if (gameData == null)
	{
		SetFailState("缺少普通感染者推击修复 gamedata：%s.txt", COMMON_SHOVE_GAMEDATA);
	}

	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(gameData, SDKConf_Signature, "ZombieBotBody::SetDesiredPosture"))
	{
		delete gameData;
		SetFailState("普通感染者推击修复缺少 SetDesiredPosture 签名");
	}
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	g_hCommonShoveSetDesiredPosture = EndPrepSDKCall();

	StartPrepSDKCall(SDKCall_Entity);
	if (!PrepSDKCall_SetFromConf(gameData, SDKConf_Virtual, "CBaseEntity::MyNextBotPointer"))
	{
		delete gameData;
		SetFailState("普通感染者推击修复缺少 MyNextBotPointer 偏移");
	}
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hCommonShoveMyNextBotPointer = EndPrepSDKCall();

	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(gameData, SDKConf_Virtual, "INextBot::GetBodyInterface"))
	{
		delete gameData;
		SetFailState("普通感染者推击修复缺少 GetBodyInterface 偏移");
	}
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hCommonShoveGetBodyInterface = EndPrepSDKCall();

	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(gameData, SDKConf_Virtual, "INextBot::GetLocomotionInterface"))
	{
		delete gameData;
		SetFailState("普通感染者推击修复缺少 GetLocomotionInterface 偏移");
	}
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hCommonShoveGetLocomotionInterface = EndPrepSDKCall();

	g_iCommonShoveLadderOffset = gameData.GetOffset("ZombieBotLocomotion::m_ladder");
	delete gameData;

	if (g_hCommonShoveSetDesiredPosture == null
		|| g_hCommonShoveMyNextBotPointer == null
		|| g_hCommonShoveGetBodyInterface == null
		|| g_hCommonShoveGetLocomotionInterface == null
		|| g_iCommonShoveLadderOffset == -1)
	{
		SetFailState("普通感染者推击修复的 SDKCall 初始化失败");
	}
}

methodmap MergedGetupAnimState
{
	public MergedGetupAnimState(int client)
	{
		int pointer = GetEntData(client, g_iMergedGetupAnimStateOffset, 4);
		if (pointer == 0)
		{
			ThrowError("起身动画状态指针无效（client %d）", client);
		}
		return view_as<MergedGetupAnimState>(pointer);
	}

	public void ResetMainActivity()
	{
		SDKCall(g_hMergedGetupResetMainActivity, this);
	}

	public bool GetFlag(MergedGetupAnimStateFlag flag)
	{
		return view_as<bool>(LoadFromAddress(view_as<Address>(this) + view_as<Address>(g_iMergedGetupChargedOffset) + view_as<Address>(flag), NumberType_Int8));
	}

	public void SetFlag(MergedGetupAnimStateFlag flag, bool value)
	{
		StoreToAddress(view_as<Address>(this) + view_as<Address>(g_iMergedGetupChargedOffset) + view_as<Address>(flag), value ? 1 : 0, NumberType_Int8);
	}
}

void InitializeMergedGetupFix()
{
	GameData gameData = new GameData(MERGED_GETUP_GAMEDATA);
	if (gameData == null)
	{
		SetFailState("缺少起身修复 gamedata：%s.txt", MERGED_GETUP_GAMEDATA);
	}

	g_iMergedGetupAnimStateOffset = gameData.GetOffset("CTerrorPlayer::m_PlayerAnimState");
	g_iMergedGetupChargedOffset = gameData.GetOffset("CTerrorPlayerAnimState::m_bCharged");
	if (g_iMergedGetupAnimStateOffset == -1 || g_iMergedGetupChargedOffset == -1)
	{
		delete gameData;
		SetFailState("起身修复 gamedata 缺少动画状态偏移");
	}

	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(gameData, SDKConf_Virtual, "CTerrorPlayerAnimState::ResetMainActivity"))
	{
		delete gameData;
		SetFailState("起身修复 gamedata 缺少 ResetMainActivity 偏移");
	}
	g_hMergedGetupResetMainActivity = EndPrepSDKCall();
	delete gameData;
	if (g_hMergedGetupResetMainActivity == null)
	{
		SetFailState("无法建立起身修复 ResetMainActivity 调用");
	}

	g_cvMergedGetupLongChargeDuration = CreateConVar("l4d2_difficulty_getup_long_charger_godframe", "2.2", "较长 Charger 起身动画的无敌帧秒数", FCVAR_NOTIFY, true, 0.0, true, 10.0);
	g_cvMergedGetupKeepWallSlam = CreateConVar("l4d2_difficulty_getup_keep_wall_slam", "1", "1=保留 Charger 撞墙后的长起身动画，0=改为普通起身", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvMergedGetupKeepLongCharge = CreateConVar("l4d2_difficulty_getup_keep_long_charge", "0", "1=保留 Charger 远距离冲撞后的长起身动画，0=改为普通起身", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	ResetAllMergedGetupState();
}

void InitializeStaggerDirectionFix()
{
	GameData gameData = new GameData(STAGGER_DIRECTION_GAMEDATA);
	if (gameData == null)
	{
		LogError("缺少特感推击方向修复 gamedata：%s.txt；该选项已停用。", STAGGER_DIRECTION_GAMEDATA);
		g_bStaggerDirectionAvailable = false;
		return;
	}

	g_iStaggerDirectionPlayerAnimStateOffset = gameData.GetOffset("CTerrorPlayer::m_PlayerAnimState");
	g_iStaggerDirectionEyeYawOffset = gameData.GetOffset("m_flEyeYaw");
	delete gameData;

	if (g_iStaggerDirectionPlayerAnimStateOffset == -1 || g_iStaggerDirectionEyeYawOffset == -1)
	{
		LogError("特感推击方向修复 gamedata 缺少动画状态偏移；该选项已停用。");
		g_bStaggerDirectionAvailable = false;
		return;
	}

	g_bStaggerDirectionAvailable = true;
}

public void OnPluginStart()
{
	g_cvSmartAiRock = CreateConVar("l4d2_difficulty_smart_ai_rock", "1", "1=AI Tank 扔石头后恢复追踪目标，0=关闭", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvHunterNoDeadstop = CreateConVar("l4d2_difficulty_hunter_no_deadstop", "0", "1=未扑中目标的 Hunter 空中不能被推，0=关闭", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvAiHunterPounce = CreateConVar("l4d2_difficulty_ai_hunter_pounce", "0", "1=增强 AI Hunter 的连续跳扑和空中调整，0=关闭", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvAiSmokerTongue = CreateConVar("l4d2_difficulty_ai_smoker_tongue", "0", "1=增强 AI Smoker 的瞄准和主动伸舌，0=关闭", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvTongueFloatFix = CreateConVar("l4d2_difficulty_tongue_float_fix", "1", "1=修复 Smoker 舌头刚抓住生还者时异常立即吊起，0=关闭", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvSiShoveDirectionFix = CreateConVar("l4d2_difficulty_si_shove_direction_fix", "1", "1=修复特感被幸存者推击时的踉跄动画方向，0=关闭", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvTongueRange = FindConVar("tongue_range");
	g_cvChargerIncapPummel = CreateConVar("l4d2_difficulty_charger_incap_pummel", "0", "1=Charger 对倒地目标的锤击伤害固定为30，0=关闭", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvChargerPoundDamage = FindConVar("z_charger_pound_dmg");
	g_cvTankChargerShoveFix = CreateConVar("l4d2_difficulty_tank_charger_shove_fix", "1", "1=幸存者推击不减速 Tank 和 Charger，0=关闭", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvTankMeleeFury = CreateConVar("l4d2_difficulty_tank_melee_fury", "0", "1=近战命中 Tank 时提前其主、副攻击冷却，0=关闭", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvTankSwingInterval = FindConVar("tank_swing_interval");
	g_cvTankWindupTime = FindConVar("tank_windup_time");
	g_cvRockLagComp = CreateConVar("l4d2_difficulty_rock_lagcomp", "1", "1=开启 Tank 石头空爆与延迟补偿，0=关闭", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvRockHitboxRadius = CreateConVar("l4d2_difficulty_rock_hitbox_radius", "30", "Tank 石头自定义命中框半径", FCVAR_NOTIFY, true, 0.0, true, 10000.0);
	g_cvRockGodframes = CreateConVar("l4d2_difficulty_rock_godframes", "1.7", "未收到投石离手回调时的石头保护秒数", FCVAR_NOTIFY, true, 0.0, true, 10.0);
	g_cvRockGodframesRender = CreateConVar("l4d2_difficulty_rock_godframes_render", "1", "1=石头保护期间显示半透明效果，0=关闭", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvRockRangeMin = CreateConVar("l4d2_difficulty_rock_range_min", "1", "命中石头的全局最小距离", FCVAR_NOTIFY, true, 0.0, true, 10000.0);
	g_cvRockRangeMax = CreateConVar("l4d2_difficulty_rock_range_max", "2000", "命中石头的全局最大距离，0=不限", FCVAR_NOTIFY, true, 0.0, true, 10000.0);
	g_cvTankWaterNoSlowdown = CreateConVar("l4d2_difficulty_tank_water_no_slowdown", "1", "1=Tank 存活时幸存者水中不减速，0=关闭", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvTankFlyingIncap = CreateConVar("l4d2_difficulty_tank_flying_incap", "1", "1=Tank 一拳致倒时击飞幸存者，0=关闭", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvSurvivorLimpHealth = FindConVar("survivor_limp_health");
	g_cvJockeyMinMountedSpeed = FindConVar("z_jockey_min_mounted_speed");
	g_cvCommonShoveFix = CreateConVar("l4d2_difficulty_common_shove_fix", "1", "1=修复普通感染者蹲伏、下落、落地和爬梯时无法正常被推，0=关闭", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvMultiGetupFix = CreateConVar("l4d2_difficulty_multi_getup_fix", "1", "1=启用完整的多人重复/遗漏起身修复，0=关闭", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	InitializeMergedGetupFix();
	InitializeCommonShoveFix();
	InitializeStaggerDirectionFix();

	g_aRockEntities = new ArrayList(ROCK_BLOCK_COUNT);

	// 所有在游戏内的玩家均可打开菜单。
	RegConsoleCmd("sm_tankdiff", Command_DifficultyMenu, "打开战役难度选项菜单");
	RegConsoleCmd("sm_tankdifficulty", Command_DifficultyMenu, "打开战役难度选项菜单");

	BuildPath(Path_SM, g_sPersistentStatePath, sizeof(g_sPersistentStatePath), "data/l4d2_campaign_difficulty_options_state.cfg");
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Post);
	HookEvent("tank_spawn", Event_TankSpawn, EventHookMode_PostNoCopy);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
	HookEvent("player_incapacitated", Event_PlayerIncapacitated, EventHookMode_Post);
	HookEvent("tongue_grab", Event_GetupTongueGrab, EventHookMode_Post);
	HookEvent("lunge_pounce", Event_MergedGetupLungePounce, EventHookMode_Post);
	HookEvent("jockey_ride", Event_GetupJockeyRide, EventHookMode_Post);
	HookEvent("jockey_ride_end", Event_GetupJockeyRideEnd, EventHookMode_Post);
	HookEvent("charger_carry_start", Event_MergedGetupChargerCarryStart, EventHookMode_Post);
	HookEvent("charger_pummel_start", Event_GetupChargerPummelStart, EventHookMode_Post);
	HookEvent("charger_pummel_end", Event_GetupChargerPummelEnd, EventHookMode_Post);
	HookEvent("charger_killed", Event_MergedGetupChargerKilled, EventHookMode_Post);
	HookEvent("revive_success", Event_GetupReviveSuccess, EventHookMode_Post);
	HookEvent("player_bot_replace", Event_GetupPlayerBotReplace, EventHookMode_Post);
	HookEvent("bot_player_replace", Event_GetupBotPlayerReplace, EventHookMode_Post);
	HookEvent("weapon_fire", Event_WeaponFire, EventHookMode_Post);
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
		{
			SDKHook(client, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
		}
	}
	AutoExecConfig(true, "l4d2_campaign_difficulty_options");
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
	g_iIncapEventTick[client] = 0;
	g_iSavedIncapState[client] = 0;
	g_bTemporarilyClearedIncap[client] = false;
	ResetMultiGetupState(client);
	ResetMergedGetupState(client);
}

public void OnClientDisconnect(int client)
{
	g_iIncapEventTick[client] = 0;
	g_iSavedIncapState[client] = 0;
	g_bTemporarilyClearedIncap[client] = false;
	ResetMultiGetupState(client);
	ResetMergedGetupState(client);
}

public void OnMapStart()
{
	ClearTrackedRocks();
	g_bTankWaterNoSlowdownActive = false;
	ResetAllTankFlyingIncapState();
	ResetAllMultiGetupState();
	ResetAllMergedGetupState();
}

public void OnPluginEnd()
{
	ClearTrackedRocks();
	ResetAllMultiGetupState();
	ResetAllMergedGetupState();
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (!StrEqual(classname, "tank_rock"))
	{
		return;
	}

	int rockRef = EntIndexToEntRef(entity);
	SDKHook(entity, SDKHook_OnTakeDamage, OnRockTakeDamage);
	SDKHook(entity, SDKHook_SpawnPost, OnRockSpawnPost);
	AddTrackedRock(rockRef);
	UpdateRockRenderByRef(rockRef);
}

public void OnRockSpawnPost(int entity)
{
	if (!IsValidEntity(entity))
	{
		return;
	}

	if (GetEntProp(entity, Prop_Data, "m_iHammerID") == 92950)
	{
		RemoveTrackedRock(EntIndexToEntRef(entity));
	}
}

public void OnEntityDestroyed(int entity)
{
	if (IsRock(entity))
	{
		RemoveTrackedRock(EntIndexToEntRef(entity));
	}
}

public void OnGameFrame()
{
	if (g_aRockEntities == null || g_aRockEntities.Length == 0)
	{
		return;
	}

	float position[3];
	int historyIndex = GetHistoryIndex(GetGameTickCount());
	for (int i = g_aRockEntities.Length - 1; i >= 0; i--)
	{
		int rockRef = g_aRockEntities.Get(i, ROCK_BLOCK_ENT_REF);
		int rock = EntRefToEntIndex(rockRef);
		if (rock == INVALID_ENT_REFERENCE || !IsValidEntity(rock))
		{
			RemoveTrackedRockByIndex(i);
			continue;
		}

		GetEntPropVector(rock, Prop_Send, "m_vecOrigin", position);
		ArrayList history = view_as<ArrayList>(g_aRockEntities.Get(i, ROCK_BLOCK_POS_HISTORY));
		history.SetArray(historyIndex, position, sizeof(position));
		UpdateRockRender(i);
	}
}

// 地图配置可能会重新执行默认 ConVar；在其执行完成后恢复菜单保存的所有设置。
public void OnConfigsExecuted()
{
	LoadPersistentSettings();
	RefreshTankWaterNoSlowdownState(false);
}

void LoadPersistentSettings()
{
	KeyValues state = new KeyValues("CampaignDifficultyOptions");
	if (FileToKeyValues(state, g_sPersistentStatePath))
	{
		int smartAiRock = state.GetNum("smart_ai_rock", -1);
		if (smartAiRock != -1)
		{
			g_cvSmartAiRock.BoolValue = smartAiRock != 0;
		}

		int hunterNoDeadstop = state.GetNum("hunter_no_deadstop", -1);
		if (hunterNoDeadstop != -1)
		{
			g_cvHunterNoDeadstop.BoolValue = hunterNoDeadstop != 0;
		}

		int aiHunterPounce = state.GetNum("ai_hunter_pounce", -1);
		if (aiHunterPounce != -1)
		{
			g_cvAiHunterPounce.BoolValue = aiHunterPounce != 0;
		}

		int aiSmokerTongue = state.GetNum("ai_smoker_tongue", -1);
		if (aiSmokerTongue != -1)
		{
			g_cvAiSmokerTongue.BoolValue = aiSmokerTongue != 0;
		}

		int tongueFloatFix = state.GetNum("tongue_float_fix", -1);
		if (tongueFloatFix != -1)
		{
			g_cvTongueFloatFix.BoolValue = tongueFloatFix != 0;
		}

		int siShoveDirectionFix = state.GetNum("si_shove_direction_fix", -1);
		if (siShoveDirectionFix != -1)
		{
			g_cvSiShoveDirectionFix.BoolValue = siShoveDirectionFix != 0;
		}

		int chargerIncapPummel = state.GetNum("charger_incap_pummel", -1);
		if (chargerIncapPummel != -1)
		{
			g_cvChargerIncapPummel.BoolValue = chargerIncapPummel != 0;
		}

		int tankChargerShoveFix = state.GetNum("tank_charger_shove_fix", -1);
		if (tankChargerShoveFix != -1)
		{
			g_cvTankChargerShoveFix.BoolValue = tankChargerShoveFix != 0;
		}

		int tankMeleeFury = state.GetNum("tank_melee_fury", -1);
		if (tankMeleeFury != -1)
		{
			g_cvTankMeleeFury.BoolValue = tankMeleeFury != 0;
		}

		int rockLagComp = state.GetNum("rock_lagcomp", -1);
		if (rockLagComp != -1)
		{
			g_cvRockLagComp.BoolValue = rockLagComp != 0;
		}

		int tankWaterNoSlowdown = state.GetNum("tank_water_no_slowdown", -1);
		if (tankWaterNoSlowdown != -1)
		{
			g_cvTankWaterNoSlowdown.BoolValue = tankWaterNoSlowdown != 0;
		}

		int tankFlyingIncap = state.GetNum("tank_flying_incap", -1);
		if (tankFlyingIncap != -1)
		{
			g_cvTankFlyingIncap.BoolValue = tankFlyingIncap != 0;
		}

		int commonShoveFix = state.GetNum("common_shove_fix", -1);
		if (commonShoveFix != -1)
		{
			g_cvCommonShoveFix.BoolValue = commonShoveFix != 0;
		}

		int multiGetupFix = state.GetNum("multi_getup_fix", -1);
		if (multiGetupFix != -1)
		{
			g_cvMultiGetupFix.BoolValue = multiGetupFix != 0;
		}
	}
	delete state;
}

// 今后菜单中新增的开关，也在这里读写，保证行为与现有选项一致。
void SavePersistentSettings()
{
	KeyValues state = new KeyValues("CampaignDifficultyOptions");
	state.SetNum("smart_ai_rock", g_cvSmartAiRock.BoolValue ? 1 : 0);
	state.SetNum("hunter_no_deadstop", g_cvHunterNoDeadstop.BoolValue ? 1 : 0);
	state.SetNum("ai_hunter_pounce", g_cvAiHunterPounce.BoolValue ? 1 : 0);
	state.SetNum("ai_smoker_tongue", g_cvAiSmokerTongue.BoolValue ? 1 : 0);
	state.SetNum("tongue_float_fix", g_cvTongueFloatFix.BoolValue ? 1 : 0);
	state.SetNum("si_shove_direction_fix", g_cvSiShoveDirectionFix.BoolValue ? 1 : 0);
	state.SetNum("charger_incap_pummel", g_cvChargerIncapPummel.BoolValue ? 1 : 0);
	state.SetNum("tank_charger_shove_fix", g_cvTankChargerShoveFix.BoolValue ? 1 : 0);
	state.SetNum("tank_melee_fury", g_cvTankMeleeFury.BoolValue ? 1 : 0);
	state.SetNum("rock_lagcomp", g_cvRockLagComp.BoolValue ? 1 : 0);
	state.SetNum("tank_water_no_slowdown", g_cvTankWaterNoSlowdown.BoolValue ? 1 : 0);
	state.SetNum("tank_flying_incap", g_cvTankFlyingIncap.BoolValue ? 1 : 0);
	state.SetNum("common_shove_fix", g_cvCommonShoveFix.BoolValue ? 1 : 0);
	state.SetNum("multi_getup_fix", g_cvMultiGetupFix.BoolValue ? 1 : 0);
	state.Rewind();
	state.ExportToFile(g_sPersistentStatePath);
	delete state;
}

public void OnActionCreated(BehaviorAction action, int actor, const char[] name)
{
	if (name[0] == 'I' && strcmp(name, "InfectedShoved") == 0)
	{
		action.OnStart = CommonShove_OnStart;
		action.OnShoved = CommonShove_OnShoved;
		action.OnLandOnGroundPost = CommonShove_OnLandOnGroundPost;
	}
}

Action CommonShove_OnStart(BehaviorAction action, int actor, any priorAction, ActionResult result)
{
	if (!g_cvCommonShoveFix.BoolValue)
	{
		return Plugin_Continue;
	}

	CommonShoveNextBot nextBot = CommonShoveMyNextBotPointer(actor);
	CommonShoveBotBody body = nextBot.GetBodyInterface();
	if (body.Activity == L4D2_ACT_TERROR_FALL)
	{
		result.type = CONTINUE;
		action.SetUserData("state", CommonShovePending_Yes);

		float direction[3], position[3];
		direction[0] = action.Get(56, NumberType_Int32);
		direction[1] = action.Get(60, NumberType_Int32);
		direction[2] = action.Get(64, NumberType_Int32);
		GetEntPropVector(actor, Prop_Data, "m_vecAbsOrigin", position);
		SubtractVectors(direction, position, direction);
		action.SetUserDataVector("direction", direction);
		return Plugin_Handled;
	}

	body.SetDesiredPosture(CommonShove_PostureStand);
	nextBot.GetLocomotionInterface().Ladder = Address_Null;
	CommonShoveForceLandingInterruptible(actor);

	if (action.GetUserData("state") == CommonShovePending_Callback)
	{
		float direction[3], position[3];
		action.GetUserDataVector("direction", direction);
		GetEntPropVector(actor, Prop_Data, "m_vecAbsOrigin", position);
		AddVectors(position, direction, position);
		action.Set(56, position[0], NumberType_Int32);
		action.Set(60, position[1], NumberType_Int32);
		action.Set(64, position[2], NumberType_Int32);
	}

	return Plugin_Continue;
}

Action CommonShove_OnShoved(BehaviorAction action, int actor, int entity, ActionDesiredResult result)
{
	if (g_cvCommonShoveFix.BoolValue && GetEntPropEnt(actor, Prop_Data, "m_hGroundEntity") != -1)
	{
		CommonShoveMyNextBotPointer(actor).GetBodyInterface().SetDesiredPosture(CommonShove_PostureStand);
	}
	return Plugin_Continue;
}

Action CommonShove_OnLandOnGroundPost(BehaviorAction action, int actor, int entity, ActionDesiredResult result)
{
	if (!g_cvCommonShoveFix.BoolValue || action.GetUserData("state") != CommonShovePending_Yes)
	{
		return Plugin_Continue;
	}

	action.IsStarted = false;
	action.SetUserData("state", CommonShovePending_Callback);
	CommonShoveForceLandingInterruptible(actor);
	return Plugin_Handled;
}

bool CommonShoveForceLandingInterruptible(int infected)
{
	CommonShoveBotBody body = CommonShoveMyNextBotPointer(infected).GetBodyInterface();
	switch (body.Activity)
	{
		case L4D2_ACT_TERROR_JUMP_LANDING,
			L4D2_ACT_TERROR_JUMP_LANDING_HARD,
			L4D2_ACT_TERROR_JUMP_LANDING_NEUTRAL,
			L4D2_ACT_TERROR_JUMP_LANDING_HARD_NEUTRAL:
		{
			body.ActivityType &= ~CommonShove_ActivityUninterruptible;
			return true;
		}
	}
	return false;
}

public Action Command_DifficultyMenu(int client, int args)
{
	if (client <= 0 || !IsClientInGame(client))
	{
		ReplyToCommand(client, "此命令只能由游戏内玩家使用。");
		return Plugin_Handled;
	}

	ShowDifficultyMenu(client);
	return Plugin_Handled;
}

void ShowDifficultyMenu(int client)
{
	Menu menu = new Menu(DifficultyMenuHandler);
	menu.SetTitle("多特战役难度选项");

	char display[96];
	Format(display, sizeof(display), "AI Tank 投石后重瞄：%s", g_cvSmartAiRock.BoolValue ? "开启" : "关闭");
	menu.AddItem("smart_ai_rock", display);

	Format(display, sizeof(display), "Hunter 空中防推：%s", g_cvHunterNoDeadstop.BoolValue ? "开启" : "关闭");
	menu.AddItem("hunter_deadstop", display);

	Format(display, sizeof(display), "AI Hunter 跳扑增强：%s", g_cvAiHunterPounce.BoolValue ? "开启" : "关闭");
	menu.AddItem("ai_hunter_pounce", display);

	Format(display, sizeof(display), "AI Smoker 主动伸舌增强：%s", g_cvAiSmokerTongue.BoolValue ? "开启" : "关闭");
	menu.AddItem("ai_smoker_tongue", display);

	Format(display, sizeof(display), "Smoker 舌头立即吊起修复：%s", g_cvTongueFloatFix.BoolValue ? "开启" : "关闭");
	menu.AddItem("tongue_float_fix", display);

	if (g_bStaggerDirectionAvailable)
	{
		Format(display, sizeof(display), "特感推击踉跄方向修复：%s", g_cvSiShoveDirectionFix.BoolValue ? "开启" : "关闭");
		menu.AddItem("si_shove_direction_fix", display);
	}
	else
	{
		Format(display, sizeof(display), "特感推击踉跄方向修复：不可用");
		menu.AddItem("si_shove_direction_fix", display, ITEMDRAW_DISABLED);
	}

	Format(display, sizeof(display), "Charger 倒地连拳伤害 30：%s", g_cvChargerIncapPummel.BoolValue ? "开启" : "关闭");
	menu.AddItem("charger_incap_pummel", display);

	Format(display, sizeof(display), "Tank / Charger 推击减速修复：%s", g_cvTankChargerShoveFix.BoolValue ? "开启" : "关闭");
	menu.AddItem("tank_charger_shove_fix", display);

	Format(display, sizeof(display), "Tank 近战反制（无上限）：%s", g_cvTankMeleeFury.BoolValue ? "开启" : "关闭");
	menu.AddItem("tank_melee_fury", display);

	Format(display, sizeof(display), "Tank 石头空爆与延迟补偿：%s", g_cvRockLagComp.BoolValue ? "开启" : "关闭");
	menu.AddItem("rock_lagcomp", display);

	Format(display, sizeof(display), "Tank 战水中不减速：%s", g_cvTankWaterNoSlowdown.BoolValue ? "开启" : "关闭");
	menu.AddItem("tank_water_no_slowdown", display);

	Format(display, sizeof(display), "Tank 一拳致倒击飞：%s", g_cvTankFlyingIncap.BoolValue ? "开启" : "关闭");
	menu.AddItem("tank_flying_incap", display);

	Format(display, sizeof(display), "普通感染者推击修复：%s", g_cvCommonShoveFix.BoolValue ? "开启" : "关闭");
	menu.AddItem("common_shove_fix", display);

	Format(display, sizeof(display), "重复/遗漏起身修复（多人）：%s", g_cvMultiGetupFix.BoolValue ? "开启" : "关闭");
	menu.AddItem("multi_getup_fix", display);

	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int DifficultyMenuHandler(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(item, info, sizeof(info));

		if (StrEqual(info, "smart_ai_rock"))
		{
			g_cvSmartAiRock.BoolValue = !g_cvSmartAiRock.BoolValue;
			SavePersistentSettings();
			PrintToChat(client, "\x04[难度]\x01 AI Tank 投石后重瞄已%s。", g_cvSmartAiRock.BoolValue ? "开启" : "关闭");
		}
		else if (StrEqual(info, "hunter_deadstop"))
		{
			g_cvHunterNoDeadstop.BoolValue = !g_cvHunterNoDeadstop.BoolValue;
			SavePersistentSettings();
			PrintToChat(client, "\x04[难度]\x01 Hunter 空中防推已%s。", g_cvHunterNoDeadstop.BoolValue ? "开启" : "关闭");
		}
		else if (StrEqual(info, "ai_hunter_pounce"))
		{
			g_cvAiHunterPounce.BoolValue = !g_cvAiHunterPounce.BoolValue;
			ResetAllHunterPounceState();
			SavePersistentSettings();
			PrintToChat(client, "\x04[难度]\x01 AI Hunter 跳扑增强已%s。", g_cvAiHunterPounce.BoolValue ? "开启" : "关闭");
		}
		else if (StrEqual(info, "ai_smoker_tongue"))
		{
			g_cvAiSmokerTongue.BoolValue = !g_cvAiSmokerTongue.BoolValue;
			ResetAllSmokerTongueState();
			SavePersistentSettings();
			PrintToChat(client, "\x04[难度]\x01 AI Smoker 主动伸舌增强已%s。", g_cvAiSmokerTongue.BoolValue ? "开启" : "关闭");
		}
		else if (StrEqual(info, "tongue_float_fix"))
		{
			g_cvTongueFloatFix.BoolValue = !g_cvTongueFloatFix.BoolValue;
			SavePersistentSettings();
			PrintToChat(client, "\x04[难度]\x01 Smoker 舌头立即吊起修复已%s。", g_cvTongueFloatFix.BoolValue ? "开启" : "关闭");
		}
		else if (StrEqual(info, "si_shove_direction_fix") && g_bStaggerDirectionAvailable)
		{
			g_cvSiShoveDirectionFix.BoolValue = !g_cvSiShoveDirectionFix.BoolValue;
			SavePersistentSettings();
			PrintToChat(client, "\x04[难度]\x01 特感推击踉跄方向修复已%s。", g_cvSiShoveDirectionFix.BoolValue ? "开启" : "关闭");
		}
		else if (StrEqual(info, "charger_incap_pummel"))
		{
			g_cvChargerIncapPummel.BoolValue = !g_cvChargerIncapPummel.BoolValue;
			SavePersistentSettings();
			PrintToChat(client, "\x04[难度]\x01 Charger 倒地连拳伤害 30 已%s。", g_cvChargerIncapPummel.BoolValue ? "开启" : "关闭");
		}
		else if (StrEqual(info, "tank_charger_shove_fix"))
		{
			g_cvTankChargerShoveFix.BoolValue = !g_cvTankChargerShoveFix.BoolValue;
			SavePersistentSettings();
			PrintToChat(client, "\x04[难度]\x01 Tank / Charger 推击减速修复已%s。", g_cvTankChargerShoveFix.BoolValue ? "开启" : "关闭");
		}
		else if (StrEqual(info, "tank_melee_fury"))
		{
			g_cvTankMeleeFury.BoolValue = !g_cvTankMeleeFury.BoolValue;
			SavePersistentSettings();
			PrintToChat(client, "\x04[难度]\x01 Tank 近战反制（无上限）已%s。", g_cvTankMeleeFury.BoolValue ? "开启" : "关闭");
		}
		else if (StrEqual(info, "rock_lagcomp"))
		{
			g_cvRockLagComp.BoolValue = !g_cvRockLagComp.BoolValue;
			SavePersistentSettings();
			UpdateAllRockRenders();
			PrintToChat(client, "\x04[难度]\x01 Tank 石头空爆与延迟补偿已%s。", g_cvRockLagComp.BoolValue ? "开启" : "关闭");
		}
		else if (StrEqual(info, "tank_water_no_slowdown"))
		{
			g_cvTankWaterNoSlowdown.BoolValue = !g_cvTankWaterNoSlowdown.BoolValue;
			SavePersistentSettings();
			RefreshTankWaterNoSlowdownState(true);
			PrintToChat(client, "\x04[难度]\x01 Tank 战水中不减速已%s。", g_cvTankWaterNoSlowdown.BoolValue ? "开启" : "关闭");
		}
		else if (StrEqual(info, "tank_flying_incap"))
		{
			g_cvTankFlyingIncap.BoolValue = !g_cvTankFlyingIncap.BoolValue;
			ResetAllTankFlyingIncapState();
			SavePersistentSettings();
			PrintToChat(client, "\x04[难度]\x01 Tank 一拳致倒击飞已%s。", g_cvTankFlyingIncap.BoolValue ? "开启" : "关闭");
		}
		else if (StrEqual(info, "common_shove_fix"))
		{
			g_cvCommonShoveFix.BoolValue = !g_cvCommonShoveFix.BoolValue;
			SavePersistentSettings();
			PrintToChat(client, "\x04[难度]\x01 普通感染者推击修复已%s。", g_cvCommonShoveFix.BoolValue ? "开启" : "关闭");
		}
		else if (StrEqual(info, "multi_getup_fix"))
		{
			g_cvMultiGetupFix.BoolValue = !g_cvMultiGetupFix.BoolValue;
			ResetAllMultiGetupState();
			ResetAllMergedGetupState();
			SavePersistentSettings();
			PrintToChat(client, "\x04[难度]\x01 重复/遗漏起身修复（多人）已%s。", g_cvMultiGetupFix.BoolValue ? "开启" : "关闭");
		}

		ShowDifficultyMenu(client);
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	ResetAllHunterPounceState();
	ResetAllSmokerTongueState();
	g_bTankWaterNoSlowdownActive = false;
	ResetAllTankFlyingIncapState();
	ResetAllMultiGetupState();
	ResetAllMergedGetupState();
}

public void Event_TankSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if (g_cvTankWaterNoSlowdown.BoolValue && !g_bTankWaterNoSlowdownActive)
	{
		g_bTankWaterNoSlowdownActive = true;
		PrintToChatAll("\x04[难度]\x01 Tank 已出现：幸存者在水中不再减速。");
	}
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	ResetMultiGetupState(client);
	MergedGetupOnPlayerDeath(client);
	if (IsTankClient(client))
	{
		CreateTimer(0.1, Timer_CheckTankWaterNoSlowdown, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public void Event_PlayerIncapacitated(Event event, const char[] name, bool dontBroadcast)
{
	int survivor = GetClientOfUserId(event.GetInt("userid"));
	if (!g_cvTankFlyingIncap.BoolValue)
	{
		return;
	}

	if (IsSurvivor(survivor))
	{
		g_iIncapEventTick[survivor] = GetGameTickCount();
	}
}

public Action Timer_CheckTankWaterNoSlowdown(Handle timer)
{
	RefreshTankWaterNoSlowdownState(true);
	return Plugin_Stop;
}

// Tank 致倒事件与爪击回调在同一个游戏 Tick 内发生时，临时解除倒地状态，
// 让引擎应用原生的 Tank 拳击击飞；每位幸存者独立保存并恢复自己的状态。
public Action L4D_TankClaw_OnPlayerHit_Pre(int tank, int claw, int player)
{
	if (!g_cvTankFlyingIncap.BoolValue || !IsTank(tank) || !IsSurvivor(player)
		|| g_iIncapEventTick[player] != GetGameTickCount() || g_bTemporarilyClearedIncap[player])
	{
		return Plugin_Continue;
	}

	int incapState = GetEntProp(player, Prop_Send, "m_isIncapacitated");
	if (incapState == 0)
	{
		return Plugin_Continue;
	}

	g_iSavedIncapState[player] = incapState;
	g_bTemporarilyClearedIncap[player] = true;
	SetEntProp(player, Prop_Send, "m_isIncapacitated", 0);
	return Plugin_Continue;
}

public void L4D_TankClaw_OnPlayerHit_Post(int tank, int claw, int player)
{
	RestoreTankFlyingIncapState(player);
	MergedGetupProcessTankAttack(player);
}

public void L4D_TankClaw_OnPlayerHit_PostHandled(int tank, int claw, int player)
{
	RestoreTankFlyingIncapState(player);
	MergedGetupProcessTankAttack(player);
}

public void L4D_OnKnockedDown_Post(int client, int reason)
{
	if (reason == KNOCKDOWN_TANK)
	{
		MergedGetupProcessTankAttack(client);
	}
}

void RestoreTankFlyingIncapState(int client)
{
	if (client <= 0 || client > MaxClients || !g_bTemporarilyClearedIncap[client])
	{
		return;
	}

	if (IsSurvivor(client))
	{
		SetEntProp(client, Prop_Send, "m_isIncapacitated", g_iSavedIncapState[client]);
	}

	g_iSavedIncapState[client] = 0;
	g_bTemporarilyClearedIncap[client] = false;
}

void ResetAllTankFlyingIncapState()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		RestoreTankFlyingIncapState(client);
		g_iIncapEventTick[client] = 0;
	}
}

// 以下状态机来自 double_getup 的完整起身修复逻辑，但所有状态均按客户端而非角色模型保存。
// 因此多个 Nick、Ellis 或任意 4 人以上组合不会互相覆盖起身状态。
void ResetMultiGetupState(int client)
{
	if (client <= 0 || client > MaxClients)
	{
		return;
	}

	g_eGetupState[client] = Getup_Upright;
	g_iPendingGetups[client] = 0;
	g_bGetupInterrupted[client] = false;
	g_iGetupSequence[client] = 0;
}

void ResetAllMultiGetupState()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		ResetMultiGetupState(client);
	}
}

bool IsMultiGetupEnabled()
{
	return g_cvMultiGetupFix != null && g_cvMultiGetupFix.BoolValue;
}

int GetGetupAnimationIndex(int client)
{
	if (!IsSurvivor(client))
	{
		return -1;
	}

	switch (GetEntProp(client, Prop_Send, "m_Gender"))
	{
		case 7: return 0;  // Nick
		case 8: return 1;  // Rochelle
		case 9: return 2;  // Coach
		case 10: return 3; // Ellis
		case 3: return 4;  // Bill
		case 4: return 5;  // Zoey
		case 5: return 6;  // Francis
		case 6: return 7;  // Louis
	}

	return -1;
}

bool IsGetupInProgress(int client)
{
	switch (g_eGetupState[client])
	{
		case Getup_Hunter, Getup_Charger, Getup_MultiCharged, Getup_TankPunch, Getup_TankRock:
		{
			return true;
		}
	}
	return false;
}

void StartMultiGetupTimer(int client)
{
	if (IsSurvivor(client))
	{
		CreateTimer(GETUP_TIMER_INTERVAL, Timer_MultiGetup, GetClientUserId(client), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	}
}

void StartMultiGetupCancelTimer(int client)
{
	if (IsSurvivor(client))
	{
		CreateTimer(GETUP_TIMER_INTERVAL, Timer_MultiGetupCancel, GetClientUserId(client), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	}
}

void StartMultiGetupTankLandTimer(int client)
{
	if (IsSurvivor(client))
	{
		CreateTimer(GETUP_TIMER_INTERVAL, Timer_MultiGetupTankLand, GetClientUserId(client), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	}
}

stock void MultiGetupOnIncapacitated(int client)
{
	if (!IsMultiGetupEnabled() || !IsSurvivor(client))
	{
		return;
	}

	if (g_eGetupState[client] == Getup_InstantCharged)
	{
		g_iPendingGetups[client]++;
	}
	g_eGetupState[client] = Getup_Incapped;
}

public void Event_GetupTongueGrab(Event event, const char[] name, bool dontBroadcast)
{
	if (g_cvTongueFloatFix.BoolValue)
	{
		FixTongueFloat(GetClientOfUserId(event.GetInt("userid")));
	}

	MergedGetupOnTongueGrab(GetClientOfUserId(event.GetInt("victim")));
}

void FixTongueFloat(int smoker)
{
	if (smoker <= 0 || !IsClientInGame(smoker))
	{
		return;
	}

	int ability = GetEntPropEnt(smoker, Prop_Send, "m_customAbility");
	if (!IsValidEdict(ability) || !HasEntProp(ability, Prop_Send, "m_tongueVictimLastOnGroundTime"))
	{
		return;
	}

	SetEntPropFloat(ability, Prop_Send, "m_tongueVictimLastOnGroundTime", GetGameTime());
}

public void Event_GetupTongueRelease(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("victim"));
	if (!IsMultiGetupEnabled() || !IsSurvivor(client) || g_eGetupState[client] == Getup_Incapped)
	{
		return;
	}

	g_eGetupState[client] = Getup_Upright;
	StartMultiGetupCancelTimer(client);
}

public void Event_GetupPounceStopped(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("victim"));
	if (!IsMultiGetupEnabled() || !IsSurvivor(client) || g_eGetupState[client] == Getup_Incapped)
	{
		return;
	}

	if (IsGetupInProgress(client))
	{
		g_iPendingGetups[client]++;
		return;
	}

	g_eGetupState[client] = Getup_Hunter;
	StartMultiGetupTimer(client);
}

public void Event_GetupJockeyRide(Event event, const char[] name, bool dontBroadcast)
{
	MergedGetupOnJockeyRide(GetClientOfUserId(event.GetInt("victim")));
}

public void Event_GetupJockeyRideEnd(Event event, const char[] name, bool dontBroadcast)
{
	MergedGetupOnJockeyRideEnd(GetClientOfUserId(event.GetInt("victim")));
}

public void Event_GetupChargerImpact(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("victim"));
	if (IsMultiGetupEnabled() && IsSurvivor(client) && g_eGetupState[client] != Getup_Incapped)
	{
		g_eGetupState[client] = Getup_MultiCharged;
	}
}

public void Event_GetupChargerCarryEnd(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("victim"));
	if (!IsMultiGetupEnabled() || !IsSurvivor(client))
	{
		return;
	}

	if (g_eGetupState[client] == Getup_Incapped)
	{
		g_iPendingGetups[client]++;
	}
	g_eGetupState[client] = Getup_InstantCharged;
}

public void Event_GetupChargerPummelStart(Event event, const char[] name, bool dontBroadcast)
{
	MergedGetupOnChargerPummelStart(GetClientOfUserId(event.GetInt("userid")), GetClientOfUserId(event.GetInt("victim")));
}

public void Event_GetupChargerPummelEnd(Event event, const char[] name, bool dontBroadcast)
{
	MergedGetupOnChargerPummelEnd(GetClientOfUserId(event.GetInt("userid")), GetClientOfUserId(event.GetInt("victim")));
}

stock void MultiGetupStartChargerGetup(int client)
{
	if (!IsMultiGetupEnabled() || !IsSurvivor(client) || g_eGetupState[client] == Getup_Incapped)
	{
		return;
	}

	g_eGetupState[client] = Getup_Charger;
	StartMultiGetupTimer(client);
}

public void Event_GetupReviveSuccess(Event event, const char[] name, bool dontBroadcast)
{
	MergedGetupOnReviveSuccess(GetClientOfUserId(event.GetInt("subject")));
}

stock void MultiGetupOnTakeDamage(int victim, int inflictor)
{
	if (!IsMultiGetupEnabled() || !IsSurvivor(victim) || inflictor <= MaxClients || !IsValidEntity(inflictor))
	{
		return;
	}

	char classname[32];
	GetEdictClassname(inflictor, classname, sizeof(classname));
	if (StrEqual(classname, "weapon_tank_claw"))
	{
		if (g_eGetupState[victim] == Getup_Charger)
		{
			g_bGetupInterrupted[victim] = true;
		}
		else if (g_eGetupState[victim] == Getup_MultiCharged)
		{
			g_iPendingGetups[victim]++;
		}

		if (g_eGetupState[victim] == Getup_TankRock)
		{
			g_eGetupState[victim] = Getup_TankPunchAfterRock;
		}
		else if (g_eGetupState[victim] == Getup_Jockeyed)
		{
			g_eGetupState[victim] = Getup_TankPunchAfterJockey;
			StartMultiGetupTankLandTimer(victim);
		}
		else
		{
			g_eGetupState[victim] = Getup_TankPunchFly;
			StartMultiGetupTankLandTimer(victim);
		}
	}
	else if (StrEqual(classname, "tank_rock"))
	{
		if (g_eGetupState[victim] == Getup_Charger)
		{
			g_bGetupInterrupted[victim] = true;
		}
		else if (g_eGetupState[victim] == Getup_MultiCharged)
		{
			g_iPendingGetups[victim]++;
		}

		g_eGetupState[victim] = Getup_TankRock;
		StartMultiGetupTimer(victim);
	}
}

public Action Timer_MultiGetupTankLand(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (!IsMultiGetupEnabled() || !IsSurvivor(client)
		|| (g_eGetupState[client] != Getup_TankPunchFly && g_eGetupState[client] != Getup_TankPunchAfterJockey
			&& g_eGetupState[client] != Getup_TankPunch))
	{
		return Plugin_Stop;
	}

	int animationIndex = GetGetupAnimationIndex(client);
	if (animationIndex == -1)
	{
		return Plugin_Stop;
	}

	int sequence = GetEntProp(client, Prop_Send, "m_nSequence");
	if (sequence == g_iTankFlySequences[animationIndex] || sequence == g_iTankFlySequences[animationIndex] + 1
		|| (g_eGetupState[client] == Getup_TankPunchAfterJockey && sequence == g_iTankFlySequences[animationIndex] + 2))
	{
		return Plugin_Continue;
	}

	if (g_eGetupState[client] == Getup_TankPunchAfterJockey)
	{
		L4D2Direct_DoAnimationEvent(client, ANIM_TANK_PUNCH_GETUP);
	}
	if (g_eGetupState[client] == Getup_TankPunchFly)
	{
		g_eGetupState[client] = Getup_TankPunch;
	}

	L4D2Direct_DoAnimationEvent(client, ANIM_TANK_PUNCH_GETUP);
	StartMultiGetupTimer(client);
	return Plugin_Stop;
}

public Action Timer_MultiGetup(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (!IsMultiGetupEnabled() || !IsSurvivor(client)
		|| g_eGetupState[client] == Getup_Upright || g_eGetupState[client] == Getup_Incapped)
	{
		return Plugin_Stop;
	}

	if (g_iGetupSequence[client] == 0)
	{
		g_iGetupSequence[client] = GetEntProp(client, Prop_Send, "m_nSequence");
		g_iPendingGetups[client]++;
		return Plugin_Continue;
	}
	if (g_bGetupInterrupted[client])
	{
		g_bGetupInterrupted[client] = false;
		return Plugin_Stop;
	}
	if (g_iGetupSequence[client] == GetEntProp(client, Prop_Send, "m_nSequence"))
	{
		return Plugin_Continue;
	}

	if (g_eGetupState[client] == Getup_TankPunchAfterRock)
	{
		g_eGetupState[client] = Getup_TankPunch;
		g_iGetupSequence[client] = 0;
		L4D2Direct_DoAnimationEvent(client, ANIM_TANK_PUNCH_GETUP);
		StartMultiGetupTankLandTimer(client);
		return Plugin_Stop;
	}

	g_eGetupState[client] = Getup_Upright;
	g_iPendingGetups[client]--;
	StartMultiGetupCancelTimer(client);
	return Plugin_Stop;
}

public Action Timer_MultiGetupCancel(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (!IsMultiGetupEnabled() || !IsSurvivor(client))
	{
		return Plugin_Stop;
	}

	if (g_iPendingGetups[client] <= 0)
	{
		g_iPendingGetups[client] = 0;
		g_iGetupSequence[client] = 0;
		return Plugin_Stop;
	}

	g_iPendingGetups[client]--;
	SetEntPropFloat(client, Prop_Send, "m_flCycle", 1000.0);
	return Plugin_Continue;
}

public void Event_GetupPlayerBotReplace(Event event, const char[] name, bool dontBroadcast)
{
	MergedGetupHandlePlayerReplace(GetClientOfUserId(event.GetInt("bot")), GetClientOfUserId(event.GetInt("player")));
}

public void Event_GetupBotPlayerReplace(Event event, const char[] name, bool dontBroadcast)
{
	MergedGetupHandlePlayerReplace(GetClientOfUserId(event.GetInt("player")), GetClientOfUserId(event.GetInt("bot")));
}

stock void TransferMultiGetupState(int from, int to)
{
	if (!IsMultiGetupEnabled() || from <= 0 || to <= 0 || from > MaxClients || to > MaxClients || !IsSurvivor(to))
	{
		return;
	}

	g_eGetupState[to] = g_eGetupState[from];
	g_iPendingGetups[to] = g_iPendingGetups[from];
	g_bGetupInterrupted[to] = g_bGetupInterrupted[from];
	g_iGetupSequence[to] = 0;
	ResetMultiGetupState(from);

	if (g_eGetupState[to] == Getup_TankPunchFly || g_eGetupState[to] == Getup_TankPunchAfterJockey)
	{
		StartMultiGetupTankLandTimer(to);
	}
	else if (IsGetupInProgress(to) || g_eGetupState[to] == Getup_TankPunchAfterRock)
	{
		StartMultiGetupTimer(to);
	}
}

// 以下为 l4d2_getup_fixes 的完整修复逻辑。状态按客户端槽位保存，
// 因此重复角色、8 人以上以及玩家/Bot 互换均不会按模型串状态。
bool IsMergedGetupEnabled()
{
	return g_cvMultiGetupFix != null && g_cvMultiGetupFix.BoolValue;
}

void ResetMergedGetupState(int client)
{
	if (client <= 0 || client > MaxClients)
	{
		return;
	}

	g_iMergedGetupChargeVictim[client] = -1;
	g_iMergedGetupChargeAttacker[client] = -1;
	g_fMergedGetupLastChargedEndTime[client] = 0.0;
}

void ResetAllMergedGetupState()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		ResetMergedGetupState(client);
	}
}

void MergedGetupOnReviveSuccess(int client)
{
	if (!IsMergedGetupEnabled() || !IsSurvivor(client))
	{
		return;
	}

	MergedGetupAnimState animation = MergedGetupAnimState(client);
	animation.SetFlag(MergedGetup_GroundSlammed, false);
	animation.SetFlag(MergedGetup_WallSlammed, false);
	animation.SetFlag(MergedGetup_Pounded, false);
	animation.SetFlag(MergedGetup_Pounced, false);
}

void MergedGetupOnTongueGrab(int client)
{
	if (IsMergedGetupEnabled() && IsSurvivor(client))
	{
		MergedGetupAnimState(client).SetFlag(MergedGetup_Pounced, false);
	}
}

public void Event_MergedGetupLungePounce(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("victim"));
	if (!IsMergedGetupEnabled() || !IsSurvivor(client))
	{
		return;
	}

	MergedGetupAnimState animation = MergedGetupAnimState(client);
	animation.SetFlag(MergedGetup_TankPunched, false);
	animation.SetFlag(MergedGetup_Charged, false);
	animation.SetFlag(MergedGetup_Pounded, false);
	animation.SetFlag(MergedGetup_WallSlammed, false);
}

void MergedGetupOnJockeyRide(int client)
{
	if (!IsMergedGetupEnabled() || !IsSurvivor(client))
	{
		return;
	}

	MergedGetupAnimState animation = MergedGetupAnimState(client);
	animation.SetFlag(MergedGetup_Charged, false);
	animation.SetFlag(MergedGetup_WallSlammed, false);
}

void MergedGetupOnJockeyRideEnd(int client)
{
	if (IsMergedGetupEnabled() && IsSurvivor(client))
	{
		MergedGetupAnimState(client).SetFlag(MergedGetup_RiddenByJockey, false);
	}
}

public void Event_MergedGetupChargerCarryStart(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("victim"));
	if (!IsMergedGetupEnabled() || !IsSurvivor(victim))
	{
		return;
	}

	MergedGetupAnimState animation = MergedGetupAnimState(victim);
	animation.SetFlag(MergedGetup_TankPunched, false);
	animation.SetFlag(MergedGetup_Charged, false);
	animation.SetFlag(MergedGetup_Pounded, false);
	animation.SetFlag(MergedGetup_GroundSlammed, false);
	animation.SetFlag(MergedGetup_WallSlammed, false);
}

void MergedGetupOnPlayerDeath(int client)
{
	if (client <= 0 || client > MaxClients)
	{
		return;
	}

	int attacker = g_iMergedGetupChargeAttacker[client];
	if (attacker > 0 && attacker <= MaxClients)
	{
		g_iMergedGetupChargeVictim[attacker] = -1;
	}
	ResetMergedGetupState(client);
}

void MergedGetupOnChargerPummelStart(int charger, int victim)
{
	if (!IsMergedGetupEnabled() || charger <= 0 || charger > MaxClients || !IsSurvivor(victim))
	{
		return;
	}

	g_iMergedGetupChargeVictim[charger] = victim;
	g_iMergedGetupChargeAttacker[victim] = charger;
}

void MergedGetupOnChargerPummelEnd(int charger, int victim)
{
	if (!IsMergedGetupEnabled() || charger <= 0 || charger > MaxClients || !IsSurvivor(victim))
	{
		return;
	}

	MergedGetupAnimState animation = MergedGetupAnimState(victim);
	animation.SetFlag(MergedGetup_TankPunched, false);
	animation.SetFlag(MergedGetup_Pounced, false);
	g_iMergedGetupChargeVictim[charger] = -1;
	g_iMergedGetupChargeAttacker[victim] = -1;
	g_fMergedGetupLastChargedEndTime[victim] = GetGameTime();
}

public void Event_MergedGetupChargerKilled(Event event, const char[] name, bool dontBroadcast)
{
	if (!IsMergedGetupEnabled())
	{
		return;
	}

	int charger = GetClientOfUserId(event.GetInt("userid"));
	if (charger <= 0 || charger > MaxClients)
	{
		return;
	}

	int victim = g_iMergedGetupChargeVictim[charger];
	if (!IsSurvivor(victim))
	{
		return;
	}

	MergedGetupAnimState animation = MergedGetupAnimState(victim);
	if (GetEntPropEnt(victim, Prop_Send, "m_pounceAttacker") != -1)
	{
		animation.SetFlag(MergedGetup_GroundSlammed, false);
		animation.SetFlag(MergedGetup_WallSlammed, false);
	}
	else
	{
		int attacker = GetClientOfUserId(event.GetInt("attacker"));
		if (attacker != 0 && attacker == victim)
		{
			if (!L4D_IsPlayerIncapacitated(victim))
			{
				animation.SetFlag(MergedGetup_GroundSlammed, false);
				animation.SetFlag(MergedGetup_WallSlammed, false);
			}
		}
		else
		{
			float elapsedAnimationTime = 0.0;
			bool keepLongGetup = (animation.GetFlag(MergedGetup_GroundSlammed)
				&& ((elapsedAnimationTime = 119.0 / 30.0), g_cvMergedGetupKeepLongCharge.BoolValue))
				|| (animation.GetFlag(MergedGetup_WallSlammed)
				&& ((elapsedAnimationTime = 116.0 / 30.0), g_cvMergedGetupKeepWallSlam.BoolValue));

			if (keepLongGetup)
			{
				elapsedAnimationTime *= GetEntPropFloat(victim, Prop_Send, "m_flCycle");
				MergedGetupSetInvulnerable(victim, g_cvMergedGetupLongChargeDuration.FloatValue - elapsedAnimationTime);
			}
			else
			{
				if (animation.GetFlag(MergedGetup_GroundSlammed) || animation.GetFlag(MergedGetup_WallSlammed))
				{
					ConVar normalDuration = FindConVar("gfc_charger_duration");
					MergedGetupSetInvulnerable(victim, normalDuration == null ? 2.0 : normalDuration.FloatValue);
				}
				L4D2Direct_DoAnimationEvent(victim, ANIM_CHARGER_GETUP);
			}

			g_fMergedGetupLastChargedEndTime[victim] = GetGameTime();
		}
	}

	g_iMergedGetupChargeVictim[charger] = -1;
	g_iMergedGetupChargeAttacker[victim] = -1;
}

public void L4D2_OnSlammedSurvivor_Post(int victim, int attacker, bool wallSlam, bool deadlyCharge)
{
	if (!IsMergedGetupEnabled() || !IsSurvivor(victim) || attacker <= 0 || attacker > MaxClients)
	{
		return;
	}

	g_iMergedGetupChargeVictim[attacker] = victim;
	g_iMergedGetupChargeAttacker[victim] = attacker;

	MergedGetupAnimState animation = MergedGetupAnimState(victim);
	animation.SetFlag(MergedGetup_Pounded, false);
	animation.SetFlag(MergedGetup_Charged, false);
	animation.SetFlag(MergedGetup_TankPunched, false);
	animation.SetFlag(MergedGetup_Pounced, false);
	animation.ResetMainActivity();

	if (!IsClientInGame(attacker) || !IsPlayerAlive(attacker))
	{
		Event chargerKilled = CreateEvent("charger_killed");
		chargerKilled.SetInt("userid", GetClientUserId(attacker));
		Event_MergedGetupChargerKilled(chargerKilled, "charger_killed", false);
		chargerKilled.Cancel();
	}
}

void MergedGetupSetInvulnerable(int client, float duration)
{
	if (!IsPlayerAlive(client) || duration <= 0.0)
	{
		return;
	}

	if (LibraryExists("l4d2_godframes_control_merge"))
	{
		GiveClientGodFrames(client, duration, 8);
		return;
	}

	CountdownTimer timer = L4D2Direct_GetInvulnerabilityTimer(client);
	if (timer != CTimer_Null)
	{
		CTimer_Start(timer, duration);
	}
}

void MergedGetupProcessTankAttack(int victim)
{
	if (!IsMergedGetupEnabled() || !IsSurvivor(victim) || L4D_IsPlayerIncapacitated(victim)
		|| GetEntPropEnt(victim, Prop_Send, "m_pummelAttacker") != -1)
	{
		return;
	}

	MergedGetupAnimState animation = MergedGetupAnimState(victim);
	animation.SetFlag(MergedGetup_Charged, false);
	if (GetGameTime() - g_fMergedGetupLastChargedEndTime[victim] <= 0.1)
	{
		animation.SetFlag(MergedGetup_TankPunched, false);
	}
	else
	{
		animation.SetFlag(MergedGetup_GroundSlammed, false);
		animation.SetFlag(MergedGetup_WallSlammed, false);
		animation.SetFlag(MergedGetup_Pounded, false);
		animation.ResetMainActivity();
	}
}

void MergedGetupHandlePlayerReplace(int replacer, int replacee)
{
	if (!IsMergedGetupEnabled() || replacer <= 0 || replacer > MaxClients || replacee <= 0 || replacee > MaxClients
		|| !IsClientInGame(replacer) || !IsClientInGame(replacee))
	{
		return;
	}

	if (GetClientTeam(replacer) == TEAM_INFECTED)
	{
		int victim = g_iMergedGetupChargeVictim[replacee];
		if (victim > 0 && victim <= MaxClients)
		{
			g_iMergedGetupChargeVictim[replacer] = victim;
			g_iMergedGetupChargeAttacker[victim] = replacer;
		}
	}
	else
	{
		int attacker = g_iMergedGetupChargeAttacker[replacee];
		if (attacker > 0 && attacker <= MaxClients)
		{
			g_iMergedGetupChargeAttacker[replacer] = attacker;
			g_iMergedGetupChargeVictim[attacker] = replacer;
		}
	}
	ResetMergedGetupState(replacee);
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client > 0)
	{
		ResetHunterPounceState(client);
		ResetSmokerTongueState(client);
		g_iIncapEventTick[client] = 0;
		ResetMultiGetupState(client);
		ResetMergedGetupState(client);
	}
}

// 只在 Tank 战期间覆盖幸存者的水中跑速；其余减速项目均保持游戏原样。
public Action L4D_OnGetRunTopSpeed(int client, float &retVal)
{
	if (!g_bTankWaterNoSlowdownActive || !g_cvTankWaterNoSlowdown.BoolValue || !IsSurvivor(client)
		|| !IsPlayerAlive(client) || !(GetEntityFlags(client) & FL_INWATER))
	{
		return Plugin_Continue;
	}

	// 被 Smoker 控制的移动速度由 tongue_victim_max_speed 决定，不应在这里覆盖。
	if (GetEntPropEnt(client, Prop_Send, "m_tongueOwner") != -1)
	{
		return Plugin_Continue;
	}

	float health = L4D_GetTempHealth(client) + GetClientHealth(client);
	if (GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") != -1)
	{
		int maximumHealth = GetEntProp(client, Prop_Send, "m_iMaxHealth");
		if (maximumHealth <= 0 || g_cvJockeyMinMountedSpeed == null)
		{
			return Plugin_Continue;
		}

		float healthRate = health / float(maximumHealth);
		float minimumRate = g_cvJockeyMinMountedSpeed.FloatValue;
		retVal = SURVIVOR_RUNSPEED * (healthRate > minimumRate ? healthRate : minimumRate);
		return Plugin_Handled;
	}

	// 肾上腺素和残血跛行原本就不受水中减速影响，继续使用引擎原速度。
	if (GetEntProp(client, Prop_Send, "m_bAdrenalineActive") || g_cvSurvivorLimpHealth == null
		|| RoundToFloor(health) < g_cvSurvivorLimpHealth.IntValue)
	{
		return Plugin_Continue;
	}

	retVal = SURVIVOR_RUNSPEED;
	return Plugin_Handled;
}

void RefreshTankWaterNoSlowdownState(bool announce)
{
	bool shouldBeActive = g_cvTankWaterNoSlowdown.BoolValue && HasLivingTank();
	if (shouldBeActive == g_bTankWaterNoSlowdownActive)
	{
		return;
	}

	g_bTankWaterNoSlowdownActive = shouldBeActive;
	if (!announce)
	{
		return;
	}

	if (shouldBeActive)
	{
		PrintToChatAll("\x04[难度]\x01 Tank 已出现：幸存者在水中不再减速。");
	}
	else
	{
		PrintToChatAll("\x04[难度]\x01 Tank 已死亡：幸存者恢复正常水中减速。");
	}
}

bool HasLivingTank()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsTank(client))
		{
			return true;
		}
	}

	return false;
}

// 仅替换 Charger 正在锤击其倒地抓取目标时的单次伤害；不影响冲撞、撞飞或普通爪击。
public Action Hook_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damageType, int &weapon, float damageForce[3], float damagePosition[3])
{
	if (!g_cvChargerIncapPummel.BoolValue || damageType != DMG_CLUB || g_cvChargerPoundDamage == null)
	{
		return Plugin_Continue;
	}

	if (FloatAbs(damage - g_cvChargerPoundDamage.FloatValue) > 0.01 || !IsSurvivor(victim)
		|| !GetEntProp(victim, Prop_Send, "m_isIncapacitated"))
	{
		return Plugin_Continue;
	}

	if (attacker <= 0 || attacker > MaxClients || !IsClientInGame(attacker) || GetClientTeam(attacker) != TEAM_INFECTED
		|| GetEntProp(attacker, Prop_Send, "m_zombieClass") != Z_CHARGER)
	{
		return Plugin_Continue;
	}

	if (GetEntPropEnt(attacker, Prop_Send, "m_pummelVictim") != victim)
	{
		return Plugin_Continue;
	}

	damage = CHARGER_INCAP_PUMMEL_DAMAGE;
	return Plugin_Changed;
}

// 近战命中 Tank 时，按原 l4d2_tank_melee_fury 的规则同时提前主、副攻击时间。
// 不设下限或叠加上限：连续近战命中会持续将两个可攻击时间向前推进。
public void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_cvTankMeleeFury.BoolValue || g_cvTankSwingInterval == null || g_cvTankWindupTime == null)
	{
		return;
	}

	int tank = GetClientOfUserId(event.GetInt("userid"));
	int survivor = GetClientOfUserId(event.GetInt("attacker"));
	if (!IsSurvivor(survivor) || !IsTank(tank))
	{
		return;
	}

	char weaponName[64];
	event.GetString("weapon", weaponName, sizeof(weaponName));
	if (!StrEqual(weaponName, "weapon_melee", false) && !StrEqual(weaponName, "melee", false))
	{
		return;
	}

	int tankClaw = GetEntPropEnt(tank, Prop_Send, "m_hActiveWeapon");
	if (tankClaw == -1 || !IsValidEntity(tankClaw))
	{
		return;
	}

	float cooldownReduction = g_cvTankSwingInterval.FloatValue + g_cvTankWindupTime.FloatValue;
	SetEntPropFloat(tankClaw, Prop_Send, "m_flNextPrimaryAttack", GetEntPropFloat(tankClaw, Prop_Send, "m_flNextPrimaryAttack") - cooldownReduction);
	SetEntPropFloat(tankClaw, Prop_Send, "m_flNextSecondaryAttack", GetEntPropFloat(tankClaw, Prop_Send, "m_flNextSecondaryAttack") - cooldownReduction);
}

// Tank 石头空爆与延迟补偿：保留原 l4d_rock_lagcomp 的位置回溯、自定义耐久、
// 枪械属性伤害、初始保护和空爆处理。总开关关闭时完全交还原版石头判定。
public Action OnRockTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damageType)
{
	if (!g_cvRockLagComp.BoolValue)
	{
		return Plugin_Continue;
	}

	float incomingDamage = damage;
	damage = 0.0;
	if (!IsSurvivor(attacker))
	{
		return Plugin_Handled;
	}

	int rockIndex = FindTrackedRock(EntIndexToEntRef(victim));
	if (rockIndex == -1 || !IsRockDamageAllowed(rockIndex))
	{
		return Plugin_Handled;
	}

	char weaponName[64];
	if (!GetNativeDamageWeaponName(attacker, inflictor, weaponName, sizeof(weaponName)))
	{
		return Plugin_Handled;
	}

	// 命中扫描武器在 weapon_fire 中按回溯位置处理；这里阻止原版重复扣血。
	if (IsHitscanWeaponName(weaponName) || incomingDamage <= 0.0)
	{
		return Plugin_Handled;
	}

	float eyePosition[3];
	float rockPosition[3];
	GetClientEyePosition(attacker, eyePosition);
	GetEntPropVector(victim, Prop_Send, "m_vecOrigin", rockPosition);
	ApplyDamageToRock(rockIndex, EntIndexToEntRef(victim), incomingDamage, 0.0, 1.0, GetVectorDistance(eyePosition, rockPosition), true);
	return Plugin_Handled;
}

public Action Event_WeaponFire(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_cvRockLagComp.BoolValue || g_aRockEntities == null || g_aRockEntities.Length == 0)
	{
		return Plugin_Continue;
	}

	int survivor = GetClientOfUserId(event.GetInt("userid"));
	if (!IsSurvivor(survivor))
	{
		return Plugin_Continue;
	}

	char weaponName[64];
	event.GetString("weapon", weaponName, sizeof(weaponName));
	NormalizeWeaponName(weaponName, weaponName, sizeof(weaponName));

	float weaponDamage;
	float weaponRange;
	float weaponRangeModifier;
	if (!GetHitscanWeaponAttributes(weaponName, weaponDamage, weaponRange, weaponRangeModifier))
	{
		return Plugin_Continue;
	}

	float eyeAngles[3];
	float eyePosition[3];
	float direction[3];
	GetClientEyeAngles(survivor, eyeAngles);
	GetClientEyePosition(survivor, eyePosition);
	GetAngleVectors(eyeAngles, direction, NULL_VECTOR, NULL_VECTOR);

	float lagTime = IsFakeClient(survivor) ? 0.0 : GetClientLatency(survivor, NetFlow_Both) + GetClientInterp(survivor);
	int rollbackTick = GetGameTickCount() - RoundToNearest(lagTime / GetTickInterval());
	int historyIndex = GetHistoryIndex(rollbackTick);

	for (int i = g_aRockEntities.Length - 1; i >= 0; i--)
	{
		int rockRef = g_aRockEntities.Get(i, ROCK_BLOCK_ENT_REF);
		int rock = EntRefToEntIndex(rockRef);
		if (rock == INVALID_ENT_REFERENCE || !IsValidEntity(rock))
		{
			RemoveTrackedRockByIndex(i);
			continue;
		}

		if (!IsRockDamageAllowed(i))
		{
			continue;
		}

		float center[3];
		ArrayList history = view_as<ArrayList>(g_aRockEntities.Get(i, ROCK_BLOCK_POS_HISTORY));
		history.GetArray(historyIndex, center, sizeof(center));
		if (RayIntersectsSphere(eyePosition, direction, center, g_cvRockHitboxRadius.FloatValue))
		{
			ApplyDamageToRock(i, rockRef, weaponDamage, weaponRange, weaponRangeModifier, GetVectorDistance(eyePosition, center), false);
		}
	}

	return Plugin_Continue;
}

void MarkRockReleased(int rock, const float position[3])
{
	if (rock <= MaxClients || !IsValidEntity(rock))
	{
		return;
	}

	int rockRef = EntIndexToEntRef(rock);
	int rockIndex = FindTrackedRock(rockRef);
	if (rockIndex == -1)
	{
		SDKHook(rock, SDKHook_OnTakeDamage, OnRockTakeDamage);
		AddTrackedRock(rockRef);
		rockIndex = FindTrackedRock(rockRef);
	}

	if (rockIndex == -1)
	{
		return;
	}

	g_aRockEntities.Set(rockIndex, 1, ROCK_BLOCK_RELEASED);
	SeedRockHistory(rockIndex, position);
	UpdateRockRender(rockIndex);
}

void NormalizeWeaponName(const char[] input, char[] output, int maxlen)
{
	char weaponName[64];
	strcopy(weaponName, sizeof(weaponName), input);
	TrimString(weaponName);
	StripQuotes(weaponName);
	StringToLowerCase(weaponName);
	if (strncmp(weaponName, "weapon_", 7, false) == 0)
	{
		strcopy(weaponName, sizeof(weaponName), weaponName[7]);
	}

	strcopy(output, maxlen, weaponName);
}

bool GetNativeDamageWeaponName(int attacker, int inflictor, char[] weaponName, int maxlen)
{
	char classname[64];
	if (inflictor > MaxClients && IsValidEntity(inflictor) && GetEntityClassname(inflictor, classname, sizeof(classname)))
	{
		NormalizeWeaponName(classname, weaponName, maxlen);
		if (IsMountedGunWeaponName(weaponName))
		{
			return true;
		}
	}

	int activeWeapon = GetEntPropEnt(attacker, Prop_Send, "m_hActiveWeapon");
	if (activeWeapon > MaxClients && IsValidEntity(activeWeapon) && GetEntityClassname(activeWeapon, classname, sizeof(classname)))
	{
		NormalizeWeaponName(classname, weaponName, maxlen);
		return weaponName[0] != '\0';
	}

	return false;
}

bool GetHitscanWeaponAttributes(const char[] weaponName, float &damage, float &range, float &rangeModifier)
{
	char normalized[64];
	NormalizeWeaponName(weaponName, normalized, sizeof(normalized));
	if (!IsWeaponAttributeReadable(normalized))
	{
		return false;
	}

	int weaponType = L4D2_GetIntWeaponAttribute(normalized, L4D2IWA_WeaponType);
	if (!IsHitscanWeaponType(weaponType))
	{
		return false;
	}

	int baseDamage = L4D2_GetIntWeaponAttribute(normalized, L4D2IWA_Damage);
	if (baseDamage <= 0)
	{
		return false;
	}

	int bullets = L4D2_GetIntWeaponAttribute(normalized, L4D2IWA_Bullets);
	if (bullets < 1)
	{
		bullets = 1;
	}

	damage = float(baseDamage * bullets);
	range = L4D2_GetFloatWeaponAttribute(normalized, L4D2FWA_Range);
	rangeModifier = L4D2_GetFloatWeaponAttribute(normalized, L4D2FWA_RangeModifier);
	return range > 0.0;
}

bool IsHitscanWeaponName(const char[] weaponName)
{
	char normalized[64];
	NormalizeWeaponName(weaponName, normalized, sizeof(normalized));
	return IsWeaponAttributeReadable(normalized) && IsHitscanWeaponType(L4D2_GetIntWeaponAttribute(normalized, L4D2IWA_WeaponType));
}

bool IsWeaponAttributeReadable(const char[] weaponName)
{
	return weaponName[0] != '\0' && L4D_GetWeaponID(weaponName) != -1 && L4D2_IsValidWeapon(weaponName);
}

bool IsHitscanWeaponType(int weaponType)
{
	return weaponType == view_as<int>(WEAPONTYPE_PISTOL)
		|| weaponType == view_as<int>(WEAPONTYPE_SMG)
		|| weaponType == view_as<int>(WEAPONTYPE_RIFLE)
		|| weaponType == view_as<int>(WEAPONTYPE_SHOTGUN)
		|| weaponType == view_as<int>(WEAPONTYPE_SNIPERRIFLE)
		|| weaponType == view_as<int>(WEAPONTYPE_MACHINEGUN);
}

bool IsMountedGunWeaponName(const char[] weaponName)
{
	return StrEqual(weaponName, "prop_minigun") || StrEqual(weaponName, "prop_minigun_l4d1") || StrEqual(weaponName, "prop_mounted_machine_gun");
}

float GetClientInterp(int client)
{
	char buffer[32];
	GetClientInfo(client, "cl_interp", buffer, sizeof(buffer));
	return Clamp(StringToFloat(buffer), 0.0, 0.5);
}

bool RayIntersectsSphere(const float origin[3], const float direction[3], const float center[3], float radius)
{
	float originMinusCenter[3];
	SubtractVectors(origin, center, originMinusCenter);
	float dot = GetVectorDotProduct(direction, originMinusCenter);
	float delta = dot * dot - GetVectorLength(originMinusCenter, true) + radius * radius;
	if (delta < 0.0)
	{
		return false;
	}

	float firstHit = -dot - SquareRoot(delta);
	float secondHit = -dot + SquareRoot(delta);
	return firstHit >= 0.0 || secondHit >= 0.0;
}

void ApplyDamageToRock(int rockIndex, int rockRef, float weaponDamage, float weaponRange, float weaponRangeModifier, float distance, bool nativeDamage)
{
	if (rockIndex < 0 || rockIndex >= g_aRockEntities.Length || g_aRockEntities.Get(rockIndex, ROCK_BLOCK_DETONATING))
	{
		return;
	}

	if (distance <= 0.0)
	{
		distance = 1.0;
	}

	if (weaponDamage <= 0.0 || !IsRockDistanceAllowed(distance, weaponRange, nativeDamage))
	{
		return;
	}

	float appliedDamage = weaponDamage;
	if (!nativeDamage && weaponRangeModifier > 0.0 && weaponRangeModifier < 1.0)
	{
		appliedDamage *= Pow(weaponRangeModifier, distance / 500.0);
	}

	float rockDamage = g_aRockEntities.Get(rockIndex, ROCK_BLOCK_DAMAGE_DEALT) + appliedDamage;
	if (rockDamage >= ROCK_HEALTH)
	{
		g_aRockEntities.Set(rockIndex, 1, ROCK_BLOCK_DETONATING);
		RequestFrame(FrameDetonateRock, rockRef);
		return;
	}

	g_aRockEntities.Set(rockIndex, rockDamage, ROCK_BLOCK_DAMAGE_DEALT);
}

bool IsRockDistanceAllowed(float distance, float weaponRange, bool nativeDamage)
{
	float maximumRange = g_cvRockRangeMax.FloatValue;
	if (maximumRange > 0.0 && distance > maximumRange)
	{
		return false;
	}
	if (!nativeDamage && distance < g_cvRockRangeMin.FloatValue)
	{
		return false;
	}

	return weaponRange <= 0.0 || distance <= weaponRange;
}

void FrameDetonateRock(any rockRef)
{
	int rock = EntRefToEntIndex(rockRef);
	if (rock != INVALID_ENT_REFERENCE && IsValidEntity(rock))
	{
		L4D_DetonateProjectile(rock);
	}
}

void AddTrackedRock(int rockRef)
{
	if (FindTrackedRock(rockRef) != -1)
	{
		return;
	}

	int index = g_aRockEntities.Push(rockRef);
	ArrayList history = new ArrayList(3, ROCK_HISTORY_FRAMES);
	g_aRockEntities.Set(index, history, ROCK_BLOCK_POS_HISTORY);
	g_aRockEntities.Set(index, 0.0, ROCK_BLOCK_DAMAGE_DEALT);
	g_aRockEntities.Set(index, GetGameTime(), ROCK_BLOCK_SPAWN_TIME);
	g_aRockEntities.Set(index, 0, ROCK_BLOCK_RELEASED);
	g_aRockEntities.Set(index, 0, ROCK_BLOCK_DETONATING);

	float position[3];
	int rock = EntRefToEntIndex(rockRef);
	if (rock != INVALID_ENT_REFERENCE && IsValidEntity(rock))
	{
		GetEntPropVector(rock, Prop_Send, "m_vecOrigin", position);
	}
	SeedRockHistory(index, position);
}

void RemoveTrackedRock(int rockRef)
{
	int index = FindTrackedRock(rockRef);
	if (index != -1)
	{
		RemoveTrackedRockByIndex(index);
	}
}

void RemoveTrackedRockByIndex(int index)
{
	ArrayList history = view_as<ArrayList>(g_aRockEntities.Get(index, ROCK_BLOCK_POS_HISTORY));
	delete history;
	g_aRockEntities.Erase(index);
}

void ClearTrackedRocks()
{
	if (g_aRockEntities == null)
	{
		return;
	}

	for (int i = g_aRockEntities.Length - 1; i >= 0; i--)
	{
		RemoveTrackedRockByIndex(i);
	}
}

int FindTrackedRock(int rockRef)
{
	if (g_aRockEntities == null)
	{
		return -1;
	}

	for (int i = 0; i < g_aRockEntities.Length; i++)
	{
		if (g_aRockEntities.Get(i, ROCK_BLOCK_ENT_REF) == rockRef)
		{
			return i;
		}
	}

	return -1;
}

void SeedRockHistory(int rockIndex, const float position[3])
{
	ArrayList history = view_as<ArrayList>(g_aRockEntities.Get(rockIndex, ROCK_BLOCK_POS_HISTORY));
	for (int i = 0; i < ROCK_HISTORY_FRAMES; i++)
	{
		history.SetArray(i, position, sizeof(position));
	}
}

bool IsRockDamageAllowed(int rockIndex)
{
	if (g_aRockEntities.Get(rockIndex, ROCK_BLOCK_RELEASED) != 0)
	{
		return true;
	}

	float fallbackTime = g_cvRockGodframes.FloatValue;
	return fallbackTime <= 0.0 || GetGameTime() - g_aRockEntities.Get(rockIndex, ROCK_BLOCK_SPAWN_TIME) >= fallbackTime;
}

void UpdateAllRockRenders()
{
	if (g_aRockEntities == null)
	{
		return;
	}

	for (int i = 0; i < g_aRockEntities.Length; i++)
	{
		UpdateRockRender(i);
	}
}

void UpdateRockRenderByRef(int rockRef)
{
	int index = FindTrackedRock(rockRef);
	if (index != -1)
	{
		UpdateRockRender(index);
	}
}

void UpdateRockRender(int rockIndex)
{
	int rockRef = g_aRockEntities.Get(rockIndex, ROCK_BLOCK_ENT_REF);
	int rock = EntRefToEntIndex(rockRef);
	if (rock == INVALID_ENT_REFERENCE || !IsValidEntity(rock))
	{
		return;
	}

	if (g_cvRockLagComp.BoolValue && g_cvRockGodframesRender.BoolValue && !IsRockDamageAllowed(rockIndex))
	{
		SetEntityRenderMode(rock, RENDER_TRANSCOLOR);
		SetEntityRenderColor(rock, 255, 255, 255, 200);
		return;
	}

	SetEntityRenderMode(rock, RENDER_NORMAL);
	SetEntityRenderColor(rock, 255, 255, 255, 255);
}

int GetHistoryIndex(int tick)
{
	int index = tick % ROCK_HISTORY_FRAMES;
	return index < 0 ? index + ROCK_HISTORY_FRAMES : index;
}

bool IsRock(int entity)
{
	if (entity <= MaxClients || !IsValidEntity(entity))
	{
		return false;
	}

	char classname[32];
	GetEntityClassname(entity, classname, sizeof(classname));
	return StrEqual(classname, "tank_rock");
}

void StringToLowerCase(char[] text)
{
	for (int i = 0; i < strlen(text); i++)
	{
		text[i] = CharToLower(text[i]);
	}
}

float Clamp(float value, float valueMin, float valueMax)
{
	if (value < valueMin)
	{
		return valueMin;
	}
	return value > valueMax ? valueMax : value;
}

// 仅摘取 AI_HardSI_new 的 Hunter 行为：不包含其中的全局 nb_assault 定时器，
// 因此可与 aggresive_specials_patch 的 Director 强攻逻辑并用。
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float velocity[3], float angles[3], int &weapon)
{
	Action result = Plugin_Continue;

	if (g_cvAiHunterPounce.BoolValue && IsAiHunter(client))
	{
		result = HandleAiHunterPounce(client, buttons, velocity, angles);
	}

	if (g_cvAiSmokerTongue.BoolValue && IsAiSmoker(client))
	{
		Action smokerResult = HandleAiSmokerTongue(client, buttons, angles);
		if (smokerResult != Plugin_Continue)
		{
			result = smokerResult;
		}
	}

	return result;
}

// 仅保留 ai_smoker_new 的主动伸舌部分：AI 对可见的当前目标进行胸口瞄准，
// 并在合理距离内主动按下舌头技能键。不包含连跳、传送或目标策略重写。
Action HandleAiSmokerTongue(int smoker, int &buttons, float angles[3])
{
	if (GetEntPropEnt(smoker, Prop_Send, "m_tongueVictim") > 0 || L4D_IsPlayerStaggering(smoker))
	{
		return Plugin_Continue;
	}

	int target = GetClientAimTarget(smoker, true);
	if (!IsMobileSurvivor(target) || !view_as<bool>(GetEntProp(smoker, Prop_Send, "m_hasVisibleThreats")))
	{
		return Plugin_Continue;
	}

	float smokerPosition[3];
	float targetPosition[3];
	GetClientAbsOrigin(smoker, smokerPosition);
	GetClientAbsOrigin(target, targetPosition);
	float distance = GetVectorDistance(smokerPosition, targetPosition);

	AimAtSurvivorChest(smoker, target, angles);
	TeleportEntity(smoker, NULL_VECTOR, angles, NULL_VECTOR);

	if (GetGameTime() < g_fSmokerNextTongue[smoker])
	{
		return Plugin_Changed;
	}

	float maximumTongueDistance = g_cvTongueRange.FloatValue * SMOKER_TONGUE_DISTANCE_PERCENT;
	if (distance > 0.0 && distance < maximumTongueDistance)
	{
		buttons |= IN_ATTACK2;
		g_fSmokerNextTongue[smoker] = GetGameTime() + SMOKER_TONGUE_COMMAND_INTERVAL;
		return Plugin_Changed;
	}

	return Plugin_Changed;
}

void AimAtSurvivorChest(int attacker, int target, float angles[3])
{
	float attackerEyePosition[3];
	float targetPosition[3];
	float direction[3];
	GetClientEyePosition(attacker, attackerEyePosition);
	GetClientAbsOrigin(target, targetPosition);
	targetPosition[2] += 45.0;
	MakeVectorFromPoints(attackerEyePosition, targetPosition, direction);
	GetVectorAngles(direction, angles);
	angles[2] = 0.0;
}

void ResetAllSmokerTongueState()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		ResetSmokerTongueState(client);
	}
}

void ResetSmokerTongueState(int client)
{
	if (client > 0 && client <= MaxClients)
	{
		g_fSmokerNextTongue[client] = 0.0;
	}
}

Action HandleAiHunterPounce(int hunter, int &buttons, float velocity[3], float angles[3])
{
	Action result = Plugin_Continue;
	bool internalAttack = false;

	if (!HunterDelayExpired(hunter, 1, HUNTER_ASSAULT_DURATION) && GetEntityMoveType(hunter) != MOVETYPE_LADDER)
	{
		buttons |= IN_DUCK;
		if (GetRandomInt(0, HUNTER_REPEAT_ATTACK_CHANCE - 1) == 0)
		{
			buttons |= IN_ATTACK;
			internalAttack = true;
		}
		result = Plugin_Changed;
	}

	if (!(GetEntityFlags(hunter) & FL_ONGROUND))
	{
		if (g_iHunterState[hunter][2] == 0)
		{
			HunterDelayStart(hunter, 2);
			g_iHunterState[hunter][1] = 0;
			g_iHunterState[hunter][2] = 1;
		}

		if (g_iHunterState[hunter][0] == IN_FORWARD)
		{
			buttons |= IN_FORWARD;
			velocity[0] = HUNTER_AIR_SPEED;
			if (g_iHunterState[hunter][1] == 0 && HunterDelayExpired(hunter, 2, 0.2))
			{
				if (angles[2] == 0.0)
				{
					angles[0] = GetRandomFloat(-50.0, 20.0);
					TeleportEntity(hunter, NULL_VECTOR, angles, NULL_VECTOR);
				}
				g_iHunterState[hunter][1] = 1;
			}
			result = Plugin_Changed;
		}
	}
	else
	{
		g_iHunterState[hunter][2] = 0;
	}

	if (HunterDelayExpired(hunter, 0, 0.1) && (buttons & IN_ATTACK) && (GetEntityFlags(hunter) & FL_ONGROUND))
	{
		float distance = NearestMobileSurvivorDistance(hunter);
		HunterDelayStart(hunter, 0);

		if (!internalAttack && !(buttons & IN_BACK) && distance >= 0.0 && distance < 1000.0 && HunterDelayExpired(hunter, 1, HUNTER_ASSAULT_DURATION + HUNTER_ATTACK_COOLDOWN))
		{
			HunterDelayStart(hunter, 1);
		}

		if (GetRandomInt(0, 1) == 0 && distance >= 0.0 && distance < 1000.0)
		{
			if (angles[2] == 0.0)
			{
				angles[0] = GetRandomInt(0, 4) != 0 ? GetRandomFloat(10.0, 30.0) : GetRandomFloat(-30.0, -10.0);
				TeleportEntity(hunter, NULL_VECTOR, angles, NULL_VECTOR);
			}
			g_iHunterState[hunter][0] = IN_FORWARD;
		}
		else
		{
			g_iHunterState[hunter][0] = 0;
		}

		result = Plugin_Changed;
	}

	return result;
}

void ResetAllHunterPounceState()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		ResetHunterPounceState(client);
	}
}

void ResetHunterPounceState(int client)
{
	if (client <= 0 || client > MaxClients)
	{
		return;
	}

	for (int i = 0; i < 3; i++)
	{
		g_fHunterDelay[client][i] = GetGameTime();
		g_iHunterState[client][i] = 0;
	}
}

void HunterDelayStart(int hunter, int index)
{
	g_fHunterDelay[hunter][index] = GetGameTime();
}

bool HunterDelayExpired(int hunter, int index, float duration)
{
	return GetGameTime() - g_fHunterDelay[hunter][index] > duration;
}

float NearestMobileSurvivorDistance(int hunter)
{
	float hunterPosition[3];
	GetClientAbsOrigin(hunter, hunterPosition);

	float nearestDistance = -1.0;
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsMobileSurvivor(client))
		{
			continue;
		}

		float survivorPosition[3];
		GetClientAbsOrigin(client, survivorPosition);
		float distance = GetVectorDistance(hunterPosition, survivorPosition);
		if (nearestDistance < 0.0 || distance < nearestDistance)
		{
			nearestDistance = distance;
		}
	}

	return nearestDistance;
}

bool IsMobileSurvivor(int client)
{
	return IsSurvivor(client) && IsPlayerAlive(client) && !GetEntProp(client, Prop_Send, "m_isIncapacitated")
		&& GetEntPropEnt(client, Prop_Send, "m_tongueOwner") <= 0 && GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") <= 0
		&& GetEntPropEnt(client, Prop_Send, "m_carryAttacker") <= 0 && GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") <= 0
		&& GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") <= 0;
}

// Smart AI Rock：仅针对 AI Tank。石头离手后，提前结束旧朝向锁定，恢复 AI 的正常目标追踪。
methodmap PlayerBody
{
	property CountdownTimer m_lookAtExpireTimer
	{
		public get()
		{
			return view_as<CountdownTimer>(view_as<Address>(this) + view_as<Address>(100));
		}
	}
}

public void L4D_TankRock_OnRelease_Post(int tank, int rock, const float vecPos[3], const float vecAng[3], const float vecVel[3], const float vecRot[3])
{
	MarkRockReleased(rock, vecPos);

	if (!g_cvSmartAiRock.BoolValue || !IsAiTank(tank))
	{
		return;
	}

	int ability = GetEntPropEnt(tank, Prop_Send, "m_customAbility");
	if (ability == -1)
	{
		return;
	}

	CountdownTimer throwTimer = CThrow__GetThrowTimer(ability);
	float delay = CTimer_GetTimestamp(throwTimer) - GetGameTime() + 0.01;
	if (delay < 0.01)
	{
		delay = 0.01;
	}

	CreateTimer(delay, Timer_ExpireTankLookAt, GetClientUserId(tank), TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_ExpireTankLookAt(Handle timer, int userId)
{
	int tank = GetClientOfUserId(userId);
	if (!IsAiTank(tank))
	{
		return Plugin_Stop;
	}

	PlayerBody body = Tank__GetBodyInterface(tank);
	CTimer_SetTimestamp(body.m_lookAtExpireTimer, GetGameTime());
	return Plugin_Stop;
}

PlayerBody Tank__GetBodyInterface(int tank)
{
	static int offsetPlayerBody = -1;
	if (offsetPlayerBody == -1)
	{
		offsetPlayerBody = FindSendPropInfo("SurvivorBot", "m_humanSpectatorEntIndex") + 12 - 4 * view_as<int>(L4D_IsEngineLeft4Dead2());
	}

	return view_as<PlayerBody>(LoadFromAddress(GetEntityAddress(tank) + view_as<Address>(offsetPlayerBody), NumberType_Int32));
}

CountdownTimer CThrow__GetThrowTimer(int ability)
{
	static int offsetThrowTimer = -1;
	if (offsetThrowTimer == -1)
	{
		offsetThrowTimer = FindSendPropInfo("CThrow", "m_hasBeenUsed") + 4;
	}

	return view_as<CountdownTimer>(GetEntityAddress(ability) + view_as<Address>(offsetThrowTimer));
}

// 推击处理：Tank / Charger 的推击减速修复与 Hunter 空中防推共用 Left4DHooks 回调。
public Action L4D_OnShovedBySurvivor(int shover, int shovee, const float vector[3])
{
	Action result = HandleSurvivorShove(shover, shovee);
	if (result == Plugin_Continue && g_bStaggerDirectionAvailable && g_cvSiShoveDirectionFix.BoolValue)
	{
		FixSpecialInfectedShoveDirection(shovee);
	}

	return result;
}

void FixSpecialInfectedShoveDirection(int infected)
{
	if (infected <= 0 || infected > MaxClients || !IsClientInGame(infected) || GetClientTeam(infected) != TEAM_INFECTED)
	{
		return;
	}

	Address playerAnimState = view_as<Address>(GetEntData(infected, g_iStaggerDirectionPlayerAnimStateOffset));
	if (playerAnimState == Address_Null)
	{
		return;
	}

	float angles[3];
	GetClientAbsAngles(infected, angles);
	StoreToAddress(playerAnimState + view_as<Address>(g_iStaggerDirectionEyeYawOffset), angles[1], NumberType_Int32);
}

public Action L4D2_OnEntityShoved(int shover, int shoveeEntity, int weapon, float vector[3], bool isHunterDeadstop)
{
	return HandleSurvivorShove(shover, shoveeEntity);
}

Action HandleSurvivorShove(int shover, int shovee)
{
	if (!IsSurvivor(shover))
	{
		return Plugin_Continue;
	}

	if (g_cvTankChargerShoveFix.BoolValue && IsTankOrCharger(shovee))
	{
		return Plugin_Handled;
	}

	if (!g_cvHunterNoDeadstop.BoolValue || !IsHunter(shovee) || HasPounceTarget(shovee))
	{
		return Plugin_Continue;
	}

	return IsPlayingDeadstopAnimation(shovee) ? Plugin_Handled : Plugin_Continue;
}

bool IsTankOrCharger(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && IsPlayerAlive(client)
		&& GetClientTeam(client) == TEAM_INFECTED
		&& (GetEntProp(client, Prop_Send, "m_zombieClass") == Z_TANK || GetEntProp(client, Prop_Send, "m_zombieClass") == Z_CHARGER);
}

bool IsSurvivor(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == TEAM_SURVIVOR;
}

bool IsHunter(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && IsPlayerAlive(client)
		&& GetClientTeam(client) == TEAM_INFECTED && GetEntProp(client, Prop_Send, "m_zombieClass") == Z_HUNTER;
}

bool IsAiHunter(int client)
{
	return IsHunter(client) && IsFakeClient(client) && GetEntProp(client, Prop_Send, "m_isGhost") == 0;
}

bool IsAiSmoker(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && IsPlayerAlive(client) && IsFakeClient(client)
		&& GetClientTeam(client) == TEAM_INFECTED && GetEntProp(client, Prop_Send, "m_zombieClass") == Z_SMOKER
		&& GetEntProp(client, Prop_Send, "m_isGhost") == 0;
}

bool IsTank(int client)
{
	return IsTankClient(client) && IsPlayerAlive(client);
}

bool IsTankClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client)
		&& GetClientTeam(client) == TEAM_INFECTED && GetEntProp(client, Prop_Send, "m_zombieClass") == Z_TANK;
}

bool IsAiTank(int client)
{
	return IsTank(client) && IsFakeClient(client);
}

bool IsPlayingDeadstopAnimation(int hunter)
{
	int sequence = GetEntProp(hunter, Prop_Send, "m_nSequence");
	for (int i = 0; i < sizeof(g_iDeadstopSequences); i++)
	{
		if (g_iDeadstopSequences[i] == sequence)
		{
			return true;
		}
	}

	return false;
}

bool HasPounceTarget(int hunter)
{
	int target = GetEntPropEnt(hunter, Prop_Send, "m_pounceVictim");
	return IsSurvivor(target) && IsPlayerAlive(target);
}
