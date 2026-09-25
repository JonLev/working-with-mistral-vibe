import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { test } from "node:test";

const projectRoot = new URL("../", import.meta.url);
const hookPath = new URL(".vibe/hooks/release-guard.mjs", projectRoot);

function runHook(fixtureName) {
  const fixture = new URL(
    `.vibe/hooks/fixtures/${fixtureName}`,
    projectRoot,
  );
  return spawnSync(process.execPath, [hookPath.pathname], {
    encoding: "utf8",
    input: readFileSync(fixture, "utf8"),
  });
}

test("the guard allows a local test command", () => {
  const result = runHook("pass.json");

  assert.equal(result.status, 0, result.stderr);
  assert.equal(JSON.parse(result.stdout).decision, "allow");
});

test("the guard denies a publishing command", () => {
  for (const fixtureName of [
    "fail.json",
    "npm-obfuscated.json",
    "npm-silent.json",
  ]) {
    const result = runHook(fixtureName);
    const decision = JSON.parse(result.stdout);

    assert.equal(result.status, 0, `${fixtureName}: ${result.stderr}`);
    assert.equal(decision.decision, "deny", fixtureName);
    assert.match(decision.reason, /npm run verify/);
  }
});

test("the guard denies a container push", () => {
  for (const fixtureName of ["docker-push.json", "docker-obfuscated.json"]) {
    const result = runHook(fixtureName);

    assert.equal(result.status, 0, `${fixtureName}: ${result.stderr}`);
    assert.equal(JSON.parse(result.stdout).decision, "deny", fixtureName);
  }
});

test("the guard fails on malformed hook input", () => {
  const result = runHook("malformed.json");

  // A non-zero exit is a hook failure, not a decision. hooks.toml sets
  // strict = true, so the runtime denies the tool call instead of failing
  // open when the guard cannot parse its input.
  assert.notEqual(result.status, 0, "malformed input must exit non-zero");
  assert.equal(result.stdout, "");
  assert.match(result.stderr, /JSON|payload/i);
});
