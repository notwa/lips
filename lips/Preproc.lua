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

    -- first pass: collect tokens, constants, and relative labels.
    self.i = 0
    while self.i < #self.tokens do
        local tt, tok = self:advance()
        if tt == 'DEF' then
            local tt2, tok2 = self:advance()
            if tt2 ~= 'NUM' then
                self:error('expected number for define')
            end
            defines[tok] = tok2
        elseif tt == 'RELLABEL' then
            if tok == '+' then
                insert(plus_labels, self.i)
            elseif tok == '-' then
                insert(minus_labels, 1, self.i)
            else
                error('Internal Error: unexpected token for relative label')
            end
        elseif tt == nil then
            error('Internal Error: missing token')
        end
    end

    -- resolve defines and relative labels
    for i, t in ipairs(self.tokens) do
        self.fn = t.fn
        self.line = t.line
        if t.tt == 'DEFSYM' then
            t.tt = 'NUM'
            t.tok = defines[t.tok]
            if t.tok == nil then
                self:error('undefined define') -- uhhh nice wording
            end
        elseif t.tt == 'RELLABEL' then
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

    return self.tokens
end

return Preproc
