-- typ dla strefy klimatycznej
CREATE TYPE strefa_klimatyczna_t AS OBJECT (
    id_strefy NUMBER,
    nazwa VARCHAR2(100),
    min_temperatura NUMBER,
    max_temperatura NUMBER,
    wilgotnosc NUMBER
);

-- typ dla lokalizacji
CREATE TYPE lokalizacja_t AS OBJECT (
    id_lokalizacji NUMBER,
    nazwa VARCHAR2(100),
    powierzchnia NUMBER,
    strefa REF strefa_klimatyczna_t,
    opis VARCHAR2(500)
);

-- typ dla gatunku
CREATE TYPE gatunek_t AS OBJECT (
    id_gatunku NUMBER,
    nazwa_lacinska VARCHAR2(100),
    nazwa_zwyczajowa VARCHAR2(100),
    rodzaj VARCHAR2(50), -- drzewo, krzew, kwiat itp.
    rodzina VARCHAR2(100),
    opis CLOB
);

-- typ dla etykiety
CREATE TYPE etykieta_t AS OBJECT (
    id_etykiety NUMBER,
    nazwa VARCHAR2(100),
    opis VARCHAR2(500)
);

-- kolekcja etykiet
CREATE TYPE etykiety_tab_t AS TABLE OF etykieta_t;

-- typ dla zagrozenia
CREATE TYPE zagrozenie_t AS OBJECT (
    id_zagrozenia NUMBER,
    nazwa VARCHAR2(100),
    typ VARCHAR2(50), -- szkodnik, choroba, warunki pogodowe
    poziom_ryzyka VARCHAR2(20),
    opis VARCHAR2(500)
);

-- kolekcja zagrozen
CREATE TYPE zagrozenia_tab_t AS TABLE OF zagrozenie_t;

-- typ dla sezonu
CREATE TYPE sezon_t AS OBJECT (
    id_sezonu NUMBER,
    nazwa VARCHAR2(50),
    data_rozpoczecia DATE,
    data_zakonczenia DATE,
    typ VARCHAR2(50) -- kwitnienie, owocowanie, pielegnacja
);

-- kolekcja sezonow
CREATE TYPE sezony_tab_t AS TABLE OF sezon_t;

-- typ dla dostawcy
CREATE TYPE dostawca_t AS OBJECT (
    id_dostawcy NUMBER,
    nazwa VARCHAR2(100),
    nip VARCHAR2(10),
    adres VARCHAR2(200),
    telefon VARCHAR2(20),
    email VARCHAR2(100)
);

-- typ dla harmonogramu pracy
CREATE TYPE harmonogram_t AS OBJECT (
    id_harmonogramu NUMBER,
    data_od DATE,
    data_do DATE,
    godziny_od VARCHAR2(5),
    godziny_do VARCHAR2(5)
);

-- typ dla pracownika
CREATE TYPE pracownik_t AS OBJECT (
    id_pracownika NUMBER,
    imie VARCHAR2(50),
    nazwisko VARCHAR2(50),
    stanowisko VARCHAR2(50),
    data_zatrudnienia DATE,
    harmonogram REF harmonogram_t,
    telefon VARCHAR2(20),
    email VARCHAR2(100)
    --placa NUMBER
);

-- typ dla zabiegu pielgnacyjnego
CREATE TYPE zabieg_t AS OBJECT (
    id_zabiegu NUMBER,
    nazwa VARCHAR2(100),
    data DATE,
    opis VARCHAR2(500),
    pracownik REF pracownik_t,
    koszt NUMBER
);

-- kolekcja zabiegow
CREATE TYPE zabiegi_tab_t AS TABLE OF zabieg_t;

-- typ dla rosliny (glowny obiekt)
CREATE TYPE roslina_t AS OBJECT (
    id_rosliny NUMBER,
    nazwa VARCHAR2(100),
    gatunek REF gatunek_t,
    lokalizacja REF lokalizacja_t,
    pracownik REF pracownik_t,
    dostawca REF dostawca_t,
    data_zasadzenia DATE,
    wysokosc NUMBER,
    stan_zdrowia VARCHAR2(50),
    zabiegi zabiegi_tab_t,
    etykiety etykiety_tab_t,
    zagrozenia zagrozenia_tab_t,
    sezony sezony_tab_t,
    
    -- metody
    MEMBER FUNCTION wiek RETURN NUMBER,
    MEMBER FUNCTION koszt_utrzymania RETURN NUMBER,
    MEMBER PROCEDURE dodaj_zabieg(p_zabieg zabieg_t),
    MEMBER PROCEDURE dodaj_etykiete(p_etykieta etykieta_t),
    MEMBER PROCEDURE dodaj_zagrozenie(p_zagrozenie zagrozenie_t)
);

CREATE OR REPLACE TYPE BODY roslina_t AS
    MEMBER FUNCTION wiek RETURN NUMBER IS
    BEGIN
        RETURN TRUNC(MONTHS_BETWEEN(SYSDATE, data_zasadzenia) / 12);
    END;
    
    MEMBER FUNCTION koszt_utrzymania RETURN NUMBER IS
        v_suma NUMBER := 0;
    BEGIN
        FOR i IN 1..zabiegi.COUNT LOOP
            v_suma := v_suma + zabiegi(i).koszt;
        END LOOP;
        RETURN v_suma;
    END;
    
    MEMBER PROCEDURE dodaj_zabieg(p_zabieg zabieg_t) IS
    BEGIN
        zabiegi.EXTEND;
        zabiegi(zabiegi.LAST) := p_zabieg;
    END;
    
    MEMBER PROCEDURE dodaj_etykiete(p_etykieta etykieta_t) IS
    BEGIN
        etykiety.EXTEND;
        etykiety(etykiety.LAST) := p_etykieta;
    END;
    
    MEMBER PROCEDURE dodaj_zagrozenie(p_zagrozenie zagrozenie_t) IS
    BEGIN
        zagrozenia.EXTEND;
        zagrozenia(zagrozenia.LAST) := p_zagrozenie;
    END;
END;
/
---------
-- tworzenie tabel dla podstawowych typow
CREATE TABLE strefy_klimatyczne OF strefa_klimatyczna_t (
    PRIMARY KEY (id_strefy)
);

CREATE TABLE lokalizacje OF lokalizacja_t (
    PRIMARY KEY (id_lokalizacji)
);

CREATE TABLE gatunki OF gatunek_t (
    PRIMARY KEY (id_gatunku)
);

CREATE TABLE dostawcy OF dostawca_t (
    PRIMARY KEY (id_dostawcy)
);

CREATE TABLE harmonogramy OF harmonogram_t (
    PRIMARY KEY (id_harmonogramu)
);

CREATE TABLE pracownicy OF pracownik_t (
    PRIMARY KEY (id_pracownika)
);

CREATE TABLE rosliny OF roslina_t
NESTED TABLE zabiegi STORE AS tab_zabiegi
NESTED TABLE etykiety STORE AS tab_etykiety
NESTED TABLE zagrozenia STORE AS tab_zagrozenia
NESTED TABLE sezony STORE AS tab_sezony;
/

SELECT * FROM user_types WHERE type_name IN (
    'ZABIEGI_TAB_T',
    'ETYKIETY_TAB_T',
    'ZAGROZENIA_TAB_T',
    'SEZONY_TAB_T'
);
SELECT * FROM user_types WHERE type_name = 'ROSLINA_T';


-------------------------------------------------------

-- pakiet do zarzadzania roslinami
CREATE OR REPLACE PACKAGE zarzadzanie_roslinami AS
    -- dodawanie nowej rosliny
    PROCEDURE dodaj_rosline(
        p_nazwa VARCHAR2,
        p_gatunek_id NUMBER,
        p_lokalizacja_id NUMBER,
        p_pracownik_id NUMBER,
        p_dostawca_id NUMBER,
        p_wysokosc NUMBER
    );
    
    -- przenoszenie rosliny do nowej lokalizacji
    PROCEDURE przenies_rosline(
        p_id_rosliny NUMBER,
        p_nowa_lokalizacja_id NUMBER
    );
    
    -- dodawanie zabiegu pielgnacyjnego
    PROCEDURE dodaj_zabieg(
        p_id_rosliny NUMBER,
        p_nazwa_zabiegu VARCHAR2,
        p_pracownik_id NUMBER,
        p_koszt NUMBER
    );
    
    -- aktualizacja stanu zdrowia rosliny
    PROCEDURE aktualizuj_stan_zdrowia(
        p_id_rosliny NUMBER,
        p_stan VARCHAR2
    );
    
    -- pobranie wieku rosliny
    FUNCTION pobierz_wiek_rosliny(
        p_id_rosliny NUMBER
    ) RETURN NUMBER;
    
    -- pobranie calkowitego kosztu utrzymania rosliny
    FUNCTION pobierz_koszt_utrzymania(
        p_id_rosliny NUMBER
    ) RETURN NUMBER;
    
    -- pobranie historii zabiegow
    FUNCTION pobierz_historie_zabiegow(
        p_id_rosliny NUMBER
    ) RETURN zabiegi_tab_t;
END zarzadzanie_roslinami;
/

-- implementacja pakietu zarzadzania roslinami
CREATE OR REPLACE PACKAGE BODY zarzadzanie_roslinami AS
    PROCEDURE dodaj_rosline(
        p_nazwa VARCHAR2,
        p_gatunek_id NUMBER,
        p_lokalizacja_id NUMBER,
        p_pracownik_id NUMBER,
        p_dostawca_id NUMBER,
        p_wysokosc NUMBER
    ) IS
        v_gatunek_ref REF gatunek_t;
        v_lokalizacja_ref REF lokalizacja_t;
        v_pracownik_ref REF pracownik_t;
        v_dostawca_ref REF dostawca_t;
        v_id NUMBER;
    BEGIN
        -- Pobieramy referencje
        SELECT REF(g) INTO v_gatunek_ref
        FROM gatunki g WHERE g.id_gatunku = p_gatunek_id;
        
        SELECT REF(l) INTO v_lokalizacja_ref
        FROM lokalizacje l WHERE l.id_lokalizacji = p_lokalizacja_id;
        
        SELECT REF(p) INTO v_pracownik_ref
        FROM pracownicy p WHERE p.id_pracownika = p_pracownik_id;
        
        SELECT REF(d) INTO v_dostawca_ref
        FROM dostawcy d WHERE d.id_dostawcy = p_dostawca_id;
        
        -- generujemy nowe ID
        SELECT NVL(MAX(id_rosliny), 0) + 1 INTO v_id FROM rosliny;
        
        -- wstawiamy nowa rosline
        INSERT INTO rosliny VALUES (
            roslina_t(
                v_id,
                p_nazwa,
                v_gatunek_ref,
                v_lokalizacja_ref,
                v_pracownik_ref,
                v_dostawca_ref,
                SYSDATE,
                p_wysokosc,
                'Dobry',
                zabiegi_tab_t(),
                etykiety_tab_t(),
                zagrozenia_tab_t(),
                sezony_tab_t()
            )
        );
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20001, 'Blad podczas dodawania rosliny: ' || SQLERRM);
    END dodaj_rosline;

    PROCEDURE przenies_rosline(
        p_id_rosliny NUMBER,
        p_nowa_lokalizacja_id NUMBER
    ) IS
        v_lokalizacja_ref REF lokalizacja_t;
    BEGIN
        -- pobieramy referencje do nowej lokalizacji
        SELECT REF(l) INTO v_lokalizacja_ref
        FROM lokalizacje l WHERE l.id_lokalizacji = p_nowa_lokalizacja_id;
        
        -- aktualizujemy lokalizacje rosliny
        UPDATE rosliny r
        SET r.lokalizacja = v_lokalizacja_ref
        WHERE r.id_rosliny = p_id_rosliny;
        
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20002, 'Blad podczas przenoszenia rosliny: ' || SQLERRM);
    END przenies_rosline;
    
    PROCEDURE dodaj_zabieg(
        p_id_rosliny NUMBER,
        p_nazwa_zabiegu VARCHAR2,
        p_pracownik_id NUMBER,
        p_koszt NUMBER
    ) IS
        v_pracownik_ref REF pracownik_t;
        v_id NUMBER;
        v_zabieg zabieg_t;
    BEGIN
        -- Pobieramy referencj� do pracownika
        SELECT REF(p) INTO v_pracownik_ref
        FROM pracownicy p 
        WHERE p.id_pracownika = p_pracownik_id;
        
        -- Generujemy nowe ID dla zabiegu
        SELECT NVL(MAX(z.id_zabiegu), 0) + 1 INTO v_id
        FROM TABLE(SELECT r.zabiegi FROM rosliny r WHERE r.id_rosliny = p_id_rosliny) z;
        
        -- Tworzymy nowy zabieg
        v_zabieg := zabieg_t(
            v_id, 
            p_nazwa_zabiegu, 
            SYSDATE, 
            'Standardowy zabieg piel�gnacyjny', 
            v_pracownik_ref, 
            p_koszt
        );
        
        -- Dodajemy zabieg do kolekcji
        UPDATE rosliny r
        SET r.zabiegi = r.zabiegi MULTISET UNION ALL zabiegi_tab_t(v_zabieg)
        WHERE r.id_rosliny = p_id_rosliny;
        
        COMMIT;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20003, 'Nie znaleziono ro�liny lub pracownika');
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20004, 'B��d podczas dodawania zabiegu: ' || SQLERRM);
    END dodaj_zabieg;

    PROCEDURE aktualizuj_stan_zdrowia(
        p_id_rosliny NUMBER,
        p_stan VARCHAR2
    ) IS
        v_count NUMBER;
    BEGIN
        -- Sprawdzamy czy ro�lina istnieje
        SELECT COUNT(*) INTO v_count
        FROM rosliny
        WHERE id_rosliny = p_id_rosliny;
        
        IF v_count = 0 THEN
            RAISE_APPLICATION_ERROR(-20005, 'Nie znaleziono ro�liny o ID: ' || p_id_rosliny);
        END IF;
        
        -- Sprawdzamy poprawno�� stanu zdrowia
        IF p_stan NOT IN ('Dobry', '�redni', 'Z�y', 'Krytyczny') THEN
            RAISE_APPLICATION_ERROR(-20006, 'Nieprawid�owy stan zdrowia. Dozwolone warto�ci: Dobry, �redni, Z�y, Krytyczny');
        END IF;
        
        -- Aktualizujemy stan zdrowia
        UPDATE rosliny r
        SET r.stan_zdrowia = p_stan
        WHERE r.id_rosliny = p_id_rosliny;
        
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            IF SQLCODE NOT IN (-20005, -20006) THEN
                RAISE_APPLICATION_ERROR(-20007, 'B��d podczas aktualizacji stanu zdrowia: ' || SQLERRM);
            ELSE
                RAISE;
            END IF;
    END aktualizuj_stan_zdrowia;

    FUNCTION pobierz_wiek_rosliny(
        p_id_rosliny NUMBER
    ) RETURN NUMBER IS
        v_wiek NUMBER;
    BEGIN
        SELECT r.wiek() INTO v_wiek
        FROM rosliny r
        WHERE r.id_rosliny = p_id_rosliny;
        
        RETURN v_wiek;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20005, 'Nie znaleziono rosliny o podanym ID');
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20006, 'Blad podczas pobierania wieku rosliny: ' || SQLERRM);
    END pobierz_wiek_rosliny;

    FUNCTION pobierz_koszt_utrzymania(
        p_id_rosliny NUMBER
    ) RETURN NUMBER IS
        v_koszt NUMBER;
    BEGIN
        SELECT r.koszt_utrzymania() INTO v_koszt
        FROM rosliny r
        WHERE r.id_rosliny = p_id_rosliny;
        
        RETURN v_koszt;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20007, 'Nie znaleziono rosliny o podanym ID');
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20008, 'Blad podczas pobierania kosztu utrzymania: ' || SQLERRM);
    END pobierz_koszt_utrzymania;

    FUNCTION pobierz_historie_zabiegow(
        p_id_rosliny NUMBER
    ) RETURN zabiegi_tab_t IS
        v_zabiegi zabiegi_tab_t;
    BEGIN
        SELECT r.zabiegi INTO v_zabiegi
        FROM rosliny r
        WHERE r.id_rosliny = p_id_rosliny;
        
        RETURN v_zabiegi;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20009, 'Nie znaleziono rosliny o podanym ID');
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20010, 'Blad podczas pobierania historii zabiegow: ' || SQLERRM);
    END pobierz_historie_zabiegow;
END zarzadzanie_roslinami;
/

-- pakiet do zarzadzania pracownikami
CREATE OR REPLACE PACKAGE zarzadzanie_pracownikami AS
    -- dodawanie nowego pracownika
    PROCEDURE dodaj_pracownika(
        p_imie VARCHAR2,
        p_nazwisko VARCHAR2,
        p_stanowisko VARCHAR2,
        p_telefon VARCHAR2,
        p_email VARCHAR2
    );
    
    -- przypisanie harmonogramu do pracownika
    PROCEDURE przypisz_harmonogram(
        p_pracownik_id NUMBER,
        p_harmonogram_id NUMBER
    );
    
    -- pobranie listy roslin pod opieka pracownika
    FUNCTION pobierz_rosliny_pracownika(
        p_pracownik_id NUMBER
    ) RETURN SYS_REFCURSOR;
    
    -- aktualizacja danych kontaktowych
    PROCEDURE aktualizuj_dane_kontaktowe(
        p_pracownik_id NUMBER,
        p_telefon VARCHAR2,
        p_email VARCHAR2
    );
END zarzadzanie_pracownikami;
/

-- implementacja pakietu zarzadzania pracownikami
CREATE OR REPLACE PACKAGE BODY zarzadzanie_pracownikami AS
    PROCEDURE dodaj_pracownika(
        p_imie VARCHAR2,
        p_nazwisko VARCHAR2,
        p_stanowisko VARCHAR2,
        p_telefon VARCHAR2,
        p_email VARCHAR2
    ) IS
        v_id NUMBER;
    BEGIN
        -- generujemy nowe ID
        SELECT NVL(MAX(id_pracownika), 0) + 1 INTO v_id FROM pracownicy;
        
        -- wstawiamy nowego pracownika
        INSERT INTO pracownicy VALUES (
            pracownik_t(
                v_id,
                p_imie,
                p_nazwisko,
                p_stanowisko,
                SYSDATE,
                NULL, -- harmonogram poczatkowo pusty
                p_telefon,
                p_email
            )
        );
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20003, 'Blad podczas dodawania pracownika: ' || SQLERRM);
    END dodaj_pracownika;

    PROCEDURE przypisz_harmonogram(
        p_pracownik_id NUMBER,
        p_harmonogram_id NUMBER
    ) IS
        v_harmonogram_ref REF harmonogram_t;
    BEGIN
        -- pobieramy referencje do harmonogramu
        SELECT REF(h) INTO v_harmonogram_ref
        FROM harmonogramy h WHERE h.id_harmonogramu = p_harmonogram_id;
        
        -- aktualizujemy harmonogram pracownika
        UPDATE pracownicy p
        SET p.harmonogram = v_harmonogram_ref
        WHERE p.id_pracownika = p_pracownik_id;
        
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20004, 'Blad podczas przypisywania harmonogramu: ' || SQLERRM);
    END przypisz_harmonogram;

    FUNCTION pobierz_rosliny_pracownika(
        p_pracownik_id NUMBER
    ) RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        OPEN v_cursor FOR
        SELECT r.id_rosliny, r.nazwa, DEREF(r.gatunek).nazwa_lacinska as gatunek
        FROM rosliny r
        WHERE DEREF(r.pracownik).id_pracownika = p_pracownik_id;
        
        RETURN v_cursor;
    END pobierz_rosliny_pracownika;

    PROCEDURE aktualizuj_dane_kontaktowe(
        p_pracownik_id NUMBER,
        p_telefon VARCHAR2,
        p_email VARCHAR2
    ) IS
        v_count NUMBER;
    BEGIN
        -- Sprawdzenie czy pracownik istnieje
        SELECT COUNT(*)
        INTO v_count
        FROM pracownicy
        WHERE id_pracownika = p_pracownik_id;
        
        IF v_count = 0 THEN
            RAISE_APPLICATION_ERROR(-20001, 'Nie znaleziono pracownika o ID: ' || p_pracownik_id);
        END IF;
        
        -- Aktualizacja danych kontaktowych
        UPDATE pracownicy p
        SET p.telefon = p_telefon,
            p.email = p_email
        WHERE p.id_pracownika = p_pracownik_id;
        
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20002, 'B��d podczas aktualizacji danych kontaktowych: ' || SQLERRM);
    END aktualizuj_dane_kontaktowe;

END zarzadzanie_pracownikami;
/


CREATE USER botanic_garden IDENTIFIED BY 12345;
GRANT CREATE SESSION, CREATE TABLE, CREATE TRIGGER, CREATE SEQUENCE TO botanic_garden;
GRANT UNLIMITED TABLESPACE TO botanic_garden;

CONNECT botanic_garden/12345;

ALTER SESSION SET CURRENT_SCHEMA = botanic_garden;
--triggery
SHOW USER;
SET SERVEROUTPUT ON;
CREATE OR REPLACE TRIGGER trg_roslina_audit
AFTER INSERT OR UPDATE OR DELETE ON rosliny
FOR EACH ROW
DECLARE
    v_operacja VARCHAR2(10);
BEGIN
    IF INSERTING THEN
        v_operacja := 'INSERT';
    ELSIF UPDATING THEN
        v_operacja := 'UPDATE';
    ELSE
        v_operacja := 'DELETE';
    END IF;
    
    -- tutaj mozna logowac do tabeli audytowej
    -- dla demonstracji uzyjemy dbms_output
    DBMS_OUTPUT.PUT_LINE('Operacja ' || v_operacja || ' na roslinie ID: ' || 
        CASE 
            WHEN INSERTING OR UPDATING THEN :NEW.id_rosliny
            ELSE :OLD.id_rosliny
        END);
END;
/

SELECT object_name, object_type 
FROM user_objects 
WHERE object_type IN ('TABLE', 'TYPE');

SELECT object_name, object_type, status 
FROM user_objects 
WHERE object_name LIKE 'ZARZADZANIE%';

-- przyklad wstawiania danych z referencjami
DECLARE
    v_strefa_ref REF strefa_klimatyczna_t;
    v_lok_ref REF lokalizacja_t;
BEGIN
    -- Najpierw usu�my istniej�ce dane (w odwrotnej kolejno�ci ni� zale�no�ci)
    DELETE FROM rosliny;
    DELETE FROM pracownicy;
    DELETE FROM dostawcy;
    DELETE FROM gatunki;
    DELETE FROM lokalizacje;
    DELETE FROM strefy_klimatyczne;
    
    -- Wstawianie strefy klimatycznej
    INSERT INTO strefy_klimatyczne VALUES (
        strefa_klimatyczna_t(1, 'Strefa umiarkowana', 0, 25, 70)
    );
    
    -- Pobieranie referencji do strefy klimatycznej
    SELECT REF(s) INTO v_strefa_ref
    FROM strefy_klimatyczne s
    WHERE s.id_strefy = 1;
    
    -- Wstawianie lokalizacji
    INSERT INTO lokalizacje VALUES (
        lokalizacja_t(1, 'Szklarnia p�nocna', 100, v_strefa_ref, 'Szklarnia z kontrolowan� temperatur�')
    );
    
    -- Wstawianie gatunku
    INSERT INTO gatunki VALUES (
        gatunek_t(1, 'Phalaenopsis amabilis', 'Storczyk bia�y', 'kwiat', 'Orchidaceae',
        'Popularny storczyk o bia�ych kwiatach')
    );
    
    -- Wstawianie dostawcy
    INSERT INTO dostawcy VALUES (
        dostawca_t(1, 'GreenHouse Sp. z o.o.', '1234567890',
        'ul. Ogrodowa 1, Warszawa', '123456789', 'kontakt@greenhouse.pl')
    );
    
    -- Wstawianie pracownika
    INSERT INTO pracownicy VALUES (
        pracownik_t(1, 'Jan', 'Kowalski', 'Ogrodnik', SYSDATE, NULL, '111222333', 'jan.kowalski@ogrod.pl')
    );
    
    -- Teraz mo�emy doda� ro�lin�
    zarzadzanie_roslinami.dodaj_rosline(
        'Storczyk niebieski',
        1, -- gatunek_id
        1, -- lokalizacja_id
        1, -- pracownik_id
        1, -- dostawca_id
        30  -- wysoko��
    );
    
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Dane zosta�y pomy�lnie dodane');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Wyst�pi� b��d: ' || SQLERRM);
END;
/

-- przyklad danych testowych
DECLARE
    v_strefa_ref1 REF strefa_klimatyczna_t;
    v_strefa_ref2 REF strefa_klimatyczna_t;
    v_lok_ref1 REF lokalizacja_t;
    v_lok_ref2 REF lokalizacja_t;
    v_gatunek_ref1 REF gatunek_t;
    v_harmonogram_ref1 REF harmonogram_t;
    v_pracownik_ref1 REF pracownik_t;
    v_dostawca_ref1 REF dostawca_t;
    
    -- zmienne pomocnicze
    v_zabieg zabieg_t;
    v_etykieta etykieta_t;
    v_zagrozenie zagrozenie_t;
    v_sezon sezon_t;
    v_cursor SYS_REFCURSOR;
    v_roslina_id NUMBER;
    v_koszt NUMBER;
BEGIN
    -- 1. Wstawianie stref klimatycznych
    INSERT INTO strefy_klimatyczne VALUES (
        strefa_klimatyczna_t(101, 'Strefa tropikalna', 20, 35, 80)
    );
    
    INSERT INTO strefy_klimatyczne VALUES (
        strefa_klimatyczna_t(102, 'Strefa umiarkowana', 5, 25, 60)
    );
    
    -- Pobieranie referencji do stref
    SELECT REF(s) INTO v_strefa_ref1
    FROM strefy_klimatyczne s
    WHERE s.id_strefy = 101;
    
    SELECT REF(s) INTO v_strefa_ref2
    FROM strefy_klimatyczne s
    WHERE s.id_strefy = 102;

    -- 2. Wstawianie lokalizacji
    INSERT INTO lokalizacje VALUES (
        lokalizacja_t(101, 'Szklarnia tropikalna', 200, v_strefa_ref1, 'Szklarnia dla ro�lin tropikalnych')
    );
    
    INSERT INTO lokalizacje VALUES (
        lokalizacja_t(102, 'Ogr�d zewn�trzny', 500, v_strefa_ref2, 'Przestrze� dla ro�lin strefy umiarkowanej')
    );
    
    -- Pobieranie referencji do lokalizacji
    SELECT REF(l) INTO v_lok_ref1
    FROM lokalizacje l
    WHERE l.id_lokalizacji = 101;
    
    SELECT REF(l) INTO v_lok_ref2
    FROM lokalizacje l
    WHERE l.id_lokalizacji = 102;

    -- 3. Wstawianie gatunk�w
    INSERT INTO gatunki VALUES (
        gatunek_t(101, 'Phalaenopsis amabilis', 'Storczyk bia�y', 'kwiat', 'Orchidaceae',
        'Popularny storczyk o bia�ych kwiatach')
    );
    
    INSERT INTO gatunki VALUES (
        gatunek_t(102, 'Ficus benjamina', 'Figowiec benjamina', 'drzewo', 'Moraceae',
        'Popularne drzewo doniczkowe')
    );
    
    -- Pobieranie referencji do gatunku
    SELECT REF(g) INTO v_gatunek_ref1
    FROM gatunki g
    WHERE g.id_gatunku = 101;

    -- 4. Wstawianie harmonogram�w
    INSERT INTO harmonogramy VALUES (
        harmonogram_t(101, TO_DATE('2024-01-01', 'YYYY-MM-DD'),
        TO_DATE('2024-12-31', 'YYYY-MM-DD'), '08:00', '16:00')
    );
    
    -- Pobieranie referencji do harmonogramu
    SELECT REF(h) INTO v_harmonogram_ref1
    FROM harmonogramy h
    WHERE h.id_harmonogramu = 101;

    -- 5. Wstawianie dostawc�w
    INSERT INTO dostawcy VALUES (
        dostawca_t(101, 'GreenHouse Sp. z o.o.', '1234567890',
        'ul. Ogrodowa 1, Warszawa', '123456789', 'kontakt@greenhouse.pl')
    );
    
    -- Pobieranie referencji do dostawcy
    SELECT REF(d) INTO v_dostawca_ref1
    FROM dostawcy d
    WHERE d.id_dostawcy = 101;

    -- 6. Dodawanie pracownik�w przez pakiet
    zarzadzanie_pracownikami.dodaj_pracownika(
        'Jan', 'Kowalski', 'Ogrodnik', '111222333', 'jan.kowalski@ogrod.pl'
    );
    
    -- Przypisanie harmonogramu do pracownika
    zarzadzanie_pracownikami.przypisz_harmonogram(101, 101);
    
    -- 7. Dodawanie ro�lin przez pakiet
    BEGIN
        zarzadzanie_roslinami.dodaj_rosline(
            'Storczyk Bia�y #1',
            101, -- gatunek_id
            101, -- lokalizacja_id
            101, -- pracownik_id
            101, -- dostawca_id
            30  -- wysoko��
        );
    END;
    
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Wszystkie dane testowe zosta�y pomy�lnie dodane');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Wyst�pi� b��d podczas dodawania danych testowych: ' || SQLERRM);
        RAISE;
END;
/

-- przyklad zapytan demonstracyjnych
-- 1. pobranie wszystkich roslin wraz z ich lokalizacjami
SELECT r.id_rosliny, r.nazwa, 
       DEREF(r.lokalizacja).nazwa as lokalizacja,
       DEREF(r.gatunek).nazwa_lacinska as gatunek
FROM rosliny r;

-- 2. pobranie wszystkich pracownikow i ich harmonogramow
SELECT p.imie, p.nazwisko, 
       DEREF(p.harmonogram).godziny_od as godziny_od,
       DEREF(p.harmonogram).godziny_do as godziny_do
FROM pracownicy p;

-- 3. pobranie roslin z ich zabiegami
SELECT r.nazwa, z.*
FROM rosliny r, TABLE(r.zabiegi) z;

-- 4. pobranie roslin w okreslonej strefie klimatycznej
SELECT r.nazwa, DEREF(r.lokalizacja).nazwa as lokalizacja,
       DEREF(DEREF(r.lokalizacja).strefa).nazwa as strefa_klimatyczna
FROM rosliny r;