/**
 * Copyright (C) SirDigbot & Mesharsky
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

// Arbitrary limits to prevent creating too many entities
#define GIVE_BREACH_CHARGE_LIMIT 32
#define GIVE_BUMP_MINE_LIMIT 32


static bool s_AreAmmoTypesSet;

static int s_AmmoTypeHE;
static int s_AmmoTypeSmoke;
static int s_AmmoTypeFlashbang;
static int s_AmmoTypeMolotov;
static int s_AmmoTypeIncendiary;
static int s_AmmoTypeDecoy;
static int s_AmmoTypeBreachCharge;
static int s_AmmoTypeBumpMine;
static int s_AmmoTypeTAG;
static int s_AmmoTypeSnowball;
static int s_AmmoTypeHealthshot;

static ConVar s_limitTotal;
static ConVar s_limitDefault;
static ConVar s_limitFlash;
static ConVar s_limitSnowball;
static ConVar s_limitHealthshot;


/**
 * List of each type of consumable item CSGO supports.
 *
 * If you modify this, you'll also need to modify:
 *      - s_Classnames
 *      - s_IsConsumableIDList
 *      - ConsumableItems enum struct
 *          - ConsumableItems::Reset()
 *          - ConsumableItems::SetFromClientService()
 *      - AddConsumableAmmo()
 *      - StripPlayerConsumables()
 *      - GivePlayerConsumables()
 *      - GetAllAmmoTypes()
 *      - Possibly GetAllLimitCvars()
 *      - Possibly GetTotalGrenades()
 *      - GetAmmoCount()
 *
 * Why I have designed it this way is because I am dumb as fuck. Enjoy.
 * Love, Digby.
 */
enum CSItemType
{
    Item_HE = 0,    // Values are all array indexes for s_Classnames
    Item_Smoke,
    Item_Flashbang,
    Item_FireNade,  // Molotov OR Incendiary depending on team.
    Item_Molotov,
    Item_Incendiary,
    Item_Decoy,

    Item_BreachCharge,
    Item_BumpMine,
    Item_TAG,

    Item_Snowball,
    Item_Healthshot
}

// Classnames per each CSItemType, indexed by each CSItemType
static const char s_Classnames[][] =
{
    "weapon_hegrenade",
    "weapon_smokegrenade",
    "weapon_flashbang",
    "",
    "weapon_molotov",
    "weapon_incgrenade",
    "weapon_decoy",

    "weapon_breachcharge",
    "weapon_bumpmine",
    "weapon_tagrenade",

    "weapon_snowball",
    "weapon_healthshot"
};

// List of *valid* CSWeaponIDs for IsConsumable()
// This must not have CSWeapon_NONE or it breaks StripPlayerConsumables
static const CSWeaponID s_IsConsumableIDList[] =
{
    CSWeapon_HEGRENADE,
    CSWeapon_SMOKEGRENADE,
    CSWeapon_FLASHBANG,
    // No FireNade
    CSWeapon_MOLOTOV,
    CSWeapon_INCGRENADE,
    CSWeapon_DECOY,
    CSWeapon_BREACHCHARGE,
    CSWeapon_BUMPMINE,
    CSWeapon_TAGGRENADE,
    CSWeapon_SNOWBALL,
    CSWeapon_HEALTHSHOT
};


enum struct ConsumableItems
{
    int heAmmo;
    int smokeAmmo;
    int flashbangAmmo;
    int molotovAmmo;
    // No FireNade
    int incendiaryAmmo;
    int decoyAmmo;
    int breachChargeAmmo;
    int bumpMineAmmo;
    int tagAmmo;
    int snowballAmmo;
    int healthshotAmmo;

    void Reset()
    {
        this.heAmmo = 0;
        this.smokeAmmo = 0;
        this.flashbangAmmo = 0;
        this.molotovAmmo = 0;
        this.incendiaryAmmo = 0;
        this.decoyAmmo = 0;
        this.breachChargeAmmo = 0;
        this.bumpMineAmmo = 0;
        this.tagAmmo = 0;
        this.snowballAmmo = 0;
        this.healthshotAmmo = 0;
    }

    void SetFromClientService(int client, Service svc)
    {
        this.Reset();

        if (svc == null)
            return;

        if (IsRoundAllowed(svc.BonusHEGrenadesRound))
            this.heAmmo = svc.BonusHEGrenades;
        if (IsRoundAllowed(svc.BonusSmokeGrenadesRound))
            this.smokeAmmo = svc.BonusSmokeGrenades;
        if (IsRoundAllowed(svc.BonusFlashGrenadesRound))
            this.flashbangAmmo = svc.BonusFlashGrenades;

        CSItemType type = GetFireNadeType(client);
        if (IsRoundAllowed(svc.BonusMolotovGrenadesRound))
        {
            if (type == Item_Molotov)
                this.molotovAmmo = svc.BonusMolotovGrenades;
            else
                this.incendiaryAmmo = svc.BonusMolotovGrenades;
        }

        if (IsRoundAllowed(svc.BonusDecoyGrenadesRound))
            this.decoyAmmo = svc.BonusDecoyGrenades;

        if (IsRoundAllowed(svc.BonusBreachchargeGrenadesRound))
            this.breachChargeAmmo = svc.BonusBreachchargeGrenades;
        if (IsRoundAllowed(svc.BonusBumpmineGrenadesRound))
            this.bumpMineAmmo = svc.BonusBumpmineGrenades;
        if (IsRoundAllowed(svc.BonusTacticalGrenadesRound))
            this.tagAmmo = svc.BonusTacticalGrenades;

        if (IsRoundAllowed(svc.BonusSnowballGrenadesRound))
            this.snowballAmmo = svc.BonusSnowballGrenades;
        if (IsRoundAllowed(svc.BonusHealthshotGrenadesRound))
            this.healthshotAmmo = svc.BonusHealthshotGrenades;
    }
}

bool GivePlayerConsumables(
    int client,
    const ConsumableItems items,
    bool strip=false)
{
    if (!IsClientInGame(client))
        return false;

    if (!s_AreAmmoTypesSet)
        GetAllAmmoTypes();

    if (strip)
        StripPlayerConsumables(client);

    // AddConsumableAmmo adds up to a target amount, and no further.
    // That means if a player is to get 2 flashes but already has 1,
    // we only add 1 even if the limit is higher.
    AddConsumableAmmo(client, Item_HE, items.heAmmo);
    AddConsumableAmmo(client, Item_Smoke, items.smokeAmmo);
    AddConsumableAmmo(client, Item_Flashbang, items.flashbangAmmo);
    AddConsumableAmmo(client, Item_Molotov, items.molotovAmmo);
    AddConsumableAmmo(client, Item_Incendiary, items.incendiaryAmmo);
    AddConsumableAmmo(client, Item_Decoy, items.decoyAmmo);
    AddConsumableAmmo(client, Item_BreachCharge, items.breachChargeAmmo);
    AddConsumableAmmo(client, Item_BumpMine, items.bumpMineAmmo);
    AddConsumableAmmo(client, Item_TAG, items.tagAmmo);
    AddConsumableAmmo(client, Item_Snowball, items.snowballAmmo);
    AddConsumableAmmo(client, Item_Healthshot, items.healthshotAmmo);

    return true;
}

/**
 * Add ammo for a consumable item up to a specific amount.
 *
 * Will not exceed any limits that cause the item to drop on the ground,
 * and will not remove items if a negative amount is specified.
 */
static void AddConsumableAmmo(int client, CSItemType type, int targetAmount)
{
    /**
     * NOTE: A few important notes for making this function work.
     *
     * 1) ammo_grenade_limit_default is per-each-type.
     *
     * 2) TA Grenades obey ammo_grenade_limit_default, but
     *    Breach charges, Bump mines, Snowballs and Healthshots don't.
     * 3) Breach charges and Bump mines conflict.
     * 4) Breach charges and Bump mines prevent you picking up C4, unless
     *    you pick up the C4 first.
     *    This is ignored by GivePlayerItem.
     * 5) ammo_grenade_limit_breachcharge and ammo_grenade_limit_bumpmine
     *    only control the reserve ammo which you can't use anyway.
     * 6) For everything except Breach charge and Bump mine, you just use
     *    GivePlayerItem.
     *    For those 2 exceptions, you only give if they dont already have
     *    one (or it will drop on the ground) and then you set m_iClip1
     *    to set the ammo.
     * 7) BUG: There's some mysterious limit between TA Grenades and flashes
     *    that I can't seem to figure out.
     */

    if (!s_AreAmmoTypesSet)
        GetAllAmmoTypes();

    if (s_limitTotal == null)
        GetAllLimitCvars();

    if (type == Item_FireNade)
        type = GetFireNadeType(client);

    switch (type)
    {
        case Item_HE, Item_Smoke, Item_Molotov, Item_Incendiary, Item_Decoy,
            Item_TAG, Item_Flashbang:
        {
            // Flashbangs are the only one that use the s_limitTotal
            // but not s_limitDefault
            int totalLimit = s_limitTotal.IntValue;
            int currentTotal = GetTotalGrenades(client);
            int typeLimit = (type == Item_Flashbang) ? s_limitFlash.IntValue : s_limitDefault.IntValue;
            int currentOfType = GetAmmoCount(client, type);

            int maxGiveable = _MIN(typeLimit - currentOfType, totalLimit - currentTotal);

            targetAmount = _MIN(maxGiveable, targetAmount);

            for (int i = 0; i < targetAmount; ++i)
                GivePlayerItem(client, s_Classnames[view_as<int>(type)]);
        }

        case Item_BreachCharge:
        {
            if (targetAmount <= 0)
                return;
            targetAmount = _MIN(targetAmount, GIVE_BREACH_CHARGE_LIMIT);

            // Conflicts with bump mine
            if (GetPlayerWeapon(client, CSWeapon_BUMPMINE) != -1)
                return;

            RemoveC4GiveItem(
                client,
                CSWeapon_BREACHCHARGE,
                s_Classnames[view_as<int>(type)],
                targetAmount);
        }

        case Item_BumpMine:
        {
            if (targetAmount <= 0)
                return;
            targetAmount = _MIN(targetAmount, GIVE_BUMP_MINE_LIMIT);

            // Conflicts with breach charge
            if (GetPlayerWeapon(client, CSWeapon_BREACHCHARGE) != -1)
                return;

            RemoveC4GiveItem(
                client,
                CSWeapon_BUMPMINE,
                s_Classnames[view_as<int>(type)],
                targetAmount);
        }

        case Item_Snowball:
        {
            int current = GetAmmoCount(client, type);
            int limit = s_limitSnowball.IntValue - current;

            targetAmount = _MIN(limit, targetAmount);

            for (int i = 0; i < targetAmount; ++i)
                GivePlayerItem(client, s_Classnames[view_as<int>(type)]);
        }

        case Item_Healthshot:
        {
            int current = GetAmmoCount(client, type);
            int limit = s_limitHealthshot.IntValue - current;

            targetAmount = _MIN(limit, targetAmount);

            for (int i = 0; i < targetAmount; ++i)
                GivePlayerItem(client, s_Classnames[view_as<int>(type)]);
        }
    }
}

static void StripPlayerConsumables(int client)
{
    int maxWeapons = GetEntPropArraySize(client, Prop_Send, "m_hMyWeapons");
    for (int i = 0; i < maxWeapons; i++)
    {
        int weapon = GetEntPropEnt(client, Prop_Send, "m_hMyWeapons", i);

        if (IsConsumable(GetWeaponEntityID(weapon)))
            DeleteWeapon(client, weapon);
    }

    // Fix ammo pool since we just deleted all of the consumable entities,
    // but haven't actually changed the client's ammo
    SetEntProp(client, Prop_Send, "m_iAmmo", 0, _, s_AmmoTypeHE);
    SetEntProp(client, Prop_Send, "m_iAmmo", 0, _, s_AmmoTypeSmoke);
    SetEntProp(client, Prop_Send, "m_iAmmo", 0, _, s_AmmoTypeFlashbang);
    SetEntProp(client, Prop_Send, "m_iAmmo", 0, _, s_AmmoTypeMolotov);
    SetEntProp(client, Prop_Send, "m_iAmmo", 0, _, s_AmmoTypeIncendiary);
    SetEntProp(client, Prop_Send, "m_iAmmo", 0, _, s_AmmoTypeDecoy);
    SetEntProp(client, Prop_Send, "m_iAmmo", 0, _, s_AmmoTypeBreachCharge);
    SetEntProp(client, Prop_Send, "m_iAmmo", 0, _, s_AmmoTypeBumpMine);
    SetEntProp(client, Prop_Send, "m_iAmmo", 0, _, s_AmmoTypeTAG);
    SetEntProp(client, Prop_Send, "m_iAmmo", 0, _, s_AmmoTypeSnowball);
    SetEntProp(client, Prop_Send, "m_iAmmo", 0, _, s_AmmoTypeHealthshot);
}

/**
 * Get the global ammo-type values used to set the m_iAmmo property.
 */
static void GetAllAmmoTypes()
{
    s_AmmoTypeHE = GetAmmoType("weapon_hegrenade");
    s_AmmoTypeSmoke = GetAmmoType("weapon_smokegrenade");
    s_AmmoTypeFlashbang = GetAmmoType("weapon_flashbang");
    s_AmmoTypeMolotov = GetAmmoType("weapon_molotov");
    s_AmmoTypeIncendiary = GetAmmoType("weapon_incgrenade");
    s_AmmoTypeDecoy = GetAmmoType("weapon_decoy");

    s_AmmoTypeBreachCharge = GetAmmoType("weapon_breachcharge");
    s_AmmoTypeBumpMine = GetAmmoType("weapon_bumpmine");
    s_AmmoTypeTAG = GetAmmoType("weapon_tagrenade");

    s_AmmoTypeSnowball = GetAmmoType("weapon_snowball");
    s_AmmoTypeHealthshot = GetAmmoType("weapon_healthshot");

    s_AreAmmoTypesSet = true;
}

static int GetAmmoType(const char[] classname)
{
    int ent = CreateEntityByName(classname);
    DispatchSpawn(ent);
    int type = GetEntProp(ent, Prop_Send, "m_iPrimaryAmmoType");
    AcceptEntityInput(ent, "Kill");
    return type;
}

/**
 * Get all of the consumable-limit cvars
 */
static void GetAllLimitCvars()
{
    s_limitTotal = FindConVar("ammo_grenade_limit_total");
    s_limitDefault = FindConVar("ammo_grenade_limit_default");
    s_limitFlash = FindConVar("ammo_grenade_limit_flashbang");
    s_limitSnowball = FindConVar("ammo_grenade_limit_snowballs");
    s_limitHealthshot = FindConVar("ammo_item_limit_healthshot");
}

/**
 * Get total amount of all grenades that obey ammo_grenade_limit_total
 */
static int GetTotalGrenades(int client)
{
    // TODO: Optimize
    int total;
    total += GetAmmoCount(client, Item_HE);
    total += GetAmmoCount(client, Item_Smoke);
    total += GetAmmoCount(client, Item_Molotov);
    if (s_AmmoTypeMolotov != s_AmmoTypeIncendiary)
        total += GetAmmoCount(client, Item_Incendiary);
    total += GetAmmoCount(client, Item_Decoy);
    total += GetAmmoCount(client, Item_TAG);
    total += GetAmmoCount(client, Item_Flashbang);
    return total;
}

/**
 * Get amount of ammo a client has for a particular CSItemType
 *
 * This does not mean they actually have any usable items
 * because the ammo count is a player property not a weapon property.
 */
static int GetAmmoCount(int client, CSItemType item)
{
    if (item == Item_FireNade)
        item = GetFireNadeType(client);

    switch (item)
    {
        case Item_HE:           return GetEntProp(client, Prop_Send, "m_iAmmo", _, s_AmmoTypeHE);
        case Item_Smoke:        return GetEntProp(client, Prop_Send, "m_iAmmo", _, s_AmmoTypeSmoke);
        case Item_Flashbang:    return GetEntProp(client, Prop_Send, "m_iAmmo", _, s_AmmoTypeFlashbang);
        //case Item_FireNade:
        case Item_Molotov:      return GetEntProp(client, Prop_Send, "m_iAmmo", _, s_AmmoTypeMolotov);
        case Item_Incendiary:   return GetEntProp(client, Prop_Send, "m_iAmmo", _, s_AmmoTypeIncendiary);
        case Item_Decoy:        return GetEntProp(client, Prop_Send, "m_iAmmo", _, s_AmmoTypeDecoy);
        case Item_BreachCharge: return GetEntProp(client, Prop_Send, "m_iAmmo", _, s_AmmoTypeBreachCharge);
        case Item_BumpMine:     return GetEntProp(client, Prop_Send, "m_iAmmo", _, s_AmmoTypeBumpMine);
        case Item_TAG:          return GetEntProp(client, Prop_Send, "m_iAmmo", _, s_AmmoTypeTAG);
        case Item_Snowball:     return GetEntProp(client, Prop_Send, "m_iAmmo", _, s_AmmoTypeSnowball);
        case Item_Healthshot:   return GetEntProp(client, Prop_Send, "m_iAmmo", _, s_AmmoTypeHealthshot);
    }

    ThrowError("Unknown ConsumableItem value %i", item);
    return 0;
}

/**
 * Get either the Item_Molotov or Item_Incendiary depending on
 * client team.
 */
static CSItemType GetFireNadeType(int client)
{
    if (!IsClientInGame(client))
        return Item_Molotov;

    int team = GetClientTeam(client);

    if (team == CS_TEAM_CT)
        return Item_Incendiary;
    else if (team == CS_TEAM_T)
        return Item_Molotov;

    return Item_Molotov;
}

static bool IsConsumable(CSWeaponID id)
{
    for (int i = 0; i < sizeof(s_IsConsumableIDList); ++i)
    {
        if (s_IsConsumableIDList[i] == id)
            return true;
    }

    return false;
}

/**
 * Give a player an item (that has its ammo set via setting m_iClip1),
 * but temporarily delete the C4 if they have it.
 * This is a work-around for a specific quirk where you can't pick up
 * certain consumables if you have a C4, but you can the other way around.
 */
static void RemoveC4GiveItem(int client, CSWeaponID id, const char[] classname, int amount)
{
    if (id == CSWeapon_NONE)
        return;

    bool removed = RemoveC4(client);

    int weapon = GetPlayerWeapon(client, id);
    if (weapon == -1)
        weapon = GivePlayerItem(client, classname);

    if (weapon != -1)
        SetEntProp(weapon, Prop_Send, "m_iClip1", amount);

    if (removed)
    {
        int bomb = GivePlayerItem(client, "weapon_c4");
        if (bomb == -1)
            LogError("Failed to respawn bomb while attempting GivePlayerItem");
    }
}

static bool RemoveC4(int client)
{
    int weapon = GetPlayerWeapon(client, CSWeapon_C4);
    if (weapon != -1)
    {
        DeleteWeapon(client, weapon);
        return true;
    }

    return false;
}

static void DeleteWeapon(int client, int weapon)
{
    SDKHooks_DropWeapon(client, weapon);
    RemoveEntity(weapon);
}

static any _MIN(any a, any b)
{
    return a < b ? a : b;
}
