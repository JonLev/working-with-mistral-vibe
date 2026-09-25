#!/usr/bin/env python3
"""validate-quiz.py — validate quiz/questions/*.yaml against quiz/schema.md.

Port of the source repo's quiz schema and validator concept; question
content is regenerated for Vibe.
The validator enforces the schema so regenerated content lands clean:

- category (non-empty), category_id (integer)
- per question: id (globally unique), difficulty, profiles, question text,
  options a-d (non-empty), correct answer among a-d, explanation,
  doc_reference (file must exist; anchor, if present, must resolve to a
  heading in that file)

Usage: scripts/validate-quiz.py  (exit 1 on any violation)
Used by: .pre-commit-config.yaml and .github/workflows/ci.yml.
"""

from __future__ import annotations

import glob
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "lib"))
import markdown  # noqa: E402
import yamlmini  # noqa: E402

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
QUESTIONS_DIR = os.path.join(REPO_ROOT, "quiz", "questions")

DIFFICULTIES = {"junior", "senior", "power"}
PROFILES = {"junior", "senior", "power", "pm"}


def fail(errors, msg):
    errors.append(msg)


def validate_file(path, seen_ids, errors):
    rel = os.path.relpath(path, REPO_ROOT)
    with open(path, encoding="utf-8") as f:
        text = f.read()
    try:
        data = yamlmini.parse(text, rel)
    except yamlmini.YamlMiniError as e:
        fail(errors, f"{rel}: unparseable YAML ({e})")
        return

    category = data.get("category")
    if not isinstance(category, str) or not category.strip():
        fail(errors, f"{rel}: 'category' missing or empty")
    try:
        int(data.get("category_id"))
    except (TypeError, ValueError):
        fail(errors, f"{rel}: 'category_id' missing or not an integer")

    questions = data.get("questions")
    if not isinstance(questions, list) or not questions:
        fail(errors, f"{rel}: 'questions' missing or empty")
        return

    for i, q in enumerate(questions):
        where = f"{rel}: question[{i}]"
        if not isinstance(q, dict):
            fail(errors, f"{where}: not a mapping")
            continue
        qid = q.get("id")
        if not qid:
            fail(errors, f"{where}: missing 'id'")
        elif qid in seen_ids:
            fail(errors, f"{where}: duplicate id '{qid}' (first seen in {seen_ids[qid]})")
        else:
            seen_ids[qid] = where
        if q.get("difficulty") not in DIFFICULTIES:
            fail(errors, f"{where}: 'difficulty' must be one of {sorted(DIFFICULTIES)}")
        profiles = q.get("profiles")
        if not isinstance(profiles, list) or not profiles:
            fail(errors, f"{where}: 'profiles' must be a non-empty list")
        elif not set(profiles) <= PROFILES:
            fail(errors, f"{where}: 'profiles' may only contain {sorted(PROFILES)}")
        if not (q.get("question") or "").strip():
            fail(errors, f"{where}: 'question' missing or empty")
        options = q.get("options")
        if not isinstance(options, dict) or set(options) != {"a", "b", "c", "d"}:
            fail(errors, f"{where}: 'options' must have exactly the keys a, b, c, d")
        else:
            for key, value in options.items():
                if not str(value).strip():
                    fail(errors, f"{where}: option '{key}' is empty")
        if q.get("correct") not in {"a", "b", "c", "d"}:
            fail(errors, f"{where}: 'correct' must be one of a, b, c, d")
        if not (q.get("explanation") or "").strip():
            fail(errors, f"{where}: 'explanation' missing or empty")

        ref = q.get("doc_reference")
        if not isinstance(ref, dict) or not ref.get("file"):
            fail(errors, f"{where}: 'doc_reference.file' missing")
        else:
            ref_path = os.path.join(REPO_ROOT, ref["file"])
            if not os.path.exists(ref_path):
                fail(errors, f"{where}: doc_reference file does not exist: {ref['file']}")
            elif ref.get("anchor"):
                anchor = ref["anchor"]
                if not anchor.startswith("#"):
                    fail(errors, f"{where}: anchor must start with '#': {anchor}")
                else:
                    with open(ref_path, encoding="utf-8") as rf:
                        body = rf.read()
                    slugs = {markdown.slugify(t) for _, t, _ in markdown.extract_headings(body)}
                    if anchor[1:] not in slugs:
                        fail(errors, f"{where}: anchor does not resolve in "
                                     f"{ref['file']}: {anchor}")


def main():
    errors = []
    seen_ids = {}
    files = sorted(glob.glob(os.path.join(QUESTIONS_DIR, "*.yaml")))
    if not files:
        fail(errors, "quiz/questions/: no question files found")
    for path in files:
        validate_file(path, seen_ids, errors)

    for e in errors:
        print(f"FAIL {e}")
    if errors:
        print(f"quiz validator: {len(errors)} violation(s)")
        sys.exit(1)
    print(f"quiz validator: clean ({len(files)} file(s))")


if __name__ == "__main__":
    main()
