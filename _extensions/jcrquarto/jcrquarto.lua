-- jcrquarto.lua  (jcrquarto 1.0.0)
-- Journal of Consumer Research Quarto/Pandoc filter, run before Quarto's own
-- filters. jcrquarto-post.lua runs after them and formats captions and tables.
-- Modes: "manuscript" (default, the submission format) | "web-appendix" |
-- "article" (a publication-style preview)
--
-- Rules follow JCR's manuscript preparation page and style guide:
--   https://consumerresearcher.com/manuscript-preparation
--   https://consumerresearcher.com/wp-content/uploads/2021/01/stylesheet.pdf

local footnote_count = 0
local jcr_mode = "manuscript"
local anonymous = true   -- web appendix: no authorship list during review
local note_dash = true   -- JCR's sample: "NOTE." followed by an em dash
local has_quarto = (quarto ~= nil)

local is_docx, is_latex
if has_quarto then
  is_docx = quarto.doc.is_format("docx")
  is_latex = quarto.doc.is_format("latex") or quarto.doc.is_format("pdf")
else
  is_docx = (FORMAT == "docx")
  is_latex = (FORMAT == "latex") or (FORMAT == "pdf")
end

local function log_warning(msg)
  if has_quarto then quarto.log.warning(msg)
  else io.stderr:write("WARNING: " .. msg .. "\n") end
end

local function count_words(text)
  local n = 0
  for _ in text:gmatch("%S+") do n = n + 1 end
  return n
end

local function to_blocks(val)
  if val == nil then return nil end
  local t = pandoc.utils.type(val)
  if t == "Blocks" then return val
  elseif t == "Inlines" then return pandoc.Blocks({ pandoc.Para(val) })
  elseif t == "table" and val[1] then return pandoc.Blocks(val)
  end
  local s = pandoc.utils.stringify(val)
  if s ~= "" then return pandoc.Blocks({ pandoc.Para({ pandoc.Str(s) }) }) end
  return nil
end

local function meta_to_latex(val)
  local blocks = to_blocks(val)
  if blocks == nil then return "" end
  local latex = pandoc.write(pandoc.Pandoc(blocks), "latex")
  return (latex:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- LaTeX of a list of paragraphs, with a blank line between them (JCR's
-- sample sets the front matter flush left, with an extra return between
-- paragraphs)
local function latex_paragraphs(blocks)
  local parts = {}
  for _, b in ipairs(blocks) do
    local tex = pandoc.write(pandoc.Pandoc({ b }), "latex")
    tex = tex:gsub("^%s+", ""):gsub("%s+$", "")
    if tex ~= "" then parts[#parts + 1] = tex end
  end
  return table.concat(parts, "\n\n\\vspace{\\baselineskip}\n\n")
end

local function latex_text(text)
  local tex = pandoc.write(pandoc.Pandoc({ pandoc.Plain(pandoc.Inlines(text)) }), "latex")
  return (tex:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function safe_str(val)
  if val == nil then return "" end
  local s = pandoc.utils.stringify(val)
  if s and s ~= "" then return s end
  return ""
end

local function get_author_name(a)
  if a.name then
    if type(a.name) == "table" then
      if a.name.literal then return safe_str(a.name.literal) end
      local lit = a.name["literal"]
      if lit then return safe_str(lit) end
    end
    local n = safe_str(a.name)
    if n ~= "" then return n end
  end
  return safe_str(a)
end

local function get_author_field(a, field)
  if a[field] then return safe_str(a[field]) end
  return ""
end

-- Word paragraph with a named style from jcr-reference.docx
local function styled(style, blocks)
  return pandoc.Div(blocks, pandoc.Attr("", {}, { ["custom-style"] = style }))
end

local function docx_page_break()
  return pandoc.RawBlock("openxml", '<w:p><w:r><w:br w:type="page"/></w:r></w:p>')
end

local function page_break()
  if is_latex then return pandoc.RawBlock("latex", "\\clearpage") end
  if is_docx then return docx_page_break() end
  return nil
end

-- Does a list of blocks contain an element JCR does not allow in an abstract?
local function forbidden_in_abstract(blocks)
  local found = {}
  pandoc.Pandoc(blocks):walk({
    Cite = function() found.citations = true end,
    Link = function() found.links = true end,
    Image = function() found.figures = true end,
    Table = function() found.tables = true end,
  })
  local out = {}
  for _, k in ipairs({ "citations", "links", "tables", "figures" }) do
    if found[k] then table.insert(out, k) end
  end
  return out
end

local saved_meta = {}

-- =========================================================================
-- Meta
-- =========================================================================
function Meta(meta)
  if meta["jcr-mode"] then
    jcr_mode = pandoc.utils.stringify(meta["jcr-mode"]):lower():gsub("[%s_]", "-")
    if jcr_mode == "webappendix" then jcr_mode = "web-appendix" end
  end
  if meta["jcr-note-dash"] ~= nil then
    note_dash = (meta["jcr-note-dash"] == true) or
      (pandoc.utils.stringify(meta["jcr-note-dash"]) == "true")
  end

  if meta.anonymous ~= nil then
    anonymous = not ((meta.anonymous == false) or
      (pandoc.utils.stringify(meta.anonymous) == "false"))
  end

  -- Extension resources (Quarto also resolves these; kept for plain Pandoc use)
  local ext_dir = pandoc.path.directory(PANDOC_SCRIPT_FILE)
  if meta.csl then
    local csl_full = pandoc.path.join({ ext_dir, pandoc.utils.stringify(meta.csl) })
    local fh = io.open(csl_full, "r")
    if fh then fh:close(); meta.csl = pandoc.MetaInlines({ pandoc.Str(csl_full) }) end
  end
  if is_docx and meta["reference-doc"] then
    local ref_full = pandoc.path.join({ ext_dir, pandoc.utils.stringify(meta["reference-doc"]) })
    local fh = io.open(ref_full, "r")
    if fh then fh:close(); meta["reference-doc"] = pandoc.MetaInlines({ pandoc.Str(ref_full) }) end
  end

  -- Save the front matter before it is removed from the metadata
  saved_meta.title_inlines = meta.title
  saved_meta.title = meta.title and meta_to_latex(meta.title) or ""
  saved_meta.abstract_blocks = to_blocks(meta.abstract)
  saved_meta.abstract = meta.abstract and meta_to_latex(meta.abstract) or ""
  saved_meta.abstract_plain = meta.abstract and pandoc.utils.stringify(meta.abstract) or ""
  saved_meta.keywords = {}
  if meta.keywords then
    for _, k in ipairs(meta.keywords) do
      table.insert(saved_meta.keywords, pandoc.utils.stringify(k))
    end
  end
  saved_meta.authors = {}
  if meta.author then
    local author_list = meta.author
    if pandoc.utils.type(author_list) == "Inlines" then
      table.insert(saved_meta.authors, { name = pandoc.utils.stringify(author_list) })
    else
      for _, a in ipairs(author_list) do
        table.insert(saved_meta.authors, {
          name = get_author_name(a),
          email = get_author_field(a, "email"),
          affiliation = get_author_field(a, "affiliation"),
        })
      end
    end
  end
  saved_meta.author_note = meta["jcr-author-note"] and meta_to_latex(meta["jcr-author-note"]) or ""
  saved_meta.relevance_blocks = to_blocks(meta["consumer-relevance-statement"])
  saved_meta.relevance = meta["consumer-relevance-statement"] and meta_to_latex(meta["consumer-relevance-statement"]) or ""
  saved_meta.relevance_plain = meta["consumer-relevance-statement"] and pandoc.utils.stringify(meta["consumer-relevance-statement"]) or ""
  saved_meta.data_blocks = to_blocks(meta["data-availability-statement"])

  -- Article mode: publication-style preview (not for submission)
  if is_latex and jcr_mode == "article" then
    meta["jcr-article-mode"] = pandoc.MetaBool(true)
    meta.fontsize = pandoc.MetaInlines({ pandoc.Str("11pt") })
    meta.linestretch = pandoc.MetaInlines({ pandoc.Str("1.15") })
    meta.geometry = pandoc.MetaList({
      pandoc.MetaInlines({ pandoc.Str("top=1in") }),
      pandoc.MetaInlines({ pandoc.Str("bottom=1in") }),
      pandoc.MetaInlines({ pandoc.Str("left=1.25in") }),
      pandoc.MetaInlines({ pandoc.Str("right=1.25in") }),
    })
    meta.classoption = pandoc.MetaList({})
  end

  -- The filter writes the front matter itself
  if is_latex or is_docx then
    meta.title = nil
    meta.abstract = nil
    meta.author = nil
  end

  -- Checks against JCR's rules
  if jcr_mode == "web-appendix" then return meta end
  if saved_meta.abstract_plain ~= "" then
    local wc = count_words(saved_meta.abstract_plain)
    if wc > 200 then
      log_warning("JCR: abstract limited to 200 words. Current: ~" .. wc)
    end
    local bad = forbidden_in_abstract(saved_meta.abstract_blocks)
    if #bad > 0 then
      log_warning("JCR: the abstract may not contain " .. table.concat(bad, ", ") .. ".")
    end
  end
  if #saved_meta.keywords > 0 and (#saved_meta.keywords < 3 or #saved_meta.keywords > 6) then
    log_warning("JCR: include 3 to 6 keywords. Current: " .. #saved_meta.keywords)
  end
  if saved_meta.relevance_plain ~= "" then
    local wc = count_words(saved_meta.relevance_plain)
    if wc > 300 then
      log_warning("JCR: consumer relevance and contribution statement limited to 300 words. Current: ~" .. wc)
    end
  end
  return meta
end

-- =========================================================================
-- Front matter
-- =========================================================================
local function build_manuscript_latex()
  -- As in JCR's sample manuscript: the title; the heading of the statement;
  -- the statement; the heading of the abstract; the abstract; the keywords.
  -- Headings are centered and bold, the text is flush left, and an extra
  -- return (a blank line) separates each part from the next.
  local ms = {}
  local function add(line) table.insert(ms, line) end
  local blank = "\\vspace{\\baselineskip}"
  add("\\jcrsetupmanuscript")
  if saved_meta.title ~= "" then
    add("{\\centering " .. saved_meta.title .. "\\par}")
    add(blank)
  end
  if saved_meta.relevance_blocks then
    add("{\\centering\\textbf{CONSUMER RELEVANCE AND CONTRIBUTION STATEMENT}\\par}")
    add(blank)
    add("\\begin{jcrfront}")
    add(latex_paragraphs(saved_meta.relevance_blocks))
    add("\\end{jcrfront}")
    add(blank)
  end
  if saved_meta.abstract_blocks then
    add("{\\centering\\textbf{ABSTRACT}\\par}")
    add(blank)
    add("\\begin{jcrfront}")
    add(latex_paragraphs(saved_meta.abstract_blocks))
    add("\\end{jcrfront}")
  end
  if #saved_meta.keywords > 0 then
    -- JCR: keywords in a separate paragraph after the abstract
    add(blank)
    add("\\begin{jcrfront}")
    add("\\textit{Keywords:} " .. latex_text(table.concat(saved_meta.keywords, ", ")))
    add("\\end{jcrfront}")
  end
  add("\\clearpage")
  return table.concat(ms, "\n")
end

-- Web appendix: a title page labeled "WEB APPENDIX" with the title of the
-- manuscript and, after acceptance (anonymous: false), the authorship list.
-- The text that follows (a table of contents or a brief description of the
-- contents) stays on the title page; each web appendix begins on a new page.
local function build_web_appendix_latex()
  local ms = {}
  local function add(line) table.insert(ms, line) end
  local blank = "\\vspace{\\baselineskip}"
  add("\\jcrsetupmanuscript")
  add("{\\centering\\textbf{WEB APPENDIX}\\par}")
  add(blank)
  if saved_meta.title ~= "" then
    add("{\\centering " .. saved_meta.title .. "\\par}")
    add(blank)
  end
  if not anonymous and #saved_meta.authors > 0 then
    for _, a in ipairs(saved_meta.authors) do
      if a.name ~= "" then add("{\\centering " .. latex_text(a.name) .. "\\par}") end
    end
    add(blank)
  end
  return table.concat(ms, "\n")
end

local function build_web_appendix_docx()
  local front = pandoc.Blocks({})
  front:insert(styled("Abstract Title", { pandoc.Para({ pandoc.Str("WEB APPENDIX") }) }))
  if saved_meta.title_inlines then
    front:insert(styled("Title", { pandoc.Para(saved_meta.title_inlines) }))
  end
  if not anonymous and #saved_meta.authors > 0 then
    local names = pandoc.Blocks({})
    for _, a in ipairs(saved_meta.authors) do
      if a.name ~= "" then names:insert(pandoc.Para(pandoc.Inlines(a.name))) end
    end
    front:insert(styled("Author", names))
  end
  -- (an extra return before the text)
  front:insert(styled("Abstract", { pandoc.Para({ pandoc.Str("") }) }))
  return front
end

local function build_article_latex()
  local lines = {}
  table.insert(lines, "\\jcrsetuparticle")
  table.insert(lines, "")
  table.insert(lines, "{\\fontsize{16}{19}\\selectfont\\bfseries\\raggedright "
    .. saved_meta.title .. "\\par}%")
  table.insert(lines, "\\vskip 10pt")
  if #saved_meta.authors > 0 then
    table.insert(lines, "\\begin{center}")
    for _, a in ipairs(saved_meta.authors) do
      if a.name ~= "" then
        table.insert(lines, "{\\normalsize\\bfseries " .. a.name .. "\\par}%")
      end
    end
    table.insert(lines, "\\end{center}")
    table.insert(lines, "\\vskip 6pt")
  end
  if saved_meta.abstract ~= "" then
    table.insert(lines, "{\\noindent\\textbf{Abstract}\\par}")
    table.insert(lines, "\\vskip 4pt")
    table.insert(lines, "{\\noindent\\small " .. saved_meta.abstract .. "\\par}")
    table.insert(lines, "\\vskip 8pt")
    if #saved_meta.keywords > 0 then
      table.insert(lines, "{\\noindent\\textbf{Keywords}: \\small "
        .. table.concat(saved_meta.keywords, ", ") .. "\\par}")
      table.insert(lines, "\\vskip 8pt")
    end
  end
  table.insert(lines, "\\vskip 0.8\\baselineskip")
  table.insert(lines, "\\noindent\\rule{\\textwidth}{0.4pt}")
  table.insert(lines, "\\vskip 0.8\\baselineskip")
  if saved_meta.author_note ~= "" then
    table.insert(lines, "\\makeatletter")
    table.insert(lines, "\\def\\@makefnmark{}%")
    table.insert(lines, "\\footnotetext{\\fontsize{8}{10}\\selectfont\\raggedright")
    table.insert(lines, saved_meta.author_note)
    table.insert(lines, "}%")
    table.insert(lines, "\\makeatother")
  end
  return table.concat(lines, "\n")
end

-- Paragraphs separated by an empty paragraph (an extra return)
local function with_blank_lines(blocks)
  local out = pandoc.Blocks({})
  for i, b in ipairs(blocks) do
    if i > 1 then out:insert(pandoc.Para({ pandoc.Str("") })) end
    out:insert(b)
  end
  return out
end

local function build_manuscript_docx()
  local front = pandoc.Blocks({})
  if saved_meta.title_inlines then
    front:insert(styled("Title", { pandoc.Para(saved_meta.title_inlines) }))
  end
  if saved_meta.relevance_blocks then
    front:insert(styled("Abstract Title", { pandoc.Para({ pandoc.Str("CONSUMER RELEVANCE AND CONTRIBUTION STATEMENT") }) }))
    front:insert(styled("Abstract", with_blank_lines(saved_meta.relevance_blocks)))
  end
  if saved_meta.abstract_blocks then
    front:insert(styled("Abstract Title", { pandoc.Para({ pandoc.Str("ABSTRACT") }) }))
    front:insert(styled("Abstract", with_blank_lines(saved_meta.abstract_blocks)))
  end
  if #saved_meta.keywords > 0 then
    local kw = pandoc.Inlines({ pandoc.Emph({ pandoc.Str("Keywords:") }), pandoc.Space() })
    kw:extend(pandoc.Inlines(table.concat(saved_meta.keywords, ", ")))
    front:insert(styled("Keywords", { pandoc.Para(kw) }))
  end
  front:insert(docx_page_break())
  return front
end

-- =========================================================================
-- Notes under tables and figures: ::: {.jcr-note}. The class names of the
-- other extensions of this family (.notes, .table-notes, ...) work as well.
-- =========================================================================
local note_classes = { "jcr-note", "jcr-notes", "table-notes", "table-note", "figure-notes",
  "figure-note", "notes", "note" }

local function is_note_div(el)
  for _, c in ipairs(note_classes) do
    if el.classes:includes(c) then return true end
  end
  return false
end

-- In LaTeX a note is one block, which the second filter moves into the
-- figure it follows, so that a page break cannot separate the two
local function latex_note(blocks)
  local out = pandoc.Blocks({ pandoc.RawBlock("latex", "\\begin{jcrnotes}") })
  out:extend(blocks)
  out:insert(pandoc.RawBlock("latex", "\\end{jcrnotes}"))
  return pandoc.Div(out, pandoc.Attr("", { "mq-note" }))
end

local function starts_with_note(inlines)
  local first = inlines[1]
  if first == nil then return false end
  local s = pandoc.utils.stringify(first)
  return s:sub(1, 4):upper() == "NOTE"
end

local function note_label()
  local label = pandoc.Inlines({ pandoc.Str("NOTE.") })
  if note_dash then label:insert(pandoc.Str("\u{2014}")) else label:insert(pandoc.Space()) end
  return label
end

local function make_note(el)
  local blocks = el.content:clone()
  if blocks[1] and (blocks[1].t == "Para" or blocks[1].t == "Plain")
     and not starts_with_note(blocks[1].content) then
    local inl = note_label()
    inl:extend(blocks[1].content)
    blocks[1] = pandoc.Para(inl)
  end
  if is_latex then
    return latex_note(blocks)
  elseif is_docx then
    return styled("Table Note", blocks)
  end
  return pandoc.Div(blocks, el.attr)
end

-- =========================================================================
-- Hypotheses, "bold, indented, syllabus style": the label ("H1:", "H2a:",
-- "Hypothesis 1:": the words up to the first colon, or a label typed in
-- bold) is set in bold at the paragraph indent, and the hypothesis hangs
-- half an inch to its right, as in the style guide's example
-- =========================================================================
local function split_hypothesis(inl)
  if #inl == 0 then return nil end
  if inl[1].t == "Strong" then
    local rest = pandoc.Inlines({})
    for j = 2, #inl do rest:insert(inl[j]) end
    return inl[1].content, rest
  end
  for i = 1, math.min(#inl, 4) do
    local x = inl[i]
    if x.t == "Str" and x.text:sub(-1) == ":" then
      local label, rest = pandoc.Inlines({}), pandoc.Inlines({})
      for j = 1, i do label:insert(inl[j]) end
      for j = i + 1, #inl do rest:insert(inl[j]) end
      return label, rest
    end
  end
  return nil
end

function bold_hypothesis_label(blocks)
  local first = blocks[1]
  if first == nil or (first.t ~= "Para" and first.t ~= "Plain") then return blocks end
  local label, rest = split_hypothesis(first.content)
  if not label then return blocks end
  while rest[1] and (rest[1].t == "Space" or rest[1].t == "SoftBreak") do rest:remove(1) end
  local out
  if is_latex then
    out = pandoc.Inlines({ pandoc.RawInline("latex", "\\jcrhyplabel{") })
    out:extend(label)
    out:insert(pandoc.RawInline("latex", "}"))
  elseif is_docx then
    -- (the tab moves to the hanging indent of the "Hypothesis" style)
    out = pandoc.Inlines({ pandoc.Strong(label), pandoc.RawInline("openxml", "<w:r><w:tab /></w:r>") })
  else
    out = pandoc.Inlines({ pandoc.Strong(label), pandoc.Space() })
  end
  out:extend(rest)
  first.content = out
  blocks[1] = first
  return blocks
end

-- =========================================================================
function Note(el)
  footnote_count = footnote_count + 1
  if footnote_count > 5 then
    log_warning("JCR: the style sheet asks for footnotes to be used sparingly. Count: " .. footnote_count)
  end
  return el
end

function Div(el)
  if is_note_div(el) then
    -- false: do not process the note's paragraphs again (see Para below)
    return make_note(el), false
  end
  -- Hypotheses: ::: {.hypothesis}, indented, with space above and below;
  -- the label ("H1:") in bold, the hypothesis itself not
  if el.classes:includes("hypothesis") then
    local content = bold_hypothesis_label(el.content:clone())
    if is_latex then
      local blocks = pandoc.Blocks({ pandoc.RawBlock("latex", "\\begin{jcrhypothesis}") })
      blocks:extend(content)
      blocks:insert(pandoc.RawBlock("latex", "\\end{jcrhypothesis}"))
      return blocks
    elseif is_docx then
      return styled("Hypothesis", content)
    end
    el.content = content
    return el
  end
  if el.classes:includes("jcr-label") then
    if is_latex then
      local blocks = pandoc.Blocks({ pandoc.RawBlock("latex", "\\begin{center}") })
      blocks:extend(el.content)
      blocks:insert(pandoc.RawBlock("latex", "\\end{center}"))
      return blocks
    elseif is_docx then
      return styled("Caption", el.content)
    end
  end
  return el
end

-- Images that stand alone in a paragraph of the text are centered (see Para
-- below). Images inside a numbered figure or table, or inside a panel
-- (layout-ncol and the like), are placed by Quarto: they are marked first
-- and left alone.
local function is_custom_float(b)
  return b.t == "Div" and b.attributes["__quarto_custom_type"] == "FloatRefTarget"
end

local function placed_by_quarto(div)
  local a = div.attributes
  return a["__quarto_custom_type"] ~= nil or a["layout-ncol"] ~= nil
    or a["layout-nrow"] ~= nil or a["layout"] ~= nil
end

-- Word: Quarto separates two tables or figures that follow each other with
-- an empty paragraph, also inside a figure with panels, where the paragraph
-- becomes an empty panel and the panels end up below each other. Each panel
-- goes into a block of its own, the way the plots of a code chunk arrive.
local function separate_panels(float)
  local changed = false
  for i, slot in ipairs(float.content) do
    if slot.t == "Div" and slot.attributes["__quarto_custom_scaffold"] then
      local n = 0
      for _, b in ipairs(slot.content) do if is_custom_float(b) then n = n + 1 end end
      if n >= 2 then
        slot.content = slot.content:map(function(b)
          if is_custom_float(b) then
            return pandoc.Div({ b }, pandoc.Attr("", { "cell-output-display" }))
          end
          return b
        end)
        float.content[i] = slot
        changed = true
      end
    end
  end
  return changed
end

local function prepare_floats(doc)
  if not (is_latex or is_docx) then return nil end
  return doc:walk({
    Div = function(div)
      local changed = false
      if is_docx and is_custom_float(div) then changed = separate_panels(div) end
      if is_latex and placed_by_quarto(div) then
        div = div:walk({
          Image = function(img) img.attributes["mq-placed"] = "1"; return img end,
        })
        changed = true
      end
      if changed then return div end
      return nil
    end,
  })
end

local function clear_marks(doc)
  if not is_latex then return nil end
  return doc:walk({
    Image = function(img)
      if img.attributes["mq-placed"] then
        img.attributes["mq-placed"] = nil
        return img
      end
      return nil
    end,
  })
end

-- Paragraphs that begin with "NOTE." outside a note div; centered images
function Para(el)
  if #el.content == 0 then return el end
  local first = el.content[1]
  if is_latex and #el.content == 1 and first.t == "Image" and not first.attributes["mq-placed"] then
    return pandoc.Blocks({
      pandoc.RawBlock("latex", "\\begin{center}"), el,
      pandoc.RawBlock("latex", "\\end{center}"),
    })
  end
  local text = ""
  if first.t == "Str" then text = first.text
  elseif (first.t == "Strong" or first.t == "Emph") and #first.content > 0
         and first.content[1].t == "Str" then text = first.content[1].text end
  if text:sub(1, 5) == "NOTE." then
    if is_latex then
      -- false: the paragraph inside the new block is not visited again
      return latex_note(pandoc.Blocks({ el })), false
    elseif is_docx then
      return styled("Table Note", { el })
    end
  end
  return el
end

-- Appendixes: "Appendix A: Title" is set as a label line and a title line.
-- (The page break before each appendix is added in Pandoc below.)
local function is_appendix(b)
  return b.t == "Header" and b.level == 1 and b.classes:includes("appendix")
end

-- The title of an appendix is set in regular type under its bold label. In
-- Word, a character style cannot switch off the bold of the heading style
-- (bold in a character style toggles the bold of the paragraph style), so
-- the title is written as WordprocessingML runs with bold switched off.
local function regular_runs(inlines)
  if not (pandoc.write and pandoc.zip) then return nil end
  local ok, xml = pcall(function()
    local bytes = pandoc.write(pandoc.Pandoc({ pandoc.Plain(inlines) }), "docx")
    local archive = pandoc.zip.Archive(bytes)
    for _, entry in ipairs(archive.entries) do
      if entry.path == "word/document.xml" then return entry:contents() end
    end
    return nil
  end)
  if not ok or type(xml) ~= "string" then return nil end
  local body = xml:match("<w:body>(.-)<w:sectPr")
  if not body then return nil end
  local para = body:match("^%s*<w:p>(.*)</w:p>%s*$") or body:match("^%s*<w:p [^>]*>(.*)</w:p>%s*$")
  if not para or para:find("<w:p[ >]") then return nil end
  para = para:gsub("^%s*<w:pPr>.-</w:pPr>", "", 1):gsub("^%s*<w:pPr%s*/>", "", 1)
  local off = '<w:b w:val="0" /><w:bCs w:val="0" />'
  local count = 0
  para = para:gsub("<w:r>(.-)</w:r>", function(inner)
    count = count + 1
    -- bold typed by the author is left alone
    if inner:find("<w:b[ />]") then return "<w:r>" .. inner .. "</w:r>" end
    local rest = inner:match("^%s*<w:rPr>(.*)$")
    if rest then
      -- (CT_RPr order: rStyle, rFonts, b, bCs, ...)
      local lead = ""
      for _, tag in ipairs({ "rStyle", "rFonts" }) do
        local piece = rest:match("^(%s*<w:" .. tag .. " [^>]-/>)")
        if piece then lead = lead .. piece; rest = rest:sub(#piece + 1) end
      end
      return "<w:r><w:rPr>" .. lead .. off .. rest .. "</w:r>"
    end
    local after = inner:match("^%s*<w:rPr%s*/>(.*)$")
    if after then return "<w:r><w:rPr>" .. off .. "</w:rPr>" .. after .. "</w:r>" end
    return "<w:r><w:rPr>" .. off .. "</w:rPr>" .. inner .. "</w:r>"
  end)
  if count == 0 then return nil end
  return pandoc.RawInline("openxml", para)
end

function Header(el)
  -- In a web appendix, "# Web Appendix A: Title" needs no class
  if jcr_mode == "web-appendix" and el.level == 1 and not el.classes:includes("appendix")
     and pandoc.utils.stringify(el.content):lower():match("^web appendix") then
    el.classes:insert("appendix")
  end
  if is_appendix(el) then
    local content = el.content
    for i, inl in ipairs(content) do
      if inl.t == "Str" and inl.text:sub(-1) == ":" and i < #content then
        local label = pandoc.Inlines({})
        for j = 1, i - 1 do label:insert(content[j]) end
        label:insert(pandoc.Str(inl.text:sub(1, -2)))
        local title = pandoc.Inlines({})
        for j = i + 1, #content do title:insert(content[j]) end
        if title[1] and title[1].t == "Space" then title:remove(1) end
        -- JCR's sample: the label in bold, the title in regular type
        local new = pandoc.Inlines(label)
        if is_latex then
          -- \\ breaks inside capitalized section titles; \jcrbr does not
          new:insert(pandoc.RawInline("latex", "\\jcrbr{}\\mdseries{}"))
          new:insert(pandoc.Space())
          new:extend(title)
        elseif is_docx then
          new:insert(pandoc.LineBreak())
          new:insert(regular_runs(title)
            or pandoc.Span(title, pandoc.Attr("", {}, { ["custom-style"] = "Appendix Title" })))
        else
          new:insert(pandoc.LineBreak())
          new:extend(title)
        end
        el.content = new
        break
      end
    end
  end
  return el
end

-- =========================================================================
-- Document-level passes
-- =========================================================================
local function is_refs_header(b)
  return b.t == "Header" and b.level == 1 and
    (b.identifier == "references" or b.classes:includes("references") or
     pandoc.utils.stringify(b.content):lower() == "references")
end

local function check_secondary_headings(blocks)
  local count, section = 0, nil
  local warned_level = false
  local function flush()
    if section and count == 1 then
      log_warning("JCR: section \"" .. section .. "\" has a single secondary heading; use none or at least two.")
    end
  end
  for _, b in ipairs(blocks) do
    if b.t == "Header" and b.level == 1 then
      flush(); section = pandoc.utils.stringify(b.content); count = 0
    elseif b.t == "Header" and b.level == 2 then
      count = count + 1
    end
    if b.t == "Header" and b.level > 3 and not warned_level then
      warned_level = true
      log_warning("JCR: use no more than 3 levels of headings.")
    end
  end
  flush()
end

-- A table or a picture that has a title but no label is not numbered, in
-- either output, and cannot be cited; the author most likely forgot the label
local function check_unlabeled(blocks)
  local tables, figures = 0, 0
  local ok = pcall(function()
    pandoc.Blocks(blocks):walk({
      traverse = "topdown",
      Div = function(d)
        -- (the parts of a labeled table or figure may have captions of their own)
        if d.attributes["__quarto_custom_type"] ~= nil or d.attributes["layout-ncol"] ~= nil
           or d.attributes["layout-nrow"] ~= nil or d.attributes["layout"] ~= nil then
          return d, false
        end
        return nil
      end,
      Table = function(t)
        if t.caption and t.caption.long and pandoc.utils.stringify(t.caption.long) ~= "" then
          tables = tables + 1
        end
        return nil
      end,
      Figure = function(f)
        if f.caption and f.caption.long and pandoc.utils.stringify(f.caption.long) ~= "" then
          figures = figures + 1
        end
        return nil
      end,
    })
  end)
  if not ok then return end
  if tables > 0 then
    log_warning("JCR: " .. tables .. (tables == 1 and " table has" or " tables have")
      .. " a title but no label, so " .. (tables == 1 and "it is" or "they are")
      .. " not numbered. Give it a label: {#tbl-results} after the title, or \"#| label: tbl-results\" in a code chunk.")
  end
  if figures > 0 then
    log_warning("JCR: " .. figures .. (figures == 1 and " figure has" or " figures have")
      .. " a caption but no label, so " .. (figures == 1 and "it is" or "they are")
      .. " not numbered. Give it a label: {#fig-results} after the image, or \"#| label: fig-results\" in a code chunk.")
  end
end

-- Word cannot set a heading in the same paragraph as text, so tertiary
-- headings become an italic run-in phrase ending with a period (JCR style)
local function runin_tertiary(blocks)
  local out = pandoc.Blocks({})
  local i = 1
  while i <= #blocks do
    local b = blocks[i]
    local nxt = blocks[i + 1]
    if b.t == "Header" and b.level == 3 and nxt and nxt.t == "Para" then
      local head = b.content:clone()
      local last = head[#head]
      if not (last and last.t == "Str" and last.text:match("[%.%?!]$")) then
        head:insert(pandoc.Str("."))
      end
      local inl = pandoc.Inlines({ pandoc.Emph(head), pandoc.Space() })
      inl:extend(nxt.content)
      -- "Run-in Paragraph": the paragraph indent, and an extra return before
      out:insert(styled("Run-in Paragraph", { pandoc.Para(inl) }))
      i = i + 2
    else
      out:insert(b)
      i = i + 1
    end
  end
  return out
end

function Pandoc(doc)
  check_secondary_headings(doc.blocks)
  if is_latex or is_docx then check_unlabeled(doc.blocks) end
  local body = doc.blocks
  if is_docx then body = runin_tertiary(body) end

  -- JCR order: text; data and materials availability statement; each
  -- appendix on a new page; references on a new page
  local with_refs = pandoc.Blocks({})
  local data_done = (saved_meta.data_blocks == nil)
  local refs_done = false
  local function insert_data()
    if not data_done then
      -- The statement begins on a new page (style guide)
      local br = page_break()
      if br then with_refs:insert(br) end
      with_refs:insert(pandoc.Header(1,
        pandoc.Inlines("Data and Materials Availability Statement"),
        pandoc.Attr("data-and-materials-availability-statement", { "unnumbered" })))
      with_refs:extend(saved_meta.data_blocks)
      data_done = true
    end
  end
  for _, b in ipairs(body) do
    local refs = (not refs_done) and
      (is_refs_header(b) or (b.t == "Div" and b.identifier == "refs"))
    if is_appendix(b) or refs then
      insert_data()
      local br = page_break()
      if br then with_refs:insert(br) end
      if refs then refs_done = true end
    end
    with_refs:insert(b)
  end
  insert_data()

  local new_blocks = pandoc.Blocks({})
  if is_latex then
    if jcr_mode == "article" then
      new_blocks:insert(pandoc.RawBlock("latex", build_article_latex()))
    elseif jcr_mode == "web-appendix" then
      new_blocks:insert(pandoc.RawBlock("latex", build_web_appendix_latex()))
    else
      new_blocks:insert(pandoc.RawBlock("latex", build_manuscript_latex()))
    end
  elseif is_docx then
    if jcr_mode == "web-appendix" then
      new_blocks:extend(build_web_appendix_docx())
    else
      new_blocks:extend(build_manuscript_docx())
    end
  end
  new_blocks:extend(with_refs)
  doc.blocks = new_blocks
  return doc
end

return {
  { Meta = Meta },
  { Note = Note },
  { Pandoc = prepare_floats },
  -- Top down, so that a note div is formatted once and its paragraphs are
  -- not formatted again by Para
  { traverse = "topdown", Div = Div, Para = Para },
  { Pandoc = clear_marks },
  { Header = Header },
  { Pandoc = Pandoc },
}
