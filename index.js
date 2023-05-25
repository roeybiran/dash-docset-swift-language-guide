import fs from "node:fs";
import { join } from "node:path";
import plist from "plist";
import Database from "better-sqlite3";
import { execFileSync } from "node:child_process";
import process from "node:process";

// https://github.com/apple/swift-book
// https://kapeli.com/docsets#dashDocset
// https://github.com/Kapeli/Dash-User-Contributions/wiki/Docset-Contribution-Checklist
// https://github.com/Kapeli/Dash-User-Contributions#contribute-a-new-docset

const DOCSET_VERSION = "5.7"; // swift version

// BEGIN CONSTANTS
const ARCHIVE_NAME = "SwiftLanguageGuide";
const DOCSET_NAME = "Swift Language Guide";
const KEYWORDS = ["Swift", "Swift Language Guide", "Swift Book"];
const AUTHOR = "Roey Biran";
const AUTHOR_URL = "https://github.com/roeybiran";
const FALLBACK_URL = "https://docs.swift.org/swift-book/";
const DOCSET_BUNDLE_ID = "com.roeybiran.dashdocset.$ARCHIVE_NAME";
const PLATFORM_FAMILY = "Swift";
const SWIFT_BOOK_REPO = "https://github.com/apple/swift-book";
// END CONSTANTS

const ASSETS_PATH = "./assets";
const README = "./README.md";
const ARCHIVE_BASENAME = `${ARCHIVE_NAME}.tgz`;
const BUNDLE_BASENAME = `${ARCHIVE_NAME}.docset`;
const BUILD_PATH = "./.build";
const BUNDLE_PATH = `${BUILD_PATH}/${BUNDLE_BASENAME}`;
const DOCSET_DB_DIRNAME = `${BUNDLE_PATH}/Contents/Resources`;
const DOCSET_DB_PATH = `${DOCSET_DB_DIRNAME}/docSet.dsidx`;
const DOCSET_PLIST_PATH = `${BUNDLE_PATH}/Contents/Info.plist`;
const HTML_PATH = `${BUNDLE_PATH}/Contents/Resources/Documents`;
const ICON = `${ASSETS_PATH}/icon.png`;
const ICON2X = `${ASSETS_PATH}/icon@2x.png`;
const JSON_PATH = `${BUILD_PATH}/docset.json`;
const TAR_PATH = `${BUILD_PATH}/${ARCHIVE_BASENAME}`;

fs.mkdirSync(HTML_PATH, { recursive: true });

// PLIST
fs.rmSync(DOCSET_PLIST_PATH, { force: true });
const plistData = {
  CFBundleIdentifier: DOCSET_BUNDLE_ID,
  CFBundleName: DOCSET_NAME,
  DocSetPlatformFamily: PLATFORM_FAMILY,
  isDashDocset: true,
  dashIndexFilePath: "docs.swift.org/swift-book/index.html",
  DashDocSetFallbackURL: FALLBACK_URL,
  DashDocSetFamily: "dashtoc",
  isJavaScriptEnabled: true,
};
const plistString = plist.build(plistData);
fs.writeFileSync(DOCSET_PLIST_PATH, plistString);

if (!fs.existsSync(join(BUILD_PATH, "swift-book"))) {
  try {
    execFileSync("/usr/bin/git", [
      "clone",
      "--depth",
      "1",
      "--single-branch",
      "--no-tags",
      SWIFT_BOOK_REPO,
      join(BUILD_PATH, "swift-book"),
    ]);
  } catch (error) {
    console.log(error);
    process.exit(1);
  }
}

if (fs.readdirSync(HTML_PATH).length === 0) {
  try {
    execFileSync("/usr/bin/xcrun", [
      "docc",
      "convert",
      join(BUILD_PATH, "swift-book", "TSPL.docc"),
      "--output-dir",
      HTML_PATH,
    ]);
  } catch (error) {
    console.log(error);
    process.exit(1);
  }
}

const {
  interfaceLanguages: { swift },
} = JSON.parse(
  fs.readFileSync(join(HTML_PATH, "index", "index.json"), {
    encoding: "utf-8",
  })
);

const { path, title, type, children } = swift[0];
// console.log(path, title, type, children);

const indexFilePath = { path };

// DB
fs.rmSync(DOCSET_DB_PATH, { force: true });
const db = new Database(DOCSET_DB_PATH);
[
  "CREATE TABLE searchIndex(id INTEGER PRIMARY KEY, name TEXT, type TEXT, path TEXT)",
  "CREATE UNIQUE INDEX anchor ON searchIndex (name, type, path)",
].forEach((s) => db.prepare(s).run());

const guides = children
  .filter(({ type }) => type === "article")
  .map(({ path, title }) => ({
    title,
    path: join(path, "index.html"),
    dashEntryType: "Guide",
  }))
  .forEach(({ path, title, dashEntryType }) => {
		console.log(path);
    db.prepare(
      "INSERT OR IGNORE INTO searchIndex(name, type, path) VALUES (?, ?, ?)"
    ).run(title, dashEntryType, path);
  });

db.close();

// # tar
// tar --exclude=".DS_Store" -cvzf "$TAR_PATH" -C "$BUILD_PATH" "$BUNDLE_BASENAME" &>/dev/null

// # json
// json="
// {
// 	\"name\": \"$DOCSET_NAME\",
// 	\"version\": \"$DOCSET_VERSION\",
// 	\"archive\": \"$ARCHIVE_BASENAME\",
// 	\"author\": {
// 		\"name\": \"$AUTHOR\",
// 		\"link\": \"$AUTHOR_URL\"
// 	},
// 	\"aliases\": [$KEYWORDS],
// 	\"specific_versions\": []
// }"

// printf "%s\n" "$json" >"$JSON_PATH"

// # README
// cp "$README" "$BUILD_PATH"
// # icons
// cp "$ICON" "$BUILD_PATH"
// cp "$ICON2X" "$BUILD_PATH"
