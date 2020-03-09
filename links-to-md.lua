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

local function category_exists(c)
    return file_exists("/mnt/c/Apps/data/zh-wikipedia.gfm/Category/" .. c .. ".md")
end

function Link(el)
  if el.title ~= "wikilink" then
    return el
  end
  
  if istarts_with(el.target, "Category:") then
    local c = string.sub(el.target, 1 + #"Category:")
    if not category_exists(c) then
        el.target = "https://zh.wikipedia.org/wiki/" .. el.target
        return pandoc.Link("Category:" .. c, "https://zh.wikipedia.org/wiki/Category:" .. c, el.title)
    end
    el.target = "../Category/" .. c
  elseif istarts_with(el.target, ":Category:") then
    local c = string.sub(el.target, 1 + #":Category:")
    if not category_exists(c) then
        el.target = "https://zh.wikipedia.org/wiki/Category:" .. c
        return el
    end
    el.target = "../Category/" .. c
  elseif istarts_with(el.target, "Wikipedia:") then
    el.target = "https://zh.wikipedia.org/wiki/" .. el.target
    return el
  elseif istarts_with(el.target, "Help:") then
    el.target = "https://zh.wikipedia.org/wiki/" .. el.target
    return el
  else
    el.target = "../Page/" .. el.target
  end
  el.target = el.target .. ".md"
  
  return el
end

function Image(el)
  return pandoc.Link(el.caption, "https://zh.wikipedia.org/wiki/File:" .. el.src, el.title)
end