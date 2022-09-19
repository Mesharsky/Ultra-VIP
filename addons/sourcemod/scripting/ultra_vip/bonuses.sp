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
void Bonus_KillMoney(int attacker, Service svc)
{
    if (!IsRoundAllowed(svc.BonusKillMoneyRound))
        return;

    int value = svc.BonusKillMoney;
    if (value <= 0)
        return;

    SetClientMoney(attacker, GetClientMoney(attacker) + value);
    if (svc.BonusKillMoneyNotify)
        CPrintToChat(attacker, "%s %t", g_ChatTag, "Bonus Kill Money", value);
}

void Bonus_AssisterMoney(int assister, Service svc)
{
    if (assister && svc == null || !IsRoundAllowed(svc.BonusAssistMoneyRound))
        return;

    int value = svc.BonusAssistMoney;
    if (value <= 0)
        return;
    
    SetClientMoney(assister, GetClientMoney(assister) + value);
    if (svc.BonusAssistMoneyNotify)
        CPrintToChat(assister, "%s %t", g_ChatTag, "Bonus Assists Money", value);
}

void Bonus_HeadShotMoney(int attacker, bool headshot, Service svc)
{
    if (!headshot || !IsRoundAllowed(svc.BonusHeadshotMoneyRound))
        return;

    int value = svc.BonusHeadshotMoney;
    if (value <= 0)
        return;

    SetClientMoney(attacker, GetClientMoney(attacker) + value);
    if (svc.BonusHeadshotMoneyNotify)
        CPrintToChat(attacker, "%s %t", g_ChatTag, "Bonus Headshot Money", value);
}

void Bonus_KnifeMoney(int attacker, const char[] weapon, Service svc)
{
    if (!IsWeaponKnife(weapon) || !IsRoundAllowed(svc.BonusKnifeMoneyRound))
        return;

    int value = svc.BonusKnifeMoney;
    if (value <= 0)
        return;

    SetClientMoney(attacker, GetClientMoney(attacker) + value);
    if (svc.BonusKnifeMoneyNotify)
        CPrintToChat(attacker, "%s %t", g_ChatTag, "Bonus Knife Money", value);
}

void Bonus_ZeusMoney(int attacker, const char[] weapon, Service svc)
{
    if (!IsWeaponTaser(weapon) || !IsRoundAllowed(svc.BonusZeusMoneyRound))
        return;

    int value = svc.BonusZeusMoney;
    if (value <= 0)
        return;

    SetClientMoney(attacker, GetClientMoney(attacker) + value);
    if (svc.BonusZeusMoneyNotify)
        CPrintToChat(attacker, "%s %t", g_ChatTag, "Bonus Zeus Money", value);
}

void Bonus_GrenadeKillMoney(int attacker, const char[] weapon, Service svc)
{
    if (!IsWeaponGrenade(weapon) || !IsRoundAllowed(svc.BonusGrenadeMoneyRound))
        return;

    int value = svc.BonusGrenadeMoney;
    if (value <= 0)
        return;

    SetClientMoney(attacker, GetClientMoney(attacker) + value);
    if (svc.BonusGrenadeMoneyNotify)
        CPrintToChat(attacker, "%s %t", g_ChatTag, "Bonus Grenade Money", value);
}

void Bonus_NoScopeMoney(int attacker, bool noscope, Service svc)
{
    if (!noscope || !IsRoundAllowed(svc.BonusNoscopeMoneyRound))
        return;

    int value = svc.BonusNoscopeMoney;
    if (value <= 0)
        return;

    SetClientMoney(attacker, GetClientMoney(attacker) + value);
    if (svc.BonusNoscopeMoneyNotify)
        CPrintToChat(attacker, "%s %t", g_ChatTag, "Bonus NoScope Money", value);
}

//////////////////////////////////
/*          HP BONUSES          */
//////////////////////////////////
void Bonus_KillHP(int attacker, Service svc)
{
    if (!IsRoundAllowed(svc.BonusKillHPRound))
        return;

    int value = svc.BonusKillHP;
    if (value <= 0)
        return;

    SetPlayerHealth(attacker, GetClientHealth(attacker) + value, svc);
    if (svc.BonusKillHPNotify)
        CPrintToChat(attacker, "%s %t", g_ChatTag, "Bonus Kill HP", value);

}

void Bonus_AssisterHP(int assister, Service svc)
{
    if (assister && svc == null || !IsRoundAllowed(svc.BonusAssistHPRound))
        return;

    int value = svc.BonusAssistHP;
    if (value <= 0)
        return;
    
    SetPlayerHealth(assister, GetClientHealth(assister) + value, svc);
    if (svc.BonusAssistHPNotify)
        CPrintToChat(assister, "%s %t", g_ChatTag, "Bonus Assists HP", value);
}

void Bonus_HeadShotHP(int attacker, bool headshot, Service svc)
{
    if (!headshot || !IsRoundAllowed(svc.BonusHeadshotHPRound))
        return;

    int value = svc.BonusHeadshotHP;
    if (value <= 0)
        return;

    SetPlayerHealth(attacker, GetClientHealth(attacker) + value, svc);
    if (svc.BonusHeadshotHPNotify)
        CPrintToChat(attacker, "%s %t", g_ChatTag, "Bonus Headshot HP", value);
}

void Bonus_KnifeHP(int attacker, const char[] weapon, Service svc)
{
    if (!IsWeaponKnife(weapon) || !IsRoundAllowed(svc.BonusKnifeHPRound))
        return;

    int value = svc.BonusKnifeHP;
    if (value <= 0)
        return;

    SetPlayerHealth(attacker, GetClientHealth(attacker) + value, svc);
    if (svc.BonusKnifeHPNotify)
        CPrintToChat(attacker, "%s %t", g_ChatTag, "Bonus Knife HP", value);
}

void Bonus_ZeusHP(int attacker, const char[] weapon, Service svc)
{
    if (!IsWeaponTaser(weapon) || !IsRoundAllowed(svc.BonusZeusHPRound))
        return;

    int value = svc.BonusZeusHP;
    if (value <= 0)
        return;

    SetPlayerHealth(attacker, GetClientHealth(attacker) + value, svc);
    if (svc.BonusZeusHPNotify)
        CPrintToChat(attacker, "%s %t", g_ChatTag, "Bonus Zeus HP", value);
}

void Bonus_GrenadeKillHP(int attacker, const char[] weapon, Service svc)
{
    if (!IsWeaponGrenade(weapon) || !IsRoundAllowed(svc.BonusGrenadeHPRound))
        return;

    int value = svc.BonusGrenadeHP;
    if (value <= 0)
        return;

    SetPlayerHealth(attacker, GetClientHealth(attacker) + value, svc);
    if (svc.BonusGrenadeHPNotify)
        CPrintToChat(attacker, "%s %t", g_ChatTag, "Bonus Grenade HP", value);
}

void Bonus_NoScopeHP(int attacker, bool noscope, Service svc)
{
    if (!noscope || !IsRoundAllowed(svc.BonusNoscopeHPRound))
        return;

    int value = svc.BonusNoscopeHP;
    if (value <= 0)
        return;

    SetPlayerHealth(attacker, GetClientHealth(attacker) + value, svc);
    if (svc.BonusNoscopeHPNotify)
        CPrintToChat(attacker, "%s %t", g_ChatTag, "Bonus NoScope HP", value);
}