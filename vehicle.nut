/*
 * This file is part of CityLifeAI, an AI for OpenTTD.
 *
 * It's free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the
 * Free Software Foundation, version 2 of the License.
 *
 */

enum Category {
    CAR,
    BUS,
    MAIL,
    GARBAGE,
    TRUCK,
    POLICE,
    AMBULANCE,
    FIRE,
    SPORT
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
        local weight = AIEngine.GetWeight(engine);
        local speed = AIEngine.GetMaxSpeed(engine);
        local power = AIEngine.GetPower(engine);
        local effort = AIEngine.GetMaxTractiveEffort(engine);

        // AILog.Info("Engine id: " + engine
		// 	     + ", name:" + AIEngine.GetName(engine)
		// 	     + ", weight: " + weight
		// 	     + ", speed: " + speed
		// 	     + ", power: " + power
		// 	     + ", effort: " + effort
		// 	     );

        if (weight == 2 && speed == 127 && power == 100 && effort == 5) 
            engine_list.SetValue(engine, Category.POLICE)
        else if (weight == 3 && speed == 88 && power == 140 && effort == 8) 
            engine_list.SetValue(engine, Category.AMBULANCE);
        else if (weight == 19 && speed == 88 && power == 500 && effort == 55) 
            engine_list.SetValue(engine, Category.FIRE);
        else if (weight == 1 && speed == 56 && power == 50 && effort == 2) 
            engine_list.SetValue(engine, Category.MAIL);
        else if (weight == 1 && speed == 376 && power == 750 && effort == 5) 
            engine_list.SetValue(engine, Category.SPORT);
        else if (weight == 12 && speed == 64 && power == 300 && effort == 34) 
            engine_list.SetValue(engine, Category.GARBAGE);
        else
            engine_list.SetValue(engine, Category.CAR);
        

        // AILog.Info("Vehicle " + AIEngine.GetName(engine) + " of category " + engine_list.GetValue(engine));
    }

    ::EngineList <- engine_list; // Global variable with toy engines and their categories
}