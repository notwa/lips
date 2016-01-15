local format = string.format
local insert = table.insert

local data = require "lips.data"
local util = require "lips.util"

local arg_types = {
    NUM = true,
    REG = true,
    DEFSYM = true,
    LABELSYM = true,
    RELLABELSYM = true,
}

local Muncher = util.Class()
-- no base init method

function Muncher:error(msg)
    error(format('%s:%d: Error: %s', self.fn, self.line, msg), 2)
end

function Muncher:advance()
    self.i = self.i + 1
    local t = self.tokens[self.i]
    self.tt = t.tt
    self.tok = t.tok
    self.fn = t.fn
    self.line = t.line
    return t
end

function Muncher:is_EOL()
    return self.tt == 'EOL' or self.tt == 'EOF'
end

function Muncher:expect_EOL()
    if self:is_EOL() then
        self:advance()
        return
    end
    self:error('expected end of line')
end

function Muncher:optional_comma()
    if self.tt == 'SEP' and self.tok == ',' then
        self:advance()
        return true
    end
end

function Muncher:number()
    if self.tt ~= 'NUM' then
        self:error('expected number')
    end
    local value = self.tok
    self:advance()
    return value
end

function Muncher:string()
    if self.tt ~= 'STRING' then
        self:error('expected string')
    end
    local value = self.tok
    self:advance()
    return value
end

function Muncher:register(t)
    t = t or data.registers
    if self.tt ~= 'REG' then
        self:error('expected register')
    end
    local reg = self.tok
    if not t[reg] then
        self:error('wrong type of register')
    end
    self:advance()
    return reg
end

function Muncher:deref()
    if self.tt ~= 'OPEN' then
        self:error('expected opening parenthesis for dereferencing')
    end
    self:advance()
    if self.tt ~= 'REG' then
        self:error('expected register to dereference')
    end
    local reg = self.tok
    self:advance()
    if self.tt ~= 'CLOSE' then
        self:error('expected closing parenthesis for dereferencing')
    end
    self:advance()
    return reg
end

function Muncher:const(relative, no_label)
    if self.tt ~= 'NUM' and self.tt ~= 'LABELSYM' then
        self:error('expected constant')
    end
    if no_label and self.tt == 'LABELSYM' then
        self:error('labels are not allowed here')
    end
    if relative and self.tt == 'LABELSYM' then
        self.tt = 'LABELREL'
    end
    local t = {self.tt, self.tok}
    self:advance()
    return t
end

function Muncher:special()
    if self.tt ~= 'SPECIAL' then
        self:error('expected special name to call')
    end
    local name = self.tok
    self:advance()
    if self.tt ~= 'OPEN' then
        self:error('expected opening parenthesis for special call')
    end

    local args = {}
    while true do
        local arg = self:advance()
        if not arg_types[arg.tt] then
            self:error('invalid argument type')
        else
            self:advance()
        end
        if self.tt == 'SEP' then
            insert(args, arg)
        elseif self.tt == 'CLOSE' then
            insert(args, arg)
            self:advance()
            break
        else
            self:error('unexpected token in argument list')
        end
    end

    return name, args
end

return Muncher
