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

// Import ToyLib
import("Library.AIToyLib", "AIToyLib", 1);
import("Library.SCPLib", "SCPLib", 45);

class CityLife extends AIController
{
    load_saved_data = null;
    current_save_version = null;
    current_date = null;
	current_month = null;
	current_year = null;
    toy_lib = null;
    towns = null;

    constructor() 
    {
        this.load_saved_data = false;
        this.current_save_version = SELF_VERSION;
        this.current_date = 0;
        this.current_month = 0;
        this.current_year = 0;
    } // constructor
}

function CityLife::Init()
{
    // Wait for game to start and give time to SCP
    this.Sleep(84); // TODO: Uncomment

    // Init ToyLib
    this.toy_lib = AIToyLib(null);

    // Init time
    local date = AIDate.GetCurrentDate();
    this.current_date = date;
    this.current_month = AIDate.GetMonth(date);
    this.current_year = AIDate.GetYear(date);

    // Set company name
    if (!AICompany.SetName("CityLifeAI")) {
        local i = 2;
        while (!AICompany.SetName("CityLifeAI #" + i)) {
            i += 1;
            if (i > 255) break;
        } // while
    } // if

    // Set predident's name
    AICompany.SetPresidentName("Bernie");

    // Enable automatic renewal of vehicles
    AICompany.SetAutoRenewStatus(true);
    AICompany.SetAutoRenewMonths(1);

    // Create Vehicles list
    CreateEngineList();

    // Create the towns list
	AILog.Info("Create town list ... (can take a while on large maps)");
	this.towns = this.CreateTownList();
    this.MonthlyManageTowns();
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
        if (date - this.current_date != 0) {
            this.current_date = date;

            AIToyLib.Check();
        }

        // Run the monthly functions
        local month = AIDate.GetMonth(date);
        if (month - this.current_month != 0) {
            AILog.Info("Monthly update");

            this.MonthlyManageTowns();
            this.AskForMoney();

            this.current_month = month;
        }

        // Run the yearly functions
        local year = AIDate.GetYear(date);
        if (year - this.current_year != 0) {
            AILog.Info("Yearly Update");

            CreateEngineList();

            this.current_year = year
        }

        //AILog.Info("Processing town index " + town_index);
        this.ManageTown(this.towns[town_index++])
        if (town_index >= this.towns.len())
        {
            town_index = 0;
        }
    }

}

function CityLife::AskForMoney()
{
    local bank_balance = AICompany.GetBankBalance(AICompany.COMPANY_SELF);
    local loan_amount = AICompany.GetLoanAmount();
    local max_loan_amount = AICompany.GetMaxLoanAmount();
    if (loan_amount > 0 && bank_balance >= loan_amount) {
        AICompany.SetLoanAmount(0);
        bank_balance -= loan_amount;
    }

    if (bank_balance < max_loan_amount) {
        AIToyLib.ToyAskMoney(max_loan_amount - bank_balance);
        AILog.Info("I am once again asking for your financial support of " + (max_loan_amount - bank_balance));
    }
}

function CityLife::CreateTownList()
{
    local towns_list = AITownList();
    local towns_array = [];

    foreach (t, _ in towns_list) {
        towns_array.append(Town(t));
	}

    return towns_array;
}

function CityLife::MonthlyManageTowns()
{
    foreach (town in this.towns) {
        town.MonthlyManageTown();
	}
}

function CityLife::ManageTown(town)
{
    town.ManageTown();
}

function CityLife::Save()
{
    AILog.Info("Saving data...");

	local save_table = {};
    save_table.save_version <- this.current_save_version;

    return save_table;
}

function CityLife::Load()
{
    if ((saved_data.rawin("save_version") && saved_data.save_version >= SELF_MINLOADVERSION))
    {
        this.load_saved_data = true;
    }
}
