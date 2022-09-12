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

enum WeaponType
{
    Weapon_Rifle = 0,
    Weapon_Pistol
}

enum struct WeaponMenuItem
{
    WeaponType weaponType;
    int team;
    int price;
    char classname[MAX_WEAPON_CLASSNAME_SIZE];
}

enum struct WeaponLoadout
{
    char primary[MAX_WEAPON_CLASSNAME_SIZE]; 
    char secondary[MAX_WEAPON_CLASSNAME_SIZE];

    bool IsSet()
    {
        return this.primary[0] || this.secondary[0];
    }

    void Reset()
    {
        this.primary[0] = '\0';
        this.secondary[0] = '\0';
    }
}

static void GiveLoadoutIfAllowed(int client, WeaponLoadout weapons, Service svc)
{
    if (svc.IsWeaponAllowed(s_PreviousWeapon[client].primary))
        GivePlayerItem(client, s_PreviousWeapon[client].primary);

    if (svc.IsWeaponAllowed(s_PreviousWeapon[client].secondary))
        GivePlayerItem(client, s_PreviousWeapon[client].secondary);
}


// Size of string output by EncodeMenuItem(). Fits:
// - Weapon type (zero-padded hex)
// - Team (zero-padded hex)
// - Price (zero-padded hex)
// - Classname (string)
#define ENCODED_WEAPONITEM_MINSIZE (8 * 3) // Size with empty classname
#define ENCODED_WEAPONITEM_SIZE (ENCODED_WEAPONITEM_MINSIZE + sizeof(WeaponMenuItem::classname))

static Menu s_WeaponMenu;
static Service s_WeaponListService[MAXPLAYERS + 1];
static WeaponLoadout s_PreviousWeapon[MAXPLAYERS + 1];

static WeaponType s_SelectionList[MAXPLAYERS + 1] = { Weapon_Rifle, ... };

void SetPreviousWeapons(int client, WeaponLoadout loadout)
{
    s_PreviousWeapon[client] = loadout;
}

void ResetPreviousWeapons(int client)
{
    s_PreviousWeapon[client].Reset();
}

void DisplayWeaponMenu(int client, Service weaponListService)
{
    if (s_WeaponMenu == null)
    {
        s_WeaponMenu = new Menu(WeaponMenu_Handler, MENU_ACTIONS_ALL);

        menu.Pagination = false;
        menu.ExitButton = true;

        menu.AddItem("NEW", "Weapon Menu New"); // Translation phrase
        menu.AddItem("PREVIOUS", "Weapon Menu Previous");
    }

    s_WeaponListService[client] = weaponListService;

    s_WeaponMenu.Display(client, MENU_TIME_FOREVER);
}

public int WeaponMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
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

            FormatEx(buffer, sizeof(buffer), "%T", "Weapon Menu Title", param1); 

            Panel panel = view_as<Panel>(param2);
            panel.SetTitle(buffer);
        }

        case MenuAction_DrawItem:
        {
            char info[16];
            menu.GetItem(param2, info, sizeof(info));

            if (StrEqual(info, "PREVIOUS") && !s_PreviousWeapon[param1].IsSet())
                return ITEMDRAW_DISABLED;

            return ITEMDRAW_DEFAULT;
        }

        case MenuAction_DisplayItem:
        {
            char info[16];
            char display[64];
            menu.GetItem(param2, info, sizeof(info), _, display, sizeof(display));

            Format(display, sizeof(display), "%T", display, param1);

            return RedrawMenuItem(display);
        }

        case MenuAction_Select:
        {
            char info[16];
            menu.GetItem(param2, info, sizeof(info));

            if (StrEqual(info, "NEW"))
            {
                if (!IsServiceHandleValid(s_WeaponListService[param1]))
                    return 0;

                Menu listMenu = s_WeaponListService[param1].WeaponMenu;
                if (listMenu != null)
                    listMenu.Display(param1, MENU_TIME_FOREVER);
            }
            else if (StrEqual(info, "PREVIOUS"))
            {
                if(!s_PreviousWeapon[param1].IsSet())
                    return 0;

                Service svc = GetClientService(param1);
                if(svc == null)
                    return 0;

                GiveLoadoutIfAllowed(param1, s_PreviousWeapon[param1], svc);      
            }
        }
    }

    return 0;
}

void WeaponMenu_BuildSelectionsFromConfig(KeyValues kv, const char[] serviceName, Menu &outputMenu, ArrayList &outputWeapons)
{
    ArrayList weapons = new ArrayList(ByteCountToCells(MAX_WEAPON_CLASSNAME_SIZE));

    Menu menu = new Menu(WeaponSelection_Handler, MENU_ACTIONS_ALL);

    menu.Pagination = true;
    menu.ExitBackButton = true;

    char encodedInfo[ENCODED_WEAPONITEM_SIZE];
    char weaponName[32];
    WeaponMenuItem item;

    char sections[][] =
    { 
        "Rifles",
        "Pistols"
    };
    char sectionStateKeys =
    {
        "rifles_menu_enabled",
        "pistols_menu_enabled"
    };
    WeaponType sectionTypes[] =
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

    kv.GoBack(); // To Service

    outputMenu = menu;
    outputWeapons = weapons;

    return;
}

void GetWeaponMenuItem(KeyValues kv, WeaponMenuItem outputItem)
{
    char buffer[MAX_WEAPON_CLASSNAME_SIZE];

    kv.GetString("team", buffer, sizeof(buffer));
    outputItem.team = GetCSTeamFromString(buffer);

    kv.GetString("weapon_entity", outputItem.classname, sizeof(WeaponMenuItem::classname));
    outputItem.price = kv.GetNum("price");
}

public int WeaponSelection_Handler(Menu menu, MenuAction action, int param1, int param2)
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
                DisplayWeaponMenu(param1, s_WeaponListService[param1]);
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
            if(!DecodeMenuInfo(info, item))
                SetFailState("Decoding weapon menu item failed");

            if(item.weaponType != s_SelectionList[param1])
                return ITEMDRAW_IGNORE;

            return ITEMDRAW_DEFAULT;    
        }

        case MenuAction_DisplayItem:
        {
            #error add price
        }

        case MenuAction_Select:
        {
            #error needs to be done
        }
    }

    return 0;
}


static void EncodeMenuInfo(const WeaponMenuItem item, char[] output, int size)
{
    int len = strlen(item.classname);

    FormatEx(output, size, "%08X%08X%08X%s",
        item.weaponType,
        item.team,
        item.price,
        classname);
}

static bool DecodeMenuInfo(const char[] info, WeaponMenuItem outputItem)
{
    int len = strlen(info);
    if (len < ENCODED_WEAPONITEM_MINSIZE)
        return false; // Invalid size, cannot decode

    outputItem.weaponType = view_as<WeaponType>(NStringToInt(info, 8, 16));
    outputItem.team = NStringToInt(info[8], 8, 16);
    outputItem.price = NStringToInt(info[16], 8, 16);
    strcopy(outputItem.className, sizeof(WeaponMenuItem::classname), info[24]);

    return true;
}


#error have i forgotten to delete any handles somewhere. maybe.

#error README
/*
    - The "round" variables will be stored per weapon
    - The build function will get them itself for each weapon type,
       otherwise we'd have to pass them in as a hardcoded array.
    - Later, if we want to add in a "per-weapon round" we can easily
      add it as an override to the "x_menu_round" variable.
*/