local mod = {}

function mod.animate(imageLabel: ImageLabel, frameCount: number, frameDelay: number, sqSize: number)
    local currentFrame = 0
    task.spawn(function()
        while true do
            currentFrame = (currentFrame + 1) % frameCount
            local x = (currentFrame % sqSize) * imageLabel.ImageRectSize.X
            local y = math.floor(currentFrame / sqSize) * imageLabel.ImageRectSize.Y
            imageLabel.ImageRectOffset = Vector2.new(x, y)
            task.wait(frameDelay)
        end
    end)
end

return mod