describe("lips", function()
    setup(function()
        --local globalize = require "strict" -- FIXME
        local function globalize(t)
            for k, v in pairs(t) do
                _G[k] = v
            end
        end

        local lips = require "lips.init"
        local dummy = function() end

        local lipstick = function(fn, options)
            options = options or {}
            options.unsafe = true
            local writer = lips.writers.make_tester()
            lips(fn, writer, options)
            return writer()
        end

        local function simple_read(fn)
            local f = io.open(fn, 'r')
            if f == nil then
                error("couldn't open file for reading: "..tostring(fn), 2)
            end
            local data = f:read("*a")
            f:close()
            return data
        end

        local function simple_test(name)
            local expected = simple_read("spec/"..name..".txt")
            local ret = lipstick("spec/"..name..".asm")
            assert.is_equal(expected, ret)
        end

        globalize{
            lips = lips,
            dummy = dummy,
            lipstick = lipstick,
            simple_read = simple_read,
            simple_test = simple_test,
        }
    end)

    it("assembles all basic CPU instructions", function()
        -- no pseudo stuff, just plain MIPS
        simple_test("basic")
    end)

    it("assembles all registers", function()
        pending("all registers including aliases and coprocessor")
    end)
end)
