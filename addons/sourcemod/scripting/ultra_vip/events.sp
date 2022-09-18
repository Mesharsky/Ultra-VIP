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

    bool headshot = event.GetBool("headshot", false);

    ExtraJump_OnPlayerDeath(victim);

    Service svc = GetClientService(attacker);

    if (svc == null)
        return;

    if (attacker == 0 || attacker == victim)
        return;

    if (!g_BotsGrantBonuses && (victim == 0 || IsFakeClient(victim)))
        return;    

    if(ClientsAreTeammates(attacker, victim))
        return;        
}

public void Event_BombPlanted(Event event, const char[] name, bool bDontBroadcast)
{

}

public void Event_BombDefused(Event event, const char[] name, bool bDontBroadcast)
{

}