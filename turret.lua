minetest.register_craft({
    output = 'adv_weapons:turret_base',
    recipe = {
        {'default:steel_ingot', 'default:steel_ingot', 'default:steel_ingot'},
        {'default:steel_ingot', '', 'default:steel_ingot'},
        {'default:steel_ingot', '', 'default:steel_ingot'}
    }
})

minetest.register_craft({
    output = 'adv_weapons:gatlin_barrel',
    recipe = {
        {'default:steel_ingot', 'default:diamond', 'default:steel_ingot'},
        {'default:steel_ingot', 'default:mese_crystal', 'default:steel_ingot'},
        {'default:steel_ingot', 'default:diamond', 'default:steel_ingot'}
    }
})

local function target_player(self, player)
    local player_pos = player:get_pos()
    player_pos.y = player_pos.y + player:get_properties().eye_height
    local eye_pos = vector.add(self.object:get_pos(), vector.multiply(vector.direction(self.object:get_pos(), player_pos), 0.75))
    if is_opponent(self._owner, player:get_player_name()) and player_pos.y >= self.object:get_pos().y
        and minetest.line_of_sight(eye_pos, player_pos) then
        local distance = vector.distance(self.object:get_pos(), player_pos)
        if distance < 20 then
            return distance
        end
    end
    return false
end

minetest.register_entity("adv_weapons:turret_gatlin_barrel", {
    initial_properties = {
        hp = 1,
        visual = "mesh",
        mesh = "adv_weapons_gatlin_barrel.obj",
        visual_size = {x = 8, y = 8, z = 8},
        textures = {"adv_weapons_grappling_hook_texture.png"},
        physical = false,
        collide_with_objects = false,
        collisionbox = {0,0,0,0,0,0},
        pointable = false,
        infotext = "Gatlin Barrel"
    },
    on_activate = function(self, staticdata)
        self.object:set_armor_groups({immortal = 1})
        self._dtime = 0
        self._owner = staticdata
    end,
    get_staticdata = function(self)
        return self._owner
    end,
    on_step = function(self, dtime)
        if minetest.get_node(self.object:get_pos()).name ~= "adv_weapons:turret_base" then
            self.object:remove()
            minetest.add_item(self.object:get_pos(), "adv_weapons:gatlin_barrel")
            return
        end
        self._dtime = self._dtime + dtime
        local target_ref
        if self._target then
            target_ref = minetest.get_player_by_name(self._target)
            if not target_player(self, target_ref) then
                target_ref = nil
            end
        end
        if not target_ref then
            local min_distance = math.huge
            for _, player in pairs(minetest.get_connected_players()) do
                local distance = target_player(self, player)
                if distance then
                    if distance < min_distance then
                        min_distance = distance
                        target_ref = player
                    end
                end
            end
        end
        if target_ref then
            local player_pos = target_ref:get_pos()
            player_pos.y = player_pos.y + target_ref:get_properties().eye_height
            self._target_rotation = get_rotation(vector.direction(self.object:get_pos(), player_pos))
        end
        if self._target_rotation then
            local total_diff = vector.subtract(self._target_rotation, self.object:get_rotation())
            total_diff = vector.apply(total_diff, function(c)
                if math.abs(c) > math.pi then
                    return -(2*math.pi-c)
                end
                return c
            end)
            local diff = vector.length(total_diff)
            if diff < 0.1 then -- time for SHOOT
                if self._dtime > 0.5 then
                    local r = self.object:get_rotation()
                    local d = {}
                    -- x rotation
                    d.y = math.sin(r.x)
                    d.z = math.cos(r.x)
                    -- y rotation
                    d.x = -(d.z * math.sin(r.y))
                    d.z = d.z * math.cos(r.y)
                    local start = vector.add(self.object:get_pos(), vector.multiply(d, 0.75))
                    minetest.add_particle({
                        pos = start,
                        velocity = vector.multiply(d, 10),
                        --acceleration = {x=0, y=0, z=0},
                        expirationtime = 10,
                        size = 0.2,
                        collisiondetection = true,
                        collision_removal = true,
                        object_collision = true,
                        glow = 14,
                        texture = "adv_weapons_bullet.png",
                    })
                    for thing in minetest.raycast(start, vector.add(start, vector.multiply(d, 20)), true, true) do
                        if thing.type ~= "object" then
                            break
                        end
                        thing.ref:punch(self.object, 1, {full_punch_interval=1, damage_groups = {fleshy=2}}, d)
                    end
                    self._dtime = 0
                end
            end
            if diff < 0.05 then
                self.object:set_rotation(self._target_rotation)
            else
                local rotate = vector.add(self.object:get_rotation(), vector.multiply(total_diff, math.min(1, dtime*2)))
                self.object:set_rotation(rotate)
            end
        end
    end
})

-- HACK should use item instead
minetest.register_node("adv_weapons:gatlin_barrel", {
    groups = {not_in_creative_inventory = 1},
    description = "Gatlin Barrel",
    drawtype = "mesh",
    mesh = "adv_weapons_gatlin_barrel.obj",
    tiles = {"adv_weapons_grappling_hook_texture.png"},
    on_place = function(itemstack, placer, pointed_thing)
        if pointed_thing.type ~= "node" then
            return
        end
        if minetest.get_node(pointed_thing.under).name ~= "adv_weapons:turret_base" then
            return
        end
        local above = vector.add(pointed_thing.under, {x=0, y=0.3, z=0})
        local ent = minetest.add_entity(above, "adv_weapons:turret_gatlin_barrel")
        ent:get_luaentity()._owner = placer:get_player_name()
        itemstack:take_item()
        return itemstack
    end
})

minetest.register_node("adv_weapons:turret_base", {
    paramtype = "light",
    sunlight_propagates = true,
    groups = {cracky = 1, level = 3, falling_node = 1},
    --[[collisionbox = {
        type = "fixed",
        fixed = {
            {-0.5, -0.5, -0.5, 0.5, 0, 0.5},
        },
    },]]
    description = "Turret Base",
    drawtype = "mesh",
    mesh = "adv_weapons_turret_base.obj",
    tiles = {"adv_weapons_grappling_hook_texture.png"}
})