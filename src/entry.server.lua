-- PRELOAD CHECKS
assert(plugin, "This script should only run on Studio as a plugin!")
if _G.__OCELOT_LOADED__ then
    warn("Ocelot is already loaded! Loading it again may cause issues.")
end
local RunService = game:GetService("RunService")
assert(RunService:IsStudio(), "This script should only run on Studio as a plugin!")
if RunService:IsRunning() then return end
_G.__OCELOT_LOADED__ = true
local PLUGIN_IS_VALID = true
local API_KEY = nil

local VERSION = "v2"
local BUILD = 20251010

local gui = script.Parent.OcelotGuiRev2

local WindowHandler = require(script.Parent.utils.windowHandler)
local DropdownHandler = require(script.Parent.utils.dropdownHandler)
local PopupTool = require(script.Parent.utils.popupTool)
local NetHttp = require(script.Parent.utils.netHttp)
local State = require(script.Parent.utils.globalState)
local FlipbookAnimator = require(script.Parent.utils.flipbookAnimator)

local Players = game:GetService("Players")

--#region Setup Windows

local buttontb = plugin:CreateToolbar("Tiny Strats DevTools V2")
local button = buttontb:CreateButton("Tiny Strats DevTools V2", "Open the Tiny Strats Development Tools UI", "rbxassetid://116652703039248")

WindowHandler.createWindow(gui.Login)
WindowHandler.createWindow(gui.MainContainer.UploadUI)
WindowHandler.createWindow(gui.MainContainer.Explorer)
PopupTool.createPopup = function(title: string, message: string)
    local popup = gui.Popup:Clone()
    popup.ZIndex = 10
    popup.Title.Text = `[ {title:upper()} ]`
    popup.Welcomer.Text = message
    popup.TextButton.MouseButton1Click:Connect(function()
        popup:Destroy()
    end)
    WindowHandler.createWindow(popup)
    popup.Visible = true
    popup.Parent = gui
end
FlipbookAnimator.animate(gui.Login.Busy.ImageLabel, 16, 0.03, 4)
gui.Login.Busy.Visible = false
gui.MenuToggle.Visible = false
task.spawn(function()
    while PLUGIN_IS_VALID do
        local delta = task.wait()
        if not gui.Parent then break end
        gui.Login.Busy.ImageLabel.Rotation += 15 * delta
    end
end)

local UploadAssetTypeHandler = DropdownHandler.createDropdown(gui.MainContainer.UploadUI.Default.AssetType, {
    Map = "game/map",
    Model = "asset/model",
    Mod = "asset/mod",
    Animation = "asset/animation",
})
UploadAssetTypeHandler.toggle_item("Mod", false)
UploadAssetTypeHandler.toggle_item("Animation", false)
UploadAssetTypeHandler.select_item("Map")
local UploadPrivacyHandler = DropdownHandler.createDropdown(gui.MainContainer.UploadUI.Default.Privacy, {
    Public = "public",
    Unlisted = "unlisted",
    Private = "private",
})
UploadPrivacyHandler.select_item("Public")

gui.Login.Welcomer.Text = `Hello, {Players:GetNameFromUserIdAsync(NetHttp.UserId)}!\nPlease enter your API Key to continue:`

local CoreGui = game:GetService("CoreGui")
gui.Parent = CoreGui
gui.Enabled = false
button.Click:Connect(function()
    gui.Enabled = not gui.Enabled
end)

local function update_version_text()
    local loggedintext = "Not logged in"
    if API_KEY then
        loggedintext = `Logged in as {Players:GetNameFromUserIdAsync(NetHttp.UserId)}`
    end
    gui.VersionNumber.Text = `Tiny Strats DevTools - Version {VERSION} (Build Number {BUILD}) - OcelotGUI Version 2.0 - {loggedintext}`
end

--#endregion

--#region Authentication

local STORED_API_KEY = plugin:GetSetting("api_key") :: string?
if STORED_API_KEY then
    local success = NetHttp.Login(STORED_API_KEY)
    if success then
        API_KEY = STORED_API_KEY
        gui.MenuToggle.Visible = true
    else
        plugin:SetSetting("api_key", nil)
        gui.Login.Visible = true
    end
else
    gui.Login.Visible = true
end
update_version_text()
local TOSAccepted = false
local LoginButtonBusy = false
gui.Login.TOSAccept.MouseButton1Click:Connect(function()
    TOSAccepted = not TOSAccepted
    gui.Login.TOSAccept.ImageTransparency = if TOSAccepted then 0 else 1
    WindowHandler.setButtonEnabled(gui.Login.TextButton, TOSAccepted and not LoginButtonBusy)
end)
WindowHandler.setButtonEnabled(gui.Login.TextButton, false)

gui.Login.TextButton.MouseButton1Click:Connect(function()
    WindowHandler.setButtonEnabled(gui.Login.TextButton, false)
    LoginButtonBusy = true
    gui.Login.Busy.Visible = true
    local api_key = gui.Login.ApiKey.Text
    if api_key == "" then
        PopupTool.createPopup("Login Error", "API key cannot be empty")
        return
    end
    local success = NetHttp.Login(api_key)
    if success then
        plugin:SetSetting("api_key", api_key)
        gui.Login.Visible = false
        gui.MenuToggle.Visible = true
    end
    API_KEY = api_key
    gui.Login.Busy.Visible = false
    LoginButtonBusy = false
    WindowHandler.setButtonEnabled(gui.Login.TextButton, TOSAccepted)
    update_version_text()
end)

gui.Buttons.Logout.MouseButton1Click:Connect(function()
    API_KEY = nil
    plugin:SetSetting("api_key", nil)
    gui.Login.ApiKey.Text = ""
    TOSAccepted = false
    gui.Login.TOSAccept.ImageTransparency = 1
    LoginButtonBusy = false
    WindowHandler.setButtonEnabled(gui.Login.TextButton, false)
    gui.Login.Visible = true
    gui.MenuToggle.Visible = false
    gui.Buttons.Size = UDim2.fromOffset(0, 64)
    gui.MainContainer.Visible = false
    update_version_text()
end)

--#endregion

--#region Upload Logic

local Selection = game:GetService("Selection")
local jsonModel = require(script.Parent.utils.jsonModel)
local jsonAnim = require(script.Parent.utils.jsonAnim)
local deflate = require(script.Parent.utils.deflate)
local UploadIsBusy = false
local UploadData = nil

gui.Buttons.Upload.MouseButton1Click:Connect(function()
    if UploadIsBusy then return end
    if not gui.MainContainer.UploadUI.Visible then
        UploadIsBusy = true
        WindowHandler.setButtonEnabled(gui.Buttons.Upload, false)
        local process_success, process_result = pcall(function()
            local selections = Selection:Get()
            if #selections > 1 then
                PopupTool.createPopup("ERROR", "Please only select one object.")
                return
            elseif #selections == 0 then
                PopupTool.createPopup("ERROR", "Please select an object to upload.")
                return
            end
            local selected = selections[1]
            UploadAssetTypeHandler.toggle_item("Mod", false)
            UploadAssetTypeHandler.toggle_item("Animation", false)
            UploadAssetTypeHandler.toggle_item("Model", false)
            UploadAssetTypeHandler.toggle_item("Map", false)
            if selected.ClassName == "Model" or selected.ClassName == "Folder" then
                UploadAssetTypeHandler.toggle_item("Model", true)
                UploadAssetTypeHandler.toggle_item("Map", true)
                UploadAssetTypeHandler.select_item("Map")
                UploadPrivacyHandler.select_item("Public")
                local latestJSM = jsonModel.get_latest_version()
                local success, result = pcall(function()
                    local jsonData, err = latestJSM.to_json(selected)
                    if err ~= nil then
                        PopupTool.createPopup("JSON ERROR", "Failed to convert object to JSON: " .. tostring(err))
                        return
                    end
                    local compressed = deflate.Zlib.Compress(jsonData, {
                        level = 9,
                    })
                    return compressed
                end)
                if not success then
                    PopupTool.createPopup("ENCODING ERROR", `Failed to prepare object for upload: {result}`)
                    return
                end
                return result
            elseif selected.ClassName == "KeyframeSequence" then
                UploadAssetTypeHandler.toggle_item("Animation", true)
                UploadAssetTypeHandler.select_item("Animation")
                UploadPrivacyHandler.select_item("Public")
                local latestJSA = jsonAnim.get_latest_version()
                local success, result = pcall(function()
                    local jsonData, err = latestJSA.sequence_to_json(selected)
                    if err ~= nil then
                        PopupTool.createPopup("JSON ERROR", "Failed to convert sequence to JSON: " .. tostring(err))
                        return
                    end
                    local compressed = deflate.Zlib.Compress(jsonData, {
                        level = 9,
                    })
                    return compressed
                end)
                if not success then
                    PopupTool.createPopup("ENCODING ERROR", `Failed to prepare sequence for upload: {result}`)
                    return
                end
                return result
            elseif selected.ClassName == "StringValue" and selected:HasTag("tsmodfs") then
                UploadAssetTypeHandler.toggle_item("Mod", true)
                UploadAssetTypeHandler.select_item("Mod")
                UploadPrivacyHandler.select_item("Public")
                local fsRaw = selected.Value::string
                local success, result = pcall(function()
                    local compressed = deflate.Zlib.Compress(fsRaw, {
                        level = 9,
                    })
                    return compressed
                end)
                if not success then
                    PopupTool.createPopup("COMPRESSION ERROR", `Failed to prepare mod for upload: {result}`)
                    return
                end
                return result
            else
                PopupTool.createPopup("ERROR", "Unknown object type: "..selected.ClassName)
                return
            end
        end)
        WindowHandler.setButtonEnabled(gui.Buttons.Upload, true)
        UploadIsBusy = false
        if not process_success then
            PopupTool.createPopup("ERROR", `Failed to process data: {process_result}`)
            return
        end
        if not process_result then return end
        UploadData = process_result
        gui.MainContainer.UploadUI.Position = UDim2.fromScale(.5, .5)
		gui.Buttons.Upload.BackgroundColor3 = Color3.new(1,1,1)
		gui.Buttons.Upload.ImageColor3 = Color3.fromRGB(32,32,32)
    else
		gui.Buttons.Upload.BackgroundColor3 = Color3.fromRGB(32,32,32)
		gui.Buttons.Upload.ImageColor3 = Color3.new(1,1,1)
    end
    gui.MainContainer.UploadUI.Visible = not gui.MainContainer.UploadUI.Visible
end)

--#endregion

plugin.Unloading:Connect(function()
    PLUGIN_IS_VALID = false
    gui:Destroy()
end)