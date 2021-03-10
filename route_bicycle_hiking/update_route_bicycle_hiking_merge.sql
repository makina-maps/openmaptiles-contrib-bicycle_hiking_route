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
    member_id, geometry,
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
    coalesce(bicycle.geometry, hiking.geometry) AS geometry,
    bicycle.network AS bicycle_network, bicycle.name AS bicycle_name, bicycle.ref AS bicycle_ref,
    hiking.network AS hiking_network, hiking.name AS hiking_name, hiking.ref AS hiking_ref
FROM
    (SELECT * FROM osm_route_bicycle_hiking_max_network WHERE route = 'bicycle') AS bicycle
    FULL OUTER JOIN (SELECT * FROM osm_route_bicycle_hiking_max_network WHERE route = 'hiking') AS hiking ON
        bicycle.member_id = hiking.member_id
;

-- etldoc: osm_route_bicycle_hiking_network -> osm_route_bicycle_hiking_network_merge
DROP MATERIALIZED VIEW IF EXISTS osm_route_bicycle_hiking_network_merge CASCADE;
CREATE MATERIALIZED VIEW osm_route_bicycle_hiking_network_merge AS
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
    hiking_ref
;
CREATE INDEX IF NOT EXISTS osm_route_bicycle_hiking_network_merge_geometry_idx ON osm_route_bicycle_hiking_network_merge USING gist(geometry);

-- etldoc: osm_route_bicycle_hiking_network_merge -> osm_route_bicycle_hiking_network_gen_z12
DROP MATERIALIZED VIEW IF EXISTS osm_route_bicycle_hiking_network_gen_z12 CASCADE;
CREATE MATERIALIZED VIEW osm_route_bicycle_hiking_network_gen_z12 AS
SELECT ST_Simplify(geometry, ZRes(12)) AS geometry,
       bicycle_network,
       bicycle_name,
       bicycle_ref,
       hiking_network,
       hiking_name,
       hiking_ref
FROM osm_route_bicycle_hiking_network_merge
WHERE ST_Length(geometry) > 20
;
CREATE INDEX IF NOT EXISTS osm_route_bicycle_hiking_network_gen_z12_geometry_idx ON osm_route_bicycle_hiking_network_gen_z12 USING gist(geometry);

-- etldoc: osm_route_bicycle_hiking_network_gen_z12 -> osm_route_bicycle_hiking_network_gen_z11
CREATE MATERIALIZED VIEW osm_route_bicycle_hiking_network_gen_z11 AS
SELECT ST_Simplify(geometry, ZRes(11)) AS geometry,
       bicycle_network,
       bicycle_name,
       bicycle_ref,
       hiking_network,
       hiking_name,
       hiking_ref
FROM osm_route_bicycle_hiking_network_gen_z12
WHERE ST_Length(geometry) > 75
;
CREATE INDEX IF NOT EXISTS osm_route_bicycle_hiking_network_gen_z11_geometry_idx ON osm_route_bicycle_hiking_network_gen_z11 USING gist(geometry);

-- etldoc: osm_route_bicycle_hiking_network_gen_z11 -> osm_route_bicycle_hiking_network_gen_z10
CREATE MATERIALIZED VIEW osm_route_bicycle_hiking_network_gen_z10 AS
SELECT ST_Simplify(geometry, ZRes(10)) AS geometry,
       bicycle_network,
       bicycle_name,
       bicycle_ref,
       hiking_network,
       hiking_name,
       hiking_ref
FROM osm_route_bicycle_hiking_network_gen_z11
WHERE ST_Length(geometry) > 125
;
CREATE INDEX IF NOT EXISTS osm_route_bicycle_hiking_network_gen_z10_geometry_idx ON osm_route_bicycle_hiking_network_gen_z10 USING gist(geometry);

-- etldoc: osm_route_bicycle_hiking_network_gen_z10 -> osm_route_bicycle_hiking_network_gen_z9
CREATE MATERIALIZED VIEW osm_route_bicycle_hiking_network_gen_z9 AS
SELECT ST_Simplify(geometry, ZRes(9)) AS geometry,
       bicycle_network,
       bicycle_name,
       bicycle_ref,
       hiking_network,
       hiking_name,
       hiking_ref
FROM osm_route_bicycle_hiking_network_gen_z10
WHERE ST_Length(geometry) > 250 AND
    least(bicycle_network, hiking_network) <= 4
;
CREATE INDEX IF NOT EXISTS osm_route_bicycle_hiking_network_gen_z9_geometry_idx ON osm_route_bicycle_hiking_network_gen_z9 USING gist(geometry);

-- etldoc: osm_route_bicycle_hiking_network_gen_z9 -> osm_route_bicycle_hiking_network_gen_z8
CREATE MATERIALIZED VIEW osm_route_bicycle_hiking_network_gen_z8 AS
SELECT ST_Simplify(geometry, ZRes(8)) AS geometry,
       bicycle_network,
       bicycle_name,
       bicycle_ref,
       hiking_network,
       hiking_name,
       hiking_ref
FROM osm_route_bicycle_hiking_network_gen_z9
WHERE ST_Length(geometry) > 500
;
CREATE INDEX IF NOT EXISTS osm_route_bicycle_hiking_network_gen_z8_geometry_idx ON osm_route_bicycle_hiking_network_gen_z8 USING gist(geometry);

-- etldoc: osm_route_bicycle_hiking_network_gen_z8 -> osm_route_bicycle_hiking_network_gen_z7
CREATE MATERIALIZED VIEW osm_route_bicycle_hiking_network_gen_z7 AS
SELECT ST_Simplify(geometry, ZRes(7)) AS geometry,
       bicycle_network,
       bicycle_name,
       bicycle_ref,
       hiking_network,
       hiking_name,
       hiking_ref
FROM osm_route_bicycle_hiking_network_gen_z8
WHERE ST_Length(geometry) > 1000 AND
    least(bicycle_network, hiking_network) <= 3
;
CREATE INDEX IF NOT EXISTS osm_route_bicycle_hiking_network_gen_z7_geometry_idx ON osm_route_bicycle_hiking_network_gen_z7 USING gist(geometry);

-- etldoc: osm_route_bicycle_hiking_network_gen_z7 -> osm_route_bicycle_hiking_network_gen_z6
CREATE MATERIALIZED VIEW osm_route_bicycle_hiking_network_gen_z6 AS
SELECT ST_Simplify(geometry, ZRes(6)) AS geometry,
       bicycle_network,
       bicycle_name,
       bicycle_ref,
       hiking_network,
       hiking_name,
       hiking_ref
FROM osm_route_bicycle_hiking_network_gen_z7
WHERE ST_Length(geometry) > 2000
;
CREATE INDEX IF NOT EXISTS osm_route_bicycle_hiking_network_gen_z6_geometry_idx ON osm_route_bicycle_hiking_network_gen_z6 USING gist(geometry);

-- etldoc: osm_route_bicycle_hiking_network_gen_z6 -> osm_route_bicycle_hiking_network_gen_z5
CREATE MATERIALIZED VIEW osm_route_bicycle_hiking_network_gen_z5 AS
SELECT ST_Simplify(geometry, ZRes(5)) AS geometry,
       bicycle_network,
       bicycle_name,
       bicycle_ref,
       hiking_network,
       hiking_name,
       hiking_ref
FROM osm_route_bicycle_hiking_network_gen_z6
WHERE ST_Length(geometry) > 2000 AND
    least(bicycle_network, hiking_network) <= 2
;
CREATE INDEX IF NOT EXISTS osm_route_bicycle_hiking_network_gen_z5_geometry_idx ON osm_route_bicycle_hiking_network_gen_z6 USING gist(geometry);

-- etldoc: osm_route_bicycle_hiking_network_gen_z5 -> osm_route_bicycle_hiking_network_gen_z4
CREATE MATERIALIZED VIEW osm_route_bicycle_hiking_network_gen_z4 AS
SELECT ST_Simplify(geometry, ZRes(4)) AS geometry,
       bicycle_network,
       bicycle_name,
       bicycle_ref,
       hiking_network,
       hiking_name,
       hiking_ref
FROM osm_route_bicycle_hiking_network_gen_z5
WHERE ST_Length(geometry) > 2000 AND
    least(bicycle_network, hiking_network) <= 1
;
CREATE INDEX IF NOT EXISTS osm_route_bicycle_hiking_network_gen_z4_geometry_idx ON osm_route_bicycle_hiking_network_gen_z6 USING gist(geometry);


-- Handle updates

CREATE SCHEMA IF NOT EXISTS route_bicycle_hiking;

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
    REFRESH MATERIALIZED VIEW osm_route_bicycle_hiking_network_merge;
    REFRESH MATERIALIZED VIEW osm_route_bicycle_hiking_network_gen_z12;
    REFRESH MATERIALIZED VIEW osm_route_bicycle_hiking_network_gen_z11;
    REFRESH MATERIALIZED VIEW osm_route_bicycle_hiking_network_gen_z10;
    REFRESH MATERIALIZED VIEW osm_route_bicycle_hiking_network_gen_z9;
    REFRESH MATERIALIZED VIEW osm_route_bicycle_hiking_network_gen_z8;
    REFRESH MATERIALIZED VIEW osm_route_bicycle_hiking_network_gen_z7;
    REFRESH MATERIALIZED VIEW osm_route_bicycle_hiking_network_gen_z6;
    REFRESH MATERIALIZED VIEW osm_route_bicycle_hiking_network_gen_z5;
    -- noinspection SqlWithoutWhere
    DELETE FROM route_bicycle_hiking.updates;

    RAISE LOG 'Refresh route_bicycle_hiking done in %', age(clock_timestamp(), t);
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

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
