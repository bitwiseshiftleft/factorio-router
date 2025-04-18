local M = {}

M.have_stacked_belts = feature_flags.space_travel
local sizes = {"4x4"}
-- Other mod support
local have_cube = mods["Ultracube"] ~= nil
local have_se = data.raw.item["se-space-transport-belt"] ~= nil
local have_ir3 = mods["IndustrialRevolution3"] ~= nil
local have_k2 = data.raw.item["kr-superior-transport-belt"] ~= nil
local have_bobs = data.raw.item["ultimate-transport-belt"] ~= nil
local have_spaceage = feature_flags.space_travel and data.raw.item["turbo-transport-belt"] ~= nil
local have_ae3 = (
  data.raw.technology["advanced-electronics-3"] ~= nil
  and data.raw.item["advanced-logistic-science-pack"] ~= nil
) 
local have_py = mods["pyhightech"]

if have_cube then
  require("__Ultracube__/prototypes/lib/tech_costs")
end

-- Copied from miniloader
local turbo_hex
if mods["boblogistics-belt-reskin"] then
  turbo_hex = "df1ee5D1"
elseif have_bobs then
  turbo_hex = "a510e5D1"
else
  turbo_hex = "aad458D1"
end

local cube_prefix = (have_cube and "cube-") or ""
local blue_chip_name = (have_cube and "cube-spectral-processor") or "processing-unit"

M.table = {
    [""] = {
        tint = util.color("ffc340ff"),
        prerequisites = have_cube and {"cube-combinatorics"}
          or {"circuit-network", "logistics" },
        tech_costs = have_cube and tech_cost_unit("0",100) or {
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
        tint=util.color("e31717ff"),
        prerequisites = {
          (have_cube and "cube-logistics") or "logistics-2",
          (have_py and "basic-electronics") or
          (have_cube and "cube-advanced-electronics")
          or "advanced-circuit" },
        tech_costs = have_cube and tech_cost_unit("1b", 300) or {
            count = 300,
            ingredients =
            {
                { "automation-science-pack", 1 },
                { "logistic-science-pack", 1 },
            },
            time = 15
        },
        manual_ingredients = {
            {cube_prefix.."advanced-circuit",20}
        }, smart_ingredients = {
            {cube_prefix.."advanced-circuit",30}
        }, io_ingredients = {
            {cube_prefix.."advanced-circuit",10}
        }
    },
    ["express-"] = {
        tint=util.color("43c0faff"),
        prerequisites = {
          (have_cube and "cube-express-logistics") or "logistics-3", blue_chip_name },
        tech_costs = have_cube and tech_cost_unit("2", 300) or {
            count = 500,
            ingredients =
            have_se and  {
                { "automation-science-pack", 1 },
                { "logistic-science-pack", 1 },
                { "chemical-science-pack", 1 }
            } or {
                { "automation-science-pack", 1 },
                { "logistic-science-pack", 1 },
                { "chemical-science-pack", 1 },
                { "production-science-pack", 1 },
            },
            time = 15
        },
        manual_ingredients = {
            {blue_chip_name,20}
        },
        smart_ingredients = {
            {blue_chip_name,30}
        },
        io_ingredients = {
            {blue_chip_name,10}
        }
    }
}

-- Py support
if have_py then
  table.insert(M.table["fast-"].tech_costs.ingredients, {"py-science-pack-2",1})
  M.table["fast-"].tech_costs.count = 1800
  M.table["express-"].tech_costs.count = 1000
  M.table[""].tech_costs.count = 300
end

-- IR3 support
if have_ir3 then
  table.insert(M.table["fast-"].tech_costs.ingredients, {"chemical-science-pack",1})
  M.table["fast-"].tech_costs.count = 400
  M.table["express-"].tech_costs.count = 1000
end

-- Krastorio2 support
if have_k2 and have_se then
  M.table["kr-advanced-"] = {
    tint = util.color("3ade21D1"),
    prerequisites = {"kr-logistic-4","se-energy-science-pack-1"},
    manual_ingredients = { {"imersium-gear-wheel",4}, {"se-energy-catalogue-1", 8} },
    smart_ingredients =  { {"imersium-gear-wheel",6}, {"se-energy-catalogue-1", 12} },
    io_ingredients    =  { {"imersium-gear-wheel",2}, {"se-energy-catalogue-1", 4} },
    tech_costs = {
      count = 750,
      ingredients = {
        { "automation-science-pack", 1 },
        { "logistic-science-pack", 1 },
        { "chemical-science-pack", 1 },
        { "production-science-pack", 1 },
        { "utility-science-pack", 1 },
        { "space-science-pack", 1 },
        { "se-energy-science-pack-1", 1 },
        { "se-material-science-pack-1", 1 },
      },
      time = 15
    },
  }
  M.table["kr-superior-"] = {
    prerequisites = {"kr-logistic-5","kr-ai-core"},
    tint = util.color("a30bd6D1"),
    manual_ingredients = { {"ai-core",10}, {"se-material-catalogue-2", 10} },
    smart_ingredients  = { {"ai-core",20}, {"se-material-catalogue-2", 20} },
    io_ingredients     = { {"ai-core",5} , {"se-material-catalogue-2", 50} },
    tech_costs = {
      count = 1000,
      ingredients = {
        { "automation-science-pack", 1 },
        { "logistic-science-pack", 1 },
        { "chemical-science-pack", 1 },
        { "production-science-pack", 1 },
        { "utility-science-pack", 1 },
        { "space-science-pack", 1 },
        { "se-energy-science-pack-3", 1 },
        { "se-biological-science-pack-3", 1 },
        { "se-material-science-pack-2", 1 },
        { "kr-optimization-tech-card", 1 }
      },
      time = 15
    },
  }
elseif have_cube then
  M.table["cube-v4-"] = {
    tint = util.color("a30bd6D1"),
    prerequisites = {"cube-v4-logistics"},
    manual_ingredients = { {"cube-spectral-processor",40}, {"cube-advanced-engine",10} },
    smart_ingredients =  { {"cube-spectral-processor",60}, {"cube-advanced-engine",15} },
    io_ingredients    =  { {"cube-spectral-processor",20}, {"cube-advanced-engine",5} },
    tech_costs = tech_cost_unit("3", 500)
  }
elseif have_k2 then
  M.table["kr-advanced-"] = {
    tint = util.color("3ade21D1"),
    prerequisites = {"kr-logistic-4","kr-ai-core"},
    manual_ingredients = { {"ai-core",4} },
    smart_ingredients =  { {"ai-core",6} },
    io_ingredients    =  { {"ai-core",2} },
    tech_costs = {
      count = 750,
      ingredients = {
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
      ingredients = {
          { "production-science-pack", 1 },
          { "utility-science-pack", 1 },
          { "advanced-tech-card", 1}
      },
      time = 15
    },
  }
end

if have_se then
    M.table["se-space-"] = {
      tint = util.color("ffffff"),
      prerequisites = {"se-space-belt","router-express-router","space-science-pack"},
      manual_ingredients = { {"processing-unit",40}, {"electric-engine-unit",8}, {"low-density-structure",15}, {"decider-combinator", 20} },
      smart_ingredients =  { {"processing-unit",60}, {"electric-engine-unit",12}, {"low-density-structure",20}, {"arithmetic-combinator", 20} },
      io_ingredients    =  { {"processing-unit",20}, {"electric-engine-unit",4}, {"low-density-structure",10}, {"arithmetic-combinator", 10} },
      tech_costs = {
        count = 750,
        ingredients =
        {
            { "automation-science-pack", 1 },
            { "logistic-science-pack", 1 },
            { "chemical-science-pack", 1 },
            { "se-rocket-science-pack", 1 },
            { "space-science-pack", 1 },
        },
        time = 15
      },
      is_space = true,
      -- Nah, SE does this manually and so can we
      -- next_upgrade = "se-deep-space-"
    }

  M.table["se-deep-space-"] = {
    tint = util.color("00ffff"), -- idk cyan
    postfix = "-cyan",
    prerequisites = {"se-deep-space-transport-belt","router-se-space-router"},
    manual_ingredients = { {"se-nanomaterial",20}, {"se-heavy-bearing",20}, {"se-naquium-plate", 20}, {"se-aeroframe-scaffold", 20} },
    smart_ingredients =  { {"se-nanomaterial",30}, {"se-heavy-bearing",30}, {"se-naquium-plate", 30}, {"se-aeroframe-scaffold", 30} },
    io_ingredients    =  { {"se-nanomaterial",10}, {"se-heavy-bearing",10}, {"se-naquium-plate", 10}, {"se-aeroframe-scaffold", 10} },
    tech_costs = {
      count = 750,
      ingredients =
      {
        { "automation-science-pack", 1 },
        { "logistic-science-pack", 1 },
        { "chemical-science-pack", 1 },
        { "se-rocket-science-pack", 1 },
        { "se-astronomic-science-pack-4", 1 },
        { "se-energy-science-pack-4", 1 },
        { "se-material-science-pack-4", 1 },
        { "se-biological-science-pack-4", 1 },
        { "se-deep-space-science-pack-2", 1 },
      },
      time = 15
    },
    is_space = true
  }
end

if have_bobs and have_ae3 then
  M.table["turbo-"] = {
    tint = util.color(turbo_hex),
    prerequisites = {"logistics-4","advanced-electronics-3"},
    manual_ingredients = { {"advanced-processing-unit", 4} },
    smart_ingredients =  { {"advanced-processing-unit", 6} },
    io_ingredients    =  { {"advanced-processing-unit", 2} },
    tech_costs = {
      count = 300,
      ingredients = {
        { "automation-science-pack", 1 },
        { "logistic-science-pack", 1 },
        { "chemical-science-pack", 1 },
        { "production-science-pack", 1 },
      },
      time = 15
    },
  }
  M.table["ultimate-"] = {
    tint = util.color("16f263D1"),
    prerequisites = {"logistics-5"},
    manual_ingredients = { {"advanced-processing-unit", 12} },
    smart_ingredients =  { {"advanced-processing-unit", 18} },
    io_ingredients    =  { {"advanced-processing-unit", 6} },
    tech_costs = {
      count = 300,
      ingredients = {
        { "automation-science-pack", 1 },
        { "logistic-science-pack", 1 },
        { "chemical-science-pack", 1 },
        { "production-science-pack", 1 },
        { "advanced-logistic-science-pack", 1 },
      },
      time = 15
    },
  }
elseif have_bobs then
  M.table["turbo-"] = {
    tint = util.color(turbo_hex),
    prerequisites = {"logistics-4"},
    manual_ingredients = { {"processing-unit", 40} },
    smart_ingredients =  { {"processing-unit", 60} },
    io_ingredients    =  { {"processing-unit", 20} },
    tech_costs = {
      count = 300,
      ingredients = {
        { "automation-science-pack", 1 },
        { "logistic-science-pack", 1 },
        { "chemical-science-pack", 1 },
        { "production-science-pack", 1 },
      },
      time = 15
    },
  }
  M.table["ultimate-"] = {
    tint = util.color("16f263D1"),
    prerequisites = {"logistics-5"},
    manual_ingredients = { {"processing-unit", 120} },
    smart_ingredients =  { {"processing-unit", 180} },
    io_ingredients    =  { {"processing-unit", 60} },
    tech_costs = {
      count = 300,
      ingredients = {
        { "automation-science-pack", 1 },
        { "logistic-science-pack", 1 },
        { "chemical-science-pack", 1 },
        { "production-science-pack", 1 }
      },
      time = 15
    },
  }
elseif have_spaceage then
  M.table["turbo-"] = {
    tint = util.color(turbo_hex),
    prerequisites = {"turbo-transport-belt","utility-science-pack"},
    tech_costs = {
        count = 800,
        ingredients =
        {
          {"automation-science-pack", 1},
          {"logistic-science-pack", 1},
          {"chemical-science-pack", 1},
          {"production-science-pack", 1},
          {"utility-science-pack", 1},
          {"space-science-pack", 1},
          {"metallurgic-science-pack", 1}
        },
        time = 60
    },
    manual_ingredients = {
        {"processing-unit",60}
    },
    smart_ingredients = {
        {"processing-unit",90}
    },
    io_ingredients = {
        {"processing-unit",30}
    }
  }
end

-- Fixup: add automatic ingredients and power consumption
local power_scale =  settings.startup["router-power-scale"].value
for prefix,router in pairs(M.table) do
    local postfix = router.postfix or ""
    local belt = data.raw["transport-belt"][prefix.."transport-belt"..postfix]
    if belt then
        table.insert(router.manual_ingredients, { prefix.."transport-belt"..postfix or "", 8 })
        table.insert(router.manual_ingredients, { prefix.."splitter"..postfix, 8 })
        table.insert(router.smart_ingredients,  { prefix.."transport-belt"..postfix, 8 })
        table.insert(router.smart_ingredients,  { prefix.."splitter"..postfix, 8 })
        table.insert(router.io_ingredients,     { prefix.."transport-belt"..postfix, 2 })
        table.insert(router.io_ingredients,     { prefix.."splitter"..postfix, 2 })
        local speed = belt.speed
        router.power = router.power or math.floor(speed * speed * 480 * 480 * power_scale / 100)
    end
end

-- Fixup: add automatic prerequisites for upgrades
for prefix,router in pairs(M.table) do
    local base_underground_item = data.raw["transport-belt"][prefix .. "transport-belt"]
    local next_upgrade = base_underground_item and base_underground_item.next_upgrade
    if have_k2 and prefix == "express-" then next_upgrade = "kr-advanced-" end
    if next_upgrade then
        next_upgrade = string.gsub(next_upgrade, "transport%-belt$", "")
        local next_table = next_upgrade and M.table[next_upgrade]
        if next_table then
            -- add it as an upgrade
            if router.next_upgrade == nil then router.next_upgrade = next_upgrade end

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
