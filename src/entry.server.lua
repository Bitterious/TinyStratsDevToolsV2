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
local BUILD = 20251011 --YYMMDD

local gui = script.Parent.OcelotGuiRev2

local WindowHandler = require(script.Parent.utils.windowHandler)
local DropdownHandler = require(script.Parent.utils.dropdownHandler)
local PopupTool = require(script.Parent.utils.popupTool)
local NetHttp = require(script.Parent.utils.netHttp)
local FlipbookAnimator = require(script.Parent.utils.flipbookAnimator)

local Players = game:GetService("Players")

--#region Setup Windows

local buttontb = plugin:CreateToolbar("Tiny Strats DevTools V2")
local button = buttontb:CreateButton("Tiny Strats DevTools V2", "Open the Tiny Strats Development Tools UI", "rbxassetid://116652703039248")

WindowHandler.createWindow(gui.Login)
WindowHandler.createWindow(gui.MainContainer.UploadUI)
WindowHandler.createWindow(gui.MainContainer.Explorer)
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
    Mod = "package/mod",
    Animation = "asset/animation",
})
local AssetTypeValueReverse = {
    ["game/map"] = "Map",
    ["asset/model"] = "Model",
    ["package/mod"] = "Mod",
    ["asset/animation"] = "Animation",
}
UploadAssetTypeHandler.toggle_item("Mod", false)
UploadAssetTypeHandler.toggle_item("Animation", false)
UploadAssetTypeHandler.select_item("Map")
local UploadPrivacyHandler = DropdownHandler.createDropdown(gui.MainContainer.UploadUI.Default.Privacy, {
    Public = "public",
    Unlisted = "unlisted",
    Private = "private",
})
local PrivacyValueReverse = {
    ["public"] = "Public",
    ["unlisted"] = "Unlisted",
    ["private"] = "Private",
}
UploadPrivacyHandler.select_item("Public")
local ExplorerTypeHandler = DropdownHandler.createDropdown(gui.MainContainer.Explorer.TypeDropdown, {
    Map = "game/map",
    Model = "asset/model",
    Mod = "package/mod",
    Animation = "asset/animation",
})
ExplorerTypeHandler.select_item("Map")

gui.Login.Welcomer.Text = `Hello, {Players:GetNameFromUserIdAsync(NetHttp.UserId)}!\nPlease enter your API Key to continue:`
local ExplorerContent = gui.MainContainer.Explorer.Container.Template
ExplorerContent.Parent = nil

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

--#region Upload Logic

local Selection = game:GetService("Selection")
local jsonModel = require(script.Parent.utils.jsonModel)
local jsonAnim = require(script.Parent.utils.jsonAnim)
local deflate = require(script.Parent.utils.deflate)
local UploadIsBusy = false
local UploadData = nil
local UploadResourceVersionUsed = nil
local UploadMenuMode: "upload" | "update" | "overwrite" = "upload"
local MaxAssetSize = 5000000 -- 5 megabytes (decimal)
local OverwriteMenuItem = gui.MainContainer.UploadUI.Overwrite.Contents.Button
OverwriteMenuItem.Parent = nil
local OverwriteMenuItemList = {}

function is_valid_integer(s)
  return s:match("^-?%d+$") ~= nil
end

local function reset_upload_menu_default()
    local default = gui.MainContainer.UploadUI.Default
    default.ItemName.Text = ""
    default.ItemDescription.Text = ""
    default.IconId.Text = "10925696693"
    default.RawData.Text = ""
    default.OverwriteMenu.Visible = true
    default.Visible = true
    gui.MainContainer.UploadUI.Title.Text = "[ UPLOAD ]"
    gui.MainContainer.UploadUI.Overwrite.Visible = false
    UploadMenuMode = "upload"
end
local function reset_upload_menu_overwrite()
    local overwrite = gui.MainContainer.UploadUI.Overwrite
    for _, x in OverwriteMenuItemList do x:Destroy() end
    local owned_assets = NetHttp.GetAssets()
    local allowed_types = { }
    local current_type = UploadAssetTypeHandler.get_current_value()
    if UploadMenuMode == "upload" then
        if current_type == "game/map" or current_type == "asset/model" then
            allowed_types = { "game/map", "asset/model" }
        else allowed_types = { current_type } end
    elseif UploadMenuMode == "update" then allowed_types = { current_type } end
    -- remove unsupported asset types before making the buttons
    for i = #owned_assets, 1, -1 do
        local asset = owned_assets[i]
        if not table.find(allowed_types, (asset.content_type or "game/map")) then
            table.remove(owned_assets, i)
        end
    end
    for _, asset in owned_assets do
        local btn = OverwriteMenuItem:Clone()
        btn.ContentName.Text = asset.name
        btn.ContentId.Text = `[{asset.id}]`
        btn.ContentIcon.Image = asset.icon
        btn.MouseButton1Click:Connect(function()
            overwrite.ContentId.Text = tostring(asset.id)
        end)
        btn:SetAttribute("ID", asset.id)
        btn.Name = asset.name
        btn.Parent = overwrite.Contents
        table.insert(OverwriteMenuItemList, btn)
    end
    overwrite.Visible = true
    gui.MainContainer.UploadUI.Default.Visible = false
    gui.MainContainer.UploadUI.Title.Text = "[ OVERWRITE ]"
    UploadMenuMode = "overwrite"
end
gui.MainContainer.UploadUI.Overwrite.SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
    local search_text = gui.MainContainer.UploadUI.Overwrite.SearchBox.Text
    for _, x in OverwriteMenuItemList do
        if search_text == "" then
            x.Visible = true
            continue
        end
        if string.find(x.Name, search_text) then
            x.Visible = true
        else
            x.Visible = false
        end
    end
end)
gui.MainContainer.UploadUI.Overwrite.ContentId:GetPropertyChangedSignal("Text"):Connect(function()
    local overwrite_id = gui.MainContainer.UploadUI.Overwrite.ContentId.Text
    if not is_valid_integer(overwrite_id) then
        for _, x in OverwriteMenuItemList do
            x.BackgroundColor3 = Color3.fromRGB(32,32,32)
            x.ImageColor3 = Color3.new(1,1,1)
        end
        return
    end
    local id = tonumber(overwrite_id)
    for _, x in OverwriteMenuItemList do
        if x:GetAttribute("ID") == id then
            x.BackgroundColor3 = Color3.fromRGB(16, 194, 0)
        else
            x.BackgroundColor3 = Color3.fromRGB(32,32,32)
        end
    end
end)

gui.MainContainer.UploadUI.Default.OverwriteMenu.MouseButton1Click:Connect(reset_upload_menu_overwrite)
gui.MainContainer.UploadUI.Overwrite.OverwriteMenu.MouseButton1Click:Connect(reset_upload_menu_default)

gui.MainContainer.UploadUI.Default.IconId:GetPropertyChangedSignal("Text"):Connect(function()
    local iconid = gui.MainContainer.UploadUI.Default.IconId.Text
    local rbxassetid = "rbxassetid://"..iconid
    gui.MainContainer.UploadUI.Default.Icon.Image = rbxassetid
end)

gui.Buttons.Upload.MouseButton1Click:Connect(function()
    if UploadIsBusy then return end
    if not gui.MainContainer.UploadUI.Visible then
        UploadIsBusy = true
        WindowHandler.setButtonEnabled(gui.Buttons.Upload, false)
        local _, delete_popup = PopupTool.createStatePopup("Compiling asset...")
        local process_success, process_result, latest_lib_version = pcall(function()
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
            UploadPrivacyHandler.select_item("Public")
            if selected.ClassName == "Model" or selected.ClassName == "Folder" then
                UploadAssetTypeHandler.toggle_item("Model", true)
                UploadAssetTypeHandler.toggle_item("Map", true)
                UploadAssetTypeHandler.select_item("Map")
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
                return result, jsonModel.get_latest_version_id()
            elseif selected.ClassName == "KeyframeSequence" then
                UploadAssetTypeHandler.toggle_item("Animation", true)
                UploadAssetTypeHandler.select_item("Animation")
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
                return result, jsonAnim.get_latest_version_id()
            elseif selected.ClassName == "StringValue" and selected:HasTag("tsmodfs") then
                UploadAssetTypeHandler.toggle_item("Mod", true)
                UploadAssetTypeHandler.select_item("Mod")
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
                return result, 1
            else
                PopupTool.createPopup("ERROR", "Unknown object type: "..selected.ClassName)
                return
            end
        end)
        WindowHandler.setButtonEnabled(gui.Buttons.Upload, true)
        UploadIsBusy = false
        delete_popup()
        if not process_success then
            PopupTool.createPopup("ERROR", `Failed to process data: {process_result}`)
            return
        end
        if not process_result then return end
        if string.len(process_result) > MaxAssetSize then
            PopupTool.createPopup("ERROR", `Max asset size is 5 MB. Your asset is {string.len(process_result)/1000000} MB.`)
            return
        end
        UploadData = process_result
        UploadResourceVersionUsed = latest_lib_version
        reset_upload_menu_default()
        gui.MainContainer.UploadUI.Position = UDim2.fromScale(.5, .5)
		gui.Buttons.Upload.BackgroundColor3 = Color3.new(1,1,1)
		gui.Buttons.Upload.ImageColor3 = Color3.fromRGB(32,32,32)
    else
		gui.Buttons.Upload.BackgroundColor3 = Color3.fromRGB(32,32,32)
		gui.Buttons.Upload.ImageColor3 = Color3.new(1,1,1)
    end
    gui.MainContainer.UploadUI.Visible = not gui.MainContainer.UploadUI.Visible
end)

gui.MainContainer.UploadUI.Default.Upload.MouseButton1Click:Connect(function()
    if UploadIsBusy then return end
    gui.MainContainer.UploadUI.Visible = false
    gui.Buttons.Upload.BackgroundColor3 = Color3.fromRGB(32,32,32)
    gui.Buttons.Upload.ImageColor3 = Color3.new(1,1,1)
    UploadIsBusy = true
    WindowHandler.setButtonEnabled(gui.MainContainer.UploadUI.Default.Upload, false)
    local _, delete_popup = PopupTool.createStatePopup("Uploading asset...")
    local success, result = pcall(function()
        assert(UploadData, "No data to upload.")
        local AssetName = gui.MainContainer.UploadUI.Default.ItemName.Text
        local AssetDescription = gui.MainContainer.UploadUI.Default.ItemDescription.Text
        local AssetIconId = gui.MainContainer.UploadUI.Default.IconId.Text
        local AssetPrivacy = UploadPrivacyHandler.get_current_value()
        local AssetType = UploadAssetTypeHandler.get_current_value()
        if AssetName:gsub(" ", "") == "" then
            PopupTool.createPopup("ERROR", "Asset name cannot be empty.")
            return
        end
        if not is_valid_integer(AssetIconId) then
            PopupTool.createPopup("ERROR", "Invalid icon ID.")
            return
        end
        local SourceId = NetHttp.UploadBinary(UploadData)
        if not SourceId then return end
        local request_data = {
            name = AssetName,
            description = AssetDescription,
            icon = `rbxassetid://{AssetIconId}`,
            visibility = AssetPrivacy,
            source_id = SourceId,
            resource_version = UploadResourceVersionUsed or 1,
            content_type = AssetType,
        }
        local SuccessfulUpload = NetHttp.UploadAsset(request_data)
        if SuccessfulUpload then
            PopupTool.createPopup("INFO", "Asset uploaded successfully!")
        end
    end)
    if not success then
        PopupTool.createPopup("ERROR", `Failed to upload data: {result}`)
    end
    UploadIsBusy = false
    WindowHandler.setButtonEnabled(gui.MainContainer.UploadUI.Default.Upload, true)
    delete_popup()
end)

gui.MainContainer.UploadUI.Overwrite.Upload.MouseButton1Click:Connect(function()
    if UploadIsBusy then return end
    gui.MainContainer.UploadUI.Visible = false
    gui.Buttons.Upload.BackgroundColor3 = Color3.fromRGB(32,32,32)
    gui.Buttons.Upload.ImageColor3 = Color3.new(1,1,1)
    UploadIsBusy = true
    WindowHandler.setButtonEnabled(gui.MainContainer.UploadUI.Default.Upload, false)
    local _, delete_popup = PopupTool.createStatePopup("Uploading asset...")
    local success, result = pcall(function()
        assert(UploadData, "No data to upload.")
        local TargetID = gui.MainContainer.UploadUI.Overwrite.ContentId.Text
        local IsValidID = is_valid_integer(TargetID)
        if not IsValidID then
            PopupTool.createPopup("ERROR", "Invalid asset ID. Must be an integer.")
            return
        end
        local RealID = tonumber(TargetID)
        for _, x in OverwriteMenuItemList do
            if x:GetAttribute("ID") == RealID then
                IsValidID = true
                break
            end
        end
        if not IsValidID then
            PopupTool.createPopup("ERROR", "Invalid asset ID. You don't own an asset with this ID.")
            return
        end
        local SourceId = NetHttp.UploadBinary(UploadData)
        if not SourceId then return end
        local request_data = {
            source_id = SourceId,
            resource_version = UploadResourceVersionUsed or 1,
        }
        local SuccessfulUpload = NetHttp.UpdateAsset(RealID, request_data)
        if SuccessfulUpload then
            PopupTool.createPopup("INFO", "Asset overwritten successfully!")
        end
    end)
    UploadIsBusy = false
    WindowHandler.setButtonEnabled(gui.MainContainer.UploadUI.Default.Upload, true)
    delete_popup()
end)

--#endregion

--#region Explorer Window

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local function TableToTextData(t)
    local s = ""
    for k, v in t do
        s ..= `[{k}]: {v}\n`
    end
    return s
end

local ExplorerContentItems = {}
local function load_explorer_content()
    local _, delete_popup = PopupTool.createStatePopup("Loading owned assets...")
    for _, x in ExplorerContentItems do x:Destroy() end
    local current_content_type = ExplorerTypeHandler.get_current_value()
    local assets = NetHttp.GetAssets()
    for i = #assets, 1, -1 do
        local asset = assets[i]
        if (asset.content_type or "game/map") ~= current_content_type then
            table.remove(assets, i)
        end
    end
    if #assets == 0 then
        --TODO: Add 'Create New Content' dialog
    end
    for i, asset in ipairs(assets) do
        local ContentItem = ExplorerContent:Clone()
        ContentItem.Parent = gui.MainContainer.Explorer.Container
        ContentItem.Name = `entry_{i}`
        ContentItem.ContentName.Text = asset.name
        ContentItem.ContentDescription.Text = if asset.description == "" then "<No Description>" else asset.description
        ContentItem.ContentIcon.Image = asset.icon
        ContentItem.LayoutOrder = i
        ContentItem.CopyId.MouseButton1Click:Connect(function()
            local popup = PopupTool.createPopup("COPY ID", "Asset id for\n"..asset.name)
            local textbox = gui.Login.ApiKey:Clone()
            textbox.Parent = popup
            textbox.TextEditable = false
            textbox.Text = tostring(asset.id)
            popup.Welcomer.TextYAlignment = Enum.TextYAlignment.Top
        end)
        ContentItem.Edit.MouseButton1Click:Connect(function()
            reset_upload_menu_default()
            UploadAssetTypeHandler.toggle_item("Mod", false)
            UploadAssetTypeHandler.toggle_item("Animation", false)
            UploadAssetTypeHandler.toggle_item("Model", false)
            UploadAssetTypeHandler.toggle_item("Map", false)
            UploadAssetTypeHandler.select_item(AssetTypeValueReverse[asset.content_type or "game/map"])
            UploadPrivacyHandler.select_item(PrivacyValueReverse[asset.visibility or "public"])
            gui.MainContainer.UploadUI.Default.ItemName.Text = asset.name
            gui.MainContainer.UploadUI.Default.ItemDescription.Text = asset.description
            local icon_raw = string.match(asset.icon, "rbxassetid://([0-9]+)")
            gui.MainContainer.UploadUI.Default.IconId.Text = icon_raw or ""
            gui.MainContainer.UploadUI.Default.RawData.Text = TableToTextData(asset)
            UploadMenuMode = "update"
            gui.MainContainer.UploadUI.Position = UDim2.fromScale(.5, .5)
            gui.Buttons.Upload.BackgroundColor3 = Color3.new(1,1,1)
            gui.Buttons.Upload.ImageColor3 = Color3.fromRGB(32,32,32)
            gui.MainContainer.UploadUI.Visible = true
        end)
        ContentItem.Load.MouseButton1Click:Connect(function()
            local data, err = NetHttp.GetSource(asset.id)
            if err then return end
            local content_type = asset.content_type or "game/map"
            if content_type == "game/map" or content_type == "asset/model" then
                if not jsonModel.has_version(asset.resource_version) then
                    PopupTool.createPopup("LOAD ERROR", `JSM{asset.resource_version} not found. Try updating the plugin.`)
                    return
                end
                local JSMVersion  = jsonModel.get_version(asset.resource_version)
                if asset.resource_version ~= jsonModel.get_latest_version_id() then
                    PopupTool.createPopup("WARNING", `This map uses an outdated decoder version.\nA reupload is recommended.`)
                end
                if not asset.compressed then -- .compressed is only set when the compression is server sided
                    data = deflate.Zlib.Decompress(data)
                end
                local model: Folder, jserr = JSMVersion.from_json(data)
                if jserr then
                    PopupTool.createPopup("LOAD ERROR", `Failed to load JSON into a model: {jserr}`)
                    return
                end
                model.Name = `[{asset.id}] {asset.name}`
                model.Parent = workspace
                ChangeHistoryService:SetWaypoint("TSDEVTOOL_IMPORT_JSM_"..asset.id)
            elseif content_type == "package/mod" then
                -- no need to check for asset.compressed since it has been deprecated by the time this comes out
                local decompressed = deflate.Zlib.Decompress(data)
                local stringval = Instance.new("StringValue")
                stringval.Name = `[{asset.id}] {asset.name}`
                stringval.Value = decompressed
                stringval:AddTag("tsmodfs")
                stringval.Parent = workspace
                ChangeHistoryService:SetWaypoint("TSDEVTOOL_IMPORT_MOD_"..asset.id)
            elseif content_type == "asset/animation" then
                if not jsonAnim.has_version(asset.resource_version) then
                    PopupTool.createPopup("LOAD ERROR", `JSA{asset.resource_version} not found. Try updating the plugin.`)
                    return
                end
                local JSAVersion  = jsonAnim.get_version(asset.resource_version)
                if asset.resource_version ~= jsonAnim.get_latest_version_id() then
                    PopupTool.createPopup("WARNING", `This sequence uses an outdated decoder version.\nA reupload is recommended.`)
                end
                data = deflate.Zlib.Decompress(data)
                local sequence: KeyframeSequence, jserr = JSAVersion.json_to_sequence(data)
                if jserr then
                    PopupTool.createPopup("LOAD ERROR", `Failed to load JSON into a sequence: {jserr}`)
                    return
                end
                sequence.Name = `[{asset.id}] {asset.name}`
                sequence.Parent = workspace
                ChangeHistoryService:SetWaypoint("TSDEVTOOL_IMPORT_JSA_"..asset.id)
            else
                PopupTool.createPopup("ERROR", "Unknown content type: "..content_type)
                return
            end
        end)
        table.insert(ExplorerContentItems, ContentItem)
    end
    delete_popup()
end
local ReloadBusy = false
gui.MainContainer.Explorer.Refresh.MouseButton1Click:Connect(function()
    if ReloadBusy then return end
    ReloadBusy = true
    WindowHandler.setButtonEnabled(gui.MainContainer.Explorer.Refresh, false)
    pcall(function()
        for _, x in ExplorerContentItems do x:Destroy() end
        load_explorer_content()
    end)
    ReloadBusy = false
    WindowHandler.setButtonEnabled(gui.MainContainer.Explorer.Refresh, true)
end)
ExplorerTypeHandler.changed:Connect(function(_)
    load_explorer_content()
end)

--#endregion

--#region Authentication

local STORED_API_KEY = plugin:GetSetting("api_key") :: string?
if STORED_API_KEY then
    local success = NetHttp.Login(STORED_API_KEY)
    if success then
        API_KEY = STORED_API_KEY
        gui.MenuToggle.Visible = true
        load_explorer_content()
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
    load_explorer_content()
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

plugin.Unloading:Connect(function()
    PLUGIN_IS_VALID = false
    gui:Destroy()
end)
ChangeHistoryService:ResetWaypoints()