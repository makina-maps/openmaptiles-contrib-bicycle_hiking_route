-- etldoc: layer_route_bicycle_hiking[shape=record fillcolor=lightpink, style="rounded,filled",
-- etldoc:     label="<sql> layer_route_bicycle_hiking |<z4> z4 |<z5> z5 |<z6> z6 |<z7> z7 |<z8> z8 |<z9> z9 |<z10> z10 |<z11> z11 |<z12> z12|<z13> z13|<z14_> z14+" ] ;
CREATE OR REPLACE FUNCTION layer_route_bicycle_hiking(bbox geometry, zoom_level int)
RETURNS TABLE(geometry geometry,
              bicycle_network INTEGER,
              bicycle_name TEXT,
              bicycle_ref TEXT,
              hiking_network INTEGER,
              hiking_name TEXT,
              hiking_ref TEXT
 ) AS $$
    -- etldoc:  osm_route_bicycle_hiking_network_gen_z4 -> layer_route_bicycle_hiking:z4
    SELECT *
    FROM osm_route_bicycle_hiking_network_gen_z4
    WHERE zoom_level = 4 AND geometry && bbox
    UNION ALL

    -- etldoc:  osm_route_bicycle_hiking_network_gen_z5 -> layer_route_bicycle_hiking:z5
    SELECT *
    FROM osm_route_bicycle_hiking_network_gen_z5
    WHERE zoom_level = 5 AND geometry && bbox
    UNION ALL

    -- etldoc:  osm_route_bicycle_hiking_network_gen_z6 -> layer_route_bicycle_hiking:z6
    SELECT *
    FROM osm_route_bicycle_hiking_network_gen_z6
    WHERE zoom_level = 6 AND geometry && bbox
    UNION ALL

    -- etldoc:  osm_route_bicycle_hiking_network_gen_z7 -> layer_route_bicycle_hiking:z7
    SELECT *
    FROM osm_route_bicycle_hiking_network_gen_z7
    WHERE zoom_level = 7 AND geometry && bbox
    UNION ALL

    -- etldoc:  osm_route_bicycle_hiking_network_gen_z8 -> layer_route_bicycle_hiking:z8
    SELECT *
    FROM osm_route_bicycle_hiking_network_gen_z8
    WHERE zoom_level = 8 AND geometry && bbox
    UNION ALL

    -- etldoc:  osm_route_bicycle_hiking_network_gen_z9 -> layer_route_bicycle_hiking:z9
    SELECT *
    FROM osm_route_bicycle_hiking_network_gen_z9
    WHERE zoom_level = 9 AND geometry && bbox
    UNION ALL

    -- etldoc:  osm_route_bicycle_hiking_network_gen_z10 -> layer_route_bicycle_hiking:z10
    SELECT *
    FROM osm_route_bicycle_hiking_network_gen_z10
    WHERE zoom_level = 10 AND geometry && bbox
    UNION ALL

    -- etldoc:  osm_route_bicycle_hiking_network_gen_z11 -> layer_route_bicycle_hiking:z11
    SELECT *
    FROM osm_route_bicycle_hiking_network_gen_z11
    WHERE zoom_level = 11 AND geometry && bbox
    UNION ALL

    -- etldoc:  osm_route_bicycle_hiking_network_gen_z12 -> layer_route_bicycle_hiking:z12
    SELECT *
    FROM osm_route_bicycle_hiking_network_gen_z12
    WHERE zoom_level = 12 AND geometry && bbox
    UNION ALL

    -- etldoc:  osm_route_bicycle_hiking_network_merge -> layer_route_bicycle_hiking:z13
    -- etldoc:  osm_route_bicycle_hiking_network_merge -> layer_route_bicycle_hiking:z14_
    SELECT
        geometry,
        bicycle_network,
        bicycle_name,
        bicycle_ref,
        hiking_network,
        hiking_name,
        hiking_ref
    FROM osm_route_bicycle_hiking_network_merge
    WHERE zoom_level >= 13 AND geometry && bbox
    ;
$$ LANGUAGE SQL STABLE
                -- STRICT
                PARALLEL SAFE;
