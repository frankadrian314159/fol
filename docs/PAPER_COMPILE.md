# Compiling the Dispatch Caching Paper

## Files

- `caching.tex` - Main paper source (ACM SIGPLAN format)
- `caching.bib` - Bibliography file
- `caching.pdf` - Compiled output (after running pdflatex)

## Requirements

You need a LaTeX distribution with ACM SIGPLAN templates:
- `pdflatex` or `xelatex` compiler
- `acmart` package (included in most modern LaTeX distributions)
- `bibtex` for bibliography processing

### Install LaTeX

**macOS (via Homebrew)**:
```bash
brew install mactex
```

**Ubuntu/Debian**:
```bash
sudo apt-get install texlive-latex-full texlive-bibtex-extra
```

**Windows**:
- Install [MiKTeX](https://miktex.org/download) or [TeX Live](https://www.tug.org/texlive/windows.html)

## Compilation Steps

### One-Command Build

```bash
cd docs
pdflatex caching.tex && bibtex caching && pdflatex caching.tex && pdflatex caching.tex
```

This will:
1. Run `pdflatex` to create auxiliary files
2. Run `bibtex` to process bibliography
3. Run `pdflatex` twice more to resolve cross-references

### Step-by-Step Build

```bash
# First pass: generate .aux files
pdflatex caching.tex

# Generate bibliography
bibtex caching

# Second pass: include bibliography
pdflatex caching.tex

# Third pass: resolve all cross-references
pdflatex caching.tex
```

### Using Makefile (if available)

```bash
make -C docs
```

### Using Latexmk (recommended)

If you have `latexmk` installed (usually comes with LaTeX distributions):

```bash
cd docs
latexmk -pdflatex caching.tex
```

This automatically runs all necessary passes and handles bibliography.

## Output

After compilation, you'll have:
- `caching.pdf` - The final PDF document
- `caching.aux` - Auxiliary file (cross-references)
- `caching.bbl` - Processed bibliography
- `caching.blg` - Bibliography log
- `caching.log` - Compilation log

## Troubleshooting

### Missing acmart package

If you get `! LaTeX Error: File 'acmart.cls' not found`:

**Solution**: Install ACM templates
```bash
# On macOS
tlmgr install acmart

# On Ubuntu
sudo apt-get install texlive-latex-extra

# Or download from https://www.ctan.org/pkg/acmart
```

### Bibliography not appearing

If references don't show up in PDF:
1. Make sure `caching.bib` is in the same directory as `caching.tex`
2. Run the full compilation sequence (all three pdflatex passes)
3. Check `caching.blg` for error messages

### Encoding issues

If you get encoding errors, ensure the .tex and .bib files are UTF-8:

```bash
# Check encoding
file caching.tex

# Convert to UTF-8 if needed (on macOS/Linux)
iconv -f ISO-8859-1 -t UTF-8 caching.tex > caching-utf8.tex
mv caching-utf8.tex caching.tex
```

### PDF not updating

If the PDF doesn't change after edits:
1. Close the PDF viewer (some lock the file)
2. Delete auxiliary files: `rm -f caching.aux caching.bbl caching.blg caching.log`
3. Recompile: `pdflatex caching.tex && bibtex caching && pdflatex caching.tex`

## Paper Structure

The compiled paper contains:

1. **Title and Authors** - Research team attribution
2. **Abstract** (250 words) - Executive summary of findings
3. **Introduction** - Motivation and contributions
4. **Background** - Related work on inline caching and COND dispatch
5. **Methodology** - Implementation details and benchmarking approach
6. **Results** - Benchmark numbers and cache hit rates
7. **Analysis** - Assembly-level breakdown and cost accounting
8. **Related Work** - Positioning within dynamic language research
9. **Discussion** - Key findings and implications
10. **Limitations and Future Work**
11. **Conclusion** - Summary and takeaways
12. **References** - Full bibliography

## For Submission to Conferences

When submitting to a venue:

1. **ICFP** - Change document class:
   ```latex
   \documentclass[sigplan,review]{acmart}  % For review
   \documentclass[sigplan,final]{acmart}   % For camera-ready
   ```

2. **PLDI** - Same ACM SIGPLAN template works

3. **Generic Lisp/FP conference** - May require different template
   (Modify `\documentclass` as needed)

4. **Anonymization** - For blind review, add `anonymous`:
   ```latex
   \documentclass[sigplan,review,anonymous]{acmart}
   ```
   This will hide author names and affiliations.

## Customization

### Change Authors

Edit the author section:
```latex
\author{Your Name}
\affiliation{%
  \institution{Your Institution}
}
\email{your.email@example.com}
```

### Change Conference/Venue

Modify the comment section at top:
```latex
%% For PLDI, change to:
%% \documentclass[sigplan,review,10pt]{acmart}\settopmatter{printfolios=true}

%% For ICFP, use:
%% \documentclass[sigplan,review]{acmart}
```

### Adjust References

To use a different bibliography style (e.g., IEEE):
```latex
\bibliographystyle{IEEE}  % Instead of ACM-Reference-Format
\citestyle{ieee}          % Instead of acmauthoryear
```

## Word Count

The paper is approximately:
- **Main text**: 5,000--6,000 words
- **With references**: 6,500 words
- **With appendices** (if added): 7,500+ words

Typical conference page limit: 10--12 pages (this fits comfortably).

## Metrics

The compiled PDF will show:
- **Pages**: 10--12 (single column, ACM format)
- **Figures**: 4 (benchmark results, assembly comparison, etc.)
- **Tables**: 2 (benchmark results, instruction latencies)
- **References**: 25+

---

**Last Updated**: 2026-05-12  
**LaTeX Template**: ACM SIGPLAN (2019+)  
**Tested With**: pdflatex 3.14159265-2.6-1.40.20 (TeX Live 2021)
