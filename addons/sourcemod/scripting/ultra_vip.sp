/**
 * The file is a part of Ultra-VIP.
 *
 * Copyright (C) Mesharsky & SirDigbot
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

#include <sourcemod>
#include <multicolors>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <clientprefs>

#undef REQUIRE_PLUGIN
#tryinclude <chat-processor>    // Prefer chat-processor over scp
#if !defined _chat_processor_included
    #tryinclude <scp>
#endif
#define REQUIRE_PLUGIN

#if !defined MAXLENGTH_NAME
    #define MAXLENGTH_NAME 64 // scp.inc
#endif
#if !defined MAXLENGTH_MESSAGE
    #define MAXLENGTH_MESSAGE 128
#endif

#include <ultra_vip>


#pragma newdecls required
#pragma semicolon 1

#define PLUGIN_VERSION "0.1"
//#define DEBUG


#if SOURCEMOD_V_MAJOR >= 1 && SOURCEMOD_V_MINOR >= 11
    #define COMPILER_IS_SM1_11
#else
    #define COMPILER_IS_OLDER_THAN_SM1_11
#endif


// Special round values (used by IsRoundAllowed)
// All special values must be negative, and INVALID_ROUND must be 0
#define INVALID_ROUND 0
#define ROUND_WARMUP_ONLY -1
#define ROUND_MATCH_POINT -2
#define ROUND_PISTOL -3
#define ROUND_LAST_OF_HALF -4

#define MAX_WEAPON_CLASSNAME_SIZE 24 // https://wiki.alliedmods.net/Counter-Strike:_Global_Offensive_Weapons
#define MAX_SERVICE_NAME_SIZE 64
#define MAX_SERVICE_OVERRIDE_SIZE 64
#define MAX_SETTING_NAME_SIZE 64
#define MAX_SETTING_VALUE_SIZE 256

#define EXTRAJUMP_DEFAULT_HEIGHT 250.0

// How frequently to rescan all players for changes to admin cache.
#define ADMCACHE_RESCAN_INTERVAL 8.0
int g_AdminCacheFlags[MAXPLAYERS + 1];
int g_AdminCacheGroupCount[MAXPLAYERS + 1];

enum
{
    GamePhase_Warmup,
    GamePhase_Standard,
    GamePhase_PlayingFirstHalf,
    GamePhase_PlayingSecondHalf,
    GamePhase_Halftime,
    GamePhase_MatchEnded,
    GamePhase_TOTAL
};

static ConVar s_Cvar_MaxRounds;

bool g_IsLateLoad;
bool g_HaveAllPluginsLoaded;    // Used to detect if natives are being called during a lateload
Handle g_HudMessages;
bool g_IsInOnStartForward;
ArrayList g_Services;
ArrayList g_SortedServiceFlags;
ArrayList g_SortedServiceOverrides;
StringMap g_ModuleSettings;
bool g_HasRoundEnded;

GlobalForward g_Fwd_OnStart;
GlobalForward g_Fwd_OnReady;
GlobalForward g_Fwd_OnPostAdminCheck;
GlobalForward g_Fwd_OnDisconnect;
GlobalForward g_Fwd_OnSpawn;
GlobalForward g_Fwd_OnSpawnWithService;

Cookie g_Cookie_PrevWeapons;

enum ChatProcessor
{
    Processor_Null = 0,
    Processor_SCP,
    Processor_ChatProcessor
};

enum struct Detect_ChatTag
{
    ChatProcessor processor;
    char name[64];
}

Detect_ChatTag g_ChatTagPlugin;

//ConVar g_Cvar_ArenaMode;

int g_RoundCount;

#include "ultra_vip/config.sp"
#include "ultra_vip/service.sp"
#include "ultra_vip/events.sp"
#include "ultra_vip/weaponmenu.sp"
#include "ultra_vip/menus.sp"
#include "ultra_vip/extrajump.sp"
#include "ultra_vip/util.sp"
#include "ultra_vip/chat.sp"
#include "ultra_vip/grenade.sp"

Service g_ClientService[MAXPLAYERS +1];

#include "ultra_vip/natives.sp" // After g_ClientService


public Plugin myinfo =
{
    name = "Ultra VIP",
    author = "Mesharsky",
    description = "Highly configurable VIP system with support for custom services",
    version = PLUGIN_VERSION,
    url = "https://github.com/Mesharsky/Ultra-VIP"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    if (GetEngineVersion() != Engine_CSGO)
    {
        Format(error, err_max, "Ultra-VIP only works with CS:GO.");
        return APLRes_Failure;
    }

    CreateNative("_UVIP_IsCoreCompatible", Native_IsCoreCompatible);
    CreateNative("_UVIP_HandleLateLoad", Native_HandleLateLoad);

    CreateNative("UVIP_RegisterSetting", Native_RegisterSetting);
    CreateNative("UVIP_OverrideFeature", Native_OverrideFeature);
    CreateNative("UVIP_GetClientService", Native_GetClientService);

    CreateNative("UVIPService.Get", Native_UVIPService_Get);
    CreateNative("UVIPService.GetInt", Native_UVIPService_GetInt);
    CreateNative("UVIPService.GetFloat", Native_UVIPService_GetFloat);
    CreateNative("UVIPService.GetCell", Native_UVIPService_GetCell);
    RegPluginLibrary("ultra_vip");

    g_IsLateLoad = late;
    return APLRes_Success;
}

public void OnPluginStart()
{
    g_Services = new ArrayList();
    g_SortedServiceFlags = new ArrayList();
    g_SortedServiceOverrides = new ArrayList(ByteCountToCells(MAX_SERVICE_OVERRIDE_SIZE));
    g_Cookie_PrevWeapons = new Cookie("ultra_vip_weapons", "Previously Selected Weapons", CookieAccess_Private);
    g_HudMessages = CreateHudSynchronizer();

    g_Fwd_OnStart = new GlobalForward("UVIP_OnStart", ET_Ignore);
    g_Fwd_OnReady = new GlobalForward("UVIP_OnReady", ET_Ignore);
    g_Fwd_OnPostAdminCheck = new GlobalForward("UVIP_OnClientPostAdminCheck", ET_Ignore, Param_Cell, Param_Cell);
    g_Fwd_OnDisconnect = new GlobalForward("UVIP_OnClientDisconnect", ET_Ignore, Param_Cell, Param_Cell);
    g_Fwd_OnSpawn = new GlobalForward("UVIP_OnSpawn", ET_Ignore, Param_Cell, Param_Cell);
    g_Fwd_OnSpawnWithService = new GlobalForward("UVIP_OnSpawnWithService", ET_Ignore, Param_Cell, Param_Cell);

    s_Cvar_MaxRounds = FindConVar("mp_maxrounds");
    if (s_Cvar_MaxRounds == null)
        SetFailState("Game is somehow missing the required \"mp_maxrounds\" ConVar.");

    //g_Cvar_ArenaMode = CreateConVar("arena_mode", "0", "Should arena mode (splewis) be enabled?\nRemeber that plugin will use arena configuration file instead if enabled");

    LoadTranslations("ultra_vip.phrases.txt");

    Natives_OnPluginStart();

    RegConsoleCmd("sm_jumps", Command_ToggleJumps);
    RegConsoleCmd("sm_vips", Command_OnlineList);
    RegConsoleCmd("sm_vipbonus", Command_VipBonuses);
    RegAdminCmd("sm_reloadservices", Command_ReloadServices, ADMFLAG_ROOT, "Reloads configuration file");

    HookEvent("player_spawn", Event_PlayerSpawn);
    HookEvent("player_death", Event_PlayerDeath);
    HookEvent("bomb_planted", Event_BombPlanted);
    HookEvent("bomb_defused", Event_BombDefused);
    HookEvent("round_mvp", Event_RoundMvp);
    HookEvent("hostage_rescued", Event_HostageRescued);
    HookEvent("round_start", Event_RoundStart);
    HookEvent("round_end", Event_RoundEnd);
    HookEvent("weapon_fire", Event_WeaponFire);
    HookEvent("player_connect_full", Event_PlayerConnectFull);
}

public void OnAllPluginsLoaded()
{
    FindChatProcessor();

    // Must call OnStart here so modules are all loaded
    g_IsInOnStartForward = true;
    Call_StartForward(g_Fwd_OnStart);
    if (Call_Finish() != SP_ERROR_NONE)
        LogError("Failed to call UVIP_OnStart");
    g_IsInOnStartForward = false;

    ReloadConfig(true, g_IsLateLoad);

    CreateTimer(ADMCACHE_RESCAN_INTERVAL, Timer_RescanServices, _, TIMER_REPEAT);

    Call_StartForward(g_Fwd_OnReady);
    if (Call_Finish() != SP_ERROR_NONE)
        LogError("Failed to call UVIP_OnReady");

    g_HaveAllPluginsLoaded = true; // Must set last. See comment at definition.
}

bool ReloadConfig(bool fatalError, bool notifyLateLoad)
{
    if (Config_Load(fatalError))
    {
        HandleLateLoad();
        if (notifyLateLoad)
            PrintToServer("[Ultra VIP] %t", "Late load warning");
        return true;
    }

    return false;
}

static void HandleLateLoad()
{
    /**
     * NOTE / TODO: Lateloading is not fully supported.
     * It doesn't handle Event_PlayerSpawn so players will not get bonuses until the next round.
     * Some other things may behave incorrectly or be completely broken.
     *
     * Otherwise, it does *try* to make sure the plugin will work correctly on the next round.
     */

    for (int i = 1; i <= MaxClients; ++i)
    {
        if (IsClientAuthorized(i))
        {
            OnClientPostAdminCheck(i);

            // TODO: Technically this should retry if it fails but eh
            if (AreClientCookiesCached(i))
                OnClientCookiesCached(i);
        }
    }
}

// For config.sp because of include ordering
void ResetAllClientServices()
{
    for (int i = 0; i < sizeof(g_ClientService); ++i)
        g_ClientService[i] = null;
}

public void OnMapStart()
{
    g_RoundCount = INVALID_ROUND;
    Bonus_OnMapStart();
}

public void OnConfigsExecuted()
{
    Config_FixCvars();
}

public void OnMapEnd()
{
    Events_OnMapEnd();
}

public void OnClientCookiesCached(int client)
{
    if (IsFakeClient(client))
        return;

    WeaponMenu_GetPreviousWeapons(client);
}

public void OnClientPostAdminCheck(int client)
{
    // NOTE: This function must be callable from Timer_RescanServices
    // and Command_ReloadServices without issues!

    // Service must always be null if none is owned
    g_ClientService[client] = FindClientService(client);
    UpdateClientAdminCache(client);

    ExtraJump_OnClientPostAdminCheck(client, g_ClientService[client]);

    CallServiceForward(g_Fwd_OnPostAdminCheck, client, g_ClientService[client]);
}

public void OnClientDisconnect(int client)
{
    CallServiceForward(g_Fwd_OnDisconnect, client, g_ClientService[client]);

    Bonus_LeaveMessage(client);
    ExtraJump_OnClientDisconect(client);
    WeaponMenu_ResetPreviousWeapons(client);

    g_ClientService[client] = null;
    g_AdminCacheFlags[client] = 0;
    g_AdminCacheGroupCount[client] = 0;
}

public Action Timer_RescanServices(Handle timer)
{
    /**
     * NOTE: Because of VIP plugins granting access via database, the admin
     * permissions aren't ready during OnClientPostAdminCheck.
     * As of 1.11, there's no forward for when a client's admin permissions change.
     *
     * So we must manually recheck it constantly.
     */

    for (int i = 1; i <= MaxClients; ++i)
    {
        if (!IsClientInGame(i) || !IsClientAuthorized(i) || IsFakeClient(i))
            continue;

        if (UpdateClientAdminCache(i))
            OnClientPostAdminCheck(i);
    }

    return Plugin_Continue;
}

#if defined COMPILER_IS_SM1_11
public void OnNotifyPluginUnloaded(Handle plugin)
{
    Natives_OnPluginUnloaded(plugin);
}
#endif

public Action Command_OnlineList(int client, int args)
{
    if (!g_UseOnlineList)
    {
        CReplyToCommand(client, "%t", "Vip Online List Disabled");
        return Plugin_Handled;
    }

    if (!IsClientInGame(client) || IsFakeClient(client))
        return Plugin_Handled;

    ShowOnlineList(client);

    return Plugin_Handled;
}

public Action Command_VipBonuses(int client, int args)
{
    if (!IsClientInGame(client) || IsFakeClient(client))
        return Plugin_Handled;

    if (!g_UseBonusesList)
    {
        CReplyToCommand(client, "%t", "Vip Bonuses Disabled");
        return Plugin_Handled;
    }

    ShowServiceBonuses(client);
    return Plugin_Handled;
}

public Action Command_ReloadServices(int client, int args)
{
    if (ReloadConfig(false, false))
        CPrintToChatAll("%t", "Ultra VIP reloaded config");
    else
    {
        CReplyToCommand(client, "%t", "Config Reload Error");
        SetFailState("Failed to reload configuration file");
    }

    return Plugin_Handled;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
    ExtraJump_OnPlayerRunCmd(client);
    return Plugin_Continue;
}

int GetRoundOfCurrentHalf()
{
    if (IsWarmup())
        return INVALID_ROUND;

    // Increase by 1 so 0 = invalid/INVALID_ROUND and 1 = first round
    int roundNum = GameRules_GetProp("m_totalRoundsPlayed") + 1;

    if (GameRules_GetProp("m_gamePhase") == GamePhase_PlayingSecondHalf)
        return roundNum - (s_Cvar_MaxRounds.IntValue / 2);
    return roundNum;
}

static bool IsMatchPoint(int maxRounds)
{
    int ct = CS_GetTeamScore(CS_TEAM_CT);
    int t = CS_GetTeamScore(CS_TEAM_T);

    int max = ct > t ? ct : t;

    // Rounds needed to win is (maxRounds / 2) + 1
    return max == (maxRounds / 2);
}

static bool IsPistolRound(int currentRoundOfHalf)
{
    return currentRoundOfHalf == 1;
}

static bool IsRoundLastOfHalf(int currentRoundOfHalf, int maxRounds)
{
    // For even values of mp_maxrounds, or for the second half of games
    // with odd mp_maxrounds, the formula (current * 2) >= maxRounds works.
    //
    // For the first half of games with odd mp_maxrounds,
    // (current * 2) + 1 >= maxRounds works

    if (maxRounds % 2 == 0 || GameRules_GetProp("m_gamePhase") == GamePhase_PlayingSecondHalf)
        return (currentRoundOfHalf * 2) >= maxRounds;
    return (currentRoundOfHalf * 2) + 1 >= maxRounds;
}

bool IsRoundAllowed(Service svc, int round)
{
    if (IsWarmup() && (round == ROUND_WARMUP_ONLY || svc.AllowDuringWarmup))
        return true;

    int current = GetRoundOfCurrentHalf();
    int maxRounds = s_Cvar_MaxRounds.IntValue;

    if (round == ROUND_MATCH_POINT && IsMatchPoint(maxRounds))
        return true;
    if (round == ROUND_PISTOL && IsPistolRound(current))
        return true;
    if (round == ROUND_LAST_OF_HALF && IsRoundLastOfHalf(current, maxRounds))
        return true;

    return g_RoundCount >= round && round > INVALID_ROUND;
}

bool UpdateClientAdminCache(int client)
{
    // See Timer_RescanServices

    int oldFlags = g_AdminCacheFlags[client];
    int oldCount = g_AdminCacheGroupCount[client];

    g_AdminCacheFlags[client] = GetUserFlagBits(client);
    g_AdminCacheGroupCount[client] = GetClientAdminGroupCount(client); // TODO / BUG: DOESNT WORK IF YOU ONLY CHANGE OVERRIDES REEE

    return oldFlags != g_AdminCacheFlags[client] || oldCount != g_AdminCacheGroupCount[client];
}

Service GetClientService(int client)
{
    if (!client)
        return null;
    return g_ClientService[client];
}

Service FindClientService(int client)
{
    if (!IsClientAuthorized(client) || IsFakeClient(client))
        return null;

    // Find root service, if any
    int flags = GetUserFlagBits(client);

    if (flags & ADMFLAG_ROOT)
    {
        if (g_RootServiceMode == Mode_None)
            return null;
        else if (g_RootServiceMode == Mode_Specified)
            return g_RootService;
        // Mode_Auto handled below
    }

    // Search using admin flags/overrides
    Service svc = FindHighestPriorityService(client, flags);
    if (svc != null)
        return svc;

    // Search using steamid overrides
    int account = GetSteamAccountID(client);
    if (account)
    {
        char buffer[16];
        IntToString(account, buffer, sizeof(buffer));

        if (g_SteamIDServices.GetValue(buffer, svc))
            return svc;
    }

    return null;
}

Service FindHighestPriorityService(int client, int adminFlags)
{
    Service svc;
    if (adminFlags)
        svc = FindServiceByFlagAccess(adminFlags);

    if (svc == null)
        svc = FindServiceByOverrideAccess(client);

    return svc;
}

static Service FindServiceByFlagAccess(int adminFlags)
{
    // Find highest priority service flag that client has access to
    int len = g_SortedServiceFlags.Length;
    int foundFlag;
    for (int i = 0; i < len; ++i)
    {
        int temp = g_SortedServiceFlags.Get(i);
        if (HasAdminFlagAccess(temp, adminFlags))
        {
            foundFlag = temp;
            break;
        }
    }

    if (!foundFlag)
        return null;

    // Find the matching service
    len = g_Services.Length;
    for (int i = 0; i < len; ++i)
    {
        Service svc = g_Services.Get(i);
        if (svc.Flag == foundFlag)
            return svc;
    }

    LogError("Somehow failed to find g_Services flag that was in g_SortedServiceFlags");
    return null;
}

static Service FindServiceByOverrideAccess(int client)
{
    // Find highest priority service override that client has access to
    char override[MAX_SERVICE_OVERRIDE_SIZE];
    int len = g_SortedServiceOverrides.Length;

    for (int i = 0; i < len; ++i)
    {
        g_SortedServiceOverrides.GetString(i, override, sizeof(override));

        if (!override[0])
            continue;

        if (CheckCommandAccess(client, override, ADMFLAG_ROOT, false))
            break;

        override[0] = '\0';
    }

    if (!override[0])
        return null;

    // Find the matching service
    len = g_Services.Length;
    char svcOverride[MAX_SERVICE_OVERRIDE_SIZE];

    for (int i = 0; i < len; ++i)
    {
        Service svc = g_Services.Get(i);

        svc.GetOverride(svcOverride, sizeof(svcOverride));

        if (StrEqual(svcOverride, override, false))
            return svc;
    }

    LogError("Somehow failed to find g_Services override that was in g_SortedServiceOverrides");
    return null;
}

void CallServiceForward(GlobalForward fwd, int client, Service svc)
{
    Call_StartForward(fwd);
    Call_PushCell(client);
    Call_PushCell(svc);
    if (Call_Finish() != SP_ERROR_NONE)
        LogError("Failed to call forward.");
}

void FindChatProcessor()
{
    if (LibraryExists("scp"))
    {
        g_ChatTagPlugin.processor = Processor_SCP;
        PrintToServer("[Ultra VIP] %T", "Chat Processor Loaded", LANG_SERVER, g_ChatTagPlugin.name);
    }
    else if (LibraryExists("chat-processor"))
    {
        g_ChatTagPlugin.processor = Processor_ChatProcessor;
        PrintToServer("[Ultra VIP] %T", "Chat Processor Loaded", LANG_SERVER, g_ChatTagPlugin.name);
    }
    else
    {
        g_ChatTagPlugin.processor = Processor_Null;
        PrintToServer("[Ultra VIP] %T", "Chat Processor Not Found", LANG_SERVER);
    }
}

public void OnLibraryAdded(const char[] name)
{
    if (StrEqual(name, "scp"))
    {
        g_ChatTagPlugin.processor = Processor_SCP;
        g_ChatTagPlugin.name = "Simple Chat Processor";

        return;
    }
    else if (StrEqual(name, "chat-processor"))
    {
        g_ChatTagPlugin.processor = Processor_ChatProcessor;
        g_ChatTagPlugin.name = "Chat Processor";

        return;
    }
}

public void OnLibraryRemoved(const char[] name)
{
    if (StrEqual(name, "scp") && g_ChatTagPlugin.processor == Processor_SCP)
        g_ChatTagPlugin.processor = Processor_Null;
    else if (StrEqual(name, "chat-processor") && g_ChatTagPlugin.processor == Processor_ChatProcessor)
        g_ChatTagPlugin.processor = Processor_Null;
}
