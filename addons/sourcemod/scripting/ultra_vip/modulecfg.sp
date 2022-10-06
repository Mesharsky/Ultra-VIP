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

#pragma newdecls required
#pragma semicolon 1


// All module settings per service. (Key is "SERVICENAME_some_setting_name")
static StringMap s_Settings;

// All of the required settings per service. (Key is "SERVICENAME_some_setting_name")
static StringMap s_RequiredSettings;

// The SettingType for each unique setting name
// *NOT* stored per-service (Key is "some_setting_name").
static StringMap s_SettingTypes;


static int s_ParseDepth;
static bool s_IsParsingValidService;
static char s_ParsingServiceName[MAX_SERVICE_NAME_SIZE];

#define _MODULE_SETTING_SIZE (MAX_SETTING_NAME_SIZE + MAX_SERVICE_NAME_SIZE + 1)


/**
 * Must be called after g_Services has been populated by LoadConfig
 */
bool LoadModuleConfig(bool fatalError)
{
    Cleanup();

    s_Settings = new StringMap();
    s_RequiredSettings = new StringMap();
    s_SettingTypes = new StringMap();

    if (!LoadDefaultSettingValues()
        || !ParseModuleConfig(fatalError)
        || !CheckRequiredSettings()
        || !ApplySettingsToServices())
    {
        Cleanup();

        if (fatalError)
            SetFailState("An error occurred while processing ultra_vip_modules.cfg. See error logs for details.");
        // No need for else since other funcs already LogError

        return false;
    }

    Cleanup();

    return true;
}

static void Cleanup()
{
    delete s_Settings;
    delete s_RequiredSettings;
    delete s_SettingTypes;
}

static bool LoadDefaultSettingValues()
{
    int serviceCount = g_Services.Length;
    char svcName[MAX_SERVICE_NAME_SIZE];

    char key[MAX_SETTING_NAME_SIZE];
    StringMapSnapshot snap = g_ModuleSettings.Snapshot();
    ModuleSettingInfo info;
    int settingCount = snap.Length;

    // For each service
    for (int i = 0; i < serviceCount; ++i)
    {
        Service svc = g_Services.Get(i);
        svc.GetName(svcName, sizeof(svcName));

        NormaliseString(svcName);

        // For each setting
        for (int j = 0; j < settingCount; ++j)
        {
            // Add setting to s_Settings
            // Using SetSettings for Key = "SERVICENAME_some_setting_name"
            // Keys are already normalised before here.
            snap.GetKey(j, key, sizeof(key));
            g_ModuleSettings.GetArray(key, info, sizeof(info));

            SetSetting(s_Settings, svcName, key, info.defaultValue);

            // If setting is Setting_Required, also add it to the s_RequiredSettings
            // with the same per-service key used for s_Settings
            if (info.mode == Setting_Required)
                SetSetting(s_RequiredSettings, svcName, key, "");

            // Store the setting type (*not* stored per service, but settings
            // may exist for one service but not others)
            s_SettingTypes.SetValue(key, info.type);
        }
    }

    delete snap;
    return true;
}


static bool ParseModuleConfig(bool fatalError)
{
    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), "configs/ultra_vip_modules.cfg");

    s_ParseDepth = 0;
    ResetSectionParsingState();

    SMCParser p = new SMCParser();
    p.OnEnterSection = ModuleConfig_EnterSection;
    p.OnLeaveSection = ModuleConfig_LeaveSection;
    p.OnKeyValue = ModuleConfig_KeyValue;

    SMCError res = p.ParseFile(path);
    if (res != SMCError_Okay)
    {
        char error[256];
        p.GetErrorString(res, error, sizeof(error));
        delete p;

        if (fatalError)
            SetFailState("Failed to parse Ultra-VIP modules config. Error: %s", error);
        else
            LogError("Failed to parse Ultra-VIP modules config. Error: %s", error);

        return false;
    }

    delete p;
    return true;
}


static void ResetSectionParsingState()
{
    // Only the state for the current section
    s_IsParsingValidService = false;
    s_ParsingServiceName[0] = '\0';
}

static SMCResult ModuleConfig_EnterSection(
    SMCParser smc,
    const char[] name,
    bool opt_quotes)
{
    ++s_ParseDepth;

    // If top level section, treat as service name
    // Root node counts as depth 1
    if (s_ParseDepth == 2)
    {
        // Find by name (case-insensitive)
        s_IsParsingValidService = FindServiceByName(name, false) != null;

        strcopy(s_ParsingServiceName, sizeof(s_ParsingServiceName), name);
        NormaliseString(s_ParsingServiceName);
    }

    return SMCParse_Continue;
}

static SMCResult ModuleConfig_LeaveSection(SMCParser smc)
{
    --s_ParseDepth;

    // Depth 1 = root node (left top level section/service name)
    if (s_ParseDepth == 1)
        ResetSectionParsingState();

    return SMCParse_Continue;
}

static SMCResult ModuleConfig_KeyValue(
    SMCParser smc,
    const char[] key,
    const char[] value,
    bool key_quotes,
    bool value_quotes)
{
    if (!s_IsParsingValidService)
        return SMCParse_Continue;

    char normalised[MAX_SETTING_NAME_SIZE];
    strcopy(normalised, sizeof(normalised), key);
    NormaliseString(normalised);

    // If setting key has no known type it's not a valid setting; Skip it.
    SettingType type;
    if (!s_SettingTypes.GetValue(normalised, type))
        return SMCParse_Continue;

    char error[256];
    if (!DoesSettingTypeMatch(type, value, error, sizeof(error)))
        LogError("Module setting error for \"%s\" (\"%s\"): %s", key, s_ParsingServiceName, error);
    else
    {
        // Update/replace the default value in s_Settings
        SetSetting(s_Settings, s_ParsingServiceName, normalised, value);
    }

    // Remove the setting from s_RequiredSettings since it exists in the config
    // Even if we use a default value because the config's value type mismatched.
    // This is fine because Native_RegisterSetting forces default values to be be valid.
    RemoveSetting(s_RequiredSettings, s_ParsingServiceName, normalised);

    return SMCParse_Continue;
}


static bool CheckRequiredSettings()
{
    StringMapSnapshot snap = s_RequiredSettings.Snapshot();
    int len = snap.Length;
    if (len == 0)
    {
        delete snap;
        return true;
    }

    char buffer[_MODULE_SETTING_SIZE];
    char svcName[MAX_SERVICE_NAME_SIZE];

    for (int i = 0; i < len; ++i)
    {
        snap.GetKey(i, buffer, sizeof(buffer));
        int settingNameStart = SplitString(buffer, "\x01", svcName, sizeof(svcName));
        if (settingNameStart == -1)
        {
            LogError("Internal s_RequiredSetting name is somehow missing separator '\\x01' \"%s\"", buffer);
            continue;
        }

        LogError("Ultra-VIP service \"%s\" is missing required setting \"%s\" in ultra_vip_modules.cfg", svcName, buffer[settingNameStart]);
    }

    delete snap;
    return false;
}


static bool ApplySettingsToServices()
{
    StringMapSnapshot snap = s_Settings.Snapshot();
    int len = snap.Length;

    char buffer[_MODULE_SETTING_SIZE];
    char svcName[MAX_SERVICE_NAME_SIZE];
    char value[MAX_SETTING_VALUE_SIZE];

    // For each setting (which is stored with a per-service prefix)
    for (int i = 0; i < len; ++i)
    {
        // Get the service the setting is for
        snap.GetKey(i, buffer, sizeof(buffer));
        int settingNameStart = SplitString(buffer, "\x01", svcName, sizeof(svcName));

        if (settingNameStart == -1)
        {
            LogError("Internal s_RequiredSetting name is somehow missing separator '\\x01' \"%s\"", buffer);
            continue;
        }

        Service svc = FindServiceByName(svcName, false);
        if (svc == null)
        {
            LogError("Internal s_RequiredSetting service name \"%s\" somehow refers to an unknown service", svcName);
            continue;
        }

        // Get setting type
        SettingType type;
        if (!s_SettingTypes.GetValue(buffer[settingNameStart], type))
        {
            LogError("bruh");
            continue;
        }

        // Get setting value
        if (!s_Settings.GetString(buffer, value, sizeof(value)))
        {
            LogError("bruh 2");
            continue;
        }

        // Add setting into the Service
        Service_AddModuleSetting(svc, type, buffer[settingNameStart], value);
    }

    delete snap;
    return true;
}


static void SetSetting(StringMap map, const char[] serviceName, const char[] settingName, const char[] value)
{
    // IsSettingNameAllowed guarantees control chars are not used
    char key[_MODULE_SETTING_SIZE];
    FormatEx(key, sizeof(key), "%s\x01%s", serviceName, settingName);

    map.SetString(key, value);
}

static void RemoveSetting(StringMap map, const char[] serviceName, const char[] settingName)
{
    char key[_MODULE_SETTING_SIZE];
    FormatEx(key, sizeof(key), "%s\x01%s", serviceName, settingName);

    map.Remove(key);
}
