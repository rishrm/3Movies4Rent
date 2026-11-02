#!/usr/bin/env python3
"""Run the movie rental database tests in a NEW disposable MySQL database.

Requires Python 3 and PyMySQL. Passwords are prompted, never saved.
The existing team database is not used, overwritten, or dropped.
"""
import argparse
import datetime as dt
import getpass
import json
import os
import re
import sys
from pathlib import Path

try:
    import pymysql
except ImportError:
    raise SystemExit('Install the test dependency first: python3 -m pip install PyMySQL==1.1.1')

HERE = Path(__file__).resolve().parent
TABLES = ['PERSON','CUSTOMER','ACCOUNT','EMPLOYEE','MOVIE','ACTOR','ORDERR',
          'PLACES','ORDER_MOVIE','FEATURES','HANDLEDBY','QUEUES','RATES']

def table_text(columns, rows):
    if not rows:
        return '(0 rows)\n' + ('Columns: ' + ', '.join(columns) if columns else '')
    cells = [['NULL' if v is None else str(v) for v in row] for row in rows]
    widths = [max(len(str(c)), *(len(row[i]) for row in cells)) for i,c in enumerate(columns)]
    def line(row): return ' | '.join(str(v).ljust(widths[i]) for i,v in enumerate(row))
    return '\n'.join([line(columns), '-+-'.join('-'*n for n in widths)] + [line(r) for r in cells]) + f'\n({len(rows)} rows)'

def snapshot(conn):
    result={}
    with conn.cursor() as cur:
        for table in TABLES:
            cur.execute('SELECT * FROM `' + table + '`')
            result[table]=sorted(cur.fetchall(),key=lambda row:repr(row))
    return result

def setup_statements(text):
    return [s.strip() for s in text.split(';') if s.strip()]

def routine_statements(text):
    text = re.sub(r'^DELIMITER.*$', '', text, flags=re.M)
    return [s.strip() for s in text.split('$$') if s.strip()]

def execute_bound(cur, sql, values):
    """Actually prepare and execute every parameterized SQL statement on MySQL."""
    if not values:
        cur.execute(sql)
    else:
        cur.execute('PREPARE a2_stmt FROM %s', (sql,))
        for i, value in enumerate(values):
            cur.execute(f'SET @a2_p{i} = %s', (value,))
        cur.execute('EXECUTE a2_stmt USING ' + ', '.join('@a2_p'+str(i) for i in range(len(values))))
    sets=[]
    while True:
        if cur.description:
            cols=[d[0] for d in cur.description]
            rows=cur.fetchall()
            sets.append({'columns':cols,'rows':rows})
        else:
            sets.append({'affected_rows':cur.rowcount})
        if not cur.nextset():break
    if values:cur.execute('DEALLOCATE PREPARE a2_stmt')
    return sets

def rendered_sql(cur,sql,values):
    return cur.mogrify(sql.replace('%','%%').replace('?','%s'),tuple(values)) if values else sql

def check_read(id,sets):
    rows=next((s['rows'] for s in sets if 'rows' in s),[])
    # Independent, known baseline checks. These are assertions, not report output.
    if id=='R01':assert rows and str(rows[0][-1])=='30.00', rows
    if id=='R06':assert len(rows)==1 and 4 in rows[0], rows
    if id=='R07':assert len(rows)==2, rows
    if id=='R08':assert [r[0] for r in rows]==[3,1,2], rows
    if id=='R09':assert len(rows)==4, rows
    if id=='R10':assert len(rows)==1 and rows[0][0]==2, rows
    if id=='R11':assert len(rows)==1 and 3 in rows[0] and 'Borat' in rows[0], rows
    if id=='R12':assert len(rows)==2, rows
    if id=='R14':assert len(rows)==2, rows
    if id=='R15':assert {r[0] for r in rows}=={1,2}, rows
    if id in ('R16','R17','R18','R19'):assert len(rows)==1 and rows[0][0]==1, rows
    if id=='R20':assert len(rows)==2, rows

def check_mutation(cur, id):
    checks={
        'CRUD01':[("SELECT PersonID, EmailAddress FROM CUSTOMER WHERE CustomerID='555-55-5555'",((7,'JohnAdams@example.com'),))],
        'CRUD02':[("SELECT p.Telephone,c.EmailAddress FROM PERSON p JOIN CUSTOMER c USING(PersonID) WHERE c.CustomerID='111-11-1111'",(('631-000-0000','shang@example.com'),))],
        'CRUD03':[("SELECT PersonID,HourlyRate,EmployeeType FROM EMPLOYEE WHERE SocialSecurityNumber='555-55-5555'",((7,25,'Manager'),))],
        'CRUD04':[("SELECT HourlyRate FROM EMPLOYEE WHERE SocialSecurityNumber='789-12-3456'",((55,),))],
        'CRUD05':[("SELECT MovieName,NumberOfCopies FROM MOVIE WHERE MovieID=4",(('Inception',5),))],
        'CRUD06':[("SELECT COUNT(*) FROM MOVIE WHERE MovieID=4",((0,),))],
        'CRUD07':[("SELECT ActorName,Age,Rating FROM ACTOR WHERE ActorID=3",(('New Actor',40,3),))],
        'CRUD08':[("SELECT Age,Rating FROM ACTOR WHERE ActorID=1",((64,4),))],
        'CRUD09':[("SELECT COUNT(*) FROM ACTOR WHERE ActorID=3",((0,),))],
        'CRUD10':[("SELECT COUNT(*) FROM FEATURES WHERE MovieID=2 AND ActorID=2",((1,),))],
        'CRUD11':[("SELECT COUNT(*) FROM FEATURES WHERE MovieID=1 AND ActorID=2",((0,),))],
        'P01':[("SELECT p.AccountNumber,om.MovieID,h.SocialSecurityNumber FROM PLACES p JOIN ORDER_MOVIE om USING(OrderID) JOIN HANDLEDBY h USING(OrderID) WHERE p.OrderID=5",((1,1,'123-45-6789'),)),("SELECT MovieID,QueuePosition FROM QUEUES WHERE AccountNumber=1 ORDER BY QueuePosition",((3,1),))],
        'P02':[("SELECT ReturnDateTime IS NOT NULL FROM ORDERR WHERE OrderID=3",((1,),)),("SELECT MovieID FROM ORDER_MOVIE WHERE OrderID=5",((1,),))],
        'P03':[("SELECT MovieID,QueuePosition FROM QUEUES WHERE AccountNumber=1 ORDER BY QueuePosition",((1,1),(3,2),(2,3)))],
        'P04':[("SELECT MovieID,QueuePosition FROM QUEUES WHERE AccountNumber=1 ORDER BY QueuePosition",((3,1),))],
        'P05':[("SELECT MovieID,QueuePosition FROM QUEUES WHERE AccountNumber=1 ORDER BY QueuePosition",((3,1),(1,2)))],
        'P06':[("SELECT Rating FROM RATES WHERE AccountNumber=1 AND MovieID=1",((5,),))],
        'P07':[("SELECT Rating FROM RATES WHERE AccountNumber=1 AND MovieID=1",((4,),))],
        'P08':[("SELECT COUNT(*) FROM CUSTOMER WHERE CustomerID='111-11-1111'",((0,),)),("SELECT COUNT(*) FROM PERSON WHERE PersonID=1",((0,),))],
        'P09':[("SELECT COUNT(*) FROM EMPLOYEE WHERE SocialSecurityNumber='789-12-3456'",((0,),)),("SELECT COUNT(*) FROM PERSON WHERE PersonID=6",((0,),))],
        'P10':[("SELECT MovieName,DistributionFee,NumberOfCopies,Rating FROM MOVIE WHERE MovieID=1",(('The Godfather Updated',12000,5,4),))],
        'P11':[("SELECT CustomerID,AccountType FROM ACCOUNT WHERE AccountNumber=3",(('111-11-1111','Unlim1'),))],
        'E01':[("SELECT ReturnDateTime IS NOT NULL FROM ORDERR WHERE OrderID=4",((1,),)),("SELECT COUNT(*) FROM ORDERR WHERE OrderID=5",((0,),))],
        'E02':[("SELECT MovieID FROM ORDER_MOVIE WHERE OrderID=5",((1,),)),("SELECT MovieID,QueuePosition FROM QUEUES WHERE AccountNumber=1 ORDER BY QueuePosition",((3,1),))],
        'E03':[("SELECT AccountNumber FROM PLACES WHERE OrderID=5",((2,),)),("SELECT MovieID FROM ORDER_MOVIE WHERE OrderID=5",((1,),))]
    }
    for sql, expected in checks.get(id,[]):
        cur.execute(sql);actual=cur.fetchall()
        assert actual==expected, f'Outcome assertion failed: {sql}; expected {expected!r}, got {actual!r}'

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--host',default='127.0.0.1')
    ap.add_argument('--port',type=int,default=3306)
    ap.add_argument('--user',default='root')
    ap.add_argument('--socket')
    ap.add_argument('--database',default='3Movies4Rent_A2_Test_'+dt.datetime.now().strftime('%Y%m%d_%H%M%S'))
    ap.add_argument('--output-dir',default=str(HERE/'execution_results'))
    ap.add_argument('--team-file',default=str(HERE.parent/'team.local.json'),
                    help='Optional local-only team metadata for an execution report.')
    args=ap.parse_args()
    if not re.fullmatch(r'3Movies4Rent_A2_Test(?:_[A-Za-z0-9]+)*',args.database):
        raise SystemExit('Use a NEW database name beginning 3Movies4Rent_A2_Test, followed only by underscores, letters and digits.')
    password=os.environ.get('MYSQL_TEST_PASSWORD')
    if password is None:
        password=getpass.getpass('MySQL password (not saved): ')
    conn=pymysql.connect(host=args.host,port=args.port,user=args.user,password=password,
        unix_socket=args.socket,autocommit=True,charset='utf8mb4')
    out=Path(args.output_dir);out.mkdir(parents=True,exist_ok=True)
    report=[]
    report.extend(['3Movies4Rent','DATABASE EXECUTION REPORT',''])
    team_path=Path(args.team_file)
    if team_path.exists():
        team=json.loads(team_path.read_text())
        report.append('Group: '+str(team.get('group','')))
        for member in team.get('members',[]):
            report.append(str(member.get('name',''))+' - '+str(member.get('email','')))
        report.append('')
    else:
        report.extend(['Team details omitted. Add a private team.local.json to include them in a local report.',''])
    with conn.cursor() as cur:
        cur.execute('SELECT VERSION()');version=cur.fetchone()[0]
        cur.execute('SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME=%s',(args.database,))
        if cur.fetchone():raise SystemExit('Refusing to overwrite an existing database. Choose a new --database name.')
        if 'MariaDB' in version:raise SystemExit('This package targets MySQL 8.0.16 or newer, not MariaDB.')
        nums=tuple(map(int,re.match(r'(\d+)\.(\d+)\.(\d+)',version).groups()))
        if nums < (8,0,16):raise SystemExit('MySQL 8.0.16+ is required for enforced CHECK constraints.')
        cur.execute("SET SESSION sql_mode='STRICT_TRANS_TABLES,ONLY_FULL_GROUP_BY,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION'")
        cur.execute('SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED')
        cur.execute('SET SESSION innodb_lock_wait_timeout=10')
        cur.execute("SET SESSION time_zone='+00:00'")
        setup=(HERE/'01_schema_and_demo.sql').read_text().replace('3Movies4Rent_A2_Test',args.database)
        for s in setup_statements(setup):cur.execute(s)
        for s in routine_statements((HERE/'02_transaction_procedures.sql').read_text()):cur.execute(s)
    report.extend([f'Executed on MySQL {version}',f'Test database: {args.database}',
                   'Execution timestamp (UTC): '+dt.datetime.now(dt.timezone.utc).isoformat(),
                   'Isolation: READ COMMITTED; storage engine: InnoDB.',
                   'Test mutations use ROLLBACK. Real successful application transactions use COMMIT.',
                   'Only output captured from the server is shown below.','',
                   (HERE/'ASSUMPTIONS.txt').read_text(),'','INITIAL DEMO TABLE CONTENTS',''])
    baseline=snapshot(conn)
    with conn.cursor() as cur:
        for table in TABLES:
            cur.execute('SELECT * FROM `'+table+'`')
            rows=sorted(cur.fetchall(),key=lambda row:repr(row))
            report.extend([table,table_text([d[0] for d in cur.description],rows),''])
    tests=json.loads((HERE/'transactions.json').read_text())
    passed=0;failures=[];records=[]
    for t in tests:
        result={'id':t['id'],'title':t['title'],'status':None,'statements':[]}
        report.extend(['='*76,t['id']+' - '+t['title'],'Role: '+t['role'],
                       'Definition: '+t['definition'],'Input parameters:'])
        for p in t['parameters']:report.append('  '+p['name']+' '+p['type']+': '+p['description'])
        if not t['parameters']:report.append('  None; validation examples bind the inputs shown in their SQL.')
        report.extend(['Transaction: SET TRANSACTION ISOLATION LEVEL READ COMMITTED; START TRANSACTION;'])
        conn.begin();error=None;server_error=False
        try:
            with conn.cursor() as cur:
                for phase, statements in [('Fixture setup',t.get('setup',[])),('Transaction',t.get('statements',[t] if 'sql' in t else []))]:
                    for s in statements:
                        sql=s['sql'];values=s.get('values',[])
                        report.extend(['',phase+' parameterized SQL:',sql,
                            'Bound values, in placeholder order: '+json.dumps(values),
                            'SQL with the test values:',rendered_sql(cur,sql,values)])
                        sets=execute_bound(cur,sql,values)
                        result['statements'].append({'sql':sql,'values':values,'results':sets})
                        for rs in sets:
                            report.append(table_text(rs['columns'],rs['rows']) if 'rows' in rs else 'Affected rows: '+str(rs['affected_rows']))
                        if phase=='Transaction' and 'sql' in t:check_read(t['id'],sets)
                if t.get('expected_error'):raise AssertionError('Expected rejection did not occur: '+t['expected_error'])
                check_mutation(cur,t['id'])
        except Exception as exc:
            error=str(exc);server_error=isinstance(exc,pymysql.MySQLError)
            report.append('Server/test error: '+error)
        finally:
            conn.rollback();report.append('ROLLBACK;')
        unchanged=snapshot(conn)==baseline
        valid_error=bool(server_error and t.get('expected_error') and error
                         and t['expected_error'].lower() in error.lower())
        ok=unchanged and ((error is None and not t.get('expected_error')) or valid_error)
        result.update(status='PASS' if ok else 'FAIL',error=error,baseline_restored=unchanged)
        report.extend(['Baseline restored after test: '+str(unchanged),'Status: '+result['status'],
                       'Notes: '+t.get('notes',''),''])
        records.append(result)
        if ok:passed+=1
        else:failures.append(t['id'])
        print(f"{t['id']}: {result['status']}",flush=True)
        # Save even if a later test or connection fails.
        (out/'execution_report.txt').write_text('\n'.join(report)+'\n')
        (out/'results.json').write_text(json.dumps(records,indent=2,default=str)+'\n')
        if not unchanged:break
    report.extend(['='*76,f'TEST SUMMARY: {passed}/{len(tests)} passed.',
        'Failed or incomplete cases: '+(', '.join(failures) if failures else 'None'),
        'These tests exercise isolated transactions; they do not constitute a two-session concurrency test.',
        'Deployment authentication/authorization is an application integration requirement, not established by this root-account test.',
        '', 'APPENDIX A - SCHEMA AND DEMO LOAD', setup,
        '', 'APPENDIX B - FULL SQL DEFINITIONS FOR GUARDED TRANSACTIONS',
        (HERE/'02_transaction_procedures.sql').read_text()])
    (out/'execution_report.txt').write_text('\n'.join(report)+'\n')
    conn.close()
    print(f'Report: {out / "execution_report.txt"}')
    print('The isolated test database was retained. Your original team database was not modified.')
    return 0 if passed==len(tests) else 1

if __name__=='__main__':
    sys.exit(main())
