#include <a_samp>
#include <a_mysql>
#include <sscanf2>
#include "./include/database"
#include "./include/teleport"
#include <YSI_Visual\y_commands>

#define DIALOG_LOGIN_INPUT 1
#define DIALOG_REGISTER 2

new g_PlayerLogged[MAX_PLAYERS];

forward OnLoginResult(playerid);
forward OnRegisterResult(playerid);
forward OnLoginSuccess(playerid);

public OnGameModeInit()
{
    printf("Gamemode iniciado.");
    
    // Desactivar características por defecto
    DisableInteriorEnterExits();
    //DisableMenu();
    ShowPlayerMarkers(1);
    ShowNameTags(1);
    EnableStuntBonusForAll(0);

    Database_Init();

    return 1;
}

public OnPlayerConnect(playerid)
{
    TogglePlayerSpectating(playerid, true);
    g_PlayerLogged[playerid] = 0;

    new nombre[MAX_PLAYER_NAME];
    GetPlayerName(playerid, nombre, sizeof(nombre));

    new query[128];
    mysql_format(conexion, query, sizeof(query), "SELECT * FROM users WHERE nombre='%e' LIMIT 1", nombre);
    mysql_tquery(conexion, query, "OnLoginResult", "d", playerid);
    return 1;
}

public OnPlayerRequestClass(playerid, classid)
{
    // Prevenir la selección de clase
    TogglePlayerSpectating(playerid, true);
    
    // Redirigir al login/registro
    new nombre[MAX_PLAYER_NAME];
    GetPlayerName(playerid, nombre, sizeof(nombre));
    
    new query[128];
    mysql_format(conexion, query, sizeof(query), "SELECT * FROM users WHERE nombre='%e' LIMIT 1", nombre);
    mysql_tquery(conexion, query, "OnLoginResult", "d", playerid);
    
    return 0; // Rechazar la selección de clase
}

public OnPlayerSpawn(playerid)
{
    if(g_PlayerLogged[playerid] == 0)
    {
        Kick(playerid);
        return 0;
    }
    return 1;
}

public OnLoginResult(playerid)
{
    new title[32] = "";
    new message[64] = "";
    new button1[16] = "";
    new button2[16] = "";
    
    if (cache_num_rows() > 0)
    {
        strcat(title, "Login");
        strcat(message, "Introduce tu contrasena:");
        strcat(button1, "Iniciar");
        strcat(button2, "Salir");
        
        ShowPlayerDialog(playerid, DIALOG_LOGIN_INPUT, DIALOG_STYLE_PASSWORD, 
            title, message, button1, button2);
    }
    else
    {
        strcat(title, "Registro");
        strcat(message, "Elige una contrasena:");
        strcat(button1, "Registrar");
        strcat(button2, "Salir");
        
        ShowPlayerDialog(playerid, DIALOG_REGISTER, DIALOG_STYLE_PASSWORD, 
            title, message, button1, button2);
    }
    return 1;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    new nombre[MAX_PLAYER_NAME];
    GetPlayerName(playerid, nombre, sizeof(nombre));
    new query[256];
    
    if (dialogid == DIALOG_LOGIN_INPUT && response)
    {
        mysql_format(conexion, query, sizeof(query), "SELECT pos_x, pos_y, pos_z, skin FROM users WHERE nombre='%e' AND password='%s' LIMIT 1", nombre, WP_Hash(inputtext));
        mysql_tquery(conexion, query, "OnLoginSuccess", "d", playerid);
    }
    else if (dialogid == DIALOG_REGISTER && response)
    {
        mysql_format(conexion, query, sizeof(query), "INSERT INTO users (nombre, password) VALUES ('%e', '%s')", nombre, WP_Hash(inputtext));
        mysql_tquery(conexion, query, "OnRegisterResult", "d", playerid);
    }
    else
    {
        Kick(playerid);
    }
    return 1;
}

public OnLoginSuccess(playerid)
{
    if (cache_num_rows() > 0) // Verifica si el usuario existe en la base de datos
    {
        new Float:x = 1522.0, Float:y = -1690.0, Float:z = 13.5; // Valores por defecto
        new skin = 26;

        // Extraer la información de la base de datos
        cache_get_value_float(0, "pos_x", x);
        cache_get_value_float(0, "pos_y", y);
        cache_get_value_float(0, "pos_z", z);
        cache_get_value_int(0, "skin", skin);

        g_PlayerLogged[playerid] = 1;
        TogglePlayerSpectating(playerid, false); // Asegurar que deja de ser espectador
        SetSpawnInfo(playerid, 0, skin, x, y, z, 0.0, 0, 0, 0, 0, 0, 0); // Configurar spawn
        SpawnPlayer(playerid); // Forzar spawn

        // Usar variable mutable para el mensaje
        new welcome_msg[32] = "";
        strcat(welcome_msg, "Bienvenido de nuevo!");
        SendClientMessage(playerid, 0x00FF00FF, welcome_msg);
    }
    else
    {
        // Usar variables mutables para los strings del diálogo
        new title[32] = "";
        new message[64] = "";
        new button1[16] = "";
        new button2[16] = "";
        
        strcat(title, "Login");
        strcat(message, "Contraseña incorrecta. Intenta de nuevo:");
        strcat(button1, "Iniciar");
        strcat(button2, "Salir");
        
        ShowPlayerDialog(playerid, DIALOG_LOGIN_INPUT, DIALOG_STYLE_PASSWORD, 
            title, message, button1, button2);
    }
    return 1;
}

public OnRegisterResult(playerid)
{
    // Usar variable mutable para el mensaje
    new success_msg[64] = "";
    strcat(success_msg, "Registro exitoso! Ahora inicia sesion con tu nueva cuenta.");
    SendClientMessage(playerid, 0x00FF00FF, success_msg);
    
    // Usar variables mutables para los strings del diálogo
    new title[32] = "";
    new message[64] = "";
    new button1[16] = "";
    new button2[16] = "";
    
    strcat(title, "Login");
    strcat(message, "Introduce tu contrasena:");
    strcat(button1, "Iniciar");
    strcat(button2, "Salir");
    
    ShowPlayerDialog(playerid, DIALOG_LOGIN_INPUT, DIALOG_STYLE_PASSWORD, 
        title, message, button1, button2);
    return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
    if (g_PlayerLogged[playerid] == 1)
    {
        new query[128];
        new Float:x, Float:y, Float:z;
        new nombre[MAX_PLAYER_NAME];
        GetPlayerName(playerid, nombre, sizeof(nombre));
        GetPlayerPos(playerid, x, y, z);
        mysql_format(conexion, query, sizeof(query), "UPDATE users SET pos_x=%f, pos_y=%f, pos_z=%f WHERE nombre='%e'", x, y, z, nombre);
        mysql_tquery(conexion, query);
    }
    return 1;
}

stock WP_Hash(const buffer[])
{
    new length = strlen(buffer);
    new s1 = 1;
    new s2 = 0;
    new n;
    for (n = 0; n < length; n++)
    {
        s1 = (s1 + buffer[n]) % 65521;
        s2 = (s2 + s1) % 65521;
    }
    new dest[65];
    format(dest, sizeof(dest), "%04x%04x", s2, s1);
    return dest;
}

// Definir un enumerador sin etiquetas para que Pawn lo trate como enteros
enum _:TeleportLocationIndex {
    IDX_X,        // Índice de coordenada X
    IDX_Y,        // Índice de coordenada Y
    IDX_Z,        // Índice de coordenada Z
    IDX_INTERIOR, // Índice de interior
    IDX_VW        // Índice de Virtual World
}

// Definir un array con ubicaciones predefinidas con Float en las coordenadas
static const Float:TeleportLocations[][5] = { 
    {1520.0, -1708.0, 13.5, 0.0, 0.0},   // "garage"
    {2486.0, -1668.0, 13.3, 0.0, 0.0},   // "aeropuerto"
    {-2030.0, -118.0, 1035.0, 10.0, 0.0} // "casino"
};

// Definir los nombres de las ubicaciones predefinidas, en el mismo orden que el array anterior
static const TeleportNames[][] = {
    "garage",
    "aeropuerto",
    "casino"
};

// Definir los límites del mapa de San Andreas en SA-MP
#define MAP_LIMIT_X 3000.0
#define MAP_LIMIT_Y 3000.0
#define MAP_LIMIT_Z 2000.0  // Se ajusta para prevenir bugs de altura

// Comando de teletransporte
CMD:tp(playerid, params[])
{
    new Float:x, Float:y, Float:z;  // Variables para las coordenadas
    new interior = 0, vw = 0;       // Interior y Virtual World (por defecto 0)
    new index = -1; // Índice para verificar si el usuario ingresó un nombre de ubicación

    // Buscar si el parámetro ingresado es una ubicación predefinida
    for (new i = 0; i < sizeof(TeleportNames); i++)
    {
        if (strcmp(params, TeleportNames[i], true) == 0) // Comparar sin distinguir mayúsculas/minúsculas
        {
            index = i; // Guardar el índice de la ubicación encontrada
            break; // Salir del bucle una vez encontrada
        }
    }

    // Si se encontró una ubicación predefinida, asignar las coordenadas de esa ubicación
    if (index != -1)
    {
        x = TeleportLocations[index][IDX_X];
        y = TeleportLocations[index][IDX_Y];
        z = TeleportLocations[index][IDX_Z];
        interior = floatround(TeleportLocations[index][IDX_INTERIOR]); // Convertir a entero
        vw = floatround(TeleportLocations[index][IDX_VW]); // Convertir a entero
    }
    // Si no es una ubicación predefinida, intentar leer coordenadas manualmente
    else if (sscanf(params, "fffii", x, y, z, interior, vw))
    {
        return SendClientMessage(playerid, -1, "USO: /tp [Ubicación]");
    }

    // Verificar que las coordenadas ingresadas están dentro de los límites del mapa
    if (x < -MAP_LIMIT_X || x > MAP_LIMIT_X || 
        y < -MAP_LIMIT_Y || y > MAP_LIMIT_Y || 
        z < 0.0 || z > MAP_LIMIT_Z)
    {
        return SendClientMessage(playerid, -1, "❌ ERROR: Las coordenadas están fuera del límite del mapa.");
    }

    // Teletransportar al jugador a las coordenadas especificadas
    SetPlayerPos(playerid, x, y, z);
    SetPlayerInterior(playerid, interior);
    SetPlayerVirtualWorld(playerid, vw);

    // Confirmar la teletransportación con un mensaje
    SendClientMessage(playerid, -1, "📌 Te has teletransportado correctamente.");
    return 1;
}
