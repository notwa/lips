local floor = math.floor
local open = io.open

local function Class(inherit)
    local class = {}
    local mt_obj = {__index = class}
    local mt_class = {
        __call = function(self, ...)
            local obj = setmetatable({}, mt_obj)
            obj:init(...)
            return obj
        end,
        __index = inherit,
    }

    return setmetatable(class, mt_class)
end

local function construct(t)
    if type(t) == 'table' then
        return t
    elseif type(t) == 'string' then
        return {'REG', t}
    elseif type(t) == 'number' then
        return {'NUM', t}
    else
        error('Internal Error: unknown type to construct')
    end
end

local function withflag(t, key, value)
    if type(t) == 'table' then
        t = {t[1], t[2]}
    else
        t = construct(t)
    end
    if value == nil then
        value = true
    end
    if key ~= nil then
        t[key] = value
    end
    return t
end

local function readfile(fn)
    local f = open(fn, 'r')
    if not f then
        error('could not open assembly file for reading: '..tostring(fn), 2)
    end
    local asm = f:read('*a')
    f:close()
    return asm
end

local function bitrange(x, lower, upper)
    return floor(x/2^lower) % 2^(upper - lower + 1)
end

return {
    Class = Class,
    construct = construct,
    withflag = withflag,
    readfile = readfile,
    bitrange = bitrange,
}
