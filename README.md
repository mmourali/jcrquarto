# jcrquarto: Quarto Extension for the *Journal of Consumer Research*

A [Quarto](https://quarto.org/) extension that formats manuscripts for the *Journal of Consumer Research* (JCR). One `.qmd` file renders to three outputs:

| Format | Output | Use |
| --- | --- | --- |
| `jcrquarto-pdf` | PDF typeset with pdfLaTeX | The file to upload for review; JCR asks authors who write in LaTeX to upload a PDF |
| `jcrquarto-docx` | Word file | JCR requires the final accepted manuscript in Word, with editable Word tables |
| `jcrquarto-latex` | `.tex` source of the PDF | For working in LaTeX; compile with pdfLaTeX (two or three runs, or latexmk). Rendering the PDF also keeps this file. |

Version 1.0.0. The formatting follows JCR's [manuscript preparation page](https://consumerresearcher.com/manuscript-preparation), [style guide](https://consumerresearcher.com/wp-content/uploads/2021/01/stylesheet.pdf), [sample manuscript for review](https://consumerresearcher.com/wp-content/uploads/2021/05/JCR_Sample_Manuscript_for_Review.pdf), and [instructions for accepted manuscripts](https://consumerresearcher.com/authors/accepted-manuscripts). Where the sample manuscript and the style guide differ, the extension follows the sample manuscript; see [Where the style guide and the sample manuscript differ](#where-the-style-guide-and-the-sample-manuscript-differ).

## Installation

Start a new manuscript from the template:

```bash
quarto use template mmourali/jcrquarto
```

Or add the extension to an existing project:

```bash
quarto add mmourali/jcrquarto
```

`quarto add` installs the current state of the `main` branch. To update an installed copy, run `quarto update mmourali/jcrquarto` in the project folder.

## Quick start

```yaml
---
title: "Your Manuscript Title"
jcr-mode: manuscript
abstract: |
  At most 200 words, in the third person, with no citations.
keywords: [first keyword, second keyword, third keyword]
bibliography: bibliography.bib
format:
  jcrquarto-pdf: default
  jcrquarto-docx: default
  jcrquarto-latex: default
---
```

`template.qmd` shows every feature; `web-appendix.qmd` is the template for the separate web appendix file; `bibliography.bib` holds the template's references.

## Rendering modes

**Manuscript mode** (`jcr-mode: manuscript`, the default) is the submission format: US letter, 1-inch margins, Times New Roman 12 point, double spaced, single column, left justified, and no page numbers, headers, footers, or author information. The title, consumer relevance and contribution statement, abstract, and keywords come first, laid out as in JCR's sample manuscript (headings centered and bold, text flush left, an extra return between the parts), and the text begins on a new page.

**Web appendix mode** (`jcr-mode: web-appendix`) renders the separate web appendix file in the same format. Its first page carries the label WEB APPENDIX, the title of the manuscript, and the text you write before the first web appendix (JCR asks for a table of contents or a brief paragraph that describes the contents). Each `# Web Appendix A: Title` heading begins a new page and is set like a manuscript appendix: the label in bold capitals and the title in capitals on the next line. During the review process the file carries no author names; after acceptance, add `anonymous: false` and the `author` list to print the authorship list on the first page, and upload the Word file, which JCR then requires.

**Line spacing.** The PDF and `.tex` outputs are set with `linestretch: 2`, which puts 23 lines on a page, the number that Word's double spacing gives in JCR's sample manuscripts (and in this extension's Word output). LaTeX's own `\doublespacing` is tighter, about 27 lines on a page; to use it instead, add `linestretch: 1.655` to the document options.

**Article mode** (`jcr-mode: article`, PDF and `.tex` only) is a publication-style preview for sharing drafts: 11 point Times with 1.15 line spacing, 1.25-inch side margins, the title and author names at the top, the abstract and keywords below them, the `jcr-author-note` as a first-page footnote, and centered page numbers. Article mode is not a submission format.

```bash
quarto render template.qmd                      # manuscript mode
quarto render template.qmd -M jcr-mode:article  # article mode
```

## Front matter

| Field | Mode | What the extension does |
| --- | --- | --- |
| `title` | Both | Printed at the top of the first page |
| `jcr-mode` | All | `manuscript` (default), `web-appendix`, or `article` |
| `consumer-relevance-statement` | Manuscript | Printed first, under CONSUMER RELEVANCE AND CONTRIBUTION STATEMENT, flush left, with an extra return between paragraphs. Warns above 300 words. The statement is for new submissions only: delete the field for invited revisions. |
| `abstract` | Both | Printed under ABSTRACT. Warns above 200 words and when the abstract contains citations, links, tables, or figures, which JCR does not allow. The style sheet also asks for the third person (no "I" or "we"). |
| `keywords` | Both | Printed after the abstract, after an extra return, as a separate paragraph that begins with an italic *Keywords:* label. Warns unless there are 3 to 6. |
| `data-availability-statement` | Both | One anonymized paragraph under DATA AND MATERIALS AVAILABILITY STATEMENT, on a new page after the text and before the appendixes (or before the references if there are none) |
| `jcr-note-dash` | Both | `true` (default) prints table and figure notes as in JCR's sample, "NOTE." followed by an em dash; `false` prints "NOTE." and a space |
| `author` | Article, web appendix | Author names (use `name: literal:`). In a web appendix they are printed only with `anonymous: false`. |
| `anonymous` | Web appendix | `true` (default). `false` prints the authorship list on the first page of the web appendix, as JCR asks after acceptance. |
| `linestretch` | Manuscript, web appendix | `2` (default); see Line spacing above |
| `jcr-author-note` | Article | Pre-formatted first-page footnote: affiliations, correspondence, acknowledgments |

The `jcr-author-note` field is pre-formatted text, which avoids Quarto's restructuring of `author` metadata. No author information is printed in manuscript mode, as double-anonymous review requires.

## Text

**Headings.** JCR uses up to three levels and does not number headings. `#` is a primary heading (bold, centered, all capitals), `##` a secondary heading (title case, flush left), and `###` a tertiary heading (indented, italic, followed by a period, with the text on the same line). The render warns when a section has a single secondary heading. Start the text without an "Introduction" heading: the style sheet's manuscript order puts the main text right after the keywords.

**Hypotheses.** Write each hypothesis in a `hypothesis` div. The style guide asks for "bold, indented, syllabus style," and its example sets the label in bold at the paragraph indent and the hypothesis, in regular type, as a block one inch from the margin. The extension does the same: the label (the words up to the first colon, such as "H1:", or a label typed in bold) stands at the paragraph indent and the hypothesis hangs to its right, double spaced. In the text, name hypotheses in lowercase ("hypothesis 2").

```markdown
::: {.hypothesis}
H1: Consumers judge a combination of a high-risk and a low-risk item to be
less risky than the high-risk item alone.
:::
```

**Statistics.** Italicize statistical letters (*p*, *F*, *M*, *df*, *r*, *t*) but not Greek letters, report specific *p* values rather than thresholds, and write probabilities without a leading zero (*p* = .035). Example: (*F*(2, 290) = 17.53, *p* < .001); confidence intervals as 95% CI [2.20, 8.23]. LaTeX helpers are available in the PDF and `.tex` outputs: `$\Fstat{2}{290}{17.53}$`, `$\pval{.001}$`, `\CI{2.20}{8.23}`.

**Equations.** The style guide centers equations, leaves a single equation without a number, and, when there are several, asks for a bold number flush right in parentheses. Label the equations you want numbered (`$$ ... $$ {#eq-model}`); in the text, `@eq-model` prints "equation 1" (`@Eq-model` at the start of a sentence). In Word, a numbered equation and its number are placed in a table without borders, so that the number stands at the right margin.

**Footnotes.** The style guide asks for footnotes to be used sparingly and does not allow endnotes; the render warns after the fifth footnote.

**General style.** Write "and" rather than an ampersand; spell out "that is" and "for example" in the text and abbreviate them (i.e., e.g.) only in parentheses; use the serial comma; write "participants" or "respondents," not "subjects"; and refer in lowercase to table 1, figure 1, study 1, hypothesis 1, and appendix A.

## Tables and figures

Tables and figures go in the body of the manuscript, not at the end, and count toward JCR's 60-page limit.

Type captions in ordinary case and give each table or figure a label. The extension prints "TABLE 1" or "FIGURE 1" centered on one line and the title, in capitals, centered on the next. Math in a caption keeps its case, so write statistics there as `$p$` rather than `*p*`. In the text, `@tbl-risk` prints "table 1" and `@fig-risk` prints "figure 1"; at the start of a sentence, `@Tbl-risk` and `@Fig-risk` print "Table 1" and "Figure 1". JCR does not allow references such as "above" or "below."

```markdown
| Condition      | *M*  | SD   |
|:---------------|-----:|-----:|
| Single (high)  | 35.3 | 12.4 |
| Combined (H+L) | 27.0 | 18.8 |

: Perceived risk across conditions (study 1A) {#tbl-risk}

::: {.jcr-note}
Planned contrasts compare each combined condition to the single condition.
:::
```

Tables are set as in JCR's sample manuscripts: in 12-point Times, like the text, single spaced, and centered, with rules above and below the column heads and below the table. The label and the title stand on two double-spaced lines, after an extra return. In a pipe table whose lines are long, the number of dashes in each column of the separator line sets that column's share of the width. If a share is too small for the longest word of its column, the extension sets the widths from the contents instead, so that no word is broken in the middle. Right-aligned columns of numbers with the same number of decimals keep the decimals aligned. Tables that a code chunk writes (with `knitr::kable()`, for example) are set the same way. A table that fits on a page is kept on one page with its label, title, and note. In Word, each table is a native Word table that the typesetter can edit; its centered alignment is written into the table itself (a table that holds citations, footnotes, images, or web links takes it from the table style of the reference document). A table or figure without a note is followed by an extra return, because Word otherwise sets the next paragraph directly against it.

Write notes in a `jcr-note` div directly after the table or figure (the `notes` class of the other extensions in this family and the older `table-notes` class also work). The extension adds the "NOTE." label and sets the note as JCR's sample manuscripts do: paragraph indented, in 12-point Times, single spaced. A note stays on the page of its figure.

Figures come from an image or a code chunk:

````markdown
![Conceptual framework](figures/fig1-framework){#fig-framework}

```{r}
#| label: fig-risk
#| fig-cap: "Perceived risk by condition (study 1A)"
```
````

An image path written without an extension uses the `.pdf` file for the PDF and `.tex` outputs and the `.png` file for Word, so keep both versions side by side. JCR asks for sans serif type inside figures, labeled axes, legends placed horizontally beneath the figure where possible, and 95% confidence intervals for any error bars. After acceptance, JCR also needs a separate file for each figure, and it prefers source files. The template's figure is drawn with R (ggplot2); delete that chunk if you do not use R.

**Labels.** A table or figure that has a title but no label is printed without a number, in every output, and the render warns; a table without a title takes no number either.

**Figures and tables with panels.** Quarto's layout options set several pictures in one figure. Give the figure a label; give each panel a caption and, if the text cites single panels, a label of its own:

```markdown
::: {#fig-studies layout-ncol=2}
![Study 1](study1.png){#fig-study1}

![Study 2](study2.png){#fig-study2}

Purchase intention by condition
:::
```

Both outputs set the panels side by side under the label and title of the figure, each with its caption, "(a) Study 1," centered above it, and `@fig-study1` prints "figure 1a." Panel captions are printed as typed, not in capitals. In Word the panels stand in a table without borders. A table with several parts (a `#tbl-` div with a layout option that holds one table for each part) is set the same way, and so are the plots of a code chunk with `layout-ncol` and `fig-subcap`.

Captions of raw LaTeX tables (from kableExtra, for example) are not capitalized by the extension; type their titles in capitals.

## Appendixes, citations, and references

**Appendixes.** Write each manuscript appendix as a primary heading with the `appendix` class. The label (in bold) and the title (in regular type) are set on separate lines, in capitals, and each appendix begins on a new page, after the data and materials availability statement and before the references. Label a single appendix "Appendix," without a letter.

```markdown
# Appendix A: Stimuli and Scenarios {.appendix}
```

**Citations.** JCR uses an author-date format: (Lipkus 2007); (Reyna and Brainerd 1995); three authors in full at first mention, (Munz, Greenberg, and Morwitz 2025), and with "et al." afterward, (Munz et al. 2025); four or more authors always with "et al."; multiple citations in alphabetical order, separated by semicolons; and page numbers without "p.", (Lipkus 2007, 698). The extension's style file does all of this from `[@key]` citations.

**References.** End the document with the reference list, which begins on a new page:

```markdown
# References

::: {#refs}
:::
```

References are formatted by `journal-of-consumer-research.csl`, the Zotero JCR style edited to follow JCR's style sheet and examples (the edits are listed at the top of the file): repeated authors are printed in full, entries with more than six authors list the first three and "et al.", volume and issue are separated by a space ("44 (3)"), the month stands in for a missing issue number ("13 (June)"), and entries are double spaced with a half-inch hanging indent and no blank line between them. In the `.bib` file, give a forthcoming article `year = {forthcoming}` and no volume, and enter a working paper as `@unpublished` with `note = {working paper, University}`. A work without a date is listed with "(n.d.)."

## Where the style guide and the sample manuscript differ

JCR's style guide is written for accepted manuscripts, and its text differs from the two sample manuscripts (for review and accepted) in one point that matters here: the guide asks for sans serif type in tables, but the tables of both sample manuscripts are set in 12-point Times New Roman. The extension follows the sample manuscripts. To use a sans serif face instead, add `\sffamily` to the three `\AtBeginEnvironment` lines of `jcr-header.tex` and change the font of the "Table Text" style in `jcr-reference.docx` (or in `tools/build_reference_docx.py`).

The extension does not yet build the extra parts of an accepted manuscript (the authorship list and author note on separate pages, page numbers in the top right corner, the data collection statement, and the headings list). Add them in the Word file after rendering.

## Checks during rendering

The filter warns when the abstract exceeds 200 words or contains citations, links, tables, or figures; when there are fewer than 3 or more than 6 keywords; when the consumer relevance and contribution statement exceeds 300 words; when there are more than 5 footnotes; and when a section has a single secondary heading. The extension cannot check the anonymity of the manuscript, the 60-page limit, the names of hypotheses in the text, statistics, or the design of figures.

## Fonts

The PDF and `.tex` outputs use pdfLaTeX with the `mathptmx` (Times) package, which comes with standard TeX Live and TinyTeX installations; `helvet` (Helvetica) is loaded for any sans serif text. The Word output takes Times New Roman from `jcr-reference.docx`. No system fonts are required.

## Files

| File | Role |
| --- | --- |
| `_extensions/jcrquarto/_extension.yml` | The three formats and their settings |
| `_extensions/jcrquarto/jcrquarto.lua` | Front matter, the web appendix title page, notes, hypotheses, run-in headings in Word, appendixes, the data statement, page breaks, and the checks |
| `_extensions/jcrquarto/jcrquarto-post.lua` | Captions, Word table text and alignment, equation numbers in Word, figures and tables with panels, and removal of Quarto's layout tables in Word (it runs after Quarto has numbered tables and figures) |
| `_extensions/jcrquarto/jcr-header.tex` | LaTeX preamble: fonts, spacing, headings, captions, notes, hypotheses, statistics helpers |
| `_extensions/jcrquarto/partials/` | LaTeX template pieces (no title block, no author information) |
| `_extensions/jcrquarto/jcr-reference.docx` | Word styles |
| `_extensions/jcrquarto/journal-of-consumer-research.csl` | Reference style |
| `_extensions/jcrquarto/tools/build_reference_docx.py` | Rebuilds `jcr-reference.docx` from pandoc's default reference document (requires Python and python-docx; see the script's first lines) |
| `template.qmd`, `bibliography.bib` | Manuscript template and its references |
| `web-appendix.qmd` | Web appendix template (a separate file for ScholarOne; `jcr-mode: web-appendix`) |

## Requirements

Quarto 1.4 or later (tested with Quarto 1.4.557, 1.5.57, and 1.11.9; the Word output was checked in Microsoft Word for Mac) and a TeX distribution with pdfLaTeX. The captions and Word tables depend on how Quarto lays out tables and figures; with a much newer Quarto, check that captions still print as two centered lines. If they do not, the output falls back to Quarto's own captions.

Greek letters and common mathematical signs can be typed as characters (α, χ², ≤, ≠, −, ×, →, ✓). In the PDF and `.tex` outputs, which pdfLaTeX typesets, Greek letters stand upright in the text, as they do in the Word file. pdfLaTeX has no type for other scripts (Cyrillic, Chinese, Arabic) or for a letter with a combining accent (a mean typed as an x followed by a combining macron); write such symbols as math, `$\bar{x}$`. The Word output takes any character.

## Differences from the AMA journals template

If you are familiar with [amaquarto](https://github.com/mmourali/amaquarto) for AMA journals (JM, JMR), key differences for JCR include: no separate title page; a consumer relevance and contribution statement (not required by AMA); all-capital primary headings; secondary headings without bold or italics; footnotes used sparingly; a 60-page limit; 3 to 6 keywords (not up to 8); 95% confidence intervals for any error bars; and declarations entered in ScholarOne, not in the manuscript file.

## Resources

- [JCR Manuscript Preparation Guidelines](https://consumerresearcher.com/manuscript-preparation)
- [JCR Style Sheet](https://consumerresearcher.com/wp-content/uploads/2021/01/stylesheet.pdf)
- [JCR Sample Manuscript for Review](https://consumerresearcher.com/wp-content/uploads/2021/05/JCR_Sample_Manuscript_for_Review.pdf)
- [JCR Accepted Manuscripts](https://consumerresearcher.com/authors/accepted-manuscripts)
- [JCR Research Ethics](https://consumerresearcher.com/research-ethics)
- [Quarto Journal Article Guide](https://quarto.org/docs/journals/formats.html)

## License

The CSL file is derived from the [Journal of Consumer Research](https://www.zotero.org/styles/journal-of-consumer-research) style, licensed under [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/). All other files are available under the [MIT License](LICENSE).
