local wall_filters = {
    {filter = "type", type = "wall"},
    {filter = "type", type = "gate"}
}

local function ensure_queue()
    storage.repair_queue = storage.repair_queue or storage.RepairQueue or {}
    storage.RepairQueue = nil
    return storage.repair_queue
end

local function queue_repairs(entity, tick)
    if not (entity and entity.valid) then return end
    if entity.type ~= "wall" and entity.type ~= "gate" then return end
    if not entity.unit_number then return end

    local repair_queue = ensure_queue()
    repair_queue[entity.unit_number] = {
        entity = entity,
        tick = tick
    }
end

local function do_repairs()
    local repairCount = 0
    local evoFactor = game.forces["enemy"].evolution_factor
    local updateSpeed = settings.global["wall-repair-delay"].value or 5

    if( evoFactor < 0.5) then 
        updateSpeed = updateSpeed * 2
    else 
        if (evoFactor < 0.7) then
            updateSpeed = updateSpeed * 1.5
        end
    end
    local repair_queue = storage.repair_queue
    if repair_queue then
        local removeList = {}
        local repairMult = settings.global["wall-repair-factor"].value or 1
        local maxRepairsPerSecond = settings.global["wall-repair-max"].value  or 100
        for k, v in pairs(repair_queue) do
            local unit = v.entity
            local t = v.tick
            -- wait for configured delay
            if (game.tick - t > 60 * updateSpeed) then
                -- this unit hasn't been damaged recently, begin repair
                if unit.valid then
                    local health_ratio = unit.get_health_ratio()
                    if health_ratio and health_ratio < 1 then
                        unit.health = unit.health + ((30 * repairMult) + (30 * evoFactor))
                        repairCount = repairCount + 1
                    else
                        table.insert(removeList, k)
                    end
                else
                    table.insert(removeList, k)
                end
            end
            if(repairCount > maxRepairsPerSecond) then break end
        end
        for _, v in pairs(removeList) do
            repair_queue[v] = nil
        end
    end
end

script.on_init(ensure_queue)
script.on_configuration_changed(ensure_queue)

script.on_event(
    defines.events.on_entity_damaged,
    function(event)
        queue_repairs(event.entity, event.tick)
    end,
    wall_filters
)

script.on_event(
    defines.events.on_built_entity,
    function(event)
        queue_repairs(event.entity, event.tick)
    end,
    wall_filters
)

script.on_event(
    defines.events.on_robot_built_entity,
    function(event)
        queue_repairs(event.entity, event.tick)
    end,
    wall_filters
)

script.on_nth_tick(60, do_repairs)
