#!/usr/bin/env python3
"""Build Leu's real-text evaluation corpus from PDFs already in the repository.

Development-time tool only (needs poppler's pdftohtml/pdftotext). The app itself uses
PDFKit; this script approximates its spatial reconstruction (PDFBlockClassifier +
PDFTextReconstructor) from poppler's font/geometry XML:

* lines on the same baseline are merged, page-number furniture near the edges is dropped;
* a line is code when its font is monospaced or it starts with a code keyword, a heading
  when its size is >= 1.18x the body size or it is all capitals, a bullet by prefix;
* blocks break on kind change, a vertical gap > 0.8x font size, or a column change;
* paragraph lines join with spaces, code lines with newlines, blocks with blank lines.

`text` feeds DocumentAnalyzer (like SourcePageInput); `canonical` is the raw page
string (like PDFKit's page.string) and becomes AnalyzedPage.canonicalText.
"""
import hashlib, json, re, statistics, subprocess, sys
import xml.etree.ElementTree as ET

DOCS = [
    ("React Notes", "Shelf/Resources/Samples/React Notes.pdf"),
    ("System Design", "Shelf/Resources/Samples/System Design.pdf"),
    ("JavaScript Deep Dive", "Shelf/Resources/Samples/JavaScript Deep Dive.pdf"),
    ("Coding Interviews", "Shelf/Resources/Samples/Coding Interviews.pdf"),
    ("Computer Science Essentials", "Shelf/Resources/Samples/Computer Science Essentials.pdf"),
    ("Design Patterns", "Shelf/Resources/Samples/Design Patterns.pdf"),
    ("Mobile Mastery", "docs/v28/fixtures/javascript_midlevel_interview_mobile_mastery.pdf"),
]
CODE_START = re.compile(r"^(?:const |let |func |function |class |import |SELECT |\{|\})")
BULLET = re.compile(r"^(?:[•●▪◦*–-]\s+|\d+[.)]\s+)")

def text_of(node):
    return "".join(node.itertext())

def page_lines(page, fonts):
    items = []
    for t in page.findall("text"):
        s = text_of(t)
        if not s.strip():
            continue
        f = fonts[t.get("font")]
        items.append(dict(top=int(t.get("top")), left=int(t.get("left")), width=int(t.get("width")),
                          height=int(t.get("height")), text=s, size=f["size"], mono=f["mono"]))
    items.sort(key=lambda i: (i["top"], i["left"]))
    lines = []
    for it in items:
        if lines and abs(lines[-1]["top"] - it["top"]) <= 3:
            ln = lines[-1]
            gap = it["left"] - (ln["left"] + ln["width"])
            joiner = "" if it["text"].startswith(" ") or ln["text"].endswith(" ") or gap < 2 else " "
            ln["text"] += joiner + it["text"]
            ln["width"] = it["left"] + it["width"] - ln["left"]
            ln["size"] = max(ln["size"], it["size"])
            ln["mono_chars"] += len(it["text"]) if it["mono"] else 0
            ln["chars"] += len(it["text"])
        else:
            lines.append(dict(top=it["top"], left=it["left"], width=it["width"], height=it["height"],
                              text=it["text"], size=it["size"], mono_chars=len(it["text"]) if it["mono"] else 0,
                              chars=len(it["text"])))
    for ln in lines:
        ln["text"] = ln["text"].strip() if ln["mono_chars"] * 2 <= ln["chars"] else ln["text"].rstrip()
        ln["mono"] = ln["mono_chars"] * 2 > ln["chars"]
    return lines

def reconstruct(page, fonts):
    height = int(page.get("height"))
    lines = page_lines(page, fonts)
    body_sizes = sorted(s for ln in lines if not ln["mono"] for s in [ln["size"]] * max(1, ln["chars"]))
    body = body_sizes[len(body_sizes) // 2] if body_sizes else 12
    blocks, acc, kind, prev, code_origin = [], "", "paragraph", None, 0
    def flush():
        nonlocal acc
        if acc:
            blocks.append(acc)
        acc = ""
    for ln in lines:
        text = ln["text"]
        if re.fullmatch(r"\d+(?:[.\-/]\d+)*", text.strip()) and (ln["top"] < height * 0.07 or ln["top"] + ln["height"] > height * 0.93):
            continue
        letters = [c for c in text if c.isalpha()]
        if ln["mono"] or CODE_START.match(text.strip()):
            k = "code"
        elif BULLET.match(text):
            k = "bullet"
        elif ln["size"] >= body * 1.18 or (len(text) < 90 and len(letters) > 2 and all(c.isupper() for c in letters)):
            k = "heading"
        else:
            k = "paragraph"
        gap = (ln["top"] - (prev["top"] + prev["height"])) if prev else 0
        column = prev is not None and abs(prev["left"] - ln["left"]) > max(120 if k == "code" else 40, ln["width"] * 0.5)
        level = prev is not None and k == "heading" and max(prev["size"], ln["size"]) > min(prev["size"], ln["size"]) * 1.18
        if k != kind or gap > ln["size"] * 0.8 or column or level or k == "bullet":
            flush()
        kind = k
        if not acc:
            acc, code_origin = text.strip() if k != "code" else text.strip(), ln["left"]
        elif k == "code":
            indent = max(0, round((ln["left"] - code_origin) / max(1, ln["size"] * 0.6)))
            acc += "\n" + " " * min(80, indent) + text.strip()
        elif acc.endswith("-") and text[:1].islower():
            acc += text
        else:
            acc += " " + text
        prev = ln
    flush()
    return "\n\n".join(blocks)

def main():
    out = []
    for title, path in DOCS:
        xml = subprocess.run(["pdftohtml", "-xml", "-i", "-stdout", "-q", path], capture_output=True, text=True).stdout
        root = ET.fromstring(xml)
        raw = subprocess.run(["pdftotext", path, "-"], capture_output=True, text=True).stdout.split("\f")
        pages = []
        for index, page in enumerate(root.findall("page")):
            fonts = {}
            for f in page.findall("fontspec"):
                fam = f.get("family")
                fonts[f.get("id")] = dict(size=int(f.get("size")), mono=bool(re.search(r"Mono|Courier", fam, re.I)))
            # fontspecs accumulate across pages in poppler XML
            for f in root.iter("fontspec"):
                fonts.setdefault(f.get("id"), dict(size=int(f.get("size")), mono=bool(re.search(r"Mono|Courier", f.get("family"), re.I))))
            pages.append({"text": reconstruct(page, fonts), "canonical": raw[index] if index < len(raw) else ""})
        sha = hashlib.sha256(open(path, "rb").read()).hexdigest()
        out.append({"title": title, "sourcePDF": path, "sourceSHA256": sha,
                    "extractor": "poppler 24.02 pdftohtml -xml (reconstruction) + pdftotext (canonical)", "pages": pages})
        print(title, len(pages), file=sys.stderr)
    json.dump(out, sys.stdout, indent=1, ensure_ascii=False)

if __name__ == "__main__":
    main()
