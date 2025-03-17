#include <a_samp>
#include <a_mysql>
#include <sscanf2>

#define DIALOG_LOGIN_INPUT 1
#define DIALOG_REGISTER 2

new MySQL:conexion;
new g_PlayerLogged[MAX_PLAYERS];

forward OnLoginResult(playerid);
forward OnRegisterResult(playerid);
forward OnLoginSuccess(playerid);
forward command_tp(playerid, params[]); // Forward declaration para el comando

public OnGameModeInit()
{
    // El uso de variables temporales resuelve el problema de los strings literales
    new const host[] = "localhost";
    new const user[] = "root";
    new const password[] = "";
    new const database[] = "baredb";
    conexion = mysql_connect(host, user, password, database);

    if (conexion == MYSQL_INVALID_HANDLE)
    {
        print("Error al conectar con MySQL.");
        return 0;
    }
    print("Conectado a MySQL correctamente.");
    
    // Usar variable temporal para el query
    new const create_query[] = "CREATE TABLE IF NOT EXISTS users (id INT AUTO_INCREMENT PRIMARY KEY, nombre VARCHAR(24) NOT NULL UNIQUE, password VARCHAR(64) NOT NULL, pos_x FLOAT DEFAULT 1522.0, pos_y FLOAT DEFAULT -1690.0, pos_z FLOAT DEFAULT 13.5, skin INT DEFAULT 0)";
    mysql_tquery(conexion, create_query);
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

public OnLoginResult(playerid)
{
    new title[32], message[64], button1[16], button2[16];
    
    if (cache_num_rows() > 0)
    {
        // Usar strcat en lugar de asignación directa
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
        new skin = 0;

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
        new welcome_msg[32];
        strcat(welcome_msg, "Bienvenido de nuevo!");
        SendClientMessage(playerid, 0x00FF00FF, welcome_msg);
    }
    else
    {
        // Usar variables mutables para los strings del diálogo
        new title[32], message[64], button1[16], button2[16];
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
    new success_msg[64];
    strcat(success_msg, "Registro exitoso! Ahora inicia sesion con tu nueva cuenta.");
    SendClientMessage(playerid, 0x00FF00FF, success_msg);
    
    // Usar variables mutables para los strings del diálogo
    new title[32], message[64], button1[16], button2[16];
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

// Implementación del comando tp
public command_tp(playerid, params[])
{
    new targetid;
    
    if (sscanf(params, "d", targetid)) 
    {
        // Usar variable mutable para el mensaje
        new usage_msg[32];
        strcat(usage_msg, "Uso: /tp [ID del jugador]");
        SendClientMessage(playerid, 0xFF0000FF, usage_msg);
        return 1;
    }

    if (!IsPlayerConnected(targetid) || targetid == INVALID_PLAYER_ID) 
    {
        // Usar variable mutable para el mensaje
        new error_msg[32];
        strcat(error_msg, "Ese jugador no está conectado.");
        SendClientMessage(playerid, 0xFF0000FF, error_msg);
        return 1;
    }

    new Float:x, Float:y, Float:z;
    GetPlayerPos(targetid, x, y, z); // Obtiene la posición del jugador objetivo

    SetPlayerPos(playerid, x + 1.5, y, z); // Teletransporta al jugador al lado del objetivo

    // Usar variable mutable para el mensaje
    new success_msg[48];
    strcat(success_msg, "Te has teletransportado correctamente!");
    SendClientMessage(playerid, 0x00FF00FF, success_msg);
    return 1;
}

// Si se usa YCMD, añadir esto:
// YCMD:tp(playerid, params[], help)
// {
//     return command_tp(playerid, params);
// }

// Si se usa ZCMD, añadir esto:
// COMMAND:tp(playerid, params[])
// {
//     return command_tp(playerid, params);
// }

// Si se usa el sistema de comandos nativo, añadir esto:
public OnPlayerCommandText(playerid, cmdtext[])
{
    if (strcmp(cmdtext, "/tp", true, 3) == 0)
    {
        return command_tp(playerid, cmdtext[3]);
    }
    return 0;
}







// Definiciones para el sistema de NPCs
#define MAX_NPCS 50 // Máximo de NPCs que se pueden crear
#define NPC_SPAWN_RADIUS 2000.0 // Radio desde el centro del mapa donde pueden aparecer NPCs

// Array para almacenar IDs de NPCs
new g_NPCIDs[MAX_NPCS];
new g_NPCCount = 0;

// Puntos de spawn predefinidos (puedes ajustarlos según tu mapa)
new Float:g_SpawnPoints[][3] = {
    {1543.5, -1353.2, 13.5},   // Centro de Los Santos
    {2503.1, -1682.3, 13.5},   // East Los Santos
    {2228.8, -1721.9, 13.5},   // Jefferson
    {1125.9, -2036.5, 69.8},   // Verona Beach
    {2635.5, -2124.8, 13.5},   // Ocean Docks
    {1797.4, -1578.3, 13.5},   // Downtown
    {2191.5, -1455.7, 25.5},   // East Los Santos
    {1902.3, -1320.2, 13.5},   // Commerce
    {1187.8, -1323.1, 13.5},   // Market
    {657.1, -1867.5, 5.5},     // Santa Maria Beach
    {454.3, -1502.7, 31.0},    // Rodeo
    {2292.8, -2013.2, 13.5},   // Ganton
    {1367.5, -1279.8, 13.5},   // Commerce
    {1831.7, -1842.5, 13.5},   // El Corona
    {1210.7, -1755.8, 13.5},   // Idlewood
    {1572.8, -1898.1, 13.5},   // Las Colinas
    {1985.3, -1455.2, 13.5},   // Jefferson
    {2114.9, -1754.8, 13.5},   // Willowfield
    {1352.6, -1758.9, 13.5},   // Idlewood
    {1401.8, -1699.4, 13.5}    // Idlewood
};

// Nombres predefinidos para los NPCs
new g_NPCNames[][24] = {
    "Carlos_Rodriguez", "Maria_Sanchez", "Juan_Perez", "Ana_Martinez", 
    "Luis_Gonzalez", "Sofia_Lopez", "Pedro_Ramirez", "Elena_Torres", 
    "Miguel_Diaz", "Isabel_Ortiz", "Jose_Hernandez", "Laura_Garcia", 
    "Roberto_Flores", "Carmen_Vargas", "Antonio_Reyes", "Lucia_Mendoza", 
    "Francisco_Morales", "Gabriela_Castillo", "Sergio_Delgado", "Rosa_Navarro",
    "Jorge_Soto", "Marta_Ramos", "Alejandro_Guzman", "Silvia_Rojas",
    "Fernando_Castro", "Patricia_Medina", "Alberto_Suarez", "Victoria_Romero",
    "Daniel_Molina", "Alicia_Jimenez", "Marco_Herrera", "Beatriz_Vasquez",
    "Ricardo_Aguilar", "Teresa_Salazar", "Victor_Marquez", "Natalia_Ruiz",
    "Eduardo_Alvarez", "Adriana_Guerrero", "Pablo_Fuentes", "Claudia_Velasco",
    "Manuel_Dominguez", "Monica_Espinoza", "Javier_Acosta", "Susana_Rios",
    "Oscar_Cabrera", "Cristina_Quintero", "Raul_Campos", "Diana_Vega",
    "Felix_Nunez", "Veronica_Sandoval"
};

// Skins predefinidos para los NPCs
new g_NPCSkins[] = {
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 
    11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
    21, 22, 23, 24, 25, 26, 27, 28, 29, 30,
    31, 32, 33, 34, 35, 36, 37, 38, 39, 40,
    41, 42, 43, 44, 45, 46, 47, 48, 49, 50
};

// Función para crear un NPC aleatorio
forward CreateRandomNPC();
public CreateRandomNPC()
{
    if (g_NPCCount >= MAX_NPCS) {
        print("Límite de NPCs alcanzado. No se pueden crear más.");
        return 0;
    }
    
    // Elegir un punto de spawn aleatorio
    new spawnIndex = random(sizeof(g_SpawnPoints));
    new Float:x = g_SpawnPoints[spawnIndex][0];
    new Float:y = g_SpawnPoints[spawnIndex][1];
    new Float:z = g_SpawnPoints[spawnIndex][2];
    
    // Añadir un poco de aleatoriedad a la posición
    x += float(random(20) - 10);
    y += float(random(20) - 10);
    
    // Elegir un nombre aleatorio
    new nameIndex = random(sizeof(g_NPCNames));
    new name[24];
    strcpy(name, g_NPCNames[nameIndex]);
    
    // Añadir un número aleatorio al nombre para hacerlo único
    new uniqueNumber[4];
    format(uniqueNumber, sizeof(uniqueNumber), "%d", random(100));
    strcat(name, uniqueNumber);
    
    // Elegir un skin aleatorio
    new skinIndex = random(sizeof(g_NPCSkins));
    new skin = g_NPCSkins[skinIndex];
    
    // Conectar al NPC (simular conexión)
    new playerid = ConnectNPC(name, skin, x, y, z);
    
    if (playerid != INVALID_PLAYER_ID) {
        g_NPCIDs[g_NPCCount] = playerid;
        g_NPCCount++;
        
        new logMessage[128];
        format(logMessage, sizeof(logMessage), "NPC '%s' creado con ID %d en posición %.1f, %.1f, %.1f con skin %d", 
            name, playerid, x, y, z, skin);
        print(logMessage);
        return playerid;
    }
    
    print("Error al crear el NPC");
    return INVALID_PLAYER_ID;
}

// Función para simular la conexión de un NPC
stock ConnectNPC(const name[], skin, Float:x, Float:y, Float:z)
{
    // Aquí normalmente usarías una función para conectar NPCs reales
    // Pero como estamos creando NPCs simulados, vamos a crear un jugador falso
    
    // Buscar un slot libre (ID de jugador)
    new playerid = INVALID_PLAYER_ID;
    for (new i = 0; i < MAX_PLAYERS; i++) {
        if (!IsPlayerConnected(i)) {
            playerid = i;
            break;
        }
    }
    
    if (playerid == INVALID_PLAYER_ID) {
        return INVALID_PLAYER_ID; // No hay slots libres
    }
    
    // Código para simular la conexión - esto es solo para demostración
    // En un servidor real, usarías funciones específicas de SA-MP para NPCs
    
    // Establecer el nombre del NPC
    SetPlayerName(playerid, name);
    
    // Establecer el skin del NPC
    SetPlayerSkin(playerid, skin);
    
    // Establecer la posición del NPC
    SetPlayerPos(playerid, x, y, z);
    
    // Establecer algunas propiedades adicionales para que parezca un NPC
    SetPlayerVirtualWorld(playerid, 0);
    SetPlayerInterior(playerid, 0);
    SetPlayerHealth(playerid, 100.0);
    SetPlayerArmour(playerid, 0.0);
    
    return playerid;
}

// Función para eliminar un NPC
forward RemoveNPC(playerid);
public RemoveNPC(playerid)
{
    if (!IsPlayerConnected(playerid)) {
        return 0;
    }
    
    // Eliminar el NPC de nuestro array
    for (new i = 0; i < g_NPCCount; i++) {
        if (g_NPCIDs[i] == playerid) {
            // Mover los elementos restantes
            for (new j = i; j < g_NPCCount - 1; j++) {
                g_NPCIDs[j] = g_NPCIDs[j + 1];
            }
            g_NPCCount--;
            break;
        }
    }
    
    // Desconectar al NPC
    Kick(playerid);
    
    new logMessage[64];
    format(logMessage, sizeof(logMessage), "NPC con ID %d eliminado", playerid);
    print(logMessage);
    
    return 1;
}

// Comando para crear un NPC aleatorio
forward CMD:createnpc(playerid, params[]);
public CMD:createnpc(playerid, params[])
{
    new count = 1;
    
    if (strlen(params) > 0) {
        count = strval(params);
        if (count <= 0 || count > 50) {
            // Usar variable mutable para el mensaje
            new error_msg[64];
            strcpy(error_msg, "Uso: /createnpc [cantidad (1-50)]");
            SendClientMessage(playerid, 0xFF0000FF, error_msg);
            return 1;
        }
    }
    
    new created = 0;
    for (new i = 0; i < count; i++) {
        if (CreateRandomNPC() != INVALID_PLAYER_ID) {
            created++;
        }
    }
    
    // Enviar mensaje de éxito
    new success_msg[64];
    format(success_msg, sizeof(success_msg), "Se han creado %d NPCs aleatorios", created);
    SendClientMessage(playerid, 0x00FF00FF, success_msg);
    
    return 1;
}

// Comando para eliminar todos los NPCs
forward CMD:removenpcs(playerid, params[]);
public CMD:removenpcs(playerid, params[])
{
    new count = g_NPCCount;
    
    // Copiar el array para evitar problemas durante la iteración
    new npcsToRemove[MAX_NPCS];
    for (new i = 0; i < g_NPCCount; i++) {
        npcsToRemove[i] = g_NPCIDs[i];
    }
    
    // Eliminar todos los NPCs
    for (new i = 0; i < count; i++) {
        RemoveNPC(npcsToRemove[i]);
    }
    
    // Enviar mensaje de éxito
    new success_msg[64];
    format(success_msg, sizeof(success_msg), "Se han eliminado %d NPCs", count);
    SendClientMessage(playerid, 0x00FF00FF, success_msg);
    
    return 1;
}

// Función para que los NPCs se muevan aleatoriamente
forward MoveNPCsRandomly();
public MoveNPCsRandomly()
{
    for (new i = 0; i < g_NPCCount; i++) {
        new playerid = g_NPCIDs[i];
        if (IsPlayerConnected(playerid)) {
            // Obtener posición actual
            new Float:x, Float:y, Float:z;
            GetPlayerPos(playerid, x, y, z);
            
            // Generar un movimiento aleatorio
            new Float:moveX = float(random(10) - 5); // -5 a 5
            new Float:moveY = float(random(10) - 5); // -5 a 5
            
            // Aplicar el movimiento
            SetPlayerPos(playerid, x + moveX, y + moveY, z);
            
            // Establece una orientación aleatoria
            SetPlayerFacingAngle(playerid, float(random(360)));
        }
    }
    return 1;
}

// Añadir estas funciones a tu gamemode
// Agregar al OnGameModeInit:
public OnGameModeInit()
{
    // Tu código existente
    
    // Iniciar el timer para mover NPCs aleatoriamente cada 10 segundos
    SetTimer("MoveNPCsRandomly", 10000, true);
    
    return 1;
}

// Agregar al OnPlayerCommandText si usas el sistema nativo de comandos:
public OnPlayerCommandText(playerid, cmdtext[])
{
    // Tu código existente
    
    if (strcmp(cmdtext, "/createnpc", true, 10) == 0) {
        return CMD:createnpc(playerid, cmdtext[11]);
    }
    else if (strcmp(cmdtext, "/removenpcs", true, 11) == 0) {
        return CMD:removenpcs(playerid, "");
    }
    
    return 0; // Comando no reconocido
}

// O usar estas definiciones si usas otro sistema de comandos:
/*
COMMAND:createnpc(playerid, params[])
{
    return CMD:createnpc(playerid, params);
}

COMMAND:removenpcs(playerid, params[])
{
    return CMD:removenpcs(playerid, params);
}
*/