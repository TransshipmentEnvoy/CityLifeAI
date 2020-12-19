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
    road_type = null;               // Road type of the town
    vehicle_group = null;           // Group ID of this town vehicles
    vehicle_list = null;            // List of owned vehicles
    population = null;              // Monthly population count 
    pax_transported = null;         // Monthly percentage of transported pax
    mail_transported = null;        // Monthly percentage of transported mail
    connections = null;             // List of established road connections

    constructor(town_id, load_town_data=false)
    {
        this.id = town_id;
        this.road_type = this.GetRoadType();
        this.MonthlyManageTown();

        /* If there isn't saved data for the towns, we
		 * initialize them. Otherwise, we load saved data.
		 */
        if (!load_town_data)
        {
            this.connections = [];
            this.vehicle_list = [];
            this.vehicle_group = AIGroup.CreateGroup(AIVehicle.VT_ROAD, AIGroup.GROUP_INVALID);
            AIGroup.SetName(this.vehicle_group, AITown.GetName(this.id));
        }
        else
        {
            this.depot = ::TownDataTable[this.id].depot;
            this.vehicle_group = ::TownDataTable[this.id].vehicle_group;
            this.connections = ::TownDataTable[this.id].connections;

            // Recreate list of vehicles from group information
            if (AIGroup.IsValidGroup(this.vehicle_group))
            {
                local vehicle_list = AIVehicleList_Group(this.vehicle_group);
                this.vehicle_list = [];
                local sell_vehicles = ::TownDataTable[this.id].sell_vehicles;
                foreach (vehicle, _ in vehicle_list)
                {
                    this.vehicle_list.append(Vehicle(vehicle, ::EngineList.GetValue(AIVehicle.GetEngineType(vehicle))));
                    foreach (index, sell_id in sell_vehicles)
                    {
                        if (vehicle == sell_id)
                        {
                            this.vehicle_list.top().action = Action.SELL;
                            sell_vehicles.remove(index);
                            break;
                        }
                    }
                }
            }
        }
    }
}

function Town::SaveTownData()
{
    local town_data = {};
    town_data.depot <- this.depot;
    town_data.vehicle_group <- this.vehicle_group;
    town_data.connections <- this.connections;

    local sell_vehicles = [];
    foreach (vehicle in this.vehicle_list)
    {
        if (vehicle.action == Action.SELL)
            sell_vehicles.append(vehicle.id);
    }
    town_data.sell_vehicles <- sell_vehicles;

    return town_data;
}

function Town::ManageTown()
{
    if (this.depot == null)
    {
        // AILog.Info("Trying to build a depot in town " + AITown.GetName(this.id));
        this.depot = BuildDepot(this.id, this.road_type);
    }
    else
    {
        if (::EngineList.Count() > 0 || vehicle_list.len() > 0)
        {
            local personal_count = ceil(this.population / 100.0 * this.CalculateVehicleCountDecrease(this.pax_transported, 30));

            if (GetEngineListByCategory(Category.MAIL | Category.GARBAGE).Count() > 0)
            {
                local service_count = ceil(this.population / 500.0 * this.CalculateVehicleCountDecrease(this.mail_transported, 30, 80));
                this.ManageVehiclesByCategory(service_count, Category.MAIL | Category.GARBAGE);
            }
            else
            {
                personal_count += ceil(this.population / 500.0 * this.CalculateVehicleCountDecrease(this.mail_transported, 30, 80));
            }

            if (GetEngineListByCategory(Category.FIRE | Category.POLICE | Category.AMBULANCE).Count() > 0)
            {
                local emergency_count = ceil((this.population - 1000.0) / 2000.0) * 3;
                this.ManageVehiclesByCategory(emergency_count, Category.FIRE | Category.POLICE | Category.AMBULANCE);
            }
            else
            {
                personal_count += ceil((this.population - 1000.0) / 2000.0) * 3;
            }

            this.ManageVehiclesByCategory(personal_count, Category.CAR);
            this.UpdateVehicles();
        }
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

function Town::ManageVehiclesByCategory(target_count, category)
{
    local vehicle_count = GetVehicleCountByCategory(this.vehicle_list, category);
    // AILog.Info(AITown.GetName(this.id) + ": " + category + " (" + vehicle_count + "/" + target_count + ")");
    if (vehicle_count > target_count)
    {
        // AILog.Info("Selling " + (vehicle_count - target_count) + " vehicles of type " + category);

        local vehicle_list = GetVehiclesByCategory(this.vehicle_list, category);
        vehicle_list = GetFurthestVehiclesToDepot(vehicle_list, this.depot, vehicle_count - target_count);

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

        local engine_list = GetEngineListByCategory(category)
        local engine = engine_list.Begin();
        for (local i = 0; (i < target_count - vehicle_count) && (company_vehicles_count + i < max_vehicles); ++i)
        {
            local vehicle = AIVehicle.BuildVehicle(this.depot, engine);
            if (AIVehicle.IsValidVehicle(vehicle))
            {
                this.vehicle_list.append(Vehicle(vehicle, engine_list.GetValue(engine)));
                AIGroup.MoveVehicle(this.vehicle_group, vehicle);
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

function Town::GetRoadType()
{
    local town_location = AITown.GetLocation(this.id);
    local road_types = AIRoadTypeList(AIRoad.ROADTRAMTYPES_ROAD);
    foreach(road, _ in road_types)
    {
        if (AIRoad.HasRoadType(town_location, road))
            return road;
    }

    return AIRoad.ROADTRAMTYPES_ROAD;
}