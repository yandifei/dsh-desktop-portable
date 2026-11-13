#!/usr/bin/env node
/*
 * Apply the portable patches to an extracted official DeepSeek Harness payload.
 *
 * Usage: node Patch-Asar.js <root-dir>
 *   <root-dir> must contain resources/app.asar (the official payload root).
 *
 * Exit codes: 0 = patched, 2 = a patch anchor is missing (payload untouched).
 *
 * The script rewrites resources/app.asar in place:
 *   - packed entries are copied in order and their offsets/integrity are rebuilt
 *   - entries marked "unpacked" keep their files under resources/app.asar.unpacked
 *   - only lib/main.js and the workspace-controller files are modified
 */
'use strict';

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const root = process.argv[2];
if (!root) {
  console.error('usage: node Patch-Asar.js <root-dir>');
  process.exit(2);
}

const ASAR = path.join(root, 'resources', 'app.asar');
const OUT = ASAR + '.new';
const BLOCK = 4194304;

function fail(message) {
  console.error('patch error: ' + message);
  process.exit(2);
}

if (!fs.existsSync(ASAR)) fail('app.asar not found: ' + ASAR);

const fd = fs.openSync(ASAR, 'r');
const head = Buffer.alloc(16);
fs.readSync(fd, head, 0, 16, 0);
const headerSize = head.readUInt32LE(4);
const jsonLength = head.readUInt32LE(12);
const headerBuffer = Buffer.alloc(jsonLength);
fs.readSync(fd, headerBuffer, 0, jsonLength, 16);
const header = JSON.parse(headerBuffer.toString('utf8').replace(/\0+$/u, ''));
// The header JSON is padded to a 4-byte boundary, so the payload starts at
// 8 + headerSize, not at 16 + jsonLength. Using the latter shifts every read by
// the padding width (0-3 bytes) and silently corrupts every packed file.
const dataBase = 8 + headerSize;

function readEntry(node) {
  const buffer = Buffer.alloc(node.size);
  fs.readSync(fd, buffer, 0, node.size, dataBase + Number(node.offset));
  return buffer;
}

function sha256(buffer) {
  return crypto.createHash('sha256').update(buffer).digest('hex');
}

function integrityOf(buffer) {
  const blocks = [];
  for (let offset = 0; offset < buffer.length; offset += BLOCK) {
    blocks.push(sha256(buffer.subarray(offset, Math.min(offset + BLOCK, buffer.length))));
  }
  return { algorithm: 'SHA256', hash: sha256(buffer), blockSize: BLOCK, blocks };
}

function patchMain(source) {
  let text = source.toString('utf8');

  const importAnchor = 'import { REMOTE_STREAM_MUX_PATH, parseRemoteStreamServerMessage } from "@deepseek-ai/dsh-api-gateway/stream-protocol";\n';
  if (!text.includes(importAnchor)) fail('main.js import anchor not found');

  const injection = [
    '',
    '// --- portable build: keep every writable path on the drive that holds the executable ---',
    'const __dshPortableRoot = dirname(process.execPath);',
    'process.env.DSH_HOME ??= join(__dshPortableRoot, ".dsh");',
    'const __dshPortableTemp = join(__dshPortableRoot, "@deepseek-aidsh-desktop-updater", "temp");',
    'mkdirSync(__dshPortableTemp, { recursive: true });',
    'const __dshPortableHome = join(__dshPortableRoot, "home");',
    'mkdirSync(join(__dshPortableHome, "AppData", "Local"), { recursive: true });',
    'process.env.TEMP = __dshPortableTemp;',
    'process.env.TMP = __dshPortableTemp;',
    'process.env.DSH_WE_DATA_DIR ??= join(__dshPortableRoot, ".dsh", "plugin-data", "wallpaper-engine");',
    'process.env.DSH_WE_CACHE_DIR ??= join(__dshPortableRoot, "@deepseek-aidsh-desktop-updater", "wallpaper-engine-cache");',
    'app.setPath("userData", join(__dshPortableRoot, "@deepseek-ai", "dsh-desktop"));',
    'app.setPath("sessionData", join(__dshPortableRoot, "@deepseek-ai", "dsh-desktop"));',
    '',
  ].join('\n');
  text = text.replace(importAnchor, importAnchor + injection);

  const homeOld = 'function defaultDshHome() {\n\treturn join(homedir(), DSH_HOME_DIR_NAME);\n}';
  const homeNew = 'function defaultDshHome() {\n\treturn join(dirname(process.execPath), DSH_HOME_DIR_NAME);\n}';
  if (!text.includes(homeOld)) fail('main.js defaultDshHome anchor not found');
  text = text.replace(homeOld, homeNew);

  const protocolOld = 'if (app.isPackaged || process.env.DSH_DESKTOP_DEV_APP === "1") app.setAsDefaultProtocolClient("dsh");';
  const protocolNew = 'if (process.env.DSH_DESKTOP_REGISTER_PROTOCOL === "1") app.setAsDefaultProtocolClient("dsh");';
  if (!text.includes(protocolOld)) fail('main.js protocol anchor not found');
  text = text.replace(protocolOld, protocolNew);

  const hostEnvOld = '\t\t\tenv: desktopNodeEnvironment(this.node, void 0, this.environment),';
  const hostEnvNew = '\t\t\tenv: desktopNodeEnvironment(this.node, void 0, { ...this.environment, USERPROFILE: join(__dshPortableRoot, "home"), HOME: this.environment.HOME || this.environment.USERPROFILE, LOCALAPPDATA: join(__dshPortableRoot, "home", "AppData", "Local") }),';
  if (!text.includes(hostEnvOld)) fail('main.js host environment anchor not found');
  text = text.replace(hostEnvOld, hostEnvNew);

  return Buffer.from(text, 'utf8');
}

function patchWorkspaceTypes(source) {
  let text = source.toString('utf8');
  const old = "    const paths = platform === 'win32' ? win32 : posix;\n    signal.throwIfAborted();\n    let directory = documentsDirectory;";
  if (!text.includes(old)) fail('types/default-directory.js anchor not found');
  const replacement = [
    "    const paths = platform === 'win32' ? win32 : posix;",
    '    if (documentsDirectory === undefined) {',
    "        const portableHome = process.env.DSH_HOME || paths.join(paths.dirname(process.execPath), '.dsh');",
    "        return paths.join(portableHome, 'workspace', 'deepseek-harness', DEFAULT_WORKSPACE_DIRECTORY);",
    '    }',
    '    signal.throwIfAborted();',
    '    let directory = documentsDirectory;',
  ].join('\n');
  return Buffer.from(text.replace(old, replacement), 'utf8');
}

function patchWorkspaceController(source) {
  let text = source.toString('utf8');
  const old = '\tconst paths = platform === "win32" ? win32 : posix;\n\tsignal.throwIfAborted();\n\tlet directory = documentsDirectory;';
  if (!text.includes(old)) fail('workspace-controller index.js anchor not found');
  const replacement = [
    '\tconst paths = platform === "win32" ? win32 : posix;',
    '\tif (documentsDirectory === void 0) {',
    '\t\tconst portableHome = process.env.DSH_HOME || paths.join(paths.dirname(process.execPath), ".dsh");',
    '\t\treturn paths.join(portableHome, "workspace", "deepseek-harness", DEFAULT_WORKSPACE_DIRECTORY);',
    '\t}',
    '\tsignal.throwIfAborted();',
    '\tlet directory = documentsDirectory;',
  ].join('\n');
  return Buffer.from(text.replace(old, replacement), 'utf8');
}

const MAIN = 'lib/main.js';
const TYPES_DIR = 'dsh/node_modules/@deepseek-ai/dsh-api-workspace-controller/lib/types/default-directory.js';
const CONTROLLER = 'dsh/node_modules/@deepseek-ai/dsh-api-workspace-controller/lib/index.js';

let mainNode;
let typesNode;
let controllerNode;
try {
  mainNode = header.files.lib.files['main.js'];
  const controllerPackage = header.files.dsh.files.node_modules.files['@deepseek-ai'].files['dsh-api-workspace-controller'];
  typesNode = controllerPackage.files.lib.files.types.files['default-directory.js'];
  controllerNode = controllerPackage.files.lib.files['index.js'];
} catch {
  fail('asar layout changed');
}

const patched = new Map();
patched.set(MAIN, patchMain(readEntry(mainNode)));
patched.set(TYPES_DIR, patchWorkspaceTypes(readEntry(typesNode)));
patched.set(CONTROLLER, patchWorkspaceController(readEntry(controllerNode)));

// Remember where every file lived in the original archive so the written copy can
// be checked byte for byte (the walk below rewrites offset/size in place).
const originalLayout = new Map();
(function collect(node, prefix) {
  for (const [name, child] of Object.entries(node.files || {})) {
    const filePath = prefix ? prefix + '/' + name : name;
    if (child.files) {
      collect(child, filePath);
      continue;
    }
    if (child.unpacked) continue;
    originalLayout.set(filePath, { offset: Number(child.offset), size: child.size });
  }
})(header, '');

function readOriginal(entry) {
  const buffer = Buffer.alloc(entry.size);
  fs.readSync(fd, buffer, 0, entry.size, dataBase + entry.offset);
  return buffer;
}

// Reads the archive back and refuses to install it unless the result is sane:
// the root manifest must parse, the patches must be present, and every file we
// did not touch must still be byte-identical to the original archive.
function verifyArchive(outPath) {
  const vfd = fs.openSync(outPath, 'r');
  try {
    const size = fs.fstatSync(vfd).size;
    const vhead = Buffer.alloc(16);
    fs.readSync(vfd, vhead, 0, 16, 0);
    const vjsonLength = vhead.readUInt32LE(12);
    const vdataBase = 8 + vhead.readUInt32LE(4);
    const vbuffer = Buffer.alloc(vjsonLength);
    fs.readSync(vfd, vbuffer, 0, vjsonLength, 16);
    const vheader = JSON.parse(vbuffer.toString('utf8').replace(/\0+$/u, ''));

    const readOut = (node) => {
      const offset = vdataBase + Number(node.offset);
      if (node.size < 0 || offset + node.size > size) {
        throw new Error('entry out of bounds: ' + node.size + ' bytes at ' + offset);
      }
      const buffer = Buffer.alloc(node.size);
      fs.readSync(vfd, buffer, 0, node.size, offset);
      return buffer;
    };

    const manifest = JSON.parse(readOut(vheader.files['package.json']).toString('utf8'));
    if (manifest.name !== '@deepseek-ai/dsh-desktop') {
      throw new Error('root package.json does not look like the app manifest');
    }

    const markers = [
      ['lib/main.js', '__dshPortableRoot'],
      [TYPES_DIR, 'portableHome'],
      [CONTROLLER, 'portableHome'],
    ];
    for (const [filePath, marker] of markers) {
      const buffer = readOut(readNodeByPath(vheader, filePath));
      if (!buffer.includes(marker)) throw new Error('patch marker missing from ' + filePath);
    }

    let compared = 0;
    (function walkVerify(node, prefix) {
      for (const [name, child] of Object.entries(node.files || {})) {
        const filePath = prefix ? prefix + '/' + name : name;
        if (child.files) {
          walkVerify(child, filePath);
          continue;
        }
        if (child.unpacked) continue;
        const written = readOut(child);
        if (patched.has(filePath)) continue;
        const original = originalLayout.get(filePath);
        if (!original) throw new Error('unexpected new entry: ' + filePath);
        const source = readOriginal(original);
        if (!written.equals(source)) throw new Error('content changed unexpectedly: ' + filePath);
        compared++;
      }
    })(vheader, '');
    console.log('verified: ' + compared + ' untouched files identical, root package.json parses');
  } finally {
    fs.closeSync(vfd);
  }
}

function readNodeByPath(node, filePath) {
  let current = node;
  for (const part of filePath.split('/')) {
    current = current.files[part];
    if (!current) fail('asar layout changed: missing ' + filePath);
  }
  return current;
}

const items = [];
let cursor = 0;

(function walk(node, prefix) {
  for (const [name, child] of Object.entries(node.files || {})) {
    const filePath = prefix ? prefix + '/' + name : name;
    if (child.files) {
      walk(child, filePath);
      continue;
    }
    if (child.unpacked) continue; // files stay in app.asar.unpacked
    const data = patched.get(filePath) ?? readEntry(child);
    child.offset = String(cursor);
    child.size = data.length;
    child.integrity = integrityOf(data);
    cursor += data.length;
    items.push(data);
  }
})(header, '');

const headerJson = Buffer.from(JSON.stringify(header), 'utf8');
const paddedHeader = Buffer.concat([
  headerJson,
  Buffer.alloc((4 - (headerJson.length % 4)) % 4, 0x20),
]);

const preamble = Buffer.alloc(16);
preamble.writeUInt32LE(4, 0);
preamble.writeUInt32LE(paddedHeader.length + 8, 4);
preamble.writeUInt32LE(paddedHeader.length + 4, 8);
preamble.writeUInt32LE(paddedHeader.length, 12);

const output = fs.openSync(OUT, 'w');
fs.writeSync(output, preamble);
fs.writeSync(output, paddedHeader);
for (const data of items) fs.writeSync(output, data);
fs.closeSync(output);

try {
  verifyArchive(OUT);
} catch (error) {
  fs.closeSync(fd);
  fs.unlinkSync(OUT);
  fail('post-write verification failed: ' + error.message);
}

fs.closeSync(fd);

fs.unlinkSync(ASAR);
fs.renameSync(OUT, ASAR);
console.log('patched: ' + ASAR);
