/**
 * The file is a part of Ultra-VIP.
 *
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

#pragma newdecls required
#pragma semicolon 1

#include "modulecfg.sp"

enum RootServiceMode
{
    Mode_None = 0,      // Root does not get a service.
    Mode_Auto,          // Root gets the highest priority service.
    Mode_Specified      // Root gets a specific service.
}

bool g_FixRequiredCvars;
bool g_FixGrenadeLimits;
char g_ChatTag[64];
bool g_UseOnlineList;
bool g_UseBonusesList;
StringMap g_OnlineListCommands;
StringMap g_BonusesListCommands;
bool g_IsDeathmatchMode;
bool g_BotsGrantBonuses;

Service g_RootService;
RootServiceMode g_RootServiceMode;
StringMap g_SteamIDServices;    // Maps SteamID2 to Service handle (g_Services)

static int s_UsedServiceFlags;
static StringMap s_UsedServiceOverrides;
static bool s_IsInheritOnlyPass;

#define CONFIG_PATH "configs/ultra_vip_main.cfg"
#define ONLINE_CMD_SEPARATOR ";"
#define ONLINE_CMD_STRING_MAXLENGTH 512

// Struct used purely for sorting purposes in BuildSortedLists()
enum struct ServicePriorityData
{
    int flag;
    int priority;
    char override[MAX_SERVICE_OVERRIDE_SIZE];
}

static void ResetAllServices()
{
    g_SortedServiceFlags.Clear();
    g_SortedServiceOverrides.Clear();
    s_UsedServiceFlags = 0;
    delete s_UsedServiceOverrides;

    delete g_SteamIDServices;
    g_SteamIDServices = new StringMap();

    int len = g_Services.Length;
    for(int i = 0; i < len; ++i)
    {
        Service svc = g_Services.Get(i);
        Service_Delete(svc);
    }

    g_Services.Clear();

    ResetAllClientServices();
}

bool Config_Load(bool fatalError = true)
{
    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), CONFIG_PATH);

    KeyValues kv = new KeyValues("UltraVIP - Configuration");
    if (!kv.ImportFromFile(path))
        return HandleError(kv, fatalError, "Cannot find config file: %s", path);

    ResetAllServices();

    s_UsedServiceOverrides = new StringMap();

    if (!kv.JumpToKey("Services"))
        return HandleError(kv, fatalError, "Missing \"Services\" section in config file.");

    if (!kv.GotoFirstSubKey())
        return HandleError(kv, fatalError, "There are no valid services in the config.");

    // Add first service to traversal stack again so we can do a second pass
    kv.SavePosition();

    char serviceName[MAX_SERVICE_NAME_SIZE|MAX_SERVICE_OVERRIDE_SIZE]; // Cheeky MAX()
    char inheritSvcName[MAX_SERVICE_NAME_SIZE];

    s_IsInheritOnlyPass = false;

    for (int i = 0; i < 2; ++i)
    {
        do
        {
            inheritSvcName[0] = '\0';
            kv.GetSectionName(serviceName, sizeof(serviceName));

            // Inheriting services still need to set "service_enabled"
            if (!IsServiceEnabled(kv))
                continue;

            // Only allow inheriting-services in the inherit pass, and vice versa
            if (s_IsInheritOnlyPass != IsInheritingService(kv, inheritSvcName, sizeof(inheritSvcName)))
                continue;

            // Create new service (blocking duplicates)
            Service svc;
            if (FindServiceByName(serviceName, false) != null)
            {
                HandleError(svc, fatalError, "Service \"%s\" already exists. Cannot re-use the same service name.", serviceName);
                continue;
            }

            if (s_IsInheritOnlyPass)
                svc = Service_CloneByName(serviceName, inheritSvcName, false);
            else
                svc = new Service(serviceName);

            if (svc == null)
            {
                HandleError(svc, fatalError, "Service \"%s\" could not inherit from unknown service \"%s\". Either the name is invalid, or the order in the config is incorrect.", serviceName, inheritSvcName);
                continue;
            }

            // svc automatically deleted on fail
            // kv is NOT because we need to process the next Service
            if (!ProcessMainConfiguration(kv, svc, fatalError, serviceName))
                continue;
            if (!ProcessPlayerSpawnBonuses(kv, svc, fatalError, serviceName))
                continue;
            if (!ProcessPlayerGrenadesOnSpawn(kv, svc, fatalError, serviceName))
                continue;
            if (!ProcessSpecialBonuses(kv, svc, fatalError, serviceName))
                continue;
            if (!ProcessEventMoneyBonuses(kv, svc, fatalError, serviceName))
                continue;
            if (!ProcessEventHPBonuses(kv, svc, fatalError, serviceName))
                continue;
            if (!ProcessChatWelcomeLeaveMessages(kv, svc, fatalError, serviceName))
                continue;
            if (!ProcessHudWelcomeLeaveMessages(kv, svc, fatalError, serviceName))
                continue;

            if (!ProcessWeapons(kv, svc, fatalError, serviceName))
                continue;

            g_Services.Push(svc);

            s_UsedServiceFlags |= svc.Flag;

            svc.GetOverride(serviceName, sizeof(serviceName));
            if (serviceName[0])
                s_UsedServiceOverrides.SetValue(serviceName, 0);
        }
        while (kv.GotoNextKey());

        // Start second config pass
        kv.GoBack(); // To first service
        s_IsInheritOnlyPass = true;
    }

    delete s_UsedServiceOverrides;

    // Get global config *after* getting services so it's not set unless all
    // services are valid, which is both safer and required for "root_service"
    if (!GetGlobalConfiguration(kv, fatalError))
    {
        ResetAllServices();
        return false;
    }

    delete kv;

    if (!BuildSortedLists() || !LoadModuleConfig(fatalError))
    {
        ResetAllServices();
        return false;
    }

    PrintToServer("[Ultra VIP] %T", "Services Loaded", LANG_SERVER, g_Services.Length);

    return true;
}

static bool GetGlobalConfiguration(KeyValues kv, bool fatalError)
{
    // Must be called after g_Services is loaded
    kv.Rewind();

    kv.GetString("chat_tag", g_ChatTag, sizeof(g_ChatTag));
    if (!g_ChatTag[0])
        return HandleError(kv, fatalError, "Missing \"chat_tag\" setting in config file.");

    g_UseOnlineList = view_as<bool>(kv.GetNum("online_list", 1));
    g_UseBonusesList = view_as<bool>(kv.GetNum("bonuses_list", 1));
    g_IsDeathmatchMode = view_as<bool>(kv.GetNum("deathmatch_mode", 0));
    g_BotsGrantBonuses = view_as<bool>(kv.GetNum("bots_grant_bonuses", 0));

    delete g_OnlineListCommands;
    delete g_BonusesListCommands;
    g_OnlineListCommands = new StringMap();
    g_BonusesListCommands = new StringMap();

    // Allow an extra char to catch misuse
    char buffer[ONLINE_CMD_STRING_MAXLENGTH + 2];
    kv.GetString("online_list_commands", buffer, sizeof(buffer));
    if (strlen(buffer) >= ONLINE_CMD_STRING_MAXLENGTH)
        return HandleError(kv, fatalError, "\"online_list_commands\" is too long (Max %i characters).", ONLINE_CMD_STRING_MAXLENGTH);

    SplitIntoStringMap(g_OnlineListCommands, buffer, ONLINE_CMD_SEPARATOR);

    kv.GetString("bonuses_list_commands", buffer, sizeof(buffer));
    if (strlen(buffer) >= ONLINE_CMD_STRING_MAXLENGTH)
        return HandleError(kv, fatalError, "\"bonuses_list_commands\" is too long (Max %i characters).", ONLINE_CMD_STRING_MAXLENGTH);

    SplitIntoStringMap(g_BonusesListCommands, buffer, ONLINE_CMD_SEPARATOR);

    if (!GetRootService(kv))
        return HandleError(kv, fatalError, "An error occurred while processing the \"root_service\".");

    g_FixRequiredCvars = view_as<bool>(kv.GetNum("fix_cvars", 1));
    g_FixGrenadeLimits = view_as<bool>(kv.GetNum("fix_grenade_limits", 0));
    // Config_FixCvars must be called in OnConfigsExecuted

    return true;
}

static bool GetRootService(KeyValues kv)
{
    char buffer[64];
    kv.GetString("root_service", buffer, sizeof(buffer));

    g_RootService = null;
    g_RootServiceMode = Mode_None;

    if (!buffer[0])
    {
        LogError("\"root_service\" cannot be empty. You must use \"NONE\", \"AUTO\" or the name of a service.");
        return false;
    }

    if (StrEqual(buffer, "NONE", false))
        return true;
    else if (StrEqual(buffer, "AUTO", false))
    {
        g_RootServiceMode = Mode_Auto;
        return true;
    }

    g_RootService = FindServiceByName(buffer);
    if (g_RootService == null)
    {
        LogError("\"root_service\" is set to an unknown service \"%s\"", buffer);
        return false;
    }

    g_RootServiceMode = Mode_Specified;
    return true;
}

bool Config_FixCvars()
{
    Service svc;
    int len = g_Services.Length;

    if (g_FixGrenadeLimits)
    {
        int he;
        int flash;
        int smoke;
        int decoy;
        int molotov;
        int healthshot;
        int tag;
        int snowball;

        for (int i = 0; i < len; ++i)
        {
            svc = g_Services.Get(i);

            he = _MAX(svc.BonusHEGrenades, he);
            flash = _MAX(svc.BonusFlashGrenades, flash);
            smoke = _MAX(svc.BonusSmokeGrenades, smoke);
            decoy = _MAX(svc.BonusDecoyGrenades, decoy);
            molotov = _MAX(svc.BonusMolotovGrenades, molotov);
            healthshot = _MAX(svc.BonusHealthshotGrenades, healthshot);
            tag = _MAX(svc.BonusTacticalGrenades, tag);
            snowball = _MAX(svc.BonusSnowballGrenades, snowball);
        }

        if (!_SetCvarIfHigher("ammo_grenade_limit_total", he + flash + smoke + decoy + molotov + tag))
            return false;

        int max = he;
        max = _MAX(smoke, max);
        max = _MAX(decoy, max);
        max = _MAX(molotov, max);
        max = _MAX(tag, max);

        if (!_SetCvarIfHigher("ammo_grenade_limit_default", max))
            return false;

        if (!_SetCvarIfHigher("ammo_grenade_limit_flashbang", flash))
            return false;
        if (!_SetCvarIfHigher("ammo_grenade_limit_snowballs", snowball))
            return false;
        if (!_SetCvarIfHigher("ammo_item_limit_healthshot", healthshot))
            return false;
    }


    if (!g_FixRequiredCvars)
        return true;

    for (int i = 0; i < len; ++i)
    {
        svc = g_Services.Get(i);

        // Only modify cvars if actually required
        if (svc.BonusPlayerVisibility < 255)
        {
            // "player_visibility" requires this for SetPlayerVisibility
            _SetCvarIfHigher("sv_disable_immunity_alpha", 1);
        }
    }
    return true;
}

static bool _SetCvarIfHigher(const char[] cvarName, int amount)
{
    ConVar cvar = FindConVar(cvarName);
    if (cvar == null)
    {
        LogError("Missing hardcoded ConVar %s", cvarName);
        return false;
    }

    if (amount < 0)
        amount = 0;

    int current = cvar.IntValue;

    if (amount > current)
        cvar.IntValue = amount;
    return true;
}

static bool IsInheritingService(KeyValues kv, char[] serviceNameOut, int size)
{
    if (!kv.JumpToKey("Main Configuration"))
        return false;

    kv.GetString("inherit_from_service", serviceNameOut, size);
    kv.GoBack();
    return serviceNameOut[0] != '\0';
}

static bool IsServiceEnabled(KeyValues kv)
{
    if (!kv.JumpToKey("Main Configuration"))
        return false;

    bool result = view_as<bool>(kv.GetNum("service_enabled", 0));
    kv.GoBack();
    return result;
}

static bool CanGetKey(KeyValues kv, const char[] key)
{
    return (!s_IsInheritOnlyPass || (s_IsInheritOnlyPass && KvContainsSubKey(kv, key)));
}

static bool ProcessMainConfiguration(KeyValues kv, Service svc, bool fatalError, const char[] serviceName)
{
    if (!kv.JumpToKey("Main Configuration"))
        return HandleError(svc, fatalError, "Service \"%s\" is missing section \"Main Configuration\".", serviceName);

    char buffer[MAX_SERVICE_OVERRIDE_SIZE + 64];

    // Flags MUST be unique per service or FindServiceByFlagAccess wont work
    if (CanGetKey(kv, "flag"))
    {
        kv.GetString("flag", buffer, sizeof(buffer));
        int flag = ReadFlagString(buffer); // No flag is ignored by ifs below
        if (flag && !HasOnlySingleBit(flag))
            return HandleErrorAndGoBack(kv, svc, fatalError, "Service \"%s\" is not allowed to have multiple admin flags.", serviceName);
        if (s_UsedServiceFlags & flag)
            return HandleErrorAndGoBack(kv, svc, fatalError, "Service \"%s\" is using admin flag '%s' which is in use by another service.", serviceName, buffer);
        if (flag & ADMFLAG_ROOT)
            return HandleErrorAndGoBack(kv, svc, fatalError, "Service \"%s\" is not allowed to have the ROOT flag (z). Use \"root_service\" instead.", serviceName);

        svc.Flag = flag;
    }
    else if (s_IsInheritOnlyPass)
    {
        // Make sure we're not defaulting to an in-use flag when inheriting a service
        int flag = svc.Flag;
        if (flag & s_UsedServiceFlags || flag != 0)
           return HandleErrorAndGoBack(kv, svc, fatalError, "Service \"%s\" cannot use the same admin flag as the service it is inheriting from.", serviceName);
    }


    // Overrides must be unique per service or FindServiceByOverrideAccess wont work
    if (CanGetKey(kv, "override"))
    {
        kv.GetString("override", buffer, sizeof(buffer));
        if (buffer[0] && s_UsedServiceOverrides.ContainsKey(buffer))
            return HandleErrorAndGoBack(kv, svc, fatalError, "Service \"%s\" is using admin override '%s' which is in use by another service.", serviceName, buffer);
        svc.SetOverride(buffer);
    }
    else if (s_IsInheritOnlyPass)
    {
        // Make sure we're not defaulting to an in-use override when inheriting a service
        svc.GetOverride(buffer, sizeof(buffer));
        if (s_UsedServiceOverrides.ContainsKey(buffer) || buffer[0])
            return HandleErrorAndGoBack(kv, svc, fatalError, "Service \"%s\" cannot use the same override as the service it is inheriting from.", serviceName);
    }


    // s_UsedServiceFlags and s_UsedServiceOverrides are updated when
    // the service is pushed to g_Services


    if (CanGetKey(kv, "priority"))
        svc.Priority = kv.GetNum("priority", 0);

    if (CanGetKey(kv, "chat_tag"))
    {
        kv.GetString("chat_tag", buffer, sizeof(buffer));
        svc.SetChatTag(buffer);
    }

    if (CanGetKey(kv, "chat_name_color"))
    {
        kv.GetString("chat_name_color", buffer, sizeof(buffer));
        ReplaceString(buffer, sizeof(buffer), "{teamcolor}", "\x03");
        svc.SetChatNameColor(buffer);
    }

    if (CanGetKey(kv, "chat_message_color"))
    {
        kv.GetString("chat_message_color", buffer, sizeof(buffer));
        svc.SetChatMsgColor(buffer);
    }

    if (CanGetKey(kv, "scoreboard_tag"))
    {
        kv.GetString("scoreboard_tag", buffer, sizeof(buffer));
        svc.SetScoreboardTag(buffer);
    }

    if (CanGetKey(kv, "allow_during_warmup"))
        svc.AllowDuringWarmup = view_as<bool>(kv.GetNum("allow_during_warmup", 0));

    if (!Config_ProcessSteamIDAccess(kv, svc, fatalError, serviceName))
    {
        Config_RemoveSteamIDsForService(svc);
        return false;
    }

    kv.GoBack(); // To service name
    return true;
}

static bool Config_ProcessSteamIDAccess(KeyValues kv, Service svc, bool fatalError, const char[] serviceName)
{
#warning This was HandleErrorAndGoBack before but i think thats wrong, so test it

    if (!kv.JumpToKey("SteamID Access"))
        return s_IsInheritOnlyPass ? true : HandleError(svc, fatalError, "Service \"%s\" is missing secttion \"SteamID Access\".", serviceName);

    if (!kv.GotoFirstSubKey(false))
    {
        kv.GoBack(); // To "Main Configuration"
        return true;
    }

    char auth[MAX_AUTHID_LENGTH];
    do
    {
        kv.GetString(NULL_STRING, auth, sizeof(auth));

        // Empty steamid is not an error
        if (!auth[0])
            continue;

        int account = GetAccountFromSteamID(auth);
        if (account)
        {
            IntToString(account, auth, sizeof(auth));
            g_SteamIDServices.SetValue(auth, svc);
        }
        else
            LogError("Invalid SteamID2 or SteamID3 \"%s\" for Service \"%s\"", auth, serviceName);

    } while (kv.GotoNextKey(false));

    kv.GoBack(); // To SteamID Access
    kv.GoBack(); // To "Main Configuration"
    return true;
}

static void Config_RemoveSteamIDsForService(Service svc)
{
    StringMapSnapshot snap = g_SteamIDServices.Snapshot();

    char auth[MAX_AUTHID_LENGTH];
    int len = snap.Length;
    Service value;

    for (int i = 0; i < len; ++i)
    {
        snap.GetKey(i, auth, sizeof(auth));

        if (!g_SteamIDServices.GetValue(auth, value))
            continue;

        if (svc == value)
            g_SteamIDServices.Remove(auth);
    }

    delete snap;
}

static bool ProcessPlayerSpawnBonuses(KeyValues kv, Service svc, bool fatalError, const char[] serviceName)
{
    if (!kv.JumpToKey("Player Spawn Bonuses"))
        return s_IsInheritOnlyPass ? true : HandleError(svc, fatalError, "Service \"%s\" is missing section \"Player Spawn Bonuses\".", serviceName);

    if (CanGetKey(kv, "player_hp"))
        svc.BonusPlayerHealth = kv.GetNum("player_hp", 105);
    if (CanGetKey(kv, "player_hp_round"))
        svc.BonusPlayerHealthRound = GetConfigRound(kv, "player_hp_round", 1);
    if (CanGetKey(kv, "player_max_hp"))
        svc.BonusMaxPlayerHealth = kv.GetNum("player_max_hp", 110);

    if (CanGetKey(kv, "player_vest"))
        svc.BonusArmorEnabled = view_as<bool>(kv.GetNum("player_vest", 1));
    if (CanGetKey(kv, "player_vest_value"))
        svc.BonusArmor = kv.GetNum("player_vest_value", 100);
    if (CanGetKey(kv, "player_vest_round"))
        svc.BonusArmorRound = GetConfigRound(kv, "player_vest_round", 2);

    if (CanGetKey(kv, "player_helmet"))
        svc.BonusHelmetEnabled = view_as<bool>(kv.GetNum("player_helmet", 1));
    if (CanGetKey(kv, "player_helmet_round"))
        svc.BonusHelmetRound = GetConfigRound(kv, "player_helmet_round", 2);

    if (CanGetKey(kv, "player_defuser"))
        svc.BonusDefuserEnabled = view_as<bool>(kv.GetNum("player_defuser", 1));
    if (CanGetKey(kv, "player_defuser_round"))
        svc.BonusDefuserRound = GetConfigRound(kv, "player_defuser_round", 2);

    kv.GoBack(); // To service name
    return true;
}

static bool ProcessPlayerGrenadesOnSpawn(KeyValues kv, Service svc, bool fatalError, const char[] serviceName)
{
    if (!kv.JumpToKey("Grenades On Spawn"))
        return s_IsInheritOnlyPass ? true : HandleError(svc, fatalError, "Service \"%s\" is missing section \"Grenades On Spawn\".", serviceName);

    if (CanGetKey(kv, "strip_grenades"))
        svc.ShouldStripConsumables = view_as<bool>(kv.GetNum("strip_grenades", 0));

    if (CanGetKey(kv, "he_amount"))
        svc.BonusHEGrenades = kv.GetNum("he_amount", 1);
    if (CanGetKey(kv, "he_round"))
        svc.BonusHEGrenadesRound = GetConfigRound(kv, "he_round", 1);

    if (CanGetKey(kv, "flash_amount"))
        svc.BonusFlashGrenades = kv.GetNum("flash_amount", 1);
    if (CanGetKey(kv, "flash_round"))
        svc.BonusFlashGrenadesRound = GetConfigRound(kv, "flash_round", 1);

    if (CanGetKey(kv, "smoke_amount"))
        svc.BonusSmokeGrenades = kv.GetNum("smoke_amount", 1);
    if (CanGetKey(kv, "smoke_round"))
        svc.BonusSmokeGrenadesRound = GetConfigRound(kv, "smoke_round", 1);

    if (CanGetKey(kv, "decoy_amount"))
        svc.BonusDecoyGrenades = kv.GetNum("decoy_amount", 0);
    if (CanGetKey(kv, "decoy_round"))
        svc.BonusDecoyGrenadesRound = GetConfigRound(kv, "decoy_round", 1);

    if (CanGetKey(kv, "molotov_amount"))
        svc.BonusMolotovGrenades = kv.GetNum("molotov_amount", 0);
    if (CanGetKey(kv, "molotov_round"))
        svc.BonusMolotovGrenadesRound = GetConfigRound(kv, "molotov_round", 1);

    if (CanGetKey(kv, "healthshot_amount"))
        svc.BonusHealthshotGrenades = kv.GetNum("healthshot_amount", 0);
    if (CanGetKey(kv, "healthshot_round"))
        svc.BonusHealthshotGrenadesRound = GetConfigRound(kv, "healthshot_round", 3);

    if (CanGetKey(kv, "tag_amount"))
        svc.BonusTacticalGrenades = kv.GetNum("tag_amount", 0);
    if (CanGetKey(kv, "tag_round"))
        svc.BonusTacticalGrenadesRound = GetConfigRound(kv, "tag_round", 1);

    if (CanGetKey(kv, "snowball_amount"))
        svc.BonusSnowballGrenades = kv.GetNum("snowball_amount", 0);
    if (CanGetKey(kv, "snowball_round"))
        svc.BonusSnowballGrenadesRound = GetConfigRound(kv, "snowball_round", 1);

    if (CanGetKey(kv, "breachcharge_amount"))
        svc.BonusBreachchargeGrenades = kv.GetNum("breachcharge_amount", 0);
    if (CanGetKey(kv, "breachcharge_round"))
        svc.BonusBreachchargeGrenadesRound = GetConfigRound(kv, "breachcharge_round", 1);

    if (CanGetKey(kv, "bumpmine_amount"))
        svc.BonusBumpmineGrenades = kv.GetNum("bumpmine_amount", 0);
    if (CanGetKey(kv, "bumpmine_round"))
        svc.BonusBumpmineGrenadesRound = GetConfigRound(kv, "bumpmine_round", 1);

    kv.GoBack(); // To service name
    return true;
}

static bool ProcessSpecialBonuses(KeyValues kv, Service svc, bool fatalError, const char[] serviceName)
{
    if (!kv.JumpToKey("Special Bonuses"))
        return s_IsInheritOnlyPass ? true : HandleError(svc, fatalError, "Service \"%s\" is missing section \"Special Bonuses\".", serviceName);

    if (CanGetKey(kv, "player_extra_jumps"))
        svc.BonusExtraJumps = kv.GetNum("player_extra_jumps", 1);
    if (CanGetKey(kv, "player_extra_jump_height"))
        svc.BonusJumpHeight = kv.GetFloat("player_extra_jump_height", EXTRAJUMP_DEFAULT_HEIGHT);
    if (CanGetKey(kv, "player_extra_jumps_round"))
        svc.BonusExtraJumpsRound = GetConfigRound(kv, "player_extra_jumps_round", 1);
    if (CanGetKey(kv, "player_extra_jumps_falldamage"))
        svc.BonusExtraJumpsTakeFallDamage = view_as<bool>(kv.GetNum("player_extra_jumps_falldamage", 1));

    if (CanGetKey(kv, "player_shield"))
        svc.BonusPlayerShield = view_as<bool>(kv.GetNum("player_shield", 0));
    if (CanGetKey(kv, "player_shield_round"))
        svc.BonusPlayerShieldRound = GetConfigRound(kv, "player_shield_round", 1);

    if (CanGetKey(kv, "player_gravity"))
        svc.BonusPlayerGravity = kv.GetFloat("player_gravity", 1.0);
    if (CanGetKey(kv, "player_gravity_round"))
        svc.BonusPlayerGravityRound = GetConfigRound(kv, "player_gravity_round", 1);

    if (CanGetKey(kv, "player_speed"))
        svc.BonusPlayerSpeed = kv.GetFloat("player_speed", 1.0);
    if (CanGetKey(kv, "player_speed_round"))
        svc.BonusPlayerSpeedRound = GetConfigRound(kv, "player_speed_round", 1);

    if (CanGetKey(kv, "player_visibility"))
        svc.BonusPlayerVisibility = kv.GetNum("player_visibility", 255);
    if (CanGetKey(kv, "player_visibility_round"))
        svc.BonusPlayerVisibilityRound = GetConfigRound(kv, "player_visibility_round", 1);

    if (CanGetKey(kv, "player_respawn_percent"))
        svc.BonusPlayerRespawnPercent = kv.GetNum("player_respawn_percent", 0);
    if (CanGetKey(kv, "player_respawn_round"))
        svc.BonusPlayerRespawnPercentRound = GetConfigRound(kv, "player_respawn_round", 3);
    if (CanGetKey(kv, "player_respawn_notify"))
        svc.BonusPlayerRespawnPercentNotify = view_as<bool>(kv.GetNum("player_respawn_notify", 0));

    if (CanGetKey(kv, "player_fall_damage_percent"))
        svc.BonusPlayerFallDamagePercent = kv.GetNum("player_fall_damage_percent", 100);
    if (CanGetKey(kv, "player_fall_damage_round"))
        svc.BonusPlayerFallDamagePercentRound = GetConfigRound(kv, "player_fall_damage_round", 1);

    if (CanGetKey(kv, "player_attack_damage"))
        svc.BonusPlayerAttackDamage = kv.GetNum("player_attack_damage", 100);
    if (CanGetKey(kv, "player_attack_damage_round"))
        svc.BonusPlayerAttackDamageRound = GetConfigRound(kv, "player_attack_damage_round", 3);

    if (CanGetKey(kv, "player_damage_resist"))
        svc.BonusPlayerDamageResist = kv.GetNum("player_damage_resist", 0);
    if (CanGetKey(kv, "player_damage_resist_round"))
        svc.BonusPlayerDamageResistRound = GetConfigRound(kv, "player_damage_resist_round", 3);

    if (CanGetKey(kv, "player_unlimited_ammo"))
        svc.BonusUnlimitedAmmo = view_as<bool>(kv.GetNum("player_unlimited_ammo", 0));
    if (CanGetKey(kv, "player_unlimited_ammo_round"))
        svc.BonusUnlimitedAmmoRound = GetConfigRound(kv, "player_unlimited_ammo_round", 1);

    if (CanGetKey(kv, "player_no_recoil"))
        svc.BonusNoRecoil = view_as<bool>(kv.GetNum("player_no_recoil", 0));
    if (CanGetKey(kv, "player_no_recoil_round"))
        svc.BonusNoRecoilRound = GetConfigRound(kv, "player_no_recoil_round", 1);

    kv.GoBack(); // Service name
    return true;
}

static bool ProcessEventMoneyBonuses(KeyValues kv, Service svc, bool fatalError, const char[] serviceName)
{
    if (!kv.JumpToKey("Events Bonuses"))
        return s_IsInheritOnlyPass ? true : HandleError(svc, fatalError, "Service \"%s\" is missing section \"Events Bonuses\".", serviceName);

    if (!kv.JumpToKey("Money"))
        return s_IsInheritOnlyPass ? GoBackReturnTrue(kv) : HandleErrorAndGoBack(kv, svc, fatalError, "Service \"%s\" is missing section \"Money\".", serviceName);

    if (CanGetKey(kv, "spawn_bonus"))
        svc.BonusSpawnMoney = kv.GetNum("spawn_bonus", 0);
    if (CanGetKey(kv, "spawn_bonus_round"))
        svc.BonusSpawnMoneyRound = GetConfigRound(kv, "spawn_bonus_round", 1);
    if (CanGetKey(kv, "spawn_bonus_chat"))
        svc.BonusSpawnMoneyNotify = view_as<bool>(kv.GetNum("spawn_bonus_chat", 0));

    if (CanGetKey(kv, "kill_bonus"))
        svc.BonusKillMoney = kv.GetNum("kill_bonus", 0);
    if (CanGetKey(kv, "kill_bonus_round"))
        svc.BonusKillMoneyRound = GetConfigRound(kv, "kill_bonus_round", 1);
    if (CanGetKey(kv, "kill_bonus_chat"))
        svc.BonusKillMoneyNotify = view_as<bool>(kv.GetNum("kill_bonus_chat", 0));

    if (CanGetKey(kv, "assist_bonus"))
        svc.BonusAssistMoney = kv.GetNum("assist_bonus", 0);
    if (CanGetKey(kv, "assist_bonus_round"))
        svc.BonusAssistMoneyRound = GetConfigRound(kv, "assist_bonus_round", 1);
    if (CanGetKey(kv, "assist_bonus_chat"))
        svc.BonusAssistMoneyNotify = view_as<bool>(kv.GetNum("assist_bonus_chat", 0));

    if (CanGetKey(kv, "headshot_bonus"))
        svc.BonusHeadshotMoney = kv.GetNum("headshot_bonus", 0);
    if (CanGetKey(kv, "headshot_bonus_round"))
        svc.BonusHeadshotMoneyRound = GetConfigRound(kv, "headshot_bonus_round", 1);
    if (CanGetKey(kv, "headshot_bonus_chat"))
        svc.BonusHeadshotMoneyNotify = view_as<bool>(kv.GetNum("headshot_bonus_chat", 0));

    if (CanGetKey(kv, "knife_bonus"))
        svc.BonusKnifeMoney = kv.GetNum("knife_bonus", 0);
    if (CanGetKey(kv, "knife_bonus_round"))
        svc.BonusKnifeMoneyRound = GetConfigRound(kv, "knife_bonus_round", 1);
    if (CanGetKey(kv, "knife_bonus_chat"))
        svc.BonusKnifeMoneyNotify = view_as<bool>(kv.GetNum("knife_bonus_chat", 0));

    if (CanGetKey(kv, "zeus_bonus"))
        svc.BonusZeusMoney = kv.GetNum("zeus_bonus", 0);
    if (CanGetKey(kv, "zeus_bonus_round"))
        svc.BonusZeusMoneyRound = GetConfigRound(kv, "zeus_bonus_round", 1);
    if (CanGetKey(kv, "zeus_bonus_chat"))
        svc.BonusZeusMoneyNotify = view_as<bool>(kv.GetNum("zeus_bonus_chat", 0));

    if (CanGetKey(kv, "grenade_bonus"))
        svc.BonusGrenadeMoney = kv.GetNum("grenade_bonus", 0);
    if (CanGetKey(kv, "grenade_bonus_round"))
        svc.BonusGrenadeMoneyRound = GetConfigRound(kv, "grenade_bonus_round", 1);
    if (CanGetKey(kv, "grenade_bonus_chat"))
        svc.BonusGrenadeMoneyNotify = view_as<bool>(kv.GetNum("grenade_bonus_chat", 0));

    if (CanGetKey(kv, "mvp_bonus"))
        svc.BonusMvpMoney = kv.GetNum("mvp_bonus", 0);
    if (CanGetKey(kv, "mvp_bonus_round"))
        svc.BonusMvpMoneyRound = GetConfigRound(kv, "mvp_bonus_round", 1);
    if (CanGetKey(kv, "mvp_bonus_chat"))
        svc.BonusMvpMoneyNotify = view_as<bool>(kv.GetNum("mvp_bonus_chat", 0));

    if (CanGetKey(kv, "noscope_bonus"))
        svc.BonusNoscopeMoney = kv.GetNum("noscope_bonus", 0);
    if (CanGetKey(kv, "noscope_bonus_round"))
        svc.BonusNoscopeMoneyRound = GetConfigRound(kv, "noscope_bonus_round", 1);
    if (CanGetKey(kv, "noscope_bonus_chat"))
        svc.BonusNoscopeMoneyNotify = view_as<bool>(kv.GetNum("noscope_bonus_chat", 0));

    if (CanGetKey(kv, "hostage_bonus"))
        svc.BonusHostageMoney = kv.GetNum("hostage_bonus", 0);
    if (CanGetKey(kv, "hostage_bonus_round"))
        svc.BonusHostageMoneyRound = GetConfigRound(kv, "hostage_bonus_round", 1);
    if (CanGetKey(kv, "hostage_bonus_chat"))
        svc.BonusHostageMoneyNotify = view_as<bool>(kv.GetNum("hostage_bonus_chat", 0));

    if (CanGetKey(kv, "bomb_planted_bonus"))
        svc.BonusBombPlantedMoney = kv.GetNum("bomb_planted_bonus", 0);
    if (CanGetKey(kv, "bomb_planted_bonus_round"))
        svc.BonusBombPlantedMoneyRound = GetConfigRound(kv, "bomb_planted_bonus_round", 1);
    if (CanGetKey(kv, "bomb_planted_bonus_chat"))
        svc.BonusBombPlantedMoneyNotify = view_as<bool>(kv.GetNum("bomb_planted_bonus_chat", 0));

    if (CanGetKey(kv, "bomb_defused_bonus"))
        svc.BonusBombDefusedMoney = kv.GetNum("bomb_defused_bonus", 0);
    if (CanGetKey(kv, "bomb_defused_bonus_round"))
        svc.BonusBombDefusedMoneyRound = GetConfigRound(kv, "bomb_defused_bonus_round", 1);
    if (CanGetKey(kv, "bomb_defused_bonus_chat"))
        svc.BonusBombDefusedMoneyNotify = view_as<bool>(kv.GetNum("bomb_defused_bonus_chat", 0));

    kv.GoBack(); // Events Bonuses
    kv.GoBack(); // Service Name
    return true;
}

static bool ProcessEventHPBonuses(KeyValues kv, Service svc, bool fatalError, const char[] serviceName)
{
    if (!kv.JumpToKey("Events Bonuses"))
        return s_IsInheritOnlyPass ? true : HandleError(svc, fatalError, "Service \"%s\" is missing section \"Events Bonuses\".", serviceName);

    if (!kv.JumpToKey("Bonus Health"))
        return s_IsInheritOnlyPass ? GoBackReturnTrue(kv) : HandleErrorAndGoBack(kv, svc, fatalError, "Service \"%s\" is missing section \"Bonus Health\".", serviceName);

    if (CanGetKey(kv, "kill_hp_bonus"))
        svc.BonusKillHP = kv.GetNum("kill_hp_bonus", 0);
    if (CanGetKey(kv, "kill_hp_bonus_round"))
        svc.BonusKillHPRound = GetConfigRound(kv, "kill_hp_bonus_round", 1);
    if (CanGetKey(kv, "kill_hp_bonus_chat"))
        svc.BonusKillHPNotify = view_as<bool>(kv.GetNum("kill_hp_bonus_chat", 0));

    if (CanGetKey(kv, "assist_hp_bonus"))
        svc.BonusAssistHP = kv.GetNum("assist_hp_bonus", 0);
    if (CanGetKey(kv, "assist_hp_bonus_round"))
        svc.BonusAssistHPRound = GetConfigRound(kv, "assist_hp_bonus_round", 1);
    if (CanGetKey(kv, "assist_hp_bonus_chat"))
        svc.BonusAssistHPNotify = view_as<bool>(kv.GetNum("assist_hp_bonus_chat", 0));

    if (CanGetKey(kv, "headshot_hp_bonus"))
        svc.BonusHeadshotHP = kv.GetNum("headshot_hp_bonus", 0);
    if (CanGetKey(kv, "headshot_hp_bonus_round"))
        svc.BonusHeadshotHPRound = GetConfigRound(kv, "headshot_hp_bonus_round", 1);
    if (CanGetKey(kv, "headshot_hp_bonus_chat"))
        svc.BonusHeadshotHPNotify = view_as<bool>(kv.GetNum("headshot_hp_bonus_chat", 0));

    if (CanGetKey(kv, "knife_hp_bonus"))
        svc.BonusKnifeHP = kv.GetNum("knife_hp_bonus", 0);
    if (CanGetKey(kv, "knife_hp_bonus_round"))
        svc.BonusKnifeHPRound = GetConfigRound(kv, "knife_hp_bonus_round", 1);
    if (CanGetKey(kv, "knife_hp_bonus_chat"))
        svc.BonusKnifeHPNotify = view_as<bool>(kv.GetNum("knife_hp_bonus_chat", 0));

    if (CanGetKey(kv, "zeus_hp_bonus"))
        svc.BonusZeusHP = kv.GetNum("zeus_hp_bonus", 0);
    if (CanGetKey(kv, "zeus_hp_bonus_round"))
        svc.BonusZeusHPRound = GetConfigRound(kv, "zeus_hp_bonus_round", 1);
    if (CanGetKey(kv, "zeus_hp_bonus_chat"))
        svc.BonusZeusHPNotify = view_as<bool>(kv.GetNum("zeus_hp_bonus_chat", 0));

    if (CanGetKey(kv, "grenade_hp_bonus"))
        svc.BonusGrenadeHP = kv.GetNum("grenade_hp_bonus", 0);
    if (CanGetKey(kv, "grenade_hp_bonus_round"))
        svc.BonusGrenadeHPRound = GetConfigRound(kv, "grenade_hp_bonus_round", 1);
    if (CanGetKey(kv, "grenade_hp_bonus_chat"))
        svc.BonusGrenadeHPNotify = view_as<bool>(kv.GetNum("grenade_hp_bonus_chat", 0));

    if (CanGetKey(kv, "noscope_hp_bonus"))
        svc.BonusNoscopeHP = kv.GetNum("noscope_hp_bonus", 0);
    if (CanGetKey(kv, "noscope_hp_bonus_round"))
        svc.BonusNoscopeHPRound = GetConfigRound(kv, "noscope_hp_bonus_round", 1);
    if (CanGetKey(kv, "noscope_hp_bonus_chat"))
        svc.BonusNoscopeHPNotify = view_as<bool>(kv.GetNum("noscope_hp_bonus_chat", 0));

    kv.GoBack(); // Events Bonuses
    kv.GoBack(); // Service name
    return true;
}

static bool ProcessChatWelcomeLeaveMessages(KeyValues kv, Service svc, bool fatalError, const char[] serviceName)
{
    if (!kv.JumpToKey("Welcome and Leave Messages"))
        return s_IsInheritOnlyPass ? true : HandleError(svc, fatalError, "Service \"%s\" is missing section \"Welcome and Leave Messages\".", serviceName);

    if (!kv.JumpToKey("Chat"))
        return s_IsInheritOnlyPass ? GoBackReturnTrue(kv) : HandleErrorAndGoBack(kv, svc, fatalError, "Service \"%s\" is missing section \"Chat\".", serviceName);

    char buffer[256];

    if (CanGetKey(kv, "chat_join_msg_enable"))
        svc.ChatWelcomeMessage = view_as<bool>(kv.GetNum("chat_join_msg_enable", 1));

    if (CanGetKey(kv, "chat_join_msg"))
    {
        kv.GetString("chat_join_msg", buffer, sizeof(buffer));
        svc.SetChatWelcomeMessage(buffer);
    }

    if (CanGetKey(kv, "chat_leave_msg_enable"))
        svc.ChatLeaveMessage = view_as<bool>(kv.GetNum("chat_leave_msg_enable", 1));

    if (CanGetKey(kv, "chat_leave_msg"))
    {
        kv.GetString("chat_leave_msg", buffer, sizeof(buffer));
        svc.SetChatLeaveMessage(buffer);
    }

    kv.GoBack(); // Welcome and Leave Messages
    kv.GoBack(); // Service Name
    return true;
}

static bool ProcessHudWelcomeLeaveMessages(KeyValues kv, Service svc, bool fatalError, const char[] serviceName)
{
    if (!kv.JumpToKey("Welcome and Leave Messages"))
        return s_IsInheritOnlyPass ? true : HandleError(svc, fatalError, "Service \"%s\" is missing section \"Welcome and Leave Messages\".", serviceName);

    if (!kv.JumpToKey("Hud"))
        return s_IsInheritOnlyPass ? GoBackReturnTrue(kv) : HandleErrorAndGoBack(kv, svc, fatalError, "Service \"%s\" is missing section \"Hud\".", serviceName);

    char buffer[256];

    if (CanGetKey(kv, "hud_leave_msg_enable"))
        svc.HudWelcomeMessage = view_as<bool>(kv.GetNum("hud_leave_msg_enable", 0));

    if (CanGetKey(kv, "hud_join_msg"))
    {
        kv.GetString("hud_join_msg", buffer, sizeof(buffer));
        svc.SetHudWelcomeMessage(buffer);
    }

    if (CanGetKey(kv, "hud_leave_msg_enable"))
        svc.HudLeaveMessage = view_as<bool>(kv.GetNum("hud_leave_msg_enable", 0));

    if (CanGetKey(kv, "hud_leave_msg"))
    {
        kv.GetString("hud_leave_msg", buffer, sizeof(buffer));
        svc.SetHudLeaveMessage(buffer);
    }

    if (CanGetKey(kv, "hud_position_x"))
        svc.HudPositionX = kv.GetFloat("hud_position_x", -1.0);
    if (CanGetKey(kv, "hud_position_y"))
        svc.HudPositionY = kv.GetFloat("hud_position_y", -0.7);
    if (CanGetKey(kv, "hud_color_red"))
        svc.HudColorRed = kv.GetNum("hud_color_red", 243);
    if (CanGetKey(kv, "hud_color_green"))
        svc.HudColorGreen = kv.GetNum("hud_color_green", 200);
    if (CanGetKey(kv, "hud_color_blue"))
        svc.HudColorBlue = kv.GetNum("hud_color_blue", 36);
    svc.HudColorAlpha = 255;

    kv.GoBack(); // Welcome and Leave Messages
    kv.GoBack(); // Service Name

    return true;
}

static bool ProcessWeapons(KeyValues kv, Service svc, bool fatalError, const char[] serviceName)
{
    KeyValues tempKv = kv;
    bool usingTempKv = false;

    if (s_IsInheritOnlyPass && !CanGetKey(kv, "Advanced Weapons Menu"))
    {
        // Build the weapons menu belonging to the inherited service.
        // To do this sucks ass:
        //
        // 1) Make a new KeyValues instance so we dont corrupt the existing
        //    traversal stack.
        // 2) Repeatedly climb up the 'inheritance chain' (in case this service
        //    inherits from another inheriting-service) until we find the
        //    root inherited service that actuall contains a weapons menu.
        // 3) Build a copy of that root inherited service's "Advanced Weapons Menu"
        //    using the rest of the function.

        char path[PLATFORM_MAX_PATH];
        BuildPath(Path_SM, path, sizeof(path), CONFIG_PATH);

        KeyValues weaponKv = new KeyValues("UltraVIP - Configuration");
        if (weaponKv == null || !weaponKv.ImportFromFile(path))
        {
            delete weaponKv;
            return HandleError(svc, fatalError, "Could not create KeyValues needed to process inherited weapons menu for service \"%s\".", serviceName);
        }

        if (!FindInheritedWeaponMenu(weaponKv, serviceName)) // Jumps to "Advanced Weapons Menu"
        {
            delete weaponKv;
            return HandleError(svc, fatalError, "Failed to find the inherited weapon menu for service \"%s\"", serviceName);
        }

        tempKv = weaponKv;
        usingTempKv = true;
    }
    else if (!tempKv.JumpToKey("Advanced Weapons Menu"))
        return HandleError(svc, fatalError, "Service \"%s\" is missing section \"Advanced Weapons Menu\".", serviceName);

    svc.WeaponMenuDisplayTime = kv.GetNum("menu_display_time", 0);
    svc.ForceWeaponMenuToBuyZones = view_as<bool>(kv.GetNum("menu_block_outside_buyzone", 1));

    Menu menu;
    ArrayList weapons;

    WeaponMenu_BuildSelectionsFromConfig(tempKv, serviceName, menu, weapons);

    // Make sure handles get deleted by HandleErrorAndGoBack.
    svc.WeaponMenu = menu;
    svc.Weapons = weapons;

    if (menu == null)
        return HandleErrorAndGoBack(tempKv, svc, fatalError, "Failed to build menu for service \"%s\"", serviceName);
    if (weapons == null)
        return HandleErrorAndGoBack(tempKv, svc, fatalError, "Failed to build weapons list for service \"%s\"", serviceName);

    svc.WeaponMenu = menu;

    if (!tempKv.JumpToKey("Rifles"))
        return HandleErrorAndGoBack(tempKv, svc, fatalError, "Service \"%s\" is missing section \"Rifles\".", serviceName);

    svc.RifleWeaponsRound = GetConfigRound(tempKv, "rifles_menu_round", 3);
    svc.RifleWeaponsEnabled = view_as<bool>(tempKv.GetNum("rifles_menu_enabled", 0));

    tempKv.GoBack();

    if (!tempKv.JumpToKey("Pistols"))
        return HandleErrorAndGoBack(tempKv, svc, fatalError, "Service \"%s\" is missing section \"Pistols\".", serviceName);

    svc.PistolWeaponsRound = GetConfigRound(tempKv, "pistols_menu_round", 1);
    svc.PistolWeaponsEnabled = view_as<bool>(tempKv.GetNum("pistols_menu_enabled", 0));

    if (usingTempKv)
        delete tempKv;  // weaponKv only
    else
    {
        tempKv.GoBack(); // To "Advanced Weapons Menu"
        tempKv.GoBack(); // To service name
    }

    return true;
}

static bool FindInheritedWeaponMenu(KeyValues kv, const char[] leafServiceName)
{
    char inheritFrom[MAX_SERVICE_NAME_SIZE];
    strcopy(inheritFrom, sizeof(inheritFrom), leafServiceName);

    kv.Rewind();

    if (!kv.GotoFirstSubKey()) // To "Services"
        return false;

    int count = 0;
    while (++count)
    {
        if (count >= 99)
            return false;

        if (!kv.JumpToKey(inheritFrom)) // To service name
            return false;

        if (!IsInheritingService(kv, inheritFrom, sizeof(inheritFrom)))
        {
            // Found root--Service does not inherit from any other.
            // Go to "Advanced Weapons Menu", which should exist
            return kv.JumpToKey("Advanced Weapons Menu");
        }

        kv.GoBack(); // To "Services"
    }

    return false;
}

/**
 * Process g_Services to create 2 sorted lists ordered by Service::Priority:
 * g_SortedServiceFlags -- A sorted list of each service flag
 * g_SortedServiceOverrides -- A sorted list of each service override
 *
 * Both flags and overrides are optional so we need to make both lists
 * separately.
 *
 * @note This func must be called after loading g_Services.
 */
static bool BuildSortedLists()
{
    int len = g_Services.Length;
    ArrayList list = new ArrayList(sizeof(ServicePriorityData), len);

    for (int i = 0; i < len; ++i)
    {
        ServicePriorityData data; // Zero out each loop!

        Service svc = g_Services.Get(i);

        data.flag = svc.Flag;
        data.priority = svc.Priority;
        svc.GetOverride(data.override, sizeof(ServicePriorityData::override));

        list.SetArray(i, data, sizeof(data));
    }

    list.SortCustom(SortHighestPriority);

    g_SortedServiceFlags.Clear();
    g_SortedServiceOverrides.Clear();

    ServicePriorityData data;
    for (int i = 0; i < len; ++i)
    {
        list.GetArray(i, data, sizeof(data));

        // Both flag and override are independently optional
        if (data.flag != 0)
            g_SortedServiceFlags.Push(data.flag);
        if (data.override[0])
            g_SortedServiceOverrides.PushString(data.override);
    }

    delete list;
    return true;
}

static int SortHighestPriority(int index1, int index2, ArrayList array, Handle hndl)
{
    ServicePriorityData data1;
    ServicePriorityData data2;

    array.GetArray(index1, data1, sizeof(data1));
    array.GetArray(index2, data2, sizeof(data2));

    if (data1.priority > data2.priority)
        return -1;
    else if (data1.priority == data2.priority)
        return 0;
    return 1;
}

static bool GoBackReturnTrue(KeyValues kv)
{
    kv.GoBack();
    return true;
}

static bool HandleError(Handle &hndl, bool isFatal, const char[] fmt, any ...)
{
    int len = strlen(fmt) + 512;
    char[] formatted = new char[len];
    VFormat(formatted, len, fmt, 4);

    if (isFatal)
        SetFailState(formatted);
    else
        LogError(formatted);

    delete hndl;
    return false;
}

static bool HandleErrorAndGoBack(KeyValues kv, Service &hndl, bool isFatal, const char[] fmt, any ...)
{
    int len = strlen(fmt) + 512;
    char[] formatted = new char[len];
    VFormat(formatted, len, fmt, 5);

    if (isFatal)
        SetFailState(formatted);
    else
        LogError(formatted);

    Service_Delete(hndl);

    kv.GoBack();
    return false;
}

static int GetConfigRound(KeyValues kv, const char[] key, int defaultValue)
{
    char round[16];
    kv.GetString(key, round, sizeof(round));

    if (StrEqual(round, "WARMUP", false)
        || StrEqual(round, "WARM UP", false)
        || StrEqual(round, "WARMUP ONLY", false)
        || StrEqual(round, "WARM UP ONLY", false)
        || StrEqual(round, "WARMUP ROUND", false)
        || StrEqual(round, "WARM UP ROUND", false))
    {
        return ROUND_WARMUP_ONLY;
    }

    if (StrEqual(round, "MATCH POINT", false)
        || StrEqual(round, "MATCHPOINT", false))
    {
        return ROUND_MATCH_POINT;
    }

    if (StrEqual(round, "PISTOL", false)
        || StrEqual(round, "PISTOLS", false)
        || StrEqual(round, "PISTOL ONLY", false)
        || StrEqual(round, "PISTOLS ONLY", false)
        || StrEqual(round, "PISTOL ROUND", false)
        || StrEqual(round, "PISTOLS ROUND", false))
    {
        return ROUND_PISTOL;
    }

    if (StrEqual(round, "LAST OF HALF", false))
        return ROUND_LAST_OF_HALF;

    int value = kv.GetNum(key, defaultValue);
    if (value < 0)
        value = INVALID_ROUND;

    return value;
}
