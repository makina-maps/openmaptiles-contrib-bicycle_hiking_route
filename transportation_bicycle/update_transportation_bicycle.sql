DROP TRIGGER IF EXISTS trigger_flag_transportation_bicycle ON osm_highway_linestring;
DROP TRIGGER IF EXISTS trigger_refresh ON transportation_bicycle.updates;

CREATE SCHEMA IF NOT EXISTS transportation_bicycle;

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
BEGIN
    RAISE LOG 'Refresh transportation_bicycle';
    REFRESH MATERIALIZED VIEW osm_highway_bicycle_all;
    -- noinspection SqlWithoutWhere
    DELETE FROM transportation_bicycle.updates;

    RAISE LOG 'Refresh transportation_bicycle done in %', age(clock_timestamp(), t);
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

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
