# Design and testing notes

The SQL implements the movie rental project's database requirements. The database test step in [GitHub Actions run 41535204328](https://github.com/rishrm/3Movies4Rent/actions/runs/41535204328) executed the scripts on **MySQL 8.4.13**. Its captured report records **58/58 cases passed**, all 58 baselines restored, and all 13 intended rejection cases matched. These are actual server results for isolated tests; concurrent-session behavior and application authorization need separate integration checks.

## What the database work covers

- Manager movie and employee operations, catalog and rental reports, activity rankings, and a monthly subscription-income estimate.
- Representative customer operations, order recording, mailing lists, employee information without hourly pay, and customer recommendations.
- Customer account reads, available-movie searches, queues, rentals and returns, ratings, best sellers, and recommendations.
- Additional actor and cast-link operations. These are supplemental; they do not replace required transactions.

The catalog documents parameter types, bound sample values, SQL, and transaction-specific notes. The verified run covered 45 normal/read/edge cases and 13 expected rejections. Preserve the captured results and rerun the suite whenever the SQL or test fixtures change.

## Decisions to retain when making changes

1. **Availability:** total copies minus currently outstanding rentals determines whether a movie can be rented. Apply it to type, keyword, and actor searches. Recheck during checkout.
2. **Search sets:** multiple keywords or actors mean all selected values. Actor IDs avoid ambiguous names.
3. **Recommendations:** compare customers' distinct rental histories, include tied nearest neighbors, and exclude movies already rented by the target customer. Histories span that customer's accounts.
4. **Ownership:** bind the customer identity from the authenticated session. An editable customer-ID field is not authorization.
5. **History and inventory:** preserve referenced rental history during deletion; do not reduce copy counts below outstanding rentals.
6. **Revenue:** the existing schema has no cancellation, historical-plan, or payment history. Monthly income is an estimate under documented persistence and full-month-fee assumptions.
7. **Demo additions:** the fixture assigns the four historical orders to the available representative because their handlers were omitted from the supplied demo data. This is an explicit assumption.
8. **Transaction boundaries:** successful application mutations commit; failures roll back. Test mutations roll back to preserve the fixture. Use the documented transaction paths and lock order.

Details are in [the database assumptions](../database/ASSUMPTIONS.txt).

## What still needs verification

- Repeat schema loading and the full catalog after code changes or when moving to another MySQL version.
- Inspect each new run's actual outputs and retain the bound inputs with those outputs.
- Check simultaneous rentals, returns, and inventory changes using separate connections.
- Implement login and role enforcement in the application. Stored customer-ID checks alone do not authenticate a person.
- Keep screenshots and exported tables readable, including all selected columns. A screenshot of a preceding version is not evidence for changed SQL.
- Keep transaction documentation current: describe each operation, its parameters, SQL, sample execution, and relevant assumptions. Retain the fixture and results used to verify each change.

## Sources and public-repository scope

The repository links to the [project requirements](https://www3.cs.stonybrook.edu/~sas/courses/cse305/fall26/project/main.html) and [demo-data page](https://www3.cs.stonybrook.edu/~sas/courses/cse305/fall26/project/demo_data.html) rather than republishing full handouts.

Private documents, team contact details, credentials, and local reports stay outside the public code repository. Use the ignored `team.local.json` file when team details are needed in a local report.
