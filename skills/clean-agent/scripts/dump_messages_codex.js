#!/usr/bin/env node

const {
  closeSync,
  fchmodSync,
  fstatSync,
  fsyncSync,
  lstatSync,
  openSync,
  readSync,
  readdirSync,
  renameSync,
  statSync,
  unlinkSync,
  writeSync,
} = require("node:fs");
const { constants } = require("node:fs");
const { homedir } = require("node:os");
const { basename, dirname, join, resolve } = require("node:path");
const { randomUUID } = require("node:crypto");

function parseArgs(argv) {
  const args = { session: undefined, out: undefined, help: false };

  for (let index = 2; index < argv.length; index += 1) {
    const name = argv[index];

    if (name === "--help" || name === "-h") {
      args.help = true;
      continue;
    }

    if (name !== "--session" && name !== "--out") {
      throw new Error(`Unknown argument: ${name}`);
    }

    const value = argv[index + 1];
    if (!value) {
      throw new Error(`${name} requires a value.`);
    }

    args[name.slice(2)] = value;
    index += 1;
  }

  return args;
}

function printHelp() {
  process.stdout.write(
    "Usage: node scripts/dump_messages_codex.js [--session THREAD_ID] --out PATH\n\n" +
      "Copies the selected raw Codex rollout JSONL bytes through the snapshot point.\n" +
      "Without --session, selects the uniquely newest rollout by modification time.\n",
  );
}

function codexHome() {
  return resolve(process.env.CODEX_HOME || join(homedir(), ".codex"));
}

function collectRollouts(directory) {
  const rollouts = [];

  for (const entry of readdirSync(directory, { withFileTypes: true })) {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) {
      rollouts.push(...collectRollouts(path));
    } else if (entry.isFile() && entry.name.startsWith("rollout-") && entry.name.endsWith(".jsonl")) {
      rollouts.push(path);
    }
  }

  return rollouts;
}

function selectBySession(rollouts, session) {
  if (!/^[A-Za-z0-9_-]+$/.test(session)) {
    throw new Error("--session must contain only letters, digits, underscores, or hyphens.");
  }

  const suffix = `-${session}.jsonl`;
  const matches = rollouts.filter((path) => basename(path).endsWith(suffix));
  if (matches.length === 0) {
    throw new Error(`No Codex rollout found for session ${session}.`);
  }
  if (matches.length !== 1) {
    throw new Error(`Multiple Codex rollouts found for session ${session}; selection is ambiguous.`);
  }

  return matches[0];
}

function selectLatest(rollouts) {
  if (rollouts.length === 0) {
    throw new Error("No Codex rollout found. Pass --session THREAD_ID after a session is persisted.");
  }

  const candidates = rollouts.map((path) => ({ path, mtimeNs: statSync(path, { bigint: true }).mtimeNs }));
  const newestTime = candidates.reduce(
    (newest, candidate) => (candidate.mtimeNs > newest ? candidate.mtimeNs : newest),
    candidates[0].mtimeNs,
  );
  const newest = candidates.filter((candidate) => candidate.mtimeNs === newestTime);
  if (newest.length !== 1) {
    throw new Error("Multiple Codex rollouts share the newest modification time; pass --session THREAD_ID.");
  }

  return newest[0].path;
}

function selectRollout(session) {
  const sessionsDirectory = join(codexHome(), "sessions");
  let rollouts;
  try {
    rollouts = collectRollouts(sessionsDirectory);
  } catch (error) {
    throw new Error(`Cannot scan Codex sessions at ${sessionsDirectory}.`, { cause: error });
  }

  return session ? selectBySession(rollouts, session) : selectLatest(rollouts);
}

function rejectUnsafeDestination(sourceStat, destination) {
  let destinationStat;
  try {
    destinationStat = lstatSync(destination);
  } catch (error) {
    if (error.code === "ENOENT") {
      return;
    }
    throw error;
  }

  if (destinationStat.isSymbolicLink()) {
    throw new Error(`Refusing to replace destination symlink: ${destination}`);
  }
  if (destinationStat.dev === sourceStat.dev && destinationStat.ino === sourceStat.ino) {
    throw new Error("Source and destination refer to the same file.");
  }
}

function copyPrefix(sourceFd, destinationFd, size) {
  const buffer = Buffer.allocUnsafe(64 * 1024);
  let position = 0;

  while (position < size) {
    const length = Math.min(buffer.length, size - position);
    const bytesRead = readSync(sourceFd, buffer, 0, length, position);
    if (bytesRead === 0) {
      throw new Error("Codex rollout was truncated while the snapshot was being copied.");
    }

    let written = 0;
    while (written < bytesRead) {
      written += writeSync(destinationFd, buffer, written, bytesRead - written, position + written);
    }
    position += bytesRead;
  }
}

function verifyPrefix(sourceFd, destinationFd, size) {
  const sourceBuffer = Buffer.allocUnsafe(64 * 1024);
  const destinationBuffer = Buffer.allocUnsafe(64 * 1024);
  let position = 0;

  while (position < size) {
    const length = Math.min(sourceBuffer.length, size - position);
    const sourceBytes = readSync(sourceFd, sourceBuffer, 0, length, position);
    const destinationBytes = readSync(destinationFd, destinationBuffer, 0, length, position);
    if (
      sourceBytes !== length ||
      destinationBytes !== length ||
      !sourceBuffer.subarray(0, length).equals(destinationBuffer.subarray(0, length))
    ) {
      throw new Error("Snapshot verification failed: output differs from the captured source prefix.");
    }
    position += length;
  }

  if (fstatSync(destinationFd).size !== size) {
    throw new Error("Snapshot verification failed: output size differs from the captured source prefix.");
  }
}

function snapshotRollout(source, requestedDestination) {
  const destination = resolve(requestedDestination);
  if (resolve(source) === destination) {
    throw new Error("Source and destination paths must differ.");
  }

  const sourceFd = openSync(source, constants.O_RDONLY | constants.O_NOFOLLOW);
  let temporary;
  let destinationFd;

  try {
    const sourceStat = fstatSync(sourceFd);
    if (!sourceStat.isFile()) {
      throw new Error(`Codex rollout is not a regular file: ${source}`);
    }
    rejectUnsafeDestination(sourceStat, destination);

    temporary = join(dirname(destination), `.${basename(destination)}.${randomUUID()}.tmp`);
    destinationFd = openSync(
      temporary,
      constants.O_CREAT | constants.O_EXCL | constants.O_RDWR | constants.O_NOFOLLOW,
      0o600,
    );
    fchmodSync(destinationFd, 0o600);
    copyPrefix(sourceFd, destinationFd, sourceStat.size);
    verifyPrefix(sourceFd, destinationFd, sourceStat.size);
    fsyncSync(destinationFd);
    closeSync(destinationFd);
    destinationFd = undefined;
    renameSync(temporary, destination);
    temporary = undefined;
  } finally {
    if (destinationFd !== undefined) {
      closeSync(destinationFd);
    }
    closeSync(sourceFd);
    if (temporary !== undefined) {
      unlinkSync(temporary);
    }
  }

  return destination;
}

function main() {
  const args = parseArgs(process.argv);
  if (args.help) {
    printHelp();
    return;
  }
  if (!args.out) {
    throw new Error("--out PATH is required.");
  }

  const source = selectRollout(args.session);
  const destination = snapshotRollout(source, args.out);
  process.stdout.write(`${destination}\n`);
}

try {
  main();
} catch (error) {
  process.stderr.write(`${error.message}\n`);
  process.exitCode = 1;
}
