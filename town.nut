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
    vehicle_group = null;           // Group ID of this town vehicles
    vehicle_list = null;            // List of owned vehicles
    population = null;              // Monthly population count
    pax_transported = null;         // Monthly percentage of transported pax
    mail_transported = null;        // Monthly percentage of transported mail
    connection_status = null;       // List of in range towns & status
    network_radius = null;          // radius

    constructor(town_id, load_town_data=false)
    {
        this.id = town_id;
        this.MonthlyManageTown();

        /* If there isn't saved data for the towns, we
		 * initialize them. Otherwise, we load saved data.
		 */
        if (!load_town_data)
        {
            this.connection_status = {};
            this.vehicle_list = [];
            this.vehicle_group = AIGroup.CreateGroup(AIVehicle.VT_ROAD, AIGroup.GROUP_INVALID);
            AIGroup.SetName(this.vehicle_group, AITown.GetName(this.id));
        }
        else
        {
            this.depot = ::TownDataTable[this.id].depot;
            this.vehicle_group = ::TownDataTable[this.id].vehicle_group;
            this.connection_status = ::TownDataTable[this.id].connection_status;

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
    town_data.connection_status <- this.connection_status;

    local sell_vehicles = [];
    foreach (vehicle in this.vehicle_list)
    {
        if (vehicle.action == Action.SELL)
            sell_vehicles.append(vehicle.id);
    }
    town_data.sell_vehicles <- sell_vehicles;

    return town_data;
}

function Town::ManageTown(max_veh)
{
    if (::EngineList.Count() == 0)
        return;

    if (this.depot == null)
    {
        // AILog.Info("Trying to build a depot in town " + AITown.GetName(this.id));
        this.depot = BuildDepot(this.id);
    }
    else
    {
        if (::EngineList.Count() > 0 || vehicle_list.len() > 0)
        {
            // AILog.Info("pop: " + this.population)

            local personal_count = ceil(this.population / 4000.0 * this.CalculateVehicleCountDecrease(this.pax_transported, 0, 100));
            local service_count = ceil(this.population / 12000.0 * this.CalculateVehicleCountDecrease(this.mail_transported, 10, 60));
            if (service_count > max_veh) {
                service_count = max_veh;
            }
            local emergency_count = ceil((this.population - 10000.0) / 60000.0) * 3;
            if (emergency_count > max_veh) {
                emergency_count = max_veh;
            }

            // AILog.Info("p: " + personal_count)
            // AILog.Info("s: " + service_count)
            // AILog.Info("e: " + emergency_count)

            if (GetEngineListByCategory(Category.MAIL | Category.GARBAGE).Count() > 0)
            {
                this.ManageVehiclesByCategory(service_count, Category.MAIL | Category.GARBAGE);
            }
            else
            {
                personal_count += service_count;
            }

            if (GetEngineListByCategory(Category.FIRE | Category.POLICE | Category.AMBULANCE).Count() > 0)
            {
                this.ManageVehiclesByCategory(emergency_count, Category.FIRE | Category.POLICE | Category.AMBULANCE);
            }
            else
            {
                personal_count +=  emergency_count;
            }

            if(personal_count > max_veh) {
                personal_count = max_veh;
            }

            // AILog.Info("p: " + personal_count)

            this.ManageVehiclesByCategory(personal_count, Category.CAR);
            this.UpdateVehicles();
        }
    }
}

function Town::MonthlyManageTown()
{
    local population = AITown.GetPopulation(this.id);
    this.population = population > 500000 ? 500000 : population;
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
        for (local i = 0; i < vehicle_count - target_count; ++i)
        {
            vehicle_list[i].Sell();
        }
    }
    else if (vehicle_count < target_count)
    {
        local company_vehicles_count = AIVehicleList().Count();
        local max_vehicles = AIGameSettings.GetValue("max_roadveh");

        // AILog.Info("Buying " + (target_count - vehicle_count) + " vehicles of type " + category);

        local engine_list = GetEngineListByCategory(category)

        // Randomize start of the vehicle list
        local engine = engine_list.Begin();
        local rand = AIBase.RandRange(engine_list.Count());
        for (local i = 0; i < rand; ++i)
        {
            engine = engine_list.Next();
        }

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

function Town::RemoveVehicle(vehicle_id)
{
    for (local i = 0; i < this.vehicle_list.len(); ++i)
    {
        if (this.vehicle_list[i].id == vehicle_id)
        {
            this.vehicle_list.remove(i);
            return true;
        }
    }

    return false;
}

/*
function Town::Parade(town_b)
{
    local company_vehicles_count = AIVehicleList().Count();
    local max_vehicles = AIGameSettings.GetValue("max_roadveh");

    local engine_list = GetEngineListByCategory(Category.SPORT);
    if (engine_list.Count() == 0)
        engine_list = AIEngineList(AIVehicle.VT_ROAD);
        engine_list.Valuate(AIEngine.GetMaxSpeed);
        engine_list.KeepTop(1);

    local engine = engine_list.Begin();
    for (local i = 0; (i < 10) && (company_vehicles_count + i < max_vehicles); ++i)
    {
        local purchased = AIVehicle.BuildVehicle(this.depot, engine);
        if (AIVehicle.IsValidVehicle(purchased))
        {
            local vehicle = Vehicle(purchased, engine_list.GetValue(engine));
            vehicle.action = Action.SELL;
            this.vehicle_list.append(vehicle);
            AIVehicle.StartStopVehicle(purchased);
            AIGroup.MoveVehicle(this.vehicle_group, purchased);
            AIOrder.AppendOrder(purchased, town_b.depot, AIOrder.OF_STOP_IN_DEPOT);
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
*/

function Town::ScanRegion(network_radius)
{
    // update network_radius
    this.network_radius = network_radius;

    // fill in connection_status
    local townlist = AITownList();
    local this_pos = AITown.GetLocation(this.id);
    townlist.Valuate(AITown.GetDistanceManhattanToTile, this_pos);
    townlist.KeepBelowValue(this.network_radius);
    townlist.Sort(AIList.SORT_BY_VALUE, true);
    foreach (t, _ in townlist) {
        if (!(t in this.connection_status)) {
            if (t == this.id) {
                this.connection_status[t] <- true; // always connect to self
            } else {
                this.connection_status[t] <- false;
            }
        }
    }

    // foreach (t, st in this.connection_status) {
    //     AILog.Info("    " + AITown.GetName(t) + ":" + st)
    // }
    // AILog.Info("---")
}