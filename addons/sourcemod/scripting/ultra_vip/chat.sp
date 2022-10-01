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

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
    if (!sArgs[0])
        return Plugin_Continue;

    int len = strlen(sArgs);
    char[] filtered = new char[len +1];

    BreakString(sArgs, filtered, len);

    int count = 0;
    for(int i = 0; i < len; ++i)
    {
        if (sArgs[i] != '!' && sArgs[i] != '/')
        {
            filtered[count] = sArgs[i];
            ++count;
        }
    }

    if (!filtered[0])
        return Plugin_Continue;

    if (!g_UseOnlineList && g_OnlineListCommands != null && g_OnlineListCommands.ContainsKey(filtered))
    {
        ShowOnlineList(client);
        return Plugin_Handled;
    }

    if (!g_UseBonusesList && g_BonusesListCommands != null && g_BonusesListCommands.ContainsKey(filtered))
    {
        ShowServiceBonuses(client);
        return Plugin_Handled;
    }

    return Plugin_Continue;
}

public Action CP_OnChatMessage(int& author, ArrayList recipients, char[] flagstring, char[] name, char[] message, bool& processcolors, bool& removecolors)
{
    if (g_ChatTagPlugin.processor != Processor_ChatProcessor)
        return Plugin_Continue;

    Service svc = GetClientService(author);
    if (svc == null)
        return Plugin_Continue;

    char namecolor[32];
    svc.GetChatNameColor(namecolor, sizeof(namecolor));

    // Colors does not support {teamcolor} at all. So we need to create it manually. It's gross and nasty but can't think of other way.
    // Since we support name and message color that's the only approach i can think of.
    FormatTeamColor(namecolor, sizeof(namecolor));
    ApplyColors(name, namecolor, message, svc);

    return Plugin_Changed;
}

public Action OnChatMessage(int &author, Handle recipients, char[] name, char[] message)
{
    if (g_ChatTagPlugin.processor != Processor_SCP)
        return Plugin_Continue;

    Service svc = GetClientService(author);
    if (svc == null)
        return Plugin_Continue;

    char namecolor[32];
    svc.GetChatNameColor(namecolor, sizeof(namecolor));

    FormatTeamColor(namecolor, sizeof(namecolor));
    ApplyColors(name, namecolor, message, svc);

    return Plugin_Changed;
}

void FormatTeamColor(char[] namecolor, int size)
{
    ReplaceString(namecolor, size, "{teamcolor}", "\x03");
}

void ApplyColors(char[] name, char[] namecolor, char[] message, Service svc)
{
    char tag[32];
    svc.GetChatTag(tag, sizeof(tag));
    char msgcolor[32];
    svc.GetChatMsgColor(msgcolor, sizeof(msgcolor));

    Format(name, MAXLENGTH_NAME, " %s %s%s", tag, namecolor, name);
    CFormatColor(name, MAXLENGTH_NAME);
    Format(message, MAXLENGTH_MESSAGE, "%s%s", msgcolor, message);
    CFormatColor(message, MAXLENGTH_MESSAGE);
}