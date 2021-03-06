local wiki_prefix = "https://zh.wikipedia.org/wiki/"

local function starts_with(str, start)
  return str:sub(1, #start) == start
end

local function istarts_with(str, start)
  return starts_with(str:lower(), start:lower())
end

local function ends_with(str, ending)
   return ending == "" or str:sub(-#ending) == ending
end

local function file_exists(name)
    local f = io.open(name, 'r')
    if f ~= nil then
        io.close(f)
        return true
    else
        return false
    end
end

local wiki_path = "../wikipedia.zh"
if not file_exists( wiki_path .. "/README.md") then
  wiki_path = "/mnt/t/chinapedia/wikipedia.zh"
end

local function category_exists(c)
  return false
end

local function page_exists(p)
    return file_exists(wiki_path .. "/Page/" .. p .. ".md")
end

local function special_page_exists(sp, p)
    return file_exists(wiki_path .. "/" .. sp .. "/" .. p .. ".md")
end

function Link(el)
  if el.title ~= "wikilink" then
    return el
  end
  
  if istarts_with(el.target, "Category:") then
    local c = string.sub(el.target, 1 + #"Category:")
    if not category_exists(c) then
        el.target = wiki_prefix .. el.target
        return pandoc.Link("Category:" .. c, wiki_prefix .. "Category:" .. c, el.title)
    end
    el.target = "../Category/" .. c
  elseif istarts_with(el.target, ":Category:") then
    local c = string.sub(el.target, 1 + #":Category:")
    if not category_exists(c) then
        el.target = "https://zh.wikipedia.org/wiki/Category:" .. c
        return el
    end
    el.target = "../Category/" .. c
  elseif istarts_with(el.target, "MediaWiki:") then
    local c = string.sub(el.target, 1 + #"MediaWiki:")
    if not special_page_exists("MediaWiki", c) then
        el.target = "https://zh.wikipedia.org/wiki/MediaWiki:" .. c
        return el
    end
    el.target = "../MediaWiki/" .. c
  elseif istarts_with(el.target, "Wikipedia:") or istarts_with(el.target, "WP:") then
    el.target = wiki_prefix .. el.target
    return el
  elseif istarts_with(el.target, "Help:") then
    el.target = wiki_prefix .. el.target
    return el
  elseif not page_exists(el.target) then
    ctxt = el.content[1].text
    if starts_with(ctxt, el.target) then
      if ctxt ~= el.target then
        suffix = ctxt:sub(1 + #el.target)
        el.content[1].text = el.target
        el.target = wiki_prefix .. el.target 
        return {el, pandoc.Str(suffix)} 
      end
    end
    el.target = wiki_prefix .. el.target
    return el
  else 
    ctxt = el.content[1].text
    if starts_with(ctxt, el.target) then
      if ctxt ~= el.target then
        suffix = ctxt:sub(1 + #el.target)
        el.content[1].text = el.target
        el.target = "../Page/" .. el.target .. ".md"
        return {el, pandoc.Str(suffix)} 
      end
    end
    el.target = "../Page/" .. el.target
  end
  el.target = el.target .. ".md"
  
  return el
end

function Image(el)
  return pandoc.Link(el.caption, "https://zh.wikipedia.org/wiki/File:" .. el.src, el.title)
end
