#!/bin/bash

set -o nounset

if ! command -v wget &>/dev/null; then
	echo wget is not installed.
	exit
fi

# https://kapeli.com/docsets#dashDocset
# https://github.com/Kapeli/Dash-User-Contributions/wiki/Docset-Contribution-Checklist
# https://github.com/Kapeli/Dash-User-Contributions#contribute-a-new-docset

# BEGIN CONSTANTS (configure as necessary)
DOCSET_VERSION="5.7" # swift version
ARCHIVE_NAME="SwiftLanguageGuide"
DOCSET_NAME="Swift Language Guide"
KEYWORDS='"Swift", "Swift Language Guide", "Swift Book"'
AUTHOR="Roey Biran"
AUTHOR_URL="https://github.com/roeybiran"
FALLBACK_URL="https://"
DOCSET_BUNDLE_ID="com.roeybiran.dashdocset.$ARCHIVE_NAME"
PLATFORM_FAMILY="Swift"
INDEX_FILE_PATH="docs.swift.org/swift-book/index.html"
DOCS_FETCH_URL="https://docs.swift.org/swift-book/"
# END CONSTANTS

BUILD_PATH="./.build"
DIST_PATH="./.dist"
CACHE_PATH="./.cache"
ASSETS_PATH="./assets"
README="./README.md"
ARCHIVE_BASENAME="$ARCHIVE_NAME.tgz"
BUNDLE_BASENAME="$ARCHIVE_NAME.docset"
BUNDLE_PATH="$BUILD_PATH/$BUNDLE_BASENAME"
DOCSET_DB_PATH="$BUNDLE_PATH/Contents/Resources/docSet.dsidx"
DOCSET_PLIST_PATH="$BUNDLE_PATH/Contents/Info.plist"
HTML_PATH="$BUNDLE_PATH/Contents/Resources/Documents"
ICON="$ASSETS_PATH/icon.png"
ICON2X="$ASSETS_PATH/icon@2x.png"
JSON_PATH="$DIST_PATH/docset.json"
TAR_PATH="$DIST_PATH/$ARCHIVE_BASENAME"

PLB=/usr/libexec/PlistBuddy

rm -rf "${BUILD_PATH:?}"/* "${DIST_PATH:?}"/*

sleep 0.5

mkdir -p "$HTML_PATH" "$BUILD_PATH" "$DIST_PATH" 2>/dev/null

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

if [ "${1:-""}" = '--refetch' ]; then
	rm -rf "$CACHE_PATH"
fi

# fetch docs
if ! test -d "$CACHE_PATH"; then
	wget \
		--show-progress \
		--recursive \
		--page-requisites \
		--no-parent \
		--directory-prefix "$CACHE_PATH" \
		--compression=gzip \
		"$DOCS_FETCH_URL"
fi

# make db
sqlite3 "$DOCSET_DB_PATH" <<-EOF
	CREATE TABLE searchIndex(id INTEGER PRIMARY KEY, name TEXT, type TEXT, path TEXT);
	CREATE UNIQUE INDEX anchor ON searchIndex (name, type, path);
EOF

# copy html
cp -R "$CACHE_PATH"/* "$HTML_PATH"

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
		# TODO: percent escape
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
tar --exclude=".DS_Store" -cvzf "$TAR_PATH" -C "$BUILD_PATH" "$BUNDLE_BASENAME" &>/dev/null

# json
json="
{
	\"name\": \"$DOCSET_NAME\",
	\"version\": \"$DOCSET_VERSION\",
	\"archive\": \"$ARCHIVE_BASENAME\",
	\"author\": {
		\"name\": \"$AUTHOR\",
		\"link\": \"$AUTHOR_URL\"
	},
	\"aliases\": [$KEYWORDS],
	\"specific_versions\": []
}"

printf "%s\n" "$json" >"$JSON_PATH"

# README
cp "$README" "$DIST_PATH"

# icons
cp "$ICON" "$DIST_PATH"
cp "$ICON2X" "$DIST_PATH"
