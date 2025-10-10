local mod = {}

function mod.createDropdown(textButton: TextButton, _items: {[string]: any}?)
    local dropdownImage = textButton:FindFirstChildWhichIsA("ImageLabel")
    local dropdownItem = textButton:FindFirstChildWhichIsA("TextLabel")
    if not dropdownImage or not dropdownItem then
        error("[DropdownHandler] No dropdown image or item found in button " .. textButton.Name)
    end
    local expanded = false
    local currentValue = nil
    local itemcount = 0
    local items = _items or {}
    for _, _ in items do itemcount += 1 end
    local firstname, firstvalue = next(items)
    currentValue = firstvalue
    dropdownItem.Text = firstname or "[Broken Dropdown]"
    local dropdownFrame = Instance.new("Frame")
    dropdownFrame.Name = "DropdownFrame"
    dropdownFrame.BackgroundColor3 = textButton.BackgroundColor3
    dropdownFrame.BorderSizePixel = 0
    dropdownFrame.Size = UDim2.new(1, 0, 0, 0)
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
    for name, value in items do
        local itemButton = Instance.new("TextButton")
        itemButton.Text = name
        itemButton.TextColor3 = dropdownItem.TextColor3
        itemButton.FontFace = dropdownItem.FontFace
        itemButton.TextSize = dropdownItem.TextSize
        itemButton.Name = name
        itemButton.BackgroundColor3 = dropdownFrame.BackgroundColor3:Lerp(Color3.new(0,0,0), .1)
        itemButton.BorderSizePixel = 0
        itemButton.Size = UDim2.new(1, 0, 0, 30)
        itemButton.LayoutOrder = id
        itemButton.Parent = dropdownFrame
        itemButton.MouseButton1Click:Connect(function()
            if disabledItems[name] then return end
            currentValue = value
            dropdownItem.Text = name
            expanded = false
            dropdownImage.Rotation = 0
            dropdownFrame:TweenSize(UDim2.new(1, 0, 0, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.2, true)
        end)
        buttons[name] = itemButton
        id += 1
    end
    textButton.MouseButton1Click:Connect(function()
        expanded = not expanded
        dropdownImage.Rotation = if expanded then 180 else 0
        if expanded then
            local targetHeight = itemcount * 30 + 8
            dropdownFrame:TweenSize(UDim2.new(1, 0, 0, targetHeight), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.2, true)
        else
            dropdownFrame:TweenSize(UDim2.new(1, 0, 0, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.2, true)
        end
    end)
    return {
        toggle_item = function(name: string, state: boolean)
            disabledItems[name] = not state
            if currentValue == items[name] then
                currentValue = nil
                for n, v in items do
                    if disabledItems[n] then continue end
                    currentValue = v
                    dropdownItem.Text = n
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
                    button.TextColor3 = dropdownItem.TextColor3
                    button.BackgroundColor3 = dropdownFrame.BackgroundColor3:Lerp(Color3.new(0,0,0), .1)
                end
            end
        end,
        select_item = function(name: string)
            if disabledItems[name] then return end
            currentValue = items[name]
            dropdownItem.Text = name
        end,
        get_current_value = function()
            return currentValue
        end,
    }
end

return mod