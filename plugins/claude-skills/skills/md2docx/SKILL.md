---
name: md2docx
description: This skill should be used when the user asks to "convert markdown to word", "convert md to docx", "make a word doc", "export to docx", or wants to convert .md files to .docx format. Produces professionally styled documents with navy headings, code blocks, and tables.
version: 2.0.0
allowed-tools: Read, Glob, Grep, Bash(python3 *), Bash(pip3 *), Bash(pandoc *), Bash(which *), Bash(ls *), Bash(mkdir *)
---

# Convert Markdown to Word (.docx)

Converts one or more Markdown files to professionally styled Word documents using a bundled Python script (`md_to_docx.py`). Falls back to Pandoc for basic conversion if python-docx is unavailable.

---

## Step 1: Pre-flight Checks

Resolve the path to the bundled converter script. It lives alongside this skill file:

```bash
SKILL_DIR="$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")"
```

In practice, locate it at the skill's installed path:

```bash
ls ~/.claude/plugins/marketplaces/briannaandco-skills/plugins/claude-skills/skills/md2docx/md_to_docx.py
```

Check if python-docx is installed:

```bash
python3 -c "import docx" 2>/dev/null && echo "python-docx OK" || echo "python-docx MISSING"
```

If python-docx is missing, install it:

```bash
pip3 install python-docx
```

If pip3 is unavailable or the user declines, fall back to Pandoc (see Step 3b).

---

## Step 2: Identify Files

Ask the user which files to convert if not already specified. Help them find candidates:

```bash
ls *.md 2>/dev/null
```

For batch conversion, use Glob to find all `.md` files under a directory.

Determine output location:
- Default: same directory as the input file, with `.docx` extension
- If the user specifies an output directory, use that

---

## Step 3a: Convert with Styled Script (Primary)

For each file, run the bundled converter:

```bash
python3 ~/.claude/plugins/marketplaces/briannaandco-skills/plugins/claude-skills/skills/md2docx/md_to_docx.py "<input>.md" "<output>.docx"
```

The script produces professionally styled documents:
- Navy blue headings (Calibri), dark gray body text
- Code blocks with gray background shading
- Styled tables with header row and alternating row colors
- Blockquotes with left accent border
- Title block with accent bar on the first H1
- 1.25" margins, 1.15x line spacing

For batch conversion, loop over each file.

---

## Step 3b: Fallback — Pandoc (Basic)

If python-docx cannot be installed, check for Pandoc:

```bash
which pandoc
```

If available, convert with Pandoc (produces unstyled output):

```bash
pandoc "<input>.md" -o "<output>.docx" --from=markdown --to=docx
```

If a reference doc template exists, apply it:

```bash
pandoc "<input>.md" -o "<output>.docx" --from=markdown --to=docx --reference-doc=<template.docx>
```

If neither python-docx nor Pandoc is available, tell the user:
> "Install python-docx (`pip3 install python-docx`) or Pandoc (`brew install pandoc`) to convert."

---

## Step 4: Confirm

After conversion, verify the output files exist:

```bash
ls -la "<output>.docx"
```

Report: how many files were converted, where they were placed, and which converter was used (styled script or Pandoc fallback).
