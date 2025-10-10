local mod = {
    Endpoint = "http://localhost",
    UserId = 0,
}
local HttpService = game:GetService("HttpService")
local StudioService = game:GetService("StudioService")

local HashLib = require(script.Parent.HashLib)
local PopupTool = require(script.Parent.popupTool)
local State = require(script.Parent.globalState)

local UserId = StudioService:GetUserId()
if not UserId or UserId <= 0 then
    PopupTool.createPopup("ERROR", "This Studio session is not logged in")
    error("This Studio session is not logged in")
end
mod.UserId = UserId

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
    end
    State.GLOBAL_API_KEY = api_key
    return ownerhash == uidhash
end

return mod