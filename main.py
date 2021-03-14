#!/usr/bin/env python3

# https://kapeli.com/docsets#dashDocset
# https://github.com/Kapeli/Dash-User-Contributions/wiki/Docset-Contribution-Checklist
# https://github.com/Kapeli/Dash-User-Contributions#contribute-a-new-docset
# https://www.crummy.com/software/BeautifulSoup/bs4/doc/

import subprocess
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
from os.path import join

html_bundle_name = "docs.swift.org"
docset_file_name = "Swift.docset"
assets_dir = "assets"
build_dir = ".build"
cache_dir = ".cache"

# cache
docs_cache_path_src = join(cache_dir, html_bundle_name)

# build
docset_path = join(build_dir, docset_file_name)
docset_plist_path = join(docset_path, "Contents/Info.plist")
docset_db_path = join(docset_path, "Contents/Resources/docSet.dsidx")
docs_dirname = join(docset_path, "Contents/Resources/Documents")
docs_path = join(docs_dirname, html_bundle_name)
html_pages = join(docs_path, "swift-book/LanguageGuide")

json_path = join(build_dir, "docset.json")
tar_path = join(build_dir, "Swift.tgz")
icon = join(assets_dir, "icon.png")
icon2x = join(assets_dir, "icon@2x.png")
readme = "README.md"

json_obj = {
    "name": "Swift Language Guide",
    "version": "5.4",
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
    "CFBundleName": "Swift 5.4 Language Guide",
    "DocSetPlatformFamily": "Swift",
    "isDashDocset": True,
    "dashIndexFilePath": "docs.swift.org/swift-book/LanguageGuide/TheBasics.html",
    "DashDocSetFallbackURL": "https://docs.swift.org/swift-book/LanguageGuide/TheBasics.html",
    "isJavaScriptEnabled": True,
    "DashDocSetFamily": "dashtoc",
}

os.makedirs(cache_dir, exist_ok=True)
shutil.rmtree(build_dir, ignore_errors=True)
os.makedirs(os.path.dirname(docs_dirname))

# copy assets
shutil.copy(icon, build_dir)
shutil.copy(icon2x, build_dir)
shutil.copy(readme, build_dir)
fp = open(json_path, "w+")
json.dump(json_obj, fp, indent=2)
fp.close()

if not os.path.exists(docs_cache_path_src):
    check_output(
        [
            "/usr/local/bin/wget",
            "--show-progress",
            "--recursive",
            "--page-requisites",
            "--no-parent",
            "--directory-prefix",
            cache_dir,
            "https://docs.swift.org/swift-book/LanguageGuide/TheBasics.html",
        ]
    )

shutil.copytree(docs_cache_path_src, docs_path)

fp = open(docset_plist_path, "wb")
plistlib.dump(plist_obj, fp)
fp.close()

try:
    os.unlink(docset_db_path)
except:
    pass

connection = sqlite3.connect(docset_db_path)

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

        if first_child.name == "h1":
            dash_entry_type = "Guide"
        elif first_child.name == "h2":
            dash_entry_type = "Section"
        else:
            dash_entry_type = "Entry"
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

subprocess.check_output(["/usr/bin/tar", "--exclude='.DS_Store'", "-cvzf", tar_path, docset_path
                         ])

os.rename(docset_path, os.path.join(
    os.path.dirname(docset_path), "FOR_TESTING.docset"))
os.makedirs(join(build_dir, "Swift"))
for file in glob(join(build_dir, "*")):
    if "FOR_TESTING" in file:
        continue
    shutil.move(file, join(build_dir, "Swift"))
