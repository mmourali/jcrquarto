# Builds jcr-reference.docx for the jcrquarto extension from pandoc's default
# reference document, so every style pandoc and Quarto use exists exactly once.
#
# Usage, from the extension folder (requires Python 3 and python-docx):
#   quarto pandoc -o pandoc-default-reference.docx --print-default-data-file reference.docx
#   python3 tools/build_reference_docx.py pandoc-default-reference.docx jcr-reference.docx
#
# Settings follow JCR's manuscript preparation page, style guide, and sample
# manuscripts: letter paper, 1-inch margins, Times New Roman 12 pt, double
# spacing, left justified, no page numbers, headers, or footers; primary
# headings bold, centered, all caps; secondary headings flush left; an extra
# return (one double-spaced line, 27.6 pt) before and after headings; tables
# in 12-point Times New Roman, single spaced and centered; notes paragraph
# indented; references with a half-inch hanging indent.
import sys
import warnings
import docx
from docx.enum.style import WD_STYLE_TYPE
from docx.enum.text import WD_ALIGN_PARAGRAPH, WD_LINE_SPACING
from docx.oxml.ns import qn
from docx.oxml import OxmlElement
from docx.shared import Pt, Inches, RGBColor

# Pandoc names its caption style "Caption", which python-docx finds by style
# ID and warns about; the lookup is correct
warnings.filterwarnings("ignore", message="style lookup by style_id")

src, out = sys.argv[1], sys.argv[2]
d = docx.Document(src)
S = d.styles

SERIF, SANS = "Times New Roman", "Arial"
# An "extra return" in a double-spaced manuscript: one line of 12-point Times
# New Roman at double spacing
RETURN = 27.6


def set_font(style, name=SERIF, size=12, bold=False, italic=False, caps=False):
    f = style.font
    f.name = name
    f.size = Pt(size)
    f.bold = bold
    f.italic = italic
    f.all_caps = caps
    f.color.rgb = RGBColor(0, 0, 0)
    rpr = style.element.get_or_add_rPr()
    fonts = rpr.find(qn("w:rFonts"))
    if fonts is None:
        fonts = OxmlElement("w:rFonts")
        rpr.insert(0, fonts)
    for attr in ("w:ascii", "w:hAnsi", "w:cs", "w:eastAsia"):
        fonts.set(qn(attr), name)
    for attr in ("w:asciiTheme", "w:hAnsiTheme", "w:cstheme", "w:eastAsiaTheme"):
        if fonts.get(qn(attr)) is not None:
            del fonts.attrib[qn(attr)]
    # No condensed or kerned type (pandoc's title style has both; the style
    # guide: "Do not use condensed characters"), and the same size for
    # complex scripts
    for tag in ("w:spacing", "w:kern", "w:w"):
        for el in rpr.findall(qn(tag)):
            rpr.remove(el)
    for el in rpr.findall(qn("w:szCs")):
        el.set(qn("w:val"), str(int(size * 2)))


def set_par(style, align=WD_ALIGN_PARAGRAPH.LEFT, line=2.0, before=0, after=0,
            first=None, left=None, hanging=None, keep_next=False, keep_lines=False,
            contextual=False):
    p = style.paragraph_format
    p.alignment = align
    p.line_spacing_rule = WD_LINE_SPACING.DOUBLE if line == 2.0 else WD_LINE_SPACING.SINGLE
    p.space_before = Pt(before)
    p.space_after = Pt(after)
    p.left_indent = Inches(left) if left is not None else Inches(0)
    if hanging is not None:
        p.first_line_indent = Inches(-hanging)
    else:
        p.first_line_indent = Inches(first) if first is not None else Inches(0)
    p.keep_with_next = keep_next
    # pandoc's reference document keeps the lines of an abstract together, which
    # moves a whole paragraph of the contribution statement or the abstract to
    # the next page; only headings stay in one piece
    p.keep_together = keep_lines
    p.widow_control = True
    # No space between two paragraphs of this style (the paragraphs of a note)
    ppr = style.element.get_or_add_pPr()
    for el in ppr.findall(qn("w:contextualSpacing")):
        ppr.remove(el)
    if contextual:
        el = OxmlElement("w:contextualSpacing")
        anchor = ppr.find(qn("w:ind"))
        if anchor is None:
            anchor = ppr.find(qn("w:spacing"))
        if anchor is not None:
            anchor.addnext(el)
        elif ppr.find(qn("w:jc")) is not None:
            ppr.find(qn("w:jc")).addprevious(el)
        else:
            ppr.append(el)


def para_style(name, base="Normal"):
    try:
        st = S[name]
    except KeyError:
        st = S.add_style(name, WD_STYLE_TYPE.PARAGRAPH)
        st.base_style = S[base]
        st.quick_style = True
    return st


# Document defaults: Times New Roman 12, double spaced
rpr_default = d.styles.element.find(qn("w:docDefaults")).find(qn("w:rPrDefault")).find(qn("w:rPr"))
fonts = rpr_default.find(qn("w:rFonts"))
for attr in list(fonts.attrib):
    del fonts.attrib[attr]
for attr in ("w:ascii", "w:hAnsi", "w:cs", "w:eastAsia"):
    fonts.set(qn(attr), SERIF)

set_font(S["Normal"]); set_par(S["Normal"])
for name in ("Body Text", "First Paragraph"):
    set_font(S[name]); set_par(S[name], first=0.5)
set_font(S["Compact"]); set_par(S["Compact"])
for name in ("Title", "Subtitle", "Author", "Date"):
    set_font(S[name]); set_par(S[name], align=WD_ALIGN_PARAGRAPH.CENTER)
# Front matter, as in JCR's sample: headings centered and bold with an extra
# return before and after; text flush left; an extra return before the
# keywords
set_font(S["Abstract Title"], bold=True, caps=True)
set_par(S["Abstract Title"], align=WD_ALIGN_PARAGRAPH.CENTER, before=RETURN, after=RETURN, keep_next=True,
        keep_lines=True)
set_font(S["Abstract"]); set_par(S["Abstract"])
kw = para_style("Keywords")
set_font(kw); set_par(kw, before=RETURN)
set_font(S["Bibliography"]); set_par(S["Bibliography"], left=0.5, hanging=0.5)

# Headings: primary bold, centered, all caps, an extra double space before
# and after; secondary flush left; tertiary indented and italic
set_font(S["Heading 1"], bold=True, caps=True)
set_par(S["Heading 1"], align=WD_ALIGN_PARAGRAPH.CENTER, before=RETURN, after=RETURN, keep_next=True,
        keep_lines=True)
set_font(S["Heading 2"])
set_par(S["Heading 2"], before=RETURN, after=RETURN, keep_next=True, keep_lines=True)
for name in ("Heading 3", "Heading 4", "Heading 5", "Heading 6"):
    set_font(S[name], italic=True)
    set_par(S[name], first=0.5, before=RETURN, keep_next=True, keep_lines=True)
for name in ("Heading 7", "Heading 8", "Heading 9"):
    set_font(S[name], italic=True)
    set_par(S[name], first=0.5, keep_next=True, keep_lines=True)
# The paragraph that opens with a tertiary heading (the filter runs the
# heading into the text): paragraph indent, an extra return before
ri = para_style("Run-in Paragraph")
set_font(ri); set_par(ri, first=0.5, before=RETURN)
# The title line of an appendix heading: regular type under the bold label.
# The filter sets it by direct formatting; this character style is only its
# fallback (in Word, bold in a character style toggles the bold of the
# paragraph style instead of overriding it).
try:
    at = S["Appendix Title"]
except KeyError:
    at = S.add_style("Appendix Title", WD_STYLE_TYPE.CHARACTER)
at.font.bold = False

# Quoted text (used for hypotheses): indented, not bold
set_font(S["Block Text"]); set_par(S["Block Text"], left=0.5, before=0, after=0)
S["Block Text"].paragraph_format.right_indent = Inches(0.5)

# Hypotheses, "bold, indented, syllabus style": the bold label at the
# paragraph indent and the hypothesis one inch from the margin (the filter
# sets the label in bold and a tab after it), double spaced, with 12 pt above
# and below
hy = para_style("Hypothesis")
set_font(hy); set_par(hy, left=1.0, hanging=0.5, before=12, after=12)

# Display equations: centered, without indentation. (The filter places a
# numbered equation and its bold number, flush right, in a table without
# borders.)
eq = para_style("Equation")
# (Word puts the extra space of a double-spaced line below the line, so less
# space before the equation than after it gives the same distance on both sides)
set_font(eq); set_par(eq, align=WD_ALIGN_PARAGRAPH.CENTER, line=1.0, before=8, after=18)

# Captions: label and title centered on two double-spaced lines, with an
# extra return before, kept with the table or figure
for name in ("Caption", "Table Caption", "Image Caption"):
    set_font(S[name])
    set_par(S[name], align=WD_ALIGN_PARAGRAPH.CENTER, line=2.0, before=RETURN, after=0,
            keep_next=True)
for name in ("Figure", "Captioned Figure"):
    set_par(S[name], align=WD_ALIGN_PARAGRAPH.CENTER, line=1.0, keep_next=True)
# The caption of one panel of a figure, "(a) Text", centered with its panel
panel = para_style("Panel Caption")
set_font(panel); set_par(panel, align=WD_ALIGN_PARAGRAPH.CENTER, line=1.0, before=2, after=6,
                         keep_next=True)

# Footnotes
set_font(S["Footnote Text"], size=10); set_par(S["Footnote Text"], line=1.0)
set_font(S["Footnote Block Text"], size=10); set_par(S["Footnote Block Text"], line=1.0, left=0.5)

# Tables and notes, as in JCR's sample manuscripts: 12-point Times New Roman,
# single spaced; notes paragraph indented, with an extra return after
# (keep_next holds the rows of a table together on one page)
tt = para_style("Table Text")
set_font(tt, name=SERIF, size=12); set_par(tt, line=1.0, keep_next=True)
tn = para_style("Table Note")
set_font(tn, name=SERIF, size=12); set_par(tn, line=1.0, first=0.5, before=4, after=RETURN, contextual=True)

# Links in black without underlining (JCR: no underlining)
hl = S["Hyperlink"]
hl.font.color.rgb = RGBColor(0, 0, 0)
hl.font.underline = False

# Table style: rules above and below the header row and below the table.
# (jcrquarto-post.lua takes single tables and figures out of Quarto's layout
# tables, so these rules fall on data tables.)
tbl = S["Table"].element
for old in tbl.findall(qn("w:tblStylePr")):
    tbl.remove(old)
tblpr = tbl.find(qn("w:tblPr"))
if tblpr is None:
    tblpr = OxmlElement("w:tblPr")
    tbl.append(tblpr)
for tag in ("w:tblBorders", "w:jc"):
    for b in tblpr.findall(qn(tag)):
        tblpr.remove(b)
tbl_borders = OxmlElement("w:tblBorders")
bottom = OxmlElement("w:bottom")
bottom.set(qn("w:val"), "single"); bottom.set(qn("w:sz"), "6"); bottom.set(qn("w:space"), "0"); bottom.set(qn("w:color"), "000000")
tbl_borders.append(bottom)
# CT_TblPrBase order: tblStyle, ..., tblInd, tblBorders, shd, ...
anchor = None
for tag in ("w:shd", "w:tblLayout", "w:tblCellMar", "w:tblLook", "w:tblCaption", "w:tblDescription"):
    anchor = tblpr.find(qn(tag))
    if anchor is not None:
        break
if anchor is not None:
    anchor.addprevious(tbl_borders)
else:
    tblpr.append(tbl_borders)
# Tables centered. (The filter also writes the alignment into each table; a
# table that holds citations or footnotes takes it from this style.)
jc = OxmlElement("w:jc")
jc.set(qn("w:val"), "center")
before = None
for tag in ("w:tblCellSpacing", "w:tblInd", "w:tblBorders"):
    before = tblpr.find(qn(tag))
    if before is not None:
        break
before.addprevious(jc)
first = OxmlElement("w:tblStylePr"); first.set(qn("w:type"), "firstRow")
tcpr = OxmlElement("w:tcPr"); borders = OxmlElement("w:tcBorders")
for edge in ("top", "bottom"):
    e = OxmlElement(f"w:{edge}")
    e.set(qn("w:val"), "single"); e.set(qn("w:sz"), "6"); e.set(qn("w:space"), "0"); e.set(qn("w:color"), "000000")
    borders.append(e)
tcpr.append(borders); first.append(tcpr)
tbl.append(first)

# Page: US letter, 1-inch margins, no headers or footers
for sec in d.sections:
    sec.page_width, sec.page_height = Inches(8.5), Inches(11)
    for side in ("left_margin", "right_margin", "top_margin", "bottom_margin"):
        setattr(sec, side, Inches(1))

# Remove the sample body text so the reference document holds only styles
body = d.element.body
for child in list(body):
    if child.tag != qn("w:sectPr"):
        body.remove(child)
d.core_properties.title = "JCR manuscript reference document (jcrquarto)"
d.core_properties.author = ""
d.save(out)
print("saved", out)
