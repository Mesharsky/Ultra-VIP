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

#include "bonuses.sp"

static Handle s_SpawnTimers[MAXPLAYERS + 1];

public void Event_RoundStart(Event event, const char[] name, bool bDontBroadcast)
{
    #warning REWRITE THIS FUNCTION DEBUG
    if (GameRules_GetProp("m_bWarmupPeriod"))
		return;

    g_RoundCount++;
    PrintToChatAll("%i", g_RoundCount);
}

public void Event_TeamChange(Event event, const char[] name, bool bDontBroadcast)
{
    g_RoundCount = -1;
}

public void Event_PlayerSpawn(Event event, const char[] name, bool bDontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    PrintToChatAll("DEBUG: -- PlayerSpawn ---");

    // TODO / NOTE: Delay spawn events to force them to occur after round_start
    // stupid janky bastard engine
    DataPack pack;
    delete s_SpawnTimers[client];
    s_SpawnTimers[client] = CreateDataTimer(0.5, Timer_SpawnBonuses, pack, TIMER_FLAG_NO_MAPCHANGE);
    pack.WriteCell(GetClientUserId(client));
    pack.WriteCell(client); // >:I
}

public Action Timer_SpawnBonuses(Handle tmr, DataPack pack)
{
    pack.Reset();

    int client = GetClientOfUserId(pack.ReadCell());
    if (!client)
    {
        client = pack.ReadCell(); // Get original index
        s_SpawnTimers[client] = null;
        return Plugin_Handled;
    }

    Service svc = GetClientService(client);

    // This must run for every spawn, even without a service
    ExtraJump_OnPlayerSpawn(client, svc);

    if (svc == null)
    {
        s_SpawnTimers[client] = null;
        return Plugin_Handled;
    }

    Bonus_SetPlayerScoreBoardTag(client, svc);
    Bonus_SetPlayerHealth(client, svc);

    Bonus_GivePlayerArmor(client, svc);
    Bonus_GivePlayerHelmet(client, svc);
    Bonus_GivePlayerDefuser(client, svc);

    Bonus_SetPlayerGravity(client, svc);
    Bonus_SetPlayerSpeed(client, svc);
    Bonus_SetPlayerVisibility(client, svc);
    
    Bonus_GivePlayerSpawnMoney(client, svc);
    Bonus_GivePlayerShield(client, svc);

    DisplayWeaponMenu(client, svc);
    GiveGrenades(client, svc);

    s_SpawnTimers[client] = null;
    return Plugin_Handled;
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

    Service svcAttacker = GetClientService(attacker);
    Service svcAssister = GetClientService(assister); // Assister allowed to be invalid

    if (svcAttacker == null)
        return;

    if (attacker == 0 || attacker == victim)
        return;

    if (!g_BotsGrantBonuses && (victim == 0 || IsFakeClient(victim)))
        return;

    if(ClientsAreTeammates(attacker, victim))
        return;

    // Award Money Bonuses
    Bonus_KillMoney(attacker, svcAttacker);
    Bonus_AssisterMoney(assister, svcAssister);
    Bonus_HeadShotMoney(attacker, headshot, svcAttacker);
    Bonus_KnifeMoney(attacker, weapon, svcAttacker);
    Bonus_ZeusMoney(attacker, weapon, svcAttacker);
    Bonus_GrenadeKillMoney(attacker, weapon, svcAttacker);
    Bonus_NoScopeMoney(attacker, noscope, svcAttacker);

    // Award HP Bonuses
    Bonus_KillHP(attacker, svcAttacker);
    Bonus_AssisterHP(assister, svcAssister);
    Bonus_HeadShotHP(attacker, headshot, svcAttacker);
    Bonus_KnifeHP(attacker, weapon, svcAttacker);
    Bonus_ZeusHP(attacker, weapon, svcAttacker);
    Bonus_GrenadeKillHP(attacker, weapon, svcAttacker);
    Bonus_NoScopeHP(attacker, noscope, svcAttacker);
    
    Bonus_RespawnPlayer(victim);
}

public void Event_BombPlanted(Event event, const char[] name, bool bDontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    Service svc = GetClientService(client);
    if (svc == null)
        return;

    Bonus_BombPlantedMoney(client, svc);    
}

public void Event_BombDefused(Event event, const char[] name, bool bDontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    Service svc = GetClientService(client);
    if (svc == null)
        return;

    Bonus_BombDefusedMoney(client, svc);
}

public void Event_HostageRescued(Event event, const char[] name, bool bDontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    Service svc = GetClientService(client);
    if (svc == null)
        return;
}

public void Event_WeaponFire(Event event, const char[] name, bool bDontBroadcast)
{
    #warning REWRITE
    int client = GetClientOfUserId(event.GetInt("userid"));
    int weapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");

    Service svc = GetClientService(client);
    if (svc == null)
        return;

    if(!svc.BonusUnlimitedAmmo || !IsRoundAllowed(svc.BonusUnlimitedAmmoRound))
        return;

    GivePlayerUnlimitedAmmo(client, weapon);
}

public Action Hook_OnTakeDamage(int client, int &attacker, int &inflictor, float &damage, int &damagetype)
{
    Service clientSvc = GetClientService(client);
    Service attackerSvc = null;

    if (attacker >= 1 && attacker <= MaxClients)
        attackerSvc = GetClientService(attacker);

    Action state = Plugin_Continue;

    // Increase damage first before implementing resistance
    if (attackerSvc != null && IsRoundAllowed(attackerSvc.BonusPlayerAttackDamageRound))
    {
        damage *= attackerSvc.BonusPlayerAttackDamage * 0.01;
        state = Plugin_Changed;
    }

    if (clientSvc == null)
        return state;

    if (damagetype & DMG_FALL)
    {
        // TODO: I think technically if multiple damage types exist the scaling
        // should be different, but eh.
        if (IsRoundAllowed(clientSvc.BonusPlayerFallDamagePercentRound))
        {
            damage *= clientSvc.BonusPlayerFallDamagePercent * 0.01;
            state = Plugin_Changed;
        }
    }
    else
    {
        // Fall damage should never be included in this resistance
        if (IsRoundAllowed(clientSvc.BonusPlayerDamageResistRound))
        {
            damage -= damage * clientSvc.BonusPlayerDamageResist * 0.01;
            if (damage < 0.0)
                damage = 0.0;
            state = Plugin_Changed;
        }
    }

    return state;
}
