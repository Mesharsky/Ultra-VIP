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
 * Add a Service property to the service details menu.
 *
 * %1 = Translation phrase (must take 1 formatting arg)
 * %2 = Formatting arg for phrase
 */
#define ADDSVCDETAIL(%1,%2)                                     \
    FormatEx(display, sizeof(display), "%T", %1, client, %2);   \
    menu.AddItem("", display);

static Service g_SelectedService[MAXPLAYERS +1];

void ShowVipSettings(int client)
{
    Menu menu = new Menu(MenuHandler_Settings, MENU_ACTIONS_ALL);
    menu.Pagination = true;

    Service svc = GetClientService(client);
    
    if (svc == null)
        CPrintToChat(client, "%s %t", g_ChatTag, "You Have No Service");

    char display[MAX_SERVICE_NAME_SIZE];
    svc.GetName(display, sizeof(display));

    menu.AddItem("vip-disable-bonuses", display);
    menu.AddItem("vip-enable-bonuses", display);

    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Settings(Menu menu, MenuAction action, int param1, int param2)
{
    switch(action)
    {
        case MenuAction_End:
        {
            delete menu;
        }
        case MenuAction_Display:
        {
            char title[255];
            FormatEx(title, sizeof(title), "%T", "Vip Settings Select", param1);
            Panel panel = view_as<Panel>(param2);
            panel.SetTitle(title);
        }
        case MenuAction_DisplayItem:
        {
            char info[16];
            menu.GetItem(param2, info, sizeof(info));
        }
        case MenuAction_Select:
        {
            char info[16];
            char display[32];
            menu.GetItem(param2, info, sizeof(info), _, display, sizeof(display));

            Service svc = view_as<Service>(StringToInt(info));

            ServiceBonusesList(param1, svc, display);
        }
    }

    return 0;
}

void ShowServiceBonuses(int client)
{
    Menu menu = new Menu(MenuHandler_Bonuses, MENU_ACTIONS_ALL);
    menu.Pagination = true;

    Service svc;

    int len = g_Services.Length;
    char display[MAX_SERVICE_NAME_SIZE];
    char itemID[16];

    for (int i = 0; i < len; ++i)
    {
        svc = g_Services.Get(i);
        svc.GetName(display, sizeof(display));

        IntToString(i, itemID, sizeof(itemID));
        FormatEx(itemID, sizeof(itemID), "%i", svc);

        menu.AddItem(itemID, display);
    }
    if (len == 0)
        menu.AddItem("noservices", "No services loaded");

    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Bonuses(Menu menu, MenuAction action, int param1, int param2)
{
    switch(action)
    {
        case MenuAction_End:
        {
            delete menu;
        }
        case MenuAction_Display:
        {
            char title[255];
            FormatEx(title, sizeof(title), "%T", "Service Category List Bonuses", param1);
            Panel panel = view_as<Panel>(param2);
            panel.SetTitle(title);
        }
        case MenuAction_DrawItem:
        {
            char info[16];
            menu.GetItem(param2, info, sizeof(info));

            if (StrEqual(info, "noservices"))
                return ITEMDRAW_DISABLED;

            return ITEMDRAW_DEFAULT;
        }
        case MenuAction_Select:
        {
            char info[16];
            char display[32];
            menu.GetItem(param2, info, sizeof(info), _, display, sizeof(display));

            Service svc = view_as<Service>(StringToInt(info));

            ServiceBonusesList(param1, svc, display);
        }
    }

    return 0;
}

void ServiceBonusesList(int client, Service svc, char[] serviceName)
{
    Menu menu = new Menu(Menu_HandlerBonusesList, MENU_ACTIONS_ALL);

    menu.Pagination = true;
    menu.ExitBackButton = true;

    char title[255];
    FormatEx(title, sizeof(title), "%T", "Service Bonuses List", client, serviceName, "\n");
    menu.SetTitle(title);

    g_SelectedService[client] = svc;

    char display[64];
    if (svc.BonusPlayerHealth != 100)
    {
        ADDSVCDETAIL("Menu player_hp", svc.BonusPlayerHealth)
    }
    if (svc.BonusArmorEnabled)
    {
        ADDSVCDETAIL("Menu player_vest", svc.BonusArmor)
    }
    if (svc.BonusHelmetEnabled)
    {
        FormatEx(display, sizeof(display), "%T", "Menu player_helmet", client);
        menu.AddItem("", display);
    }
    if (svc.BonusDefuserEnabled)
    {
        FormatEx(display, sizeof(display), "%T", "Menu player_defuser", client);
        menu.AddItem("", display);
    }
    if (svc.RifleWeaponsEnabled)
    {
        ADDSVCDETAIL("Menu rifles_menu_enabled", svc.RifleWeaponsRound)
    }
    if (svc.PistolWeaponsEnabled)
    {
        ADDSVCDETAIL("Menu pistols_menu_enabled", svc.PistolWeaponsRound)
    }
    if (svc.BonusHEGrenades > 0)
    {
        FormatEx(display, sizeof(display), "%T", "Menu he_amount", client, svc.BonusHEGrenades);
        menu.AddItem("", display);
    }
    if (svc.BonusFlashGrenades > 0)
    {
        FormatEx(display, sizeof(display), "%T", "Menu flash_amount", client, svc.BonusFlashGrenades);
        menu.AddItem("", display);
    }
    if (svc.BonusSmokeGrenades > 0)
    {
        FormatEx(display, sizeof(display), "%T", "Menu smoke_amount", client, svc.BonusSmokeGrenades);
        menu.AddItem("", display);
    }
    if (svc.BonusDecoyGrenades > 0)
    {
        FormatEx(display, sizeof(display), "%T", "Menu decoy_amount", client, svc.BonusDecoyGrenades);
        menu.AddItem("", display);
    }
    if (svc.BonusMolotovGrenades > 0)
    {
        FormatEx(display, sizeof(display), "%T", "Menu molotov_amount", client, svc.BonusMolotovGrenades);
        menu.AddItem("", display);
    }
    if (svc.BonusHealthshotGrenades > 0)
    {
        FormatEx(display, sizeof(display), "%T", "Menu healthshot_amount", client, svc.BonusHealthshotGrenades);
        menu.AddItem("", display);
    }
    if (svc.BonusTacticalGrenades > 0)
    {
        FormatEx(display, sizeof(display), "%T", "Menu tag_amount", client, svc.BonusTacticalGrenades);
        menu.AddItem("", display);
    }
    if (svc.BonusSnowballGrenades > 0)
    {
        FormatEx(display, sizeof(display), "%T", "Menu snowball_amount", client, svc.BonusSnowballGrenades);
        menu.AddItem("", display);
    }
    if (svc.BonusBreachchargeGrenades > 0)
    {
        FormatEx(display, sizeof(display), "%T", "Menu breachcharge_amount", client, svc.BonusBreachchargeGrenades);
        menu.AddItem("", display);
    }
    if (svc.BonusBumpmineGrenades > 0)
    {
        FormatEx(display, sizeof(display), "%T", "Menu bumpmine_amount", client, svc.BonusBumpmineGrenades);
        menu.AddItem("", display);
    }
    if (svc.BonusExtraJumps > 0)
    {
        ADDSVCDETAIL("Menu player_extra_jumps", svc.BonusExtraJumps)
    }
    if (svc.ChatWelcomeMessage)
    {
        FormatEx(display, sizeof(display), "%T", "Menu chat_join_msg_enable", client);
        menu.AddItem("", display);
    }
    if (svc.ChatLeaveMessage)
    {
        FormatEx(display, sizeof(display), "%T", "Menu chat_leave_msg_enable", client);
        menu.AddItem("", display);
    }
    if (svc.HudWelcomeMessage)
    {
        FormatEx(display, sizeof(display), "%T", "Menu hud_join_msg_enable", client);
        menu.AddItem("", display);
    }
    if (svc.HudLeaveMessage)
    {
        FormatEx(display, sizeof(display), "%T", "Menu hud_leave_msg_enable", client);
        menu.AddItem("", display);
    }
    if (svc.BonusPlayerShield)
    {
        FormatEx(display, sizeof(display), "%T", "Menu player_shield", client);
        menu.AddItem("", display);
    }
    if (!FloatEqual(svc.BonusPlayerGravity, 1.0))
    {
        ADDSVCDETAIL("Menu player_gravity", svc.BonusPlayerGravity)
    }
    if (!FloatEqual(svc.BonusPlayerSpeed, 1.0))
    {
        ADDSVCDETAIL("Menu player_speed", svc.BonusPlayerSpeed)
    }
    if (svc.BonusPlayerVisibility < 255)
    {
        int percent = RoundToCeil((float(svc.BonusPlayerVisibility) / 255.0) * 100.0);

        ADDSVCDETAIL("Menu player_visibility", percent)
    }
    if (svc.BonusPlayerRespawnPercent > 0)
    {
        ADDSVCDETAIL("Menu player_respawn_percent", svc.BonusPlayerRespawnPercent)
    }
    if (svc.BonusPlayerFallDamagePercent != 100)
    {
        ADDSVCDETAIL("Menu player_fall_damage_percent", svc.BonusPlayerFallDamagePercent)
    }
    if (svc.BonusPlayerAttackDamage != 100)
    {
        ADDSVCDETAIL("Menu player_attack_damage", svc.BonusPlayerAttackDamage)
    }
    if (svc.BonusPlayerDamageResist > 0)
    {
        ADDSVCDETAIL("Menu player_damage_resist", svc.BonusPlayerDamageResist)
    }
    if (svc.BonusUnlimitedAmmo)
    {
        FormatEx(display, sizeof(display), "%T", "Menu player_unlimited_ammo", client);
        menu.AddItem("", display);
    }
    if (svc.BonusKillHP > 0)
    {
        ADDSVCDETAIL("Menu kill_hp_bonus", svc.BonusKillHP)
    }
    if (svc.BonusAssistHP > 0)
    {
        ADDSVCDETAIL("Menu assist_hp_bonus", svc.BonusAssistHP)
    }
    if (svc.BonusHeadshotHP > 0)
    {
        ADDSVCDETAIL("Menu headshot_hp_bonus", svc.BonusHeadshotHP)
    }
    if (svc.BonusKnifeHP > 0)
    {
        ADDSVCDETAIL("Menu knife_hp_bonus", svc.BonusKnifeHP)
    }
    if (svc.BonusZeusHP > 0)
    {
        ADDSVCDETAIL("Menu zeus_hp_bonus", svc.BonusZeusHP)
    }
    if (svc.BonusGrenadeHP > 0)
    {
        ADDSVCDETAIL("Menu grenade_hp_bonus", svc.BonusGrenadeHP)
    }
    if (svc.BonusNoscopeHP > 0)
    {
        ADDSVCDETAIL("Menu noscope_hp_bonus", svc.BonusNoscopeHP)
    }
    if (svc.BonusSpawnMoney > 0)
    {
        ADDSVCDETAIL("Menu spawn_bonus", svc.BonusSpawnMoney)
    }
    if (svc.BonusKillMoney > 0)
    {
        ADDSVCDETAIL("Menu kill_bonus", svc.BonusKillMoney)
    }
    if (svc.BonusAssistMoney > 0)
    {
        ADDSVCDETAIL("Menu assist_bonus", svc.BonusAssistMoney)
    }
    if (svc.BonusHeadshotMoney > 0)
    {
        ADDSVCDETAIL("Menu headshot_bonus", svc.BonusHeadshotMoney)
    }
    if (svc.BonusKnifeMoney > 0)
    {
        ADDSVCDETAIL("Menu knife_bonus", svc.BonusKnifeMoney)
    }
    if (svc.BonusZeusMoney > 0)
    {
        ADDSVCDETAIL("Menu zeus_bonus", svc.BonusZeusMoney)
    }
    if (svc.BonusGrenadeMoney > 0)
    {
        ADDSVCDETAIL("Menu grenade_bonus", svc.BonusGrenadeMoney)
    }
    if (svc.BonusMvpMoney > 0)
    {
        ADDSVCDETAIL("Menu mvp_bonus", svc.BonusMvpMoney)
    }
    if (svc.BonusNoscopeMoney > 0)
    {
        ADDSVCDETAIL("Menu noscope_bonus", svc.BonusNoscopeMoney)
    }
    if (svc.BonusHostageMoney > 0)
    {
        ADDSVCDETAIL("Menu hostage_bonus", svc.BonusHostageMoney)
    }
    if (svc.BonusBombPlantedMoney > 0)
    {
        ADDSVCDETAIL("Menu bomb_planted_bonus", svc.BonusBombPlantedMoney)
    }
    if (svc.BonusBombDefusedMoney > 0)
    {
        ADDSVCDETAIL("Menu bomb_defused_bonus", svc.BonusBombDefusedMoney)
    }

    menu.Display(client, MENU_TIME_FOREVER);
}

public int Menu_HandlerBonusesList(Menu menu, MenuAction action, int param1, int param2)
{
    switch(action)
    {
        case MenuAction_End:
        {
            delete menu;
        }
         case MenuAction_Cancel:
        {
            if (param2 == MenuCancel_ExitBack)
                ShowServiceBonuses(param1);
        }
        case MenuAction_Select:
        {
            return 0;
        }
    }

    return 0;
}

void ShowOnlineList(int client)
{
    Menu menu = new Menu(MenuHandler_List, MENU_ACTIONS_ALL);
    menu.Pagination = true;

    Service svc;

    int len = g_Services.Length;
    char display[MAX_SERVICE_NAME_SIZE];
    char itemID[16];

    for (int i = 0; i < len; ++i)
    {
        svc = g_Services.Get(i);
        svc.GetName(display, sizeof(display));

        IntToString(i, itemID, sizeof(itemID));
        FormatEx(itemID, sizeof(itemID), "%i", svc);

        menu.AddItem(itemID, display);
    }
    if (len == 0)
        menu.AddItem("noservices", "No services loaded");

    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_List(Menu menu, MenuAction action, int param1, int param2)
{
    switch(action)
    {
        case MenuAction_End:
        {
            delete menu;
        }
        case MenuAction_Display:
        {
            char title[255];
            FormatEx(title, sizeof(title), "%T", "Service Category List", param1);
            Panel panel = view_as<Panel>(param2);
            panel.SetTitle(title);
        }
        case MenuAction_DrawItem:
        {
            char info[16];
            menu.GetItem(param2, info, sizeof(info));

            if (StrEqual(info, "noservices"))
                return ITEMDRAW_DISABLED;

            return ITEMDRAW_DEFAULT;
        }
        case MenuAction_Select:
        {
            char info[16];
            char display[32];
            menu.GetItem(param2, info, sizeof(info), _, display, sizeof(display));

            Service svc = view_as<Service>(StringToInt(info));

            ServiceOnlineList(param1, svc, display);
        }
    }

    return 0;
}

void ServiceOnlineList(int client, Service svc, char[] serviceName)
{
    Menu menu = new Menu(MenuHandler_Online, MENU_ACTIONS_ALL);

    char title[255];
    FormatEx(title, sizeof(title), "%T", "Service Players Online", client, serviceName, "\n");
    menu.SetTitle(title);

    menu.Pagination = true;
    menu.ExitBackButton = true;

    int count = 0;

    char name[MAX_NAME_LENGTH];
    for(int i = 1; i <= MaxClients; ++i)
    {
        if (!IsClientAuthorized(i) || !IsClientInGame(i) || IsFakeClient(i))
            continue;

        if (svc != GetClientService(i))
            continue;

        GetClientName(i, name, sizeof(name));

        menu.AddItem("", name);
        count++;
    }
    if (count == 0)
        menu.AddItem("nodata", "No Players Online"); // translation phrase

    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Online(Menu menu, MenuAction action, int param1, int param2)
{
    switch(action)
    {
        case MenuAction_End:
        {
            delete menu;
        }
        case MenuAction_Cancel:
        {
            if (param2 == MenuCancel_ExitBack)
                ShowOnlineList(param1);
        }
        case MenuAction_DisplayItem:
        {
            char info[16];
            char display[64];
            menu.GetItem(param2, info, sizeof(info), _, display, sizeof(display));
            
            if (StrEqual(info, "nodata"))
                FormatEx(display, sizeof(display), "%T", display, param1);

            return RedrawMenuItem(display);
        }
        case MenuAction_DrawItem:
        {
            char info[16];
            menu.GetItem(param2, info, sizeof(info));

            if (StrEqual(info, "nodata"))
                return ITEMDRAW_DISABLED;

            return ITEMDRAW_DEFAULT;
        }
        case MenuAction_Select:
        {
            return 0;
        }
    }

    return 0;
}