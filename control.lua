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

local function get_enemy_evolution_factor(surface)
    local enemy_force = game.forces["enemy"]
    if not enemy_force then return 0 end

    return enemy_force.get_evolution_factor(surface) or 0
end

local function get_update_speed(evo_factor)
    local update_speed = settings.global["wall-repair-delay"].value or 5

    if evo_factor < 0.5 then
        return update_speed * 2
    end

    if evo_factor < 0.7 then
        return update_speed * 1.5
    end

    return update_speed
end

local function do_repairs()
    local repair_queue = storage.repair_queue
    if repair_queue then
        local repairCount = 0
        local removeList = {}
        local repairMult = settings.global["wall-repair-factor"].value or 1
        local maxRepairsPerSecond = settings.global["wall-repair-max"].value  or 100
        for k, v in pairs(repair_queue) do
            local unit = v.entity
            local t = v.tick
            if unit.valid then
                local evo_factor = get_enemy_evolution_factor(unit.surface)
                local update_speed = get_update_speed(evo_factor)

                -- wait for configured delay
                if (game.tick - t > 60 * update_speed) then
                    -- this unit hasn't been damaged recently, begin repair
                    local health_ratio = unit.get_health_ratio()
                    if health_ratio and health_ratio < 1 then
                        unit.health = unit.health + ((30 * repairMult) + (30 * evo_factor))
                        repairCount = repairCount + 1
                    else
                        table.insert(removeList, k)
                    end
                end
            else
                table.insert(removeList, k)
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
