local mod = {}
local userInputService = game:GetService("UserInputService")

local draggingWindow = nil
function mod.createWindow(frame: GuiObject)
    local title = frame:FindFirstChild("Title")::GuiObject
    if not title then
        warn(`[WindowHandler] No title found in frame {frame.Name}`)
        return
    end
    title.Active = true
    title.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            if draggingWindow then
                if draggingWindow.ZIndex > frame.ZIndex then
                    return
                end
            end
            draggingWindow = frame
        end
    end)
    title.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            draggingWindow = nil
        end
    end)
end

function mod.setButtonEnabled(button: GuiButton, enabled: boolean)
    button.Active = enabled
    button.AutoButtonColor = enabled
    if button:IsA("TextButton") then button.TextColor3 = if enabled then Color3.new(1, 1, 1) else Color3.new(0.5, 0.5, 0.5)
    elseif button:IsA("ImageButton") then button.ImageColor3 = if enabled then Color3.new(1, 1, 1) else Color3.new(0.5, 0.5, 0.5)
    end
    button.BackgroundColor3 = if enabled then Color3.fromRGB(32,32,32) else Color3.fromRGB(45,45,45)
end

local lastMousePos = userInputService:GetMouseLocation()
userInputService.InputChanged:Connect(function(input)
    local newMousePos = userInputService:GetMouseLocation()
    if draggingWindow and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = newMousePos - lastMousePos
        draggingWindow.Position = UDim2.new(
            draggingWindow.Position.X.Scale,
            draggingWindow.Position.X.Offset + delta.X,
            draggingWindow.Position.Y.Scale,
            draggingWindow.Position.Y.Offset + delta.Y
        )
    end
    lastMousePos = newMousePos
end)

return mod