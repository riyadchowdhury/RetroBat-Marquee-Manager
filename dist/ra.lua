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
	-- OK : mp.command('vf add lavfi=[movie=\'Nelfe.png\'[img],[vid1][img]overlay=W-w-10:H-h-10]')
	-- OK : mp.commandv('vf', 'add', 'lavfi=[movie=\'Nelfe.png\'[img],[vid1][img]overlay=W-w-10:H-h-10]')
	-- OK : local imagepath = 'RA/UserPic/Nelfe.png'
	-- OK : mp.commandv('vf', 'remove', '@user')
	-- OK : mp.commandv('vf', 'clr')
	-- OK local overlay = mp.create_osd_overlay("ass-events")
	-- OK overlay.data = "{\\pos(300,50)\\fs40\\c&H00FF00&}" .. username
	-- OK overlay:update()
-- end

-- This is a simple Lua script for mpv media player

-- Variables globales
local gfx_objects = {}
local refresh_interval = 0.02  -- Par exemple, 0.1 seconde
local achievements_data = {}
-- dimensions de l'écran
local screen_width = 0
local screen_height = 0
-- dimensions de l'image
local image_width = 0
local image_height = 0
local sorted_objects = {}
local is_sorted_objects_dirty = true
local is_update_display_running = false
local initialisation = true
local initscreen = "RA/Cache/_initscreen.png"

mp.register_event("file-loaded", function()
	-- mp.osd_message("register_event", 1)
	if initialisation then
		-- achievements_data = {}
		-- mp.osd_message("Initialisation", 5)
		init()
		initialisation = false
	end
end)

-- Fonction pour afficher le nom de la touche pressée
function display_key_binding(name, event)
    local key_name = event["key_name"]
    if key_name then
        -- mp.osd_message("Touche pressée : " .. key_name)
    end
end
-- Écouter tous les événements de clavier et de souris
mp.register_event("key-binding", display_key_binding)

function init()	
	clear_osd(function()
		update_screen_dimensions(nil)
		update_display_periodically()
	end)	
end

-- #####################################
-- ############# CLEAR FUNCTIONS
-- #####################################

function clear_osd(callback)
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

local chrono_mode = false -- Etat mode chrono global
function process_data(data)
    local data_split = {}
    for str in string.gmatch(data, "([^|]+)") do
        table.insert(data_split, str)
    end
    -- Vérification et traitement des données selon le type
    if data_split[1] == "user_info" then
		achievements_data = {}
		chrono_mode = false
		clear_osd(function()
			process_user_info(data_split)
		end)
    elseif data_split[1] == "game_info" then
        process_game_info(data_split)
	elseif data_split[1] == "game_stop" then
		process_game_stop(data_split)
    elseif data_split[1] == "achievement" then
		process_achievement(data_split)
	elseif data_split[1] == "achievement_info" then
        process_achievement_info(data_split)
	elseif data_split[1] == "leaderboardtimes" then
        process_leaderboardtimes(data_split)		
	elseif data_split[1] == "leaderboard_event_started" then
        process_leaderboard_started(data_split)
	elseif data_split[1] == "leaderboard_event_canceled" then
        process_leaderboard_canceled(data_split)
	elseif data_split[1] == "leaderboard_event_submitting" then
        process_leaderboard_submitting(data_split)
	elseif data_split[1] == "leaderboard_event_submitted" then
        --process_leaderboard_submitted(data_split)
    else
        mp.osd_message("Type de données inconnu: " .. data, 2)
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

function update_screen_dimensions(callback)
    local function check_dimensions()
        screen_width = mp.get_property_number("osd-width")
        screen_height = mp.get_property_number("osd-height")
		image_width = mp.get_property_number("dwidth")
        image_height = mp.get_property_number("dheight")

        -- Si les dimensions sont mises à jour, exécutez la callback
        if screen_width ~= 0 and screen_height ~= 0 then
            if callback then
				-- mp.osd_message("screen_width" .. screen_width .. " screen_height" .. screen_height .. "image_width" .. image_width .. " image_height" .. image_height, 10)
                callback()
            end
        else
            -- Sinon, planifiez une nouvelle vérification après un court délai
            mp.add_timeout(0.01, check_dimensions)
        end
    end
    -- Démarrez la première vérification
    check_dimensions()
end

local last_refresh_time = 0
local framerate_threshold = 10  -- Seuil de framerate


function gfx_refresh()
    local current_time = mp.get_time()
    local delta_time = current_time - last_refresh_time
    last_refresh_time = current_time

    local framerate = 0
    if delta_time > 0 then
        framerate = 1 / delta_time
    end

    if framerate < framerate_threshold then
        -- mp.osd_message(string.format("Low Framerate : %.2f FPS", framerate), 1)
    end

    for obj_name, obj in pairs(gfx_objects) do
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
            obj.overlay.res_x = image_width
            obj.overlay.res_y = image_height
            obj.overlay.data = ass_data
            obj.overlay.z = obj.z
            -- mp.osd_message("obj_name" .. obj_name .. "z" .. obj.overlay.z, 10)
            obj.overlay:update()
            obj.updated = false
        end

        ::continue::
    end
end


local cache_screen_referer
function cache_screen(name, hide, referer, callback)
    local temp_hidden_objects = {}
	local path = "RA/Cache/" .. name .. ".png"
    -- Désactiver temporairement les objets de type "shape" et "text"
    for obj_name, obj in pairs(gfx_objects) do
        if obj.type == "shape" or obj.type == "text" then
            if obj.properties.show then
                temp_hidden_objects[obj_name] = true
                set_object_properties(obj_name, { show = false })
            end
        end
    end
    -- Attendre un court délai pour le rafraîchissement
    mp.add_timeout(0.2, function()
        -- Prendre un screenshot
        mp.commandv("screenshot-to-file", path)
        -- Réactiver les objets "shape" et "text" désactivés
        for obj_name, _ in pairs(temp_hidden_objects) do
            set_object_properties(obj_name, { show = true })
        end
		-- Mémorisation de cette image cache pour restoration ultèrieure
		if referer then
            cache_screen_referer = path
        end
		mp.add_timeout(0.2, function()
			if hide then
				for obj_name, obj in pairs(gfx_objects) do
					if obj.type == "image" then
						set_object_properties(obj_name, { show = false })
					end
				end
			end
		end)
        -- Affichage du screenshot en fond
		mp.add_timeout(0.2, function()
			mp.commandv("loadfile", path)
			-- Si hide est true, désactiver tous les objets de type "image"	
		end)
		if callback then callback() end
    end)
end

function restore_cache_screen(cacheimg)
    if cacheimg then
        -- Afficher l'image en cache spécifiée
		mp.commandv("loadfile", cacheimg)
    elseif cache_screen_referer then
        -- Afficher l'image référencée par cache_screen_referer
        mp.commandv("loadfile", cache_screen_referer)
    else
        print("Aucune image en cache spécifiée ou aucun cache_screen_referer défini.")
    end
end

-- #####################################
-- ############# OBJECTS FUNCTIONS
-- #####################################

function create(name, type, properties, z)
    if gfx_objects[name] then
        -- Mettre à jour les propriétés de l'objet existant
        gfx_objects[name].type = type
        for key, value in pairs(properties) do
            gfx_objects[name].properties[key] = value
        end
        gfx_objects[name].overlay.z = z or gfx_objects[name].z
        gfx_objects[name].updated = true
    else
        -- Créer un nouvel objet si aucun objet avec ce nom n'existe
        gfx_objects[name] = {
            type = type,
            properties = properties,
            z = z or 0,
            updated = true
        }
    end
end

function set_object_properties(name, properties)
    local obj = gfx_objects[name]
    if not obj then
        print("Avertissement: L'objet nommé '" .. name .. "' n'existe pas.")
        return
    end
    -- Parcourir chaque propriété fournie et la mettre à jour
    for key, value in pairs(properties) do
        -- Gérer les cas spéciaux pour 'type' et 'z'
        if key == "type" then
            obj.type = value
        elseif key == "z" then
			obj.z = value
        elseif obj.properties and obj.properties[key] ~= nil then
            -- Mise à jour des autres propriétés standard
            obj.properties[key] = value
			obj.updated = true
        else
            print("Avertissement: La propriété '" .. key .. "' n'existe pas pour l'objet '" .. name .. "'.")
        end
    end
    -- Mettre à jour l'affichage pour refléter les changements
    -- gfx_refresh()
end

function get_object_property(name, property_key)
    local obj = gfx_objects[name]
    if not obj then
        print("Avertissement: L'objet nommé '" .. name .. "' n'existe pas.")
        return nil
    end
    -- Gérer les cas spéciaux pour 'type' et 'z'
    if property_key == "type" then
        return obj.type
    elseif property_key == "z" then
        return obj.z
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
	
	-- local decx = 0  -- Décalage en X
	-- local decy = 0  -- Décalage en Y

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
    return text_string
end

function gfx_draw_image(name, properties, callback)
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

local chrono_active = false -- Chrono en marche
local chrono_start_time
local chrono_paused = false
local paused_time = 0  -- Temps écoulé à la mise en pause
local record_time_global

function update_chrono_display()
    if not chrono_active then
        return
    end

    local elapsed
    if chrono_paused then
        elapsed = paused_time
    else
        elapsed = mp.get_time() - chrono_start_time
    end

    local minutes = math.floor(elapsed / 60)
    local seconds = math.floor(elapsed % 60)
    local centiseconds = math.floor((elapsed - math.floor(elapsed)) * 100)
    local display_time = string.format("%d:%02d.%02d", minutes, seconds, centiseconds)

    set_object_properties("Chrono", {text = display_time})

	local progression
    if record_time_global then
        progression = math.min(elapsed / record_time_global, 1)
    else
        progression = 0  -- Aucun record, donc progression est 0
    end
    local color_hex = calculate_progression_color(progression)
    set_object_properties("ProgressionBar", {
        w = (screen_width+10) * progression,
        color_hex = color_hex
    })

    if not chrono_paused then
        mp.add_timeout(0.01, update_chrono_display)
    end
end

function toggle_chrono_pause()
    if chrono_active then
        chrono_paused = not chrono_paused
        if chrono_paused then
            paused_time = mp.get_time() - chrono_start_time
        else
            chrono_start_time = mp.get_time() - paused_time
            update_chrono_display()
        end
    end
end

-- Captation de la touche start pour gérer les pause en jeu (désolé, mais des fois ça marche pas bien...)
mp.add_key_binding("GAMEPAD_START", "toggle_chrono", toggle_chrono_pause)

-- Fonction pour calculer la couleur de progression
function calculate_progression_color(progression)
    local b, g, r

    if progression < 0.5 then
        -- Interpoler entre vert (0x00FF00) et orange (0x00A5FF)
        b = 0
		g = 0xFF
        r = 0xA5 * progression / 0.5        
    elseif progression < 0.8 then
        -- Interpoler entre orange (0x00A5FF) et rouge (0xFF0000)
        local local_progress = (progression - 0.5) / 0.3
        b = 0
		g = 0xFF - 0xFF * local_progress
        r = 0xA5 + (0xFF - 0xA5) * local_progress        
    else
        -- Reste sur rouge
        b, g, r = 0, 0, 0xFF
    end

    return string.format("%02X%02X%02X", b, g, r)
end

-- Fonction pour convertir le temps en secondes
function convert_time_to_seconds(time_str)
    local mins, secs, cents = time_str:match("(%d+):(%d+).(%d+)")
    return tonumber(mins) * 60 + tonumber(secs) + tonumber(cents) / 100
end

-- #####################################
-- ############# PROCESS FUNCTIONS
-- #####################################&

function process_leaderboard_started(data_split)
	show_score()
    chrono_mode = true
	set_object_properties("BottomBar", {show = false})
	create("BackgroundBar", "shape", {
        x = 0, y = 0,
        w = screen_width, h = screen_height,
        color_hex = "000000",
        opacity_decimal = 0.6
    }, 1)
	
	
    local text_properties = {
        align = 6,
        text = "0:00.00",
        color = "FFFFFF",
        size = 400,
        font = "Bebas Neue",
        border_size = 5
    }

    if gfx_objects["Chrono"] then
        set_object_properties("Chrono", text_properties)
    else
        create("Chrono", "text", text_properties, 100)
    end

    -- Créer un shape pour la progression
    create("ProgressionBar", "shape", {
        x = 0, y = 0,
        w = 0, h = screen_height,
        color_hex = "00FF00",
        opacity_decimal = 0.7
    }, 2)

	local record_text_properties = {
        align = 3,
        color = "FFFFFF",
        size = 100,
        font = "Bebas Neue",
        border_size = 3
    }

    -- Démarrer le chronomètre	
	if data_split[4] ~= "No Record" then
        record_time_global = convert_time_to_seconds(data_split[4])
		record_text_properties.text = "Record: " .. data_split[4]
    else
        record_time_global = nil -- Aucun record disponible
		record_text_properties.text = "Record: No Record"
    end
	
	create("RecordTime", "text", record_text_properties, 200)
	
    chrono_active = true
    chrono_paused = false
    chrono_start_time = mp.get_time() - 0.43
	
    update_chrono_display()
end

function process_leaderboard_canceled(data_split)
    -- Arrêter le chronomètre
	clear_osd(function()
		restore_cache_screen(initscreen)
	end)
    chrono_active = false
end

function process_leaderboard_submitting(data_split)
	show_score()
	animate_properties("BottomBar", {y = screen_height-13, opacity_decimal = 0.7}, 3, nil)
    -- Arrêter le chronomètre
    local final_time_str = data_split[3]
    set_object_properties("Chrono", {text = final_time_str})	
    chrono_active = false
	
	local submitted_time = convert_time_to_seconds(data_split[3])
    local time_diff = record_time_global and (submitted_time - record_time_global) or nil

    if time_diff then
        local diff_minutes = math.abs(math.floor(time_diff / 60))
        local diff_seconds = math.abs(math.floor(time_diff % 60))
        local diff_display = string.format("%d:%02d", diff_minutes, diff_seconds)

        if time_diff < 0 then
            -- Nouveau record
            set_object_properties("RecordTime", {
                text = "New record! -" .. diff_display,
                color = "00FF00" -- Vert
            })
        else
            -- En retard par rapport au record
            set_object_properties("RecordTime", {
                text = "No record! +" .. diff_display,
                color = "0000FF" -- Rouge
            })
        end
    else
        -- Aucun record précédent n'était disponible ou le temps soumis n'était pas un record
        set_object_properties("RecordTime", {
            text = "Record",
            color = "FFFFFF" -- Blanc
        })
    end
end

function process_leaderboardtimes(data_split)
	-- leaderboardtimes|2|0:44.66
end

local hardcoreMode = "False"
function process_user_info(data_split)
	-- Traitement des informations utilisateur
	local username = data_split[2]
	local userPicPath = data_split[3]
	local userLanguage = data_split[4]
	hardcoreMode = data_split[5]
	local textColor
    if hardcoreMode == "True" then
        textColor = "FFFFFF" -- White si hardcore
    else
        textColor = "808080" -- Gris sinon
    end
	-- Overlay background
	create("BlackRectangle", "shape", {x = -128, y = 10, w = 128, h = 128, color_hex = "000000", show = true, opacity_decimal = 0} , 1)
	create("UserText", "text", {text = username .. " connected", color = textColor, font = "VT323", x = 0, y = 90, border = 3, size = 40, show = true, opacity_decimal = 0}, 2)
	create("UserImage", "image", {image_path = userPicPath, x = 10, y = 10, w = 128, h = 128, show = false, opacity_decimal = 1}, 3)
	move("BlackRectangle", 10, 10, 0.2, 0.5, function ()	
		move("UserText", 30, 90, 1, 1, nil)
		set_object_properties('UserImage', {show = true})
		mp.add_timeout(3, function()	
			set_object_properties('UserImage', {show = false})
			move("UserText", -50, 90, 0, 0, nil)
			move("BlackRectangle", -128, 10, 0, 0.5, function ()	
				remove_object("BlackRectangle", function ()	
					remove_object("UserImage", nil)
					remove_object("UserText", nil)
				end)
			end)
		end)
	end)
end

function process_game_info(data_split)
	update_screen_dimensions(nil)
	
    -- Traitement des informations du jeu
    local gameTitle = data_split[2]
    local gameIconPath = data_split[3]
    local numAchievementsUnlocked = data_split[4]
    local userCompletion = data_split[5]
    local totalAchievements = data_split[6]
	--create("Pixels", "image", {image_path = 'RA/Anim/pixels.gif', x = 30, y = 30, w = 128, h = 128, show = true, opacity_decimal = 1}, 5)

    mp.add_timeout(3, function()
		cache_screen("_initscreen", false, false)
		show_achievements(function()
			print("Animation des achievements terminée")
			mp.add_timeout(2, function()
				cache_screen("_cacheAchv", true, true, function()
					print("Image cache des achievements")
					show_score()
				end)
			end)	
		end)		
	end)
	
end

function process_marquee_compose(data_split)
	update_screen_dimensions(nil)
	local name = "logo"
	mp.commandv('vf', 'remove', '@' .. name)
    -- Traitement des informations du marquee
	local fanart_file_path = data_split[4]:gsub("\\", "/")
    local fanart_top_y = data_split[5]
    local logo_file_path = data_split[2]:gsub("\\", "/")
    local logo_align = data_split[3]
	local logo_new_width = image_width / 2

	local x_position
    if logo_align == "left" then
        x_position = image_width / 10  -- 1/10th from left
    elseif logo_align == "center" then
        x_position = (image_width - logo_new_width) / 2  -- Center
    elseif logo_align == "right" then
        x_position = image_width - logo_new_width - (image_width / 10)  -- 1/10th from right
    end

	mp.commandv("loadfile", fanart_file_path)

	-- Échapper les apostrophes et les deux-points
	local escapedImagePath = logo_file_path:gsub("'", "\\'"):gsub(":", "\\:")
	local filter_str = string.format("@%s:lavfi=[movie='%s'[img];[img]scale=%d:%d[scaled];[vid1][scaled]overlay=%d:%d]",
									 name, escapedImagePath, logo_new_width, -1, x_position, 10)
	mp.commandv('vf', 'add', filter_str)
	mp.add_timeout(0.5, function()
		mp.commandv("screenshot-to-file", "_cacheMarquee.png")
		mp.add_timeout(0.2, function()
			mp.add_timeout(0.2, function()
				mp.commandv("loadfile", "_cacheMarquee.png")
				mp.add_timeout(0.2, function()
					mp.commandv('vf', 'remove', '@' .. name)
				end)
			end)
		end)
	end)
end

function process_game_stop(data_split)
	clear_osd(function()
		restore_cache_screen(initscreen)
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
	update_screen_dimensions(nil)
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
	local points = achievementInfo and tonumber(achievementInfo.Points) or 0
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
		set_object_properties(achievementName, {y = image_height+74})
        if ach.Unlock == "True" then
            totalPoints = totalPoints + (tonumber(ach.Points) or 0)
        end
    end

    -- Construire et afficher le message
    local message = string.format(
        "Succès débloqué: %s\nID: %s\nBadge: %s\nDescription: %s\nPoints: %s\nDébloqué par: %s utilisateurs\nDébloqué en mode hardcore par: %s utilisateurs\nRatio: %s\nPourcentage de complétion: %s\nTotal des points: %d",
        title, achievementId, badgePath, description, points, numAwarded, numAwardedHardcore, trueRatio, userCompletion, totalPoints
    )

	if chrono_mode == false then
		-- Créer les éléments graphiques pour l'affichage de l'achievement
		local backgroundShape = "AchievementBackgroundShape"
		local backgroundName = "AchievementBackground"
		local cupName = "AchievementCup"
		local badgeName = "AchievementBadge"
		local textAchievement = "AchievementTxt"

		-- clear_visible_objects(function()
		    create(backgroundShape, "shape", {x = 0, y = -1, w = image_width, h = image_height+1, color_hex = "000000", opacity_decimal = 0}, 1)
			create(badgeName, "image", {
				image_path = badgePath,
				x = (image_width - 64) / 2,
				y = (image_height - 235) / 2 + 41,
				w = 64,
				h = 64,
				show = false,
				opacity_decimal = 1
				}, 30)
			create(cupName, "image", {
				image_path = 'RA/System/biggoldencup.png',
				x = (image_width - 238) / 2,
				y = (image_height - 235) / 2,
				w = 238,
				h = 235,
				show = false,
				opacity_decimal = 1
				}, 20)
			mp.add_timeout(1, function()
				-- move(name, target_x, target_y, target_opacity, duration, on_complete)
				create(backgroundName, "image", {image_path = 'RA/System/background.png', x = 0, y = 0, w = image_width, h = image_height, show = false, opacity_decimal = 1}, 2)
				fade_opacity(backgroundShape,  0.9, 0.4, function()
					mp.add_timeout(0.6, function()
						-- Positionnement de l'image du badge
						set_object_properties(backgroundName, {show = true})
						mp.add_timeout(0.2, function()
							fade_opacity(backgroundShape,  0, 0, function()
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
								--mp.add_timeout(1, function()
									set_object_properties(cupName, {show = true})
									set_object_properties(badgeName, {show = true})
									mp.add_timeout(1, function()
										cache_screen("_cacheNewAchv", true, false, function()
											fade_opacity(textAchievement, 1, 0.6, function()
												mp.add_timeout(1, function()
													fade_opacity(textAchievement, 0, 0.6, function()
														set_object_properties(textAchievement, {size = 80})
														set_object_properties(textAchievement, {text = "(" .. description .. ")"})
														mp.add_timeout(1, function()
															fade_opacity(textAchievement, 1, 0.6, function()
																mp.add_timeout(1, function()
																	fade_opacity(textAchievement, 0, 0.6, function()
																		set_object_properties(textAchievement, {size = 140})
																		set_object_properties(textAchievement, {text = "+" .. points .. "pts"})
																		mp.add_timeout(1, function()
																			fade_opacity(textAchievement, 1, 0.6, function()

																				mp.add_timeout(2, function()
																					fade_opacity(textAchievement, 0, 0.6, function()
																						remove_object(textAchievement)
																						fade_opacity(backgroundShape,  1, 0, function()
																							restore_cache_screen(initscreen)
																							fade_opacity(backgroundShape,  0, 1, function()
																								set_object_properties(backgroundShape, {show = false})
																								set_object_properties(badgeName, {show = false})
																								set_object_properties(cupName, {show = false})
																								set_object_properties(backgroundName, {show = false})
																								show_achievements(function()
																									print("Animation des achievements terminée")
																									mp.add_timeout(3, function()
																										cache_screen("_cacheAchv", true, true, function()
																											print("Image cache des achievements")
																											show_score()
																											remove_object(backgroundShape)
																											remove_object(badgeName)
																											remove_object(cupName)            
																											remove_object(backgroundName)
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
								--end)
							end)
						end)
					end)
				end)
			end)
		-- end)
    end

end

-- #####################################
-- ############# SHOW FUNCTIONS
-- #####################################

function show_achievements(callback)
	update_screen_dimensions(function()
		-- mp.osd_message(" screen_height:" .. screen_height .. " image_height:" .. image_height, 15)
	end)
	
	if next(achievements_data) == nil then
		print("Aucun achievement à afficher.")
		if callback then callback() end
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
	local imageHeight = 64
	local imageSpacing = 4
	local order = 10	
	-- Calcul du nombre maximum d'achievements par ligne
	local maxAchievementsPerLine = math.floor((image_width - xPos) / (imageWidth + imageSpacing))
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
			y = image_height - yPos,
			w = imageWidth,
			h = imageHeight,
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
			if callback then callback() end
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

			local currentY = image_height - yPos - yPosAdjustment
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
    local potentialPoints = 0

    -- Calculer le score total et le score potentiel
    for _, ach in pairs(achievements_data) do
        potentialPoints = potentialPoints + (tonumber(ach.Points) or 0)
        if ach.Unlock == "True" then
            currentPoints = currentPoints + (tonumber(ach.Points) or 0)
        end
    end

    -- Définir la couleur de bordure pour currentPoints
    local currentPointsBorderColor
    if hardcoreMode == "True" then
        currentPointsBorderColor = "FF0000"  -- Bleu si hardcore
    else
        currentPointsBorderColor = "808080"  -- Gris sinon
    end

    -- Construire le texte avec des styles différents pour chaque partie
    local scoreText = string.format("PTS {\\3c&H%s&}%d{\\3c&H000000&}/%d", currentPointsBorderColor, currentPoints, potentialPoints)

    -- Fonction pour mettre à jour le texte du score
    local function show_score_text(scoreText)
        local text_properties = {
            align = 9,
            text = scoreText,
            color = "FFFFFF",  -- Couleur de base du texte (blanc)
            size = 50,
            font = "VT323",
            border_size = 4
        }

        if gfx_objects[scoreTextName] then
            set_object_properties(scoreTextName, text_properties)
        else
            create(scoreTextName, "text", text_properties, 50)
        end
    end
    
    show_score_text(scoreText)
end



-- Register the 'push-ra' message for processing
mp.register_script_message("push-ra", process_data)
