local insert = table.insert
local unpack = unpack or table.unpack

local path = string.gsub(..., "[^.]+$", "")
local Token = require(path.."Token")
local Statement = require(path.."Statement")
local Muncher = require(path.."Muncher")

local arg_types = { -- for instructions
    NUM = true,
    REG = true,
    DEFSYM = true,
    LABELSYM = true,
    RELLABELSYM = true,
}

local Collector = Muncher:extend()
function Collector:init(options)
    self.options = options or {}
end

function Collector:statement(...)
    local s = Statement(self.fn, self.line, ...)
    return s
end

function Collector:format_out(t, args)
    self:format_out_raw(t[3], t[1], args, t[4], t[5])
end

function Collector:push_data(data, size)
    -- FIXME: local 'data' name clashes with lips.data
    --[[ pseudo-example:
    Statement{type='!DATA',
        {tt='BYTES', tok={0, 1, 2}},
        {tt='HALFWORDS', tok={3, 4, 5}},
        {tt='WORDS', tok={6, 7, 8}},
        {tt='LABEL', tok='myLabel'},
    }
    --]]

    -- TODO: consider not scrunching data statements, just their tokens

    local last_statement = self.statements[#self.statements]
    local s
    if last_statement and last_statement.type == '!DATA' then
        s = last_statement
    else
        s = self:statement('!DATA')
        insert(self.statements, s)
    end

    if type(data) == 'string' and size == 'WORD' then
        -- labels will be assembled to words
        insert(s, Token('LABEL', data))
        return
    end

    if size ~= 'BYTE' and size ~= 'HALFWORD' and size ~= 'WORD' then
        error('Internal Error: unknown data size argument')
    end

    local sizes = size..'S'

    local last_token = s[#s]
    local t
    if last_token and last_token.tt == sizes then
        t = last_token
    else
        t = self:token(sizes, {})
        insert(s, t)
        s:validate()
    end
    insert(t.tok, data)
end

function Collector:variable()
    local t = self.t
    local t2 = self:advance()

    local s = self:statement('!DEF', t, t2)
    insert(self.statements, s)
    self:advance()
end

function Collector:directive()
    local name = self.tok
    self:advance()
    local function add(kind, ...)
        insert(self.statements, self:statement('!'..kind, ...))
    end
    if name == 'ORG' then
        add(name, self:const(false, true))
    elseif name == 'ALIGN' or name == 'SKIP' then
        if self:is_EOL() and name == 'ALIGN' then
            add(name, self:token('NUM', 0))
        else
            local size = self:number()
            if self:is_EOL() then
                add(name, size)
            else
                self:optional_comma()
                add(name, size, self:number())
            end
            self:expect_EOL()
        end
    elseif name == 'BYTE' or name == 'HALFWORD' or name == 'WORD' then
        self:push_data(self:const().tok, name)
        while not self:is_EOL() do
            self:advance()
            self:optional_comma()
            self:push_data(self:const().tok, name)
        end
        self:expect_EOL()
    elseif name == 'INC' or name == 'INCBIN' then
        -- noop, handled by lexer
    elseif name == 'ASCII' or name == 'ASCIIZ' then
        local bytes = self:string()
        for i, number in ipairs(bytes.tok) do
            self:push_data(number, 'BYTE')
        end
        if name == 'ASCIIZ' then
            self:push_data(0, 'BYTE')
        end
        self:expect_EOL()
    elseif name == 'FLOAT' then
        self:error('unimplemented directive', name)
    else
        self:error('unknown directive', name)
    end
end

function Collector:basic_special()
    local name, args = self:special()

    local portion
    if name == 'hi' then
        portion = 'upperoff'
    elseif name == 'up' then
        portion = 'upper'
    elseif name == 'lo' then
        portion = 'lower'
    else
        self:error('unknown special', name)
    end

    if #args ~= 1 then
        self:error(name..' expected one argument', #args)
    end

    local t = self:token(args[1]):set('portion', portion)
    return t
end

function Collector:instruction()
    local s = self:statement(self.tok)
    insert(self.statements, s)
    self:advance()

    while self.tt ~= 'EOL' do
        local t = self.t
        if self.tt == 'OPEN' then
            t = self:deref()
            t.tt = 'DEREF' -- TODO: should just be returned by :deref
            insert(s, t)
        elseif self.tt == 'UNARY' then
            local peek = self.tokens[self.i + 1]
            if peek.tt == 'DEFSYM' then
                t = self:advance()
                t = Token(t):set('negate')
                insert(s, t)
                self:advance()
            elseif peek.tt == 'EOL' or peek.tt == 'SEP' then
                local tok = t.tok == 1 and '+' or t.tok == -1 and '-'
                t = Token(self.fn, self.line, 'RELLABELSYM', tok)
                insert(s, t)
                self:advance()
            else
                self:error('unexpected token after unary operator', peek.tt)
            end
        elseif self.tt == 'SPECIAL' then
            t = self:basic_special()
            insert(s, t)
            self:advance()
        elseif self.tt == 'SEP' then
            self:error('extraneous comma')
        elseif not arg_types[self.tt] then
            self:error('unexpected argument type in instruction', self.tt)
        else
            insert(s, t)
            self:advance()
        end
        self:optional_comma()
    end

    self:expect_EOL()
    s:validate()
end

function Collector:collect(tokens, fn)
    self.tokens = tokens
    self.fn = fn or '(string)'
    self.main_fn = self.fn

    self.statements = {}

    self.i = 0 -- set up Muncher iteration
    self:advance() -- load up the first token
    while true do
        if self.tt == 'EOF' then
            -- don't break if this is an included file's EOF
            if self.fn == self.main_fn then
                break
            end
            self:advance()
        elseif self.tt == 'EOL' then
            -- empty line
            self:advance()
        elseif self.tt == 'DEF' then
            self:variable() -- handles advancing
        elseif self.tt == 'LABEL' or self.tt == 'RELLABEL' then
            insert(self.statements, self:statement('!LABEL', self.t))
            self:advance()
        elseif self.tt == 'DIR' then
            self:directive() -- handles advancing
        elseif self.tt == 'INSTR' then
            self:instruction() -- handles advancing
        else
            self:error('expected starting token for statement', self.tt)
        end
    end

    return self.statements
end

return Collector
