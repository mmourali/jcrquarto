-- jcrquarto.lua  (v0.5.0)
-- Journal of Consumer Research Quarto/Pandoc filter
-- Modes: "manuscript" (default) | "article"

local footnote_count = 0
local jcr_mode = "manuscript"
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

local function meta_to_latex(val)
  if val == nil then return "" end
  local t = pandoc.utils.type(val)
  local doc
  if t == "Inlines" then
    doc = pandoc.Pandoc({ pandoc.Para(val) })
  elseif t == "Blocks" then
    doc = pandoc.Pandoc(val)
  else
    return pandoc.utils.stringify(val)
  end
  local latex = pandoc.write(doc, "latex")
  return latex:gsub("^%s+", ""):gsub("%s+$", "")
end

local function meta_to_blocks(val)
  local t = pandoc.utils.type(val)
  if t == "Blocks" then return val
  elseif t == "Inlines" then return pandoc.Blocks({ pandoc.Para(val) })
  elseif t == "table" and val[1] then return pandoc.Blocks(val)
  else
    local s = pandoc.utils.stringify(val)
    if s ~= "" then return pandoc.Blocks({ pandoc.Para({ pandoc.Str(s) }) }) end
  end
  return nil
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
  local n = safe_str(a)
  if n ~= "" then return n end
  return ""
end

local function get_author_field(a, field)
  if a[field] then return safe_str(a[field]) end
  return ""
end

local saved_meta = {}

-- =========================================================================
-- Meta filter
-- =========================================================================
function Meta(meta)
  if meta["jcr-mode"] then
    jcr_mode = pandoc.utils.stringify(meta["jcr-mode"])
  end

  -- ---- Resolve extension resource paths ----
  local ext_dir = pandoc.path.directory(PANDOC_SCRIPT_FILE)
  if meta.csl then
    local csl_name = pandoc.utils.stringify(meta.csl)
    local csl_full = pandoc.path.join({ ext_dir, csl_name })
    local fh = io.open(csl_full, "r")
    if fh then
      fh:close()
      meta.csl = pandoc.MetaInlines({ pandoc.Str(csl_full) })
    end
  end
  if is_docx and meta["reference-doc"] then
    local ref_name = pandoc.utils.stringify(meta["reference-doc"])
    local ref_full = pandoc.path.join({ ext_dir, ref_name })
    local fh = io.open(ref_full, "r")
    if fh then
      fh:close()
      meta["reference-doc"] = pandoc.MetaInlines({ pandoc.Str(ref_full) })
    end
  end

  -- Save fields
  saved_meta.title = meta.title and meta_to_latex(meta.title) or ""
  saved_meta.abstract = meta.abstract and meta_to_latex(meta.abstract) or ""
  saved_meta.abstract_plain = meta.abstract and pandoc.utils.stringify(meta.abstract) or ""
  saved_meta.keywords = {}
  if meta.keywords then
    for _, k in ipairs(meta.keywords) do
      table.insert(saved_meta.keywords, pandoc.utils.stringify(k))
    end
  end

  -- Extract authors
  saved_meta.authors = {}
  if meta.author then
    local author_list = meta.author
    if pandoc.utils.type(author_list) == "Inlines" then
      table.insert(saved_meta.authors, {
        name = pandoc.utils.stringify(author_list),
        email = "", role = "", affiliation = ""
      })
    else
      for _, a in ipairs(author_list) do
        local entry = {
          name = get_author_name(a),
          email = get_author_field(a, "email"),
          role = get_author_field(a, "role"),
          affiliation = get_author_field(a, "affiliation"),
        }
        if entry.name == "" then
          entry.name = safe_str(a)
        end
        table.insert(saved_meta.authors, entry)
      end
    end
  end

  saved_meta.short_author = meta["short-author"] and safe_str(meta["short-author"]) or ""
  saved_meta.corresponding = meta["corresponding-author"] and safe_str(meta["corresponding-author"]) or ""
  saved_meta.acknowledgments = meta.acknowledgments and meta_to_latex(meta.acknowledgments) or ""
  saved_meta.web_appendix = meta["web-appendix-note"] and true or false
  saved_meta.editor = meta["jcr-editor"] and safe_str(meta["jcr-editor"]) or ""
  saved_meta.assoc_editor = meta["jcr-associate-editor"] and safe_str(meta["jcr-associate-editor"]) or ""
  saved_meta.pub_date = meta["publication-date"] and safe_str(meta["publication-date"]) or ""
  saved_meta.author_note = meta["jcr-author-note"] and meta_to_latex(meta["jcr-author-note"]) or ""
  saved_meta.consumer_relevance = meta["consumer-relevance-statement"] and meta_to_latex(meta["consumer-relevance-statement"]) or ""
  saved_meta.consumer_relevance_plain = meta["consumer-relevance-statement"] and pandoc.utils.stringify(meta["consumer-relevance-statement"]) or ""

  -- Article mode: override metadata for publication-style single-column layout
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
    -- No twocolumn
    meta.classoption = pandoc.MetaList({})
  end

  -- Clear title/author/abstract from meta so Pandoc's default template
  -- does not render them. Our Lua filter handles all front matter.
  if is_latex or is_docx then
    meta.title = nil
    meta.abstract = nil
    meta.author = nil
  end

  -- Validation
  if saved_meta.abstract_plain ~= "" then
    local wc = count_words(saved_meta.abstract_plain)
    if wc > 200 then
      log_warning("JCR: Abstract limited to 200 words. Current: ~" .. wc)
    end
  end
  if #saved_meta.keywords > 0 and (#saved_meta.keywords < 3 or #saved_meta.keywords > 6) then
    log_warning("JCR: Include 3 to 6 keywords. Current: " .. #saved_meta.keywords)
  end
  if saved_meta.consumer_relevance_plain ~= "" then
    local wc = count_words(saved_meta.consumer_relevance_plain)
    if wc > 300 then
      log_warning("JCR: Consumer Relevance Statement max 300 words. Current: ~" .. wc)
    end
  end

  -- DOCX front-matter
  if is_docx then
    local front = pandoc.Blocks({})
    if saved_meta.title ~= "" then
      front:insert(pandoc.Header(1, pandoc.Str(saved_meta.title)))
    end
    if saved_meta.consumer_relevance_plain ~= "" then
      front:insert(pandoc.Para({ pandoc.LineBreak() }))
      front:insert(pandoc.Header(2, pandoc.Str("CONSUMER RELEVANCE AND CONTRIBUTION STATEMENT")))
      front:insert(pandoc.Para({ pandoc.Str(saved_meta.consumer_relevance_plain) }))
    end
    if saved_meta.abstract_plain ~= "" then
      front:insert(pandoc.Para({ pandoc.LineBreak() }))
      front:insert(pandoc.Header(2, pandoc.Str("ABSTRACT")))
      front:insert(pandoc.Para({ pandoc.Str(saved_meta.abstract_plain) }))
    end
    if #saved_meta.keywords > 0 then
      local kw = { pandoc.Emph({ pandoc.Str("Keywords:") }), pandoc.Str(" ") }
      for i, k in ipairs(saved_meta.keywords) do
        if i > 1 then table.insert(kw, pandoc.Str(", ")) end
        table.insert(kw, pandoc.Str(k))
      end
      front:insert(pandoc.Para(kw))
    end
    front:insert(pandoc.RawBlock("openxml",
      '<w:p><w:r><w:br w:type="page"/></w:r></w:p>'))
    meta["front-matter-blocks"] = front
  end

  return meta
end

-- =========================================================================
-- Build article-mode LaTeX title block (single-column publication style)
-- =========================================================================
local function build_article_header()
  local lines = {}

  table.insert(lines, "\\jcrsetuparticle")
  table.insert(lines, "")

  -- Title
  table.insert(lines, "{\\fontsize{16}{19}\\selectfont\\bfseries\\raggedright "
    .. saved_meta.title .. "\\par}%")
  table.insert(lines, "\\vskip 10pt")

  -- Authors (centered)
  if #saved_meta.authors > 0 then
    table.insert(lines, "\\begin{center}")
    for _, a in ipairs(saved_meta.authors) do
      if a.name ~= "" then
        table.insert(lines, "{\\normalsize\\bfseries "
          .. a.name .. "\\par}%")
      end
    end
    table.insert(lines, "\\end{center}")
    table.insert(lines, "\\vskip 6pt")
  end

  -- Abstract
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

  -- Author note as first-page footnote
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

-- =========================================================================
function Note(el)
  footnote_count = footnote_count + 1
  if footnote_count > 5 then
    log_warning("JCR: Footnotes strongly discouraged. Count: " .. footnote_count)
  end
  return el
end

function Div(el)
  if is_latex and el.classes:includes("hypothesis") then
    return pandoc.Blocks({
      pandoc.RawBlock("latex", "\\begin{quote}\\bfseries"),
      table.unpack(el.content),
      pandoc.RawBlock("latex", "\\end{quote}"),
    })
  end
  -- Table/figure notes: renders as small sans-serif indented text below table
  if el.classes:includes("table-notes") then
    if is_latex then
      return pandoc.Blocks({
        pandoc.RawBlock("latex", "\\begin{jcrnotes}"),
        table.unpack(el.content),
        pandoc.RawBlock("latex", "\\end{jcrnotes}"),
      })
    elseif is_docx then
      -- For DOCX, render as small italic paragraph
      local blocks = pandoc.Blocks({})
      for _, b in ipairs(el.content) do
        if b.t == "Para" then
          local inlines = pandoc.List({})
          for _, inline in ipairs(b.content) do
            inlines:insert(inline)
          end
          blocks:insert(pandoc.Para(inlines))
        else
          blocks:insert(b)
        end
      end
      return blocks
    end
  end
  return el
end

-- Appendix headers: auto-insert page break before H1 headers with .appendix class
function Header(el)
  if el.level == 1 and el.classes:includes("appendix") then
    if is_latex then
      return pandoc.Blocks({
        pandoc.RawBlock("latex", "\\newpage"),
        el,
      })
    elseif is_docx then
      return pandoc.Blocks({
        pandoc.RawBlock("openxml", '<w:p><w:r><w:br w:type="page"/></w:r></w:p>'),
        el,
      })
    end
  end
  return el
end

function Pandoc(doc)
  local new_blocks = pandoc.Blocks({})

  if is_latex then
    if jcr_mode == "article" then
      new_blocks:insert(pandoc.RawBlock("latex", build_article_header()))
    else
      -- Manuscript mode: build front matter here since we cleared meta
      local ms = {}
      table.insert(ms, "\\jcrsetupmanuscript")
      if saved_meta.title ~= "" then
        table.insert(ms, "\\begin{center}")
        table.insert(ms, "{\\normalsize " .. saved_meta.title .. "}")
        table.insert(ms, "\\end{center}")
        table.insert(ms, "\\vspace{\\baselineskip}")
      end
      if saved_meta.consumer_relevance ~= "" then
        table.insert(ms, "\\begin{center}")
        table.insert(ms, "\\textbf{CONSUMER RELEVANCE AND CONTRIBUTION STATEMENT}")
        table.insert(ms, "\\end{center}")
        table.insert(ms, "\\vspace{0.5\\baselineskip}")
        table.insert(ms, "\\noindent (for new submissions only; do not include this with invited revisions)")
        table.insert(ms, "")
        table.insert(ms, saved_meta.consumer_relevance)
        table.insert(ms, "\\vspace{\\baselineskip}")
      end
      if saved_meta.abstract ~= "" then
        table.insert(ms, "\\begin{center}")
        table.insert(ms, "\\textbf{ABSTRACT}")
        table.insert(ms, "\\end{center}")
        table.insert(ms, "\\vspace{0.5\\baselineskip}")
        table.insert(ms, "\\noindent " .. saved_meta.abstract)
      end
      if #saved_meta.keywords > 0 then
        table.insert(ms, "\\vspace{0.5\\baselineskip}")
        table.insert(ms, "\\noindent \\textit{Keywords:} "
          .. table.concat(saved_meta.keywords, ", "))
      end
      table.insert(ms, "\\newpage")
      new_blocks:insert(pandoc.RawBlock("latex", table.concat(ms, "\n")))
    end
  end

  if is_docx and doc.meta["front-matter-blocks"] then
    local front = doc.meta["front-matter-blocks"]
    if pandoc.utils.type(front) == "Blocks" then
      new_blocks:extend(front)
    end
    doc.meta["front-matter-blocks"] = nil
  end

  new_blocks:extend(doc.blocks)
  doc.blocks = new_blocks
  return doc
end

return {
  { Meta = Meta },
  { Note = Note },
  { Div = Div },
  { Header = Header },
  { Pandoc = Pandoc }
}
