local WIKILANG = os.getenv("WIKILANG")
local wiki_prefix = "https://" .. WIKILANG .. ".wikipedia.org/wiki/"

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

local wiki_path = "../wikipedia." .. WIKILANG
if not file_exists( wiki_path .. "/README.md") then
  wiki_path = "~/chinapedia/wikipedia." .. WIKILANG
end

local function capitalize(t)
  if t then
      firstCh = t:sub(1,1)
      return firstCh:upper() .. t:sub(2)
  end 
  return t
end

local function category_exists(c)
  return false
end

local function special_page_exists(sp, p)
  if not p then
    return nil
  end
  p=capitalize(p):gsub(" ","_")
  path="/" .. sp .. "/" .. p .. ".md"
  if file_exists(wiki_path .. path) then
      return path
  end
  return nil
end

local function page_exists(p)
    return special_page_exists("Page", p)
end

function Link(el)
  if el.title ~= "wikilink" then
    return el
  end
  pagePath=page_exists(el.target)
  redPath=special_page_exists("Redirect", el.target)
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
        el.target = wiki_prefix .. "Category:" .. c
        return el
    end
    el.target = "../Category/" .. c
  elseif istarts_with(el.target, "MediaWiki:") then
    local c = string.sub(el.target, 1 + #"MediaWiki:")
    if not special_page_exists("MediaWiki", c) then
        el.target = wiki_prefix .. "MediaWiki:" .. c
        return el
    end
    el.target = "../MediaWiki/" .. c
  elseif istarts_with(el.target, "Wikipedia:") or istarts_with(el.target, "WP:") then
    el.target = wiki_prefix .. el.target
    return el
  elseif istarts_with(el.target, "Help:") then
    el.target = wiki_prefix .. el.target
    return el
  elseif pagePath then
    if not el.content then
      return nil
    end
    ctxt = el.content[1].text
    if ctxt and starts_with(ctxt, el.target) then
      if ctxt ~= el.target then
        suffix = ctxt:sub(1 + #el.target)
        el.content[1].text = el.target .. "$"
        el.target = ".." .. pagePath
        return {el, pandoc.Str(suffix)} 
      end
    end
    el.target = ".." .. pagePath
    return el
  elseif redPath then
    if not el.content then
      return nil
    end
    ctxt = el.content[1].text
    realpath=io.popen('readlink "' .. wiki_path .. redPath ..'"'):read()
    realpathcomp = {}
    realname=""
    for str in string.gmatch(realpath, "([^/]+)") do
      table.insert(realpathcomp, str)
      realname=str
    end
    if #realpathcomp < 2 or #realname==0 then
      el.target = "../Redirect/" .. el.target .. ".md"
      if #el.content == 1 then
        el.content[1].text = el.content[1].text .. "Ⓡ"
      end
      return el
    elseif ctxt and starts_with(ctxt, el.target) and ctxt ~= el.target then
      suffix = ctxt:sub(1 + #el.target)
      el.content[1].text = el.target
      el.target = "../Page/" .. capitalize(realname)
      return {el, pandoc.Str(suffix)}
    else
      el.target = "../Page/" .. capitalize(realname)
      return el
    end
  else
    if not el.content or #el.content == 0 then
      return nil
    end
    ctxt = el.content[1].text
    if not ctxt then
      return nil
    end
    if ctxt and starts_with(ctxt, el.target) then
      if ctxt ~= el.target then
        suffix = ctxt:sub(1 + #el.target)
        if #el.content == 1 then
          el.content[1].text = el.target .. "ⓦ"
        end
        el.target = wiki_prefix .. el.target 
        return {el, pandoc.Str(suffix)} 
      end
    end
    if #el.content == 1 then
      el.content[1].text = ctxt .. "ⓦ"
    end
    el.target = wiki_prefix .. el.target
    return el
  end
  el.target = el.target .. ".md"
  return el
end

function Image(el)
  return pandoc.Link(el.caption, wiki_prefix .. "File:" .. el.src, el.title)
end

function RawBlock(el)
  if starts_with(el.text, '{{') then
    tpl=all_trim(el.text:sub(3, #el.text - 2))
    local t={}
    tplNames={}
    for str in string.gmatch(tpl, "([^|]+)") do
      found=0
      kvs=string.gmatch(str, "(%s*[-%w]+%s*)=(.*)")
      for k,v in kvs do
        if k and v then
          t[all_trim(k)]=all_trim(v)
          found=1
        end
      end
      if found == 0 then
        table.insert(tplNames, str)
      end
    end
    if #tplNames == 0 then
      return nil
    end

    tplName = tplNames[1]
    if istarts_with(tplName, "cite ") then -- cite web/book/...
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
        if t['dead-url']=="yes" and archiveUrl then
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

function RawInline(el)
  if not starts_with(el.text, '{{') then
    return nil
  end
  tpl=all_trim(el.text:sub(3, #el.text - 2))
  tplNames={}
  for str in string.gmatch(tpl, "([^|]*)") do
    if not istarts_with(str,"catIdx") then
      table.insert(tplNames, str)
    end
  end
  if #tplNames == 0 then
    return nil
  end

  if istarts_with(tplNames[1],"lang-") and #tplNames[1] >= 7 then
    if #tplNames==1 then
      return nil
    end
    lang=tplNames[1]:sub(6)
    if lang:lower() == "en" then
      return pandoc.Str("English：" .. tplNames[2])
    end
    return pandoc.Str(lang .. ":" .. tplNames[2])
  end

  if tplNames[1]:lower() == "lang" then
    if #tplNames>2 then
      return pandoc.Str(tplNames[3])
    end
    return nil
  end
  if tplNames[1]:lower() == "bd" then
    if #tplNames>1 then
      bd=tplNames[2]
      if #tplNames>2 then
        bd=bd..tplNames[3]
        
        if #tplNames>3 then
          to=tplNames[4]
          if #tplNames>4 then
            to=to..tplNames[5]
          end
          bd=bd.."－" .. to
        end
      end
      return bd
    end
  end
end
