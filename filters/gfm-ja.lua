local wiki_prefix = "https://ja.wikipedia.org/wiki/"

function all_trim(s)
   return s:match( "^%s*(.-)%s*$" )
end

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

local wiki_path = "../wikipedia.ja"
if not file_exists( wiki_path .. "/README.md") then
  wiki_path = "/mnt/t/chinapedia/wikipedia.ja"
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
        el.target = "https://ja.wikipedia.org/wiki/Category:" .. c
        return el
    end
    el.target = "../Category/" .. c
  elseif istarts_with(el.target, "MediaWiki:") then
    local c = string.sub(el.target, 1 + #"MediaWiki:")
    if not special_page_exists("MediaWiki", c) then
        el.target = "https://ja.wikipedia.org/wiki/MediaWiki:" .. c
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
    if ctxt and starts_with(ctxt, el.target) then
      if ctxt ~= el.target then
        suffix = ctxt:sub(1 + #el.target)
        el.content[1].text = el.target .. "ⓦ"
        el.target = wiki_prefix .. el.target 
        return {el, pandoc.Str(suffix)} 
      end
    end
    el.content[1].text = ctxt .. "ⓦ"
    el.target = wiki_prefix .. el.target
    return el
  else 
    ctxt = el.content[1].text
    if ctxt and starts_with(ctxt, el.target) then
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
  return pandoc.Link(el.caption, "https://ja.wikipedia.org/wiki/File:" .. el.src, el.title)
end

function RawBlock(el)
  if starts_with(el.text, '{{') then
    tpl=all_trim(el.text:sub(3, #el.text - 2))
    local t={}
    tplName=""
    for str in string.gmatch(tpl, "([^|]+)") do
      found=0
      kvs=string.gmatch(str, "([-%w]+)=(.+)")
      for k,v in kvs do
        t[k]=v
        found=1 
      end
      if found == 0 then
        tplName=str
      end
    end
    if istarts_with(tplName, "cite ") then
      title=t['title']
      url=t['url']
      archiveUrl=t['archive-url']
      if t['archiveurl'] then
        archiveUrl = t['archiveurl']
      end
      
      if title==nil then
        title=t['publisher']
      end
      if title and url then
        if t['dead-url']=="yes" then
          return pandoc.Link(title, archiveUrl)
        end
        return pandoc.Link(title, url)
      end
      return pandoc.Str(el.text)
    end

    if special_page_exists("Template",tplName) and #t == 0 then
      local tplFile = io.open(wiki_path .. "/Template/" .. tplName .. ".md", 'rb')
      local content = tplFile:read "*a"
      tplFile:close()
      return pandoc.RawInline('mediawiki', content)
    end
  
  end
  return nil
end

function Blocks(el)
  if #el > 0 then
    btext=el[1].text
    if btext and istarts_with(btext, "{{cite book") then
      return pandoc.Str''
    end
  end
  return nil
end
