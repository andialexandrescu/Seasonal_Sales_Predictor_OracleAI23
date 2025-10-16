create or replace procedure inserare_comenzi_data
(
    k_inserari_comenzi in number,
    k_inserari_adauga_comanda in number,
    k_cantitate_produse in number,
    data_vanzare in date,-- format DD-MON-YYYY, si pt a verifica existenta lunii cu invalid_month
    id_start_comanda in out number-- din moment ce apelez procedura pentru diverse perioade, vreau sa ia ultimul id din comenzile efectuate pana intr-un anumit moment
)
is
    -- tablou imbricat cu anii in care s-a inregistrat cel putin o comanda
    type lista_ani is table of char(4);
    t_ani_valizi lista_ani;
    var_an_gasit boolean := false;
    
    -- varray cu toate lunile anului
    type lista_luni is varray(12) of char(3);-- maxim 12 luni, de aceea a avut rost sa folosesc si varray
    v_luni_valide lista_luni := lista_luni('JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC');
    var_luna_gasita boolean := false;

    type lista_id_clienti is table of client.id_client%type index by binary_integer;
    t_clienti lista_id_clienti;
    var_client_index integer;

    type lista_id_angajati is table of agent_vanzari.id_angajat%type index by binary_integer;
    t_angajati lista_id_angajati;
    var_angajat_index integer;
    
    type lista_id_produse is table of piesa_mobilier.id_produs%type index by binary_integer;
    t_produse lista_id_produse;
    var_produs_index integer;
    type lista_indici is table of integer index by binary_integer;
    t_index lista_indici;
    j integer;
    index1 integer;
    var_poz_random integer;
    
    var_id_comanda comanda.id_comanda%type;
    var_id_client client.id_client%type;
    var_id_angajat agent_vanzari.id_angajat%type;
    
    var_id_produs piesa_mobilier.id_produs%type;
    var_cantitate_random number;
    var_moment_timp adauga_comanda.moment_timp%type;-- va trebui sa concatenez cu data_vanzare
    var_ora_random number;
    var_minut_random number;
    var_secunda_random number;
    am_pm char(2);
    
    invalid_month exception;
    --invalid_year exception;-- foarte restrictiv, daca sterg toate inserarile din ADAUGA_COMANDA si COMANDA apelul procedurii nu va insera nimic deoarece niciun an nu e valid pt ca nu exista vanzari
begin
    id_start_comanda := id_start_comanda+2;-- primul id de comanda care poate fi folosit
    
    /*select distinct(to_char(data_achizitie, 'YYYY'))-- ne permitem sa inseram doar in ani in care au existat vanzari, altfel nu
    bulk collect into t_ani_valizi
    from comanda;
    
    for i in 1..t_ani_valizi.count loop
        if t_ani_valizi(i) = an
            then
                var_an_gasit := true;
        end if;
    end loop;
    
    if var_an_gasit = false
        then
            raise invalid_year;
    end if;*/
  
    for i in 1..v_luni_valide.count loop
        if v_luni_valide(i) = to_char(data_vanzare, 'MON')
            then
                var_luna_gasita := true;
        end if;
    end loop;
    
    if var_luna_gasita = false
        then
            raise invalid_month;
    end if;

    select id_client
    bulk collect into t_clienti
    from client;
    
    select id_angajat
    bulk collect into t_angajati
    from agent_vanzari;
    
    select id_produs
    bulk collect into t_produse
    from piesa_mobilier;

    for i in 0..k_inserari_comenzi-1 loop
        var_id_comanda := id_start_comanda+i*2;
        
        var_client_index := trunc(dbms_random.value(1, t_clienti.count+1));
        var_id_client := t_clienti(var_client_index);
        
        var_angajat_index := trunc(dbms_random.value(1, t_angajati.count+1));
        var_id_angajat := t_angajati(var_angajat_index);
        
        insert into COMANDA values(var_id_comanda, 0, data_vanzare, var_id_angajat, var_id_client, null);
        
        for i in 0..k_inserari_adauga_comanda-1 loop
            j := 0;
            t_index := lista_indici();
            index1 := t_produse.first;
            while index1 is not null loop
                if t_produse.exists(index1) then
                    j := j + 1;
                    t_index(j) := index1;
                end if;
                index1 := t_produse.next(index1);
            end loop;
            
            if j = 0 then-- nu mai sunt produse de alocat
                exit;
            end if;
            
            var_poz_random := trunc(dbms_random.value(1, j+1));-- poz in lista de indici valizi
            var_produs_index := t_index(var_poz_random);-- cheia efectiva din t_produse
            var_id_produs := t_produse(var_produs_index);
            
            -- o data ce un produs e asociat tuplului (id_produs, id_comanda), el va fi eliminat din lista de produse din cauza unicitatii cheii
            t_produse.delete(var_produs_index);
            
            var_cantitate_random := k_cantitate_produse;--!!!
            am_pm := case when trunc(dbms_random.value(0, 2)) = 0 then 'AM' else 'PM' end;
            var_ora_random := trunc(dbms_random.value(1, 12));
            var_minut_random := trunc(dbms_random.value(1, 60));
            var_secunda_random := trunc(dbms_random.value(1, 60));
            var_moment_timp := to_timestamp(data_vanzare || ' ' || var_ora_random || '.' || var_minut_random || '.' || var_secunda_random, 'DD-MON-RR HH.MI.SS AM');
            
            insert into ADAUGA_COMANDA values(var_id_produs, var_id_comanda, var_cantitate_random, var_moment_timp);
        end loop;
        
    end loop;
    
    id_start_comanda := var_id_comanda;-- ultimul id de comanda existent in tabela
    
    commit;
exception
    when invalid_month then
        dbms_output.put_line('Exceptie invalid_month: Nu exista luna '||to_char(data_vanzare, 'MON'));
    /*when invalid_year then
        dbms_output.put_line('Exceptie invalid_year: Nu exista comenzi efectuate in anul '||an);*/
end;
/