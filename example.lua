package.path = package.path..";?/init.lua"
local lips = require "lips"
local err = lips('example.asm')
if err then
    print(err)
end
