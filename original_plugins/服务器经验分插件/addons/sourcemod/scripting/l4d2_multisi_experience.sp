#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3

#define ZC_SMOKER  1
#define ZC_BOOMER  2
#define ZC_HUNTER  3
#define ZC_SPITTER 4
#define ZC_JOCKEY  5
#define ZC_CHARGER 6
#define ZC_TANK    8

#define CONTROL_NONE    0
#define CONTROL_SMOKER  1
#define CONTROL_HUNTER  2
#define CONTROL_JOCKEY  3
#define CONTROL_CHARGER 4

#define MAX_TRACKED_ENTITIES 2049

#define DecayWeapon_None            -1
#define DecayWeapon_Rifle            0
#define DecayWeapon_RifleDesert      1
#define DecayWeapon_RifleAK47        2
#define DecayWeapon_HuntingRifle     3
#define DecayWeapon_SniperMilitary   4
#define DecayWeapon_SniperScout      5
#define DecayWeapon_SniperAWP        6
#define DecayWeapon_AutoShotgun      7
#define DecayWeapon_SpasShotgun      8
#define DecayWeapon_Count            9

public Plugin myinfo =
{
    name = "L4D2 Multi-SI Campaign Experience",
    author = "night",
    description = "Round and long-term experience rating for multi-SI coop servers.",
    version = "1.7.4",
    url = ""
};

ConVar g_hEnable;
ConVar g_hIncludeBots;
ConVar g_hMinPlayers;

ConVar g_hMinPlayTime;
ConVar g_hMinPlayRatio;
ConVar g_hMinPlayFloor;

ConVar g_hBaseScore;
ConVar g_hScoreMin;
ConVar g_hScoreMax;
ConVar g_hScoreSoftcap;
ConVar g_hScoreSoftcapScale;

ConVar g_hW_SIDamage;
ConVar g_hW_SIKill;
ConVar g_hW_CommonKill;
ConVar g_hW_Clear;
ConVar g_hW_Revive;
ConVar g_hW_Defib;
ConVar g_hW_ControlSurvive;
ConVar g_hW_TankDamage;
ConVar g_hW_TankKill;
ConVar g_hW_TankTopDamage;
ConVar g_hW_WitchKill;
ConVar g_hW_RockDestroy;
ConVar g_hClearRecentWindow;

ConVar g_hW_Skeet;
ConVar g_hW_MeleeSkeet;
ConVar g_hW_TongueCut;
ConVar g_hW_HunterDeadstop;
ConVar g_hW_ChargerLevel;
ConVar g_hW_FastClear;
ConVar g_hW_SmokerSelfClear;
ConVar g_hFastClearTime;

ConVar g_hWeaponMult_SMG;
ConVar g_hWeaponMult_SMGSilenced;
ConVar g_hWeaponMult_PumpShotgun;
ConVar g_hWeaponMult_ChromeShotgun;
ConVar g_hWeaponMult_MP5;
ConVar g_hWeaponMult_SG552;
ConVar g_hWeaponMult_Rifle;
ConVar g_hWeaponMult_RifleDesert;
ConVar g_hWeaponMult_RifleAK47;
ConVar g_hWeaponMult_AutoShotgun;
ConVar g_hWeaponMult_SpasShotgun;
ConVar g_hWeaponMult_HuntingRifle;
ConVar g_hWeaponMult_SniperMilitary;
ConVar g_hWeaponMult_SniperScout;
ConVar g_hWeaponMult_SniperAWP;
ConVar g_hWeaponDecayEnable;
ConVar g_hWeaponDecayStart;
ConVar g_hWeaponDecayZero;
ConVar g_hWeaponDecayAutoShotgunStart;
ConVar g_hWeaponDecayAutoShotgunZero;
ConVar g_hWeaponDecayRecoveryRate;
ConVar g_hWeaponDecayNotifyRearmBuffer;

ConVar g_hW_AccuracyStep;
ConVar g_hAccuracyMinShots;
ConVar g_hAccuracyFloor;
ConVar g_hAccuracyStep;
ConVar g_hAccuracyMaxBonus;

ConVar g_hP_Control;
ConVar g_hP_ControlTime;
ConVar g_hP_Incap;
ConVar g_hP_Death;
ConVar g_hSaferoomIncapScale;
ConVar g_hSaferoomDeathScale;
ConVar g_hP_FFDamage;
ConVar g_hP_RockHit;
ConVar g_hP_TankPunch;
ConVar g_hP_TankHittable;
ConVar g_hP_SpitDamage;

ConVar g_hDefaultRating;
ConVar g_hRatingWeight;
ConVar g_hRankMinRounds;
ConVar g_hShortRoundSkipTime;
ConVar g_hShortRoundFullTime;
ConVar g_hShortRoundMinWeightScale;
ConVar g_hWinLowTeamScoreFloor;
ConVar g_hWinLowScoreNegativeScale;
ConVar g_hEndgameOutsideDeathGuard;
ConVar g_hEndgameOutsideDeathNegativeScale;
ConVar g_hAnnounce;
ConVar g_hJoinAnnounce;
ConVar g_hJoinAnnounceDelay;
ConVar g_hSave;

float g_fSIDamage[MAXPLAYERS + 1];
float g_fSIRawDamage[MAXPLAYERS + 1];
int   g_iSIKills[MAXPLAYERS + 1];
int   g_iCommonKills[MAXPLAYERS + 1];
int   g_iClears[MAXPLAYERS + 1];
int   g_iRevives[MAXPLAYERS + 1];
int   g_iDefibs[MAXPLAYERS + 1];
float g_fTankDamage[MAXPLAYERS + 1];
float g_fTankRawDamage[MAXPLAYERS + 1];
float g_fTankDamageByTank[MAXPLAYERS + 1][MAXPLAYERS + 1];
float g_fTankRawDamageByTank[MAXPLAYERS + 1][MAXPLAYERS + 1];
int   g_iTankKills[MAXPLAYERS + 1];
int   g_iTankTopDamage[MAXPLAYERS + 1];
int   g_iWitchKills[MAXPLAYERS + 1];
int   g_iRockDestroys[MAXPLAYERS + 1];
int   g_iRockHits[MAXPLAYERS + 1];
int   g_iTankPunches[MAXPLAYERS + 1];
int   g_iTankHittables[MAXPLAYERS + 1];
float g_fSpitDamage[MAXPLAYERS + 1];
int   g_iAccuracyShots[MAXPLAYERS + 1];
int   g_iAccuracyHits[MAXPLAYERS + 1];
bool  g_bRockDestroyAwarded[MAX_TRACKED_ENTITIES];
float g_fDecayWeaponTime[MAXPLAYERS + 1][DecayWeapon_Count];
float g_fDecayWeaponUpdatedAt[MAXPLAYERS + 1][DecayWeapon_Count];
int   g_iActiveDecayWeapon[MAXPLAYERS + 1];
bool  g_bDecayStartNotified[MAXPLAYERS + 1][DecayWeapon_Count];
bool  g_bDecayZeroNotified[MAXPLAYERS + 1][DecayWeapon_Count];
bool  g_bPendingInfectedDamage[MAXPLAYERS + 1];
int   g_iPendingDamageAttacker[MAXPLAYERS + 1];
int   g_iPendingDamagePreHealth[MAXPLAYERS + 1];
int   g_iPendingDamageZombieClass[MAXPLAYERS + 1];
float g_fPendingDamageMultiplier[MAXPLAYERS + 1];

int   g_iSkeets[MAXPLAYERS + 1];
int   g_iMeleeSkeets[MAXPLAYERS + 1];
int   g_iTongueCuts[MAXPLAYERS + 1];
int   g_iHunterDeadstops[MAXPLAYERS + 1];
int   g_iChargerLevels[MAXPLAYERS + 1];
int   g_iFastClears[MAXPLAYERS + 1];
int   g_iSmokerSelfClears[MAXPLAYERS + 1];
int   g_iLastFastClearPinner[MAXPLAYERS + 1];
int   g_iLastFastClearVictim[MAXPLAYERS + 1];
float g_fLastFastClearAt[MAXPLAYERS + 1];

int   g_iControlsTaken[MAXPLAYERS + 1];
float g_fControlDuration[MAXPLAYERS + 1];
int   g_iControlType[MAXPLAYERS + 1];
int   g_iControlAttacker[MAXPLAYERS + 1];
float g_fControlStart[MAXPLAYERS + 1];
int   g_iControlStartIncaps[MAXPLAYERS + 1];
int   g_iControlStartDeaths[MAXPLAYERS + 1];
int   g_iControlsSurvived[MAXPLAYERS + 1];
int   g_iLastControlAttacker[MAXPLAYERS + 1];
float g_fLastControlEndTime[MAXPLAYERS + 1];

int   g_iIncaps[MAXPLAYERS + 1];
int   g_iDeaths[MAXPLAYERS + 1];
int   g_iSaferoomIncaps[MAXPLAYERS + 1];
int   g_iSaferoomDeaths[MAXPLAYERS + 1];
int   g_iEndgameOutsideIncaps[MAXPLAYERS + 1];
int   g_iEndgameOutsideDeaths[MAXPLAYERS + 1];
float g_fFriendlyFire[MAXPLAYERS + 1];

bool  g_bSurvivorActive[MAXPLAYERS + 1];
bool  g_bHasLeftCheckpoint[MAXPLAYERS + 1];
bool  g_bInEndSaferoom[MAXPLAYERS + 1];
float g_fJoinStartedAt[MAXPLAYERS + 1];
float g_fPlayAccum[MAXPLAYERS + 1];

bool  g_bLoaded[MAXPLAYERS + 1];
float g_fRating[MAXPLAYERS + 1];
int   g_iValidRounds[MAXPLAYERS + 1];

float g_fRoundStart;
bool  g_bRoundEnded;
bool  g_bRoundEndedByWin;
bool  g_bEndSaferoomReached;

public void OnPluginStart()
{
    EngineVersion engine = GetEngineVersion();
    if (engine != Engine_Left4Dead2)
    {
        SetFailState("This plugin supports Left 4 Dead 2 only.");
    }

    g_hEnable = CreateConVar("l4d2_mexp_enable", "1", "0=Disable scoring/tracking for the current map, 1=Enable.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_hEnable.AddChangeHook(ConVarChanged_Enable);
    g_hIncludeBots = CreateConVar("l4d2_mexp_include_bots", "0", "0=Ignore bots, 1=Include bots in rating and round results.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_hMinPlayers = CreateConVar("l4d2_mexp_min_players", "2", "Minimum valid real players required to update/announce rating.", FCVAR_NOTIFY, true, 1.0);

    g_hMinPlayTime = CreateConVar("l4d2_mexp_min_play_time", "120.0", "Maximum participation threshold in seconds.", FCVAR_NOTIFY, true, 0.0);
    g_hMinPlayRatio = CreateConVar("l4d2_mexp_min_play_ratio", "0.5", "Participation threshold ratio of round duration.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_hMinPlayFloor = CreateConVar("l4d2_mexp_min_play_floor", "15.0", "Absolute minimum participation threshold in seconds.", FCVAR_NOTIFY, true, 0.0);

    g_hBaseScore = CreateConVar("l4d2_mexp_base_score", "100.0", "Base round performance score.", FCVAR_NOTIFY);
    g_hScoreMin = CreateConVar("l4d2_mexp_score_min", "0.0", "Minimum round score.", FCVAR_NOTIFY);
    g_hScoreMax = CreateConVar("l4d2_mexp_score_max", "400.0", "Maximum round score.", FCVAR_NOTIFY);
    g_hScoreSoftcap = CreateConVar("l4d2_mexp_score_softcap", "300.0", "Score above this value is compressed before final min/max clamp.", FCVAR_NOTIFY);
    g_hScoreSoftcapScale = CreateConVar("l4d2_mexp_score_softcap_scale", "0.5", "Multiplier for score above softcap. 1.0 disables compression.", FCVAR_NOTIFY, true, 0.0, true, 1.0);

    g_hW_SIDamage = CreateConVar("l4d2_mexp_w_si_damage", "0.006", "Score per 1 damage dealt to normal special infected. 0.006 = +1 per 167 damage.", FCVAR_NOTIFY);
    g_hW_SIKill = CreateConVar("l4d2_mexp_w_si_kill", "0.35", "Score per normal special infected killing blow.", FCVAR_NOTIFY);
    g_hW_CommonKill = CreateConVar("l4d2_mexp_w_common_kill", "0.125", "Score per common infected kill. 0.125 = +1 per 8 commons.", FCVAR_NOTIFY);
    g_hW_Clear = CreateConVar("l4d2_mexp_w_clear", "12.0", "Score per clear/save by killing a controlling SI.", FCVAR_NOTIFY);
    g_hW_Revive = CreateConVar("l4d2_mexp_w_revive", "5.0", "Score per successful revive.", FCVAR_NOTIFY);
    g_hW_Defib = CreateConVar("l4d2_mexp_w_defib", "12.0", "Score per defibrillator revive.", FCVAR_NOTIFY);
    g_hW_ControlSurvive = CreateConVar("l4d2_mexp_w_control_survive", "4.0", "Score for surviving a control without incap/death. Helps frontliners who absorb pressure.", FCVAR_NOTIFY);
    g_hW_TankDamage = CreateConVar("l4d2_mexp_w_tank_damage", "0.002", "Score per 1 Tank damage. 0.002 = +1 per 500 Tank damage.", FCVAR_NOTIFY);
    g_hW_TankKill = CreateConVar("l4d2_mexp_w_tank_kill", "5.0", "Score per Tank killing blow.", FCVAR_NOTIFY);
    g_hW_TankTopDamage = CreateConVar("l4d2_mexp_w_tank_top_damage", "10.0", "Score for dealing the most damage to one Tank.", FCVAR_NOTIFY);
    g_hW_WitchKill = CreateConVar("l4d2_mexp_w_witch_kill", "5.0", "Score per Witch kill.", FCVAR_NOTIFY);
    g_hW_RockDestroy = CreateConVar("l4d2_mexp_w_rock_destroy", "3.0", "Score per Tank rock destroyed.", FCVAR_NOTIFY);
    g_hClearRecentWindow = CreateConVar("l4d2_mexp_clear_recent_window", "1.0", "Seconds after a control ends to still count the controlling SI kill as a clear.", FCVAR_NOTIFY, true, 0.0, true, 5.0);

    g_hW_Skeet = CreateConVar("l4d2_mexp_w_skeet", "1.0", "Score per full shotgun skeet reported by skill_detect.", FCVAR_NOTIFY, true, 0.0);
    g_hW_MeleeSkeet = CreateConVar("l4d2_mexp_w_melee_skeet", "2.0", "Score per melee skeet reported by skill_detect.", FCVAR_NOTIFY, true, 0.0);
    g_hW_TongueCut = CreateConVar("l4d2_mexp_w_tongue_cut", "0.5", "Score per melee tongue cut reported by skill_detect.", FCVAR_NOTIFY, true, 0.0);
    g_hW_HunterDeadstop = CreateConVar("l4d2_mexp_w_hunter_deadstop", "0.2", "Score per Hunter deadstop reported by skill_detect.", FCVAR_NOTIFY, true, 0.0);
    g_hW_ChargerLevel = CreateConVar("l4d2_mexp_w_charger_level", "0.2", "Score per full or chipped melee Charger level reported by skill_detect.", FCVAR_NOTIFY, true, 0.0);
    g_hW_FastClear = CreateConVar("l4d2_mexp_w_fast_clear", "0.8", "Extra score per fast teammate clear reported by skill_detect.", FCVAR_NOTIFY, true, 0.0);
    g_hW_SmokerSelfClear = CreateConVar("l4d2_mexp_w_smoker_self_clear", "0.6", "Score per Smoker self-clear reported by skill_detect.", FCVAR_NOTIFY, true, 0.0);
    g_hFastClearTime = CreateConVar("l4d2_mexp_fast_clear_time", "0.75", "Maximum control duration in seconds for the fast-clear bonus. 0 disables.", FCVAR_NOTIFY, true, 0.0);

    g_hWeaponMult_SMG = CreateConVar("l4d2_mexp_weapon_mult_smg", "1.25", "Damage score multiplier for Uzi/SMG.", FCVAR_NOTIFY, true, 0.0);
    g_hWeaponMult_SMGSilenced = CreateConVar("l4d2_mexp_weapon_mult_smg_silenced", "1.2", "Damage score multiplier for silenced SMG.", FCVAR_NOTIFY, true, 0.0);
    g_hWeaponMult_PumpShotgun = CreateConVar("l4d2_mexp_weapon_mult_pumpshotgun", "1.2", "Damage score multiplier for pump shotgun.", FCVAR_NOTIFY, true, 0.0);
    g_hWeaponMult_ChromeShotgun = CreateConVar("l4d2_mexp_weapon_mult_shotgun_chrome", "1.2", "Damage score multiplier for chrome shotgun.", FCVAR_NOTIFY, true, 0.0);
    g_hWeaponMult_MP5 = CreateConVar("l4d2_mexp_weapon_mult_mp5", "1.15", "Damage score multiplier for MP5.", FCVAR_NOTIFY, true, 0.0);
    g_hWeaponMult_SG552 = CreateConVar("l4d2_mexp_weapon_mult_sg552", "1.1", "Damage score multiplier for SG552.", FCVAR_NOTIFY, true, 0.0);
    g_hWeaponMult_Rifle = CreateConVar("l4d2_mexp_weapon_mult_rifle", "0.88", "Damage score multiplier for M16.", FCVAR_NOTIFY, true, 0.0);
    g_hWeaponMult_RifleDesert = CreateConVar("l4d2_mexp_weapon_mult_rifle_desert", "0.88", "Damage score multiplier for SCAR/desert rifle.", FCVAR_NOTIFY, true, 0.0);
    g_hWeaponMult_RifleAK47 = CreateConVar("l4d2_mexp_weapon_mult_rifle_ak47", "0.92", "Damage score multiplier for AK47.", FCVAR_NOTIFY, true, 0.0);
    g_hWeaponMult_AutoShotgun = CreateConVar("l4d2_mexp_weapon_mult_autoshotgun", "0.95", "Damage score multiplier for auto shotgun.", FCVAR_NOTIFY, true, 0.0);
    g_hWeaponMult_SpasShotgun = CreateConVar("l4d2_mexp_weapon_mult_shotgun_spas", "0.95", "Damage score multiplier for SPAS shotgun.", FCVAR_NOTIFY, true, 0.0);
    g_hWeaponMult_HuntingRifle = CreateConVar("l4d2_mexp_weapon_mult_hunting_rifle", "0.96", "Damage score multiplier for hunting rifle.", FCVAR_NOTIFY, true, 0.0);
    g_hWeaponMult_SniperMilitary = CreateConVar("l4d2_mexp_weapon_mult_sniper_military", "0.84", "Damage score multiplier for military sniper.", FCVAR_NOTIFY, true, 0.0);
    g_hWeaponMult_SniperScout = CreateConVar("l4d2_mexp_weapon_mult_sniper_scout", "0.75", "Damage score multiplier for Scout sniper.", FCVAR_NOTIFY, true, 0.0);
    g_hWeaponMult_SniperAWP = CreateConVar("l4d2_mexp_weapon_mult_sniper_awp", "0.70", "Damage score multiplier for AWP sniper.", FCVAR_NOTIFY, true, 0.0);
    g_hWeaponDecayEnable = CreateConVar("l4d2_mexp_weapon_decay_enable", "1", "0=Disable per-weapon usage decay, 1=Enable for rifles, sniper rifles, and auto shotguns.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_hWeaponDecayEnable.AddChangeHook(ConVarChanged_WeaponDecayEnable);
    g_hWeaponDecayStart = CreateConVar("l4d2_mexp_weapon_decay_start", "120.0", "Full damage score multiplier before this many accumulated active-use seconds.", FCVAR_NOTIFY, true, 0.0);
    g_hWeaponDecayZero = CreateConVar("l4d2_mexp_weapon_decay_zero", "420.0", "Damage score multiplier reaches zero at this many accumulated active-use seconds.", FCVAR_NOTIFY, true, 0.0);
    g_hWeaponDecayAutoShotgunStart = CreateConVar("l4d2_mexp_weapon_decay_autoshotgun_start", "180.0", "Full damage score multiplier duration for auto shotguns.", FCVAR_NOTIFY, true, 0.0);
    g_hWeaponDecayAutoShotgunZero = CreateConVar("l4d2_mexp_weapon_decay_autoshotgun_zero", "600.0", "Auto-shotgun damage score multiplier reaches zero at this accumulated active-use time.", FCVAR_NOTIFY, true, 0.0);
    g_hWeaponDecayRecoveryRate = CreateConVar("l4d2_mexp_weapon_decay_recovery_rate", "1.0", "Usage seconds recovered per second while that weapon class is not active.", FCVAR_NOTIFY, true, 0.0);
    g_hWeaponDecayNotifyRearmBuffer = CreateConVar("l4d2_mexp_weapon_decay_notify_rearm_buffer", "20.0", "Usage-time recovery required below a threshold before its decay notification can trigger again.", FCVAR_NOTIFY, true, 0.0);

    g_hW_AccuracyStep = CreateConVar("l4d2_mexp_w_accuracy_step", "1.0", "Score per accuracy step after floor is reached.", FCVAR_NOTIFY, true, 0.0);
    g_hAccuracyMinShots = CreateConVar("l4d2_mexp_accuracy_min_shots", "80", "Minimum tracked weapon fires required before accuracy bonus can apply.", FCVAR_NOTIFY, true, 0.0);
    g_hAccuracyFloor = CreateConVar("l4d2_mexp_accuracy_floor", "0.10", "Accuracy below this ratio gives no bonus.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_hAccuracyStep = CreateConVar("l4d2_mexp_accuracy_step", "0.10", "Accuracy ratio per bonus step. 0.10 means 10%-20% = one step.", FCVAR_NOTIFY, true, 0.01, true, 1.0);
    g_hAccuracyMaxBonus = CreateConVar("l4d2_mexp_accuracy_max_bonus", "6.0", "Maximum round score from accuracy bonus.", FCVAR_NOTIFY, true, 0.0);

    g_hP_Control = CreateConVar("l4d2_mexp_p_control", "1.5", "Penalty per time being controlled by SI.", FCVAR_NOTIFY);
    g_hP_ControlTime = CreateConVar("l4d2_mexp_p_control_time", "0.4", "Penalty per second while controlled by SI.", FCVAR_NOTIFY);
    g_hP_Incap = CreateConVar("l4d2_mexp_p_incap", "20.0", "Penalty per incap.", FCVAR_NOTIFY);
    g_hP_Death = CreateConVar("l4d2_mexp_p_death", "50.0", "Penalty per death.", FCVAR_NOTIFY);
    g_hSaferoomIncapScale = CreateConVar("l4d2_mexp_saferoom_incap_scale", "0.10", "Penalty scale for incaps after entering the end saferoom.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_hSaferoomDeathScale = CreateConVar("l4d2_mexp_saferoom_death_scale", "0.10", "Penalty scale for deaths after entering the end saferoom.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_hP_FFDamage = CreateConVar("l4d2_mexp_p_ff_damage", "0.10", "Penalty per 1 friendly fire damage. 0.10 = -1 per 10 damage.", FCVAR_NOTIFY);
    g_hP_RockHit = CreateConVar("l4d2_mexp_p_rock_hit", "10.0", "Penalty per Tank rock hit taken.", FCVAR_NOTIFY);
    g_hP_TankPunch = CreateConVar("l4d2_mexp_p_tank_punch", "4.0", "Penalty per standing Tank punch taken.", FCVAR_NOTIFY);
    g_hP_TankHittable = CreateConVar("l4d2_mexp_p_tank_hittable", "15.0", "Penalty per standing Tank hittable impact taken.", FCVAR_NOTIFY);
    g_hP_SpitDamage = CreateConVar("l4d2_mexp_p_spit_damage", "0.12", "Penalty per 1 spit damage while standing.", FCVAR_NOTIFY);

    g_hDefaultRating = CreateConVar("l4d2_mexp_default_rating", "1000.0", "Default long-term experience rating for new players.", FCVAR_NOTIFY);
    g_hRatingWeight = CreateConVar("l4d2_mexp_rating_weight", "0.015", "How strongly each valid round affects long-term rating.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_hRankMinRounds = CreateConVar("l4d2_mexp_rank_min_rounds", "5", "Minimum valid rounds required to appear in personal rating rank. 0 includes everyone.", FCVAR_NOTIFY, true, 0.0);
    g_hShortRoundSkipTime = CreateConVar("l4d2_mexp_short_round_skip_time", "300.0", "Rounds shorter than this many seconds announce stats but do not update long-term rating. 0 disables skip.", FCVAR_NOTIFY, true, 0.0);
    g_hShortRoundFullTime = CreateConVar("l4d2_mexp_short_round_full_time", "600.0", "Rounds at or above this many seconds use full rating weight. 0 disables scaling.", FCVAR_NOTIFY, true, 0.0);
    g_hShortRoundMinWeightScale = CreateConVar("l4d2_mexp_short_round_min_weight_scale", "0.25", "Minimum rating weight scale for rounds between skip time and full time.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_hWinLowTeamScoreFloor = CreateConVar("l4d2_mexp_win_low_team_score_floor", "180.0", "On successful map transition/finale, protect rating loss when average valid player score is below this. 0 disables.", FCVAR_NOTIFY, true, 0.0);
    g_hWinLowScoreNegativeScale = CreateConVar("l4d2_mexp_win_low_score_negative_scale", "0.25", "Rating weight scale for negative updates when win low team score protection triggers.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_hEndgameOutsideDeathGuard = CreateConVar("l4d2_mexp_endgame_outside_death_guard", "1", "0=Disable, 1=Protect long-term rating loss for outside-saferoom incaps/deaths after someone reaches end saferoom and the team wins.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_hEndgameOutsideDeathNegativeScale = CreateConVar("l4d2_mexp_endgame_outside_death_negative_scale", "0.50", "Rating weight scale for negative updates caused by endgame outside-saferoom incaps/deaths.", FCVAR_NOTIFY, true, 0.0, true, 1.0);

    g_hAnnounce = CreateConVar("l4d2_mexp_announce", "1", "0=Do not announce round rating, 1=Announce after round end.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_hJoinAnnounce = CreateConVar("l4d2_mexp_join_announce", "1", "0=Do not announce rating when a player joins, 1=Announce rating to all players.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_hJoinAnnounceDelay = CreateConVar("l4d2_mexp_join_announce_delay", "5.0", "Delay before showing join rating message.", FCVAR_NOTIFY, true, 0.1, true, 30.0);
    g_hSave = CreateConVar("l4d2_mexp_save", "1", "0=Do not save long-term rating, 1=Save to data/l4d2_multisi_exp.txt.", FCVAR_NOTIFY, true, 0.0, true, 1.0);

    AutoExecConfig(true, "l4d2_multisi_experience");

    HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
    HookEvent("map_transition", Event_RoundEnd, EventHookMode_PostNoCopy);
    HookEvent("mission_lost", Event_RoundEnd, EventHookMode_PostNoCopy);
    HookEvent("finale_win", Event_RoundEnd, EventHookMode_PostNoCopy);

    HookEvent("player_team", Event_PlayerTeam, EventHookMode_Post);
    HookEvent("player_entered_checkpoint", Event_PlayerEnteredCheckpoint, EventHookMode_Post);
    HookEvent("player_left_checkpoint", Event_PlayerLeftCheckpoint, EventHookMode_Post);
    HookEvent("weapon_fire", Event_WeaponFire, EventHookMode_Post);
    HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Post);
    HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
    HookEvent("infected_death", Event_InfectedDeath, EventHookMode_Post);
    HookEvent("infected_hurt", Event_InfectedHurt, EventHookMode_Post);
    HookEvent("witch_killed", Event_WitchKilled, EventHookMode_Post);
    HookEvent("player_incapacitated", Event_PlayerIncapacitated, EventHookMode_Post);
    HookEvent("revive_success", Event_ReviveSuccess, EventHookMode_Post);
    HookEvent("defibrillator_used", Event_DefibUsed, EventHookMode_Post);

    HookEvent("tongue_grab", Event_TongueGrab, EventHookMode_Post);
    HookEvent("tongue_release", Event_TongueRelease, EventHookMode_Post);
    HookEvent("lunge_pounce", Event_LungePounce, EventHookMode_Post);
    HookEvent("pounce_end", Event_PounceEnd, EventHookMode_Post);
    HookEvent("jockey_ride", Event_JockeyRide, EventHookMode_Post);
    HookEvent("jockey_ride_end", Event_JockeyRideEnd, EventHookMode_Post);
    HookEvent("charger_pummel_start", Event_ChargerPummelStart, EventHookMode_Post);
    HookEvent("charger_pummel_end", Event_ChargerPummelEnd, EventHookMode_Post);

    RegConsoleCmd("sm_mexp", Command_ShowExp, "Show your multi-SI campaign experience rating.");
    RegConsoleCmd("sm_mexp_round", Command_ShowRound, "Show current round experience stats.");
    RegConsoleCmd("sm_mexp_weapon", Command_ShowWeapon, "Show current weapon damage-score decay status.");
    RegAdminCmd("sm_mexp_enable", Command_MExpEnable, ADMFLAG_CONVARS, "Open or change multi-SI experience scoring switch.");

    ResetAllRoundStats();

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
        {
            OnClientPutInServer(i);
            if (GetClientTeam(i) == TEAM_SURVIVOR)
            {
                StartParticipation(i);
            }
        }
    }
}

public void OnMapStart()
{
    g_fRoundStart = GetGameTime();
    g_bRoundEnded = !IsExperienceEnabled();
    g_bRoundEndedByWin = false;
    g_bEndSaferoomReached = false;
    ResetAllRoundStats();
}

public void ConVarChanged_Enable(ConVar convar, const char[] oldValue, const char[] newValue)
{
    bool oldEnabled = StringToInt(oldValue) != 0;
    bool newEnabled = convar.BoolValue;

    if (oldEnabled == newEnabled)
    {
        return;
    }

    g_fRoundStart = GetGameTime();
    g_bRoundEnded = !newEnabled;
    g_bRoundEndedByWin = false;
    g_bEndSaferoomReached = false;
    ResetAllRoundStats();

    if (newEnabled)
    {
        PrintToChatAll("\x04[经验]\x01 经验分计分已开启，本关从现在开始重新记录。");
    }
    else
    {
        PrintToChatAll("\x04[经验]\x01 经验分计分已关闭，本关统计已清空，不会结算或保存。");
    }
}

public void ConVarChanged_WeaponDecayEnable(ConVar convar, const char[] oldValue, const char[] newValue)
{
    bool enabled = convar.BoolValue;
    for (int i = 1; i <= MaxClients; i++)
    {
        ResetClientWeaponDecay(i);
        if (enabled && IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVOR)
        {
            SyncActiveDecayWeapon(i);
        }
    }
}

public void OnMapEnd()
{
    for (int i = 1; i <= MaxClients; i++)
    {
        EndParticipation(i);
        EndControl(i);
        if (IsClientInGame(i) && !IsFakeClient(i) && g_bLoaded[i])
        {
            SavePlayer(i);
        }
    }
}

public void OnEntityCreated(int entity, const char[] classname)
{
    if (entity > 0 && entity < MAX_TRACKED_ENTITIES)
    {
        g_bRockDestroyAwarded[entity] = false;
    }

    if (StrEqual(classname, "tank_rock", false))
    {
        SDKHook(entity, SDKHook_OnTakeDamage, OnTankRockTakeDamage);
    }
}

public void OnEntityDestroyed(int entity)
{
    if (entity > 0 && entity < MAX_TRACKED_ENTITIES)
    {
        g_bRockDestroyAwarded[entity] = false;
    }
}

public void OnClientPutInServer(int client)
{
    SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
    SDKHook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitchPost);

    g_bLoaded[client] = false;
    g_fRating[client] = g_hDefaultRating != null ? g_hDefaultRating.FloatValue : 1000.0;
    g_iValidRounds[client] = 0;
    ResetClientWeaponDecay(client);
    SyncActiveDecayWeapon(client);
}

public void OnClientPostAdminCheck(int client)
{
    if (!IsValidClient(client) || IsFakeClient(client))
    {
        return;
    }

    if (!g_bLoaded[client])
    {
        LoadPlayer(client);
    }

    if (IsExperienceEnabled() && g_hJoinAnnounce.BoolValue)
    {
        CreateTimer(g_hJoinAnnounceDelay.FloatValue, Timer_AnnounceJoinExp, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
    }
}

public Action Timer_AnnounceJoinExp(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);
    if (!IsValidClient(client) || IsFakeClient(client) || !IsExperienceEnabled() || !g_hJoinAnnounce.BoolValue)
    {
        return Plugin_Stop;
    }

    if (!g_bLoaded[client])
    {
        LoadPlayer(client);
    }

    if (!g_bLoaded[client])
    {
        return Plugin_Stop;
    }

    PrintToChatAll("\x04[经验]\x03%N\x01 加入服务器，当前经验分：\x03%.0f\x01，有效关卡：\x03%d\x01。", client, g_fRating[client], g_iValidRounds[client]);
    return Plugin_Stop;
}

public void OnClientDisconnect(int client)
{
    EndParticipation(client);
    EndControl(client);

    if (!IsFakeClient(client) && g_bLoaded[client])
    {
        SavePlayer(client);
    }

    SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
    SDKUnhook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitchPost);
    ClearClientAll(client);
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    g_fRoundStart = GetGameTime();
    g_bRoundEnded = !IsExperienceEnabled();
    g_bRoundEndedByWin = false;
    g_bEndSaferoomReached = false;
    ResetAllRoundStats();

    if (!IsExperienceEnabled())
    {
        return;
    }

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVOR)
        {
            StartParticipation(i);
        }
    }
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    g_bRoundEndedByWin = StrEqual(name, "map_transition", false) || StrEqual(name, "finale_win", false);
    TryFinalizeRound();
}

void TryFinalizeRound()
{
    if (g_bRoundEnded)
    {
        return;
    }

    if (!IsExperienceEnabled())
    {
        g_bRoundEnded = true;
        return;
    }

    g_bRoundEnded = true;

    for (int i = 1; i <= MaxClients; i++)
    {
        EndControl(i);
        EndParticipation(i);
    }

    CreateTimer(0.5, Timer_FinalizeRound, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_FinalizeRound(Handle timer)
{
    if (!IsExperienceEnabled())
    {
        return Plugin_Stop;
    }

    FinalizeRound();
    return Plugin_Stop;
}

void FinalizeRound()
{
    if (!IsExperienceEnabled())
    {
        return;
    }

    float duration = GetGameTime() - g_fRoundStart;
    if (duration < 1.0)
    {
        return;
    }

    float required = GetRequiredPlayTime(duration);

    int validCount = CountValidPlayers(required);
    if (validCount < g_hMinPlayers.IntValue)
    {
        return;
    }

    float ratingWeightScale = GetShortRoundWeightScale(duration);
    float roundScores[MAXPLAYERS + 1];
    float teamScoreTotal = 0.0;
    int scoreCount = 0;

    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsValidCandidate(client, required))
        {
            continue;
        }

        roundScores[client] = CalculateRoundScore(client);
        teamScoreTotal += roundScores[client];
        scoreCount++;
    }

    if (scoreCount <= 0)
    {
        return;
    }

    float teamAverageScore = teamScoreTotal / float(scoreCount);
    float teamNegativeWeightScale = ratingWeightScale > 0.0 ? GetWinLowScoreNegativeScale(teamAverageScore) : 1.0;
    bool hasEndgameOutsideGuard = false;

    int best = 0;
    float bestRoundScore = -999999.0;

    if (g_hAnnounce.BoolValue)
    {
        PrintToChatAll("\x04本局经验分评定：");

        if (ratingWeightScale <= 0.0)
        {
            PrintToChatAll("\x05短图保护：\x01本关时长 %.0f 秒，只播报评分，长期经验不变。", duration);
        }
        else if (ratingWeightScale < 0.999)
        {
            PrintToChatAll("\x05短图保护：\x01本关时长 %.0f 秒，长期经验影响倍率 %.0f%%。", duration, ratingWeightScale * 100.0);
        }

        if (teamNegativeWeightScale < 0.999)
        {
            PrintToChatAll("\x05过关低分保护：\x01团队均分 %.1f，低于 %.1f，本关掉分影响倍率 %.0f%%。",
                teamAverageScore,
                g_hWinLowTeamScoreFloor.FloatValue,
                teamNegativeWeightScale * 100.0
            );
        }
    }

    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsValidCandidate(client, required))
        {
            continue;
        }

        float roundScore = roundScores[client];
        if (ratingWeightScale > 0.0)
        {
            float playerNegativeWeightScale = GetPlayerNegativeWeightScale(client, teamNegativeWeightScale);
            if (HasEndgameOutsideAccident(client))
            {
                hasEndgameOutsideGuard = true;
            }
            UpdateRating(client, roundScore, ratingWeightScale, playerNegativeWeightScale);
        }

        if (roundScore > bestRoundScore)
        {
            bestRoundScore = roundScore;
            best = client;
        }

        if (g_hAnnounce.BoolValue)
        {
            PrintToChatAll("\x03%N\x01 本关 %.1f 分 | 经验 %.0f | 小尸 %d | 坦伤 %.0f(计%.0f) | 清控 %d | 承压 %d | 倒地 %d",
                client,
                roundScore,
                g_fRating[client],
                g_iCommonKills[client],
                g_fTankRawDamage[client],
                g_fTankDamage[client],
                g_iClears[client],
                g_iControlsSurvived[client],
                g_iIncaps[client]
            );
        }

        if (ratingWeightScale > 0.0 && !IsFakeClient(client) && g_hSave.BoolValue)
        {
            SavePlayer(client);
        }
    }

    if (g_hAnnounce.BoolValue && IsValidClient(best))
    {
        if (hasEndgameOutsideGuard)
        {
            PrintToChatAll("\x05终点阶段保护：\x01有玩家在终点安全屋外倒地/死亡，本关仅降低其长期掉分影响。");
        }

        PrintToChatAll("\x05本局团队核心：\x03%N\x01，综合表现 %.1f 分。", best, bestRoundScore);
    }
}

public Action Command_ShowExp(int client, int args)
{
    if (!IsValidClient(client))
    {
        return Plugin_Handled;
    }

    if (!g_bLoaded[client] && !IsFakeClient(client))
    {
        LoadPlayer(client);
    }

    if (!g_bLoaded[client] && !IsFakeClient(client))
    {
        PrintToChat(client, "\x04[经验]\x01 经验档案还在读取中，请稍后再试。");
        return Plugin_Handled;
    }

    PrintToChat(client, "\x04[经验]\x01 %N 当前经验分：\x03%.0f\x01，有效关卡：\x03%d", client, g_fRating[client], g_iValidRounds[client]);

    int minRounds = g_hRankMinRounds.IntValue;
    if (g_iValidRounds[client] < minRounds)
    {
        PrintToChat(client, "\x04[排名]\x01 暂未上榜，至少需要 \x03%d\x01 个有效关卡。", minRounds);
        return Plugin_Handled;
    }

    int rank;
    int rankedPlayers;
    if (GetPlayerRatingRank(client, rank, rankedPlayers))
    {
        PrintToChat(client, "\x04[排名]\x01 服务器经验分排名：\x03%d/%d\x01。", rank, rankedPlayers);
    }
    else
    {
        PrintToChat(client, "\x04[排名]\x01 排名暂时无法读取，请稍后再试。");
    }

    return Plugin_Handled;
}

public Action Command_ShowRound(int client, int args)
{
    if (!IsValidClient(client))
    {
        return Plugin_Handled;
    }

    if (!IsExperienceEnabled())
    {
        PrintToChat(client, "\x04[经验]\x01 当前地图经验分计分已关闭，本关不会记录、结算或保存。");
        return Plugin_Handled;
    }

    float score = CalculateRoundScore(client);
    float accuracy = GetAccuracyRatio(client) * 100.0;
    float accuracyBonus = CalculateAccuracyBonus(client);
    float skillBonus = CalculateSkillBonus(client);

    PrintToChat(client, "\x04[本关]\x01 评分 %.1f | 命 %.0f%%/%d | 命+ %.1f | 小尸 %d | 特伤 %.0f(计%.0f) | 特杀 %d",
        score,
        accuracy,
        g_iAccuracyShots[client],
        accuracyBonus,
        g_iCommonKills[client],
        g_fSIRawDamage[client],
        g_fSIDamage[client],
        g_iSIKills[client]
    );

    PrintToChat(client, "\x04[输出]\x01 坦伤 %.0f(计%.0f) | 坦杀 %d | 坦一 %d | Witch %d | 石破 %d | 石中 %d",
        g_fTankRawDamage[client],
        g_fTankDamage[client],
        g_iTankKills[client],
        g_iTankTopDamage[client],
        g_iWitchKills[client],
        g_iRockDestroys[client],
        g_iRockHits[client]
    );

    PrintToChat(client, "\x04[状态]\x01 清控 %d | 承压 %d | 救人 %d | 被控 %d | 控时 %.1f | 倒地 %d | 安倒 %d | 死亡 %d | 安死 %d",
        g_iClears[client],
        g_iControlsSurvived[client],
        g_iRevives[client],
        g_iControlsTaken[client],
        g_fControlDuration[client],
        g_iIncaps[client],
        g_iSaferoomIncaps[client],
        g_iDeaths[client],
        g_iSaferoomDeaths[client]
    );

    PrintToChat(client, "\x04[失误]\x01 拳 %d | 打铁 %d | 酸 %.0f | 友伤 %.0f",
        g_iTankPunches[client],
        g_iTankHittables[client],
        g_fSpitDamage[client],
        g_fFriendlyFire[client]
    );

    PrintToChat(client, "\x04[技巧]\x01 空爆 %d | 近爆 %d | 砍舌 %d | 推停 %d",
        g_iSkeets[client],
        g_iMeleeSkeets[client],
        g_iTongueCuts[client],
        g_iHunterDeadstops[client]
    );

    PrintToChat(client, "\x04[技巧]\x01 秒牛 %d | 秒救 %d | 自救 %d | 加分 %.1f",
        g_iChargerLevels[client],
        g_iFastClears[client],
        g_iSmokerSelfClears[client],
        skillBonus
    );

    return Plugin_Handled;
}

public Action Command_ShowWeapon(int client, int args)
{
    if (!IsValidClient(client))
    {
        return Plugin_Handled;
    }

    if (!IsExperienceEnabled())
    {
        PrintToChat(client, "\x04[武器]\x01 当前地图经验分计分已关闭，武器持用时间不会记录。");
        return Plugin_Handled;
    }

    ShowWeaponDecayStatus(client);
    return Plugin_Handled;
}

public void OnSkeet(int survivor, int hunter)
{
    if (IsValidSurvivor(survivor) && ShouldTrackClient(survivor))
    {
        g_iSkeets[survivor]++;
    }
}

public void OnSkeetMelee(int survivor, int hunter)
{
    if (IsValidSurvivor(survivor) && ShouldTrackClient(survivor))
    {
        g_iMeleeSkeets[survivor]++;
    }
}

public void OnTongueCut(int survivor, int smoker)
{
    if (IsValidSurvivor(survivor) && ShouldTrackClient(survivor))
    {
        g_iTongueCuts[survivor]++;
    }
}

public void OnHunterDeadstop(int survivor, int hunter)
{
    if (IsValidSurvivor(survivor) && ShouldTrackClient(survivor))
    {
        g_iHunterDeadstops[survivor]++;
    }
}

public void OnChargerLevel(int survivor, int charger)
{
    if (IsValidSurvivor(survivor) && ShouldTrackClient(survivor))
    {
        g_iChargerLevels[survivor]++;
    }
}

public void OnChargerLevelHurt(int survivor, int charger, int damage)
{
    if (IsValidSurvivor(survivor) && ShouldTrackClient(survivor))
    {
        g_iChargerLevels[survivor]++;
    }
}

public void OnSmokerSelfClear(int survivor, int smoker, bool withShove)
{
    if (IsValidSurvivor(survivor) && ShouldTrackClient(survivor))
    {
        g_iSmokerSelfClears[survivor]++;
    }
}

public void OnSpecialClear(int clearer, int pinner, int pinVictim, int zombieClass, float timeA, float timeB, bool withShove)
{
    if (!IsValidSurvivor(clearer) || !ShouldTrackClient(clearer) || !IsValidSurvivor(pinVictim) || clearer == pinVictim)
    {
        return;
    }

    float threshold = g_hFastClearTime.FloatValue;
    float clearTime = (zombieClass == ZC_SMOKER || zombieClass == ZC_CHARGER) ? timeB : timeA;
    if (threshold <= 0.0 || clearTime < 0.0 || clearTime > threshold)
    {
        return;
    }

    float now = GetGameTime();
    if (g_iLastFastClearPinner[clearer] == pinner
        && g_iLastFastClearVictim[clearer] == pinVictim
        && now - g_fLastFastClearAt[clearer] <= 0.25)
    {
        return;
    }

    g_iLastFastClearPinner[clearer] = pinner;
    g_iLastFastClearVictim[clearer] = pinVictim;
    g_fLastFastClearAt[clearer] = now;
    g_iFastClears[clearer]++;
}

public Action Command_MExpEnable(int client, int args)
{
    if (args < 1)
    {
        if (IsValidClient(client))
        {
            ShowEnableMenu(client);
        }
        else
        {
            ReplyToCommand(client, "[MEXP] l4d2_mexp_enable = %d. Usage: sm_mexp_enable <0|1|toggle|status>", IsExperienceEnabled() ? 1 : 0);
        }

        return Plugin_Handled;
    }

    char arg[16];
    GetCmdArg(1, arg, sizeof(arg));

    if (StrEqual(arg, "status", false))
    {
        ReplyToCommand(client, "[MEXP] Current scoring status: %s.", IsExperienceEnabled() ? "enabled" : "disabled");
        return Plugin_Handled;
    }

    if (StrEqual(arg, "toggle", false))
    {
        SetExperienceEnabled(!IsExperienceEnabled(), client);
        return Plugin_Handled;
    }

    if (StrEqual(arg, "1", false) || StrEqual(arg, "on", false) || StrEqual(arg, "enable", false) || StrEqual(arg, "open", false))
    {
        SetExperienceEnabled(true, client);
        return Plugin_Handled;
    }

    if (StrEqual(arg, "0", false) || StrEqual(arg, "off", false) || StrEqual(arg, "disable", false) || StrEqual(arg, "close", false))
    {
        SetExperienceEnabled(false, client);
        return Plugin_Handled;
    }

    ReplyToCommand(client, "[MEXP] Usage: sm_mexp_enable <0|1|toggle|status>");
    return Plugin_Handled;
}

void ShowEnableMenu(int client)
{
    Menu menu = new Menu(MenuHandler_MExpEnable);
    menu.SetTitle("经验分计分开关\n当前状态: %s", IsExperienceEnabled() ? "开启" : "关闭");
    menu.AddItem("1", "开启计分");
    menu.AddItem("0", "关闭计分");
    menu.AddItem("toggle", "切换状态");
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_MExpEnable(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_End)
    {
        delete menu;
    }
    else if (action == MenuAction_Select)
    {
        int client = param1;
        char info[16];
        menu.GetItem(param2, info, sizeof(info));

        if (StrEqual(info, "toggle", false))
        {
            SetExperienceEnabled(!IsExperienceEnabled(), client);
        }
        else if (StrEqual(info, "1", false))
        {
            SetExperienceEnabled(true, client);
        }
        else if (StrEqual(info, "0", false))
        {
            SetExperienceEnabled(false, client);
        }
    }

    return 0;
}

void SetExperienceEnabled(bool enabled, int client)
{
    if (IsExperienceEnabled() == enabled)
    {
        ReplyToCommand(client, "[MEXP] Experience scoring is already %s.", enabled ? "enabled" : "disabled");
        return;
    }

    g_hEnable.BoolValue = enabled;
}

public void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
    if (!IsExperienceEnabled())
    {
        return;
    }

    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!IsValidClient(client))
    {
        return;
    }

    int team = event.GetInt("team");
    int oldteam = event.GetInt("oldteam");

    if (oldteam == TEAM_SURVIVOR && team != TEAM_SURVIVOR)
    {
        SetActiveDecayWeapon(client, DecayWeapon_None);
        EndParticipation(client);
        EndControl(client);
    }
    else if (team == TEAM_SURVIVOR && oldteam != TEAM_SURVIVOR)
    {
        StartParticipation(client);
        SyncActiveDecayWeapon(client);
    }
}

public void OnWeaponSwitchPost(int client, int weapon)
{
    if (!IsExperienceEnabled() || !g_hWeaponDecayEnable.BoolValue || !IsValidSurvivor(client) || !ShouldTrackClient(client))
    {
        SetActiveDecayWeapon(client, DecayWeapon_None);
        return;
    }

    char classname[64];
    if (weapon <= MaxClients || !IsValidEntity(weapon) || !GetEntityClassname(weapon, classname, sizeof(classname)))
    {
        SetActiveDecayWeapon(client, DecayWeapon_None);
        return;
    }

    SetActiveDecayWeapon(client, GetDecayWeaponType(classname));
}

public void Event_PlayerEnteredCheckpoint(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!IsValidSurvivor(client) || !ShouldTrackClient(client))
    {
        return;
    }

    if (g_bHasLeftCheckpoint[client])
    {
        g_bInEndSaferoom[client] = true;
        g_bEndSaferoomReached = true;
    }
}

public void Event_PlayerLeftCheckpoint(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!IsValidSurvivor(client) || !ShouldTrackClient(client))
    {
        return;
    }

    g_bHasLeftCheckpoint[client] = true;
    g_bInEndSaferoom[client] = false;
}

public void Event_WeaponFire(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!IsValidSurvivor(client) || !ShouldTrackClient(client) || !IsAccuracyTrackedWeapon(client))
    {
        return;
    }

    g_iAccuracyShots[client]++;
    CheckActiveWeaponDecayNotification(client);
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
    if (!IsExperienceEnabled() || damage <= 0.0)
    {
        return Plugin_Continue;
    }

    if (!IsValidClient(victim))
    {
        return Plugin_Continue;
    }

    ClearPendingInfectedDamage(victim);

    bool victimStanding = IsValidSurvivor(victim) && !IsSurvivorIncapacitatedOrHanging(victim);

    if (IsValidSurvivor(victim) && (IsTankRock(inflictor) || IsTankRock(attacker)))
    {
        if (ShouldTrackClient(victim))
        {
            g_iRockHits[victim]++;
        }

        return Plugin_Continue;
    }

    if (IsValidSurvivor(victim) && IsValidSurvivor(attacker) && attacker != victim)
    {
        if (ShouldTrackClient(attacker))
        {
            g_fFriendlyFire[attacker] += damage;
        }

        return Plugin_Continue;
    }

    if (victimStanding && ShouldTrackClient(victim))
    {
        if (IsSpitDamage(inflictor, attacker))
        {
            g_fSpitDamage[victim] += damage;
        }
        else if (IsTankHittable(inflictor) && IsTankClient(attacker))
        {
            g_iTankHittables[victim]++;
        }
        else if (IsTankClient(attacker))
        {
            g_iTankPunches[victim]++;
        }
    }

    if (IsValidSurvivor(attacker) && IsValidClient(victim) && GetClientTeam(victim) == TEAM_INFECTED)
    {
        CountAccuracyHit(attacker);

        if (ShouldTrackClient(attacker))
        {
            int zc = GetZombieClass(victim);
            int health = GetClientHealth(victim);
            if ((IsNormalSpecialClass(zc) || zc == ZC_TANK) && health > 0)
            {
                // Damage-fix plugins may rewrite damage later; player_hurt resolves the real health loss.
                g_bPendingInfectedDamage[victim] = true;
                g_iPendingDamageAttacker[victim] = attacker;
                g_iPendingDamagePreHealth[victim] = health;
                g_iPendingDamageZombieClass[victim] = zc;
                g_fPendingDamageMultiplier[victim] = GetWeaponScoreMultiplier(attacker);
            }
        }
    }

    return Plugin_Continue;
}

public void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
    if (!IsExperienceEnabled())
    {
        return;
    }

    int victim = GetClientOfUserId(event.GetInt("userid"));
    if (!IsValidClient(victim) || !g_bPendingInfectedDamage[victim])
    {
        return;
    }

    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    int pendingAttacker = g_iPendingDamageAttacker[victim];
    int preHealth = g_iPendingDamagePreHealth[victim];
    int zc = g_iPendingDamageZombieClass[victim];
    float weaponMultiplier = g_fPendingDamageMultiplier[victim];
    ClearPendingInfectedDamage(victim);

    if (attacker != pendingAttacker || !IsValidSurvivor(attacker) || !ShouldTrackClient(attacker))
    {
        return;
    }

    int postHealth = event.GetInt("health");
    if (postHealth < 0)
    {
        postHealth = 0;
    }

    float actualDamage = float(preHealth - postHealth);
    if (actualDamage <= 0.0)
    {
        return;
    }

    float scaledDamage = actualDamage * weaponMultiplier;
    if (IsNormalSpecialClass(zc))
    {
        g_fSIRawDamage[attacker] += actualDamage;
        g_fSIDamage[attacker] += scaledDamage;
    }
    else if (zc == ZC_TANK)
    {
        g_fTankRawDamage[attacker] += actualDamage;
        g_fTankDamage[attacker] += scaledDamage;
        g_fTankDamageByTank[victim][attacker] += scaledDamage;
        g_fTankRawDamageByTank[victim][attacker] += actualDamage;
    }
}

public Action OnTankRockTakeDamage(int entity, int &attacker, int &inflictor, float &damage, int &damagetype)
{
    if (!IsExperienceEnabled() || damage <= 0.0 || !IsValidSurvivor(attacker) || !ShouldTrackClient(attacker))
    {
        return Plugin_Continue;
    }

    if (!IsTankRock(entity))
    {
        return Plugin_Continue;
    }

    if (entity > 0 && entity < MAX_TRACKED_ENTITIES && g_bRockDestroyAwarded[entity])
    {
        return Plugin_Continue;
    }

    int health = GetEntityHealthSafe(entity);
    if (health > 0 && damage >= float(health))
    {
        g_iRockDestroys[attacker]++;

        if (entity > 0 && entity < MAX_TRACKED_ENTITIES)
        {
            g_bRockDestroyAwarded[entity] = true;
        }
    }

    return Plugin_Continue;
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    if (!IsExperienceEnabled())
    {
        return;
    }

    int victim = GetClientOfUserId(event.GetInt("userid"));
    int attacker = GetClientOfUserId(event.GetInt("attacker"));

    if (!IsValidClient(victim))
    {
        return;
    }

    if (IsValidSurvivor(victim))
    {
        SetActiveDecayWeapon(victim, DecayWeapon_None);
        if (ShouldTrackClient(victim))
        {
            g_iDeaths[victim]++;
            if (g_bInEndSaferoom[victim])
            {
                g_iSaferoomDeaths[victim]++;
            }
            else if (IsEndgameOutsideSaferoom(victim))
            {
                g_iEndgameOutsideDeaths[victim]++;
            }
        }
        EndControl(victim);
        return;
    }

    if (GetClientTeam(victim) != TEAM_INFECTED)
    {
        return;
    }

    int zc = GetZombieClass(victim);
    if (zc == ZC_TANK)
    {
        if (IsValidSurvivor(attacker) && ShouldTrackClient(attacker))
        {
            g_iTankKills[attacker]++;
        }

        int topDamageDealer = GetTankTopDamageDealer(victim);
        if (IsValidSurvivor(topDamageDealer) && ShouldTrackClient(topDamageDealer))
        {
            g_iTankTopDamage[topDamageDealer]++;
        }

        ResetTankDamageForTank(victim);
        return;
    }

    if (IsValidSurvivor(attacker) && ShouldTrackClient(attacker))
    {
        if (IsNormalSpecialClass(zc))
        {
            g_iSIKills[attacker]++;

            int pinned = GetPinnedVictim(victim, zc);
            if (!IsValidSurvivor(pinned))
            {
                pinned = FindControlledVictimByAttacker(victim);
            }
            if (!IsValidSurvivor(pinned))
            {
                pinned = FindRecentlyControlledVictimByAttacker(victim);
            }

            if (IsValidSurvivor(pinned))
            {
                g_iClears[attacker]++;
            }
        }
    }
}

public void Event_InfectedDeath(Event event, const char[] name, bool dontBroadcast)
{
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    if (!IsValidSurvivor(attacker) || !ShouldTrackClient(attacker))
    {
        return;
    }

    g_iCommonKills[attacker]++;
}

public void Event_InfectedHurt(Event event, const char[] name, bool dontBroadcast)
{
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    if (!IsValidSurvivor(attacker) || !ShouldTrackClient(attacker))
    {
        return;
    }

    CountAccuracyHit(attacker);
}

public void Event_WitchKilled(Event event, const char[] name, bool dontBroadcast)
{
    int attacker = GetClientOfUserId(event.GetInt("userid"));
    if (!IsValidSurvivor(attacker))
    {
        attacker = GetClientOfUserId(event.GetInt("attacker"));
    }

    if (IsValidSurvivor(attacker) && ShouldTrackClient(attacker))
    {
        g_iWitchKills[attacker]++;
    }
}

public void Event_PlayerIncapacitated(Event event, const char[] name, bool dontBroadcast)
{
    int victim = GetClientOfUserId(event.GetInt("userid"));
    if (IsValidSurvivor(victim) && ShouldTrackClient(victim))
    {
        g_iIncaps[victim]++;
        if (g_bInEndSaferoom[victim])
        {
            g_iSaferoomIncaps[victim]++;
        }
        else if (IsEndgameOutsideSaferoom(victim))
        {
            g_iEndgameOutsideIncaps[victim]++;
        }
    }
}

public void Event_ReviveSuccess(Event event, const char[] name, bool dontBroadcast)
{
    int reviver = GetClientOfUserId(event.GetInt("userid"));
    if (IsValidSurvivor(reviver) && ShouldTrackClient(reviver))
    {
        g_iRevives[reviver]++;
    }
}

public void Event_DefibUsed(Event event, const char[] name, bool dontBroadcast)
{
    int reviver = GetClientOfUserId(event.GetInt("userid"));
    if (IsValidSurvivor(reviver) && ShouldTrackClient(reviver))
    {
        g_iDefibs[reviver]++;
    }
}

public void Event_TongueGrab(Event event, const char[] name, bool dontBroadcast)
{
    int attacker = GetClientOfUserId(event.GetInt("userid"));
    int victim = GetClientOfUserId(event.GetInt("victim"));
    StartControl(victim, CONTROL_SMOKER, attacker);
}

public void Event_TongueRelease(Event event, const char[] name, bool dontBroadcast)
{
    if (!IsExperienceEnabled())
    {
        return;
    }

    int victim = GetClientOfUserId(event.GetInt("victim"));
    EndControl(victim);
}

public void Event_LungePounce(Event event, const char[] name, bool dontBroadcast)
{
    int attacker = GetClientOfUserId(event.GetInt("userid"));
    int victim = GetClientOfUserId(event.GetInt("victim"));
    StartControl(victim, CONTROL_HUNTER, attacker);
}

public void Event_PounceEnd(Event event, const char[] name, bool dontBroadcast)
{
    if (!IsExperienceEnabled())
    {
        return;
    }

    int victim = GetClientOfUserId(event.GetInt("victim"));
    EndControl(victim);
}

public void Event_JockeyRide(Event event, const char[] name, bool dontBroadcast)
{
    int attacker = GetClientOfUserId(event.GetInt("userid"));
    int victim = GetClientOfUserId(event.GetInt("victim"));
    StartControl(victim, CONTROL_JOCKEY, attacker);
}

public void Event_JockeyRideEnd(Event event, const char[] name, bool dontBroadcast)
{
    if (!IsExperienceEnabled())
    {
        return;
    }

    int victim = GetClientOfUserId(event.GetInt("victim"));
    EndControl(victim);
}

public void Event_ChargerPummelStart(Event event, const char[] name, bool dontBroadcast)
{
    int attacker = GetClientOfUserId(event.GetInt("userid"));
    int victim = GetClientOfUserId(event.GetInt("victim"));
    StartControl(victim, CONTROL_CHARGER, attacker);
}

public void Event_ChargerPummelEnd(Event event, const char[] name, bool dontBroadcast)
{
    if (!IsExperienceEnabled())
    {
        return;
    }

    int victim = GetClientOfUserId(event.GetInt("victim"));
    EndControl(victim);
}

void StartControl(int victim, int controlType, int attacker)
{
    if (!IsValidSurvivor(victim) || !ShouldTrackClient(victim))
    {
        return;
    }

    if (IsSurvivorIncapacitatedOrHanging(victim))
    {
        return;
    }

    if (g_iControlType[victim] != CONTROL_NONE)
    {
        return;
    }

    g_iControlType[victim] = controlType;
    g_iControlAttacker[victim] = attacker;
    g_fControlStart[victim] = GetGameTime();
    g_iControlStartIncaps[victim] = g_iIncaps[victim];
    g_iControlStartDeaths[victim] = g_iDeaths[victim];
    g_iControlsTaken[victim]++;
}

void EndControl(int victim)
{
    if (!IsValidClient(victim))
    {
        return;
    }

    if (g_iControlType[victim] == CONTROL_NONE)
    {
        return;
    }

    g_iLastControlAttacker[victim] = g_iControlAttacker[victim];
    g_fLastControlEndTime[victim] = GetGameTime();

    float elapsed = GetGameTime() - g_fControlStart[victim];
    if (elapsed > 0.0 && elapsed < 120.0)
    {
        g_fControlDuration[victim] += elapsed;

        if (ShouldTrackClient(victim)
            && g_iIncaps[victim] == g_iControlStartIncaps[victim]
            && g_iDeaths[victim] == g_iControlStartDeaths[victim])
        {
            g_iControlsSurvived[victim]++;
        }
    }

    g_iControlType[victim] = CONTROL_NONE;
    g_iControlAttacker[victim] = 0;
    g_fControlStart[victim] = 0.0;
    g_iControlStartIncaps[victim] = 0;
    g_iControlStartDeaths[victim] = 0;
}

void StartParticipation(int client)
{
    if (!ShouldTrackClient(client))
    {
        return;
    }

    if (!g_bSurvivorActive[client])
    {
        g_bSurvivorActive[client] = true;
        g_fJoinStartedAt[client] = GetGameTime();
    }
}

void EndParticipation(int client)
{
    if (client < 1 || client > MaxClients)
    {
        return;
    }

    if (g_bSurvivorActive[client])
    {
        float elapsed = GetGameTime() - g_fJoinStartedAt[client];
        if (elapsed > 0.0 && elapsed < 36000.0)
        {
            g_fPlayAccum[client] += elapsed;
        }
    }

    g_bSurvivorActive[client] = false;
    g_fJoinStartedAt[client] = 0.0;
}

float GetParticipation(int client)
{
    float total = g_fPlayAccum[client];

    if (g_bSurvivorActive[client])
    {
        float elapsed = GetGameTime() - g_fJoinStartedAt[client];
        if (elapsed > 0.0)
        {
            total += elapsed;
        }
    }

    return total;
}

float GetRequiredPlayTime(float roundDuration)
{
    float byRatio = roundDuration * g_hMinPlayRatio.FloatValue;
    float floor = g_hMinPlayFloor.FloatValue;
    float cap = g_hMinPlayTime.FloatValue;

    float required = byRatio;
    if (required < floor)
    {
        required = floor;
    }
    if (required > cap)
    {
        required = cap;
    }

    return required;
}

int CountValidPlayers(float required)
{
    int count = 0;

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsValidCandidate(i, required))
        {
            count++;
        }
    }

    return count;
}

bool IsValidCandidate(int client, float required)
{
    if (!IsValidClient(client))
    {
        return false;
    }

    if (!g_hIncludeBots.BoolValue && IsFakeClient(client))
    {
        return false;
    }

    if (GetParticipation(client) < required)
    {
        return false;
    }

    return true;
}

float CalculateRoundScore(int client)
{
    float score = g_hBaseScore.FloatValue;

    score += g_fSIDamage[client] * g_hW_SIDamage.FloatValue;
    score += float(g_iSIKills[client]) * g_hW_SIKill.FloatValue;
    score += float(g_iCommonKills[client]) * g_hW_CommonKill.FloatValue;
    score += float(g_iClears[client]) * g_hW_Clear.FloatValue;
    score += float(g_iRevives[client]) * g_hW_Revive.FloatValue;
    score += float(g_iDefibs[client]) * g_hW_Defib.FloatValue;
    score += float(g_iControlsSurvived[client]) * g_hW_ControlSurvive.FloatValue;
    score += g_fTankDamage[client] * g_hW_TankDamage.FloatValue;
    score += float(g_iTankKills[client]) * g_hW_TankKill.FloatValue;
    score += float(g_iTankTopDamage[client]) * g_hW_TankTopDamage.FloatValue;
    score += float(g_iWitchKills[client]) * g_hW_WitchKill.FloatValue;
    score += float(g_iRockDestroys[client]) * g_hW_RockDestroy.FloatValue;
    score += CalculateAccuracyBonus(client);
    score += CalculateSkillBonus(client);

    score -= float(g_iControlsTaken[client]) * g_hP_Control.FloatValue;
    score -= g_fControlDuration[client] * g_hP_ControlTime.FloatValue;
    score -= GetScaledPenaltyCount(g_iIncaps[client], g_iSaferoomIncaps[client], g_hSaferoomIncapScale.FloatValue) * g_hP_Incap.FloatValue;
    score -= GetScaledPenaltyCount(g_iDeaths[client], g_iSaferoomDeaths[client], g_hSaferoomDeathScale.FloatValue) * g_hP_Death.FloatValue;
    score -= g_fFriendlyFire[client] * g_hP_FFDamage.FloatValue;
    score -= float(g_iRockHits[client]) * g_hP_RockHit.FloatValue;
    score -= float(g_iTankPunches[client]) * g_hP_TankPunch.FloatValue;
    score -= float(g_iTankHittables[client]) * g_hP_TankHittable.FloatValue;
    score -= g_fSpitDamage[client] * g_hP_SpitDamage.FloatValue;

    float minScore = g_hScoreMin.FloatValue;
    float maxScore = g_hScoreMax.FloatValue;
    float softcap = g_hScoreSoftcap.FloatValue;
    float softcapScale = g_hScoreSoftcapScale.FloatValue;

    if (softcap > minScore && score > softcap)
    {
        score = softcap + ((score - softcap) * softcapScale);
    }

    if (score < minScore)
    {
        score = minScore;
    }

    if (score > maxScore)
    {
        score = maxScore;
    }

    return score;
}

float CalculateSkillBonus(int client)
{
    float bonus = 0.0;
    bonus += float(g_iSkeets[client]) * g_hW_Skeet.FloatValue;
    bonus += float(g_iMeleeSkeets[client]) * g_hW_MeleeSkeet.FloatValue;
    bonus += float(g_iTongueCuts[client]) * g_hW_TongueCut.FloatValue;
    bonus += float(g_iHunterDeadstops[client]) * g_hW_HunterDeadstop.FloatValue;
    bonus += float(g_iChargerLevels[client]) * g_hW_ChargerLevel.FloatValue;
    bonus += float(g_iFastClears[client]) * g_hW_FastClear.FloatValue;
    bonus += float(g_iSmokerSelfClears[client]) * g_hW_SmokerSelfClear.FloatValue;
    return bonus;
}

void UpdateRating(int client, float roundScore, float weightScale, float negativeWeightScale)
{
    if (!g_bLoaded[client])
    {
        if (!IsFakeClient(client))
        {
            LoadPlayer(client);
            if (!g_bLoaded[client])
            {
                return;
            }
        }
        else
        {
            g_fRating[client] = g_hDefaultRating.FloatValue;
            g_iValidRounds[client] = 0;
            g_bLoaded[client] = true;
        }
    }

    float target = roundScore * 10.0;
    float weight = g_hRatingWeight.FloatValue * ClampFloat(weightScale, 0.0, 1.0);
    if (weight <= 0.0)
    {
        return;
    }

    if (target < g_fRating[client])
    {
        weight *= ClampFloat(negativeWeightScale, 0.0, 1.0);
        if (weight <= 0.0)
        {
            return;
        }
    }

    g_fRating[client] = (g_fRating[client] * (1.0 - weight)) + (target * weight);
    g_iValidRounds[client]++;
}

float GetWinLowScoreNegativeScale(float teamAverageScore)
{
    if (!g_bRoundEndedByWin)
    {
        return 1.0;
    }

    float floor = g_hWinLowTeamScoreFloor.FloatValue;
    if (floor <= 0.0 || teamAverageScore >= floor)
    {
        return 1.0;
    }

    return ClampFloat(g_hWinLowScoreNegativeScale.FloatValue, 0.0, 1.0);
}

float GetPlayerNegativeWeightScale(int client, float baseScale)
{
    float scale = ClampFloat(baseScale, 0.0, 1.0);

    if (g_bRoundEndedByWin
        && g_hEndgameOutsideDeathGuard.BoolValue
        && HasEndgameOutsideAccident(client))
    {
        float endgameScale = ClampFloat(g_hEndgameOutsideDeathNegativeScale.FloatValue, 0.0, 1.0);
        if (endgameScale < scale)
        {
            scale = endgameScale;
        }
    }

    return scale;
}

bool HasEndgameOutsideAccident(int client)
{
    if (client < 1 || client > MaxClients)
    {
        return false;
    }

    return g_iEndgameOutsideIncaps[client] > 0 || g_iEndgameOutsideDeaths[client] > 0;
}

bool IsEndgameOutsideSaferoom(int client)
{
    return g_bEndSaferoomReached && IsValidSurvivor(client) && !g_bInEndSaferoom[client];
}

float GetShortRoundWeightScale(float duration)
{
    if (duration < 0.0)
    {
        duration = 0.0;
    }

    float skipTime = g_hShortRoundSkipTime.FloatValue;
    if (skipTime > 0.0 && duration < skipTime)
    {
        return 0.0;
    }

    float fullTime = g_hShortRoundFullTime.FloatValue;
    if (fullTime <= 0.0 || fullTime <= skipTime || duration >= fullTime)
    {
        return 1.0;
    }

    float minScale = ClampFloat(g_hShortRoundMinWeightScale.FloatValue, 0.0, 1.0);
    float ratio = (duration - skipTime) / (fullTime - skipTime);
    ratio = ClampFloat(ratio, 0.0, 1.0);

    return minScale + ((1.0 - minScale) * ratio);
}

float ClampFloat(float value, float minValue, float maxValue)
{
    if (value < minValue)
    {
        return minValue;
    }

    if (value > maxValue)
    {
        return maxValue;
    }

    return value;
}

bool LoadPlayer(int client)
{
    g_fRating[client] = g_hDefaultRating.FloatValue;
    g_iValidRounds[client] = 0;
    g_bLoaded[client] = false;

    if (!g_hSave.BoolValue || IsFakeClient(client))
    {
        g_bLoaded[client] = true;
        return true;
    }

    char auth[64];
    if (!GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth), true))
    {
        return false;
    }

    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), "data/l4d2_multisi_exp.txt");

    KeyValues kv = new KeyValues("L4D2_Multisi_Experience");
    bool fileExists = FileExists(path);
    bool imported = kv.ImportFromFile(path);
    if (fileExists && !imported)
    {
        LogError("[MEXP] Failed to import existing rating data file while loading: %s", path);
        delete kv;
        return false;
    }

    if (kv.JumpToKey(auth, false))
    {
        g_fRating[client] = kv.GetFloat("rating", g_hDefaultRating.FloatValue);
        g_iValidRounds[client] = kv.GetNum("rounds", 0);
    }

    delete kv;
    g_bLoaded[client] = true;
    return true;
}

bool GetPlayerRatingRank(int client, int &rank, int &rankedPlayers)
{
    rank = 0;
    rankedPlayers = 0;

    if (!g_hSave.BoolValue || IsFakeClient(client) || !g_bLoaded[client])
    {
        return false;
    }

    char auth[64];
    if (!GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth), true))
    {
        return false;
    }

    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), "data/l4d2_multisi_exp.txt");

    KeyValues kv = new KeyValues("L4D2_Multisi_Experience");
    if (!kv.ImportFromFile(path))
    {
        delete kv;
        return false;
    }

    int minRounds = g_hRankMinRounds.IntValue;
    int playerRating = RoundToNearest(g_fRating[client]);
    int higherPlayers = 0;

    if (kv.GotoFirstSubKey(false))
    {
        do
        {
            char section[64];
            kv.GetSectionName(section, sizeof(section));
            if (StrEqual(section, auth, false))
            {
                continue;
            }

            if (kv.GetNum("rounds", 0) < minRounds)
            {
                continue;
            }

            int savedRating = RoundToNearest(kv.GetFloat("rating", g_hDefaultRating.FloatValue));
            rankedPlayers++;
            if (savedRating > playerRating)
            {
                higherPlayers++;
            }
        }
        while (kv.GotoNextKey(false));
    }

    delete kv;

    rankedPlayers++;
    rank = higherPlayers + 1;
    return true;
}

void SavePlayer(int client)
{
    if (!g_hSave.BoolValue || IsFakeClient(client) || !g_bLoaded[client])
    {
        return;
    }

    char auth[64];
    if (!GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth), true))
    {
        return;
    }

    char playerName[96];
    GetClientName(client, playerName, sizeof(playerName));

    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), "data/l4d2_multisi_exp.txt");

    KeyValues kv = new KeyValues("L4D2_Multisi_Experience");
    bool fileExists = FileExists(path);
    bool imported = kv.ImportFromFile(path);
    if (fileExists && !imported)
    {
        LogError("[MEXP] Failed to import existing rating data file while saving. Save skipped to avoid data loss: %s", path);
        delete kv;
        return;
    }

    kv.JumpToKey(auth, true);
    kv.SetString("name", playerName);
    kv.SetFloat("rating", g_fRating[client]);
    kv.SetNum("rounds", g_iValidRounds[client]);
    kv.Rewind();
    kv.ExportToFile(path);

    delete kv;
}

int GetZombieClass(int client)
{
    if (!IsValidClient(client))
    {
        return 0;
    }

    if (!HasEntProp(client, Prop_Send, "m_zombieClass"))
    {
        return 0;
    }

    return GetEntProp(client, Prop_Send, "m_zombieClass");
}

bool IsNormalSpecialClass(int zc)
{
    return zc >= ZC_SMOKER && zc <= ZC_CHARGER;
}

void CountAccuracyHit(int client)
{
    if (!IsValidSurvivor(client) || !ShouldTrackClient(client) || !IsAccuracyTrackedWeapon(client))
    {
        return;
    }

    g_iAccuracyHits[client]++;
}

float GetAccuracyRatio(int client)
{
    int shots = g_iAccuracyShots[client];
    if (shots <= 0)
    {
        return 0.0;
    }

    int hits = g_iAccuracyHits[client];
    if (hits > shots)
    {
        hits = shots;
    }

    return float(hits) / float(shots);
}

float CalculateAccuracyBonus(int client)
{
    int shots = g_iAccuracyShots[client];
    if (shots < g_hAccuracyMinShots.IntValue)
    {
        return 0.0;
    }

    float accuracy = GetAccuracyRatio(client);
    float floor = g_hAccuracyFloor.FloatValue;
    if (accuracy < floor)
    {
        return 0.0;
    }

    float step = g_hAccuracyStep.FloatValue;
    if (step <= 0.0)
    {
        return 0.0;
    }

    int steps = RoundToFloor((accuracy - floor) / step) + 1;
    float bonus = float(steps) * g_hW_AccuracyStep.FloatValue;
    float maxBonus = g_hAccuracyMaxBonus.FloatValue;

    if (bonus > maxBonus)
    {
        bonus = maxBonus;
    }

    return bonus;
}

float GetScaledPenaltyCount(int total, int scaled, float scale)
{
    if (scaled < 0)
    {
        scaled = 0;
    }

    if (scaled > total)
    {
        scaled = total;
    }

    int normal = total - scaled;
    return float(normal) + (float(scaled) * scale);
}

bool IsAccuracyTrackedWeapon(int client)
{
    if (!IsValidSurvivor(client))
    {
        return false;
    }

    char weapon[64];
    if (!GetClientWeapon(client, weapon, sizeof(weapon)))
    {
        return false;
    }

    return IsAccuracyTrackedWeaponClass(weapon);
}

bool IsAccuracyTrackedWeaponClass(const char[] weapon)
{
    return StrEqual(weapon, "weapon_pistol", false)
        || StrEqual(weapon, "weapon_pistol_magnum", false)
        || StrEqual(weapon, "weapon_smg", false)
        || StrEqual(weapon, "weapon_smg_silenced", false)
        || StrEqual(weapon, "weapon_smg_mp5", false)
        || StrEqual(weapon, "weapon_pumpshotgun", false)
        || StrEqual(weapon, "weapon_shotgun_chrome", false)
        || StrEqual(weapon, "weapon_autoshotgun", false)
        || StrEqual(weapon, "weapon_shotgun_spas", false)
        || StrEqual(weapon, "weapon_rifle", false)
        || StrEqual(weapon, "weapon_rifle_ak47", false)
        || StrEqual(weapon, "weapon_rifle_desert", false)
        || StrEqual(weapon, "weapon_rifle_sg552", false)
        || StrEqual(weapon, "weapon_rifle_m60", false)
        || StrEqual(weapon, "weapon_hunting_rifle", false)
        || StrEqual(weapon, "weapon_sniper_military", false)
        || StrEqual(weapon, "weapon_sniper_scout", false)
        || StrEqual(weapon, "weapon_sniper_awp", false);
}

float GetWeaponScoreMultiplier(int client)
{
    if (!IsValidSurvivor(client))
    {
        return 1.0;
    }

    char weapon[64];
    if (!GetClientWeapon(client, weapon, sizeof(weapon)))
    {
        SetActiveDecayWeapon(client, DecayWeapon_None);
        return 1.0;
    }

    int decayWeapon = GetDecayWeaponType(weapon);
    SetActiveDecayWeapon(client, g_hWeaponDecayEnable.BoolValue ? decayWeapon : DecayWeapon_None);

    float multiplier = 1.0;

    if (StrEqual(weapon, "weapon_smg", false))
    {
        multiplier = g_hWeaponMult_SMG.FloatValue;
    }
    else if (StrEqual(weapon, "weapon_smg_silenced", false))
    {
        multiplier = g_hWeaponMult_SMGSilenced.FloatValue;
    }
    else if (StrEqual(weapon, "weapon_pumpshotgun", false))
    {
        multiplier = g_hWeaponMult_PumpShotgun.FloatValue;
    }
    else if (StrEqual(weapon, "weapon_shotgun_chrome", false))
    {
        multiplier = g_hWeaponMult_ChromeShotgun.FloatValue;
    }
    else if (StrEqual(weapon, "weapon_smg_mp5", false))
    {
        multiplier = g_hWeaponMult_MP5.FloatValue;
    }
    else if (StrEqual(weapon, "weapon_rifle_sg552", false))
    {
        multiplier = g_hWeaponMult_SG552.FloatValue;
    }
    else if (StrEqual(weapon, "weapon_rifle", false))
    {
        multiplier = g_hWeaponMult_Rifle.FloatValue;
    }
    else if (StrEqual(weapon, "weapon_rifle_desert", false))
    {
        multiplier = g_hWeaponMult_RifleDesert.FloatValue;
    }
    else if (StrEqual(weapon, "weapon_rifle_ak47", false))
    {
        multiplier = g_hWeaponMult_RifleAK47.FloatValue;
    }
    else if (StrEqual(weapon, "weapon_autoshotgun", false))
    {
        multiplier = g_hWeaponMult_AutoShotgun.FloatValue;
    }
    else if (StrEqual(weapon, "weapon_shotgun_spas", false))
    {
        multiplier = g_hWeaponMult_SpasShotgun.FloatValue;
    }
    else if (StrEqual(weapon, "weapon_hunting_rifle", false))
    {
        multiplier = g_hWeaponMult_HuntingRifle.FloatValue;
    }
    else if (StrEqual(weapon, "weapon_sniper_military", false))
    {
        multiplier = g_hWeaponMult_SniperMilitary.FloatValue;
    }
    else if (StrEqual(weapon, "weapon_sniper_scout", false))
    {
        multiplier = g_hWeaponMult_SniperScout.FloatValue;
    }
    else if (StrEqual(weapon, "weapon_sniper_awp", false))
    {
        multiplier = g_hWeaponMult_SniperAWP.FloatValue;
    }

    return multiplier * GetDecayWeaponScoreMultiplier(client, decayWeapon, true);
}

int GetDecayWeaponType(const char[] weapon)
{
    if (StrEqual(weapon, "weapon_rifle", false))
    {
        return DecayWeapon_Rifle;
    }
    if (StrEqual(weapon, "weapon_rifle_desert", false))
    {
        return DecayWeapon_RifleDesert;
    }
    if (StrEqual(weapon, "weapon_rifle_ak47", false))
    {
        return DecayWeapon_RifleAK47;
    }
    if (StrEqual(weapon, "weapon_hunting_rifle", false))
    {
        return DecayWeapon_HuntingRifle;
    }
    if (StrEqual(weapon, "weapon_sniper_military", false))
    {
        return DecayWeapon_SniperMilitary;
    }
    if (StrEqual(weapon, "weapon_sniper_scout", false))
    {
        return DecayWeapon_SniperScout;
    }
    if (StrEqual(weapon, "weapon_sniper_awp", false))
    {
        return DecayWeapon_SniperAWP;
    }
    if (StrEqual(weapon, "weapon_autoshotgun", false))
    {
        return DecayWeapon_AutoShotgun;
    }
    if (StrEqual(weapon, "weapon_shotgun_spas", false))
    {
        return DecayWeapon_SpasShotgun;
    }

    return DecayWeapon_None;
}

void SyncActiveDecayWeapon(int client)
{
    if (!IsExperienceEnabled() || !g_hWeaponDecayEnable.BoolValue || !IsValidSurvivor(client) || !ShouldTrackClient(client))
    {
        SetActiveDecayWeapon(client, DecayWeapon_None);
        return;
    }

    char weapon[64];
    if (!GetClientWeapon(client, weapon, sizeof(weapon)))
    {
        SetActiveDecayWeapon(client, DecayWeapon_None);
        return;
    }

    SetActiveDecayWeapon(client, GetDecayWeaponType(weapon));
}

void SetActiveDecayWeapon(int client, int weaponType)
{
    if (client < 1 || client > MaxClients)
    {
        return;
    }

    if (weaponType < DecayWeapon_None || weaponType >= DecayWeapon_Count)
    {
        weaponType = DecayWeapon_None;
    }

    int oldWeapon = g_iActiveDecayWeapon[client];
    if (oldWeapon == weaponType)
    {
        return;
    }

    float now = GetGameTime();
    if (oldWeapon >= 0 && oldWeapon < DecayWeapon_Count)
    {
        UpdateDecayWeaponTime(client, oldWeapon, now, true);
    }

    g_iActiveDecayWeapon[client] = DecayWeapon_None;

    if (weaponType >= 0 && weaponType < DecayWeapon_Count)
    {
        UpdateDecayWeaponTime(client, weaponType, now, true);
        g_iActiveDecayWeapon[client] = weaponType;
        g_fDecayWeaponUpdatedAt[client][weaponType] = now;
    }
}

float UpdateDecayWeaponTime(int client, int weaponType, float now, bool commit)
{
    float value = g_fDecayWeaponTime[client][weaponType];
    float elapsed = now - g_fDecayWeaponUpdatedAt[client][weaponType];
    if (elapsed < 0.0)
    {
        elapsed = 0.0;
    }

    if (g_iActiveDecayWeapon[client] == weaponType)
    {
        value += elapsed;
    }
    else
    {
        value -= elapsed * g_hWeaponDecayRecoveryRate.FloatValue;
    }

    if (value < 0.0)
    {
        value = 0.0;
    }

    float maxTime = GetDecayWeaponZeroTime(weaponType);
    float startTime = GetDecayWeaponStartTime(weaponType);
    if (maxTime < startTime)
    {
        maxTime = startTime;
    }
    if (maxTime >= 0.0 && value > maxTime)
    {
        value = maxTime;
    }

    if (g_iActiveDecayWeapon[client] != weaponType)
    {
        float zeroTime = GetDecayWeaponZeroTime(weaponType);
        float rearmBuffer = g_hWeaponDecayNotifyRearmBuffer.FloatValue;
        if (zeroTime < startTime)
        {
            zeroTime = startTime;
        }

        float startRearmTime = startTime - rearmBuffer;
        float zeroRearmTime = zeroTime - rearmBuffer;
        if (startRearmTime < 0.0)
        {
            startRearmTime = 0.0;
        }
        if (zeroRearmTime < 0.0)
        {
            zeroRearmTime = 0.0;
        }

        if (value <= startRearmTime)
        {
            g_bDecayStartNotified[client][weaponType] = false;
        }
        if (value <= zeroRearmTime)
        {
            g_bDecayZeroNotified[client][weaponType] = false;
        }
    }

    if (commit)
    {
        g_fDecayWeaponTime[client][weaponType] = value;
        g_fDecayWeaponUpdatedAt[client][weaponType] = now;
    }

    return value;
}

float GetDecayWeaponTime(int client, int weaponType)
{
    if (client < 1 || client > MaxClients || weaponType < 0 || weaponType >= DecayWeapon_Count)
    {
        return 0.0;
    }

    return UpdateDecayWeaponTime(client, weaponType, GetGameTime(), false);
}

void CheckActiveWeaponDecayNotification(int client)
{
    if (!g_hWeaponDecayEnable.BoolValue)
    {
        return;
    }

    SyncActiveDecayWeapon(client);
    int weaponType = g_iActiveDecayWeapon[client];
    if (weaponType >= 0 && weaponType < DecayWeapon_Count)
    {
        GetDecayWeaponScoreMultiplier(client, weaponType, true);
    }
}

float GetDecayWeaponScoreMultiplier(int client, int weaponType, bool notifyThreshold = false)
{
    if (!g_hWeaponDecayEnable.BoolValue || weaponType < 0 || weaponType >= DecayWeapon_Count)
    {
        return 1.0;
    }

    float usageTime = GetDecayWeaponTime(client, weaponType);
    float startTime = GetDecayWeaponStartTime(weaponType);
    float zeroTime = GetDecayWeaponZeroTime(weaponType);
    float multiplier;

    if (zeroTime <= startTime)
    {
        multiplier = usageTime < startTime ? 1.0 : 0.0;
    }
    else if (usageTime <= startTime)
    {
        multiplier = 1.0;
    }
    else if (usageTime >= zeroTime)
    {
        multiplier = 0.0;
    }
    else
    {
        multiplier = (zeroTime - usageTime) / (zeroTime - startTime);
    }

    if (notifyThreshold)
    {
        NotifyWeaponDecayThreshold(client, weaponType, usageTime, startTime, zeroTime, multiplier);
    }

    return multiplier;
}

void NotifyWeaponDecayThreshold(int client, int weaponType, float usageTime, float startTime, float zeroTime, float multiplier)
{
    if (client < 1 || client > MaxClients || weaponType < 0 || weaponType >= DecayWeapon_Count)
    {
        return;
    }

    char weaponName[32];
    GetDecayWeaponName(weaponType, weaponName, sizeof(weaponName));

    if (usageTime >= zeroTime)
    {
        g_bDecayStartNotified[client][weaponType] = true;
        if (!g_bDecayZeroNotified[client][weaponType])
        {
            g_bDecayZeroNotified[client][weaponType] = true;
            PrintToChat(client, "\x04[武器]\x01 %s 持用时间倍率已降至 \x03x0.00\x01，换枪后会逐步恢复。", weaponName);
        }
        return;
    }

    if (usageTime >= startTime && !g_bDecayStartNotified[client][weaponType])
    {
        g_bDecayStartNotified[client][weaponType] = true;
        PrintToChat(client, "\x04[武器]\x01 %s 持用时间已进入衰减，伤害分时间倍率 \x03x%.2f\x01。", weaponName, multiplier);
    }
}

float GetDecayWeaponStartTime(int weaponType)
{
    if (weaponType == DecayWeapon_AutoShotgun || weaponType == DecayWeapon_SpasShotgun)
    {
        return g_hWeaponDecayAutoShotgunStart.FloatValue;
    }

    return g_hWeaponDecayStart.FloatValue;
}

float GetDecayWeaponZeroTime(int weaponType)
{
    if (weaponType == DecayWeapon_AutoShotgun || weaponType == DecayWeapon_SpasShotgun)
    {
        return g_hWeaponDecayAutoShotgunZero.FloatValue;
    }

    return g_hWeaponDecayZero.FloatValue;
}

void ShowWeaponDecayStatus(int client)
{
    if (!g_hWeaponDecayEnable.BoolValue)
    {
        SetActiveDecayWeapon(client, DecayWeapon_None);
        PrintToChat(client, "\x04[武器]\x01 大枪持用时间衰减当前已关闭。");
        return;
    }

    SyncActiveDecayWeapon(client);

    int weaponType = g_iActiveDecayWeapon[client];
    float usageTime = 0.0;
    bool active = weaponType >= 0 && weaponType < DecayWeapon_Count;
    if (active)
    {
        usageTime = GetDecayWeaponTime(client, weaponType);
    }
    else if (!GetHighestDecayWeaponTime(client, weaponType, usageTime))
    {
        PrintToChat(client, "\x04[武器]\x01 当前枪械不参与持用时间衰减，暂无恢复中的大枪。");
        return;
    }

    char weaponName[32];
    GetDecayWeaponName(weaponType, weaponName, sizeof(weaponName));
    float multiplier = GetDecayWeaponScoreMultiplier(client, weaponType);

    if (active)
    {
        PrintToChat(client, "\x04[武器]\x01 %s 累计 %.0f 秒 | 当前伤害分时间倍率 \x03x%.2f", weaponName, usageTime, multiplier);
    }
    else
    {
        PrintToChat(client, "\x04[武器]\x01 当前枪械不衰减 | %s 已恢复至 %.0f 秒，换回后时间倍率 \x03x%.2f", weaponName, usageTime, multiplier);
    }
}

bool GetHighestDecayWeaponTime(int client, int &weaponType, float &usageTime)
{
    weaponType = DecayWeapon_None;
    usageTime = 0.0;

    for (int i = 0; i < DecayWeapon_Count; i++)
    {
        float current = GetDecayWeaponTime(client, i);
        if (current > usageTime)
        {
            weaponType = i;
            usageTime = current;
        }
    }

    return weaponType != DecayWeapon_None;
}

void GetDecayWeaponName(int weaponType, char[] buffer, int maxlen)
{
    switch (weaponType)
    {
        case DecayWeapon_Rifle: strcopy(buffer, maxlen, "M16");
        case DecayWeapon_RifleDesert: strcopy(buffer, maxlen, "SCAR");
        case DecayWeapon_RifleAK47: strcopy(buffer, maxlen, "AK47");
        case DecayWeapon_HuntingRifle: strcopy(buffer, maxlen, "15连狙");
        case DecayWeapon_SniperMilitary: strcopy(buffer, maxlen, "30连狙");
        case DecayWeapon_SniperScout: strcopy(buffer, maxlen, "Scout");
        case DecayWeapon_SniperAWP: strcopy(buffer, maxlen, "AWP");
        case DecayWeapon_AutoShotgun: strcopy(buffer, maxlen, "一代连喷");
        case DecayWeapon_SpasShotgun: strcopy(buffer, maxlen, "二代连喷");
        default: strcopy(buffer, maxlen, "未知枪械");
    }
}

void ClearPendingInfectedDamage(int client)
{
    if (client < 1 || client > MaxClients)
    {
        return;
    }

    g_bPendingInfectedDamage[client] = false;
    g_iPendingDamageAttacker[client] = 0;
    g_iPendingDamagePreHealth[client] = 0;
    g_iPendingDamageZombieClass[client] = 0;
    g_fPendingDamageMultiplier[client] = 1.0;
}

void ResetClientWeaponDecay(int client)
{
    if (client < 1 || client > MaxClients)
    {
        return;
    }

    float now = GetGameTime();
    g_iActiveDecayWeapon[client] = DecayWeapon_None;
    for (int i = 0; i < DecayWeapon_Count; i++)
    {
        g_fDecayWeaponTime[client][i] = 0.0;
        g_fDecayWeaponUpdatedAt[client][i] = now;
        g_bDecayStartNotified[client][i] = false;
        g_bDecayZeroNotified[client][i] = false;
    }
}

bool IsTankClient(int client)
{
    return IsValidClient(client) && GetClientTeam(client) == TEAM_INFECTED && GetZombieClass(client) == ZC_TANK;
}

bool IsSurvivorIncapacitatedOrHanging(int client)
{
    if (!IsValidSurvivor(client))
    {
        return false;
    }

    if (HasEntProp(client, Prop_Send, "m_isIncapacitated") && GetEntProp(client, Prop_Send, "m_isIncapacitated") != 0)
    {
        return true;
    }

    if (HasEntProp(client, Prop_Send, "m_isHangingFromLedge") && GetEntProp(client, Prop_Send, "m_isHangingFromLedge") != 0)
    {
        return true;
    }

    return false;
}

bool IsSpitDamage(int inflictor, int attacker)
{
    return IsEntityClassname(inflictor, "insect_swarm")
        || IsEntityClassname(attacker, "insect_swarm");
}

bool IsTankHittable(int entity)
{
    if (entity <= MaxClients || !IsValidEntity(entity))
    {
        return false;
    }

    char classname[64];
    GetEntityClassname(entity, classname, sizeof(classname));
    return StrEqual(classname, "prop_physics", false)
        || StrEqual(classname, "prop_car_alarm", false)
        || StrEqual(classname, "prop_physics_multiplayer", false);
}

bool IsTankRock(int entity)
{
    if (entity <= MaxClients || !IsValidEntity(entity))
    {
        return false;
    }

    char classname[64];
    GetEntityClassname(entity, classname, sizeof(classname));
    return StrEqual(classname, "tank_rock", false);
}

bool IsEntityClassname(int entity, const char[] expected)
{
    if (entity <= MaxClients || !IsValidEntity(entity))
    {
        return false;
    }

    char classname[64];
    GetEntityClassname(entity, classname, sizeof(classname));
    return StrEqual(classname, expected, false);
}

int GetEntityHealthSafe(int entity)
{
    if (!IsValidEntity(entity))
    {
        return 0;
    }

    if (HasEntProp(entity, Prop_Data, "m_iHealth"))
    {
        return GetEntProp(entity, Prop_Data, "m_iHealth");
    }

    if (HasEntProp(entity, Prop_Send, "m_iHealth"))
    {
        return GetEntProp(entity, Prop_Send, "m_iHealth");
    }

    return 0;
}

int GetTankTopDamageDealer(int tank)
{
    int best = 0;
    float bestDamage = 0.0;

    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsValidSurvivor(client) || !ShouldTrackClient(client))
        {
            continue;
        }

        if (g_fTankRawDamageByTank[tank][client] > bestDamage)
        {
            bestDamage = g_fTankRawDamageByTank[tank][client];
            best = client;
        }
    }

    return best;
}

void ResetTankDamageForTank(int tank)
{
    if (tank < 1 || tank > MaxClients)
    {
        return;
    }

    for (int client = 1; client <= MaxClients; client++)
    {
        g_fTankDamageByTank[tank][client] = 0.0;
        g_fTankRawDamageByTank[tank][client] = 0.0;
    }
}

int GetPinnedVictim(int attacker, int zc)
{
    if (!IsValidClient(attacker))
    {
        return 0;
    }

    switch (zc)
    {
        case ZC_SMOKER:
        {
            return GetEntPropEntSafe(attacker, "m_tongueVictim");
        }
        case ZC_HUNTER:
        {
            return GetEntPropEntSafe(attacker, "m_pounceVictim");
        }
        case ZC_JOCKEY:
        {
            return GetEntPropEntSafe(attacker, "m_jockeyVictim");
        }
        case ZC_CHARGER:
        {
            int pummel = GetEntPropEntSafe(attacker, "m_pummelVictim");
            if (pummel > 0)
            {
                return pummel;
            }
            return GetEntPropEntSafe(attacker, "m_carryVictim");
        }
    }

    return 0;
}

int FindControlledVictimByAttacker(int attacker)
{
    if (!IsValidClient(attacker))
    {
        return 0;
    }

    for (int victim = 1; victim <= MaxClients; victim++)
    {
        if (!IsValidSurvivor(victim))
        {
            continue;
        }

        if (g_iControlType[victim] != CONTROL_NONE && g_iControlAttacker[victim] == attacker)
        {
            return victim;
        }
    }

    return 0;
}

int FindRecentlyControlledVictimByAttacker(int attacker)
{
    if (!IsValidClient(attacker))
    {
        return 0;
    }

    float now = GetGameTime();
    float window = g_hClearRecentWindow.FloatValue;
    if (window <= 0.0)
    {
        return 0;
    }

    for (int victim = 1; victim <= MaxClients; victim++)
    {
        if (!IsValidSurvivor(victim))
        {
            continue;
        }

        if (g_iLastControlAttacker[victim] != attacker)
        {
            continue;
        }

        float elapsed = now - g_fLastControlEndTime[victim];
        if (elapsed >= 0.0 && elapsed <= window)
        {
            g_iLastControlAttacker[victim] = 0;
            g_fLastControlEndTime[victim] = 0.0;
            return victim;
        }
    }

    return 0;
}

int GetEntPropEntSafe(int entity, const char[] prop)
{
    if (!IsValidEntity(entity))
    {
        return -1;
    }

    if (!HasEntProp(entity, Prop_Send, prop))
    {
        return -1;
    }

    return GetEntPropEnt(entity, Prop_Send, prop);
}

bool ShouldTrackClient(int client)
{
    if (!IsExperienceEnabled())
    {
        return false;
    }

    if (!IsValidClient(client))
    {
        return false;
    }

    if (!g_hIncludeBots.BoolValue && IsFakeClient(client))
    {
        return false;
    }

    return true;
}

bool IsExperienceEnabled()
{
    return g_hEnable != null && g_hEnable.BoolValue;
}

bool IsValidSurvivor(int client)
{
    return IsValidClient(client) && GetClientTeam(client) == TEAM_SURVIVOR;
}

bool IsValidClient(int client)
{
    return client > 0 && client <= MaxClients && IsClientInGame(client);
}

void ResetAllRoundStats()
{
    bool enabled = IsExperienceEnabled();
    g_bEndSaferoomReached = false;

    for (int i = 1; i <= MaxClients; i++)
    {
        ClearClientRoundStats(i);

        if (enabled && IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVOR)
        {
            g_bSurvivorActive[i] = true;
            g_fJoinStartedAt[i] = GetGameTime();
            SyncActiveDecayWeapon(i);
        }
        else
        {
            g_bSurvivorActive[i] = false;
            g_fJoinStartedAt[i] = 0.0;
        }

        g_bHasLeftCheckpoint[i] = false;
        g_bInEndSaferoom[i] = false;
        g_fPlayAccum[i] = 0.0;
    }
}

void ClearClientRoundStats(int client)
{
    g_fSIDamage[client] = 0.0;
    g_fSIRawDamage[client] = 0.0;
    g_iSIKills[client] = 0;
    g_iCommonKills[client] = 0;
    g_iClears[client] = 0;
    g_iRevives[client] = 0;
    g_iDefibs[client] = 0;
    g_fTankDamage[client] = 0.0;
    g_fTankRawDamage[client] = 0.0;
    g_iTankKills[client] = 0;
    g_iTankTopDamage[client] = 0;
    g_iWitchKills[client] = 0;
    g_iRockDestroys[client] = 0;
    g_iRockHits[client] = 0;
    g_iTankPunches[client] = 0;
    g_iTankHittables[client] = 0;
    g_fSpitDamage[client] = 0.0;
    g_iAccuracyShots[client] = 0;
    g_iAccuracyHits[client] = 0;
    g_iSkeets[client] = 0;
    g_iMeleeSkeets[client] = 0;
    g_iTongueCuts[client] = 0;
    g_iHunterDeadstops[client] = 0;
    g_iChargerLevels[client] = 0;
    g_iFastClears[client] = 0;
    g_iSmokerSelfClears[client] = 0;
    g_iLastFastClearPinner[client] = 0;
    g_iLastFastClearVictim[client] = 0;
    g_fLastFastClearAt[client] = 0.0;

    for (int i = 1; i <= MaxClients; i++)
    {
        g_fTankDamageByTank[client][i] = 0.0;
        g_fTankDamageByTank[i][client] = 0.0;
        g_fTankRawDamageByTank[client][i] = 0.0;
        g_fTankRawDamageByTank[i][client] = 0.0;
    }

    g_iControlsTaken[client] = 0;
    g_fControlDuration[client] = 0.0;
    g_iControlType[client] = CONTROL_NONE;
    g_iControlAttacker[client] = 0;
    g_fControlStart[client] = 0.0;
    g_iControlStartIncaps[client] = 0;
    g_iControlStartDeaths[client] = 0;
    g_iControlsSurvived[client] = 0;
    g_iLastControlAttacker[client] = 0;
    g_fLastControlEndTime[client] = 0.0;

    g_iIncaps[client] = 0;
    g_iDeaths[client] = 0;
    g_iSaferoomIncaps[client] = 0;
    g_iSaferoomDeaths[client] = 0;
    g_iEndgameOutsideIncaps[client] = 0;
    g_iEndgameOutsideDeaths[client] = 0;
    g_fFriendlyFire[client] = 0.0;
    ClearPendingInfectedDamage(client);
    ResetClientWeaponDecay(client);
}

void ClearClientAll(int client)
{
    ClearClientRoundStats(client);
    g_bSurvivorActive[client] = false;
    g_bHasLeftCheckpoint[client] = false;
    g_bInEndSaferoom[client] = false;
    g_fJoinStartedAt[client] = 0.0;
    g_fPlayAccum[client] = 0.0;

    g_bLoaded[client] = false;
    g_fRating[client] = 0.0;
    g_iValidRounds[client] = 0;
}
