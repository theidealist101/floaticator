function floaticator.nodebox_to_mesh(nodebox)
    --assemble list of boxes to use
    local boxes = {}
    if nodebox.type == "fixed" then
        table.insert(boxes, nodebox.fixed)
    end
    local newboxes = {}
    for i, box in ipairs(boxes) do
        if type(box[1]) == "table" then
            table.insert_all(newboxes, box)
        else
            table.insert(newboxes, box)
        end
    end
    --convert all to mesh parts
    local out = {
        "# Auto-generated from nodebox by Floaticator",
        "usemtl none",
        "vn 1 0 0",
        "vn -1 0 0",
        "vn 0 1 0",
        "vn 0 -1 0",
        "vn 0 0 1",
        "vn 0 0 -1",
    }
    for i, box in ipairs(newboxes) do
        table.insert(out, "o box"..i)
        --vertices, order ---, --+, -+-, -++, +--, +-+, ++-, +++
        for _, x in ipairs({-box[4], -box[1]}) do
            for _, y in ipairs({box[2], box[5]}) do
                for _, z in ipairs({box[3], box[6]}) do
                    table.insert(out, table.concat({"v", x, y, z}, " "))
                end
            end
        end
        --textures, same order as coords in faces (placeholder)
        for j = 1, 6 do
            local uv --u1, u2, v1, v2
            if j <= 2 then
                uv = {box[3], box[6], box[2], box[5]} --no x: uv=zy
            elseif j <= 4 then
                uv = {box[1], box[4], box[3], box[6]} --no y: uv=xz
            else
                uv = {box[1], box[4], box[2], box[5]} --no z: uv=xy
            end
            if j%2 == 0 then
                uv = {-uv[1], -uv[2], -uv[3], -uv[4]}
            end
            uv = {uv[1]+0.5, uv[2]+0.5, uv[3]+0.5, uv[4]+0.5}
            table.insert_all(out, {
                table.concat({"vt", uv[1], uv[3]}, " "),
                table.concat({"vt", uv[1], uv[4]}, " "),
                table.concat({"vt", uv[2], uv[4]}, " "),
                table.concat({"vt", uv[2], uv[3]}, " ")
            })
        end
        --faces, should be the same for any box
        table.insert_all(out, {
            "g m1",
            "f -6/-16/3 -5/-15/3 -1/-14/3 -2/-13/3",
            "g m2",
            "f -4/-12/4 -3/-11/4 -7/-10/4 -8/-9/4",
            "g m3",
            "f -4/-24/1 -2/-23/1 -1/-22/1 -3/-21/1",
            "g m4",
            "f -7/-20/2 -5/-19/2 -6/-18/2 -8/-17/2",
            "g m5",
            "f -8/-8/5 -6/-7/5 -2/-6/5 -4/-5/5",
            "g m6",
            "f -3/-4/6 -1/-3/6 -5/-2/6 -7/-1/6",
        })
    end
    return table.concat(out, "\n")
end

floaticator.nodebox_meshes = {}

minetest.register_on_mods_loaded(floaticator.save_nodeboxes)

--Get object properties based on node defs
local function bounding_box(boxes)
    if not boxes then return end
    if type(boxes[1]) == "table" then
        local out = boxes[1]
        for i, box in ipairs(boxes) do
            for c = 1, 3 do
                out[c] = math.min(out[c], box[c])
            end
            for c = 4, 6 do
                out[c] = math.max(out[c], box[c])
            end
        end
        return out
    else
        return boxes
    end
end

local function rotate_box(box, node, defs)
    box = table.copy(box)
    local rotation = floaticator.get_rotation(node, defs)
    --do some matrix multiplication to rotate the nodebox
    local cos, sin = math.cos(rotation.y), math.sin(rotation.y)
    box = {
        cos*box[1]-sin*box[3], box[2], sin*box[1]+cos*box[3],
        cos*box[4]-sin*box[6], box[5], sin*box[4]+cos*box[6]
    }
    return box
end

function floaticator.get_box(nodebox, defs, param2)
    if not nodebox or nodebox.type == "regular" then
        return {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5}
    elseif nodebox.type == "fixed" then
        return rotate_box(bounding_box(nodebox.fixed), {param2=param2}, defs)
    elseif nodebox.type == "wallmounted" then
        if defs.paramtype2 ~= "wallmounted" or param2 == 0 then return bounding_box(nodebox.wall_top) or {-0.5, 0.4375, -0.5, 0.5, 0.5, 0.5}
        elseif param2 == 1 then return bounding_box(nodebox.wall_bottom) or {-0.5, -0.5, -0.5, 0.5, -0.4375, 0.5}
        else return rotate_box(bounding_box(nodebox.wall_side) or {-0.5, -0.5, 0.4375, 0.5, 0.5, 0.5}, {param2=param2}, defs) end --placeholder - can't yet deal with rotated nodeboxes
    else
        return {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5}
    end
end

function floaticator.get_rotation(node, defs)
    defs = defs or minetest.registered_nodes[node.name]
    local param2 = node.param2
    local paramtype2 = defs.paramtype2
    if paramtype2 == "wallmounted" then
        return vector.dir_to_rotation(minetest.wallmounted_to_dir(param2))+vector.new(math.pi*0.5, 0, 0)
    elseif paramtype2 == "4dir" then
        return vector.dir_to_rotation(minetest.fourdir_to_dir(param2))
    elseif paramtype2 == "facedir" then
        return vector.dir_to_rotation(minetest.facedir_to_dir(param2))
    else
        return vector.zero()
    end
end

function floaticator.get_props(node, defs)
    local out = {
        visual = "sprite",
        textures = {"blank.png"},
        physical = false,
        is_visible = false
    }

    if defs and defs.drawtype ~= "airlike" then
        --set up default props for most types
        out.visual = "mesh"
        out.visual_size = {x=10, y=10}
        out.textures = defs.tiles
        for i, texture in ipairs(out.textures) do
            if type(texture) == "table" then
                out.textures[i] = texture.name
            end
        end
        out.physical = defs.walkable
        out.collisionbox = floaticator.get_box(defs.collision_box, defs, node.param2)
        out.selectionbox = floaticator.get_box(defs.selection_box, defs, node.param2)
        out.is_visible = true

        --ordinary cube with all faces visible (disappearing faces will be taken care of by the floater)
        if defs.drawtype == "normal" or defs.drawtype == "allfaces" or defs.drawtype == "allfaces_optional"
        or defs.drawtype == "glasslike" or (defs.drawtype == "nodebox" and defs.node_box.type == "regular") then
            out.visual = "cube"
            out.visual_size = {x=1, y=1}
            while #out.textures < 6 do
                table.insert(out.textures, out.textures[#out.textures])
            end

        --similar but sorting out the textures for glasslike_framed nodes
        elseif defs.drawtype == "glasslike_framed" or defs.drawtype == "glasslike_framed_optional" then
            out.visual = "cube"
            out.visual_size = {x=1, y=1}
            local texture = defs.tiles[1].."^"..defs.tiles[2]
            out.textures = {texture, texture, texture, texture, texture, texture}

        --grass-like node with several faces in a cross shape (currently only the default)
        elseif defs.drawtype == "plantlike" then
            out.mesh = "plantlike.obj"

        --ladder-like node with one face against the bottom of the node
        elseif defs.drawtype == "signlike" then
            out.mesh = "signlike.obj"
        
        --nodebox node, having been converted to a mesh earlier
        elseif defs.drawtype == "nodebox" and defs.node_box.type ~= "regular" then
            out.mesh = floaticator.nodebox_meshes[node.name]

        --basic mesh node
        elseif defs.drawtype == "mesh" then
            out.mesh = defs.mesh

        --if drawtype unsupported, show as airlike
        else
            out.is_visible = false
        end
    end

    return out
end

--Call a function from a floater with alterations to global namespaces
local function local_env(floater, func)
    local old_minetest = minetest
    minetest = table.copy(minetest)

    minetest.get_node = function (pos)
        local obj = floater:get_node_at(pos)
        if not obj then return {name="ignore", param=0, param2=0} end
        return obj:get_luaentity().node
    end

    minetest.swap_node = function (pos, node)
        local obj = floater:get_node_at(pos)
        if not obj then return end
        obj:get_luaentity():set_node(node)
        --floater:update_connects() --drawtype is nil causing floatater to disappear, unknown reason
    end

    local out = func()
    minetest = old_minetest
    return out
end

--Entity representing a node, with all the necessary collision and stuff
minetest.register_entity("floaticator:node", {
    initial_properties = floaticator.get_props(),
    node = {},
    node_defs = {},
    set_node = function (self, node)
        node = node or self.node
        if not node or not node.name then self.object:remove() return end
        local node_defs = minetest.registered_nodes[node.name]
        self.object:set_properties(floaticator.get_props(node, node_defs))
        self.object:set_rotation(floaticator.get_rotation(node, node_defs))
        self.node = node
        self.node_defs = node_defs
    end,
    on_activate = function (self, staticdata)
        if not staticdata or staticdata == "" then self.object:remove() return end
        self:set_node(minetest.deserialize(staticdata))
    end,
    get_staticdata = function (self)
        return minetest.serialize(self.node)
    end,
    connect = function (self, face, node)
        local defs = minetest.registered_nodes[node.name] or {}
        local opaque = defs.drawtype == "normal" --placeholder
        if (((self.node.name == node.name or opaque) and (self.node_defs.drawtype == "glasslike"
        or self.node_defs.drawtype == "glasslike_framed" or self.node_defs.drawtype == "glasslike_framed_optional"))
        or (self.node_defs.drawtype == "normal" and opaque))
        and self.object:get_rotation() == vector.zero() then --temporary fix for rotations
            local props = self.object:get_properties()
            props.textures[face] = "blank.png"
            self.object:set_properties(props)
        end
    end
})

--Collection of node objects considered as one entity
minetest.register_entity("floaticator:floater", {
    initial_properties = {
        visual = "sprite",
        textures = {"blank.png"},
        physical = false
    },
    node_data = {}, --schematics not used because of the contact system: it might overlap other stuff
    node_timers = {},
    metadata = {},
    on_activate = function (self, staticdata, dtime)
        if staticdata and staticdata ~= "" then
            self.node_data, self.node_timers, self.metadata = unpack(minetest.deserialize(staticdata))
            local selfpos = self.object:get_pos()
            for _, pair in ipairs(self.node_data) do
                local obj = minetest.add_entity(selfpos, "floaticator:node", minetest.serialize(pair[2]))
                obj:set_attach(self.object, "", vector.multiply(pair[1], 10), -vector.apply(floaticator.get_rotation(pair[2]), math.deg), false)
            end
            self:update_connects()
        end
    end,
    get_staticdata = function (self)
        return minetest.serialize({self.node_data, self.node_timers, self.metadata})
    end,

    --Remove floater and place all nodes back into the world
    dismantle = function (self)
        local selfpos = self.object:get_pos()
        for i, obj in ipairs(self.object:get_children()) do
            local pos = selfpos+({obj:get_attach()})[3]*0.1
            local node = obj:get_luaentity().node
            if node then
                obj:remove()
                minetest.set_node(pos, node)
            end
        end
        for _, val in ipairs(self.node_timers) do
            minetest.get_node_timer(val[1]+selfpos):set(val[2], val[3])
        end
        for _, val in ipairs(self.metadata) do
            local meta = minetest.get_meta(val[1]+selfpos)
            meta:from_table({fields=val[2], inventory=meta:to_table().inventory})
        end
        self.object:remove()
    end,

    --Update connections of all nodes
    update_connects = function (self)
        for _, obj in ipairs(self.object:get_children()) do
            local entity = obj:get_luaentity()
            entity:set_node()
            local pos = ({obj:get_attach()})[3]*0.1
            for _, pair in ipairs(self.node_data) do
                if vector.distance(pair[1], pos) == 1 then
                    entity:connect(minetest.dir_to_wallmounted(pair[1]-pos)+1, pair[2])
                end
            end
        end
    end,

    --Get child node object at a given position
    get_node_at = function (self, pos)
        for _, obj in ipairs(self.object:get_children()) do
            local p = ({obj:get_attach()})[3]*0.1
            if p-pos == vector.zero() then return obj end
        end
    end,

    --Update node timers
    update_timers = function (self, dtime)
        local removals = {}
        for i, val in ipairs(self.node_timers) do
            val[3] = val[3]+dtime
            if val[3] >= val[2] then
                local node = self:get_node_at(val[1])
                if node and local_env(self, function()
                    local entity = node:get_luaentity()
                    return entity.node_defs.on_timer(val[1])
                end) then
                    val[3] = 0
                else
                    table.insert(removals, i)
                end
            end
        end
        for i = #removals, 1, -1 do
            table.remove(self.node_timers, removals[i])
        end
    end,

    --Do lots of update stuff on step
    on_step = function (self, dtime)
        self:update_timers(dtime)
    end
})