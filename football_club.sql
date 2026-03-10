-- ============================================================
-- football_club.sql — полный скрипт для создания и заполнения БД
-- Объединяет: coursework_db.sql + test_data.sql + все миграции
-- Версия: 3.0  |  Дата: 2026-03-01
-- ============================================================
-- Использование:
--   psql -U postgres -c "DROP DATABASE IF EXISTS football_club; CREATE DATABASE football_club;"
--   psql -U postgres -d football_club -f football_club.sql
-- ============================================================

SET client_encoding = 'UTF8';

-- ============================================================
-- 0. ОЧИСТКА
-- ============================================================

DROP TABLE IF EXISTS tournament_standings_manual CASCADE;
DROP TABLE IF EXISTS training_attendances     CASCADE;
DROP TABLE IF EXISTS trainings               CASCADE;
DROP TABLE IF EXISTS club_budget             CASCADE;
DROP TABLE IF EXISTS transfers               CASCADE;
DROP TABLE IF EXISTS coach_salary_payments   CASCADE;
DROP TABLE IF EXISTS player_salary_payments  CASCADE;
DROP TABLE IF EXISTS player_market_values    CASCADE;
DROP TABLE IF EXISTS match_substitutions     CASCADE;
DROP TABLE IF EXISTS match_cards             CASCADE;
DROP TABLE IF EXISTS match_goals             CASCADE;
DROP TABLE IF EXISTS match_lineups           CASCADE;
DROP TABLE IF EXISTS matches                 CASCADE;
DROP TABLE IF EXISTS player_status_log       CASCADE;
DROP TABLE IF EXISTS player_contracts        CASCADE;
DROP TABLE IF EXISTS players                 CASCADE;
DROP TABLE IF EXISTS coach_contracts         CASCADE;
DROP TABLE IF EXISTS coaches                 CASCADE;
DROP TABLE IF EXISTS persons                 CASCADE;
DROP TABLE IF EXISTS tournament_seasons      CASCADE;
DROP TABLE IF EXISTS tournaments             CASCADE;
DROP TABLE IF EXISTS seasons                 CASCADE;
DROP TABLE IF EXISTS users                   CASCADE;
DROP TABLE IF EXISTS agents                  CASCADE;
DROP TABLE IF EXISTS clubs                   CASCADE;
DROP TABLE IF EXISTS budget_categories       CASCADE;
DROP TABLE IF EXISTS positions               CASCADE;

DROP FUNCTION IF EXISTS trg_card_control() CASCADE;

DROP TYPE IF EXISTS user_role            CASCADE;
DROP TYPE IF EXISTS match_status         CASCADE;
DROP TYPE IF EXISTS coach_role           CASCADE;
DROP TYPE IF EXISTS player_status        CASCADE;
DROP TYPE IF EXISTS tournament_type      CASCADE;
DROP TYPE IF EXISTS dominant_foot        CASCADE;
DROP TYPE IF EXISTS budget_direction     CASCADE;
DROP TYPE IF EXISTS transfer_direction   CASCADE;
DROP TYPE IF EXISTS transfer_type        CASCADE;
DROP TYPE IF EXISTS training_type        CASCADE;
DROP TYPE IF EXISTS training_time_of_day CASCADE;
DROP TYPE IF EXISTS position_group       CASCADE;
DROP TYPE IF EXISTS card_type            CASCADE;


-- ============================================================
-- 1. ТИПЫ ENUM
-- ============================================================

CREATE TYPE user_role            AS ENUM('player', 'coach', 'finance', 'admin');
CREATE TYPE match_status         AS ENUM('planned', 'in_progress', 'finished');
CREATE TYPE coach_role           AS ENUM('head_coach', 'assistant', 'goalkeeper_coach', 'fitness_coach');
CREATE TYPE player_status        AS ENUM('active', 'suspended', 'injured');
CREATE TYPE tournament_type      AS ENUM('league', 'cup', 'friendly');
CREATE TYPE dominant_foot        AS ENUM('left', 'right', 'both');
CREATE TYPE budget_direction     AS ENUM('income', 'expense');
CREATE TYPE transfer_direction   AS ENUM('in', 'out');
CREATE TYPE transfer_type        AS ENUM('transfer', 'free', 'loan');
CREATE TYPE training_type        AS ENUM('physical', 'tactical', 'technical', 'match_practice', 'recovery');
CREATE TYPE training_time_of_day AS ENUM('morning', 'afternoon', 'evening');
CREATE TYPE position_group       AS ENUM('goalkeeper', 'defender', 'midfielder', 'forward');
CREATE TYPE card_type            AS ENUM('yellow', 'red');


-- ============================================================
-- 2. СПРАВОЧНЫЕ ТАБЛИЦЫ
-- ============================================================

CREATE TABLE positions (
    id              SERIAL         PRIMARY KEY,
    code            VARCHAR(10)    NOT NULL UNIQUE,
    full_name       VARCHAR(60)    NOT NULL,
    position_group  position_group NOT NULL
);

CREATE TABLE budget_categories (
    id                SERIAL           PRIMARY KEY,
    code              VARCHAR(30)      NOT NULL UNIQUE,
    name              VARCHAR(100)     NOT NULL,
    default_direction budget_direction
);


-- ============================================================
-- 3. ИНФРАСТРУКТУРНЫЕ ТАБЛИЦЫ
-- ============================================================

CREATE TABLE clubs (
    id            SERIAL       PRIMARY KEY,
    name          VARCHAR(100) NOT NULL UNIQUE,
    city          VARCHAR(100) NOT NULL,
    founded_year  INT          CHECK(founded_year BETWEEN 1800 AND EXTRACT(YEAR FROM CURRENT_DATE)),
    stadium_name  VARCHAR(100),
    logo_path     VARCHAR(255)
);

CREATE TABLE users (
    id             SERIAL       PRIMARY KEY,
    email          VARCHAR(150) NOT NULL UNIQUE,
    password_hash  TEXT         NOT NULL,
    role           user_role    NOT NULL,
    is_active      BOOLEAN      NOT NULL DEFAULT TRUE,
    last_login_at  TIMESTAMP,
    created_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE agents (
    id              SERIAL       PRIMARY KEY,
    company_name    VARCHAR(150) NOT NULL,
    contact_person  VARCHAR(150),
    email           VARCHAR(150),
    phone           VARCHAR(50)
);

CREATE TABLE seasons (
    id          SERIAL      PRIMARY KEY,
    name        VARCHAR(20) NOT NULL UNIQUE,
    start_date  DATE        NOT NULL,
    end_date    DATE        NOT NULL CHECK(end_date > start_date)
);

CREATE TABLE tournaments (
    id       SERIAL          PRIMARY KEY,
    name     VARCHAR(100)    NOT NULL,
    type     tournament_type NOT NULL,
    country  VARCHAR(50)
);

CREATE TABLE tournament_seasons (
    id             SERIAL PRIMARY KEY,
    tournament_id  INT    NOT NULL REFERENCES tournaments(id),
    season_id      INT    NOT NULL REFERENCES seasons(id),
    UNIQUE(tournament_id, season_id)
);


-- ============================================================
-- 4. ПЕРСОНАЛ
-- ============================================================

CREATE TABLE persons (
    id              SERIAL       PRIMARY KEY,
    first_name      VARCHAR(50)  NOT NULL,
    last_name       VARCHAR(50)  NOT NULL,
    middle_name     VARCHAR(50),
    birth_date      DATE         NOT NULL,
    place_of_birth  VARCHAR(100),
    nationality     VARCHAR(50)  NOT NULL,
    photo_path      VARCHAR(255),
    flag_path       VARCHAR(255),
    achievements    TEXT,
    agent_id        INT          REFERENCES agents(id)
);

CREATE TABLE players (
    id             SERIAL        PRIMARY KEY,
    person_id      INT           NOT NULL UNIQUE REFERENCES persons(id),
    user_id        INT           UNIQUE REFERENCES users(id),
    height_cm      INT           CHECK(height_cm BETWEEN 140 AND 220),
    dominant_foot  dominant_foot
);

CREATE TABLE player_contracts (
    id                     SERIAL        PRIMARY KEY,
    player_id              INT           NOT NULL REFERENCES players(id),
    club_id                INT           NOT NULL REFERENCES clubs(id),
    shirt_number           INT           NOT NULL CHECK(shirt_number BETWEEN 1 AND 99),
    main_position_id       INT           NOT NULL REFERENCES positions(id),
    secondary_position_id  INT           REFERENCES positions(id),
    join_date              DATE          NOT NULL,
    contract_end_date      DATE          NOT NULL CHECK(contract_end_date > join_date),
    salary                 NUMERIC(12,2) NOT NULL CHECK(salary >= 0),
    goal_bonus             NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK(goal_bonus >= 0),
    win_bonus              NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK(win_bonus >= 0),
    is_active              BOOLEAN       NOT NULL DEFAULT TRUE
);

CREATE UNIQUE INDEX uidx_player_active_contract
    ON player_contracts(player_id) WHERE is_active = TRUE;

CREATE UNIQUE INDEX uidx_active_shirt_per_club
    ON player_contracts(club_id, shirt_number) WHERE is_active = TRUE;

CREATE TABLE player_status_log (
    id                 SERIAL        PRIMARY KEY,
    player_id          INT           NOT NULL REFERENCES players(id),
    status             player_status NOT NULL,
    reason             TEXT,
    start_date         DATE          NOT NULL DEFAULT CURRENT_DATE,
    expected_end_date  DATE,
    actual_end_date    DATE,
    created_at         TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE coaches (
    id         SERIAL      PRIMARY KEY,
    person_id  INT         NOT NULL UNIQUE REFERENCES persons(id),
    user_id    INT         UNIQUE REFERENCES users(id),
    license    VARCHAR(50)
);

CREATE TABLE coach_contracts (
    id                 SERIAL        PRIMARY KEY,
    coach_id           INT           NOT NULL REFERENCES coaches(id),
    club_id            INT           NOT NULL REFERENCES clubs(id),
    role               coach_role    NOT NULL,
    join_date          DATE          NOT NULL,
    contract_end_date  DATE          NOT NULL CHECK(contract_end_date > join_date),
    salary             NUMERIC(12,2) NOT NULL CHECK(salary >= 0),
    is_active          BOOLEAN       NOT NULL DEFAULT TRUE
);

CREATE UNIQUE INDEX uidx_coach_active_contract
    ON coach_contracts(coach_id) WHERE is_active = TRUE;


-- ============================================================
-- 5. МАТЧИ (с расширенной статистикой)
-- ============================================================

CREATE TABLE matches (
    id                    SERIAL       PRIMARY KEY,
    home_club_id          INT          NOT NULL REFERENCES clubs(id),
    away_club_id          INT          NOT NULL REFERENCES clubs(id),
    tournament_season_id  INT          NOT NULL REFERENCES tournament_seasons(id),
    match_date            TIMESTAMP    NOT NULL,
    status                match_status NOT NULL DEFAULT 'planned',
    home_score            INT          DEFAULT 0 CHECK(home_score >= 0),
    away_score            INT          DEFAULT 0 CHECK(away_score >= 0),
    home_formation        VARCHAR(10),
    away_formation        VARCHAR(10),
    -- Расширенная статистика
    home_shots            INT          NOT NULL DEFAULT 0,
    away_shots            INT          NOT NULL DEFAULT 0,
    home_shots_on_target  INT          NOT NULL DEFAULT 0,
    away_shots_on_target  INT          NOT NULL DEFAULT 0,
    home_fouls            INT          NOT NULL DEFAULT 0,
    away_fouls            INT          NOT NULL DEFAULT 0,
    home_corners          INT          NOT NULL DEFAULT 0,
    away_corners          INT          NOT NULL DEFAULT 0,
    home_offsides         INT          NOT NULL DEFAULT 0,
    away_offsides         INT          NOT NULL DEFAULT 0,
    home_possession       INT          NOT NULL DEFAULT 50,
    away_possession       INT          NOT NULL DEFAULT 50,
    home_free_kicks       INT          NOT NULL DEFAULT 0,
    away_free_kicks       INT          NOT NULL DEFAULT 0,
    home_yellows          INT          NOT NULL DEFAULT 0,
    away_yellows          INT          NOT NULL DEFAULT 0,
    home_reds             INT          NOT NULL DEFAULT 0,
    away_reds             INT          NOT NULL DEFAULT 0,
    CHECK(home_club_id != away_club_id)
);

CREATE TABLE match_lineups (
    id              SERIAL  PRIMARY KEY,
    match_id        INT     NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
    player_id       INT     NOT NULL REFERENCES players(id),
    is_starting     BOOLEAN NOT NULL,
    minutes_played  INT     CHECK(minutes_played BETWEEN 0 AND 130),
    UNIQUE(match_id, player_id)
);

CREATE TABLE match_goals (
    id                SERIAL  PRIMARY KEY,
    match_id          INT     NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
    scorer_id         INT     REFERENCES players(id),
    assist_player_id  INT     REFERENCES players(id),
    minute            INT     NOT NULL CHECK(minute BETWEEN 0 AND 120),
    extra_minute      INT     NOT NULL DEFAULT 0 CHECK(extra_minute BETWEEN 0 AND 15),
    is_own_goal       BOOLEAN NOT NULL DEFAULT FALSE,
    description       TEXT
);

CREATE TABLE match_cards (
    id            SERIAL    PRIMARY KEY,
    match_id      INT       NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
    player_id     INT       REFERENCES players(id),
    coach_id      INT       REFERENCES coaches(id),
    card_type     card_type NOT NULL,
    minute        INT       NOT NULL CHECK(minute BETWEEN 0 AND 120),
    extra_minute  INT       NOT NULL DEFAULT 0 CHECK(extra_minute BETWEEN 0 AND 15),
    description   TEXT,
    CHECK (player_id IS NOT NULL OR coach_id IS NOT NULL)
);

CREATE TABLE match_substitutions (
    id             SERIAL PRIMARY KEY,
    match_id       INT    NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
    player_out_id  INT    NOT NULL REFERENCES players(id),
    player_in_id   INT    NOT NULL REFERENCES players(id),
    minute         INT    NOT NULL CHECK(minute BETWEEN 0 AND 120),
    extra_minute   INT    NOT NULL DEFAULT 0 CHECK(extra_minute BETWEEN 0 AND 15)
);


-- ============================================================
-- 6. СТАТИСТИКА И ФИНАНСЫ
-- ============================================================

CREATE TABLE player_market_values (
    id              SERIAL        PRIMARY KEY,
    player_id       INT           NOT NULL REFERENCES players(id),
    value_eur       NUMERIC(12,2) CHECK(value_eur >= 0),
    valuation_date  DATE          NOT NULL,
    UNIQUE(player_id, valuation_date)
);

CREATE TABLE player_salary_payments (
    id            SERIAL        PRIMARY KEY,
    player_id     INT           NOT NULL REFERENCES players(id),
    amount        NUMERIC(12,2) NOT NULL CHECK(amount > 0),
    payment_date  DATE          NOT NULL,
    season_id     INT           REFERENCES seasons(id)
);

CREATE TABLE coach_salary_payments (
    id            SERIAL        PRIMARY KEY,
    coach_id      INT           NOT NULL REFERENCES coaches(id),
    amount        NUMERIC(12,2) NOT NULL CHECK(amount > 0),
    payment_date  DATE          NOT NULL,
    season_id     INT           REFERENCES seasons(id)
);

CREATE TABLE transfers (
    id             SERIAL             PRIMARY KEY,
    player_id      INT                NOT NULL REFERENCES players(id),
    direction      transfer_direction NOT NULL,
    type           transfer_type      NOT NULL DEFAULT 'transfer',
    from_club_id   INT                REFERENCES clubs(id),
    to_club_id     INT                REFERENCES clubs(id),
    transfer_fee   NUMERIC(14,2)      NOT NULL CHECK(transfer_fee >= 0),
    transfer_date  DATE               NOT NULL,
    season_id      INT                REFERENCES seasons(id),
    notes          TEXT
);

CREATE TABLE club_budget (
    id              SERIAL           PRIMARY KEY,
    club_id         INT              NOT NULL REFERENCES clubs(id),
    season_id       INT              NOT NULL REFERENCES seasons(id),
    category_id     INT              NOT NULL REFERENCES budget_categories(id),
    direction       budget_direction NOT NULL,
    amount          NUMERIC(14,2)    NOT NULL CHECK(amount > 0),
    transfer_id     INT              REFERENCES transfers(id),
    description     TEXT,
    operation_date  DATE             NOT NULL,
    created_at      TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP
);


-- ============================================================
-- 7. ТРЕНИРОВКИ
-- ============================================================

CREATE TABLE trainings (
    id             SERIAL               PRIMARY KEY,
    club_id        INT                  NOT NULL REFERENCES clubs(id),
    coach_id       INT                  NOT NULL REFERENCES coaches(id),
    type           training_type        NOT NULL,
    time_of_day    training_time_of_day NOT NULL,
    training_date  DATE                 NOT NULL,
    start_time     TIME                 NOT NULL,
    end_time       TIME                 NOT NULL CHECK(end_time > start_time),
    description    TEXT,
    created_at     TIMESTAMP            NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE training_attendances (
    id           SERIAL  PRIMARY KEY,
    training_id  INT     NOT NULL REFERENCES trainings(id) ON DELETE CASCADE,
    player_id    INT     NOT NULL REFERENCES players(id),
    attended     BOOLEAN NOT NULL DEFAULT TRUE,
    notes        TEXT,
    UNIQUE(training_id, player_id)
);


-- ============================================================
-- 8. РУЧНАЯ ТУРНИРНАЯ ТАБЛИЦА
-- ============================================================

CREATE TABLE tournament_standings_manual (
    id                   SERIAL  PRIMARY KEY,
    tournament_season_id INTEGER NOT NULL,
    club_id              INTEGER NOT NULL,
    played               INTEGER NOT NULL DEFAULT 0,
    wins                 INTEGER NOT NULL DEFAULT 0,
    draws                INTEGER NOT NULL DEFAULT 0,
    losses               INTEGER NOT NULL DEFAULT 0,
    goals_for            INTEGER NOT NULL DEFAULT 0,
    goals_against        INTEGER NOT NULL DEFAULT 0,
    points               INTEGER NOT NULL DEFAULT 0,
    UNIQUE (tournament_season_id, club_id)
);


-- ============================================================
-- 9. ТРИГГЕР
-- ============================================================

CREATE OR REPLACE FUNCTION trg_card_control()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.card_type = 'red' AND NEW.player_id IS NOT NULL THEN
        INSERT INTO player_status_log (player_id, status, reason, start_date)
        VALUES (
            NEW.player_id,
            'suspended',
            'Red card in match #' || NEW.match_id,
            CURRENT_DATE
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER after_card_event
    AFTER INSERT ON match_cards
    FOR EACH ROW
    EXECUTE FUNCTION trg_card_control();


-- ============================================================
-- 10. ПРЕДСТАВЛЕНИЯ
-- ============================================================

CREATE VIEW player_current_status AS
SELECT
    p.id AS player_id,
    COALESCE(latest_log.status, 'active'::player_status) AS current_status
FROM players p
LEFT JOIN LATERAL (
    SELECT status
    FROM player_status_log psl
    WHERE psl.player_id = p.id
      AND psl.actual_end_date IS NULL
    ORDER BY psl.start_date DESC, psl.id DESC
    LIMIT 1
) latest_log ON TRUE;

CREATE VIEW player_current_contract AS
SELECT
    p.id                   AS player_id,
    per.first_name,
    per.last_name,
    per.middle_name,
    pc.club_id,
    pc.shirt_number,
    pos_m.code             AS main_position,
    pos_s.code             AS secondary_position,
    pc.join_date,
    pc.contract_end_date,
    pc.salary,
    pc.goal_bonus,
    pc.win_bonus
FROM players p
JOIN persons per          ON per.id = p.person_id
JOIN player_contracts pc  ON pc.player_id = p.id AND pc.is_active = TRUE
JOIN positions pos_m      ON pos_m.id = pc.main_position_id
LEFT JOIN positions pos_s ON pos_s.id = pc.secondary_position_id;

CREATE VIEW coach_current_contract AS
SELECT
    c.id           AS coach_id,
    per.first_name,
    per.last_name,
    per.middle_name,
    cc.club_id,
    cc.role,
    cc.join_date,
    cc.contract_end_date,
    cc.salary
FROM coaches c
JOIN persons per         ON per.id = c.person_id
JOIN coach_contracts cc  ON cc.coach_id = c.id AND cc.is_active = TRUE;

CREATE VIEW match_player_statistics AS
SELECT
    ml.match_id,
    ml.player_id,
    ml.minutes_played,
    COUNT(DISTINCT CASE WHEN mg.scorer_id = ml.player_id AND NOT COALESCE(mg.is_own_goal, FALSE) THEN mg.id END) AS goals,
    COUNT(DISTINCT CASE WHEN mg.assist_player_id = ml.player_id THEN mg.id END) AS assists,
    COUNT(DISTINCT CASE WHEN mc.card_type = 'yellow' THEN mc.id END)            AS yellow_cards,
    COUNT(DISTINCT CASE WHEN mc.card_type = 'red'    THEN mc.id END)            AS red_cards
FROM match_lineups ml
LEFT JOIN match_goals mg
    ON  mg.match_id = ml.match_id
    AND (mg.scorer_id = ml.player_id OR mg.assist_player_id = ml.player_id)
LEFT JOIN match_cards mc
    ON  mc.match_id = ml.match_id
    AND mc.player_id = ml.player_id
GROUP BY ml.match_id, ml.player_id, ml.minutes_played;

CREATE VIEW season_player_summary AS
SELECT
    ml.player_id,
    ts.season_id,
    COUNT(DISTINCT ml.match_id)                                                  AS matches_played,
    COALESCE(SUM(ml.minutes_played), 0)                                          AS total_minutes,
    COUNT(DISTINCT CASE WHEN mg.scorer_id = ml.player_id AND NOT COALESCE(mg.is_own_goal, FALSE) THEN mg.id END) AS goals,
    COUNT(DISTINCT CASE WHEN mg.assist_player_id = ml.player_id THEN mg.id END) AS assists,
    COUNT(DISTINCT CASE WHEN mc.card_type = 'yellow' THEN mc.id END)            AS yellow_cards,
    COUNT(DISTINCT CASE WHEN mc.card_type = 'red'    THEN mc.id END)            AS red_cards
FROM match_lineups ml
JOIN matches m             ON ml.match_id = m.id
JOIN tournament_seasons ts ON m.tournament_season_id = ts.id
LEFT JOIN match_goals mg
    ON  mg.match_id = ml.match_id
    AND (mg.scorer_id = ml.player_id OR mg.assist_player_id = ml.player_id)
LEFT JOIN match_cards mc
    ON  mc.match_id = ml.match_id
    AND mc.player_id = ml.player_id
GROUP BY ml.player_id, ts.season_id;

CREATE VIEW season_budget_summary AS
SELECT
    cb.club_id,
    cb.season_id,
    SUM(CASE WHEN cb.direction = 'income'  THEN cb.amount ELSE 0          END) AS total_income,
    SUM(CASE WHEN cb.direction = 'expense' THEN cb.amount ELSE 0          END) AS total_expense,
    SUM(CASE WHEN cb.direction = 'income'  THEN cb.amount ELSE -cb.amount END) AS net_balance
FROM club_budget cb
GROUP BY cb.club_id, cb.season_id;


-- ============================================================
-- ДАННЫЕ
-- ============================================================


-- 1. КЛУБЫ
INSERT INTO clubs (name, city, founded_year, stadium_name, logo_path) VALUES
('Локомотив Оскол',  'Старый Оскол', 2020, 'Арена Оскол',        'logo_oskol_loko_🚂.png'),
('Динамо Воронеж',   'Воронеж',      1935, 'Центральный стадион', 'Dinamo_Voronezh.png'),
('Спартак Тамбов',   'Тамбов',       1946, 'Спартак Арена',       'Spartak_Tambov.png'),
('Торпедо Курск',    'Курск',        1958, 'Трудовые резервы',    'Torpedo_Kursk.png'),
('Металлург Липецк', 'Липецк',       1960, 'Металлург',           'Metall_Lipetsk.png'),
('Энергия Белгород', 'Белгород',     1978, 'Салют',               'Energy_Belgorod.png'),
('Сокол Саратов',    'Саратов',      1943, 'Локомотив',           'Sokol_Saratov.png');


-- 2. ПОЛЬЗОВАТЕЛИ (пароль для всех: password, BCrypt cost=11)
INSERT INTO users (email, password_hash, role) VALUES
('alexey.batrakov@lokooskol.ru',        '$2a$11$g8ToR/qIB0T4ZSnDSGeNQuHlXRR89Nfau/uSjYuF9E3oKXjvdr4jC', 'player'),
('aleksandr.samarov@lokooskol.ru',      '$2a$11$g8ToR/qIB0T4ZSnDSGeNQuHlXRR89Nfau/uSjYuF9E3oKXjvdr4jC', 'player'),
('michael.melyokhin@lokooskol.ru',      '$2a$11$g8ToR/qIB0T4ZSnDSGeNQuHlXRR89Nfau/uSjYuF9E3oKXjvdr4jC', 'player'),
('michel.khesus@lokooskol.ru',          '$2a$11$g8ToR/qIB0T4ZSnDSGeNQuHlXRR89Nfau/uSjYuF9E3oKXjvdr4jC', 'player'),
('joe.lavamer@lokooskol.ru',            '$2a$11$g8ToR/qIB0T4ZSnDSGeNQuHlXRR89Nfau/uSjYuF9E3oKXjvdr4jC', 'player'),
('francesco.lauterali@lokooskol.ru',    '$2a$11$g8ToR/qIB0T4ZSnDSGeNQuHlXRR89Nfau/uSjYuF9E3oKXjvdr4jC', 'player'),
('yusuf-izi.monogramle@lokooskol.ru',   '$2a$11$g8ToR/qIB0T4ZSnDSGeNQuHlXRR89Nfau/uSjYuF9E3oKXjvdr4jC', 'player'),
('yakob.politsaevich@lokooskol.ru',     '$2a$11$g8ToR/qIB0T4ZSnDSGeNQuHlXRR89Nfau/uSjYuF9E3oKXjvdr4jC', 'player'),
('danil.kvantum@lokooskol.ru',          '$2a$11$g8ToR/qIB0T4ZSnDSGeNQuHlXRR89Nfau/uSjYuF9E3oKXjvdr4jC', 'player'),
('danil.karpin@lokooskol.ru',           '$2a$11$g8ToR/qIB0T4ZSnDSGeNQuHlXRR89Nfau/uSjYuF9E3oKXjvdr4jC', 'player'),
('dmitriy.balalai@lokooskol.ru',        '$2a$11$g8ToR/qIB0T4ZSnDSGeNQuHlXRR89Nfau/uSjYuF9E3oKXjvdr4jC', 'player'),
('vasiliy.memel-kositsin@lokooskol.ru', '$2a$11$g8ToR/qIB0T4ZSnDSGeNQuHlXRR89Nfau/uSjYuF9E3oKXjvdr4jC', 'player'),
('hose.kremiya-rus@lokooskol.ru',       '$2a$11$g8ToR/qIB0T4ZSnDSGeNQuHlXRR89Nfau/uSjYuF9E3oKXjvdr4jC', 'player'),
('roberto.durto@lokooskol.ru',          '$2a$11$g8ToR/qIB0T4ZSnDSGeNQuHlXRR89Nfau/uSjYuF9E3oKXjvdr4jC', 'player'),
('serd.krul-lurk@lokooskol.ru',         '$2a$11$g8ToR/qIB0T4ZSnDSGeNQuHlXRR89Nfau/uSjYuF9E3oKXjvdr4jC', 'player'),
('albert.parunashvili@lokooskol.ru',    '$2a$11$g8ToR/qIB0T4ZSnDSGeNQuHlXRR89Nfau/uSjYuF9E3oKXjvdr4jC', 'player'),
('trobert.pravandovskiy@lokooskol.ru',  '$2a$11$g8ToR/qIB0T4ZSnDSGeNQuHlXRR89Nfau/uSjYuF9E3oKXjvdr4jC', 'player'),
('yuriy.mashtakov@lokooskol.ru',        '$2a$11$g8ToR/qIB0T4ZSnDSGeNQuHlXRR89Nfau/uSjYuF9E3oKXjvdr4jC', 'player'),
('bartolomey.rabotnik@lokooskol.ru',    '$2a$11$g8ToR/qIB0T4ZSnDSGeNQuHlXRR89Nfau/uSjYuF9E3oKXjvdr4jC', 'player'),
('anatoliy.sledovatel@lokooskol.ru',    '$2a$11$g8ToR/qIB0T4ZSnDSGeNQuHlXRR89Nfau/uSjYuF9E3oKXjvdr4jC', 'player'),
('ivan.volkov@lokooskol.ru',            '$2a$11$g8ToR/qIB0T4ZSnDSGeNQuHlXRR89Nfau/uSjYuF9E3oKXjvdr4jC', 'player'),
('nikita.sergeev@lokooskol.ru',         '$2a$11$g8ToR/qIB0T4ZSnDSGeNQuHlXRR89Nfau/uSjYuF9E3oKXjvdr4jC', 'player'),
('omar.diallo@lokooskol.ru',            '$2a$11$g8ToR/qIB0T4ZSnDSGeNQuHlXRR89Nfau/uSjYuF9E3oKXjvdr4jC', 'player'),
('artem.kozlov@lokooskol.ru',           '$2a$11$g8ToR/qIB0T4ZSnDSGeNQuHlXRR89Nfau/uSjYuF9E3oKXjvdr4jC', 'player'),
('mateo.horvat@lokooskol.ru',           '$2a$11$g8ToR/qIB0T4ZSnDSGeNQuHlXRR89Nfau/uSjYuF9E3oKXjvdr4jC', 'player'),
('andrey.semyonov@lokooskol.ru',        '$2a$11$g8ToR/qIB0T4ZSnDSGeNQuHlXRR89Nfau/uSjYuF9E3oKXjvdr4jC', 'coach'),
('igor.petrov@lokooskol.ru',            '$2a$11$g8ToR/qIB0T4ZSnDSGeNQuHlXRR89Nfau/uSjYuF9E3oKXjvdr4jC', 'coach'),
('sergey.nikitin@lokooskol.ru',         '$2a$11$g8ToR/qIB0T4ZSnDSGeNQuHlXRR89Nfau/uSjYuF9E3oKXjvdr4jC', 'coach'),
('dmitriy.orlov@lokooskol.ru',          '$2a$11$g8ToR/qIB0T4ZSnDSGeNQuHlXRR89Nfau/uSjYuF9E3oKXjvdr4jC', 'coach'),
('viktor.zaytsev@lokooskol.ru',         '$2a$11$g8ToR/qIB0T4ZSnDSGeNQuHlXRR89Nfau/uSjYuF9E3oKXjvdr4jC', 'coach'),
('oleg.morozov@lokooskol.ru',           '$2a$11$g8ToR/qIB0T4ZSnDSGeNQuHlXRR89Nfau/uSjYuF9E3oKXjvdr4jC', 'coach'),
('aleksey.ivanov@lokooskol.ru',         '$2a$11$g8ToR/qIB0T4ZSnDSGeNQuHlXRR89Nfau/uSjYuF9E3oKXjvdr4jC', 'coach'),
('nikolay.fedorov@lokooskol.ru',        '$2a$11$g8ToR/qIB0T4ZSnDSGeNQuHlXRR89Nfau/uSjYuF9E3oKXjvdr4jC', 'coach'),
('vladimir.kuznetsov@lokooskol.ru',     '$2a$11$g8ToR/qIB0T4ZSnDSGeNQuHlXRR89Nfau/uSjYuF9E3oKXjvdr4jC', 'coach'),
('pavel.sokolov@lokooskol.ru',          '$2a$11$g8ToR/qIB0T4ZSnDSGeNQuHlXRR89Nfau/uSjYuF9E3oKXjvdr4jC', 'coach'),
('roman.lebedev@lokooskol.ru',          '$2a$11$g8ToR/qIB0T4ZSnDSGeNQuHlXRR89Nfau/uSjYuF9E3oKXjvdr4jC', 'coach'),
('maksim.novikov@lokooskol.ru',         '$2a$11$g8ToR/qIB0T4ZSnDSGeNQuHlXRR89Nfau/uSjYuF9E3oKXjvdr4jC', 'coach'),
('elena.smirnova@lokooskol.ru',         '$2a$11$g8ToR/qIB0T4ZSnDSGeNQuHlXRR89Nfau/uSjYuF9E3oKXjvdr4jC', 'finance'),
('marina.popova@lokooskol.ru',          '$2a$11$g8ToR/qIB0T4ZSnDSGeNQuHlXRR89Nfau/uSjYuF9E3oKXjvdr4jC', 'finance'),
('admin@lokooskol.ru',                  '$2a$11$g8ToR/qIB0T4ZSnDSGeNQuHlXRR89Nfau/uSjYuF9E3oKXjvdr4jC', 'admin');


-- 3. АГЕНТЫ
INSERT INTO agents (company_name, contact_person, email, phone) VALUES
('ProSport Agency',       'Михаил Громов',   'gromov@prosport.ru',   '+7-495-111-2233'),
('Global Football Group', 'James O''Brien',  'james@gfg-agency.com', '+44-20-7946-0958'),
('Estrella Sports',       'Carlos Mendez',   'carlos@estrella.es',   '+34-91-555-4321'),
('Eastern Europe Sports', 'Анна Коваль',     'koval@eesports.com',   '+380-44-123-4567'),
('Victory Management',    'Олег Тарасов',    'tarasov@victory-m.ru', '+7-495-999-8877');


-- 4. СЕЗОНЫ (сдвинуты на +1 год)
INSERT INTO seasons (name, start_date, end_date) VALUES
('2024/2025', '2024-07-01', '2025-06-30'),
('2025/2026', '2025-07-01', '2026-06-30');


-- 5. ТУРНИРЫ
INSERT INTO tournaments (name, type, country) VALUES
('Лига Черноземья',              'league',   'Россия'),
('Кубок Имени Андрея Аршавина',  'cup',      'Россия'),
('Товарищеский турнир',          'friendly',  NULL);


-- 6. СВЯЗЬ ТУРНИРОВ И СЕЗОНОВ
INSERT INTO tournament_seasons (tournament_id, season_id) VALUES
(1, 1),  -- Лига Черноземья 2024/2025        id=1
(1, 2),  -- Лига Черноземья 2025/2026        id=2
(2, 1),  -- Кубок Аршавина 2024/2025         id=3
(2, 2),  -- Кубок Аршавина 2025/2026         id=4
(3, 1),  -- Товарищеский 2024/2025           id=5
(3, 2);  -- Товарищеский 2025/2026           id=6


-- 7. ПОЗИЦИИ
INSERT INTO positions (code, full_name, position_group) VALUES
('ВРТ', 'Вратарь',                            'goalkeeper'),
('ПЗ',  'Правый защитник',                    'defender'),
('ЛЗ',  'Левый защитник',                     'defender'),
('ЦЗ',  'Центральный защитник',               'defender'),
('ПЦЗ', 'Правый центральный защитник',        'defender'),
('ЛЦЗ', 'Левый центральный защитник',         'defender'),
('ПФЗ', 'Правый фланговый защитник',          'defender'),
('ЛФЗ', 'Левый фланговый защитник',           'defender'),
('ЦОП', 'Центральный опорный полузащитник',   'midfielder'),
('ЦП',  'Центральный полузащитник',           'midfielder'),
('ЦАП', 'Центральный атакующий полузащитник', 'midfielder'),
('ПП',  'Правый полузащитник',                'midfielder'),
('ПАП', 'Правый атакующий полузащитник',      'midfielder'),
('ПФА', 'Правый фланговый атакующий',         'forward'),
('ЛФА', 'Левый фланговый атакующий',          'forward'),
('ФРВ', 'Форвард',                            'forward'),
('ЦФД', 'Центральный форвард',                'forward');


-- 8. КАТЕГОРИИ БЮДЖЕТА
INSERT INTO budget_categories (code, name, default_direction) VALUES
('salary',       'Зарплата',           'expense'),
('transfer_in',  'Трансфер (покупка)', 'expense'),
('transfer_out', 'Трансфер (продажа)', 'income'),
('bonus',        'Премиальные',        'expense'),
('sponsorship',  'Спонсорство',        'income'),
('ticket_sales', 'Продажа билетов',    'income'),
('merchandise',  'Атрибутика',         'income'),
('other',        'Прочее',              NULL);


-- 9. ПЕРСОНЫ (25 игроков + 12 тренеров)
INSERT INTO persons (first_name, last_name, middle_name, birth_date, place_of_birth, nationality, agent_id) VALUES
('Алексей',    'Батраков',        'Андреевич',    '2003-03-15', 'Москва',                        'Россия',      1),
('Александр',  'Самаров',         'Анатольевич',  '2002-08-22', 'Краснодар',                     'Россия',      1),
('Майкл',      'Мелёхин',         'Джонович',     '2001-11-03', 'Чикаго',                        'США',         2),
('Мишель',     'Хесус',           'Ахматович',    '2003-05-10', 'Барселона',                     'Испания',     3),
('Джо',        'Лавамер',          NULL,           '2004-01-28', 'Лион',                          'Франция',     2),
('Франческо',  'Лаутерали',        NULL,           '2003-09-14', 'Милан',                         'Италия',      3),
('Юсуф-Изи',  'Монограмле',       NULL,           '2002-04-05', 'Аккра',                         'Гана',        NULL),
('Якоб',       'Политсаевич',     'Альбертович',  '2004-07-19', 'Минск',                         'Беларусь',    4),
('Данил',      'Квантум',         'Олегович',     '2003-12-01', 'Санкт-Петербург',               'Россия',      NULL),
('Данил',      'Карпин',          'Валерьевич',   '2005-02-14', 'Сан-Паулу',                     'Бразилия',    2),
('Дмитрий',    'Балалай',         'Никитович',    '2002-06-30', 'Ростов-на-Дону',                'Россия',      1),
('Василий',    'Мемель-Косицин',  'Иванович',     '2003-10-08', 'Кишинёв',                       'Молдова',     4),
('Хосе',       'Кремия-Рус',       NULL,           '2004-03-22', 'Сан-Хосе',                      'Коста-Рика',  3),
('Роберто',    'Дурто',            NULL,           '2005-07-11', 'Лиссабон',                      'Португалия',  NULL),
('Серд',       'Крул-Лурк',        NULL,           '2001-01-17', 'Бухарест',                      'Румыния',     NULL),
('Альберт',    'Парунашвили',      NULL,           '2002-09-25', 'Вадуц',                         'Лихтенштейн', NULL),
('Троберт',    'Правандовский',    NULL,           '2003-04-03', 'Варшава',                       'Польша',      5),
('Юрий',       'Маштаков',        'Александрович','2002-12-10', 'Волгоград',                     'Россия',      NULL),
('Бартоломей', 'Работник',         NULL,           '2004-11-30', 'Сидней',                        'Австралия',   2),
('Анатолий',   'Следователь',     'Спартакович',  '2001-05-20', 'Ташкент',                       'Узбекистан',  NULL),
('Иван',       'Волков',          'Сергеевич',    '2003-02-18', 'Екатеринбург',                  'Россия',      NULL),
('Никита',     'Сергеев',         'Дмитриевич',   '2004-08-05', 'Нижний Новгород',               'Россия',      NULL),
('Омар',       'Диалло',           NULL,           '2002-07-14', 'Дакар',                         'Сенегал',     5),
('Артём',      'Козлов',          'Игоревич',     '2005-04-12', 'Казань',                        'Россия',      NULL),
('Матео',      'Хорват',           NULL,           '2004-10-20', 'Загреб',                        'Хорватия',    5),
('Андрей',     'Семёнов',         'Владимирович', '1975-03-10', 'Москва',        'Россия', NULL),
('Игорь',      'Петров',          'Николаевич',   '1980-07-22', 'Воронеж',       'Россия', NULL),
('Сергей',     'Никитин',         'Павлович',     '1982-11-15', 'Курск',         'Россия', NULL),
('Дмитрий',    'Орлов',           'Александрович','1978-04-05', 'Тула',          'Россия', NULL),
('Виктор',     'Зайцев',          'Михайлович',   '1985-09-18', 'Белгород',      'Россия', NULL),
('Олег',       'Морозов',         'Викторович',   '1983-01-25', 'Липецк',        'Россия', NULL),
('Алексей',    'Иванов',          'Петрович',     '1986-06-12', 'Рязань',        'Россия', NULL),
('Николай',    'Фёдоров',         'Андреевич',    '1981-10-08', 'Саратов',       'Россия', NULL),
('Владимир',   'Кузнецов',        'Олегович',     '1979-12-20', 'Тамбов',        'Россия', NULL),
('Павел',      'Соколов',         'Дмитриевич',   '1984-05-30', 'Пенза',         'Россия', NULL),
('Роман',      'Лебедев',         'Сергеевич',    '1987-08-14', 'Орёл',          'Россия', NULL),
('Максим',     'Новиков',         'Игоревич',     '1988-02-28', 'Старый Оскол',  'Россия', NULL);


-- 10. ИГРОКИ
INSERT INTO players (person_id, user_id, height_cm, dominant_foot) VALUES
( 1,  1, 182, 'right'), ( 2,  2, 186, 'right'), ( 3,  3, 181, 'right'),
( 4,  4, 175, 'left'),  ( 5,  5, 183, 'right'), ( 6,  6, 180, 'left'),
( 7,  7, 195, 'right'), ( 8,  8, 185, 'right'), ( 9,  9, 195, 'right'),
(10, 10, 180, 'left'),  (11, 11, 184, 'right'), (12, 12, 182, 'right'),
(13, 13, 176, 'right'), (14, 14, 170, 'left'),  (15, 15, 198, 'right'),
(16, 16, 190, 'right'), (17, 17, 186, 'right'), (18, 18, 183, 'right'),
(19, 19, 200, 'right'), (20, 20, 180, 'left'),  (21, 21, 192, 'right'),
(22, 22, 188, 'left'),  (23, 23, 191, 'right'), (24, 24, 178, 'right'),
(25, 25, 180, 'right');


-- 11. КОНТРАКТЫ ИГРОКОВ
-- Примечание: окончания контрактов сдвинуты +1 год для истёкших до 2026-03-01
INSERT INTO player_contracts
    (player_id, club_id, shirt_number, main_position_id, secondary_position_id,
     join_date, contract_end_date, salary, goal_bonus, win_bonus, is_active)
VALUES
( 1, 1,  10, 11, 10, '2022-07-01', '2027-06-30', 500000.00, 50000.00, 10000.00, TRUE),
( 2, 1,   9, 16, NULL,'2023-01-15', '2026-12-31', 280000.00, 40000.00, 10000.00, TRUE),
( 3, 1,   8, 10, NULL,'2023-07-01', '2026-06-30', 220000.00, 20000.00, 10000.00, TRUE),
( 4, 1,   6, 10, NULL,'2023-08-01', '2026-07-31', 240000.00, 20000.00, 10000.00, TRUE),
( 5, 1,   7, 14, 11, '2024-01-10', '2027-01-09', 260000.00, 35000.00, 10000.00, TRUE),
( 6, 1,  11, 15, 11, '2023-07-15', '2026-07-14', 250000.00, 35000.00, 10000.00, TRUE),
( 7, 1,   5,  9,  4, '2023-02-01', '2027-01-31', 200000.00, 10000.00, 10000.00, TRUE),  -- сдвинут с 2026-01-31
( 8, 1,  19, 16, 17, '2024-02-01', '2027-01-31', 180000.00, 35000.00, 10000.00, TRUE),
( 9, 1,   1,  1, NULL,'2022-07-01', '2026-06-30', 180000.00,     0.00, 10000.00, TRUE),
(10, 1,  77, 14, NULL,'2024-07-01', '2028-06-30', 200000.00, 30000.00, 10000.00, TRUE),
(11, 1,  14, 10, 11, '2023-01-20', '2027-01-19', 190000.00, 20000.00, 10000.00, TRUE),  -- сдвинут с 2026-01-19
(12, 1,  20, 10, 11, '2023-08-15', '2026-08-14', 170000.00, 20000.00, 10000.00, TRUE),
(13, 1,  22, 15, NULL,'2024-01-05', '2027-01-04', 160000.00, 30000.00, 10000.00, TRUE),
(14, 1,  17, 17, NULL,'2024-08-01', '2028-07-31', 190000.00, 40000.00, 10000.00, TRUE),
(15, 1,  13,  1, NULL,'2023-07-01', '2026-06-30', 120000.00,     0.00, 10000.00, TRUE),
(16, 1,   3,  4, NULL,'2023-02-10', '2027-02-09', 150000.00,  5000.00, 10000.00, TRUE),  -- сдвинут с 2026-02-09
(17, 1,  21, 17, NULL,'2024-01-15', '2027-01-14', 200000.00, 40000.00, 10000.00, TRUE),
(18, 1,   2,  2,  7, '2022-07-15', '2026-07-14', 150000.00,  5000.00, 10000.00, TRUE),
(19, 1,  99, 16, NULL,'2024-07-10', '2027-07-09', 140000.00, 30000.00, 10000.00, TRUE),
(20, 1,   4,  3,  8, '2022-08-01', '2026-07-31', 140000.00,  5000.00, 10000.00, TRUE),  -- сдвинут с 2025-07-31
(21, 1,  24,  4,  5, '2023-07-01', '2026-06-30', 140000.00,  5000.00, 10000.00, TRUE),
(22, 1,  15,  6,  4, '2024-01-20', '2027-01-19', 130000.00,  5000.00, 10000.00, TRUE),
(23, 1,  25,  5,  4, '2024-02-01', '2027-01-31', 160000.00,  5000.00, 10000.00, TRUE),
(24, 1,  16, 10,  9, '2024-07-01', '2028-06-30', 120000.00, 15000.00, 10000.00, TRUE),
(25, 1,  18, 12, 13, '2024-08-10', '2027-08-09', 150000.00, 15000.00, 10000.00, TRUE);


-- 12. ЛОГ СТАТУСОВ ИГРОКОВ (даты сдвинуты +1 год)
INSERT INTO player_status_log (player_id, status, reason, start_date, expected_end_date, actual_end_date) VALUES
(19, 'injured',   'Растяжение задней поверхности бедра', '2026-01-20', '2026-03-01', NULL),
(23, 'suspended', 'Red card in match #8',                 '2026-02-02', '2026-02-16', NULL);


-- 13. ТРЕНЕРЫ
INSERT INTO coaches (person_id, user_id, license) VALUES
(26, 26, 'UEFA Pro'),
(27, 27, 'UEFA A'),
(28, 28, 'UEFA A'),
(29, 29, 'UEFA B'),
(30, 30, 'UEFA B'),
(31, 31, 'ФИФА Фит'),
(32, 32, 'ФИФА Фит'),
(33, 33, 'UEFA A'),
(34, 34, 'UEFA B'),
(35, 35, 'UEFA B'),
(36, 36, 'UEFA B'),
(37, 37, 'UEFA B');


-- 14. КОНТРАКТЫ ТРЕНЕРОВ
-- Примечание: окончания контрактов сдвинуты +1 год для истёкших до 2026-03-01
INSERT INTO coach_contracts (coach_id, club_id, role, join_date, contract_end_date, salary, is_active) VALUES
( 1, 1, 'head_coach',       '2022-06-01', '2026-05-31', 200000.00, TRUE),
( 2, 1, 'assistant',        '2022-07-01', '2026-06-30', 100000.00, TRUE),
( 3, 1, 'assistant',        '2023-01-15', '2027-01-14',  90000.00, TRUE),  -- сдвинут с 2026-01-14
( 4, 1, 'goalkeeper_coach', '2022-07-01', '2026-06-30',  80000.00, TRUE),  -- сдвинут с 2025-06-30
( 5, 1, 'goalkeeper_coach', '2023-07-01', '2026-06-30',  75000.00, TRUE),
( 6, 1, 'fitness_coach',    '2022-08-01', '2026-07-31',  85000.00, TRUE),  -- сдвинут с 2025-07-31
( 7, 1, 'fitness_coach',    '2024-01-10', '2027-01-09',  70000.00, TRUE),
( 8, 1, 'assistant',        '2023-07-01', '2026-06-30',  85000.00, TRUE),
( 9, 1, 'assistant',        '2022-07-15', '2026-07-14',  80000.00, TRUE),  -- сдвинут с 2025-07-14
(10, 1, 'assistant',        '2024-02-01', '2027-01-31',  75000.00, TRUE),
(11, 1, 'assistant',        '2024-07-01', '2027-06-30',  70000.00, TRUE),
(12, 1, 'assistant',        '2024-07-01', '2027-06-30',  65000.00, TRUE);


-- 15. МАТЧИ (даты +1 год, расширенная статистика встроена)
-- Колонки: home_club_id, away_club_id, ts_id, match_date, status, h_sc, a_sc,
--          h_form, a_form, h_shots, a_shots, h_sot, a_sot, h_fouls, a_fouls,
--          h_corn, a_corn, h_off, a_off, h_poss, a_poss, h_fk, a_fk,
--          h_yel, a_yel, h_red, a_red
INSERT INTO matches
    (home_club_id, away_club_id, tournament_season_id, match_date, status,
     home_score, away_score, home_formation, away_formation,
     home_shots, away_shots, home_shots_on_target, away_shots_on_target,
     home_fouls, away_fouls, home_corners, away_corners,
     home_offsides, away_offsides, home_possession, away_possession,
     home_free_kicks, away_free_kicks, home_yellows, away_yellows,
     home_reds, away_reds)
VALUES
-- Матч 1: Оскол 3:1 Динамо (2025-08-03)
(1,2,2,'2025-08-03 18:00','finished',3,1,'4-3-3','4-4-2',
 14,8,7,3,12,15,6,3,2,4,58,42,15,12,1,3,0,0),
-- Матч 2: Спартак 0:2 Оскол (2025-08-17)
(3,1,2,'2025-08-17 16:00','finished',0,2,'4-4-2','4-3-3',
 9,16,3,8,18,10,4,7,3,1,40,60,18,10,3,1,0,0),
-- Матч 3: Оскол 2:2 Торпедо (2025-09-01)
(1,4,2,'2025-09-01 18:00','finished',2,2,'4-3-3','5-3-2',
 11,12,5,5,14,16,5,5,3,3,52,48,14,16,2,2,0,0),
-- Матч 4: Металлург 1:3 Оскол (2025-09-14)
(5,1,2,'2025-09-14 15:00','finished',1,3,'4-4-2','4-3-3',
 7,18,3,9,16,8,3,8,4,2,38,62,16,8,3,0,0,0),
-- Матч 5: Оскол 4:0 Энергия (2025-09-28)
(1,6,2,'2025-09-28 18:00','finished',4,0,'4-3-3','4-5-1',
 20,4,10,1,6,18,9,1,1,5,68,32,6,18,0,4,0,1),
-- Матч 6: Сокол 2:2 Оскол (2025-10-12)
(7,1,2,'2025-10-12 14:00','finished',2,2,'4-3-3','4-3-3',
 12,13,5,5,13,14,5,6,2,3,49,51,13,14,2,2,0,0),
-- Матч 7: Оскол 1:0 Спартак (2025-10-26)
(1,3,2,'2025-10-26 18:00','finished',1,0,'4-3-3','4-4-2',
 13,7,6,2,10,14,7,3,2,3,56,44,10,14,1,2,0,0),
-- Матч 8: Оскол 2:1 Сокол (2025-11-09)
(1,7,2,'2025-11-09 17:00','finished',2,1,'4-3-3','4-3-3',
 15,10,7,4,11,13,6,4,1,2,54,46,11,13,1,2,0,0),
-- Матч 9: Кубок, Оскол 3:2 Металлург (2025-10-02)
(1,5,4,'2025-10-02 19:00','finished',3,2,'4-3-3','4-4-2',
 16,14,8,6,12,11,7,5,2,3,55,45,12,11,1,1,0,0),
-- Матч 10: Кубок, Торпедо 1:2 Оскол (2025-11-20)
(4,1,4,'2025-11-20 18:00','finished',1,2,'5-3-2','4-3-3',
 10,15,4,7,17,9,4,6,5,2,42,58,17,9,3,1,1,0),
-- Матч 11: Оскол vs Динамо (план, 2026-03-01)
(1,2,2,'2026-03-01 18:00','planned',0,0,NULL,NULL,
 0,0,0,0,0,0,0,0,0,0,50,50,0,0,0,0,0,0),
-- Матч 12: Энергия vs Оскол (план, 2026-03-15)
(6,1,2,'2026-03-15 16:00','planned',0,0,NULL,NULL,
 0,0,0,0,0,0,0,0,0,0,50,50,0,0,0,0,0,0),
-- Матч 13: Оскол vs Торпедо (план, 2026-03-07)
(1,4,2,'2026-03-07 18:00','planned',0,0,NULL,NULL,
 0,0,0,0,0,0,0,0,0,0,50,50,0,0,0,0,0,0),
-- Матч 14: Динамо vs Оскол (план, 2026-03-21)
(2,1,2,'2026-03-21 16:00','planned',0,0,NULL,NULL,
 0,0,0,0,0,0,0,0,0,0,50,50,0,0,0,0,0,0),
-- Матч 15: Кубок, Оскол vs Металлург (план, 2026-03-28)
(1,5,4,'2026-03-28 19:00','planned',0,0,NULL,NULL,
 0,0,0,0,0,0,0,0,0,0,50,50,0,0,0,0,0,0);


-- 16. СОСТАВЫ НА МАТЧ

-- Матч 1: Оскол 3:1 Динамо
INSERT INTO match_lineups (match_id, player_id, is_starting, minutes_played) VALUES
(1, 9,TRUE,90),(1,18,TRUE,90),(1,21,TRUE,90),(1,16,TRUE,90),
(1,20,TRUE,90),(1, 7,TRUE,90),(1, 3,TRUE,78),(1, 1,TRUE,90),
(1, 5,TRUE,85),(1, 6,TRUE,72),(1, 2,TRUE,90),
(1,11,FALSE,18),(1,4,FALSE,12),(1,10,FALSE,5);

-- Матч 2: Спартак 0:2 Оскол
INSERT INTO match_lineups (match_id, player_id, is_starting, minutes_played) VALUES
(2, 9,TRUE,90),(2,18,TRUE,90),(2,21,TRUE,90),(2,16,TRUE,90),
(2,20,TRUE,90),(2, 7,TRUE,90),(2, 3,TRUE,82),(2, 1,TRUE,90),
(2, 5,TRUE,76),(2, 6,TRUE,90),(2, 2,TRUE,90),
(2, 4,FALSE,14),(2,11,FALSE,8);

-- Матч 3: Оскол 2:2 Торпедо
INSERT INTO match_lineups (match_id, player_id, is_starting, minutes_played) VALUES
(3, 9,TRUE,90),(3,18,TRUE,90),(3,21,TRUE,90),(3,16,TRUE,90),
(3,20,TRUE,80),(3, 7,TRUE,90),(3, 3,TRUE,70),(3, 1,TRUE,90),
(3, 5,TRUE,90),(3, 6,TRUE,65),(3, 2,TRUE,90),
(3, 4,FALSE,25),(3,11,FALSE,20),(3,8,FALSE,10);

-- Матч 4: Металлург 1:3 Оскол
INSERT INTO match_lineups (match_id, player_id, is_starting, minutes_played) VALUES
(4, 9,TRUE,90),(4,18,TRUE,90),(4,21,TRUE,90),(4,22,TRUE,90),
(4,20,TRUE,90),(4, 7,TRUE,90),(4, 4,TRUE,80),(4, 1,TRUE,90),
(4, 5,TRUE,75),(4, 6,TRUE,68),(4, 2,TRUE,90),
(4,11,FALSE,22),(4,10,FALSE,15),(4,12,FALSE,10);

-- Матч 5: Оскол 4:0 Энергия
INSERT INTO match_lineups (match_id, player_id, is_starting, minutes_played) VALUES
(5, 9,TRUE,90),(5,18,TRUE,90),(5,21,TRUE,90),(5,22,TRUE,90),
(5,20,TRUE,90),(5, 7,TRUE,90),(5,11,TRUE,75),(5, 1,TRUE,90),
(5, 5,TRUE,80),(5, 6,TRUE,68),(5,17,TRUE,90),
(5, 4,FALSE,22),(5,10,FALSE,15),(5,12,FALSE,10);

-- Матч 6: Сокол 2:2 Оскол
INSERT INTO match_lineups (match_id, player_id, is_starting, minutes_played) VALUES
(6, 9,TRUE,90),(6,18,TRUE,90),(6,16,TRUE,90),(6,23,TRUE,90),
(6,20,TRUE,90),(6, 7,TRUE,90),(6, 3,TRUE,78),(6, 1,TRUE,90),
(6, 5,TRUE,82),(6,13,TRUE,90),(6, 2,TRUE,90),
(6, 4,FALSE,12),(6,14,FALSE,8);

-- Матч 7: Оскол 1:0 Спартак
INSERT INTO match_lineups (match_id, player_id, is_starting, minutes_played) VALUES
(7, 9,TRUE,90),(7,18,TRUE,90),(7,21,TRUE,90),(7,16,TRUE,90),
(7,20,TRUE,90),(7, 7,TRUE,90),(7,11,TRUE,73),(7, 1,TRUE,90),
(7, 5,TRUE,85),(7, 6,TRUE,90),(7, 2,TRUE,90),
(7, 3,FALSE,17),(7,10,FALSE,5);

-- Матч 8: Оскол 2:1 Сокол
INSERT INTO match_lineups (match_id, player_id, is_starting, minutes_played) VALUES
(8, 9,TRUE,90),(8,18,TRUE,90),(8,16,TRUE,90),(8,23,TRUE,62),
(8,20,TRUE,90),(8, 7,TRUE,90),(8, 3,TRUE,90),(8, 1,TRUE,90),
(8, 5,TRUE,80),(8,13,TRUE,90),(8, 2,TRUE,85),
(8,24,FALSE,28),(8,14,FALSE,10),(8,8,FALSE,5);

-- Матч 9: Кубок, Оскол 3:2 Металлург
INSERT INTO match_lineups (match_id, player_id, is_starting, minutes_played) VALUES
(9,15,TRUE,90),(9,18,TRUE,90),(9,22,TRUE,90),(9,16,TRUE,90),
(9,20,TRUE,90),(9,24,TRUE,70),(9, 4,TRUE,90),(9, 1,TRUE,90),
(9,10,TRUE,75),(9,13,TRUE,80),(9, 8,TRUE,90),
(9,12,FALSE,20),(9,6,FALSE,15),(9,25,FALSE,10);

-- Матч 10: Кубок, Торпедо 1:2 Оскол
INSERT INTO match_lineups (match_id, player_id, is_starting, minutes_played) VALUES
(10,15,TRUE,90),(10,18,TRUE,90),(10,22,TRUE,90),(10,23,TRUE,90),
(10,20,TRUE,90),(10,24,TRUE,75),(10, 4,TRUE,90),(10, 1,TRUE,90),
(10,10,TRUE,80),(10,13,TRUE,68),(10, 8,TRUE,90),
(10,11,FALSE,22),(10,12,FALSE,15),(10,25,FALSE,10);


-- 17. ГОЛЫ

INSERT INTO match_goals (match_id, scorer_id, assist_player_id, minute, description) VALUES
-- Матч 1
(1,1,5,23,'Батраков забивает после паса Лавамера'),
(1,2,1,41,'Самаров замыкает подачу Батракова'),
(1,1,6,67,'Батраков забивает третий, подача Лаутерали'),
-- Матч 2
(2,2,1,34,'Самаров забивает, пас Батракова'),
(2,5,6,61,'Лавамер забивает второй, подача Лаутерали'),
-- Матч 3
(3,1,3,19,'Батраков открывает счёт, пас Мелёхина'),
(3,2,5,53,'Самаров забивает, подача Лавамера'),
-- Матч 4
(4,1,4,11,'Батраков забивает, пас Хесуса'),
(4,5,1,38,'Лавамер забивает второй, пас Батракова'),
(4,2,6,64,'Самаров забивает третий, подача Лаутерали'),
-- Матч 5
(5,1,11,12,'Батраков открывает счёт, пас Балалая'),
(5,17,1,28,'Правандовский забивает, навес Батракова'),
(5,5,6,52,'Лавамер забивает, пас Лаутерали'),
(5,1,7,74,'Батраков забивает четвёртый, длинный пас Монограмле'),
-- Матч 6
(6,1,5,27,'Батраков забивает, пас Лавамера'),
(6,2,13,73,'Самаров забивает, подача Кремия-Руса'),
-- Матч 7
(7,1,11,57,'Батраков забивает единственный гол, пас Балалая'),
-- Матч 8
(8,1,3,15,'Батраков забивает, пас Мелёхина'),
(8,2,1,71,'Самаров забивает, голевой пас Батракова'),
-- Матч 9
(9,8,4,18,'Политсаевич забивает, пас Хесуса'),
(9,1,10,33,'Батраков забивает, подача Карпина'),
(9,1,13,58,'Батраков забивает третий, пас Кремия-Руса'),
-- Матч 10
(10,1,4,22,'Батраков забивает, пас Хесуса'),
(10,8,1,55,'Политсаевич забивает второй, пас Батракова');


-- 18. КАРТОЧКИ

INSERT INTO match_cards (match_id, player_id, card_type, minute, description) VALUES
(1, 6,'yellow',55,'Лаутерали — фол в середине поля'),
(3,18,'yellow',44,'Маштаков — грубый фол'),
(4,22,'yellow',56,'Сергеев — нарушение'),
(6, 7,'yellow',50,'Монограмле — симуляция'),
(7,20,'yellow',32,'Следователь — удар по мячу рукой'),
(8,23,'yellow',38,'Диалло — первая жёлтая, грубый фол'),
(8,23,'red',   62,'Диалло — вторая жёлтая, удаление'),
(9,16,'yellow',45,'Парунашвили — нарушение перед перерывом'),
(9,18,'yellow',88,'Маштаков — жёлтая в конце матча'),
(10,23,'yellow',85,'Диалло — жёлтая на последних минутах');


-- 19. ЗАМЕНЫ

INSERT INTO match_substitutions (match_id, player_out_id, player_in_id, minute) VALUES
(1, 6,11,72),(1, 3, 4,78),(1, 5,10,85),
(2, 5, 4,76),(2, 3,11,82),
(3, 6, 4,65),(3, 3,11,70),(3,20, 8,80),
(4, 6,11,68),(4, 5,10,75),(4, 4,12,80),
(5, 6, 4,68),(5,11,10,75),(5, 5,12,80),
(6, 3, 4,78),(6, 5,14,82),
(7,11, 3,73),(7, 5,10,85),
(8,23,24,62),(8, 5,14,80),(8, 2, 8,85),
(9,24,12,70),(9,10, 6,75),(9,13,25,80),
(10,13,11,68),(10,24,12,75),(10,10,25,80);


-- 20. РЫНОЧНАЯ СТОИМОСТЬ ИГРОКОВ (даты сдвинуты +1 год)

INSERT INTO player_market_values (player_id, value_eur, valuation_date) VALUES
-- 01.01.2025
( 1,12000000.00,'2025-01-01'),( 2, 5000000.00,'2025-01-01'),
( 3, 4000000.00,'2025-01-01'),( 4, 4500000.00,'2025-01-01'),
( 5, 5500000.00,'2025-01-01'),( 6, 5000000.00,'2025-01-01'),
( 7, 3500000.00,'2025-01-01'),( 8, 2500000.00,'2025-01-01'),
( 9, 3000000.00,'2025-01-01'),(10, 3000000.00,'2025-01-01'),
(11, 2800000.00,'2025-01-01'),(12, 2000000.00,'2025-01-01'),
(13, 1800000.00,'2025-01-01'),(14, 2200000.00,'2025-01-01'),
(15, 1500000.00,'2025-01-01'),(16, 2000000.00,'2025-01-01'),
(17, 3000000.00,'2025-01-01'),(18, 1800000.00,'2025-01-01'),
(19, 1500000.00,'2025-01-01'),(20, 1600000.00,'2025-01-01'),
(21, 1800000.00,'2025-01-01'),(22, 1200000.00,'2025-01-01'),
(23, 2200000.00,'2025-01-01'),(24,  800000.00,'2025-01-01'),
(25, 1000000.00,'2025-01-01'),
-- 01.01.2026
( 1,15000000.00,'2026-01-01'),( 2, 6000000.00,'2026-01-01'),
( 3, 4500000.00,'2026-01-01'),( 4, 5000000.00,'2026-01-01'),
( 5, 6500000.00,'2026-01-01'),( 6, 5500000.00,'2026-01-01'),
( 7, 4000000.00,'2026-01-01'),( 8, 3200000.00,'2026-01-01'),
( 9, 3500000.00,'2026-01-01'),(10, 3800000.00,'2026-01-01'),
(11, 3200000.00,'2026-01-01'),(12, 2500000.00,'2026-01-01'),
(13, 2200000.00,'2026-01-01'),(14, 3000000.00,'2026-01-01'),
(15, 1600000.00,'2026-01-01'),(16, 2200000.00,'2026-01-01'),
(17, 3800000.00,'2026-01-01'),(18, 2000000.00,'2026-01-01'),
(19, 1800000.00,'2026-01-01'),(20, 1700000.00,'2026-01-01'),
(21, 2200000.00,'2026-01-01'),(22, 1800000.00,'2026-01-01'),
(23, 2500000.00,'2026-01-01'),(24, 1200000.00,'2026-01-01'),
(25, 1500000.00,'2026-01-01');


-- 21. ВЫПЛАТЫ ЗАРПЛАТ — ИГРОКИ (даты сдвинуты +1 год)

INSERT INTO player_salary_payments (player_id, amount, payment_date, season_id) VALUES
-- Октябрь 2025
( 1,500000.00,'2025-10-05',2),( 2,280000.00,'2025-10-05',2),
( 3,220000.00,'2025-10-05',2),( 4,240000.00,'2025-10-05',2),
( 5,260000.00,'2025-10-05',2),( 6,250000.00,'2025-10-05',2),
( 7,200000.00,'2025-10-05',2),( 8,180000.00,'2025-10-05',2),
( 9,180000.00,'2025-10-05',2),(10,200000.00,'2025-10-05',2),
(11,190000.00,'2025-10-05',2),(12,170000.00,'2025-10-05',2),
(13,160000.00,'2025-10-05',2),(14,190000.00,'2025-10-05',2),
(15,120000.00,'2025-10-05',2),(16,150000.00,'2025-10-05',2),
(17,200000.00,'2025-10-05',2),(18,150000.00,'2025-10-05',2),
(19,140000.00,'2025-10-05',2),(20,140000.00,'2025-10-05',2),
(21,140000.00,'2025-10-05',2),(22,130000.00,'2025-10-05',2),
(23,160000.00,'2025-10-05',2),(24,120000.00,'2025-10-05',2),
(25,150000.00,'2025-10-05',2),
-- Ноябрь 2025
( 1,500000.00,'2025-11-05',2),( 2,280000.00,'2025-11-05',2),
( 3,220000.00,'2025-11-05',2),( 4,240000.00,'2025-11-05',2),
( 5,260000.00,'2025-11-05',2),( 6,250000.00,'2025-11-05',2),
( 7,200000.00,'2025-11-05',2),( 8,180000.00,'2025-11-05',2),
( 9,180000.00,'2025-11-05',2),(10,200000.00,'2025-11-05',2),
(11,190000.00,'2025-11-05',2),(12,170000.00,'2025-11-05',2),
(13,160000.00,'2025-11-05',2),(14,190000.00,'2025-11-05',2),
(15,120000.00,'2025-11-05',2),(16,150000.00,'2025-11-05',2),
(17,200000.00,'2025-11-05',2),(18,150000.00,'2025-11-05',2),
(19,140000.00,'2025-11-05',2),(20,140000.00,'2025-11-05',2),
(21,140000.00,'2025-11-05',2),(22,130000.00,'2025-11-05',2),
(23,160000.00,'2025-11-05',2),(24,120000.00,'2025-11-05',2),
(25,150000.00,'2025-11-05',2),
-- Декабрь 2025
( 1,500000.00,'2025-12-05',2),( 2,280000.00,'2025-12-05',2),
( 3,220000.00,'2025-12-05',2),( 4,240000.00,'2025-12-05',2),
( 5,260000.00,'2025-12-05',2),( 6,250000.00,'2025-12-05',2),
( 7,200000.00,'2025-12-05',2),( 8,180000.00,'2025-12-05',2),
( 9,180000.00,'2025-12-05',2),(10,200000.00,'2025-12-05',2),
(11,190000.00,'2025-12-05',2),(12,170000.00,'2025-12-05',2),
(13,160000.00,'2025-12-05',2),(14,190000.00,'2025-12-05',2),
(15,120000.00,'2025-12-05',2),(16,150000.00,'2025-12-05',2),
(17,200000.00,'2025-12-05',2),(18,150000.00,'2025-12-05',2),
(19,140000.00,'2025-12-05',2),(20,140000.00,'2025-12-05',2),
(21,140000.00,'2025-12-05',2),(22,130000.00,'2025-12-05',2),
(23,160000.00,'2025-12-05',2),(24,120000.00,'2025-12-05',2),
(25,150000.00,'2025-12-05',2);


-- 22. ВЫПЛАТЫ ЗАРПЛАТ — ТРЕНЕРЫ (даты сдвинуты +1 год)

INSERT INTO coach_salary_payments (coach_id, amount, payment_date, season_id) VALUES
-- Октябрь 2025
( 1,200000.00,'2025-10-05',2),( 2,100000.00,'2025-10-05',2),
( 3, 90000.00,'2025-10-05',2),( 4, 80000.00,'2025-10-05',2),
( 5, 75000.00,'2025-10-05',2),( 6, 85000.00,'2025-10-05',2),
( 7, 70000.00,'2025-10-05',2),( 8, 85000.00,'2025-10-05',2),
( 9, 80000.00,'2025-10-05',2),(10, 75000.00,'2025-10-05',2),
(11, 70000.00,'2025-10-05',2),(12, 65000.00,'2025-10-05',2),
-- Ноябрь 2025
( 1,200000.00,'2025-11-05',2),( 2,100000.00,'2025-11-05',2),
( 3, 90000.00,'2025-11-05',2),( 4, 80000.00,'2025-11-05',2),
( 5, 75000.00,'2025-11-05',2),( 6, 85000.00,'2025-11-05',2),
( 7, 70000.00,'2025-11-05',2),( 8, 85000.00,'2025-11-05',2),
( 9, 80000.00,'2025-11-05',2),(10, 75000.00,'2025-11-05',2),
(11, 70000.00,'2025-11-05',2),(12, 65000.00,'2025-11-05',2),
-- Декабрь 2025
( 1,200000.00,'2025-12-05',2),( 2,100000.00,'2025-12-05',2),
( 3, 90000.00,'2025-12-05',2),( 4, 80000.00,'2025-12-05',2),
( 5, 75000.00,'2025-12-05',2),( 6, 85000.00,'2025-12-05',2),
( 7, 70000.00,'2025-12-05',2),( 8, 85000.00,'2025-12-05',2),
( 9, 80000.00,'2025-12-05',2),(10, 75000.00,'2025-12-05',2),
(11, 70000.00,'2025-12-05',2),(12, 65000.00,'2025-12-05',2);


-- 23. ТРАНСФЕРЫ (даты сдвинуты +1 год)

INSERT INTO transfers (player_id, direction, type, from_club_id, to_club_id, transfer_fee, transfer_date, season_id, notes) VALUES
(10,'in', 'transfer',NULL,1,2500000.00,'2025-07-01',2,'Покупка Карпина из бразильского клуба'),
(14,'in', 'free',    NULL,1,      0.00,'2025-08-01',2,'Дурто пришёл как свободный агент'),
(25,'in', 'transfer',NULL,1, 800000.00,'2025-08-10',2,'Покупка Хорвата из хорватского клуба'),
(19,'out','loan',      1, 3,      0.00,'2026-01-25',2,'Работник уходит в аренду в Спартак Тамбов');


-- 24. БЮДЖЕТ КЛУБА (даты сдвинуты +1 год)

INSERT INTO club_budget (club_id, season_id, category_id, direction, amount, transfer_id, description, operation_date) VALUES
(1,2,5,'income', 50000000.00,NULL,'Генеральный спонсор — сезон 2025/2026',      '2025-07-01'),
(1,2,5,'income', 15000000.00,NULL,'Технический спонсор — экипировка',            '2025-07-01'),
(1,2,6,'income',  8000000.00,NULL,'Доход от продажи билетов (август–декабрь)',   '2025-12-31'),
(1,2,7,'income',  3500000.00,NULL,'Продажа атрибутики за полугодие',             '2025-12-31'),
(1,2,8,'income',  2000000.00,NULL,'Призовые за Кубок — проход в 1/4 финала',    '2025-11-25'),
(1,2,2,'expense', 2500000.00,1,   'Покупка Карпина',                             '2025-07-01'),
(1,2,2,'expense',  800000.00,3,   'Покупка Хорвата',                             '2025-08-10'),
(1,2,1,'expense', 5770000.00,NULL,'Фонд зарплат — октябрь 2025',                '2025-10-05'),
(1,2,1,'expense', 5770000.00,NULL,'Фонд зарплат — ноябрь 2025',                 '2025-11-05'),
(1,2,1,'expense', 5770000.00,NULL,'Фонд зарплат — декабрь 2025',                '2025-12-05'),
(1,2,4,'expense',  500000.00,NULL,'Премии за победу — матч vs Динамо',          '2025-08-05'),
(1,2,4,'expense',  500000.00,NULL,'Премии за победу — Спартак (выезд)',          '2025-08-19'),
(1,2,4,'expense',  500000.00,NULL,'Премии за победу — матч vs Энергия',         '2025-09-30'),
(1,2,4,'expense',  500000.00,NULL,'Премии за победу — Кубок vs Металлург',      '2025-10-04'),
(1,2,4,'expense',  500000.00,NULL,'Премии за победу — матч vs Спартак (дома)',  '2025-10-28'),
(1,2,4,'expense',  500000.00,NULL,'Премии за победу — матч vs Сокол (дома)',    '2025-11-11'),
(1,2,4,'expense',  500000.00,NULL,'Премии за победу — Кубок vs Торпедо',        '2025-11-22'),
(1,2,8,'expense', 1200000.00,NULL,'Аренда тренировочной базы (полугодие)',       '2025-07-01'),
(1,2,8,'expense',  800000.00,NULL,'Медицинское обеспечение (полугодие)',         '2025-07-01');


-- 25. ТРЕНИРОВКИ (даты сдвинуты +1 год: Feb 2025 → Feb 2026)

INSERT INTO trainings (club_id, coach_id, type, time_of_day, training_date, start_time, end_time, description) VALUES
(1, 1,'tactical',      'morning',  '2026-02-17','10:00','12:00','Тактическая подготовка: отработка схемы 4-3-3'),
(1, 6,'physical',      'afternoon','2026-02-17','15:00','16:30','Силовая тренировка в зале'),
(1, 2,'technical',     'morning',  '2026-02-18','10:00','11:30','Работа с мячом: короткие передачи и контроль'),
(1, 7,'physical',      'afternoon','2026-02-18','15:00','16:30','Беговая работа: интервальный бег'),
(1, 1,'match_practice','morning',  '2026-02-19','10:00','12:00','Двусторонняя игра: основной состав vs резерв'),
(1, 6,'recovery',      'afternoon','2026-02-20','14:00','15:30','Восстановительная тренировка: растяжка и бассейн'),
(1, 3,'tactical',      'morning',  '2026-02-21','10:00','11:30','Розыгрыш стандартов: угловые и штрафные'),
(1, 1,'tactical',      'morning',  '2026-02-22','10:00','12:00','Предматчевая тактическая установка'),
(1, 4,'technical',     'morning',  '2026-02-24','10:00','11:30','Тренировка вратарей: работа на линии'),
(1, 6,'physical',      'afternoon','2026-02-24','15:00','16:30','Функциональная тренировка: взрывная сила'),
(1, 2,'technical',     'morning',  '2026-02-25','10:00','11:30','Отработка завершающего удара'),
(1, 1,'match_practice','morning',  '2026-02-26','10:00','12:00','Тренировочный матч: моделирование игры с Динамо'),
(1, 7,'recovery',      'afternoon','2026-02-27','14:00','15:30','Лёгкая восстановительная тренировка'),
(1, 1,'tactical',      'morning',  '2026-02-28','10:00','12:00','Предматчевая тактическая установка на Динамо'),
(1, 5,'technical',     'evening',  '2026-02-28','18:00','19:30','Индивидуальная работа вратарей: игра ногами');


-- 26. ПОСЕЩАЕМОСТЬ ТРЕНИРОВОК

-- Тренировка 1 (тактика, 2026-02-17)
INSERT INTO training_attendances (training_id, player_id, attended, notes) VALUES
(1, 1,TRUE,NULL),(1, 2,TRUE,NULL),(1, 3,TRUE,NULL),(1, 4,TRUE,NULL),(1, 5,TRUE,NULL),
(1, 6,TRUE,NULL),(1, 7,TRUE,NULL),(1, 8,TRUE,NULL),(1, 9,TRUE,NULL),(1,10,TRUE,NULL),
(1,11,TRUE,NULL),(1,12,TRUE,NULL),(1,13,TRUE,NULL),(1,14,TRUE,NULL),(1,15,TRUE,NULL),
(1,16,TRUE,NULL),(1,17,TRUE,NULL),(1,18,TRUE,NULL),
(1,19,FALSE,'Травма: растяжение задней поверхности бедра'),
(1,20,TRUE,NULL),(1,21,TRUE,NULL),(1,22,TRUE,NULL),
(1,23,TRUE,'Дисквалификация снята 16.02.2026'),
(1,24,TRUE,NULL),(1,25,TRUE,NULL);

-- Тренировки 2–15: все игроки, игрок 19 отсутствует на тренировках 2–8 (травма)
DO $$
DECLARE
    t_id INT;
    p_id INT;
BEGIN
    FOR t_id IN 2..15 LOOP
        FOR p_id IN 1..25 LOOP
            IF p_id = 19 AND t_id <= 8 THEN
                INSERT INTO training_attendances (training_id, player_id, attended, notes)
                VALUES (t_id, p_id, FALSE, 'Травма')
                ON CONFLICT DO NOTHING;
            ELSE
                INSERT INTO training_attendances (training_id, player_id, attended, notes)
                VALUES (t_id, p_id, TRUE, NULL)
                ON CONFLICT DO NOTHING;
            END IF;
        END LOOP;
    END LOOP;
END $$;


-- ============================================================
-- НОРМАЛИЗАЦИЯ СТАТИСТИКИ (из migration_normalize_stats.sql)
-- ============================================================

-- Добавить запасного вратаря (player 15) в матчи 1-8 (не стартовал, 0 минут)
INSERT INTO match_lineups (match_id, player_id, is_starting, minutes_played)
VALUES (1,15,FALSE,0),(2,15,FALSE,0),(3,15,FALSE,0),(4,15,FALSE,0),
       (5,15,FALSE,0),(6,15,FALSE,0),(7,15,FALSE,0),(8,15,FALSE,0)
ON CONFLICT (match_id, player_id) DO UPDATE SET minutes_played = EXCLUDED.minutes_played;

-- Добавить запасного вратаря (player 9) в матчи 9-10 (не стартовал, 0 минут)
INSERT INTO match_lineups (match_id, player_id, is_starting, minutes_played)
VALUES (9,9,FALSE,0),(10,9,FALSE,0)
ON CONFLICT (match_id, player_id) DO UPDATE SET minutes_played = EXCLUDED.minutes_played;

-- Дурто (id=14) — замена в матчах 1, 3, 6
INSERT INTO match_lineups (match_id, player_id, is_starting, minutes_played)
VALUES (1,14,FALSE,12),(3,14,FALSE,20),(6,14,FALSE,10)
ON CONFLICT (match_id, player_id) DO UPDATE SET minutes_played = EXCLUDED.minutes_played;

-- Козлов (id=24) — замена в матчах 2, 4
INSERT INTO match_lineups (match_id, player_id, is_starting, minutes_played)
VALUES (2,24,FALSE,8),(4,24,FALSE,10)
ON CONFLICT (match_id, player_id) DO UPDATE SET minutes_played = EXCLUDED.minutes_played;

-- Мемель-Косицин (id=12) — замена в матчах 3, 5
INSERT INTO match_lineups (match_id, player_id, is_starting, minutes_played)
VALUES (3,12,FALSE,25),(5,12,FALSE,15)
ON CONFLICT (match_id, player_id) DO UPDATE SET minutes_played = EXCLUDED.minutes_played;

-- Карпин (id=10) — замена в матчах 1, 6, 7
INSERT INTO match_lineups (match_id, player_id, is_starting, minutes_played)
VALUES (1,10,FALSE,5),(6,10,FALSE,8),(7,10,FALSE,17)
ON CONFLICT (match_id, player_id) DO UPDATE SET minutes_played = EXCLUDED.minutes_played;

-- Скорректировать минуты Батракова (id=1)
UPDATE match_lineups SET minutes_played = 75 WHERE match_id = 3  AND player_id = 1;
UPDATE match_lineups SET minutes_played = 80 WHERE match_id = 6  AND player_id = 1;
UPDATE match_lineups SET minutes_played = 70 WHERE match_id = 10 AND player_id = 1;

-- Скорректировать минуты Маштакова (id=18)
UPDATE match_lineups SET minutes_played = 65 WHERE match_id = 4  AND player_id = 18;
UPDATE match_lineups SET minutes_played = 72 WHERE match_id = 8  AND player_id = 18;

-- Скорректировать минуты Следователя (id=20)
UPDATE match_lineups SET minutes_played = 78 WHERE match_id = 5  AND player_id = 20;
UPDATE match_lineups SET minutes_played = 82 WHERE match_id = 7  AND player_id = 20;
UPDATE match_lineups SET minutes_played = 75 WHERE match_id = 9  AND player_id = 20;


-- ============================================================
-- ФОТО ИГРОКОВ И ТРЕНЕРОВ (из update_images.sql)
-- ============================================================

UPDATE persons SET photo_path = 'S600xU_2x.webp'                    WHERE id =  1;
UPDATE persons SET photo_path = 'Самаров_Александр.png'             WHERE id =  2;
UPDATE persons SET photo_path = 'Мелёхин_Майкл.png'                 WHERE id =  3;
UPDATE persons SET photo_path = 'Мишель_Хесус.png'                  WHERE id =  4;
UPDATE persons SET photo_path = 'Джо_Лавамер.png'                   WHERE id =  5;
UPDATE persons SET photo_path = 'Лаутерали_Франческо.png'           WHERE id =  6;
UPDATE persons SET photo_path = 'Юсуф-Изи_Монограмле.png'           WHERE id =  7;
UPDATE persons SET photo_path = 'Политсаевич_Якоб.png'              WHERE id =  8;
UPDATE persons SET photo_path = 'Данил_Квантум.png'                  WHERE id =  9;
UPDATE persons SET photo_path = 'Карпин_Данил.png'                   WHERE id = 10;
UPDATE persons SET photo_path = 'Дмитрий_Балалай.png'               WHERE id = 11;
UPDATE persons SET photo_path = 'Мемель-Косицин_Василий.png'        WHERE id = 12;
UPDATE persons SET photo_path = 'Кремия-Рус_Хосе.png'               WHERE id = 13;
UPDATE persons SET photo_path = 'Роберто_Дурто.png'                  WHERE id = 14;
UPDATE persons SET photo_path = 'Серд_Крул-Лурк.png'                 WHERE id = 15;
UPDATE persons SET photo_path = 'Альберт_Парунашвили.png'           WHERE id = 16;
UPDATE persons SET photo_path = 'Правандовский_Троберт.png'         WHERE id = 17;
UPDATE persons SET photo_path = 'Юрий_Маштаков.png'                  WHERE id = 18;
UPDATE persons SET photo_path = 'Работник_Бартоломей.png'           WHERE id = 19;
UPDATE persons SET photo_path = 'Следователь_Анатолий.png'          WHERE id = 20;
UPDATE persons SET photo_path = 'Волков_Иван.png'                    WHERE id = 21;
UPDATE persons SET photo_path = 'Сергеев_Никита.png'                 WHERE id = 22;
UPDATE persons SET photo_path = 'Омар_Диалло.png'                    WHERE id = 23;
UPDATE persons SET photo_path = 'Козлов_Артём.png'                   WHERE id = 24;
UPDATE persons SET photo_path = 'Хорват_Матео.png'                   WHERE id = 25;
UPDATE persons SET photo_path = 'Semenov.png'                        WHERE id = 26;
UPDATE persons SET photo_path = 'Игорь Петрович Николаев.png'        WHERE id = 27;
UPDATE persons SET photo_path = 'Сергей Павлович Никитин.png'        WHERE id = 28;
UPDATE persons SET photo_path = 'Дмитрий Александрович Орлов.png'   WHERE id = 29;
UPDATE persons SET photo_path = 'Виктор Михайлович Зайцев.png'      WHERE id = 30;
UPDATE persons SET photo_path = 'Олег Викторович Морозов.png'       WHERE id = 31;
UPDATE persons SET photo_path = 'Алексей Петрович Иванов.png'       WHERE id = 32;
UPDATE persons SET photo_path = 'Николай Андреевич Фёдоров.png'     WHERE id = 33;
UPDATE persons SET photo_path = 'Владимир Олегович Кузнецов.png'    WHERE id = 34;
UPDATE persons SET photo_path = 'Павел Дмитриевич Соколов.png'      WHERE id = 35;
UPDATE persons SET photo_path = 'Роман Сергеевич Лебедев.png'       WHERE id = 36;
UPDATE persons SET photo_path = 'Максим Игоревич Новиков.png'       WHERE id = 37;

-- Флаг румынского игрока (Крул-Лурк, id=15)
UPDATE persons SET flag_path = 'Flag_of_Romania.svg.png' WHERE id = 15;
