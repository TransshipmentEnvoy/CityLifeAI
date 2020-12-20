/*
 * This file is part of CityLifeAI, an AI for OpenTTD.
 *
 * It's free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the
 * Free Software Foundation, version 2 of the License.
 *
 */

require("version.nut");
require("vehicle.nut");
require("town.nut");
require("roadbuilder.nut");

// Import ToyLib
import("Library.AIToyLib", "AIToyLib", 1);
import("Library.SCPLib", "SCPLib", 45);
import("util.superlib", "SuperLib", 40);

RoadPathFinder <- SuperLib.RoadPathFinder;

class CityLife extends AIController
{
    load_saved_data = null;
    current_save_version = null;
    ai_init_done = null;
    duplicit_ai = null;
    current_date = null;
	current_month = null;
	current_year = null;
    toy_lib = null;
    towns = null;
    road_builder = null;

    constructor() 
    {
        this.load_saved_data = false;
        this.current_save_version = SELF_VERSION;
        this.ai_init_done = false;
        this.duplicit_ai = false;
        this.current_date = 0;
        this.current_month = 0;
        this.current_year = 0;
        this.road_builder = RoadBuilder();
        ::TownDataTable <- {};
    } // constructor
}

function CityLife::Init()
{
    // Wait for game to start and give time to SCP
    this.Sleep(84);

    // Init ToyLib
    this.toy_lib = AIToyLib(null);

    // Init time
    local date = AIDate.GetCurrentDate();
    this.current_date = date;
    this.current_month = AIDate.GetMonth(date);
    this.current_year = AIDate.GetYear(date);

    // Set company name
    if (!AICompany.SetName("CityLifeAI")) 
    {
        this.duplicit_ai = true;
        local i = 2;
        while (!AICompany.SetName("CityLifeAI #" + i)) 
        {
            i += 1;
            if (i > 255) break;
        }
    }

    // Enable automatic renewal of vehicles
    AICompany.SetAutoRenewStatus(true);
    AICompany.SetAutoRenewMonths(1);

    // Create Vehicles list
    CreateEngineList();

    // Create the towns list
	AILog.Info("Create town list ... (can take a while on large maps)");
	this.towns = this.CreateTownList();

    // Ending initialization
	this.ai_init_done = true;

    // Now we can free ::TownDataTable
	::TownDataTable = null;
}

function CityLife::Start()
{
    this.Init();

    // Main loop
    local town_index = 0;
	while (true) 
    {
        // Run the daily functions
        local date = AIDate.GetCurrentDate();
        if (date - this.current_date != 0) 
        {
            this.current_date = date;

            AIToyLib.Check();
        }

        // Run the monthly functions
        local month = AIDate.GetMonth(date);
        if (month - this.current_month != 0) 
        {
            AILog.Info("Monthly update");

            this.MonthlyManageTowns();
            this.MonthlyManageRoadBuilder();
            this.AskForMoney();

            this.current_month = month;
        }

        // Run the yearly functions
        local year = AIDate.GetYear(date);
        if (year - this.current_year != 0) 
        {
            AILog.Info("Yearly Update");

            CreateEngineList();

            this.current_year = year
        }

        this.HandleEvents();
        this.ManageTown(this.towns[town_index++]);
        town_index = town_index >= this.towns.len() ? 0 : town_index;
        this.ManageRoadBuilder();
    }
}

function CityLife::HandleEvents()
{
    while (AIEventController.IsEventWaiting()) 
    {
		local event = AIEventController.GetNextEvent();
		switch (event.GetEventType())
        {
		    // On town founding, add a new town to the list
            case AIEvent.ET_TOWN_FOUNDED:
                event = AIEventTownFounded.Convert(event);
                local town_id = event.GetTownID();
                // AILog.Info("New town founded: " + AITown.GetName(town_id));
                if (AITown.IsValidTown(town_id))
                    this.towns[town_id] <- Town(town_id, false);
                break;

            case AIEvent.ET_VEHICLE_LOST:
                event = AIEventVehicleLost.Convert(event);
                AIVehicle.SendVehicleToDepot(event.GetVehicleID());
                break;

            // case AIEvent.ET_VEHICLE_CRASHED: // TODO: Handle crash
            //     break;

            default: 
                break;
		}
	}
}

function CityLife::AskForMoney()
{
    local bank_balance = AICompany.GetBankBalance(AICompany.COMPANY_SELF);
    local loan_amount = AICompany.GetLoanAmount();
    local max_loan_amount = AICompany.GetMaxLoanAmount();
    if (loan_amount > 0 && bank_balance >= loan_amount) 
    {
        AICompany.SetLoanAmount(0);
        bank_balance -= loan_amount;
    }

    if (bank_balance < max_loan_amount) 
    {
        AIToyLib.ToyAskMoney(max_loan_amount - bank_balance);
        AILog.Info("I am once again asking for your financial support of " + (max_loan_amount - bank_balance));
    }
}

function CityLife::CreateTownList()
{
    local towns_list = AITownList();
    local towns_array = {};

    foreach (t, _ in towns_list)
    {
        towns_array[t] <- Town(t, this.load_saved_data);
	}

    return towns_array;
}

function CityLife::MonthlyManageTowns()
{
    foreach (_, town in this.towns)
    {
        town.MonthlyManageTown();
	}
}

function CityLife::ManageTown(town)
{
    town.ManageTown();
}

function CityLife::MonthlyManageRoadBuilder()
{
    if (this.duplicit_ai)
        return;

    this.road_builder.Init(this.towns);
}

function CityLife::ManageRoadBuilder()
{
    if (this.road_builder.status != PathfinderStatus.RUNNING)
        return;

    if (this.road_builder.FindPath(this.towns))
    {
        this.road_builder.BuildRoad(this.towns);
        this.towns[this.road_builder.town_a].Parade(this.towns[this.road_builder.town_b]);
    }
}

function CityLife::Save()
{
    AILog.Info("Saving data...");
    local save_table = {};

    /* If the script isn't yet initialized, we can't retrieve data
	 * from Town instances. Thus, simply use the original
	 * loaded table. Otherwise we build the table with town data.
	 */
    save_table.town_data_table <- {};
    if (!this.ai_init_done)
    {
        save_table.town_data_table <- ::TownDataTable;
    }
    else
    {
        foreach (town_id, town in this.towns)
        {
            save_table.town_data_table[town_id] <- town.SaveTownData();
        }
        // Also store a savegame version flag
        save_table.save_version <- this.current_save_version;
    }

    return save_table;
}

function CityLife::Load(version, saved_data)
{
    if ((saved_data.rawin("save_version") && saved_data.save_version == this.current_save_version))
    {
        this.load_saved_data = true;
        foreach (townid, town_data in saved_data.town_data_table) 
        {
			::TownDataTable[townid] <- town_data;
		}
    }
    else 
    {
		Log.Info("Data format doesn't match with current version. Resetting.", Log.LVL_INFO);
	}
}
