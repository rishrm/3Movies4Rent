#!/usr/bin/env python3
"""Check source structure without connecting to MySQL or claiming SQL execution."""

import ast
import json
import re
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DATABASE = ROOT / "database"
REQUIRED_FILES = (
    "database/01_schema_and_demo.sql",
    "database/02_transaction_procedures.sql",
    "database/03_test_examples.sql",
    "database/transactions.json",
    "database/run_tests.py",
    "requirements-test.txt",
    ".github/workflows/mysql-tests.yml",
)
EXPECTED_IDS = {
    *(f"CRUD{i:02d}" for i in range(1, 12)),
    *(f"R{i:02d}" for i in range(1, 21)),
    *(f"P{i:02d}" for i in range(1, 12)),
    *(f"N{i:02d}" for i in range(1, 14)),
    *(f"E{i:02d}" for i in range(1, 4)),
}
SKIP_DIRECTORIES = {
    ".git", ".venv", "venv", "__pycache__", "execution_results",
    "node_modules", "private", ".pytest_cache",
}
TEXT_SUFFIXES = {".py", ".sql", ".json", ".txt", ".md", ".yml", ".yaml"}


def is_private_file(path):
    name = path.name.lower()
    return (
        name == ".env" or name.startswith(".env.")
        or name.startswith("team.private.")
        or name.startswith("team_private.")
        or name.startswith("team.local.")
        or name.endswith((".pem", ".key"))
    )


def source_files():
    for path in ROOT.rglob("*"):
        if not path.is_file():
            continue
        relative = path.relative_to(ROOT)
        if any(part in SKIP_DIRECTORIES for part in relative.parts):
            continue
        if is_private_file(path):
            continue
        if path.suffix.lower() in TEXT_SUFFIXES:
            yield path


def placeholder_count(sql):
    """Count bind markers outside MySQL quoted text and comments."""
    count = 0
    i = 0
    while i < len(sql):
        char = sql[i]
        if char in ("'", '"', "`"):
            quote = char
            i += 1
            while i < len(sql):
                if sql[i] == "\\" and quote != "`":
                    i += 2
                elif sql[i] == quote:
                    if i + 1 < len(sql) and sql[i + 1] == quote:
                        i += 2
                    else:
                        i += 1
                        break
                else:
                    i += 1
        elif sql.startswith("/*", i):
            end = sql.find("*/", i + 2)
            i = len(sql) if end < 0 else end + 2
        elif char == "#" or (
            sql.startswith("--", i)
            and (i + 2 == len(sql) or sql[i + 2].isspace())
        ):
            end = sql.find("\n", i)
            i = len(sql) if end < 0 else end + 1
        else:
            count += char == "?"
            i += 1
    return count


def check_tracked_private_files(errors):
    """Ignore local private inputs, but reject accidentally tracked ones."""
    try:
        top = subprocess.run(
            ["git", "-C", str(ROOT), "rev-parse", "--show-toplevel"],
            check=True, capture_output=True, text=True,
        ).stdout.strip()
        if Path(top).resolve() != ROOT.resolve():
            return
        names = subprocess.run(
            ["git", "-C", str(ROOT), "ls-files", "-z"],
            check=True, capture_output=True, text=True,
        ).stdout.split("\0")
    except (OSError, subprocess.CalledProcessError):
        return
    for name in filter(None, names):
        path = Path(name)
        if is_private_file(path) or "execution_results" in path.parts or "private" in path.parts:
            errors.append(f"Private/generated input must not be tracked: {name}")


def main():
    errors = []
    for name in REQUIRED_FILES:
        if not (ROOT / name).is_file():
            errors.append(f"Missing required file: {name}")

    python_count = 0
    institutional_email = re.compile(
        r"[A-Za-z0-9._%+-]+@(?:[A-Za-z0-9-]+\.)*stonybrook\.edu", re.I
    )
    credential_markers = (
        re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----"),
        re.compile(r"\bgh[pousr]_[A-Za-z0-9]{30,}\b"),
        re.compile(r"\bAKIA[A-Z0-9]{16}\b"),
    )
    for path in source_files():
        relative = path.relative_to(ROOT)
        try:
            text = path.read_text(encoding="utf-8")
        except (OSError, UnicodeError) as exc:
            errors.append(f"Cannot read {relative}: {exc}")
            continue
        if institutional_email.search(text):
            errors.append(f"Remove personal university email metadata from public source: {relative}")
        if any(pattern.search(text) for pattern in credential_markers):
            errors.append(f"Potential private key or access credential in public source: {relative}")
        if path.suffix == ".py":
            try:
                tree = ast.parse(text, filename=str(relative))
                python_count += 1
                if path == DATABASE / "run_tests.py":
                    for node in ast.walk(tree):
                        if (
                            isinstance(node, ast.BinOp) and isinstance(node.op, ast.Div)
                            and isinstance(node.left, ast.Name) and node.left.id == "HERE"
                            and isinstance(node.right, ast.Constant)
                            and isinstance(node.right.value, str)
                            and Path(node.right.value).suffix in {".sql", ".json", ".txt"}
                            and not (DATABASE / node.right.value).is_file()
                        ):
                            errors.append(f"Runner references missing file: database/{node.right.value}")
            except SyntaxError as exc:
                errors.append(f"Python syntax error in {relative}:{exc.lineno}: {exc.msg}")

    check_tracked_private_files(errors)
    transactions_path = DATABASE / "transactions.json"
    procedures_path = DATABASE / "02_transaction_procedures.sql"
    transactions = []
    if transactions_path.is_file():
        try:
            transactions = json.loads(transactions_path.read_text())
            if not isinstance(transactions, list):
                raise ValueError("Top-level JSON must be a list.")
        except (OSError, ValueError) as exc:
            errors.append(f"Invalid transactions.json: {exc}")
            transactions = []

    defined_procedures = set()
    if procedures_path.is_file():
        defined_procedures = {
            name.lower() for name in re.findall(
                r"\bCREATE\s+PROCEDURE\s+`?([A-Za-z_][A-Za-z0-9_]*)`?",
                procedures_path.read_text(), re.I,
            )
        }
    ids = []
    statement_count = 0
    for index, transaction in enumerate(transactions):
        if not isinstance(transaction, dict):
            errors.append(f"Transaction #{index + 1} must be an object.")
            continue
        ident = transaction.get("id", f"#{index + 1}")
        ids.append(ident)
        for key in ("title", "role", "definition", "notes"):
            if not isinstance(transaction.get(key), str):
                errors.append(f"{ident}: {key} must be text.")
        parameters = transaction.get("parameters")
        if not isinstance(parameters, list):
            errors.append(f"{ident}: parameters must be a list.")
        else:
            for parameter in parameters:
                if not isinstance(parameter, dict) or any(
                    not isinstance(parameter.get(key), str)
                    for key in ("name", "type", "description")
                ):
                    errors.append(f"{ident}: malformed parameter definition.")

        statements = transaction.get("statements", [transaction] if "sql" in transaction else [])
        fixtures = transaction.get("setup", [])
        if not isinstance(statements, list) or not isinstance(fixtures, list) or not statements:
            errors.append(f"{ident}: requires a nonempty statements list or a SQL statement.")
            continue
        for statement in fixtures + statements:
            statement_count += 1
            if not isinstance(statement, dict) or not isinstance(statement.get("sql"), str):
                errors.append(f"{ident}: malformed SQL statement.")
                continue
            sql = statement["sql"]
            values = statement.get("values", [])
            if not isinstance(values, list) or placeholder_count(sql) != len(values):
                errors.append(f"{ident}: bind-marker count does not match values.")
            for called in re.findall(r"\bCALL\s+`?([A-Za-z_][A-Za-z0-9_]*)`?\s*\(", sql, re.I):
                if called.lower() not in defined_procedures:
                    errors.append(f"{ident}: undefined procedure {called}.")
        if "expected_error" in transaction and not isinstance(transaction["expected_error"], str):
            errors.append(f"{ident}: expected_error must be text.")

    if len(ids) != 58 or len(ids) != len(set(ids)) or set(ids) != EXPECTED_IDS:
        errors.append("The catalog must contain the 58 unique documented CRUD/R/P/N/E cases.")
    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1
    print(
        f"Static checks complete: {python_count} Python files, "
        f"{len(ids)} transaction definitions, {statement_count} SQL/test statements."
    )
    print("No MySQL statements were executed by this checker.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
