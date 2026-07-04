local function has_value(tab, val)
    for _, value in ipairs(tab) do
        if value == val then
            return true
        end
    end

    return false
end

local function add_not_repairable_flag(prototypes)
    if not prototypes then return end

    for _, prototype in pairs(prototypes) do
        prototype.flags = prototype.flags or {}
        if not has_value(prototype.flags, "not-repairable") then
            table.insert(prototype.flags, "not-repairable")
        end
    end
end

add_not_repairable_flag(data.raw["wall"])
add_not_repairable_flag(data.raw["gate"])
