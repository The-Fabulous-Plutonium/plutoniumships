local S, PS = core.get_translator("plutoniumships")

-- Définition des constantes et blocs autorisés
-- Definition of constants and allowed blocks
local max_size = 50
local allowed_blocks = {
    ["default:wood"] = true,
    ["default:junglewood"] = true,
    ["default:pine_wood"] = true,
    ["default:acacia_wood"] = true,
    ["default:aspen_wood"] = true,
    ["default:tree"] = true,
    ["default:jungletree"] = true,
    ["default:pine_tree"] = true,
    ["default:acacia_tree"] = true,
    ["default:aspen_tree"] = true,
    ["wool:white"] = true,
    ["wool:red"] = true,
    ["wool:blue"] = true,
    ["wool:green"] = true,
    ["wool:yellow"] = true,
    ["wool:black"] = true,
    ["wool:grey"] = true,
    ["wool:dark_grey"] = true,
    ["wool:brown"] = true,
    ["wool:cyan"] = true,
    ["wool:magenta"] = true,
    ["wool:orange"] = true,
    ["wool:pink"] = true,
    ["wool:violet"] = true,
    ["default:meselamp"] = true,
    ["default:goldblock"] = true,
    ["default:copperblock"] = true,
    ["default:tinblock"] = true,
    ["default:bronzeblock"] = true,
    ["default:steelblock"] = true,
    ["default:diamondblock"] = true,
    ["default:mese_block"] = true,
    ["default:glass"] = true,
    ["default:obsidian_glass"] = true,
    ["plutoniumships:barre"] = true,
    ["plutoniumships:ballon"] = true,
}


-- Enregistrement de l'outil de destrcution (admin)
-- Registration of the destruction tool (admin)
minetest.register_tool("plutoniumships:destroyer_tool", {
    short_description = S("Ship destroyer"),
    description = S("Instant Destruction Tool (Admin)"),
    -- You can replace the texture with a custom image.
    inventory_image = "default_tool_steelaxe.png", -- Tu peux remplacer par une image custom
    tool_capabilities = {
        full_punch_interval = 0.1,
        max_drop_level = 1,
        groupcaps = {
            crumbly = {times = {[1] = 0.1}, uses = 0, maxlevel = 3},
            snappy = {times = {[1] = 0.1}, uses = 0, maxlevel = 3},
            choppy = {times = {[1] = 0.1}, uses = 0, maxlevel = 3},
        },
        -- Just in case
        damage_groups = {fleshy = 100}, -- Juste au cas où
    },

    -- Effet à l'impact
    -- Impact effect
    on_use = function(itemstack, user, pointed_thing)
        if pointed_thing.type == "object" then
            local obj = pointed_thing.ref
            if obj and obj:get_luaentity() then
                local name = obj:get_luaentity().name
                if name == "plutoniumships:ship" or name == "plutoniumships:blimp" then
                    for _, ent in ipairs(obj:get_luaentity().block_entities or {}) do
                        if ent and ent:get_luaentity() then
                            ent:remove()
                        end
                    end
                    obj:remove()
                    minetest.chat_send_player(user:get_player_name(), "Entity destroyed!") -- Entité détruite !
                end
            end
        end
    end,
})



-- Enregistrement du kit de réparation
-- Repair kit registration
minetest.register_craft({
    output = "plutoniumships:repair_kit",
    recipe = {
        {"anvil:hammer", "default:wood", "default:steel_ingot"},
        {"default:wood", "boats:boat", "default:wood"},
        {"default:mese_crystal", "default:wood", "screwdriver:screwdriver"},
    }
})
minetest.register_craftitem("plutoniumships:repair_kit", {
    description = S("Repair Kit"),
    inventory_image = "plutoniumships_repair_kit.png",
})

-- Enregistrement du noeud barre permettant de contrôler un bateau
-- Registration of the tiller node used to control a boat
minetest.register_node("plutoniumships:barre", {
    short_descrtiption = S("Boat Tiller"),
    description = S("Allows you to create and control a boat"),
    tiles = {
        "plutoniumships_helm_top.png",
        "plutoniumships_helm_bottom.png",
        "plutoniumships_helm.png",
        "plutoniumships_helm.png",
        "plutoniumships_helm.png",
        "plutoniumships_helm.png"
    },
    groups = {cracky = 1},
    on_rightclick = function(pos, node, player, itemstack, pointed_thing)
        minetest.chat_send_player(player:get_player_name(), S("Attempting to create the ship..."))
        convert_to_entity(pos, player)
    end
})
minetest.register_craft({
    output = "plutoniumships:barre",
    recipe = {
        {"default:wood", "plutoniumships:repair_kit", "default:wood"},
        {"mesecons_materials:glue", "mesecons_powerplant:power_plant", "mesecons_materials:glue"},
        {"default:wood", "default:wood", "default:wood"},
    }
})

-- Enregistrement du noeud ballon pour les dirigeables
-- Registration of the balloon node for airships
minetest.register_node("plutoniumships:ballon", {
    short_description = S("Airship Builder"),
    description = S("Allows you to build airships"),
    tiles = {"plutoniumships_balloon.png"},
    groups = {cracky = 1},
})
minetest.register_craft({
    output = "plutoniumships:ballon",
    recipe = {
        {"xdecor:rope", "wool:white", "xdecor:rope"},
        {"wool:white", "default:mese_crystal", "wool:white"},
        {"xdecor:rope", "wool:white", "xdecor:rope"},
    }
})

-----------------------------------------------------------
-- Fonctions utilitaires
-- Utility Functions
-----------------------------------------------------------

-- Fonction : detect_structure
-- Function: detect_structure
-- But : Parcourir la structure à partir d'une position donnée et retourner la liste des positions connectées
-- Goal: Traverse the structure starting from a given position and return the list of connected positions.
function detect_structure(start_pos)
    local stack = {start_pos}
    local visited = {}
    local structure = {}

    while #stack > 0 do
        if #structure >= max_size then
            return structure
        end

        local pos = table.remove(stack)
        local hash = minetest.pos_to_string(pos)

        if not visited[hash] then
            visited[hash] = true
            table.insert(structure, pos)

            -- Parcours des positions voisines (6 directions)
            -- Traversal of neighboring positions (6 directions)
            for _, offset in ipairs({
                {x = 1, y = 0, z = 0}, {x = -1, y = 0, z = 0},
                {x = 0, y = 1, z = 0}, {x = 0, y = -1, z = 0},
                {x = 0, y = 0, z = 1}, {x = 0, y = 0, z = -1}
            }) do
                local neighbor = vector.add(pos, offset)
                local node = minetest.get_node(neighbor)
                if node.name ~= "air" and not visited[minetest.pos_to_string(neighbor)] then
                    table.insert(stack, neighbor)
                end
            end
        end
    end

    return structure
end

-----------------------------------------------------------
-- Enregistrement de l'entité "plutoniumships:blimp" (dirigeable)
-- Registering entity "plutoniumships:blimp" (airship)
-----------------------------------------------------------
minetest.register_entity("plutoniumships:blimp", {
    -- Propriétés initiales de l'entité
    -- Initial Properties of the Entity
    initial_properties = {
        physical = true,
        collide_with_objects = true,
        collisionbox = {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5},
        visual = "cube",
        visual_size = {x = 1, y = 1},
        textures = {""},
        static_save = true,
        hp_max = 10
    },

    structure_data = {},
    block_entities = {},
    structure = 200,
    max_structure = 200,
    -- Currently attached player
    driver = nil,       -- Joueur actuellement attaché
    player_rotation = 0,

    -- on_activate : Initialise l'entité lors de son chargement
    -- on_activate: Initializes the entity upon loading
    on_activate = function(self, staticdata, dtime_s)
        self.block_entities = {}
        self.object:set_armor_groups({immortal = 1})
        self.ship_id = self.object:get_luaentity() and self.object:get_luaentity().name or "unknown"
        if staticdata and staticdata ~= "" then
            local data = minetest.deserialize(staticdata)
            self.structure_data = data.structure_data or {}
            self.structure = data.structure or 200
        end
        self:adjust_hitbox()
        self:create_visual_blocks()
    end,

    -- get_staticdata : Sérialise les données de l'entité pour sauvegarde
    -- get_staticdata: Serializes the entity data for saving
    get_staticdata = function(self)
        return minetest.serialize({
            structure_data = self.structure_data,
            structure = self.structure
        })
    end,

    -- on_step : Logique de déplacement et de physique de l'entité à chaque pas de simulation
    -- on_step: Entity movement and physics logic at each simulation step
    on_step = function(self, dtime)
        if self.driver then
            self.driver:set_animation({x = 0, y = 0}, 0)
            local control = self.driver:get_player_control()
            local acceleration_factor = 0.05
            local max_speed = 10
            local maxy_speed = 6
            local turn_speed = math.pi / 180
            local speed_x = 0
            local speed_z = 0
            local speed_y = 0
            self.driver_rotation = self.object:get_yaw()

            -- Détermination de la vitesse horizontale selon l'orientation
            -- Determination of horizontal velocity based on orientation
            if control.up then
                if self.player_rotation == 0 then
                    speed_z = max_speed
                elseif self.player_rotation == 270 then
                    speed_x = -max_speed
                elseif self.player_rotation == 180 then
                    speed_z = -max_speed
                elseif self.player_rotation == 90 then
                    speed_x = max_speed
                end
            elseif control.down then
                if self.player_rotation == 0 then
                    speed_z = -max_speed
                elseif self.player_rotation == 270 then
                    speed_x = max_speed
                elseif self.player_rotation == 180 then
                    speed_z = max_speed
                elseif self.player_rotation == 90 then
                    speed_x = -max_speed
                end
            end

            -- Détermination de la vitesse verticale
            -- Determination of Vertical Velocity
            if control.sneak then
                speed_y = -maxy_speed
            elseif control.jump then
                speed_y = maxy_speed
            end

            -- Rotation du vaisseau
            -- Ship rotation
            if control.left then
                self.driver_rotation = (self.driver_rotation + turn_speed) % (2 * math.pi)
            elseif control.right then
                self.driver_rotation = (self.driver_rotation - turn_speed) % (2 * math.pi)
            end

            -- Calcul de la vélocité cible en fonction de la rotation
            -- Calculation of target velocity based on rotation
            local target_velocity = {
                x = math.cos(self.driver_rotation) * speed_x - math.sin(self.driver_rotation) * speed_z,
                y = speed_y,
                z = math.cos(self.driver_rotation) * speed_z + math.sin(self.driver_rotation) * speed_x
            }

            local current_velocity = self.object:get_velocity()
            local new_velocity = {
                x = current_velocity.x + (target_velocity.x - current_velocity.x) * acceleration_factor,
                y = (current_velocity.y == 0 and target_velocity.y ~= 0) and (target_velocity.y > 0 and 0.5 or -0.5)
                    or (current_velocity.y + (target_velocity.y - current_velocity.y) * acceleration_factor),
                z = current_velocity.z + (target_velocity.z - current_velocity.z) * acceleration_factor
            }

            self.object:set_velocity(new_velocity)
            self.object:set_yaw(self.driver_rotation)

            -- Arrêt complet si la vitesse est faible
            -- Complete stop if speed is low
            local vel = self.object:get_velocity()
            if (math.abs(vel.x) < 0.1) and not (control.down or control.up) then vel.x = 0 end
            if (math.abs(vel.y) < 0.1) and not (control.down or control.up) then vel.y = 0 end
            if (math.abs(vel.z) < 0.1) and not (control.down or control.up) then vel.z = 0 end
            self.object:set_velocity({x = vel.x, y = vel.y, z = vel.z})
        else
            -- Décélération en l'absence de conducteur
            -- Deceleration in the absence of a driver
            local vel = self.object:get_velocity()
            local deceleration_factor = 0.01
            vel.x = vel.x * (1 - deceleration_factor)
            --vel.y = vel.y * (1 - deceleration_factor)
            vel.z = vel.z * (1 - deceleration_factor)
            if math.abs(vel.x) < 0.1 then vel.x = 0 end
            --if math.abs(vel.y) < 0.1 then vel.y = 0 end
            if math.abs(vel.z) < 0.1 then vel.z = 0 end
            self.object:set_velocity({x = vel.x, y = vel.y, z = vel.z})
        end

        -- Application de la gravité et de la flottabilité
        -- Application of gravity and buoyancy
        local pos = self.object:get_pos()
        local velocity = self.object:get_velocity()
        local v = velocity.y
        local new_acce = {x = 0, y = 0, z = 0}
        local collisionbox = self.object:get_properties().collisionbox
        local hitbox_bottom = pos.y + collisionbox[2]
        local below_pos = {x = pos.x, y = hitbox_bottom, z = pos.z}
        local below_node = minetest.get_node(below_pos)

        if minetest.get_item_group(below_node.name, "water") > 0 then
            local function round(num, decimals)
                local mult = 10^decimals
                return math.floor(num * mult + 0.5) / mult
            end
            local function get_water_surface(pos)
                local node = minetest.get_node(pos)
                if minetest.get_item_group(node.name, "water") == 0 then return nil end
                while minetest.get_item_group(node.name, "water") > 0 do
                    pos.y = pos.y + 1
                    node = minetest.get_node(pos)
                end
                return pos.y - 1
            end

            local water_level = round(get_water_surface(below_pos), 0)
            if hitbox_bottom < water_level then
                if math.abs(v) < 0.2 and math.abs(water_level - hitbox_bottom) < 0.1 then
                    self.object:set_acceleration({x = 0, y = 0, z = 0})
                    self.object:set_velocity({x = velocity.x, y = 0, z = velocity.z})
                    return
                else
                    if not self.driver then
                        new_acce.y = (v < 0 and water_level > hitbox_bottom) and 2 or 0.1
                    else
                        new_acce.y = 3
                    end
                end
            end
        else
            new_acce.y = (not self.driver) and -0.3 or 0
        end

        self.object:set_acceleration(new_acce)
        local new_velo = {x = velocity.x, y = velocity.y + new_acce.y * dtime, z = velocity.z}
        self.object:set_velocity(new_velo)
    end,

    -- adjust_hitbox : Ajuste la hitbox en fonction de la structure du vaisseau
    -- adjust_hitbox: Adjusts the hitbox based on the ship's structure
    adjust_hitbox = function(self)
        local minp, maxp = vector.new(0, 0, 0), vector.new(0, 0, 0)
        for _, data in ipairs(self.structure_data) do
            minp = vector.new(math.min(minp.x, data.pos.x), math.min(minp.y, data.pos.y), math.min(minp.z, data.pos.z))
            maxp = vector.new(math.max(maxp.x, data.pos.x), math.max(maxp.y, data.pos.y), math.max(maxp.z, data.pos.z))
        end
        self.object:set_properties({
            collisionbox = {-0.7, minp.y - 0.5, -0.7, 0.7, 2, 0.7}
        })
    end,

    -- create_visual_blocks : Crée les blocs visuels attachés à l'entité
    -- Creates the visual blocks attached to the entity
    create_visual_blocks = function(self)
        local base_pos = self.object:get_pos()
        if not base_pos then return end
        for _, data in ipairs(self.structure_data) do
            local rel_pos = data.pos
            if not rel_pos then return end
            local entity = minetest.add_entity(vector.add(base_pos, rel_pos), "plutoniumships:block_part")
            if entity then
                local luaent = entity:get_luaentity()
                if luaent then
                    luaent:set_texture(data.node)
                    luaent.ship = self
                    luaent.ship_id = self.ship_id
                end
                entity:set_attach(self.object, "", vector.multiply(rel_pos, 10), {x = 0, y = 0, z = 0})
                table.insert(self.block_entities, entity)
            end
        end
    end,

    -- on_rightclick : Gère les interactions (réparation ou prise de contrôle)
    -- on_rightclick: Manages interactions (repair or takeover)
    on_rightclick = function(self, clicker)
        local inv = clicker:get_inventory()
        local wielded_item = clicker:get_wielded_item()
        if clicker:get_player_control().sneak and wielded_item:get_name() == "plutoniumships:repair_kit" then
            if self.structure < self.max_structure then
                self.structure = math.min(self.structure + 10, self.max_structure)
                wielded_item:take_item()
                clicker:set_wielded_item(wielded_item)
                minetest.chat_send_player(clicker:get_player_name(), S("Repair complete! Structure: @1 / @2", self.structure, self.max_structure))
            else
                minetest.chat_send_player(clicker:get_player_name(), S("The structure is already at its maximum!"))
            end
            return
        end

        -- Gestion de la prise de contrôle
        -- Takeover management
        if self.driver == nil and not clicker:get_player_control().sneak then
            local base_pos = self.object:get_pos()
            for _, data in ipairs(self.structure_data) do
                if data.node == "plutoniumships:barre" then
                    clicker:set_attach(self.object, "", vector.multiply(data.pos, 10), {x = 0, y = 0, z = 0})
                    self.driver = clicker
                    minetest.chat_send_player(clicker:get_player_name(), S("You take the helm."))
                    return
                end
            end
            minetest.chat_send_player(clicker:get_player_name(), S("No bars found!"))
        elseif self.driver == clicker then
            self:detach_driver()
        end
    end,

    -- detach_driver : Détache le conducteur du vaisseau
    -- detach_driver: Detach the ship's pilot
    detach_driver = function(self)
        if self.driver then
            self.driver:set_detach()
            minetest.chat_send_player(self.driver:get_player_name(), S("You went down."))
            self.driver = nil
        end
    end,

    -- on_punch : Gère les impacts sur le vaisseau et la rotation du conducteur
    -- on_punch: Manages impacts on the ship and the driver's rotation
    on_punch = function(self, hitter)
        if self.driver and hitter == self.driver then
            if not self.player_rotation then self.player_rotation = 0 end
            self.player_rotation = (self.player_rotation + 90) % 360
            hitter:set_attach(self.object, "", {x = 0, y = 0, z = 0}, {x = 0, y = self.player_rotation, z = 0})
            minetest.chat_send_player(hitter:get_player_name(), S("You turned around."))
        else
            if self.structure > 1 then
                self.structure = self.structure - 1
            else
                for _, ent in ipairs(self.block_entities) do
                    if ent and ent:get_luaentity() then
                        ent:remove()
                    end
                end
                self.object:remove()
            end
        end
    end,
})

-----------------------------------------------------------
-- Enregistrement de l'entité "plutoniumships:ship" (bateau)
-- Registration of the entity "plutoniumships:ship" (ship)
-----------------------------------------------------------
minetest.register_entity("plutoniumships:ship", {
    initial_properties = {
        physical = true,
        collide_with_objects = true,
        collisionbox = {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5},
        visual = "cube",
        visual_size = {x = 1, y = 1},
        textures = {""},
        static_save = true,
        hp_max = 10
    },

    structure_data = {},
    block_entities = {},
    structure = 200,
    max_structure = 200,
    driver = nil,
    player_rotation = 0,
    passenger_seats = {},
    passengers = {},

    -- on_activate : Initialise le bateau lors de son chargement
    -- on_activate: Initializes the boat upon loading
    on_activate = function(self, staticdata, dtime_s)
        self.block_entities = {}
        self.object:set_armor_groups({immortal = 1})
        self.ship_id = self.object:get_luaentity() and self.object:get_luaentity().name or "unknown"
        self.passenger_seats = {}
        if staticdata and staticdata ~= "" then
            local data = minetest.deserialize(staticdata)
            self.structure_data = data.structure_data or {}
            self.structure = data.structure or 200
        end
        self:adjust_hitbox()
        self:create_visual_blocks()
    end,

    -- get_staticdata : Sérialise les données du bateau pour sauvegarde
    -- get_staticdata: Serializes boat data for saving
    get_staticdata = function(self)
        return minetest.serialize({
            structure_data = self.structure_data,
            structure = self.structure
        })
    end,

    -- on_step : Logique de déplacement et de physique du bateau
    -- on_step: Boat movement and physics logic
    on_step = function(self, dtime)
        if self.driver then
            self.driver:set_animation({x = 0, y = 0}, 0)
            local control = self.driver:get_player_control()
            local acceleration_factor = 0.05
            local max_speed = 10
            local turn_speed = math.pi / 180
            local speed_x = 0
            local speed_z = 0
            self.driver_rotation = self.object:get_yaw()

            if control.up then
                if self.player_rotation == 0 then
                    speed_z = max_speed
                elseif self.player_rotation == 270 then
                    speed_x = -max_speed
                elseif self.player_rotation == 180 then
                    speed_z = -max_speed
                elseif self.player_rotation == 90 then
                    speed_x = max_speed
                end
            elseif control.down then
                if self.player_rotation == 0 then
                    speed_z = -max_speed
                elseif self.player_rotation == 270 then
                    speed_x = max_speed
                elseif self.player_rotation == 180 then
                    speed_z = max_speed
                elseif self.player_rotation == 90 then
                    speed_x = -max_speed
                end
            end

            if control.left then
                self.driver_rotation = (self.driver_rotation + turn_speed) % (2 * math.pi)
            elseif control.right then
                self.driver_rotation = (self.driver_rotation - turn_speed) % (2 * math.pi)
            end

            local target_velocity = {
                x = math.cos(self.driver_rotation) * speed_x - math.sin(self.driver_rotation) * speed_z,
                y = self.object:get_velocity().y,
                z = math.cos(self.driver_rotation) * speed_z + math.sin(self.driver_rotation) * speed_x
            }
            local current_velocity = self.object:get_velocity()
            local new_velocity = {
                x = current_velocity.x + (target_velocity.x - current_velocity.x) * acceleration_factor,
                y = target_velocity.y,
                z = current_velocity.z + (target_velocity.z - current_velocity.z) * acceleration_factor
            }
            self.object:set_velocity(new_velocity)
            self.object:set_yaw(self.driver_rotation)
        else
            local vel = self.object:get_velocity()
            local deceleration_factor = 0.01
            vel.x = vel.x * (1 - deceleration_factor)
            vel.z = vel.z * (1 - deceleration_factor)
            if math.abs(vel.x) < 0.1 then vel.x = 0 end
            if math.abs(vel.z) < 0.1 then vel.z = 0 end
            self.object:set_velocity({x = vel.x, y = vel.y, z = vel.z})
        end

        -- Gravité et flottabilité
        -- Gravity and buoyancy
        local pos = self.object:get_pos()
        local velocity = self.object:get_velocity()
        local v = velocity.y
        local new_acce = {x = 0, y = 0, z = 0}
        local collisionbox = self.object:get_properties().collisionbox
        local hitbox_bottom = pos.y + collisionbox[2]
        local below_pos = {x = pos.x, y = hitbox_bottom, z = pos.z}
        local below_node = minetest.get_node(below_pos)

        if minetest.get_item_group(below_node.name, "water") > 0 then
            local function round(num, decimals)
                local mult = 10^decimals
                return math.floor(num * mult + 0.5) / mult
            end
            local function get_water_surface(pos)
                local node = minetest.get_node(pos)
                if minetest.get_item_group(node.name, "water") == 0 then return nil end
                while minetest.get_item_group(node.name, "water") > 0 do
                    pos.y = pos.y + 1
                    node = minetest.get_node(pos)
                end
                return pos.y - 1
            end

            local water_level = round(get_water_surface(below_pos), 0)
            if hitbox_bottom < water_level then
                if math.abs(v) < 0.2 and math.abs(water_level - hitbox_bottom) < 0.1 then
                    self.object:set_acceleration({x = 0, y = 0, z = 0})
                    self.object:set_velocity({x = velocity.x, y = 0, z = velocity.z})
                    return
                else
                    new_acce.y = (v < 0 and water_level > hitbox_bottom) and 12 or 2
                end
            end
        else
            new_acce.y = -9.8
        end

        self.object:set_acceleration(new_acce)
        local new_velo = {x = velocity.x, y = velocity.y + new_acce.y * dtime, z = velocity.z}
        self.object:set_velocity(new_velo)
    end,

    -- adjust_hitbox : Ajuste la hitbox en fonction de la structure du bateau
    -- adjust_hitbox: Adjusts the hitbox based on the ship's structure
    adjust_hitbox = function(self)
        local minp, maxp = vector.new(0, 0, 0), vector.new(0, 0, 0)
        for _, data in ipairs(self.structure_data) do
            minp = vector.new(math.min(minp.x, data.pos.x), math.min(minp.y, data.pos.y), math.min(minp.z, data.pos.z))
            maxp = vector.new(math.max(maxp.x, data.pos.x), math.max(maxp.y, data.pos.y), math.max(maxp.z, data.pos.z))
        end
        self.object:set_properties({
            collisionbox = {-0.7, minp.y - 0.5, -0.7, 0.7, 2, 0.7}
        })
    end,

    -- create_visual_blocks : Crée les blocs visuels attachés au bateau
    -- create_visual_blocks: Creates the visual blocks attached to the boat
    create_visual_blocks = function(self)
        local base_pos = self.object:get_pos()
        if not base_pos then return end
        for _, data in ipairs(self.structure_data) do
            local rel_pos = data.pos
            if not rel_pos then return end
            local entity = minetest.add_entity(vector.add(base_pos, rel_pos), "plutoniumships:block_part")
            if entity then
                local luaent = entity:get_luaentity()
                if luaent then
                    luaent:set_texture(data.node)
                    luaent.ship = self
                    luaent.ship_id = self.ship_id
                end
                entity:set_attach(self.object, "", vector.multiply(rel_pos, 10), {x = 0, y = 0, z = 0})
                table.insert(self.block_entities, entity)
            end
        end
    end,

    -- on_rightclick : Gère les interactions (réparation ou prise de contrôle)
    -- on_rightclick: Manages interactions (repair or takeover)
    on_rightclick = function(self, clicker)
        local inv = clicker:get_inventory()
        local wielded_item = clicker:get_wielded_item()
        if clicker:get_player_control().sneak and wielded_item:get_name() == "plutoniumships:repair_kit" then
            if self.structure < self.max_structure then
                self.structure = math.min(self.structure + 10, self.max_structure)
                wielded_item:take_item()
                clicker:set_wielded_item(wielded_item)
                minetest.chat_send_player(clicker:get_player_name(), S("Repair complete! Structure: @1 / @2", self.structure, self.max_structure)) -- Réparation effectuée ! Structure : @1 / @2
            else
                minetest.chat_send_player(clicker:get_player_name(), S("The structure is already at its maximum!")) -- La structure est déjà au maximum !
            end
            return
        end

        if self.driver == nil and not clicker:get_player_control().sneak then
            local base_pos = self.object:get_pos()
            for _, data in ipairs(self.structure_data) do
                if data.node == "plutoniumships:barre" then
                    clicker:set_attach(self.object, "", vector.multiply(data.pos, 10), {x = 0, y = 0, z = 0})
                    self.driver = clicker
                    minetest.chat_send_player(clicker:get_player_name(), S("You take the helm.")) -- Vous prenez les commandes.
                    return
                end
            end
            minetest.chat_send_player(clicker:get_player_name(), S("No bars found!")) -- Aucune barre trouvée !
        elseif self.driver == clicker then
            self:detach_driver()
        end
    end,

    -- detach_driver : Détache le conducteur du bateau
    -- detach_driver: Detach the boat driver
    detach_driver = function(self)
        if self.driver then
            self.driver:set_detach()
            minetest.chat_send_player(self.driver:get_player_name(), S("You came down."))
            self.driver = nil
        end
    end,

    -- on_punch : Gère l'impact sur le bateau et la rotation du conducteur
    -- on_punch: Manages the impact on the boat and the driver's rotation
    on_punch = function(self, hitter)
        if self.driver and hitter == self.driver then
            if not self.player_rotation then self.player_rotation = 0 end
            self.player_rotation = (self.player_rotation + 90) % 360
            hitter:set_attach(self.object, "", {x = 0, y = 0, z = 0}, {x = 0, y = self.player_rotation, z = 0})
            minetest.chat_send_player(hitter:get_player_name(), S("You turned around.")) -- Vous vous êtes tourné.
        else
            if self.structure > 1 then
                self.structure = self.structure - 1
            else
                for _, ent in ipairs(self.block_entities) do
                    if ent and ent:get_luaentity() then
                        ent:remove()
                    end
                end
                self.object:remove()
            end
        end
    end,
})

-----------------------------------------------------------
-- Enregistrement de l'entité "plutoniumships:block_part" (partie visuelle des blocs)
-- Registration of the "plutoniumships:block_part" entity (visual part of blocks)
-----------------------------------------------------------
minetest.register_entity("plutoniumships:block_part", {
    initial_properties = {
        physical = true,
        collide_with_objects = true,
        walkable = true,
        visual = "cube",
        visual_size = {x = 1, y = 1},
        static_save = false,
        collisionbox = {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5},
    },

    -- on_activate : Initialise la partie du bloc visuel et récupère l'ID du navire
    -- on_activate: Initializes the visual block component and retrieves the ship ID
    on_activate = function(self, staticdata, dtime_s)
        self.object:set_armor_groups({immortal = 1})
        if staticdata and staticdata ~= "" then
            local data = minetest.deserialize(staticdata)
            if data and data.ship_id then
                self.ship_id = data.ship_id
            end
        end
    end,

    -- get_staticdata : Sérialise l'ID du navire pour sauvegarde
    -- get_staticdata: Serializes the ship ID for saving
    get_staticdata = function(self)
        return minetest.serialize({ship_id = self.ship_id})
    end,

    -- on_step : Vérifie que le navire associé existe toujours, sinon supprime le bloc
    -- on_step: Checks if the associated ship still exists; otherwise, deletes the block
    on_step = function(self, dtime)
        if not self.ship_id then
            self.object:remove()
            return
        end

        local still_exists = false
        for _, obj in ipairs(minetest.get_objects_inside_radius(self.object:get_pos(), 20)) do
            local ent = obj:get_luaentity()
            if ent and (ent.name == "plutoniumships:ship" or ent.name == "plutoniumships:blimp") and ent.ship_id == self.ship_id then
                still_exists = true
                break
            end
        end
        if not still_exists then
            self.object:remove()
        end
    end,

    -- set_texture : Définit la texture et la luminance en fonction du bloc de base
    -- set_texture: Sets the texture and luminance based on the base block
    set_texture = function(self, node_name)
        local def = minetest.registered_nodes[node_name]
        if not def or not def.tiles then return end
        local glow_value = def.light_source or 0
        self.object:set_properties({glow = glow_value})

        local is_glass = false
        local glass_texture = nil
        if def.drawtype == "glasslike" then
            is_glass = true
            glass_texture = def.tiles[1]
        elseif def.drawtype == "glasslike_framed" or def.drawtype == "glasslike_framed_optional" then
            is_glass = true
            glass_texture = def.tiles[1]
        end

        local textures = {}
        local function get_texture(index)
            return def.tiles[index] or def.tiles[#def.tiles]
        end

        if is_glass and glass_texture then
            textures = {glass_texture, glass_texture, glass_texture, glass_texture, glass_texture, glass_texture}
        else
            if #def.tiles == 1 then
                textures = {def.tiles[1], def.tiles[1], def.tiles[1], def.tiles[1], def.tiles[1], def.tiles[1]}
            elseif #def.tiles == 2 then
                textures = {get_texture(1), get_texture(1), get_texture(2), get_texture(2), get_texture(2), get_texture(2)}
            elseif #def.tiles == 3 then
                textures = {get_texture(1), get_texture(2), get_texture(3), get_texture(3), get_texture(3), get_texture(3)}
            elseif #def.tiles >= 6 then
                textures = {get_texture(1), get_texture(2), get_texture(3), get_texture(4), get_texture(5), get_texture(6)}
            end
        end

        self.object:set_properties({textures = textures})
    end,

    -- on_punch : Gère l'impact sur la partie visuelle et réduit la structure du navire
    -- on_punch: Manages the visual impact and reduces the ship's structural integrity
    on_punch = function(self, puncher)
        if self.ship then
            if self.ship.structure > 1 then
                self.ship.structure = self.ship.structure - 1
            else
                for _, ent in ipairs(self.ship.block_entities) do
                    if ent and ent:get_luaentity() then
                        ent:remove()
                    end
                end
                self.ship.object:remove()
            end
        end
    end,
})

-----------------------------------------------------------
-- Fonction utilitaire pour réparer le navire
-- Utility function to repair the ship
-----------------------------------------------------------
local function repair_ship(player, ship)
    local player_name = player:get_player_name()
    local structure = ship.structure or 0
    if structure < max_structure then
        structure = structure + 10
        ship.structure = structure
        minetest.chat_send_player(player_name, S("You have repaired your ship; it now has: @1", structure))
        return true
    else
        minetest.chat_send_player(player_name, S("This ship does not need to be repaired."))
        return false
    end
end

-----------------------------------------------------------
-- Fonction utilitaire de conversion d'une structure en entité navire
-- Utility function for converting a structure into a ship entity
-----------------------------------------------------------
function convert_to_entity(pos, player)
    local structure = detect_structure(pos)
    if #structure >= max_size then
        minetest.chat_send_player(player:get_player_name(), S("The structure is too big!"))
        return
    end

    if #structure < 10 then
        minetest.chat_send_player(player:get_player_name(), S("The structure is too small!"))
        return
    end

    local bar_count = 0
    local balloon_count = 0
    local total_blocks = #structure

    -- Comptage des barres et ballons
    -- Counting bars and balloons
    for _, block_pos in ipairs(structure) do
        local node = minetest.get_node(block_pos)
        if node.name == "plutoniumships:barre" then
            bar_count = bar_count + 1
            if bar_count > 1 then
                minetest.chat_send_player(player:get_player_name(), S("Too many bars on the boat!"))
                return
            end
        elseif node.name == "plutoniumships:ballon" then
            balloon_count = balloon_count + 1
        end
    end

    local other_blocks = total_blocks - balloon_count
    local balloon_ratio = balloon_count / other_blocks

    local entity_name
    if balloon_ratio >= 0.5 then
        entity_name = "plutoniumships:blimp"
        minetest.chat_send_player(player:get_player_name(), S("Airship created with @1 blocks!", total_blocks))
    elseif (balloon_ratio < 0.5) and (balloon_count >= 1) then
        minetest.chat_send_player(player:get_player_name(), S("Not enough balloons to build an airship!"))
        return
    else
        entity_name = "plutoniumships:ship"
        minetest.chat_send_player(player:get_player_name(), S("Boat created with @1 blocks!", total_blocks))
    end

    local structure_data = {}
    local center = vector.new(pos)
    for _, block_pos in ipairs(structure) do
        local node = minetest.get_node(block_pos)
        table.insert(structure_data, {pos = vector.subtract(block_pos, center), node = node.name})
        minetest.set_node(block_pos, {name = "air"})
    end

    local entity = minetest.add_entity(center, entity_name)
    if entity then
        local luaent = entity:get_luaentity()
        if luaent then
            luaent.structure_data = structure_data
            luaent.structure = 200
            luaent:create_visual_blocks()
            luaent:adjust_hitbox()
        end
    end
end
