local insert = table.insert

local path = string.gsub(..., "[^.]+$", "")
local data = require(path.."data")
local Base = require(path.."Base")
local Token = require(path.."Token")
local Lexer = require(path.."Lexer")
local Collector = require(path.."Collector")
local Preproc = require(path.."Preproc")
local Dumper = require(path.."Dumper")

local Parser = Base:extend()
function Parser:init(writer, fn, options)
    self.writer = writer
    self.fn = fn or '(string)'
    self.main_fn = self.fn
    self.options = options or {}
end

--[[
function Parser:instruction()
    local name = self.tok
    local h = data.instructions[name]
    assert(h, 'Internal Error: undefined instruction')
    self:advance()

    if overrides[name] then
        overrides[name](self, name)
    elseif h[2] == 'tob' then -- TODO: or h[2] == 'Tob' then
        -- handle all the addressing modes for lw/sw-like instructions
        local lui = data.instructions['LUI']
        local addu = data.instructions['ADDU']
        local args = {}
        args.rt = self:register()
        self:optional_comma()
        if self.tt == 'OPEN' then
            args.offset = 0
            args.base = self:deref()
        else -- NUM or LABELSYM
            local lui_args = {}
            local addu_args = {}
            local o = self:const()
            if self.tt == 'NUM' then
                o:set('offset', self:const().tok)
            end
            args.offset = self:token(o)
            if not o.portion then
                args.offset:set('portion', 'lower')
            end
            -- attempt to use the fewest possible instructions for this offset
            if not o.portion and (o.tt == 'LABELSYM' or o.tok >= 0x80000000) then
                lui_args.immediate = Token(o):set('portion', 'upperoff')
                lui_args.rt = 'AT'
                self:format_out(lui, lui_args)
                if not self:is_EOL() then
                    addu_args.rd = 'AT'
                    addu_args.rs = 'AT'
                    addu_args.rt = self:deref()
                    self:format_out(addu, addu_args)
                end
                args.base = 'AT'
            else
                args.base = self:deref()
            end
        end
        self:format_out(h, args)
    elseif h[2] ~= nil then
        local args = self:format_in(h[2])
        self:format_out(h, args)
    else
        self:error('unimplemented instruction')
    end
    self:expect_EOL()
end
--]]

function Parser:tokenize(asm)
    local lexer = Lexer(asm, self.main_fn, self.options)
    local tokens = {}

    local loop = true
    while loop do
        lexer:lex(function(tt, tok, fn, line)
            assert(tt, 'Internal Error: missing token')
            local t = Token(fn, line, tt, tok)
            insert(tokens, t)
            -- don't break if this is an included file's EOF
            if tt == 'EOF' and fn == self.main_fn then
                loop = false
            end
        end)
    end

    -- the lexer guarantees an EOL and EOF for a blank file
    assert(#tokens > 0, 'Internal Error: no tokens after preprocessing')

    local collector = Collector(self.options)
    self.statements = collector:collect(tokens, self.main_fn)
end

function Parser:parse(asm)
    self:tokenize(asm)

    local preproc = Preproc(self.options)
    self.statements = preproc:process(self.statements)
    self.statements = preproc:expand(self.statements)

    -- DEBUG
    for i, s in ipairs(self.statements) do
        local values = ''
        for j, v in ipairs(s) do
            values = values..'\t'..v.tt..'('..tostring(v.tok)..')'
        end
        values = values:sub(2)
        print(i, s.type, values)
    end

    local dumper = Dumper(self.writer, self.options)
    self.statements = dumper:load(self.statements)

    --if self.options.labels then
    --    dumper:export_labels(self.options.labels)
    --end
    return dumper:dump()
end

return Parser
