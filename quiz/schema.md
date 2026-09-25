# Quiz schema

> The question file format for `quiz/questions/*.yaml`, enforced by
> `scripts/validate-quiz.py` (CI and pre-commit). Schema reused from the
> source guide; question content is regenerated for Vibe — never
> transliterated.

## File format

One YAML file per category under `quiz/questions/`:

```yaml
category: "Category Name"   # free-form, names the file's scope
category_id: 1             # integer, groups files for the future engine

questions:
  - id: "xx-001"            # unique across ALL files; prefix = category
    difficulty: "junior"    # junior | senior | power
    profiles: ["junior", "senior", "power", "pm"]  # non-empty subset
    question: "Question text?"
    options:
      a: "Option A"
      b: "Option B"
      c: "Option C"
      d: "Option D"
    correct: "b"            # one of a, b, c, d
    explanation: |          # must teach, not just state the answer
      Why the correct answer is correct, and why the
      plausible distractors are not.
    doc_reference:          # backlink into the guide
      file: "guide/style-guide.md"  # repo-relative, must exist
      section: "Voice"      # human-readable section name (optional)
      anchor: "#voice"      # heading anchor (optional, checked if present)
```

## Rules the validator enforces

- `category` non-empty; `category_id` an integer.
- `questions` a non-empty list.
- `id` unique across all files.
- `difficulty` one of `junior`, `senior`, `power`.
- `profiles` a non-empty subset of `junior`, `senior`, `power`, `pm`.
- `options` exactly the keys `a`–`d`, all non-empty.
- `correct` one of `a`, `b`, `c`, `d`.
- `explanation` non-empty — write it to teach.
- `doc_reference.file` exists in the repo; `doc_reference.anchor`, when
  present, resolves to a heading of that file.

## Authoring rules the validator cannot check

- Test practical understanding, not memorization.
- Make distractors plausible but clearly distinguishable.
- Every mechanic in a question or explanation cites the mechanics oracle
  (`docs/mechanics/verified-mechanics.md`) — no command from memory.
- The regeneration replaced the placeholder file; real
  questions never carry placeholder markers.
