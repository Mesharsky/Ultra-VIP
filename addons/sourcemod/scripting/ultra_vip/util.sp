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

Service FindServiceByName(const char[] name)
{
    char buffer[MAX_SERVICE_NAME_SIZE];

    int len = g_Services.Length;
    for (int i = 0; i < len; ++i)
    {
        Service svc = g_Services.Get(i);
        svc.GetName(buffer, sizeof(buffer));

        if (StrEqual(name, buffer))
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

bool FloatEqual(float a, float b)
{
    float sum = a + b;
    float product = a * b;
    return (sum - product) < 0.00001; // Minimum value of FLT_EPSILON in C Standard
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
    if (GetClientTeam(client) == CS_TEAM_CT)
        return false;
    if (GetEntProp(client, Prop_Send, "m_bHasDefuser"))
        return false;

    return true;
}

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
    int maxWeapons = GetEntPropArraySize(client, Prop_Send, "m_hMyWeapons");
    for (int i = 0; i < maxWeapons; i++)
    {
        int weapon = GetEntPropEnt(client, Prop_Send, "m_hMyWeapons", i);
        if (weapon != -1)
        {
            int def = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
            if (CS_ItemDefIndexToID(def) == wepid)
                return weapon;
        }
    }

    return -1;
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
