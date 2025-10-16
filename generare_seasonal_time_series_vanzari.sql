create or replace type info_vanzari_zilnice force as object
(
    data_vanzare date,
    an number,
    luna varchar2(3),
    index_zi integer,
    vanzari_zilnice float
);
/
create or replace type lista_vanzari_zilnice force as table of info_vanzari_zilnice;
/
create or replace procedure generare_seasonal_time_series_vanzari
(
    an_inceput number,
    an_sfarsit number,
    init_id_start_comanda number,
    nivel_baza number default 200,
    ampl_sezonier number default 30,-- amplificator sezonier, cat de mult variatia sezoniera poate sa scada/ creasca
    ampl_zi_din_sapt number default 0.3,
    zgomot_std number default 0.85,-- standard, limita superioara
    baza_max_produse number default 37,-- baza pt nr maxim de produse disponibile (nr de produse existente in baza de date)
    ampl_max_produse number default 1,
    baza_max_cantitate number default 20,
    ampl_max_cantitate number default 2
)
as
    t_vanzari_zilnice lista_vanzari_zilnice := lista_vanzari_zilnice();
    i integer;
    data_curenta date;
    data_sfarsit date;
    var_init_id_start number := init_id_start_comanda;-- copie locala id inserare_comenzi_an_luna
    var_rec_zilnic info_vanzari_zilnice;
    
    var_k_inserari_comenzi number;
    var_k_inserari_adauga_comanda number;
    var_k_cantitate_produse number;
begin
    data_curenta := to_date('01-01-' || an_inceput, 'DD-MM-YYYY');
    data_sfarsit  := to_date('01-01-' || (an_sfarsit+1), 'DD-MM-YYYY')-1;-- nu vreau 1 ianuarie din anul urmator
    --dbms_output.put_line('data_sfarsit: '||data_sfarsit);
    
    t_vanzari_zilnice := lista_vanzari_zilnice();
    while data_curenta <= data_sfarsit loop
        --dbms_output.put_line('data_curenta: '||data_curenta);
        declare
            index_zi integer;
            luna varchar2(2);
            an integer;
            
            scalare float;
            factor_sezonier float;
            zgomot float;
            aux_vanzari_zilnice float;
        begin
            index_zi := round(data_curenta - to_date('01-01-' || an_inceput, 'DD-MM-YYYY'));
            luna := extract(month from data_curenta);-- conversie numerica
            an := extract(year from data_curenta);
            
            if luna < 7
            then
                scalare := 1.0 + (luna-1) * (0.3/5);-- prima jum a anului inseamna o crestere de la 1.0 la 1.3
            else
                scalare := 1.3 - (luna-7) * (0.3/5);-- o scadere de la 1.3 la 1.0
            end if;
    
            factor_sezonier := ampl_sezonier * sin(2*acos(-1)*index_zi/365);-- acos(-1) = pi, codif zilelor dintr-un an, totusi trebuie impartit la nr de zile care completeaza ciclul
            -- SAU V2: https://skforecast.org/0.10.0/faq/cyclical-features-time-series
            -- signal_1 = 3 + 4 * sin(index_zi/365*2*acos(-1))
            -- signal_2 = 3 * sin(index_zi/365*4*acos(-1)+365/2)
            zgomot := zgomot_std * dbms_random.normal;
    
            -- additive + multiplicative time series
            aux_vanzari_zilnice := (nivel_baza + factor_sezonier + zgomot) * scalare;-- de adaugat in tabloul de rec
            -- SAU V2: aux_vanzari_zilnice = (signal_1 + signal_2 + factor_sezonier + zgomot) * scalare
            if aux_vanzari_zilnice < 0-- modul
                then
                    aux_vanzari_zilnice := 0;
            end if;

            -- adaugarea unui obiect initilizat complet la tabloul imbricat, altfel e eroarea `uncomposite object error`
            t_vanzari_zilnice.extend;
            t_vanzari_zilnice(t_vanzari_zilnice.count) := info_vanzari_zilnice(data_curenta, an, luna, index_zi, aux_vanzari_zilnice);
        end;

        data_curenta := data_curenta+1;
    end loop;
    
    for i in 1..t_vanzari_zilnice.count loop
        declare
            zi_din_sapt integer;
            scalare_zi_din_sapt float;
        begin
            var_rec_zilnic := t_vanzari_zilnice(i);
            zi_din_sapt := 1 + trunc(var_rec_zilnic.data_vanzare) - trunc(var_rec_zilnic.data_vanzare, 'IW');
            scalare_zi_din_sapt := 1 + ampl_zi_din_sapt * (1-sin(2*acos(-1)*(zi_din_sapt-1)/7));
        
            var_k_inserari_comenzi := round(var_rec_zilnic.vanzari_zilnice);
            
            -- limitele (..._max_...) pentru cantitati si nr max de produse in adauga_comanda
            -- mapare ciclu folosind sin(var_rec_zilnic.avg_index_zi/365*2*acos(-1)) sau sin(var_rec_zilnic.avg_index_zi/365*2*acos(-1)+acos(-1)/2) (shiftare cu 90 de grade)
            -- dbms_random.normal sau dbms_random.normal * 0.5 varianta zgomot
            var_k_inserari_adauga_comanda := round((baza_max_produse + ampl_max_produse * sin(var_rec_zilnic.index_zi/365*2*acos(-1)) + dbms_random.normal) * scalare_zi_din_sapt);
            var_k_cantitate_produse := round((baza_max_cantitate + ampl_max_cantitate * sin(var_rec_zilnic.index_zi/365*2*acos(-1)+acos(-1)/2) + dbms_random.normal * 0.5) * scalare_zi_din_sapt);
        
            inserare_comenzi_data(var_k_inserari_comenzi, var_k_inserari_adauga_comanda, var_k_cantitate_produse, var_rec_zilnic.data_vanzare, var_init_id_start);
        end;
    end loop;

end;
/
begin
    delete from ADAUGA_COMANDA;
    delete from COMANDA;
    commit;
    generare_seasonal_time_series_vanzari(2020, 2024, 1000000000);
end;
/