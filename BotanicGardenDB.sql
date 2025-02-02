CREATE USER ogrod_botaniczny IDENTIFIED BY 12345;
GRANT CREATE SESSION, CREATE TABLE, CREATE TRIGGER, CREATE SEQUENCE TO ogrod_botaniczny;
GRANT UNLIMITED TABLESPACE TO ogrod_botaniczny;

ALTER SESSION SET CURRENT_SCHEMA = ogrod_botaniczny;

/* 
    FILE STRUCTURE
    - tworzenie typow
    - tworzenie tabel
    - triggery
    - pakiety
    - wstawianie danych
*/

/* **************************************************************************************************************************************************************************************************************************** */
-- TWORZENIE TYPOW
/* **************************************************************************************************************************************************************************************************************************** */

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

-- typ dla pracownika
CREATE TYPE pracownik_t AS OBJECT (
    id_pracownika NUMBER,
    imie VARCHAR2(50),
    nazwisko VARCHAR2(50),
    stanowisko VARCHAR2(50),
    data_zatrudnienia DATE,
    telefon VARCHAR2(20),
    email VARCHAR2(100),
    placa NUMBER
);

-- typ dla harmonogramu pracy
CREATE OR REPLACE TYPE harmonogram_t AS OBJECT (
    id_harmonogramu NUMBER,
    id_pracownika REF pracownik_t,
    godzina_od NUMBER,
    godzina_do NUMBER,
    
    -- metoda do sprawdzenia godzin
    CONSTRUCTOR FUNCTION harmonogram_t(
        id_harmonogramu NUMBER,
        id_pracownika REF pracownik_t,
        godzina_od NUMBER,
        godzina_do NUMBER
    ) RETURN SELF AS RESULT
);


CREATE OR REPLACE TYPE BODY harmonogram_t AS
    CONSTRUCTOR FUNCTION harmonogram_t(
        id_harmonogramu NUMBER,
        id_pracownika REF pracownik_t,
        godzina_od NUMBER,
        godzina_do NUMBER
    ) RETURN SELF AS RESULT IS
    BEGIN
        -- Sprawdzenie ograniczeďż˝
        IF godzina_od < 6 THEN
            RAISE_APPLICATION_ERROR(-20002, 'Godzina rozpoczecia nie moze byc wczesniejsza niz 6:00');
        END IF;
        
        IF godzina_do > 20 THEN
            RAISE_APPLICATION_ERROR(-20003, 'Godzina zakonczenia nie moze byc pozniejsza niz 20:00');
        END IF;
        
        IF (godzina_do - godzina_od) > 10 THEN
            RAISE_APPLICATION_ERROR(-20004, 'Czas pracy nie moze przekraczac 10 godzin');
        END IF;
        
        self.id_harmonogramu := id_harmonogramu;
        self.id_pracownika := id_pracownika;
        self.godzina_od := godzina_od;
        self.godzina_do := godzina_do;
        
        RETURN;
    END;
END;
/


-- typ dla zabiegu pielgnacyjnego
CREATE OR REPLACE TYPE zabieg_t AS OBJECT (
    id_zabiegu NUMBER,
    nazwa VARCHAR2(100),
    data_zabiegu DATE,  
    czas_trwania NUMBER, -- w minutach
    status VARCHAR2(20), -- np. 'ZAPLANOWANY', 'W TRAKCIE', 'ZAKONCZONY'
    koszt NUMBER,
    
    -- metoda do aktualizacji statusu
    MEMBER PROCEDURE aktualizuj_status(nowy_status VARCHAR2)
);
/

CREATE OR REPLACE TYPE BODY zabieg_t AS
    MEMBER PROCEDURE aktualizuj_status(nowy_status VARCHAR2) IS
    BEGIN
        IF nowy_status IN ('ZAPLANOWANY', 'W TRAKCIE', 'ZAKONCZONY') THEN
            self.status := nowy_status;
        ELSE
            RAISE_APPLICATION_ERROR(-20001, 'Nieprawidlowy status zabiegu');
        END IF;
    END;
END;
/

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

-- typ dla elementow magazynowych
CREATE OR REPLACE TYPE element_magazynowy_t AS OBJECT (
    id NUMBER,
    nazwa VARCHAR2(100),
    kategoria VARCHAR2(50),
    ilosc NUMBER,
    jednostka VARCHAR2(20),
    stan_magazynowy NUMBER,
    data_dodania DATE,
    
    MEMBER FUNCTION czy_niski_stan RETURN BOOLEAN
);
/

CREATE OR REPLACE TYPE BODY element_magazynowy_t AS
    MEMBER FUNCTION czy_niski_stan RETURN BOOLEAN IS
    BEGIN
        RETURN self.stan_magazynowy < 10; -- zakladamy iz jesli jest mniej niz 10 to jest niski stan, procentowo
    END;
END;
/
/* **************************************************************************************************************************************************************************************************************************** */
-- TWORZENIE TABEL
/* **************************************************************************************************************************************************************************************************************************** */

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

CREATE TABLE magazyn OF element_magazynowy_t (
    PRIMARY KEY (id)
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

/* **************************************************************************************************************************************************************************************************************************** */
-- TWORZENIE TRIGGEROW
/* **************************************************************************************************************************************************************************************************************************** */

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
    DBMS_OUTPUT.PUT_LINE('Operacja ' || v_operacja || ' na roslinie ID: ' || 
        CASE 
            WHEN INSERTING OR UPDATING THEN :NEW.id_rosliny
            ELSE :OLD.id_rosliny
        END);
END;
/

/* **************************************************************************************************************************************************************************************************************************** */
-- TWORZENIE PACKIETOW
/* **************************************************************************************************************************************************************************************************************************** */

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
    
    -- procedura do zmiany statusu rosliny
    PROCEDURE aktualizuj_status_zabiegu(
        p_id_zabiegu NUMBER,
        p_id_pracownika NUMBER,
        p_nowy_status VARCHAR2
    );
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
        SELECT NVL(MAX(id_rosliny), 0) + 1 INTO v_id FROM rosliny; -- sekwencje
        
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
        -- ref do pracownika
        SELECT REF(p) INTO v_pracownik_ref
        FROM pracownicy p 
        WHERE p.id_pracownika = p_pracownik_id;
        
        -- nowe ID dla zabiegu
        SELECT NVL(MAX(z.id_zabiegu), 0) + 1 INTO v_id
        FROM TABLE(SELECT r.zabiegi FROM rosliny r WHERE r.id_rosliny = p_id_rosliny) z;
        
        -- nowy zabieg
        v_zabieg := zabieg_t(
            v_id, 
            p_nazwa_zabiegu, 
            SYSDATE, 
            p_czas_trwania, 
            'ZAPLANOWANY', -- default status
            p_koszt
        );
        
        -- dod zabieg do kolekcji
        UPDATE rosliny r
        SET r.zabiegi = r.zabiegi MULTISET UNION ALL zabiegi_tab_t(v_zabieg)
        WHERE r.id_rosliny = p_id_rosliny;
        
        COMMIT;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20003, 'Nie znaleziono rosliny lub pracownika');
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20004, 'Blad podczas dodawania zabiegu: ' || SQLERRM);
    END dodaj_zabieg;

    PROCEDURE aktualizuj_stan_zdrowia(
        p_id_rosliny NUMBER,
        p_stan VARCHAR2
    ) IS
        v_count NUMBER;
    BEGIN
        -- sprawdzenie czy roslina istnieje
        SELECT COUNT(*) INTO v_count
        FROM rosliny
        WHERE id_rosliny = p_id_rosliny;
        
        IF v_count = 0 THEN
            RAISE_APPLICATION_ERROR(-20005, 'Nie znaleziono rosliny o ID: ' || p_id_rosliny);
        END IF;
        
        -- sprawdzenie poprawnosci stanu zdrowia
        IF p_stan NOT IN ('Dobry', 'Sredni', 'Zly', 'Krytyczny') THEN
            RAISE_APPLICATION_ERROR(-20006, 'Nieprawidlowa wartosc stanu zdrowia. Dozwolone wartosci: Dobry, Sredni, Zly, Krytyczny');
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
                RAISE_APPLICATION_ERROR(-20007, 'Blad podczas aktualizacji stanu zdrowia: ' || SQLERRM);
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
    
    
    -- aktualizacja stanu zabiegow
    PROCEDURE aktualizuj_status_zabiegu(
        p_id_zabiegu NUMBER,
        p_id_pracownika NUMBER,
        p_nowy_status VARCHAR2
    ) IS
        v_zabieg zabieg_t;
    BEGIN
        -- sprawdzenie czy pracownik ma przypisany ten zabieg
        SELECT z.*
        INTO v_zabieg
        FROM zabiegi z
        WHERE z.id_zabiegu = p_id_zabiegu
        AND z.id_pracownika = p_id_pracownika;
        
        v_zabieg.aktualizuj_status(p_nowy_status);
        
        -- 
        UPDATE zabiegi z
        SET z.status = p_nowy_status
        WHERE z.id_zabiegu = p_id_zabiegu;
        
        COMMIT;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20006, 'Nie znaleziono zabiegu lub brak uprawnieďż˝');
    END;
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
    
    -- magazyn
    PROCEDURE dodaj_do_magazynu(
        p_nazwa VARCHAR2,
        p_kategoria VARCHAR2,
        p_ilosc NUMBER,
        p_jednostka VARCHAR2
    );

    PROCEDURE zuzyj_z_magazynu(
        p_id NUMBER,
        p_ilosc NUMBER
    );

    FUNCTION raport_magazynowy RETURN SYS_REFCURSOR;

    PROCEDURE inicjuj_magazyn;
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
        -- sprawdzenie czy pracownik istnieje
        SELECT COUNT(*)
        INTO v_count
        FROM pracownicy
        WHERE id_pracownika = p_pracownik_id;
        
        IF v_count = 0 THEN
            RAISE_APPLICATION_ERROR(-20001, 'Nie znaleziono pracownika o ID: ' || p_pracownik_id);
        END IF;
        
        -- aktualizacja danych kontaktowych
        UPDATE pracownicy p
        SET p.telefon = p_telefon,
            p.email = p_email
        WHERE p.id_pracownika = p_pracownik_id;
        
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20002, 'Blad podczas aktualizacji danych kontaktowych: ' || SQLERRM);
    END aktualizuj_dane_kontaktowe;
    
    
     -- dodawanie elementu do magazynu
    PROCEDURE dodaj_do_magazynu(
        p_nazwa VARCHAR2,
        p_kategoria VARCHAR2,
        p_ilosc NUMBER,
        p_jednostka VARCHAR2
    ) IS
        v_id NUMBER;
    BEGIN
        -- generowanie ID
        SELECT NVL(MAX(id), 0) + 1 INTO v_id 
        FROM TABLE(magazyn);

        -- dodanie elementu do magazynu
        magazyn.EXTEND;
        magazyn(magazyn.LAST) := element_magazynowy_t(
            v_id,
            p_nazwa,
            p_kategoria,
            p_ilosc,
            p_jednostka,
            p_ilosc,  -- poczatkowy stan magazynowy
            SYSDATE
        );
    END dodaj_do_magazynu;

    -- zuzycie elementu z magazynu
    PROCEDURE zuzyj_z_magazynu(
        p_id NUMBER,
        p_ilosc NUMBER
    ) IS
        v_index NUMBER;
    BEGIN
        -- szukamy indeks elementu
        FOR i IN 1..magazyn.COUNT LOOP
            IF magazyn(i).id = p_id THEN
                v_index := i;
                EXIT;
            END IF;
        END LOOP;

        -- sprawdzenie czy wystarcza w magazynie
        IF v_index IS NOT NULL THEN
            IF magazyn(v_index).stan_magazynowy >= p_ilosc THEN
                magazyn(v_index).stan_magazynowy := 
                    magazyn(v_index).stan_magazynowy - p_ilosc;
            ELSE
                RAISE_APPLICATION_ERROR(-20005, 
                    'Niewystarczajďż˝ca ilosc˝ w magazynie');
            END IF;
        ELSE
            RAISE_APPLICATION_ERROR(-20006, 
                'Nie znaleziono elementu w magazynie');
        END IF;
    END zuzyj_z_magazynu;

    -- raport z magazynu
    FUNCTION raport_magazynowy RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        OPEN v_cursor FOR
        SELECT 
            id, 
            nazwa, 
            kategoria, 
            stan_magazynowy,
            jednostka
        FROM TABLE(magazyn)
        WHERE stan_magazynowy < 10;  -- elementy o niskim stanie

        RETURN v_cursor;
    END raport_magazynowy;

    -- inicjalizacja magazynu
    PROCEDURE inicjuj_magazyn IS
    BEGIN
        magazyn := elements_magazynowe_tab();
    END inicjuj_magazyn;
END zarzadzanie_pracownikami;
/
-- sprawdzenie czy dostepny pracownik przed dodaniem zabiegu
CREATE OR REPLACE PACKAGE zarzadzanie_zabiegami AS
    FUNCTION sprawdz_dostepnosc_pracownika(
        p_id_pracownika NUMBER,
        p_data_zabiegu DATE,
        p_czas_trwania NUMBER
    ) RETURN BOOLEAN;
    
    -- dodwanie zabiegu do harmonogramu pracownika
    PROCEDURE dodaj_zabieg_do_harmonogramu(
        p_id_pracownika NUMBER,
        p_zabieg IN OUT zabieg_t
    );
END zarzadzanie_zabiegami;
/

CREATE OR REPLACE PACKAGE BODY zarzadzanie_zabiegami AS
    FUNCTION sprawdz_dostepnosc_pracownika(
        p_id_pracownika NUMBER,
        p_data_zabiegu DATE,
        p_czas_trwania NUMBER
    ) RETURN BOOLEAN IS
        v_godzina_zabiegu NUMBER;
        v_godzina_zakonczenia NUMBER;
        v_harmonogram_exists NUMBER;
        v_konflikt_zabiegow NUMBER;
    BEGIN
        -- pobieramy godzine z daty zabiegu
        v_godzina_zabiegu := TO_NUMBER(TO_CHAR(p_data_zabiegu, 'HH24'));
        v_godzina_zakonczenia := v_godzina_zabiegu + (p_czas_trwania / 60);
        
        -- sprawdzamy czy pracownik ma harmonogram na dany dzien
        SELECT COUNT(*)
        INTO v_harmonogram_exists
        FROM TABLE(SELECT harmonogramy FROM pracownicy WHERE id_pracownika = p_id_pracownika) h
        WHERE h.godzina_od <= v_godzina_zabiegu
        AND h.godzina_do >= v_godzina_zakonczenia;
        
        IF v_harmonogram_exists = 0 THEN
            RETURN FALSE;
        END IF;
        
        -- sprawdzenie czy nie ma konfliktu z innymi zabiegami
        SELECT COUNT(*)
        INTO v_konflikt_zabiegow
        FROM zabiegi z
        WHERE z.id_pracownika = p_id_pracownika
        AND TRUNC(z.data_zabiegu) = TRUNC(p_data_zabiegu)
        AND (
            (v_godzina_zabiegu BETWEEN TO_NUMBER(TO_CHAR(z.data_zabiegu, 'HH24')) 
                AND TO_NUMBER(TO_CHAR(z.data_zabiegu, 'HH24')) + (z.czas_trwania / 60))
            OR
            (v_godzina_zakonczenia BETWEEN TO_NUMBER(TO_CHAR(z.data_zabiegu, 'HH24')) 
                AND TO_NUMBER(TO_CHAR(z.data_zabiegu, 'HH24')) + (z.czas_trwania / 60))
        );
        
        RETURN (v_konflikt_zabiegow = 0);
    END;
    
    PROCEDURE dodaj_zabieg_do_harmonogramu(
        p_id_pracownika NUMBER,
        p_zabieg IN OUT zabieg_t
    ) IS
    BEGIN
        IF NOT sprawdz_dostepnosc_pracownika(
            p_id_pracownika, 
            p_zabieg.data_zabiegu, 
            p_zabieg.czas_trwania
        ) THEN
            RAISE_APPLICATION_ERROR(-20005, 'Pracownik nie jest dostepny w tym terminie');
        END IF;
        
        p_zabieg.status := 'ZAPLANOWANY';
        INSERT INTO zabiegi VALUES p_zabieg;
    
    COMMIT;
        
    END;
END zarzadzanie_zabiegami;
/

CREATE OR REPLACE PACKAGE zarzadzanie_magazynem AS
    PROCEDURE dodaj_do_magazynu(
        p_nazwa VARCHAR2,
        p_kategoria VARCHAR2,
        p_ilosc NUMBER,
        p_jednostka VARCHAR2
    );
    
    PROCEDURE uzyj_z_magazynu(
        p_id NUMBER,
        p_ilosc NUMBER
    );
    
    FUNCTION sprawdz_braki_magazynowe RETURN SYS_REFCURSOR;
END zarzadzanie_magazynem;
/

CREATE OR REPLACE PACKAGE BODY zarzadzanie_magazynem AS
    PROCEDURE dodaj_do_magazynu(
        p_nazwa VARCHAR2,
        p_kategoria VARCHAR2,
        p_ilosc NUMBER,
        p_jednostka VARCHAR2
    ) IS
        v_count number;
        v_id NUMBER;
    BEGIN
        -- sprawdzamy czy juz jest w bazie
        SELECT COUNT(*) INTO v_count
        FROM magazyn
        WHERE nazwa = p_nazwa AND kategoria = p_kategoria;
    
        IF v_count > 0 THEN
            RAISE_APPLICATION_ERROR(-20004, 'Przedmiot już istnieje w magazynie');
        END IF;
    
        SELECT NVL(MAX(id), 0) + 1 INTO v_id FROM magazyn;
        
        INSERT INTO magazyn VALUES (
            element_magazynowy_t(
                v_id,
                p_nazwa,
                p_kategoria,
                p_ilosc,
                p_jednostka,
                p_ilosc, -- initial wartosc
                SYSDATE
            )
        );
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20001, 'Blad podczas dodawania do magazynu: ' || SQLERRM);
    END dodaj_do_magazynu;

    PROCEDURE uzyj_z_magazynu(
        p_id NUMBER,
        p_ilosc NUMBER
    ) IS
    BEGIN
        UPDATE magazyn
        SET stan_magazynowy = stan_magazynowy - p_ilosc
        WHERE id = p_id;
        
        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20002, 'Nie znaleziono przedmiotu w magazynie');
        END IF;
        
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20003, 'Błąd podczas używania z magazynu: ' || SQLERRM);
    END uzyj_z_magazynu;

    FUNCTION sprawdz_braki_magazynowe RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        OPEN v_cursor FOR
        SELECT id, nazwa, kategoria, stan_magazynowy, jednostka
        FROM magazyn
        WHERE stan_magazynowy < 10; -- niski kiedy < 10
        
        RETURN v_cursor;
    END sprawdz_braki_magazynowe;
END zarzadzanie_magazynem;
/

INSERT INTO strefy_klimatyczne VALUES (
    strefa_klimatyczna_t(1, 'Strefa tropikalna', 20, 35, 80)
);

INSERT INTO strefy_klimatyczne VALUES (
    strefa_klimatyczna_t(2, 'Strefa umiarkowana', 5, 25, 60)
);

INSERT INTO strefy_klimatyczne VALUES (
    strefa_klimatyczna_t(3, 'Strefa sucha', 30, 45, 30)
);

--------------------------------------------------------------------
DECLARE
    v_strefa_tropikalna REF strefa_klimatyczna_t;
    v_strefa_umiarkowana REF strefa_klimatyczna_t;
    v_strefa_sucha REF strefa_klimatyczna_t;
BEGIN
    SELECT REF(s) INTO v_strefa_tropikalna FROM strefy_klimatyczne s WHERE s.id_strefy = 1;
    SELECT REF(s) INTO v_strefa_umiarkowana FROM strefy_klimatyczne s WHERE s.id_strefy = 2;
    SELECT REF(s) INTO v_strefa_sucha FROM strefy_klimatyczne s WHERE s.id_strefy = 3;

    INSERT INTO lokalizacje VALUES (
        lokalizacja_t(1, 'Szklarnia Tropikalna', 250, v_strefa_tropikalna, 'Specjalistyczna szklarnia dla roślin tropikalnych')
    );

    INSERT INTO lokalizacje VALUES (
        lokalizacja_t(2, 'Ogród Alpinarium', 500, v_strefa_umiarkowana, 'Przestrzeń dla roślin górskich i chłodnych')
    );

    INSERT INTO lokalizacje VALUES (
        lokalizacja_t(3, 'Kolekcja Kaktusów', 100, v_strefa_sucha, 'Specjalistyczna przestrzeń dla sukulentów')
    );
END;
/

------------------------------------------------------------------------
INSERT INTO gatunki VALUES (
    gatunek_t(1, 'Monstera deliciosa', 'Monstera', 'roślina doniczkowa', 'Araceae', 'Popularna roślina doniczkowa o dużych, dziurkowanych liściach')
);

INSERT INTO gatunki VALUES (
    gatunek_t(2, 'Phalaenopsis amabilis', 'Storczyk biały', 'kwiat', 'Orchidaceae', 'Elegancki storczyk o białych kwiatach')
);

INSERT INTO gatunki VALUES (
    gatunek_t(3, 'Opuntia ficus-indica', 'Kaktus figowy', 'kaktus', 'Cactaceae', 'Popularny kaktus o jadalnych owocach')
);

-----------------------------------------------------------------------
INSERT INTO dostawcy VALUES (
    dostawca_t(1, 'GreenHouse Sp. z o.o.', '1234567890', 'ul. Ogrodowa 15, Warszawa', '22 123 45 67', 'kontakt@greenhouse.pl')
);

INSERT INTO dostawcy VALUES (
    dostawca_t(2, 'Egzotyka Plants', '9876543210', 'ul. Tropikalna 7, Kraków', '12 987 65 43', 'biuro@egzotyka.pl')
);

-----------------------------------------------------------------------
INSERT INTO pracownicy VALUES (
    pracownik_t(1, 'Jan', 'Kowalski', 'Główny Ogrodnik', SYSDATE, '501 234 567', 'jan.kowalski@ogrod.pl', 5000)
);

INSERT INTO pracownicy VALUES (
    pracownik_t(2, 'Anna', 'Nowak', 'Specjalista ds. Roślin Egzotycznych', SYSDATE, '602 345 678', 'anna.nowak@ogrod.pl', 4500)
);

-----------------------------------------------------------------------
DECLARE
    v_pracownik_ref REF pracownik_t;
BEGIN
    SELECT REF(p) INTO v_pracownik_ref FROM pracownicy p WHERE p.id_pracownika = 1;

    INSERT INTO harmonogramy VALUES (
        harmonogram_t(1, v_pracownik_ref, 8, 16)
    );

    SELECT REF(p) INTO v_pracownik_ref FROM pracownicy p WHERE p.id_pracownika = 2;

    INSERT INTO harmonogramy VALUES (
        harmonogram_t(2, v_pracownik_ref, 9, 17)
    );
END;
/

------------------------------------------------------------------------
DECLARE
    v_gatunek_ref REF gatunek_t;
    v_lokalizacja_ref REF lokalizacja_t;
    v_pracownik_ref REF pracownik_t;
    v_dostawca_ref REF dostawca_t;
BEGIN
    SELECT REF(g) INTO v_gatunek_ref FROM gatunki g WHERE g.id_gatunku = 1;
    SELECT REF(l) INTO v_lokalizacja_ref FROM lokalizacje l WHERE l.id_lokalizacji = 1;
    SELECT REF(p) INTO v_pracownik_ref FROM pracownicy p WHERE p.id_pracownika = 1;
    SELECT REF(d) INTO v_dostawca_ref FROM dostawcy d WHERE d.id_dostawcy = 1;

    INSERT INTO rosliny VALUES (
        roslina_t(
            1, 
            'Monstera Olbrzymia', 
            v_gatunek_ref, 
            v_lokalizacja_ref, 
            v_pracownik_ref, 
            v_dostawca_ref, 
            SYSDATE - 365, 
            150, 
            'Dobry',
            zabiegi_tab_t(),
            etykiety_tab_t(),
            zagrozenia_tab_t(),
            sezony_tab_t()
        )
    );
END;
/

---------------------------------------------------------------------------
---------------------------------------------------------------------------
SELECT * FROM strefy_klimatyczne;

SELECT l.id_lokalizacji, l.nazwa, DEREF(l.strefa).nazwa AS strefa_klimatyczna
FROM lokalizacje l;

SELECT * FROM gatunki;

SELECT * FROM dostawcy;

SELECT * FROM pracownicy;

SELECT h.id_harmonogramu, DEREF(h.id_pracownika).imie AS pracownik, h.godzina_od, h.godzina_do
FROM harmonogramy h;

SELECT r.id_rosliny, r.nazwa, DEREF(r.gatunek).nazwa_lacinska AS gatunek, DEREF(r.lokalizacja).nazwa AS lokalizacja
FROM rosliny r;

SELECT * FROM magazyn;

SELECT z.id_zabiegu, z.nazwa, z.data_zabiegu, z.status
FROM TABLE(SELECT r.zabiegi FROM rosliny r WHERE r.id_rosliny = 1) z;