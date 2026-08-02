
local TMGCore = exports['tmg-core']:GetCoreObject()
local UseTarget = Config.UseTarget 


local ApartState = {
    inApartment = false,
    closestHouse = nil,
    currentApartment = nil,
    isOwned = false,
    currentDoorbell = 0,
    currentOffset = 0,
    houseObj = {},
    poiOffsets = nil,
    rangDoorbell = nil,
    blips = {},
    
    isInsideEntrance = false,
    isInsideExit = false,
    isInsideStash = false,
    isInsideOutfits = false,
    isInsideLogout = false,
    
    
    targetsCreated = false,
    apartmentTargets = {}
}



local function RefreshApartmentBlips(homeType)
    
    for id, data in pairs(Apartments.Locations) do
        if not ApartState.blips[id] then
            local blip = AddBlipForCoord(data.coords.enter.x, data.coords.enter.y, data.coords.enter.z)
            ApartState.blips[id] = blip
            SetBlipDisplay(blip, 4)
            SetBlipScale(blip, 0.65)
            SetBlipAsShortRange(blip, true)
            SetBlipColour(blip, 3)
            AddTextEntry(data.label, data.label)
            BeginTextCommandSetBlipName(data.label)
            EndTextCommandSetBlipName(blip)
        end

        local currentBlip = ApartState.blips[id]
        if id == homeType then
            SetBlipSprite(currentBlip, 475)
            SetBlipCategory(currentBlip, 11)
        else
            SetBlipSprite(currentBlip, 476)
            SetBlipCategory(currentBlip, 10)
        end
    end
end



local function OpenEntranceMenu()
    local headerMenu = {}
    if ApartState.isOwned then
        headerMenu[#headerMenu + 1] = { header = Lang:t('text.enter'), params = { event = 'apartments:client:EnterApartment' } }
    else
        headerMenu[#headerMenu + 1] = { header = Lang:t('text.move_here'), params = { event = 'apartments:client:UpdateApartment' } }
    end
    headerMenu[#headerMenu + 1] = { header = Lang:t('text.ring_doorbell'), params = { event = 'apartments:client:DoorbellMenu' } }
    headerMenu[#headerMenu + 1] = { header = Lang:t('text.close_menu'), params = { event = 'tmg-menu:client:closeMenu' } }
    exports['tmg-menu']:openMenu(headerMenu)
end

local function OpenExitMenu()
    local headerMenu = {
        { header = Lang:t('text.open_door'), params = { event = 'apartments:client:OpenDoor' } },
        { header = Lang:t('text.leave'), params = { event = 'apartments:client:LeaveApartment' } },
        { header = Lang:t('text.close_menu'), params = { event = 'tmg-menu:client:closeMenu' } }
    }
    exports['tmg-menu']:openMenu(headerMenu)
end



local function RegisterApartmentEntranceZone(apartmentID, apartmentData)
    local coords = apartmentData.coords['enter']
    local boxData = apartmentData.polyzoneBoxData
    if boxData.created then return end

    local zone = BoxZone:Create(coords, boxData.length, boxData.width, {
        name = 'apartmentEntrance_' .. apartmentID,
        heading = boxData.heading or 340.0, 
        minZ = coords.z - 1.0, maxZ = coords.z + 5.0, debugPoly = false
    })

    zone:onPlayerInOut(function(isInside)
        if isInside and not ApartState.inApartment then exports['tmg-core']:DrawText(Lang:t('text.options'), 'left')
        else exports['tmg-core']:HideText() end
        ApartState.isInsideEntrance = isInside
    end)
    boxData.created, boxData.zone = true, zone
end

local function RegisterApartmentEntranceTarget(apartmentID, apartmentData)
    local coords, boxData = apartmentData.coords['enter'], apartmentData.polyzoneBoxData
    if boxData.created then return end

    local options = {}
    if apartmentID == ApartState.closestHouse and ApartState.isOwned then
        options[1] = { type = 'client', event = 'apartments:client:EnterApartment', icon = 'fas fa-door-open', label = Lang:t('text.enter') }
    else
        options[1] = { type = 'client', event = 'apartments:client:UpdateApartment', icon = 'fas fa-hotel', label = Lang:t('text.move_here') }
    end
    options[#options + 1] = { type = 'client', event = 'apartments:client:DoorbellMenu', icon = 'fas fa-concierge-bell', label = Lang:t('text.ring_doorbell') }

    exports['tmg-target']:AddBoxZone('apartmentEntrance_' .. apartmentID, coords, boxData.length, boxData.width, {
        name = 'apartmentEntrance_' .. apartmentID, heading = boxData.heading, debugPoly = boxData.debug, minZ = boxData.minZ, maxZ = boxData.maxZ,
    }, { options = options, distance = boxData.distance })
    boxData.created = true
end



local function RegisterInApartmentZone(targetKey, coords, heading, text)
    if not ApartState.inApartment then return end 
    
    if ApartState.apartmentTargets[targetKey] and ApartState.apartmentTargets[targetKey].created then
        return
    end

    local zone = BoxZone:Create(coords, 1.5, 1.5, {
        name = 'inApartmentTarget_' .. targetKey,
        heading = heading,
        minZ = coords.z - 1.0,
        maxZ = coords.z + 5.0,
        debugPoly = false
    })

    zone:onPlayerInOut(function(isInside)
        if isInside and text then exports['tmg-core']:DrawText(text, 'left')
        else exports['tmg-core']:HideText() end

        
        if targetKey == 'entrancePos' then ApartState.isInsideExit = isInside
        elseif targetKey == 'stashPos' then ApartState.isInsideStash = isInside
        elseif targetKey == 'outfitsPos' then ApartState.isInsideOutfits = isInside
        elseif targetKey == 'logoutPos' then ApartState.isInsideLogout = isInside end
    end)

    ApartState.apartmentTargets[targetKey] = { created = true, zone = zone }
end


local function RegisterInApartmentTarget(targetKey, coords, heading, options)
    if not ApartState.inApartment then return end 

    if ApartState.apartmentTargets[targetKey] and ApartState.apartmentTargets[targetKey].created then
        return
    end

    exports['tmg-target']:AddBoxZone('inApartmentTarget_' .. targetKey, coords, 1.5, 1.5, {
        name = 'inApartmentTarget_' .. targetKey,
        heading = heading,
        minZ = coords.z - 1.0,
        maxZ = coords.z + 5.0,
        debugPoly = false,
    }, {
        options = options,
        distance = 1.0 
    })

    ApartState.apartmentTargets[targetKey] = { created = true }
end





local function SetApartmentsEntranceTargets()
    if not Apartments.Locations or not next(Apartments.Locations) then return end

    for id, apartment in pairs(Apartments.Locations) do
        if apartment.coords and apartment.coords['enter'] then
            
            if UseTarget then
                RegisterApartmentEntranceTarget(id, apartment)
            else
                RegisterApartmentEntranceZone(id, apartment)
            end
        end
    end
end


local function SetInApartmentTargets()
    
    if not ApartState.poiOffsets or not ApartState.closestHouse then return end

    local baseCoords = Apartments.Locations[ApartState.closestHouse].coords.enter
    local zPos = baseCoords.z - ApartState.currentOffset
    local offsets = ApartState.poiOffsets

    
    local entrancePos = vector3(baseCoords.x + offsets.exit.x, baseCoords.y + offsets.exit.y, zPos + offsets.exit.z)
    local stashPos    = vector3(baseCoords.x - offsets.stash.x, baseCoords.y - offsets.stash.y, zPos + offsets.stash.z)
    local outfitsPos  = vector3(baseCoords.x - offsets.clothes.x, baseCoords.y - offsets.clothes.y, zPos + offsets.clothes.z)
    local logoutPos   = vector3(baseCoords.x - offsets.logout.x, baseCoords.y + offsets.logout.y, zPos + offsets.logout.z)

    if UseTarget then
        
        RegisterInApartmentTarget('entrancePos', entrancePos, 0, {
            { type = 'client', event = 'apartments:client:OpenDoor', icon = 'fas fa-door-open', label = Lang:t('text.open_door') },
            { type = 'client', event = 'apartments:client:LeaveApartment', icon = 'fas fa-sign-out-alt', label = Lang:t('text.leave') },
        })
        RegisterInApartmentTarget('stashPos', stashPos, 0, {
            { type = 'client', event = 'apartments:client:OpenStash', icon = 'fas fa-box-open', label = Lang:t('text.open_stash') },
        })
        RegisterInApartmentTarget('outfitsPos', outfitsPos, 0, {
            { type = 'client', event = 'apartments:client:ChangeOutfit', icon = 'fas fa-tshirt', label = Lang:t('text.change_outfit') },
        })
        RegisterInApartmentTarget('logoutPos', logoutPos, 0, {
            { type = 'client', event = 'apartments:client:Logout', icon = 'fas fa-power-off', label = Lang:t('text.logout') },
        })
    else
        
        RegisterInApartmentZone('stashPos', stashPos, 0, '[E] ' .. Lang:t('text.open_stash'))
        RegisterInApartmentZone('outfitsPos', outfitsPos, 0, '[E] ' .. Lang:t('text.change_outfit'))
        RegisterInApartmentZone('logoutPos', logoutPos, 0, '[E] ' .. Lang:t('text.logout'))
        RegisterInApartmentZone('entrancePos', entrancePos, 0, Lang:t('text.options'))
    end
end


local function DeleteApartmentsEntranceTargets()
    for id, apartment in pairs(Apartments.Locations) do
        local boxName = 'apartmentEntrance_' .. id
        
        if UseTarget then
            exports['tmg-target']:RemoveZone(boxName)
        elseif apartment.polyzoneBoxData and apartment.polyzoneBoxData.zone then
            apartment.polyzoneBoxData.zone:destroy()
            apartment.polyzoneBoxData.zone = nil
        end
        
        
        if apartment.polyzoneBoxData then
            apartment.polyzoneBoxData.created = false
        end
    end
end


local function DeleteInApartmentTargets()
    
    ApartState.isInsideExit = false
    ApartState.isInsideStash = false
    ApartState.isInsideOutfits = false
    ApartState.isInsideLogout = false

    
    if ApartState.apartmentTargets and next(ApartState.apartmentTargets) then
        for id, targetData in pairs(ApartState.apartmentTargets) do
            if UseTarget then
                exports['tmg-target']:RemoveZone('inApartmentTarget_' .. id)
            elseif targetData.zone then
                targetData.zone:destroy()
            end
        end
    end
    
    
    ApartState.apartmentTargets = {}
end


local function DeleteInApartmentTargets()
    ApartState.isInsideExit = false
    ApartState.isInsideStash = false
    ApartState.isInsideOutfits = false
    ApartState.isInsideLogout = false

    if ApartState.apartmentTargets and next(ApartState.apartmentTargets) then
        for id, targetData in pairs(ApartState.apartmentTargets) do
            if UseTarget then
                exports['tmg-target']:RemoveZone('inApartmentTarget_' .. id)
            elseif targetData.zone then
                targetData.zone:destroy()
                targetData.zone = nil
            end
        end
    end

    ApartState.apartmentTargets = {}
end



local function loadAnimDict(dict)
    if HasAnimDictLoaded(dict) then return true end
    
    RequestAnimDict(dict)
    local timeout = 0
    
    while not HasAnimDictLoaded(dict) do
        Wait(10)
        timeout = timeout + 1
        if timeout > 100 then 
            print(string.format("^1[TMG Error]^7 Failed to load animation: %s", dict))
            return false 
        end
    end
    return true
end

local function openHouseAnim()
    local ped = PlayerPedId()
    local animDict = 'anim@heists@keycard@'
    
    if loadAnimDict(animDict) then
        TaskPlayAnim(ped, animDict, 'exit', 5.0, 1.0, -1, 16, 0, false, false, false)
        Wait(400)
        ClearPedTasks(ped)
    end
end



local function EnterApartment(house, apartmentId, isNew, isVisiting)
    TriggerServerEvent('InteractSound_SV:PlayOnSource', 'houses_door_open', 0.1)
    openHouseAnim()
    
    TMGCore.Functions.TriggerCallback('apartments:GetApartmentOffset', function(offset)
        local function ProceedWithEntry(targetOffset)
            if targetOffset > 230 then targetOffset = 210 end
            
            ApartState.currentOffset = targetOffset
            ApartState.closestHouse = house
            ApartState.currentApartment = apartmentId
            ApartState.rangDoorbell = nil
            
            TriggerServerEvent('apartments:server:AddObject', apartmentId, house, ApartState.currentOffset)
            
            local enterCoords = Apartments.Locations[house].coords.enter
            local interiorPos = { 
                x = enterCoords.x, 
                y = enterCoords.y, 
                z = enterCoords.z - ApartState.currentOffset 
            }
            
            local data = exports['tmg-interior']:CreateApartmentFurnished(interiorPos)
            ApartState.houseObj = data[1]
            ApartState.poiOffsets = data[2]
            ApartState.inApartment = true
            
            Wait(500)
            TriggerEvent('tmg-weathersync:client:DisableSync')
            
            
            TriggerServerEvent('tmg-apartments:server:SetInsideMeta', house, apartmentId, true, isVisiting or false)
            TriggerServerEvent('InteractSound_SV:PlayOnSource', 'houses_door_close', 0.1)
            TriggerServerEvent('apartments:server:setCurrentApartment', apartmentId)
            
            local newState = (isNew ~= nil) and isNew or false
            TriggerEvent('tmg-interior:client:SetNewState', newState)
        end

        if offset == nil or offset == 0 then
            TMGCore.Functions.TriggerCallback('apartments:GetApartmentOffsetNewOffset', function(newoffset)
                ProceedWithEntry(newoffset)
            end, house)
        else
            ProceedWithEntry(offset)
        end
    end, apartmentId)
end

local function LeaveApartment(house)
    if not house or not ApartState.inApartment then return end
    
    TriggerServerEvent('InteractSound_SV:PlayOnSource', 'houses_door_open', 0.1)
    openHouseAnim() 
    
    TriggerServerEvent('tmg-apartments:returnBucket')
    
    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do Wait(10) end
    
    exports['tmg-interior']:DespawnInterior(ApartState.houseObj, function()
        TriggerEvent('tmg-weathersync:client:EnableSync')
        
        local entrance = Apartments.Locations[house].coords.enter
        local ped = PlayerPedId()
        SetEntityCoords(ped, entrance.x, entrance.y, entrance.z)
        SetEntityHeading(ped, entrance.w)
        
        DeleteInApartmentTargets()
        DeleteApartmentsEntranceTargets()
        
        Wait(500) 
        
        TriggerServerEvent('apartments:server:RemoveObject', ApartState.currentApartment, house)
        TriggerServerEvent('tmg-apartments:server:SetInsideMeta', ApartState.currentApartment, false)
        TriggerServerEvent('apartments:server:setCurrentApartment', nil)
        
        ApartState.currentApartment = nil
        ApartState.inApartment = false
        ApartState.currentOffset = 0
        ApartState.houseObj = nil
        
        DoScreenFadeIn(1000)
        TriggerServerEvent('InteractSound_SV:PlayOnSource', 'houses_door_close', 0.1)
    end)
end

local function SetClosestApartment()
    if ApartState.inApartment or not LocalPlayer.state.isLoggedIn then return end

    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local current = nil
    local dist = 100.0 

    for id, data in pairs(Apartments.Locations) do
        local entrance = data.coords.enter
        local distcheck = #(pos - vector3(entrance.x, entrance.y, entrance.z))
        
        if distcheck < dist then
            dist = distcheck
            current = id
        end
    end

    if current ~= ApartState.closestHouse then
        ApartState.closestHouse = current
        
        if not current then
            DeleteApartmentsEntranceTargets()
            return
        end

        TMGCore.Functions.TriggerCallback('apartments:IsOwner', function(result)
            ApartState.isOwned = result
            
            DeleteApartmentsEntranceTargets()
            DeleteInApartmentTargets()
            
            if not UseTarget then SetApartmentsEntranceTargets() end
        end, ApartState.closestHouse)
    end
end

function MenuOwners()
    if not ApartState.closestHouse then 
        return TMGCore.Functions.Notify(Lang:t('error.nobody_home'), 'error') 
    end

    TMGCore.Functions.TriggerCallback('apartments:GetAvailableApartments', function(apartments)
        
        if not apartments or next(apartments) == nil then
            TMGCore.Functions.Notify(Lang:t('error.nobody_home'), 'error', 3500)
            if CloseMenuFull then CloseMenuFull() end
            return
        end

        local apartmentMenu = {
            {
                header = Lang:t('text.tennants'),
                isMenuHeader = true
            }
        }

        for k, v in pairs(apartments) do
            apartmentMenu[#apartmentMenu + 1] = {
                header = v, 
                txt = "",
                params = {
                    event = 'apartments:client:RingMenu',
                    args = {
                        apartmentId = k
                    }
                }
            }
        end

        apartmentMenu[#apartmentMenu + 1] = {
            header = Lang:t('text.close_menu'),
            txt = "",
            params = {
                event = 'tmg-menu:client:closeMenu'
            }
        }

        exports['tmg-menu']:openMenu(apartmentMenu)

    end, ApartState.closestHouse)
end

function CloseMenuFull()
    exports['tmg-menu']:closeMenu()
end




AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    if ApartState.houseObj ~= nil then
        DoScreenFadeOut(500)
        while not IsScreenFadedOut() do Wait(10) end

        exports['tmg-interior']:DespawnInterior(ApartState.houseObj, function()
            TriggerEvent('tmg-weathersync:client:EnableSync')

            if ApartState.closestHouse and Apartments.Locations[ApartState.closestHouse] then
                local entrance = Apartments.Locations[ApartState.closestHouse].coords.enter
                local ped = PlayerPedId()
                
                SetEntityCoords(ped, entrance.x, entrance.y, entrance.z)
                SetEntityHeading(ped, entrance.w)
            end

            ApartState.currentApartment = nil
            ApartState.inApartment = false
            ApartState.houseObj = nil
            ApartState.currentOffset = 0

            DoScreenFadeIn(1000)
        end)
    end

    DeleteApartmentsEntranceTargets()
    DeleteInApartmentTargets()
    
    print("^5[TMG]^7 Mainframe: Residential services terminated and spatial nodes purged.")
end)






RegisterNetEvent('TMGCore:Client:OnPlayerUnload', function()
    ApartState.currentApartment = nil
    ApartState.inApartment = false
    ApartState.currentOffset = 0
    ApartState.houseObj = nil
    ApartState.closestHouse = nil
    ApartState.isOwned = false

    DeleteApartmentsEntranceTargets()
    DeleteInApartmentTargets()
    
    print("^5[TMG]^7 Mainframe: Session terminated. Residential matrix purged.")
end)

RegisterNetEvent('apartments:client:setupSpawnUI', function(cData)
    TMGCore.Functions.TriggerCallback('apartments:GetOwnedApartment', function(result)
        if result then
            TriggerEvent('tmg-spawn:client:setupSpawns', cData, false, nil)
            TriggerEvent('tmg-spawn:client:openUI', true)
            
            TriggerEvent('apartments:client:SetHomeBlip', result.type)
        else
            if Apartments.Starting then
                TriggerEvent('tmg-spawn:client:setupSpawns', cData, true, Apartments.Locations)
                TriggerEvent('tmg-spawn:client:openUI', true)
            else
                TriggerEvent('tmg-spawn:client:setupSpawns', cData, false, nil)
                TriggerEvent('tmg-spawn:client:openUI', true)
                TriggerEvent('apartments:client:SetHomeBlip', nil)
            end
        end
    end, cData.citizenid)
end)


RegisterNetEvent('apartments:client:SpawnInApartment', function(apartmentId, apartment)
    if ApartState.rangDoorbell ~= nil then
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        local doorCoords = Apartments.Locations[ApartState.rangDoorbell].coords.enter
        
        local doorbelldist = #(pos - vector3(doorCoords.x, doorCoords.y, doorCoords.z))
        
        if doorbelldist > 10.0 then
            return TMGCore.Functions.Notify(Lang:t('error.to_far_from_door'), 'error')
        end
    end

    ApartState.closestHouse = apartment
    ApartState.isOwned = true

    EnterApartment(apartment, apartmentId, true, false)
    
    print(string.format("^5[TMG]^7 Character materialized in apartment: %s (%s)", apartment, apartmentId))
end)

RegisterNetEvent('tmg-apartments:client:LastLocationHouse', function(apartmentType, apartmentId)
    ApartState.closestHouse = apartmentType
    EnterApartment(apartmentType, apartmentId, false, false)
    print(string.format("^5[TMG]^7 Mainframe: Last known location restored. Character phased into apartment: %s", apartmentType))
end)


RegisterNetEvent('apartments:client:SetHomeBlip', function(home)
    if SetClosestApartment then SetClosestApartment() end
    RefreshApartmentBlips(home)
    print(string.format("^5[TMG]^7 Minimap synchronized. Home designated: %s", home or "None"))
end)

RegisterNetEvent('apartments:client:RingMenu', function(data)
    if not ApartState.closestHouse then return end
    ApartState.rangDoorbell = ApartState.closestHouse
    TriggerServerEvent('InteractSound_SV:PlayOnSource', 'doorbell', 0.1)
    TriggerServerEvent('apartments:server:RingDoor', data.apartmentId, ApartState.closestHouse)
    print(string.format("^5[TMG]^7 Intercom signal dispatched for Apartment: %s", data.apartmentId))
end)

RegisterNetEvent('apartments:client:RingDoor', function(player, _)
    ApartState.currentDoorbell = player
    TriggerServerEvent('InteractSound_SV:PlayOnSource', 'doorbell', 0.1)
    TMGCore.Functions.Notify(Lang:t('info.at_the_door'), 'primary')
    print(string.format("^5[TMG]^7 Intercom signal received from Player Source: %s", player))
end)

RegisterNetEvent('apartments:client:DoorbellMenu', function()
    if not ApartState.closestHouse then 
        return TMGCore.Functions.Notify(Lang:t('error.to_far_from_door'), 'error') 
    end
    MenuOwners()
    print(string.format("^5[TMG]^7 Intercom interface initialized for location: %s", ApartState.closestHouse))
end)

RegisterNetEvent('apartments:client:EnterApartment', function()
    if not ApartState.closestHouse then 
        return TMGCore.Functions.Notify(Lang:t('error.to_far_from_door'), 'error') 
    end
    TMGCore.Functions.TriggerCallback('apartments:GetOwnedApartment', function(result)
        if result ~= nil then
            -- Pass isVisiting = false (4th argument)
            EnterApartment(ApartState.closestHouse, result.name, false, false)
            print(string.format("^5[TMG]^7 Access granted. Character entering property: %s", result.name))
        else
            TMGCore.Functions.Notify(Lang:t('error.nobody_home'), 'error')
        end
    end)
end)

RegisterNetEvent('apartments:client:UpdateApartment', function()
    local targetHouse = ApartState.closestHouse
    if not targetHouse or not Apartments.Locations[targetHouse] then 
        return TMGCore.Functions.Notify(Lang:t('error.to_far_from_door'), 'error') 
    end

    local targetLabel = Apartments.Locations[targetHouse].label

    TMGCore.Functions.TriggerCallback('apartments:GetOwnedApartment', function(result)
        if result == nil then
            TriggerServerEvent("apartments:server:CreateApartment", targetHouse, targetLabel, false)
        else
            TriggerServerEvent('apartments:server:UpdateApartment', targetHouse, targetLabel)
        end

        ApartState.isOwned = true

        DeleteApartmentsEntranceTargets()
        DeleteInApartmentTargets()
        
        if not Config.UseTarget then
            SetApartmentsEntranceTargets()
        end
        
        print(string.format("^5[TMG]^7 Migration sequence finalized for property: %s", targetLabel))
    end)
end)

RegisterNetEvent('apartments:client:OpenDoor', function()
    if ApartState.currentDoorbell == 0 then
        return TMGCore.Functions.Notify(Lang:t('error.nobody_at_door'), 'error')
    end
    TriggerServerEvent(
        'apartments:server:OpenDoor', 
        ApartState.currentDoorbell, 
        ApartState.currentApartment, 
        ApartState.closestHouse
    )
    ApartState.currentDoorbell = 0
    print("^5[TMG]^7 Access grant signal dispatched. Intercom cleared.")
end)

RegisterNetEvent('apartments:client:LeaveApartment', function()
    local targetHouse = ApartState.closestHouse
    if not targetHouse then
        return TMGCore.Functions.Notify(Lang:t('error.to_far_from_door'), 'error')
    end
    LeaveApartment(targetHouse)
    print(string.format("^5[TMG]^7 Egress protocol initiated for location: %s", targetHouse))
end)

RegisterNetEvent('apartments:client:OpenStash', function()
    if not ApartState.inApartment or not ApartState.currentApartment then 
        return TMGCore.Functions.Notify(Lang:t('error.to_far_from_door'), 'error') 
    end
    TriggerServerEvent('InteractSound_SV:PlayOnSource', 'StashOpen', 0.4)
    TriggerServerEvent('apartments:server:openStash', ApartState.currentApartment)
    print(string.format("^5[TMG]^7 Vault access granted for instance: %s", ApartState.currentApartment))
end)

RegisterNetEvent('apartments:client:ChangeOutfit', function()
    if not ApartState.inApartment then 
        return TMGCore.Functions.Notify(Lang:t('error.to_far_from_door'), 'error') 
    end
    TriggerServerEvent('InteractSound_SV:PlayOnSource', 'Clothes1', 0.4)
    TriggerEvent('tmg-clothing:client:openOutfitMenu')
    print("^5[TMG]^7 Wardrobe interface materialized. Local appearance matrix synchronized.")
end)

RegisterNetEvent('apartments:client:Logout', function()
    if not ApartState.inApartment then 
        return TMGCore.Functions.Notify(Lang:t('error.to_far_from_door'), 'error') 
    end
    ApartState.currentApartment = nil
    ApartState.inApartment = false
    ApartState.currentOffset = 0
    ApartState.houseObj = nil
    TriggerServerEvent('tmg-houses:server:LogoutLocation')
    print("^5[TMG]^7 Logout protocol initiated. Character state committed to NoSQL.")
end)




CreateThread(function()
    while not LocalPlayer.state.isLoggedIn do Wait(1000) end

    local sleep
    while true do
        sleep = 1000 

        if not ApartState.inApartment then
            SetClosestApartment()
            SetApartmentsEntranceTargets()

            if not Config.UseTarget and IsInsideEntranceZone then
                sleep = 0
                if IsControlJustPressed(0, 38) then 
                    OpenEntranceMenu()
                    exports['tmg-core']:HideText()
                end
            end

        else
            SetInApartmentTargets()

            if not Config.UseTarget then
                sleep = 0 

                if IsInsideExitZone and IsControlJustPressed(0, 38) then
                    OpenExitMenu()
                    exports['tmg-core']:HideText()

                elseif IsInsideStashZone and IsControlJustPressed(0, 38) then
                    TriggerEvent('apartments:client:OpenStash')
                    exports['tmg-core']:HideText()

                elseif IsInsideOutfitsZone and IsControlJustPressed(0, 38) then
                    TriggerEvent('apartments:client:ChangeOutfit')
                    exports['tmg-core']:HideText()

                elseif IsInsideLogoutZone and IsControlJustPressed(0, 38) then
                    TriggerEvent('apartments:client:Logout')
                    exports['tmg-core']:HideText()
                end
            end
        end

        Wait(sleep)
    end
end)
