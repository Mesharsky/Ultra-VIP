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

/////////////////////////////////////////////////////////
/*
            -> NORMAL MODE
*/
////////////////////////////////////////////////////////
public void Event_PlayerSpawn(Event event, const char[] name, bool bDontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    PlayerSpawnApplyBonuses(client);    
    /*
        Arena mode uses a special forward for Player_Spawn. So we won't be applying bonuses in this event.  
    */

}

void PlayerSpawnApplyBonuses(int client)
{

}

public void Event_PlayerDeath(Event event, const char[] name, bool bDontBroadcast)
{
    int victim = GetClientOfUserId(event.GetInt("userid"));
    int attacker = GetClientOfUserId(event.GetInt("attacker"));

    bool headshot = event.GetBool("headshot", false);

    PlayerDeathApplyBonuses(victim, attacker, headshot);
}

void PlayerDeathApplyBonuses(int victim, int attacker, bool headshot)
{
    // damnn this one will be long
}