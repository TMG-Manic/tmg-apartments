local ApartmentObjects = {}
local TMGCore = exports['tmg-core']:GetCoreObject()




local function CreateApartmentId(type)
    local ApartmentId = tostring(type .. math.random(1111, 9999))
    
    local exists = Citizen.Await(exports['tmgnosql']:FetchOne('apartments', { ["name"] = ApartmentId }))
    
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
    return Citizen.Await(exports['tmgnosql']:FetchOne('apartments', { ["name"] = apartmentId }))
end

AddEventHandler('playerDropped', function()
    local src = source
    
    for house, houseData in pairs(ApartmentObjects) do
        if houseData.apartments then
            for aptId, aptData in pairs(houseData.apartments) do
                if aptData.players[src] then
                    aptData.players[src] = nil
                    
                    if next(aptData.players) == nil then
                        ApartmentObjects[house].apartments[aptId] = nil
                    end
                end
            end
        end
    end
end)

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
    else
        insideMeta.apartment.apartmentType = nil
        insideMeta.apartment.apartmentId = nil
        insideMeta.house = nil
        Player.Functions.SetMetaData('inside', insideMeta)
        SetPlayerRoutingBucket(src, 0)
    end
end)

RegisterNetEvent('tmg-apartments:returnBucket', function()
    SetPlayerRoutingBucket(source, 0)
end)

RegisterNetEvent('apartments:server:openStash', function(CurrentApartment)
    local src = source
    local isInside = false
    
    for house, data in pairs(ApartmentObjects) do
        if data.apartments[CurrentApartment] and data.apartments[CurrentApartment].players[src] then
            isInside = true
            break
        end
    end
    
    if isInside then
        exports['tmg-inventory']:OpenInventory(src, CurrentApartment)
    else
        print(string.format("^1[TMG Security]^7 Player %s attempted to exploit stash trigger for instance: %s", src, CurrentApartment))
    end
end)

RegisterNetEvent('apartments:server:GiveKey', function(apartmentId, targetCid)
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src)
    
    local apt = Citizen.Await(exports['tmgnosql']:FetchOne('apartments', { 
        ["name"] = apartmentId, 
        ["citizenid"] = Player.PlayerData.citizenid 
    }))
    
    if apt then
        exports['tmgnosql']:UpdateOne('apartments',
            { ["name"] = apartmentId },
            { ["$addToSet"] = { ["tenants"] = targetCid } }
        )
        TriggerClientEvent('TMGCore:Notify', src, Lang:t('success.key_given'))
        print(string.format("^5[TMG]^7 Mainframe: Offline key granted to CID %s for Apartment %s", targetCid, apartmentId))
    else
        TriggerClientEvent('TMGCore:Notify', src, Lang:t('error.not_owner'), 'error')
    end
end)

RegisterNetEvent('apartments:server:RevokeKey', function(apartmentId, targetCid)
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src)
    
    local apt = Citizen.Await(exports['tmgnosql']:FetchOne('apartments', { 
        ["name"] = apartmentId, 
        ["citizenid"] = Player.PlayerData.citizenid 
    }))
    
    if apt then
        exports['tmgnosql']:UpdateOne('apartments',
            { ["name"] = apartmentId },
            { ["$pull"] = { ["tenants"] = targetCid } }
        )
        TriggerClientEvent('TMGCore:Notify', src, Lang:t('success.key_revoked'))
    else
        TriggerClientEvent('TMGCore:Notify', src, Lang:t('error.not_owner'), 'error')
    end
end)

RegisterNetEvent('apartments:server:UpgradeApartment', function(apartmentId, tierKey)
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src)
    local upgradeData = Config.Upgrades[tierKey]
    
    if not upgradeData then return end
    
    local apt = Citizen.Await(exports['tmgnosql']:FetchOne('apartments', { 
        ["name"] = apartmentId, 
        ["citizenid"] = Player.PlayerData.citizenid 
    }))
    
    if apt then
        if Player.Functions.RemoveMoney('bank', upgradeData.price, "apartment-upgrade") then
            exports['tmgnosql']:UpdateOne('apartments',
                { ["name"] = apartmentId },
                { ["$set"] = { ["tier"] = tierKey } }
            )
            TriggerClientEvent('TMGCore:Notify', src, Lang:t('success.upgraded') .. upgradeData.label)
        else
            TriggerClientEvent('TMGCore:Notify', src, Lang:t('error.insufficient_funds'), 'error')
        end
    end
end)

RegisterNetEvent('apartments:server:CreateApartment', function(type, label, firstSpawn)
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src) 
    local num = CreateApartmentId(type)
    local apartmentId = tostring(type .. num)
    label = tostring(label .. ' ' .. num)

    exports['tmgnosql']:UpdateOne('apartments', 
        { 
            ["citizenid"] = Player.PlayerData.citizenid,
            ["name"] = apartmentId 
        }, 
        { 
            ["$set"] = { 
                ["name"] = apartmentId, 
                ["type"] = type,        
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
                ["type"] = type,   
                ["label"] = label  
            } 
        }, 
        { ["upsert"] = false } 
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

TMGCore.Functions.CreateCallback('apartments:GetPlayerProperties', function(source, cb, cid)
    local citizenid = cid or TMGCore.Functions.GetPlayer(source).PlayerData.citizenid
    
    local owned = Citizen.Await(exports['tmgnosql']:FetchAll('apartments', { ["citizenid"] = citizenid }))
    local rented = Citizen.Await(exports['tmgnosql']:FetchAll('apartments', { ["tenants"] = citizenid }))
    
    cb({
        owned = owned or {},
        rented = rented or {}
    })
    
    print(string.format("^5[TMG]^7 Mainframe: Full Property Matrix synchronized for %s", citizenid))
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
        cb(false) 
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
        cb(nil) 
    end
end)
