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

#pragma newdecls required
#pragma semicolon 1

#define PLUGIN_VERSION "0.1"

#define MAX_WEAPON_CLASSNAME_SIZE 24 // https://wiki.alliedmods.net/Counter-Strike:_Global_Offensive_Weapons
#define MAX_SERVICE_NAME_SIZE 64

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

Service g_ClientService[MAXPLAYERS +1];

public Plugin myinfo =
{
    name = "Ultra VIP",
    author = "Mesharsky",
    description = "Ultra VIP System that supports multimple services",
    version = PLUGIN_VERSION,
    url = "https://github.com/Mesharsky/Ultra-VIP"
};

public void OnPluginStart()
{
    g_Services = new ArrayList();
    g_SortedServiceFlags = new ArrayList();

    LoadTranslations("ultra_vip.phrases.txt");

    RegConsoleCmd("sm_vips", Command_ShowServices);
    RegConsoleCmd("sm_jumps", Command_ToggleJumps);

    RegAdminCmd("sm_reloadservices", Command_ReloadServices, ADMFLAG_ROOT, "Reloads configuration file");

    HookEvent("player_spawn", Event_PlayerSpawn);
    HookEvent("player_death", Event_PlayerDeath);
    HookEvent("bomb_planted", Event_BombPlanted);
    HookEvent("bomb_defused", Event_BombDefused);
    HookEvent("round_mvp", Event_RoundMvp);
    HookEvent("hostage_rescued", Event_HostageRescued);
    HookEvent("round_start", Event_RoundStart);
    HookEvent("weapon_fire", Event_WeaponFire);

    HookEvent("announce_phase_end", Event_TeamChange);
    HookEvent("cs_intermission", Event_TeamChange);
    HookEvent("player_connect_full", Event_PlayerConnectFull);

	//g_Cvar_ArenaMode = CreateConVar("arena_mode", "0", "Should arena mode (splewis) be enabled?\nRemeber that plugin will use arena configuration file instead if enabled");

    g_Cookie_PrevWeapons = new Cookie("ultra_vip_weapons", "Previously Selected Weapons", CookieAccess_Private);
    LoadConfig();
    HandleLateLoad();

    g_HudMessages = CreateHudSynchronizer();
}

static void HandleLateLoad()
{
#warning FIXME I dont know if we can, but we should also trigger any of the "OnSpawn" effect in HandleLateLoad

    // HOWEVER, we might risk breaking things if we just triggered the Event_PlayerSpawn
    // stuff manually, so it might be better to actually disable the whole plugin until
    // the next round, or not bother with that and just let it be not-fully-working

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
    g_RoundCount = 0;
}

public void OnClientCookiesCached(int client)
{
    if (IsFakeClient(client))
        return;

    GetPreviousWeapons(client);    
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

    ResetPreviousWeapons(client);
}

public Action Command_ShowServices(int client, int args)
{
	return Plugin_Handled;
}

public Action Command_ReloadServices(int client, int args)
{
#warning FIXME LoadConfig will leave some globals in an invalid state if it doesn't fail fatally.
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

int IsRoundAllowed(int round)
{
    return g_RoundCount >= round;
}

bool IsServiceHandleValid(Handle hndl)
{
    if (hndl == null)
        return false;
    return g_Services.FindValue(hndl) != -1;
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

    Service svc;

    // Find root service, if any
    int flags = GetUserFlagBits(client);

    if (flags & ADMFLAG_ROOT)
        flags |= g_RootServiceFlag;

    // Search using admin flags
    svc = FindHighestPriorityService(flags);
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

    // Find highest priority flag in param that matches a service
    int len = g_SortedServiceFlags.Length;
    int foundFlag;
    for (int i = 0; i < len; ++i)
    {
        int temp = g_SortedServiceFlags.Get(i);
        if (temp & adminFlags)
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

    if (g_ChatTagPlugin.processor == Processor_Null)
        PrintToServer("[Ultra VIP] Chat Processor not loaded");
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
    if (StrEqual(name, "scp") && StrEqual(name, "chat-processor"))
        g_ChatTagPlugin.processor = Processor_Null;   
}