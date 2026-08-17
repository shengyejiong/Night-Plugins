/*
*	Flashlight Package
*	Copyright (C) 2024 Silvers
*
*	This program is free software: you can redistribute it and/or modify
*	it under the terms of the GNU General Public License as published by
*	the Free Software Foundation, either version 3 of the License, or
*	(at your option) any later version.
*
*	This program is distributed in the hope that it will be useful,
*	but WITHOUT ANY WARRANTY; without even the implied warranty of
*	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*	GNU General Public License for more details.
*
*	You should have received a copy of the GNU General Public License
*	along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/



#define PLUGIN_VERSION 		"2.34"

/*======================================================================================
	Plugin Info:

*	Name	:	[L4D & L4D2] Flashlight Package
*	Author	:	SilverShot
*	Descrp	:	Attaches an extra flashlight to survivors and spectators.
*	Link	:	https://forums.alliedmods.net/showthread.php?t=173257
*	Plugins	:	https://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

2.34 (22-Sep-2024)
	- Fixed color names not working for the flashlight commands. Thanks to "KadabraZz" for reporting.
	- Now the color names input are not case sensitive.

2.33 (17-Jun-2024)
	- Added "Random" and "Rainbow" to the menu. Requested by "JustMadMan".

2.32 (21-Apr-2024)
	- Fixed the "l4d_flashlight_random" cvar not giving bots random colors if saving was enabled. Thanks to "kochiurun119" for reporting.

2.31 (23-Jan-2024)
	- Fixed various issues when using the commands due to the rainbow update. Should toggle, turn off or change correctly for all commands.
	- Fixed issues with saving the light state on or off.
	- Updated and fixed the "chi" translation file. Thanks to "Shimo" for fixing.

2.30 (21-Dec-2023)
	- The rainbow activated state will now save and load.
	- Commands "sm_light" and "sm_lightclient" now accept the option "bow" to turn on the rainbow.
	- Thanks to "Hawkins" and "JustMadMan" for help testing.

2.29 (20-Dec-2023)
	- Added cvar "l4d_flashlight_rainbow" to allow or disallow rainbow changing colors.
	- Added cvar "l4d_flashlight_rainbows" to set the rainbow color speed.
	- Added command "sm_lightbow" to enable/disable the rainbow color.
	- Requested by "JustMadMan". Thanks to "King_OxO" for the code this was based on.

2.28 (01-Oct-2023)
	- Now sets the clients saved color if they spawned before client prefs were loaded. Thanks to "kochiurun119" for reporting.

2.27 (25-May-2023)
	- Fixed the default light color not setting when new players join. Thanks to "iciaria" for reporting.

2.26 (22-Nov-2022)
	- No longer shows the flashlight of the player you're spectating. Thanks to "yabi" for reporting.

2.25 (30-Sep-2022)
	- Plugin now deletes the client cookie if they no longer have access to use the flashlight. Requested by "maclarens".

2.24 (19-Aug-2022)
	- Added cvar "l4d_flashlight_brights" to control the brightness of lights for Special Infected. Requested by "A1ekin".
	- Changed the light position on Special Infected and Spectators in an attempt to fix lighting the area. Thanks to "A1ekin" for reporting.

2.23 (01-May-2022)
	- Added a 1 second delay before creating a light on spawn, to avoid the light flashing once. Thanks to "Ja-`s" for reporting.

2.22 (15-Jan-2022)
	- Fixed not saving light state across map changes. Thanks to "NoroHime" for reporting.

2.21 (01-Jan-2022)
	- Fixed not setting the default color when "l4d_flashlight_default" is "1" and "l4d_flashlight_random" is "0". Thanks to "kalmas77" for reporting.

2.20 (25-Dec-2021)
	- Fixed command "sm_light <color>" not changing the color. Thanks to "Shadowart" for reporting.
	- Fixed cvar "l4d_flashlight_default" not restricting bots when set to "1". Thanks to "Shadowart" for reporting.

2.19 (09-Dec-2021)
	- Changes to fix warnings when compiling on SourceMod 1.11.
	- Changed command "sm_light" to accept "rand" or "random" as a parameter option to give a random light color. Requested by "NoroHime".
	- Code change includes completely random color instead of specified from the list. Uncomment and delete other code if you want this instead.

2.18 (18-Sep-2021)
	- Menu now returns to the page it was on before selecting an option. Requested by "Shadowart".

2.17 (04-Aug-2021)
	- Changed the plugin to allow bots to use the color cvar when _default cvar is enabled _random cvar was disabled.

2.16 (31-Jul-2021)
	- Added cvar "l4d_flashlight_default" to turn on the flashlight by default when spawning.
	- Added cvar "l4d_flashlight_random" to give random colors when spawning.

2.15 (11-Jul-2021)
	- Fixed the Special Infected light being visible to others. Thanks to "A1ekin" for reporting.

2.14 (11-Jul-2021)
	- Added cvar "l4d_flashlight_users" to control if Survivors and Special Infected can use the plugins light.
	- Fixed the Survivors spectator light attaching to their dead body and not themselves.

2.13 (01-Jul-2021)
	- Added a warning message to suggest installing the "Attachments API" and "Use Priority Patch" plugins if missing.

2.12 (28-Apr-2021)
	- Changed command "sm_light" to accept "off" param to turn off the light. Thanks to "Dragokas" for requesting.

2.11 (09-Oct-2020)
	- Changed "OnClientPostAdminCheck" to "OnClientPutInServer" - to fix any issues if Steam service is down.

2.10 (18-Sep-2020)
	- Added cookie preferences to save player flashlight color and state. Thanks to "GoGetSomeSleep" for requesting.
	- Added cvar "l4d_flashlight_save" to control if the server can save and load client preferences.

2.9 (10-May-2020)
	- Added Traditional Chinese and Simplified Chinese translations. Thanks to "fbef0102".
	- Extra checks to prevent "IsAllowedGameMode" throwing errors.
	- Increased "l4d_flashlight_precach" cvar length, max usable length 485 (due to game limitations).
	- Various changes to tidy up code.

2.8 (01-Apr-2020)
	- Fixed "IsAllowedGameMode" from throwing errors when the "_tog" cvar was changed before MapStart.
	- Removed "colors.inc" dependency.
	- Updated these translation file encodings to UTF-8 (to display all characters correctly): Hungarian (hu).

2.7.1 (07-Jan-2020)
	- Fixed "sm_light" not working with color names because 2 args were the wrong way round. Thanks to "K4d4br4" for reporting.

2.7 (19-Dec-2019)
	- Added command "sm_lightmenu" to display a menu and select light color. No translations support.
	- Added cvar "l4d_flashlight_precach" to prevent displaying the model on specific maps. Or "0" for all.
	- Added to "sm_light" and "sm_lightclient" additional colors by name: "cyan" "pink" "lime" "maroon" "teal" "grey".

2.6.1 (21-Jul-2018)
	- Added Hungarian translations - Thanks to KasperH.
	- No other changes.

2.6.1 (18-Jun-2018)
	- Fixed errors, thanks to "ReCreator" for reporting and testing.

2.6 (05-May-2018)
	- Converted plugin source to the latest syntax utilizing methodmaps. Requires SourceMod 1.8 or newer.
	- Changed cvar "l4d_flashlight_modes_tog" now supports L4D1.

2.5.1 (19-Nov-2015)
	- Fix to prevent garbage being passed into SetVariantString, as suggested by "KyleS".

2.5 (25-May-2012)
	- Added more checks to events, preventing errors being logged.

2.4 (22-May-2012)
	- Fixed cvar "l4d_flashlight_spec" enums mistake, thanks to "Dont Fear The Reaper".
	- Fixed errors being logged on player spawn event when clients were not in game.

2.3 (22-May-2012)
	- Changed cvar "l4d_flashlight_spec". The cvar is now a bit flag, add the numbers together.
	- Fixed cvar "l4d_flashlight_spec" blocking alive survivors from using the flashlight.

2.2 (20-May-2012)
	- Changed cvar "l4d_flashlight_spec". You can now specify which teams can use spectator lights.
	- Added German translations - Thanks to "Dont Fear The Reaper".

2.1 (30-Mar-2012)
	- Added Spanish translations - Thanks to "Januto".
	- Added cvar "l4d_flashlight_modes_off" to control which game modes the plugin works in.
	- Added cvar "l4d_flashlight_modes_tog" same as above, but only works for L4D2.
	- Added cvar "l4d_flashlight_hints" which displays the "intro" message to spectators if spectator lights are enabled.
	- Changed the way "l4d_flashlight_flags" validates clients by checking they have one of the flags specified.
	- Fixed the "sm_lightclient" command not affecting all clients.
	- Fixed the "sm_light" command not working for spectators.
	- Fixed ghost players still having flashlights.
	- Small changes and fixes.

2.0 (02-Dec-2011)
	- Plugin separated and taken from the "Flare and Light Package" plugin.
	- Added Russian translations - Thanks to "disawar1".
	- Added personal flashlights for spectators and dead players. The light is invisible to everyone else.
	- Added cvar "l4d_flashlight_spec" to control if spectators should have personal flashlights.
	- Added the following triggers to specify colors with sm_light: red, green, blue, purple, orange, yellow, white.
	- Saves players flashlight on/off state and colors on map change.

1.0 (29-Jan-2011)
	- Initial release.

======================================================================================*/

#pragma semicolon 1

#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>

#define CVAR_FLAGS			FCVAR_NOTIFY
#define CHAT_TAG			"\x04[\x05Flashlight\x04] \x01"

#define ATTACH_GRENADE		"grenade"
#define MODEL_LIGHT			"models/props_lighting/flashlight_dropped_01.mdl"

#define COMPLETELY_RANDOM	0 // Set this to 1 for completely random colors, or set to 1 to randomly pick from the preset list


// Cvar Handles/Variables
ConVar g_hCvarAllow, g_hCvarAlpha, g_hCvarAlphas, g_hCvarRainbow, g_hCvarRainbows, g_hCvarRandom, g_hCvarColor, g_hCvarDefault, g_hCvarFlags, g_hCvarHints, g_hCvarIntro, g_hCvarLock, g_hCvarModes, g_hCvarModesOff, g_hCvarModesTog, g_hCvarPrecache, g_hCvarSave, g_hCvarSpec, g_hCvarUsers;
bool g_bCvarAllow, g_bMapStarted, g_bCvarLock;
char g_sCvarCols[12];
float g_fCvarIntro, g_fCvarRainbows;
int g_iCvarAlpha, g_iCvarAlphas, g_iCvarColor, g_iCvarDefault, g_iCvarFlags, g_iCvarHints, g_iCvarRainbow, g_iCvarRandom, g_iCvarSave, g_iCvarSpec, g_iCvarUsers;

// Plugin Variables
ConVar g_hCvarMPGameMode;
bool g_bRoundOver, g_bValidMap;
bool g_bCookieAuth[MAXPLAYERS+1], g_bRainbow[MAXPLAYERS+1];
char g_sPlayerModel[MAXPLAYERS+1][42];
int g_iClientColor[MAXPLAYERS+1], g_iClientLight[MAXPLAYERS+1], g_iLightIndex[MAXPLAYERS+1], g_iLights[MAXPLAYERS+1], g_iModelIndex[MAXPLAYERS+1];
Handle g_hCookieColor;
Handle g_hCookieState;
Handle g_hCookieBows;
StringMap g_hColors;
StringMapSnapshot g_hSnapColors;
Menu g_hMenu;



// ====================================================================================================
//					PLUGIN INFO / START / END
// ====================================================================================================
public Plugin myinfo =
{
	name = "[L4D & L4D2] Flashlight Package",
	author = "SilverShot",
	description = "Attaches an extra flashlight to survivors and spectators.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=173257"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if( test != Engine_Left4Dead && test != Engine_Left4Dead2 )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnAllPluginsLoaded()
{
	// Attachments API
	if( FindConVar("attachments_api_version") == null && (FindConVar("l4d2_swap_characters_version") != null || FindConVar("l4d_csm_version") != null) )
	{
		LogMessage("\n==========\nWarning: You should install \"[ANY] Attachments API\" to fix model attachments when changing character models: https://forums.alliedmods.net/showthread.php?t=325651\n==========\n");
	}

	// Use Priority Patch
	if( FindConVar("l4d_use_priority_version") == null )
	{
		LogMessage("\n==========\nWarning: You should install \"[L4D & L4D2] Use Priority Patch\" to fix attached models blocking +USE action: https://forums.alliedmods.net/showthread.php?t=327511\n==========\n");
	}
}

public void OnPluginStart()
{
	// Translations
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, PLATFORM_MAX_PATH, "translations/flashlight.phrases.txt");
	if( FileExists(sPath) )
		LoadTranslations("flashlight.phrases");
	else
		SetFailState("Missing required 'translations/flashlight.phrases.txt', please download and install.");

	LoadTranslations("common.phrases");
	LoadTranslations("core.phrases");

	g_hCvarAllow =			CreateConVar(	"l4d_flashlight_allow",			"1",			"0=Plugin off, 1=Plugin on.", CVAR_FLAGS );
	g_hCvarAlpha =			CreateConVar(	"l4d_flashlight_bright",		"255.0",		"Brightness of the light for Survivors <10-255> (changes Distance value).", CVAR_FLAGS, true, 10.0, true, 255.0 );
	g_hCvarAlphas =			CreateConVar(	"l4d_flashlight_brights",		"255.0",		"Brightness of the light for Special Infected <10-255> (changes Distance value).", CVAR_FLAGS, true, 10.0, true, 255.0 );
	g_hCvarColor =			CreateConVar(	"l4d_flashlight_colour",		"200 20 15",	"The default light color. Three values between 0-255 separated by spaces. RGB Color255 - Red Green Blue.", CVAR_FLAGS );
	g_hCvarDefault =		CreateConVar(	"l4d_flashlight_default",		"1",			"Turn on the light when players join (unless it's saved it off). 0=Off. 1=Survivors. 2=Special Infected. 4=Survivor Bots. Add numbers together.", CVAR_FLAGS );
	g_hCvarFlags =			CreateConVar(	"l4d_flashlight_flags",			"",				"Players with these flags may use the sm_light command. (Empty = all).", CVAR_FLAGS );
	g_hCvarHints =			CreateConVar(	"l4d_flashlight_hints",			"1",			"0=Off, 1=Show intro message to players entering spectator.", CVAR_FLAGS );
	g_hCvarIntro =			CreateConVar(	"l4d_flashlight_intro",			"35.0",			"0=Off, Show intro message in chat this many seconds after joining.", CVAR_FLAGS, true, 0.0, true, 120.0);
	g_hCvarLock =			CreateConVar(	"l4d_flashlight_lock",			"0",			"0=Let players set their flashlight color, 1=Force to cvar specified.", CVAR_FLAGS );
	g_hCvarModes =			CreateConVar(	"l4d_flashlight_modes",			"",				"Turn on the plugin in these game modes, separate by commas (no spaces). (Empty = all).", CVAR_FLAGS );
	g_hCvarModesOff =		CreateConVar(	"l4d_flashlight_modes_off",		"",				"Turn off the plugin in these game modes, separate by commas (no spaces). (Empty = none).", CVAR_FLAGS );
	g_hCvarModesTog =		CreateConVar(	"l4d_flashlight_modes_tog",		"0",			"Turn on the plugin in these game modes. 0=All, 1=Coop, 2=Survival, 4=Versus, 8=Scavenge. Add numbers together.", CVAR_FLAGS );
	g_hCvarPrecache =		CreateConVar(	"l4d_flashlight_precach",		"c1m3_mall",	"Empty = Allow all. 0=Block on all maps. Prevent displaying the model on these maps, separate by commas (no spaces).", CVAR_FLAGS );
	g_hCvarRainbow =		CreateConVar(	"l4d_flashlight_rainbow",		"3",			"Allow players to use the sm_lightbow command for rainbow changing colors. 0=Off. 1=Survivors. 2=Special Infected. 3=Both.", CVAR_FLAGS );
	g_hCvarRainbows =		CreateConVar(	"l4d_flashlight_rainbows",		"1.0",			"Speed of rainbow colors changing. Smaller value = slower. Larger value = faster.", CVAR_FLAGS );
	g_hCvarRandom =			CreateConVar(	"l4d_flashlight_random",		"2",			"Give random colors on spawn? 0=Use color cvar. 1=Give Survivor bots random colors if enabled by the _default cvar. 2=Give real players random colors (unless save enabled). 3=Both.", CVAR_FLAGS );
	g_hCvarSave =			CreateConVar(	"l4d_flashlight_save",			"1",			"0=Off, 1=Save client preferences for flashlight color and state.", CVAR_FLAGS );
	g_hCvarSpec =			CreateConVar(	"l4d_flashlight_spec",			"7",			"0=Off, 1=Spectators, 2=Survivors, 4=Infected, 7=All. Give personal flashlights when dead which only they can see.", CVAR_FLAGS );
	g_hCvarUsers =			CreateConVar(	"l4d_flashlight_users",			"1",			"1=Survivors, 2=Infected, 3=All. Allow these players when alive to use the flashlight.", CVAR_FLAGS );
	CreateConVar(							"l4d_flashlight_version",		PLUGIN_VERSION,	"Flashlight plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	AutoExecConfig(true,					"l4d_flashlight");

	g_hCvarMPGameMode = FindConVar("mp_gamemode");
	g_hCvarMPGameMode.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModes.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesOff.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesTog.AddChangeHook(ConVarChanged_Allow);
	g_hCvarAllow.AddChangeHook(ConVarChanged_Allow);
	g_hCvarAlpha.AddChangeHook(ConVarChanged_LightAlpha);
	g_hCvarAlphas.AddChangeHook(ConVarChanged_LightAlpha);
	g_hCvarRainbow.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarRainbows.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarRandom.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarColor.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarDefault.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarFlags.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarHints.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarIntro.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarLock.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarPrecache.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarSave.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarSpec.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarUsers.AddChangeHook(ConVarChanged_Cvars);

	// Commands
	RegAdminCmd(	"sm_lightclient",	CmdLightClient,	ADMFLAG_ROOT,	"Create and toggle flashlight attachment on the specified target. Usage: sm_lightclient <#user id|name> [R G B|off|random|bow|red|green|blue|purple|cyan|orange|white|pink|lime|maroon|teal|yellow|grey]");
	RegConsoleCmd(	"sm_lightbow",		CmdLightRainbow,				"Toggle the attached flashlight with rainbow changing colors.");
	RegConsoleCmd(	"sm_light",			CmdLightCommand,				"Toggle the attached flashlight. Usage: sm_light [R G B|off|random|bow|red|green|blue|purple|cyan|orange|white|pink|lime|maroon|teal|yellow|grey]");
	RegConsoleCmd(	"sm_lightmenu",		CmdLightMenu,					"Opens the flashlight color menu.");

	CreateColors();

	g_hCookieColor = RegClientCookie("l4d_flashlight", "Flashlight Color", CookieAccess_Protected);
	g_hCookieState = RegClientCookie("l4d_flashlights", "Flashlight State", CookieAccess_Protected);
	g_hCookieBows = RegClientCookie("l4d_flashlightbow", "Flashlight Rainbow", CookieAccess_Protected);
}

public void OnPluginEnd()
{
	for( int i = 1; i <= MaxClients; i++ )
		DeleteLight(i);
}

public void OnMapStart()
{
	g_bMapStarted = true;
	g_bValidMap = true;

	char sCvar[512];
	g_hCvarPrecache.GetString(sCvar, sizeof(sCvar));

	if( sCvar[0] != '\0' )
	{
		if( strcmp(sCvar, "0") == 0 )
		{
			g_bValidMap = false;
		} else {
			char sMap[64];
			GetCurrentMap(sMap, sizeof(sMap));

			Format(sMap, sizeof(sMap), ",%s,", sMap);
			Format(sCvar, sizeof(sCvar), ",%s,", sCvar);

			if( StrContains(sCvar, sMap, false) != -1 )
				g_bValidMap = false;
		}
	}

	if( g_bValidMap )
		PrecacheModel(MODEL_LIGHT, true);
}

public void OnMapEnd()
{
	g_bMapStarted = false;
}



// ====================================================================================================
//					COOKIES
// ====================================================================================================
public void OnClientDisconnect(int client)
{
	g_iClientColor[client] = 0;
	g_iClientLight[client] = 0;

	g_bCookieAuth[client] = false;
	g_bRainbow[client] = false;
}

public void OnClientPostAdminCheck(int client)
{
	CookieAuthTest(client);
}

public void OnClientCookiesCached(int client)
{
	if( !g_bCvarLock && g_iCvarSave && !IsFakeClient(client) )
	{
		char sCookie[10];

		// Color
		GetClientCookie(client, g_hCookieColor, sCookie, sizeof(sCookie));
		if( sCookie[0] )
		{
			g_iClientColor[client] = StringToInt(sCookie);
		} else {
			g_iClientColor[client] = g_iCvarColor;
		}

		// State on/off
		GetClientCookie(client, g_hCookieState, sCookie, sizeof(sCookie));
		if( sCookie[0] )
		{
			g_iClientLight[client] = StringToInt(sCookie);
		}

		// State rainbow
		GetClientCookie(client, g_hCookieBows, sCookie, sizeof(sCookie));
		if( sCookie[0] )
		{
			g_bRainbow[client] = !!StringToInt(sCookie);
		}
	} else {
		g_iClientColor[client] = g_iCvarColor;
	}

	// Set color if they spawned before cookies were cached
	int entity = g_iLightIndex[client];
	if( IsValidEntRef(entity) )
	{
		if( g_iCvarRainbow && g_bRainbow[client] && (g_iCvarRainbow == 3 || g_iCvarRainbow == GetClientTeam(client) - 1) )
		{
			SDKUnhook(client, SDKHook_PreThinkPost, OnRainbowPlayer);
			SDKHook(client, SDKHook_PreThinkPost, OnRainbowPlayer);
		}
		else if( g_iClientColor[client] )
		{
			SetEntProp(entity, Prop_Send, "m_clrRender", g_iClientColor[client]);
		}
	}

	CookieAuthTest(client);
}

void CookieAuthTest(int client)
{
	// Check if clients allowed to use hats otherwise delete cookie/hat
	if( g_iCvarFlags && g_bCookieAuth[client] && !IsFakeClient(client) )
	{
		int flags = GetUserFlagBits(client);

		if( !(flags & ADMFLAG_ROOT) && !(flags & g_iCvarFlags) )
		{
			DeleteLight(client);
			g_iClientLight[client] = 0;
			g_iClientColor[client] = 0;
			SetClientCookie(client, g_hCookieColor, "0");
			SetClientCookie(client, g_hCookieState, "0");
		}
	} else {
		g_bCookieAuth[client] = true;
	}
}



// ====================================================================================================
//					MENU + COLORS
// ====================================================================================================
void CreateColors()
{
	// Menu
	g_hMenu = new Menu(Menu_Light);
	g_hMenu.SetTitle("Light Color:");
	g_hMenu.ExitButton = true;

	// Colors
	g_hColors = new StringMap();

	AddColorItem("random",		"0");
	AddColorItem("rainbow",		"1");
	AddColorItem("red",			"255 0 0");
	AddColorItem("green",		"0 255 0");
	AddColorItem("blue",		"0 0 255");
	AddColorItem("purple",		"155 0 255");
	AddColorItem("cyan",		"0 255 255");
	AddColorItem("orange",		"255 155 0");
	AddColorItem("white",		"-1 -1 -1");
	AddColorItem("pink",		"255 0 150");
	AddColorItem("lime",		"128 255 0");
	AddColorItem("maroon",		"128 0 0");
	AddColorItem("teal",		"0 128 128");
	AddColorItem("yellow",		"255 255 0");
	AddColorItem("grey",		"50 50 50");

	g_hSnapColors = g_hColors.Snapshot();
}

void AddColorItem(char[] sName, const char[] sColor)
{
	g_hColors.SetString(sName, sColor);

	sName[0] = CharToUpper(sName[0]);
	g_hMenu.AddItem(sColor, sName);
	sName[0] = CharToLower(sName[0]); // For whatever reason, if this isn't set to lower, next time the function is called all sName strings will have a capital letter instead.
}

Action CmdLightMenu(int client, int args)
{
	if( !client )
	{
		ReplyToCommand(client, "Command can only be used %s", IsDedicatedServer() ? "in game on a dedicated server." : "in chat on a Listen server.");
		return Plugin_Handled;
	}

	g_hMenu.Display(client, 0);
	return Plugin_Handled;
}

int Menu_Light(Menu menu, MenuAction action, int client, int index)
{
	switch( action )
	{
		case MenuAction_Select:
		{
			char sColor[12];
			menu.GetItem(index, sColor, sizeof(sColor));
			if( strcmp(sColor, "0") == 0 )
			{
				CommandLight(client, 0, "", false, true);
			}
			else if( strcmp(sColor, "1") == 0 )
			{
				if( g_iCvarRainbow == 3 || g_iCvarRainbow == GetClientTeam(client) - 1 )
				{
					CommandLight(client, 0, "", true);
				}
				else
				{
					CPrintToChat(client, "[SM] %T.", "No Access", client);
				}
			}
			else
			{
				CommandLight(client, 3, sColor);
			}
			g_hMenu.DisplayAt(client, 7 * RoundToFloor(index / 7.0), 0);
		}
	}

	return 0;
}



// ====================================================================================================
//					INTRO
// ====================================================================================================
public void OnClientPutInServer(int client)
{
	// Display intro / welcome message
	if( g_fCvarIntro && IsValidNow() && !IsFakeClient(client) )
		CreateTimer(g_fCvarIntro, TimerIntro, GetClientUserId(client));
}

Action TimerIntro(Handle timer, int client)
{
	client = GetClientOfUserId(client);
	if( client && IsClientInGame(client) )
	{
		int team = GetClientTeam(client);
		if( team == 2 ) team = 1;
		else if( team == 3 ) team = 2;
		else team = 0;

		if( g_iCvarUsers & team )
		{
			CPrintToChat(client, "%s%T", CHAT_TAG, "Flashlight Intro", client);
		}
	}

	return Plugin_Continue;
}



// ====================================================================================================
//					CVARS
// ====================================================================================================
public void OnConfigsExecuted()
{
	IsAllowed();
}

void ConVarChanged_Cvars(Handle convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void ConVarChanged_Allow(Handle convar, const char[] oldValue, const char[] newValue)
{
	IsAllowed();
}

void ConVarChanged_LightAlpha(Handle convar, const char[] oldValue, const char[] newValue)
{
	int i, entity;
	g_iCvarAlpha = g_hCvarAlpha.IntValue;
	g_iCvarAlphas = g_hCvarAlphas.IntValue;

	// Loop through players and change their brightness
	for( i = 1; i <= MaxClients; i++ )
	{
		entity = g_iLightIndex[i];
		if( IsValidEntRef(entity) )
		{
			SetVariantInt(GetClientTeam(i) == 3 ? g_iCvarAlphas : g_iCvarAlpha);
			AcceptEntityInput(entity, "distance");
		}
	}
}

void GetCvars()
{
	char sTemp[16];
	int rainbow = g_iCvarRainbow;

	g_iCvarAlpha = g_hCvarAlpha.IntValue;
	g_iCvarAlphas = g_hCvarAlphas.IntValue;
	g_iCvarRainbow = g_hCvarRainbow.IntValue;
	g_fCvarRainbows = g_hCvarRainbows.FloatValue;
	g_iCvarRandom = g_hCvarRandom.IntValue;
	g_hCvarColor.GetString(g_sCvarCols, sizeof(g_sCvarCols));
	g_iCvarDefault = g_hCvarDefault.IntValue;
	g_hCvarFlags.GetString(sTemp, sizeof(sTemp));
	g_iCvarFlags = ReadFlagString(sTemp);
	g_iCvarHints = g_hCvarHints.IntValue;
	g_fCvarIntro = g_hCvarIntro.FloatValue;
	g_bCvarLock = g_hCvarLock.BoolValue;
	g_iCvarSave = g_hCvarSave.IntValue;
	g_iCvarSpec = g_hCvarSpec.IntValue;
	g_iCvarUsers = g_hCvarUsers.IntValue;

	char sColors[3][4];
	g_iCvarColor = ExplodeString(g_sCvarCols, " ", sColors, sizeof(sColors), sizeof(sColors[]));
	if( g_iCvarColor == 3 )
	{
		g_iCvarColor = StringToInt(sColors[0]);
		g_iCvarColor += 256 * StringToInt(sColors[1]);
		g_iCvarColor += 65536 * StringToInt(sColors[2]);
	}

	if( !g_iCvarRainbow && rainbow )
	{
		delete g_hMenu;
		delete g_hColors;
		delete g_hSnapColors;

		CreateColors();
	}
}

void IsAllowed()
{
	bool bCvarAllow = g_hCvarAllow.BoolValue;
	bool bAllowMode = IsAllowedGameMode();
	GetCvars();

	if( g_bCvarAllow == false && bCvarAllow == true && bAllowMode == true )
	{
		g_bCvarAllow = true;
		HookEvents();

		if( IsValidNow() )
		{
			for( int i = 1; i <= MaxClients; i++ )
			{
				if( IsClientInGame(i) )
				{
					OnClientCookiesCached(i);

					if( IsFakeClient(i) )
					{
						CreateTimer(0.1, TimerDelayCreateLight, GetClientUserId(i));
					}

					else if( IsValidClient(i) )
					{
						CreateLight(i);
					}
				}
			}
		}
	}

	else if( g_bCvarAllow == true && (bCvarAllow == false || bAllowMode == false) )
	{
		g_bCvarAllow = false;
		UnhookEvents();

		for( int i = 1; i <= MaxClients; i++ )
		{
			g_iClientLight[i] = 0;
			DeleteLight(i);
		}
	}
}

int g_iCurrentMode;
bool IsAllowedGameMode()
{
	if( g_hCvarMPGameMode == null )
		return false;

	int iCvarModesTog = g_hCvarModesTog.IntValue;
	if( iCvarModesTog != 0 )
	{
		if( g_bMapStarted == false )
			return false;

		g_iCurrentMode = 0;

		int entity = CreateEntityByName("info_gamemode");
		if( IsValidEntity(entity) )
		{
			DispatchSpawn(entity);
			HookSingleEntityOutput(entity, "OnCoop", OnGamemode, true);
			HookSingleEntityOutput(entity, "OnSurvival", OnGamemode, true);
			HookSingleEntityOutput(entity, "OnVersus", OnGamemode, true);
			HookSingleEntityOutput(entity, "OnScavenge", OnGamemode, true);
			ActivateEntity(entity);
			AcceptEntityInput(entity, "PostSpawnActivate");
			if( IsValidEntity(entity) ) // Because sometimes "PostSpawnActivate" seems to kill the ent.
				RemoveEdict(entity); // Because multiple plugins creating at once, avoid too many duplicate ents in the same frame
		}

		if( g_iCurrentMode == 0 )
			return false;

		if( !(iCvarModesTog & g_iCurrentMode) )
			return false;
	}

	char sGameModes[64], sGameMode[64];
	g_hCvarMPGameMode.GetString(sGameMode, sizeof(sGameMode));
	Format(sGameMode, sizeof(sGameMode), ",%s,", sGameMode);

	g_hCvarModes.GetString(sGameModes, sizeof(sGameModes));
	if( sGameModes[0] )
	{
		Format(sGameModes, sizeof(sGameModes), ",%s,", sGameModes);
		if( StrContains(sGameModes, sGameMode, false) == -1 )
			return false;
	}

	g_hCvarModesOff.GetString(sGameModes, sizeof(sGameModes));
	if( sGameModes[0] )
	{
		Format(sGameModes, sizeof(sGameModes), ",%s,", sGameModes);
		if( StrContains(sGameModes, sGameMode, false) != -1 )
			return false;
	}

	return true;
}

void OnGamemode(const char[] output, int caller, int activator, float delay)
{
	if( strcmp(output, "OnCoop") == 0 )
		g_iCurrentMode = 1;
	else if( strcmp(output, "OnSurvival") == 0 )
		g_iCurrentMode = 2;
	else if( strcmp(output, "OnVersus") == 0 )
		g_iCurrentMode = 4;
	else if( strcmp(output, "OnScavenge") == 0 )
		g_iCurrentMode = 8;
}



// ====================================================================================================
//					EVENTS
// ====================================================================================================
void HookEvents()
{
	HookEvent("round_start",		Event_RoundStart,	EventHookMode_PostNoCopy);
	HookEvent("round_end",			Event_RoundEnd,		EventHookMode_PostNoCopy);
	HookEvent("player_death",		Event_PlayerDeath);
	HookEvent("item_pickup",		Event_ItemPickup);
	HookEvent("player_spawn",		Event_PlayerSpawn);
	HookEvent("player_team",		Event_PlayerTeam);
}

void UnhookEvents()
{
	UnhookEvent("round_start",		Event_RoundStart,	EventHookMode_PostNoCopy);
	UnhookEvent("round_end",		Event_RoundEnd,		EventHookMode_PostNoCopy);
	UnhookEvent("player_death",		Event_PlayerDeath);
	UnhookEvent("item_pickup",		Event_ItemPickup);
	UnhookEvent("player_spawn",		Event_PlayerSpawn);
	UnhookEvent("player_team",		Event_PlayerTeam);
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_bRoundOver = false;
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	g_bRoundOver = true;

	for( int i = 1; i <= MaxClients; i++ )
		DeleteLight(i);
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if( !client )
		return;

	DeleteLight(client); // Delete attached flashlight
	CreateSpecLight(client);
}

void Event_ItemPickup(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if( client && IsClientInGame(client) && GetClientTeam(client) == 3 )
		DeleteLight(client);
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int clientID = event.GetInt("userid");
	int client = GetClientOfUserId(clientID);
	DeleteLight(client);

	if( client && IsClientInGame(client) )
	{
		int team = GetClientTeam(client);
		if( team == 2 ) team = 1;
		else if( team == 3 ) team = 2;
		else team = 0;

		if( g_iCvarUsers & team )
		{
			CreateTimer(1.0, TimerDelayCreateLight, clientID); // Needed because round_start event occurs AFTER player_spawn, so IsValidNow() fails...
		}
	}
}

void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	int clientID = event.GetInt("userid");
	int client = GetClientOfUserId(clientID);

	if( !client )
		return;

	DeleteLight(client);
	CreateTimer(1.0, TimerDelayCreateLight, clientID);
	CreateSpecLight(client);
}

Action TimerDelayCreateLight(Handle timer, int client)
{
	client = GetClientOfUserId(client);

	if( client && IsValidNow() && IsValidClient(client) ) // Re-create attached flashlight
	{
		bool fake = IsFakeClient(client);

		if( g_iCvarDefault && (!g_iCvarSave || !g_bCookieAuth[client]) || fake)
		{
			int team = GetClientTeam(client);

			if( team == 2 && ((g_iCvarDefault & 1 && !fake) || (g_iCvarDefault & 4 && fake)) )
			{
				// Set light on
				g_iClientLight[client] = 1;

				// Give random light to clients if not saved or bots if allowed
				if( (g_iCvarRandom & 1 && fake) || (g_iCvarRandom & 2 && !fake && (!g_iCvarSave || g_iClientColor[client] == 0)) )
				{
					#if COMPLETELY_RANDOM
						int color;

						color = GetRandomInt(50, 255);
						color += 256 * GetRandomInt(50, 255);
						color += 65536 * GetRandomInt(50, 255);
						g_iClientColor[client] = color;

						delete g_hSnapColors;
					#else
						int size = g_hSnapColors.Length;
						int pos = g_iCvarRainbow ? 2 : 1;

						char sTemp[32];

						g_hSnapColors.GetKey(GetRandomInt(pos, size - 1), sTemp, sizeof(sTemp));
						if( g_hColors.GetString(sTemp, sTemp, sizeof(sTemp)) )
						{
							char sColors[3][4];
							int color;

							ExplodeString(sTemp, " ", sColors, sizeof(sColors), sizeof(sColors[]));
							color = StringToInt(sColors[0]);
							color += 256 * StringToInt(sColors[1]);
							color += 65536 * StringToInt(sColors[2]);
							g_iClientColor[client] = color;
						}
					#endif
				}
				else if( g_iClientColor[client] == 0 )
				{
					g_iClientColor[client] = g_iCvarColor;
				}
			}

			if( g_iCvarDefault & 2 && team == 3 && !fake )
			{
				g_iClientLight[client] = 1;
			}
		}

		CreateLight(client);
	}

	return Plugin_Continue;
}

void CreateSpecLight(int client)
{
	if( g_iCvarSpec && client && !IsFakeClient(client) && !IsPlayerAlive(client) )
	{
		int team = GetClientTeam(client);
		if( team == 3 ) team = 4;
		else if( team == 4 ) team = 8;

		if( g_iCvarSpec & team )
		{
			int entity = MakeLightDynamic(view_as<float>({ 0.0, 0.0, -10.0 }), view_as<float>({ 0.0, 0.0, 0.0 }), client);
			DispatchKeyValue(entity, "_light", "255 255 255 255");
			DispatchKeyValue(entity, "brightness", "2");
			g_iLights[client] = EntIndexToEntRef(entity);
			SDKHook(entity, SDKHook_SetTransmit, Hook_SetTransmitSpec);

			if( g_iCvarHints )
			{
				CPrintToChat(client, "%s%T", CHAT_TAG, "Flashlight Intro", client);
			}
		}
	}
}



// ====================================================================================================
//					COMMAND - sm_lightclient
// ====================================================================================================
// Attach flashlight onto specified client / change colors
Action CmdLightClient(int client, int args)
{
	if( !client )
	{
		ReplyToCommand(client, "Command can only be used %s", IsDedicatedServer() ? "in game on a dedicated server." : "in chat on a Listen server.");
		return Plugin_Handled;
	}

	if( args == 0 )
	{
		ReplyToCommand(client, "[Flashlight] Usage: sm_lightclient <#user id|name> [R G B|off|random|bow|red|green|blue|purple|orange|yellow|white]");
		return Plugin_Handled;
	}

	char sArg[32], target_name[MAX_TARGET_LENGTH];
	GetCmdArg(1, sArg, sizeof(sArg));

	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;

	if( (target_count = ProcessTargetString(
		sArg,
		client,
		target_list,
		MAXPLAYERS,
		COMMAND_FILTER_ALIVE, /* Only allow alive players */
		target_name,
		sizeof(target_name),
		tn_is_ml)) <= 0 )
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	if( args > 1 )
	{
		GetCmdArgString(sArg, sizeof(sArg));
		// Send the args without target name
		int pos = StrContains(sArg, " ");
		if( pos != -1 )
		{
			Format(sArg, sizeof(sArg), sArg[pos+1]);
			TrimString(sArg);
			args--;
		}
	}
	else
	{
		args = 0;
	}

	for( int i = 0; i < target_count; i++ )
	{
		if( IsValidClient(target_list[i]) )
			CommandForceLight(client, target_list[i], args, sArg);
	}
	return Plugin_Handled;
}

void CommandForceLight(int client, int target, int args, char[] sArg)
{
	// Wrong number of arguments
	if( args != 0 && args != 1 && args != 3 )
	{
		// Display usage help if translation exists and hints turned on
		CPrintToChat(client, "%s%T", CHAT_TAG, "Flashlight Usage", client);
		return;
	}

	// Delete flashlight and re-make if the players model has changed, CSM plugin fix...
	static char sTempStr[42];
	GetClientModel(target, sTempStr, sizeof(sTempStr));
	if( strcmp(g_sPlayerModel[target], sTempStr) != 0 )
	{
		DeleteLight(target);
		strcopy(g_sPlayerModel[target], sizeof(g_sPlayerModel[]), sTempStr);
	}

	// Off option
	if( args == 1 )
	{
		if( strcmp(sArg, "off", false) == 0 )
		{
			g_bRainbow[target] = false;
			g_iClientLight[target] = 0;

			SDKUnhook(target, SDKHook_PreThinkPost, OnRainbowPlayer);

			if( g_iCvarSave && !IsFakeClient(target) )
			{
				SetClientCookie(target, g_hCookieState, "0");
			}

			DeleteLight(target);
			return;
		}
	}

	// Check if they have a light, or try to create
	int entity = g_iLightIndex[target];
	if( !IsValidEntRef(entity) )
	{
		CreateLight(target);

		entity = g_iLightIndex[target];
		if( !IsValidEntRef(entity) )
			return;
	}

	bool setCol;
	bool rainbow;

	// Toggle or set light color and turn on.
	if( args == 1 && strncmp(sArg, "rand", 4, false) == 0 )
	{
		char sTempL[12];

		#if COMPLETELY_RANDOM
			// Completely random color
			Format(sTempL, sizeof(sTempL), "%d %d %d", GetRandomInt(20, 255), GetRandomInt(20, 255), GetRandomInt(20, 255));
			SetVariantString(sTempL);
			AcceptEntityInput(entity, "color");
			setCol = true;
		#else
			// Random color from list
			int size = g_hSnapColors.Length;
			int pos = g_iCvarRainbow ? 2 : 1;

			g_hSnapColors.GetKey(GetRandomInt(pos, size - 1), sTempL, sizeof(sTempL));
			if( g_hColors.GetString(sTempL, sTempL, sizeof(sTempL)) )
			{
				SetVariantString(sTempL);
				AcceptEntityInput(entity, "color");
				setCol = true;
			}
		#endif
	}
	else if( args == 1 && (strncmp(sArg, "bow", 4, false) == 0 || strncmp(sArg, "rainbow", 8, false) == 0) )
	{
		rainbow = true;
	}
	else if( args == 1 )
	{
		char sTempL[12];

		LowerCaseString(sArg);

		if( g_hColors.GetString(sArg, sTempL, sizeof(sTempL)) == false )
			sTempL = "-1 -1 -1";

		SetVariantString(sTempL);
		AcceptEntityInput(entity, "color");
		setCol = true;
	}
	else if( args == 3 )
	{
		// Specified colors
		char sTempL[12];
		char sSplit[3][4];
		ExplodeString(sArg, " ", sSplit, sizeof(sSplit), sizeof(sSplit[]));
		Format(sTempL, sizeof(sTempL), "%d %d %d", StringToInt(sSplit[0]), StringToInt(sSplit[1]), StringToInt(sSplit[2]));

		SetVariantString(sTempL);
		AcceptEntityInput(entity, "color");
		setCol = true;
	}

	// Rainbow state
	bool oldBow = g_bRainbow[target];
	g_bRainbow[target] = rainbow;

	// Turn off rainbow if toggling, else turn on
	if( rainbow )
	{
		// Turn rainbow off
		if( oldBow )
		{
			rainbow = false;
			g_bRainbow[target] = false;
			g_iClientLight[target] = 0;
			AcceptEntityInput(entity, "TurnOff");

			if( g_iCvarSave && !IsFakeClient(target) )
			{
				SetClientCookie(target, g_hCookieBows, "0");
			}
		}
		// Turn rainbow on
		else
		{
			g_bRainbow[target] = true;
			g_iClientLight[target] = 1;
			AcceptEntityInput(entity, "TurnOn");

			if( g_iCvarSave && !IsFakeClient(target) )
			{
				SetClientCookie(target, g_hCookieBows, "1");
			}
		}
	}
	else
	{
		// Save rainbow off
		if( g_iCvarSave && !IsFakeClient(target) )
		{
			g_bRainbow[target] = false;
			SetClientCookie(target, g_hCookieBows, "0");
		}

		// Set new color
		int color;

		if( setCol )
		{
			color = GetEntProp(entity, Prop_Send, "m_clrRender");

			if( color == g_iClientColor[target] )
			{
				g_iClientLight[target] = !g_iClientLight[target];
				AcceptEntityInput(entity, "Toggle");
			}
			else
			{
				g_iClientColor[target] = color;
				g_iClientLight[target] = 1;
				AcceptEntityInput(entity, "TurnOn");
			}

			g_bRainbow[target] = false;

			if( g_iCvarSave && !IsFakeClient(target) )
			{
				char sNum[10];
				IntToString(color, sNum, sizeof(sNum));
				SetClientCookie(target, g_hCookieColor, sNum);
			}
		}
		else
		{
			g_bRainbow[target] = false;

			// Turn off bow
			if( oldBow )
			{
				g_iClientLight[target] = 0;
				AcceptEntityInput(entity, "TurnOff");
			}
			else
			{
				// Restore previous color and toggle
				g_iClientLight[target] = !g_iClientLight[target];
				SetEntProp(entity, Prop_Send, "m_clrRender", g_iClientColor[target]);
				AcceptEntityInput(entity, "Toggle");

				if( g_iCvarSave && !IsFakeClient(target) )
				{
					char sNum[10];
					IntToString(g_iClientColor[target], sNum, sizeof(sNum));
					SetClientCookie(target, g_hCookieColor, sNum);
				}
			}
		}
	}

	// Save light state/color
	if( g_iCvarSave && !IsFakeClient(target) )
	{
		char sNum[4];
		IntToString(g_iClientLight[target], sNum, sizeof(sNum));
		SetClientCookie(target, g_hCookieState, sNum);
	}

	SDKUnhook(target, SDKHook_PreThinkPost, OnRainbowPlayer);

	if( rainbow )
	{
		SDKHook(target, SDKHook_PreThinkPost, OnRainbowPlayer);
	}
}



// ====================================================================================================
//					COMMAND - sm_lightbow
// ====================================================================================================
Action CmdLightRainbow(int client, int args)
{
	if( !client )
	{
		ReplyToCommand(client, "Command can only be used %s", IsDedicatedServer() ? "in game on a dedicated server." : "in chat on a Listen server.");
		return Plugin_Handled;
	}

	SDKUnhook(client, SDKHook_PreThinkPost, OnRainbowPlayer);

	if( g_bCvarAllow && g_bMapStarted && !g_bRoundOver && g_iCvarRainbow )
	{
		if( g_iCvarRainbow == 3 || g_iCvarRainbow == GetClientTeam(client) - 1 )
		{
			DeleteLight(client);

			CommandLight(client, 0, "", true);
		}
	}

	return Plugin_Handled;
}

void OnRainbowPlayer(int client)
{
	if( !g_bCvarAllow || !g_bMapStarted || g_bRoundOver || !g_iCvarRainbow || !IsClientInGame(client) || !IsPlayerAlive(client) || !IsValidEntRef(g_iLightIndex[client]) )
	{
		SDKUnhook(client, SDKHook_PreThinkPost, OnRainbowPlayer);
	}

	int color[3];
	float time = client + g_fCvarRainbows * GetGameTime();
	color[0] = RoundToNearest(Cosine(time + 1) * 127.5 + 127.5);
	color[1] = RoundToNearest(Cosine(time + 3) * 127.5 + 127.5);
	color[2] = RoundToNearest(Cosine(time + 5) * 127.5 + 127.5);

	// Light Color
	static char sBuffer[16];
	FormatEx(sBuffer, sizeof(sBuffer), "%d %d %d %d", GetRandomColor(color[2]), GetRandomColor(color[1]), GetRandomColor(color[0]), 255);
	DispatchKeyValue(g_iLightIndex[client], "_light", sBuffer);
}

stock int GetRandomColor(int color)
{
	return (color == -1 || color < 0 || color > 255) ? GetRandomInt(0, 255) : color;
}



// ====================================================================================================
//					COMMAND - sm_light
// ====================================================================================================
Action CmdLightCommand(int client, int args)
{
	if( !client )
	{
		ReplyToCommand(client, "Command can only be used %s", IsDedicatedServer() ? "in game on a dedicated server." : "in chat on a Listen server.");
		return Plugin_Handled;
	}

	char sArg[25];
	GetCmdArgString(sArg, sizeof(sArg));
	CommandLight(client, args, sArg);
	return Plugin_Handled;
}

void CommandLight(int client, int args, char[] sArg, bool rainbow = false, bool random = false)
{
	// Must be valid
	if( !client || !IsClientInGame(client) )
		return;

	if( !IsValidNow() )
	{
		CPrintToChat(client, "[SM] %T.", "No Access", client);
		return;
	}

	if( IsPlayerAlive(client) )
	{
		int team = GetClientTeam(client);
		if( team == 2 ) team = 1;
		else if( team == 3 ) team = 2;
		else team = 0;

		if( !(g_iCvarUsers & team) )
		{
			CPrintToChat(client, "[SM] %T.", "No Access", client);
			return;
		}
	}
	else
	{
		if( g_iCvarSpec == 0 )
		{
			CPrintToChat(client, "[SM] %T.", "No Access", client);
			return;
		}

		int team = GetClientTeam(client);
		if( team == 3 ) team = 4;
		else if( team == 4 ) team = 8;

		if( !(g_iCvarSpec & team) )
		{
			CPrintToChat(client, "[SM] %T.", "No Access", client);
			return;
		}
	}

	// Make sure the user has the correct permissions
	int flagc = GetUserFlagBits(client);

	if( g_iCvarFlags != 0 && !(flagc & g_iCvarFlags) && !(flagc & ADMFLAG_ROOT) )
	{
		CPrintToChat(client, "[SM] %T.", "No Access", client);
		return;
	}

	// Wrong number of arguments
	if( args != 0 && args != 1 && args != 3 )
	{
		// Display usage help if translation exists and hints turned on
		CPrintToChat(client, "%s%T", CHAT_TAG, "Flashlight Usage", client);
		return;
	}

	// Delete flashlight and re-make if the players model has changed, CSM plugin fix...
	static char sTempStr[42];
	GetClientModel(client, sTempStr, sizeof(sTempStr));
	if( strcmp(g_sPlayerModel[client], sTempStr) != 0 )
	{
		DeleteLight(client);
		strcopy(g_sPlayerModel[client], sizeof(g_sPlayerModel[]), sTempStr); 
	}

	// Off option
	if( args == 1 )
	{
		if( strcmp(sArg, "off", false) == 0 )
		{
			g_bRainbow[client] = false;
			g_iClientLight[client] = 0;

			SDKUnhook(client, SDKHook_PreThinkPost, OnRainbowPlayer);

			if( g_iCvarSave && !IsFakeClient(client) )
			{
				SetClientCookie(client, g_hCookieState, "0");
			}

			DeleteLight(client);
			return;
		}
	}

	// Check if they have a light, or try to create
	int entity = g_iLightIndex[client];
	if( !IsValidEntRef(entity) )
	{
		CreateLight(client);

		entity = g_iLightIndex[client];
		if( !IsValidEntRef(entity) )
			return;
	}

	// Specified colors
	if( g_bCvarLock && !(flagc & ADMFLAG_ROOT) )
		flagc = 0;
	else
		flagc = 1;

	bool setCol;

	// Toggle or set light color and turn on./
	if( flagc && (random || (args == 1 && strncmp(sArg, "rand", 4, false) == 0)) )
	{
		char sTempL[12];

		#if COMPLETELY_RANDOM
			// Completely random color
			Format(sTempL, sizeof(sTempL), "%d %d %d", GetRandomInt(20, 255), GetRandomInt(20, 255), GetRandomInt(20, 255));
			SetVariantString(sTempL);
			AcceptEntityInput(entity, "color");
			setCol = true;
		#else
			// Random color from list
			int size = g_hSnapColors.Length;
			int pos = g_iCvarRainbow ? 2 : 1;

			g_hSnapColors.GetKey(GetRandomInt(pos, size - 1), sTempL, sizeof(sTempL));
			if( g_hColors.GetString(sTempL, sTempL, sizeof(sTempL)) )
			{
				SetVariantString(sTempL);
				AcceptEntityInput(entity, "color");
				setCol = true;
			}
		#endif
	}
	else if( flagc && args == 1 && (strncmp(sArg, "bow", 4, false) == 0 || strncmp(sArg, "rainbow", 8, false) == 0) )
	{
		rainbow = true;
	}
	else if( flagc && args == 1 )
	{
		char sTempL[12];

		LowerCaseString(sArg);

		if( g_hColors.GetString(sArg, sTempL, sizeof(sTempL)) == false )
		{
			sTempL = "-1 -1 -1";
		}
		else if( strcmp(sTempL, "0") == 0 )
		{
			rainbow = true;
		}
		else
		{
			SetVariantString(sTempL);
			AcceptEntityInput(entity, "color");
			setCol = true;
		}
	}
	else if( flagc && args == 3 )
	{
		// Specified colors
		char sTempL[12];
		char sSplit[3][4];
		ExplodeString(sArg, " ", sSplit, sizeof(sSplit), sizeof(sSplit[]));
		Format(sTempL, sizeof(sTempL), "%d %d %d", StringToInt(sSplit[0]), StringToInt(sSplit[1]), StringToInt(sSplit[2]));

		SetVariantString(sTempL);
		AcceptEntityInput(entity, "color");
		setCol = true;
	}

	// Rainbow state
	bool oldBow = g_bRainbow[client];
	g_bRainbow[client] = rainbow;

	// Turn off rainbow if toggling, else turn on
	if( rainbow && g_iCvarRainbow && (g_iCvarRainbow == 3 || g_iCvarRainbow == GetClientTeam(client) - 1) )
	{
		// Turn rainbow off
		if( oldBow )
		{
			rainbow = false;
			g_bRainbow[client] = false;
			g_iClientLight[client] = 0;
			AcceptEntityInput(entity, "TurnOff");

			if( g_iCvarSave && !IsFakeClient(client) )
			{
				SetClientCookie(client, g_hCookieBows, "0");
			}
		}
		// Turn rainbow on
		else
		{
			g_bRainbow[client] = true;
			g_iClientLight[client] = 1;
			AcceptEntityInput(entity, "TurnOn");

			if( g_iCvarSave && !IsFakeClient(client) )
			{
				SetClientCookie(client, g_hCookieBows, "1");
			}
		}
	}
	else
	{
		// Save rainbow off
		if( g_iCvarSave && !IsFakeClient(client) )
		{
			g_bRainbow[client] = false;
			SetClientCookie(client, g_hCookieBows, "0");
		}

		// Set new color
		int color;

		if( setCol )
		{
			color = GetEntProp(entity, Prop_Send, "m_clrRender");

			if( color == g_iClientColor[client] )
			{
				g_iClientLight[client] = !g_iClientLight[client];
				AcceptEntityInput(entity, "Toggle");
			}
			else
			{
				g_iClientLight[client] = 1;
				g_iClientColor[client] = color;
				AcceptEntityInput(entity, "TurnOn");
			}

			g_bRainbow[client] = false;

			if( g_iCvarSave && !IsFakeClient(client) )
			{
				char sNum[10];
				IntToString(color, sNum, sizeof(sNum));
				SetClientCookie(client, g_hCookieColor, sNum);
			}
		}
		else
		{
			g_bRainbow[client] = false;

			// Turn off bow
			if( oldBow )
			{
				g_iClientLight[client] = 0;
				AcceptEntityInput(entity, "TurnOff");
			}
			else
			{
				// Restore previous color and toggle
				g_iClientLight[client] = !g_iClientLight[client];
				SetEntProp(entity, Prop_Send, "m_clrRender", g_iClientColor[client]);
				AcceptEntityInput(entity, "Toggle");

				if( g_iCvarSave && !IsFakeClient(client) )
				{
					char sNum[10];
					IntToString(g_iClientColor[client], sNum, sizeof(sNum));
					SetClientCookie(client, g_hCookieColor, sNum);
				}
			}
		}
	}

	// Save light state/color
	if( g_iCvarSave && !IsFakeClient(client) )
	{
		char sNum[4];
		IntToString(g_iClientLight[client], sNum, sizeof(sNum));
		SetClientCookie(client, g_hCookieState, sNum);
	}

	SDKUnhook(client, SDKHook_PreThinkPost, OnRainbowPlayer);

	if( rainbow )
	{
		SDKHook(client, SDKHook_PreThinkPost, OnRainbowPlayer);
	}
}

// Called to attach permanent light.
void CreateLight(int client)
{
	DeleteLight(client);

	// Declares
	int entity;
	float vOrigin[3], vAngles[3];

	// Flashlight model
	if( g_bValidMap && GetClientTeam(client) == 2 && IsPlayerAlive(client) )
	{
		entity = CreateEntityByName("prop_dynamic");
		if( entity == -1 )
		{
			LogError("Failed to create 'prop_dynamic'");
		}
		else
		{
			SetEntityModel(entity, MODEL_LIGHT);
			DispatchSpawn(entity);

			vOrigin = view_as<float>({ 0.0, 0.0, -2.0 });
			vAngles = view_as<float>({ 180.0, 9.0, 90.0 });

			// Attach to survivor
			SetVariantString("!activator");
			AcceptEntityInput(entity, "SetParent", client);
			SetVariantString(ATTACH_GRENADE);
			AcceptEntityInput(entity, "SetParentAttachment");

			TeleportEntity(entity, vOrigin, vAngles, NULL_VECTOR);
			SDKHook(entity, SDKHook_SetTransmit, Hook_SetTransmitLight);
			g_iModelIndex[client] = EntIndexToEntRef(entity);
		}
	}

	// Position light
	switch( GetClientTeam(client) )
	{
		case 2:	vOrigin = view_as<float>({ 0.5, -1.5, -7.5 });
		case 3: vOrigin = view_as<float>({ 0.0, 0.0, 50.0 });
		default: vOrigin = view_as<float>({ 0.0, 0.0, 0.0 });
	}

	vAngles = view_as<float>({ -45.0, -45.0, 90.0 });

	// Light_Dynamic
	entity = MakeLightDynamic(vOrigin, vAngles, client);
	g_iLightIndex[client] = EntIndexToEntRef(entity);

	if( g_bRainbow[client] )
	{
		SDKUnhook(client, SDKHook_PreThinkPost, OnRainbowPlayer);
		SDKHook(client, SDKHook_PreThinkPost, OnRainbowPlayer);
	}
	else if( g_iClientColor[client] )
	{
		SetEntProp(entity, Prop_Send, "m_clrRender", g_iClientColor[client]);
	}

	if( g_iClientLight[client] == 1 )
		AcceptEntityInput(entity, "TurnOn");
	else
		AcceptEntityInput(entity, "TurnOff");

	// Special Infected only light
	if( GetClientTeam(client) == 3 )
	{
		g_iLights[client] = EntIndexToEntRef(entity);
		SDKHook(entity, SDKHook_SetTransmit, Hook_SetTransmitSpec);
	}
}



// ====================================================================================================
//					LIGHTS
// ====================================================================================================
int MakeLightDynamic(const float vOrigin[3], const float vAngles[3], int client)
{
	int entity = CreateEntityByName("light_dynamic");
	if( entity == -1)
	{
		LogError("Failed to create 'light_dynamic'");
		return 0;
	}

	char sTemp[16];
	Format(sTemp, sizeof(sTemp), "%s 255", g_sCvarCols);
	DispatchKeyValue(entity, "_light", sTemp);
	DispatchKeyValue(entity, "brightness", "1");
	DispatchKeyValueFloat(entity, "spotlight_radius", 32.0);
	DispatchKeyValueFloat(entity, "distance", GetClientTeam(client) == 3 ? float(g_iCvarAlphas) : float(g_iCvarAlpha));
	DispatchKeyValue(entity, "style", "0");
	DispatchSpawn(entity);
	AcceptEntityInput(entity, "TurnOn");

	// Attach to survivor
	SetVariantString("!activator");
	AcceptEntityInput(entity, "SetParent", client);

	if( GetClientTeam(client) == 2 && IsPlayerAlive(client) )
	{
		SetVariantString(ATTACH_GRENADE);
		AcceptEntityInput(entity, "SetParentAttachment");
	}

	TeleportEntity(entity, vOrigin, vAngles, NULL_VECTOR);
	return entity;
}



// ====================================================================================================
//					DELETE ENTITIES
// ====================================================================================================
void DeleteLight(int client)
{
	int entity = g_iLightIndex[client];
	g_iLightIndex[client] = 0;
	DeleteEntity(entity);

	entity = g_iModelIndex[client];
	g_iModelIndex[client] = 0;
	DeleteEntity(entity);

	entity = g_iLights[client];
	g_iLights[client] = 0;
	DeleteEntity(entity);
}

void DeleteEntity(int entity)
{
	if( IsValidEntRef(entity) )
		RemoveEntity(entity);
}



// ====================================================================================================
//					BOOLEANS
// ====================================================================================================
bool IsValidEntRef(int entity)
{
	if( entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE )
		return true;
	return false;
}

bool IsValidClient(int client)
{
	if( !client || !IsClientInGame(client) || !IsPlayerAlive(client) )
		return false;

	int team = GetClientTeam(client);
	if( team == 2 ) team = 1;
	else if( team == 3 ) team = 2;
	else team = 0;

	if( !(g_iCvarUsers & team) )
		return false;

	return true;
}

bool IsValidNow()
{
	if( g_bRoundOver || !g_bCvarAllow )
		return false;
	return true;
}



// ====================================================================================================
//					SDKHOOKS TRANSMIT
// ====================================================================================================
Action Hook_SetTransmitLight(int entity, int client)
{
	if( g_iModelIndex[client] == EntIndexToEntRef(entity) || GetEntPropEnt(client, Prop_Send, "m_hObserverTarget") != -1 )
		return Plugin_Handled;
	return Plugin_Continue;
}

Action Hook_SetTransmitSpec(int entity, int client)
{
	if( g_iLights[client] == EntIndexToEntRef(entity) )
		return Plugin_Continue;
	return Plugin_Handled;
}



// ====================================================================================================
//					COLORS.INC REPLACEMENT
// ====================================================================================================
void CPrintToChat(int client, char[] message, any ...)
{
	static char buffer[256];
	VFormat(buffer, sizeof(buffer), message, 3);

	ReplaceString(buffer, sizeof(buffer), "{default}",		"\x01");
	ReplaceString(buffer, sizeof(buffer), "{white}",		"\x01");
	ReplaceString(buffer, sizeof(buffer), "{cyan}",			"\x03");
	ReplaceString(buffer, sizeof(buffer), "{lightgreen}",	"\x03");
	ReplaceString(buffer, sizeof(buffer), "{orange}",		"\x04");
	ReplaceString(buffer, sizeof(buffer), "{green}",		"\x04"); // Actually orange in L4D2, but replicating colors.inc behaviour
	ReplaceString(buffer, sizeof(buffer), "{olive}",		"\x05");
	PrintToChat(client, buffer);
}

void LowerCaseString(char[] sTemp)
{
	int len = strlen(sTemp);

	for( int i = 0; i < len; i++ )
	{
		sTemp[i] = CharToLower(sTemp[i]);
	}
}