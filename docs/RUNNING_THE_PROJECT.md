# Running the project

This repository currently contains the database layer and a test harness. It is not yet the final Java/JDBC web application. The database test step in [GitHub Actions run 41535204328](https://github.com/rishrm/3Movies4Rent/actions/runs/41535204328) executed the suite on **MySQL 8.4.13: 58/58 cases passed**, with the baseline restored after every case and all 13 expected rejections matched. This verifies the isolated tests; concurrent sessions and application authorization still need separate checks. Use the steps below to repeat the tests locally.

## What you need

- A running MySQL server, version **8.0.16 or newer**. The scripts target MySQL, not MariaDB.
- A database account permitted to create a new database, tables, views, and stored procedures.
- Either the MySQL command-line client / MySQL Workbench, or Python 3 for the optional automated test runner.

Keep the files in `database/` together. The runner finds its SQL, transaction catalog, and assumptions relative to its own location.

## Option A: optional Python test runner

From the repository root, create and activate a virtual environment:

```sh
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements-test.txt
```

On Windows PowerShell, use `py -m venv .venv` and `.venv\Scripts\Activate.ps1` instead of the first two commands.

Run:

```sh
python database/run_tests.py --host 127.0.0.1 --port 3306 --user root
```

Replace the host, port, and username with your own MySQL connection settings. Enter the password at the prompt; do not add a password to a tracked file or command-line argument.

The runner creates a fresh database named like `3Movies4Rent_A2_Test_20261102_120000`. It refuses to overwrite an existing database, retains the test database afterward, and rolls back each test's data changes.

There are currently **58 test cases**, including **13 expected rejections**. An expected rejection counts as a pass only when the intended error occurs and the original fixture is restored.

Actual outputs are written to:

- `database/execution_results/execution_report.txt`
- `database/execution_results/results.json`

Read the final summary and investigate every failure. If schema or procedure loading fails, retain the terminal error too. These generated reports are local artifacts, excluded from Git.

The connector's RSA extra supports MySQL's SHA-256 authentication plugins.[^pymysql] Python is only a convenience for repeatable testing and report capture; it does not replace the required Java/JDBC application.

## Option B: MySQL only, without Python

The manual scripts use the fixed database name `3Movies4Rent_A2_Test`. Use a MySQL instance where that database does not already exist. If it does exist, stop and use the runner's fresh database workflow instead of rerunning the schema over it.

From the repository root:

```sh
cd database
mysql --host=127.0.0.1 --port=3306 --user=root --password
```

At the MySQL prompt, run these in order, stopping if a script reports an error:

```sql
SOURCE 01_schema_and_demo.sql;
SOURCE 02_transaction_procedures.sql;
SOURCE 03_test_examples.sql;
```

In MySQL Workbench, open and execute the same three files in that order on the same connection. The third file contains literal examples with rollback; it does not perform the runner's full assertion and expected-rejection checks.

Use the parameterized statements in `database/transactions.json` as the implementation reference. Bare `?` placeholders need JDBC binding or a prepared statement; they are not directly executable as ordinary queries in a SQL editor.

## Before sharing results

- Keep credentials, local team details, real customer data, and private documents out of the public repository.
- Copy `team.example.json` to the ignored `team.local.json` file when a local report needs team details.
- After later code changes, inspect the latest GitHub Actions run and its captured results. An earlier passing run establishes results only for the revision it tested.
- A passing isolated test suite does not establish simultaneous-session behavior or application authorization. Those remain separate integration checks.

[^pymysql]: [PyMySQL installation documentation](https://pymysql.readthedocs.io/en/latest/user/installation.html).
