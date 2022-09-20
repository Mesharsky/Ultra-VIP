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

//////////////////////////////////
/*        SPAWN BONUSES         */
//////////////////////////////////
void Bonus_SetPlayerScoreBoardTag(int client, Service svc)
{
    SetPlayerScoreBoardTag(client, svc);
}

void Bonus_SetPlayerHealth(int client, Service svc)
{
    if (!IsRoundAllowed(svc.BonusPlayerHealthRound))
        return;

    SetPlayerHealth(client, svc.BonusPlayerHealth, svc);
}

void Bonus_GivePlayerHelmet(int client, Service svc)
{
    if(!svc.BonusHelmetEnabled || !IsRoundAllowed(svc.BonusHelmetRound))
        return;
    
    SetEntProp(client, Prop_Send, "m_bHasHelmet", 1);
}

void Bonus_GivePlayerArmor(int client, Service svc)
{
    if(!svc.BonusArmorEnabled || !IsRoundAllowed(svc.BonusArmorRound))
        return;
    
    SetEntProp(client, Prop_Send, "m_ArmorValue", svc.BonusArmorValue);
}

void Bonus_GivePlayerDefuser(int client, Service svc)
{
    if (!svc.BonusDefuserEnabled || !IsRoundAllowed(svc.BonusDefuserRound) || !CanGiveDefuser(client))
        return;
    
    GivePlayerItem(client, "item_defuser");
}

void Bonus_SetPlayerGravity(int client, Service svc)
{
    if (!IsRoundAllowed(svc.BonusPlayerGravityRound))
        return;

    float value = svc.BonusPlayerGravity;
    if (FloatEqual(value, 1.0))
        return;
    
    SetEntityGravity(client, value);
}

void Bonus_SetPlayerSpeed(int client, Service svc)
{
    if (!IsRoundAllowed(svc.BonusPlayerSpeedRound))
        return;

    float value = svc.BonusPlayerSpeed;
    if (FloatEqual(value, 1.0))
        return;

    SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", value);
}

void Bonus_SetPlayerVisibility(int client, Service svc)
{
    if (!IsRoundAllowed(svc.BonusPlayerVisibilityRound))
        return;

    int value = svc.BonusPlayerVisibility;
    if (value == 255)
        return;

    SetPlayerVisibility(client, value);
}

void Bonus_GivePlayerSpawnMoney(int client, Service svc)
{
    if (!IsRoundAllowed(svc.BonusSpawnMoneyRound))
        return;

    int value = svc.BonusSpawnMoney;
    SetClientMoney(client, GetClientMoney(client) + value);
    
    if(svc.BonusSpawnMoneyNotify)
        CPrintToChat(client, "%s %t", g_ChatTag, "Bonus Spawn Money", value);
}

void Bonus_GivePlayerShield(int client, Service svc)
{
    if(!svc.BonusPlayerShield || !IsRoundAllowed(svc.BonusPlayerShieldRound))
        return;

    if (GetPlayerWeapon(client, CSWeapon_SHIELD) != -1)
        GivePlayerItem(client, "weapon_shield");
}

void GiveGrenades(int client, Service svc)
{
    // xd
}

//////////////////////////////////
/*        MONEY BONUSES         */
//////////////////////////////////
static void _SetMoney(int client, int additionalMoney, bool notify, const char[] translation)
{
    if (additionalMoney <= 0)
        return;

    SetClientMoney(client, GetClientMoney(client) + additionalMoney);
    if(notify)
        CPrintToChat(client, "%s %t", g_ChatTag, translation, additionalMoney);    
}

void Bonus_KillMoney(int attacker, Service svc)
{
    if (!IsRoundAllowed(svc.BonusKillMoneyRound))
        return;

    _SetMoney(attacker, svc.BonusKillMoney, svc.BonusKillMoneyNotify, "Bonus Kill Money");
}

void Bonus_AssisterMoney(int assister, Service svc)
{
    if (assister && svc == null || !IsRoundAllowed(svc.BonusAssistMoneyRound))
        return;

    _SetMoney(assister, svc.BonusAssistMoney, svc.BonusAssistMoneyNotify, "Bonus Assists Money");
}

void Bonus_HeadShotMoney(int attacker, bool headshot, Service svc)
{
    if (!headshot || !IsRoundAllowed(svc.BonusHeadshotMoneyRound))
        return;

    _SetMoney(attacker, svc.BonusHeadshotMoney, svc.BonusHeadshotMoneyNotify, "Bonus Headshot Money");
}

void Bonus_KnifeMoney(int attacker, const char[] weapon, Service svc)
{
    if (!IsWeaponKnife(weapon) || !IsRoundAllowed(svc.BonusKnifeMoneyRound))
        return;

    _SetMoney(attacker, svc.BonusKnifeMoney, svc.BonusKnifeMoneyNotify, "Bonus Knife Money");
}

void Bonus_ZeusMoney(int attacker, const char[] weapon, Service svc)
{
    if (!IsWeaponTaser(weapon) || !IsRoundAllowed(svc.BonusZeusMoneyRound))
        return;

    _SetMoney(attacker, svc.BonusZeusMoney, svc.BonusZeusMoneyNotify, "Bonus Zeus Money");
}

void Bonus_GrenadeKillMoney(int attacker, const char[] weapon, Service svc)
{
    if (!IsWeaponGrenade(weapon) || !IsRoundAllowed(svc.BonusGrenadeMoneyRound))
        return;

    _SetMoney(attacker, svc.BonusGrenadeMoney, svc.BonusGrenadeMoneyNotify, "Bonus Grenade Money");
}

void Bonus_NoScopeMoney(int attacker, bool noscope, Service svc)
{
    if (!noscope || !IsRoundAllowed(svc.BonusNoscopeMoneyRound))
        return;
    
    _SetMoney(attacker, svc.BonusNoscopeMoney, svc.BonusNoscopeMoneyNotify, "Bonus NoScope Money");
}

void Bonus_BombPlantedMoney(int client, Service svc)
{
    if (!IsRoundAllowed(svc.BonusBombPlantedMoneyRound))
        return;

    _SetMoney(client, svc.BonusBombPlantedMoney, svc.BonusBombPlantedMoneyNotify, "Bonus Bomb Planted Money");
}

void Bonus_BombDefusedMoney(int client, Service svc)
{
    if (!IsRoundAllowed(svc.BonusBombDefusedMoneyRound))
        return;

    _SetMoney(client, svc.BonusBombDefusedMoney, svc.BonusBombDefusedMoneyNotify, "Bonus Bomb Defused Money");  
}

//////////////////////////////////
/*          HP BONUSES          */
//////////////////////////////////
static void _SetHP(int client, int additionalHP, Service svc, bool notify, const char[] translation)
{
    if (additionalHP <= 0)
        return;

    SetPlayerHealth(client, GetClientHealth(client) + additionalHP, svc);
    if(notify)
        CPrintToChat(client, "%s %t", g_ChatTag, translation, additionalHP);    
}

void Bonus_KillHP(int attacker, Service svc)
{
    if (!IsRoundAllowed(svc.BonusKillHPRound))
        return;

    _SetHP(attacker, svc.BonusKillHP, svc, svc.BonusKillHPNotify, "Bonus Kill HP");    
}

void Bonus_AssisterHP(int assister, Service svc)
{
    if (assister && svc == null || !IsRoundAllowed(svc.BonusAssistHPRound))
        return;

    _SetHP(assister, svc.BonusAssistHP, svc, svc.BonusAssistHPNotify, "Bonus Assists HP");    
}

void Bonus_HeadShotHP(int attacker, bool headshot, Service svc)
{
    if (!headshot || !IsRoundAllowed(svc.BonusHeadshotHPRound))
        return;

    _SetHP(attacker, svc.BonusHeadshotHP, svc, svc.BonusHeadshotHPNotify, "Bonus Headshot HP");      
}

void Bonus_KnifeHP(int attacker, const char[] weapon, Service svc)
{
    if (!IsWeaponKnife(weapon) || !IsRoundAllowed(svc.BonusKnifeHPRound))
        return;

    _SetHP(attacker, svc.BonusKnifeHP, svc, svc.BonusKnifeHPNotify, "Bonus Knife HP");
}

void Bonus_ZeusHP(int attacker, const char[] weapon, Service svc)
{
    if (!IsWeaponTaser(weapon) || !IsRoundAllowed(svc.BonusZeusHPRound))
        return;

    _SetHP(attacker, svc.BonusZeusHP, svc, svc.BonusZeusHPNotify, "Bonus Zeus HP");
}

void Bonus_GrenadeKillHP(int attacker, const char[] weapon, Service svc)
{
    if (!IsWeaponGrenade(weapon) || !IsRoundAllowed(svc.BonusGrenadeHPRound))
        return;

    _SetHP(attacker, svc.BonusGrenadeHP, svc, svc.BonusGrenadeHPNotify, "Bonus Grenade HP"); 
}

void Bonus_NoScopeHP(int attacker, bool noscope, Service svc)
{
    if (!noscope || !IsRoundAllowed(svc.BonusNoscopeHPRound))
        return;

    _SetHP(attacker, svc.BonusNoscopeHP, svc, svc.BonusNoscopeHPNotify, "Bonus NoScope HP");
}