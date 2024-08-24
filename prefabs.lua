local preventFromAddingSelf = true

local cache = {
    sprites = {},
    spritePaths = {},
    spritePathIndices = {},
    options = {},
    optionIndices = {},
}

local prefabColorBound = Color { r = 0, g = 255, b = 0, a = 70 }
local prefabColorEmpty = Color { r = 0, g = 255, b = 0, a = 35 }
local prefabColorMissing = Color { r = 255, g = 0, b = 0, a = 70 }
local pluginKey = "Horun/Prefabs"
local optionEmpty = "[empty]"
local optionMissing = "[missing]"
local prefabWindow
local prefabWindowCache

local OpenPrefabWindow = function() end

local function ArrayRemove(t, shouldRemove)
    local j = 1
    local count = #t;

    for i = 1, count do
        if not shouldRemove(i, t[i]) then
            if i ~= j then
                t[j] = t[i]
                t[i] = nil
            end
            j = j + 1
        else
            t[i] = nil
        end
    end

    return t
end

local function ClearTable(t)
    for k in pairs(t) do
        t[k] = nil
    end
end

local function ShallowCopy(t)
    local t2 = {}
    for k, v in pairs(t) do
        t2[k] = v
    end
    return t2
end

local function ResetPrefabCache()
    ClearTable(cache.sprites)
    ClearTable(cache.spritePaths)
    ClearTable(cache.options)
    ClearTable(cache.spritePathIndices)
    ClearTable(cache.optionIndices)
end

local function GatherPrefabCache()
    for index, sprite in ipairs(app.sprites) do
        if #sprite.frames > 0 and #sprite.layers > 0 then
            local spritePath = sprite.filename
            local optionName = app.fs.fileTitle(sprite.filename)
            table.insert(cache.sprites, sprite)
            table.insert(cache.spritePaths, spritePath)
            table.insert(cache.options, optionName)
            cache.spritePathIndices[spritePath] = index
            cache.optionIndices[optionName] = index
        end
    end
end

local function IsPrefabLayer(layer)
    if layer == nil then
        return false
    end

    if layer.isGroup then
        return false
    end

    local properties = layer.properties(pluginKey)
    if properties.isPrefab == nil then
        return false
    end

    return true
end

local function IsValidPrefabLayer(layer)
    if layer == nil then
        return false
    end

    if layer.isGroup then
        return false
    end

    local properties = layer.properties(pluginKey)
    if properties.isPrefab == nil then
        return false
    end

    if properties.filepath == nil then
        return false
    end

    return true
end

local function IsOpenedPrefabLayer(layer)
    if layer == nil then
        return false
    end

    if layer.isGroup then
        return false
    end

    local properties = layer.properties(pluginKey)
    if properties.isPrefab == nil then
        return false
    end

    if properties.filepath == nil then
        return false
    end

    if cache.spritePathIndices[properties.filepath] == nil then
        return false
    end

    return true
end

local function IsEmptyPrefabLayer(layer)
    if layer == nil then
        return false
    end

    if layer.isGroup then
        return false
    end

    local properties = layer.properties(pluginKey)
    if properties.isPrefab == nil then
        return false
    end

    return properties.filepath == nil
end

local function IsCelIndexValid(layer, frame)
    if frame == nil then
        return false
    end

    if layer == nil then
        return false
    end

    local layerProperties = layer.properties(pluginKey)
    if layerProperties.isPrefab == nil then
        return false
    end

    if layerProperties.filepath == nil then
        return false
    end

    local spriteIndex = cache.spritePathIndices[layerProperties.filepath]
    if spriteIndex == nil then
        return false
    end

    local cel = layer:cel(frame)
    if cel == nil then
        return true
    end

    local sprite = cache.sprites[spriteIndex]
    local celProperties = cel.properties(pluginKey)
    if celProperties.celIndex == nil then
        return false
    end

    return celProperties.celIndex >= 0 and celProperties.celIndex <= #sprite.frames
end

local function GetPrefabFilePath(layer)
    if layer == nil then
        return nil
    end

    local properties = layer.properties(pluginKey)
    if properties.isPrefab == nil then
        return nil
    end

    return properties.filepath
end

local function GetPrefabIndexFromLayer(layer)
    if layer == nil then
        return nil
    end

    local properties = layer.properties(pluginKey)
    if properties.isPrefab == nil then
        return nil
    end

    if properties.filepath == nil then
        return nil
    end

    local spriteIndex = cache.spritePathIndices[properties.filepath]
    if spriteIndex == nil then
        return nil
    end

    return spriteIndex
end

local function GetPrefabCelIndex(layer, frame)
    if frame == nil then
        return nil
    end

    if layer == nil then
        return nil
    end

    local layerProperties = layer.properties(pluginKey)
    if layerProperties.isPrefab == nil then
        return nil
    end

    if layerProperties.filepath == nil then
        return nil
    end

    local spriteIndex = cache.spritePathIndices[layerProperties.filepath]
    if spriteIndex == nil then
        return nil
    end

    local cel = layer:cel(frame)
    if cel == nil then
        return 0
    end

    local celProperties = cel.properties(pluginKey)
    return celProperties.celIndex
end

local function GetPrefabFrameCount(layer)
    if layer == nil then
        return nil
    end

    local layerProperties = layer.properties(pluginKey)
    if layerProperties.isPrefab == nil then
        return nil
    end

    if layerProperties.filepath == nil then
        return nil
    end

    local spriteIndex = cache.spritePathIndices[layerProperties.filepath]
    if spriteIndex == nil then
        return nil
    end

    return #cache.sprites[spriteIndex].frames
end

local function GetImage(sprite, celIndex, colorMode, transparentColor)
    local spec = ImageSpec {
        width = sprite.width,
        height = sprite.height,
        colorMode = colorMode,
        transparentColor = transparentColor,
    }
    local copyImage = Image(spec)
    copyImage:drawSprite(sprite, celIndex)
    local rectangle = copyImage:shrinkBounds()
    return copyImage, rectangle
end

local function TryGetImageFromLayer(layer, celIndex)
    if not IsOpenedPrefabLayer(layer) then
        return nil, "not a valid prefab"
    end

    local layerProperties = layer.properties(pluginKey)
    local spritePathIndex = cache.spritePathIndices[layerProperties.filepath]
    local targetSprite = cache.sprites[spritePathIndex]
    if #targetSprite.frames == 0 then
        return nil, "empty"
    end

    if celIndex < 1 or celIndex > #targetSprite.frames then
        return nil, "out of bounds"
    end

    return GetImage(targetSprite, celIndex, layer.sprite.spec.colorMode, layer.sprite.spec.transparentColor)
end

local function SetCelIndex(layer, frame, celIndex)
    pcall(function ()
        local cel = layer:cel(frame)
        local celProperties = cel and cel.properties(pluginKey) or {}
        celIndex =
            celIndex ~= nil and celIndex or
            celProperties.celIndex ~= nil and celProperties.celIndex or
            0
        if celIndex == 0 then
            if not cel then
                app.transaction("Change prefab cel index", function()
                    cel = layer.sprite:newCel(layer, frame)
                    celProperties = cel.properties(pluginKey)
                    celProperties.celIndex = 0
                    app.refresh()
                end)
            else
                local emptyImage = Image(cel.image.width, cel.image.height)
                if not cel.image:isEqual(emptyImage) then
                    app.transaction("Change prefab cel index", function()
                        cel.image = emptyImage
                        celProperties.celIndex = 0
                        app.refresh()
                    end)
                elseif celProperties.celIndex ~= celIndex then
                    app.transaction("Change prefab cel index", function()
                        celProperties.celIndex = 0
                    end)
                end
            end
        else
            local image, ctx = TryGetImageFromLayer(layer, celIndex)
            if image then
                if not cel then
                    app.transaction("Change prefab cel index", function()
                        cel = layer.sprite:newCel(layer, frame, image, Point())
                        celProperties = cel.properties(pluginKey)
                        celProperties.celIndex = celIndex
                        app.refresh()
                    end)
                elseif not cel.image:isEqual(image) then
                    app.transaction("Change prefab cel index", function()
                        cel.image = image
                        celProperties.celIndex = celIndex
                        app.refresh()
                    end)
                elseif celProperties.celIndex ~= celIndex then
                    app.transaction("Change prefab cel index", function()
                        celProperties.celIndex = celIndex
                    end)
                end
            elseif IsEmptyPrefabLayer(layer) then
                local emptyImage = Image(cel.image.width, cel.image.height)
                if not cel.image:isEqual(emptyImage) then
                    app.transaction("Change prefab cel index", function()
                        cel.image = emptyImage
                        app.refresh()
                    end)
                end
            end
        end
    end)
end

local function GetPrefabOptionsForSprite(sprite, layer)
    local copy = ShallowCopy(cache.options)
    if preventFromAddingSelf then
        copy = ArrayRemove(copy, function(index, value)
            return cache.sprites[cache.optionIndices[value]].filename == sprite.filename
        end)
    end
    table.insert(copy, optionEmpty)
    if IsValidPrefabLayer(layer) and not IsOpenedPrefabLayer(layer) then
        table.insert(copy, optionMissing)
    end
    return copy
end

local function UpdateLayerVisuals(layer)
    if IsOpenedPrefabLayer(layer) then
        local layerProperties = layer.properties(pluginKey)
        local spriteIndex = cache.spritePathIndices[layerProperties.filepath]
        local optionName = cache.options[spriteIndex]
        if layer.name ~= optionName or layer.color ~= prefabColorBound then
            app.transaction("Change prefab layer visuals", function()
                layer.name = optionName
                layer.color = prefabColorBound
            end)
        end
    elseif IsEmptyPrefabLayer(layer) then
        if layer.name ~= optionEmpty or layer.color ~= prefabColorEmpty then
            app.transaction("Change prefab layer visuals", function()
                layer.name = optionEmpty
                layer.color = prefabColorEmpty
            end)
        end
    elseif IsPrefabLayer(layer) then
        if layer.color ~= prefabColorMissing then
            app.transaction("Change prefab layer visuals", function()
                layer.color = prefabColorMissing
            end)
        end
    end
end

local function RefreshLayer(layer, updatedSprite)
    if layer.isGroup then
        for _, innerLayer in ipairs(layer.layers) do
            RefreshLayer(innerLayer, updatedSprite)
        end
    else
        if IsPrefabLayer(layer) then
            if updatedSprite ~= nil then
                local layerProperties = layer.properties(pluginKey)
                if cache.sprites[cache.spritePathIndices[layerProperties.filepath]] ~= updatedSprite then
                    return
                end
            end
            for _, frame in ipairs(layer.sprite.frames) do
                SetCelIndex(layer, frame)
            end
        end
    end
end

local function TryOpenPrefab(layer)
    if not IsPrefabLayer(layer) then
        return nil
    end

    local properties = layer.properties(pluginKey)
    if properties.filepath == nil then
        return nil
    end

    if IsOpenedPrefabLayer(layer) then
        local openedSpriteIndex = cache.spritePathIndices[properties.filepath]
        return cache.sprites[openedSpriteIndex]
    else
        local openedSprite
        local status, err = pcall(function()
            local previousSprite = app.sprite
            openedSprite = app.open(properties.filepath)
            if openedSprite then
                app.sprite = previousSprite
                ResetPrefabCache()
                GatherPrefabCache()
            end
        end)
        if not status then
            app.alert("Couldn't open file \"" .. properties.filepath .. '"')
            return nil
        end
        return openedSprite
    end
end

local function OpenAllPrefabs()
    if not app.sprite then
        return
    end

    if prefabWindow ~= nil then
        OpenPrefabWindow()
    end

    if prefabWindowCache.isOpeningInProgress then
        return
    else
        prefabWindowCache.isOpeningInProgress = true
    end

    local lastSprite = app.sprite
    for index, layer in ipairs(app.sprite.layers) do
        TryOpenPrefab(layer)
    end

    app.sprite = lastSprite
    prefabWindowCache.isOpeningInProgress = nil
end

local function UpdatePrefabCombobox(layer)
    local option =
        IsOpenedPrefabLayer(layer) and cache.options[GetPrefabIndexFromLayer(layer)] or
        IsValidPrefabLayer(layer) and optionMissing or
        optionEmpty;
    local options = GetPrefabOptionsForSprite(app.site.sprite, layer)

    prefabWindowCache.skipComboboxUpdate = true
    prefabWindow:modify {
        id = "prefabPath",
        options = options,
    }
    prefabWindowCache.skipComboboxUpdate = false
    prefabWindow:modify {
        id = "prefabPath",
        option = option,
    }
end

local function UpdateCelSlider(layer, cel)
    local celProperties = cel and cel.properties(pluginKey) or {}
    local prefabIndex = GetPrefabIndexFromLayer(layer)
    local prefabSprite = prefabIndex and cache.sprites[prefabIndex] or nil

    local celIndexMax = prefabSprite and #prefabSprite.frames or 0
    local celIndexValue = celProperties.celIndex or 0
    if prefabWindowCache.celIndexMax ~= celIndexMax or prefabWindowCache.celIndexValue ~= celIndexValue then
        prefabWindowCache.celIndexMax = celIndexMax
        prefabWindowCache.celIndexValue = celIndexValue

        prefabWindow:modify {
            id = "prefabCel",
            min = 0,
            max = celIndexMax,
            value = celIndexValue,
        }
    end
end

local function UpdateDialogElements(layer, frame)
    if IsPrefabLayer(layer) then
        prefabWindow:modify {
            id = "notSelectedLabel1",
            visible = false,
        }
        prefabWindow:modify {
            id = "notSelectedLabel2",
            visible = false,
        }
        prefabWindow:modify {
            id = "prefabPath",
            visible = true,
        }
        prefabWindow:modify {
            id = "missingButton",
            visible = not IsOpenedPrefabLayer(layer) and IsValidPrefabLayer(layer),
            text = app.fs.fileTitle(GetPrefabFilePath(layer)),
        }
        prefabWindow:modify {
            id = "invalidCelLabel",
            visible = IsOpenedPrefabLayer(layer) and not IsCelIndexValid(layer, frame),
            text = "" .. (GetPrefabCelIndex(layer, frame) or 0) .. " > " .. (GetPrefabFrameCount(layer) or 0),
        }
        prefabWindow:modify {
            id = "prefabCel",
            enabled = IsOpenedPrefabLayer(layer) or not IsValidPrefabLayer(layer),
            visible = true,
        }
        prefabWindow:modify {
            id = "layerIsEmpty1",
            visible = IsEmptyPrefabLayer(layer),
        }
        prefabWindow:modify {
            id = "layerIsEmpty2",
            visible = IsEmptyPrefabLayer(layer),
        }
    else
        prefabWindow:modify {
            id = "notSelectedLabel1",
            visible = true,
        }
        prefabWindow:modify {
            id = "notSelectedLabel2",
            visible = true,
        }
        prefabWindow:modify {
            id = "prefabPath",
            visible = false,
        }
        prefabWindow:modify {
            id = "missingButton",
            visible = false,
        }
        prefabWindow:modify {
            id = "invalidCelLabel",
            visible = false,
        }
        prefabWindow:modify {
            id = "prefabCel",
            visible = false,
        }
        prefabWindow:modify {
            id = "layerIsEmpty1",
            visible = false,
        }
        prefabWindow:modify {
            id = "layerIsEmpty2",
            visible = false,
        }
    end
end

local function OnSpriteChangeUndoRedo(ev)
    if cache.isSpriteChangeInProgress then
        return
    end
    cache.isSpriteChangeInProgress = true
    -- it seems that changing cel.properties while switched to another sprite throws an error
    -- the pcall ensures that the opertation exits gracefully
    if ev.fromUndo then
        UpdateDialogElements(app.layer, app.frame)
        UpdatePrefabCombobox(app.layer)
        UpdateCelSlider(app.layer, app.cel)
    end
    for _, sprite in ipairs(app.sprites) do
        if sprite ~= app.sprite then
            for _, layer in ipairs(sprite.layers) do
                RefreshLayer(layer, app.sprite)
            end
        end
    end
    cache.isSpriteChangeInProgress = false
end

local function OnSiteChange(ev)
    if prefabWindowCache.sprite ~= app.site.sprite then
        ResetPrefabCache()
        GatherPrefabCache()
        OpenAllPrefabs()

        if prefabWindowCache.sprite then
            prefabWindowCache.sprite.events:off(OnSpriteChangeUndoRedo)
        end
        if app.site.sprite then
            app.site.sprite.events:on('change', OnSpriteChangeUndoRedo)
            for _, layer in ipairs(app.site.sprite.layers) do
                RefreshLayer(layer)
            end
        end
    end

    if prefabWindowCache.sprite ~= app.site.sprite or
        prefabWindowCache.cel ~= app.site.cel or
        prefabWindowCache.layer ~= app.site.layer or
        prefabWindowCache.frame ~= app.site.frame then
        UpdateDialogElements(app.site.layer, app.site.frame)
        if app.site.sprite then
            UpdatePrefabCombobox(app.site.layer)
            UpdateCelSlider(app.site.layer, app.site.cel)
            UpdateLayerVisuals(app.site.layer)
        end
    end

    prefabWindowCache.cel = app.site.cel
    prefabWindowCache.layer = app.site.layer
    prefabWindowCache.frame = app.site.frame
    prefabWindowCache.sprite = app.site.sprite
end

local function NewPrefab()
    if prefabWindow == nil then
        OpenPrefabWindow()
    end
    app.transaction("New prefab layer", function()
        app.command.NewLayer {
            top = false,
        }
        local layer = app.layer
        local layerProperties = layer.properties(pluginKey)
        layerProperties.isPrefab = true
        UpdateLayerVisuals(layer)
        UpdateDialogElements(app.site.layer, app.site.frame)
        UpdatePrefabCombobox(app.site.layer)
        UpdateCelSlider(app.site.layer, app.site.cel)
        UpdateLayerVisuals(app.site.layer)
    end)
end

OpenPrefabWindow = function()
    if prefabWindow ~= nil then
        return
    end

    cache.plugin.preferences.opened = true
    prefabWindowCache = {}

    app.events:on('sitechange', OnSiteChange)
    prefabWindow = Dialog {
        title = "Prefab Window",
        onclose = function()
            cache.plugin.preferences.opened = false
            prefabWindow = nil
            app.events:off(OnSiteChange)
            ResetPrefabCache()
        end,
    }
    prefabWindow:label {
        id = "notSelectedLabel1",
        text = "Select an existing prefab layer, or create",
    }
    prefabWindow:newrow()
    prefabWindow:label {
        id = "notSelectedLabel2",
        text = "a new one (Layer > New... > New Prefab Layer).",
    }
    prefabWindow:combobox {
        id = "prefabPath",
        visible = false,
        label = "Prefab",
        options = { optionEmpty, optionMissing },
        onchange = function()
            if prefabWindowCache.skipComboboxUpdate then
                -- this is required since changing the options and option at the same
                -- time triggers the even twice, once with a default value
                return
            end
            if prefabWindow.data.prefabPath == optionMissing then
                return
            end
            local layerProperties = app.layer.properties(pluginKey)
            local changedOptionIndex = cache.optionIndices[prefabWindow.data.prefabPath]
            local newSpritePath = cache.spritePaths[changedOptionIndex]
            if layerProperties.filepath ~= newSpritePath then
                app.transaction("Change prefab", function()
                    layerProperties.filepath = newSpritePath
                    SetCelIndex(app.layer, app.frame)
                    UpdateCelSlider(app.layer, app.cel)
                    UpdateLayerVisuals(app.layer)
                    UpdatePrefabCombobox(app.layer)
                    UpdateDialogElements(app.layer, app.frame)
                end)
            end
        end
    }
    prefabWindow:slider {
        id = "prefabCel",
        label = "Frame",
        onchange = function()
            if prefabWindow.data.prefabPath == optionMissing then
                return
            end
            SetCelIndex(app.layer, app.frame, prefabWindow.data.prefabCel)
            UpdateDialogElements(app.layer, app.frame)
        end
    }
    prefabWindow:button {
        id = "missingButton",
        visible = false,
        label = "Open missing",
        onclick = function()
            local previousSprite = app.sprite
            local openedSprite = TryOpenPrefab(app.layer)
            if openedSprite then
                app.sprite = previousSprite
                UpdateLayerVisuals(app.layer)
                UpdateDialogElements(app.layer, app.frame)
            end
        end
    }
    prefabWindow:button {
        id = "invalidCelLabel",
        visible = false,
        label = "Fix cel",
        onclick = function()
            if IsPrefabLayer(app.layer) then
                local spriteFrameCount = GetPrefabFrameCount(app.layer)
                local frameIndex = GetPrefabCelIndex(app.layer, app.frame)
                if frameIndex > spriteFrameCount then
                    app.transaction("Fix prefab cel index", function()
                        SetCelIndex(app.layer, app.frame, spriteFrameCount)
                        UpdateCelSlider(app.layer, app.cel)
                        UpdateLayerVisuals(app.layer)
                        UpdatePrefabCombobox(app.layer)
                        UpdateDialogElements(app.layer, app.frame)
                    end)
                end
            end
        end
    }
    prefabWindow:label {
        id = "layerIsEmpty1",
        text = "Open a project or image in a separate tab",
    }
    prefabWindow:newrow()
    prefabWindow:label {
        id = "layerIsEmpty2",
        text = "and select it in the dropdown above.",
    }

    prefabWindow:show {
        wait = false,
    }

    UpdateDialogElements(nil, nil)
    OnSiteChange({})
end

function init(plugin)
    cache.plugin = plugin

    plugin:newMenuGroup {
        id = "prefabs_group",
        title = "Prefabs",
        group = "view_controls"
    }
    plugin:newCommand {
        id = "PrefabWindow",
        title = "Prefab Window",
        group = "prefabs_group",
        onclick = OpenPrefabWindow,
    }
    plugin:newMenuSeparator {
        group = "prefabs_group"
    }
    plugin:newCommand {
        id = "NewPrefab",
        title = "New Prefab Layer",
        group = "prefabs_group",
        onclick = NewPrefab,
        onenabled = function()
            return app.sprite ~= nil
        end
    }
    plugin:newMenuSeparator {
        group = "prefabs_group"
    }
    plugin:newCommand {
        id = "OpenAllPrefabs",
        title = "Open All Prefabs",
        group = "prefabs_group",
        onclick = OpenAllPrefabs,
        onenabled = function()
            return app.sprite ~= nil
        end,
    }

    plugin:newCommand {
        id = "NewPrefab",
        title = "New Prefab Layer",
        group = "layer_popup_new",
        onclick = NewPrefab,
        onenabled = function()
            return app.sprite ~= nil
        end
    }
    plugin:newCommand {
        id = "NewPrefab",
        title = "New Prefab Layer",
        group = "layer_new",
        onclick = NewPrefab,
        onenabled = function()
            return app.sprite ~= nil
        end
    }

    if plugin.preferences.opened then
        OpenPrefabWindow()
    end
end

function exit(plugin)
    ResetPrefabCache()
end
