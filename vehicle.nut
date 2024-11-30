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
    LUXURY = 256,
    OBSOLETE = 512
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

function RefreshEngineList() 
{
    local engine_list = AIEngineList(AIVehicle.VT_ROAD);

    engine_list.Valuate(AIEngine.GetRunningCost);
    engine_list.KeepValue(0);
    // remove those has cargo capacity
    engine_list.Valuate(AIEngine.GetCapacity);
    engine_list.KeepBelowValue(0);

    foreach (engine, index in engine_list)
    {
        engine_list.SetValue(engine, GetEngineCategory(engine));
    }
    engine_list.Sort(AIList.SORT_BY_VALUE, true);

    ::EngineList <- engine_list; // Global variable with toy engines and their categories
}

function IsObsolete(speed)
{
	local date = AIDate.GetCurrentDate()
	local year = AIDate.GetYear(date)

	local modern_speed_threshold = 0
	if (year > 1930)
		modern_speed_threshold = AIController.GetSetting("obsolete_spd_1930");
	if (year > 2000)
		modern_speed_threshold = AIController.GetSetting("obsolete_spd_2000");
		
	return (speed < modern_speed_threshold)
}

function GetEngineCategory(engine)
{
    local weight = AIEngine.GetWeight(engine);
    local speed = AIEngine.GetMaxSpeed(engine);
    local power = AIEngine.GetPower(engine);
    local effort = AIEngine.GetMaxTractiveEffort(engine);

    local category = Category.CAR;
    if (weight == 2 && speed == 127 && power == 100 && effort == 5) // Eyecandy Road Vehicles: Police Car
        category = Category.POLICE;
    else if (weight == 3 && speed == 88 && power == 140 && effort == 8) // Eyecandy Road Vehicles: Ambulance
        category = Category.AMBULANCE;
    else if (weight == 19 && speed == 88 && power == 500 && effort == 55) // Eyecandy Road Vehicles: Fire Engine
        category = Category.FIRE;
    else if (weight == 1 && speed == 56 && power == 50 && effort == 2) // Eyecandy Road Vehicles: Mail Van
        category = Category.MAIL;
    else if (weight == 12 && speed == 64 && power == 300 && effort == 34) // Eyecandy Road Vehicles: Dustbin Lorry (Modern)
        category = Category.GARBAGE;
    else if (weight == 12 && speed == 56 && power == 200 && effort == 34) // Eyecandy Road Vehicles: Dustbin Lorry (Classic)
        category = Category.GARBAGE;
    else if (weight == 1 && speed == 376 && power == 750 && effort == 5) // Funny Cars: F1 Jordan
        category = Category.LUXURY;
    // else if ()

    if (IsObsolete(speed))
		category = category | Category.OBSOLETE

    AILog.Info("Engine id: " + engine
    	     + ", name:" + AIEngine.GetName(engine)
    	     + ", weight: " + weight
    	     + ", speed: " + speed
    	     + ", power: " + power
    	     + ", effort: " + effort
             + ", category: " + category
    	     );
    
    return category;
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

function GetEngineListByCategory(category, exclude_category = 0)
{
    local engine_list = AIList();
    foreach (engine, cat in ::EngineList)
    {
        if ((category & cat) && !(exclude_category & cat))
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