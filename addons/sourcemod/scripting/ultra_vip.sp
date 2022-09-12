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

#pragma newdecls required
#pragma semicolon 1

#define PLUGIN_VERSION "0.1"

#define MAX_WEAPON_CLASSNAME_SIZE 24 // https://wiki.alliedmods.net/Counter-Strike:_Global_Offensive_Weapons

ArrayList g_Services;
ArrayList g_SortedServiceFlags;

ConVar g_Cvar_ArenaMode;

#include "ultra_vip/util.sp"
#include "ultra_vip/config.sp"
#include "ultra_vip/service.sp"
#include "ultra_vip/events.sp"
#include "ultra_vip/weaponmenu.sp"
#include "ultra_vip/menus.sp"

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
	LoadTranslations("ultra_vip.phrases.txt");

	RegConsoleCmd("sm_vips", Command_ShowServices);
	RegAdminCmd("sm_reloadservices", Command_ReloadServices, ADMFLAG_ROOT, "Reloads configuration file");

	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("bomb_planted", Event_BombPlanted);
	HookEvent("bomb_defused", Event_BombDefused);
	HookEvent("round_start", Event_RoundStart);

	g_Cvar_ArenaMode = CreateConVar("arena_mode", "0", "Should arena mode (splewis) be enabled?\nRemeber that plugin will use arena configuration file instead if enabled");

	LoadConfig();
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    CreateNative("UltraVIP_GetService", Native_GetService);
    CreateNative("UltraVIP_SetService", Native_SetService);

    RegPluginLibrary("ultra_vip");
    return APLRes_Success;
}

public void OnConfigsExecuted()
{
    
}

public void OnClientPutInServer(int client)
{

}

public Action Command_ShowServices(int client, int args)
{
	return Plugin_Handled;
}

public Action Command_ReloadServices(int client, int args)
{
	if(LoadConfig(false))
		CReplyToCommand(client, "Config has been reloaded");
	else
	{
		CReplyToCommand(client, "There is some problem with reloading config file. Check for error logs");
		SetFailState("Failed to reload configuration file");
	}

	return Plugin_Handled;	
}


bool IsServiceHandleValid(Handle hndl)
{
    if (hndl == null)
        return false;
    return g_Services.FindValue(hndl) != -1;
}
