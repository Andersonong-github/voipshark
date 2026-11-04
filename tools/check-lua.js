#!/usr/bin/env node
/*
 * Syntax-check every Lua file of the plugin set.
 *
 * Wireshark executes the plugins with Lua 5.4, but a standalone Lua
 * interpreter is not always installed. This script only parses the sources
 * with luaparse (no execution), so it can run on a bare Node.js setup and in
 * GitHub Actions.
 *
 * Usage:
 *   npm install --no-save luaparse
 *   node tools/check-lua.js
 */

"use strict";

const fs = require("fs");
const path = require("path");

let luaparse;
try {
  luaparse = require("luaparse");
} catch (err) {
  console.error("luaparse is not installed. Run: npm install --no-save luaparse");
  process.exit(2);
}

const root = path.resolve(__dirname, "..", "plugins");
const files = [];

function walk(dir) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      walk(full);
    } else if (entry.isFile() && entry.name.endsWith(".lua")) {
      files.push(full);
    }
  }
}

walk(root);
files.sort();

let failed = 0;
for (const file of files) {
  const rel = path.relative(path.resolve(__dirname, ".."), file);
  try {
    luaparse.parse(fs.readFileSync(file, "utf8"), {
      luaVersion: "5.3",
      comments: false,
      scope: false,
    });
  } catch (err) {
    failed += 1;
    const line = err.line ? `:${err.line}` : "";
    console.error(`FAIL ${rel}${line} ${err.message}`);
  }
}

if (failed > 0) {
  console.error(`\n${failed} of ${files.length} Lua file(s) failed to parse.`);
  process.exit(1);
}

console.log(`OK: ${files.length} Lua file(s) parsed successfully.`);
