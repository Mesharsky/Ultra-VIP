/**
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


#if defined _ultravip_included
    #endinput
#endif
#define _ultravip_included

#define UVIP_VERSION "1.0.0"
#define UVIP_API_VERSION 1

//--------------------------------------------------------------
// Constants
//--------------------------------------------------------------
enum SettingRequiredMode
{
    Setting_Optional = 0,   // Setting will use the default value if a service is has no configured value.
    Setting_Required        // An error will occur if the setting is missing from any service in the config.
}

enum FeatureOverrideMode
{
    Override_Optional = 0,  // The core feature will be re-enabled if the module plugin is unloaded.
    Override_Required       // The core feature cannot be re-enabled even if the module plugin is unloaded.
}

enum SettingType
{
    Type_String = 0,
    Type_Byte,
    Type_UnsignedByte,
    Type_Integer,
    Type_Bool,
    Type_Hex,
    Type_Float,

    // TODO: Vec2d/3d/4d + float variant
    // TODO: RGB Hex + RGBA Hex

    SettingType_TOTAL
}

/**
 * The core features in Ultra-VIP that can be overridden
 * with UVIP_OverrideFeature().
 */
enum UVIPFeature
{
    // Main Configuration
    Feature_ChatTag = 0,
    Feature_NameColor,
    Feature_MessageColor,
    Feature_ScoreboardTag,

    // Player Spawn Bonuses
    Feature_PlayerHP = 100,
    Feature_PlayerMaxHP,
    Feature_Armor,
    Feature_Helmet,
    Feature_Defuser,

    // Grenades On Spawn
    Feature_Grenades = 200,

    // Special Bonuses
    Feature_ExtraJumps = 300,
    Feature_Shield,
    Feature_Gravity,
    Feature_SpeedModifier,
    Feature_Visibility,
    Feature_RespawnChance,
    Feature_FallDamage,
    Feature_AttackDamage,
    Feature_DamageResist,
    Feature_UnlimitedAmmo,

    Feature_LAST_ITEM       // Internal use only. Similar to a TOTAL, but not the correct number.
}


//--------------------------------------------------------------
// UVIPService methodmap
// A methodmap the represents the service owned by a player.
//--------------------------------------------------------------
methodmap UVIPService < Handle
{
    public native void Get(const char[] settingName, char[] output, int size);

    public native int GetInt(const char[] settingName);

    public native int GetFloat(const char[] settingName);

    public native any GetCell(const char[] settingName);
}


//--------------------------------------------------------------
// Forwards
//--------------------------------------------------------------

// -- Must do RegisterSetting and OverrideFeature in here
// otherwise it will occur after LoadConfig, which is blocked.
forward void UVIP_OnStart();

// -- post config load
forward void UVIP_OnReady();

// --  Must be after service is actually applied to client
// Also called shortly after clients admin permissions change
forward void UVIP_OnClientPostAdminCheck(int client, UVIPService service);

// --  Must be just before service is removed from client
forward void UVIP_OnClientDisconnected(int client, UVIPService service);

// --  After the timer/checks on Event_PlayerSpawn
forward void UVIP_OnSpawn(int client, UVIPService service);

// --  OnSpawn but it guarantees a valid Service handle
forward void UVIP_OnSpawnWithService(int client, UVIPService service);


//--------------------------------------------------------------
// Natives
//--------------------------------------------------------------
stock void UVIP_CheckCoreCompatible()
{
    if (!_UVIP_IsCoreCompatible())
        SetFailState("This plugin is not compatible with the installed version of Ultra-VIP (Compiled for version: '%s', Required API version: %i).", UVIP_VERSION, UVIP_API_VERSION);
}

native bool _UVIP_IsCoreCompatible(int pluginVersion=UVIP_API_VERSION);

native void UVIP_RegisterSetting(
    const char[] name,
    const char[] defaultValue,
    SettingType type,
    SettingRequiredMode mode=Setting_Optional);

native bool UVIP_OverrideFeature(
    UVIPFeature feature,
    FeatureOverrideMode mode);

/**
 * Get the UVIPService owned by a client.
 * Returns null if client does not have a service.
 */
native UVIPService UVIP_GetClientService(int client);


/**
 * Do not edit below this.
 */
public SharedPlugin __pl_ultra_vip =
{
    name = "ultra_vip",
    file = "ultra_vip.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_ultra_vip_SetNTVOptional()
{
    MarkNativeAsOptional("_UVIP_IsCoreCompatible");
    MarkNativeAsOptional("UVIP_RegisterSetting");
    MarkNativeAsOptional("UVIP_OverrideFeature");
    MarkNativeAsOptional("UVIP_GetClientService");

    MarkNativeAsOptional("UVIPService.Get");
    MarkNativeAsOptional("UVIPService.GetInt");
    MarkNativeAsOptional("UVIPService.GetFloat");
    MarkNativeAsOptional("UVIPService.GetCell");
}
#endif