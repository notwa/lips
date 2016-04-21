local insert = table.insert

local path = string.gsub(..., "[^.]+$", "")
local data = require(path.."data")
local overrides = require(path.."overrides")
local Base = require(path.."Base")
local Token = require(path.."Token")
local Lexer = require(path.."Lexer")
local Collector = require(path.."Collector")
local Preproc = require(path.."Preproc")
local Dumper = require(path.."Dumper")

local Parser = Base:extend()
function Parser:init(writer, fn, options)
    self.fn = fn or '(string)'
    self.main_fn = self.fn
    self.options = options or {}
    self.dumper = Dumper(writer, fn, options)
end

--[[

function Parser:format_in(informat)
    -- see data.lua for a guide on what all these mean
    local args = {}
    for i=1,#informat do
        local c = informat:sub(i, i)
        local c2 = informat:sub(i + 1, i + 1)
        if c == 'd' and not args.rd then
            args.rd = self:register()
        elseif c == 's' and not args.rs then
            args.rs = self:register()
        elseif c == 't' and not args.rt then
            args.rt = self:register()
        elseif c == 'D' and not args.fd then
            args.fd = self:register(data.fpu_registers)
        elseif c == 'S' and not args.fs then
            args.fs = self:register(data.fpu_registers)
        elseif c == 'T' and not args.ft then
            args.ft = self:register(data.fpu_registers)
        elseif c == 'X' and not args.rd then
            args.rd = self:register(data.sys_registers)
        elseif c == 'Y' and not args.rs then
            args.rs = self:register(data.sys_registers)
        elseif c == 'Z' and not args.rt then
            args.rt = self:register(data.sys_registers)
        elseif c == 'o' and not args.offset then
            args.offset = Token(self:const()):set('signed')
        elseif c == 'r' and not args.offset then
            args.offset = Token(self:const('relative')):set('signed')
        elseif c == 'i' and not args.immediate then
            args.immediate = self:const(nil, 'no label')
        elseif c == 'I' and not args.index then
            args.index = Token(self:const()):set('index')
        elseif c == 'k' and not args.immediate then
            args.immediate = Token(self:const(nil, 'no label')):set('negate')
        elseif c == 'K' and not args.immediate then
            args.immediate = Token(self:const(nil, 'no label')):set('signed')
        elseif c == 'b' and not args.base then
            args.base = self:deref()
        else
            error('Internal Error: invalid input formatting string')
        end
        if c2:find('[dstDSTorIikKXYZ]') then
            self:optional_comma()
        end
    end
    return args
end

function Parser:format_out_raw(outformat, first, args, const, formatconst)
    -- see data.lua for a guide on what all these mean
    local lookup = {
        [1]=self.dumper.add_instruction_j,
        [3]=self.dumper.add_instruction_i,
        [5]=self.dumper.add_instruction_r,
    }
    local out = {}
    for i=1,#outformat do
        local c = outformat:sub(i, i)
        if c == 'd' then
            out[#out+1] = self:token(args.rd)
        elseif c == 's' then
            out[#out+1] = self:token(args.rs)
        elseif c == 't' then
            out[#out+1] = self:token(args.rt)
        elseif c == 'D' then
            out[#out+1] = self:token(args.fd)
        elseif c == 'S' then
            out[#out+1] = self:token(args.fs)
        elseif c == 'T' then
            out[#out+1] = self:token(args.ft)
        elseif c == 'o' then
            out[#out+1] = self:token(args.offset)
        elseif c == 'i' then
            out[#out+1] = self:token(args.immediate)
        elseif c == 'I' then
            out[#out+1] = self:token(args.index)
        elseif c == 'b' then
            out[#out+1] = self:token(args.base)
        elseif c == '0' then
            out[#out+1] = self:token(0)
        elseif c == 'C' then
            out[#out+1] = self:token(const)
        elseif c == 'F' then
            out[#out+1] = self:token(formatconst)
        end
    end
    local f = lookup[#outformat]
    assert(f, 'Internal Error: invalid output formatting string')
    f(self.dumper, self.fn, self.line, first, out[1], out[2], out[3], out[4], out[5])
end

function Parser:format_out(t, args)
    self:format_out_raw(t[3], t[1], args, t[4], t[5])
end

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
    local statements = collector:collect(tokens, self.main_fn)

    local preproc = Preproc(self.options)
    self.statements = preproc:process(statements)
end

function Parser:parse(asm)
    self:tokenize(asm)

    --[[ process:
- inline constants
- inline variables
- inline labels? how do you know how far they are?
                 i guess you can just offset on labels instead
- assemble? dumper gets passed .org .base
--]]

    -- DEBUG
    for i, s in ipairs(self.statements) do
        local values = ''
        for j, v in ipairs(s) do
            values = values..'\t'..v.tt..'('..v.tok..')'
        end
        values = values:sub(2)
        print(i, s.type, values)
    end
    --[[
    if self.options.labels then
        self.dumper:export_labels(self.options.labels)
    end
    return self.dumper:dump()
    --]]
end

return Parser
