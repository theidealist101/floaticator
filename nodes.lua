--Some settings
local max_dist = minetest.settings:get("floaticator_size_limit") or 16
local speed = minetest.settings:get("floaticator_speed") or 1

--Recursively build floater from position, returning data (possibly empty) or nil if blocked
local function build_floater(pos, push_dir, origin, out)
    local node = minetest.get_node(pos)
    push_dir = push_dir or vector.zero()
    origin = origin or pos
    out = out or {}
    table.insert(out, {pos-origin, node})

    --check it's not too far from start
    if math.abs(pos.x-origin.x) > max_dist or math.abs(pos.y-origin.y) > max_dist or math.abs(pos.z-origin.z) > max_dist then return end

    --try each neighbor in turn
    for i = 0, 5 do
        local dir = minetest.wallmounted_to_dir(i)
        local node2 = minetest.get_node(pos+dir)

        --check if already included
        local included = false
        for _, v in ipairs(out) do
            if v[1]+origin == pos+dir then included = true break end
        end
        if not included then

            --check if connected
            if floaticator.can_connect(node, node2, dir, push_dir) then

                --check if blocked
                if not floaticator.can_move(node2) then return end

                --otherwise try to build more in this direction
                local floater = build_floater(pos+dir, push_dir, origin, out)
                if not floater then return end
            end
        end
    end

    return out
end

--Modified floater step function to allow it to dismantle on collision with a node
local old_on_step = minetest.registered_entities["floaticator:floater"].on_step or function() end

local function floater_on_step(self, dtime, moveresult)
    local dir = vector.normalize(self.object:get_velocity())*0.5
    for i, obj in ipairs(self.object:get_children()) do
        local defs = minetest.registered_nodes[minetest.get_node(vector.round(obj:get_pos()+({obj:get_attach()})[3]*0.1+dir)).name]
        if not defs or defs.walkable or not defs.buildable_to then
            self:dismantle()
            return
        end
    end
    old_on_step(self, dtime, moveresult)
end

--Literally just the floaticator
minetest.register_node("floaticator:floaticator_off", {
    description = "Floaticator",
    tiles = {
        "floaticator_back.png",
        "floaticator_front.png",
        "floaticator_side.png^[transform2",
        "floaticator_side.png^[transform2",
        "floaticator_side.png^[transform2",
        "floaticator_side.png^[transform2"
    },
    paramtype2 = "wallmounted",
    groups = {cracky=3, mesecon_effector_off=1},
    mesecons = {effector={
        action_on = function (pos, node)
            node = table.copy(node)
            node.name = "floaticator:floaticator_on"
            minetest.swap_node(pos, node)
            minetest.get_node_timer(pos):set(1, 1)
        end,
        rules = mesecon.rules.wallmounted_get
    }}
})

minetest.register_node("floaticator:floaticator_on", {
    description = "Floaticator",
    tiles = {
        "floaticator_back_powered.png",
        "floaticator_front.png",
        "floaticator_side.png^[transform2",
        "floaticator_side.png^[transform2",
        "floaticator_side.png^[transform2",
        "floaticator_side.png^[transform2"
    },
    paramtype2 = "wallmounted",
    groups = {cracky=3, mesecon_effector_on=1, not_in_creative_inventory=1},
    drop = "floaticator:floaticator_off",
    mesecons = {effector={
        action_off = function (pos, node)
            node = table.copy(node)
            node.name = "floaticator:floaticator_off"
            minetest.swap_node(pos, node)
        end,
        rules = mesecon.rules.wallmounted_get
    }},
    on_timer = function (pos)
        local node = minetest.get_node(pos)
        local dir = minetest.wallmounted_to_dir(node.param2)
        local floater = build_floater(pos, dir)
        if floater then
            local node_timers = {}
            local metadata = {}
            for _, v in pairs(floater) do
                local p = v[1]+pos
                local timer = minetest.get_node_timer(p)
                local meta = minetest.get_meta(p):to_table()
                minetest.remove_node(p)
                if timer:is_started() then
                    table.insert(node_timers, {v[1], timer:get_timeout(), timer:get_elapsed()})
                end
                if meta.fields ~= {} then
                    table.insert(metadata, {v[1], meta.fields})
                end
            end
            local obj = minetest.add_entity(pos, "floaticator:floater", minetest.serialize({floater, node_timers, metadata}))
            obj:get_luaentity().on_step = floater_on_step
            obj:set_velocity(dir*speed)
            return false
        end
        return true
    end
})

--Debug tool to turn node into node object and vice versa
local function nodeify(_, _, pointed)
    if pointed.type == "node" then
        local node = minetest.get_node(pointed.under)
        minetest.remove_node(pointed.under)
        minetest.add_entity(pointed.under, "floaticator:node", minetest.serialize(node))
    elseif pointed.type == "object" then
        local pos = pointed.ref:get_pos()
        if pointed.ref:get_attach() then pos = pos+({pointed.ref:get_attach()})[3]*0.1 end
        local node = pointed.ref:get_luaentity().node
        if not node then return end
        pointed.ref:remove()
        minetest.set_node(pos, node)
    end
end

minetest.register_craftitem("floaticator:nodeifier", {
    description = "Nodeifier",
    inventory_image = "default_stick.png",
    groups = {not_in_creative_inventory=1},
    on_place = nodeify,
    on_secondary_use = nodeify
})

--Debug nodebox thing
minetest.register_node("floaticator:testcube", {
    description = "Test Cube",
    drawtype = "nodebox",
    tiles = {"testcube0.png", "testcube1.png", "testcube2.png", "testcube3.png", "testcube4.png", "testcube5.png"},
    node_box = {
        type = "fixed",
        fixed = {{-0.5, -0.5, -0.5, 0.5, 0, 0.5}, {-0.5, 0, -0.5, 0, 0.5, 0}}
    },
    groups = {cracky=3, not_in_creative_inventory=1}
})

--[[
--Make players on top of floater move with it
minetest.register_globalstep(function (dtime)
    for i, obj in ipairs(minetest.get_connected_players()) do
        local pos = obj:get_pos()
        local under = minetest.raycast(pos, pos+vector.new(0, -2, 0))
        under:next() --discard the first, this is the player
        under = under:next()
        if under and under.type == "object" and under.ref:get_luaentity() and under.ref:get_luaentity().name == "floaticator:node" then
            local floater = under.ref:get_attach()
            if floater then
                obj:set_attach(floater, "", pos-floater:get_pos(), vector.new(math.deg(obj:get_look_vertical()), math.deg(obj:get_look_horizontal()), 0), false)
            end
        end
    end
end)
]]