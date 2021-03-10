DROP TRIGGER IF EXISTS trigger_osm_route_bicycle_hiking_merge_linestring ON osm_route_bicycle_hiking_network_merge;
DROP TRIGGER IF EXISTS trigger_store_route_bicycle_hiking ON osm_route_bicycle_hiking_linestring;
DROP TRIGGER IF EXISTS trigger_flag_route_bicycle_hiking ON osm_route_bicycle_hiking_linestring;
DROP TRIGGER IF EXISTS trigger_refresh ON route_bicycle_hiking.updates;

CREATE OR REPLACE FUNCTION network_level(network TEXT) RETURNS INTEGER AS $$
    SELECT coalesce(
        array_position(ARRAY['icn', 'ncn', 'rcn', 'lcn'], network::text),
        array_position(ARRAY['iwn', 'nwn', 'rwn', 'lwn'], network::text)
    );
$$ LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE;

-- etldoc: osm_route_bicycle_hiking_linestring -> osm_route_bicycle_hiking_max_network
CREATE OR REPLACE VIEW osm_route_bicycle_hiking_max_network AS
SELECT DISTINCT ON (member_id, route)
    member_id AS osm_id,
    geometry,
    route,
    network_level(network) AS network,
    name,
    ref
FROM
    osm_route_bicycle_hiking_linestring
WHERE
    "type" = 1 AND
    network_level(network) IS NOT NULL AND
    role IN ('', 'forward', 'backward', 'reverse')
ORDER BY
    member_id,
    route,
    network_level(network)
;

-- etldoc: osm_route_bicycle_hiking_max_network -> osm_route_bicycle_hiking_network
CREATE OR REPLACE VIEW osm_route_bicycle_hiking_network AS
SELECT
    coalesce(bicycle.osm_id, hiking.osm_id) AS osm_id,
    coalesce(bicycle.geometry, hiking.geometry) AS geometry,
    bicycle.network AS bicycle_network,
    bicycle.name AS bicycle_name,
    bicycle.ref AS bicycle_ref,
    hiking.network AS hiking_network,
    hiking.name AS hiking_name,
    hiking.ref AS hiking_ref
FROM
    (SELECT * FROM osm_route_bicycle_hiking_max_network WHERE route = 'bicycle') AS bicycle
    FULL OUTER JOIN (SELECT * FROM osm_route_bicycle_hiking_max_network WHERE route = 'hiking') AS hiking ON
        bicycle.osm_id = hiking.osm_id
;

CREATE TABLE IF NOT EXISTS osm_route_bicycle_hiking_network_merge (
    geometry geometry,
    id SERIAL PRIMARY KEY,
    bicycle_network integer,
    bicycle_name varchar,
    bicycle_ref varchar,
    hiking_network integer,
    hiking_name varchar,
    hiking_ref varchar
);

-- etldoc: osm_route_bicycle_hiking_network -> osm_route_bicycle_hiking_network_merge
INSERT INTO osm_route_bicycle_hiking_network_merge (geometry, bicycle_network, bicycle_name, bicycle_ref, hiking_network, hiking_name, hiking_ref)
SELECT (ST_Dump(ST_LineMerge(ST_Collect(geometry)))).geom::geometry(Geometry,3857) AS geometry,
       bicycle_network,
       bicycle_name,
       bicycle_ref,
       hiking_network,
       hiking_name,
       hiking_ref
FROM
    osm_route_bicycle_hiking_network
GROUP BY
    bicycle_network,
    bicycle_name,
    bicycle_ref,
    hiking_network,
    hiking_name,
    hiking_ref;
CREATE INDEX IF NOT EXISTS osm_route_bicycle_hiking_network_merge_geometry_idx
    ON osm_route_bicycle_hiking_network_merge USING gist(geometry);

CREATE TABLE IF NOT EXISTS osm_route_bicycle_hiking_network_gen_z12
    (LIKE osm_route_bicycle_hiking_network_merge);
CREATE TABLE IF NOT EXISTS osm_route_bicycle_hiking_network_gen_z11
    (LIKE osm_route_bicycle_hiking_network_gen_z12);
CREATE TABLE IF NOT EXISTS osm_route_bicycle_hiking_network_gen_z10
    (LIKE osm_route_bicycle_hiking_network_gen_z11);
CREATE TABLE IF NOT EXISTS osm_route_bicycle_hiking_network_gen_z9
    (LIKE osm_route_bicycle_hiking_network_gen_z10);
CREATE TABLE IF NOT EXISTS osm_route_bicycle_hiking_network_gen_z8
    (LIKE osm_route_bicycle_hiking_network_gen_z9);
CREATE TABLE IF NOT EXISTS osm_route_bicycle_hiking_network_gen_z7
    (LIKE osm_route_bicycle_hiking_network_gen_z8);
CREATE TABLE IF NOT EXISTS osm_route_bicycle_hiking_network_gen_z6
    (LIKE osm_route_bicycle_hiking_network_gen_z7);
CREATE TABLE IF NOT EXISTS osm_route_bicycle_hiking_network_gen_z5
    (LIKE osm_route_bicycle_hiking_network_gen_z6);
CREATE TABLE IF NOT EXISTS osm_route_bicycle_hiking_network_gen_z4
    (LIKE osm_route_bicycle_hiking_network_gen_z5);


CREATE OR REPLACE FUNCTION insert_route_bicycle_hiking_network_gen(update_id bigint) RETURNS void AS
$$
BEGIN
    -- etldoc: osm_route_bicycle_hiking_network_merge -> osm_route_bicycle_hiking_network_gen_z12
    INSERT INTO osm_route_bicycle_hiking_network_gen_z12
    SELECT ST_Simplify(geometry, ZRes(12)) AS geometry,
        id,
        bicycle_network,
        bicycle_name,
        bicycle_ref,
        hiking_network,
        hiking_name,
        hiking_ref
    FROM osm_route_bicycle_hiking_network_merge
    WHERE
        (update_id IS NULL OR id = update_id) AND
        ST_Length(geometry) > 20;

    -- etldoc: osm_route_bicycle_hiking_network_gen_z12 -> osm_route_bicycle_hiking_network_gen_z11
    INSERT INTO osm_route_bicycle_hiking_network_gen_z11
    SELECT ST_Simplify(geometry, ZRes(11)) AS geometry,
        id,
        bicycle_network,
        bicycle_name,
        bicycle_ref,
        hiking_network,
        hiking_name,
        hiking_ref
    FROM osm_route_bicycle_hiking_network_gen_z12
    WHERE
        (update_id IS NULL OR id = update_id) AND
        ST_Length(geometry) > 75;

    -- etldoc: osm_route_bicycle_hiking_network_gen_z11 -> osm_route_bicycle_hiking_network_gen_z10
    INSERT INTO osm_route_bicycle_hiking_network_gen_z10
    SELECT ST_Simplify(geometry, ZRes(10)) AS geometry,
        id,
        bicycle_network,
        bicycle_name,
        bicycle_ref,
        hiking_network,
        hiking_name,
        hiking_ref
    FROM osm_route_bicycle_hiking_network_gen_z11
    WHERE
        (update_id IS NULL OR id = update_id) AND
        ST_Length(geometry) > 125;

    -- etldoc: osm_route_bicycle_hiking_network_gen_z10 -> osm_route_bicycle_hiking_network_gen_z9
    INSERT INTO osm_route_bicycle_hiking_network_gen_z9
    SELECT ST_Simplify(geometry, ZRes(9)) AS geometry,
        id,
        bicycle_network,
        bicycle_name,
        bicycle_ref,
        hiking_network,
        hiking_name,
        hiking_ref
    FROM osm_route_bicycle_hiking_network_gen_z10
    WHERE
        (update_id IS NULL OR id = update_id) AND
        ST_Length(geometry) > 250 AND
        least(bicycle_network, hiking_network) <= 4;

    -- etldoc: osm_route_bicycle_hiking_network_gen_z9 -> osm_route_bicycle_hiking_network_gen_z8
    INSERT INTO osm_route_bicycle_hiking_network_gen_z8
    SELECT ST_Simplify(geometry, ZRes(8)) AS geometry,
        id,
        bicycle_network,
        bicycle_name,
        bicycle_ref,
        hiking_network,
        hiking_name,
        hiking_ref
    FROM osm_route_bicycle_hiking_network_gen_z9
    WHERE
        (update_id IS NULL OR id = update_id) AND
        ST_Length(geometry) > 500;

    -- etldoc: osm_route_bicycle_hiking_network_gen_z8 -> osm_route_bicycle_hiking_network_gen_z7
    INSERT INTO osm_route_bicycle_hiking_network_gen_z7
    SELECT ST_Simplify(geometry, ZRes(7)) AS geometry,
        id,
        bicycle_network,
        bicycle_name,
        bicycle_ref,
        hiking_network,
        hiking_name,
        hiking_ref
    FROM osm_route_bicycle_hiking_network_gen_z8
    WHERE
        (update_id IS NULL OR id = update_id) AND
        ST_Length(geometry) > 1000 AND
        least(bicycle_network, hiking_network) <= 3;

    -- etldoc: osm_route_bicycle_hiking_network_gen_z7 -> osm_route_bicycle_hiking_network_gen_z6
    INSERT INTO osm_route_bicycle_hiking_network_gen_z6
    SELECT ST_Simplify(geometry, ZRes(6)) AS geometry,
        id,
        bicycle_network,
        bicycle_name,
        bicycle_ref,
        hiking_network,
        hiking_name,
        hiking_ref
    FROM osm_route_bicycle_hiking_network_gen_z7
    WHERE
        (update_id IS NULL OR id = update_id) AND
        ST_Length(geometry) > 2000;

    -- etldoc: osm_route_bicycle_hiking_network_gen_z6 -> osm_route_bicycle_hiking_network_gen_z5
    INSERT INTO osm_route_bicycle_hiking_network_gen_z5
    SELECT ST_Simplify(geometry, ZRes(5)) AS geometry,
        id,
        bicycle_network,
        bicycle_name,
        bicycle_ref,
        hiking_network,
        hiking_name,
        hiking_ref
    FROM osm_route_bicycle_hiking_network_gen_z6
    WHERE
        (update_id IS NULL OR id = update_id) AND
        ST_Length(geometry) > 2000 AND
        least(bicycle_network, hiking_network) <= 2;

    -- etldoc: osm_route_bicycle_hiking_network_gen_z5 -> osm_route_bicycle_hiking_network_gen_z4
    INSERT INTO osm_route_bicycle_hiking_network_gen_z4
    SELECT ST_Simplify(geometry, ZRes(4)) AS geometry,
        id,
        bicycle_network,
        bicycle_name,
        bicycle_ref,
        hiking_network,
        hiking_name,
        hiking_ref
    FROM osm_route_bicycle_hiking_network_gen_z5
    WHERE
        (update_id IS NULL OR id = update_id) AND
        ST_Length(geometry) > 2000 AND
        least(bicycle_network, hiking_network) <= 1;
END;
$$ LANGUAGE plpgsql;


SELECT insert_route_bicycle_hiking_network_gen(NULL);

CREATE INDEX IF NOT EXISTS osm_route_bicycle_hiking_network_gen_z12_geometry_idx
    ON osm_route_bicycle_hiking_network_gen_z12 USING gist(geometry);
CREATE INDEX IF NOT EXISTS osm_route_bicycle_hiking_network_gen_z12_id_idx
    ON osm_route_bicycle_hiking_network_gen_z12(id);

CREATE INDEX IF NOT EXISTS osm_route_bicycle_hiking_network_gen_z11_geometry_idx
    ON osm_route_bicycle_hiking_network_gen_z11 USING gist(geometry);
CREATE INDEX IF NOT EXISTS osm_route_bicycle_hiking_network_gen_z11_id_idx
    ON osm_route_bicycle_hiking_network_gen_z11(id);

CREATE INDEX IF NOT EXISTS osm_route_bicycle_hiking_network_gen_z10_geometry_idx
    ON osm_route_bicycle_hiking_network_gen_z10 USING gist(geometry);
CREATE INDEX IF NOT EXISTS osm_route_bicycle_hiking_network_gen_z10_id_idx
    ON osm_route_bicycle_hiking_network_gen_z10(id);

CREATE INDEX IF NOT EXISTS osm_route_bicycle_hiking_network_gen_z9_geometry_idx
    ON osm_route_bicycle_hiking_network_gen_z9 USING gist(geometry);
CREATE INDEX IF NOT EXISTS osm_route_bicycle_hiking_network_gen_z9_id_idx
    ON osm_route_bicycle_hiking_network_gen_z9(id);

CREATE INDEX IF NOT EXISTS osm_route_bicycle_hiking_network_gen_z8_geometry_idx
    ON osm_route_bicycle_hiking_network_gen_z8 USING gist(geometry);
CREATE INDEX IF NOT EXISTS osm_route_bicycle_hiking_network_gen_z8_id_idx
    ON osm_route_bicycle_hiking_network_gen_z8(id);

CREATE INDEX IF NOT EXISTS osm_route_bicycle_hiking_network_gen_z7_geometry_idx
    ON osm_route_bicycle_hiking_network_gen_z7 USING gist(geometry);
CREATE INDEX IF NOT EXISTS osm_route_bicycle_hiking_network_gen_z7_id_idx
    ON osm_route_bicycle_hiking_network_gen_z7(id);

CREATE INDEX IF NOT EXISTS osm_route_bicycle_hiking_network_gen_z6_geometry_idx
    ON osm_route_bicycle_hiking_network_gen_z6 USING gist(geometry);
CREATE INDEX IF NOT EXISTS osm_route_bicycle_hiking_network_gen_z6_id_idx
    ON osm_route_bicycle_hiking_network_gen_z6(id);

CREATE INDEX IF NOT EXISTS osm_route_bicycle_hiking_network_gen_z5_geometry_idx
    ON osm_route_bicycle_hiking_network_gen_z5 USING gist(geometry);
CREATE INDEX IF NOT EXISTS osm_route_bicycle_hiking_network_gen_z5_id_idx
    ON osm_route_bicycle_hiking_network_gen_z5(id);

CREATE INDEX IF NOT EXISTS osm_route_bicycle_hiking_network_gen_z4_geometry_idx
    ON osm_route_bicycle_hiking_network_gen_z4 USING gist(geometry);
CREATE INDEX IF NOT EXISTS osm_route_bicycle_hiking_network_gen_z4_id_idx
    ON osm_route_bicycle_hiking_network_gen_z4(id);


-- Handle updates

CREATE SCHEMA IF NOT EXISTS route_bicycle_hiking;

CREATE TABLE IF NOT EXISTS route_bicycle_hiking.changes
(
    id serial PRIMARY KEY,
    osm_id bigint,
    role varchar,
    is_old boolean,
    geometry geometry,
    route varchar,
    name varchar,
    ref varchar
);

CREATE OR REPLACE FUNCTION route_bicycle_hiking.store() RETURNS trigger AS
$$
BEGIN
    IF (tg_op = 'DELETE' OR tg_op = 'UPDATE') AND old.type = 1 THEN
        INSERT INTO route_bicycle_hiking.changes(osm_id, role, is_old, geometry, route, name, ref)
        VALUES (old.osm_id, old.role , true, old.geometry, old.route, old.name, old.ref);
    END IF;
    IF (tg_op = 'UPDATE' OR tg_op = 'INSERT') AND new.type = 1 THEN
        INSERT INTO route_bicycle_hiking.changes(osm_id, role, is_old, geometry, route, name, ref)
        VALUES (new.osm_id, new.role, false, new.geometry, new.route, new.name, new.ref);
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TABLE IF NOT EXISTS route_bicycle_hiking.updates
(
    id serial PRIMARY KEY,
    t text,
    UNIQUE (t)
);
CREATE OR REPLACE FUNCTION route_bicycle_hiking.flag() RETURNS trigger AS
$$
BEGIN
    INSERT INTO route_bicycle_hiking.updates(t) VALUES ('y') ON CONFLICT(t) DO NOTHING;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION route_bicycle_hiking.refresh() RETURNS trigger AS
$$
DECLARE
    t TIMESTAMP WITH TIME ZONE := clock_timestamp();
BEGIN
    RAISE LOG 'Refresh route_bicycle_hiking';

    -- Compact the change history to keep only the first and last version
    CREATE TEMP TABLE changes_compact AS
    SELECT
        osm_id,
        role,
        is_old,
        geometry,
        route,
        name,
        ref
    FROM ((
              SELECT DISTINCT ON (osm_id) *
              FROM route_bicycle_hiking.changes
              WHERE is_old
              ORDER BY osm_id,
                       id ASC
          )
          UNION ALL
          (
              SELECT DISTINCT ON (osm_id) *
              FROM route_bicycle_hiking.changes
              WHERE NOT is_old
              ORDER BY osm_id,
                       id DESC
          )) AS t;

    CREATE OR REPLACE TEMP VIEW changes_osm_route_bicycle_hiking_max_network AS
    SELECT DISTINCT ON (osm_id, route, is_old)
        osm_id,
        is_old,
        geometry,
        route,
        name,
        ref
    FROM
        changes_compact
    WHERE
        role IN ('', 'forward', 'backward', 'reverse')
    ORDER BY
        osm_id,
        route,
        is_old;

    CREATE OR REPLACE TEMP VIEW changes_osm_route_bicycle_hiking_network AS
    SELECT
        coalesce(bicycle.osm_id, hiking.osm_id) AS osm_id,
        coalesce(bicycle.is_old, hiking.is_old) AS is_old,
        coalesce(bicycle.geometry, hiking.geometry) AS geometry,
        -- bicycle.network AS bicycle_network,
        bicycle.name AS bicycle_name,
        bicycle.ref AS bicycle_ref,
        -- hiking.network AS hiking_network,
        hiking.name AS hiking_name,
        hiking.ref AS hiking_ref
    FROM
        (SELECT * FROM changes_osm_route_bicycle_hiking_max_network WHERE route = 'bicycle') AS bicycle
        FULL OUTER JOIN (SELECT * FROM changes_osm_route_bicycle_hiking_max_network WHERE route = 'hiking') AS hiking ON
            bicycle.osm_id = hiking.osm_id AND
            bicycle.is_old = hiking.is_old;

    -- Collect all original existing ways from impacted mmerge
    CREATE TEMP TABLE original AS
    SELECT DISTINCT ON (geometry, bicycle_network, bicycle_name, bicycle_ref, hiking_network, hiking_name, hiking_ref)
        t.geometry AS geometry,
        t.bicycle_network,
        t.bicycle_name,
        t.bicycle_ref,
        t.hiking_network,
        t.hiking_name,
        t.hiking_ref
    FROM
        changes_osm_route_bicycle_hiking_network AS c
        JOIN osm_route_bicycle_hiking_network_merge AS r ON
            r.geometry && c.geometry
            -- AND r.bicycle_network IS NOT DISTINCT FROM c.bicycle_network
            AND r.bicycle_name IS NOT DISTINCT FROM c.bicycle_name
            AND r.bicycle_ref IS NOT DISTINCT FROM c.bicycle_ref
            -- AND r.hiking_network IS NOT DISTINCT FROM c.hiking_network
            AND r.hiking_name IS NOT DISTINCT FROM c.hiking_name
            AND r.hiking_ref IS NOT DISTINCT FROM c.hiking_ref
        JOIN osm_route_bicycle_hiking_network AS t ON
            NOT t.osm_id IN (SELECT osm_id FROM changes_osm_route_bicycle_hiking_network)
            AND t.geometry && r.geometry
            AND ST_Contains(r.geometry, t.geometry)
            -- AND t.bicycle_network IS NOT DISTINCT FROM r.bicycle_network
            AND t.bicycle_name IS NOT DISTINCT FROM r.bicycle_name
            AND t.bicycle_ref IS NOT DISTINCT FROM r.bicycle_ref
            -- AND t.hiking_network IS NOT DISTINCT FROM r.hiking_network
            AND t.hiking_name IS NOT DISTINCT FROM r.hiking_name
            AND t.hiking_ref IS NOT DISTINCT FROM r.hiking_ref;

    DELETE
    FROM osm_route_bicycle_hiking_network_merge AS t
        USING changes_osm_route_bicycle_hiking_network AS c
    WHERE
        t.geometry && c.geometry
        -- AND t.bicycle_network IS NOT DISTINCT FROM c.bicycle_network
        AND t.bicycle_name IS NOT DISTINCT FROM c.bicycle_name
        AND t.bicycle_ref IS NOT DISTINCT FROM c.bicycle_ref
        -- AND t.hiking_network IS NOT DISTINCT FROM c.hiking_network
        AND t.hiking_name IS NOT DISTINCT FROM c.hiking_name
        AND t.hiking_ref IS NOT DISTINCT FROM c.hiking_ref;

    INSERT INTO osm_route_bicycle_hiking_network_merge (geometry, bicycle_network, bicycle_name, bicycle_ref, hiking_network, hiking_name, hiking_ref)
    SELECT (ST_Dump(ST_LineMerge(ST_Collect(t.geometry)))).geom::geometry(Geometry,3857) AS geometry,
        t.bicycle_network,
        t.bicycle_name,
        t.bicycle_ref,
        t.hiking_network,
        t.hiking_name,
        t.hiking_ref
    FROM ((
            SELECT
                *
            FROM
                original
        ) UNION ALL (
            -- New or updated ways
            SELECT
                r.geometry AS geometry,
                r.bicycle_network,
                r.bicycle_name,
                r.bicycle_ref,
                r.hiking_network,
                r.hiking_name,
                r.hiking_ref
            FROM
                changes_osm_route_bicycle_hiking_network AS c
                JOIN osm_route_bicycle_hiking_network AS r ON
                    r.geometry && c.geometry
                    AND ST_Equals(r.geometry, c.geometry)
                    -- AND r.bicycle_network IS NOT DISTINCT FROM c.bicycle_network
                    AND r.bicycle_name IS NOT DISTINCT FROM c.bicycle_name
                    AND r.bicycle_ref IS NOT DISTINCT FROM c.bicycle_ref
                    -- AND r.hiking_network IS NOT DISTINCT FROM c.hiking_network
                    AND r.hiking_name IS NOT DISTINCT FROM c.hiking_name
                    AND r.hiking_ref IS NOT DISTINCT FROM c.hiking_ref
            WHERE
                NOT c.is_old
        )) AS t
    GROUP BY
        t.bicycle_network,
        t.bicycle_name,
        t.bicycle_ref,
        t.hiking_network,
        t.hiking_name,
        t.hiking_ref;

    DROP VIEW changes_osm_route_bicycle_hiking_network;
    DROP VIEW changes_osm_route_bicycle_hiking_max_network;
    DROP TABLE original;
    DROP TABLE changes_compact;
    -- noinspection SqlWithoutWhere
    DELETE FROM route_bicycle_hiking.changes;
    -- noinspection SqlWithoutWhere
    DELETE FROM route_bicycle_hiking.updates;

    RAISE LOG 'Refresh route_bicycle_hiking done in %', age(clock_timestamp(), t);
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION route_bicycle_hiking.route_bicycle_hiking_network_gen_refresh() RETURNS trigger AS
$$
BEGIN
    IF (tg_op = 'DELETE') THEN
        DELETE FROM osm_route_bicycle_hiking_network_gen_z12 WHERE id = old.id;
        DELETE FROM osm_route_bicycle_hiking_network_gen_z11 WHERE id = old.id;
        DELETE FROM osm_route_bicycle_hiking_network_gen_z10 WHERE id = old.id;
        DELETE FROM osm_route_bicycle_hiking_network_gen_z9 WHERE id = old.id;
        DELETE FROM osm_route_bicycle_hiking_network_gen_z8 WHERE id = old.id;
        DELETE FROM osm_route_bicycle_hiking_network_gen_z7 WHERE id = old.id;
        DELETE FROM osm_route_bicycle_hiking_network_gen_z6 WHERE id = old.id;
        DELETE FROM osm_route_bicycle_hiking_network_gen_z5 WHERE id = old.id;
    END IF;

    IF (tg_op = 'UPDATE' OR tg_op = 'INSERT') THEN
        PERFORM insert_route_bicycle_hiking_network_gen(new.id);
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_osm_route_bicycle_hiking_merge_linestring
    AFTER INSERT OR UPDATE OR DELETE
    ON osm_route_bicycle_hiking_network_merge
    FOR EACH ROW
EXECUTE PROCEDURE route_bicycle_hiking.route_bicycle_hiking_network_gen_refresh();

CREATE TRIGGER trigger_store_route_bicycle_hiking
    AFTER INSERT OR UPDATE OR DELETE
    ON osm_route_bicycle_hiking_linestring
    FOR EACH ROW
EXECUTE PROCEDURE route_bicycle_hiking.store();

CREATE TRIGGER trigger_flag_route_bicycle_hiking
    AFTER INSERT OR UPDATE OR DELETE
    ON osm_route_bicycle_hiking_linestring
    FOR EACH STATEMENT
EXECUTE PROCEDURE route_bicycle_hiking.flag();

CREATE CONSTRAINT TRIGGER trigger_refresh
    AFTER INSERT
    ON route_bicycle_hiking.updates
    INITIALLY DEFERRED
    FOR EACH ROW
EXECUTE PROCEDURE route_bicycle_hiking.refresh();
