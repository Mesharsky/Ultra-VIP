/**
 * The file is a part of Ultra-VIP.
 *
 * Copyright (C) SirDigbot & Mesharsky
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

#pragma semicolon 1
#pragma newdecls required

enum struct ModuleSettingInfo
{
    SettingType type;
    SettingRequiredMode mode;
    char name[MAX_SETTING_NAME_SIZE];
    char defaultValue[MAX_SETTING_VALUE_SIZE];
}

enum struct FeatureOverrideInfo
{
    char pluginName[32];
    bool isOverridden;
    FeatureOverrideMode mode;

#if defined COMPILER_IS_OLDER_THAN_SM1_11
    Handle plugin;
#endif

    void Reset()
    {
        this.pluginName[0] = '\0';
        this.isOverridden = false;
        this.mode = Override_Optional;
    }
}


#if defined COMPILER_IS_SM1_11
static_assert(view_as<int>(Feature_LAST_ITEM) == 311, "Feature was added to UVIPFeature without s_FeatureOverrides array being resized");
#endif
static FeatureOverrideInfo s_FeatureOverrides[21];


void Natives_OnPluginStart()
{
    delete g_ModuleSettings;
    g_ModuleSettings = new StringMap();
}


#if defined COMPILER_IS_SM1_11
void Natives_OnPluginUnloaded(Handle plugin)
{
    char name[sizeof(FeatureOverrideInfo::pluginName)];
    GetPluginFilename(plugin, name, sizeof(name));

    // Reset all of the plugin's overrided features,
    // but only if they are Override_Optional
    for (int i = 0; i < sizeof(s_FeatureOverrides); ++i)
    {
        if (!StrEqual(name, s_FeatureOverrides[i].pluginName))
            continue;

        if (s_FeatureOverrides[i].mode == Override_Optional)
            s_FeatureOverrides[i].Reset();
    }
}
#elseif defined COMPILER_IS_OLDER_THAN_SM1_11
static void CleanAllUnusedOverrides()
{
    for (int i = 0; i < sizeof(s_FeatureOverrides); ++i)
    {
        if (!s_FeatureOverrides[i].isOverridden)
            continue;

        if (IsPluginLoaded(s_FeatureOverrides[i].plugin))
            continue;

        // Plugin unloaded on overriden feature, mimic Natives_OnPluginUnloaded
        if (s_FeatureOverrides[i].mode == Override_Optional)
            s_FeatureOverrides[i].Reset();
    }
}
#endif


bool IsFeatureAvailable(UVIPFeature feature)
{
    return !s_FeatureOverrides[GetFeatureIndex(feature)].isOverridden;
}


public any Native_IsCoreCompatible(Handle plugin, int numParams)
{
    return GetNativeCell(1) == UVIP_API_VERSION;
}

public any Native_HandleLateLoad(Handle plugin, int numParams)
{
    // Not a lateload
    if (!g_HaveAllPluginsLoaded)
        return 0;

    // If module doesn't have UVIP_OnStart it doesn't need us to handle
    // lateload (RegisterSetting/OverrideFeature not used).
    Function onStart = GetFunctionByName(plugin, "UVIP_OnStart");
    if (onStart == INVALID_FUNCTION)
        return 0;

    // Set g_HaveAllPluginsLoaded to false temporarily so that
    // RegisterSetting and Overridefeature can work.
    bool previousState = g_HaveAllPluginsLoaded;
    g_HaveAllPluginsLoaded = false;

    // Manually call the module's UVIP_OnStart
    Call_StartFunction(plugin, onStart);
    int err = Call_Finish();

    g_HaveAllPluginsLoaded = previousState;

    char pluginName[64];
    GetPluginFilename(plugin, pluginName, sizeof(pluginName));

    if (err != SP_ERROR_NONE)
    {
        LogError("Error %i occurred while calling UVIP_OnStart for plugin '%s'", err, pluginName);
        return 0;
    }

    // Reload the config so that the newly-registered settings/feature overrides
    // are set in the services
    if (!ReloadConfig(false, false))
        SetFailState("Late-loading module failed. An error occurred while reloading the config. Ultra-VIP has stopped.");

    // Manually call the module's UVIP_OnReady to tell it the config is done.
    Function onReady = GetFunctionByName(plugin, "UVIP_OnReady");
    if (onReady != INVALID_FUNCTION)
    {
        Call_StartFunction(plugin, onReady);
        err = Call_Finish();
        if (err != SP_ERROR_NONE)
            LogError("Error %i occurred while calling UVIP_OnReady for plugin '%s'", err, pluginName);
    }

    PrintToServer("[Ultra VIP] %t", "Module triggered reload", pluginName);
    CPrintToChatAll("%t", "Ultra VIP reloaded config");
    return 0;
}

public any Native_RegisterSetting(Handle plugin, int numParams)
{
    // The OnStart forward always happens before the config is processed, so we force
    // settings to be registered there for ease-of-use.
    if (!g_IsInOnStartForward)
        return ThrowNativeError(SP_ERROR_NATIVE, "You must register a setting inside of the UVIP_OnStart forward.");

    ModuleSettingInfo info;
    int written;

    // +1 to detect oversized values
    char name[MAX_SETTING_NAME_SIZE + 1];
    char defaultVal[MAX_SETTING_VALUE_SIZE + 1];

    // Get params
    GetNativeString(1, name, sizeof(name), written);
    if (written >= MAX_SETTING_NAME_SIZE)
        return ThrowNativeError(SP_ERROR_NATIVE, "Setting name must be less than %i characters", MAX_SETTING_NAME_SIZE);

    GetNativeString(2, defaultVal, sizeof(defaultVal), written);
    if (written >= MAX_SETTING_VALUE_SIZE)
        return ThrowNativeError(SP_ERROR_NATIVE, "Setting values must be less than %i characters", MAX_SETTING_VALUE_SIZE);

    // Verify setting name
    NormaliseString(name);

    if (!IsSettingNameAllowed(name))
        return ThrowNativeError(SP_ERROR_NATIVE, "Setting names cannot be empty or start with \"%c\"", SERVICE_INTERNAL_PREFIX);

    // Verify setting default value (required by modulecfg.sp)
    SettingType type = GetNativeCell(3);
    char error[256];
    if (!DoesSettingTypeMatch(type, defaultVal, error, sizeof(error)))
        return ThrowNativeError(SP_ERROR_NATIVE, "Default value does not match type: %s", error);

    // Copy data
    strcopy(info.name, sizeof(ModuleSettingInfo::name), name);
    strcopy(info.defaultValue, sizeof(ModuleSettingInfo::defaultValue), defaultVal);
    info.type = type;
    info.mode = GetNativeCell(4);

    // Store setting (false = Check for duplicates)
    if (!g_ModuleSettings.SetArray(info.name, info, sizeof(info), false))
        return ThrowNativeError(SP_ERROR_NATIVE, "Another plugin is already using the setting name \"%s\"", info.name);

    return 0;
}

public any Native_OverrideFeature(Handle plugin, int numParams)
{
    // This check here isn't really necessary here but it enforces good module design
    if (!g_IsInOnStartForward)
        return ThrowNativeError(SP_ERROR_NATIVE, "You must override a feature inside of the UVIP_OnStart forward.");

    UVIPFeature feature = GetNativeCell(1);

    int index = GetFeatureIndex(feature);
    if (index == -1)
        ThrowNativeError(SP_ERROR_NATIVE, "UVIPFeature value %i is invalid", feature);

    char pluginName[sizeof(FeatureOverrideInfo::pluginName)];
    GetPluginFilename(plugin, pluginName, sizeof(pluginName));

    if (!CanOverrideFeature(index, pluginName))
        return false;

    s_FeatureOverrides[index].pluginName = pluginName;
    s_FeatureOverrides[index].isOverridden = true;
    s_FeatureOverrides[index].mode = GetNativeCell(2);

#if defined COMPILER_IS_OLDER_THAN_SM1_11
    s_FeatureOverrides[index].plugin = plugin;
#endif

    return true;
}

static bool CanOverrideFeature(int featureIndex, const char[] pluginName)
{
    // < 1.11 only: Clear all unloaded overrides in case module plugins
    // were unloaded.
    // 1.11+ handles this automatically.
#if defined COMPILER_IS_OLDER_THAN_SM1_11
    CleanAllUnusedOverrides();
#endif

    if (!s_FeatureOverrides[featureIndex].isOverridden)
        return true;

    if (!StrEqual(pluginName, s_FeatureOverrides[featureIndex].pluginName))
        return false;

    // Allow re-overriding both optional and required features
    // This would let you replace a Override_Required with an Override_Optional
    return true;
}

public any Native_GetClientService(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    if (client < 1 || client > MaxClients)
        return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %i", client);
    return g_ClientService[client];
}


#if defined COMPILER_IS_SM1_11
static_assert(view_as<int>(SettingType_TOTAL) == 9, "SettingType was added without being handled in Get/GetInt/GetFloat/GetCell");
#endif


public any Native_UVIPService_Get(Handle plugin, int numParams)
{
    if (!g_HaveAllPluginsLoaded)
        return ThrowNativeError(SP_ERROR_NATIVE, "Cannot use UVIPService.Get until after OnAllPluginsLoaded");

    Service svc = GetNativeCell(1);
    if (svc == null)
        return ThrowNativeError(SP_ERROR_NATIVE, "Invalid UVIPService handle %x", svc);

    char settingName[MAX_SETTING_NAME_SIZE];
    GetNativeString(2, settingName, sizeof(settingName));
    NormaliseString(settingName);

    ModuleSettingInfo info;
    if (!g_ModuleSettings.GetArray(settingName, info, sizeof(info)))
        return ThrowNativeError(SP_ERROR_NATIVE, "\"%s\" is not a registered setting name.", settingName);

    // Even though values are always set with a string, they can be stored as cell
    if (info.type != Type_String)
        return ThrowNativeError(SP_ERROR_NATIVE, "Cannot use UVIPService.Get on non-string setting \"%s\"", settingName);

    char value[MAX_SETTING_VALUE_SIZE];
    if (!svc.GetString(settingName, value, sizeof(value)))
        return ThrowNativeError(SP_ERROR_NATIVE, "Failed to get value for setting \"%s\"", settingName);

    SetNativeString(3, value, GetNativeCell(4));
    return 0;
}

public any Native_UVIPService_GetInt(Handle plugin, int numParams)
{
    if (!g_HaveAllPluginsLoaded)
        return ThrowNativeError(SP_ERROR_NATIVE, "Cannot use UVIPService.GetInt until after OnAllPluginsLoaded");

    char settingName[MAX_SETTING_NAME_SIZE];
    GetNativeString(2, settingName, sizeof(settingName));
    NormaliseString(settingName);

    ModuleSettingInfo info;
    if (!g_ModuleSettings.GetArray(settingName, info, sizeof(info)))
        return ThrowNativeError(SP_ERROR_NATIVE, "\"%s\" is not a registered setting name.", settingName);

    switch (info.type)
    {
        case Type_Byte, Type_UnsignedByte, Type_Integer, Type_Bool, Type_Hex,
            Type_RGBHex, Type_RGBAHex:
        {
            return GetServiceCell(GetNativeCell(1), settingName);
        }
    }

    return ThrowNativeError(SP_ERROR_NATIVE, "Cannot use UVIPService.GetInt on non-integer setting \"%s\"", settingName);
}

public any Native_UVIPService_GetFloat(Handle plugin, int numParams)
{
    if (!g_HaveAllPluginsLoaded)
        return ThrowNativeError(SP_ERROR_NATIVE, "Cannot use UVIPService.GetFloat until after OnAllPluginsLoaded");

    char settingName[MAX_SETTING_NAME_SIZE];
    GetNativeString(2, settingName, sizeof(settingName));
    NormaliseString(settingName);

    ModuleSettingInfo info;
    if (!g_ModuleSettings.GetArray(settingName, info, sizeof(info)))
        return ThrowNativeError(SP_ERROR_NATIVE, "\"%s\" is not a registered setting name.", settingName);

    if (info.type != Type_Float)
        return ThrowNativeError(SP_ERROR_NATIVE, "Cannot use UVIPService.GetFloat on non-float setting \"%s\"", settingName);

    return GetServiceCell(GetNativeCell(1), settingName);
}

public any Native_UVIPService_GetCell(Handle plugin, int numParams)
{
    if (!g_HaveAllPluginsLoaded)
        return ThrowNativeError(SP_ERROR_NATIVE, "Cannot use UVIPService.GetCell until after OnAllPluginsLoaded");

    char settingName[MAX_SETTING_NAME_SIZE];
    GetNativeString(2, settingName, sizeof(settingName));
    NormaliseString(settingName);

    ModuleSettingInfo info;
    if (!g_ModuleSettings.GetArray(settingName, info, sizeof(info)))
        return ThrowNativeError(SP_ERROR_NATIVE, "\"%s\" is not a registered setting name.", settingName);

    switch (info.type)
    {
        case Type_Byte, Type_UnsignedByte, Type_Integer, Type_Bool, Type_Hex,
            Type_Float, Type_RGBHex, Type_RGBAHex:
        {
            return GetServiceCell(GetNativeCell(1), settingName);
        }
    }

    return ThrowNativeError(SP_ERROR_NATIVE, "Cannot use UVIPService.GetCell on non-cell setting \"%s\"", settingName);
}


static any GetServiceCell(Service svc, const char[] settingName)
{
    if (svc == null)
        return ThrowNativeError(SP_ERROR_NATIVE, "Invalid UVIPService handle %x", svc);

    any value;
    if (!svc.GetValue(settingName, value))
        return ThrowNativeError(SP_ERROR_NATIVE, "Failed to get value for setting \"%s\"", settingName);

    return value;
}


#if defined COMPILER_IS_SM1_11
static_assert(view_as<int>(Feature_LAST_ITEM) == 311, "Feature was added to UVIPFeature without being handled in IsFeatureAvailable/GetFeatureIndex");
#endif
static int GetFeatureIndex(UVIPFeature feature)
{
    if (feature >= Feature_LAST_ITEM)
        ThrowError("Feature_LAST_ITEM is not a valid feature");

    // HACKY SHIT!
    if (feature < Feature_PlayerHP)
        return view_as<int>(feature);
    if (feature < Feature_Grenades)
        return view_as<int>(feature) - (view_as<int>(Feature_PlayerHP) - 4); // Remove first 4 indexes
    if (feature < Feature_ExtraJumps)
        return view_as<int>(feature) - (view_as<int>(Feature_Grenades) - 9); // Remove first 9 indexes
    if (feature < Feature_LAST_ITEM)
        return view_as<int>(feature) - (view_as<int>(Feature_ExtraJumps) - 10); // Remove first 10 indexes

    return -1;
}

bool IsSettingNameAllowed(const char[] name)
{
    if (!name[0] || name[0] == SERVICE_INTERNAL_PREFIX)
        return false;

    for (int i = 0; name[i] != '\0'; ++i)
    {
        // Block Control Chars, they're used internally by modulecfg.sp
        if (name[i] < 32)
            return false;
    }
    return true;
}


#if defined COMPILER_IS_SM1_11
static_assert(view_as<int>(SettingType_TOTAL) == 9, "SettingType was added without being handled in DoesSettingTypeMatch");
#endif
bool DoesSettingTypeMatch(SettingType type, const char[] value, char[] error, int errSize)
{
    any result;
    error[0] = '\0';

    switch (type)
    {
        case Type_String:
        {
            return true;
        }
        case Type_Byte:
        {
            if (!SettingType_Byte(value, result))
            {
                FormatEx(error, errSize, "Value '%s' is not a valid byte (-128 to 127).", value);
                return false;
            }
        }
        case Type_UnsignedByte:
        {
            if (!SettingType_UnsignedByte(value, result))
            {
                FormatEx(error, errSize, "Value '%s' is not a valid unsigned byte (0 to 255).", value);
                return false;
            }
        }
        case Type_Integer:
        {
            if (!SettingType_Integer(value, result))
            {
                FormatEx(error, errSize, "Value '%s' is not a valid integer.", value);
                return false;
            }
        }
        case Type_Bool:
        {
            if (!SettingType_Bool(value, result))
            {
                FormatEx(error, errSize, "Value '%s' is not a valid boolean (true/false/0/1).", value);
                return false;
            }
        }
        case Type_Hex:
        {
            if (!SettingType_Hex(value, result))
            {
                FormatEx(error, errSize, "Value '%s' is not a valid hexadecimal value (Chars must be 0 to 9, A to F).", value);
                return false;
            }
        }
        case Type_Float:
        {
            if (!SettingType_Float(value, result))
            {
                FormatEx(error, errSize, "Value '%s' is not a valid float value (e.g. \"3.1415\").", value);
                return false;
            }
        }
        case Type_RGBHex:
        {
            if (!SettingType_RGBHex(value, result))
            {
                FormatEx(error, errSize, "Value '%s' is not an RGB hexadecimal color. Must be 6 characters (0 to 9, A to F). e.g. 0099FF or #0099FF)", value);
                return false;
            }
        }
        case Type_RGBAHex:
        {
            if (!SettingType_RGBAHex(value, result))
            {
                FormatEx(error, errSize, "Value '%s' is not an RGBA hexadecimal color. Must be 8 characters (0 to 9, A to F). e.g. 0055AAFF or #0055AAFF)", value);
                return false;
            }
        }

        default:
        {
            ThrowError("Unknown SettingType %i", type);
        }
    }

    return true;
}


bool SettingType_Byte(const char[] value, int &result)
{
    int temp;
    bool success = StringToIntStrict(value, temp);

    if (success && temp >= -128 && temp <= 127)
    {
        result = temp;
        return true;
    }

    return false;
}

bool SettingType_UnsignedByte(const char[] value, int &result)
{
    int temp;
    bool success = StringToIntStrict(value, temp);

    if (success && temp >= 0 && temp <= 255)
    {
        result = temp;
        return true;
    }

    return false;
}

bool SettingType_Integer(const char[] value, int &result)
{
    return StringToIntStrict(value, result);
}

bool SettingType_Bool(const char[] value, bool &result)
{
    if (StrEqual(value, "true", false) || StrEqual(value, "1"))
    {
        result = true;
        return true;
    }
    if (StrEqual(value, "false", false) || StrEqual(value, "0"))
    {
        result = false;
        return true;
    }

    return false;
}

bool SettingType_Hex(const char[] value, int &result)
{
    return StringToIntStrict(value, result, 16);
}

bool SettingType_Float(const char[] value, float &result)
{
    return StringToFloatStrict(value, result);
}

bool SettingType_RGBHex(const char[] value, int &result)
{
    // 0099FF or #0099FF
    int len = strlen(value);
    if (len < 6)
        return false;

    bool hasHash = value[0] == '#';
    if (len != 6 && (len != 7 && hasHash))
        return false;

    if (hasHash)
        return StringToIntStrict(value[1], result, 16);
    return StringToIntStrict(value, result, 16);
}

bool SettingType_RGBAHex(const char[] value, int &result)
{
    // 005599FF or #005599FF
    int len = strlen(value);
    if (len < 8)
        return false;

    bool hasHash = value[0] == '#';
    if (len != 8 && (len != 9 && hasHash))
        return false;

    if (hasHash)
        return StringToIntStrict(value[1], result, 16);
    return StringToIntStrict(value, result, 16);
}
