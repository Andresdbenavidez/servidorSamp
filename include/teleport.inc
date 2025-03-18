#if defined _TELEPORT_INCLUDED
    #endinput
#endif
#define _TELEPORT_INCLUDED

forward TeleportPlayer(playerid, Float:x, Float:y, Float:z);
public TeleportPlayer(playerid, Float:x, Float:y, Float:z)
{
    SetPlayerPos(playerid, x, y, z);
    new msg[128];
    format(msg, sizeof(msg), "Te has teletransportado a X:%.2f Y:%.2f Z:%.2f", x, y, z);
    SendClientMessage(playerid, 0x00FF00FF, msg);
    return 1;
}
