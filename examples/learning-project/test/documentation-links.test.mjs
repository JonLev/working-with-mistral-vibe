import assert from "node:assert/strict";
import {
  existsSync,
  readFileSync,
  readdirSync,
} from "node:fs";
import { fileURLToPath } from "node:url";
import { test } from "node:test";

const projectRoot = new URL("../", import.meta.url);
const readme = new URL("README.md", projectRoot);

function markdownFiles(directory) {
  return readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const url = new URL(entry.name, directory);
    if (entry.isDirectory()) {
      return markdownFiles(new URL(`${entry.name}/`, directory));
    }
    return entry.name.endsWith(".md") ? [url] : [];
  });
}

function isExternalLink(target) {
  return /^[a-z][a-z0-9+.-]*:/i.test(target) || target.startsWith("//");
}

test("every relative Markdown link in the project resolves", () => {
  assert.equal(existsSync(readme), true, "README.md is missing");

  const links = markdownFiles(projectRoot).flatMap((source) => {
    const markdown = readFileSync(source, "utf8");
    return [...markdown.matchAll(/\[[^\]]+\]\(([^)]+)\)/g)]
      .map((match) => ({ source, target: match[1] }))
      .filter(({ target }) => !isExternalLink(target) && !target.startsWith("#"));
  });

  assert.ok(links.length >= 12, "README should connect stages to source material");

  for (const { source, target } of links) {
    const [path] = target.split("#", 1);
    const destination = new URL(path, source);
    assert.equal(
      existsSync(destination),
      true,
      `Broken README link: ${fileURLToPath(destination)}`,
    );
  }

  assert.equal(isExternalLink("notes/result:local.md"), false);

  const candidate = JSON.parse(
    readFileSync(new URL("fixtures/release-ready.json", projectRoot), "utf8"),
  );
  const evidence = Object.fromEntries(
    candidate.checks.map((check) => [check.name, check.evidence]),
  );
  const proofLog = readFileSync(
    new URL("evidence/PROOF-LOG.md", projectRoot),
    "utf8",
  );
  assert.equal(evidence.tests, "node --test: 11 passed");
  assert.equal(evidence.security, "release guard fixtures: 4 passed");
  assert.equal(
    evidence.package,
    "node --check and npm pack --dry-run: exit 0",
  );
  assert.match(proofLog, /11 of 11 tests/);
  assert.match(proofLog, /4 of 4 hook tests/);
  assert.match(proofLog, /validates JavaScript syntax and the npm manifest/);

  const hooksToml = readFileSync(
    new URL(".vibe/hooks.toml", projectRoot),
    "utf8",
  );
  assert.match(hooksToml, /^name = "release-guard"$/m);
  assert.match(hooksToml, /^type = "pre_tool"$/m);
  assert.match(hooksToml, /^match = "bash"$/m);
  assert.match(hooksToml, /^command = "node \.vibe\/hooks\/release-guard\.mjs"$/m);
  assert.match(hooksToml, /^timeout = 5$/m);
  assert.match(hooksToml, /^strict = true$/m);

  const agent = readFileSync(
    new URL(".vibe/agents/evidence-reviewer.toml", projectRoot),
    "utf8",
  );
  assert.match(agent, /^agent_type = "subagent"$/m);
  assert.match(agent, /^system_prompt_id = "evidence-reviewer"$/m);
  assert.match(agent, /^enabled_tools = \["read_file", "grep"\]$/m);
  assert.match(agent, /^\[tools\.write_file\]$/m);
  assert.match(agent, /^permission = "never"$/m);
  assert.equal(
    existsSync(new URL(".vibe/prompts/evidence-reviewer.md", projectRoot)),
    true,
    "the system_prompt_id must resolve to a prompt file",
  );

  const skill = readFileSync(
    new URL(".vibe/skills/verify-release/SKILL.md", projectRoot),
    "utf8",
  );
  assert.match(skill, /^name: verify-release$/m);
  assert.match(skill, /^description: .+$/m);
  assert.doesNotMatch(skill, /\$ARGUMENTS/);
  assert.doesNotMatch(skill, /argument-hint|disable-model-invocation/);
});
