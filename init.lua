-- ===========================================================================
-- Plutonium's Ships  -  init.lua  (v10)
--
-- Fixes v10 :
--  • Escaliers/param2 : rotation 3D complète via matrice (pas juste +yaw sur Y)
--  • Fluidité : set_attach pour le visuel, un seul set_yaw par frame
--    Les block_parts visuels sont attachés (smooth), les blocs physiques
--    sont des entités indépendantes repositionnées (solides)
--  • Architecture duale :
--      - block_part_visual  : attaché au navire (lisse), physical=false
--      - block_part_physics : non attaché, repositionné, physical=true (solide)
--  • Collision entre structures : collide_with_objects=true sur les blocs physiques
--  • Sol ralentit le bateau : friction élevée si pas dans l'eau
--  • Orientation correcte à la montée/descente (player_rotation → yaw offset)
--  • Affichage structure HP en regardant la barre (infotext)
--  • Ballons : suppression du ballon blanc en double, recettes colorées
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 1. CONFIG
-- ---------------------------------------------------------------------------
local function cfg_int(n, d)   return math.floor(tonumber(core.settings:get(n)) or d) end
local function cfg_float(n, d) return tonumber(core.settings:get(n)) or d end

local cfg = {
    max_size         = cfg_int  ("plutoniumships_max_size",          50),
    min_size         = cfg_int  ("plutoniumships_min_size",          10),
    balloon_ratio    = cfg_float("plutoniumships_balloon_ratio",      0.5),
    max_speed        = cfg_float("plutoniumships_max_speed",         10.0),
    blimp_max_speed  = cfg_float("plutoniumships_blimp_max_speed",   10.0),
    blimp_max_vspeed = cfg_float("plutoniumships_blimp_max_vspeed",   5.0),
    turn_speed       = cfg_float("plutoniumships_turn_speed",         0.4),
    accel_factor     = cfg_float("plutoniumships_accel_factor",       0.015),
    max_helm_offset  = cfg_float("plutoniumships_max_helm_offset",    5.0),
}

local function mass_factor(nb)
    local mn, mx = cfg.min_size, cfg.max_size
    if mx <= mn then return 1.0 end
    local t = math.max(0, math.min(1, (nb - mn) / (mx - mn)))
    return 1.0 - t * 0.8
end

-- ---------------------------------------------------------------------------
-- 2. CONSTANTES
-- ---------------------------------------------------------------------------
local DIRS6 = {
    {x=1,y=0,z=0},{x=-1,y=0,z=0},
    {x=0,y=1,z=0},{x=0,y=-1,z=0},
    {x=0,y=0,z=1},{x=0,y=0,z=-1},
}
local DIRS4H = { {x=0,y=0,z=-1},{x=-1,y=0,z=0},{x=0,y=0,z=1},{x=1,y=0,z=0} }

-- 24 rotations facedir en degrés (pour set_attach qui prend des degrés)
local FACE_ROT_DEG = {
    {x=0,  y=0,   z=0},   {x=0,  y=90,  z=0},  {x=0,  y=180, z=0},  {x=0,  y=-90, z=0},
    {x=90, y=0,   z=0},   {x=90, y=0,   z=90}, {x=90, y=0,   z=180},{x=90, y=0,   z=-90},
    {x=-90,y=0,   z=0},   {x=-90,y=0,   z=-90},{x=-90,y=0,   z=180},{x=-90,y=0,   z=90},
    {x=0,  y=0,   z=-90}, {x=90, y=90,  z=0},  {x=180,y=0,   z=90}, {x=0,  y=-90, z=-90},
    {x=0,  y=0,   z=90},  {x=0,  y=90,  z=90}, {x=180,y=0,   z=-90},{x=0,  y=-90, z=90},
    {x=180,y=180, z=0},   {x=180,y=90,  z=0},  {x=180,y=0,   z=0},  {x=180,y=-90, z=0},
}
local WALLMOUNT_DEG = {
    [0]={x=-90,y=0,z=0},[1]={x=90,y=0,z=0},
    [2]={x=0,y=0,z=0},  [3]={x=0,y=180,z=0},
    [4]={x=0,y=90,z=0}, [5]={x=0,y=-90,z=0},
}

local TRANS  = "plutoniumships_trans.png"
local TRANS6 = {TRANS,TRANS,TRANS,TRANS,TRANS,TRANS}
local INVIS  = { visual="cube", visual_size={x=1,y=1}, textures=TRANS6,
                 collisionbox={-0.05,-0.05,-0.05,0.05,0.05,0.05} }

local ship_counter = 0
local function new_ship_id()
    ship_counter = ship_counter + 1
    return "ship_"..os.time().."_"..ship_counter
end

-- ---------------------------------------------------------------------------
-- 3. HELPERS VISUELS
-- ---------------------------------------------------------------------------

local function node_rot_deg(def, param2)
    local p2 = param2 or 0
    if def.paramtype2 == "facedir" then
        return FACE_ROT_DEG[(p2 % 32) + 1] or FACE_ROT_DEG[1]
    elseif def.paramtype2 == "wallmounted" then
        return WALLMOUNT_DEG[p2 % 6] or {x=0,y=0,z=0}
    end
    return {x=0,y=0,z=0}
end

local function mesh_type(name, def)
    if not def then return "cube", nil end
    if core.get_item_group(name,"fence") > 0 then return "fence", nil end
    if core.get_item_group(name,"wall")  > 0 then return "wall",  nil end
    if core.get_item_group(name,"pane")  > 0 then return "pane",  nil end
    if core.get_item_group(name,"stair") > 0
        or name:find("^stairs:stair_") then return "stair", nil end
    if core.get_item_group(name,"slab")  > 0
        or name:find("^stairs:slab_")  then return "slab",  nil end
    local dt = def.drawtype
    if dt==nil or dt=="normal" or dt=="allfaces" or dt=="allfaces_optional"
       or dt=="glasslike" or dt=="glasslike_framed" or dt=="glasslike_framed_optional"
       or dt=="liquid" then return "cube", nil end
    if dt=="plantlike" or dt=="firelike" then return "plant", nil end
    if dt=="mesh" then return "custom_mesh", def.mesh end
    return "cube", nil
end

local function rtile(t)
    if type(t)=="string" then return t end
    if type(t)=="table"  then return t.name or "blank.png" end
    return "blank.png"
end

local function tiles6(def)
    local t = def.tiles or {}
    local n = #t
    if n==0 then
        local fb=(def.inventory_image~="" and def.inventory_image) or "blank.png"
        return {fb,fb,fb,fb,fb,fb}
    end
    local function g(i) return rtile(t[math.min(i,n)]) end
    return {g(1),g(2),g(3),g(4),g(5),g(6)}
end

local function conn_tex(main, facecons, has_post)
    local tx={}
    if has_post then
        tx[1]=main
        for i=1,4 do tx[i+1]=(facecons and facecons[i]) and main or TRANS end
    else
        for i=1,4 do tx[i]=(facecons and facecons[i]) and main or TRANS end
    end
    return tx
end

-- ---------------------------------------------------------------------------
-- 4. BLOCS AUTORISÉS
-- ---------------------------------------------------------------------------
local ALLOWED_GROUPS = {
    "wood","tree","wool",
    "stair","slab",
    "balloon", "flower", "grass"
}
local ALLOWED_SPECIAL = {
    ["default:meselamp"]=true,      ["default:glass"]=true,
    ["default:obsidian_glass"]=true,["default:goldblock"]=true,
    ["default:copperblock"]=true,   ["default:tinblock"]=true,
    ["default:bronzeblock"]=true,   ["default:steelblock"]=true,
    ["default:diamondblock"]=true,  ["default:mese_block"]=true,
    ["plutoniumships:barre"]=true,  ["default:fence_wood"] = true,
    ["default:fence_acacia_wood"] = true,
    ["default:fence_junglewood"] = true,
    ["default:fence_pine_wood"] = true,
    ["default:fence_aspen_wood"] = true,
    ["xdecor:rope"] = true,
    ["xdecor:wooden_lightbox"] = true,
    ["xdecor:iron_lightbox"] = true,
    ["default:chest"] = true,
    ["default:desert_cobble"] = true,
    ["default:furnace"] = true,
    ["xdecor:barrel"] = true,
    ["default:apple"] = true,
    ["vessels:steel_bottle"] = true,
}

local function is_ok(name)
    if name=="air" or name=="ignore" then return false end
    if ALLOWED_SPECIAL[name] then return true end
    for _,g in ipairs(ALLOWED_GROUPS) do
        if core.get_item_group(name,g)>0 then return true end
    end
    return false
end

-- ---------------------------------------------------------------------------
-- 5. PHYSIQUE EAU
-- ---------------------------------------------------------------------------
local function find_water_surface(x, y_bottom, z)
    local ix,iy,iz = math.floor(x),math.floor(y_bottom),math.floor(z)
    local nd = core.get_node({x=ix,y=iy,z=iz})
    if core.get_item_group(nd.name,"water")==0 then return false,nil end
    for dy=0,25 do
        local n=core.get_node({x=ix,y=iy+dy+1,z=iz})
        if core.get_item_group(n.name,"water")==0 then return true,(iy+dy) end
    end
    return true,(iy+25)
end

local function water_float_accel(obj, vel, pos, cbox)
    local hull_btm = pos.y + cbox[2]
    local in_w, surf = find_water_surface(pos.x, hull_btm, pos.z)
    if not (in_w and surf) then return nil end
    local err = (surf - cbox[2]) - pos.y
    local ay = err*8 - vel.y*3
    ay = math.max(-6, math.min(ay, 18))
    vel.x = vel.x * 0.97
    vel.z = vel.z * 0.97
    return ay
end

-- Vérifie si la position est dans l'eau (pour la friction sol)
local function is_in_water(pos, cbox)
    local hull_btm = pos.y + cbox[2]
    local in_w,_ = find_water_surface(pos.x, hull_btm, pos.z)
    return in_w
end

-- ---------------------------------------------------------------------------
-- 6. HITBOX CIRCULAIRE
-- ---------------------------------------------------------------------------
local function apply_hitbox(self)
    local min_y,max_y,max_r = 99999,-99999,0
    for _,d in ipairs(self.structure_data) do
        local p=d.pos
        min_y=math.min(min_y,p.y-0.5); max_y=math.max(max_y,p.y+0.5)
        max_r=math.max(max_r,math.sqrt(p.x*p.x+p.z*p.z)+0.6)
    end
    if min_y==99999  then min_y=-0.5 end
    if max_y==-99999 then max_y= 0.5 end
    local r=math.min(max_r,28)
    self.object:set_properties({collisionbox={
        -r,math.max(min_y,-28),-r, r,math.min(max_y,28),r
    }})
end

-- ---------------------------------------------------------------------------
-- 7. ENREGISTREMENT NOEUDS / ITEMS
-- ---------------------------------------------------------------------------

core.register_tool("plutoniumships:destroyer_tool",{
    description="Outil de destruction instantanee (Admin)",
    inventory_image="default_tool_steelaxe.png",
    tool_capabilities={
        full_punch_interval=0.1,max_drop_level=1,
        groupcaps={
            crumbly={times={[1]=0.1},uses=0,maxlevel=3},
            snappy ={times={[1]=0.1},uses=0,maxlevel=3},
            choppy ={times={[1]=0.1},uses=0,maxlevel=3},
        },
        damage_groups={fleshy=100},
    },
    on_use=function(itemstack,user,pt)
        if pt.type~="object" then return end
        local ent=pt.ref and pt.ref:get_luaentity()
        if ent and (ent.name=="plutoniumships:ship" or ent.name=="plutoniumships:blimp") then
            for _,be in ipairs(ent.block_entities or {}) do
                if be and be:get_luaentity() then be:remove() end
            end
            for _,be in ipairs(ent.phys_entities or {}) do
                if be and be:get_luaentity() then be:remove() end
            end
            pt.ref:remove()
            core.chat_send_player(user:get_player_name(),"Entite detruite !")
        end
    end,
})

core.register_craftitem("plutoniumships:repair_kit",{
    description="Kit de Reparation",
    inventory_image="plutoniumships_repair_kit.png",
})
core.register_craft({output="plutoniumships:repair_kit",recipe={
    {"anvil:hammer","default:wood","default:steel_ingot"},
    {"default:wood","boats:boat","default:wood"},
    {"default:mese_crystal","default:wood","screwdriver:screwdriver"},
}})

core.register_node("plutoniumships:barre",{
    description="Barre de controle – clic droit pour creer le navire",
    tiles={
        "plutoniumships_helm_top.png","plutoniumships_helm_bottom.png",
        "plutoniumships_helm.png","plutoniumships_helm.png",
        "plutoniumships_helm.png","plutoniumships_helm.png",
    },
    paramtype2="facedir", groups={cracky=1},
    on_rightclick=function(pos,_,player,_,_)
        core.chat_send_player(player:get_player_name(),"Tentative de creation du navire ...")
        convert_to_entity(pos,player)
    end,
})
core.register_craft({output="plutoniumships:barre",recipe={
    {"default:wood","plutoniumships:repair_kit","default:wood"},
    {"mesecons_materials:glue","mesecons_powerplant:power_plant","mesecons_materials:glue"},
    {"default:wood","default:wood","default:wood"},
}})

-- Ballons colorés (PAS de ballon "neutre" en double — juste les 6 couleurs)
local BALLOON_COLORS={
    {id="white", desc="Blanc", wool="wool:white", dye="dye:white"},
    {id="red",   desc="Rouge", wool="wool:red",   dye="dye:red"},
    {id="blue",  desc="Bleu",  wool="wool:blue",  dye="dye:blue"},
    {id="green", desc="Vert",  wool="wool:green", dye="dye:green"},
    {id="yellow",desc="Jaune", wool="wool:yellow",dye="dye:yellow"},
    {id="black", desc="Noir",  wool="wool:black", dye="dye:black"},
}
-- Ballon par défaut = alias vers le blanc pour la rétrocompatibilité
-- (on le re-register comme alias de ballon_white)
for _,c in ipairs(BALLOON_COLORS) do
    local nm="plutoniumships:ballon_"..c.id
    ALLOWED_SPECIAL[nm]=true
    local tex="plutoniumships_balloon_"..c.id..".png"
    -- Le blanc utilise aussi l'ancienne texture générique en fallback
    local tiles_list = (c.id=="white") and
        {"plutoniumships_balloon_white.png"} or {tex}
    core.register_node(nm,{
        description="Ballon "..c.desc,
        tiles=tiles_list,
        groups={cracky=1,balloon=1},
    })
    core.register_craft({output=nm.." 2",recipe={
        {"xdecor:rope", c.wool,                "xdecor:rope"},
        {c.wool,        "default:mese_crystal", c.wool},
        {"xdecor:rope", c.wool,                "xdecor:rope"},
    }})
end
-- Alias rétrocompat : "plutoniumships:ballon" → blanc
core.register_alias("plutoniumships:ballon","plutoniumships:ballon_white")
ALLOWED_SPECIAL["plutoniumships:ballon"]=true  -- pour la détection

-- ---------------------------------------------------------------------------
-- 8. DÉTECTION DE STRUCTURE
-- ---------------------------------------------------------------------------
function detect_structure(start_pos)
    local sn=core.get_node(start_pos)
    if sn.name=="air" or sn.name=="ignore" then return {},{} end
    local stack={vector.new(start_pos)}
    local visited,allowed,banned={},{},{}
    local limit = cfg.max_size + 1  -- +1 pour détecter le dépassement
    while #stack>0 do
        -- Arrêt immédiat dès que la limite est atteinte
        if #allowed >= limit then
            return allowed, banned, true  -- 3e valeur = trop_grand
        end
        local pos=table.remove(stack)
        local hash=core.pos_to_string(pos)
        if visited[hash] then goto _nxt end
        visited[hash]=true
        local nd=core.get_node(pos)
        if nd.name~="air" and nd.name~="ignore" then
            if is_ok(nd.name) then
                table.insert(allowed,pos)
                -- Ajouter les voisins seulement si on n'a pas encore atteint la limite
                if #allowed < limit then
                    for _,d in ipairs(DIRS6) do
                        local nb=vector.add(pos,d)
                        if not visited[core.pos_to_string(nb)] then
                            local nbn=core.get_node(nb)
                            if nbn.name~="air" and nbn.name~="ignore" then
                                table.insert(stack,nb)
                            end
                        end
                    end
                end
            else
                banned[nd.name]=true
                -- Continuer à explorer depuis les blocs non autorisés aussi
                for _,d in ipairs(DIRS6) do
                    local nb=vector.add(pos,d)
                    if not visited[core.pos_to_string(nb)] then
                        local nbn=core.get_node(nb)
                        if nbn.name~="air" and nbn.name~="ignore" then
                            table.insert(stack,nb)
                        end
                    end
                end
            end
        end
        ::_nxt::
    end
    return allowed, banned, false
end

-- ---------------------------------------------------------------------------
-- 9. ENTITÉS VISUELLES (block_part_visual) — attachées, smooth, physical=false
--    Responsables UNIQUEMENT du rendu visuel.
-- ---------------------------------------------------------------------------
local function setup_block_visual(le, node_name, param2, facecons)
    local def=core.registered_nodes[node_name]; if not def then return end
    local mtype_,mfile=mesh_type(node_name,def)
    local glow=def.light_source or 0
    local tx=tiles6(def)
    local main = (mtype_=="pane") and
        rtile((def.tiles or {})[3] or (def.tiles or {})[1] or "blank.png") or tx[1]
    local props={glow=glow}
    if     mtype_=="cube" then
        props.visual="cube"; props.visual_size={x=1,y=1}; props.textures=tx
    elseif mtype_=="slab" then
        props.visual="mesh"; props.mesh="slab.obj"; props.visual_size={x=1,y=1}; props.textures=tx
    elseif mtype_=="stair" then
        props.visual="mesh"; props.mesh="stair.obj"; props.visual_size={x=1,y=1}; props.textures=tx
    elseif mtype_=="plant" then
        props.visual="mesh"; props.mesh="plant.obj"; props.visual_size={x=1,y=1}; props.textures={main}
    elseif mtype_=="fence" then
        props.visual="mesh"; props.mesh="fence.obj"; props.visual_size={x=1,y=1}
        props.textures=conn_tex(main,facecons,true)
    elseif mtype_=="wall" then
        props.visual="mesh"; props.mesh="wall.obj"; props.visual_size={x=1,y=1}
        props.textures=conn_tex(main,facecons,true)
    elseif mtype_=="pane" then
        props.visual="mesh"; props.mesh="pane.obj"; props.visual_size={x=1,y=1}
        props.textures=conn_tex(main,facecons,false)
    elseif mtype_=="custom_mesh" and mfile then
        props.visual="mesh"; props.mesh=mfile; props.visual_size={x=10,y=10}; props.textures=tx
    else
        props.visual="cube"; props.visual_size={x=1,y=1}; props.textures=tx
    end
    le.object:set_properties(props)
end

core.register_entity("plutoniumships:block_visual",{
    initial_properties={
        physical=false, collide_with_objects=false,
        pointable=false,   -- invisible aux clics : les block_part gèrent l'interaction
        visual="cube", visual_size={x=1,y=1},
        textures={"blank.png","blank.png","blank.png","blank.png","blank.png","blank.png"},
        static_save=false, glow=0,
    },
    ship_id=nil,
    on_activate=function(self,_,_) self.object:set_armor_groups({immortal=1}) end,
    get_staticdata=function() return "" end,
    on_step=function(self,dtime)
        -- Pas de logique lourde : l'attachment gère tout
    end,
})

-- ---------------------------------------------------------------------------
-- 10. ENTITÉS PHYSIQUES (block_part) — non attachées, solid, physical=true
--     Responsables de la collision joueur/structure et structure/structure.
--     Repositionnées manuellement chaque frame.
-- ---------------------------------------------------------------------------
core.register_entity("plutoniumships:block_part",{
    initial_properties={
        physical=true, collide_with_objects=true,
        collisionbox={-0.5,-0.5,-0.5, 0.5,0.5,0.5},
        visual="cube", visual_size={x=0.001,y=0.001},   -- invisible (collision only)
        textures=TRANS6,
        static_save=false, glow=0,
    },
    ship=nil, ship_id=nil,
    on_activate=function(self,_,_)
        self.object:set_armor_groups({immortal=1})
        self.object:set_velocity({x=0,y=0,z=0})
        self.object:set_acceleration({x=0,y=0,z=0})
        self._t=0
    end,
    get_staticdata=function() return "" end,
    on_step=function(self,dtime)
        -- Toujours immobile (le navire repose sa position)
        self.object:set_velocity({x=0,y=0,z=0})
        self.object:set_acceleration({x=0,y=0,z=0})
        -- Orphelin check toutes les 5 s
        self._t=(self._t or 0)+dtime
        if self._t<5 then return end
        self._t=0
        if not self.ship_id then self.object:remove(); return end
        local p=self.object:get_pos(); if not p then self.object:remove(); return end
        for _,obj in ipairs(core.get_objects_inside_radius(p,8)) do
            local e=obj:get_luaentity()
            if e and e.ship_id==self.ship_id then return end
        end
        self.object:remove()
    end,
    -- Transmet rightclick au navire
    on_rightclick=function(self,clicker)
        if self.ship then do_rightclick(self.ship,clicker) end
    end,
    on_punch=function(self,puncher)
        local s=self.ship; if not s then return end
        if s.structure>1 then s.structure=s.structure-1
        else
            for _,be in ipairs(s.block_entities or {}) do if be and be:get_luaentity() then be:remove() end end
            for _,pe in ipairs(s.phys_entities  or {}) do if pe and pe:get_luaentity() then pe:remove() end end
            s.object:remove()
        end
    end,
})

-- ---------------------------------------------------------------------------
-- 11. HELPERS COMMUNS
-- ---------------------------------------------------------------------------

-- Spawne les deux couches d'entités pour chaque bloc
local function spawn_blocks(self)
    -- Idempotent : si les blocs sont déjà spawné, ne rien faire
    if self._blocks_spawned then return end
    self._blocks_spawned = true

    local bpos=self.object:get_pos(); if not bpos then return end
    local yaw=self.object:get_yaw()
    local cy,sy=math.cos(yaw),math.sin(yaw)

    local rel_set={}
    for _,d in ipairs(self.structure_data) do rel_set[core.pos_to_string(d.pos)]=d.node end

    -- Nettoyer tous les anciens blocs avant de recréer (sécurité)
    for _,be in ipairs(self.block_entities or {}) do
        if be and be:get_luaentity() then be:remove() end
    end
    for _,pe in ipairs(self.phys_entities or {}) do
        if pe and pe:get_luaentity() then pe:remove() end
    end
    self.block_entities={}
    self.phys_entities={}

    for i,data in ipairs(self.structure_data) do
        local def=core.registered_nodes[data.node]
        if not def then
            self.block_entities[i]=nil; self.phys_entities[i]=nil; goto _sk
        end

        -- Position monde initiale
        local rx=cy*data.pos.x-sy*data.pos.z
        local rz=sy*data.pos.x+cy*data.pos.z
        local wpos={x=bpos.x+rx, y=bpos.y+data.pos.y, z=bpos.z+rz}

        -- ── Visuel : attaché au navire (set_attach = smooth automatique) ──
        local vis=core.add_entity(wpos,"plutoniumships:block_visual")
        if vis then
            local le=vis:get_luaentity()
            if le then
                local facecons=nil
                local mt,_=mesh_type(data.node,def)
                if mt=="fence" or mt=="pane" or mt=="wall" then
                    facecons={}
                    for j,d2 in ipairs(DIRS4H) do
                        facecons[j]=rel_set[core.pos_to_string(vector.add(data.pos,d2))]~=nil
                    end
                end
                setup_block_visual(le,data.node,data.param2,facecons)
                le.ship_id=self.ship_id
            end
            -- Rotation du bloc (degrés) passée directement à set_attach
            -- → n'est PAS affectée par la rotation du navire car on compose
            --   correctement via set_attach (parent yaw géré par le moteur)
            local rot=node_rot_deg(def,data.param2)
            vis:set_attach(self.object,"",vector.multiply(data.pos,10),rot)
            self.block_entities[i]=vis
        else self.block_entities[i]=nil end

        -- ── Physique : non attaché, repositionné chaque frame ──
        local phys=core.add_entity(wpos,"plutoniumships:block_part")
        if phys then
            local le=phys:get_luaentity()
            if le then le.ship=self; le.ship_id=self.ship_id end
            phys:set_velocity({x=0,y=0,z=0})
            phys:set_acceleration({x=0,y=0,z=0})
            self.phys_entities[i]=phys
        else self.phys_entities[i]=nil end

        ::_sk::
    end
end

-- Repositionne uniquement les blocs physiques (les visuels sont gérés par set_attach)
local function update_phys_positions(self)
    local pos=self.object:get_pos(); if not pos then return end
    local yaw=self.object:get_yaw()
    local cy,sy=math.cos(yaw),math.sin(yaw)
    for i,data in ipairs(self.structure_data) do
        local pe=self.phys_entities[i]
        if pe then
            local le=pe:get_luaentity()
            if le then
                local rx=cy*data.pos.x-sy*data.pos.z
                local rz=sy*data.pos.x+cy*data.pos.z
                pe:set_pos({x=pos.x+rx, y=pos.y+data.pos.y, z=pos.z+rz})
                pe:set_velocity({x=0,y=0,z=0})
                pe:set_acceleration({x=0,y=0,z=0})
            end
        end
    end
end

-- yaw_offset_for_rotation : quand player_rotation vaut N×90°,
-- le joueur fait face à la direction correspondante du navire.
-- On retourne le décalage de yaw (radians) à appliquer au yaw du navire
-- pour que le joueur soit orienté face à l'avant réel.
local function orientation_yaw_offset(player_rotation)
    -- player_rotation 0   → face à l'avant (pas de décalage)
    -- player_rotation 90  → tourné de 90° à droite → décalage -90°
    -- etc.
    return -math.rad(player_rotation or 0)
end

function do_rightclick(self,clicker)
    local w=clicker:get_wielded_item()
    if clicker:get_player_control().sneak and w:get_name()=="plutoniumships:repair_kit" then
        if self.structure<self.max_structure then
            self.structure=math.min(self.structure+10,self.max_structure)
            w:take_item(); clicker:set_wielded_item(w)
            core.chat_send_player(clicker:get_player_name(),
                "Reparation ! "..self.structure.."/"..self.max_structure)
        else core.chat_send_player(clicker:get_player_name(),"Structure deja au max !") end
        return
    end
    if self.driver==nil and not clicker:get_player_control().sneak then
        for _,d in ipairs(self.structure_data) do
            if d.node=="plutoniumships:barre" then
                self._barre_pos=d.pos
                clicker:set_attach(self.object,"",vector.multiply(d.pos,10),{x=0,y=0,z=0})
                self.driver=clicker
                self.player_rotation=0
                core.chat_send_player(clicker:get_player_name(),"Vous prenez les commandes.")
                return
            end
        end
        core.chat_send_player(clicker:get_player_name(),"Aucune barre trouvee !")
    elseif self.driver==clicker then
        -- Détacher et corriger l'orientation du joueur
        local ship_yaw=self.object:get_yaw()
        clicker:set_detach()
        -- Réorienter le joueur selon l'avant réel du navire
        local player_yaw=ship_yaw + orientation_yaw_offset(self.player_rotation)
        clicker:set_look_horizontal(player_yaw)
        core.chat_send_player(clicker:get_player_name(),"Vous etes descendu.")
        self.driver=nil
    end
end

local function do_punch(self,hitter)
    if self.driver and hitter==self.driver then
        -- Clic gauche aux commandes = changer l'avant du navire de 90°
        self.player_rotation=((self.player_rotation or 0)+90)%360
        local bpos=self._barre_pos or {x=0,y=0,z=0}
        hitter:set_attach(self.object,"",vector.multiply(bpos,10),
            {x=0,y=self.player_rotation,z=0})
        core.chat_send_player(hitter:get_player_name(),
            "Avant : "..self.player_rotation.."° ("..
            (({[0]="Nord",[90]="Est",[180]="Sud",[270]="Ouest"})[self.player_rotation] or "?")..")")
    else
        if self.structure>1 then self.structure=self.structure-1
        else
            for _,be in ipairs(self.block_entities or {}) do if be and be:get_luaentity() then be:remove() end end
            for _,pe in ipairs(self.phys_entities  or {}) do if pe and pe:get_luaentity() then pe:remove() end end
            self.object:remove()
        end
    end
end

local function driver_h_vel(self,ctrl,max_spd,mf)
    local ts=math.rad(cfg.turn_speed*mf)
    local yaw=self.object:get_yaw()
    if ctrl.left  then yaw=(yaw+ts)%(2*math.pi) end
    if ctrl.right then yaw=(yaw-ts)%(2*math.pi) end
    self.object:set_yaw(yaw)
    local sx,sz=0,0
    local pr=self.player_rotation or 0
    if ctrl.up then
        if pr==0 then sz=max_spd elseif pr==90 then sx=max_spd
        elseif pr==180 then sz=-max_spd elseif pr==270 then sx=-max_spd end
    elseif ctrl.down then
        if pr==0 then sz=-max_spd elseif pr==90 then sx=-max_spd
        elseif pr==180 then sz=max_spd elseif pr==270 then sx=max_spd end
    end
    local cy,sy=math.cos(yaw),math.sin(yaw)
    return {x=cy*sx-sy*sz, z=cy*sz+sy*sx}
end

local function lerp_vel(vel,tx,tz,f)
    vel.x=vel.x+(tx-vel.x)*f; vel.z=vel.z+(tz-vel.z)*f
    if math.abs(vel.x)<0.05 then vel.x=0 end
    if math.abs(vel.z)<0.05 then vel.z=0 end
    return vel
end

-- ---------------------------------------------------------------------------
-- 12. BATEAU
-- ---------------------------------------------------------------------------
core.register_entity("plutoniumships:ship",{
    initial_properties={
        physical=true, collide_with_objects=true,
        collisionbox={-0.05,-0.05,-0.05, 0.05,0.05,0.05},
        visual="cube", visual_size={x=1,y=1}, textures=TRANS6,
        static_save=true, hp_max=10,
    },
    structure_data={}, block_entities={}, phys_entities={},
    structure=200, max_structure=200,
    driver=nil, player_rotation=0, ship_id=nil, _mf=1.0, _barre_pos=nil,

    on_activate=function(self,staticdata,_)
        self.block_entities={}; self.phys_entities={}
        self.object:set_armor_groups({immortal=1})
        self.object:set_properties(INVIS)
        if staticdata and staticdata~="" then
            local d=core.deserialize(staticdata)
            if d then
                self.structure_data=d.structure_data or {}
                self.structure=d.structure or 200
                self.max_structure=d.max_structure or 200
                self.ship_id=d.ship_id or new_ship_id()
                self._mf=d._mf or mass_factor(#self.structure_data)
                apply_hitbox(self)
                -- Différer spawn_blocks d'un tick : on_activate peut être appelé
                -- avant que la position de l'entité soit correctement fixée par le
                -- moteur (rechargement depuis disque), ce qui provoquerait des blocs
                -- fantômes à de mauvaises positions.
                local self_ref = self
                self_ref._blocks_spawned = false  -- permettre le spawn initial
                core.after(0.05, function()
                    if self_ref and self_ref.object and self_ref.object:get_luaentity() then
                        spawn_blocks(self_ref)
                    end
                end)
            end
        else self.ship_id=new_ship_id() end
        self.object:set_properties({infotext="Navire - Structure : "..(self.structure or 0)})
    end,

    get_staticdata=function(self)
        return core.serialize({
            structure_data=self.structure_data, structure=self.structure,
            max_structure=self.max_structure, ship_id=self.ship_id, _mf=self._mf,
        })
    end,

    on_step=function(self,dtime)
        local pos=self.object:get_pos()
        local vel=self.object:get_velocity()
        local mf=self._mf or 1.0

        if self.driver then
            self.driver:set_animation({x=0,y=0},0)
            local ctrl=self.driver:get_player_control()
            local tgt=driver_h_vel(self,ctrl,cfg.max_speed,mf)
            vel=lerp_vel(vel,tgt.x,tgt.z,cfg.accel_factor*mf)
        else
            vel=lerp_vel(vel,0,0,0.02)
        end

        self.object:set_velocity(vel)
        vel=self.object:get_velocity()

        local cb=self.object:get_properties().collisionbox
        local ay=water_float_accel(self.object,vel,pos,cb)

        if ay~=nil then
            -- Dans l'eau : flottaison normale
            self.object:set_acceleration({x=0,y=ay,z=0})
            self.object:set_velocity({x=vel.x,y=math.max(-25,math.min(vel.y+ay*dtime,25)),z=vel.z})
        else
            -- Sur terre : gravité + forte friction horizontale
            vel.x=vel.x*0.6; vel.z=vel.z*0.6
            if math.abs(vel.x)<0.05 then vel.x=0 end
            if math.abs(vel.z)<0.05 then vel.z=0 end
            self.object:set_acceleration({x=0,y=-9.8,z=0})
            self.object:set_velocity({x=vel.x,y=vel.y,z=vel.z})
        end

        -- Infotext (structure HP)
        self.object:set_properties({infotext=
            "Navire ("..#self.structure_data.." blocs) – Structure : "..
            self.structure.."/"..self.max_structure})

        update_phys_positions(self)
    end,

    on_rightclick=function(self,c) do_rightclick(self,c) end,
    on_punch     =function(self,h) do_punch(self,h) end,
    detach_driver=function(self)
        if self.driver then
            local ship_yaw=self.object:get_yaw()
            self.driver:set_detach()
            self.driver:set_look_horizontal(ship_yaw+orientation_yaw_offset(self.player_rotation))
            core.chat_send_player(self.driver:get_player_name(),"Vous etes descendu.")
            self.driver=nil
        end
    end,
})

-- ---------------------------------------------------------------------------
-- 13. DIRIGEABLE
-- ---------------------------------------------------------------------------
core.register_entity("plutoniumships:blimp",{
    initial_properties={
        physical=true, collide_with_objects=true,
        collisionbox={-0.05,-0.05,-0.05, 0.05,0.05,0.05},
        visual="cube", visual_size={x=1,y=1}, textures=TRANS6,
        static_save=true, hp_max=10,
    },
    structure_data={}, block_entities={}, phys_entities={},
    structure=200, max_structure=200,
    driver=nil, player_rotation=0,
    ship_id=nil, balloon_ratio=0.5, _mf=1.0, _barre_pos=nil,

    on_activate=function(self,staticdata,_)
        self.block_entities={}; self.phys_entities={}
        self.object:set_armor_groups({immortal=1})
        self.object:set_properties(INVIS)
        if staticdata and staticdata~="" then
            local d=core.deserialize(staticdata)
            if d then
                self.structure_data=d.structure_data or {}
                self.structure=d.structure or 200
                self.max_structure=d.max_structure or 200
                self.ship_id=d.ship_id or new_ship_id()
                self.balloon_ratio=d.balloon_ratio or 0.5
                self._mf=d._mf or mass_factor(#self.structure_data)
                apply_hitbox(self)
                local self_ref = self
                self_ref._blocks_spawned = false  -- permettre le spawn initial
                core.after(0.05, function()
                    if self_ref and self_ref.object and self_ref.object:get_luaentity() then
                        spawn_blocks(self_ref)
                    end
                end)
            end
        else self.ship_id=new_ship_id() end
        self.object:set_properties({infotext="Dirigeable - Structure : "..(self.structure or 0)})
    end,
    get_staticdata=function(self)
        return core.serialize({
            structure_data=self.structure_data, structure=self.structure,
            max_structure=self.max_structure, ship_id=self.ship_id,
            balloon_ratio=self.balloon_ratio, _mf=self._mf,
        })
    end,

    on_step=function(self,dtime)
        local pos=self.object:get_pos()
        local vel=self.object:get_velocity()
        local mf=self._mf or 1.0
        local ctrl=nil

        if self.driver then
            self.driver:set_animation({x=0,y=0},0)
            ctrl=self.driver:get_player_control()
            local tgt=driver_h_vel(self,ctrl,cfg.blimp_max_speed,mf)
            vel=lerp_vel(vel,tgt.x,tgt.z,cfg.accel_factor*mf)
        else
            vel=lerp_vel(vel,0,0,0.01)
        end

        self.object:set_velocity(vel)
        vel=self.object:get_velocity()

        -- Physique verticale (lissée : interpolation vers vitesse cible)
        local cb=self.object:get_properties().collisionbox
        local ay_water=water_float_accel(self.object,vel,pos,cb)
        local vmax=cfg.blimp_max_vspeed
        local target_vy  -- vitesse Y cible

        if ay_water~=nil then
            -- Dans l'eau : flottaison ou décollage
            if self.driver and ctrl and ctrl.jump then
                target_vy = vmax
            else
                -- Laisser le ressort-amortisseur gérer mais lisser aussi
                self.object:set_acceleration({x=0,y=ay_water,z=0})
                local nvy=vel.y+ay_water*dtime
                nvy=math.max(-vmax,math.min(nvy,vmax))
                self.object:set_velocity({x=vel.x,y=nvy,z=vel.z})
                goto _blimp_vert_done
            end
        elseif self.driver then
            if ctrl and ctrl.jump then
                target_vy = vmax
            elseif ctrl and ctrl.sneak then
                target_vy = -vmax
            else
                target_vy = 0   -- stable
            end
        else
            target_vy = -0.8    -- descente douce sans pilote
        end

        -- Interpolation fluide vers target_vy (pas de saut brutal)
        do
            local smooth = 4.0 * dtime   -- facteur de lissage par frame
            local nvy = vel.y + (target_vy - vel.y) * math.min(smooth, 1.0)
            if math.abs(nvy) < 0.03 and target_vy == 0 then nvy = 0 end
            nvy = math.max(-vmax, math.min(nvy, vmax))
            self.object:set_acceleration({x=0,y=0,z=0})
            self.object:set_velocity({x=vel.x,y=nvy,z=vel.z})
        end
        ::_blimp_vert_done::

        self.object:set_properties({infotext=
            "Dirigeable ("..#self.structure_data.." blocs) – Structure : "..
            self.structure.."/"..self.max_structure})

        update_phys_positions(self)
    end,

    on_rightclick=function(self,c) do_rightclick(self,c) end,
    on_punch     =function(self,h) do_punch(self,h) end,
    detach_driver=function(self)
        if self.driver then
            local ship_yaw=self.object:get_yaw()
            self.driver:set_detach()
            self.driver:set_look_horizontal(ship_yaw+orientation_yaw_offset(self.player_rotation))
            core.chat_send_player(self.driver:get_player_name(),"Vous etes descendu.")
            self.driver=nil
        end
    end,
})


-- ---------------------------------------------------------------------------
-- AUTO-NETTOYAGE DES BLOCS ORPHELINS
-- Toutes les 10 secondes, supprime les block_visual et block_part dont
-- le navire parent n'existe plus. Protège contre les fuites d'entités.
-- ---------------------------------------------------------------------------
local _cleanup_timer = 0
core.register_globalstep(function(dtime)
    _cleanup_timer = _cleanup_timer + dtime
    if _cleanup_timer < 10 then return end
    _cleanup_timer = 0

    -- Collecter tous les ship_id actifs
    local active_ids = {}
    for _, obj in pairs(core.luaentities) do
        if obj and (obj.name == "plutoniumships:ship" or obj.name == "plutoniumships:blimp") then
            if obj.ship_id then active_ids[obj.ship_id] = true end
        end
    end

    -- Supprimer les blocs orphelins
    for _, obj in pairs(core.luaentities) do
        if obj and (obj.name == "plutoniumships:block_visual" or
                    obj.name == "plutoniumships:block_part") then
            if not obj.ship_id or not active_ids[obj.ship_id] then
                obj.object:remove()
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
-- 14. CONVERSION structure → entité
-- ---------------------------------------------------------------------------
function convert_to_entity(pos,player)
    local pname=player:get_player_name()
    local structure,banned,too_big=detect_structure(pos)

    if too_big then
        core.chat_send_player(pname,"Structure trop grande ! (max "..cfg.max_size.." blocs)"); return
    end
    if next(banned)~=nil then
        local names={}
        for n in pairs(banned) do table.insert(names,n) end
        table.sort(names)
        core.chat_send_player(pname,
            "Creation impossible - blocs non autorises : "..table.concat(names,", "))
        return
    end
    if #structure<cfg.min_size then
        core.chat_send_player(pname,"Structure trop petite ! (min "..cfg.min_size..")"); return
    end

    local bar_count,balloon_count=0,0
    for _,bp in ipairs(structure) do
        local nd=core.get_node(bp)
        if nd.name=="plutoniumships:barre" then
            bar_count=bar_count+1
            if bar_count>1 then
                core.chat_send_player(pname,"Trop de barres ! Une seule autorisee."); return
            end
        end
        if core.get_item_group(nd.name,"balloon")>0 then balloon_count=balloon_count+1 end
    end
    if bar_count==0 then
        core.chat_send_player(pname,"Aucune barre de controle !"); return
    end

    local total=#structure
    local ratio=balloon_count/total
    local ename

    if balloon_count==0 then
        ename="plutoniumships:ship"
        core.chat_send_player(pname,"Bateau cree avec "..total.." blocs !")
    elseif ratio>=cfg.balloon_ratio then
        ename="plutoniumships:blimp"
        core.chat_send_player(pname,
            string.format("Dirigeable cree ! (%d blocs, %.0f%% ballons)",total,ratio*100))
    else
        core.chat_send_player(pname,
            string.format("Pas assez de ballons ! (%.0f%% / %.0f%% requis)",
                ratio*100,cfg.balloon_ratio*100)); return
    end

    local mf=mass_factor(total)

    -- Centroïde XZ de la structure (le centre réel, pas la position de la barre)
    local cx, cz = 0, 0
    for _,bp in ipairs(structure) do cx=cx+bp.x; cz=cz+bp.z end
    cx = cx / #structure; cz = cz / #structure

    -- Vérifier l'excentricité de la barre (distance XZ seulement)
    local max_off = cfg.max_helm_offset
    local helm_world = nil
    for _,bp in ipairs(structure) do
        if core.get_node(bp).name=="plutoniumships:barre" then
            helm_world=bp; break
        end
    end
    if helm_world then
        local hdx = helm_world.x - cx
        local hdz = helm_world.z - cz
        local helm_dist = math.sqrt(hdx*hdx + hdz*hdz)
        if helm_dist > max_off then
            core.chat_send_player(pname,
                string.format("Barre trop excentree ! (%.1f blocs du centre XZ, max %.0f)",
                    helm_dist, max_off))
            return
        end
    end

    -- Le centre de l'entité = barre (pour que le joueur monte au bon endroit)
    local center = vector.new(pos)

    local rel_set={}
    for _,bp in ipairs(structure) do
        rel_set[core.pos_to_string(vector.subtract(bp,center))]=true
    end

    -- Construire sdata
    local sdata={}
    for _,bp in ipairs(structure) do
        local nd=core.get_node(bp)
        local def=core.registered_nodes[nd.name]
        local rel=vector.subtract(bp,center)
        local facecons=nil
        if def then
            local mt,_=mesh_type(nd.name,def)
            if mt=="fence" or mt=="pane" or mt=="wall" then
                facecons={}
                for i,d in ipairs(DIRS4H) do
                    facecons[i]=rel_set[core.pos_to_string(vector.add(rel,d))]==true
                end
            end
        end
        table.insert(sdata,{pos=rel, node=nd.name, param2=nd.param2, facecons=facecons})
    end

    -- Supprimer les blocs du monde
    for _,bp in ipairs(structure) do core.set_node(bp,{name="air"}) end

    local ent=core.add_entity(center,ename)
    if not ent then
        core.chat_send_player(pname,"Erreur : impossible de creer l'entite !"); return
    end
    local le=ent:get_luaentity()
    if le then
        le.structure_data=sdata
        le.structure=total*4
        le.max_structure=total*4
        le.balloon_ratio=ratio
        le.ship_id=new_ship_id()
        le._mf=mf
        le.block_entities={}
        le.phys_entities={}
        le._blocks_spawned = false
        apply_hitbox(le)
        spawn_blocks(le)
        core.chat_send_player(pname,
            string.format("(Manoeuvrabilite : %.0f%%)",mf*100))
    end
end
