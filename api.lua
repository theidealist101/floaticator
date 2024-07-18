--Convert a nodebox into a mesh file and output that as a string
function floaticator.nodebox_to_mesh(boxes)
    if type(boxes[1]) ~= "table" then boxes = {boxes} end
    --convert all to mesh parts
    local out = {
        "# Auto-generated from nodebox by Floaticator",
        "usemtl none",
        "vn 0 1 0",
        "vn 0 -1 0",
        "vn 1 0 0",
        "vn -1 0 0",
        "vn 0 0 1",
        "vn 0 0 -1",
    }
    local faces = {{}, {}, {}, {}, {}, {}}
    for i, box in ipairs(boxes) do
        --vertices, order ---, --+, -+-, -++, +--, +-+, ++-, +++
        for _, x in ipairs({-box[4], -box[1]}) do
            for _, y in ipairs({box[2], box[5]}) do
                for _, z in ipairs({box[3], box[6]}) do
                    table.insert(out, table.concat({"v", x, y, z}, " "))
                end
            end
        end
        --textures, same order as coords in faces
        for j = 1, 6 do
            local uv --u1, u2, v1, v2
            if j <= 2 then
                uv = {box[1], box[4], box[3], box[6]} --no y: uv=xz
            elseif j <= 4 then
                uv = {box[3], box[6], box[2], box[5]} --no x: uv=zy
            else
                uv = {box[1], box[4], box[2], box[5]} --no z: uv=xy
            end
            if j == 2 or j == 4 or j == 5 then --I have no fucking clue why this works but it does
                uv = {-uv[2], -uv[1], uv[3], uv[4]}
                if j == 2 then
                    uv = {-uv[1], -uv[2], -uv[3], -uv[4]}
                end
            end
            uv = {uv[1]+0.5, uv[2]+0.5, uv[3]+0.5, uv[4]+0.5}
            table.insert_all(out, {
                table.concat({"vt", uv[2], uv[3]}, " "),
                table.concat({"vt", uv[2], uv[4]}, " "),
                table.concat({"vt", uv[1], uv[4]}, " "),
                table.concat({"vt", uv[1], uv[3]}, " ")
            })
        end
        --faces, should be the same for any box
        table.insert(faces[1], {3, 4, 8, 7})
        table.insert(faces[2], {5, 6, 2, 1})
        table.insert(faces[3], {2, 4, 3, 1})
        table.insert(faces[4], {5, 7, 8, 6})
        table.insert(faces[5], {6, 8, 4, 2})
        table.insert(faces[6], {1, 3, 7, 5})
    end
    --add back in the faces
    for i, side in ipairs(faces) do
        table.insert(out, "g m"..i)
        for j, face in ipairs(side) do
            local face_string = {"f "}
            for k, v in ipairs(face) do
                table.insert_all(face_string, {
                    (j-1)*8+v, "/",
                    (j-1)*24+(i-1)*4+k, "/",
                    i, " "
                })
            end
            table.insert(out, table.concat(face_string))
        end
    end

    return table.concat(out, "\n")
end

local nodebox_meshes = {}

local function pack_connections(connections)
    return (connections[1] and 32 or 0)
    +(connections[2] and 16 or 0)
    +(connections[3] and 8 or 0)
    +(connections[4] and 4 or 0)
    +(connections[5] and 2 or 0)
    +(connections[6] and 1 or 0)
end

local function unpack_connections(cp)
    return {cp%64 >= 32, cp%32 >= 16, cp%16 >= 8, cp%8 >= 4, cp%4 >= 2, cp%2 >= 1}
end

local function save_nodebox(node, defs, cp)
    local name = table.concat(string.split(node, ":"), "_")..(cp or "")..".obj"
    local file = floaticator.get_nodebox_file(name)
    if file then
        local connections = cp and unpack_connections(cp)
        local boxes = floaticator.get_boxes(defs.node_box, defs, node.param2, connections)
        local mesh = floaticator.nodebox_to_mesh(boxes)
        if mesh and file:write(mesh) then
            if cp then nodebox_meshes[node][cp] = name
            else nodebox_meshes[node] = name end
        end
        file:close()
    end
end

local function save_nodeboxes()
    for node, defs in pairs(minetest.registered_nodes) do
        if defs.drawtype == "nodebox" and defs.node_box.type ~= "regular" then
            if defs.node_box.type == "connected" then
                nodebox_meshes[node] = {}
                for connect_packed = 0, 63 do
                    save_nodebox(node, defs, connect_packed)
                end
            else
                save_nodebox(node, defs)
            end
        end
    end
end

minetest.register_on_mods_loaded(save_nodeboxes)

--Convert direction vector to side of nodebox
local function dir_to_face(dir)
    return table.indexof({
        vector.new(-1, 0, 0),
        vector.new(0, -1, 0),
        vector.new(0, 0, -1),
        vector.new(1, 0, 0),
        vector.new(0, 1, 0),
        vector.new(0, 0, 1)
    }, dir)
end

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
    box = {
        math.min(box[1], box[4]),
        math.min(box[2], box[5]),
        math.min(box[3], box[6]),
        math.max(box[1], box[4]),
        math.max(box[2], box[5]),
        math.max(box[3], box[6])
    }
    return box
end

function floaticator.get_boxes(nodebox, defs, param2, connections)
    if not nodebox or nodebox.type == "regular" then
        return {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5}
    elseif nodebox.type == "fixed" then
        return nodebox.fixed
    elseif nodebox.type == "wallmounted" then
        if defs.paramtype2 ~= "wallmounted" or param2 == 0 then return nodebox.wall_top or {-0.5, 0.4375, -0.5, 0.5, 0.5, 0.5}
        elseif param2 == 1 then return nodebox.wall_bottom or {-0.5, -0.5, -0.5, 0.5, -0.4375, 0.5}
        else return nodebox.wall_side or {-0.5, -0.5, 0.4375, 0.5, 0.5, 0.5} end
    elseif nodebox.type == "connected" then
        connections = connections or {}
        local out = nodebox.fixed
        if type(out[1]) ~= "table" then out = {out} end
        for i, side in ipairs({"bottom", "top", "right", "left", "back", "front"}) do
            local c, dc = nodebox["connect_"..side], nodebox["disconnect_"..side]
            if connections[i] then
                if c then
                    if type(c[1]) == "table" then table.insert_all(out, c) else table.insert(out, c) end
                end
            elseif dc then
                if type(c[1]) == "table" then table.insert_all(out, dc) else table.insert(out, dc) end
            end
        end
        return out
    else
        return {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5}
    end
end

function floaticator.get_box(nodebox, defs, param2, connections)
    return rotate_box(bounding_box(floaticator.get_boxes(nodebox, defs, param2, connections)), {param2=param2}, defs)
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

function floaticator.get_props(node, defs, connections)
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
        out.collisionbox = floaticator.get_box(defs.collision_box, defs, node.param2, connections)
        out.selectionbox = floaticator.get_box(defs.selection_box, defs, node.param2, connections)
        --BUG: selection_box from defs contains an erroneous fixed box with full block size, collision_box doesn't though
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
            out.mesh = nodebox_meshes[node.name]
            if connections then out.mesh = out.mesh[pack_connections(connections)] end

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

--Get whether two nodes connect to each other
function floaticator.can_connect(node1, node2, dir, push_dir)
    --check a few obvious cases: air, fluids, other game-specific stuff maybe
    if node2.name == "air" or minetest.registered_nodes[node2.name].liquidtype ~= "none" then
        return false
    end

    --check if this is the push direction
    if dir == push_dir then
        return true
    end

    --make sure the nodes allow connection that way
    if node1.name == "floaticator:floaticator_on" and minetest.wallmounted_to_dir(node1.param2) ~= dir
    or node2.name == "floaticator:floaticator_on" and minetest.wallmounted_to_dir(node2.param2) ~= dir then
        return false
    end

    --make sure the nodes are touching each other
    local mult = dir.x+dir.y+dir.z
    local defs1 = minetest.registered_nodes[node1.name]
    local defs2 = minetest.registered_nodes[node2.name]
    local connections = {true, true, true, true, true, true} --placeholder
    local side1 = floaticator.get_box(defs1.selection_box, defs1, node1.param2, connections)[dir_to_face(dir)] or mult*0.5
    local side2 = floaticator.get_box(defs2.selection_box, defs2, node2.param2, connections)[dir_to_face(-dir)] or -mult*0.5
    if side1*mult < 0.5 or side2*-mult < 0.5 then
        return false
    end

    return true
end

--Get whether a node is movable
function floaticator.can_move(node)
    return node.name ~= "ignore"
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
        if node_defs.drawtype == "nodebox" and node_defs.node_box.type == "connected" then
            self.connections = self.connections or {false, false, false, false, false, false}
        else
            self.connections = nil
        end
        self.object:set_properties(floaticator.get_props(node, node_defs, self.connections))
        self.object:set_rotation(floaticator.get_rotation(node, node_defs))
        self.node = node
        self.node_defs = node_defs
    end,
    on_activate = function (self, staticdata)
        if not staticdata or staticdata == "" then self.object:remove() return end
        self:set_node(minetest.deserialize(staticdata))
        self.object:set_armor_groups({immortal=1})
    end,
    get_staticdata = function (self)
        return minetest.serialize(self.node)
    end,
    connect = function (self, face, node)
        local defs = minetest.registered_nodes[node.name] or {}
        local opaque = defs.drawtype == "normal" --placeholder
        local drawtype = self.node_defs.drawtype
        if (((self.node.name == node.name or opaque) and (drawtype == "glasslike"
        or drawtype == "glasslike_framed" or drawtype == "glasslike_framed_optional"))
        or (drawtype == "normal" and opaque))
        and self.object:get_rotation() == vector.zero() then --temporary fix for rotations
            local props = self.object:get_properties()
            props.textures[face] = "blank.png"
            self.object:set_properties(props)
        elseif self.connections and self.node.name == node.name then
            self.connections[face] = true
            self:set_node()
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
        else
            self.object:remove()
            return
        end
        self.object:set_armor_groups({immortal=1})
    end,
    get_staticdata = function (self)
        return minetest.serialize({self.node_data, self.node_timers, self.metadata})
    end,
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
    on_punch = function (self, _, _, _, _, damage)
        if damage >= self.object:get_hp() then
            self:dismantle()
        end
    end,
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
    end
})