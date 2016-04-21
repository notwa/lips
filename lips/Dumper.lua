local floor = math.floor
local format = string.format
local insert = table.insert
local unpack = unpack or table.unpack

local path = string.gsub(..., "[^.]+$", "")
local data = require(path.."data")
local util = require(path.."util")
--local overrides = require(path.."overrides")
local Base = require(path.."Base")
local Token = require(path.."Token")
local Statement = require(path.."Statement")
local Reader = require(path.."Reader")

local bitrange = util.bitrange

local Dumper = Reader:extend()
function Dumper:init(writer, options)
    self.writer = writer
    self.options = options or {}
    self.labels = setmetatable({}, {__index=options.labels})
    self.commands = {}
    self.pos = options.offset or 0
    self.lastcommand = nil
end

function Dumper:export_labels(t)
    for k, v in pairs(self.labels) do
        -- only return valid labels; those that don't begin with a number
        -- (relative labels are invalid)
        if not tostring(k):sub(1, 1):find('%d') then
            t[k] = v
        end
    end
    return t
end

function Dumper:desym(t)
    if t.tt == 'REL' then
        local target = t.tok % 0x80000000
        local pos = self.pos % 0x80000000
        local rel = floor(target/4) - 1 - floor(pos/4)
        if rel > 0x8000 or rel <= -0x8000 then
            self:error('branch too far')
        end
        return rel % 0x10000
    elseif type(t.tok) == 'number' then
        if t.offset then
            return t.tok + t.offset
        end
        return t.tok
    elseif t.tt == 'REG' then
        assert(data.all_registers[t.tok], 'Internal Error: unknown register')
        return data.registers[t.tok] or data.fpu_registers[t.tok] or data.sys_registers[t.tok]
    elseif t.tt == 'LABELSYM' or t.tt == 'LABELREL' then
        local label = self.labels[t.tok]
        if label == nil then
            self:error('undefined label', t.tok)
        end
        if t.offset then
            label = label + t.offset
        end
        if t.tt == 'LABELSYM' then
            return label
        end

        label = label % 0x80000000
        local pos = self.pos % 0x80000000
        local rel = floor(label/4) - 1 - floor(pos/4)
        if rel > 0x8000 or rel <= -0x8000 then
            self:error('branch too far')
        end
        return rel % 0x10000
    end
    error('Internal Error: failed to desym')
end

function Dumper:toval(t)
    if type(t) == 'number' then
        return t
    end

    assert(type(t) == 'table', 'Internal Error: invalid value')

    local val = self:desym(t)

    if t.index then
        val = val % 0x80000000
        val = floor(val/4)
    end
    if t.negate then
        val = -val
    end

    if t.portion == 'upper' then
        val = bitrange(val, 16, 31)
    elseif t.portion == 'lower' then
        val = bitrange(val, 0, 15)
    elseif t.portion == 'upperoff' then
        local upper = bitrange(val, 16, 31)
        local lower = bitrange(val, 0, 15)
        if lower >= 0x8000 then
            -- accommodate for offsets being signed
            upper = (upper + 1) % 0x10000
        end
        val = upper
    end

    if t.negate or t.signed then
        if val >= 0x10000 or val < -0x8000 then
            self:error('value out of range', val)
        end
        val = val % 0x10000
    end

    return val
end

function Dumper:validate(n, bits)
    local max = 2^bits
    if n == nil then
        self:error('value is nil') -- internal error?
    end
    if n > max or n < 0 then
        self:error('value out of range', n)
    end
    return n
end

function Dumper:valvar(t, bits)
    local val = self:toval(t)
    return self:validate(val, bits)
end

function Dumper:write(t)
    for _, b in ipairs(t) do
        self.writer(self.pos, b)
        self.pos = self.pos + 1
    end
end

function Dumper:dump_instruction(t)
    local uw = 0
    local lw = 0

    local o = t[1]
    uw = uw + o*0x400

    if #t == 2 then
        local val = self:valvar(t[2], 26)
        uw = uw + bitrange(val, 16, 25)
        lw = lw + bitrange(val, 0, 15)
    elseif #t == 4 then
        uw = uw + self:valvar(t[2], 5)*0x20
        uw = uw + self:valvar(t[3], 5)
        lw = lw + self:valvar(t[4], 16)
    elseif #t == 6 then
        uw = uw + self:valvar(t[2], 5)*0x20
        uw = uw + self:valvar(t[3], 5)
        lw = lw + self:valvar(t[4], 5)*0x800
        lw = lw + self:valvar(t[5], 5)*0x40
        lw = lw + self:valvar(t[6], 6)
    else
        error('Internal Error: unknown n-size')
    end

    return uw, lw
end

function Dumper:assemble_j(first, out)
    local w = 0
    w = w + self:valvar(first,   6) * 0x04000000
    w = w + self:valvar(out[1], 26) * 0x00000001
    local t = Token(self.fn, self.line, 'WORDS', {w})
    local s = Statement(self.fn, self.line, '!DATA', t)
    return s
end
function Dumper:assemble_i(first, out)
    local w = 0
    w = w + self:valvar(first,   6) * 0x04000000
    w = w + self:valvar(out[1],  5) * 0x00200000
    w = w + self:valvar(out[2],  5) * 0x00010000
    w = w + self:valvar(out[3], 16) * 0x00000001
    local t = Token(self.fn, self.line, 'WORDS', {w})
    local s = Statement(self.fn, self.line, '!DATA', t)
    return s
end
function Dumper:assemble_r(first, out)
    local w = 0
    w = w + self:valvar(first,   6) * 0x04000000
    w = w + self:valvar(out[1],  5) * 0x00200000
    w = w + self:valvar(out[2],  5) * 0x00010000
    w = w + self:valvar(out[3],  5) * 0x00000800
    w = w + self:valvar(out[4],  5) * 0x00000040
    w = w + self:valvar(out[5],  6) * 0x00000001
    local t = Token(self.fn, self.line, 'WORDS', {w})
    local s = Statement(self.fn, self.line, '!DATA', t)
    return s
end

function Dumper:format_in(informat)
    -- see data.lua for a guide on what all these mean
    local args = {}
    --if #informat ~= #s then error('mismatch') end
    for i=1, #informat do
        self.i = i
        local c = informat:sub(i, i)
        if c == 'd' and not args.rd then
            args.rd = self:register(data.registers)
        elseif c == 's' and not args.rs then
            args.rs = self:register(data.registers)
        elseif c == 't' and not args.rt then
            args.rt = self:register(data.registers)
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
            args.offset = self:const():set('signed')
        elseif c == 'r' and not args.offset then
            args.offset = self:const('relative'):set('signed')
        elseif c == 'i' and not args.immediate then
            args.immediate = self:const(nil, 'no label')
        elseif c == 'I' and not args.index then
            args.index = self:const():set('index')
        elseif c == 'k' and not args.immediate then
            args.immediate = self:const(nil, 'no label'):set('negate')
        elseif c == 'K' and not args.immediate then
            args.immediate = self:const(nil, 'no label'):set('signed')
        elseif c == 'b' and not args.base then
            args.base = self:deref():set('tt', 'REG')
        else
            error('Internal Error: invalid input formatting string')
        end
    end
    return args
end

function Dumper:format_out_raw(outformat, first, args, const, formatconst)
    -- see data.lua for a guide on what all these mean
    local lookup = {
        [1]=self.assemble_j,
        [3]=self.assemble_i,
        [5]=self.assemble_r,
    }
    local out = {}
    for i=1, #outformat do
        local c = outformat:sub(i, i)
        if c == 'd' then out[#out+1] = args.rd
        elseif c == 's' then insert(out, args.rs)
        elseif c == 't' then insert(out, args.rt)
        elseif c == 'D' then insert(out, args.fd)
        elseif c == 'S' then insert(out, args.fs)
        elseif c == 'T' then insert(out, args.ft)
        elseif c == 'o' then insert(out, args.offset)
        elseif c == 'i' then insert(out, args.immediate)
        elseif c == 'I' then insert(out, args.index)
        elseif c == 'b' then insert(out, args.base)
        elseif c == '0' then insert(out, 0)
        elseif c == 'C' then insert(out, const)
        elseif c == 'F' then insert(out, formatconst)
        end
    end
    local f = lookup[#outformat]
    assert(f, 'Internal Error: invalid output formatting string')
    return f(self, first, out)
end

function Dumper:format_out(t, args)
    return self:format_out_raw(t[3], t[1], args, t[4], t[5])
end

function Dumper:assemble(s)
    local name = s.type
    local h = data.instructions[name]
    self.s = s
    if h[2] ~= nil then
        local args = self:format_in(h[2])
        return self:format_out(h, args)
    else
        self:error('unimplemented instruction', name)
    end
end

local assembled_directives = {
    ['!DATA'] = true,
    ['!ORG'] = true,
}

function Dumper:fill(length, content)
    self:validate(content, 8)
    local bytes = {}
    for i=1, length do
        insert(bytes, content)
    end
    local t = Token(self.fn, self.line, 'BYTES', bytes)
    local s = Statement(self.fn, self.line, '!DATA', t)
    return s
end

function Dumper:load(statements)
    local pos = self.options.offset or 0
    local new_statements = {}
    for i=1, #statements do
        local s = statements[i]
        self.fn = s.fn
        self.line = s.line
        if s.type:sub(1, 1) == '!' then
            if s.type == '!LABEL' then
                self.labels[s[1].tok] = pos
            elseif s.type == '!DATA' then
                s.length = util.measure_data(s) -- cache for next pass
                pos = pos + s.length
                insert(new_statements, s)
            elseif s.type == '!ORG' then
                pos = s[1].tok
                insert(new_statements, s)
            elseif s.type == '!ALIGN' or s.type == '!SKIP' then
                local length, content
                if s.type == '!ALIGN' then
                    local align = s[1] and s[1].tok or 2
                    content = s[2] and s[2].tok or 0
                    if align < 0 then
                        self:error('negative alignment')
                    else
                        align = 2^align
                    end
                    local temp = pos + align - 1
                    length = temp - (temp % align) - pos
                else
                    length = s[1] and s[1].tok or 0
                    content = s[2] and s[2].tok or nil
                end

                pos = pos + length
                if content == nil then
                    local new = Statement(self.fn, self.line, '!ORG', pos)
                    insert(new_statements, new)
                elseif length > 0 then
                    insert(new_statements, self:fill(length, content))
                elseif length < 0 then
                    local new = Statement(self.fn, self.line, '!ORG', pos)
                    insert(new_statements, new)
                    insert(new_statements, self:fill(length, content))
                    local new = Statement(self.fn, self.line, '!ORG', pos)
                    insert(new_statements, new)
                else
                    -- length is 0, noop
                end
            else
                error('Internal Error: unknown statement, got '..s.type)
            end
        else
            pos = pos + 4
            insert(new_statements, s)
        end
    end

    statements = new_statements
    new_statements = {}
    self.pos = self.options.offset or 0
    for i=1, #statements do
        local s = statements[i]
        self.fn = s.fn
        self.line = s.line
        if s.type:sub(1, 1) ~= '!' then
            local new = self:assemble(s)
            self.pos = self.pos + 4
            insert(new_statements, new)
        elseif s.type == '!DATA' then
            for i, t in ipairs(s) do
                if t.tt == 'LABEL' then
                    local label = self.labels[t.tok]
                    if label == nil then
                        self:error('undefined label', t.tok)
                    end
                    t.tt = 'WORDS'
                    t.tok = {label}
                end
            end
            self.pos = self.pos + s.length
            insert(new_statements, s)
        elseif s.type == '!ORG' then
            self.pos = s[1].tok
            insert(new_statements, s)
        elseif s.type == '!LABEL' then
            -- noop
        else
            error('Internal Error: unknown statement, got '..s.type)
        end
    end

    self.statements = new_statements
    return self.statements
end

function Dumper:dump()
    -- TODO: have options insert .org and/or .base; pos is always 0 at start
    self.pos = self.options.offset or 0
    for i, s in ipairs(self.statements) do
        assert(assembled_directives[s.type], 'Internal Error: unassembled statement')
        if s.type == '!DATA' then
            for j, t in ipairs(s) do
                if t.tt == 'WORDS' then
                    for _, w in ipairs(t.tok) do
                        local b0 = bitrange(w, 0, 7)
                        local b1 = bitrange(w, 8, 15)
                        local b2 = bitrange(w, 16, 23)
                        local b3 = bitrange(w, 24, 31)
                        self:write{b3, b2, b1, b0}
                    end
                elseif t.tt == 'HALFWORDS' then
                    for _, h in ipairs(t.tok) do
                        local b0 = bitrange(h, 0, 7)
                        local b1 = bitrange(h, 8, 15)
                        self:write{b1, b0}
                    end
                elseif t.tt == 'BYTES' then
                    for _, b in ipairs(t.tok) do
                        local b0 = bitrange(b, 0, 7)
                        self:write{b0}
                    end
                else
                    error('Internal Error: unknown !DATA token')
                end
            end
        elseif s.type == '!ORG' then
            self.pos = s[1].tok
        end
    end
end

return Dumper
