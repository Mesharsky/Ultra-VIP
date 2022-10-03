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

    void Reset()
    {
        this.pluginName[0] = '\0';
        this.isOverridden = false;
        this.mode = Override_Optional;
    }
}


#if SOURCEMOD_V_MAJOR >= 1 && SOURCEMOD_V_MINOR >= 11
static_assert(view_as<int>(Feature_LAST_ITEM) == 310, "Feature was added to UVIPFeature without feature-override array being resized");
#endif
static FeatureOverrideInfo s_FeatureOverrides[20];


void Natives_OnPluginStart()
{
    delete g_ModuleSettings;
    g_ModuleSettings = new StringMap();
}

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

bool IsFeatureAvailable(UVIPFeature feature)
{
    return !s_FeatureOverrides[GetFeatureIndex(feature)].isOverridden;
}


public any Native_IsCoreCompatible(Handle plugin, int numParams)
{
    return GetNativeCell(1) == UVIP_API_VERSION;
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

    // Copy data
    strcopy(info.name, sizeof(ModuleSettingInfo::name), name);
    strcopy(info.defaultValue, sizeof(ModuleSettingInfo::defaultValue), defaultVal);
    info.type = GetNativeCell(3);
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
    return true;
}

static bool CanOverrideFeature(int featureIndex, const char[] pluginName)
{
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


#if SOURCEMOD_V_MAJOR >= 1 && SOURCEMOD_V_MINOR >= 11
static_assert(view_as<int>(SettingType_TOTAL) == 7, "SettingType was added without being handled in Get/GetInt/GetFloat/GetCell");
#endif


public any Native_UVIPService_Get(Handle plugin, int numParams)
{
    Service svc = GetNativeCell(1);
    if (svc == null)
        return ThrowNativeError(SP_ERROR_NATIVE, "Invalid UVIPService handle %x", svc);

    char settingName[MAX_SETTING_NAME_SIZE];
    GetNativeString(2, settingName, sizeof(settingName));
    NormaliseString(settingName);

    ModuleSettingInfo info;
    if (!g_ModuleSettings.GetArray(settingName, info, sizeof(info)))
        return ThrowNativeError(SP_ERROR_NATIVE, "\"%s\" is not a registered setting name.", settingName);

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
    char settingName[MAX_SETTING_NAME_SIZE];
    GetNativeString(2, settingName, sizeof(settingName));
    NormaliseString(settingName);

    ModuleSettingInfo info;
    if (!g_ModuleSettings.GetArray(settingName, info, sizeof(info)))
        return ThrowNativeError(SP_ERROR_NATIVE, "\"%s\" is not a registered setting name.", settingName);

    switch (info.type)
    {
        case Type_Byte, Type_UnsignedByte, Type_Integer, Type_Bool, Type_Hex:
        {
            return GetServiceCell(GetNativeCell(1), settingName);
        }
    }

    return ThrowNativeError(SP_ERROR_NATIVE, "Cannot use UVIPService.GetInt on non-integer setting \"%s\"", settingName);
}

public any Native_UVIPService_GetFloat(Handle plugin, int numParams)
{
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
    char settingName[MAX_SETTING_NAME_SIZE];
    GetNativeString(2, settingName, sizeof(settingName));
    NormaliseString(settingName);

    ModuleSettingInfo info;
    if (!g_ModuleSettings.GetArray(settingName, info, sizeof(info)))
        return ThrowNativeError(SP_ERROR_NATIVE, "\"%s\" is not a registered setting name.", settingName);

    switch (info.type)
    {
        case Type_Byte, Type_UnsignedByte, Type_Integer, Type_Bool, Type_Hex, Type_Float:
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


#if SOURCEMOD_V_MAJOR >= 1 && SOURCEMOD_V_MINOR >= 11
static_assert(view_as<int>(Feature_LAST_ITEM) == 310, "Feature was added to UVIPFeature without being handled in IsFeatureAvailable");
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
