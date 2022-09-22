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

    char tag[32];
    svc.GetChatTag(tag, sizeof(tag));    
	
    Format(name, MAXLENGTH_NAME, " %s\x03 %s", tag, name);
	
    return Plugin_Changed;
}

public Action OnChatMessage(int &author, Handle recipients, char[] name, char[] message)
{
    if (g_ChatTagPlugin.processor != Processor_SCP)
        return Plugin_Continue;

    Service svc = GetClientService(author);
    if (svc == null)
        return Plugin_Continue;

    char tag[32];
    svc.GetChatTag(tag, sizeof(tag));

    Format(name, MAXLENGTH_NAME, " %s\x03 %s", tag, name);
    CFormatColor(name, MAXLENGTH_NAME);

    return Plugin_Changed;
}