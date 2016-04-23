package.path = package.path..";?/init.lua"
local lips = require "lips"
local err = lips('example.asm', nil, {offset=0})
if err then
    print(err)
end
