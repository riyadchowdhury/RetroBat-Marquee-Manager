-- écran des amis et ce à quoi ils sont en train de jouer 
-- écran de connexion de l'utilisateur
-- écran comme quoi il n'y a pas de succès pour le jeu (total 0 achievement)
-- écran d'un nouveau succés
-- écran du prochain succés à débloquer
-- écran progression dans le jeu
-- background possibles : étoiles jaunes, coupes gagnantes,
-- "user_info|Nelfe|C:\\RetroBat\\UserPic\\RA\\UserPic\\Nelfe.png"
-- "game_info|Blazing Star|C:\\RetroBat\\marquees\\RA\\Images\\016053.png|5|10.00%|50"
-- "achievement|59818|C:\\RetroBat\\marquees\\RA\\Badge\\62927.png|Blazing Guns|Upgrade the ship to the max (P1)|5|10.00%"

-- function display_image(image_path, x, y)
	-- mp.osd_message("Display image" .. image_path, 5)
	-- OK : mp.command('vf add lavfi=[movie=\'Nelfe.png\'[img],[vid1][img]overlay=W-w-10:H-h-10]')
	-- OK : mp.commandv('vf', 'add', 'lavfi=[movie=\'Nelfe.png\'[img],[vid1][img]overlay=W-w-10:H-h-10]')
	-- OK : local imagepath = 'RA/UserPic/Nelfe.png'
	-- OK : mp.commandv('vf', 'remove', '@user')
	-- OK : mp.commandv('vf', 'clr')
	-- local transformed_path = image_path:gsub(".*\\(RA\\)", "%1"):gsub("\\", "/")
	-- mp.commandv('vf', 'add', 'lavfi=[movie=\'' .. transformed_path .. '\'[img],[vid1][img]overlay=W-w-10:H-h-10]')
	-- OK local overlay = mp.create_osd_overlay("ass-events")
	-- OK overlay.data = "{\\pos(300,50)\\fs40\\c&H00FF00&}" .. username
	-- OK overlay:update()
-- end
-- mp.register_event("push-ra", function()
    -- Display "Bonjour" on the OSD (On Screen Display)
    -- mp.osd_message("PUSH", 5) -- The number '3' defines how many seconds the message will be shown
-- end)

-- This is a simple Lua script for mpv media player


-- Variables globales
local gfx_objects = {}
local refresh_interval = 0.02  -- Par exemple, 0.1 seconde
local achievements_data = {}
local screen_width = 1920
local screen_height = 1080
local sorted_objects = {}
local is_sorted_objects_dirty = true
local is_update_display_running = false

-- This function will be called when the file is loaded
mp.register_event("file-loaded", function()
    -- Display on the OSD (On Screen Display)
	--mp.osd_message("RetroAchievements loading...", 1)		
	init()
	
	--ov = mp.create_osd_overlay("ass-events")
	--ov.data = "{\\an5\\bord2\\3c&H000000&\\fs60\\1c&HFFFFFF&\\alpha&H0&\\fnArial}Arial{\\an6\\bord2\\3c&H000000&\\fs60\\1c&HFFFFFF&\\alpha&H0&\\fnRoboto}Roboto{\\p0}{\\an3\\bord2\\3c&H000000&\\fs60\\1c&HFFFFFF&\\alpha&H0&\\fnBebas Neue}BebasNeue{\\p0}{\\an9\\bord2\\3c&H000000&\\fs60\\1c&HFFFFFF&\\alpha&H0&\\fnVT323}VT323"
	--ov:update()

end)

function init()	
	-- mp.osd_message("Initialisation", 1)
	clear_osd(function()
		update_screen_dimensions()
		update_display_periodically()
	end)
end

function update_screen_dimensions()
    screen_width = mp.get_property_number("osd-width", 1920)
    screen_height = mp.get_property_number("osd-height", 1080)
end

function mark_sorted_objects_dirty()
    is_sorted_objects_dirty = true
end

-- #####################################
-- ############# CLEAR FUNCTIONS
-- #####################################

function clear_osd(callback)
    achievements_data = {}
    if next(gfx_objects) == nil then
        print("gfx_objects empty")
    else
        local names = {}
        for name, obj in pairs(gfx_objects) do
            table.insert(names, name)
        end

        for _, name in ipairs(names) do
            remove_object(name, function(wasRemoved)
                if wasRemoved then
                    -- print("Objet '" .. name .. "' a été supprimé avec succès.")
                end
            end)
        end
    end
    gfx_objects = {}
    mp.set_osd_ass(0, 0, "")
    if callback and type(callback) == "function" then
        callback()
    end
end

function clear_visible_objects(callback)
    local namesToRemove = {}
	mp.commandv('vf', 'clr')
    for name, obj in pairs(gfx_objects) do
        if obj.type == "image" then
            mp.commandv('vf', 'remove', '@' .. name)
        end
        table.insert(namesToRemove, name)
    end

    -- Supprimer les objets
    for _, name in ipairs(namesToRemove) do
        remove_object(name)
    end

    -- Vérifier si tous les objets ont été supprimés
    local checkIfAllRemoved = function()
        for _, name in ipairs(namesToRemove) do
            if gfx_objects[name] then
                return false
            end
        end
        return true
    end

    -- Exécuter le callback une fois que tous les objets sont supprimés
    local checkInterval = 0.1  -- Intervalle de vérification en secondes
    local function waitForRemoval()
        if checkIfAllRemoved() then
            if callback and type(callback) == "function" then
                callback()
            end
        else
            mp.add_timeout(checkInterval, waitForRemoval)
        end
    end

    waitForRemoval()
end

-- #####################################
-- ############# LISTEN DATAS
-- #####################################

function process_data(data)
    local data_split = {}
    for str in string.gmatch(data, "([^|]+)") do
        table.insert(data_split, str)
    end
    -- Vérification et traitement des données selon le type
    if data_split[1] == "user_info" then
		clear_osd(function()
			process_user_info(data_split)
		end)
    elseif data_split[1] == "game_info" then
        process_game_info(data_split)
    elseif data_split[1] == "achievement" then
        process_achievement(data_split)
	elseif data_split[1] == "achievement_info" then
        process_achievement_info(data_split)
    else
        mp.osd_message("Type de données inconnu: " .. data, 5)
	end
end

-- #####################################
-- ############# REFRESH SCREEN
-- #####################################

-- Fonction de mise à jour périodique
function update_display_periodically()
    gfx_refresh()
    if not is_update_display_running then
        is_update_display_running = true
        mp.add_timeout(refresh_interval, function()
            is_update_display_running = false
            update_display_periodically()
        end)
    end
end

function gfx_refresh()
    if is_sorted_objects_dirty then
        sorted_objects = {}
        for name, obj in pairs(gfx_objects) do
            table.insert(sorted_objects, {name = name, object = obj})
        end
        table.sort(sorted_objects, function(a, b) return a.object.z_index < b.object.z_index end)
        is_sorted_objects_dirty = false
    end

    for _, entry in ipairs(sorted_objects) do
        local obj = entry.object
        local obj_name = entry.name

        if not obj.overlay then
            obj.overlay = mp.create_osd_overlay("ass-events")
        end

        local ass_data = ""
        if obj.type == "shape" then
            ass_data = generate_ass_shape(obj.properties)
        elseif obj.type == "text" then
            ass_data = generate_ass_text(obj.properties)
        elseif obj.type == "image" then
            gfx_draw_image(obj_name, obj.properties, function()
                obj.updated = false
            end)
            -- Pas besoin de mise à jour d'overlay pour les images
            goto continue
        end

        -- Mise à jour des données de l'overlay
        if obj.updated then
            -- Obtenir les dimensions actuelles de l'OSD
			local osd_width = mp.get_property_number("osd-width", 1920)
			local osd_height = mp.get_property_number("osd-height", 1080)

			-- Mettre à jour les propriétés de l'overlay
			obj.overlay.res_x = osd_width
			obj.overlay.res_y = osd_height
			obj.overlay.data = ass_data

			-- Appliquer les modifications
			obj.overlay:update()

			-- Marquer l'objet comme non mis à jour
			obj.updated = false
        end

        ::continue::
    end
end

-- #####################################
-- ############# OBJECTS FUNCTIONS
-- #####################################

function create(name, type, properties, z_index)
    if gfx_objects[name] then
        gfx_objects[name] = nil
        -- print("Un objet avec le même nom '" .. name .. "' existe déjà.")
        return
    end
    gfx_objects[name] = {
        type = type,
        properties = properties,
        z_index = z_index or 0,  -- Assignez une valeur par défaut si z_index n'est pas fourni
		updated = true
    }
	mark_sorted_objects_dirty()
end

function set_object_properties(name, properties)
    local obj = gfx_objects[name]
    if not obj then
        print("Avertissement: L'objet nommé '" .. name .. "' n'existe pas.")
        return
    end
    -- Parcourir chaque propriété fournie et la mettre à jour
    for key, value in pairs(properties) do
        -- Gérer les cas spéciaux pour 'type' et 'z_index'
        if key == "type" then
            obj.type = value
        elseif key == "z_index" then
            obj.z_index = value
        elseif obj.properties and obj.properties[key] ~= nil then
            -- Mise à jour des autres propriétés standard
            obj.properties[key] = value
			obj.updated = true
        else
            print("Avertissement: La propriété '" .. key .. "' n'existe pas pour l'objet '" .. name .. "'.")
        end
    end
    -- Mettre à jour l'affichage pour refléter les changements
	mark_sorted_objects_dirty()
    -- gfx_refresh()
end

function get_object_property(name, property_key)
    local obj = gfx_objects[name]
    if not obj then
        print("Avertissement: L'objet nommé '" .. name .. "' n'existe pas.")
        return nil
    end
    -- Gérer les cas spéciaux pour 'type' et 'z_index'
    if property_key == "type" then
        return obj.type
    elseif property_key == "z_index" then
        return obj.z_index
    end
    -- Vérifier si la propriété existe dans les propriétés standard
    if obj.properties and obj.properties[property_key] ~= nil then
        return obj.properties[property_key]
    else
        print("Avertissement: La propriété '" .. property_key .. "' n'existe pas pour l'objet '" .. name .. "'.")
        return nil
    end
end


function remove_object(name, on_complete)
    local obj = gfx_objects[name]
    local wasRemoved = false

    if obj then
        if obj.type == "image" then
            mp.commandv('vf', 'remove', '@' .. name)
        end

        -- Supprimer l'overlay si existant
        if obj.overlay then
            obj.overlay:remove()
            obj.overlay = nil
        end

        -- Supprimer l'objet de la table
        gfx_objects[name] = nil
        mark_sorted_objects_dirty()
        -- gfx_refresh()
        wasRemoved = true
    else
        print("Avertissement: Impossible de supprimer, l'objet nommé '" .. name .. "' n'existe pas.")
    end

    if on_complete and type(on_complete) == "function" then
        on_complete(wasRemoved)
    end
end

function move(name, target_x, target_y, target_opacity, duration, on_complete)
    local obj = gfx_objects[name]
    if not obj then
        print("Avertissement: L'objet nommé '" .. name .. "' n'existe pas. Mouvement annulé.")
        return
    end

    local start_time = mp.get_time()
    local start_x = obj.properties.x
    local start_y = obj.properties.y
	-- mp.osd_message("Objet: " .. name .. " start_y: " .. start_y, 2)
    local start_opacity = obj.properties.opacity_decimal
    local delta_x = target_x - start_x
    local delta_y = target_y - start_y
    local delta_opacity = target_opacity - start_opacity

    -- Fonction pour mettre à jour la position et l'opacité de l'objet au fil du temps
    local function update_position_and_opacity()
        local current_time = mp.get_time()
        local progress = (current_time - start_time) / duration
        if progress >= 1 then
            -- Mouvement et changement d'opacité terminés
            obj.properties.x = target_x
            obj.properties.y = target_y
            obj.properties.opacity_decimal = target_opacity
			obj.updated = true
            if on_complete then
                on_complete()  -- Appeler le callback une fois terminé
            end
        else
            -- Mettre à jour la position et l'opacité de l'objet
            obj.properties.x = start_x + delta_x * progress
            obj.properties.y = start_y + delta_y * progress
            obj.properties.opacity_decimal = start_opacity + delta_opacity * progress
			obj.updated = true
            -- Planifier la prochaine mise à jour
			if progress < 1 then
				mp.add_timeout(0.01, update_position_and_opacity)
			end

        end
    end

    -- Démarrer la mise à jour de la position et de l'opacité
    update_position_and_opacity()
end

function fade_opacity(name, target_opacity, duration, on_complete)
    local obj = gfx_objects[name]
    if not obj then
        print("Avertissement: L'objet nommé '" .. name .. "' n'existe pas. Fondu annulé.")
        return
    end

    local start_time = mp.get_time()
    local start_opacity = obj.properties.opacity_decimal
    local delta_opacity = target_opacity - start_opacity

    -- Fonction pour mettre à jour progressivement l'opacité de l'objet
    local function update_opacity()
        local current_time = mp.get_time()
        local progress = (current_time - start_time) / duration
        if progress >= 1 then
            -- Changement d'opacité terminé
            obj.properties.opacity_decimal = target_opacity
            obj.updated = true
            if on_complete then
                on_complete()  -- Appeler le callback une fois terminé
            end
        else
            -- Mettre à jour l'opacité de l'objet
            obj.properties.opacity_decimal = start_opacity + delta_opacity * progress
            obj.updated = true
            -- Planifier la prochaine mise à jour
            if progress < 1 then
                mp.add_timeout(0.01, update_opacity)
            end
        end
    end

    -- Démarrer la mise à jour de l'opacité
    update_opacity()
end

function animate_properties(name, targets, duration, on_complete)
    local obj = gfx_objects[name]
    if not obj then
        print("Avertissement: L'objet nommé '" .. name .. "' n'existe pas. Animation annulée.")
        return
    end

    local start_values = {}
    local delta_values = {}

    -- Initialisation des valeurs de départ et des deltas
    for property, target_value in pairs(targets) do
        if obj.properties[property] == nil then
            print("Avertissement: La propriété '" .. property .. "' n'existe pas pour l'objet '" .. name .. "'.")
            return
        end
        start_values[property] = obj.properties[property]
        delta_values[property] = target_value - start_values[property]
    end

    local start_time = mp.get_time()

    -- Fonction pour mettre à jour progressivement les propriétés
    local function update_properties()
        local current_time = mp.get_time()
        local progress = (current_time - start_time) / duration
        if progress >= 1 then
            -- Appliquer les valeurs finales
            for property, _ in pairs(targets) do
                obj.properties[property] = targets[property]
            end
            obj.updated = true
            if on_complete then
                on_complete()  -- Appeler le callback une fois terminé
            end
        else
            -- Mettre à jour les propriétés de l'objet
            for property, delta_value in pairs(delta_values) do
                obj.properties[property] = start_values[property] + delta_value * progress
            end
            obj.updated = true
            -- Planifier la prochaine mise à jour
            if progress < 1 then
                mp.add_timeout(0.01, update_properties)
            end
        end
    end

    -- Démarrer la mise à jour des propriétés
    update_properties()
end

-- #####################################
-- ############# ASS & GFX FUNCTIONS
-- #####################################

function generate_ass_shape(properties)
	local decx = -10  -- Décalage en X
	local decy = -10  -- Décalage en Y
    local opacity_hex = math.floor(properties.opacity_decimal * 255)
    opacity_hex = string.format("%X", 255 - opacity_hex)

    local draw_command = properties.show and "m" or "n" -- Utilise "m" si show est vrai, sinon utilise "n"

    -- Appliquer le décalage global
    local x = properties.x + decx
    local y = properties.y + decy

    return string.format("{\\p1}{\\an7\\bord0\\shad0\\1c&H%s&\\1a&H%s&}%s %d %d l %d %d %d %d %d %d %d %d{\\p0}",
                         properties.color_hex, opacity_hex, draw_command,
                         x, y, 
                         x + properties.w, y, 
                         x + properties.w, y + properties.h, 
                         x, y + properties.h,
                         x, y)
end

function generate_ass_text(properties)
    -- Vérifier si l'attribut text est présent
    if not properties.text or (properties.show == false) then
        return ""
    end

    -- Valeurs par défaut
    local default_size = 20
    local default_color = "FFFFFF"  -- Blanc
    local default_align = 7
    local default_border_size = 2
    local default_opacity = 1
    local default_border_color = "000000"  -- Noir
    local default_shadow_distance = 0
    local default_font = "Arial"

    -- Construire la chaîne de style
    local style = ""

    -- Alignement
    style = style .. string.format("\\an%d", properties.align or default_align)
    -- Taille de la bordure
    style = style .. string.format("\\bord%d", properties.border_size or default_border_size)
    -- Couleur de la bordure
    style = style .. string.format("\\3c&H%s&", properties.border_color or default_border_color)
    -- Taille de la police
    style = style .. string.format("\\fs%d", properties.size or default_size)
    -- Couleur de la police
    style = style .. string.format("\\1c&H%s&", properties.color or default_color)
    -- Opacité
    local opacity_hex = math.floor((properties.opacity_decimal or default_opacity) * 255)
    opacity_hex = string.format("%X", 255 - opacity_hex)
    style = style .. string.format("\\alpha&H%s&", opacity_hex)
    -- Police
    style = style .. string.format("\\fn%s", properties.font or default_font)
    -- Distance de l'ombre
	if properties.shad then
		style = style .. string.format("\\shad%d", properties.shadow_distance or default_shadow_distance)
	 end
    -- Flou des bords (si spécifié)
    if properties.blur_edges then
        style = style .. string.format("\\be%d", properties.blur_edges)
    end
    -- Échelle de police (si spécifiée)
    if properties.font_scale_x then
        style = style .. string.format("\\fscx%d", properties.font_scale_x)
    end
    if properties.font_scale_y then
        style = style .. string.format("\\fscy%d", properties.font_scale_y)
    end
    -- Espacement des lettres (si spécifié)
    if properties.letter_spacing then
        style = style .. string.format("\\fsp%.2f", properties.letter_spacing)
    end
    -- Rotation (si spécifiée)
    if properties.rotation_x then
        style = style .. string.format("\\frx%.2f", properties.rotation_x)
    end
    if properties.rotation_y then
        style = style .. string.format("\\fry%.2f", properties.rotation_y)
    end
    if properties.rotation_z then
        style = style .. string.format("\\frz%.2f", properties.rotation_z)
    end
    -- Position X et Y
	if properties.x or properties.y then
		local posX = properties.x or 0
		local posY = properties.y or 0
		style = style .. string.format("\\pos(%d,%d)", posX, posY)
	end
    -- Construire la chaîne de texte finale
    local text_string = string.format("{\\r%s}%s", style, properties.text)
	-- mp.osd_message("text_string: " .. text_string)
	-- print(text_string)
    return text_string
end

function gfx_draw_image(name, properties, callback)
	-- mp.osd_message("gfx_draw_image name: " .. name)
    if properties.show then
        -- Afficher l'image
        local transformed_path = properties.image_path:gsub(".*\\(RA\\)", "%1"):gsub("\\", "/")
        local filter_str = string.format("@%s:lavfi=[movie='%s'[img];[img]scale=%d:%d[scaled];[vid1][scaled]overlay=%d:%d]",
                                         name, transformed_path, properties.w, properties.h, properties.x, properties.y)
        mp.commandv('vf', 'add', filter_str)
    else
        -- Cacher l'image
        mp.commandv('vf', 'remove', '@' .. name)
    end
    -- Exécuter un callback si nécessaire
    -- if properties.callback then properties.callback() end
	if callback then
        callback()
    end
end

-- #####################################
-- ############# PROCESS FUNCTIONS
-- #####################################

function process_user_info(data_split)
	-- Traitement des informations utilisateur
	local username = data_split[2]
	local userPicPath = data_split[3]
	-- mp.osd_message("Utilisateur: " .. username .. "\nImage: " .. userPicPath, 5)
	-- Overlay background
	create("BlackRectangle", "shape", {x = -128, y = 10, w = 128, h = 128, color_hex = "000000", show = true, opacity_decimal = 0} , 1)
	create("UserText", "text", {text = username .. " is connected", color = 'FFFFFF', x = 0, y = 0, size = 20, show = false, opacity_decimal = 1}, 2)
	create("UserImage", "image", {image_path = userPicPath, x = 10, y = 10, w = 128, h = 128, show = false, opacity_decimal = 1}, 3)
	-- create("ProgressBar", "shape", {x = 0, y = screen_height, w = screen_width+50, h = screen_height, color_hex = "000000", show = false, opacity_decimal = 0.5} , 5)
	-- create("Pixels", "image", {image_path = 'RA/Badge/62947.png', x = 30, y = 30, w = 64, h = 64, show = true, opacity_decimal = 1}, 3)
	-- move(name, target_x, target_y, target_opacity, duration, on_complete)
	mp.osd_message(username .. " is connecting...", 3)
	move("BlackRectangle", 10, 10, 0.2, 0.5, function ()	
		--set_object_properties('BlackRectangle', {x = 30, y = 30, show = false})		
		-- set_object_properties('UserText', {show = true})	
		-- move("UserText", 50, 0, 1, 0.4, nil)
		set_object_properties('UserImage', {show = true})
		--set_object_properties('UserText', {show = true})	
		mp.add_timeout(3, function()	
			--move("UserText", 0, -50, 0, 0.5, nil)
			-- move("UserText", 10, 10, 1, 0.4, nil)
			set_object_properties('UserImage', {show = false})
			--set_object_properties('UserText', {show = false})	
			-- move("UserText", -50, 0, 0, 0.4, nil)
			move("BlackRectangle", -128, 10, 0, 0.5, function ()	
				remove_object("BlackRectangle", function ()	
				--remove_object("UserText", nil)
				remove_object("UserImage", nil)
					-- move("ProgressBar", 0, screen_height-50, 0.7, 0.5, nil)
				end)
			end)
		end)
	end)
	
	--create("WhiteRectangle", "shape", {x = -128, y = 0, w = 128, h = 128, color_hex = "FFFFFF", opacity_decimal = 0.5} , 2)
	
	
	-- create("Background", "shape", {x = 0, y = 0, w = mp.get_property_number("osd-width", 1920), h = mp.get_property_number("osd-height", 1080), color_hex = "000000", opacity_decimal = 0.6}, 1)
	-- move("Pixels", 128, 128, 1, 1, nil)

end

function process_game_info(data_split)
	update_screen_dimensions()
    -- Traitement des informations du jeu
    local gameTitle = data_split[2]
    local gameIconPath = data_split[3]
    local numAchievementsUnlocked = data_split[4]
    local userCompletion = data_split[5]
    local totalAchievements = data_split[6]
	--create("Pixels", "image", {image_path = 'RA/Anim/pixels.gif', x = 30, y = 30, w = 128, h = 128, show = true, opacity_decimal = 1}, 5)
	
	--create("Points", "text", {text = "+255pts",color = "FFFFFF",x = screen_width/2,y = screen_height/2,size = 40,font = "Arial",show = true,opacity_decimal = 1}, 25)
	
    mp.add_timeout(5, function()
		show_achievements()	
		mp.add_timeout(2, function()
			show_score()	
		end)			
	end)
	
end

function process_achievement_info(data_split)
	-- print("Processing achievement info")
    -- Extraction des informations de l'achievement
    local achievementID = data_split[2]
    local achievementInfo = {
        NumAwarded = data_split[3],
        NumAwardedHardcore = data_split[4],
        Title = data_split[5],
        Description = data_split[6],
        Points = data_split[7],
        TrueRatio = data_split[8],
        BadgeURL = data_split[9],
        DisplayOrder = data_split[10],
        Type = data_split[11],
        Unlock = data_split[12]
    }
    -- Stocker les informations dans la variable globale
	-- print(achievementInfo)
    achievements_data[achievementID] = achievementInfo
end

function process_achievement(data_split)
    -- Traitement des informations de succès
	-- "achievement|2|C:\\RetroBat\\marquees\\RA\\Badge\\250352.png|Amateur Collector|Collect 20 rings|2|8.33%"
    local achievementId = data_split[2]
    local badgePath = data_split[3]
    local title = data_split[4]
    local description = data_split[5]
    local numAwardedToUser = data_split[6]
    local userCompletion = data_split[7]

    -- Récupérer des informations supplémentaires depuis achievements_data
    local achievementInfo = achievements_data[achievementId]
    local points = achievementInfo and achievementInfo.Points or "Inconnu"
    local numAwarded = achievementInfo and achievementInfo.NumAwarded or "Inconnu"
    local numAwardedHardcore = achievementInfo and achievementInfo.NumAwardedHardcore or "Inconnu"
    local trueRatio = achievementInfo and achievementInfo.TrueRatio or "Inconnu"
	
	if achievements_data[achievementId] then
        achievements_data[achievementId].Unlock = "True"  -- Marquer comme débloqué
        achievements_data[achievementId].NumAwarded = tostring(tonumber(achievements_data[achievementId].NumAwarded or "0") + 1)
    end
	
	-- Calculer le score total
	local totalPoints = 0
    for id, ach in pairs(achievements_data) do		
		local achievementName = "AchievementImage" .. id
		set_object_properties(achievementName, {y = screen_height+74})
        if ach.Unlock == "True" then
            totalPoints = totalPoints + (tonumber(ach.Points) or 0)
        end
    end
	-- gfx_refresh()
	
    -- Construire et afficher le message
    local message = string.format(
        "Succès débloqué: %s\nID: %s\nBadge: %s\nDescription: %s\nPoints: %s\nDébloqué par: %s utilisateurs\nDébloqué en mode hardcore par: %s utilisateurs\nRatio: %s\nPourcentage de complétion: %s\nTotal des points: %d",
        title, achievementId, badgePath, description, points, numAwarded, numAwardedHardcore, trueRatio, userCompletion, totalPoints
    )

    -- mp.osd_message(message, 10)  -- Afficher le message pendant 10 secondes

    -- Créer les éléments graphiques pour l'affichage de l'achievement
	local backgroundShape = "AchievementBackgroundShape"
    local backgroundName = "AchievementBackground"
	local cupName = "AchievementCup"
    local badgeName = "AchievementBadge"
    local textAchievement = "AchievementTxt"

	clear_visible_objects(function()
		create(backgroundShape, "shape", {x = 0, y = 0, w = screen_width, h = screen_height, color_hex = "000000", opacity_decimal = 0}, 1)
		mp.add_timeout(1, function()
			-- move(name, target_x, target_y, target_opacity, duration, on_complete)
			fade_opacity(backgroundShape,  0.8, 2, function()	
				create(backgroundName, "image", {image_path = 'RA/System/background.png', x = 0, y = 0, w = screen_width, h = screen_height, show = false, opacity_decimal = 1}, 2)
				mp.add_timeout(1, function()
					-- Positionnement de l'image du badge	
					set_object_properties(backgroundName, {show = true})
					fade_opacity(backgroundShape,  0, 1, function()
						-- remove_object(backgroundShape)
						-- (screen_height - 235) / 2 + text_decy
						create(cupName, "image", {
							image_path = 'RA/System/biggoldencup.png',
							x = (screen_width - 238) / 2,
							y = (screen_height - 235) / 2,
							w = 238,
							h = 235,
							show = false,
							opacity_decimal = 1
						}, 26)
						create(badgeName, "image", {
							image_path = badgePath,
							x = (screen_width - 64) / 2,
							y = (screen_height - 235) / 2 + 41,
							w = 64,
							h = 64,
							show = false,
							opacity_decimal = 1
						}, 27)
						create(textAchievement, "text", {
							text = title .. "!",
							color = "FFFFFF",
							size = 70,
							font = "VT323",						
							align=2,
							show = true,
							border_size = 5,
							opacity_decimal = 0
						}, 25)
						-- move(name, target_x, target_y, target_opacity, duration, on_complete)	
						-- fade_opacity(name, target_opacity, duration, on_complete)						
						mp.add_timeout(0.1, function()							
							set_object_properties(cupName, {show = true})
							set_object_properties(badgeName, {show = true})						
							fade_opacity(textAchievement, 1, 1, function()
								mp.add_timeout(1, function()  
									fade_opacity(textAchievement, 0, 1, function()
										set_object_properties(textAchievement, {size = 80})
										set_object_properties(textAchievement, {text = "(" .. description .. ")"})
										mp.add_timeout(1, function()  
											fade_opacity(textAchievement, 1, 1, function()												
												mp.add_timeout(1, function()  														
													fade_opacity(textAchievement, 0, 1, function()
														set_object_properties(textAchievement, {size = 140})
														set_object_properties(textAchievement, {text = "+" .. points .. "pts"})
														mp.add_timeout(1, function()  
															fade_opacity(textAchievement, 1, 1, function()												
																mp.add_timeout(1, function()  														
																	fade_opacity(textAchievement, 0, 1, function()
																		fade_opacity(backgroundShape,  1, 0, function()
																			remove_object(textAchievement)		
																			remove_object(badgeName)
																			remove_object(cupName)            
																			remove_object(backgroundName)													
																			fade_opacity(backgroundShape,  2, 1, function()
																				remove_object(backgroundShape)
																				show_achievements()
																				show_score()
																			end)
																		end)
																	end)
																end)
															end)
														end)
													end)
												end)
											end)
										end)
									end)
								end)
							end)
						end)
					end)
				end)
			end)
		end)
    end)

end

-- #####################################
-- ############# SHOW FUNCTIONS
-- #####################################

function show_userCompletionProgressBar()
	move_rectangle(-1, screen_height, screen_width, 20, 0, '000000', 0, screen_height - 20, 0.5, 50, nil)
end

function show_achievementsProgressBar()
	move_rectangle(-1, screen_height, screen_width, 50, 0, '000000', 0, screen_height - 50, 0.8, 50, nil)
end

function show_achievements()
	update_screen_dimensions()
	if next(achievements_data) == nil then
		print("Aucun achievement à afficher.")
		return
	end

	-- Compter le nombre d'achievements débloqués
	local numAchievementsUnlocked = 0
	for _, ach in pairs(achievements_data) do
		if ach.Unlock == "True" then
			numAchievementsUnlocked = numAchievementsUnlocked + 1
		end
	end

	-- Tri des achievements
	local sorted_achievements = {}
	for id, ach in pairs(achievements_data) do
		table.insert(sorted_achievements, {id = id, data = ach})
	end

	table.sort(sorted_achievements, function(a, b)
		local unlockA = a.data.Unlock == "True"
		local unlockB = b.data.Unlock == "True"
		if unlockA == unlockB then
			return tonumber(a.data.DisplayOrder) < tonumber(b.data.DisplayOrder)
		else
			return unlockA and not unlockB
		end
	end)

	local xPos = 4
	local yPos = 14
	local imageWidth = 64
	local imageSpacing = 4
	local order = 10

	-- Barre noire du bas
	-- mp.osd_message("Display w" .. screen_width .. " h" .. screen_height .. " osd_width" .. mp.get_property_number("osd-width", 1920) .. " osd-height" .. mp.get_property_number("osd-height", 1080), 10)
	-- screen_width = mp.get_property_number("osd-width", 1920)
    -- screen_height = mp.get_property_number("osd-height", 1080)
	create("BottomBar", "shape", {x = 0, y = screen_height, w = screen_width, h = 50, color_hex = "000000", opacity_decimal = 0.5}, 1)
	--animate_properties(name, targets, duration, on_complete)
	animate_properties("BottomBar", {y = screen_height-16, opacity_decimal = 0.6}, 1, nil)

	-- Calcul du nombre maximum d'achievements par ligne
	local maxAchievementsPerLine = math.floor((screen_width - xPos) / (imageWidth + imageSpacing))

	-- Déterminer l'index de départ pour l'affichage
	local startIndex = math.max(1, numAchievementsUnlocked - 5)
	local endIndex = math.min(startIndex + maxAchievementsPerLine - 1, #sorted_achievements)

	-- Affichage des achievements
	for i = startIndex, endIndex do
		local achievement = sorted_achievements[i]
		local achievementName = "AchievementImage" .. achievement.id

		-- Création et positionnement de l'achievement
		create(achievementName, "image", {
			image_path = achievement.data.BadgeURL,
			x = xPos,
			y = screen_height - yPos,
			w = imageWidth,
			h = imageWidth,
			show = true,
			opacity_decimal = 1
		}, order)

		xPos = xPos + imageWidth + imageSpacing
		order = order + 1
	end

	-- Fonction pour animer les achievements débloqués
	local index = 1
	local yPosAdjustment = 54

	local function animate_next_achievement()
		if index > #sorted_achievements or index > 10 then
			return  -- Arrête la récurrence si tous les achievements ont été traités ou si on a atteint 10
		end

		local achievement = sorted_achievements[index]
		local achievementName = "AchievementImage" .. achievement.id

		if achievement.data.Unlock == "True" then
			-- Récupérer la position x actuelle de l'image
			local currentXPos = get_object_property(achievementName, "x")
			-- mp.osd_message("currentXPos: " .. currentXPos)
			if currentXPos == nil then
				print("Impossible de récupérer la position x pour " .. achievementName)
				index = index + 1
				animate_next_achievement()
				return
			end

			local currentY = screen_height - yPos - yPosAdjustment
			set_object_properties(achievementName, {y = currentY})	
			index = index + 1
			animate_next_achievement()
			--move(achievementName, currentXPos, currentY, 1, 0.5, function()
			--	index = index + 1
			--	animate_next_achievement()  -- Appel récursif pour le prochain achievement
			--end)
		else
			index = index + 1
			animate_next_achievement()  -- Passe directement au prochain si celui-ci n'est pas débloqué
		end
	end

	-- Démarrer la séquence d'animation
	animate_next_achievement()
end

local score = 0
function show_score()
    local scoreTextName = "GameScoreText"
    local currentPoints = 0

    -- Calculer le score total
    for _, ach in pairs(achievements_data) do
        if ach.Unlock == "True" then
            currentPoints = currentPoints + (tonumber(ach.Points) or 0)
        end
    end

    -- Fonction pour mettre à jour le texte du score
    local function show_score_text(points)
        local text_properties = {
			align = 9,
            text = "Score : " .. points .. " pts",
            color = "FFFFFF",
            size = 50,
            font = "Bebas Neue",
			border_size = 4
        }

        if gfx_objects[scoreTextName] then
            set_object_properties(scoreTextName, text_properties)
        else
            create(scoreTextName, "text", text_properties, 50)
        end
    end
	
    show_score_text(currentPoints)
end


function show_random_goldencups(callback)
    local cupImagePath = "RA/System/goldencup.png"
    local cupSize = 64
    local numCups = 10  -- Nombre de coupes à afficher
    local cupLifetime = 0.1  -- Durée de vie d'une coupe en secondes
    local sequenceDuration = 5  -- Durée totale de la séquence en secondes
    local cupInterval = sequenceDuration / numCups  -- Intervalle de création des coupes

    for i = 1, numCups do
        -- Créer une coupe après un certain délai
        mp.add_timeout((i - 1) * cupInterval, function()
            local randomX = math.random(screen_width * 0.25, screen_width * 0.75 - cupSize)
            local randomY = math.random(screen_height * 0.25, screen_height * 0.75 - cupSize)
            local cupName = "Goldencup" .. i

            create(cupName, "image", {
                image_path = cupImagePath,
                x = randomX,
                y = randomY,
                w = cupSize,
                h = cupSize,
                show = true,
                opacity_decimal = 1
            })

            -- Supprimer la coupe après 0.2 seconde
            mp.add_timeout(cupLifetime, function()
                remove_object(cupName)
            end)
        end)
    end

    if callback then
        callback()
    end
end

-- Register the 'push-ra' message for processing
mp.register_script_message("push-ra", process_data)
