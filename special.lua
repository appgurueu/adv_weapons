minetest.register_craft({
    output = 'adv_weapons:grappling_hook',
    recipe = {
        {'default:steel_ingot', 'default:steel_ingot', 'default:steel_ingot'},
        {'', 'default:mese_crystal', 'default:steel_ingot'},
        {'default:diamond', '', 'default:steel_ingot'}
    }
})

function set_rotation(obj, size)
    obj:set_rotation({x = math.atan2(size.y, math.sqrt(size.z*size.z+size.x*size.x)), y = -math.atan2(size.x, size.z), z = 0})
end

--[[minetest.register_tool("adv_weapons:whip", {
    description = "Whip",
    range = 7,
    inventory_image = "adv_weapons_whip.png",
    tool_capabilities = {bloody = 1, stunny = 1},
    on_use = function(itemstack, user, pointed_thing)
        if pointed_thing and pointed_thing.type == "object" then
            local victim = pointed_thing.ref
            if user then
                local time_since_last = (minetest.get_us_time() - last_use[user:get_player_name()]) / 1000000
                victim:punch(user, time_since_last, {bloody = 1, stunny = 1})
                itemstack:add_wear(1000)
            end
        end
        itemstack:add_wear(100)
        return itemstack
    end,
    on_secondary_use = function(itemstack, user, pointed_thing)
        if pointed_thing and pointed_thing.type == "object" then
            local victim = pointed_thing.ref
            if victim:is_player() then
                local wield_name = victim:get_wielded_item():get_name()
                local wield_def = minetest.registered_items[wield_name]
                if wield_name and wield_def and wield_def.on_drop then
                    victim:set_wielded_item(wield_def.on_drop(victim:get_wielded_item(), victim, {x=0, y=victim:get_properties().eye_height, z=0}))
                end
            end
            itemstack:add_wear(2000)
        end
        itemstack:add_wear(100)
        return itemstack
    end
})]]

local re = "aw_bs.png"
local rs = "blank.png"
minetest.register_entity("adv_weapons:beam", {
    initial_properties = {
        hp = 1,
        visual = "cube",
        visual_size = {x = 0, y = 0, z = 0},
        textures = {rs,rs,rs,rs,re,re},
        physical = false,
        collide_with_objects = false,
        collisionbox = {0,0,0,0,0,0},
        pointable = false,
        infotext = "Rope",
        glow = 14
    },
    on_activate = function(self, staticdata)
        self.object:set_armor_groups({immortal = 1})
        if staticdata == "deleteme" then
            self.object:remove()
            return
        end
        if staticdata ~= "" then
            local size = minetest.parse_json(staticdata)
            adjust_rope(self.object, size)
        end
    end,
    get_staticdata = function(self)
        return "deleteme"
        --return (self._size and minetest.write_json(self._size)) or ""
    end,
})

function check_pos(pos)
    local node = minetest.registered_nodes[minetest.get_node(pos).name]
    return node and node.walkable ~= false
end

function check_hooked(self)
    local obj = self.object
    local checked = {}
    for _, offset in pairs({vector.multiply(vector.normalize(self._.last_velocity), 0.4), {x = 0, y = -0.2, z = 0}}) do
        local hook_pos = vector.add(obj:get_pos(), offset)
        local check = true
        for _, pos in pairs(checked) do
            if vector.equals(pos, hook_pos) then
                check = false
                break
            end
        end
        if check then
            if check_pos(hook_pos) then
                return true
            end
            table.insert(checked, vector.floor(hook_pos))
        end
    end
end

local function remove_ascent_aid(self)
    if self._owner then
        local clicker = minetest.get_player_by_name(self._owner)
        clicker:set_properties({visual_size = vector.new(1,1,1)})
        if player_api then
            player_api.player_attached[clicker:get_player_name()] = nil
            minetest.after(0.1, function()
                player_api.set_animation(clicker, "stand", 30)
            end)
        end
    end
end

local gt = "adv_weapons_grappling_hook_texture.png"
minetest.register_entity("adv_weapons:grappling_hook", {
    initial_properties = {
        hp = 1,
        visual = "mesh",
        mesh = "adv_weapons_grappling_hook.obj",
        visual_size = {x = 10, y = 10, z = 10},
        textures = {gt,gt,gt,gt,gt,gt},
        physical = true,
        collide_with_objects = true,
        collisionbox = {-0.2,-0.2,-0.2,0.2,0.2,0.2},
        infotext = "Grappling Hook"
    },
    on_step = function(self, dtime)
        local obj = self.object
        if self._.last_velocity then
            if self._.hooked then
                if self._last_check < 0.5 then
                    self._last_check = self._last_check + dtime
                elseif not check_hooked(self) then
                    if self._ascent_aid then
                        remove_ascent_aid(self._ascent_aid:get_luaentity())
                        self._ascent_aid:remove()
                        self._ascent_aid = nil
                    end
                    if self._rope then
                        self._rope:remove()
                        self._rope = nil
                    end
                    self._.hooked = false
                    self._.last_velocity = obj:get_velocity()
                    obj:set_acceleration{x=0, y=-9.81, z=0}
                end
                return
            end
            local expected_vel = vector.add(self._.last_velocity, vector.multiply(obj:get_acceleration(), dtime))
            local thresh_diff = vector.length(vector.subtract(expected_vel, obj:get_velocity()))
            if thresh_diff >= 0.05 and check_hooked(self) then
                self._.hooked = true
                self._last_check = 0
                obj:set_velocity{x=0, y=0, z=0}
                obj:set_acceleration{x=0, y=0, z=0}
                set_rotation(obj, self._.last_velocity)
                if self._origin then
                    local end_pos = vector.add(obj:get_pos(), vector.multiply(vector.normalize(self._.last_velocity), -0.4))
                    local d = vector.distance(end_pos, self._origin)
                    if d < 1 then
                        return
                    end
                    if d > 20 then
                        local dir = vector.normalize(vector.subtract(self._origin, end_pos))
                        self._origin = vector.add(vector.multiply(dir, 20), end_pos)
                    end
                    local ascent_aid = minetest.add_entity(self._origin, "adv_weapons:ascent_aid")
                    self._ascent_aid = ascent_aid
                    local aid_dir = vector.subtract(end_pos, self._origin)
                    ascent_aid:get_luaentity()._direction = vector.normalize(aid_dir)
                    ascent_aid:get_luaentity()._origin = self._origin
                    ascent_aid:get_luaentity()._length = vector.length(aid_dir)
                    set_rotation(ascent_aid, vector.normalize(aid_dir))
                    self._rope = spawn_rope(end_pos, self._origin)
                end
                return
            end
        end
        -- slowdown (air resistance)
        obj:set_velocity(vector.multiply(obj:get_velocity(), math.pow(0.99, dtime)))
        local size = obj:get_velocity()
        self._.last_velocity = obj:get_velocity()
        -- rotate properly
        set_rotation(obj, size)
    end,
    on_punch = function(self, clicker)
        if self._.hooked then
            local inv = clicker:get_inventory()
            if inv:room_for_item("main", "adv_weapons:grappling_hook") then
                inv:add_item("main", "adv_weapons:grappling_hook")
                if self._ascent_aid then
                    remove_ascent_aid(self._ascent_aid:get_luaentity())
                    self._ascent_aid:remove()
                    self._ascent_aid = nil
                end
                if self._rope then
                    self._rope:remove()
                    self._rope = nil
                end
                self.object:remove()
            end
        end
    end,
    on_activate = function(self, staticdata)
        self.object:set_armor_groups({immortal = 1})
        self._ = self._ or {}
        if staticdata ~= "" then
            local parsed = minetest.parse_json(staticdata)
            if parsed then
                modlib.table.add_all(self._, parsed)
            end
        end
        if self._.hooked then
            self._last_check = 0
        end
    end,
    get_staticdata = function(self)
        return minetest.write_json(self._)
    end,
})

local aa_box = {-0.1,0.01,-0.1,0.1,0.1,0.1}
minetest.register_entity("adv_weapons:ascent_aid", {
    initial_properties = {
        hp = 1,
        visual = "cube",
        visual_size = {x = 0.4, y = 0.2, z = 0.4},
        textures = {gt,gt,gt,gt,gt,gt},
        collisionbox = aa_box,
        selectionbox = {-0.2,-0.1,-0.2,0.2,0.1,0.2},
        physical = true,
        infotext = "Ascent Aid"
    },
    on_activate = function(self, staticdata)
        self.object:set_armor_groups({immortal = 1})
        if staticdata == "deleteme" then
            self.object:remove()
            return
        end
        if staticdata ~= "" then
            self._size = minetest.parse_json(staticdata)
            adjust_rope(self.object, size)
        end
    end,
    get_staticdata = function(self)
        return "deleteme"
        --return (self._size and minetest.write_json(self._size)) or ""
    end,
    on_rightclick = function(self, clicker)
        if vector.distance(self.object:get_pos(), clicker:get_pos()) >= 1 then
            return
        end
        if clicker:get_attach() == self.object then
            clicker:set_detach()
            self.object:set_properties({collisionbox = aa_box, selectionbox = {-0.2,-0.1,-0.2,0.2,0.1,0.2}})
            self._owner = nil
            clicker:set_properties({visual_size = vector.new(1,1,1)})
            if player_api then
                player_api.player_attached[clicker:get_player_name()] = nil
                minetest.after(0.1, function()
                    player_api.set_animation(clicker, "stand", 30)
                end)
            end
            return
        end
        clicker:set_attach(self.object, "", {x = 0, y = 12, z = 0}, {x = 180, y = 0, z = 0})
        --local box = modlib.table.copy(clicker:get_properties().collisionbox)
        --box[2] = box[2] + 0.01
        --self.object:set_properties({collisionbox = box, selectionbox = {-0.2,-0.1,-0.2,0.2,0.1,0.2}})
        clicker:set_properties({visual_size = vector.divide(vector.new(1,1,1), {x = 0.4, y = 0.2, z = 0.4})})
        self._owner = clicker:get_player_name()
        if player_api then
            player_api.player_attached[clicker:get_player_name()] = true
            minetest.after(0.1, function()
                player_api.set_animation(clicker, "lay", 30)
            end)
        end
        clicker:set_look_horizontal(self.object:get_yaw())
    end,
    on_step = function(self, dtime)
        local obj = self.object
        obj:set_velocity(vector.multiply(obj:get_velocity(), math.pow(0.75, dtime)))
        local speed = vector.length(obj:get_velocity())
        if speed < 0.1 then
            obj:set_velocity(vector.new(0,0,0))
        end
        local line_off
        if self._origin then
            local translated = vector.subtract(obj:get_pos(), self._origin)
            line_off = math.min(self._length-0.1, math.max(0.1, vector.dot(translated, self._direction)))
            local closest = vector.add(vector.multiply(self._direction, line_off), self._origin)
            local diff = vector.length(vector.subtract(obj:get_pos(), closest))
            if diff >= 0.11 then
                obj:set_velocity(vector.new(0,0,0))
                obj:set_pos(closest)
                return
            end
        end
        if speed > 5 then
            return
        end
        if self._owner then
            local clicker = minetest.get_player_by_name(self._owner)
            clicker:set_properties({visual_size = vector.divide(vector.new(1,1,1), {x = 0.4, y = 0.2, z = 0.4})})
            local control = clicker:get_player_control()
            local direction = self._direction--clicker:get_look_dir()
            set_rotation(obj, direction)
            local factor = 0
            if control.up and line_off < self._length - 0.2 then
                factor = 1
            elseif control.down and line_off > 0.2 then
                factor = -1
            end
            obj:set_velocity(vector.add(obj:get_velocity(), vector.multiply(direction, factor*0.5)))
        end
    end
})

function adjust_rope(rope, size)
    rope:get_luaentity()._size = size
    local length = vector.length(size)
    local segments = {}
    for i=0, length*2 do
        table.insert(segments, "0,"..(i*19).."=aw_bs.png")
    end
    local rs = "[combine:16x"..(#segments*19)..":"..table.concat(segments, ":")
    segments = {}
    for i=0, length*2 do
        table.insert(segments, (i*19)..",0=aw_rs.png")
    end
    local rss = "[combine:"..(#segments*19).."x16:"..table.concat(segments, ":")
    rope:set_properties({visual_size = {x = 0.1, y = 0.1, z = length}, textures = {rs, rs, rss, rss, re, re}})
    size = vector.normalize(size)
    set_rotation(rope, size)
end

function spawn_rope(origin, target)
    local size = vector.subtract(target, origin)
    local rope = minetest.add_entity(vector.add(origin, vector.divide(size, 2)), "adv_weapons:beam")
    adjust_rope(rope, size)
    return rope
end

minetest.register_tool("adv_weapons:grappling_hook", {
    description = "Grappling Hook",
    range = 20,
    inventory_image = "adv_weapons_grappling_hook.png",
    on_use = function(itemstack, user, pointed_thing)
        local pos = vector.add(user:get_pos(), vector.new(0,user:get_properties().eye_height,0))
        pos = vector.add(pos, vector.multiply(user:get_look_dir(), 0.5))
        local hook = minetest.add_entity(pos, "adv_weapons:grappling_hook")
        hook:get_luaentity()._origin = vector.add(user:get_pos(), vector.new(0, 0.01, 0))
        hook:get_luaentity()._owner = user:get_player_name()
        local velocity = vector.normalize(vector.add(user:get_look_dir(), vector.multiply(
                vector.subtract({x = math.random(), y = math.random(), z = math.random()}, 0.5), 0.1)))
        hook:set_velocity(vector.multiply(velocity, 10))
        hook:set_acceleration({x=0, y=-9.81, z=0})
        itemstack:take_item()
        return itemstack
        --[[if pointed_thing.under then
            spawn_rope(user:get_pos(), pointed_thing.under)
        end]]
    end
})