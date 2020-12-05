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
    vehicle_list = null;            // List of owned vehicles
    directions = null;              // A list with all directions
    population = null;              // Monthly population count 
    pax_transported = null;         // Monthly percentage of transported pax
    mail_transported = null;        // Monthly percentage of transported mail

    constructor(town_id)
    {
        this.id = town_id;
        this.directions = [1, -1, AIMap.GetMapSizeX(), -AIMap.GetMapSizeX()];
        this.population = 0;
        this.pax_transported = 0;
        this.mail_transported = 0;
        this.vehicle_list = [];
    }
}

function Town::ManageTown()
{
    if (this.depot == null)
    {
        // AILog.Info("Trying to build a depot in town " + AITown.GetName(this.id));
        this.depot = this.BuildDepot()
    }
    else
    {
        local personal_count = ceil(this.population / 100.0 * this.CalculateVehicleCountDecrease(this.pax_transported, 30));
        this.ManageVehiclesByCategory(personal_count, Category.CAR);
        local service_count = ceil(this.population / 500.0 * this.CalculateVehicleCountDecrease(this.mail_transported, 30, 80));
        this.ManageVehiclesByCategory(service_count, Category.MAIL | Category.GARBAGE);
        local emergency_count = ceil((this.population - 1000.0) / 2000.0) * 3;
        this.ManageVehiclesByCategory(emergency_count, Category.FIRE | Category.POLICE | Category.AMBULANCE);

        this.UpdateVehicles();
    }
}

function Town::MonthlyManageTown()
{
    local population = AITown.GetPopulation(this.id);
    this.population = population > 10000 ? 10000 : population;
    this.pax_transported = AITown.GetLastMonthTransportedPercentage(this.id, 0x00);
	this.mail_transported = AITown.GetLastMonthTransportedPercentage(this.id, 0x02);

    // // TODO: Remove
    // local personal_count = ceil(this.population / 100.0 * this.CalculateVehicleCountDecrease(this.pax_transported, 30));
    // local service_count = ceil(this.population / 500.0 * this.CalculateVehicleCountDecrease(this.mail_transported, 30, 80));
    // local emergency_count = ceil((this.population - 1000) / 2000.0) * 3;
    // AILog.Info(AITown.GetName(this.id) + ": Population = " + this.population + ", Pax transported = " + this.pax_transported + " Mail transported = " + this.mail_transported);
    // AILog.Info("Personal = " + personal_count + ", Services = " + service_count + ", Emergency = " + emergency_count);
}

function Town::GetVehicleCountByCategory(category)
{
    local count = 0;

    foreach (vehicle in this.vehicle_list)
    {
        if (vehicle.action != Action.SELL && vehicle.category & category)
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
        if (vehicle.action != Action.SELL && vehicle.category & category)
        {
            vehicle_list.append(vehicle);
        }
    }

    return vehicle_list;
}

function Town::GetEngineListByCategory(category)
{
    local engine_list = AIList();
    foreach (engine, cat in ::EngineList)
    {
        if (category & cat)
        {
            engine_list.AddItem(engine, category);
        }
    }

    return engine_list;
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

function Town::ManageVehiclesByCategory(target_count, category)
{
    local vehicle_count = this.GetVehicleCountByCategory(category);
    // AILog.Info(AITown.GetName(this.id) + ": " + category + " (" + vehicle_count + "/" + target_count + ")");
    if (vehicle_count > target_count)
    {
        // AILog.Info("Selling " + (vehicle_count - target_count) + " vehicles of type " + category);

        local vehicle_list = this.GetVehiclesByCategory(category);
        vehicle_list = this.GetFurthestVehiclesToDepot(vehicle_list, vehicle_count - target_count);

        foreach (vehicle in vehicle_list)
        {
            vehicle.Sell();
        }
    }
    else if (vehicle_count < target_count)
    {
        local company_vehicles_count = AIVehicleList().Count();
        local max_vehicles = AIGameSettings.GetValue("max_roadveh");

        // AILog.Info("Buying " + (target_count - vehicle_count) + " vehicles of type " + category);

        local engine_list = this.GetEngineListByCategory(category)
        local engine = engine_list.Begin();
        for (local i = 0; (i < target_count - vehicle_count) && (company_vehicles_count + i < max_vehicles); ++i)
        {
            local vehicle = AIVehicle.BuildVehicle(this.depot, engine);
            if (AIVehicle.IsValidVehicle(vehicle))
            {
                this.vehicle_list.append(Vehicle(vehicle, engine_list.GetValue(engine)));
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
}

function Town::CalculateVehicleCountDecrease(transported, min_transported, max_transported=100)
{
    if (transported < min_transported)
    {
        return 1.0;
    }
    else if (transported > max_transported)
    {
        return 0.0;
    }
    else
    {
        return (1.0 - (transported - min_transported).tofloat() / (max_transported - min_transported).tofloat());
    }
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