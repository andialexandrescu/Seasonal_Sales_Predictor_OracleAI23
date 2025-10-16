drop table medie_vanzari_pivot;
create table medie_vanzari_pivot
(
    luna_an varchar2(7) primary key,-- YYYY-MM
    mon number,
    tue number,
    wed number,
    thu number,
    fri number,
    sat number,
    sun number
);
create or replace procedure plotare_medie_vanzari_luna_zi_din_sapt-- procedura fara parametri
as
    cursor c_avg_vanzari is-- cursor neparametrizat pt a face media cantitatii vandute a tuplului (zi_din_sapt, luna) 
        select to_char(co.data_achizitie, 'YYYY-MM') as luna_an,
            (1 + trunc(co.data_achizitie) - trunc(co.data_achizitie, 'IW')) as zi_din_sapt,
            round(avg(suma_vanzari_zilnice), 2) as avg_vanzari_zilnice
        from
        (
            select co.data_achizitie, sum(ac.cantitate) as suma_vanzari_zilnice
            from comanda co
            join adauga_comanda ac on(ac.id_comanda = co.id_comanda)
            group by co.data_achizitie
        ) vanzari_zilnice
        join comanda co on(co.data_achizitie = vanzari_zilnice.data_achizitie)
        group by to_char(co.data_achizitie, 'YYYY-MM'), (1 + trunc(co.data_achizitie) - trunc(co.data_achizitie, 'IW'))
        order by luna_an, zi_din_sapt;
    var_luna_an varchar2(7);
    var_zi_din_sapt number;
    var_avg_cantitate number;
    var_luna_an_curenta varchar2(7) := null;-- variabila pentru a tine cont de luna curenta
    
    type tablou_sapt is table of number index by binary_integer;-- tablou imbricat cu avg de vanzari pt fiecare saptamana dintr-o luna
    t_avg_sapt tablou_sapt;
begin
    delete from medie_vanzari_pivot;-- golire tabel

    open c_avg_vanzari;
    loop
        fetch c_avg_vanzari into var_luna_an, var_zi_din_sapt, var_avg_cantitate;
        exit when c_avg_vanzari%notfound;

        -- cand luna_an se schimba, inserez datele de la luna_an anterioare in tabelul medie_vanzari_pivot
        if var_luna_an_curenta is not null and var_luna_an != var_luna_an_curenta
            then
                insert into medie_vanzari_pivot values(var_luna_an_curenta, t_avg_sapt(1), t_avg_sapt(2), t_avg_sapt(3), t_avg_sapt(4), t_avg_sapt(5), t_avg_sapt(6), t_avg_sapt(7));
                t_avg_sapt.delete;
        end if;
    
        var_luna_an_curenta := var_luna_an;
        t_avg_sapt(var_zi_din_sapt) := var_avg_cantitate;
    end loop;
    
    -- ultima luna e inafara loop-ului
    if var_luna_an_curenta is not null
        then
            insert into medie_vanzari_pivot values(var_luna_an_curenta, t_avg_sapt(1), t_avg_sapt(2), t_avg_sapt(3), t_avg_sapt(4), t_avg_sapt(5), t_avg_sapt(6), t_avg_sapt(7));
    end if;

    close c_avg_vanzari;
end plotare_medie_vanzari_luna_zi_din_sapt;
/
begin
    plotare_medie_vanzari_luna_zi_din_sapt;
end;
/