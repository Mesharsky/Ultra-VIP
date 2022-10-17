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


#if defined _ultravip_included
    #endinput
#endif
#define _ultravip_included

#define UVIP_VERSION "1.0.0"
#define UVIP_API_VERSION 1

//--------------------------------------------------------------
// Constants
//--------------------------------------------------------------

/**
 * Data types supported by UVIP_RegisterSetting().
 */
enum SettingType
{
    Type_String = 0,    // Text (or custom type).

    Type_Byte,          // Integer between -128 and 127 (inclusive).
    Type_UnsignedByte,  // Integer between 0 and 255 (inclusive).
    Type_Integer,       // Integer between -2147483648 and 2147483647 (inclusive).
    Type_Bool,          // Integer 1 or 0, or "True" or "False" (Case-insensitive).
    Type_Hex,           // Type_Integer but using hexadecimal digits (0-9, A-F). Case-insensitive.

    Type_Float,         // Number with a decimal point.

    Type_RGBHex,        // Type_Hex that must be 6 characters long, with optional # prefix (e.g. 00AAFF or #00AAFF).
    Type_RGBAHex,       // Type_Hex that must be 8 characters long, with optional # prefix (e.g. 0055AAFF or #0055AAFF).

    SettingType_TOTAL   // Internal use only.
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
    Feature_NoRecoil,

    Feature_LAST_ITEM       // Internal use only. Similar to a TOTAL, but value wrong/offset.
}


/**
 * Whether not a setting (UVIP_RegisterSetting) is required to be in the config
 * for each service.
 */
enum SettingRequiredMode
{
    Setting_Optional = 0,   // Setting will use the default value if a service is has no configured value.
    Setting_Required        // An error will occur if the setting is missing from any service in the config.
}


/**
 * Whether or not an overrided core feature (UVIP_OverrideFeature) must stay
 * overridden if the module is unloaded.
 */
enum FeatureOverrideMode
{
    Override_Optional = 0,  // The core feature will be re-enabled if the module plugin is unloaded.
    Override_Required       // The core feature cannot be re-enabled even if the module plugin is unloaded.
}


//--------------------------------------------------------------
// UVIPService methodmap
// A methodmap the represents the service owned by a player.
// Used for getting the values of settings made with UVIP_RegisterSetting().
//--------------------------------------------------------------
methodmap UVIPService < Handle
{
    /**
     * Get the value of a Type_String setting.
     *
     * @param settingName       Name of the setting.
     * @param output            Output buffer.
     * @param size              Max size of output buffer.
     *
     * @error   OnAllPluginsLoaded not called, Invalid UVIPService,
     *          Setting does not exist or is not a Type_String.
     */
    public native void Get(const char[] settingName, char[] output, int size);

    /**
     * Get the value of any integer or Type_Bool setting.
     *
     * @param settingName       Name of the setting.
     * @param output            Output buffer.
     * @param size              Max size of output buffer.
     *
     * @return                  Integer value.
     *
     * @error   OnAllPluginsLoaded not called, Invalid UVIPService,
     *          Setting does not exist or is not an integer.
     */
    public native int GetInt(const char[] settingName);

    /**
     * Get the value of a Type_Float setting.
     *
     * @param settingName       Name of the setting.
     * @param output            Output buffer.
     * @param size              Max size of output buffer.
     *
     * @return                  Float value.
     *
     * @error   OnAllPluginsLoaded not called, Invalid UVIPService,
     *          Setting does not exist or is not a float.
     */
    public native int GetFloat(const char[] settingName);

    /**
     * Get the value of any non-string setting (integer/float/bool).
     *
     * @param settingName       Name of the setting.
     * @param output            Output buffer.
     * @param size              Max size of output buffer.
     *
     * @return                  32-bit cell (any) value.
     *
     * @error   OnAllPluginsLoaded not called, Invalid UVIPService,
     *          Setting does not exist or is not a cell type.
     */
    public native any GetCell(const char[] settingName);
}


//--------------------------------------------------------------
// Forwards
//--------------------------------------------------------------

/**
 * Called when Ultra-VIP is starting.
 *
 * This is the only place you can call UVIP_RegisterSetting or
 * UVIP_OverrideFeature.
 *
 * If the plugin is late-loaded this will be called automatically
 * as long as UVIP_SetupModule is used in OnPluginStart().
 */
forward void UVIP_OnStart();

/**
 * Called after the Ultra-VIP config has been processed, after UVIP_OnStart().
 *
 * It is not safe to use any settings created by UVIP_RegisterSetting until
 * after this forward is called.
 *
 * If the plugin is late-loaded this will be called automatically
 * as long as UVIP_SetupModule is used in OnPluginStart().
 */
forward void UVIP_OnReady();

/**
 * OnClientPostAdminCheck after client is checked for a service.
 *
 * @param client        Client index.
 * @param service       Client service, or null if none.
 */
forward void UVIP_OnClientPostAdminCheck(int client, UVIPService service);

/**
 * OnClientDisconnect before service (if any) is removed from client.
 *
 * @param client        Client index.
 * @param service       Client service, or null if none.
 */
forward void UVIP_OnClientDisconnect(int client, UVIPService service);

/**
 * Called after a client spawns (spectators excluded).
 *
 * This occurs after the player_spawn event so that the client can be
 * interacted with.
 *
 * @param client        Client index.
 * @param service       Client service, or null if none.
 */
forward void UVIP_OnSpawn(int client, UVIPService service);

/**
 * Same as UVIP_OnSpawn but only called if a client has a valid
 * (non-null) service.
 *
 * @param client        Client index.
 * @param service       Client service.
 */
forward void UVIP_OnSpawnWithService(int client, UVIPService service);


//--------------------------------------------------------------
// Natives
//--------------------------------------------------------------

/**
 * Prepare an Ultra-VIP module.
 *
 * This should be called in OnPluginStart() before any other Ultra-VIP code
 * is used.
 */
stock void UVIP_SetupModule()
{
    if (!_UVIP_IsCoreCompatible())
        SetFailState("This plugin is not compatible with the installed version of Ultra-VIP (Compiled for version: '%s', Required API version: %i).", UVIP_VERSION, UVIP_API_VERSION);

    _UVIP_HandleLateLoad();
}


/**
 * Create a new setting for every Ultra-VIP service.
 *
 * Settings are named values that can be configured in the ultra_vip_modules.cfg
 * file with a different value for each service.
 *
 * To get the value of a setting (for a particular service) use the UVIPService
 * methodmap.
 * The UVIP forwards and UVIP_GetClientService can be used for that.
 *
 * @param name          Name of the setting (case insensitive).
 * @param defaultValue  Value to use if setting is not set for a service.
 * @param type          Data type of the setting.
 * @param mode          Does the setting need to be set for every service.
 * @param error         Output buffer for error message (if any).
 * @param errorSize     Size of error output buffer.
 *
 * @return  True if setting was registered, false otherwise.
 *          Registering a setting can fail if:
 *          this wasn't called inside UVIP_OnStart(),
 *          the setting name/value is too long or not allowed,
 *          the default value doesn't match the type,
 *          or the setting already registered to another plugin.
 */
native bool UVIP_RegisterSetting(
    const char[] name,
    const char[] defaultValue,
    SettingType type,
    SettingRequiredMode mode=Setting_Optional,
    char[] error=NULL_STRING,
    int errorSize=-1);


/**
 * Disabled (override) a core feature of Ultra-VIP.
 *
 * This is used if your module plugin intends to replace the feature with
 * its own version.
 *
 * e.g. You might override Feature_ScoreboardTag so your module can implement
 *      an animated scoreboard tag instead.
 *
 * @param feature       Feature being overridden/disabled.
 * @param mode          Whether or not the feature should be re-enabled if the
 *                      module plugin that disabled it is unloaded.
 *
 * @return              True if feature was successfully overridden.
 *                      False if the feature is already overridden by another
 *                      plugin.
 *
 * @error               Not called inside UVIP_OnStart().
 */
native bool UVIP_OverrideFeature(
    UVIPFeature feature,
    FeatureOverrideMode mode);

/**
 * Get the UVIPService owned by a client.
 * Returns null if client does not have a service.
 *
 * @param client    Client index.
 * @return          The client's UVIPService or null if they have none.
 */
native UVIPService UVIP_GetClientService(int client);


/**
 * Do not use. Internal use only.
 */
native bool _UVIP_IsCoreCompatible(int pluginVersion=UVIP_API_VERSION);

/**
 * Do not use. Internal use only.
 */
native bool _UVIP_HandleLateLoad();


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
    MarkNativeAsOptional("_UVIP_HandleLateLoad");

    MarkNativeAsOptional("UVIP_RegisterSetting");
    MarkNativeAsOptional("UVIP_OverrideFeature");
    MarkNativeAsOptional("UVIP_GetClientService");

    MarkNativeAsOptional("UVIPService.Get");
    MarkNativeAsOptional("UVIPService.GetInt");
    MarkNativeAsOptional("UVIPService.GetFloat");
    MarkNativeAsOptional("UVIPService.GetCell");
}
#endif
