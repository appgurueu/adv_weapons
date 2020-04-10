adv_weapons.is_opponent = function(a, b) return a == b end

players = {}
last_use = {}

minetest.register_on_joinplayer(function(player)
    players[player:get_player_name()] = {}
    last_use[player:get_player_name()] = minetest.get_us_time()
end)

minetest.register_globalstep(function()
    for _, player in pairs(minetest.get_connected_players()) do
        local controls = player:get_player_control_bits()
        local rmb = controls >= math.pow(2, 8)
        if rmb then
            local wielded = minetest.registered_items[player:get_wielded_item():get_name()]
            if wielded then
                local action = wielded.on_place or wielded.on_secondary_use or wielded.on_rightclick
                if not action then
                    local lmb = controls >= math.pow(2, 7)
                    if lmb then
                        action = wielded.on_punch or wielded.on_use
                    end
                end
                if action then
                    last_use[player:get_player_name()] = minetest.get_us_time()
                end
            end
        end
    end
end)

minetest.register_on_leaveplayer(function(player)
    players[player:get_player_name()] = nil
    last_use[player:get_player_name()] = nil
end)

function get_rotation(direction)
    return {x = math.atan2(direction.y, math.sqrt(direction.z*direction.z+direction.x*direction.x)), y = -math.atan2(direction.x, direction.z), z = 0}
end

function get_rotation_smooth(direction)
    return {x = math.pi + math.atan2(direction.y, math.sqrt(direction.z*direction.z+direction.x*direction.x)), y = math.pi-math.atan2(direction.x, direction.z), z = 0}
end