// Inspired by AST's gascan feature (海洋空氣); campaign implementation by night.
#define SPIT_GASCAN_GAMEDATA "l4d2_difficulty_spitter_gascan"
#define SPIT_GASCAN_SAMPLE_INTERVAL 0.20
#define SPIT_GASCAN_DEFAULT_DELAY 2.9
#define SPIT_GASCAN_CONTACT_RADIUS 60.0
#define SPIT_GASCAN_ZOMBIECLASS 4
#define SPIT_GASCAN_GLOW_PROPS 4

static const char g_sSpitGascanGlowProps[][] =
{
	"m_iGlowType", "m_glowColorOverride", "m_nGlowRange", "m_nGlowRangeMin"
};
static const int g_iSpitGascanGlowValues[] = {3, 255 + 255 * 256, 450, 0};

enum struct SpitGascanExposure
{
	int canRef;
	int acidRef;
	int spitterUserId;
	float startTime;
	bool damageAttempted;
	bool warningLit;
	bool glowYielded;
	int oldGlow[SPIT_GASCAN_GLOW_PROPS];
	float lastDamageTime;
	int lastDamageUserId;
}

ConVar g_cvSpitterGascan;
static ConVar g_cvSpitGascanDelay;
static ConVar g_cvSpitGascanDebug;
static ConVar g_cvSpitGascanMode;
static Handle g_hSpitGascanTouching;
static Handle g_hSpitGascanTimer;
static ArrayList g_aSpitGascanPicked;
static ArrayList g_aSpitGascanPools;
static bool g_bSpitGascanMapReady;
static bool g_bSpitGascanCampaign;
static bool g_bSpitGascanRoundEnded;

void InitializeSpitterGascan()
{
	g_cvSpitterGascan = CreateConVar("l4d2_difficulty_spitter_gascan", "1",
		"1=Spitter 酸液可点燃被拾取后放下的油桶，0=关闭", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvSpitterGascan.AddChangeHook(SpitGascan_OnSettingChanged);
	g_cvSpitGascanDelay = FindConVar("gascan_spit_time");
	g_cvSpitGascanDebug = CreateConVar("l4d2_difficulty_spitter_gascan_debug", "0", "Log gascan pickup, damage attempts and actual break events", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvSpitGascanMode = FindConVar("mp_gamemode");
	g_cvSpitGascanMode.AddChangeHook(SpitGascan_OnSettingChanged);
	g_aSpitGascanPicked = new ArrayList(sizeof(SpitGascanExposure));
	g_aSpitGascanPools = new ArrayList();

	GameData data = new GameData(SPIT_GASCAN_GAMEDATA);
	if (data == null)
	{
		LogError("缺少 %s.txt；仅停用酸液点燃油桶。", SPIT_GASCAN_GAMEDATA);
		return;
	}

	StartPrepSDKCall(SDKCall_Entity);
	bool found = PrepSDKCall_SetFromConf(data, SDKConf_Signature, "CInferno::IsTouching");
	delete data;

	if (found)
	{
		PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
		PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
		PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
		PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
		g_hSpitGascanTouching = EndPrepSDKCall();
	}
	if (g_hSpitGascanTouching == null)
	{
		LogError("%s.txt 的酸液接触签名不可用；仅停用酸液点燃油桶。", SPIT_GASCAN_GAMEDATA);
	}
}

bool IsSpitterGascanAvailable()
{
	return g_hSpitGascanTouching != null;
}

bool CanToggleSpitterGascan(int client)
{
	return CheckCommandAccess(client, "tankdiff_spitter_gascan", ADMFLAG_CONVARS, true);
}

static void SpitGascan_OnSettingChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	RefreshSpitterGascan();
}

void SetSpitterGascanMapReady(bool ready)
{
	g_bSpitGascanMapReady = ready;
	if (!ready)
	{
		ResetSpitterGascanRound();
		return;
	}
	RefreshSpitterGascan();
}

static void RefreshSpitterGascan()
{
	char mode[32];
	g_cvSpitGascanMode.GetString(mode, sizeof(mode));
	bool campaign = StrEqual(mode, "coop", false) || StrEqual(mode, "realism", false);
	if (g_bSpitGascanCampaign != campaign)
	{
		g_bSpitGascanCampaign = campaign;
		ResetSpitterGascanRound();
	}
	if (!CanRunSpitGascan())
	{
		delete g_hSpitGascanTimer;
		ClearAllSpitGascanExposure();
		return;
	}
	SpitGascan_StartTimer();
}

void ResetSpitterGascanRound()
{
	delete g_hSpitGascanTimer;
	ClearAllSpitGascanExposure();
	g_aSpitGascanPicked.Clear();
	g_aSpitGascanPools.Clear();
}

void StartSpitterGascanRound()
{
	g_bSpitGascanRoundEnded = false;
	ResetSpitterGascanRound();
}

public void SpitGascan_OnRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	g_bSpitGascanRoundEnded = true;
	ResetSpitterGascanRound();
}

void ShutdownSpitterGascan()
{
	delete g_hSpitGascanTimer;
	ClearAllSpitGascanExposure();
	delete g_aSpitGascanPicked;
	delete g_aSpitGascanPools;
	delete g_hSpitGascanTouching;
}

static bool CanRunSpitGascan()
{
	return g_bSpitGascanMapReady && g_bSpitGascanCampaign && !g_bSpitGascanRoundEnded && g_cvSpitterGascan.BoolValue && IsSpitterGascanAvailable();
}

void HookSpitterGascanClient(int client)
{
	if (IsSpitterGascanAvailable())
	{
		SDKHook(client, SDKHook_WeaponEquip, SpitGascan_OnEquipPre);
		SDKHook(client, SDKHook_WeaponEquipPost, SpitGascan_OnEquip);
	}
}

static Action SpitGascan_OnEquipPre(int client, int weapon)
{
	if (g_bSpitGascanMapReady && g_bSpitGascanCampaign && GetClientTeam(client) == 2
		&& SpitGascan_IsClass(weapon, "weapon_gascan"))
	{
		int index = g_aSpitGascanPicked.FindValue(EntIndexToEntRef(weapon));
		if (index != -1)
		{
			SpitGascanExposure state;
			g_aSpitGascanPicked.GetArray(index, state, sizeof(state));
			SpitGascan_RemoveWarning(state);
			g_aSpitGascanPicked.SetArray(index, state, sizeof(state));
		}
	}
	return Plugin_Continue;
}

static void SpitGascan_OnEquip(int client, int weapon)
{
	if (!g_bSpitGascanMapReady || !g_bSpitGascanCampaign || g_bSpitGascanRoundEnded || GetClientTeam(client) != 2
		|| !SpitGascan_IsClass(weapon, "weapon_gascan"))
	{
		return;
	}

	int ref = EntIndexToEntRef(weapon);
	int index = g_aSpitGascanPicked.FindValue(ref);
	SpitGascanExposure state;
	if (index == -1)
	{
		state.canRef = ref;
		ClearSpitGascanExposure(state);
		g_aSpitGascanPicked.PushArray(state, sizeof(state));
	}
	else
	{
		g_aSpitGascanPicked.GetArray(index, state, sizeof(state));
		if (g_cvSpitGascanDebug.BoolValue && (state.acidRef != INVALID_ENT_REFERENCE || state.lastDamageUserId != 0))
		{
			LogMessage("[SpitGascan] pickup can=%d user=%d exposure=%.2f priorAttempt=%d",
				ref, GetClientUserId(client), state.acidRef == INVALID_ENT_REFERENCE ? 0.0 : GetGameTime() - state.startTime,
				state.lastDamageUserId != 0);
		}
		ClearSpitGascanExposure(state);
		g_aSpitGascanPicked.SetArray(index, state, sizeof(state));
	}
	SpitGascan_StartTimer();
}

void TrackSpitterGascanAcidCreated(int entity, const char[] classname)
{
	if (!IsSpitterGascanAvailable() || g_bSpitGascanRoundEnded || !StrEqual(classname, "insect_swarm"))
	{
		return;
	}

	int ref = EntIndexToEntRef(entity);
	g_aSpitGascanPools.Push(ref);
	SpitGascan_StartTimer();
}

static void SpitGascan_PrunePools()
{
	for (int i = g_aSpitGascanPools.Length - 1; i >= 0; i--)
	{
		if (EntRefToEntIndex(g_aSpitGascanPools.Get(i)) == INVALID_ENT_REFERENCE)
		{
			g_aSpitGascanPools.Erase(i);
		}
	}
}

static void SpitGascan_StartTimer()
{
	if (!CanRunSpitGascan() || g_hSpitGascanTimer != null || g_aSpitGascanPicked.Length == 0)
	{
		return;
	}
	SpitGascan_PrunePools();
	if (g_aSpitGascanPools.Length != 0)
	{
		g_hSpitGascanTimer = CreateTimer(SPIT_GASCAN_SAMPLE_INTERVAL, SpitGascan_CheckExposure, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	}
}

static void ClearAllSpitGascanExposure()
{
	SpitGascanExposure state;
	for (int i = 0; i < g_aSpitGascanPicked.Length; i++)
	{
		g_aSpitGascanPicked.GetArray(i, state, sizeof(state));
		ClearSpitGascanExposure(state);
		g_aSpitGascanPicked.SetArray(i, state, sizeof(state));
	}
}

static void SpitGascan_RemoveWarning(SpitGascanExposure state)
{
	if (!state.warningLit)
	{
		return;
	}

	state.warningLit = false;
	int gascan = EntRefToEntIndex(state.canRef);
	if (gascan == INVALID_ENT_REFERENCE)
	{
		return;
	}
	for (int i = 0; i < sizeof(g_iSpitGascanGlowValues); i++)
	{
		if (GetEntProp(gascan, Prop_Send, g_sSpitGascanGlowProps[i]) != g_iSpitGascanGlowValues[i])
		{
			// A hint plugin or the game changed the glow; do not overwrite the new outline.
			state.glowYielded = true;
			return;
		}
	}
	for (int i = 0; i < sizeof(g_iSpitGascanGlowValues); i++)
	{
		SetEntProp(gascan, Prop_Send, g_sSpitGascanGlowProps[i], state.oldGlow[i]);
	}
}

static void SpitGascan_BlinkWarning(SpitGascanExposure state, int gascan)
{
	if (state.warningLit)
	{
		SpitGascan_RemoveWarning(state);
		return;
	}
	if (state.glowYielded)
	{
		return;
	}
	for (int i = 0; i < sizeof(g_iSpitGascanGlowValues); i++)
	{
		if (!HasEntProp(gascan, Prop_Send, g_sSpitGascanGlowProps[i]))
		{
			state.glowYielded = true;
			return;
		}
		state.oldGlow[i] = GetEntProp(gascan, Prop_Send, g_sSpitGascanGlowProps[i]);
	}
	for (int i = 0; i < sizeof(g_iSpitGascanGlowValues); i++)
	{
		SetEntProp(gascan, Prop_Send, g_sSpitGascanGlowProps[i], g_iSpitGascanGlowValues[i]);
	}
	state.warningLit = true;
}

static void ClearSpitGascanExposure(SpitGascanExposure state)
{
	SpitGascan_RemoveWarning(state);
	state.glowYielded = false;
	state.acidRef = INVALID_ENT_REFERENCE;
	state.spitterUserId = 0;
	state.startTime = 0.0;
	state.damageAttempted = false;
}

static bool SpitGascan_IsClass(int entity, const char[] expected)
{
	if (entity <= MaxClients || !IsValidEntity(entity))
	{
		return false;
	}
	char classname[32];
	GetEntityClassname(entity, classname, sizeof(classname));
	return StrEqual(classname, expected);
}

static bool SpitGascan_IsDropped(int gascan)
{
	// CBaseCombatWeapon owns the weapon while it is carried. Do not damage scripted invulnerable props.
	return HasEntProp(gascan, Prop_Data, "m_hOwner")
		&& GetEntPropEnt(gascan, Prop_Data, "m_hOwner") == -1
		&& GetEntProp(gascan, Prop_Data, "m_iHealth") > 0
		&& GetEntProp(gascan, Prop_Data, "m_takedamage") != 0;
}

static int SpitGascan_GetSource(int acid)
{
	if (!SpitGascan_IsClass(acid, "insect_swarm"))
	{
		return 0;
	}
	int owner = GetEntPropEnt(acid, Prop_Data, "m_hOwnerEntity");
	if (owner <= 0 || owner > MaxClients || !IsClientInGame(owner) || GetClientTeam(owner) != TEAM_INFECTED
		|| GetEntProp(owner, Prop_Send, "m_zombieClass") != SPIT_GASCAN_ZOMBIECLASS)
	{
		return 0;
	}
	return owner;
}

static bool SpitGascan_IsTouching(int acid, int gascan)
{
	// Uses the actual inferno cells and the engine's entity contact test. The installed acid-fix
	// detour can adjust the contact radius in the same way it does for ordinary acid checks.
	return SDKCall(g_hSpitGascanTouching, acid, gascan, SPIT_GASCAN_CONTACT_RADIUS, true);
}

static void SpitGascan_UpdateExposure(SpitGascanExposure state, int gascan, float now)
{
	// Keep the same acid source while it remains valid. Crossing to a different pool restarts the timer.
	int acid = EntRefToEntIndex(state.acidRef);
	int spitter = SpitGascan_GetSource(acid);
	if (spitter > 0 && GetClientUserId(spitter) == state.spitterUserId && SpitGascan_IsTouching(acid, gascan))
	{
		return;
	}

	ClearSpitGascanExposure(state);
	for (int i = 0; i < g_aSpitGascanPools.Length; i++)
	{
		int ref = g_aSpitGascanPools.Get(i);
		acid = EntRefToEntIndex(ref);
		spitter = SpitGascan_GetSource(acid);
		if (spitter > 0 && SpitGascan_IsTouching(acid, gascan))
		{
			state.acidRef = ref;
			state.spitterUserId = GetClientUserId(spitter);
			state.startTime = now;
			return;
		}
	}
}

static Action SpitGascan_CheckExposure(Handle timer)
{
	SpitGascan_PrunePools();
	float now = GetGameTime();
	float delay = g_cvSpitGascanDelay == null ? SPIT_GASCAN_DEFAULT_DELAY : g_cvSpitGascanDelay.FloatValue;

	for (int i = g_aSpitGascanPicked.Length - 1; i >= 0; i--)
	{
		SpitGascanExposure state;
		g_aSpitGascanPicked.GetArray(i, state, sizeof(state));
		int gascan = EntRefToEntIndex(state.canRef);
		if (!SpitGascan_IsClass(gascan, "weapon_gascan"))
		{
			g_aSpitGascanPicked.Erase(i);
			continue;
		}
		if (!SpitGascan_IsDropped(gascan) || delay <= 0.0)
		{
			ClearSpitGascanExposure(state);
			g_aSpitGascanPicked.SetArray(i, state, sizeof(state));
			continue;
		}

		SpitGascan_UpdateExposure(state, gascan, now);
		int acid = EntRefToEntIndex(state.acidRef);
		int spitter = GetClientOfUserId(state.spitterUserId);
		bool ignite = !state.damageAttempted && acid != INVALID_ENT_REFERENCE && spitter > 0
			&& now - state.startTime >= delay;
		if (ignite)
		{
			// Commit before firing game hooks so only one attempt is made per continuous exposure.
			state.damageAttempted = true;
			state.lastDamageTime = now;
			state.lastDamageUserId = state.spitterUserId;
			SpitGascan_RemoveWarning(state);
		}
		else if (!state.damageAttempted && acid != INVALID_ENT_REFERENCE && spitter > 0)
		{
			SpitGascan_BlinkWarning(state, gascan);
		}
		g_aSpitGascanPicked.SetArray(i, state, sizeof(state));

		if (ignite)
		{
			// Let the engine handle breaking the gascan; the existing announcer records this attacker.
			float damage = float(GetEntProp(gascan, Prop_Data, "m_iHealth")) + 1.0;
			if (g_cvSpitGascanDebug.BoolValue)
			{
				LogMessage("[SpitGascan] damage can=%d acid=%d source=%d exposure=%.2f dmg=%.0f",
					state.canRef, state.acidRef, state.spitterUserId, now - state.startTime, damage);
			}
			SDKHooks_TakeDamage(gascan, acid, spitter, damage, DMG_BURN | DMG_DIRECT, .bypassHooks = false);
			if (g_cvSpitGascanDebug.BoolValue && EntRefToEntIndex(state.canRef) == gascan)
			{
				LogMessage("[SpitGascan] damage_return can=%d hp=%d",
					state.canRef, GetEntProp(gascan, Prop_Data, "m_iHealth"));
			}
			if (g_hSpitGascanTimer != timer)
			{
				// A break listener may have ended the round or turned this feature off.
				return Plugin_Stop;
			}
		}
	}

	if (g_aSpitGascanPicked.Length == 0 || g_aSpitGascanPools.Length == 0)
	{
		g_hSpitGascanTimer = null;
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

public void L4D2_CGasCan_EventKilled_Post(int gascan, int inflictor, int attacker)
{
	if (g_cvSpitGascanDebug == null || !g_cvSpitGascanDebug.BoolValue || g_aSpitGascanPicked == null
		|| gascan <= MaxClients || !IsValidEntity(gascan))
	{
		return;
	}

	int ref = EntIndexToEntRef(gascan);
	int index = g_aSpitGascanPicked.FindValue(ref);
	if (index == -1)
	{
		return;
	}

	SpitGascanExposure state;
	g_aSpitGascanPicked.GetArray(index, state, sizeof(state));
	int attackerUserId = 0;
	if (attacker >= 1 && attacker <= MaxClients && IsClientInGame(attacker))
	{
		attackerUserId = GetClientUserId(attacker);
	}
	LogMessage("[SpitGascan] break can=%d inflictor=%d attacker=%d priorSource=%d afterAttempt=%.2f",
		ref, inflictor, attackerUserId, state.lastDamageUserId,
		state.lastDamageUserId == 0 ? -1.0 : GetGameTime() - state.lastDamageTime);
}
