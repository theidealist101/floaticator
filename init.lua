floaticator = {}

local env = minetest.request_insecure_environment()
if not env then
    error("floaticator is not trusted")
end

floaticator.save_nodeboxes = function()
    local folder = minetest.get_modpath("floaticator").."/models/"
    for node, defs in pairs(minetest.registered_nodes) do
        if defs.drawtype == "nodebox" and defs.node_box.type ~= "regular" then
            local name = table.concat(string.split(node, ":"), "_")..".obj"
            local file = env.io.open(folder..name, "w+")
            if file then
                local mesh = floaticator.nodebox_to_mesh(defs.node_box)
                if mesh and file:write(mesh) then
                    floaticator.nodebox_meshes[node] = name
                end
                file:close()
            end
        end
    end
end

local path = minetest.get_modpath("floaticator").."/"
dofile(path.."api.lua")
dofile(path.."nodes.lua")