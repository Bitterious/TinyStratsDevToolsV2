local ide = {}
local plugin: Plugin
local dockgui: DockWidgetPluginGui
local dockguiinfo = DockWidgetPluginGuiInfo.new(
    Enum.InitialDockState.Float, false, true,
    800, 600, 640, 480
)
local editorgui = script.IDEgui
local projectstorage = game:GetService("ServerStorage"):FindFirstChild("TinyStratsProjects")::Folder
if not projectstorage then
    projectstorage = Instance.new("Folder")
    projectstorage.Name = "TinyStratsProjects"
    projectstorage.Parent = game:GetService("ServerStorage")
end

local DropdownHandler = require(script.Parent.utils.dropdownHandler)
local WindowHandler = require(script.Parent.utils.windowHandler)
local TSSignal = require(script.Parent.utils.signalLibrary)

local Explorer = editorgui.Explorer

local Dropdowns = {}

local IDEclosingS, IDEclosingF = TSSignal()

function ide.init(_plugin)
    plugin = _plugin
    dockgui = plugin:CreateDockWidgetPluginGui("tinystratsIDE", dockguiinfo)
    dockgui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    dockgui.Name = "TSIDE"
    dockgui.Title = "Tiny Strats Development Environment"
    dockgui.Enabled = false

    dockgui:GetPropertyChangedSignal("Enabled"):Connect(function()
        if not dockgui.Enabled then IDEclosingF() end
    end)

    editorgui.Parent = dockgui

    local getmousepos = function()
        return dockgui:GetRelativeMousePosition()
    end
    WindowHandler.createWindow(Explorer, getmousepos)
end

local current_explorer_content = {}
local explorer_item = Explorer.Content.Item
explorer_item.Parent = nil
function ide.open_explorer()
    Explorer.Position = UDim2.fromScale(.5, .5)
    Explorer.Visible = true
    for _, x in current_explorer_content do x:Destroy() end
    for _, project in projectstorage:GetChildren() do
        local content_item = explorer_item:Clone()
        content_item.Name = project.Name
        content_item.Parent = Explorer.Content
        content_item.FileName.Text = project.Name
        content_item.FileEditTime.Text = project:GetAttribute("lastedit") or os.date()
        table.insert(current_explorer_content, content_item)
    end
end

function ide.set_ide_state(state)
    dockgui.Enabled = state
end

function ide.get_project_storage()
    return projectstorage
end

ide.closing = IDEclosingS

-- IDE GUI SETUP
Dropdowns.TitleFile = DropdownHandler.createDropdown(editorgui.Title.File, {
    ["New Project"] = "new_project",
    ["Open Project"] = "open_project",
}, false, UDim2.fromScale(2.5, 0))
Dropdowns.TitleFile.changed:Connect(function(value: string)
    print(`[IDE]: TitleFile action: {value}`)
    if value == "new_project" then

    elseif value == "open_project" then
        ide.open_explorer()
    end
end)

Dropdowns.ExplorerSort = DropdownHandler.createDropdown(Explorer.SortType, {
    ["Last Modified"] = "last_mod",
    ["Name"] = "name",
    ["Size"] = "size",
})

return ide