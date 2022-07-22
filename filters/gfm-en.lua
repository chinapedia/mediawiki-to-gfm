local wiki_prefix = "https://en.wikipedia.org/wiki/"

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

local wiki_path = "../wikipedia.en"
if not file_exists( wiki_path .. "/README.md") then
  wiki_path = "/mnt/chinapedia/wikipedia.en"
end

local function category_exists(c)
  return false
end

local function page(t)
    firstCh = t:sub(1,1)
    if firstCh:match("%u") then
        return "Page." .. firstCh:upper()
    end
    return "Page"
end

local function page_exists(p)
    return file_exists(wiki_path .. "/" .. page(p) .. "/" .. p .. ".md")
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
        el.target = "https://en.wikipedia.org/wiki/Category:" .. c
        return el
    end
    el.target = "../Category/" .. c
  elseif istarts_with(el.target, "Wikipedia:") or istarts_with(el.target, "WP:") then
    el.target = "https://en.wikipedia.org/wiki/" .. el.target
    return el
  elseif istarts_with(el.target, "Help:") then
    el.target = "https://en.wikipedia.org/wiki/" .. el.target
    return el
  elseif not page_exists(el.target) then
    el.target = wiki_prefix .. el.target
    return el
  else
    el.target = "../" .. page(el.target) .. "/" .. el.target
  end
  el.target = el.target .. ".md"
  
  return el
end

function Image(el)
  return pandoc.Link(el.caption, "https://en.wikipedia.org/wiki/File:" .. el.src, el.title)
end

function RawBlock(el)
  if starts_with(el.text, '{{') then
    tpl=el.text:sub(3, #el.text - 2)
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
      if t['archive-url'] then
        if nil==t['url'] then
          t['url'] = t['archive-url']
        end
      end
      return pandoc.Link(t['title'], t['url'])
    end
  end
  return nil
end