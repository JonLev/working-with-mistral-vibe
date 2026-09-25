---
name: tdd-workflow
description: Drive implementation through red-green-refactor cycles - write the smallest failing test first, write the minimal code to pass it, then refactor with tests green. Use when implementing business logic, algorithms, API endpoints, state management, or utility functions. Skip for UI layout, database migrations, exploratory prototypes, and anything better checked by an integration or visual test.
---

# TDD workflow

## The TDD cycle

```text
RED -> GREEN -> REFACTOR
       ^             |
       |_____________|
```

### 1. RED: write a failing test

- Write the smallest test that fails.
- The test should fail for the right reason.
- Ensure the test actually runs.

### 2. GREEN: make it pass

- Write minimal code to pass the test.
- Do not optimize yet.
- It is okay if the code is ugly.

### 3. REFACTOR: clean up

- Improve code structure.
- Remove duplication.
- Keep tests passing.

An agent left to its defaults writes implementation first and tests
second. TDD requires the inverse order, so each cycle only happens if it
is asked for explicitly: "Write a FAILING test for [feature]. Do NOT
write implementation yet."

## Best practices

### Test naming convention

```text
should_[expected behavior]_when_[condition]
```

Examples:

- `should_return_empty_array_when_no_items`
- `should_throw_error_when_invalid_input`
- `should_calculate_total_when_items_present`

### Test structure (AAA)

```typescript
it("should calculate discount when coupon applied", () => {
  // Arrange - set up test data
  const cart = new Cart();
  cart.addItem({ price: 100 });
  const coupon = new Coupon("10OFF", 10);

  // Act - execute the behavior
  cart.applyCoupon(coupon);

  // Assert - verify the result
  expect(cart.total).toBe(90);
});
```

### Test isolation

- Each test should be independent.
- No shared state between tests.
- Use `beforeEach` for common setup.
- Clean up in `afterEach`.

## Worked example: add item to cart

Step 1 (RED):

```typescript
describe("Cart", () => {
  it("should add item to cart", () => {
    const cart = new Cart();
    cart.addItem({ id: 1, name: "Book", price: 29.99 });
    expect(cart.items).toHaveLength(1);
  });
});
```

Run the test: it FAILS (Cart does not exist).

Step 2 (GREEN):

```typescript
class Cart {
  items = [];

  addItem(item) {
    this.items.push(item);
  }
}
```

Run the test: it PASSES.

Step 3 (REFACTOR):

```typescript
class Cart {
  private _items: CartItem[] = [];

  get items(): ReadonlyArray<CartItem> {
    return this._items;
  }

  addItem(item: CartItem): void {
    this._items.push(item);
  }
}
```

Run the test: still PASSES. Next iteration (calculate total): repeat the
cycle for each new behavior.

## Verifying a cycle headlessly

When a red or green state must be proven outside the session - in
automation, or to keep the verification independent of the authoring
context - run a bounded programmatic pass:

```bash
vibe --trust -p "Run the test suite and report exactly which tests pass
and fail, with the assertion output. Do not fix anything." \
  --max-turns 8 --output json
```

Verified semantics to rely on: `--trust` grants session-only trust;
in `-p` mode every approval-requiring tool call is auto-denied unless
`--auto-approve` is passed or the agent/permission config allows it, so
the run is read-only by construction. Budget with `--max-turns`,
`--max-price`, or `--max-tokens`, and read results from the JSON output.
Test commands are not in the default bash read-only allowlist - allow
them in `config.toml` (`[tools.bash] allowlist`) for automation.

## When to use TDD

Good for TDD:

- Business logic
- Complex algorithms
- API endpoints
- State management
- Utility functions

Less suitable:

- UI layout (visual testing is better)
- Database migrations
- External integrations (use integration tests)
- Exploratory or prototype code

## Common mistakes

1. Writing too much test - start with the smallest failing test.
2. Writing too much code - only enough to pass.
3. Skipping refactor - technical debt accumulates.
4. Testing implementation - test behavior, not internals.
5. Ignoring failing tests - fix or delete them, never skip.

## Test doubles

| Type | Purpose | Example |
|---|---|---|
| Stub | Return fixed data | `jest.fn().mockReturnValue(42)` |
| Mock | Verify interactions | `expect(mock).toHaveBeenCalled()` |
| Spy | Track calls | `jest.spyOn(obj, "method")` |
| Fake | Simplified implementation | In-memory database |
