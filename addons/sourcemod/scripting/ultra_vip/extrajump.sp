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

static bool s_CanMultiJump[MAXPLAYERS + 1]; // Must set to false if player dies or disconnects
static int s_MaxMultiJumps[MAXPLAYERS + 1];

void ExtraJump_OnPlayerRunCmd(int client, int &buttons, float vel[3])
{
    if (s_CanMultiJump[client])
    {
        static int previousButtons[MAXPLAYERS + 1];
        static int previousFlags[MAXPLAYERS + 1];
        static int jumpCount[MAXPLAYERS + 1];
    
        int flags = GetEntityFlags(client);

        if (flags & FL_ONGROUND)
            jumpCount[client] = 0;
        else if (HasStartedJump(previousButtons[client], buttons))
        {
            if (HasLeftGround(previousFlags[client], flags))
                ++jumpCount[client];
            else if (CanMultiJump(client, jumpCount[client]))
            {
                ++jumpCount[client];
                FakeJump(client, vel);
            }
        }

        previousButtons[client] = buttons;
        previousFlags[client] = flags;
    }
}

void ExtraJump_OnClientPostAdminCheck(int client, Service svc)
{
    if (svc == null)
    {
        s_CanMultiJump[client] = false;
        return;
    }    

    s_MaxMultiJumps[client] = svc.BonusExtraJumps;
}

void ExtraJump_OnPlayerSpawn(int client, Service svc)
{
    if (svc == null)
    {
        s_CanMultiJump[client] = false;
        return;
    }    

    if(IsRoundAllowed(svc.BonusExtraJumpsRound))
        s_CanMultiJump[client] = true;
}

void ExtraJump_OnPlayerDeath(int client)
{
    s_CanMultiJump[client] = false;
}

void ExtraJump_OnClientDisconect(int client)
{
    s_CanMultiJump[client] = false;
}

static void FakeJump(int client, float velocity[3], float jumpHeight = 250.0)
{
    velocity[2] = jumpHeight;

    TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, velocity);
}

static bool HasLeftGround(int previousEntFlags, int currentEntFlags)
{
    return previousEntFlags & FL_ONGROUND && !(currentEntFlags & FL_ONGROUND);
}

static bool HasStartedJump(int previousButtons, int currentButtons)
{
    return !(previousButtons & IN_JUMP) && currentButtons & IN_JUMP;
}

static bool CanMultiJump(int client, int jump)
{
    return jump > 0 && jump < s_MaxMultiJumps[client];
}