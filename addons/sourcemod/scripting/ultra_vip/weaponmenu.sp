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

/**
 * Types of weapon menus that can be displayed.
 */
enum WeaponMenuType
{
    Weapon_Invalid = -1,
    Weapon_Rifle = 0,
    Weapon_Pistol
}

/**
 * Structure for storing a menu item from the config file.
 */
enum struct WeaponMenuItem
{
    WeaponMenuType weaponType;
    int team;
    int price;
    char classname[MAX_WEAPON_CLASSNAME_SIZE];
}

/**
 * Classnames representing a player's weapon loadout
 * Only weapons with corresponding menus are supported.
 */
enum struct WeaponLoadout
{
    char primary[MAX_WEAPON_CLASSNAME_SIZE];
    char secondary[MAX_WEAPON_CLASSNAME_SIZE];

    bool IsSet()
    {
        return this.primary[0] || this.secondary[0];
    }

    bool IsAnyAllowedThisRound(Service svc)
    {
        if (svc == null)
            return false;
        if (svc.RifleWeaponsEnabled && CanGiveWeapon(svc, this.primary, svc.RifleWeaponsRound))
            return true;
        if (svc.PistolWeaponsEnabled && CanGiveWeapon(svc, this.secondary, svc.PistolWeaponsRound))
            return true;
        return false;
    }

    void Reset()
    {
        this.primary[0] = '\0';
        this.secondary[0] = '\0';
    }
}


/**
 * Size of cookie string storing previous weapons
 * e.g. "weapon_primary;weapon_secondary"
 */
#define LOADOUT_COOKIE_SIZE (sizeof(WeaponLoadout::primary) + sizeof(WeaponLoadout::secondary) + 1)

/**
 * Size of string output by EncodeMenuInfo(). Fits:
 * - Weapon type (zero-padded hex int)
 * - Team (zero-padded hex int)
 * - Price (zero-padded hex int)
 * - Classname (string + null)
 */
#define ENCODED_WEAPONITEM_MINSIZE (8 * 3) // Size with empty classname
#define ENCODED_WEAPONITEM_SIZE (ENCODED_WEAPONITEM_MINSIZE + sizeof(WeaponMenuItem::classname))

static Menu s_WeaponMenu;
static Service s_WeaponListService[MAXPLAYERS + 1];
static WeaponLoadout s_PreviousWeapon[MAXPLAYERS + 1];
static WeaponLoadout s_NewLoadoutBuffer[MAXPLAYERS + 1];

static WeaponMenuType s_SelectionList[MAXPLAYERS + 1] = { Weapon_Invalid, ... };


//--------------------------------------------------------------
// Load a client's previous weapons from the cookie.
//--------------------------------------------------------------
void WeaponMenu_GetPreviousWeapons(int client)
{
    char value[LOADOUT_COOKIE_SIZE];
    g_Cookie_PrevWeapons.Get(client, value, sizeof(value));

    if (!value[0])
    {
        WeaponMenu_ResetPreviousWeapons(client);
        return;
    }

    int index = SplitString(value, ";", s_PreviousWeapon[client].primary, sizeof(WeaponLoadout::primary));
    strcopy(s_PreviousWeapon[client].secondary, sizeof(WeaponLoadout::secondary), value[index]);
}

//--------------------------------------------------------------
// Save a client's previous weapons to the cookie.
//--------------------------------------------------------------
void WeaponMenu_SavePreviousWeapons(int client)
{
    char value[LOADOUT_COOKIE_SIZE];
    FormatEx(value, sizeof(value), "%s;%s", s_PreviousWeapon[client].primary, s_PreviousWeapon[client].secondary);
    g_Cookie_PrevWeapons.Set(client, value);
}

//--------------------------------------------------------------
// Reset the previous weapon cache for a client.
// Does not affect the value stored in the cookie.
//--------------------------------------------------------------
void WeaponMenu_ResetPreviousWeapons(int client)
{
    s_PreviousWeapon[client].Reset();
}


//--------------------------------------------------------------
// Main weapon menu
//--------------------------------------------------------------
void WeaponMenu_Display(int client, Service weaponListService)
{
    if (!CanDisplayWeaponMenu(client, weaponListService))
        return;

    if (s_WeaponMenu == null)
    {
        s_WeaponMenu = new Menu(WeaponMenu_MainHandler, MENU_ACTIONS_ALL);

        s_WeaponMenu.Pagination = false;
        s_WeaponMenu.ExitButton = true;

        s_WeaponMenu.AddItem("NEW", "Weapon Menu New"); // Translation phrase
        s_WeaponMenu.AddItem("PREVIOUS", "");
    }

    s_WeaponListService[client] = weaponListService;

    s_WeaponMenu.Display(client, MENU_TIME_FOREVER);
}

static bool CanSelectNewWeapons(Service svc)
{
    if (svc == null)
        return false;

    if (svc.RifleWeaponsEnabled && IsRoundAllowed(svc.RifleWeaponsRound))
        return true;
    if (svc.PistolWeaponsEnabled && IsRoundAllowed(svc.PistolWeaponsRound))
        return true;
    return false;
}

static bool CanDisplayWeaponMenu(int client, Service svc)
{
    if (svc == null)
        return false;
    if (IsWarmup())
        return false;
    if (!IsOnPlayingTeam(client) || !IsPlayerAlive(client))
        return false;

    return CanSelectNewWeapons(svc) || s_PreviousWeapon[client].IsAnyAllowedThisRound(svc);
}

public int WeaponMenu_MainHandler(Menu menu, MenuAction action, int param1, int param2)
{
    switch(action)
    {
        case MenuAction_End:
        {
            return 0;
        }

        case MenuAction_Display:
        {
            char buffer[255];

            char serviceName[MAX_SERVICE_NAME_SIZE];
            Service svc = GetClientService(param1);
            if (svc != null)
                svc.GetName(serviceName, sizeof(serviceName));

            FormatEx(buffer, sizeof(buffer), "%T", "Weapon Menu Title", param1, serviceName, "\n");

            Panel panel = view_as<Panel>(param2);
            panel.SetTitle(buffer);
        }

        case MenuAction_DrawItem:
        {
            char info[16];
            menu.GetItem(param2, info, sizeof(info));

            if (StrEqual(info, "NEW") && !CanSelectNewWeapons(s_WeaponListService[param1]))
                return ITEMDRAW_DISABLED;
            else if (StrEqual(info, "PREVIOUS"))
            {
                if (!s_PreviousWeapon[param1].IsAnyAllowedThisRound(s_WeaponListService[param1]))
                    return ITEMDRAW_DISABLED;
            }

            return ITEMDRAW_DEFAULT;
        }

        case MenuAction_DisplayItem:
        {
            char info[16];
            char display[64];
            menu.GetItem(param2, info, sizeof(info), _, display, sizeof(display));

            if (StrEqual(info, "PREVIOUS"))
                MakePreviousWeaponText(param1, s_WeaponListService[param1], display, sizeof(display));
            else
                Format(display, sizeof(display), "%T", display, param1);

            return RedrawMenuItem(display);
        }

        case MenuAction_Select:
        {
            char info[16];
            menu.GetItem(param2, info, sizeof(info));

            // Prevent exploit where you can leave the menu open and then use it in spec
            if (!IsOnPlayingTeam(param1) || !IsPlayerAlive(param1))
                return 0;

            if (StrEqual(info, "NEW"))
            {
                s_NewLoadoutBuffer[param1].Reset();

                if (GoToNextSelectionList(param1, s_WeaponListService[param1]))
                    DisplayWeaponList(param1);
            }
            else if (StrEqual(info, "PREVIOUS"))
            {
                if (!s_PreviousWeapon[param1].IsSet())
                    return 0;

                GiveLoadoutIfAllowed(param1, s_PreviousWeapon[param1], s_WeaponListService[param1]);
            }
        }
    }

    return 0;
}


//--------------------------------------------------------------
// Weapon selection list (the list of individual weapons shown
// after you select "NEW" on the main weapon menu)
//--------------------------------------------------------------
static void DisplayWeaponList(int client)
{
    Menu listMenu = s_WeaponListService[client].WeaponMenu;
    if (listMenu != null)
        listMenu.Display(client, MENU_TIME_FOREVER);
}

void WeaponMenu_BuildSelectionsFromConfig(KeyValues kv, const char[] serviceName, Menu &outputMenu, ArrayList &outputWeapons)
{
    ArrayList weapons = new ArrayList(ByteCountToCells(MAX_WEAPON_CLASSNAME_SIZE));

    Menu menu = new Menu(WeaponMenu_SelectionHandler, MENU_ACTIONS_ALL);
    menu.Pagination = true;

    // Cannot go back because weapons are given on each selection,
    // not after all selections are made.
    menu.ExitBackButton = false;

    char encodedInfo[ENCODED_WEAPONITEM_SIZE];
    char weaponName[32];
    WeaponMenuItem item;

    char sections[][] =
    {
        "Rifles",
        "Pistols"
    };
    char sectionStateKeys[][] =
    {
        "rifles_menu_enabled",
        "pistols_menu_enabled"
    };
    WeaponMenuType sectionTypes[] =
    {
        Weapon_Rifle,
        Weapon_Pistol
    };

    for (int i = 0; i < sizeof(sections); ++i)
    {
        if (!kv.JumpToKey(sections[i]))
        {
            LogError("Service \"%s\" is missing weapon menu section \"%s\".", serviceName, sections[i]);
            delete menu;
            delete weapons;
            return;
        }

        // If section is disabled, skip it
        // NOTE:
        // Because it is skipped, Service::IsWeaponAllowed will fail for those weapons.
        // You could argue that means you therefore dont need to check Service::RifleWeaponsEnabled
        // if you also check IsWeaponAllowed/CanGiveWeapon but because IsWeaponAllowed is planned
        // to be changed I wont make that assumption (at the cost of performance).
        if (!kv.GetNum(sectionStateKeys[i], 0))
        {
            kv.GoBack(); // To Advanced Weapons Menu
            continue;
        }

        if (!kv.GotoFirstSubKey())
        {
            LogError("Service \"%s\" has no weapons for an enabled weapon menu section \"%s\".", serviceName, sections[i]);
            delete menu;
            delete weapons;
            return;
        }

        do
        {
            kv.GetSectionName(weaponName, sizeof(weaponName));

            GetWeaponMenuItem(kv, item);
            item.weaponType = sectionTypes[i];

            EncodeMenuInfo(item, encodedInfo, sizeof(encodedInfo));

            menu.AddItem(encodedInfo, weaponName);

            weapons.PushString(item.classname);

        } while (kv.GotoNextKey());

        kv.GoBack(); // To weapon type section ("Rifles")
        kv.GoBack(); // To Advanced Weapons Menu
    }

    outputMenu = menu;
    outputWeapons = weapons;

    return;
}

static void GetWeaponMenuItem(KeyValues kv, WeaponMenuItem outputItem)
{
    char buffer[MAX_WEAPON_CLASSNAME_SIZE];

    kv.GetString("team", buffer, sizeof(buffer));
    outputItem.team = GetCSTeamFromString(buffer);

    kv.GetString("weapon_entity", outputItem.classname, sizeof(WeaponMenuItem::classname));
    outputItem.price = kv.GetNum("price");
}

public int WeaponMenu_SelectionHandler(Menu menu, MenuAction action, int param1, int param2)
{
    switch(action)
    {
        case MenuAction_End:
        {
            return 0;
        }

        case MenuAction_Cancel:
        {
            if (param2 == MenuCancel_ExitBack)
            {
                // TODO: Technically this is broken because we dont refund
                // the selected weapons, but going back is disabled.
                s_SelectionList[param1] = Weapon_Invalid;
                WeaponMenu_Display(param1, s_WeaponListService[param1]);
            }
        }

        case MenuAction_Display:
        {
            char buffer[255];

            if(s_SelectionList[param1] == Weapon_Rifle)
                FormatEx(buffer, sizeof(buffer), "%T", "Rifle Menu Title", param1);
            else
                FormatEx(buffer, sizeof(buffer), "%T", "Pistol Menu Title", param1);

            Panel panel = view_as<Panel>(param2);
            panel.SetTitle(buffer);
        }

        case MenuAction_DrawItem:
        {
            char info[ENCODED_WEAPONITEM_SIZE];
            menu.GetItem(param2, info, sizeof(info));

            WeaponMenuItem item;
            if (!DecodeMenuInfo(info, item))
                SetFailState("Decoding weapon menu item failed");

            if (item.weaponType != s_SelectionList[param1])
                return ITEMDRAW_IGNORE;

            if (!CanPurchaseWeapon(param1, item))
                return ITEMDRAW_IGNORE;

            if (!CanAffordWeapon(param1, item))
                return ITEMDRAW_DISABLED;

            return ITEMDRAW_DEFAULT;
        }

        case MenuAction_DisplayItem:
        {
            char info[ENCODED_WEAPONITEM_SIZE];
            char display[64];

            menu.GetItem(param2, info, sizeof(info), _, display, sizeof(display));

            WeaponMenuItem item;
            if(!DecodeMenuInfo(info, item))
                SetFailState("Decoding weapon menu item failed");

            if(item.price > 0)
            {
                Format(display, sizeof(display), "%T", "Weapon Item Price", param1, display, item.price);
                return RedrawMenuItem(display);
            }

            return 0;
        }

        case MenuAction_Select:
        {
            char info[ENCODED_WEAPONITEM_SIZE];
            menu.GetItem(param2, info, sizeof(info));

            WeaponMenuItem item;
            if(!DecodeMenuInfo(info, item))
                SetFailState("Decoding weapon menu item failed");

            if(CanPurchaseWeapon(param1, item))
            {
                int slot = -1;

                if (s_SelectionList[param1] == Weapon_Rifle)
                    slot = CS_SLOT_PRIMARY;
                else if (s_SelectionList[param1] == Weapon_Pistol)
                    slot = CS_SLOT_SECONDARY;

                if (slot != -1)
                    PurchaseWeapon(param1, item, slot);

                AddToNewLoadoutBuffer(param1, s_SelectionList[param1], item.classname);

                if (GoToNextSelectionList(param1, s_WeaponListService[param1]))
                    DisplayWeaponList(param1);
                else
                {
                    UpdatePreviousWeapons(param1);
                    WeaponMenu_SavePreviousWeapons(param1);
                }
            }
            else
                LogError("Selected weapon {%s} when CanPurchaseWeapon is false", item.classname);
        }
    }

    return 0;
}


//--------------------------------------------------------------
// Cycle through the different menus that can display.
// Used to filter out weapons to display the 'next' menu when
// redisplaying the selection list.
//--------------------------------------------------------------
#if defined COMPILER_IS_SM1_11
static_assert(Weapon_Invalid < Weapon_Rifle);
static_assert(Weapon_Rifle < Weapon_Pistol);
#endif
static bool GoToNextSelectionList(int client, Service svc)
{
    // Go to the next selection list that is allowed, checking in the order
    // we want each list/menu to appear in the cycle (assuming each is allowed)

    if (s_SelectionList[client] < Weapon_Rifle && svc.RifleWeaponsEnabled && IsRoundAllowed(svc.RifleWeaponsRound))
    {
        s_SelectionList[client] = Weapon_Rifle;
        return true;
    }

    if (s_SelectionList[client] < Weapon_Pistol && svc.PistolWeaponsEnabled && IsRoundAllowed(svc.PistolWeaponsRound))
    {
        s_SelectionList[client] = Weapon_Pistol;
        return true;
    }

    s_SelectionList[client] = Weapon_Invalid;
    return false;
}

//--------------------------------------------------------------
// Make the "Get Previous Weapons" ("PREVIOUS") menu item text.
//--------------------------------------------------------------
void MakePreviousWeaponText(int client, Service svc, char[] output, int size)
{
    if (!s_PreviousWeapon[client].IsSet())
        FormatEx(output, size, "%T", "Weapon Menu Previous", client, "");

    char weapons[64];
    bool isFirst = true;

    if (svc.RifleWeaponsEnabled && CanGiveWeapon(svc, s_PreviousWeapon[client].primary, svc.RifleWeaponsRound))
    {
        isFirst = false;

        if (TranslationPhraseExists(s_PreviousWeapon[client].primary))
            FormatEx(weapons, sizeof(weapons), " (%T", s_PreviousWeapon[client].primary, client);
        else
            weapons = s_PreviousWeapon[client].primary; // Use classname if we can't translate
    }

    if (svc.PistolWeaponsEnabled && CanGiveWeapon(svc, s_PreviousWeapon[client].secondary, svc.PistolWeaponsRound))
    {
        if (TranslationPhraseExists(s_PreviousWeapon[client].secondary))
        {
            Format(weapons, sizeof(weapons), "%s%s%T",
                weapons,
                (isFirst) ? " (" : ", ",
                s_PreviousWeapon[client].secondary,
                client);
        }
        else
        {
            Format(weapons, sizeof(weapons), "%s%s%s",
                weapons,
                (isFirst) ? " (" : ", ",
                s_PreviousWeapon[client].secondary);
        }
    }

    // If at least 1 name is in weapons, add the finishing ).
    // It must be done this way because either menu can be disabled independently,
    // so only-rifle-menu needs to work.
    FormatEx(output, size, "%T%s", "Weapon Menu Previous", client, weapons, (weapons[0]) ? ")" : "");
}

//--------------------------------------------------------------
// Add a weapon classname to the temporary buffer used to update
// previous weapons once the selection list menu is fully done.
//--------------------------------------------------------------
static void AddToNewLoadoutBuffer(int client, WeaponMenuType type, const char classname[MAX_WEAPON_CLASSNAME_SIZE])
{
    if (type == Weapon_Rifle)
        s_NewLoadoutBuffer[client].primary = classname;
    else if (type == Weapon_Pistol)
        s_NewLoadoutBuffer[client].secondary = classname;
}

//--------------------------------------------------------------
// Update a client's previous weapons using the temporary
// selection list menu buffer.
//--------------------------------------------------------------
static void UpdatePreviousWeapons(int client)
{
    s_PreviousWeapon[client] = s_NewLoadoutBuffer[client];
}


//--------------------------------------------------------------
// Can a client afford an item on the menu.
//--------------------------------------------------------------
static bool CanAffordWeapon(int client, WeaponMenuItem item)
{
    return GetClientMoney(client) > item.price;
}

//--------------------------------------------------------------
// Add a weapon classname to the temporary buffer used
// to update previous weapons.
//--------------------------------------------------------------
static bool CanPurchaseWeapon(int client, WeaponMenuItem item)
{
    if (!IsClientInGame(client) || !IsPlayerAlive(client))
        return false;

    Service svc = s_WeaponListService[client];
    if (!svc.IsWeaponAllowed(item.classname))
        return false;

    int team = GetClientTeam(client);
    if (item.team != 0 && ((team != CS_TEAM_CT && team != CS_TEAM_T) || team != item.team))
        return false;

    return true;
}

//--------------------------------------------------------------
// Give a player weapons, checking if each type is allowed
// on this current round.
//--------------------------------------------------------------
static void GiveLoadoutIfAllowed(int client, WeaponLoadout weapons, Service svc)
{
    if (svc.RifleWeaponsEnabled && CanGiveWeapon(svc, weapons.primary, svc.RifleWeaponsRound))
        GivePlayerWeapon(client, weapons.primary, CS_SLOT_PRIMARY);

    if (svc.PistolWeaponsEnabled && CanGiveWeapon(svc, weapons.secondary, svc.PistolWeaponsRound))
        GivePlayerWeapon(client, weapons.secondary, CS_SLOT_SECONDARY);
}

static bool CanGiveWeapon(Service svc, const char[] classname, int round)
{
    return classname[0] && svc.IsWeaponAllowed(classname) && IsRoundAllowed(round);
}

//--------------------------------------------------------------
// Encode a WeaponMenuItem into a string.
// Used for passing WeaponMenuItems to the menu handler.
//--------------------------------------------------------------
static void EncodeMenuInfo(const WeaponMenuItem item, char[] output, int size)
{
    FormatEx(output, size, "%08X%08X%08X%s",
        item.weaponType,
        item.team,
        item.price,
        item.classname);
}

//--------------------------------------------------------------
// Decode a WeaponMenuItem from a string (encoded with EncodeMenuInfo)
//--------------------------------------------------------------
static bool DecodeMenuInfo(const char[] info, WeaponMenuItem outputItem)
{
    int len = strlen(info);
    if (len < ENCODED_WEAPONITEM_MINSIZE)
        return false; // Invalid size, cannot decode

    outputItem.weaponType = view_as<WeaponMenuType>(NStringToInt(info, 8, 16));
    outputItem.team = NStringToInt(info[8], 8, 16);
    outputItem.price = NStringToInt(info[16], 8, 16);
    strcopy(outputItem.classname, sizeof(WeaponMenuItem::classname), info[24]);

    return true;
}

// i really fucking hate this file
