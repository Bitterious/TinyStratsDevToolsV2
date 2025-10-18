local mod = {
    Endpoint = "https://ocelot.bittwr.com",
    UserId = 0,
}
local HttpService = game:GetService("HttpService")
local StudioService = game:GetService("StudioService")

local HashLib = require(script.Parent.HashLib)
local PopupTool = require(script.Parent.popupTool)

local UserId = StudioService:GetUserId()
if not UserId or UserId <= 0 then
    PopupTool.createPopup("ERROR", "This Studio session is not logged in")
    error("This Studio session is not logged in")
end
mod.UserId = UserId
local ApiKeyCached = nil

function mod.Login(api_key: string)
    local uidhash = HashLib.sha256(tostring(UserId))::string
    local requesttimestart = os.clock()
    local success, ownerhash = pcall(function()
        return HttpService:RequestAsync({
            Url = mod.Endpoint.."/key_query",
            Method = "GET",
            Headers = {
                ["Authorization"] = api_key,
            }
        }).Body
    end)
    print(os.clock() - requesttimestart, "seconds to get response from API")
    if os.clock() - requesttimestart > 5 then
        PopupTool.createPopup("System Warning", "API seems to be slow. Requests may take longer than expected.")
    end
    if not success then
        PopupTool.createPopup("Login Error", "Failed to connect to the API: " .. tostring(ownerhash))
        return false
    end
    if ownerhash ~= uidhash then
        PopupTool.createPopup("Login Error", "Invalid API key or user ID does not match the key owner")
        return false
    else ApiKeyCached = api_key end
    return ownerhash == uidhash
end

function mod.GetAssets()
    local success, assetsdata = pcall(function()
        local request = HttpService:RequestAsync({
            Url = mod.Endpoint.."/standaloneapi/get_assets",
            Method = "GET",
            Headers = {
                ["Authorization"] = ApiKeyCached,
                ["User-ID"] = tostring(UserId),
            }
        })
        if request.StatusCode ~= 200 then
            error(request.Body)
        end
        return HttpService:JSONDecode(request.Body)
    end)
    if not success then
        PopupTool.createPopup("API Error", "Failed to fetch assets: " .. tostring(assetsdata))
        return {}
    end
    return assetsdata
end

function mod.GetSource(id: number)
    local success, assetblob = pcall(function()
        return HttpService:RequestAsync({
            Url = mod.Endpoint.."/standaloneapi/get_asset_data?content_id=" .. id,
            Method = "GET",
            Headers = {
                ["Authorization"] = ApiKeyCached,
                ["User-ID"] = tostring(UserId),
            }
        })
    end)
    if not success then
        PopupTool.createPopup("Load Error", "Failed to load asset data: " .. tostring(assetblob))
        return nil, assetblob
    end
    if assetblob.StatusCode ~= 200 then
        PopupTool.createPopup("Load Error", "Failed to load asset data: " .. tostring(assetblob.Body))
        return nil, assetblob.Body
    end
    return assetblob.Body, nil
end

function mod.UploadBinary(data: string)
    local success, response = pcall(function()
        return HttpService:RequestAsync({
            Url = mod.Endpoint.."/standaloneapi/upload_binary",
            Method = "POST",
            Headers = {
                ["Authorization"] = ApiKeyCached,
                ["User-ID"] = tostring(UserId),
            },
            Body = data,
        })
    end)
    if not success or response.StatusCode ~= 200 then
        PopupTool.createPopup("Upload Error", "Failed to upload binary: " .. tostring(if success then response.Body else response))
        return nil
    end
    return response.Body
end

function mod.UploadAsset(data)
    local success, response = pcall(function()
        return HttpService:RequestAsync({
            Url = mod.Endpoint.."/standaloneapi/upload_asset_v2",
            Method = "POST",
            Headers = {
                ["Authorization"] = ApiKeyCached,
                ["User-ID"] = tostring(UserId),
            },
            Body = HttpService:JSONEncode(data),
        })
    end)
    if not success or response.StatusCode ~= 200 then
        PopupTool.createPopup("Upload Error", "Failed to upload asset: " .. tostring(if success then response.Body else response))
        return nil
    end
    return true
end

function mod.UpdateAsset(id: number, data)
    local success, response = pcall(function()
        return HttpService:RequestAsync({
            Url = mod.Endpoint.."/standaloneapi/update_asset",
            Method = "POST",
            Headers = {
                ["Authorization"] = ApiKeyCached,
                ["User-ID"] = tostring(UserId),
                ["Target-ID"] = tostring(id),
            },
            Body = HttpService:JSONEncode(data),
        })
    end)
    if not success or response.StatusCode ~= 200 then
        PopupTool.createPopup("Upload Error", "Failed to update asset: " .. tostring(if success then response.Body else response))
        return nil
    end
    return true
end

return mod