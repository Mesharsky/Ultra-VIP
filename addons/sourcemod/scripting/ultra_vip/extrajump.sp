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

#define EXTRAJUMP_DEFAULT_STATE (true)

static bool s_IsEnabled[MAXPLAYERS + 1] = { EXTRAJUMP_DEFAULT_STATE, ... };

static bool s_AllowedToMultiJump[MAXPLAYERS + 1];
static int s_MaxMultiJumps[MAXPLAYERS + 1];
static float s_JumpHeight[MAXPLAYERS + 1];

// Players with service can toggle multijumps on/off.
public Action Command_ToggleJumps(int client, int args)
{
    Service svc = GetClientService(client);
    if (svc == null)
    {
        CReplyToCommand(client, "%t", "Service Required Command");
        return Plugin_Continue;
    }

    if (s_IsEnabled[client])
    {
        s_IsEnabled[client] = false;
        CPrintToChat(client, "%t", "Multi Jump Off");
    }
    else
    {
        s_IsEnabled[client] = true;
        CPrintToChat(client, "%t", "Multi Jump On");
    }

    return Plugin_Handled;
}

void ExtraJump_OnPlayerRunCmd(int client)
{
    if (!s_AllowedToMultiJump[client])
        return;

    static int previousButtons[MAXPLAYERS + 1];
    static int previousFlags[MAXPLAYERS + 1];
    static int jumpCount[MAXPLAYERS + 1];

    int flags = GetEntityFlags(client);
    int buttons = GetClientButtons(client);

    if (HasJustLanded(previousFlags[client], flags))
        jumpCount[client] = 0;
    else if (HasJustStartedJump(previousButtons[client], buttons))
    {
        if (HasJustLeftGround(previousFlags[client], flags))
            ++jumpCount[client];
        else
        {
            // If we are trying to jump mid-air after falling, skip the first
            // normal jump so we can attempt to extra-jump mid-air
            if (IsJumpingAfterFalling(jumpCount[client], flags))
                ++jumpCount[client];

            if (CanJumpAgain(client, jumpCount[client]))
            {
                ++jumpCount[client];
                FakeJump(client, s_JumpHeight[client]);
            }
        }
    }

    previousButtons[client] = buttons;
    previousFlags[client] = flags;
    return;
}

void ExtraJump_OnClientPostAdminCheck(int client, Service svc)
{
    if (svc == null)
    {
        s_AllowedToMultiJump[client] = false;
        return;
    }

    s_MaxMultiJumps[client] = svc.BonusExtraJumps;
    s_JumpHeight[client] = svc.BonusJumpHeight;
}

void ExtraJump_OnPlayerSpawn(int client, Service svc)
{
    s_AllowedToMultiJump[client] = false;

    if (svc == null)
        return;

    if (!s_IsEnabled[client])
        return;

    if (!IsPlayerAlive(client))
        return;

    if (!IsRoundAllowed(svc.BonusExtraJumpsRound))
        return;

    s_AllowedToMultiJump[client] = true;
}

void ExtraJump_OnPlayerDeath(int client)
{
    s_AllowedToMultiJump[client] = false;
}

void ExtraJump_OnClientDisconect(int client)
{
    s_IsEnabled[client] = EXTRAJUMP_DEFAULT_STATE;
    s_MaxMultiJumps[client] = 0;
    s_JumpHeight[client] = EXTRAJUMP_DEFAULT_HEIGHT;
    s_AllowedToMultiJump[client] = false;
}

static void FakeJump(int client, float jumpHeight = EXTRAJUMP_DEFAULT_HEIGHT)
{
    float velocity[3];
    GetEntPropVector(client, Prop_Data, "m_vecVelocity", velocity);

    velocity[2] = jumpHeight;

    TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, velocity);
}

static bool IsOnGround(int entFlags)
{
    return view_as<bool>(entFlags & FL_ONGROUND);
}

static bool HasJustLeftGround(int previousEntFlags, int currentEntFlags)
{
    return IsOnGround(previousEntFlags) && !IsOnGround(currentEntFlags);
}

static bool HasJustLanded(int previousEntFlags, int currentEntFlags)
{
    return  !IsOnGround(previousEntFlags) && IsOnGround(currentEntFlags);
}

static bool HasJustStartedJump(int previousButtons, int currentButtons)
{
    return !(previousButtons & IN_JUMP) && currentButtons & IN_JUMP;
}

static bool IsJumpingAfterFalling(int jumpCount, int entityFlags)
{
    return jumpCount == 0 && !IsOnGround(entityFlags);
}

static bool CanJumpAgain(int client, int &jumpCount)
{
    // 0 is the first jump from the ground, so it shouldn't be counted.
    // That makes s_MaxMultiJumps 1-indexed (so use <=)
    return jumpCount > 0 && jumpCount <= s_MaxMultiJumps[client];
}
