local insert = table.insert

local Muncher = require "lips.Muncher"

local Preproc = require("lips.Class")(Muncher)
function Preproc:init(options)
    self.options = options or {}
end

function Preproc:process(tokens)
    self.tokens = tokens

    local defines = {}
    local plus_labels = {} -- constructed forwards
    local minus_labels = {} -- constructed backwards

    -- first pass: resolve defines, collect relative labels
    local new_tokens = {}
    self.i = 0
    while self.i < #self.tokens do
        local t = self:advance()
        if t.tt == nil then
            error('Internal Error: missing token')
        elseif t.tt == 'DEF' then
            local t2 = self:advance()
            if t2.tt ~= 'NUM' then
                self:error('expected number for define')
            end
            defines[t.tok] = t2.tok
        elseif t.tt == 'DEFSYM' then
            local tt = 'NUM'
            local tok = defines[t.tok]
            if tok == nil then
                self:error('undefined define') -- uhhh nice wording
            end
            insert(new_tokens, {fn=t.fn, line=t.line, tt=tt, tok=tok})
        elseif t.tt == 'RELLABEL' then
            if t.tok == '+' then
                insert(plus_labels, #new_tokens + 1)
            elseif t.tok == '-' then
                insert(minus_labels, 1, #new_tokens + 1)
            else
                error('Internal Error: unexpected token for relative label')
            end
            insert(new_tokens, t)
        else
            insert(new_tokens, t)
        end
    end

    -- second pass: resolve relative labels
    for i, t in ipairs(new_tokens) do
        self.fn = t.fn
        self.line = t.line
        if t.tt == 'RELLABEL' then
            t.tt = 'LABEL'
            -- exploits the fact that user labels can't begin with a number
            t.tok = tostring(i)
        elseif t.tt == 'RELLABELSYM' then
            t.tt = 'LABELSYM'

            local rel = t.tok
            local seen = 0
            -- TODO: don't iterate over *every* label, just the ones nearby
            if rel > 0 then
                for _, label_i in ipairs(plus_labels) do
                    if label_i > i then
                        seen = seen + 1
                        if seen == rel then
                            t.tok = tostring(label_i)
                            break
                        end
                    end
                end
            else
                for _, label_i in ipairs(minus_labels) do
                    if label_i < i then
                        seen = seen - 1
                        if seen == rel then
                            t.tok = tostring(label_i)
                            break
                        end
                    end
                end
            end

            if seen ~= rel then
                self:error('could not find appropriate relative label')
            end
        end
    end

    self.tokens = new_tokens

    return self.tokens
end

return Preproc
