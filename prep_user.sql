create role sgbd_role;
 
grant connect to sgbd_role;
grant resource to sgbd_role;
grant create session to sgbd_role;
grant create table to sgbd_role;
grant create view to sgbd_role;
grant create materialized view to sgbd_role;
grant create synonym to sgbd_role;
grant create procedure to sgbd_role;
grant create sequence to sgbd_role;
grant create trigger to sgbd_role;
grant create type to sgbd_role;
grant query rewrite to sgbd_role;
grant select_catalog_role to sgbd_role;
grant alter session to sgbd_role;
grant select any dictionary to sgbd_role;
grant create public database link to sgbd_role;
grant create public synonym to sgbd_role;
 
grant create mining model to sgbd_role;
grant alter any mining model to sgbd_role;
grant drop any mining model to sgbd_role;
grant select any mining model to sgbd_role;
grant execute on dbms_data_mining to sgbd_role;
  
create user andi_homedb1 identified by oracle
profile default
default tablespace users
quota unlimited on users
account unlock;
 
grant sgbd_role to andi_homedb1;
grant unlimited tablespace to andi_homedb1;

-- an extremely simple test case to narrow down 
--   "feature not supported" error with xgboost 
 
/* 
 
  ERROR at line 1: 
  ORA-40216: feature not supported 
  ORA-06512: at "SYS.DBMS_DATA_MINING", line 355 
  ORA-06512: at "SYS.DBMS_DATA_MINING", line 605 
  ORA-06512: at "SYS.DBMS_DATA_MINING", line 564 
 
*/ 
 
-- create a training data table 
create table test_data 
( 
  case_id number, 
  col_01 number, 
  col_02 number, 
  col_03 number, 
  col_04 number, 
  col_05 number, 
  col_06 number, 
  col_07 number, 
  col_08 number, 
  col_09 number, 
  col_10 number, 
  target number 
); 
 
-- put some random data in this table 
declare 
  new_row test_data%rowtype; 
begin 
  delete from test_data; 
  commit; 
 
  for i in 1..1000 
  loop 
    -- the case_id is just the row number 
    new_row.case_id := i; 
 
    -- random data for my training data 
    new_row.col_01 := dbms_random.value; 
    new_row.col_02 := dbms_random.value; 
    new_row.col_03 := dbms_random.value; 
    new_row.col_04 := dbms_random.value; 
    new_row.col_05 := dbms_random.value; 
    new_row.col_06 := dbms_random.value; 
    new_row.col_07 := dbms_random.value; 
    new_row.col_08 := dbms_random.value; 
    new_row.col_09 := dbms_random.value; 
    new_row.col_10 := dbms_random.value; 
 
    -- 5 "classes" for a classification target 
    new_row.target := mod(i, 5); 
 
    insert into test_data values new_row; 
  end loop; 
 
  commit; 
end; 
/ 
 
-- create a settings table which is necessary for any Oracle data mining 
algorithm 
create table settings 
( 
  setting_name varchar2(30) not null, 
  setting_value varchar2(4000) not null 
); 
 
-- populate the settings with mostly default values for xgboost 
 
begin 
  delete from settings; 
  commit; 
 
  -- generic settings needed for most data mining models 
  insert into settings (setting_name,setting_value) values 
('ALGO_NAME','ALGO_XGBOOST'); 
  insert into settings (setting_name,setting_value) values ('PREP_AUTO','ON'); 
 
  -- settings specific to xgboost 
  --   note that xgboost, unlike most other models, requires lower-case 
parameter names 
  --   (p.s. that is a glitch as Oracle could have easily set those incoming 
  --     parameters lower-case) 
  -- insert into settings (setting_name,setting_value) values 
('booster','gbtree'); 
 
  -- these are the parameters that I was using originally, but I have removed 
then as you 
  --   don't need them for a test.  Oracle will automatically use default 
values if you 
  --   don't specify a value. 
 
  -- insert into settings (setting_name,setting_value) values ('alpha','0'); 
  -- insert into settings (setting_name,setting_value) values ('eta','.3'); 
  -- insert into settings (setting_name,setting_value) values ('gamma','0'); 
  -- insert into settings (setting_name,setting_value) values ('lambda','1'); 
  -- insert into settings (setting_name,setting_value) values 
('max_delta_step','0'); 
  -- insert into settings (setting_name,setting_value) values 
('max_depth','6'); 
  -- insert into settings (setting_name,setting_value) values 
('max_leaves','0'); 
  -- insert into settings (setting_name,setting_value) values 
('min_child_weight','1'); 
  -- insert into settings (setting_name,setting_value) values 
('num_parallel_tree','1'); 
  -- insert into settings (setting_name,setting_value) values 
('num_round','10'); 
  -- insert into settings (setting_name,setting_value) values 
('objective','multi:softprob'); 
  -- insert into settings (setting_name,setting_value) values 
('scale_pos_weight','1'); 
  -- insert into settings (setting_name,setting_value) values 
('subsample','1'); 
  -- insert into settings (setting_name,setting_value) values 
('tree_method','auto'); 
 
  commit; 
end; 
/ 
 
-- now call the DBMS_DATA_MINING CREATE_MODEL function 
 
begin 
  -- if already there, delete it 
  begin 
    dbms_data_mining.drop_model(model_name => 'MY_MODEL'); 
  exception when others then 
    null; 
  end; 
 
  dbms_data_mining.create_model 
  ( 
    model_name => 'MY_MODEL', 
    mining_function => dbms_data_mining.classification, 
    data_table_name => 'TEST_DATA', 
    case_id_column_name => 'CASE_ID', 
    target_column_name => 'TARGET', 
    settings_table_name => 'SETTINGS', 
    xform_list => null 
  ); 
end; 
/