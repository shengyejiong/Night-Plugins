// 受 Tank 拳切主枪：参考 Sir 的 Shove Shenanigans - REVAMPED，整合：night。
// 只摘取 l4d2_melee_drop_method = 2，不带丢武器或推击处理。
#define TANK_PUNCH_PRIMARY_FIRE_DELAY 0.1

ConVar g_cvTankPunchForcePrimary;

void InitializeTankPunchForcePrimary()
{
	g_cvTankPunchForcePrimary = CreateConVar("l4d2_difficulty_tank_punch_force_primary", "1",
		"1=持近战挨 Tank 拳后切到主枪，0=关闭", FCVAR_NOTIFY, true, 0.0, true, 1.0);
}

bool CanTankPunchForcePrimary(int client)
{
	if (!IsSurvivor(client) || !IsPlayerAlive(client) || L4D_IsPlayerIncapacitated(client)
		|| GetEntProp(client, Prop_Send, "m_isHangingFromLedge") != 0)
	{
		return false;
	}

	int melee = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if (melee <= MaxClients || !IsValidEntity(melee))
	{
		return false;
	}

	char classname[32];
	return GetEntityClassname(melee, classname, sizeof(classname)) && StrEqual(classname, "weapon_melee");
}

void QueueTankPunchForcePrimary(Event event)
{
	if (!g_cvTankPunchForcePrimary.BoolValue)
	{
		return;
	}

	char weapon[32];
	event.GetString("weapon", weapon, sizeof(weapon));
	if (!StrEqual(weapon, "tank_claw") || !IsTank(GetClientOfUserId(event.GetInt("attacker"))))
	{
		return;
	}

	int userid = event.GetInt("userid");
	int client = GetClientOfUserId(userid);
	if (CanTankPunchForcePrimary(client) && GetPlayerWeaponSlot(client, 0) > MaxClients)
	{
		// 等本次伤害的倒地与原生手枪切换结算，再决定是否强制切枪。
		RequestFrame(Frame_TankPunchForcePrimary, userid);
	}
}

void Frame_TankPunchForcePrimary(any userid)
{
	int client = GetClientOfUserId(userid);
	if (!g_cvTankPunchForcePrimary.BoolValue || !CanTankPunchForcePrimary(client))
	{
		return;
	}

	int primary = GetPlayerWeaponSlot(client, 0);
	if (primary <= MaxClients || !IsValidEntity(primary))
	{
		return;
	}

	SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", primary);

	// 按住左键砍 Tank 的玩家不会刚切枪就开火；不缩短原有冷却。
	float earliest = GetGameTime() + TANK_PUNCH_PRIMARY_FIRE_DELAY;
	if (GetEntPropFloat(primary, Prop_Send, "m_flNextPrimaryAttack") < earliest)
	{
		SetEntPropFloat(primary, Prop_Send, "m_flNextPrimaryAttack", earliest);
	}
}
