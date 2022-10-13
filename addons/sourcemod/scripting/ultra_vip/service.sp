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

#define SERVICE_INTERNAL_PREFIX '_'


void Service_Delete(Service &svc)
{
    delete svc.WeaponMenu;
    delete svc.Weapons;

    delete svc;
}


Service Service_CloneByName(const char[] newName, const char[] oldName, bool caseSensitive=false)
{
    Service svc = FindServiceByName(oldName, caseSensitive);
    if (svc == null)
        return null;

    Service newSvc = view_as<Service>(svc.Clone());
    newSvc.SetName(newName);

    // Currently there is no way to clone menus so we just have to rebuild it.
    newSvc.WeaponMenu = null;
    newSvc.Weapons = null;

    return newSvc;
}


methodmap Service < StringMap
{
    public Service(const char[] name = "")
    {
        StringMap self = new StringMap();
        self.SetString("_name", name);
        return view_as<Service>(self);
    }

    public void GetName(char[] output, int size) { this.GetString("_name", output, size); }
    public void SetName(const char[] name) { this.SetString("_name", name); }

    property int Priority
    {
        public get() { return Service_GetCell(this, "_priority"); }
        public set(int value) { this.SetValue("_priority", value); }
    }

    property int Flag
    {
        public get() { return Service_GetCell(this, "_flag"); }
        public set(int flag)
        {
            if (flag && !HasOnlySingleBit(flag))
                ThrowError("Cannot set multiple admin flags for a Service.");
            this.SetValue("_flag", flag);
        }
    }

    public void GetOverride(char[] output, int size) { this.GetString("_override", output, size); }
    public void SetOverride(const char[] override) { this.SetString("_override", override); }

    public void GetChatTag(char[] output, int size) { this.GetString("_chat_tag", output, size); }
    public void SetChatTag(const char[] tag) { this.SetString("_chat_tag", tag); }

    public void GetChatNameColor(char[] output, int size) { this.GetString("_chat_name_color", output, size); }
    public void SetChatNameColor(const char[] tag) { this.SetString("_chat_name_color", tag); }

    public void GetChatMsgColor(char[] output, int size) { this.GetString("_chat_message_color", output, size); }
    public void SetChatMsgColor(const char[] tag) { this.SetString("_chat_message_color", tag); }

    public void GetScoreboardTag(char[] output, int size) { this.GetString("_scoreboard_tag", output, size); }
    public void SetScoreboardTag(const char[] tag) { this.SetString("_scoreboard_tag", tag); }

    property bool AllowDuringWarmup
    {
        public get() { return Service_GetCell(this, "_allow_during_warmup"); }
        public set(bool value) { this.SetValue("_allow_during_warmup", value); }
    }

    property int BonusPlayerHealth
    {
        public get() { return Service_GetCell(this, "_player_hp"); }
        public set(int value) { this.SetValue("_player_hp", value); }
    }
    property int BonusPlayerHealthRound
    {
        public get() { return Service_GetCell(this, "_player_hp_round"); }
        public set(int value) { this.SetValue("_player_hp_round", value); }
    }
    property int BonusMaxPlayerHealth
    {
        public get() { return Service_GetCell(this, "_player_max_hp"); }
        public set(int value) { this.SetValue("_player_max_hp", value); }
    }

    property bool BonusArmorEnabled
    {
        public get() { return Service_GetCell(this, "_player_vest"); }
        public set(bool value) { this.SetValue("_player_vest", value); }
    }
    property int BonusArmor
    {
        public get() { return Service_GetCell(this, "_player_vest_value"); }
        public set(int value) { this.SetValue("_player_vest_value", value); }
    }
    property int BonusArmorRound
    {
        public get() { return Service_GetCell(this, "_player_vest_round"); }
        public set(int value) { this.SetValue("_player_vest_round", value); }
    }

    property bool BonusHelmetEnabled
    {
        public get() { return Service_GetCell(this, "_player_helmet"); }
        public set(bool value) { this.SetValue("_player_helmet", value); }
    }
    property int BonusHelmetRound
    {
        public get() { return Service_GetCell(this, "_player_helmet_round"); }
        public set(int value) { this.SetValue("_player_helmet_round", value); }
    }

    property bool BonusDefuserEnabled
    {
        public get() { return Service_GetCell(this, "_player_defuser"); }
        public set(bool value) { this.SetValue("_player_defuser", value); }
    }
    property int BonusDefuserRound
    {
        public get() { return Service_GetCell(this, "_player_defuser_round"); }
        public set(int value) { this.SetValue("_player_defuser_round", value); }
    }

    // For use with grenade.sp::GivePlayerConsumables
    property bool ShouldStripConsumables
    {
        public get() { return Service_GetCell(this, "_strip_consumables"); }
        public set(bool value) { this.SetValue("_strip_consumables", value); }
    }

    property int BonusHEGrenades
    {
        public get() { return Service_GetCell(this, "_he_amount"); }
        public set(int value) { this.SetValue("_he_amount", value); }
    }
    property int BonusHEGrenadesRound
    {
        public get() { return Service_GetCell(this, "_he_round"); }
        public set(int value) { this.SetValue("_he_round", value); }
    }

    property int BonusFlashGrenades
    {
        public get() { return Service_GetCell(this, "_flash_amount"); }
        public set(int value) { this.SetValue("_flash_amount", value); }
    }
    property int BonusFlashGrenadesRound
    {
        public get() { return Service_GetCell(this, "_flash_round"); }
        public set(int value) { this.SetValue("_flash_round", value); }
    }

    property int BonusSmokeGrenades
    {
        public get() { return Service_GetCell(this, "_smoke_amount"); }
        public set(int value) { this.SetValue("_smoke_amount", value); }
    }
    property int BonusSmokeGrenadesRound
    {
        public get() { return Service_GetCell(this, "_smoke_round"); }
        public set(int value) { this.SetValue("_smoke_round", value); }
    }

    property int BonusDecoyGrenades
    {
        public get() { return Service_GetCell(this, "_decoy_amount"); }
        public set(int value) { this.SetValue("_decoy_amount", value); }
    }
    property int BonusDecoyGrenadesRound
    {
        public get() { return Service_GetCell(this, "_decoy_round"); }
        public set(int value) { this.SetValue("_decoy_round", value); }
    }

    property int BonusMolotovGrenades
    {
        public get() { return Service_GetCell(this, "_molotov_amount"); }
        public set(int value) { this.SetValue("_molotov_amount", value); }
    }
    property int BonusMolotovGrenadesRound
    {
        public get() { return Service_GetCell(this, "_molotov_round"); }
        public set(int value) { this.SetValue("_molotov_round", value); }
    }

    property int BonusHealthshotGrenades
    {
        public get() { return Service_GetCell(this, "_healthshot_amount"); }
        public set(int value) { this.SetValue("_healthshot_amount", value); }
    }
    property int BonusHealthshotGrenadesRound
    {
        public get() { return Service_GetCell(this, "_healthshot_round"); }
        public set(int value) { this.SetValue("_healthshot_round", value); }
    }

    property int BonusTacticalGrenades
    {
        public get() { return Service_GetCell(this, "_tag_amount"); }
        public set(int value) { this.SetValue("_tag_amount", value); }
    }
    property int BonusTacticalGrenadesRound
    {
        public get() { return Service_GetCell(this, "_tag_round"); }
        public set(int value) { this.SetValue("_tag_round", value); }
    }

    property int BonusSnowballGrenades
    {
        public get() { return Service_GetCell(this, "_snowball_amount"); }
        public set(int value) { this.SetValue("_snowball_amount", value); }
    }
    property int BonusSnowballGrenadesRound
    {
        public get() { return Service_GetCell(this, "_snowball_round"); }
        public set(int value) { this.SetValue("_snowball_round", value); }
    }

    property int BonusBreachchargeGrenades
    {
        public get() { return Service_GetCell(this, "_breachcharge_amount"); }
        public set(int value) { this.SetValue("_breachcharge_amount", value); }
    }
    property int BonusBreachchargeGrenadesRound
    {
        public get() { return Service_GetCell(this, "_breachcharge_round"); }
        public set(int value) { this.SetValue("_breachcharge_round", value); }
    }

    property int BonusBumpmineGrenades
    {
        public get() { return Service_GetCell(this, "_bumpmine_amount"); }
        public set(int value) { this.SetValue("_bumpmine_amount", value); }
    }
    property int BonusBumpmineGrenadesRound
    {
        public get() { return Service_GetCell(this, "_bumpmine_round"); }
        public set(int value) { this.SetValue("_bumpmine_round", value); }
    }

    property int BonusExtraJumps
    {
        public get() { return Service_GetCell(this, "_player_extra_jumps"); }
        public set(int value) { this.SetValue("_player_extra_jumps", value); }
    }
    property float BonusJumpHeight
    {
        public get() { return Service_GetCell(this, "_player_extra_jump_height"); }
        public set(float value) { this.SetValue("_player_extra_jump_height", value); }
    }
    property int BonusExtraJumpsRound
    {
        public get() { return Service_GetCell(this, "_player_extra_jumps_round"); }
        public set(int value) { this.SetValue("_player_extra_jumps_round", value); }
    }
    property bool BonusExtraJumpsTakeFallDamage
    {
        public get() { return Service_GetCell(this, "_player_extra_jumps_falldamage"); }
        public set(bool value) { this.SetValue("_player_extra_jumps_falldamage", value); }
    }

    property bool BonusPlayerShield
    {
        public get() { return Service_GetCell(this, "_player_shield"); }
        public set(bool value) { this.SetValue("_player_shield", value); }
    }
    property int BonusPlayerShieldRound
    {
        public get() { return Service_GetCell(this, "_player_shield_round"); }
        public set(int value) { this.SetValue("_player_shield_round", value); }
    }

    property float BonusPlayerGravity
    {
        public get() { return Service_GetCell(this, "_player_gravity"); }
        public set(float value) { this.SetValue("_player_gravity", value); }
    }
    property int BonusPlayerGravityRound
    {
        public get() { return Service_GetCell(this, "_player_gravity_round"); }
        public set(int value) { this.SetValue("_player_gravity_round", value); }
    }

    property float BonusPlayerSpeed
    {
        public get() { return Service_GetCell(this, "_player_speed"); }
        public set(float value) { this.SetValue("_player_speed", value); }
    }
    property int BonusPlayerSpeedRound
    {
        public get() { return Service_GetCell(this, "_player_speed_round"); }
        public set(int value) { this.SetValue("_player_speed_round", value); }
    }

    property int BonusPlayerVisibility
    {
        public get() { return Service_GetCell(this, "_player_visibility"); }
        public set(int value) { this.SetValue("_player_visibility", value); }
    }
    property int BonusPlayerVisibilityRound
    {
        public get() { return Service_GetCell(this, "_player_visibility_round"); }
        public set(int value) { this.SetValue("_player_visibility_round", value); }
    }

    property int BonusPlayerRespawnPercent
    {
        public get() { return Service_GetCell(this, "_player_respawn_percent"); }
        public set(int value) { this.SetValue("_player_respawn_percent", value); }
    }
    property int BonusPlayerRespawnPercentRound
    {
        public get() { return Service_GetCell(this, "_player_respawn_round"); }
        public set(int value) { this.SetValue("_player_respawn_round", value); }
    }
    property bool BonusPlayerRespawnPercentNotify
    {
        public get() { return Service_GetCell(this, "_player_respawn_notify"); }
        public set(bool value) { this.SetValue("_player_respawn_notify", value); }
    }

    property int BonusPlayerFallDamagePercent
    {
        public get() { return Service_GetCell(this, "_player_fall_damage_percent"); }
        public set(int value) { this.SetValue("_player_fall_damage_percent", value); }
    }
    property int BonusPlayerFallDamagePercentRound
    {
        public get() { return Service_GetCell(this, "_player_fall_damage_round"); }
        public set(int value) { this.SetValue("_player_fall_damage_round", value); }
    }

    property int BonusPlayerAttackDamage
    {
        public get() { return Service_GetCell(this, "_player_attack_damage"); }
        public set(int value) { this.SetValue("_player_attack_damage", value); }
    }
    property int BonusPlayerAttackDamageRound
    {
        public get() { return Service_GetCell(this, "_player_attack_damage_round"); }
        public set(int value) { this.SetValue("_player_attack_damage_round", value); }
    }

    property int BonusPlayerDamageResist
    {
        public get() { return Service_GetCell(this, "_player_damage_resist"); }
        public set(int value) { this.SetValue("_player_damage_resist", value); }
    }
    property int BonusPlayerDamageResistRound
    {
        public get() { return Service_GetCell(this, "_player_damage_resist_round"); }
        public set(int value) { this.SetValue("_player_damage_resist_round", value); }
    }

    property bool BonusUnlimitedAmmo
    {
        public get() { return Service_GetCell(this, "_player_unlimited_ammo"); }
        public set(bool value) { this.SetValue("_player_unlimited_ammo", value); }
    }
    property int BonusUnlimitedAmmoRound
    {
        public get() { return Service_GetCell(this, "_player_unlimited_ammo_round"); }
        public set(int value) { this.SetValue("_player_unlimited_ammo_round", value); }
    }

    property bool BonusNoRecoil
    {
        public get() { return Service_GetCell(this, "_player_no_recoil"); }
        public set(bool value) { this.SetValue("_player_no_recoil", value); }
    }
    property int BonusNoRecoilRound
    {
        public get() { return Service_GetCell(this, "_player_no_recoil_round"); }
        public set(int value) { this.SetValue("_player_no_recoil_round", value); }
    }

    property int BonusSpawnMoney
    {
        public get() { return Service_GetCell(this, "_spawn_bonus"); }
        public set(int value) { this.SetValue("_spawn_bonus", value); }
    }
    property int BonusSpawnMoneyRound
    {
        public get() { return Service_GetCell(this, "_spawn_bonus_round"); }
        public set(int value) { this.SetValue("_spawn_bonus_round", value); }
    }
    property bool BonusSpawnMoneyNotify
    {
        public get() { return Service_GetCell(this, "_spawn_bonus_chat"); }
        public set(bool value) { this.SetValue("_spawn_bonus_chat", value); }
    }

    property int BonusKillMoney
    {
        public get() { return Service_GetCell(this, "_kill_bonus"); }
        public set(int value) { this.SetValue("_kill_bonus", value); }
    }
    property int BonusKillMoneyRound
    {
        public get() { return Service_GetCell(this, "_kill_bonus_round"); }
        public set(int value) { this.SetValue("_kill_bonus_round", value); }
    }
    property bool BonusKillMoneyNotify
    {
        public get() { return Service_GetCell(this, "_kill_bonus_chat"); }
        public set(bool value) { this.SetValue("_kill_bonus_chat", value); }
    }

    property int BonusAssistMoney
    {
        public get() { return Service_GetCell(this, "_assist_bonus"); }
        public set(int value) { this.SetValue("_assist_bonus", value); }
    }
    property int BonusAssistMoneyRound
    {
        public get() { return Service_GetCell(this, "_assist_bonus_round"); }
        public set(int value) { this.SetValue("_assist_bonus_round", value); }
    }
    property bool BonusAssistMoneyNotify
    {
        public get() { return Service_GetCell(this, "_assist_bonus_chat"); }
        public set(bool value) { this.SetValue("_assist_bonus_chat", value); }
    }

    property int BonusHeadshotMoney
    {
        public get() { return Service_GetCell(this, "_headshot_bonus"); }
        public set(int value) { this.SetValue("_headshot_bonus", value); }
    }
    property int BonusHeadshotMoneyRound
    {
        public get() { return Service_GetCell(this, "_headshot_bonus_round"); }
        public set(int value) { this.SetValue("_headshot_bonus_round", value); }
    }
    property bool BonusHeadshotMoneyNotify
    {
        public get() { return Service_GetCell(this, "_headshot_bonus_chat"); }
        public set(bool value) { this.SetValue("_headshot_bonus_chat", value); }
    }

    property int BonusKnifeMoney
    {
        public get() { return Service_GetCell(this, "_knife_bonus"); }
        public set(int value) { this.SetValue("_knife_bonus", value); }
    }
    property int BonusKnifeMoneyRound
    {
        public get() { return Service_GetCell(this, "_knife_bonus_round"); }
        public set(int value) { this.SetValue("_knife_bonus_round", value); }
    }
    property bool BonusKnifeMoneyNotify
    {
        public get() { return Service_GetCell(this, "_knife_bonus_chat"); }
        public set(bool value) { this.SetValue("_knife_bonus_chat", value); }
    }

    property int BonusZeusMoney
    {
        public get() { return Service_GetCell(this, "_zeus_bonus"); }
        public set(int value) { this.SetValue("_zeus_bonus", value); }
    }
    property int BonusZeusMoneyRound
    {
        public get() { return Service_GetCell(this, "_zeus_bonus_round"); }
        public set(int value) { this.SetValue("_zeus_bonus_round", value); }
    }
    property bool BonusZeusMoneyNotify
    {
        public get() { return Service_GetCell(this, "_zeus_bonus_chat"); }
        public set(bool value) { this.SetValue("_zeus_bonus_chat", value); }
    }

    property int BonusGrenadeMoney
    {
        public get() { return Service_GetCell(this, "_grenade_bonus"); }
        public set(int value) { this.SetValue("_grenade_bonus", value); }
    }
    property int BonusGrenadeMoneyRound
    {
        public get() { return Service_GetCell(this, "_grenade_bonus_round"); }
        public set(int value) { this.SetValue("_grenade_bonus_round", value); }
    }
    property bool BonusGrenadeMoneyNotify
    {
        public get() { return Service_GetCell(this, "_grenade_bonus_chat"); }
        public set(bool value) { this.SetValue("_grenade_bonus_chat", value); }
    }

    property int BonusMvpMoney
    {
        public get() { return Service_GetCell(this, "_mvp_bonus"); }
        public set(int value) { this.SetValue("_mvp_bonus", value); }
    }
    property int BonusMvpMoneyRound
    {
        public get() { return Service_GetCell(this, "_mvp_bonus_round"); }
        public set(int value) { this.SetValue("_mvp_bonus_round", value); }
    }
    property bool BonusMvpMoneyNotify
    {
        public get() { return Service_GetCell(this, "_mvp_bonus_chat"); }
        public set(bool value) { this.SetValue("_mvp_bonus_chat", value); }
    }

    property int BonusNoscopeMoney
    {
        public get() { return Service_GetCell(this, "_noscope_bonus"); }
        public set(int value) { this.SetValue("_noscope_bonus", value); }
    }
    property int BonusNoscopeMoneyRound
    {
        public get() { return Service_GetCell(this, "_noscope_bonus_round"); }
        public set(int value) { this.SetValue("_noscope_bonus_round", value); }
    }
    property bool BonusNoscopeMoneyNotify
    {
        public get() { return Service_GetCell(this, "_noscope_bonus_chat"); }
        public set(bool value) { this.SetValue("_noscope_bonus_chat", value); }
    }

    property int BonusHostageMoney
    {
        public get() { return Service_GetCell(this, "_hostage_bonus"); }
        public set(int value) { this.SetValue("_hostage_bonus", value); }
    }
    property int BonusHostageMoneyRound
    {
        public get() { return Service_GetCell(this, "_hostage_bonus_round"); }
        public set(int value) { this.SetValue("_hostage_bonus_round", value); }
    }
    property bool BonusHostageMoneyNotify
    {
        public get() { return Service_GetCell(this, "_hostage_bonus_chat"); }
        public set(bool value) { this.SetValue("_hostage_bonus_chat", value); }
    }

    property int BonusBombPlantedMoney
    {
        public get() { return Service_GetCell(this, "_bomb_planted_bonus"); }
        public set(int value) { this.SetValue("_bomb_planted_bonus", value); }
    }
    property int BonusBombPlantedMoneyRound
    {
        public get() { return Service_GetCell(this, "_bomb_planted_bonus_round"); }
        public set(int value) { this.SetValue("_bomb_planted_bonus_round", value); }
    }
    property bool BonusBombPlantedMoneyNotify
    {
        public get() { return Service_GetCell(this, "_bomb_planted_bonus_chat"); }
        public set(bool value) { this.SetValue("_bomb_planted_bonus_chat", value); }
    }

    property int BonusBombDefusedMoney
    {
        public get() { return Service_GetCell(this, "_bomb_defused_bonus"); }
        public set(int value) { this.SetValue("_bomb_defused_bonus", value); }
    }
    property int BonusBombDefusedMoneyRound
    {
        public get() { return Service_GetCell(this, "_bomb_defused_bonus_round"); }
        public set(int value) { this.SetValue("_bomb_defused_bonus_round", value); }
    }
    property bool BonusBombDefusedMoneyNotify
    {
        public get() { return Service_GetCell(this, "_bomb_defused_bonus_chat"); }
        public set(bool value) { this.SetValue("_bomb_defused_bonus_chat", value); }
    }

    property int BonusKillHP
    {
        public get() { return Service_GetCell(this, "_kill_hp_bonus"); }
        public set(int value) { this.SetValue("_kill_hp_bonus", value); }
    }
    property int BonusKillHPRound
    {
        public get() { return Service_GetCell(this, "_kill_hp_bonus_round"); }
        public set(int value) { this.SetValue("_kill_hp_bonus_round", value); }
    }
    property bool BonusKillHPNotify
    {
        public get() { return Service_GetCell(this, "_kill_hp_bonus_chat"); }
        public set(bool value) { this.SetValue("_kill_hp_bonus_chat", value); }
    }

    property int BonusAssistHP
    {
        public get() { return Service_GetCell(this, "_assist_hp_bonus"); }
        public set(int value) { this.SetValue("_assist_hp_bonus", value); }
    }
    property int BonusAssistHPRound
    {
        public get() { return Service_GetCell(this, "_assist_hp_bonus_round"); }
        public set(int value) { this.SetValue("_assist_hp_bonus_round", value); }
    }
    property bool BonusAssistHPNotify
    {
        public get() { return Service_GetCell(this, "_assist_hp_bonus_chat"); }
        public set(bool value) { this.SetValue("_assist_hp_bonus_chat", value); }
    }

    property int BonusHeadshotHP
    {
        public get() { return Service_GetCell(this, "_headshot_hp_bonus"); }
        public set(int value) { this.SetValue("_headshot_hp_bonus", value); }
    }
    property int BonusHeadshotHPRound
    {
        public get() { return Service_GetCell(this, "_headshot_hp_bonus_round"); }
        public set(int value) { this.SetValue("_headshot_hp_bonus_round", value); }
    }
    property bool BonusHeadshotHPNotify
    {
        public get() { return Service_GetCell(this, "_headshot_hp_bonus_chat"); }
        public set(bool value) { this.SetValue("_headshot_hp_bonus_chat", value); }
    }

    property int BonusKnifeHP
    {
        public get() { return Service_GetCell(this, "_knife_hp_bonus"); }
        public set(int value) { this.SetValue("_knife_hp_bonus", value); }
    }
    property int BonusKnifeHPRound
    {
        public get() { return Service_GetCell(this, "_knife_hp_bonus_round"); }
        public set(int value) { this.SetValue("_knife_hp_bonus_round", value); }
    }
    property bool BonusKnifeHPNotify
    {
        public get() { return Service_GetCell(this, "_knife_hp_bonus_chat"); }
        public set(bool value) { this.SetValue("_knife_hp_bonus_chat", value); }
    }

    property int BonusZeusHP
    {
        public get() { return Service_GetCell(this, "_zeus_hp_bonus"); }
        public set(int value) { this.SetValue("_zeus_hp_bonus", value); }
    }
    property int BonusZeusHPRound
    {
        public get() { return Service_GetCell(this, "_zeus_hp_bonus_round"); }
        public set(int value) { this.SetValue("_zeus_hp_bonus_round", value); }
    }
    property bool BonusZeusHPNotify
    {
        public get() { return Service_GetCell(this, "_zeus_hp_bonus_chat"); }
        public set(bool value) { this.SetValue("_zeus_hp_bonus_chat", value); }
    }

    property int BonusGrenadeHP
    {
        public get() { return Service_GetCell(this, "_grenade_hp_bonus"); }
        public set(int value) { this.SetValue("_grenade_hp_bonus", value); }
    }
    property int BonusGrenadeHPRound
    {
        public get() { return Service_GetCell(this, "_grenade_hp_bonus_round"); }
        public set(int value) { this.SetValue("_grenade_hp_bonus_round", value); }
    }
    property bool BonusGrenadeHPNotify
    {
        public get() { return Service_GetCell(this, "_grenade_hp_bonus_chat"); }
        public set(bool value) { this.SetValue("_grenade_hp_bonus_chat", value); }
    }

    property int BonusNoscopeHP
    {
        public get() { return Service_GetCell(this, "_noscope_hp_bonus"); }
        public set(int value) { this.SetValue("_noscope_hp_bonus", value); }
    }
    property int BonusNoscopeHPRound
    {
        public get() { return Service_GetCell(this, "_noscope_hp_bonus_round"); }
        public set(int value) { this.SetValue("_noscope_hp_bonus_round", value); }
    }
    property bool BonusNoscopeHPNotify
    {
        public get() { return Service_GetCell(this, "_noscope_hp_bonus_chat"); }
        public set(bool value) { this.SetValue("_noscope_hp_bonus_chat", value); }
    }

    property bool ChatWelcomeMessage
    {
        public get() { return Service_GetCell(this, "_chat_join_msg_enable"); }
        public set(bool value) { this.SetValue("_chat_join_msg_enable", value); }
    }

    public void GetChatWelcomeMessage(char[] output, int size) { this.GetString("_chat_join_msg", output, size); }
    public void SetChatWelcomeMessage(const char[] message) { this.SetString("_chat_join_msg", message); }

    property bool ChatLeaveMessage
    {
        public get() { return Service_GetCell(this, "_chat_leave_msg_enable"); }
        public set(bool value) { this.SetValue("_chat_leave_msg_enable", value); }
    }

    public void GetChatLeaveMessage(char[] output, int size) { this.GetString("_chat_leave_msg", output, size); }
    public void SetChatLeaveMessage(const char[] message) { this.SetString("_chat_leave_msg", message); }

    property bool HudWelcomeMessage
    {
        public get() { return Service_GetCell(this, "_hud_join_msg_enable"); }
        public set(bool value) { this.SetValue("_hud_join_msg_enable", value); }
    }

    public void GetHudWelcomeMessage(char[] output, int size) { this.GetString("_hud_join_msg", output, size); }
    public void SetHudWelcomeMessage(const char[] message) { this.SetString("_hud_join_msg", message); }

    property bool HudLeaveMessage
    {
        public get() { return Service_GetCell(this, "_hud_leave_msg_enable"); }
        public set(bool value) { this.SetValue("_hud_leave_msg_enable", value); }
    }

    public void GetHudLeaveMessage(char[] output, int size) { this.GetString("_hud_leave_msg", output, size); }
    public void SetHudLeaveMessage(const char[] message) { this.SetString("_hud_leave_msg", message); }

    property float HudPositionX
    {
        public get() { return Service_GetCell(this, "_hud_position_x"); }
        public set(float value) { this.SetValue("_hud_position_x", value); }
    }
    property float HudPositionY
    {
        public get() { return Service_GetCell(this, "_hud_position_y"); }
        public set(float value) { this.SetValue("_hud_position_y", value); }
    }
    property int HudColorRed
    {
        public get() { return Service_GetCell(this, "_hud_color_red"); }
        public set(int value) { this.SetValue("_hud_color_red", value); }
    }
    property int HudColorGreen
    {
        public get() { return Service_GetCell(this, "_hud_color_green"); }
        public set(int value) { this.SetValue("_hud_color_green", value); }
    }
    property int HudColorBlue
    {
        public get() { return Service_GetCell(this, "_hud_color_blue"); }
        public set(int value) { this.SetValue("_hud_color_blue", value); }
    }
    property int HudColorAlpha
    {
        public get() { return Service_GetCell(this, "_hud_color_alpha"); }
        public set(int value) { this.SetValue("_hud_color_alpha", value); }
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
        public get() { return Service_GetCell(this, "_weapon_menu"); }
        public set(Menu value) { this.SetValue("_weapon_menu", value); }
    }
    property ArrayList Weapons
    {
        public get() { return Service_GetCell(this, "_weapons_list"); }
        public set(ArrayList value) { this.SetValue("_weapons_list", value); }
    }

    public bool IsWeaponAllowed(const char[] className)
    {
        return this.Weapons.FindString(className) != -1;
    }

    property int RifleWeaponsRound
    {
        public get() { return Service_GetCell(this, "_rifles_menu_round"); }
        public set(int value) { this.SetValue("_rifles_menu_round", value); }
    }
    property bool RifleWeaponsEnabled
    {
        public get() { return Service_GetCell(this, "_rifles_menu_enabled"); }
        public set(bool value) { this.SetValue("_rifles_menu_enabled", value); }
    }
    property int PistolWeaponsRound
    {
        public get() { return Service_GetCell(this, "_pistols_menu_round"); }
        public set(int value) { this.SetValue("_pistols_menu_round", value); }
    }
    property bool PistolWeaponsEnabled
    {
        public get() { return Service_GetCell(this, "_pistols_menu_enabled"); }
        public set(bool value) { this.SetValue("_pistols_menu_enabled", value); }
    }
}

static any Service_GetCell(Service svc, const char[] field)
{
    any value;
    if (!svc.GetValue(field, value))
        ThrowError("Service %x is missing field '%s'", svc, field);
    return value;
}


#if defined COMPILER_IS_SM1_11
static_assert(view_as<int>(SettingType_TOTAL) == 9, "SettingType was added without being handled in Service_AddModuleSetting");
#endif
void Service_AddModuleSetting(
    Service svc,
    SettingType type,
    const char[] settingName,
    const char[] value)
{
    if (type == Type_String)
    {
        svc.SetString(settingName, value);
        return;
    }

    any result;

    switch (type)
    {
        case Type_Byte:
        {
            if (!SettingType_Byte(value, result))
                return;
        }
        case Type_UnsignedByte:
        {
            if (!SettingType_UnsignedByte(value, result))
                return;
        }
        case Type_Integer:
        {
            if (!SettingType_Integer(value, result))
                return;
        }
        case Type_Bool:
        {
            if (!SettingType_Bool(value, result))
                return;
        }
        case Type_Hex:
        {
            if (!SettingType_Hex(value, result))
                return;
        }
        case Type_Float:
        {
            if (!SettingType_Float(value, result))
                return;
        }
        case Type_RGBHex:
        {
            if (!SettingType_RGBHex(value, result))
                return;
        }
        case Type_RGBAHex:
        {
            if (!SettingType_RGBAHex(value, result))
                return;
        }

        default:
        {
            ThrowError("Unknown SettingType %i", type);
        }
    }

    svc.SetValue(settingName, result);
}
