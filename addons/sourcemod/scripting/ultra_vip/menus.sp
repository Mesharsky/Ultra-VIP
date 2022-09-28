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
            {
                FormatEx(display, sizeof(display), "%T", display, param1);
            }
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