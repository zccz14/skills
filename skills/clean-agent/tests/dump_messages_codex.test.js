const assert = require("node:assert/strict");
const { chmodSync, linkSync, lstatSync, mkdirSync, mkdtempSync, readFileSync, symlinkSync, utimesSync, writeFileSync } = require("node:fs");
const { tmpdir } = require("node:os");
const { join } = require("node:path");
const { spawn, spawnSync } = require("node:child_process");
const test = require("node:test");

const script = join(__dirname, "..", "scripts", "dump_messages_codex.js");

function fixture() {
  const root = mkdtempSync(join(tmpdir(), "clean-agent-codex-test-"));
  const home = join(root, "codex-home");
  const sessions = join(home, "sessions", "2026", "07", "12");
  mkdirSync(sessions, { recursive: true });
  return { root, home, sessions };
}

function rollout(sessions, session, bytes, timestamp = Date.now()) {
  const path = join(sessions, `rollout-2026-07-12T00-00-00-${session}.jsonl`);
  writeFileSync(path, bytes);
  const date = new Date(timestamp);
  utimesSync(path, date, date);
  return path;
}

function run(home, args) {
  return spawnSync(process.execPath, [script, ...args], {
    encoding: "utf8",
    env: { ...process.env, CODEX_HOME: home },
  });
}

test("copies exact bytes for an explicit session with private permissions", () => {
  const { root, home, sessions } = fixture();
  const bytes = Buffer.from([0, 255, 10, 123, 125, 13, 10]);
  rollout(sessions, "thread-one", bytes);
  const output = join(root, "snapshot.jsonl");

  const result = run(home, ["--session", "thread-one", "--out", output]);

  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stdout, `${output}\n`);
  assert.deepEqual(readFileSync(output), bytes);
  assert.equal(lstatSync(output).mode & 0o777, 0o600);
});

test("selects the uniquely latest rollout", () => {
  const { root, home, sessions } = fixture();
  rollout(sessions, "older", "old", 1_700_000_000_000);
  rollout(sessions, "newer", "new", 1_700_000_001_000);
  const output = join(root, "latest.jsonl");

  const result = run(home, ["--out", output]);

  assert.equal(result.status, 0, result.stderr);
  assert.equal(readFileSync(output, "utf8"), "new");
});

test("captures an exact prefix while an active rollout keeps growing", async () => {
  const { root, home, sessions } = fixture();
  const source = rollout(sessions, "active", Buffer.alloc(16 * 1024 * 1024, 65));
  const output = join(root, "active.jsonl");
  const appender = spawn(
    process.execPath,
    [
      "-e",
      "const fs=require('node:fs');const p=process.argv[1];fs.appendFileSync(p,'B');process.stdout.write('ready\\n');setInterval(()=>fs.appendFileSync(p,'B'),1);",
      source,
    ],
    { stdio: ["ignore", "pipe", "inherit"] },
  );
  await new Promise((resolveReady) => appender.stdout.once("data", resolveReady));

  const result = run(home, ["--session", "active", "--out", output]);
  appender.kill();

  assert.equal(result.status, 0, result.stderr);
  const snapshot = readFileSync(output);
  const finalSource = readFileSync(source);
  assert.equal(snapshot.equals(finalSource.subarray(0, snapshot.length)), true);
  assert.ok(finalSource.length > snapshot.length);
});

test("fails when an explicit session is missing or ambiguous", () => {
  const { root, home, sessions } = fixture();
  rollout(sessions, "other", "other");
  const missing = run(home, ["--session", "missing", "--out", join(root, "missing.jsonl")]);
  assert.notEqual(missing.status, 0);
  assert.match(missing.stderr, /No Codex rollout found for session missing/);

  const duplicateDirectory = join(home, "sessions", "2026", "07", "11");
  mkdirSync(duplicateDirectory, { recursive: true });
  rollout(sessions, "duplicate", "one");
  rollout(duplicateDirectory, "duplicate", "two");
  const ambiguous = run(home, ["--session", "duplicate", "--out", join(root, "ambiguous.jsonl")]);
  assert.notEqual(ambiguous.status, 0);
  assert.match(ambiguous.stderr, /selection is ambiguous/);
});

test("fails when latest modification time is ambiguous", () => {
  const { root, home, sessions } = fixture();
  rollout(sessions, "one", "one", 1_700_000_000_000);
  rollout(sessions, "two", "two", 1_700_000_000_000);

  const result = run(home, ["--out", join(root, "snapshot.jsonl")]);

  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /share the newest modification time/);
});

test("atomically replaces a regular snapshot", () => {
  const { root, home, sessions } = fixture();
  rollout(sessions, "thread", "replacement");
  const output = join(root, "snapshot.jsonl");
  writeFileSync(output, "previous");
  chmodSync(output, 0o644);

  const replaced = run(home, ["--session", "thread", "--out", output]);
  assert.equal(replaced.status, 0, replaced.stderr);
  assert.equal(readFileSync(output, "utf8"), "replacement");
  assert.equal(lstatSync(output).mode & 0o777, 0o600);
});

test("preserves the prior snapshot when temporary-file creation fails after selection", () => {
  const { root, home, sessions } = fixture();
  rollout(sessions, "thread", "replacement");
  const output = join(root, "s".repeat(240));
  const previous = Buffer.from([0, 255, 112, 114, 105, 111, 114]);
  writeFileSync(output, previous);

  // The destination component is valid, but the UUID-bearing temporary name
  // exceeds NAME_MAX. Selection therefore succeeds before temp creation fails.
  const failed = run(home, ["--session", "thread", "--out", output]);
  assert.notEqual(failed.status, 0);
  assert.match(failed.stderr, /ENAMETOOLONG|name too long/i);
  assert.deepEqual(readFileSync(output), previous);
});

test("rejects a destination symlink without changing its target", () => {
  const { root, home, sessions } = fixture();
  rollout(sessions, "thread", "session");
  const target = join(root, "target.txt");
  const output = join(root, "snapshot.jsonl");
  writeFileSync(target, "keep");
  symlinkSync(target, output);

  const result = run(home, ["--session", "thread", "--out", output]);

  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /destination symlink/);
  assert.equal(readFileSync(target, "utf8"), "keep");
  assert.equal(lstatSync(output).isSymbolicLink(), true);
});

test("rejects destination identity by path and hard link", () => {
  const { root, home, sessions } = fixture();
  const source = rollout(sessions, "thread", "session");
  const samePath = run(home, ["--session", "thread", "--out", source]);
  assert.notEqual(samePath.status, 0);
  assert.match(samePath.stderr, /paths must differ/);

  const hardLink = join(root, "hard-link.jsonl");
  linkSync(source, hardLink);
  const sameFile = run(home, ["--session", "thread", "--out", hardLink]);
  assert.notEqual(sameFile.status, 0);
  assert.match(sameFile.stderr, /same file/);
});
