DROP TRIGGER IF EXISTS trigger_store_osm_highway_bicycle ON osm_highway_bicycle;
DROP TRIGGER IF EXISTS trigger_flag_transportation_bicycle ON osm_highway_linestring;
DROP TRIGGER IF EXISTS trigger_refresh ON transportation_bicycle.updates;

CREATE SCHEMA IF NOT EXISTS transportation_bicycle;

CREATE TABLE IF NOT EXISTS transportation_bicycle.changes
(
    osm_id bigint
);

CREATE OR REPLACE FUNCTION transportation_bicycle.store() RETURNS trigger AS
$$
BEGIN
    IF (tg_op = 'DELETE' OR tg_op = 'UPDATE') THEN
        INSERT INTO transportation_bicycle.changes(osm_id)
        VALUES (old.osm_id);
    ELSE
        INSERT INTO transportation_bicycle.changes(osm_id)
        VALUES (new.osm_id);
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TABLE IF NOT EXISTS transportation_bicycle.updates
(
    id serial PRIMARY KEY,
    t text,
    UNIQUE (t)
);
CREATE OR REPLACE FUNCTION transportation_bicycle.flag() RETURNS trigger AS
$$
BEGIN
    INSERT INTO transportation_bicycle.updates(t) VALUES ('y') ON CONFLICT(t) DO NOTHING;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION transportation_bicycle.refresh() RETURNS trigger AS
$$
DECLARE
    t TIMESTAMP WITH TIME ZONE := clock_timestamp();
    changes_osm_ids bigint[];
BEGIN
    RAISE LOG 'Refresh transportation_bicycle';

    DELETE FROM osm_highway_bicycle_all
    USING transportation_bicycle.changes
    WHERE
        osm_highway_bicycle_all.osm_id = changes.osm_id;

    -- Aggreagate the osm_id into a variable to avoid
    -- materialize of full view on next request
    SELECT
        array_agg(osm_id)
    INTO
        changes_osm_ids
    FROM
        transportation_bicycle.changes
    ;

    INSERT INTO osm_highway_bicycle_all
    SELECT
        osm_id,
        (array_agg(facility))[array_position(array_agg(side), 'left')] AS facility_left,
        (array_agg(access))[array_position(array_agg(side), 'left')] AS access_left,
        (array_agg(facility))[array_position(array_agg(side), 'right')] AS facility_right,
        (array_agg(access))[array_position(array_agg(side), 'right')] AS access_right
    FROM
        osm_highway_bicycle_side
    WHERE
        osm_id = ANY (changes_osm_ids)
    GROUP BY
        osm_id
    ;

    -- noinspection SqlWithoutWhere
    DELETE FROM transportation_bicycle.changes;
    DELETE FROM transportation_bicycle.updates;

    RAISE LOG 'Refresh transportation_bicycle done in %', age(clock_timestamp(), t);
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_store_osm_highway_bicycle
    AFTER INSERT OR UPDATE OR DELETE
    ON osm_highway_bicycle
    FOR EACH ROW
EXECUTE PROCEDURE transportation_bicycle.store();

CREATE TRIGGER trigger_flag_transportation_bicycle
    AFTER INSERT OR UPDATE OR DELETE
    ON osm_highway_bicycle
    FOR EACH STATEMENT
EXECUTE PROCEDURE transportation_bicycle.flag();

CREATE CONSTRAINT TRIGGER trigger_refresh
    AFTER INSERT
    ON transportation_bicycle.updates
    INITIALLY DEFERRED
    FOR EACH ROW
EXECUTE PROCEDURE transportation_bicycle.refresh();
