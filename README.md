# 3Movies4Rent

Movie rental database project for CSE 305, Fall 2026. This repository keeps the
MySQL schema, demo data, transaction definitions and test tools in one place
for the team.

## Current status

The schema and transaction code have been reviewed and statically checked.
Successful MySQL execution is still pending. The test suite contains 58 cases,
including 13 operations that should be rejected. Check the **Actions** tab for
the result of the latest database test run; a prepared test is not a passed test.

The earlier reviewed submission contains screenshots, but this corrected SQL
needs its own fresh execution results before it is used in a final submission.

## Start here

1. Clone this repo, or choose **Code → Download ZIP** on GitHub.
2. Read [the setup guide](docs/RUNNING_THE_PROJECT.md).
3. Run the SQL against a **new test database** on MySQL 8.0.16 or newer.
4. Review the generated execution report and fix any failing cases.

The Python runner is an optional testing helper. The project application still
uses the required Java/JDBC stack in the later assignment.

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
The public repository contains no submitted PDFs, grading screenshots or team
contact list. Demo customer records in the SQL come from the public course
fixture and are test data.

## Course references

- [Course homepage](https://www3.cs.stonybrook.edu/~sas/courses/cse305/fall26/)
- [Project requirements](https://www3.cs.stonybrook.edu/~sas/courses/cse305/fall26/project/main.html)
- [Assignment 2 handout](https://www3.cs.stonybrook.edu/~sas/courses/cse305/fall26/project/hw2.html)
- [Official demo data](https://www3.cs.stonybrook.edu/~sas/courses/cse305/fall26/project/demo_data.html)

The public project index lists November 2 at 4:00 p.m.; the Assignment 2 handout
lists November 2 at 11:59 p.m. Confirm the current deadline in Brightspace.
