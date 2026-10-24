-- Esquema de Escape del Laboratorio (PostgreSQL 12 o superior)
-- Es idempotente: se puede ejecutar varias veces sin borrar datos.

CREATE TABLE IF NOT EXISTS users (
    id          SERIAL PRIMARY KEY,
    username    VARCHAR(16) NOT NULL,
    salt        TEXT NOT NULL,
    pass_hash   TEXT NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_login  TIMESTAMPTZ
);
CREATE UNIQUE INDEX IF NOT EXISTS users_username_lower ON users (lower(username));

CREATE TABLE IF NOT EXISTS auth_tokens (
    token_hash  CHAR(64) PRIMARY KEY,
    user_id     INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at  TIMESTAMPTZ NOT NULL
);
CREATE INDEX IF NOT EXISTS auth_tokens_user ON auth_tokens (user_id);

-- Una fila por partida (nueva o continuada)
CREATE TABLE IF NOT EXISTS runs (
    id              SERIAL PRIMARY KEY,
    user_id         INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    started_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    ended_at        TIMESTAMPTZ,
    continued       BOOLEAN NOT NULL DEFAULT false,
    status          TEXT NOT NULL DEFAULT 'in_progress'
                    CHECK (status IN ('in_progress', 'completed', 'abandoned')),
    play_time       REAL NOT NULL DEFAULT 0,
    level_reached   INT NOT NULL DEFAULT 1,
    ingredients     INT NOT NULL DEFAULT 0,
    coins           INT NOT NULL DEFAULT 0,
    parries         INT NOT NULL DEFAULT 0,
    deaths          INT NOT NULL DEFAULT 0,
    shots           INT NOT NULL DEFAULT 0,
    jumps           INT NOT NULL DEFAULT 0,
    dashes          INT NOT NULL DEFAULT 0,
    supers          INT NOT NULL DEFAULT 0,
    ultras          INT NOT NULL DEFAULT 0,
    damage_taken    INT NOT NULL DEFAULT 0,
    enemies_killed  INT NOT NULL DEFAULT 0,
    bosses_defeated INT NOT NULL DEFAULT 0,
    score           INT NOT NULL DEFAULT 0,
    best_streak     REAL NOT NULL DEFAULT 0,
    zones_cleared   INT NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS runs_user ON runs (user_id);
CREATE INDEX IF NOT EXISTS runs_status_time ON runs (status, play_time);

-- Bitácora de todo lo que hace el jugador
CREATE TABLE IF NOT EXISTS run_events (
    id          BIGSERIAL PRIMARY KEY,
    run_id      INT NOT NULL REFERENCES runs(id) ON DELETE CASCADE,
    user_id     INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    game_time   REAL NOT NULL,
    event_type  VARCHAR(40) NOT NULL,
    level       INT,
    data        JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS run_events_run ON run_events (run_id);
CREATE INDEX IF NOT EXISTS run_events_type ON run_events (event_type);
CREATE INDEX IF NOT EXISTS run_events_user ON run_events (user_id);

-- Coleccionables: ingredientes, monedas y curaciones recogidas
CREATE TABLE IF NOT EXISTS collectibles (
    id          BIGSERIAL PRIMARY KEY,
    run_id      INT NOT NULL REFERENCES runs(id) ON DELETE CASCADE,
    user_id     INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    kind        VARCHAR(20) NOT NULL,
    name        VARCHAR(60),
    level       INT,
    value       INT NOT NULL DEFAULT 1,
    game_time   REAL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS collectibles_run ON collectibles (run_id);
CREATE INDEX IF NOT EXISTS collectibles_user ON collectibles (user_id);

-- Partida guardada (una por jugador) para el botón CONTINUAR
CREATE TABLE IF NOT EXISTS progress (
    user_id     INT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    level_done  INT NOT NULL,
    ingredients TEXT NOT NULL,
    play_time   REAL NOT NULL,
    parries     INT NOT NULL,
    deaths      INT NOT NULL,
    coins       INT NOT NULL DEFAULT 0,
    score       INT NOT NULL DEFAULT 0,
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Trayectoria del jugador: una muestra cada ~0.5 s de juego (mapas de comportamiento).
-- Va en su propia tabla para no saturar la bitácora run_events.
CREATE TABLE IF NOT EXISTS run_positions (
    id          BIGSERIAL PRIMARY KEY,
    run_id      INT NOT NULL REFERENCES runs(id) ON DELETE CASCADE,
    user_id     INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    game_time   REAL NOT NULL,
    level       SMALLINT NOT NULL,
    phase       SMALLINT NOT NULL DEFAULT 0,   -- 0 = recorrido, 1 = pelea contra el jefe
    x           REAL NOT NULL,
    y           REAL NOT NULL,
    vx          REAL NOT NULL DEFAULT 0,
    vy          REAL NOT NULL DEFAULT 0,
    hp          SMALLINT NOT NULL,             -- vidas restantes en ese momento
    airborne    BOOLEAN NOT NULL DEFAULT false,
    dt          REAL NOT NULL DEFAULT 0.5,     -- segundos que representa la muestra
    shots       SMALLINT NOT NULL DEFAULT 0,   -- acciones desde la muestra anterior
    jumps       SMALLINT NOT NULL DEFAULT 0,
    dashes      SMALLINT NOT NULL DEFAULT 0,
    parries     SMALLINT NOT NULL DEFAULT 0,
    kills       SMALLINT NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS run_positions_run ON run_positions (run_id, game_time);
CREATE INDEX IF NOT EXISTS run_positions_level_hp ON run_positions (level, hp);
CREATE INDEX IF NOT EXISTS run_positions_user ON run_positions (user_id);
CREATE INDEX IF NOT EXISTS run_events_type_level ON run_events (event_type, level);

-- Actualización de bases creadas con una versión anterior del esquema
ALTER TABLE runs ADD COLUMN IF NOT EXISTS score INT NOT NULL DEFAULT 0;
ALTER TABLE runs ADD COLUMN IF NOT EXISTS best_streak REAL NOT NULL DEFAULT 0;
ALTER TABLE runs ADD COLUMN IF NOT EXISTS zones_cleared INT NOT NULL DEFAULT 0;
ALTER TABLE progress ADD COLUMN IF NOT EXISTS score INT NOT NULL DEFAULT 0;
CREATE INDEX IF NOT EXISTS runs_status_score ON runs (status, score DESC);

-- Repetición animada: posición y vida del jefe en cada muestra (nulo si no había jefe)
ALTER TABLE run_positions ADD COLUMN IF NOT EXISTS bx REAL;
ALTER TABLE run_positions ADD COLUMN IF NOT EXISTS "by" REAL;
ALTER TABLE run_positions ADD COLUMN IF NOT EXISTS bhp REAL;

-- Modo de juego de cada partida: 'story' (historia) o 'finaltop' (solo jefes, gana el menor tiempo)
ALTER TABLE runs ADD COLUMN IF NOT EXISTS mode TEXT NOT NULL DEFAULT 'story' CHECK (mode IN ('story', 'finaltop'));
CREATE INDEX IF NOT EXISTS runs_mode_status_time ON runs (mode, status, play_time);
