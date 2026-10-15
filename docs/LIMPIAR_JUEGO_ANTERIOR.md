# Limpiar el juego anterior (base de datos, carpetas y GitHub)

Usa esta guía si ya habías jugado o subido otra versión y quieres dejar **un solo videojuego**.

## 1. Borrar los datos del juego anterior en PostgreSQL

Abre pgAdmin → **escape_lab** → clic derecho → **Query Tool** y ejecuta **una** de estas opciones.

**Opción A: borrar partidas, eventos, coleccionables y progreso, pero conservar las cuentas**
```sql
TRUNCATE run_events, collectibles, runs, progress RESTART IDENTITY;
```

**Opción B: borrar todo, incluidas las cuentas de jugadores**
```sql
TRUNCATE users, auth_tokens, runs, run_events, collectibles, progress RESTART IDENTITY CASCADE;
```

**Opción C: borrar la base completa y crearla de nuevo**
1. Para el servidor (`Ctrl + C` en su terminal).
2. En pgAdmin: clic derecho en **escape_lab** → **Delete (Force)** → confirma.
3. Clic derecho en **Databases** → **Create** → **Database…** → nombre `escape_lab` → **Save**.
4. Arranca el servidor con `npm start`: crea las tablas solo.

Comprueba que quedó vacía: clic derecho en la tabla `runs` → **View/Edit Data → All Rows**.
Si borraste todo, el leaderboard del panel web aparecerá vacío.

## 2. Reemplazar el juego anterior en tu computadora
1. Cierra Godot y la terminal del servidor.
2. Descomprime este proyecto en una carpeta nueva, por ejemplo `Documentos\escape-del-laboratorio`.
3. Copia tu archivo `server\.env` de la carpeta vieja a `escape-del-laboratorio\server\`.
4. Borra la carpeta vieja del juego.
5. En Godot: **Importar** → `escape-del-laboratorio\game\project.godot`.

## 3. Conectar el juego con el servidor y la base actuales
1. Verifica que PostgreSQL esté encendido y que exista la base `escape_lab`.
2. En `server\.env` debe estar, con tu contraseña de `postgres`:
   ```
   PORT=3000
   DATABASE_URL=postgres://postgres:1234@localhost:5432/escape_lab
   ADMIN_PASSWORD=admin123
   ```
3. En una terminal dentro de `server`: `npm install` y `npm start`. Debe decir `Servidor listo en http://localhost:3000`.
4. Abre el juego con **F5**. Arriba a la izquierda debe decir **SERVIDOR EN LINEA**.
5. Registra una cuenta, juega y revisa los datos en pgAdmin (tabla `runs`) o en http://localhost:3000.

## 4. Quitar el juego anterior de GitHub
Entra a la carpeta de tu repositorio clonado y usa **una** de estas opciones.

**Opción A: reemplazar el contenido (conserva el historial)**
1. `git pull`
2. En el Explorador de archivos activa **Ver → Mostrar → Elementos ocultos**.
3. Borra **todo** lo que hay dentro de la carpeta del repositorio, **excepto la carpeta `.git`**.
4. Copia dentro el contenido de este proyecto (`game`, `server`, `docs`, `README.md`, `docker-compose.yml`,
   `.gitignore` y `.gitattributes`).
5. Sube los cambios; `git add -A` registra también los archivos borrados:
   ```
   git add -A
   git status
   git commit -m "Reemplaza el juego anterior por la version con base de datos"
   git push
   ```
6. Entra a tu repositorio en GitHub y comprueba que solo existan `game`, `server`, `docs` y los archivos de la raíz.

Si solo quieres quitar una carpeta concreta: `git rm -r NOMBRE_CARPETA`, luego `git commit -m "Elimina juego anterior"` y `git push`.

**Opción B: empezar de cero (borra también el historial)**
1. En GitHub: tu repositorio → **Settings → Danger Zone → Delete this repository**.
2. Crea un repositorio nuevo **Public** con el mismo nombre, sin README ni .gitignore.
3. En la carpeta de este proyecto:
   ```
   git init
   git add .
   git commit -m "Escape del Laboratorio con base de datos"
   git branch -M main
   git remote add origin https://github.com/TU_USUARIO/escape-del-laboratorio.git
   git push -u origin main
   ```

El historial de Git conserva las versiones borradas. Si necesitas que desaparezcan por completo, usa la Opción B.

## 5. Revisar antes de entregar
- [ ] El repositorio es **público** y abre en una ventana de incógnito.
- [ ] No aparece `server/.env` ni `node_modules` en GitHub.
- [ ] Hay un solo videojuego (`game/`).
- [ ] El README explica cómo ejecutar servidor, base de datos y juego.
- [ ] Capturas del leaderboard, del panel web y de las tablas en pgAdmin para el reporte.
