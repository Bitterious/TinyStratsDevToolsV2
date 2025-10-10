local mod = {}

local available_versions = {
    [1] = "v1",
}

local required_libraries = { }

do
    for id, version in pairs(available_versions) do
        local module = script:FindFirstChild(version)
        assert(module, "Module not found for version: " .. version)
        local library = require(module)
        required_libraries[id] = library
    end
end

function mod.get_version(id: number)
    local version_name = available_versions[id]
    assert(version_name, "Invalid version id")
    if required_libraries[id] then return required_libraries[id] end
    local module = script:FindFirstChild(version_name)
    assert(module, "Module not found for version: " .. version_name)
    local library = require(module)
    required_libraries[id] = library
    return library
end
function mod.get_latest_version_id()
    return #available_versions
end
function mod.get_latest_version()
    return mod.get_version(mod.get_latest_version_id())
end
function mod.has_version(id: number)
    return available_versions[id] ~= nil
end

return mod