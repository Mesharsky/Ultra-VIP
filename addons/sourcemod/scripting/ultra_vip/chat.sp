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
    FormatTeamColor(author, namecolor);
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
    
    FormatTeamColor(author, namecolor);
    ApplyColors(name, namecolor, message, svc);

    return Plugin_Changed;
}

void FormatTeamColor(int author, char namecolor[32])
{
    int team = GetClientTeam(author);

    if (team == CS_TEAM_CT)
        ReplaceString(namecolor, sizeof(namecolor), "{teamcolor}", "{blue}");
    else if (team == CS_TEAM_T)
        ReplaceString(namecolor, sizeof(namecolor), "{teamcolor}", "\x03");
    else if (team == CS_TEAM_SPECTATOR)
        ReplaceString(namecolor, sizeof(namecolor), "{teamcolor}", "{grey}");
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