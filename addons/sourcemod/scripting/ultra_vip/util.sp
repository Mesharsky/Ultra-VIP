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

Service FindServiceByName(const char[] name, bool caseSensitive=true)
{
    char buffer[MAX_SERVICE_NAME_SIZE];

    int len = g_Services.Length;
    for (int i = 0; i < len; ++i)
    {
        Service svc = g_Services.Get(i);
        svc.GetName(buffer, sizeof(buffer));

        if (StrEqual(name, buffer, caseSensitive))
            return svc;
    }

    return null;
}

bool HasOnlySingleBit(int value)
{
    if (!value)
        return false;

    // is value a power of 2
    return (value & (value - 1)) == 0;
}

void SplitIntoStringMap(StringMap output, const char[] str, const char[] split, any value = 0)
{
    int len = strlen(str) + 1;
    char[] buffer = new char[len];

    int index;
    int searchIndex;
    while ((index = SplitString(str[searchIndex], split, buffer, len)) != -1)
    {
        searchIndex += index;
        output.SetValue(buffer, value);
    }

    // If string does not end in split, copy remainder into StringMap
    // So "a;b;" and "a;b" both work the same, and "a" alone works too.
    if (!StrEndsWith(str, split))
    {
        strcopy(buffer, len, str[searchIndex]);
        if (buffer[0])
            output.SetValue(buffer, value);
    }
}

bool StrEndsWith(const char[] str, const char[] ending, bool caseSensitive = true)
{
    int len = strlen(str);
    int endLen = strlen(ending);
    if (endLen > len)
        return false;

    int start = len - endLen;
    return strcmp(str[start], ending, caseSensitive) == 0;
}

int NStringToInt(const char[] str, int length, int base = 10)
{
    length += 1;

    char[] buffer = new char[length];
    strcopy(buffer, length, str);

    return StringToInt(buffer, base);
}

bool FloatEqual(float A, float B, float maxRelDiff = 0.00001)
{
    // Calculate the difference.
    float diff = FloatAbs(A - B);
    A = FloatAbs(A);
    B = FloatAbs(B);
    // Find the largest
    float largest = (B > A) ? B : A;

    if (diff <= largest * maxRelDiff)
        return true;
    return false;
}

stock bool ClientsAreTeammates(int clientA, int clientB)
{
    if (clientA < 1 || clientA > MaxClients)
        return false;
    if (clientB < 1 || clientB > MaxClients)
        return false;
    if (!IsClientInGame(clientA) || !IsClientInGame(clientB))
        return false;

    if (g_IsDeathmatchMode)
        return false;
    return GetClientTeam(clientA) == GetClientTeam(clientB);
}

void RemovePlayerMoney(int client, int amount)
{
    int money = GetEntProp(client, Prop_Send, "m_iAccount");

    money -= amount;
    SetEntProp(client, Prop_Send, "m_iAccount", money);
}

bool CanGiveDefuser(int client)
{
    if (!IsClientInGame(client) || !IsPlayerAlive(client))
        return false;
    if (GetClientTeam(client) != CS_TEAM_CT)
        return false;
    if (GetEntProp(client, Prop_Send, "m_bHasDefuser"))
        return false;

    return true;
}

/**
 * Set a player's opacity/alpha.
 * sv_disable_immunity_alpha 1 is required for this to work.
 */
void SetPlayerVisibility(int client, int alpha)
{
    if (alpha >= 255)
    {
        alpha = 255;
        SetEntityRenderMode(client, RENDER_NORMAL);
    }
    else if (alpha <= 0)
    {
        alpha = 0;
        SetEntityRenderMode(client, RENDER_NONE);
    }
    else
        SetEntityRenderMode(client, RENDER_TRANSCOLOR);

    SetEntityRenderColorEx(client, -1, -1, -1, alpha);
}

/**
 * Modified SetEntityRenderColor that allows optional colour channels, preserving
 * the existing values.
 */
stock void SetEntityRenderColorEx(int entity, int r=-1, int g=-1, int b=-1, int a=-1)
{
    static bool gotconfig = false;
    static char prop[32];

    if (!gotconfig)
    {
        GameData gc = new GameData("core.games");
        bool exists = gc.GetKeyValue("m_clrRender", prop, sizeof(prop));
        delete gc;

        if (!exists)
            strcopy(prop, sizeof(prop), "m_clrRender");

        gotconfig = true;
    }

    int offset = GetEntSendPropOffs(entity, prop);

    if (offset <= 0)
        ThrowError("SetEntityRenderColor not supported by this mod");

    if (r > -1)
        SetEntData(entity, offset, r, 1, true);
    if (g > -1)
        SetEntData(entity, offset + 1, g, 1, true);
    if (b > -1)
        SetEntData(entity, offset + 2, b, 1, true);
    if (a > -1)
        SetEntData(entity, offset + 3, a, 1, true);
}

void SetPlayerHealth(int client, int value, Service svc)
{
    int max = svc.BonusMaxPlayerHealth;
    if (value > max)
        value = max;

    SetEntityHealth(client, value);
}

int GetClientMoney(int client)
{
    return GetEntProp(client, Prop_Send, "m_iAccount");
}

void SetClientMoney(int client, int value)
{
    SetEntProp(client, Prop_Send, "m_iAccount", value);
}

void SetPlayerScoreBoardTag(int client, Service svc)
{
    char buffer[32];
    svc.GetScoreboardTag(buffer, sizeof(buffer));

    if(buffer[0])
        CS_SetClientClanTag(client, buffer);
}


int GetPlayerWeapon(int client, CSWeaponID wepid)
{
    if (wepid == CSWeapon_NONE)
        return -1;

    int maxWeapons = GetEntPropArraySize(client, Prop_Send, "m_hMyWeapons");
    for (int i = 0; i < maxWeapons; i++)
    {
        int weapon = GetEntPropEnt(client, Prop_Send, "m_hMyWeapons", i);
        if (GetWeaponEntityID(weapon) == wepid)
            return weapon;
    }

    return -1;
}

CSWeaponID GetWeaponEntityID(int weapon)
{
    if (weapon <= MaxClients)
        return CSWeapon_NONE;

    int def = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
    return CS_ItemDefIndexToID(def);
}

void GivePlayerUnlimitedAmmo(int client, int weapon)
{
    char classname[32];
    GetEdictClassname(weapon, classname, sizeof(classname));

    if (!IsPlayerAlive(client))
        return;

    if (weapon > 0 && (weapon == GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY) || weapon == GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY)))
    {
        if (StrContains(classname, "weapon_", false) != -1)
        {
            SetEntProp(weapon, Prop_Send, "m_iClip1", 32);
            SetEntProp(weapon, Prop_Send, "m_iClip2", 32);
        }
    }
}

bool IsWeaponKnife(const char[] classname)
{
    if (StrContains(classname, "knife", false) != -1 || StrContains(classname, "bayonet", false) != -1)
        return true;

    return false;
}

bool IsWeaponTaser(const char[] classname)
{
    return StrContains(classname, "taser") != -1;
}

bool IsWeaponGrenade(const char[] classname)
{
    if (StrContains(classname, "hegrenade", false) != -1
        || StrContains(classname, "smokegrenade", false) != -1
        || StrContains(classname, "flashbang", false) != -1
        || StrContains(classname, "decoy", false) != -1
        || StrContains(classname, "molotov", false) != -1
        || StrContains(classname, "incgrenade", false) != -1
        || StrContains(classname, "breachcharge", false) != -1
        || StrContains(classname, "bumpmine", false) != -1
        || StrContains(classname, "snowball", false) != -1
        || StrContains(classname, "tagrenade", false) != -1)
    {
        return true;
    }
    return false;
}

int GetCSTeamFromString(const char[] team)
{
    // ugly but works!
    int len = strlen(team) + 1;

    char[] buffer = new char[len];

    strcopy(buffer, len, team);
    TrimString(buffer);

    if(StrEqual(team, "CT", false))
        return CS_TEAM_CT;

    if(StrEqual(team, "Counter-Terrorist", false))
        return CS_TEAM_CT;

    if(StrEqual(team, "Counter-Terrorists", false))
        return CS_TEAM_CT;

    if(StrEqual(team, "Counter Terrorist", false))
        return CS_TEAM_CT;

    if(StrEqual(team, "Counter Terrorists", false))
        return CS_TEAM_CT;

    if(StrEqual(team, "TT", false))
        return CS_TEAM_T;

    if(StrEqual(team, "T", false))
        return CS_TEAM_T;

    if(StrEqual(team, "Terrorist", false))
        return CS_TEAM_T;

    if(StrEqual(team, "Terrorists", false))
        return CS_TEAM_T;

    return CS_TEAM_NONE;
}


int GivePlayerWeapon(int client, const char[] classname, int stripSlot = -1)
{
    StripPlayerWeapon(client, stripSlot);
    return GivePlayerItem(client, classname);
}

void StripPlayerWeapon(int client, int slot = -1)
{
    if (slot == -1)
        return;

    int weapon;

    for(int i = 0; i < 2; i++)
    {
        while ((weapon = GetPlayerWeaponSlot(client, slot)) != -1)
        {
            RemovePlayerItem(client, weapon);
            AcceptEntityInput(weapon, "Kill");
        }
    }
}

void PurchaseWeapon(int client, WeaponMenuItem item, int slot, bool strip=true)
{
    GivePlayerWeapon(client, item.classname, (strip) ? slot : -1);
    RemovePlayerMoney(client, item.price);
}

/**
 * Get the account number from a SteamID2 or SteamID3
 */
int GetAccountFromSteamID(const char[] steamId)
{
    // TODO: Make this less janky with regex?
    // Is the performance cost worth it?

    int len = strlen(steamId);

    // SteamID2
    if (StrContains(steamId, "STEAM_") == 0 && len >= 11)
    {
        // Extract Y
        char c[2];
        c[0] = steamId[8];
        int y = StringToInt(c);

        // Skip "STEAM_0:1:"
        return (StringToInt(steamId[10]) << 1) + y;
    }

    // SteamID3
    if (len >= 7
        && steamId[0] == '['
        && steamId[2] == ':'
        && steamId[4] == ':')
    {
        // Skip "[U:1:", StringToInt should ignore the last ']'
        return StringToInt(steamId[5]);
    }

    return 0;
}

bool IsOnPlayingTeam(int client)
{
    int team = GetClientTeam(client);
    return team == CS_TEAM_CT || team == CS_TEAM_T;
}

bool IsWarmup()
{
    return GameRules_GetProp("m_bWarmupPeriod") != 0;
}

bool HasAdminFlagAccess(int flag, int flags)
{
    return flag & flags || flags & ADMFLAG_ROOT;
}

int GetClientAdminGroupCount(int client)
{
    AdminId id = GetUserAdmin(client);
    if (id == INVALID_ADMIN_ID)
        return 0;

    return GetAdminGroupCount(id);
}

any _MAX(any a, any b)
{
    return a > b ? a : b;
}

void NormaliseString(char[] str)
{
    TrimString(str);
    for (int i = 0; str[i] != '\0'; ++i)
        str[i] = CharToLower(str[i]);
}

/**
 * StringToIntEx(), but the entire string must be a valid integer.
 * Input string must contain no whitespace.
 *
 * StringToIntEx wont return 0 for invalid numbers like "90a4",
 * it will instead output the value "90".
 */
stock bool StringToIntStrict(const char[] str, int &result, int nBase=10)
{
    int temp;
    int len = strlen(str);
    if (StringToIntEx(str, temp, nBase) != len)
        return false;
    result = temp;
    return true;
}

/**
 * StringToFloatEx(), but the entire string must be a valid float.
 * Input string must contain no whitespace.
 *
 * StringToFloatEx wont return 0 for invalid numbers like "9.0a4",
 * it will instead output the value "9.0".
 */
stock bool StringToFloatStrict(const char[] str, float &result)
{
    float temp;
    int len = strlen(str);
    if (StringToFloatEx(str, temp) != len)
        return false;
    result = temp;
    return true;
}


/**
 * Used for SM 1.10 compatibility instead of using OnNotifyPluginUnloaded
 */
stock bool IsPluginLoaded(Handle plugin)
{
    PluginIterator it = new PluginIterator();
    while (it.Next())
    {
        if (it.Plugin == plugin)
        {
            delete it;
            return true;
        }
    }

    delete it;
    return false;
}
