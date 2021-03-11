# dash-docset-swift-5.3-language-guide

[Dash docset](https://github.com/Kapeli/Dash-User-Contributions) and generation script for the [Swift 5.3 Language Guide](https://docs.swift.org/swift-book/LanguageGuide/).

This script will fetch the documentation from the Swift homepage, build the Dash index, and put everything in a `.build` folder in the same directory the script has been executed in.

## Features

- Includes entries for each 'chapter' and its sub-sections.
- Tables of contents for sub-sections.

## Dependencies

- Python 3.8+
- [html5lib](https://pypi.org/project/html5lib/) (`pip3 install html5lib`)
- [beautifulsoup4](https://www.crummy.com/software/BeautifulSoup/) (`pip3 install beautifulsoup4`)
- [wget](https://www.gnu.org/software/wget/) (`brew install wget`)

## Links

- [GitHub repository](https://github.com/roeybiran/dash-docset-swift-5.3-language-guide)
