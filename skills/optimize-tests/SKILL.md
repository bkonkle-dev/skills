---
name: optimize-tests
description: Audits, removes, consolidates, and rewrites tests for higher confidence per maintenance cost. Use when optimizing a test suite, reducing test bloat, deleting low-value tests, reviewing test quality, replacing excessive mocks, or adding tests without wasting coverage on constants, formatting, or implementation details.
---

# Optimize Tests

Optimize for confidence per unit of engineering cost, not test count, line
coverage, or speed in isolation. Write tests. Not too many. Mostly integration.

Bad tests are not harmless. They consume review and CI time, resist refactors,
and can make broken behavior look verified. Prefer a smaller suite that fails
only for useful reasons and protects behavior that matters.

## Core standard

A test earns its place when it protects an important use case, regression,
boundary, contract, or invariant better than static analysis or an existing
test does.

Prefer tests that:

- exercise code through the same public interface its real users use.
- assert observable outcomes: returned values, state transitions, persisted
  data, rendered behavior, emitted events, or external requests.
- run real internal collaborators together.
- survive behavior-preserving refactors.
- fail when the protected behavior breaks and rarely for unrelated reasons.
- cover risks derived from operating reality: legacy inputs, boundary
  instants, concurrency, partial failure, re-entry, idempotency, and actual
  production callers.

Use the narrowest test level that provides realistic confidence without
reimplementing the system in mocks. Favor a few broad behavioral and
integration tests, a small number of high-value end-to-end paths, focused unit
tests for dense business logic, and property-based tests for broad invariants.

## Workflow

1. Read the production code, tests, test configuration, and nearby callers.
   Identify the public interface and who uses it before judging a test.
2. Establish the suite's existing conventions and run the relevant tests when
   feasible. Do not introduce a new framework merely to optimize tests.
3. Inventory what each test uniquely protects. Group tests by use case rather
   than source function, branch, or test file.
4. Classify each test as keep, rewrite, merge, move to a better level, or
   delete. Treat deletion as a behavior-risk decision, not a line-count goal.
5. Remove low-value tests first. Consolidate overlapping setup and assertions
   into coherent behavioral scenarios where failures remain diagnosable.
6. Replace internal mocks and interaction assertions with real internal code
   and assertions on outcomes. Keep mocks at true external or nondeterministic
   boundaries.
7. Add or strengthen tests only when the audit exposes an important uncovered
   use case, regression, contract, or invariant. Optimization is not a mandate
   to replace every deleted test.
8. Run the smallest relevant test command, then the repository's required
   checks. Compare runtime and test count when practical, but never trade away
   meaningful confidence solely for a smaller number.
9. Report what was deleted, merged, or rewritten and the behavior that remains
   protected. Call out residual risks and checks that could not be run.

## Delete by default

Delete a test when it has no meaningful protection beyond one of these:

- It verifies a constant equals the literal used to define it.
- It verifies static object shape, enum members, labels, fixture contents, or
  configuration copied directly from the same source.
- It verifies trivial string interpolation, concatenation, or formatting with
  no product contract, escaping rule, localization rule, parsing ambiguity,
  or meaningful branch.
- It exercises an assignment, getter, pass-through wrapper, framework default,
  language behavior, or library behavior we do not own.
- TypeScript, a schema, the compiler, or linting already rejects the failure
  mode more directly.
- It exists only to increase line or branch coverage.
- Another test already protects the same behavior through a more realistic
  path.
- It snapshots a large or noisy structure without a deliberate, reviewable
  contract.
- It asserts only that an internal helper, logger, hook, callback, or mock was
  called, including tests built around mocks such as `jest.mock('./logger')`.
- It locks down private methods, internal state, component names, call order,
  incidental SQL, or another implementation detail a real caller cannot
  observe.
- It recreates production logic in test helpers or expected values, allowing
  implementation and test to be wrong in the same way.
- It cannot plausibly fail without a syntax error, type error, or an unrelated
  framework failure.

Do not preserve a weak test just because it is fast, old, or raises coverage.
Do not delete a test solely because the underlying code is small. Small code
can encode an important contract.

## Preserve or strengthen

Keep or improve tests that protect:

- critical user and developer workflows.
- previously observed regressions, with the test expressed at the boundary
  where the failure was observable.
- authorization, billing, data loss, privacy, security, and irreversible
  effects.
- public APIs, protocols, serialization, escaping, canonicalization, and exact
  third-party request payloads.
- error handling, partial failure, retries, timeouts, cancellation, and
  recovery.
- boundaries involving time, money, numeric precision, pagination, ordering,
  empty input, limits, or legacy data.
- concurrency, deduplication, re-entry, and idempotency.
- complex algorithms or business rules whose cases are cheaper and clearer at
  unit level.
- invariants over a large input space, preferably with property-based tests
  and reproducible seeds.

String formatting deserves a test only when the exact string is itself a
public contract or has nontrivial rules. Examples include wire formats, cache
keys, signatures, URLs with encoding behavior, user-visible localization,
queries sent to an external system, and strings consumed by another parser.

Constants deserve a test only when verified indirectly as part of behavior or
when synchronized against an independent external contract. A test that
imports a constant and repeats its value is not independent evidence.

## Boundaries and mocks

Run internal code for real. Mocking code we own verifies a diagram of expected
calls rather than whether the system works.

Mock or fake only where reality is impractical or harmful:

- third-party APIs and services.
- clocks, randomness, process state, and unavoidable nondeterminism.
- destructive or expensive infrastructure effects.
- genuinely unavailable platform boundaries.

Prefer realistic boundary substitutes in this order:

1. a local implementation, test container, or in-memory adapter with the same
   contract.
2. captured real I/O replayed deterministically, such as VCR-style fixtures.
3. a protocol-level fake or request interceptor.
4. a hand-written mock as a last resort.

Assertions about calls are legitimate when the call is the observable product:
an exact Stripe payload, HTTP request, queue message, analytics event contract,
or another external effect. This exception does not extend to internal helpers
or logging unless logs themselves are an explicit external contract.

## Choose the right level

- Use static checks for types, syntax, schemas, and enforceable structural
  constraints.
- Use unit tests for pure, branching, combinatorial, or algorithmic business
  logic where failures are clearer at a narrow boundary.
- Use integration tests for most behavior. Exercise multiple owned units
  together and mock as little as possible.
- Use end-to-end tests for a few high-value paths that must prove system wiring
  and user experience. Do not multiply them for every edge case.
- Use property-based tests for stable invariants over many inputs, not as a way
  to generate many copies of example tests.

Do not debate labels when the boundary is clear and useful. The practical test
is whether the scenario resembles real use enough to justify its cost.

## Rewriting patterns

Replace multiple mechanical tests with one behavioral scenario when it covers
their outcome through the public interface. For example, replace separate
tests for initial state, handler invocation, and child props with one test that
performs the user action and observes the resulting UI.

Prefer:

```ts
await user.click(screen.getByRole('button', { name: 'Show details' }))
expect(screen.getByText('Account details')).toBeVisible()
```

over:

```ts
expect(setOpen).toHaveBeenCalledWith(true)
expect(wrapper.state('open')).toBe(true)
```

For external boundaries, assert the contract and resulting local behavior:

```ts
expect(paymentRequest).toEqual({ amount: 4200, currency: 'usd' })
expect(order.status).toBe('paid')
```

Avoid asserting every intermediate step. One scenario may contain several
assertions when they jointly describe one behavior. Split it only when setup,
failure diagnosis, or distinct contracts justify separate cases.

## Decision check

Before keeping or adding a test, answer:

1. What user-visible behavior, public contract, regression, or invariant does
   this protect?
2. What realistic bug would make it fail?
3. Is that bug important enough to justify the test's runtime and maintenance?
4. Does another test or static check already catch it?
5. Can the same confidence be obtained through a more realistic boundary with
   fewer mocks?
6. Would a behavior-preserving refactor leave this test unchanged?

If the first two answers are vague, delete the test. If the last answer is no,
rewrite it around the public behavior unless the implementation itself is the
documented contract.

## Safety rules

- Preserve repository-specific test requirements unless the user explicitly
  asks to change policy or configuration.
- Do not chase an arbitrary coverage percentage. Use coverage only to discover
  potentially missed use cases, never as the definition of completeness.
- Do not bulk-delete tests based only on names, snapshots, mocks, or simple
  syntax. Inspect the production contract and overlapping coverage first.
- Do not weaken exact assertions into vague smoke tests merely to reduce
  maintenance.
- Do not combine unrelated behaviors into a single long test just to reduce
  count.
- Do not make tests depend on execution order, wall-clock timing, network
  availability, random data without a seed, or shared mutable state.
- Do not replace deterministic tests with flaky end-to-end coverage.
- If evidence is insufficient to prove a test redundant, keep it and report
  the uncertainty.

## References

This guidance synthesizes these public sources:

- Guillermo Rauch, "Write tests. Not too many. Mostly integration."
  https://x.com/rauchg/status/807626710350839808
- Kent C. Dodds, "The Testing Trophy and Testing Classifications"
  https://kentcdodds.com/blog/the-testing-trophy-and-testing-classifications
- Kent C. Dodds, "Write tests. Not too many. Mostly integration."
  https://kentcdodds.com/blog/write-tests
- Kent C. Dodds, "Testing Implementation Details"
  https://kentcdodds.com/blog/testing-implementation-details
- Kent C. Dodds, "How to know what to test"
  https://kentcdodds.com/blog/how-to-know-what-to-test
- Kent C. Dodds, "Static vs Unit vs Integration vs E2E Testing for Frontend
  Apps"
  https://kentcdodds.com/blog/static-vs-unit-vs-integration-vs-e2e-tests
