floaticator = {}

local env = minetest.request_insecure_environment()
if not env then
    error("Floaticator needs to be trusted in order to load nodeboxes correctly")
end

local folder = minetest.get_modpath("floaticator").."/models/"

function floaticator.get_nodebox_file(name)
    return env.io.open(folder..name, "w+")
end

local path = minetest.get_modpath("floaticator").."/"
dofile(path.."api.lua")
dofile(path.."nodes.lua")