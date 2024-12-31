local M = {}

local function disable_picker_dollies()
    if remote.interfaces["PickerDollies"] and remote.interfaces["PickerDollies"]["add_blacklist_name"] then
        local to_blacklist = {
            "","fast-","express-","se-space-","se-deep-space","kr-advanced-","kr-superior-"
        }
        local sizes = { "4x4" }
        local suffixes = { "io", "smart", "router" }
        for _,prefix in ipairs(to_blacklist) do
            for _,size in ipairs(sizes) do
                for _,suffix in ipairs(suffixes) do
                    remote.call("PickerDollies", "add_blacklist_name", "router-"..size.."-"..prefix..suffix, true)
                end
            end
        end
        local others = {"port-control-combinator", "contents-indicator-lamp", "output-indicator-lamp",
            "is-default-lamp", "port-trim-combinator", "smart-port-lamp",
            "smart-io-indicator-lamp"}
        for _,other in ipairs(others) do
            remote.call("PickerDollies", "add_blacklist_name", "router-component-"..other, true)
        end
    end
end

M.disable_picker_dollies = disable_picker_dollies
return M
