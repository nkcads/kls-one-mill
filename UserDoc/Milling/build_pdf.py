#!/usr/bin/env python
"""Build KLSOneMill-Milling-UserGuide.pdf from the Markdown pages in this folder.

Concatenates README.md and the numbered pages below into one HTML document and prints it to
PDF using Chrome's built-in headless PDF printer (chrome --headless --print-to-pdf). No pandoc,
LaTeX, or other external tool is required — just Chrome (already installed on any dev machine
here) and the "markdown" PyPI package (`py -m pip install markdown`).

Usage (from this folder):
    py build_pdf.py
    py build_pdf.py --out KLSOneMill-Milling-UserGuide.pdf --chrome "C:\\path\\to\\chrome.exe"

Add a new page's filename to PAGES (in the order it should appear) whenever the README's
contents table gains one.
"""
import argparse
import html
import os
import re
import shutil
import subprocess
import sys
import tempfile

try:
    import markdown
except ImportError:
    sys.exit(
        "Missing dependency 'markdown'. Install it with:\n"
        "    py -m pip install markdown"
    )

HERE = os.path.dirname(os.path.abspath(__file__))

# Order matters -- this is the manual's reading order, README first as cover/TOC.
PAGES = [
    "README.md",
    "01-Overview-and-Workflow.md",
    "02-Input-Settings.md",
    "03-Raw-Part-and-Implants.md",
    "04-Holes-Csys-and-Templates.md",
    "05-Struts-and-Links.md",
    "06-Strategy-Tree-and-Session.md",
    "07-Generation-Validation-and-Toolpath.md",
    "08-Output-and-Postprocessing.md",
    "09-Configuration-Reference.md",
    "10-Extended-Settings.md",
]

CHROME_CANDIDATES = [
    r"C:\Program Files\Google\Chrome\Application\chrome.exe",
    r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
    os.path.expandvars(r"%LOCALAPPDATA%\Google\Chrome\Application\chrome.exe"),
]

CSS = """
body { font-family: -apple-system, Segoe UI, Arial, sans-serif; color: #1a1a1a;
       line-height: 1.5; font-size: 11pt; max-width: 100%; }
h1 { font-size: 20pt; border-bottom: 2px solid #ccc; padding-bottom: 6px; margin-top: 0; }
h2 { font-size: 15pt; margin-top: 1.6em; }
h3 { font-size: 12.5pt; }
code, pre { font-family: Consolas, monospace; background: #f2f2f2; }
pre { padding: 8px; overflow-x: auto; }
blockquote { border-left: 3px solid #bbb; margin: 0.8em 0; padding: 2px 12px; color: #444; }
table { border-collapse: collapse; width: 100%; margin: 0.8em 0; }
th, td { border: 1px solid #ccc; padding: 4px 8px; text-align: left; }
a { color: #1a56db; text-decoration: none; }
section.page { page-break-before: always; }
section.page:first-of-type { page-break-before: auto; }
"""

# Matches a Markdown link to one of our own pages, e.g. [text](03-Raw-Part-and-Implants.md)
PAGE_LINK_RE = re.compile(r"\]\((\d\d-[A-Za-z-]+)\.md\)")


def slug_for(filename):
    """Anchor id for a page, derived from its filename without extension."""
    return os.path.splitext(filename)[0]


def load_page_markdown(filename):
    with open(os.path.join(HERE, filename), "r", encoding="utf-8") as f:
        text = f.read()
    # Rewrite cross-page links ("03-Raw-Part-and-Implants.md") into in-document anchors so they
    # still work once everything is one HTML file.
    return PAGE_LINK_RE.sub(lambda m: "](#" + m.group(1) + ")", text)


def build_html(pages):
    md = markdown.Markdown(extensions=["tables", "fenced_code", "sane_lists"])
    sections = []
    for filename in pages:
        md.reset()
        body = md.convert(load_page_markdown(filename))
        sections.append(
            f'<section class="page" id="{html.escape(slug_for(filename))}">{body}</section>'
        )
    return (
        "<!doctype html><html><head><meta charset='utf-8'>"
        f"<title>KLS OneMill — Milling User Guide</title><style>{CSS}</style>"
        "</head><body>" + "\n".join(sections) + "</body></html>"
    )


def find_chrome(explicit):
    if explicit:
        return explicit
    found = shutil.which("chrome") or shutil.which("chrome.exe")
    if found:
        return found
    for candidate in CHROME_CANDIDATES:
        if candidate and os.path.isfile(candidate):
            return candidate
    sys.exit(
        "Could not find chrome.exe automatically. Pass its path with --chrome, e.g.\n"
        r'    py build_pdf.py --chrome "C:\Program Files\Google\Chrome\Application\chrome.exe"'
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", default="KLSOneMill-Milling-UserGuide.pdf",
                         help="Output PDF path (relative to this folder unless absolute).")
    parser.add_argument("--chrome", default=None, help="Path to chrome.exe.")
    args = parser.parse_args()

    out_path = args.out if os.path.isabs(args.out) else os.path.join(HERE, args.out)
    chrome = find_chrome(args.chrome)

    html_doc = build_html(PAGES)
    with tempfile.NamedTemporaryFile(
        "w", suffix=".html", delete=False, encoding="utf-8", dir=HERE
    ) as tmp:
        tmp.write(html_doc)
        tmp_path = tmp.name

    try:
        cmd = [
            chrome,
            "--headless",
            "--disable-gpu",
            "--no-pdf-header-footer",
            f"--print-to-pdf={out_path}",
            "file:///" + tmp_path.replace("\\", "/"),
        ]
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
        if result.returncode != 0 or not os.path.isfile(out_path):
            sys.exit(
                "Chrome failed to produce the PDF.\n"
                f"stdout: {result.stdout}\nstderr: {result.stderr}"
            )
    finally:
        os.remove(tmp_path)

    print(f"Wrote {out_path} ({os.path.getsize(out_path):,} bytes)")


if __name__ == "__main__":
    main()
