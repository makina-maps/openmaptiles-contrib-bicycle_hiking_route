CREATE OR REPLACE VIEW osm_highway_bicycle_side_priority AS
SELECT
    0::smallint AS priority,
    osm_id,
    highway,
    CASE
        WHEN "cycleway:left" IN ('lane', 'shared_lane', 'opposite_lane')
            THEN 'lane'
        WHEN "cycleway:left" IN ('track', 'separate', 'sidepath', 'opposite_track', 'shoulder')
            THEN 'track'
        WHEN "cycleway:left" IN ('share_busway', 'opposite_share_busway')
            THEN 'busway'
    END AS facility,
    CASE
        WHEN "cycleway:left" IN ('lane', 'shared_lane', 'track', 'separate', 'sidepath', 'shoulder', 'share_busway')
            THEN 1::smallint
        WHEN "cycleway:left" IN ('opposite_lane', 'opposite', 'opposite_track', 'opposite_share_busway')
            THEN -1::smallint
    END AS access,
    'left' AS side
FROM
    osm_highway_bicycle
WHERE
    highway != 'cycleway' AND
    "cycleway:left" NOT IN ('', 'no', 'none')

UNION ALL

SELECT
    0::smallint AS priority,
    osm_id,
    highway,
    CASE
        WHEN "cycleway:right" IN ('lane', 'shared_lane', 'opposite_lane')
            THEN 'lane'
        WHEN "cycleway:right" IN ('track', 'separate', 'sidepath', 'opposite_track', 'shoulder')
            THEN 'track'
        WHEN "cycleway:right" IN ('share_busway', 'opposite_share_busway')
            THEN 'busway'
    END AS facility,
    CASE
        WHEN "cycleway:right" IN ('lane', 'shared_lane', 'track', 'separate', 'sidepath', 'shoulder', 'share_busway')
            THEN 1::smallint
        WHEN "cycleway:right" IN ('opposite_lane', 'opposite', 'opposite_track', 'opposite_share_busway')
            THEN -1::smallint
    END AS access,
    'right' AS side
FROM
    highway != 'cycleway' AND
    osm_highway_bicycle
WHERE
    "cycleway:right" NOT IN ('', 'no', 'none')

UNION ALL

SELECT
    3::smallint AS priority,
    osm_id,
    highway,
    CASE side
    WHEN 'right' THEN
        CASE
        WHEN way IN ('lane', 'shared_lane')
            THEN 'lane'
        WHEN way IN ('track', 'separate', 'sidepath', 'shoulder')
            THEN 'track'
        WHEN way IN ('share_busway')
            THEN 'busway'
        END
    WHEN 'left' THEN
        CASE
        WHEN ((oneway = 'yes' OR junction = 'roundabout') AND "oneway:bicycle" != 'no') THEN
            CASE
                WHEN way IN ('opposite_lane')
                    THEN 'lane'
                WHEN way IN ('opposite_track')
                    THEN 'track'
                WHEN way IN ('opposite_share_busway')
                    THEN 'busway'
            END
        ELSE
            CASE
            WHEN way IN ('lane', 'shared_lane', 'opposite_lane')
                THEN 'lane'
            WHEN way IN ('track', 'separate', 'sidepath', 'opposite_track', 'shoulder')
                THEN 'track'
            WHEN way IN ('share_busway', 'opposite_share_busway')
                THEN 'busway'
            END
        END
    END AS facility,
    CASE side
    WHEN 'right' THEN
        CASE
        WHEN way IN ('lane', 'shared_lane', 'track', 'separate', 'sidepath', 'shoulder', 'share_busway')
            THEN 1
        END
    WHEN 'left' THEN
        CASE
        WHEN ((oneway = 'yes' OR junction = 'roundabout') AND "oneway:bicycle" != 'no') THEN
            CASE
            WHEN way IN ('opposite_lane', 'opposite', 'opposite_track', 'opposite_share_busway')
                THEN -1
            END
        ELSE
            CASE
            WHEN way IN ('lane', 'shared_lane', 'track', 'separate', 'sidepath', 'shoulder', 'share_busway')
                THEN -1
            WHEN way IN ('opposite_lane', 'opposite', 'opposite_track', 'opposite_share_busway')
                THEN -1
            END
        END
    END::smallint AS access,
    side
FROM
    (VALUES ('right'), ('left')) AS t(side),
    (SELECT *, CASE WHEN "cycleway:both" != '' THEN "cycleway:both" ELSE cycleway END AS way FROM osm_highway_bicycle WHERE highway != 'cycleway') AS osm_highway_bicycle
WHERE
    way NOT IN ('', 'no', 'none')

UNION ALL

SELECT
    4::smallint AS priority,
    osm_id,
    highway,
    CASE side
    WHEN 'right' THEN
        CASE WHEN highway IN ('pedestrian', 'path', 'footway') THEN 'pedestrian' END
    WHEN 'left' THEN
        CASE
        WHEN ((oneway = 'yes' OR junction = 'roundabout') AND "oneway:bicycle" != 'no') THEN
            NULL::text
        ELSE
            CASE WHEN highway IN ('pedestrian', 'path', 'footway') THEN 'pedestrian' END
        END
    END AS facility,
    CASE side
    WHEN 'right' THEN
        1::smallint
    WHEN 'left' THEN
        CASE
        WHEN ((oneway = 'yes' OR junction = 'roundabout') AND "oneway:bicycle" != 'no') THEN
            0::smallint
        ELSE
            -1::smallint
        END
    END AS access,
    side
FROM
    (VALUES ('right'), ('left')) AS t(side),
    osm_highway_bicycle
WHERE
    highway != 'cycleway' AND
    (highway NOT IN ('pedestrian', 'path', 'footway') OR bicycle IN ('yes', 'designated')) AND
    (highway NOT IN ('steps') OR "ramp:bicycle" = 'yes')
;


CREATE OR REPLACE VIEW osm_highway_bicycle_side AS
SELECT
    DISTINCT ON (osm_id, side)
    osm_id,
    first_value(facility) OVER (PARTITION BY osm_id, side ORDER BY facility IS NULL, priority) AS facility,
    first_value(access) OVER (PARTITION BY osm_id, side ORDER BY access IS NULL, priority) AS access,
    side
FROM
    osm_highway_bicycle_side_priority
ORDER BY
    osm_id,
    side,
    priority
;


-- etldoc: osm_highway_bicycle -> osm_highway_bicycle_all
CREATE TABLE IF NOT EXISTS osm_highway_bicycle_all AS
SELECT
    osm_id,
    (array_agg(facility))[array_position(array_agg(side), 'left')] AS facility_left,
    (array_agg(access))[array_position(array_agg(side), 'left')] AS access_left,
    (array_agg(facility))[array_position(array_agg(side), 'right')] AS facility_right,
    (array_agg(access))[array_position(array_agg(side), 'right')] AS access_right
FROM
    osm_highway_bicycle_side
GROUP BY
    osm_id
HAVING
    facility_left IS NOT NULL OR
    facility_right IS NOT NULL
;
CREATE UNIQUE INDEX IF NOT EXISTS osm_highway_bicycle_all_osm_id_idx ON osm_highway_bicycle_all(osm_id);


-- etldoc: osm_highway_bicycle_all -> osm_highway_bicycle_all_geom
-- etldoc: osm_highway_linestring -> osm_highway_bicycle_all_geom
CREATE OR REPLACE VIEW osm_highway_bicycle_all_geom AS
SELECT
    osm_highway_bicycle_all.*,
    osm_highway_linestring.highway,
    osm_highway_linestring.geometry
FROM
    osm_highway_bicycle_all
    JOIN osm_highway_linestring ON
        osm_highway_bicycle_all.osm_id = osm_highway_linestring.osm_id
;


-- etldoc: layer_transportation_bicycle[shape=record fillcolor=lightpink, style="rounded,filled",
-- etldoc:     label="<sql> layer_transportation_bicycle |<z11> z11 |<z12> z12|<z13> z13|<z14_> z14+" ] ;
CREATE OR REPLACE FUNCTION layer_transportation_bicycle(bbox geometry, zoom_level int)
    RETURNS TABLE
            (
                osm_id bigint,
                geometry geometry,
                highway text,
                facility text,
                access smallint,
                facility_left text,
                access_left smallint,
                facility_right text,
                access_right smallint
            )
AS
$$
    SELECT
        *
    FROM (
        -- etldoc: osm_highway_bicycle_all_geom -> layer_transportation_bicycle:z11
        -- etldoc: osm_highway_bicycle_all_geom -> layer_transportation_bicycle:z12
        -- etldoc: osm_highway_bicycle_all_geom -> layer_transportation_bicycle:z13
        -- etldoc: osm_highway_bicycle_all_geom -> layer_transportation_bicycle:z14_
        SELECT
            osm_id,
            geometry,
            highway,
            NULL::text AS facility,
            NULL::smallint AS access,
            facility_left,
            access_left,
            facility_right,
            access_right
        FROM
            osm_highway_bicycle_all_geom
        WHERE
            zoom_level >= 11

        UNION ALL

        -- etldoc: osm_cycleway -> layer_transportation_bicycle:z11
        -- etldoc: osm_cycleway -> layer_transportation_bicycle:z12
        -- etldoc: osm_cycleway -> layer_transportation_bicycle:z13
        -- etldoc: osm_cycleway -> layer_transportation_bicycle:z14_
        SELECT
            osm_id,
            geometry,
            highway,
            'cycleway' AS facility,
            CASE WHEN oneway = 'yes' OR junction = 'roundabout' THEN 1 END::smallint AS access,
            NULL::text AS facility_left,
            NULL::smallint AS access_left,
            NULL::text AS facility_right,
            NULL::smallint AS access_right
        FROM
            osm_highway_bicycle
        WHERE
            zoom_level >= 11 AND
            highway = 'cycleway'
    ) AS t
    WHERE
        geometry && bbox
    ;
$$ LANGUAGE SQL STABLE
                -- STRICT
                PARALLEL SAFE;
