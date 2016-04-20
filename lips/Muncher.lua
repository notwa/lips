local format = string.format
local insert = table.insert

local path = string.gsub(..., "[^.]+$", "")
local data = require(path.."data")
local Base = require(path.."Base")
local Token = require(path.."Token")

local arg_types = {
    NUM = true,
    REG = true,
    DEFSYM = true,
    LABELSYM = true,
    RELLABELSYM = true,
}

local Muncher = Base:extend()
-- no base init method

function Muncher:error(msg, got)
    if got ~= nil then
        msg = msg..', got '..tostring(got)
    end
    error(format('%s:%d: Error: %s', self.fn, self.line, msg), 2)
end

function Muncher:token(t, val)
    -- note: call Token directly if you want to specify fn and line manually
    if type(t) == 'table' then
        t.fn = self.fn
        t.line = self.line
        local token = Token(t)
        return token
    else
        local token = Token(self.fn, self.line, t, val)
        return token
    end
end

function Muncher:advance()
    self.i = self.i + 1
    self.t = self.tokens[self.i]
    self.tt = self.t.tt
    self.tok = self.t.tok
    self.fn = self.t.fn
    self.line = self.t.line
    return self.t
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
    local t = self.t
    self:advance()
    return self:token(t)
end

function Muncher:string()
    if self.tt ~= 'STRING' then
        self:error('expected string')
    end
    local t = self.t
    self:advance()
    return self:token(t)
end

function Muncher:register(registers)
    registers = registers or data.registers
    if self.tt ~= 'REG' then
        self:error('expected register')
    end
    local t = self.t
    if not registers[t.tok] then
        self:error('wrong type of register')
    end
    self:advance()
    return self:token(t)
end

function Muncher:deref()
    if self.tt ~= 'OPEN' then
        self:error('expected opening parenthesis for dereferencing')
    end
    self:advance()
    if self.tt ~= 'REG' then
        self:error('expected register to dereference')
    end
    local t = self.t
    self:advance()
    if self.tt ~= 'CLOSE' then
        self:error('expected closing parenthesis for dereferencing')
    end
    self:advance()
    return self:token(t)
end

function Muncher:const(relative, no_label)
    if self.tt ~= 'NUM' and self.tt ~= 'DEFSYM' and self.tt ~= 'LABELSYM' then
        self:error('expected constant', self.tt)
    end
    if no_label and self.tt == 'LABELSYM' then
        self:error('labels are not allowed here')
    end
    local t = self:token(self.t)
    if relative then
        if self.tt == 'LABELSYM' then
            t.tt = 'LABELREL'
        else
            t.tt = 'REL'
        end
    end
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
            break
        else
            self:error('unexpected token in argument list')
        end
    end

    return name, args
end

return Muncher
