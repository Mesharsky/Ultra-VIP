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

void Service_Delete(Service &svc)
{
    delete svc.WeaponMenu;
    delete svc.Weapons;

    delete svc;
}

methodmap Service < StringMap
{
    public Service(const char[] name = "")
    {
        StringMap self = new StringMap();
        self.SetString("name", name);
        return view_as<Service>(self);
    }

    public void GetName(char[] output, int size) { this.GetString("name", output, size); }
    public void SetName(const char[] name) { this.SetString("name", name); }

    property bool Enabled
    {
        public get() { return Service_GetCell(this, "service_enabled", false); }
        public set(bool value) { this.SetValue("service_enabled", value); }
    }

    property int Priority
    {
        public get() { return Service_GetCell(this, "priority", 0); }
        public set(int value) { this.SetValue("priority", value); }
    }

    property int Flag
    {
        public get() { return Service_GetCell(this, "flag", 0); }
        public set(int flag)
        {
            if (flag && !HasOnlySingleBit(flag))
                ThrowError("Cannot set multiple admin flags for a Service.");
            this.SetValue("flag", flag);
        }
    }

    public void GetOverride(char[] output, int size) { Service_GetString(this, "override", output, size, ""); }
    public void SetOverride(const char[] override) { this.SetString("override", override); }

    public void GetChatTag(char[] output, int size) { Service_GetString(this, "chat_tag", output, size, ""); }
    public void SetChatTag(const char[] tag) { this.SetString("chat_tag", tag); }

    public void GetChatNameColor(char[] output, int size) { Service_GetString(this, "chat_name_color", output, size, ""); }
    public void SetChatNameColor(const char[] tag) { this.SetString("chat_name_color", tag); }

    public void GetChatMsgColor(char[] output, int size) { Service_GetString(this, "chat_message_color", output, size, ""); }
    public void SetChatMsgColor(const char[] tag) { this.SetString("chat_message_color", tag); }

    public void GetScoreboardTag(char[] output, int size) { Service_GetString(this, "scoreboard_tag", output, size, ""); }
    public void SetScoreboardTag(const char[] tag) { this.SetString("scoreboard_tag", tag); }

    property int BonusPlayerHealth
    {
        public get() { return Service_GetCell(this, "player_hp", 105); }
        public set(int value) { this.SetValue("player_hp", value); }
    }
    property int BonusPlayerHealthRound
    {
        public get() { return Service_GetCell(this, "player_hp_round", 1); }
        public set(int value) { this.SetValue("player_hp_round", value); }
    }
    property int BonusMaxPlayerHealth
    {
        public get() { return Service_GetCell(this, "player_max_hp", 110); }
        public set(int value) { this.SetValue("player_max_hp", value); }
    }

    property bool BonusArmorEnabled
    {
        public get() { return Service_GetCell(this, "player_vest", true); }
        public set(bool value) { this.SetValue("player_vest", value); }
    }
    property int BonusArmor
    {
        public get() { return Service_GetCell(this, "player_vest_value", 100); }
        public set(int value) { this.SetValue("player_vest_value", value); }
    }
    property int BonusArmorRound
    {
        public get() { return Service_GetCell(this, "player_vest_round", 2); }
        public set(int value) { this.SetValue("player_vest_round", value); }
    }

    property bool BonusHelmetEnabled
    {
        public get() { return Service_GetCell(this, "player_helmet", true); }
        public set(bool value) { this.SetValue("player_helmet", value); }
    }
    property int BonusHelmetRound
    {
        public get() { return Service_GetCell(this, "player_helmet_round", 2); }
        public set(int value) { this.SetValue("player_helmet_round", value); }
    }

    property bool BonusDefuserEnabled
    {
        public get() { return Service_GetCell(this, "player_defuser", true); }
        public set(bool value) { this.SetValue("player_defuser", value); }
    }
    property int BonusDefuserRound
    {
        public get() { return Service_GetCell(this, "player_defuser_round", 2); }
        public set(int value) { this.SetValue("player_defuser_round", value); }
    }

    // For use with grenade.sp::GivePlayerConsumables
    property bool ShouldStripConsumables
    {
        public get() { return Service_GetCell(this, "strip_consumables", false); }
        public set(bool value) { this.SetValue("strip_consumables", value); }
    }

    property int BonusHEGrenades
    {
        public get() { return Service_GetCell(this, "he_amount", 1); }
        public set(int value) { this.SetValue("he_amount", value); }
    }
    property int BonusHEGrenadesRound
    {
        public get() { return Service_GetCell(this, "he_round", 1); }
        public set(int value) { this.SetValue("he_round", value); }
    }

    property int BonusFlashGrenades
    {
        public get() { return Service_GetCell(this, "flash_amount", 1); }
        public set(int value) { this.SetValue("flash_amount", value); }
    }
    property int BonusFlashGrenadesRound
    {
        public get() { return Service_GetCell(this, "flash_round", 1); }
        public set(int value) { this.SetValue("flash_round", value); }
    }

    property int BonusSmokeGrenades
    {
        public get() { return Service_GetCell(this, "smoke_amount", 1); }
        public set(int value) { this.SetValue("smoke_amount", value); }
    }
    property int BonusSmokeGrenadesRound
    {
        public get() { return Service_GetCell(this, "smoke_round", 1); }
        public set(int value) { this.SetValue("smoke_round", value); }
    }

    property int BonusDecoyGrenades
    {
        public get() { return Service_GetCell(this, "decoy_amount", 0); }
        public set(int value) { this.SetValue("decoy_amount", value); }
    }
    property int BonusDecoyGrenadesRound
    {
        public get() { return Service_GetCell(this, "decoy_round", 1); }
        public set(int value) { this.SetValue("decoy_round", value); }
    }

    property int BonusMolotovGrenades
    {
        public get() { return Service_GetCell(this, "molotov_amount", 0); }
        public set(int value) { this.SetValue("molotov_amount", value); }
    }
    property int BonusMolotovGrenadesRound
    {
        public get() { return Service_GetCell(this, "molotov_round", 1); }
        public set(int value) { this.SetValue("molotov_round", value); }
    }

    property int BonusHealthshotGrenades
    {
        public get() { return Service_GetCell(this, "healthshot_amount", 0); }
        public set(int value) { this.SetValue("healthshot_amount", value); }
    }
    property int BonusHealthshotGrenadesRound
    {
        public get() { return Service_GetCell(this, "healthshot_round", 3); }
        public set(int value) { this.SetValue("healthshot_round", value); }
    }

    property int BonusTacticalGrenades
    {
        public get() { return Service_GetCell(this, "tag_amount", 0); }
        public set(int value) { this.SetValue("tag_amount", value); }
    }
    property int BonusTacticalGrenadesRound
    {
        public get() { return Service_GetCell(this, "tag_round", 1); }
        public set(int value) { this.SetValue("tag_round", value); }
    }

    property int BonusSnowballGrenades
    {
        public get() { return Service_GetCell(this, "snowball_amount", 0); }
        public set(int value) { this.SetValue("snowball_amount", value); }
    }
    property int BonusSnowballGrenadesRound
    {
        public get() { return Service_GetCell(this, "snowball_round", 1); }
        public set(int value) { this.SetValue("snowball_round", value); }
    }

    property int BonusBreachchargeGrenades
    {
        public get() { return Service_GetCell(this, "breachcharge_amount", 0); }
        public set(int value) { this.SetValue("breachcharge_amount", value); }
    }
    property int BonusBreachchargeGrenadesRound
    {
        public get() { return Service_GetCell(this, "breachcharge_round", 1); }
        public set(int value) { this.SetValue("breachcharge_round", value); }
    }

    property int BonusBumpmineGrenades
    {
        public get() { return Service_GetCell(this, "bumpmine_amount", 0); }
        public set(int value) { this.SetValue("bumpmine_amount", value); }
    }
    property int BonusBumpmineGrenadesRound
    {
        public get() { return Service_GetCell(this, "bumpmine_round", 1); }
        public set(int value) { this.SetValue("bumpmine_round", value); }
    }

    property int BonusExtraJumps
    {
        public get() { return Service_GetCell(this, "player_extra_jumps", 1); }
        public set(int value) { this.SetValue("player_extra_jumps", value); }
    }
    property float BonusJumpHeight
    {
        public get() { return Service_GetCell(this, "player_extra_jump_height", EXTRAJUMP_DEFAULT_HEIGHT); }
        public set(float value) { this.SetValue("player_extra_jump_height", value); }
    }
    property int BonusExtraJumpsRound
    {
        public get() { return Service_GetCell(this, "player_extra_jumps_round", 1); }
        public set(int value) { this.SetValue("player_extra_jumps_round", value); }
    }
    property bool BonusExtraJumpsTakeFallDamage
    {
        public get() { return Service_GetCell(this, "player_extra_jumps_falldamage", true); }
        public set(bool value) { this.SetValue("player_extra_jumps_falldamage", value); }
    }

    property bool BonusPlayerShield
    {
        public get() { return Service_GetCell(this, "player_shield", false); }
        public set(bool value) { this.SetValue("player_shield", value); }
    }
    property int BonusPlayerShieldRound
    {
        public get() { return Service_GetCell(this, "player_shield_round", 1); }
        public set(int value) { this.SetValue("player_shield_round", value); }
    }

    property float BonusPlayerGravity
    {
        public get() { return Service_GetCell(this, "player_gravity", 1.0); }
        public set(float value) { this.SetValue("player_gravity", value); }
    }
    property int BonusPlayerGravityRound
    {
        public get() { return Service_GetCell(this, "player_gravity_round", 1); }
        public set(int value) { this.SetValue("player_gravity_round", value); }
    }

    property float BonusPlayerSpeed
    {
        public get() { return Service_GetCell(this, "player_speed", 1.0); }
        public set(float value) { this.SetValue("player_speed", value); }
    }
    property int BonusPlayerSpeedRound
    {
        public get() { return Service_GetCell(this, "player_speed_round", 1); }
        public set(int value) { this.SetValue("player_speed_round", value); }
    }

    property int BonusPlayerVisibility
    {
        public get() { return Service_GetCell(this, "player_visibility", 255); }
        public set(int value) { this.SetValue("player_visibility", value); }
    }
    property int BonusPlayerVisibilityRound
    {
        public get() { return Service_GetCell(this, "player_visibility_round", 1); }
        public set(int value) { this.SetValue("player_visibility_round", value); }
    }

    property int BonusPlayerRespawnPercent
    {
        public get() { return Service_GetCell(this, "player_respawn_percent", 0); }
        public set(int value) { this.SetValue("player_respawn_percent", value); }
    }
    property int BonusPlayerRespawnPercentRound
    {
        public get() { return Service_GetCell(this, "player_respawn_round", 3); }
        public set(int value) { this.SetValue("player_respawn_round", value); }
    }
    property bool BonusPlayerRespawnPercentNotify
    {
        public get() { return Service_GetCell(this, "player_respawn_notify", false); }
        public set(bool value) { this.SetValue("player_respawn_notify", value); }
    }

    property int BonusPlayerFallDamagePercent
    {
        public get() { return Service_GetCell(this, "player_fall_damage_percent", 100); }
        public set(int value) { this.SetValue("player_fall_damage_percent", value); }
    }
    property int BonusPlayerFallDamagePercentRound
    {
        public get() { return Service_GetCell(this, "player_fall_damage_round", 1); }
        public set(int value) { this.SetValue("player_fall_damage_round", value); }
    }

    property int BonusPlayerAttackDamage
    {
        public get() { return Service_GetCell(this, "player_attack_damage", 100); }
        public set(int value) { this.SetValue("player_attack_damage", value); }
    }
    property int BonusPlayerAttackDamageRound
    {
        public get() { return Service_GetCell(this, "player_attack_damage_round", 3); }
        public set(int value) { this.SetValue("player_attack_damage_round", value); }
    }

    property int BonusPlayerDamageResist
    {
        public get() { return Service_GetCell(this, "player_damage_resist", 0); }
        public set(int value) { this.SetValue("player_damage_resist", value); }
    }
    property int BonusPlayerDamageResistRound
    {
        public get() { return Service_GetCell(this, "player_damage_resist_round", 3); }
        public set(int value) { this.SetValue("player_damage_resist_round", value); }
    }

    property bool BonusUnlimitedAmmo
    {
        public get() { return Service_GetCell(this, "player_unlimited_ammo", false); }
        public set(bool value) { this.SetValue("player_unlimited_ammo", value); }
    }
    property int BonusUnlimitedAmmoRound
    {
        public get() { return Service_GetCell(this, "player_unlimited_ammo_round", 1); }
        public set(int value) { this.SetValue("player_unlimited_ammo_round", value); }
    }

    property int BonusSpawnMoney
    {
        public get() { return Service_GetCell(this, "spawn_bonus", 0); }
        public set(int value) { this.SetValue("spawn_bonus", value); }
    }
    property int BonusSpawnMoneyRound
    {
        public get() { return Service_GetCell(this, "spawn_bonus_round", 1); }
        public set(int value) { this.SetValue("spawn_bonus_round", value); }
    }
    property bool BonusSpawnMoneyNotify
    {
        public get() { return Service_GetCell(this, "spawn_bonus_chat", false); }
        public set(bool value) { this.SetValue("spawn_bonus_chat", value); }
    }

    property int BonusKillMoney
    {
        public get() { return Service_GetCell(this, "kill_bonus", 0); }
        public set(int value) { this.SetValue("kill_bonus", value); }
    }
    property int BonusKillMoneyRound
    {
        public get() { return Service_GetCell(this, "kill_bonus_round", 1); }
        public set(int value) { this.SetValue("kill_bonus_round", value); }
    }
    property bool BonusKillMoneyNotify
    {
        public get() { return Service_GetCell(this, "kill_bonus_chat", false); }
        public set(bool value) { this.SetValue("kill_bonus_chat", value); }
    }

    property int BonusAssistMoney
    {
        public get() { return Service_GetCell(this, "assist_bonus", 0); }
        public set(int value) { this.SetValue("assist_bonus", value); }
    }
    property int BonusAssistMoneyRound
    {
        public get() { return Service_GetCell(this, "assist_bonus_round", 1); }
        public set(int value) { this.SetValue("assist_bonus_round", value); }
    }
    property bool BonusAssistMoneyNotify
    {
        public get() { return Service_GetCell(this, "assist_bonus_chat", false); }
        public set(bool value) { this.SetValue("assist_bonus_chat", value); }
    }

    property int BonusHeadshotMoney
    {
        public get() { return Service_GetCell(this, "headshot_bonus", 0); }
        public set(int value) { this.SetValue("headshot_bonus", value); }
    }
    property int BonusHeadshotMoneyRound
    {
        public get() { return Service_GetCell(this, "headshot_bonus_round", 1); }
        public set(int value) { this.SetValue("headshot_bonus_round", value); }
    }
    property bool BonusHeadshotMoneyNotify
    {
        public get() { return Service_GetCell(this, "headshot_bonus_chat", false); }
        public set(bool value) { this.SetValue("headshot_bonus_chat", value); }
    }

    property int BonusKnifeMoney
    {
        public get() { return Service_GetCell(this, "knife_bonus", 0); }
        public set(int value) { this.SetValue("knife_bonus", value); }
    }
    property int BonusKnifeMoneyRound
    {
        public get() { return Service_GetCell(this, "knife_bonus_round", 1); }
        public set(int value) { this.SetValue("knife_bonus_round", value); }
    }
    property bool BonusKnifeMoneyNotify
    {
        public get() { return Service_GetCell(this, "knife_bonus_chat", false); }
        public set(bool value) { this.SetValue("knife_bonus_chat", value); }
    }

    property int BonusZeusMoney
    {
        public get() { return Service_GetCell(this, "zeus_bonus", 0); }
        public set(int value) { this.SetValue("zeus_bonus", value); }
    }
    property int BonusZeusMoneyRound
    {
        public get() { return Service_GetCell(this, "zeus_bonus_round", 1); }
        public set(int value) { this.SetValue("zeus_bonus_round", value); }
    }
    property bool BonusZeusMoneyNotify
    {
        public get() { return Service_GetCell(this, "zeus_bonus_chat", false); }
        public set(bool value) { this.SetValue("zeus_bonus_chat", value); }
    }

    property int BonusGrenadeMoney
    {
        public get() { return Service_GetCell(this, "grenade_bonus", 0); }
        public set(int value) { this.SetValue("grenade_bonus", value); }
    }
    property int BonusGrenadeMoneyRound
    {
        public get() { return Service_GetCell(this, "grenade_bonus_round", 1); }
        public set(int value) { this.SetValue("grenade_bonus_round", value); }
    }
    property bool BonusGrenadeMoneyNotify
    {
        public get() { return Service_GetCell(this, "grenade_bonus_chat", false); }
        public set(bool value) { this.SetValue("grenade_bonus_chat", value); }
    }

    property int BonusMvpMoney
    {
        public get() { return Service_GetCell(this, "mvp_bonus", 0); }
        public set(int value) { this.SetValue("mvp_bonus", value); }
    }
    property int BonusMvpMoneyRound
    {
        public get() { return Service_GetCell(this, "mvp_bonus_round", 1); }
        public set(int value) { this.SetValue("mvp_bonus_round", value); }
    }
    property bool BonusMvpMoneyNotify
    {
        public get() { return Service_GetCell(this, "mvp_bonus_chat", false); }
        public set(bool value) { this.SetValue("mvp_bonus_chat", value); }
    }

    property int BonusNoscopeMoney
    {
        public get() { return Service_GetCell(this, "noscope_bonus", 0); }
        public set(int value) { this.SetValue("noscope_bonus", value); }
    }
    property int BonusNoscopeMoneyRound
    {
        public get() { return Service_GetCell(this, "noscope_bonus_round", 1); }
        public set(int value) { this.SetValue("noscope_bonus_round", value); }
    }
    property bool BonusNoscopeMoneyNotify
    {
        public get() { return Service_GetCell(this, "noscope_bonus_chat", false); }
        public set(bool value) { this.SetValue("noscope_bonus_chat", value); }
    }

    property int BonusHostageMoney
    {
        public get() { return Service_GetCell(this, "hostage_bonus", 0); }
        public set(int value) { this.SetValue("hostage_bonus", value); }
    }
    property int BonusHostageMoneyRound
    {
        public get() { return Service_GetCell(this, "hostage_bonus_round", 1); }
        public set(int value) { this.SetValue("hostage_bonus_round", value); }
    }
    property bool BonusHostageMoneyNotify
    {
        public get() { return Service_GetCell(this, "hostage_bonus_chat", false); }
        public set(bool value) { this.SetValue("hostage_bonus_chat", value); }
    }

    property int BonusBombPlantedMoney
    {
        public get() { return Service_GetCell(this, "bomb_planted_bonus", 0); }
        public set(int value) { this.SetValue("bomb_planted_bonus", value); }
    }
    property int BonusBombPlantedMoneyRound
    {
        public get() { return Service_GetCell(this, "bomb_planted_bonus_round", 1); }
        public set(int value) { this.SetValue("bomb_planted_bonus_round", value); }
    }
    property bool BonusBombPlantedMoneyNotify
    {
        public get() { return Service_GetCell(this, "bomb_planted_bonus_chat", false); }
        public set(bool value) { this.SetValue("bomb_planted_bonus_chat", value); }
    }

    property int BonusBombDefusedMoney
    {
        public get() { return Service_GetCell(this, "bomb_defused_bonus", 0); }
        public set(int value) { this.SetValue("bomb_defused_bonus", value); }
    }
    property int BonusBombDefusedMoneyRound
    {
        public get() { return Service_GetCell(this, "bomb_defused_bonus_round", 1); }
        public set(int value) { this.SetValue("bomb_defused_bonus_round", value); }
    }
    property bool BonusBombDefusedMoneyNotify
    {
        public get() { return Service_GetCell(this, "bomb_defused_bonus_chat", false); }
        public set(bool value) { this.SetValue("bomb_defused_bonus_chat", value); }
    }

    property int BonusKillHP
    {
        public get() { return Service_GetCell(this, "kill_hp_bonus", 0); }
        public set(int value) { this.SetValue("kill_hp_bonus", value); }
    }
    property int BonusKillHPRound
    {
        public get() { return Service_GetCell(this, "kill_hp_bonus_round", 1); }
        public set(int value) { this.SetValue("kill_hp_bonus_round", value); }
    }
    property bool BonusKillHPNotify
    {
        public get() { return Service_GetCell(this, "kill_hp_bonus_chat", false); }
        public set(bool value) { this.SetValue("kill_hp_bonus_chat", value); }
    }

    property int BonusAssistHP
    {
        public get() { return Service_GetCell(this, "assist_hp_bonus", 0); }
        public set(int value) { this.SetValue("assist_hp_bonus", value); }
    }
    property int BonusAssistHPRound
    {
        public get() { return Service_GetCell(this, "assist_hp_bonus_round", 1); }
        public set(int value) { this.SetValue("assist_hp_bonus_round", value); }
    }
    property bool BonusAssistHPNotify
    {
        public get() { return Service_GetCell(this, "assist_hp_bonus_chat", false); }
        public set(bool value) { this.SetValue("assist_hp_bonus_chat", value); }
    }

    property int BonusHeadshotHP
    {
        public get() { return Service_GetCell(this, "headshot_hp_bonus", 0); }
        public set(int value) { this.SetValue("headshot_hp_bonus", value); }
    }
    property int BonusHeadshotHPRound
    {
        public get() { return Service_GetCell(this, "headshot_hp_bonus_round", 1); }
        public set(int value) { this.SetValue("headshot_hp_bonus_round", value); }
    }
    property bool BonusHeadshotHPNotify
    {
        public get() { return Service_GetCell(this, "headshot_hp_bonus_chat", false); }
        public set(bool value) { this.SetValue("headshot_hp_bonus_chat", value); }
    }

    property int BonusKnifeHP
    {
        public get() { return Service_GetCell(this, "knife_hp_bonus", 0); }
        public set(int value) { this.SetValue("knife_hp_bonus", value); }
    }
    property int BonusKnifeHPRound
    {
        public get() { return Service_GetCell(this, "knife_hp_bonus_round", 1); }
        public set(int value) { this.SetValue("knife_hp_bonus_round", value); }
    }
    property bool BonusKnifeHPNotify
    {
        public get() { return Service_GetCell(this, "knife_hp_bonus_chat", false); }
        public set(bool value) { this.SetValue("knife_hp_bonus_chat", value); }
    }

    property int BonusZeusHP
    {
        public get() { return Service_GetCell(this, "zeus_hp_bonus", 0); }
        public set(int value) { this.SetValue("zeus_hp_bonus", value); }
    }
    property int BonusZeusHPRound
    {
        public get() { return Service_GetCell(this, "zeus_hp_bonus_round", 1); }
        public set(int value) { this.SetValue("zeus_hp_bonus_round", value); }
    }
    property bool BonusZeusHPNotify
    {
        public get() { return Service_GetCell(this, "zeus_hp_bonus_chat", false); }
        public set(bool value) { this.SetValue("zeus_hp_bonus_chat", value); }
    }

    property int BonusGrenadeHP
    {
        public get() { return Service_GetCell(this, "grenade_hp_bonus", 0); }
        public set(int value) { this.SetValue("grenade_hp_bonus", value); }
    }
    property int BonusGrenadeHPRound
    {
        public get() { return Service_GetCell(this, "grenade_hp_bonus_round", 1); }
        public set(int value) { this.SetValue("grenade_hp_bonus_round", value); }
    }
    property bool BonusGrenadeHPNotify
    {
        public get() { return Service_GetCell(this, "grenade_hp_bonus_chat", false); }
        public set(bool value) { this.SetValue("grenade_hp_bonus_chat", value); }
    }

    property int BonusNoscopeHP
    {
        public get() { return Service_GetCell(this, "noscope_hp_bonus", 0); }
        public set(int value) { this.SetValue("noscope_hp_bonus", value); }
    }
    property int BonusNoscopeHPRound
    {
        public get() { return Service_GetCell(this, "noscope_hp_bonus_round", 1); }
        public set(int value) { this.SetValue("noscope_hp_bonus_round", value); }
    }
    property bool BonusNoscopeHPNotify
    {
        public get() { return Service_GetCell(this, "noscope_hp_bonus_chat", false); }
        public set(bool value) { this.SetValue("noscope_hp_bonus_chat", value); }
    }

    property bool ChatWelcomeMessage
    {
        public get() { return Service_GetCell(this, "chat_join_msg_enable", true); }
        public set(bool value) { this.SetValue("chat_join_msg_enable", value); }
    }

    public void GetChatWelcomeMessage(char[] output, int size) { Service_GetString(this, "chat_join_msg", output, size, ""); }
    public void SetChatWelcomeMessage(const char[] message) { this.SetString("chat_join_msg", message); }

    property bool ChatLeaveMessage
    {
        public get() { return Service_GetCell(this, "chat_leave_msg_enable", true); }
        public set(bool value) { this.SetValue("chat_leave_msg_enable", value); }
    }

    public void GetChatLeaveMessage(char[] output, int size) { Service_GetString(this, "chat_leave_msg", output, size, ""); }
    public void SetChatLeaveMessage(const char[] message) { this.SetString("chat_leave_msg", message); }

    property bool HudWelcomeMessage
    {
        public get() { return Service_GetCell(this, "hud_join_msg_enable", false); }
        public set(bool value) { this.SetValue("hud_join_msg_enable", value); }
    }

    public void GetHudWelcomeMessage(char[] output, int size) { Service_GetString(this, "hud_join_msg", output, size, ""); }
    public void SetHudWelcomeMessage(const char[] message) { this.SetString("hud_join_msg", message); }

    property bool HudLeaveMessage
    {
        public get() { return Service_GetCell(this, "hud_leave_msg_enable", false); }
        public set(bool value) { this.SetValue("hud_leave_msg_enable", value); }
    }

    public void GetHudLeaveMessage(char[] output, int size) { Service_GetString(this, "hud_leave_msg", output, size, ""); }
    public void SetHudLeaveMessage(const char[] message) { this.SetString("hud_leave_msg", message); }

    property float HudPositionX
    {
        public get() { return Service_GetCell(this, "hud_position_x", 0.0); }
        public set(float value) { this.SetValue("hud_position_x", value); }
    }
    property float HudPositionY
    {
        public get() { return Service_GetCell(this, "hud_position_y", 0.0); }
        public set(float value) { this.SetValue("hud_position_y", value); }
    }
    property int HudColorRed
    {
        public get() { return Service_GetCell(this, "hud_color_red", 255); }
        public set(int value) { this.SetValue("hud_color_red", value); }
    }
    property int HudColorGreen
    {
        public get() { return Service_GetCell(this, "hud_color_green", 255); }
        public set(int value) { this.SetValue("hud_color_green", value); }
    }
    property int HudColorBlue
    {
        public get() { return Service_GetCell(this, "hud_color_blue", 255); }
        public set(int value) { this.SetValue("hud_color_blue", value); }
    }
    property int HudColorAlpha
    {
        public get() { return Service_GetCell(this, "hud_color_alpha", 255); }
        public set(int value) { this.SetValue("hud_color_alpha", value); }
    }

    public void SetHudParams(
        float holdTime,
        int effect=0,
        float fxTime=6.0,
        float fadeIn=0.1,
        float fadeOut=0.2)
    {
        SetHudTextParams(
            this.HudPositionX,
            this.HudPositionY,
            holdTime,
            this.HudColorRed,
            this.HudColorGreen,
            this.HudColorBlue,
            this.HudColorAlpha,
            effect,
            fxTime,
            fadeIn,
            fadeOut);
    }

    property Menu WeaponMenu
    {
        public get() { return Service_GetCell(this, "weapon_menu", 0); }
        public set(Menu value) { this.SetValue("weapon_menu", value); }
    }
    property ArrayList Weapons
    {
        public get() { return Service_GetCell(this, "weapons_list", 0); }
        public set(ArrayList value) { this.SetValue("weapons_list", value); }
    }

    public bool IsWeaponAllowed(const char[] className)
    {
        return this.Weapons.FindString(className) != -1;
    }

    property int RifleWeaponsRound
    {
        public get() { return Service_GetCell(this, "rifles_menu_round", 0); }
        public set(int value) { this.SetValue("rifles_menu_round", value); }
    }
    property int PistolWeaponsRound
    {
        public get() { return Service_GetCell(this, "pistols_menu_round", 0); }
        public set(int value) { this.SetValue("pistols_menu_round", value); }
    }
}

static any Service_GetCell(Service svc, const char[] field, any defaultValue)
{
    any value;
    if (!svc.GetValue(field, value))
        return defaultValue;
    return value;
}

static void Service_GetString(
    Service svc,
    const char[] field,
    char[] output,
    int size,
    const char[] defaultValue)
{
    if (!svc.GetString(field, output, size))
        strcopy(output, size, defaultValue);
}
