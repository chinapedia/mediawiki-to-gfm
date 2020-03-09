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
    return file_exists("/root/wikipedia.en/Category/" .. c .. ".md")
end

function Image(el)
  return pandoc.Null()
end
