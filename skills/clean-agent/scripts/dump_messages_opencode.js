#!/usr/bin/env node

const { execFileSync, spawnSync } = require("node:child_process");
const { closeSync, mkdtempSync, openSync } = require("node:fs");
const { join } = require("node:path");
const { tmpdir } = require("node:os");

function parseArgs(argv) {
  const args = { session: process.env.OPENCODE_SESSION_ID || process.env.OPENCODE_SESSION, out: undefined };

  for (let index = 2; index < argv.length; index += 1) {
    const arg = argv[index];

    if (arg === "--session") {
      index += 1;
      if (!argv[index]) {
        throw new Error("--session requires a value.");
      }
      args.session = argv[index];
      continue;
    }

    if (arg === "--out") {
      index += 1;
      if (!argv[index]) {
        throw new Error("--out requires a value.");
      }
      args.out = argv[index];
      continue;
    }

    if (arg === "--help" || arg === "-h") {
      args.help = true;
      continue;
    }

    throw new Error(`Unknown argument: ${arg}`);
  }

  return args;
}

function printHelp() {
  process.stdout.write(`Usage: node scripts/dump_messages_opencode.js [--session ses_...] [--out /tmp/messages.json]\n\nDumps the current OpenCode conversation messages to a JSON file and prints only the output path.\nIf --session is omitted, the script uses OPENCODE_SESSION_ID, OPENCODE_SESSION, or the most recent session from \`opencode session list\`.\n`);
}

function latestSessionID() {
  const list = execFileSync("opencode", ["session", "list"], { encoding: "utf8" });
  const line = list.split("\n").find((entry) => entry.startsWith("ses_"));

  if (!line) {
    throw new Error("No OpenCode session found. Pass --session ses_... explicitly.");
  }

  return line.split(/\s+/)[0];
}

function outputPath(sessionID, requestedPath) {
  if (requestedPath) {
    return requestedPath;
  }

  const dir = mkdtempSync(join(tmpdir(), "clean-agent-opencode-"));
  return join(dir, `${sessionID}-messages.json`);
}

function dumpSessionToFile(sessionID, path) {
  const fd = openSync(path, "w");

  try {
    const result = spawnSync("opencode", ["export", sessionID], {
      stdio: ["ignore", fd, "inherit"],
    });

    if (result.error) {
      throw result.error;
    }

    if (result.status !== 0) {
      throw new Error(`opencode export failed with status ${result.status}.`);
    }
  } finally {
    closeSync(fd);
  }
}

function main() {
  const args = parseArgs(process.argv);

  if (args.help) {
    printHelp();
    return;
  }

  const sessionID = args.session || latestSessionID();
  const path = outputPath(sessionID, args.out);

  dumpSessionToFile(sessionID, path);
  process.stdout.write(`${path}\n`);
}

try {
  main();
} catch (error) {
  process.stderr.write(`${error.message}\n`);
  process.exit(1);
}
