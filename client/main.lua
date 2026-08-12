local TMGCore = exports['tmg-core']:GetCoreObject()

local ApartState = {
    inApartment = false,
    closestHouse = nil,
    currentApartment = nil,
    currentOffset = 0,
    isOwned = false,
    isTenant = false,
    ownedData = {},
    rentedData = {},
    houseObj = nil,
    poiOffsets = nil,
    blips = {},
    targets = {}
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
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentSubstringPlayerName(data.label)
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

local function HydratePropertyData()
    TMGCore.Functions.TriggerCallback('apartments:GetPlayerProperties', function(properties)
        ApartState.ownedData = properties.owned or {}
        ApartState.rentedData = properties.rented or {}
        
        for _, apt in pairs(ApartState.ownedData) do
            RefreshApartmentBlips(apt.name)
        end
    end)
end


local function OpenEntranceMenu(houseId)
    local headerMenu = {}
    local isOwner = false
    local isTenant = false
    local aptData = nil
    
    for _, v in pairs(ApartState.ownedData) do
        if v.name == houseId then isOwner = true aptData = v break end
    end
    for _, v in pairs(ApartState.rentedData) do
        if v.name == houseId then isTenant = true aptData = v break end
    end

    if isOwner or isTenant then
        headerMenu[#headerMenu + 1] = {
            header = Lang:t('text.enter'),
            txt = isOwner and Lang:t('info.current_tier') .. (aptData.tier or "tier1") or "Tenant Access",
            params = { event = 'apartments:client:EnterApartment', args = { id = houseId } }
        }
    else
        headerMenu[#headerMenu + 1] = {
            header = Lang:t('text.move_here'),
            params = { event = 'apartments:client:UpdateApartment', args = { id = houseId } }
        }
    end
    
    if isOwner then
        headerMenu[#headerMenu + 1] = {
            header = Lang:t('text.manage_keys'),
            params = { event = 'apartments:client:KeyMenu', args = { id = houseId } }
        }
        headerMenu[#headerMenu + 1] = {
            header = Lang:t('text.upgrade_apart'),
            params = { event = 'apartments:client:UpgradeMenu', args = { id = houseId, currentTier = aptData.tier } }
        }
    end

    headerMenu[#headerMenu + 1] = { header = Lang:t('text.ring_doorbell'), params = { event = 'apartments:client:DoorbellMenu', args = { id = houseId } } }
    headerMenu[#headerMenu + 1] = { header = Lang:t('text.close_menu'), params = { event = 'tmg-menu:client:closeMenu' } }
    
    exports['tmg-menu']:openMenu(headerMenu)
end


local function InitializeExteriorTargets()
    if not Apartments.Locations or not next(Apartments.Locations) then return end
    
    for id, apartment in pairs(Apartments.Locations) do
        local boxData = apartment.polyzoneBoxData
        local zoneName = 'apt_entrance_' .. id
        
        exports['tmg-target']:AddBoxZone(zoneName, apartment.coords.enter.xyz, boxData.length, boxData.width, {
            name = zoneName,
            heading = boxData.heading,
            debugPoly = boxData.debug,
            minZ = boxData.minZ,
            maxZ = boxData.maxZ,
        }, {
            options = {
                {
                    type = "client",
                    icon = "fas fa-building",
                    label = Lang:t('text.options'),
                    action = function()
                        OpenEntranceMenu(id)
                    end
                }
            },
            distance = boxData.distance
        })
    end
end

local function InitializeInteriorTargets()
    if not ApartState.poiOffsets or not ApartState.closestHouse then return end
    
    local baseCoords = Apartments.Locations[ApartState.closestHouse].coords.enter
    local zPos = baseCoords.z - ApartState.currentOffset
    local offsets = ApartState.poiOffsets
    
    local entrancePos = vector3(baseCoords.x + offsets.exit.x, baseCoords.y + offsets.exit.y, zPos + offsets.exit.z)
    local stashPos    = vector3(baseCoords.x - offsets.stash.x, baseCoords.y - offsets.stash.y, zPos + offsets.stash.z)
    local outfitsPos  = vector3(baseCoords.x - offsets.clothes.x, baseCoords.y - offsets.clothes.y, zPos + offsets.clothes.z)
    local logoutPos   = vector3(baseCoords.x - offsets.logout.x, baseCoords.y + offsets.logout.y, zPos + offsets.logout.z)

    exports['tmg-target']:AddBoxZone('apt_exit', entrancePos, 1.5, 1.5, { name = 'apt_exit', heading = 0, minZ = entrancePos.z - 1.0, maxZ = entrancePos.z + 2.0 }, {
        options = {
            { type = 'client', event = 'apartments:client:OpenDoor', icon = 'fas fa-door-open', label = Lang:t('text.open_door') },
            { type = 'client', event = 'apartments:client:LeaveApartment', icon = 'fas fa-sign-out-alt', label = Lang:t('text.leave') },
        }, distance = 1.5
    })
    
    exports['tmg-target']:AddBoxZone('apt_stash', stashPos, 1.5, 1.5, { name = 'apt_stash', heading = 0, minZ = stashPos.z - 1.0, maxZ = stashPos.z + 2.0 }, {
        options = { { type = 'client', event = 'apartments:client:OpenStash', icon = 'fas fa-box-open', label = Lang:t('text.open_stash') } }, distance = 1.5
    })
    
    exports['tmg-target']:AddBoxZone('apt_wardrobe', outfitsPos, 1.5, 1.5, { name = 'apt_wardrobe', heading = 0, minZ = outfitsPos.z - 1.0, maxZ = outfitsPos.z + 2.0 }, {
        options = { { type = 'client', event = 'apartments:client:ChangeOutfit', icon = 'fas fa-tshirt', label = Lang:t('text.change_outfit') } }, distance = 1.5
    })
    
    exports['tmg-target']:AddBoxZone('apt_logout', logoutPos, 1.5, 1.5, { name = 'apt_logout', heading = 0, minZ = logoutPos.z - 1.0, maxZ = logoutPos.z + 2.0 }, {
        options = { { type = 'client', event = 'apartments:client:Logout', icon = 'fas fa-power-off', label = Lang:t('text.logout') } }, distance = 1.5
    })
end

local function DeleteInApartmentTargets()
    exports['tmg-target']:RemoveZone('apt_exit')
    exports['tmg-target']:RemoveZone('apt_stash')
    exports['tmg-target']:RemoveZone('apt_wardrobe')
    exports['tmg-target']:RemoveZone('apt_logout')
end


local function loadAnimDict(dict)
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do Wait(10) end
end

local function openHouseAnim()
    local ped = PlayerPedId()
    loadAnimDict('anim@heists@keycard@')
    TaskPlayAnim(ped, 'anim@heists@keycard@', 'exit', 5.0, 1.0, -1, 16, 0, false, false, false)
    Wait(400)
    ClearPedTasks(ped)
end

RegisterNetEvent('apartments:client:EnterApartment', function(data)
    local house = data.id
    local aptData = nil

    for _, v in pairs(ApartState.ownedData) do
        if v.name == house then aptData = v break end
    end
    if not aptData then
        for _, v in pairs(ApartState.rentedData) do
            if v.name == house then aptData = v break end
        end
    end

    if not aptData then return end

    local tierData = Config.Upgrades[aptData.tier or "tier1"]
    local zOffset = tierData.interiorOffset or 0
    ApartState.currentOffset = Apartments.SpawnOffset + zOffset

    TriggerServerEvent('InteractSound_SV:PlayOnSource', 'houses_door_open', 0.1)
    openHouseAnim()

    ApartState.closestHouse = house
    ApartState.currentApartment = aptData.name
    ApartState.rangDoorbell = nil

    TriggerServerEvent('apartments:server:AddObject', aptData.name, house, ApartState.currentOffset)

    local enterCoords = Apartments.Locations[house].coords.enter
    local interiorPos = {
        x = enterCoords.x,
        y = enterCoords.y,
        z = enterCoords.z - ApartState.currentOffset
    }

    local shellData = exports['tmg-interior']:CreateApartmentFurnished(interiorPos)
    ApartState.houseObj = shellData[1]
    ApartState.poiOffsets = shellData[2]
    ApartState.inApartment = true

    Wait(500)
    TriggerEvent('tmg-weathersync:client:DisableSync')
    TriggerServerEvent('tmg-apartments:server:SetInsideMeta', house, aptData.name, true, false)
    TriggerServerEvent('InteractSound_SV:PlayOnSource', 'houses_door_close', 0.1)

    InitializeInteriorTargets()
    
    print(string.format("^5[TMG]^7 Instancing complete. Rendered %s shell at offset: %s", aptData.tier or "tier1", ApartState.currentOffset))
end)

RegisterNetEvent('apartments:client:LeaveApartment', function()
    local house = ApartState.closestHouse
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

        Wait(500)
        TriggerServerEvent('apartments:server:RemoveObject', ApartState.currentApartment, house)
        TriggerServerEvent('tmg-apartments:server:SetInsideMeta', ApartState.currentApartment, false)

        ApartState.currentApartment = nil
        ApartState.inApartment = false
        ApartState.currentOffset = 0
        ApartState.houseObj = nil

        DoScreenFadeIn(1000)
        TriggerServerEvent('InteractSound_SV:PlayOnSource', 'houses_door_close', 0.1)
    end)
end)

RegisterNetEvent('apartments:client:DoorbellMenu', function(data)
    local houseId = data.id
    
    TMGCore.Functions.TriggerCallback('apartments:GetAvailableApartments', function(apartments)
        if not apartments or next(apartments) == nil then
            return TMGCore.Functions.Notify(Lang:t('error.nobody_home'), 'error')
        end

        local apartmentMenu = { { header = Lang:t('text.tennants'), isMenuHeader = true } }
        
        for k, v in pairs(apartments) do
            apartmentMenu[#apartmentMenu + 1] = {
                header = v,
                params = { event = 'apartments:client:RingMenu', args = { apartmentId = k, houseId = houseId } }
            }
        end
        
        apartmentMenu[#apartmentMenu + 1] = { header = Lang:t('text.close_menu'), params = { event = 'tmg-menu:client:closeMenu' } }
        exports['tmg-menu']:openMenu(apartmentMenu)
    end, houseId)
end)

RegisterNetEvent('apartments:client:RingMenu', function(data)
    ApartState.rangDoorbell = data.houseId
    TriggerServerEvent('InteractSound_SV:PlayOnSource', 'doorbell', 0.1)
    TriggerServerEvent('apartments:server:RingDoor', data.apartmentId, data.houseId)
end)

RegisterNetEvent('apartments:client:RingDoor', function(player, _)
    ApartState.currentDoorbell = player
    TriggerServerEvent('InteractSound_SV:PlayOnSource', 'doorbell', 0.1)
    TMGCore.Functions.Notify(Lang:t('info.at_the_door'), 'primary')
end)

RegisterNetEvent('apartments:client:OpenDoor', function()
    if ApartState.currentDoorbell == 0 then 
        return TMGCore.Functions.Notify(Lang:t('error.nobody_at_door'), 'error') 
    end
    TriggerServerEvent('apartments:server:OpenDoor', ApartState.currentDoorbell, ApartState.currentApartment, ApartState.closestHouse)
    ApartState.currentDoorbell = 0
end)


RegisterNetEvent('apartments:client:OpenStash', function()
    if not ApartState.inApartment then return end
    TriggerServerEvent('InteractSound_SV:PlayOnSource', 'StashOpen', 0.4)
    TriggerServerEvent('apartments:server:openStash', ApartState.currentApartment)
end)

RegisterNetEvent('apartments:client:ChangeOutfit', function()
    if not ApartState.inApartment then return end
    TriggerServerEvent('InteractSound_SV:PlayOnSource', 'Clothes1', 0.4)
    TriggerEvent('tmg-clothing:client:openOutfitMenu')
end)

RegisterNetEvent('apartments:client:Logout', function()
    if not ApartState.inApartment then return end
    TriggerServerEvent('tmg-houses:server:LogoutLocation')
end)


RegisterNetEvent('apartments:client:UpdateApartment', function(data)
    local targetHouse = data.id
    if not targetHouse or not Apartments.Locations[targetHouse] then return end

    local targetLabel = Apartments.Locations[targetHouse].label

    TMGCore.Functions.TriggerCallback('apartments:GetOwnedApartment', function(result)
        if result == nil then
            TriggerServerEvent("apartments:server:CreateApartment", targetHouse, targetLabel, false)
        else
            TriggerServerEvent('apartments:server:UpdateApartment', targetHouse, targetLabel)
        end

        SetTimeout(1000, HydratePropertyData)
        print(string.format("^5[TMG]^7 Migration sequence finalized for property: %s", targetLabel))
    end)
end)

RegisterNetEvent('apartments:client:UpgradeMenu', function(data)
    local menu = { { header = "Property Renovations", isMenuHeader = true } }
    
    for tierKey, tierData in pairs(Config.Upgrades) do
        local isCurrent = (data.currentTier == tierKey)
        menu[#menu + 1] = {
            header = tierData.label,
            txt = isCurrent and "Current Tier" or string.format("Cost: $%d", tierData.price),
            disabled = isCurrent,
            params = {
                isServer = true,
                event = 'apartments:server:UpgradeApartment',
                args = { apartmentId = data.id, tierKey = tierKey }
            }
        }
    end
    menu[#menu + 1] = { header = Lang:t('text.back'), params = { event = 'tmg-menu:client:closeMenu' } }
    exports['tmg-menu']:openMenu(menu)
end)

RegisterNetEvent('apartments:client:KeyMenu', function(data)
    local dialog = exports['tmg-input']:ShowInput({
        header = "Manage Tenant Access",
        submitText = "Execute",
        inputs = {
            { type = 'text', isRequired = true, name = 'cid', text = 'Target CitizenID' },
            { type = 'select', isRequired = true, name = 'action', text = 'Action', options = { { value = 'give', text = 'Grant Key' }, { value = 'revoke', text = 'Revoke Key' } } }
        }
    })
    
    if dialog then
        if dialog.action == 'give' then
            TriggerServerEvent('apartments:server:GiveKey', data.id, dialog.cid)
        elseif dialog.action == 'revoke' then
            TriggerServerEvent('apartments:server:RevokeKey', data.id, dialog.cid)
        end
        SetTimeout(1000, HydratePropertyData)
    end
end)


RegisterNetEvent('TMGCore:Client:OnPlayerLoaded', function()
    HydratePropertyData()
    RefreshApartmentBlips(nil)
    print("^5[TMG]^7 Mainframe: Local property matrix hydrated. Thread optimizations engaged.")
end)

RegisterNetEvent('TMGCore:Client:OnPlayerUnload', function()
    ApartState.currentApartment = nil
    ApartState.inApartment = false
    ApartState.currentOffset = 0
    ApartState.houseObj = nil
    ApartState.closestHouse = nil
    ApartState.isOwned = false

    DeleteInApartmentTargets()
    print("^5[TMG]^7 Mainframe: Session terminated. Residential matrix purged.")
end)

RegisterNetEvent('apartments:client:SetHomeBlip', function(home)
    RefreshApartmentBlips(home)
end)

CreateThread(function()
    InitializeExteriorTargets()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    
    if ApartState.inApartment and ApartState.houseObj then
        exports['tmg-interior']:DespawnInterior(ApartState.houseObj, function()
            TriggerEvent('tmg-weathersync:client:EnableSync')
        end)
    end
    
    DeleteInApartmentTargets()
    
    for id, _ in pairs(Apartments.Locations) do
        exports['tmg-target']:RemoveZone('apt_entrance_' .. id)
    end
end)