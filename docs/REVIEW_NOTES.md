# Review notes

The SQL package contains proposed corrections based on a review of the assignment requirements and the supplied implementation. Static review and document screenshots do **not** establish that the revised scripts execute successfully. MySQL execution is still pending; record the real server version, results, and failures when it is run.

## What the database work covers

- Manager movie and employee operations, catalog and rental reports, activity rankings, and a monthly subscription-income estimate.
- Representative customer operations, order recording, mailing lists, employee information without hourly pay, and customer recommendations.
- Customer account reads, available-movie searches, queues, rentals and returns, ratings, best sellers, and recommendations.
- Additional actor and cast-link operations. These are supplemental; they do not replace required transactions.

The catalog documents parameter types, bound sample values, SQL, and transaction-specific notes. The automated runner exercises 58 cases, including rejection cases. That count describes the test catalog, not a claim that the tests have passed.

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

- Load the schema and procedures in the target MySQL version and resolve any execution errors.
- Run the full catalog, inspect actual outputs, and retain the bound inputs with those outputs.
- Check simultaneous rentals, returns, and inventory changes using separate connections.
- Implement login and role enforcement in the application. Stored customer-ID checks alone do not authenticate a person.
- Keep screenshots and exported tables readable, including all selected columns. A screenshot of a preceding version is not evidence for changed SQL.
- Keep assignment documentation complete: the initial demo-data dump/listing and per-transaction definitions, parameters, SQL, sample execution, and relevant notes. The assignment accepts a dump/listing; this repository does not impose an extra screenshot or SELECT-only format.[^assignment]

## Course deadline discrepancy

At review time, the public project index listed Assignment 2 for **November 2, 2026 at 4:00 p.m.**, while the detailed Assignment 2 page listed **November 2, 2026 at 11:59 p.m.**[^index][^assignment] The repository cannot resolve that discrepancy; use the course's current submission instructions or instructor clarification.

## Sources and public-repository scope

The repository links to the [project requirements](https://www3.cs.stonybrook.edu/~sas/courses/cse305/fall26/project/main.html) and [demo-data page](https://www3.cs.stonybrook.edu/~sas/courses/cse305/fall26/project/demo_data.html) rather than republishing full handouts.

Private source documents, identifying team details, credentials, local reports, and personal feedback are not part of the public code repository. Put any required team identification in the private submission.

[^index]: [Programming project index](https://www3.cs.stonybrook.edu/~sas/courses/cse305/fall26/project/index.html).
[^assignment]: [Project Assignment 2 instructions](https://www3.cs.stonybrook.edu/~sas/courses/cse305/fall26/project/hw2.html).
