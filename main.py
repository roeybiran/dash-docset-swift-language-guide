#!/usr/bin/env python3

# https://kapeli.com/docsets#dashDocset
# https://github.com/Kapeli/Dash-User-Contributions/wiki/Docset-Contribution-Checklist
# https://github.com/Kapeli/Dash-User-Contributions#contribute-a-new-docset
# https://www.crummy.com/software/BeautifulSoup/bs4/doc/

import sys
import os
import shutil
import plistlib
import json
import sqlite3
import re
from subprocess import check_output
from glob import glob
from bs4 import BeautifulSoup

html_bundle_name = "docs.swift.org"
build_dir = ".build"
docset_file_name = "Swift.docset"

# docs_src = f"{src_dir}/{html_bundle_name}"
assets_dir = "assets"
plist_path = f"{build_dir}/{docset_file_name}/Contents/Info.plist"
db_path = f"{build_dir}/{docset_file_name}/Contents/Resources/docSet.dsidx"
json_path = f"{build_dir}/docset.json"
docs_dirname = f"{build_dir}/{docset_file_name}/Contents/Resources/Documents"
docs_path = f"{docs_dirname}/{html_bundle_name}"
html_pages = f"{docs_path}/swift-book/LanguageGuide"

json_obj = {
    "name": "Swift Language Guide",
    "version": "5.3",
    "archive": "Swift.tgz",
    "author": {"name": "Roey Biran", "link": "https://github.com/roeybiran"},
    "aliases": ["Swift", "Swift Language Guide", "Swift Book"],
    "specific_versions": [
        {
            "_comment": "This is optional. Only support specific/older versions if it actually makes sense. This list should be ordered, newest/latest versions should be at the top."
        }
    ],
}

plist_obj = {
    "CFBundleIdentifier": "com.roeybiran.dashdocset.SwiftLanguageGuide",
    "CFBundleName": "Swift 5.3 Language Guide",
    "DocSetPlatformFamily": "Swift",
    "isDashDocset": True,
    "dashIndexFilePath": "docs.swift.org/swift-book/LanguageGuide/TheBasics.html",
    "DashDocSetFallbackURL": "https://docs.swift.org/swift-book/LanguageGuide/TheBasics.html",
    "isJavaScriptEnabled": True,
    "DashDocSetFamily": "dashtoc",
}

#

shutil.rmtree(build_dir, ignore_errors=True)
os.makedirs(os.path.dirname(docs_dirname))

check_output(
    [
        "/usr/local/bin/wget",
        "--show-progress",
        "--recursive",
        "--page-requisites",
        "--no-parent",
        "--directory-prefix",
        docs_dirname,
        "https://docs.swift.org/swift-book/LanguageGuide/TheBasics.html",
    ]
)

shutil.copy(f"{assets_dir}/icon.png", build_dir)
shutil.copy(f"{assets_dir}/icon@2x.png", build_dir)

fp = open(json_path, "w+")
json.dump(json_obj, fp)
fp.close()

fp = open(plist_path, "wb")
plistlib.dump(plist_obj, fp)
fp.close()

try:
    os.unlink(db_path)
except:
    pass

connection = sqlite3.connect(db_path)
cursor = connection.cursor()
cursor.execute(
    "CREATE TABLE IF NOT EXISTS searchIndex(id INTEGER PRIMARY KEY, name TEXT, type TEXT, path TEXT);"
)
cursor.execute(
    "CREATE UNIQUE INDEX IF NOT EXISTS anchor ON searchIndex (name, type, path);"
)


for page in glob(f"{html_pages}/*"):
    fp = open(page, "r+")
    soup = BeautifulSoup(fp, "lxml")

    #
    menu = soup.find(id="jump_to")
    menu["style"] = "visibility: hidden;"
    #
    for div in soup.find_all("div", "section"):
        # an h1, h2, h3 or h4, containg text and an <a> tag
        first_child = div.contents[1]
        first_child_tag = first_child.name

        dash_entry_type = "Guide"
        dash_name = first_child.contents[0]

        anchor = first_child.contents[1]["href"]
        # make the *.html paths relative
        dash_path = re.sub(r"^.+?Resources/Documents/", "", page)
        dash_path = dash_path + anchor
        dash_anchor_node = soup.new_tag("a")
        dash_anchor_node["name"] = "//apple_ref/cpp/{}/{}".format(
            dash_entry_type, dash_name
        )
        dash_anchor_node["class"] = "dashAnchor"
        div.insert(0, dash_anchor_node)

        cursor.execute(
            "INSERT OR IGNORE INTO searchIndex(name, type, path) VALUES (?, ?, ?);",
            (dash_name, dash_entry_type, dash_path),
        )

    fp.seek(0)
    fp.truncate()
    fp.write(str(soup))
    fp.close()

connection.commit()
connection.close()
