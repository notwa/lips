local floor = math.floor
local open = io.open

local function readfile(fn, binary)
    local mode = binary and 'rb' or 'r'
    local f = open(fn, mode)
    if not f then
        local kind = binary and 'binary' or 'assembly'
        error('could not open '..kind..' file for reading: '..tostring(fn), 2)
    end
    local data = f:read('*a')
    f:close()
    return data
end

local function bitrange(x, lower, upper)
    return floor(x/2^lower) % 2^(upper - lower + 1)
end

local function parent(t)
    local mt = getmetatable(t)
    if mt == nil then
        return nil
    end
    return mt.__index
end

-- http://stackoverflow.com/a/9279009
local loadcode
if setfenv and loadstring then -- 5.1, JIT
    loadcode = function(code, environment)
        local f = assert(loadstring(code))
        setfenv(f, environment)
        return f
    end
else -- 5.2, 5.3
    loadcode = function(code, environment)
        return assert(load(code, nil, 't', environment))
    end
end

return {
    readfile = readfile,
    bitrange = bitrange,
    parent = parent,
    loadcode = loadcode,
}
