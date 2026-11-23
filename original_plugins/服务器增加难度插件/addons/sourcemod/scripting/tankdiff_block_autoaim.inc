// 禁用引擎原生辅助瞄准：参考 Sir 的 Block Autoaim；菜单与权限整合：night。
#define BLOCK_AUTOAIM_GAMEDATA "l4d2_difficulty_block_autoaim"
#define BLOCK_AUTOAIM_FUNCTION "CBasePlayer::ShouldAutoaim"

ConVar g_cvBlockAutoaim;
DynamicDetour g_hBlockAutoaim;
bool g_bBlockAutoaimRequested;
bool g_bBlockAutoaimHooked;

void InitializeBlockAutoaim()
{
	g_cvBlockAutoaim = CreateConVar("l4d2_difficulty_block_autoaim", "1",
		"1=禁用游戏原生辅助瞄准（含手柄），0=恢复原生", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvBlockAutoaim.AddChangeHook(OnBlockAutoaimChanged);

	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "gamedata/%s.txt", BLOCK_AUTOAIM_GAMEDATA);
	if (!FileExists(path))
	{
		LogError("缺少 %s.txt；禁用原生辅助瞄准功能不可用。", BLOCK_AUTOAIM_GAMEDATA);
		return;
	}
	GameData data = new GameData(BLOCK_AUTOAIM_GAMEDATA);
	if (data == null)
	{
		LogError("无法读取 %s.txt；禁用原生辅助瞄准功能不可用。", BLOCK_AUTOAIM_GAMEDATA);
		return;
	}
	g_hBlockAutoaim = DynamicDetour.FromConf(data, BLOCK_AUTOAIM_FUNCTION);
	delete data;
	if (g_hBlockAutoaim == null)
	{
		LogError("无法定位引擎的辅助瞄准判定；禁用原生辅助瞄准功能不可用。");
		return;
	}
	RefreshBlockAutoaim();
}

bool CanToggleBlockAutoaim(int client)
{
	return CheckCommandAccess(client, "tankdiff_block_autoaim", ADMFLAG_CONVARS, true);
}

bool IsBlockAutoaimAvailable()
{
	return g_hBlockAutoaim != null;
}

bool IsBlockAutoaimActive()
{
	return g_bBlockAutoaimRequested && g_bBlockAutoaimHooked;
}

void OnBlockAutoaimChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	RefreshBlockAutoaim();
}

void RefreshBlockAutoaim()
{
	g_bBlockAutoaimRequested = g_cvBlockAutoaim.BoolValue;
	if (g_hBlockAutoaim == null || g_bBlockAutoaimRequested == g_bBlockAutoaimHooked)
	{
		return;
	}
	if (g_bBlockAutoaimRequested)
	{
		if (!g_hBlockAutoaim.Enable(Hook_Pre, Detour_TankdiffShouldAutoaim))
		{
			delete g_hBlockAutoaim;
			LogError("挂接辅助瞄准判定失败；仅停用禁用原生辅助瞄准功能。");
			return;
		}
		g_bBlockAutoaimHooked = true;
	}
	else if (g_hBlockAutoaim.Disable(Hook_Pre, Detour_TankdiffShouldAutoaim))
	{
		g_bBlockAutoaimHooked = false;
	}
	else
	{
		// 即使无法摘钩，回调也会放行引擎的原生判定。
		LogError("未能摘除辅助瞄准钩子；已恢复原生判定。");
	}
}

void ShutdownBlockAutoaim()
{
	g_bBlockAutoaimRequested = false;
	if (g_hBlockAutoaim != null && g_bBlockAutoaimHooked)
	{
		g_hBlockAutoaim.Disable(Hook_Pre, Detour_TankdiffShouldAutoaim);
	}
	delete g_hBlockAutoaim;
	g_bBlockAutoaimHooked = false;
}

MRESReturn Detour_TankdiffShouldAutoaim(int player, DHookReturn result)
{
	if (!g_bBlockAutoaimRequested)
	{
		return MRES_Ignored;
	}
	result.Value = false;
	return MRES_Supercede;
}
