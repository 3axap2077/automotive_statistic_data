CREATE TABLE Dim_Date (
    Date_ID INT PRIMARY KEY,
    Full_Date DATE UNIQUE,
    Year INT,
    Month INT,
    Quarter INT,
    DayOfWeek INT
);

INSERT INTO Dim_Date (Date_ID, Full_Date, Year, Month, Quarter, DayOfWeek)
SELECT DISTINCT
    CAST(TO_CHAR(activity_timestamp, 'YYYYMMDD') AS INT) AS Date_ID,
    CAST(activity_timestamp AS DATE) AS Full_Date,
    YEAR(activity_timestamp),
    MONTH(activity_timestamp),
    QUARTER(activity_timestamp),
    DAYOFWEEK(activity_timestamp)
FROM WebActivity;

CREATE TABLE Dim_Consumer (
    Consumer_ID INT IDENTITY(1,1) PRIMARY KEY,
    FirstName VARCHAR,
    LastName VARCHAR,
    Email VARCHAR,
    Income_Code VARCHAR,
    MaritalStatus VARCHAR,
    Is_Veteran VARCHAR(1)
);

INSERT INTO Dim_Consumer (FirstName, LastName, Email, Income_Code, MaritalStatus, Is_Veteran)
SELECT DISTINCT
    c.first_name,
    c.last_name,
    c.email,
    d.estimated_income_code,
    d.marital_status,
    CASE WHEN i.il_veterans = TRUE THEN 'Y' ELSE 'N' END
FROM Consumers c
LEFT JOIN Demographics d ON c.agrid20 = d.agrid20
LEFT JOIN Interests i ON c.agrid20 = i.agrid20;

CREATE TABLE Dim_Geography (
    Geo_ID INT IDENTITY(1,1) PRIMARY KEY,
    City VARCHAR,
    State VARCHAR,
    Zip VARCHAR,
    Latitude FLOAT,
    Longitude FLOAT
);

INSERT INTO Dim_Geography (City, State, Zip, Latitude, Longitude)
SELECT DISTINCT
    gl.geo_city,
    a.state,
    gl.geo_postal_code,
    gl.geo_lat,
    gl.geo_long
FROM GeoLocation gl
JOIN WebActivity wa ON gl.activity_id = wa.activity_id
JOIN Addresses a ON wa.agrid20 = a.agrid20;

CREATE TABLE Dim_Source (
    Source_ID INT IDENTITY(1,1) PRIMARY KEY,
    Domain VARCHAR,
    Category VARCHAR
);

INSERT INTO Dim_Source (Domain, Category)
SELECT DISTINCT
    domain,
    page_level_cat1
FROM WebActivity;

CREATE TABLE Fact_Marketing (
    Fact_ID INT IDENTITY(1,1) PRIMARY KEY,
    Consumer_ID INT,
    Geo_ID INT,
    Source_ID INT,
    Purchase_Price FLOAT,
    Visit_Timestamp TIMESTAMP,
    User_Visit_Rank INT -- Tu uložíme výsledok window funkcie
);
INSERT INTO Fact_Marketing (Consumer_ID, Geo_ID, Source_ID, Purchase_Price, Visit_Timestamp, User_Visit_Rank)
SELECT
    dc.Consumer_ID,
    dg.Geo_ID,
    ds.Source_ID,
    p.purchase_price,
    wa.activity_timestamp,
    ROW_NUMBER() OVER (PARTITION BY wa.agrid20 ORDER BY wa.activity_timestamp ASC) AS User_Visit_Rank
FROM WebActivity wa
JOIN Consumers c ON wa.agrid20 = c.agrid20
JOIN Dim_Consumer dc ON c.email = dc.Email
JOIN GeoLocation gl ON wa.activity_id = gl.activity_id
JOIN Dim_Geography dg ON gl.geo_city = dg.City AND gl.geo_postal_code = dg.Zip
JOIN Dim_Source ds ON wa.domain = ds.Domain AND wa.page_level_cat1 = ds.Category
LEFT JOIN Properties p ON wa.agrid20 = p.agrid20;