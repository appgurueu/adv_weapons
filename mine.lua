minetest.register_craft({
    output = 'adv_weapons:landmine_placed 3',
    recipe = {
        {'default:steel_ingot', 'default:steel_ingot', 'default:steel_ingot'},
        {'default:steel_ingot', 'tnt:tnt', 'default:steel_ingot'},
        {'default:steel_ingot', 'default:steel_ingot', 'default:steel_ingot'}
    }
})


local size = 0.99 -- in order to get rid of z fighting
local box = {
    type = "fixed",
    fixed = {
        {-size/2, -0.5, -size/2, size/2, -0.5 + size * 3/8, size/2},
    },
}

function clear_meta(pos)
    minetest.get_meta(pos):set_string("owner", "")
end

function on_walk(player)
    if is_opponent(player:get_player_name(), minetest.get_meta(player:get_pos()):get_string("owner")) then
        minetest.remove_node(player:get_pos())
        tnt.boom(player:get_pos(), {radius = 3})
        clear_meta(player:get_pos())
    end
end

local def = {
    description = "Landmine",
    drawtype = "mesh",
    visual_scale = size,
    mesh = "adv_weapons_landmine.obj",
    tiles = {"adv_weapons_landmine.png"},
    selection_box = box,
    collision_box = box,
    sunlight_propagates = true,
    on_place = function(itemstack, placer, pointed_thing)
        if pointed_thing.type ~= "node" then
            return
        end
        if pointed_thing.above.y <= pointed_thing.under.y then
            return
        end
        local pointed_node = minetest.registered_nodes[minetest.get_node(pointed_thing.under).name]
        if pointed_node and pointed_node.collision_box and pointed_node.collision_box.type == "fixed" then
            local is_high_enough = false
            for _, box in pairs(pointed_node.collision_box.fixed) do
                if box[5] == 0.5 then
                    is_high_enough = true
                    break
                end
            end
            if not is_high_enough then
                return
            end
        end
        minetest.item_place(itemstack, placer, pointed_thing)
        local meta = minetest.get_meta(pointed_thing.above)
        meta:set_string("owner", placer:get_player_name())
        itemstack:take_item()
        return itemstack
    end,
    on_blast = function(pos)
        clear_meta(pos)
        minetest.remove_node(pos)
        tnt.boom(pos, {radius = 3})
    end,
    on_punch = function(...)
        clear_meta(...)
        return unpack({minetest.node_dig(...)})
    end
}
local landmines = modlib.table.set({"adv_weapons:landmine_placed", "adv_weapons:landmine_buried"})
-- landmines can be (un)buried by digging below them
minetest.register_on_dignode(function(pos, oldnode, _)
    pos.y = pos.y + 1
    local nodename = minetest.get_node(pos).name
    if nodename == "adv_weapons:landmine_placed" then
        minetest.swap_node(pos, {name = "adv_weapons:landmine_buried"})
        pos.y = pos.y - 1
        minetest.set_node(pos, oldnode)
    elseif nodename == "adv_weapons:landmine_buried" then
        minetest.swap_node(pos, {name = "adv_weapons:landmine_placed"})
        minetest.spawn_falling_node(pos)
    end
end)
minetest.register_node("adv_weapons:landmine_placed", def)
local b = box.fixed[1]
b[2] = b[2] - 0.4
b[5] = b[5] - 0.4
def = modlib.table.copy(def)
-- moving the box down
def.mesh = "adv_weapons_landmine_buried.obj"
def.groups = {not_in_creative_inventory = 1, falling_node = 1}
def.on_punch = def.on_blast
minetest.register_node("adv_weapons:landmine_buried", def)

minetest.register_globalstep(function()
    for _, player in pairs(minetest.get_connected_players()) do
        local standing_on = minetest.get_node(player:get_pos())
        if landmines[standing_on.name] then
            on_walk(player)
        end
    end
end)