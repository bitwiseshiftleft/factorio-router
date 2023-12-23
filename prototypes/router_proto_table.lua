local M = {}

local sizes = {"4x4"}

M.table = {
    [""] = {
        tint = util.color("ffc340D1"),
        prerequisites = { "circuit-network", "logistics" },
        tech_costs = {
            count = 200,
            ingredients =
            {
                { "automation-science-pack", 1 },
                { "logistic-science-pack", 1 },
            },
            time = 15
        },
        manual_ingredients = {
            {"decider-combinator",20},
        }, smart_ingredients = {
            {"arithmetic-combinator",20}
        }, io_ingredients = {
            {"arithmetic-combinator",10}
        },
    },
    ["fast-"] = {
        tint=util.color("e31717D1"),
        prerequisites = { "logistics-2", "advanced-electronics" },
        tech_costs = {
            count = 300,
            ingredients =
            {
                { "automation-science-pack", 1 },
                { "logistic-science-pack", 1 },
            },
            time = 15
        },
        manual_ingredients = {
            {"advanced-circuit",20}
        }, smart_ingredients = {
            {"advanced-circuit",30}
        }, io_ingredients = {
            {"advanced-circuit",10}
        }
    },
    ["express-"] = {
        tint=util.color("43c0faD1"),
        prerequisites = { "logistics-3", "advanced-electronics-2" },
        tech_costs = {
            count = 500,
            ingredients =
            {
                { "automation-science-pack", 1 },
                { "logistic-science-pack", 1 },
                { "chemical-science-pack", 1 },
                { "production-science-pack", 1 },
            },
            time = 15
        },
        manual_ingredients = {
            {"processing-unit",20}
        },
        smart_ingredients = {
            {"processing-unit",30}
        },
        io_ingredients = {
            {"processing-unit",10}
        }
    }
}

-- Krastorio2 support
local have_k2 = data.raw.item["kr-superior-transport-belt"] ~= nil
if have_k2 then
  M.table["kr-advanced-"] = {
    tint = util.color("3ade21D1"),
    prerequisites = {"kr-logistic-4","kr-ai-core"},
    manual_ingredients = { {"ai-core",4} },
    smart_ingredients =  { {"ai-core",6} },
    io_ingredients    =  { {"ai-core",2} },
    tech_costs = {
        count = 750,
        ingredients =
        {
            { "automation-science-pack", 1 },
            { "logistic-science-pack", 1 },
            { "chemical-science-pack", 1 },
            { "production-science-pack", 1 },
            { "utility-science-pack", 1 },
        },
        time = 15
    },
  }
  M.table["kr-superior-"] = {
    prerequisites = {"kr-logistic-5"},
    tint = util.color("a30bd6D1"),
    manual_ingredients = { {"ai-core",10} },
    smart_ingredients  = { {"ai-core",20} },
    io_ingredients     = { {"ai-core",5} },
    tech_costs = {
        count = 1000,
        ingredients =
        {
            { "production-science-pack", 1 },
            { "utility-science-pack", 1 },
            { "advanced-tech-card", 1}
        },
        time = 15
    },
  }
end

-- Fixup: add automatic ingredients
for prefix,router in pairs(M.table) do
    table.insert(router.manual_ingredients, { prefix.."transport-belt", 8 })
    table.insert(router.manual_ingredients, { prefix.."splitter", 8 })
    table.insert(router.smart_ingredients,  { prefix.."transport-belt", 8 })
    table.insert(router.smart_ingredients,  { prefix.."splitter", 8 })
    table.insert(router.io_ingredients,     { prefix.."transport-belt", 2 })
    table.insert(router.io_ingredients,     { prefix.."splitter", 2 })
end

-- Fixup: add automatic prerequisites for upgrades
for prefix,router in pairs(M.table) do
    local base_underground_item = data.raw["transport-belt"][prefix .. "transport-belt"]
    local next_upgrade = base_underground_item and base_underground_item.next_upgrade
    if have_k2 and prefix == "express-" then next_upgrade = "kr-advanced-" end
    if next_upgrade then
        next_upgrade = string.gsub(next_upgrade, "transport%-belt$", "")
        router.next_upgrade = next_upgrade
        local next_table = next_upgrade and M.table[next_upgrade]
        if next_table then
            -- add it as a prereq techonology
            table.insert(next_table.prerequisites,"router-"..prefix.."router")

            -- add it as a prereq in recipes
            for index,size in ipairs(sizes) do
                table.insert(next_table.manual_ingredients,{"router-"..size.."-"..prefix.."router",1})
                table.insert(next_table.smart_ingredients,{"router-"..size.."-"..prefix.."smart", 1})
                table.insert(next_table.io_ingredients,{"router-"..size.."-"..prefix.."io", 1})
                next_table.had_prereq = true
            end
        end
    end
end

-- Get startup settings
M.enable_manual = settings.startup["router-enable-manual"].value
M.enable_smart  = settings.startup["router-enable-smart"].value

-- Fixup: add dumb routers as a prereq for smart routers, if present
for prefix,router in pairs(M.table) do
    if not router.had_prereq then
        for index,size in ipairs(sizes) do
            if M.enable_manual then
                table.insert(router.smart_ingredients,{"router-"..size.."-"..prefix.."router", 1})
            else
                -- manual routers are disabled; add the costs of the manual router
                for _,ing in ipairs(router.manual_ingredients) do
                    local found = false
                    for index2,ing2 in ipairs(router.smart_ingredients) do
                        if ing2[1] == ing[1] then
                            -- Sum if it's already an ingredient
                            ing2[2] = ing2[2] + ing[2]
                            found = true
                            break
                        end
                    end
                    if not found then
                        -- It's not already an ingredient; add it
                        table.insert(router.smart_ingredients,ing)
                    end
                end
            end
        end
    end
end

return M
