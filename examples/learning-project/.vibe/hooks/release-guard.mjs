#!/usr/bin/env node

// Vibe pre_tool hook. Vibe writes the invocation JSON to stdin; the decision
// contract is stdout JSON with exit 0. A non-zero exit is a hook failure:
// with strict = true in hooks.toml the failure denies the tool call, and a
// crashed guard must not fail open.

const input = await readStdin();

const event = JSON.parse(input);

if (
  event.hook_event_name !== "pre_tool" ||
  !/(?:^|\.)bash$/.test(event.tool_name ?? "") ||
  typeof event.tool_input?.command !== "string"
) {
  throw new TypeError("expected a pre_tool payload for the bash tool");
}

const command = event.tool_input.command
  .replace(/''|""/g, "")
  .replace(/\s+/g, " ")
  .trim();

const publishesArtifact =
  (/\bnpm\b/i.test(command) && /\bpublish\b/i.test(command)) ||
  (/\bdocker\b/i.test(command) && /\bpush\b/i.test(command));

process.stdout.write(
  `${JSON.stringify(
    publishesArtifact
      ? {
          decision: "deny",
          reason:
            "Run npm run verify and review evidence/PROOF-LOG.md before publishing.",
        }
      : {
          decision: "allow",
          reason: "Command does not publish or push an artifact.",
        },
  )}\n`,
);

async function readStdin() {
  const chunks = [];
  for await (const chunk of process.stdin) {
    chunks.push(chunk);
  }
  return Buffer.concat(chunks).toString("utf8");
}
