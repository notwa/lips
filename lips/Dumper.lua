local floor = math.floor
local format = string.format
local insert = table.insert
local unpack = unpack or table.unpack

local path = string.gsub(..., "[^.]+$", "")
local data = require(path.."data")
local util = require(path.."util")
local overrides = require(path.."overrides")
local Base = require(path.."Base")
local Token = require(path.."Token")
local Statement = require(path.."Statement")

local bitrange = util.bitrange

local Dumper = Base:extend()
function Dumper:init(writer, options)
    self.writer = writer
    self.options = options or {}
    self.labels = setmetatable({}, {__index=options.labels})
    self.commands = {}
    self.pos = options.offset or 0
    self.lastcommand = nil
end

function Dumper:error(msg, got)
    if got ~= nil then
        msg = msg..', got '..tostring(got)
    end
    error(('%s:%d: Error: %s'):format(self.fn, self.line, msg), 2)
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

function Dumper:advance(by)
    self.pos = self.pos + by
end

--[[
function Dumper:add_directive(fn, line, name, a, b)
    self.fn = fn
    self.line = line
    local t = {}
    t.fn = self.fn
    t.line = self.line
    if name == 'BYTE' then
    elseif name == 'HALFWORD' then
    elseif name == 'WORD' then
        if type(a) == 'string' then
            t.kind = 'label'
            t.name = a
            insert(self.commands, t)
            self:advance(4)
        end
    elseif name == 'ORG' then
        t.kind = 'goto'
        t.addr = a
        insert(self.commands, t)
        self.pos = a
        self:advance(0)
    elseif name == 'ALIGN' then
        t.kind = 'ahead'
        local align
        if a == 0 then
            align = 4
        elseif a < 0 then
            self:error('negative alignment')
        else
            align = 2^a
        end
        local temp = self.pos + align - 1
        t.skip = temp - (temp % align) - self.pos
        t.fill = b and b % 0x100 or 0
        insert(self.commands, t)
        self:advance(t.skip)
    elseif name == 'SKIP' then
        t.kind = 'ahead'
        t.skip = a
        t.fill = b and b % 0x100 or nil
        insert(self.commands, t)
        self:advance(t.skip)
    else
        self:error('unimplemented directive')
    end
end
--]]

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
            self:error('undefined label')
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
    if t.negate or t.signed then
        if val >= 0x10000 or val < -0x8000 then
            self:error('value out of range')
        end
        val = val % 0x10000
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

function Dumper:expect(tts)
    local t = self.s[self.i]
    if t == nil then
        self:error("expected another argument") -- TODO: more verbose
    end

    self.fn = t.fn
    self.line = t.line

    for _, tt in pairs(tts) do
        if t.tt == tt then
            return t.ok
        end
    end

    --local err = ("argument %i of %s expected type %s"):format(self.i, self.s.type, tt)
    local err = ("unexpected type for argument %i of %s"):format(self.i, self.s.type)
    self:error(err, t.tt)
end

function Dumper:register(registers)
    self:expect{'REG'}
    local t = self.s[self.i]
    local numeric = registers[t.tok]
    if not numeric then
        self:error('wrong type of register')
    end
    return Token(t)
end

function Dumper:const(relative, no_label)
    if no_label then
        self:expect{'NUM'}
    else
        self:expect{'NUM', 'LABELSYM'}
    end
    local t = self.s[self.i]
    local new = Token(t)
    if relative then
        if t.tt == 'LABELSYM' then
            new.t = 'LABELREL'
        else
            new.t = 'REL'
        end
    end
    return new
end

function Dumper:deref()
    self:expect{'DEREF'}
    local t = self.s[self.i]
    local new = Token(t)
    new.tt = 'REG'
    return new
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

-- NOTE: we could move format_{in,out} to its own virtual class and inherit it
function Dumper:format_in(informat)
    -- see data.lua for a guide on what all these mean
    local args = {}
    --if #informat ~= #s then error('mismatch') end
    for i=1, #informat do
        self.i = i -- FIXME: do we need this?
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
    if overrides[name] then
        --overrides[name](self, name)
        local s = Statement(self.fn, self.line, '!DATA') -- FIXME: dummy
        return s
    elseif h[2] == 'tob' then -- TODO: or h[2] == 'Tob' then
        local s = Statement(self.fn, self.line, '!DATA') -- FIXME: dummy
        return s
    elseif h[2] ~= nil then
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

function Dumper:load(statements)
    self.labels = {}

    local new_statements = {}
    for i=1, #statements do
        local s = statements[i]
        self.fn = s.fn
        self.line = s.line
        if s.type:sub(1, 1) == '!' then
            if s.type == '!LABEL' then
                self.labels[s[1].tok] = i
            elseif s.type == '!DATA' then
                -- noop
            else
                -- TODO: internal error?
                self:error('unknown statement', s.type)
            end
        end
    end

    -- TODO: keep track of lengths here?
    self.pos = 0
    for i=1, #statements do
        local s = statements[i]
        self.fn = s.fn
        self.line = s.line
        if s.type:sub(1, 1) ~= '!' then
            s = self:assemble(s)
            insert(new_statements, s)
        elseif assembled_directives[s.type] then
            -- FIXME: check for LABELs in !DATA
            -- TODO: reimplement ALIGN and SKIP here
            insert(new_statements, s)
        elseif s.type == '!LABEL' then
            -- noop
        else
            print(s.type)
            error('Internal Error: unknown statement found in Dumper')
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
                        local b0 = bitrange(h, 0, 7)
                        self:write{b0}
                    end
                else
                    error('Internal Error: unknown !DATA token')
                end
            end
        elseif s.type == '!ORG' then
            self.pos = s[1]
        end
    end

    --[[
        elseif t.kind == 'goto' then
            self.pos = t.addr
        elseif t.kind == 'ahead' then
            if t.fill then
                for i=1, t.skip do
                    self:write{t.fill}
                end
            else
                self.pos = self.pos + t.skip
            end
        elseif t.kind == 'label' then
            local val = self:desym{tt='LABELSYM', tok=t.name}
            val = (val % 0x80000000) + 0x80000000
            local b0 = bitrange(val, 0, 7)
            local b1 = bitrange(val, 8, 15)
            local b2 = bitrange(val, 16, 23)
            local b3 = bitrange(val, 24, 31)
            self:write{b3, b2, b1, b0}
    --]]
end

return Dumper
