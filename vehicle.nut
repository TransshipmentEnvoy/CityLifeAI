/*
 * This file is part of CityLifeAI, an AI for OpenTTD.
 *
 * It's free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the
 * Free Software Foundation, version 2 of the License.
 *
 */

enum Category {
    CAR = 1,
    BUS = 2,
    MAIL = 4,
    GARBAGE = 8,
    TRUCK = 16,
    POLICE = 32,
    AMBULANCE = 64,
    FIRE = 128,
    SPORT = 256
};

enum Action {
    NONE,
    LOST,
    SELL
};

class Vehicle
{
    id = null;
    category = null;
    action = null;

    constructor(id, category) {
        this.id = id;
        this.category = category;
        this.action = Action.NONE;
    }
}

function Vehicle::Sell()
{
    if (this.action == Action.SELL)
        return;

    if (AIVehicle.SendVehicleToDepot(this.id))
        this.action = Action.SELL;
}

function Vehicle::Update()
{
    if (AIVehicle.IsStoppedInDepot(this.id))
    {
        if (this.action == Action.SELL)
            return AIVehicle.SellVehicle(this.id);
        else
            AIVehicle.StartStopVehicle(this.id);
    }

    return false;
}

function CreateEngineList() 
{
    local engine_list = AIEngineList(AIVehicle.VT_ROAD);

    engine_list.Valuate(AIEngine.GetRunningCost);
    engine_list.KeepValue(0);

    foreach (engine, index in engine_list)
    {
        engine_list.SetValue(engine, GetEngineCategory(engine));
    }
    engine_list.Sort(AIList.SORT_BY_VALUE, true);

    ::EngineList <- engine_list; // Global variable with toy engines and their categories
}

function GetEngineCategory(engine)
{
    local weight = AIEngine.GetWeight(engine);
    local speed = AIEngine.GetMaxSpeed(engine);
    local power = AIEngine.GetPower(engine);
    local effort = AIEngine.GetMaxTractiveEffort(engine);

    AILog.Info("Engine id: " + engine
    	     + ", name:" + AIEngine.GetName(engine)
    	     + ", weight: " + weight
    	     + ", speed: " + speed
    	     + ", power: " + power
    	     + ", effort: " + effort
    	     );

    if (weight == 2 && speed == 127 && power == 100 && effort == 5) 
        return Category.POLICE;
    else if (weight == 3 && speed == 88 && power == 140 && effort == 8) 
        return Category.AMBULANCE;
    else if (weight == 19 && speed == 88 && power == 500 && effort == 55) 
        return Category.FIRE;
    else if (weight == 1 && speed == 56 && power == 50 && effort == 2) 
        return Category.MAIL;
    else if (weight == 1 && speed == 376 && power == 750 && effort == 5) 
        return Category.SPORT;
    else if (weight == 12 && speed == 64 && power == 300 && effort == 34) 
        return Category.GARBAGE;
    else
        return Category.CAR;
}

function GetVehicleCountByCategory(vehicle_list, category)
{
    local count = 0;

    foreach (vehicle in vehicle_list)
    {
        if (vehicle.action != Action.SELL && vehicle.category & category)
        {
            ++count;
        }
    }

    return count;
}

function GetVehiclesByCategory(vehicle_list, category)
{
    local vehicle_cat_list = [];

    foreach (vehicle in vehicle_list)
    {
        if (vehicle.action != Action.SELL && vehicle.category & category)
        {
            vehicle_cat_list.append(vehicle);
        }
    }

    return vehicle_cat_list;
}

function GetEngineListByCategory(category)
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

function GetFurthestVehiclesToDepot(vehicle_list, depot, count)
{
    local distances = [];
    foreach (vehicle in vehicle_list)
    {
       distances.append(AIMap.DistanceManhattan(depot, AIVehicle.GetLocation(vehicle.id)));
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