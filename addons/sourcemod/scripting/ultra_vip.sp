/**
 * Copyright (C) Mesharsky
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


#pragma newdecls required
#pragma semicolon 1

#define PLUGIN_VERSION "0.1"
#define DEBUG

#define INVALID_ROUND 0
#define MAX_WEAPON_CLASSNAME_SIZE 24 // https://wiki.alliedmods.net/Counter-Strike:_Global_Offensive_Weapons
#define MAX_SERVICE_NAME_SIZE 64
#define EXTRAJUMP_DEFAULT_HEIGHT 250.0


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
Handle g_HudMessages;
ArrayList g_Services;
ArrayList g_SortedServiceFlags;

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

public Plugin myinfo =
{
    name = "Ultra VIP",
    author = "Mesharsky",
    description = "Ultra VIP System that supports multimple services",
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

    g_IsLateLoad = late;
    return APLRes_Success;
}

public void OnPluginStart()
{
    g_Services = new ArrayList();
    g_SortedServiceFlags = new ArrayList();

    LoadTranslations("ultra_vip.phrases.txt");

    s_Cvar_MaxRounds = FindConVar("mp_maxrounds");
    if (s_Cvar_MaxRounds == null)
        SetFailState("Game is somehow missing the required \"mp_maxrounds\" ConVar.");

    RegConsoleCmd("sm_jumps", Command_ToggleJumps);
    RegConsoleCmd("sm_vips", Command_OnlineList);

    RegAdminCmd("sm_reloadservices", Command_ReloadServices, ADMFLAG_ROOT, "Reloads configuration file");

    HookEvent("player_spawn", Event_PlayerSpawn);
    HookEvent("player_death", Event_PlayerDeath);
    HookEvent("bomb_planted", Event_BombPlanted);
    HookEvent("bomb_defused", Event_BombDefused);
    HookEvent("round_mvp", Event_RoundMvp);
    HookEvent("hostage_rescued", Event_HostageRescued);
    HookEvent("round_start", Event_RoundStart);
    HookEvent("weapon_fire", Event_WeaponFire);
    HookEvent("player_connect_full", Event_PlayerConnectFull);

#if defined DEBUG
    RegConsoleCmd("sm_endround", Command_EndRound);
#endif

	//g_Cvar_ArenaMode = CreateConVar("arena_mode", "0", "Should arena mode (splewis) be enabled?\nRemeber that plugin will use arena configuration file instead if enabled");

    g_Cookie_PrevWeapons = new Cookie("ultra_vip_weapons", "Previously Selected Weapons", CookieAccess_Private);
    LoadConfig();
    HandleLateLoad();

    g_HudMessages = CreateHudSynchronizer();
}

static void HandleLateLoad()
{
    /**
     * NOTE / TODO: Lateloading is not properly supported.
     * It doesn't handle Event_PlayerSpawn so players will not get bonuses until the next round.
     * Some other things may behave incorrectly or be completely broken.
     *
     * Otherwise, it does *try* to make sure the plugin will work correctly on the next round.
     */

    if (!g_IsLateLoad)
        return;

    PrintToServer("[Ultra VIP] %T", "Late load warning", LANG_SERVER);

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

public void OnMapStart()
{
    g_RoundCount = INVALID_ROUND;
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
    // Service must always be null if none is owned
    g_ClientService[client] = FindClientService(client);

    SDKHook(client, SDKHook_OnTakeDamage, Hook_OnTakeDamage);

    ExtraJump_OnClientPostAdminCheck(client, g_ClientService[client]);
}

public void OnClientDisconnect(int client)
{
    Bonus_LeaveMessage(client);

    SDKUnhook(client, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
    ExtraJump_OnClientDisconect(client);

    g_ClientService[client] = null;

    WeaponMenu_ResetPreviousWeapons(client);
}

public Action Command_OnlineList(int client, int args)
{
    if (!g_UseOnlineList)
        return Plugin_Handled;
        
    if (!IsClientInGame(client) || IsFakeClient(client))
        return Plugin_Handled;

    ShowOnlineList(client);

    return Plugin_Handled;
}

#if defined DEBUG
public Action Command_EndRound(int client, int args)
{
    if (args != 1)
    {
        ReplyToCommand(client, "sm_endround <CT/T or anything else for draw>");
        return Plugin_Handled;
    }

    char arg1[3];
    GetCmdArg(1, arg1, sizeof(arg1));

    CSRoundEndReason reason = CSRoundEnd_Draw;
    if (StrEqual(arg1, "ct", false))
        reason = CSRoundEnd_CTWin;
    else if (StrEqual(arg1, "t", false))
        reason = CSRoundEnd_TerroristWin;

    CS_TerminateRound(5.0, reason);
    return Plugin_Handled;
}
#endif

public Action Command_ReloadServices(int client, int args)
{
    if(LoadConfig(false))
        CReplyToCommand(client, "%t", "Config Reloaded");
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

int IsRoundAllowed(int round)
{
    return g_RoundCount >= round;
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

    // Search using admin flags
    Service svc = FindHighestPriorityService(flags);
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

    // Search using overrides
    svc = FindServiceByOverrideAccess(client);

    return svc;
}

Service FindHighestPriorityService(int adminFlags)
{
    if (!adminFlags)
        return null;

    // TODO / BUG: Does not correctly support priority searching for services without flags
    // You'll probably need to change how they're stored and replace g_SortedServiceFlags
    // with just a sorted list of the service handles.

    // Find highest priority flag in param that matches a service
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
    Service svc;
    len = g_Services.Length;
    for (int i = 0; i < len; ++i)
    {
        svc = g_Services.Get(i);
        if (svc.Flag == foundFlag)
            return svc;
    }

    LogError("Somehow failed to find g_Services flag that was in g_SortedServiceFlags");
    return null;
}

Service FindServiceByOverrideAccess(int client)
{
    // TODO / BUG: Finding overrides ignores priority.

    Service svc;
    char buffer[64];
    int len = g_Services.Length;

    for (int i = 0; i < len; ++i)
    {
        svc = g_Services.Get(i);
        svc.GetOverride(buffer, sizeof(buffer));

        if (!buffer[0])
            continue;

        if (CheckCommandAccess(client, buffer, ADMFLAG_ROOT, false))
            return svc;
    }

    return null;
}

public void OnAllPluginsLoaded()
{
    if (LibraryExists("scp"))
    {
        g_ChatTagPlugin.processor = Processor_SCP;
        PrintToServer("[Ultra VIP] Successfuly loaded: %s", g_ChatTagPlugin.name);
    }
    else if (LibraryExists("chat-processor"))
    {
        g_ChatTagPlugin.processor = Processor_ChatProcessor;
        PrintToServer("[Ultra VIP] Successfuly loaded: %s", g_ChatTagPlugin.name);
    }
    else
    {
        g_ChatTagPlugin.processor = Processor_Null;
        PrintToServer("[Ultra VIP] Chat Processor not loaded");
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
