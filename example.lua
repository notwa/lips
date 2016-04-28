local lips = require "lips.init"
local err = lips('example.asm')
if err then
    print(err)
end
