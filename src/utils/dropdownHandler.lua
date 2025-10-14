local mod = {}
local TSSignal = require(script.Parent.signalLibrary)

function mod.createDropdown(textButton: TextButton, _items: {[string]: any}?, select_style: boolean?, frameSize: UDim2?)
    select_style = if select_style == nil then true else select_style
    local dropdownImage = textButton:FindFirstChildWhichIsA("ImageLabel")
    local dropdownItem = textButton:FindFirstChildWhichIsA("TextLabel")
    if not dropdownItem and select_style then
        error("[DropdownHandler] Item found in button " .. textButton.Name)
    end
    local expanded = false
    local currentValue = nil
    local itemcount = 0
    local items = _items or {}
    for _, _ in items do itemcount += 1 end
    local firstname, firstvalue = next(items)
    currentValue = firstvalue
    if select_style then dropdownItem.Text = firstname or "[Broken Dropdown]" end
    local dropdownFrame = Instance.new("Frame")
    dropdownFrame.Name = "DropdownFrame"
    dropdownFrame.BackgroundColor3 = textButton.BackgroundColor3
    dropdownFrame.BorderSizePixel = 0
    dropdownFrame.Size = frameSize or UDim2.new(1, 0, 0, 0)
    dropdownFrame.Position = UDim2.new(0, 0, 1, 0)
    dropdownFrame.ClipsDescendants = true
    dropdownFrame.ZIndex = textButton.ZIndex + 1
    dropdownFrame.Parent = textButton
    local uiListLayout = Instance.new("UIListLayout")
    uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    uiListLayout.Padding = UDim.new(0, 1)
    uiListLayout.Parent = dropdownFrame
    local uiPadding = Instance.new("UIPadding")
    uiPadding.PaddingTop = UDim.new(0, 2)
    uiPadding.PaddingBottom = UDim.new(0, 2)
    uiPadding.PaddingLeft = UDim.new(0, 2)
    uiPadding.PaddingRight = UDim.new(0, 2)
    uiPadding.Parent = dropdownFrame
    local id = 1
    local disabledItems = {}
    local buttons = {}
    local changesignal, changefire = TSSignal()
    local reference = textButton
    if select_style then reference = dropdownItem end
    for name, value in items do
        local itemButton = Instance.new("TextButton")
        itemButton.Text = name
        itemButton.TextColor3 = reference.TextColor3
        itemButton.FontFace = reference.FontFace
        itemButton.TextSize = reference.TextSize
        itemButton.Name = name
        itemButton.BackgroundColor3 = dropdownFrame.BackgroundColor3:Lerp(Color3.new(0,0,0), .1)
        itemButton.BorderSizePixel = 0
        itemButton.Size = UDim2.new(1, 0, 0, 30)
        itemButton.LayoutOrder = id
        itemButton.Parent = dropdownFrame
        itemButton.MouseButton1Click:Connect(function()
            if disabledItems[name] then return end
            if select_style then 
                currentValue = value
                dropdownItem.Text = name
            end
            expanded = false
            if dropdownImage then dropdownImage.Rotation = 0 end
            dropdownFrame:TweenSize(frameSize or UDim2.new(1, 0, 0, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.2, true)
            changefire(value)
        end)
        buttons[name] = itemButton
        id += 1
    end
    textButton.MouseButton1Click:Connect(function()
        expanded = not expanded
        if dropdownImage then dropdownImage.Rotation = if expanded then 180 else 0 end
        local targetsize = frameSize or UDim2.new(1, 0, 0, 0)
        if expanded then
            local itemsize = textButton.AbsoluteSize.Y
            local targetHeight = itemcount * itemsize + 8
            dropdownFrame:TweenSize(targetsize + UDim2.fromOffset(0, targetHeight), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.2, true)
            for _, x in buttons do x.Size = UDim2.new(1, 0, 0, itemsize) end
        else
            dropdownFrame:TweenSize(targetsize, Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.2, true)
        end
    end)
    return {
        toggle_item = function(name: string, state: boolean)
            disabledItems[name] = not state
            if currentValue == items[name] then
                currentValue = nil
                for n, v in items do
                    if disabledItems[n] then continue end
                    if select_style then
                        currentValue = v
                        dropdownItem.Text = n
                    end
                    break
                end
            end
            local button = buttons[name]
            if button then
                if not state then
                    button.AutoButtonColor = false
                    button.TextColor3 = Color3.fromRGB(125,125,125)
                    button.BackgroundColor3 = dropdownFrame.BackgroundColor3:Lerp(Color3.new(1,1,1), .1)
                else
                    button.AutoButtonColor = true
                    button.TextColor3 = reference.TextColor3
                    button.BackgroundColor3 = dropdownFrame.BackgroundColor3:Lerp(Color3.new(0,0,0), .1)
                end
            end
        end,
        select_item = function(name: string)
            if not select_style then return end
            currentValue = items[name]
            dropdownItem.Text = name
        end,
        get_current_value = function()
            return currentValue
        end,
        changed = changesignal,
    }
end

return mod