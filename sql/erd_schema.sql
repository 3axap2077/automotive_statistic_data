USE DATABASE CATFISH_DB;
USE WAREHOUSE CATFISH_WH;
CREATE SCHEMA auta_project;
USE SCHEMA auta_project;

SELECT * FROM AUTO2
Limit 100;

CREATE OR REPLACE TABLE CATFISH_DB.auta_project.STG_MARKETING_DATA AS
SELECT * FROM AGR_AUTO_VIN_MARKETING_DATABASE.PUBLIC.AUTO2;

CREATE TABLE Consumers (
    agrid20 VARCHAR(50) PRIMARY KEY,
    agrid15 VARCHAR(50),
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    email VARCHAR(255),
    md5_email VARCHAR(32),
    sha256_email VARCHAR(64)
);

CREATE TABLE Addresses (
    address_id INT IDENTITY(1,1) PRIMARY KEY,
    agrid20 VARCHAR(50),
    street_address VARCHAR(255),
    city VARCHAR(100),
    state CHAR(2),
    zip VARCHAR(10),
    zip4 VARCHAR(10),
    barcode VARCHAR(50),
    dpv VARCHAR(10),
    load_date DATE,
    update_date DATE,
    ncoa_date DATE,
    FOREIGN KEY (agrid20) REFERENCES Consumers(agrid20)
);

CREATE TABLE Demographics (
    agrid20 VARCHAR(50) PRIMARY KEY,
    estimated_income_code VARCHAR(10),
    homeowner_probability VARCHAR(10),
    length_of_residence INT,
    presence_of_children CHAR(1),
    marital_status CHAR(1),
    FOREIGN KEY (agrid20) REFERENCES Consumers(agrid20)
);

CREATE TABLE Properties (
    agrid20 VARCHAR(50) PRIMARY KEY,
    ownership_start_date DATE,
    purchase_price DECIMAL(15, 2),
    residential_props_owned INT,
    commercial_props_owned INT,
    FOREIGN KEY (agrid20) REFERENCES Consumers(agrid20)
);

CREATE TABLE Devices (
    device_id VARCHAR(100) PRIMARY KEY,
    device_type VARCHAR(50) -- e.g., IDFA, GAID
);

CREATE OR REPLACE TABLE WebActivity (
    activity_id INT IDENTITY(1,1) PRIMARY KEY,
    agrid20 VARCHAR(50),
    device_id VARCHAR(100),
    activity_timestamp DATETIME,
    domain VARCHAR(255),
    page TEXT,
    query_string TEXT,
    ip_address VARCHAR(45),
    page_level_cat1 VARCHAR(100),
    page_level_cat2 VARCHAR(100),
    FOREIGN KEY (agrid20) REFERENCES Consumers(agrid20),
    FOREIGN KEY (device_id) REFERENCES Devices(device_id)
);

CREATE TABLE GeoLocation (
    geo_id INT IDENTITY(1,1) PRIMARY KEY,
    activity_id INT,
    geo_city VARCHAR(100),
    geo_postal_code VARCHAR(10),
    geo_lat DECIMAL(10, 8),
    geo_long DECIMAL(11, 8),
    FOREIGN KEY (activity_id) REFERENCES WebActivity(activity_id)
);

CREATE TABLE Interests (
    agrid20 VARCHAR(50) PRIMARY KEY,
    il_vin BOOLEAN,
    il_veterans BOOLEAN,
    il_voters BOOLEAN,
    il_landline BOOLEAN,
    il_cell_phone BOOLEAN,
    FOREIGN KEY (agrid20) REFERENCES Consumers(agrid20)
);

INSERT INTO Consumers (agrid20, agrid15, first_name, last_name, email, md5_email, sha256_email)
SELECT DISTINCT 
    AGRID20, 
    AGRID15, 
    FIRST_NAME, 
    LAST_NAME, 
    EMAIL, 
    MD5_EMAIL, 
    SHA256_EMAIL
FROM STG_MARKETING_DATA;

INSERT INTO Devices (device_id, device_type)
SELECT DISTINCT 
    DEVICEID, 
    DEVICETYPE
FROM STG_MARKETING_DATA
WHERE DEVICEID IS NOT NULL;

INSERT INTO Addresses (agrid20, street_address, city, state, zip, zip4, barcode, dpv, load_date, update_date, ncoa_date)
SELECT DISTINCT
    AGRID20,
    ADDRESS,
    CITY,
    STATE,
    ZIP,
    CAST(ZIP4 AS VARCHAR),
    CAST(BARCODE AS VARCHAR),
    CAST(DPV AS VARCHAR),
    TRY_TO_DATE(LOAD_DATE),
    TRY_TO_DATE(UPDATE_DATE),
    TRY_TO_DATE(NCOA_DATE)
FROM STG_MARKETING_DATA;

INSERT INTO Demographics (agrid20, estimated_income_code, homeowner_probability, length_of_residence, presence_of_children, marital_status)
SELECT DISTINCT
    AGRID20,
    DEMO_ESTIMATEDINCOMECODE,
    DEMO_HOMEOWNERPROBABILITYMODEL,
    CAST(DEMO_LENGTHOFRESIDENCE AS INT),
    DEMO_PRESENCEOFCHILDREN,
    DEMO_PERSONMARITALSTATUS
FROM STG_MARKETING_DATA;

INSERT INTO Properties (agrid20, ownership_start_date, purchase_price, residential_props_owned, commercial_props_owned)
SELECT DISTINCT
    AGRID20,
    TRY_TO_DATE(CAST(PROP_OWNERSHIP_START_DATE AS VARCHAR), 'YYYYMMDD'),
    CAST(PROP_PURCHASE_PRICE AS DECIMAL(15,2)),
    CAST(PROP_RESIDENTIAL_PROPS_OWNED AS INT),
    CAST(PROP_COMMERCIAL_PROPS_OWNED AS INT)
FROM STG_MARKETING_DATA;

INSERT INTO Interests (agrid20, il_vin, il_veterans, il_voters, il_landline, il_cell_phone)
SELECT DISTINCT
    AGRID20,
    IFF(IL_VIN = 1, TRUE, FALSE),
    IFF(IL_VETERANS = 1, TRUE, FALSE),
    IFF(IL_VOTERS = 1, TRUE, FALSE),
    IFF(IL_LANDLINE = 1, TRUE, FALSE),
    IFF(IL_CELL_PHONE = 1, TRUE, FALSE)
FROM STG_MARKETING_DATA;

INSERT INTO WebActivity (agrid20, device_id, activity_timestamp, domain, page, query_string, ip_address, page_level_cat1, page_level_cat2)
SELECT 
    AGRID20,
    DEVICEID,
    TRY_TO_TIMESTAMP(DATETIME, 'MM/DD/YYYY HH24:MI'),
    DOMAIN,
    PAGE,
    QUERY,
    IPADDRESS,
    PAGELEVELCATEGORY1,
    PAGELEVELCATEGORY2
FROM STG_MARKETING_DATA;

INSERT INTO GeoLocation (activity_id, geo_city, geo_postal_code, geo_lat, geo_long)
SELECT 
    w.activity_id,
    s.GEOCITY,
    CAST(s.GEOPOSTALCODE AS VARCHAR),
    CAST(s.GEOLAT AS DECIMAL(10,8)),
    CAST(s.GEOLONG AS DECIMAL(11,8))
FROM STG_MARKETING_DATA s
JOIN WebActivity w 
    ON s.AGRID20 = w.agrid20 
    AND s.DEVICEID = w.device_id 
    AND TRY_TO_TIMESTAMP(s.DATETIME, 'MM/DD/YYYY HH24:MI') = w.activity_timestamp;

