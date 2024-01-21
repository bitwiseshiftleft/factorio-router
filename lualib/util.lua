M = {}

local function format_power(w)
    -- TODO: seems like this should be standard
    local unit = ""
    if w >= 1e12 then
        w = w / 1e12
        unit = "T"
    elseif w >= 1e9 then
        w = w / 1e9
        unit = "G"
    elseif w >= 1e6 then
        w = w / 1e6
        unit = "M"
    elseif w >= 1e3 then
        w = w / 1e3
        unit = "k"
    end
    if w == math.floor(w) then
        return string.format("%d %sW", w, unit)
    else
        return string.format("%.2f %sW", w, unit)
    end
end

M.format_power = format_power

return M