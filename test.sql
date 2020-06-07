CREATE OR REPLACE FUNCTION startup_properties_tests()
RETURNS SETOF TEXT AS
$$
BEGIN

    CREATE TABLE datasources (
        datasource_id text PRIMARY KEY
    );

    CREATE TABLE properties (
        property_id SERIAL PRIMARY KEY,
        uprn numeric (12) CONSTRAINT uprn_is_unique UNIQUE,
        description text,
        aig text, --address_identifier_gener
        street varchar (255),
        town varchar (255),
        postcode varchar (8),
        parish varchar (255),
        ward varchar (255)
    );

    COMMENT ON TABLE properties IS 'constrained by index property_is_unique';

    CREATE UNIQUE INDEX property_is_unique ON properties (
        COALESCE(description, ''),
        COALESCE(aig, ''),
        COALESCE(street, ''),
        COALESCE(town, ''),
        COALESCE(postcode, ''),
        COALESCE(parish, ''),
        COALESCE(ward, '')
    );

    CREATE TABLE datasources_properties (
        datasource_id text REFERENCES datasources (datasource_id)
            ON DELETE RESTRICT
            ON UPDATE CASCADE,
        property_id integer REFERENCES properties (property_id)
            ON DELETE RESTRICT
            ON UPDATE CASCADE,
        upstream_property_id text, --ID of property in datasource's database
        PRIMARY KEY (datasource_id, property_id),
        CONSTRAINT upstream_property_id_is_unique UNIQUE (
            datasource_id, upstream_property_id
        )
    );

    INSERT INTO datasources (datasource_id)
    VALUES ('local_govt_db'), ('another_govt_db');


END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION shutdown_properties_tests()
RETURNS SETOF TEXT AS
$$
BEGIN
    DROP TABLE datasources_properties;
    DROP TABLE properties;
    DROP TABLE datasources;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION test_rejects_duplicate_uprn()
RETURNS SETOF TEXT AS
$$
BEGIN
    PREPARE thrower AS
    INSERT INTO properties
        (uprn, description, aig, street, town, postcode, parish, ward)
    VALUES
        (1234, 'a', 'b', 'c', 'd', 'e', 'f', 'g'),
        (1234, 'h', 'i', 'j', 'k', 'l', 'm', 'n');

    RETURN NEXT throws_ok(
        'thrower',
        '23505',
        'duplicate key value violates unique constraint "uprn_is_unique"'
    );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION test_rejects_duplicate_upstream_id()
RETURNS SETOF TEXT AS
$$
DECLARE
    initial_properties_count numeric;
    after_first_insert_count numeric;
    final_properties_count numeric;
BEGIN

    --setup
    SELECT COUNT(*) INTO initial_properties_count FROM properties;

    --insert property with upstream id
    WITH prop_table AS (
        INSERT INTO properties
            (description, aig, street, town, postcode, parish, ward)
        VALUES ('a', 'b', 'c', 'd', 'e', 'f', 'g')
        RETURNING property_id
    )--/WITH
    INSERT INTO datasources_properties
        (datasource_id, property_id, upstream_property_id)
    VALUES (
        'local_govt_db',
        (SELECT property_id FROM prop_table),
        'a_not_unique_upstream_id'
    );
    
    --validate precondition
    SELECT COUNT(*) INTO after_first_insert_count FROM properties;
    RETURN NEXT is(
        after_first_insert_count,
        initial_properties_count + 1,
        '(precondition) setup query inserted a row'
    );

    --try again, copy and paste as couldn't get the prepared statement to
    --execute twice
    PREPARE duplicate_upstream_id_stmt AS
    WITH prop_table AS (
        INSERT INTO properties
            (description, aig, street, town, postcode, parish, ward)
        VALUES ('aa', 'bb', 'cc', 'dd', 'ee', 'ff', 'gg')
        RETURNING property_id
    )--/WITH
    INSERT INTO datasources_properties
        (datasource_id, property_id, upstream_property_id)
    VALUES (
        'local_govt_db',
        (SELECT property_id FROM prop_table),
        'a_not_unique_upstream_id'
    );

    RETURN NEXT throws_ok(
        'duplicate_upstream_id_stmt',
        '23505',
        'duplicate key value violates unique constraint '
        '"upstream_property_id_is_unique"'
    );

    --validate precondition
    SELECT COUNT(*) INTO final_properties_count FROM properties;
    RETURN NEXT is(
        final_properties_count,
        initial_properties_count + 1,
        'only one property row inserted'
    );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION test_rejects_duplicate_with_null_description()
RETURNS SETOF TEXT AS
$$
DECLARE
    initial_properties_count numeric;
    after_first_insert_count numeric;
    final_properties_count numeric;
BEGIN

    --setup
    SELECT COUNT(*) INTO initial_properties_count FROM properties;

    --insert property
    INSERT INTO properties 
        (description, aig, street, town, postcode, parish, ward)
    VALUES
        (NULL, '1', 'Foo St', 'Townston', 'XX00 0XX', 'Parish', 'Ward');


    --validate precondition
    SELECT COUNT(*) INTO after_first_insert_count FROM properties;
    RETURN NEXT is(
        after_first_insert_count,
        initial_properties_count + 1,
        '(precondition) setup query inserted a row'
    );

    PREPARE duplicate_with_description_null_stmt AS
    INSERT INTO properties
        (description, aig, street, town, postcode, parish, ward)
    VALUES
        (NULL, '1', 'Foo St', 'Townston', 'XX00 0XX', 'Parish', 'Ward');

    RETURN NEXT throws_ok(
        'duplicate_with_description_null_stmt',
        '23505',
        'duplicate key value violates unique constraint '
        '"property_is_unique"'
    );

    --validate precondition
    SELECT COUNT(*) INTO final_properties_count FROM properties;
    RETURN NEXT is(
        final_properties_count,
        initial_properties_count + 1,
        'only one property row inserted'
    );
    
END;
$$ LANGUAGE plpgsql;

--null address identifier general
CREATE OR REPLACE FUNCTION test_rejects_duplicate_with_null_aig()
RETURNS SETOF TEXT AS
$$
DECLARE
    initial_properties_count numeric;
    after_first_insert_count numeric;
    final_properties_count numeric;
BEGIN

    --setup
    SELECT COUNT(*) INTO initial_properties_count FROM properties;

    --insert property
    INSERT INTO properties 
        (description, aig, street, town, postcode, parish, ward)
    VALUES
        ('Breakwater', NULL, 'N/A', 'Bude', 'EX23 0XX', 'Parish', 'Ward');


    --validate precondition
    SELECT COUNT(*) INTO after_first_insert_count FROM properties;
    RETURN NEXT is(
        after_first_insert_count,
        initial_properties_count + 1,
        '(precondition) setup query inserted a row'
    );

    PREPARE duplicate_with_aig_null_stmt AS
    INSERT INTO properties
        (description, aig, street, town, postcode, parish, ward)
    VALUES
        ('Breakwater', NULL, 'N/A', 'Bude', 'EX23 0XX', 'Parish', 'Ward');

    RETURN NEXT throws_ok(
        'duplicate_with_aig_null_stmt',
        '23505',
        'duplicate key value violates unique constraint '
        '"property_is_unique"'
    );

    --validate precondition
    SELECT COUNT(*) INTO final_properties_count FROM properties;
    RETURN NEXT is(
        final_properties_count,
        initial_properties_count + 1,
        'only one property row inserted'
    );
    
END;
$$ LANGUAGE plpgsql;

--null street
CREATE OR REPLACE FUNCTION test_rejects_duplicate_with_null_street()
RETURNS SETOF TEXT AS
$$
DECLARE
    initial_properties_count numeric;
    after_first_insert_count numeric;
    final_properties_count numeric;
BEGIN

    --setup
    SELECT COUNT(*) INTO initial_properties_count FROM properties;

    --insert property
    INSERT INTO properties 
        (description, aig, street, town, postcode, parish, ward)
    VALUES
        ('Description', 'aig', NULL, 'Town', 'XX00 0XX', 'Parish', 'Ward');


    --validate precondition
    SELECT COUNT(*) INTO after_first_insert_count FROM properties;
    RETURN NEXT is(
        after_first_insert_count,
        initial_properties_count + 1,
        '(precondition) setup query inserted a row'
    );

    PREPARE duplicate_with_street_null_stmt AS
    INSERT INTO properties
        (description, aig, street, town, postcode, parish, ward)
    VALUES
        ('Description', 'aig', NULL, 'Town', 'XX00 0XX', 'Parish', 'Ward');

    RETURN NEXT throws_ok(
        'duplicate_with_street_null_stmt',
        '23505',
        'duplicate key value violates unique constraint '
        '"property_is_unique"'
    );

    --validate precondition
    SELECT COUNT(*) INTO final_properties_count FROM properties;
    RETURN NEXT is(
        final_properties_count,
        initial_properties_count + 1,
        'only one property row inserted'
    );
    
END;
$$ LANGUAGE plpgsql;

--null town
CREATE OR REPLACE FUNCTION test_rejects_duplicate_with_null_town()
RETURNS SETOF TEXT AS
$$
DECLARE
    initial_properties_count numeric;
    after_first_insert_count numeric;
    final_properties_count numeric;
BEGIN

    --setup
    SELECT COUNT(*) INTO initial_properties_count FROM properties;

    --insert property
    INSERT INTO properties 
        (description, aig, street, town, postcode, parish, ward)
    VALUES
        ('Description', 'aig', 'Street', NULL, 'XX00 0XX', 'Parish', 'Ward');


    --validate precondition
    SELECT COUNT(*) INTO after_first_insert_count FROM properties;
    RETURN NEXT is(
        after_first_insert_count,
        initial_properties_count + 1,
        '(precondition) setup query inserted a row'
    );

    PREPARE duplicate_with_town_null_stmt AS
    INSERT INTO properties
        (description, aig, street, town, postcode, parish, ward)
    VALUES
        ('Description', 'aig', 'Street', NULL, 'XX00 0XX', 'Parish', 'Ward');

    RETURN NEXT throws_ok(
        'duplicate_with_town_null_stmt',
        '23505',
        'duplicate key value violates unique constraint '
        '"property_is_unique"'
    );

    --validate precondition
    SELECT COUNT(*) INTO final_properties_count FROM properties;
    RETURN NEXT is(
        final_properties_count,
        initial_properties_count + 1,
        'only one property row inserted'
    );
    
END;
$$ LANGUAGE plpgsql;

--null postcode
CREATE OR REPLACE FUNCTION test_rejects_duplicate_with_null_postcode()
RETURNS SETOF TEXT AS
$$
DECLARE
    initial_properties_count numeric;
    after_first_insert_count numeric;
    final_properties_count numeric;
BEGIN

    --setup
    SELECT COUNT(*) INTO initial_properties_count FROM properties;

    --insert property
    INSERT INTO properties 
        (description, aig, street, town, postcode, parish, ward)
    VALUES
        ('Description', 'aig', 'Street', 'Town', NULL, 'Parish', 'Ward');


    --validate precondition
    SELECT COUNT(*) INTO after_first_insert_count FROM properties;
    RETURN NEXT is(
        after_first_insert_count,
        initial_properties_count + 1,
        '(precondition) setup query inserted a row'
    );

    PREPARE duplicate_with_postcode_null_stmt AS
    INSERT INTO properties
        (description, aig, street, town, postcode, parish, ward)
    VALUES
        ('Description', 'aig', 'Street', 'Town', NULL, 'Parish', 'Ward');

    RETURN NEXT throws_ok(
        'duplicate_with_postcode_null_stmt',
        '23505',
        'duplicate key value violates unique constraint '
        '"property_is_unique"'
    );

    --validate precondition
    SELECT COUNT(*) INTO final_properties_count FROM properties;
    RETURN NEXT is(
        final_properties_count,
        initial_properties_count + 1,
        'only one property row inserted'
    );
    
END;
$$ LANGUAGE plpgsql;

--null parish
CREATE OR REPLACE FUNCTION test_rejects_duplicate_with_null_parish()
RETURNS SETOF TEXT AS
$$
DECLARE
    initial_properties_count numeric;
    after_first_insert_count numeric;
    final_properties_count numeric;
BEGIN

    --setup
    SELECT COUNT(*) INTO initial_properties_count FROM properties;

    --insert property
    INSERT INTO properties 
        (description, aig, street, town, postcode, parish, ward)
    VALUES
        ('Description', 'aig', 'Street', 'Town', 'XX00 0XX', NULL, 'Ward');


    --validate precondition
    SELECT COUNT(*) INTO after_first_insert_count FROM properties;
    RETURN NEXT is(
        after_first_insert_count,
        initial_properties_count + 1,
        '(precondition) setup query inserted a row'
    );

    PREPARE duplicate_with_parish_null_stmt AS
    INSERT INTO properties
        (description, aig, street, town, postcode, parish, ward)
    VALUES
        ('Description', 'aig', 'Street', 'Town', 'XX00 0XX', NULL, 'Ward');

    RETURN NEXT throws_ok(
        'duplicate_with_parish_null_stmt',
        '23505',
        'duplicate key value violates unique constraint '
        '"property_is_unique"'
    );

    --validate precondition
    SELECT COUNT(*) INTO final_properties_count FROM properties;
    RETURN NEXT is(
        final_properties_count,
        initial_properties_count + 1,
        'only one property row inserted'
    );
    
END;
$$ LANGUAGE plpgsql;

--null ward
CREATE OR REPLACE FUNCTION test_rejects_duplicate_with_null_ward()
RETURNS SETOF TEXT AS
$$
DECLARE
    initial_properties_count numeric;
    after_first_insert_count numeric;
    final_properties_count numeric;
BEGIN

    --setup
    SELECT COUNT(*) INTO initial_properties_count FROM properties;

    --insert property
    INSERT INTO properties 
        (description, aig, street, town, postcode, parish, ward)
    VALUES
        ('Breakwater', 'aig', 'N/A', 'Bude', 'EX23 0XX', 'Parish', NULL);


    --validate precondition
    SELECT COUNT(*) INTO after_first_insert_count FROM properties;
    RETURN NEXT is(
        after_first_insert_count,
        initial_properties_count + 1,
        '(precondition) setup query inserted a row'
    );

    PREPARE duplicate_with_ward_null_stmt AS
    INSERT INTO properties
        (description, aig, street, town, postcode, parish, ward)
    VALUES
        ('Breakwater', 'aig', 'N/A', 'Bude', 'EX23 0XX', 'Parish', NULL);

    RETURN NEXT throws_ok(
        'duplicate_with_ward_null_stmt',
        '23505',
        'duplicate key value violates unique constraint '
        '"property_is_unique"'
    );

    --validate precondition
    SELECT COUNT(*) INTO final_properties_count FROM properties;
    RETURN NEXT is(
        final_properties_count,
        initial_properties_count + 1,
        'only one property row inserted'
    );
    
END;
$$ LANGUAGE plpgsql;