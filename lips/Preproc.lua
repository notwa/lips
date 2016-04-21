local insert = table.insert

local path = string.gsub(..., "[^.]+$", "")
local data = require(path.."data")
local Base = require(path.."Base")
local Token = require(path.."Token")
local Statement = require(path.."Statement")

local abs = math.abs

local function signs(s)
    local start, end_ = s:find('[+-]+')
    if start ~= 1 then
        return 0
    end
    if s:sub(1, 1) == '+' then
        return end_
    elseif s:sub(1, 1) == '-' then
        return -end_
    end
end

local function unsigns(n)
    if n > 0 then
        return string.rep('+', n)
    elseif n < 0 then
        return string.rep('-', -n)
    else
        return ''
    end
end

local function RelativeLabel(index, name)
    return {
        index = index,
        name = name,
    }
end

local Preproc = Base:extend()
function Preproc:init(options)
    self.options = options or {}
end

function Preproc:error(msg, got)
        if got ~= nil then
        msg = msg..', got '..tostring(got)
    end
    error(('%s:%d: Error: %s'):format(self.fn, self.line, msg), 2)
end

--[[
function Preproc:advance()
    self.i = self.i + 1
    self.s = self.statements[self.i]
    self.fn = self.s.fn
    self.line = self.s.line
    return self.s
end
--]]

function Preproc:lookup(t)
    if t.tt == 'VARSYM' then
        local name = t.tok
        t.tt = 'NUM'
        t.tok = self.variables[name]
        if t.tok == nil then
            self:error('undefined variable', name)
        end
    elseif self.do_labels and t.tt == 'RELLABELSYM' or t.tt == 'RELLABEL' then
        if t.tt == 'RELLABEL' then
            t.tt = 'LABEL'
            -- exploits the fact that user labels can't begin with a number
            local name = t.tok:sub(2)
            t.tok = tostring(self.i)..name
        elseif t.tt == 'RELLABELSYM' then
            local i = self.i
            t.tt = 'LABELSYM'

            local rel = signs(t.tok)
            assert(rel ~= 0, 'Internal Error: relative label without signs')

            local name = t.tok:sub(abs(rel) + 1)
            local seen = 0

            -- TODO: don't iterate over *every* label, just the ones nearby.
            -- we could do this by popping labels as we pass over them.
            -- (would need to iterate once forwards and once backwards
            --  for plus and minus labels respectively)
            if rel > 0 then
                for _, rl in ipairs(self.plus_labels) do
                    if rl.name == name and rl.index > i then
                        seen = seen + 1
                        if seen == rel then
                            t.tok = tostring(rl.index)..name
                            break
                        end
                    end
                end
            else
                for _, rl in ipairs(self.minus_labels) do
                    if rl.name == name and rl.index < i then
                        seen = seen - 1
                        if seen == rel then
                            t.tok = tostring(rl.index)..name
                            break
                        end
                    end
                end
            end

            if seen ~= rel then
                self:error('could not find appropriate relative label', unsigns(rel))
            end
        end
    else
        return false
    end
    return true
end

function Preproc:check(s, i, tt)
    local t = s[i]
    if t == nil then
        self:error("expected another argument")
    end

    self.fn = t.fn
    self.line = t.line

    if t.tt ~= tt then
        self:lookup(t)
        --[[
        local newtt, newtok = self:lookup(argtt, argtok)
        if newtt and newtok then
            argtt, argtok = newtt, newtok
        end
        --]]
    end

    if t.tt ~= tt then
        local err = ("argument %i of %s expected type %s"):format(i, s.type, tt)
        self:error(err, t.tt)
    end
    return t.tok
end

function Preproc:process(statements)
    self.statements = statements

    self.variables = {}
    self.plus_labels = {} -- constructed forwards
    self.minus_labels = {} -- constructed backwards
    self.do_labels = false

    -- first pass: resolve variables and collect relative labels
    local new_statements = {}
    for i=1, #self.statements do
        local s = self.statements[i]
        self.fn = s.fn
        self.line = s.line
        if s.type:sub(1, 1) == '!' then
            -- directive, label, etc.
            if s.type == '!VAR' then
                local a = self:check(s, 1, 'VAR')
                local b = self:check(s, 2, 'NUM')
                self.variables[a] = b
            elseif s.type == '!LABEL' then
                if s[1].tt == 'RELLABEL' then
                    local label = s[1].tok
                    local rl = RelativeLabel(#new_statements + 1, label:sub(2))
                    local c = label:sub(1, 1)
                    if c == '+' then
                        insert(self.plus_labels, rl)
                    elseif c == '-' then
                        insert(self.minus_labels, 1, rl) -- remember, it's backwards
                    else
                        error('Internal Error: unexpected token for relative label')
                    end
                end
                insert(new_statements, s)
            end
        else
            -- regular instruction
            for j, t in ipairs(s) do
                self:lookup(t)
                --[[
                local newtt, newtok = self:lookup(t.tt, t.tok)
                if newtt and newtok then
                else
                end
                --]]
            end
            insert(new_statements, s)
        end
    end

    -- second pass: resolve relative labels
    self.do_labels = true
    for i=1, #new_statements do
        self.i = i -- make visible to :lookup
        local s = new_statements[i]
        self.fn = s.fn
        self.line = s.line
        for j, t in ipairs(s) do
            self:lookup(t)
        end
    end

    self.statements = new_statements
    return self.statements
end

return Preproc
