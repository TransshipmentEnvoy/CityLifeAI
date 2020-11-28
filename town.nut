/*
 * This file is part of CityLifeAI, an AI for OpenTTD.
 *
 * It's free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the
 * Free Software Foundation, version 2 of the License.
 *
 */

class Town
{
    id = null;                      // Town id
    depot = null;                   // Built depo
    vehicle_target_count = null;    // Number of vehicles to maintain
    vehicle_list = null;            // List of owned vehicles
    directions = null;              // A list with all directions

    constructor(town_id)
    {
        this.id = town_id;
        this.directions = [1, -1, AIMap.GetMapSizeX(), -AIMap.GetMapSizeX()];
        this.vehicle_target_count = 0;
        this.vehicle_list = [];
    }
}

function Town::ManageTown()
{
    if (this.depot == null)
    {
        AILog.Info("Trying to build a depot in town " + AITown.GetName(this.id));
        this.depot = this.BuildDepot()
    }
    else
    {
        local company_vehicles = AIVehicleList();
        local max_vehicles = AIGameSettings.GetValue("max_roadveh");

        local vehicle_count = this.GetVehicleCount(Category.CAR);
        if (vehicle_count > this.vehicle_target_count)
        {
            AILog.Info("Selling " + (vehicle_count - this.vehicle_target_count) + " vehicles in " + AITown.GetName(this.id))

            local vehicle_list = this.GetVehiclesByCategory(Category.CAR);
            vehicle_list = this.GetFurthestVehiclesToDepot(vehicle_list, vehicle_count - this.vehicle_target_count);

            foreach (vehicle in vehicle_list)
            {
                vehicle.Sell();
            }
        }
        else if (vehicle_count < this.vehicle_target_count)
        {
            // Clone engine_list from global ::EngineList
            local engine_list = AIList();
            foreach (engine, category in ::EngineList)
            {
                engine_list.AddItem(engine, category);
            }

            engine_list.KeepValue(Category.CAR);
            local engine = engine_list.Begin();
            for (local i = 0; (i < this.vehicle_target_count - vehicle_count) && (company_vehicles.Count() + i < max_vehicles); ++i)
            {
                local vehicle = AIVehicle.BuildVehicle(this.depot, engine);
                if (AIVehicle.IsValidVehicle(vehicle))
                {
                    this.vehicle_list.append(Vehicle(vehicle, Category.CAR));
                }
                else
                {
                    break;
                }

                engine = engine_list.Next();
                if (engine_list.IsEnd())
                    engine = engine_list.Begin();
            }
        }

        this.UpdateVehicles();
    }
}

function Town::UpdateVehicleCount()
{
    local population = AITown.GetPopulation(this.id);
    population = population > 10000 ? 10000 : population;

    this.vehicle_target_count = (population / 100).tointeger();
}

function Town::GetVehicleCount(category)
{
    local count = 0;

    foreach (vehicle in this.vehicle_list)
    {
        if (vehicle.action != Action.SELL && vehicle.category == category)
        {
            ++count;
        }
    }

    return count;
}

function Town::GetVehiclesByCategory(category)
{
    local vehicle_list = [];

    foreach (vehicle in this.vehicle_list)
    {
        if (vehicle.action != Action.SELL && vehicle.category == category)
        {
            vehicle_list.append(vehicle);
        }
    }

    return vehicle_list;
}

function Town::GetFurthestVehiclesToDepot(vehicle_list, count)
{
    local distances = [];
    foreach (vehicle in vehicle_list)
    {
       distances.append(AIMap.DistanceManhattan(this.depot, AIVehicle.GetLocation(vehicle.id)));
    }

    local n = distances.len();
    for (local i = 0; i < n - 1; i++)
    {
        for (local j = 0; j < n - i - 1; j++) 
        {
            if (distances[j] < distances[j+1])
            {
                local temp = distances[j];
                distances[j] = distances[j+1];
                distances[j+1] = temp;

                temp = vehicle_list[j];
                vehicle_list[j] = vehicle_list[j+1];
                vehicle_list[j+1] = temp;
            }
        }
    }

    vehicle_list.resize(count);
    return vehicle_list;
}

function Town::UpdateVehicles()
{
    for (local i = 0; i < this.vehicle_list.len(); ++i)
    {
        if (this.vehicle_list[i].Update())
        {
            this.vehicle_list.remove(i--);
        }
    }
}

function Town::BuildDepot()
{
    AIRoad.SetCurrentRoadType(AIRoad.ROADTYPE_ROAD);

    local depot_placement_tiles = AITileList();
    local town_location = AITown.GetLocation(this.id);

    // The rectangle corners must be valid tiles
    local corner1 = town_location - AIMap.GetTileIndex(15, 15);
    while(!AIMap.IsValidTile(corner1) || AIMap.DistanceManhattan(corner1, town_location) > 30) {
        corner1 += AIMap.GetTileIndex(1, 1);
    }

    local corner2 = town_location + AIMap.GetTileIndex(15, 15);
    while(!AIMap.IsValidTile(corner2) || AIMap.DistanceManhattan(corner2, town_location) > 30) {
        corner2 -= AIMap.GetTileIndex(1, 1);
    }

    depot_placement_tiles.AddRectangle(corner1, corner2);

    // Only consider tiles that are buildable
    depot_placement_tiles.Valuate(AITile.IsBuildable);
    depot_placement_tiles.KeepValue(1);

    // search from town center and outwards
    depot_placement_tiles.Valuate(AIMap.DistanceManhattan, town_location);
    depot_placement_tiles.Sort(AIList.SORT_BY_VALUE, true); // highest value last

	// Look for a suitable spot and test if we can build there.
    local depot_tile = depot_placement_tiles.Begin();
    while(!depot_placement_tiles.IsEnd()) {
        foreach (direction in directions)
        {
            if (!AIRoad.IsRoadTile(depot_tile + direction)) 
            {
                continue;
            }

            if (AIRoad.CanBuildConnectedRoadPartsHere(depot_tile, depot_tile + direction, depot_tile + direction + 1)) 
            {
                if (AIRoad.BuildRoad(depot_tile, depot_tile + direction) || AIError.GetLastError() == AIError.ERR_ALREADY_BUILT)
                {
                    if (AIRoad.BuildRoadDepot(depot_tile, depot_tile + direction))
                        return depot_tile;
                    else if (!(AIError.GetLastError() == AIError.ERR_FLAT_LAND_REQUIRED
                            || AIError.GetLastError() == AIError.ERR_AREA_NOT_CLEAR)) 
                    {
                        AILog.Warning("Build depot :: Tile " + depot_tile + ": " + AIError.GetLastErrorString());
                        return null;
                    }
                }
                else if (!(AIError.GetLastError() == AIError.ERR_LAND_SLOPED_WRONG
                        || AIError.GetLastError() == AIError.ERR_AREA_NOT_CLEAR
                        || AIError.GetLastError() == AIError.ERR_ROAD_ONE_WAY_ROADS_CANNOT_HAVE_JUNCTIONS
                        || AIError.GetLastError() == AIError.ERR_ROAD_WORKS_IN_PROGRESS
                        || AIError.GetLastError() == AIError.ERR_VEHICLE_IN_THE_WAY))
                {
                    AILog.Warning("Build road :: Tile " + depot_tile + ": " + AIError.GetLastErrorString());
                    return null;
                }
            }
        }

        if(AIController.GetSetting("debug_signs"))
            AISign.BuildSign(depot_tile, "tile");

        depot_tile = depot_placement_tiles.Next();
    }

    return null;
}