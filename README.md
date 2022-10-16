# Ultra-VIP

**Ultra-VIP** is a fully featured and extensible VIP bonus system for SourceMod 1.11+.

It is a complete remake and rewrite of [this older, more limited plugin](https://forums.alliedmods.net/showthread.php?t=320113 "older more disgusting plugin").  

###### Important Note: Ultra-VIP does not give out admin permissions. It applies bonuses to players that already have admin permission access. This means you need another plugin to actually grant a player access to admin flags/overrides.*


### Features
- More than just \"VIP\".
  - This plugin supports creating any amount of custom \"VIP\" services that can all be configured separately (e.g. \"VIP\", \"Super-VIP\", or whatever you want!)
- Tons of highly and easily configurable player bonuses (see the list below).
- Supports Admin Flags *(Legacy permissions)* or Overrides/Groups *(Modern permissions)*. Whichever you prefer.
- Module API for extending functionality.
  - Does Ultra-VIP not have a feature you want? You can add your own! See the github wiki for a [tutorial on how to make modules]().
- Full translation support (currently only English and Polish, but pull requests are welcome).
- It\'s **FREE**. Now you don\'t need to *pay* for some sketchy programmer\'s bad code!

------------

### Installation

Download the [latest release.](https://github.com/Mesharsky/Ultra-VIP/releases "Latest Release")  

1. Upload all files to root directory of your server ([How to install plugins](https://wiki.alliedmods.net/Managing_your_sourcemod_installation#Installing_Plugins "Installing Plugins"))
2. Configure plugin settings and services in the configuration file: `addons/sourcemod/configs/ultra_vip_main.cfg`.
    - Read the documentation inside the file!
3. Make sure to set a player\'s admin permissions! Ultra-VIP does not grant players admin flags/overrides/groups.

For further details read [the set up guide on the github wiki](https://github.com/Mesharsky/Ultra-VIP/wiki/Setup "Setup Guide").

------------

### List of Player Bonuses
All of these bonuses can be enabled/disabled, and the round that they apply to a player can be configured.  

All of these bonuses can be configured as well as disabled.  
The round that they start becomnig active on can be changed.

| Spawn Bonus | Description |
| --- | --- |
| Bonus HP | Set the player\'s HP on spawn. |
| Bonus Armor | Set the player\'s armor on spawn. |
| Free Helmet | Give the player a helmet on spawn. |
| Free Defuser | Give the player a defuser on spawn. |
| Free Grenades/Equipment | Give the player any grenades/equipment on spawn. All utility is supported and can be specified individually (HEs, Flashbangs, Smokes, Decoys, Molotovs, Healthshots, Tactical Awareness Grenades, Snowballs, Breach Charges, Bump Mines). |
| Multi-Jump | Extra mid-air jumps (as many as you want!). |
| Riot Shield | Give the player a riot shield on spawn. (Only works on Casual Gamemode) |
| Gravity Scaling | Decrease or increase the players gravity. |
| Speed Modifier | Increase or decrease the player\'s movement speed. |
| Player Invisibility | Change how visible the player is (alpha/opacity). |
| Fall Damage Reduction | Reduce player fall damage. |
| Attack Damage Boost | Increase or decrease the player\'s attack damage. |
| Damage Resistance | Reduce damage taken by the player. |
| Unlimited Ammo | Infinite ammo (endless magazine). |
| No-Recoil | Disable weapon recoil. *Movement inaccuracy and spread still function.* |  

| Money Bonus |
| --- |
| Extra money on Spawn |
| Extra money on Kill |
| Extra money on Assist |
| Extra money on Headshot Kill |
| Extra money on Knife Kill |
| Extra money on Zeus/Taser Kill |
| Extra money on Grenade Kill |
| Extra money for MVP |
| Extra money for No-scope Kill |
| Extra money for Hostage Rescue |
| Extra money for Bomb Planted |
| Extra money for Bomb Defused |  

| HP Bonus |
| --- |
| Extra HP on Kill |
| Extra HP on Assist |
| Extra HP on Headshot Kill |
| Extra HP on Knife Kill |
| Extra HP on Zeus/Taser Kill |
| Extra HP on Grenade Kill |
| Extra HP for No-scope Kill |  

------------

### Commands
| Command | Description |
| ------------ | ------------ |
| **!jumps** | Toggle Multi-Jump On / OFF *(requires access to Multi-Jump)* |
| **!vips** | List Of online players that have a service. |
| **!vipbonus** | List of  bonuses that services have. |
| **!reloadservices** | Reload configuration file *(requires root flag)*. |
