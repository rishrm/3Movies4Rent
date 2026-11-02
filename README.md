# 3Movies4Rent

Movie rental database project for CSE 305, Fall 2026. This repository keeps the
MySQL schema, demo data, transaction definitions and test tools in one place
for the team.

## Current status

All **58 test cases passed on MySQL 8.4.13**, including 13 operations that must
be rejected. Every test restored the initial database afterward.
[Verified execution run](https://github.com/rishrm/3Movies4Rent/actions/runs/41535204328).

The run's `mysql-execution-results-41535204328` artifact contains the actual
SQL outputs and JSON results. Check the **Actions** tab after later code changes.
These are isolated transaction tests; they do not certify two-session concurrency
or the later application's login and authorization behavior.

## Start here

1. Clone this repo, or choose **Code → Download ZIP** on GitHub.
2. Read [the setup guide](docs/RUNNING_THE_PROJECT.md).
3. Run the SQL against a **new test database** on MySQL 8.0.16 or newer.
4. Review the generated execution report and fix any failing cases before merging
   your changes.

The Python runner is an optional testing helper for the MySQL database layer.
The application uses Java/JDBC to connect to the database.

```bash
git clone https://github.com/rishrm/3Movies4Rent.git
cd 3Movies4Rent
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements-test.txt
python scripts/check_repo.py
python database/run_tests.py --host 127.0.0.1 --port 3306 --user root
```

Use your own MySQL host, port and username. The runner prompts for the password,
creates a new timestamped test database, and refuses to overwrite an existing
database. It does not modify the team's original database.

## Files

```text
database/
  01_schema_and_demo.sql        Corrected schema and official demo fixture
  02_transaction_procedures.sql Guarded rental, queue and other operations
  03_test_examples.sql          Literal examples for manual MySQL testing
  transactions.json            Definitions, parameters and test inputs
  run_tests.py                  Captures actual MySQL results
  ASSUMPTIONS.txt               Data assumptions and transaction policies
docs/
  RUNNING_THE_PROJECT.md        Setup and team workflow
  REVIEW_NOTES.md               Corrections and remaining verification
scripts/
  check_repo.py                Static repository checks
team.example.json              Template for local report details
requirements-test.txt          Test-runner dependencies
.github/workflows/             MySQL checks on pushes and pull requests
```

The numbered SQL files and JSON describe the same test fixture. The manual SQL
examples use the fixed `3Movies4Rent_A2_Test` database; the Python runner creates
a separate timestamped database by default. See the setup guide before mixing
these workflows.

## Updating the code

Start a branch before editing:

```bash
git switch main
git pull --ff-only
git switch -c fix/describe-your-change
```

After editing and checking your changes:

```bash
git diff
git add database/ docs/ scripts/
git commit -m "Describe the change"
git push -u origin HEAD
```

Open a pull request on GitHub so another teammate can review it. Teammates need
collaborator access to push branches directly; otherwise they can fork the
public repo and open a pull request. A public link gives read access, not write
access. GitHub's web editor is also available for small edits.

## Local report details

Copy `team.example.json` to `team.local.json` and fill in the team names and email
addresses locally. That file and generated execution reports are ignored by Git.
The public repository contains no private documents or team contact list.
Demo customer records in the SQL come from the public course
fixture and are test data.

## Course references

- [Course homepage](https://www3.cs.stonybrook.edu/~sas/courses/cse305/fall26/)
- [Project requirements](https://www3.cs.stonybrook.edu/~sas/courses/cse305/fall26/project/main.html)
- [Official demo data](https://www3.cs.stonybrook.edu/~sas/courses/cse305/fall26/project/demo_data.html)
