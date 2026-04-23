local ApartmentObjects = {}
local TMGCore = exports['tmg-core']:GetCoreObject()

-- Functions


local function CreateApartmentId(type)
    local ApartmentId = tostring(type .. math.random(1111, 9999))
    
    local exists = exports['tmgnosql']:FetchOne('apartments', { ["name"] = ApartmentId })
    
    if not exists then 
        return ApartmentId 
    end
    
    return CreateApartmentId(type)
end

local function CreateApartment(source, apartmentType, apartmentNumber)
    local Player = TMGCore.Functions.GetPlayer(source)
    local citizenid = Player.PlayerData.citizenid

    local apartmentData = {
        citizenid = citizenid,
        name = apartmentType,
        number = apartmentNumber,
        label = apartmentType .. " " .. apartmentNumber
    }
    exports['tmgnosql']:InsertOne('apartments', apartmentData)

    Player.Functions.SetMetaData("currentapartment", apartmentType)
    
    print("^5[TMG]^7 Mainframe: Apartment " .. apartmentData.label .. " assigned to " .. citizenid)
end

local function GetApartmentInfo(apartmentId)
    return exports['tmgnosql']:FetchOne('apartments', { name = apartmentId })
end

-- Events

RegisterNetEvent('tmg-apartments:server:SetInsideMeta', function(house, insideId, bool, isVisiting)
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local insideMeta = Player.PlayerData.metadata['inside']

    if bool then
        local bucketId = GetHashKey(insideId)
        bucketId = math.abs(bucketId % 65535) + 1 

        if not isVisiting then
            insideMeta.apartment.apartmentType = house
            insideMeta.apartment.apartmentId = insideId
            insideMeta.house = nil
            Player.Functions.SetMetaData('inside', insideMeta)
        end
        SetPlayerRoutingBucket(src, bucketId)
        SetRoutingBucketPopulationEnabled(bucketId, false)
        print(string.format("^5[TMG]^7 Player %s entered bucket %s", Player.PlayerData.citizenid, bucketId))
    else
        insideMeta.apartment.apartmentType = nil
        insideMeta.apartment.apartmentId = nil
        insideMeta.house = nil
        Player.Functions.SetMetaData('inside', insideMeta)
        SetPlayerRoutingBucket(src, 0)
    end
end)

RegisterNetEvent('tmg-apartments:returnBucket', function()
    local src = source
    SetPlayerRoutingBucket(src, 0)
end)

RegisterNetEvent('apartments:server:openStash', function(CurrentApartment)
    local src = source
    exports['tmg-inventory']:OpenInventory(src, CurrentApartment)
end)

RegisterNetEvent('apartments:server:CreateApartment', function(type, label, firstSpawn)
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src) -- Standardized to TMGCore
    local num = CreateApartmentId(type)
    local apartmentId = tostring(type .. num)
    label = tostring(label .. ' ' .. num)

    exports['tmgnosql']:UpdateOne('apartments', 
        { 
            ["citizenid"] = Player.PlayerData.citizenid,
            ["name"] = apartmentId -- Specific filter to allow multiple apartments per CID
        }, 
        { 
            ["$set"] = { 
                ["name"] = apartmentId, -- This matches 'name' in SQL
                ["type"] = type,        -- Missing in your previous version
                ["label"] = label,
                ["citizenid"] = Player.PlayerData.citizenid
            } 
        }, 
        { ["upsert"] = true }
    )

    print("^5[TMG]^7 Mainframe: Apartment metadata hydrated for " .. Player.PlayerData.citizenid)
    
    TriggerClientEvent('TMGCore:Notify', src, Lang:t('success.receive_apart') .. ' (' .. label .. ')')
    
    if firstSpawn then
        TriggerClientEvent('apartments:client:SpawnInApartment', src, apartmentId, type)
    end
    TriggerClientEvent('apartments:client:SetHomeBlip', src, type)
end)

RegisterNetEvent('apartments:server:UpdateApartment', function(type, label)
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src)
    if not Player then return end

    exports['tmgnosql']:UpdateOne('apartments', 
        { ["citizenid"] = Player.PlayerData.citizenid }, 
        { 
            ["$set"] = { 
                ["type"] = type,   -- Fixed: Correctly updating the apartment type category
                ["label"] = label  -- Fixed: Correctly updating the display label
            } 
        }, 
        { ["upsert"] = false } -- Changed to false: Legacy 'UPDATE' implies the record already exists
    )

    print(string.format("^5[TMG]^7 Mainframe: Apartment meta synchronized for %s", Player.PlayerData.citizenid))
    
    TriggerClientEvent('TMGCore:Notify', src, Lang:t('success.changed_apart'))
    TriggerClientEvent('apartments:client:SetHomeBlip', src, type)
end)

RegisterNetEvent('apartments:server:RingDoor', function(apartmentId, apartment)
    local src = source
    if ApartmentObjects[apartment].apartments[apartmentId] ~= nil and next(ApartmentObjects[apartment].apartments[apartmentId].players) ~= nil then
        for k, _ in pairs(ApartmentObjects[apartment].apartments[apartmentId].players) do
            TriggerClientEvent('apartments:client:RingDoor', k, src)
        end
    end
end)

RegisterNetEvent('apartments:server:OpenDoor', function(target, apartmentId, apartment)
    local OtherPlayer = TMGCore.Functions.GetPlayer(target)
    if OtherPlayer ~= nil then
        TriggerClientEvent('apartments:client:SpawnInApartment', OtherPlayer.PlayerData.source, apartmentId, apartment)
    end
end)

RegisterNetEvent('apartments:server:AddObject', function(apartmentId, apartment, offset)
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src)
    if ApartmentObjects[apartment] ~= nil and ApartmentObjects[apartment].apartments ~= nil and ApartmentObjects[apartment].apartments[apartmentId] ~= nil then
        ApartmentObjects[apartment].apartments[apartmentId].players[src] = Player.PlayerData.citizenid
    else
        if ApartmentObjects[apartment] ~= nil and ApartmentObjects[apartment].apartments ~= nil then
            ApartmentObjects[apartment].apartments[apartmentId] = {}
            ApartmentObjects[apartment].apartments[apartmentId].offset = offset
            ApartmentObjects[apartment].apartments[apartmentId].players = {}
            ApartmentObjects[apartment].apartments[apartmentId].players[src] = Player.PlayerData.citizenid
        else
            ApartmentObjects[apartment] = {}
            ApartmentObjects[apartment].apartments = {}
            ApartmentObjects[apartment].apartments[apartmentId] = {}
            ApartmentObjects[apartment].apartments[apartmentId].offset = offset
            ApartmentObjects[apartment].apartments[apartmentId].players = {}
            ApartmentObjects[apartment].apartments[apartmentId].players[src] = Player.PlayerData.citizenid
        end
    end
end)

RegisterNetEvent('apartments:server:RemoveObject', function(apartmentId, apartment)
    local src = source
    if ApartmentObjects[apartment].apartments[apartmentId].players ~= nil then
        ApartmentObjects[apartment].apartments[apartmentId].players[src] = nil
        if next(ApartmentObjects[apartment].apartments[apartmentId].players) == nil then
            ApartmentObjects[apartment].apartments[apartmentId] = nil
        end
    end
end)

RegisterNetEvent('apartments:server:setCurrentApartment', function(ap)
    local Player = TMGCore.Functions.GetPlayer(source)

    if not Player then return end

    Player.Functions.SetMetaData('currentapartment', ap)
end)

-- Callbacks

TMGCore.Functions.CreateCallback('apartments:GetAvailableApartments', function(_, cb, apartment)
    local apartments = {}
    if ApartmentObjects ~= nil and ApartmentObjects[apartment] ~= nil and ApartmentObjects[apartment].apartments ~= nil then
        for k, _ in pairs(ApartmentObjects[apartment].apartments) do
            if (ApartmentObjects[apartment].apartments[k] ~= nil and next(ApartmentObjects[apartment].apartments[k].players) ~= nil) then
                local apartmentInfo = GetApartmentInfo(k)
                apartments[k] = apartmentInfo.label
            end
        end
    end
    cb(apartments)
end)

TMGCore.Functions.CreateCallback('apartments:GetApartmentOffset', function(_, cb, apartmentId)
    local retval = 0
    if ApartmentObjects ~= nil then
        for k, _ in pairs(ApartmentObjects) do
            if (ApartmentObjects[k].apartments[apartmentId] ~= nil and tonumber(ApartmentObjects[k].apartments[apartmentId].offset) ~= 0) then
                retval = tonumber(ApartmentObjects[k].apartments[apartmentId].offset)
            end
        end
    end
    cb(retval)
end)

TMGCore.Functions.CreateCallback('apartments:GetApartmentOffsetNewOffset', function(_, cb, apartment)
    local retval = Apartments.SpawnOffset
    if ApartmentObjects ~= nil and ApartmentObjects[apartment] ~= nil and ApartmentObjects[apartment].apartments ~= nil then
        for k, _ in pairs(ApartmentObjects[apartment].apartments) do
            if (ApartmentObjects[apartment].apartments[k] ~= nil) then
                retval = ApartmentObjects[apartment].apartments[k].offset + Apartments.SpawnOffset
            end
        end
    end
    cb(retval)
end)

TMGCore.Functions.CreateCallback('apartments:GetOwnedApartment', function(source, cb, cid)
    local citizenid = cid
    
    if not citizenid then
        local Player = TMGCore.Functions.GetPlayer(source)
        if Player then
            citizenid = Player.PlayerData.citizenid
        else
            return cb(nil)
        end
    end

    local result = exports['tmgnosql']:FetchOne('apartments', { 
        ["citizenid"] = citizenid 
    })
    
    cb(result)
    
    print(string.format("^5[TMG]^7 Mainframe: Apartment ownership telemetry retrieved for %s", citizenid))
end)


TMGCore.Functions.CreateCallback('apartments:IsOwner', function(source, cb, apartment)
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src)
    
    if Player ~= nil then
        local result = exports['tmgnosql']:FetchOne('apartments', { 
            ["citizenid"] = Player.PlayerData.citizenid 
        })
        
        if result ~= nil then
            if result.type == apartment then
                cb(true)
            else
                cb(false)
            end
        else
            cb(false)
        end
    else
        cb(false) -- Safety gate: Player session not found
    end
end)



TMGCore.Functions.CreateCallback('apartments:GetOutfits', function(source, cb)
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src)
    
    if Player then
        local result = exports['tmgnosql']:Fetch('player_outfits', { 
            ["citizenid"] = Player.PlayerData.citizenid 
        })
        
        if result and #result > 0 then
            cb(result)
        else
            cb(nil)
        end

        print(string.format("^5[TMG]^7 Mainframe: Wardrobe manifest synchronized for %s", Player.PlayerData.citizenid))
    else
        cb(nil) -- Safety gate: Player session not found
    end
end)
