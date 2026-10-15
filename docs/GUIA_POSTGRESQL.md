# Guía paso a paso: conectar el juego a PostgreSQL

El juego (Godot) **no se conecta directo** a PostgreSQL. Habla con un servidor local (API en Node.js) que sí
guarda y consulta los datos en PostgreSQL. Ese mismo servidor muestra el panel web.

```
 Juego (Godot) --HTTP/JSON--> Servidor Node.js --SQL--> PostgreSQL
                                   |
                                   +--> Panel web  http://localhost:3000
```

Tienes dos formas de levantar todo. Elige **una**:
- **Opción A: instalación normal** (PostgreSQL + Node.js en tu computadora).
- **Opción B: Docker** (un solo comando, no instalas nada más).

---

## Opción A. Instalación normal

### 1. Instalar los programas
| Programa | Versión | Enlace |
|---|---|---|
| PostgreSQL | 12 o superior | https://www.postgresql.org/download/ |
| Node.js | 18 o superior (recomendado 20 o 22) | https://nodejs.org |
| Godot | 4.7 (probado con 4.7.2) | https://godotengine.org |
| Git | cualquiera | https://git-scm.com |

**Windows:** ejecuta el instalador de PostgreSQL. Anota la contraseña del superusuario `postgres` que te pide,
deja el puerto `5432` y marca **pgAdmin 4** y **Command Line Tools**.

**macOS:** `brew install postgresql@16 && brew services start postgresql@16`

**Ubuntu / Debian:** `sudo apt install postgresql postgresql-client` y luego `sudo service postgresql start`

### 2. Crear el usuario y la base de datos
Abre **SQL Shell (psql)** en Windows, o una terminal y escribe `sudo -u postgres psql` en Linux/macOS.
Ejecuta estas líneas, una por una:

```sql
CREATE USER escape_user WITH PASSWORD 'escape_pass';
CREATE DATABASE escape_lab OWNER escape_user;
\q
```

> Con **pgAdmin**: clic derecho en *Login/Group Roles → Create* (nombre `escape_user`, pestaña Definition con la
> contraseña, pestaña Privileges con *Can login*), y clic derecho en *Databases → Create* (nombre `escape_lab`,
> owner `escape_user`).

Comprueba que funciona:
```
psql -h localhost -U escape_user -d escape_lab
```
Si te pide la contraseña (`escape_pass`) y entra, la base está lista. Sal con `\q`.

### 3. Descargar el proyecto
```
git clone https://github.com/TU_USUARIO/escape-del-laboratorio.git
cd escape-del-laboratorio/server
```

### 4. Configurar el servidor
Copia el archivo de ejemplo y edítalo:

```
cp .env.example .env        # en Windows: copy .env.example .env
```

Contenido de `.env`:
```
PORT=3000
DATABASE_URL=postgres://escape_user:escape_pass@localhost:5432/escape_lab
ADMIN_PASSWORD=pon_aqui_tu_clave
```

La `DATABASE_URL` tiene el formato `postgres://USUARIO:CONTRASEÑA@SERVIDOR:PUERTO/BASE`.
Si usaste otro usuario, contraseña o nombre de base, cámbialos aquí.
`ADMIN_PASSWORD` es la clave para entrar a las secciones de administración del panel web.

### 5. Instalar y arrancar el servidor
```
npm install
npm start
```
Al arrancar, el servidor **crea las tablas solo** (ejecuta `server/db/schema.sql`). Debes ver:
```
Servidor listo en http://localhost:3000
```
Si prefieres crear las tablas a mano: `psql -h localhost -U escape_user -d escape_lab -f db/schema.sql`

### 6. Abrir el panel web
Entra a **http://localhost:3000**. Verás el leaderboard (público). Para las demás secciones
(Resumen, Jugadores, Partidas, Eventos, Exportar) pulsa en ellas e ingresa tu `ADMIN_PASSWORD`.

### 7. Abrir y jugar
1. Abre Godot → **Importar** → `game/project.godot` → **F5**.
2. En la pantalla de inicio, arriba a la izquierda debe decir **SERVIDOR EN LINEA** (en verde).
3. Pulsa **Registrarse**, crea tu cuenta, inicia sesión y juega.
4. Recarga el panel web: tu partida, tus eventos y tu puntuación ya están en la base de datos.

### 8. Comprobar los datos con SQL
```
psql -h localhost -U escape_user -d escape_lab
```
```sql
SELECT id, status, score, play_time, coins FROM runs ORDER BY id DESC LIMIT 5;
SELECT event_type, count(*) FROM run_events GROUP BY 1 ORDER BY 2 DESC;
SELECT * FROM collectibles ORDER BY id DESC LIMIT 10;
```
En `docs/consultas.sql` hay más consultas listas para el reporte.

---

## Opción B. Docker (todo con un comando)

Requiere Docker Desktop. Desde la carpeta raíz del repositorio:

```
docker compose up --build
```
Esto levanta PostgreSQL y el servidor. Entra a **http://localhost:3000**.
La clave de administración por defecto es `cambia_esta_clave`; para cambiarla:

```
ADMIN_PASSWORD=mi_clave docker compose up --build        # Linux / macOS
$env:ADMIN_PASSWORD="mi_clave"; docker compose up --build  # Windows PowerShell
```
Para detener: `Ctrl + C` y luego `docker compose down` (agrega `-v` si quieres borrar los datos).

---

## Jugar con tus compañeros (un servidor para todos)

1. Una persona levanta el servidor (Opción A o B) y averigua su IP local (`ipconfig` en Windows, `ip a` en Linux).
2. En su computadora debe permitir el puerto **3000** en el firewall.
3. Los demás abren el juego y, en la pantalla de inicio, cambian el campo de arriba a la izquierda por
   `http://IP_DE_TU_COMPAÑERO:3000` y pulsan Enter. Debe aparecer **SERVIDOR EN LINEA**.
4. Todos comparten cuentas, partidas, leaderboard y panel web.

El juego recuerda la dirección. También puede fijarse con la variable de entorno `ESCAPE_API_URL`.

---

## Problemas frecuentes
| Síntoma | Causa y solución |
|---|---|
| El servidor dice `No se pudo conectar con PostgreSQL: ECONNREFUSED` | PostgreSQL no está encendido. Windows: servicio *postgresql-x64-XX*. Linux: `sudo service postgresql start`. |
| `password authentication failed for user` | Usuario o contraseña distintos en `.env`. Revisa `DATABASE_URL`. |
| `database "escape_lab" does not exist` | Falta el paso 2 (`CREATE DATABASE`). |
| `permission denied for schema public` (PostgreSQL 15+) | Ejecuta como `postgres`: `ALTER DATABASE escape_lab OWNER TO escape_user;` y vuelve a arrancar. |
| `EADDRINUSE: address already in use :::3000` | Otro programa usa el puerto. Cambia `PORT` en `.env` y el campo de servidor del juego. |
| El juego muestra **SIN CONEXION** | El servidor no está corriendo o la dirección es otra. Abre http://localhost:3000 en el navegador para probar. |
| `Demasiados intentos` al iniciar sesión | Se bloquea 5 minutos tras 8 contraseñas incorrectas. Reinicia el servidor si necesitas desbloquear al instante. |
| El panel pide la clave otra vez | Es la de `ADMIN_PASSWORD`. Se guarda solo mientras la pestaña está abierta. |

---

## Subir el proyecto a GitHub (repositorio público)

1. En github.com pulsa **New repository**. Nombre: `escape-del-laboratorio`. Elige **Public**.
   No marques README, .gitignore ni licencia (el proyecto ya los trae).
2. En la carpeta raíz del proyecto:
```
git init
git add .
git commit -m "Escape del Laboratorio: juego, servidor y panel web"
git branch -M main
git remote add origin https://github.com/TU_USUARIO/escape-del-laboratorio.git
git push -u origin main
```
3. Revisa en GitHub que **no** aparezcan `server/.env` ni `node_modules/` (el `.gitignore` los excluye).
4. Para agregar compañeros: **Settings → Collaborators → Add people**.
5. Si el repositorio quedó privado: **Settings → General → Danger Zone → Change visibility → Public**.
6. El **link del repositorio público** es la URL `https://github.com/TU_USUARIO/escape-del-laboratorio`.
   Ábrela en una ventana de incógnito para comprobar que se ve sin iniciar sesión.

### Lista de verificación para la entrega
- [ ] El repositorio es público y abre en incógnito.
- [ ] El README explica cómo ejecutar el servidor, la base de datos y el juego.
- [ ] `server/db/schema.sql` está en el repositorio.
- [ ] No hay contraseñas reales en el repositorio (`.env` no se sube; `.env.example` solo trae valores de ejemplo).
- [ ] Capturas del leaderboard, del panel web y de las tablas en pgAdmin para el reporte.
