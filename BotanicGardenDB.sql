-- Typ dla strefy klimatycznej
CREATE TYPE strefa_klimatyczna_t AS OBJECT (
    id_strefy NUMBER,
    nazwa VARCHAR2(100),
    min_temperatura NUMBER,
    max_temperatura NUMBER,
    wilgotnosc NUMBER
);

-- Typ dla lokalizacji
CREATE TYPE lokalizacja_t AS OBJECT (
    id_lokalizacji NUMBER,
    nazwa VARCHAR2(100),
    powierzchnia NUMBER,
    strefa REF strefa_klimatyczna_t,
    opis VARCHAR2(500)
);

-- Typ dla gatunku
CREATE TYPE gatunek_t AS OBJECT (
    id_gatunku NUMBER,
    nazwa_lacinska VARCHAR2(100),
    nazwa_zwyczajowa VARCHAR2(100),
    rodzaj VARCHAR2(50), -- drzewo, krzew, kwiat itp.
    rodzina VARCHAR2(100),
    opis CLOB
);

-- Typ dla etykiety
CREATE TYPE etykieta_t AS OBJECT (
    id_etykiety NUMBER,
    nazwa VARCHAR2(100),
    opis VARCHAR2(500)
);

-- Kolekcja etykiet
CREATE TYPE etykiety_tab_t AS TABLE OF etykieta_t;

-- Typ dla zagro¿enia
CREATE TYPE zagrozenie_t AS OBJECT (
    id_zagrozenia NUMBER,
    nazwa VARCHAR2(100),
    typ VARCHAR2(50), -- szkodnik, choroba, warunki pogodowe
    poziom_ryzyka VARCHAR2(20),
    opis VARCHAR2(500)
);

-- Kolekcja zagro¿eñ
CREATE TYPE zagrozenia_tab_t AS TABLE OF zagrozenie_t;

-- Typ dla sezonu
CREATE TYPE sezon_t AS OBJECT (
    id_sezonu NUMBER,
    nazwa VARCHAR2(50),
    data_rozpoczecia DATE,
    data_zakonczenia DATE,
    typ VARCHAR2(50) -- kwitnienie, owocowanie, pielêgnacja
);

-- Kolekcja sezonów
CREATE TYPE sezony_tab_t AS TABLE OF sezon_t;

-- Typ dla dostawcy
CREATE TYPE dostawca_t AS OBJECT (
    id_dostawcy NUMBER,
    nazwa VARCHAR2(100),
    nip VARCHAR2(10),
    adres VARCHAR2(200),
    telefon VARCHAR2(20),
    email VARCHAR2(100)
);

-- Typ dla harmonogramu pracy
CREATE TYPE harmonogram_t AS OBJECT (
    id_harmonogramu NUMBER,
    data_od DATE,
    data_do DATE,
    godziny_od VARCHAR2(5),
    godziny_do VARCHAR2(5)
);

-- Typ dla pracownika
CREATE TYPE pracownik_t AS OBJECT (
    id_pracownika NUMBER,
    imie VARCHAR2(50),
    nazwisko VARCHAR2(50),
    stanowisko VARCHAR2(50),
    data_zatrudnienia DATE,
    harmonogram REF harmonogram_t,
    telefon VARCHAR2(20),
    email VARCHAR2(100)
);

-- Typ dla zabiegu pielêgnacyjnego
CREATE TYPE zabieg_t AS OBJECT (
    id_zabiegu NUMBER,
    nazwa VARCHAR2(100),
    data DATE,
    opis VARCHAR2(500),
    pracownik REF pracownik_t,
    koszt NUMBER
);

-- Kolekcja zabiegów
CREATE TYPE zabiegi_tab_t AS TABLE OF zabieg_t;

-- Typ dla roœliny (g³ówny obiekt)
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
    
    -- Metody
    MEMBER FUNCTION wiek RETURN NUMBER,
    MEMBER FUNCTION koszt_utrzymania RETURN NUMBER,
    MEMBER PROCEDURE dodaj_zabieg(p_zabieg zabieg_t),
    MEMBER PROCEDURE dodaj_etykiete(p_etykieta etykieta_t),
    MEMBER PROCEDURE dodaj_zagrozenie(p_zagrozenie zagrozenie_t)
);


---------
-- Tworzenie tabel dla podstawowych typów
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

-- Tabela g³ówna dla roœlin
CREATE TABLE rosliny OF roslina_t (
    PRIMARY KEY (id_rosliny)
);

NESTED TABLE zabiegi STORE AS zabiegi_tab,
NESTED TABLE etykiety STORE AS etykiety_tab,
NESTED TABLE zagrozenia STORE AS zagrozenia_tab,
NESTED TABLE sezony STORE AS sezony_tab;

-------------------------------------------------------

-- Pakiet do zarz¹dzania roœlinami
CREATE OR REPLACE PACKAGE zarzadzanie_roslinami AS
    -- Dodawanie nowej roœliny
    PROCEDURE dodaj_rosline(
        p_nazwa VARCHAR2,
        p_gatunek_id NUMBER,
        p_lokalizacja_id NUMBER,
        p_pracownik_id NUMBER,
        p_dostawca_id NUMBER,
        p_wysokosc NUMBER
    );
    
    -- Przenoszenie roœliny do nowej lokalizacji
    PROCEDURE przenies_rosline(
        p_id_rosliny NUMBER,
        p_nowa_lokalizacja_id NUMBER
    );
    
    -- Dodawanie zabiegu pielêgnacyjnego
    PROCEDURE dodaj_zabieg(
        p_id_rosliny NUMBER,
        p_nazwa_zabiegu VARCHAR2,
        p_pracownik_id NUMBER,
        p_koszt NUMBER
    );
    
    -- Aktualizacja stanu zdrowia roœliny
    PROCEDURE aktualizuj_stan_zdrowia(
        p_id_rosliny NUMBER,
        p_stan VARCHAR2
    );
    
    -- Pobranie wieku roœliny
    FUNCTION pobierz_wiek_rosliny(
        p_id_rosliny NUMBER
    ) RETURN NUMBER;
    
    -- Pobranie ca³kowitego kosztu utrzymania roœliny
    FUNCTION pobierz_koszt_utrzymania(
        p_id_rosliny NUMBER
    ) RETURN NUMBER;
    
    -- Pobranie historii zabiegów
    FUNCTION pobierz_historie_zabiegow(
        p_id_rosliny NUMBER
    ) RETURN zabiegi_tab_t;
END zarzadzanie_roslinami;
/

-- Implementacja pakietu zarz¹dzania roœlinami
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
        
        -- Generujemy nowe ID
        SELECT NVL(MAX(id_rosliny), 0) + 1 INTO v_id FROM rosliny;
        
        -- Wstawiamy now¹ roœlinê
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
            RAISE_APPLICATION_ERROR(-20001, 'B³¹d podczas dodawania roœliny: ' || SQLERRM);
    END dodaj_rosline;

    PROCEDURE przenies_rosline(
        p_id_rosliny NUMBER,
        p_nowa_lokalizacja_id NUMBER
    ) IS
        v_lokalizacja_ref REF lokalizacja_t;
    BEGIN
        -- Pobieramy referencjê do nowej lokalizacji
        SELECT REF(l) INTO v_lokalizacja_ref
        FROM lokalizacje l WHERE l.id_lokalizacji = p_nowa_lokalizacja_id;
        
        -- Aktualizujemy lokalizacjê roœliny
        UPDATE rosliny r
        SET r.lokalizacja = v_lokalizacja_ref
        WHERE r.id_rosliny = p_id_rosliny;
        
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20002, 'B³¹d podczas przenoszenia roœliny: ' || SQLERRM);
    END przenies_rosline;

    -- Pozosta³e implementacje funkcji...
END zarzadzanie_roslinami;
/

-- Pakiet do zarz¹dzania pracownikami
CREATE OR REPLACE PACKAGE zarzadzanie_pracownikami AS
    -- Dodawanie nowego pracownika
    PROCEDURE dodaj_pracownika(
        p_imie VARCHAR2,
        p_nazwisko VARCHAR2,
        p_stanowisko VARCHAR2,
        p_telefon VARCHAR2,
        p_email VARCHAR2
    );
    
    -- Przypisanie harmonogramu do pracownika
    PROCEDURE przypisz_harmonogram(
        p_pracownik_id NUMBER,
        p_harmonogram_id NUMBER
    );
    
    -- Pobranie listy roœlin pod opiek¹ pracownika
    FUNCTION pobierz_rosliny_pracownika(
        p_pracownik_id NUMBER
    ) RETURN SYS_REFCURSOR;
    
    -- Aktualizacja danych kontaktowych
    PROCEDURE aktualizuj_dane_kontaktowe(
        p_pracownik_id NUMBER,
        p_telefon VARCHAR2,
        p_email VARCHAR2
    );
END zarzadzanie_pracownikami;
/

-- Implementacja pakietu zarz¹dzania pracownikami
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
        -- Generujemy nowe ID
        SELECT NVL(MAX(id_pracownika), 0) + 1 INTO v_id FROM pracownicy;
        
        -- Wstawiamy nowego pracownika
        INSERT INTO pracownicy VALUES (
            pracownik_t(
                v_id,
                p_imie,
                p_nazwisko,
                p_stanowisko,
                SYSDATE,
                NULL, -- harmonogram pocz¹tkowo pusty
                p_telefon,
                p_email
            )
        );
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20003, 'B³¹d podczas dodawania pracownika: ' || SQLERRM);
    END dodaj_pracownika;

    PROCEDURE przypisz_harmonogram(
        p_pracownik_id NUMBER,
        p_harmonogram_id NUMBER
    ) IS
        v_harmonogram_ref REF harmonogram_t;
    BEGIN
        -- Pobieramy referencjê do harmonogramu
        SELECT REF(h) INTO v_harmonogram_ref
        FROM harmonogramy h WHERE h.id_harmonogramu = p_harmonogram_id;
        
        -- Aktualizujemy harmonogram pracownika
        UPDATE pracownicy p
        SET p.harmonogram = v_harmonogram_ref
        WHERE p.id_pracownika = p_pracownik_id;
        
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20004, 'B³¹d podczas przypisywania harmonogramu: ' || SQLERRM);
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

    -- Pozosta³e implementacje funkcji...
END zarzadzanie_pracownikami;
/