#if defined _database_included
    #endinput
#endif
#define _database_included

new MySQL:conexion;

// Declarar la función para ser llamada en OnGameModeInit
forward Database_Init();
public Database_Init()
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
