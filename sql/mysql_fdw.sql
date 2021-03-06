\set MYSQL_HOST				   '\'localhost\''
\set MYSQL_PORT				   '\'3306\''
\set MYSQL_USER_NAME           '\'foo\''
\set MYSQL_PASS                '\'bar\''

\c postgres postgres
CREATE EXTENSION mysql_fdw;
CREATE SERVER mysql_svr FOREIGN DATA WRAPPER mysql_fdw OPTIONS (host :MYSQL_HOST, port :MYSQL_PORT);;
CREATE USER MAPPING FOR postgres SERVER mysql_svr OPTIONS(username :MYSQL_USER_NAME, password :MYSQL_PASS);

CREATE FOREIGN TABLE department(department_id int, department_name text) SERVER mysql_svr OPTIONS(dbname 'testdb', table_name 'department');
CREATE FOREIGN TABLE employee(emp_id int, emp_name text, emp_dept_id int) SERVER mysql_svr OPTIONS(dbname 'testdb', table_name 'employee');
CREATE FOREIGN TABLE empdata(emp_id int, emp_dat bytea) SERVER mysql_svr OPTIONS(dbname 'testdb', table_name 'empdata');
CREATE FOREIGN TABLE numbers(a int, b varchar(255)) SERVER mysql_svr OPTIONS (dbname 'testdb', table_name 'numbers');

SELECT * FROM department LIMIT 10;
SELECT * FROM employee LIMIT 10;
SELECT * FROM empdata LIMIT 10;

INSERT INTO department VALUES(generate_series(1,100), 'dept - ' || generate_series(1,100));
INSERT INTO employee VALUES(generate_series(1,100), 'emp - ' || generate_series(1,100), generate_series(1,100));
INSERT INTO empdata  VALUES(1, decode ('01234567', 'hex'));

insert into numbers values(1, 'One');
insert into numbers values(2, 'Two');
insert into numbers values(3, 'Three');
insert into numbers values(4, 'Four');
insert into numbers values(5, 'Five');
insert into numbers values(6, 'Six');
insert into numbers values(7, 'Seven');
insert into numbers values(8, 'Eight');
insert into numbers values(9, 'Nine');

SELECT count(*) FROM department;
SELECT count(*) FROM employee;
SELECT count(*) FROM empdata;

EXPLAIN (COSTS FALSE) SELECT * FROM department d, employee e WHERE d.department_id = e.emp_dept_id LIMIT 10;

EXPLAIN (COSTS FALSE) SELECT * FROM department d, employee e WHERE d.department_id IN (SELECT department_id FROM department) LIMIT 10;

SELECT * FROM department d, employee e WHERE d.department_id = e.emp_dept_id LIMIT 10;
SELECT * FROM department d, employee e WHERE d.department_id IN (SELECT department_id FROM department) LIMIT 10;
SELECT * FROM empdata;

DELETE FROM employee WHERE emp_id = 10;

SELECT COUNT(*) FROM department LIMIT 10;
SELECT COUNT(*) FROM employee WHERE emp_id = 10;

UPDATE employee SET emp_name = 'Updated emp' WHERE emp_id = 20;
SELECT emp_id, emp_name FROM employee WHERE emp_name like 'Updated emp';

UPDATE empdata SET emp_dat = decode ('0123', 'hex');
SELECT * FROM empdata;

SELECT * FROM employee LIMIT 10;
SELECT * FROM employee WHERE emp_id IN (1);
SELECT * FROM employee WHERE emp_id IN (1,3,4,5);
SELECT * FROM employee WHERE emp_id IN (10000,1000);

SELECT * FROM employee WHERE emp_id NOT IN (1) LIMIT 5;
SELECT * FROM employee WHERE emp_id NOT IN (1,3,4,5) LIMIT 5;
SELECT * FROM employee WHERE emp_id NOT IN (10000,1000) LIMIT 5;

SELECT * FROM employee WHERE emp_id NOT IN (SELECT emp_id FROM employee WHERE emp_id IN (1,10));
SELECT * FROM employee WHERE emp_name NOT IN ('emp - 1', 'emp - 2') LIMIT 5;
SELECT * FROM employee WHERE emp_name NOT IN ('emp - 10') LIMIT 5;

create or replace function test_param_where() returns void as $$
DECLARE
  n varchar;
BEGIN
  FOR x IN 1..9 LOOP
    select b into n from numbers where a=x;
    raise notice 'Found number %', n;
  end loop;
  return;
END
$$ LANGUAGE plpgsql;

SELECT test_param_where();

create or replace function test_param_where2(integer, text) returns integer as '
  select a from numbers where a=$1 and b=$2;
' LANGUAGE sql;

SELECT test_param_where2(1, 'One');

-- FDW-121: After a change to a pg_foreign_server or pg_user_mapping catalog
-- entry, existing connection should be invalidated and should make new
-- connection using the updated connection details.

-- Alter SERVER option.
-- Set wrong host, subsequent operation on this server should use updated
-- details and fail as the host address is not correct.
ALTER SERVER mysql_svr OPTIONS (SET host 'localhos');
SELECT * FROM numbers ORDER BY 1 LIMIT 1;

-- Set the correct hostname, next operation should succeed.
ALTER SERVER mysql_svr OPTIONS (SET host :MYSQL_HOST);
SELECT * FROM numbers ORDER BY 1 LIMIT 1;

-- Alter USER MAPPING option.
-- Set wrong username and password, next operation should fail.
ALTER USER MAPPING FOR postgres SERVER mysql_svr OPTIONS(SET username 'foo1', SET password 'bar1');
SELECT * FROM numbers ORDER BY 1 LIMIT 1;

-- Set correct username and password, next operation should succeed.
ALTER USER MAPPING FOR postgres SERVER mysql_svr OPTIONS(SET username :MYSQL_USER_NAME, SET password :MYSQL_PASS);
SELECT * FROM numbers ORDER BY 1 LIMIT 1;

DELETE FROM employee;
DELETE FROM department;
DELETE FROM empdata;
DELETE FROM numbers;

DROP FUNCTION test_param_where();
DROP FUNCTION test_param_where2(integer, text);
DROP FOREIGN TABLE numbers;

DROP FOREIGN TABLE department;
DROP FOREIGN TABLE employee;
DROP FOREIGN TABLE empdata;
DROP USER MAPPING FOR postgres SERVER mysql_svr;
DROP SERVER mysql_svr;
DROP EXTENSION mysql_fdw CASCADE;
