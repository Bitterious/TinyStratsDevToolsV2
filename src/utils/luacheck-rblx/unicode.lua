local unicode_printability_boundaries = require(script.Parent.unicode_printability_boundaries)

local unicode = {}

function unicode.is_printable(codepoint)
    local floor_boundary_index
    local begin_index = 1
    local end_index = #unicode_printability_boundaries + 1
    while end_index - begin_index > 1 do -- binary search :3
        local mid_index = math.floor((begin_index + end_index) / 2)
        local mid_codepoint = unicode_printability_boundaries[mid_index]
        if codepoint < mid_codepoint then
            end_index = mid_index
        elseif codepoint > mid_codepoint then
            begin_index = mid_index
        else
            floor_boundary_index = mid_index
            break
        end
   end
   floor_boundary_index = floor_boundary_index or begin_index
   return floor_boundary_index % 2 == 0
end

return unicode