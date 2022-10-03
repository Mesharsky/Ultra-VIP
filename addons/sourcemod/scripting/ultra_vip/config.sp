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

#pragma newdecls required
#pragma semicolon 1

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

#define ONLINE_CMD_SEPARATOR ";"
#define ONLINE_CMD_STRING_MAXLENGTH 512

// Struct used purely for sorting purposes in BuildFlagsList()
enum struct FlagPriority
{
    int flag;
    int priority;
}

static void ResetAllServices()
{
    g_SortedServiceFlags.Clear();
    s_UsedServiceFlags = 0;

    delete g_SteamIDServices;
    g_SteamIDServices = new StringMap();

    int len = g_Services.Length;
    for(int i = 0; i < len; ++i)
    {
        Service svc = g_Services.Get(i);
        Service_Delete(svc);
    }
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

bool LoadConfig(bool fatalError = true)
{
    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), "configs/ultra_vip_main.cfg");

    KeyValues kv = new KeyValues("UltraVIP - Configuration");
    if (!kv.ImportFromFile(path))
        return HandleError(kv, fatalError, "Cannot find config file: %s", path);

    ResetAllServices();

    if (!kv.JumpToKey("Services"))
        return HandleError(kv, fatalError, "Missing \"Services\" section in config file.");

    if (!kv.GotoFirstSubKey())
        return HandleError(kv, fatalError, "There are no valid services in the config.");

    char serviceName[MAX_SERVICE_NAME_SIZE];
    do
    {
        kv.GetSectionName(serviceName, sizeof(serviceName));

        if (!IsServiceEnabled(kv))
            continue;

        Service svc = new Service(serviceName);

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
    }
    while (kv.GotoNextKey());

    // Get global config *after* getting services so it's not set unless all
    // services are valid, which is both safer and required for "root_service"
    if (!GetGlobalConfiguration(kv, fatalError))
    {
        ResetAllServices();
        return false;
    }

    delete kv;

    if (!BuildSortedFlagList())
    {
        ResetAllServices();
        return false;
    }

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

static bool IsServiceEnabled(KeyValues kv)
{
    if (!kv.JumpToKey("Main Configuration"))
        return false;

    bool result = view_as<bool>(kv.GetNum("service_enabled", 0));
    kv.GoBack();
    return result;
}

static bool ProcessMainConfiguration(KeyValues kv, Service svc, bool fatalError, const char[] serviceName)
{
    if (!kv.JumpToKey("Main Configuration"))
        return HandleError(svc, fatalError, "Service \"%s\" is missing section \"Main Configuration\".", serviceName);

    char buffer[128];

    kv.GetString("flag", buffer, sizeof(buffer));
    int flag = ReadFlagString(buffer);
    if (!HasOnlySingleBit(flag))
        return HandleErrorAndGoBack(kv, svc, fatalError, "Service \"%s\" is not allowed to have multiple admin flags.", serviceName);
    if (s_UsedServiceFlags & flag)
        return HandleErrorAndGoBack(kv, svc, fatalError, "Service \"%s\" is using an already-assigned admin flag '%s'", serviceName, buffer);
    if (flag & ADMFLAG_ROOT)
        return HandleErrorAndGoBack(kv, svc, fatalError, "Service \"%s\" is not allowed to have the ROOT flag (z). Use \"root_service\" instead.", serviceName);

    svc.Flag = flag;
    // s_UsedServiceFlags is updated when the service is pushed to g_Services

    svc.Priority = kv.GetNum("priority", 0);

    kv.GetString("override", buffer, sizeof(buffer));
    if (buffer[0])
        svc.SetOverride(buffer);

    kv.GetString("chat_tag", buffer, sizeof(buffer));
    if (buffer[0])
        svc.SetChatTag(buffer);

    kv.GetString("chat_name_color", buffer, sizeof(buffer));
    if (buffer[0])
        svc.SetChatNameColor(buffer);

    kv.GetString("chat_message_color", buffer, sizeof(buffer));
    if (buffer[0])
        svc.SetChatMsgColor(buffer);

    kv.GetString("scoreboard_tag", buffer, sizeof(buffer));
    if (buffer[0])
        svc.SetScoreboardTag(buffer);

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
    if (!kv.JumpToKey("SteamID Access"))
        return HandleErrorAndGoBack(kv, svc, fatalError, "Service \"%s\" is missing secttion \"SteamID Access\".", serviceName);

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
        return HandleError(svc, fatalError, "Service \"%s\" is missing section \"Player Spawn Bonuses\".", serviceName);

    svc.BonusPlayerHealth = kv.GetNum("player_hp", 105);
    svc.BonusPlayerHealthRound = kv.GetNum("player_hp_round", 1);
    svc.BonusMaxPlayerHealth = kv.GetNum("player_max_hp", 110);

    svc.BonusArmorEnabled = view_as<bool>(kv.GetNum("player_vest", 1));
    svc.BonusArmor = kv.GetNum("player_vest_value", 100);
    svc.BonusArmorRound = kv.GetNum("player_vest_round", 2);

    svc.BonusHelmetEnabled = view_as<bool>(kv.GetNum("player_helmet", 1));
    svc.BonusHelmetRound = kv.GetNum("player_helmet_round", 2);

    svc.BonusDefuserEnabled = view_as<bool>(kv.GetNum("player_defuser", 1));
    svc.BonusDefuserRound = kv.GetNum("player_defuser_round", 2);

    kv.GoBack(); // To service name
    return true;
}

static bool ProcessPlayerGrenadesOnSpawn(KeyValues kv, Service svc, bool fatalError, const char[] serviceName)
{
    if (!kv.JumpToKey("Grenades On Spawn"))
        return HandleError(svc, fatalError, "Service \"%s\" is missing section \"Grenades On Spawn\".", serviceName);

    svc.ShouldStripConsumables = view_as<bool>(kv.GetNum("strip_grenades", 0));
    svc.BonusHEGrenades = kv.GetNum("he_amount", 1);
    svc.BonusHEGrenadesRound = kv.GetNum("he_round", 1);
    svc.BonusFlashGrenades = kv.GetNum("flash_amount", 1);
    svc.BonusFlashGrenadesRound = kv.GetNum("flash_round", 1);
    svc.BonusSmokeGrenades = kv.GetNum("smoke_amount", 1);
    svc.BonusSmokeGrenadesRound = kv.GetNum("smoke_round", 1);
    svc.BonusDecoyGrenades = kv.GetNum("decoy_amount", 0);
    svc.BonusDecoyGrenadesRound = kv.GetNum("decoy_round", 1);
    svc.BonusMolotovGrenades = kv.GetNum("molotov_amount", 0);
    svc.BonusMolotovGrenadesRound = kv.GetNum("molotov_round", 1);
    svc.BonusHealthshotGrenades = kv.GetNum("healthshot_amount", 0);
    svc.BonusHealthshotGrenadesRound = kv.GetNum("healthshot_round", 3);
    svc.BonusTacticalGrenades = kv.GetNum("tag_amount", 0);
    svc.BonusTacticalGrenadesRound = kv.GetNum("tag_round", 1);
    svc.BonusSnowballGrenades = kv.GetNum("snowball_amount", 0);
    svc.BonusSnowballGrenadesRound = kv.GetNum("snowball_round", 1);
    svc.BonusBreachchargeGrenades = kv.GetNum("breachcharge_amount", 0);
    svc.BonusBreachchargeGrenadesRound = kv.GetNum("breachcharge_round", 1);
    svc.BonusBumpmineGrenades = kv.GetNum("bumpmine_amount", 0);
    svc.BonusBumpmineGrenadesRound = kv.GetNum("bumpmine_round", 1);

    kv.GoBack(); // To service name
    return true;
}

static bool ProcessSpecialBonuses(KeyValues kv, Service svc, bool fatalError, const char[] serviceName)
{
    if (!kv.JumpToKey("Special Bonuses"))
        return HandleError(svc, fatalError, "Service \"%s\" is missing section \"Special Bonuses\".", serviceName);

    svc.BonusExtraJumps = kv.GetNum("player_extra_jumps", 1);
    svc.BonusJumpHeight = kv.GetFloat("player_extra_jump_height", EXTRAJUMP_DEFAULT_HEIGHT);
    svc.BonusExtraJumpsRound = kv.GetNum("player_extra_jumps_round", 1);
    svc.BonusExtraJumpsTakeFallDamage = view_as<bool>(kv.GetNum("player_extra_jumps_falldamage", 1));

    svc.BonusPlayerShield = view_as<bool>(kv.GetNum("player_shield", 0));
    svc.BonusPlayerShieldRound = kv.GetNum("player_shield_round", 1);

    svc.BonusPlayerGravity = kv.GetFloat("player_gravity", 1.0);
    svc.BonusPlayerGravityRound = kv.GetNum("player_gravity_round", 1);

    svc.BonusPlayerSpeed = kv.GetFloat("player_speed", 1.0);
    svc.BonusPlayerSpeedRound = kv.GetNum("player_speed_round", 1);

    svc.BonusPlayerVisibility = kv.GetNum("player_visibility", 255);
    svc.BonusPlayerVisibilityRound = kv.GetNum("player_visibility_round", 1);

    svc.BonusPlayerRespawnPercent = kv.GetNum("player_respawn_percent", 0);
    svc.BonusPlayerRespawnPercentRound = kv.GetNum("player_respawn_round", 3);
    svc.BonusPlayerRespawnPercentNotify = view_as<bool>(kv.GetNum("player_respawn_notify", 0));

    svc.BonusPlayerFallDamagePercent = kv.GetNum("player_fall_damage_percent", 100);
    svc.BonusPlayerFallDamagePercentRound = kv.GetNum("player_fall_damage_round", 1);

    svc.BonusPlayerAttackDamage = kv.GetNum("player_attack_damage", 100);
    svc.BonusPlayerAttackDamageRound = kv.GetNum("player_attack_damage_round", 3);

    svc.BonusPlayerDamageResist = kv.GetNum("player_damage_resist", 0);
    svc.BonusPlayerDamageResistRound = kv.GetNum("player_damage_resist_round", 3);

    svc.BonusUnlimitedAmmo = view_as<bool>(kv.GetNum("player_unlimited_ammo", 0));
    svc.BonusUnlimitedAmmoRound = kv.GetNum("player_unlimited_ammo_round", 1);

    kv.GoBack(); // Service name
    return true;
}

static bool ProcessEventMoneyBonuses(KeyValues kv, Service svc, bool fatalError, const char[] serviceName)
{
    if (!kv.JumpToKey("Events Bonuses"))
        return HandleError(svc, fatalError, "Service \"%s\" is missing section \"Events Bonuses\".", serviceName);

    if (!kv.JumpToKey("Money"))
        return HandleErrorAndGoBack(kv, svc, fatalError, "Service \"%s\" is missing section \"Money\".", serviceName);

    svc.BonusSpawnMoney = kv.GetNum("spawn_bonus", 0);
    svc.BonusSpawnMoneyRound = kv.GetNum("spawn_bonus_round", 1);
    svc.BonusSpawnMoneyNotify = view_as<bool>(kv.GetNum("spawn_bonus_chat", 0));

    svc.BonusKillMoney = kv.GetNum("kill_bonus", 0);
    svc.BonusKillMoneyRound = kv.GetNum("kill_bonus_round", 1);
    svc.BonusKillMoneyNotify = view_as<bool>(kv.GetNum("kill_bonus_chat", 0));

    svc.BonusAssistMoney = kv.GetNum("assist_bonus", 0);
    svc.BonusAssistMoneyRound = kv.GetNum("assist_bonus_round", 1);
    svc.BonusAssistMoneyNotify = view_as<bool>(kv.GetNum("assist_bonus_chat", 0));

    svc.BonusHeadshotMoney = kv.GetNum("headshot_bonus", 0);
    svc.BonusHeadshotMoneyRound = kv.GetNum("headshot_bonus_round", 1);
    svc.BonusHeadshotMoneyNotify = view_as<bool>(kv.GetNum("headshot_bonus_chat", 0));

    svc.BonusKnifeMoney = kv.GetNum("knife_bonus", 0);
    svc.BonusKnifeMoneyRound = kv.GetNum("knife_bonus_round", 1);
    svc.BonusKnifeMoneyNotify = view_as<bool>(kv.GetNum("knife_bonus_chat", 0));

    svc.BonusZeusMoney = kv.GetNum("zeus_bonus", 0);
    svc.BonusZeusMoneyRound = kv.GetNum("zeus_bonus_round", 1);
    svc.BonusZeusMoneyNotify = view_as<bool>(kv.GetNum("zeus_bonus_chat", 0));

    svc.BonusGrenadeMoney = kv.GetNum("grenade_bonus", 0);
    svc.BonusGrenadeMoneyRound = kv.GetNum("grenade_bonus_round", 1);
    svc.BonusGrenadeMoneyNotify = view_as<bool>(kv.GetNum("grenade_bonus_chat", 0));

    svc.BonusMvpMoney = kv.GetNum("mvp_bonus", 0);
    svc.BonusMvpMoneyRound = kv.GetNum("mvp_bonus_round", 1);
    svc.BonusMvpMoneyNotify = view_as<bool>(kv.GetNum("mvp_bonus_chat", 0));

    svc.BonusNoscopeMoney = kv.GetNum("noscope_bonus", 0);
    svc.BonusNoscopeMoneyRound = kv.GetNum("noscope_bonus_round", 1);
    svc.BonusNoscopeMoneyNotify = view_as<bool>(kv.GetNum("noscope_bonus_chat", 0));

    svc.BonusHostageMoney = kv.GetNum("hostage_bonus", 0);
    svc.BonusHostageMoneyRound = kv.GetNum("hostage_bonus_round", 1);
    svc.BonusHostageMoneyNotify = view_as<bool>(kv.GetNum("hostage_bonus_chat", 0));

    svc.BonusBombPlantedMoney = kv.GetNum("bomb_planted_bonus", 0);
    svc.BonusBombPlantedMoneyRound = kv.GetNum("bomb_planted_bonus_round", 1);
    svc.BonusBombPlantedMoneyNotify = view_as<bool>(kv.GetNum("bomb_planted_bonus_chat", 0));

    svc.BonusBombDefusedMoney = kv.GetNum("bomb_defused_bonus", 0);
    svc.BonusBombDefusedMoneyRound = kv.GetNum("bomb_defused_bonus_round", 1);
    svc.BonusBombDefusedMoneyNotify = view_as<bool>(kv.GetNum("bomb_defused_bonus_chat", 0));

    kv.GoBack(); // Events Bonuses
    kv.GoBack(); // Service Name
    return true;
}

static bool ProcessEventHPBonuses(KeyValues kv, Service svc, bool fatalError, const char[] serviceName)
{
    if (!kv.JumpToKey("Events Bonuses"))
        return HandleError(svc, fatalError, "Service \"%s\" is missing section \"Events Bonuses\".", serviceName);

    if (!kv.JumpToKey("Bonus Health"))
        return HandleErrorAndGoBack(kv, svc, fatalError, "Service \"%s\" is missing section \"Bonus Health\".", serviceName);

    svc.BonusKillHP = kv.GetNum("kill_hp_bonus", 0);
    svc.BonusKillHPRound = kv.GetNum("kill_hp_bonus_round", 1);
    svc.BonusKillHPNotify = view_as<bool>(kv.GetNum("kill_hp_bonus_chat", 0));

    svc.BonusAssistHP = kv.GetNum("assist_hp_bonus", 0);
    svc.BonusAssistHPRound = kv.GetNum("assist_hp_bonus_round", 1);
    svc.BonusAssistHPNotify = view_as<bool>(kv.GetNum("assist_hp_bonus_chat", 0));

    svc.BonusHeadshotHP = kv.GetNum("headshot_hp_bonus", 0);
    svc.BonusHeadshotHPRound = kv.GetNum("headshot_hp_bonus_round", 1);
    svc.BonusHeadshotHPNotify = view_as<bool>(kv.GetNum("headshot_hp_bonus_chat", 0));

    svc.BonusKnifeHP = kv.GetNum("knife_hp_bonus", 0);
    svc.BonusKnifeHPRound = kv.GetNum("knife_hp_bonus_round", 1);
    svc.BonusKnifeHPNotify = view_as<bool>(kv.GetNum("knife_hp_bonus_chat", 0));

    svc.BonusZeusHP = kv.GetNum("zeus_hp_bonus", 0);
    svc.BonusZeusHPRound = kv.GetNum("zeus_hp_bonus_round", 1);
    svc.BonusZeusHPNotify = view_as<bool>(kv.GetNum("zeus_hp_bonus_chat", 0));

    svc.BonusGrenadeHP = kv.GetNum("grenade_hp_bonus", 0);
    svc.BonusGrenadeHPRound = kv.GetNum("grenade_hp_bonus_round", 1);
    svc.BonusGrenadeHPNotify = view_as<bool>(kv.GetNum("grenade_hp_bonus_chat", 0));

    svc.BonusNoscopeHP = kv.GetNum("noscope_hp_bonus", 0);
    svc.BonusNoscopeHPRound = kv.GetNum("noscope_hp_bonus_round", 1);
    svc.BonusNoscopeHPNotify = view_as<bool>(kv.GetNum("noscope_hp_bonus_chat", 0));

    kv.GoBack(); // Events Bonuses
    kv.GoBack(); // Service name
    return true;
}

static bool ProcessChatWelcomeLeaveMessages(KeyValues kv, Service svc, bool fatalError, const char[] serviceName)
{
    if (!kv.JumpToKey("Welcome and Leave Messages"))
        return HandleError(svc, fatalError, "Service \"%s\" is missing section \"Welcome and Leave Messages\".", serviceName);

    if (!kv.JumpToKey("Chat"))
        return HandleErrorAndGoBack(kv, svc, fatalError, "Service \"%s\" is missing section \"Chat\".", serviceName);

    char buffer[256];

    svc.ChatWelcomeMessage = view_as<bool>(kv.GetNum("chat_join_msg_enable", 1));

    kv.GetString("chat_join_msg", buffer, sizeof(buffer));
    if (buffer[0])
        svc.SetChatWelcomeMessage(buffer);

    svc.ChatLeaveMessage = view_as<bool>(kv.GetNum("chat_leave_msg_enable", 1));

    kv.GetString("chat_leave_msg", buffer, sizeof(buffer));
    if (buffer[0])
        svc.SetChatLeaveMessage(buffer);

    kv.GoBack(); // Welcome and Leave Messages
    kv.GoBack(); // Service Name
    return true;
}

static bool ProcessHudWelcomeLeaveMessages(KeyValues kv, Service svc, bool fatalError, const char[] serviceName)
{
    if (!kv.JumpToKey("Welcome and Leave Messages"))
        return HandleError(svc, fatalError, "Service \"%s\" is missing section \"Welcome and Leave Messages\".", serviceName);

    if (!kv.JumpToKey("Hud"))
        return HandleErrorAndGoBack(kv, svc, fatalError, "Service \"%s\" is missing section \"Hud\".", serviceName);

    char buffer[256];

    svc.HudWelcomeMessage = view_as<bool>(kv.GetNum("hud_leave_msg_enable", 0));

    kv.GetString("hud_join_msg", buffer, sizeof(buffer));
    if (buffer[0])
        svc.SetHudWelcomeMessage(buffer);

    svc.HudLeaveMessage = view_as<bool>(kv.GetNum("hud_leave_msg_enable", 0));

    kv.GetString("hud_leave_msg", buffer, sizeof(buffer));
    if (buffer[0])
        svc.SetHudLeaveMessage(buffer);

    svc.HudPositionX = kv.GetFloat("hud_position_x", -1.0);
    svc.HudPositionY = kv.GetFloat("hud_position_y", -0.7);
    svc.HudColorRed = kv.GetNum("hud_color_red", 243);
    svc.HudColorGreen = kv.GetNum("hud_color_green", 200);
    svc.HudColorBlue = kv.GetNum("hud_color_blue", 36);
    svc.HudColorAlpha = 255;

    kv.GoBack(); // Welcome and Leave Messages
    kv.GoBack(); // Service Name

    return true;
}

static bool ProcessWeapons(KeyValues kv, Service svc, bool fatalError, const char[] serviceName)
{
    if (!kv.JumpToKey("Advanced Weapons Menu"))
        return HandleError(svc, fatalError, "Service \"%s\" is missing section \"Advanced Weapons Menu\".", serviceName);

    Menu menu;
    ArrayList weapons;

    WeaponMenu_BuildSelectionsFromConfig(kv, serviceName, menu, weapons);

    // Make sure handles get deleted by HandleErrorAndGoBack.
    svc.WeaponMenu = menu;
    svc.Weapons = weapons;

    if (menu == null)
        return HandleErrorAndGoBack(kv, svc, fatalError, "Failed to build menu for service \"%s\"", serviceName);
    if (weapons == null)
        return HandleErrorAndGoBack(kv, svc, fatalError, "Failed to build weapons list for service \"%s\"", serviceName);

    svc.WeaponMenu = menu;

    if (!kv.JumpToKey("Rifles"))
        return HandleErrorAndGoBack(kv, svc, fatalError, "Service \"%s\" is missing section \"Rifles\".", serviceName);

    svc.RifleWeaponsRound = kv.GetNum("rifles_menu_round", 3);
    svc.RifleWeaponsEnabled = view_as<bool>(kv.GetNum("rifles_menu_enabled", 0));

    kv.GoBack();

    if (!kv.JumpToKey("Pistols"))
        return HandleErrorAndGoBack(kv, svc, fatalError, "Service \"%s\" is missing section \"Pistols\".", serviceName);

    svc.PistolWeaponsRound = kv.GetNum("pistols_menu_round", 1);
    svc.PistolWeaponsEnabled = view_as<bool>(kv.GetNum("pistols_menu_enabled", 0));

    kv.GoBack(); // To "Advanced Weapons Menu"
    kv.GoBack(); // To service name
    return true;
}

/**
 * Set g_SortedServiceFlags to a list of each Service flag (from g_Services)
 * sorted by the Service priority.
 */
static bool BuildSortedFlagList()
{
    // This func must be called after loading g_Services

    int len = g_Services.Length;

    ArrayList list = new ArrayList(sizeof(FlagPriority), len);

    Service svc;
    FlagPriority data;

    for (int i = 0; i < len; ++i)
    {
        svc = g_Services.Get(i);

        data.flag = svc.Flag;
        data.priority = svc.Priority;

        list.SetArray(i, data, sizeof(data));
    }

    list.SortCustom(SortHighestFlagPriority);

    delete g_SortedServiceFlags;
    g_SortedServiceFlags = new ArrayList(1, len);

    for (int i = 0; i < len; ++i)
    {
        list.GetArray(i, data, sizeof(data));
        g_SortedServiceFlags.Set(i, data.flag);
    }

    delete list;
    return true;
}

int SortHighestFlagPriority(int index1, int index2, ArrayList array, Handle hndl)
{
    FlagPriority data1;
    FlagPriority data2;

    array.GetArray(index1, data1, sizeof(data1));
    array.GetArray(index2, data2, sizeof(data2));

    if (data1.priority > data2.priority)
        return -1;
    else if (data1.priority == data2.priority)
        return 0;
    return 1;
}
