/**
 * Copyright (C) Mesharsky & sirdigbot
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

#include <sourcemod>
#include <multicolors>

#pragma newdecls required
#pragma semicolon 1

#define PLUGIN_VERSION "0.1"

public Plugin myinfo =
{
	name = "Ultra VIP",
	author = "Mesharsky & sirdigbot",
	description = "Advanced Vip System that supports multimple VIP services setup",
	version = PLUGIN_VERSION,
	url = "https://github.com/Mesharsky/Ultra-VIP"
};

public void OnPluginStart()
{
    LoadTranslations("ultra_vip.phrases.txt");
}

public void OnConfigsExecuted()
{
    KV_Build();
}
