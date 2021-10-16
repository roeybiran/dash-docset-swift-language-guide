#!/bin/bash

set -o nounset

if ! command -v wget; then
	echo wget is not installed.
	exit
fi

# https://kapeli.com/docsets#dashDocset
# https://github.com/Kapeli/Dash-User-Contributions/wiki/Docset-Contribution-Checklist
# https://github.com/Kapeli/Dash-User-Contributions#contribute-a-new-docset

# define constants

PLB=/usr/libexec/PlistBuddy

BUILD_DIR="./.build"
CACHE_DIR="./.cache"
ASSETS_DIR="./assets"
README="./README.md"

KEYWORDS=("Swift" "Swift Language Guide" "Swift Book")
AUTHOR="Roey Biran"
AUTHOR_URL="https://github.com/roeybiran"
DOCS_URL="https://docs.swift.org/swift-book/LanguageGuide/TheBasics.html"
DOCSET_NAME="Swift Language Guide"
DOCSET_BUNDLE_ID="com.roeybiran.dashdocset.SwiftLanguageGuide"
FALLBACK_URL="https://docs.swift.org/swift-book/LanguageGuide/TheBasics.html"
PLATFORM_FAMILY="Swift"
INDEX_FILE_PATH="docs.swift.org/swift-book/LanguageGuide/TheBasics.html"

BUNDLE_PATH="$BUILD_DIR/$DOCSET_NAME.docset"
DOCSET_PLIST_PATH="$BUNDLE_PATH/Contents/Info.plist"
DOCSET_DB_PATH="$BUNDLE_PATH/Contents/Resources/docSet.dsidx"
HTML_PATH="$BUNDLE_PATH/Contents/Resources/Documents"

JSON_PATH="$BUILD_DIR/docset.json"
TAR_PATH="$BUILD_DIR/$DOCSET_NAME.tgz"
ICON="$ASSETS_DIR/icon.png"
ICON2X="$ASSETS_DIR/icon@2x.png"

rm -rf "$BUILD_DIR"

sleep 0.5

mkdir -p "$HTML_PATH" 2>/dev/null

# plist
for entry in \
	"Add :CFBundleIdentifier string $DOCSET_BUNDLE_ID" \
	"Add :CFBundleName string $DOCSET_NAME" \
	"Add :DocSetPlatformFamily string $PLATFORM_FAMILY" \
	"Add :isDashDocset bool true" \
	"Add :dashIndexFilePath string $INDEX_FILE_PATH" \
	"Add :DashDocSetFallbackURL string $FALLBACK_URL" \
	"Add :DashDocSetFamily string dashtoc" \
	"Add :isJavaScriptEnabled bool true"; do
	$PLB -c "$entry" "$DOCSET_PLIST_PATH" 1>/dev/null
done

# fetch docs
if ! test -d "$CACHE_DIR"; then
	wget \
		--show-progress \
		--recursive \
		--page-requisites \
		--no-parent \
		--directory-prefix "$CACHE_DIR" \
		"$DOCS_URL"
fi

# make db
sqlite3 "$DOCSET_DB_PATH" <<-EOF
	CREATE TABLE searchIndex(id INTEGER PRIMARY KEY, name TEXT, type TEXT, path TEXT);
	CREATE UNIQUE INDEX anchor ON searchIndex (name, type, path);
EOF

# copy html
cp -R "$CACHE_DIR"/* "$HTML_PATH"

# iterate html files and populate the index
while IFS=$'\n' read -r FILE; do
	# make the path relative
	relative_path="${FILE//$HTML_PATH\//}"

	# keep the file's contents around to inject dash anchors and mutate in memory instead of disk i/o
	contents="$(cat "$FILE")"

	# this will find all h1, h2, h3 suitable to appear in Dash's index
	SECTIONS="$(grep 'class="headerlink"' "$FILE")"

	while IFS=$'\n' read -r SECTION; do
		dash_name="${SECTION:4}"
		dash_name="${dash_name//<*/}"

		# https://kapeli.com/docsets#supportedentrytypes
		dash_type="Section"
		if printf "%s\n" "$SECTION" | grep -q "h1"; then
			dash_type="Guide"
		fi

		hash_link="$(printf "%s\n" "$SECTION" | grep -oE "#\S+")"
		hash_link="${hash_link%\"}"
		dash_path="$relative_path$hash_link"

		sqlite3 "$DOCSET_DB_PATH" "INSERT OR IGNORE INTO searchIndex(name, type, path) VALUES (\"${dash_name}\", \"${dash_type}\", \"${dash_path}\");"

		dash_anchor="<a name=\"//apple_ref/cpp/$dash_type/$dash_name\" class=\"dashAnchor\"></a>"
		with_dash_anchor="$SECTION\n$dash_anchor"
		# update the file contents with the newly injected anchor
		contents="$(printf "%s\n" "$contents" | sed "s|$SECTION|$with_dash_anchor|")"
	done <<<"${SECTIONS}"

	printf "%s\n" "$contents" >"$FILE"

done < <(find "$HTML_PATH" -name "*.html")

# tar
tar --exclude=".DS_Store" -cvzf "$TAR_PATH" "$BUNDLE_PATH" &>/dev/null

# json
for stmt in \
	"Add :name string $DOCSET_NAME" \
	"Add :version string 5.4" \
	"Add :archive string $DOCSET_NAME.tgz" \
	"Add :author dict" \
	"Add :author:name string $AUTHOR" \
	"Add :author:link string $AUTHOR_URL" \
	"Add :aliases array"; do
	$PLB -c "$stmt" "$JSON_PATH" 1>/dev/null
done

for ((i = 0; i < "${#KEYWORDS[@]}"; i++)); do
	$PLB -c "Add :aliases:$i string ${KEYWORDS[$i]}" "$JSON_PATH" 1>/dev/null
done
plutil -convert json "$JSON_PATH"

# README
cp "$README" "$BUILD_DIR"

# icons
cp "$ICON" "$BUILD_DIR"
cp "$ICON2X" "$BUILD_DIR"
