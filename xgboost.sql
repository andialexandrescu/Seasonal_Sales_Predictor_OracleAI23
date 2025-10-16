drop table vanzari;
create table vanzari as
select co.data_achizitie, sum(ac.cantitate) as cantitate
from comanda co
join adauga_comanda ac on(ac.id_comanda = co.id_comanda)
group by co.data_achizitie
order by co.data_achizitie;

create or replace view train_vanzari as
select
    data_achizitie,
    cantitate,
    -- features
    to_number(to_char(data_achizitie,'D')) as zi_din_sapt,
    to_number(to_char(data_achizitie,'Q')) as anotimp,
    extract(month from data_achizitie) as luna,
    extract(year from data_achizitie) as an
from vanzari
where data_achizitie < to_date('2024-01-01', 'YYYY-MM-DD');

create or replace view test_vanzari as
select
    data_achizitie,
    cantitate,
    to_number(to_char(data_achizitie,'D')) as zi_din_sapt,
    to_number(to_char(data_achizitie,'Q')) as anotimp,
    extract(month from data_achizitie) as luna,
    extract(year from data_achizitie) as an
from vanzari
where data_achizitie >= to_date('2024-01-01', 'YYYY-MM-DD');

begin
    execute immediate 'drop table xgb_settings';
exception when others then null;
end;
/

create table xgb_settings-- e necesar un tabel de setari pt orice data mining alg
(
    setting_name varchar2(30) not null,
    setting_value varchar2(4000) not null
);

begin-- populare tabel setari cu valori pt xgboost
    delete from xgb_settings;
    commit;
    
    insert into xgb_settings values ('ALGO_NAME', 'ALGO_XGBOOST');
    insert into xgb_settings values ('PREP_AUTO', 'ON');
    
    insert into xgb_settings values('booster', 'gbtree');
    insert into xgb_settings values('num_round', '1000');-- n estimators
    insert into xgb_settings values('max_depth', '3');
    insert into xgb_settings values('eta', '0.01');-- learning rate
    insert into xgb_settings values('objective', 'reg:squarederror');-- by default
    insert into xgb_settings values('base_score', '0.5');-- by default
    insert into xgb_settings values('eval_metric', 'mae');-- rmse

  commit;
end;
/

begin
    begin
        dbms_data_mining.drop_model('XGB_VANZARE');
    exception when others then null;
    end;
    
    dbms_data_mining.create_model-- fit
    (
        model_name => 'XGB_VANZARE',
        mining_function => dbms_data_mining.regression,
        data_table_name => 'TRAIN_VANZARI',-- X_train
        case_id_column_name => 'DATA_ACHIZITIE',
        target_column_name => 'CANTITATE',-- y_train
        settings_table_name => 'XGB_SETTINGS'
    );
end;
/

create or replace view pred_vanzari as-- y_pred = model.predict(X_test)
select
    t.data_achizitie as case_id,-- X_test
    t.cantitate as actual,-- y_test
    prediction
    (
        xgb_vanzare
        using zi_din_sapt, anotimp, luna, an
    ) as prediction-- y_pred
from test_vanzari t;-- eval_set
/

select count(*), avg(cantitate), stddev(cantitate)-- deviatia standard
from train_vanzari;

select regr_r2(actual, prediction) as r2
from pred_vanzari;