CREATE OR REPLACE FUNCTION network_level(network TEXT) RETURNS INTEGER AS $$
    SELECT coalesce(
        array_position(ARRAY['icn', 'ncn', 'rcn', 'lcn'], network::text),
        array_position(ARRAY['iwn', 'nwn', 'rwn', 'lwn'], network::text)
    );
$$ LANGUAGE SQL IMMUTABLE STRICT;

-- etldoc: osm_bicycle_hiking_route_linestring -> osm_bicycle_hiking_route_max_network
CREATE TEMP TABLE osm_bicycle_hiking_route_max_network AS
SELECT DISTINCT ON (member_id, route)
    member_id, geometry,
    route,
    network_level(network) AS network,
    name,
    ref
FROM
    osm_bicycle_hiking_route_linestring
WHERE
    "type" = 1 AND
    network != '' AND
    network_level(network) IS NOT NULL AND
    role IN ('', 'forward', 'backward', 'reverse')
ORDER BY
    member_id,
    route,
    network_level(network)
;

-- etldoc: osm_bicycle_hiking_route_max_network -> osm_bicycle_hiking_route_network
CREATE TEMP TABLE osm_bicycle_hiking_route_network AS
SELECT
    coalesce(bicycle.geometry, hiking.geometry) AS geometry,
    bicycle.network AS bicycle_network, bicycle.name AS bicycle_name, bicycle.ref AS bicycle_ref,
    hiking.network AS hiking_network, hiking.name AS hiking_name, hiking.ref AS hiking_ref
FROM
    (SELECT * FROM osm_bicycle_hiking_route_max_network WHERE route = 'bicycle') AS bicycle
    FULL OUTER JOIN (SELECT * FROM osm_bicycle_hiking_route_max_network WHERE route = 'hiking') AS hiking ON
        bicycle.member_id = hiking.member_id
;

-- etldoc: osm_bicycle_hiking_route_network -> osm_bicycle_hiking_route_network_merge
DROP TABLE IF EXISTS osm_bicycle_hiking_route_network_merge CASCADE;
CREATE TABLE IF NOT EXISTS osm_bicycle_hiking_route_network_merge AS
SELECT
    (ST_Dump(ST_LineMerge(ST_Collect(geometry)))).geom AS geometry,
    bicycle_network, bicycle_name, bicycle_ref,
    hiking_network, hiking_name, hiking_ref
FROM
    osm_bicycle_hiking_route_network
GROUP BY
    bicycle_network, bicycle_name, bicycle_ref,
    hiking_network, hiking_name, hiking_ref,
    -- Cluster by windows to lower time and memory required
    (ST_XMin(geometry) / 10000)::int,
    (ST_YMin(geometry) / 10000)::int
;


-- etldoc: osm_bicycle_hiking_route_network_merge -> osm_bicycle_hiking_route_network_merge_z12
CREATE MATERIALIZED VIEW osm_bicycle_hiking_route_network_merge_z12 AS (
    SELECT ST_Simplify(geometry, 30) AS geometry,
        bicycle_network, bicycle_name, bicycle_ref,
        hiking_network, hiking_name, hiking_ref
    FROM osm_bicycle_hiking_route_network_merge
    WHERE ST_Length(geometry) > 20
);
CREATE INDEX IF NOT EXISTS osm_bicycle_hiking_route_network_merge_z12_geometry_idx ON osm_bicycle_hiking_route_network_merge_z12 USING gist(geometry);

-- etldoc: osm_bicycle_hiking_route_network_merge_z12 -> osm_bicycle_hiking_route_network_merge_z11
CREATE MATERIALIZED VIEW osm_bicycle_hiking_route_network_merge_z11 AS (
    SELECT ST_Simplify(geometry, 60) AS geometry,
        bicycle_network, bicycle_name, bicycle_ref,
        hiking_network, hiking_name, hiking_ref
    FROM osm_bicycle_hiking_route_network_merge_z12
    WHERE ST_Length(geometry) > 75
);
CREATE INDEX IF NOT EXISTS osm_bicycle_hiking_route_network_merge_z11_geometry_idx ON osm_bicycle_hiking_route_network_merge_z11 USING gist(geometry);

-- etldoc: osm_bicycle_hiking_route_network_merge_z11 -> osm_bicycle_hiking_route_network_merge_z10
CREATE MATERIALIZED VIEW osm_bicycle_hiking_route_network_merge_z10 AS (
    SELECT ST_Simplify(geometry, 110) AS geometry,
        bicycle_network, bicycle_name, bicycle_ref,
        hiking_network, hiking_name, hiking_ref
    FROM osm_bicycle_hiking_route_network_merge_z11
    WHERE ST_Length(geometry) > 125
);
CREATE INDEX IF NOT EXISTS osm_bicycle_hiking_route_network_merge_z10_geometry_idx ON osm_bicycle_hiking_route_network_merge_z10 USING gist(geometry);

-- etldoc: osm_bicycle_hiking_route_network_merge_z10 -> osm_bicycle_hiking_route_network_merge_z9
CREATE MATERIALIZED VIEW osm_bicycle_hiking_route_network_merge_z9 AS (
    SELECT ST_Simplify(geometry, 200) AS geometry,
        bicycle_network, bicycle_name, bicycle_ref,
        hiking_network, hiking_name, hiking_ref
    FROM osm_bicycle_hiking_route_network_merge_z10
    WHERE ST_Length(geometry) > 250
);
CREATE INDEX IF NOT EXISTS osm_bicycle_hiking_route_network_merge_z9_geometry_idx ON osm_bicycle_hiking_route_network_merge_z9 USING gist(geometry);

-- etldoc: osm_bicycle_hiking_route_network_merge_z9 -> osm_bicycle_hiking_route_network_merge_z8
CREATE MATERIALIZED VIEW osm_bicycle_hiking_route_network_merge_z8 AS (
    SELECT ST_Simplify(geometry, 400) AS geometry,
        bicycle_network, bicycle_name, bicycle_ref,
        hiking_network, hiking_name, hiking_ref
    FROM osm_bicycle_hiking_route_network_merge_z9
    WHERE ST_Length(geometry) > 500 AND
        least(bicycle_network, hiking_network) <= 3
);
CREATE INDEX IF NOT EXISTS osm_bicycle_hiking_route_network_merge_z8_geometry_idx ON osm_bicycle_hiking_route_network_merge_z8 USING gist(geometry);

-- etldoc: osm_bicycle_hiking_route_network_merge_z8 -> osm_bicycle_hiking_route_network_merge_z7
CREATE MATERIALIZED VIEW osm_bicycle_hiking_route_network_merge_z7 AS (
    SELECT ST_Simplify(geometry, 800) AS geometry,
        bicycle_network, bicycle_name, bicycle_ref,
        hiking_network, hiking_name, hiking_ref
    FROM osm_bicycle_hiking_route_network_merge_z8
    WHERE ST_Length(geometry) > 1000 AND
        least(bicycle_network, hiking_network) <= 2
);
CREATE INDEX IF NOT EXISTS osm_bicycle_hiking_route_network_merge_z7_geometry_idx ON osm_bicycle_hiking_route_network_merge_z7 USING gist(geometry);

-- etldoc: osm_bicycle_hiking_route_network_merge_z7 -> osm_bicycle_hiking_route_network_merge_z6
CREATE MATERIALIZED VIEW osm_bicycle_hiking_route_network_merge_z6 AS (
    SELECT ST_Simplify(geometry, 1600) AS geometry,
        bicycle_network, bicycle_name, bicycle_ref,
        hiking_network, hiking_name, hiking_ref
    FROM osm_bicycle_hiking_route_network_merge_z7
    WHERE ST_Length(geometry) > 2000 AND
        least(bicycle_network, hiking_network) <= 1
);
CREATE INDEX IF NOT EXISTS osm_bicycle_hiking_route_network_merge_z6_geometry_idx ON osm_bicycle_hiking_route_network_merge_z6 USING gist(geometry);

-- etldoc: layer_bicycle_hiking_route[shape=record fillcolor=lightpink, style="rounded,filled",
-- etldoc:     label="<sql> layer_bicycle_hiking_route |<z6> z6 |<z7> z7 |<z8> z8 |<z9> z9 |<z10> z10 |<z11> z11 |<z12> z12|<z13> z13|<z14_> z14+" ] ;
CREATE OR REPLACE FUNCTION layer_bicycle_hiking_route(bbox geometry, zoom_level int)
RETURNS TABLE(geometry geometry, bicycle_network INTEGER, bicycle_name TEXT, bicycle_ref TEXT, hiking_network INTEGER, hiking_name TEXT, hiking_ref TEXT) AS $$
    SELECT *
    FROM osm_bicycle_hiking_route_network_merge_z6
    WHERE zoom_level = 6 AND geometry && bbox
    UNION ALL

    SELECT *
    FROM osm_bicycle_hiking_route_network_merge_z7
    WHERE zoom_level = 7 AND geometry && bbox
    UNION ALL

    SELECT *
    FROM osm_bicycle_hiking_route_network_merge_z8
    WHERE zoom_level = 8 AND geometry && bbox
    UNION ALL

    SELECT *
    FROM osm_bicycle_hiking_route_network_merge_z9
    WHERE zoom_level = 9 AND geometry && bbox
    UNION ALL

    SELECT *
    FROM osm_bicycle_hiking_route_network_merge_z10
    WHERE zoom_level = 10 AND geometry && bbox
    UNION ALL

    SELECT *
    FROM osm_bicycle_hiking_route_network_merge_z11
    WHERE zoom_level = 11 AND geometry && bbox
    UNION ALL

    SELECT *
    FROM osm_bicycle_hiking_route_network_merge_z12
    WHERE zoom_level = 12 AND geometry && bbox
    UNION ALL

    SELECT
        geometry,
        bicycle_network, bicycle_name, bicycle_ref,
        hiking_network, hiking_name, hiking_ref
    FROM osm_bicycle_hiking_route_network_merge
    WHERE zoom_level >= 13 AND geometry && bbox
    ;
$$ LANGUAGE SQL IMMUTABLE;
