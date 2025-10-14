local utils = require(script.Parent.utils)
local vFS = require(script.Parent.Parent.vFS)

return ([[
Luacheck: %s
Luau: %s
VirtualFileSystem: %s
Roblox: %s
]]):format(utils.luacheck_version, _VERSION, vFS.version, version())