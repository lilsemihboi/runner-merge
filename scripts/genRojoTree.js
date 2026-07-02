/*
MIT License

Copyright (c) 2021 Leif Stout

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

const fs = require("fs");
const path = require("path");

const BASE_PATH = path.join(__dirname, "../src");

const BLACKLISTED_DIRS = [
  toPosix(path.join(BASE_PATH, "library")),
];

// Tracks folders that are "claimed" by init.luau
const initClaimedFolders = new Set();

function toPosix(p) {
  return p.split(path.sep).join("/");
}

function toPascalCase(str) {
  return str.charAt(0).toUpperCase() + str.slice(1);
}

function getVirtualPath(filepath) {
  const relativePath = path.relative(BASE_PATH, filepath);
  const parts = relativePath.split(path.sep);
  const filename = path.basename(filepath, ".luau");
  const isServer = filename.toLowerCase().includes("server");

  const folderName =
    parts.length > 1 ? toPascalCase(parts[parts.length - 2]) : "";
  let name;

  if (filename === "init") {
    name = folderName;
  } else if (
    ["server", "client", "utils", "types"].includes(filename.toLowerCase())
  ) {
    name = folderName + toPascalCase(filename);
  } else {
    name = filename;
  }

  return {
    isInit: filename === "init",
    target: isServer ? "ServerScriptService" : "ReplicatedStorage",
    folder: parts.slice(0, -1).map(toPascalCase),
    name,
    file:
      filename === "init"
        ? toPosix(path.join("src", ...parts.slice(0, -1)))
        : toPosix(path.join("src", ...parts)),
  };
}

const tree = {
  name: "runner-merge",
  tree: {
    $className: "DataModel",

    ReplicatedStorage: {
      Shared: {
        $className: "Folder",
        Services: { $className: "Folder" },
        Classes: { $className: "Folder" },
        Modules: { $className: "Folder" },
      },
      Packages: { $path: "Packages" },
    },
    ServerScriptService: {
      Server: { $path: "src/library/Server.server.luau" },
      Services: { $className: "Folder" },
      Classes: { $className: "Folder" },
      Modules: { $className: "Folder" },
    },

    StarterPlayer: {
      StarterPlayerScripts: {
        Client: { $path: "src/library/Client.client.luau" },
      },
    },
  }
};

const sharedRoot = tree.tree.ReplicatedStorage.Shared;
const serverRoot = tree.tree.ServerScriptService;

// Recursively walk all files
function walk(dir, callback) {
  if (BLACKLISTED_DIRS.includes(toPosix(dir))) return;

  fs.readdirSync(dir, { withFileTypes: true }).forEach((entry) => {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      walk(full, callback);
    } else if (entry.isFile() && entry.name.endsWith(".luau")) {
      callback(full);
    }
  });
}

walk(BASE_PATH, (filepath) => {
  const { target, folder, name, file, isInit } = getVirtualPath(filepath);
  const root = target === "ServerScriptService" ? serverRoot : sharedRoot;

  const fullFolderKey = folder.join("/");

  // If it's init.luau, promote the parent folder
  if (isInit) {
    const parent = folder.slice(0, -1).reduce((acc, part) => {
      if (!acc[part]) acc[part] = { $className: "Folder" };
      return acc[part];
    }, root);

    parent[name] = { $path: file };
    initClaimedFolders.add(fullFolderKey);
    return;
  }

  // If folder was claimed by init.luau, skip assigning children
  if (initClaimedFolders.has(fullFolderKey)) return;

  let current = root;
  for (const part of folder) {
    if (!current[part]) current[part] = { $className: "Folder" };
    current = current[part];
  }

  current[name] = { $path: file };
});

fs.writeFileSync("default.project.json", JSON.stringify(tree, null, 2));
console.log("[CS-TFX] Generated default.project.json! ✅");
return;
