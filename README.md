# jcrquarto: Quarto Extension for the *Journal of Consumer Research*

A [Quarto](https://quarto.org/) extension that formats manuscripts for the *Journal of Consumer Research* (JCR). Produces PDF (via pdfLaTeX) and DOCX output in two rendering modes:

- **Manuscript mode** (`jcr-mode: manuscript`): Double-spaced, single-column, 12pt format matching JCR's submission guidelines for double-anonymous review.
- **Article mode** (`jcr-mode: article`): Publication-style single-column layout (11pt, compact spacing, centered page numbers). Designed for sharing drafts and preprints.

## Installation

```bash
quarto use template mmourali/jcrquarto
```

Or, to add the extension to an existing project:

```bash
quarto add mmourali/jcrquarto
```

## Quick Start

Set the format and mode in your YAML header:

```yaml
---
title: "Your Manuscript Title"
jcr-mode: manuscript       # or: article
format: jcrquarto-pdf      # or: jcrquarto-docx
bibliography: bibliography.bib
---
```

## Rendering Modes

### Manuscript Mode (default)

Produces a submission-ready PDF conforming to JCR's formatting requirements:

- US Letter (8.5 x 11 in), 1-inch margins
- Times New Roman 12pt, double-spaced
- Single-column, left-justified
- No page numbers, headers, or footers
- Title, Consumer Relevance Statement, Abstract, and Keywords on page 1
- Main text begins on page 2

```yaml
jcr-mode: manuscript
format: jcrquarto-pdf
```

### Article Mode

Produces a publication-style PDF for sharing drafts and preprints:

- US Letter, 1.25-inch side margins
- Times 11pt body, 1.15 line spacing, single-column
- Helvetica sans-serif headings
- Left-aligned title in large bold sans-serif
- Centered author names
- Abstract with keywords below the title
- Centered page numbers at the bottom
- Author note as first-page footnote with editor info

```yaml
jcr-mode: article
format: jcrquarto-pdf
author:
  - name:
      literal: "Mehdi Mourali"
  - name:
      literal: "Zhiyong Yang"
jcr-author-note: |
  Mehdi Mourali (mehdi.mourali@haskayne.ucalgary.ca) is an associate
  professor of marketing at the Haskayne School of Business, University
  of Calgary, 2500 University Drive NW, Calgary, AB T2N 1N4, Canada.
  Zhiyong Yang is a professor of marketing at the Farmer School of
  Business, Miami University, 800 E. High St. Oxford, OH 45056, USA.
  Please address correspondence to Mehdi Mourali.
jcr-editor: "Margaret C. Campbell and Stacy Wood"
jcr-associate-editor: "Nailya Ordabayeva"
publication-date: "September 1, 2022"
```

Note: The `jcr-author-note` field is pre-formatted text that appears as a first-page footnote in article mode. This avoids issues with Quarto restructuring the `author` metadata. Include author names, emails, titles, affiliations, correspondence information, acknowledgments, and any web appendix note directly in this field.

### DOCX Mode

Produces a Word document with JCR-styled headings, double spacing, and Times New Roman font:

```yaml
format: jcrquarto-docx
```

## Template Files

| File | Purpose |
|------|---------|
| `template.qmd` | Main manuscript template with inline comments |
| `web-appendix.qmd` | Supplementary materials (separate file for ScholarOne) |
| `bibliography.bib` | Sample bibliography with JCR-style entries |

## YAML Fields

| Field | Mode | Description |
|-------|------|-------------|
| `title` | Both | Manuscript title |
| `jcr-mode` | Both | `manuscript` (default) or `article` |
| `abstract` | Both | Abstract text (max 200 words) |
| `keywords` | Both | 3 to 6 keywords |
| `consumer-relevance-statement` | Manuscript | New submissions only (max 300 words) |
| `author` | Article | Author names only (use `name: literal:`) |
| `jcr-author-note` | Article | Pre-formatted first-page footnote (affiliations, correspondence, acknowledgments, web appendix note) |
| `jcr-editor` | Article | Editor name(s) |
| `jcr-associate-editor` | Article | Associate editor name |
| `publication-date` | Article | Advance Access publication date |

## JCR Formatting Rules

### Headings

JCR uses up to three heading levels (do not number headings):

- **Primary (H1):** ALL CAPS, centered, bold. Use `# Heading`.
- **Secondary (H2):** Title case, flush left. Use `## Heading`.
- **Tertiary (H3):** Title case, italic, run-in with period. Use `*Tertiary Heading.* Text continues...`

Title case follows Chicago Manual of Style headline-style capitalization.

### Hypotheses

```markdown
::: {.hypothesis}
**H1:** Consumers exposed to influencer content will report higher
brand loyalty.
:::
```

### Citations

JCR uses author-date format based on Chicago Manual of Style:

- Single author: `(Reyna 2008)`
- Two authors: `(Mourali and Yang 2023)`
- Three authors, first mention: `(French, Marteau, and Weinman 2000)`, then `(French et al. 2000)`
- Four or more: always first author et al.
- Multiple: alphabetical, semicolons: `(Brough and Chernev 2012; Chernev and Gal 2010)`
- Page reference: `(Anderson 1981, 785)` (no "p.")

### Statistics

- Italicize: *p*, *F*, *M*, *df*, *r*, *t*
- No zero before decimal in probabilities: *p* = .035
- Report specific *p*-values, not thresholds
- Format: (*F*(2, 290) = 17.53, *p* < .001)
- Confidence intervals: 95% CI [2.20, 8.23]

LaTeX helpers: `$\Fstat{2}{290}{17.53}$`, `$\pval{.001}$`, `$\CI{2.20}{8.23}$`

### Tables and Figures

- Place within main text (not at the end)
- Labels: ALL CAPS (TABLE 1, FIGURE 1)
- Refer in text by number in lowercase: table 1, figure 1
- Error bars must be 95% CI if reported

### General Style

- Do not use ampersands; write "and"
- Spell out "that is" and "for example" in text; abbreviate (i.e., e.g.) only in parentheses
- Use serial comma: Green, Smith, and Jones
- Use "participants" or "respondents," not "subjects"
- Refer to lowercase: table 1, study 1, hypothesis 1, appendix A

## Validation Warnings

The Lua filter automatically checks:

- Abstract exceeding 200 words
- Keywords outside the 3-6 range
- Consumer Relevance Statement exceeding 300 words
- More than 5 footnotes (JCR strongly discourages footnotes)

## Font Configuration

The extension uses pdfLaTeX with the `mathptmx` (Times) and `helvet` (Helvetica) packages, which are included in all standard TeX Live and TinyTeX installations. No system fonts or additional font packages are required.

## Differences from AMA Journals Template

If you are familiar with [amaquarto](https://github.com/mmourali/amaquarto) for AMA journals (JM, JMR), key differences for JCR include: no separate title page; Consumer Relevance and Contribution Statement (not required by AMA); ALL CAPS H1 headings; H2 headings without bold/italic; footnotes strongly discouraged; 60-page limit; 3-6 keywords (not up to 8); error bars must be 95% CI; declarations entered in ScholarOne, not in the manuscript file.

## Resources

- [JCR Manuscript Preparation Guidelines](https://consumerresearcher.com/manuscript-preparation)
- [JCR Style Guide](https://consumerresearcher.com/wp-content/uploads/2021/01/stylesheet.pdf)
- [JCR Sample Manuscript](https://consumerresearcher.com/wp-content/uploads/2021/05/JCR_Sample_Manuscript_for_Review.pdf)
- [JCR Research Ethics](https://consumerresearcher.com/research-ethics)
- [Quarto Journal Article Guide](https://quarto.org/docs/journals/formats.html)

## License

The CSL file is derived from the [Journal of Consumer Research](https://www.zotero.org/styles/journal-of-consumer-research) style, licensed under [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/). All other files are available under the [MIT License](LICENSE).
