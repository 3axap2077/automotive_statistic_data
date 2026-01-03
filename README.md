# **ELT proces datasetu AGR Auto Marketing**

Tento repozitár obsahuje implementáciu ELT procesu v Snowflake pre spracovanie dát z marketingovej databázy automobilového sektora. Cieľom projektu je transformovať surové dáta o aktivite používateľov na webe, ich demografii a majetkových pomeroch do viacdimenzionálneho modelu typu **Star Schema**, ktorý umožňuje efektívnu analýzu spotrebiteľského správania.

## **1. Úvod a popis zdrojových dát**

V rámci projektu analyzujeme dáta obsahujúce informácie o online aktivite potenciálnych kupcov áut, ich geografickej polohe a socioekonomických atribútoch. Dataset obsahuje informácie ako:

* **Identita:** Meno, email (vrátane hashovaných formátov).
* **Aktivita:** Navštívené domény, kategórie stránok, časové pečiatky návštev a IP adresy.
* **Demografia a majetok:** Odhadovaný príjem, rodinný stav, vlastnené nehnuteľnosti a nákupná cena.
* **Záujmy:** Príslušnosť k zoznamom (veteráni, voliči, vlastníci VIN).

Zdrojové dáta sú načítané zo staging tabuľky `STG_MARKETING_DATA`, ktorá vznikla zo zdroja `AGR_AUTO_VIN_MARKETING_DATABASE.PUBLIC.AUTO2`.

### **1.1 Dátová architektúra**

Dáta prechádzajú tromi úrovňami:

1. **Staging:** Surové dáta v tabuľke `STG_MARKETING_DATA`.
2. **Relational Layer (Normalized):** Rozdelenie dát do 8 entít (`Consumers`, `Addresses`, `Demographics`, `Properties`, `Devices`, `WebActivity`, `GeoLocation`, `Interests`) pre zabezpečenie integrity.
3. **Dimensional Layer (Star Schema):** Finálny analytický model pripravený na vizualizáciu.

---

## **2. Dimenzionálny model**

Navrhnutý model je **schéma hviezdy (star schema)**, ktorá pozostáva z tabuľky faktov a štyroch dimenzií:

### **Tabuľka faktov: `Fact_Marketing`**

Obsahuje kľúčové metriky a prepojenia na dimenzie:

* **`Purchase_Price`**: Finančná hodnota spojená s profilom spotrebiteľa.
* **`Visit_Timestamp`**: Presný čas aktivity.
* **`User_Visit_Rank`**: Poradie návštevy používateľa (vypočítané pomocou window funkcie `ROW_NUMBER()`).

### **Dimenzie**

* **`Dim_Consumer`**: Socio-demografický profil (Meno, Email, Príjmová kategória, Rodinný stav, status veterána).
* **`Dim_Geography`**: Priestorový kontext (Mesto, Štát, PSČ, zemepisná šírka a dĺžka).
* **`Dim_Date`**: Časový kontext (Deň, Mesiac, Rok, Kvartál, Deň v týždni).
* **`Dim_Source`**: Kontext zdroja návštevy (Doména a kategória webu).

---

## **3. ELT proces v Snowflake**

Proces transformácie prebieha priamo v prostredí Snowflake pomocou SQL.

### **3.1 Extract & Load (Do Stagingu)**

Dáta sú najprv skopírované do staging tabuľky, čím sa izoluje pôvodný zdroj od transformačnej logiky.

```sql
CREATE OR REPLACE TABLE STG_MARKETING_DATA AS
SELECT * FROM AGR_AUTO_VIN_MARKETING_DATABASE.PUBLIC.AUTO2;

```

### **3.2 Transformation (Normalizácia)**

V tejto fáze sa dáta čistia a rozdeľujú do relačných tabuliek. Používajú sa funkcie ako `TRY_TO_DATE` a `TRY_TO_TIMESTAMP` na ošetrenie nekonzistentných formátov dátumov a `IFF` na transformáciu číselných príznakov na boolean hodnoty.

* **Consumers**: Unikátne identity používateľov.
* **Addresses & GeoLocation**: Geografické údaje extrahované z viacerých častí pôvodného datasetu.
* **WebActivity**: Detailné záznamy o každom kliknutí prepojené na zariadenia (`Devices`).

### **3.3 Tvorba dimenzionálneho modelu**

Z normalizovaných tabuliek sa následne budujú dimenzie a faktová tabuľka.

#### **Príklad tvorby Dim_Date:**

Dátumová dimenzia sa generuje z unikátnych časových pečiatok webovej aktivity:

```sql
INSERT INTO Dim_Date (Date_ID, Full_Date, Year, Month, Quarter, DayOfWeek)
SELECT DISTINCT
    CAST(TO_CHAR(activity_timestamp, 'YYYYMMDD') AS INT),
    CAST(activity_timestamp AS DATE),
    YEAR(activity_timestamp),
    MONTH(activity_timestamp),
    QUARTER(activity_timestamp),
    DAYOFWEEK(activity_timestamp)
FROM WebActivity;

```

#### **Príklad tvorby Fact_Marketing:**

Faktová tabuľka integruje dáta naprieč modelom a pridáva analytickú vrstvu pomocou analytických funkcií:

```sql
INSERT INTO Fact_Marketing (Consumer_ID, Geo_ID, Source_ID, Purchase_Price, Visit_Timestamp, User_Visit_Rank)
SELECT
    dc.Consumer_ID,
    dg.Geo_ID,
    ds.Source_ID,
    p.purchase_price,
    wa.activity_timestamp,
    ROW_NUMBER() OVER (PARTITION BY wa.agrid20 ORDER BY wa.activity_timestamp ASC)
FROM WebActivity wa
JOIN Consumers c ON wa.agrid20 = c.agrid20
-- ... joiny na ostatné dimenzie

```


## **4. Zhrnutie**

Implementovaný ELT proces úspešne transformoval plochý súbor marketingových dát na robustný relačný a následne dimenzionálny model. Použitie **Star Schemy** optimalizuje výkonnosť dopytov pre potreby business intelligence a umožňuje sledovať cestu zákazníka (customer journey) v čase a priestore.

---
## **5.Vizualizácia**
1. Odhadovaný príjem (Estimated Income Code)
   
<img width="879" height="317" alt="visualisaton2" src="https://github.com/user-attachments/assets/04d7214a-8639-4367-91ce-9b13fd442c00" />

Tento graf zobrazuje distribúciu spotrebiteľov podľa kódov odhadovaného príjmu, pričom kategória „N“ predstavuje najpočetnejšiu skupinu. Väčšina zákazníkov sa sústreďuje v prvých dvoch príjmových kategóriách, po ktorých nasleduje klesajúci trend.
2. Distribúcia podľa štátov (State)

<img width="869" height="310" alt="visualisaton4" src="https://github.com/user-attachments/assets/8a0b8235-f936-405e-9da1-1174ca15b0a5" />

Vizualizácia porovnáva počty obyvateľov v jednotlivých štátoch, kde dominantné postavenie má Kalifornia (CA). Za ňou nasledujú Florida (FL) a Texas (TX), ktoré tvoria ďalšie významné lokality v databáze.
3. Typy zariadení (Device Chart)

<img width="540" height="308" alt="visualisaton3" src="https://github.com/user-attachments/assets/a4a04aa2-239e-4a29-9565-218d167046e9" />

Tento koláčový graf rozdeľuje používateľov podľa značky ich mobilného zariadenia medzi Apple a Android. Z údajov vyplýva, že Apple má v rámci tejto vzorky miernu prevahu nad zariadeniami so systémom Android.
4. Celkový počet návštev podľa dátumu (Total Visits)

<img width="871" height="305" alt="visualisaton1" src="https://github.com/user-attachments/assets/55844d19-caa6-45ea-9df9-6e484979cc2d" />

Graf dokumentuje vývoj počtu návštev v čase, pričom v marci 2024 je viditeľný prudký nárast aktivity. Pred týmto obdobím bol objem návštev výrazne nižší a stabilizovaný na minimálnych hodnotách.
5. Počet obyvateľov podľa miest (City)

<img width="863" height="309" alt="visualisaton5" src="https://github.com/user-attachments/assets/311105f7-3bdb-4c23-9807-e3c3a351eb21" />

Táto vizualizácia zobrazuje rozloženie obyvateľov v konkrétnych mestách, kde najvyššie hodnoty dosahuje Saint Paul. Mestá ako Las Vegas a Los Angeles nasledujú v tesnom závese s mierne nižším zastúpením.
