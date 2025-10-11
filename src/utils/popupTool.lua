local mod = {}
local WindowHandler = require(script.Parent.windowHandler)
local FlipbookAnimator = require(script.Parent.flipbookAnimator)

local gui = script.Parent.Parent.OcelotGuiRev2

function mod.createPopup(title, message)
    local popup = gui.Popup:Clone()
    popup.ZIndex = 100000
    popup.Title.Text = `[ {title:upper()} ]`
    popup.Welcomer.Text = message
    popup.TextButton.MouseButton1Click:Connect(function()
        popup:Destroy()
    end)
    WindowHandler.createWindow(popup)
    popup.Visible = true
    popup.Parent = gui
    return popup
end
function mod.createStatePopup(message)
    local popup = gui.MainContainer.BusyPopup:Clone()
    popup.ZIndex = 100000
    popup.Welcomer.Text = message
    WindowHandler.createWindow(popup)
    FlipbookAnimator.animate(popup.Gif, 16, .05, 4)
    popup.Visible = true
    popup.Parent = gui
    task.spawn(function()
        while popup.Parent do
            local delta = task.wait()
            if not popup.Parent then break end
            popup.Gif.Rotation += 90 * delta
        end
    end)
    return popup, function()
        popup:Destroy()
    end
end

return mod