Config = {}
Config.UseTarget = true 
Config.UseIntercom = true 


Config.Keys = {
    Enabled = true,
    MaxTenantsPerApartment = 3, 
    AllowTenantStashAccess = true 
}

Apartments = {}
Apartments.Starting = true
Apartments.SpawnOffset = 30 


Config.Upgrades = {
    ["tier1"] = { 
        price = 0, 
        label = "Basic Studio", 
        interiorOffset = 0, 
        stashWeight = 100000 
    },
    ["tier2"] = { 
        price = 50000, 
        label = "Modern Loft", 
        interiorOffset = 50, 
        stashWeight = 250000 
    },
    ["tier3"] = { 
        price = 150000, 
        label = "Luxury Penthouse", 
        interiorOffset = 100, 
        stashWeight = 500000 
    }
}


Apartments.Locations = {
    ["apartment1"] = {
        name = "apartment1",
        label = "South Rockford Drive",
        coords = {
            enter = vector4(-667.02, -1105.24, 14.63, 242.32),
        },
        polyzoneBoxData = {
            heading = 245,
            minZ = 13.5,
            maxZ = 16.0,
            debug = false,
            length = 1,
            width = 3,
            distance = 2.0,
            created = false
        }
    },
    ["apartment2"] = {
        name = "apartment2",
        label = "Morningwood Blvd",
        coords = {
            enter = vector4(-1288.52, -430.51, 35.15, 124.81),
        },
        polyzoneBoxData = {
            heading = 124,
            minZ = 34.0,
            maxZ = 37.0,
            debug = false,
            length = 1,
            width = 3,
            distance = 2.0,
            created = false
        }
    }
    
}