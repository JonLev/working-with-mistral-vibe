# Stage 1: CEO review - strategic product gate

Pre-implementation gate. Inserts an explicit checkpoint between "I have a
request" and "I start coding". Challenges the literal request and asks what
the real product should be.

Use in plan mode, before any implementation.

## The problem this solves

A CLI agent is optimized to build what you ask. If you say "add X", it
builds X. It will not ask whether X is actually the right product. This
stage corrects that by explicitly switching into product-thinking mode
before the implementation instinct kicks in.

## When to use

- Before implementing any significant feature request.
- Especially when the request is specific ("add photo upload"), since
  specificity often signals the requester has already collapsed the
  solution space.
- When you want to pressure-test a direction before committing
  engineering time.

## Three modes

Ask the user to choose one before proceeding:

| Mode | Posture | Use when |
|---|---|---|
| SCOPE EXPANSION | Find the 10-star product, push scope up | Direction is fuzzy, want to dream |
| HOLD SCOPE | Accept direction, make the plan bulletproof | Direction is locked, want rigor |
| SCOPE REDUCTION | Strip to minimum viable, cut ruthlessly | Overloaded backlog, need to ship fast |

Commit to the selected mode and do not drift mid-review.

## Review template

Work through these steps in order, in the conversation:

### Step 1: Choose mode

Ask the user which mode to use if not specified. Once the user selects,
commit to that mode for the entire review.

### Step 2: Restate the request

Summarize the literal request in one or two sentences. Be precise, not
editorialized.

### Step 3: Challenge the premise

Ask the more important question: what is this product actually for?

- What is the user's real job-to-be-done?
- Is the literal request the best way to solve it?
- What assumption is the request making that might be wrong?

### Step 4: The real product / bulletproof plan / MVP

- **SCOPE EXPANSION**: describe the 10-star version of this product.
  What would make this 10x better for 2x the effort? What do users
  actually want, not what they asked for? List five to eight specific
  features or design decisions that would make this feel inevitable.
- **HOLD SCOPE**: accept the direction, then find everything that can go
  wrong: unstated assumptions in the request, edge cases that are not
  covered, missing error states, UX gaps, security or trust boundary
  issues, operational concerns (monitoring, rollback, data migration).
- **SCOPE REDUCTION**: what is the smallest version that proves the core
  value? What is the one thing this must do? What can be cut without
  losing the point? What can be deferred to v2?

### Step 5: Recommendation

Return one of:

- **Proceed as stated**: the original request is the right product.
- **Reframe**: here is the better brief (with specifics).
- **Reject**: here is why this is the wrong direction, and what to build
  instead.

Do NOT make any code changes. This is a review, not an implementation.

## Example

Input: "Let sellers upload a photo for their listing"

Output (SCOPE EXPANSION):

> "Photo upload" is not the feature. The real job is helping sellers
> create listings that actually sell.
>
> Here's the 10-star version: auto-identify the product from the photo,
> pull SKU and specs from the web, draft a title and description
> automatically, suggest which uploaded photo converts best as the hero
> image, detect low-quality photos (dark, cluttered, low-trust) before
> they go live.
>
> Recommendation: Reframe. The brief should be "smart listing creation
> from photo", not "photo upload".

## Pipeline position

```text
ceo-review    -> lock product direction      <- you are here
eng-review    -> lock technical architecture
start         -> produce implementation plan
validate      -> validate before execution
execute       -> execute to merged PR
```
