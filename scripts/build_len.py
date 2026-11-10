#!/usr/bin/env python3
"""Length in lines of every `build` method under a dir (default lib/ui), longest first.

Usage: build_len.py [DIR] [--metrics] [--self-test]
  --metrics    also print the structure greps of docs/storico/fasi/fase-38 (lines/files, counts)
"""
import re
import signal
import subprocess
import sys
from pathlib import Path


def mask(src):
    """Blank out comments and string contents (keeps length and newlines)."""
    out = list(src)
    n, i = len(src), 0
    stack = []  # entries: [quote, raw, triple, depth] for strings being scanned

    def blank(a, b):
        for k in range(a, b):
            if out[k] != "\n":
                out[k] = " "

    while i < n:
        c = src[i]
        if stack:
            q, raw, tri, depth = stack[-1]
            if depth:  # inside ${ ... } code
                if c == "{":
                    stack[-1][3] += 1
                elif c == "}":
                    stack[-1][3] -= 1
                    if stack[-1][3] == 0:
                        blank(i, i + 1)
                        i += 1
                        continue
                elif c in "'\"":
                    t = src.startswith(c * 3, i)
                    stack.append([c * 3 if t else c, False, t, 0])
                    blank(i, i + (3 if t else 1))
                    i += 3 if t else 1
                    continue
                blank(i, i + 1) if c not in "{}" else None
                i += 1
                continue
            if c == "\\" and not raw:
                blank(i, i + 2)
                i += 2
                continue
            if not raw and c == "$" and src.startswith("${", i):
                stack[-1][3] = 1
                blank(i, i + 2)
                i += 2
                continue
            if src.startswith(q, i):
                blank(i, i + len(q))
                i += len(q)
                stack.pop()
                continue
            blank(i, i + 1)
            i += 1
            continue
        if src.startswith("//", i):
            j = src.find("\n", i)
            j = n if j < 0 else j
            blank(i, j)
            i = j
        elif src.startswith("/*", i):
            d, j = 1, i + 2
            while j < n and d:
                if src.startswith("/*", j):
                    d, j = d + 1, j + 2
                elif src.startswith("*/", j):
                    d, j = d - 1, j + 2
                else:
                    j += 1
            blank(i, j)
            i = j
        elif c in "'\"":
            raw = i > 0 and src[i - 1] == "r" and not (i > 1 and (src[i - 2].isalnum() or src[i - 2] == "_"))
            t = src.startswith(c * 3, i)
            stack.append([c * 3 if t else c, raw, t, 0])
            blank(i, i + (3 if t else 1))
            i += 3 if t else 1
        else:
            i += 1
    return "".join(out)


BUILD_RE = re.compile(r"^[ \t]*(?:@override\s+)?[\w<>?,. ]*\bbuild\s*\(", re.M)
CLASS_RE = re.compile(r"^\s*(?:abstract\s+|final\s+|base\s+)*(?:class|mixin)\s+(\w+)", re.M)


def _match(m, i, open_c, close_c):
    d = 0
    for j in range(i, len(m)):
        if m[j] == open_c:
            d += 1
        elif m[j] == close_c:
            d -= 1
            if d == 0:
                return j
    return len(m) - 1


def build_methods(src):
    """Yield (class, lines) for each build method in Dart source."""
    m = mask(src)
    classes = [(c.start(), c.group(1)) for c in CLASS_RE.finditer(m)]
    for b in BUILD_RE.finditer(m):
        start = m.index("build", b.start())
        p = m.index("(", start)
        k = _match(m, p, "(", ")") + 1
        rest = m[k:].lstrip()
        k = len(m) - len(rest)
        if rest.startswith("=>"):
            end = m.index(";", k)
        elif rest.startswith("{"):
            end = _match(m, k, "{", "}")
        else:
            continue  # abstract / not a method
        first = m.count("\n", 0, start)
        cls = next((n for pos, n in reversed(classes) if pos < start), "?")
        yield cls, m.count("\n", 0, end) - first + 1


def self_test():
    src = '''class A extends StatelessWidget {
  @override
  Widget build(BuildContext c) {
    final s = 'a { ${x.map((e) { return "}"; })} }';
    // } comment {
    /* } */
    return Text(r'{', key: Key("""
}
"""));
  }
}
class B {
  Widget build(BuildContext c) => Text('}');
}
'''
    assert list(build_methods(src)) == [("A", 8), ("B", 1)], list(build_methods(src))
    print("self-test ok")


def grep(pattern, root):
    args = ["grep", "-rn", "--include=*.dart", "-e", pattern, root]
    r = subprocess.run(args, capture_output=True, text=True)
    lines = [l for l in r.stdout.splitlines() if l]
    return len(lines), len({l.split(":", 1)[0] for l in lines})


def main():
    signal.signal(signal.SIGPIPE, signal.SIG_DFL)
    a = sys.argv[1:]
    if "--self-test" in a:
        return self_test()
    root = next((x for x in a if not x.startswith("--")), "lib/ui")
    rows = []
    for f in sorted(Path(root).rglob("*.dart")):
        for cls, n in build_methods(f.read_text(encoding="utf-8")):
            rows.append((n, str(f), cls))
    for n, f, cls in sorted(rows, reverse=True):
        print(f"{n:5d}  {f}  {cls}")
    print(f"build > 120 lines: {sum(r[0] > 120 for r in rows)}   > 150 lines: {sum(r[0] > 150 for r in rows)}   (total {len(rows)})")
    if "--metrics" in a:
        for label, pat in [("databaseProvider|RepositoryProvider", r"databaseProvider\|RepositoryProvider"),
                           ("SnackBar(", "SnackBar("), ("AppBar(", "AppBar("),
                           ("Duration(milliseconds", "Duration(milliseconds")]:
            ln, fl = grep(pat, root)
            print(f"{label}: {ln} lines / {fl} files")


if __name__ == "__main__":
    main()
