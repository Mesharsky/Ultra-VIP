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

public void Event_RoundStart(Event event, const char[] name, bool bDontBroadcast)
{

}

public void Event_PlayerSpawn(Event event, const char[] name, bool bDontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    Service svc = GetClientService(client);

    // It must run every single spawn.
    ExtraJump_OnPlayerSpawn(client, svc);

    if (svc == null)
        return;    

    SetPlayerScoreBoardTag(client, svc);

    if (IsRoundAllowed(svc.BonusPlayerHealthRound))
        SetPlayerHealth(client, svc.BonusPlayerHealth, svc);

    if(svc.BonusArmorEnabled && IsRoundAllowed(svc.BonusArmorRound))
        SetEntProp(client, Prop_Send, "m_ArmorValue", svc.BonusArmorValue);

    if(svc.BonusHelmetEnabled && IsRoundAllowed(svc.BonusHelmetRound))
        SetEntProp(client, Prop_Send, "m_bHasHelmet", 1);

    if (svc.BonusDefuserEnabled && IsRoundAllowed(svc.BonusDefuserRound) && CanGiveDefuser(client))
        GivePlayerItem(client, "item_defuser");

    if (IsRoundAllowed(svc.BonusPlayerGravityRound))
    {
        float value = svc.BonusPlayerGravity;
        if (!FloatEqual(value, 1.0))
            SetEntityGravity(client, value);
    }

    if (IsRoundAllowed(svc.BonusPlayerSpeedRound))
    {
        float value = svc.BonusPlayerSpeed;
        if(!FloatEqual(value, 1.0))
            SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", value);
    }

    if (IsRoundAllowed(svc.BonusPlayerVisibilityRound))
    {
        int value = svc.BonusPlayerVisibility;
        if(value != 255)
            SetPlayerVisibility(client, value);
    }    

    if(IsRoundAllowed(svc.BonusSpawnMoneyRound))
    {
        int value = svc.BonusSpawnMoney;
        SetClientMoney(client, GetClientMoney(client) + value);
        if(svc.BonusSpawnMoneyNotify)
            CPrintToChat(client, "%s %t", g_ChatTag, "Bonus Spawn Money", value);
    }

    if(svc.BonusPlayerShield && IsRoundAllowed(svc.BonusPlayerShieldRound))
    {
        int weapon = GetPlayerWeapon(client, CSWeapon_SHIELD);

        if (weapon == -1)
            GivePlayerItem(client, "weapon_shield");
    }

    DisplayWeaponMenu(client, svc);
    GiveGrenades(client, svc);   
}

void GiveGrenades(int client, Service svc)
{

}

public void Event_PlayerDeath(Event event, const char[] name, bool bDontBroadcast)
{
    int victim = GetClientOfUserId(event.GetInt("userid"));
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    int assister = GetClientOfUserId(event.GetInt("assister"));

    bool headshot = event.GetBool("headshot", false);
    bool noscope = event.GetBool("noscope", false);

    char weapon[MAX_WEAPON_CLASSNAME_SIZE];
    event.GetString("weapon", weapon, sizeof(weapon));

    ExtraJump_OnPlayerDeath(victim);

    // Probably i should (MAKE A FUNCTION) but fuck it....
    Service svcAttacker = GetClientService(attacker);
    Service svcAssister = GetClientService(assister);

    if (svcAttacker == null || svcAssister == null)
        return;

    if (attacker == 0 || attacker == victim)
        return;

    if (!g_BotsGrantBonuses && (victim == 0 || IsFakeClient(victim)))
        return;

    if(ClientsAreTeammates(attacker, victim))
        return;

    AwardMoneyBonuses(attacker, assister, headshot, noscope, weapon, svcAttacker, svcAssister);
    AwardHPBonuses(attacker, assister, headshot, noscope, weapon, svcAttacker, svcAssister);
}

void AwardMoneyBonuses(int attacker, int assister, bool headshot, bool noscope, char[] weapon, Service svcAttacker, Service svcAssister)
{
    if (IsRoundAllowed(svcAttacker.BonusKillMoneyRound))
    {
        int value = svcAttacker.BonusKillMoney;
        if (value > 0)
        {
            SetClientMoney(attacker, GetClientMoney(attacker) + value);
            if (svcAttacker.BonusKillMoneyNotify)
                CPrintToChat(attacker, "%s %t", g_ChatTag, "Bonus Kill Money", value);
        }       
    }
    if (IsRoundAllowed(svcAssister.BonusAssistMoneyRound))
    {
        int value = svcAssister.BonusAssistMoney;
        if (value > 0)
        {
            SetClientMoney(assister, GetClientMoney(assister) + value);
            if (svcAssister.BonusAssistMoneyNotify)
                CPrintToChat(attacker, "%s %t", g_ChatTag, "Bonus Assists Money", value);
        }
    }
    if (headshot && IsRoundAllowed(svcAttacker.BonusHeadshotMoneyRound))
    {
        int value = svcAttacker.BonusHeadshotMoney;
        if (value > 0)
        {
            SetClientMoney(attacker, GetClientMoney(attacker) + value);
            if (svcAttacker.BonusHeadshotMoneyNotify)
                CPrintToChat(attacker, "%s %t", g_ChatTag, "Bonus Headshot Money", value);
        }
    }
    if (IsWeaponKnife(weapon) && IsRoundAllowed(svcAttacker.BonusKnifeMoneyRound))
    {
        int value = svcAttacker.BonusKnifeMoney;
        if (value > 0)
        {
            SetClientMoney(attacker, GetClientMoney(attacker) + value);
            if (svcAttacker.BonusKnifeMoneyNotify)
                CPrintToChat(attacker, "%s %t", g_ChatTag, "Bonus Knife Money", value);
        }
    }
    // maybe some function for that? idk
    if (StrContains(weapon, "taser") != -1 && IsRoundAllowed(svcAttacker.BonusZeusMoneyRound))
    {
        int value = svcAttacker.BonusZeusMoney;
        if (value > 0)
        {
            SetClientMoney(attacker, GetClientMoney(attacker) + value);
            if (svcAttacker.BonusZeusMoneyNotify)
                CPrintToChat(attacker, "%s %t", g_ChatTag, "Bonus Zeus Money", value);
        }
    }
    if (noscope && IsRoundAllowed(svcAttacker.BonusNoscopeMoneyRound))
    {
        int value = svcAttacker.BonusNoscopeMoney;
        if (value > 0)
        {
            SetClientMoney(attacker, GetClientMoney(attacker) + value);
            if (svcAttacker.BonusNoscopeMoneyNotify)
                CPrintToChat(attacker, "%s %t", g_ChatTag, "Bonus NoScope Money", value);
        }
    }
    // how to proceed with grenade stuff?
}

void AwardHPBonuses(int attacker, int assister, bool headshot, bool noscope, char[] weapon, Service svcAttacker, Service svcAssister)
{
    if (IsRoundAllowed(svcAttacker.BonusKillHPRound))
    {
        int value = svcAttacker.BonusKillHP;
        if (value > 0)
        {
            SetPlayerHealth(attacker, GetClientHealth(attacker) + value, svcAttacker);
            if (svcAttacker.BonusKillHPNotify)
                CPrintToChat(attacker, "%s %t", g_ChatTag, "Bonus Kill HP", value);
        }
    }
}

public void Event_BombPlanted(Event event, const char[] name, bool bDontBroadcast)
{

}

public void Event_BombDefused(Event event, const char[] name, bool bDontBroadcast)
{

}

public Action Hook_OnTakeDamage(int client, int &attacker, int &inflictor, float &damage, int &damagetype)
{
    Service svc = GetClientService(attacker|client);
    if (svc == null)
        return Plugin_Continue;

    if(IsRoundAllowed(svc.BonusPlayerFallDamagePercentRound))
    {
        if(damagetype == DMG_FALL)
        {

        }
    }

    return Plugin_Continue;    
}

