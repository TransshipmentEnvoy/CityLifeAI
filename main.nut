/*
 * This file is part of CityLifeAI (Custom), an AI for OpenTTD.
 *
 * It's free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the
 * Free Software Foundation, version 2 of the License.
 *
 */

require("math_util.nut")
require("version.nut");
require("vehicle.nut");
require("town.nut");
require("roadbuilder.nut");
require("roadpathfinder.nut")

// Import ToyLib
//import("Library.AIToyLib", "AIToyLib", 2);
require("dep/AIToyLib/main.nut");
import("Library.SCPLib", "SCPLib", 45);
import("util.superlib", "SuperLib", 40);

// RoadPathFinder <- SuperLib.RoadPathFinder;
RoadPathFinder <- CityLifeAI_RoadPathFinder

class CityLife extends AIController
{
    load_saved_data = null;
    current_save_version = null;
    ai_init_done = null;
    duplicit_ai = null;

    current_date = null;
    current_month = null;
    current_year = null;
    current_decade_year = null;

    toy_lib = null;

    road_type = null;

    towns = null;
    towns_id = null;
    towns_backup_id = null;

    road_builder = null;

    // comm
    received_exemption = false;

    // param
    MaxTownNum = null;
    NetworkRadius = null;
    MaxVehiclePerTown = null;

    // me
    Me = null;

    constructor()
    {
        this.load_saved_data = false;
        this.current_save_version = SELF_MAJORVERSION;    // Ensures compatibility between revisions
        this.ai_init_done = false;
        this.duplicit_ai = false;
        this.current_date = 0;
        this.current_month = 0;
        this.current_year = 0;
        this.current_decade_year = 0;
        this.road_builder = RoadBuilder();
        ::TownDataTable <- {};
        ::TownsIDList <- [];

        this.Me = AICompany.ResolveCompanyID(AICompany.COMPANY_SELF);
    } // constructor
}

function CityLife::LoadParam()
{
    this.MaxTownNum = AIController.GetSetting("MaxTownNum");
    this.NetworkRadius = AIController.GetSetting("NetworkRadius");
    this.MaxVehiclePerTown = AIController.GetSetting("MaxVehiclePerTown");
}

function CityLife::Init()
{
    // Wait for game to start and give time to SCP
    this.Sleep(74);

    // Version
    AILog.Info("Version: " + SELF_MAJORVERSION + "." + SELF_MINORVERSION )

    // Init ToyLib
    this.toy_lib = AIToyLib(null, this);
    this.toy_lib.SCPConfigChange(false, false, true);

    // Init time
    local date = AIDate.GetCurrentDate();
    this.current_date = date;
    this.current_month = AIDate.GetMonth(date);
    this.current_year = AIDate.GetYear(date);
    this.current_decade_year = current_year

    if (!this.load_saved_data)
    {
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

        // Set company color (if fails, use default asignment)
        AICompany.SetPrimaryLiveryColour(AICompany.LS_DEFAULT, AICompany.COLOUR_GREY);
        AICompany.SetPrimaryLiveryColour(AICompany.LS_DEFAULT, AICompany.COLOUR_GREY);
        AICompany.SetPresidentName("CityLife");
    }

    // Load Param
    this.LoadParam();

    if (!this.load_saved_data)
    {
        // Enable automatic renewal of vehicles
        AICompany.SetAutoRenewStatus(true);
        AICompany.SetAutoRenewMonths(1);
    }

    // Create Vehicles list
    RefreshEngineList();

    // Create the towns list
    if (!this.load_saved_data) {
        AILog.Info("Create town list ... (can take a while on large maps)");
        this.CreateTownList();
    } else {
        AILog.Info("Loading town list ...");
        this.LoadTownList();
    }
    this.VerboseTownList();

    // road type
    if (!this.load_saved_data) {
        this.road_type = GetRoadType(null);
    }
    if (this.road_type != null) {
        AILog.Info("Select Road Type: " + AIRoad.GetName(this.road_type));
        AIRoad.SetCurrentRoadType(this.road_type);
    }

    // comm
    this.received_exemption = false;

    // Ending initialization
    this.ai_init_done = true;

    // Now we can free ::TownDataTable
    ::TownDataTable = null;
    ::TownsIDList = null;
}

function CityLife::Start()
{
    this.Init();

    // Main loop
    AIToyLib.Check();
    local town_id = this.towns_id.Begin();
    while (true)
    {
        // Get ticks
        local start_tick = AIController.GetTick();

        // Load Params (Update In Game)
        this.LoadParam();

        // Handle Events
        this.HandleEvents();

        // Get bank balance
        local bank_balance = AICompany.GetBankBalance(AICompany.COMPANY_SELF);
        local allow_manage_town = (bank_balance > 50000);

        // Run the daily functions
        local date = AIDate.GetCurrentDate();
        if (date - this.current_date != 0)
        {
            this.current_date = date;

            // comm
            AIToyLib.Check();
        }

        // Run the monthly functions
        local month = AIDate.GetMonth(date);
        if (month - this.current_month != 0)
        {
            AILog.Info("Monthly update");

            this.MonthlyManageTowns();
            this.MonthlyManageRoadBuilder(town_id);
            this.AskForMoney();
            this.AskForExemption();

            this.current_month = month;
        }

        // Run the yearly functions
        local year = AIDate.GetYear(date);
        if (year - this.current_year != 0)
        {
            AILog.Info("Yearly Update");

            RefreshEngineList();

            // update road type
            local road_type = GetRoadType(null);
            if (road_type != null) {
                if (road_type != this.road_type) {
                    AILog.Info("New road type: " + AIRoad.GetName(road_type) + "  => Switch to new epoch");
                    // switch to a new epoch
                    SwitchToNewEpoch();
                }
                this.road_type = road_type;
                AIRoad.SetCurrentRoadType(this.road_type);
            }

            // yearly parade
            local target_id = this.towns[town_id].ParadeFind(this.towns_id);
            if (target_id != null) {
                AILog.Info("Parade: " + AITown.GetName(town_id) + " => " + AITown.GetName(target_id));
                this.towns[town_id].Parade(this.towns[target_id]);
            }

            // manage inactive
            foreach (t, _ in this.towns) {
                if (!this.towns_id.HasItem(t)) {
                    this.towns[t].UpdateVehicles();
                }
            }

            this.current_year = year
        }

        // Run the per-decade functions
        if (year - this.current_decade_year >= 10)
        {
            AILog.Info("Decade Update");

            // update town list
            town_id = this.RefreshTownList()
            this.VerboseTownList();

            this.current_decade_year = year;
        }

        // Run the per-loop functions
        {
            // town
            if (allow_manage_town)
            {
                // AILog.Info("Manage town: " + AITown.GetName(this.towns[town_id].id));
                this.ManageTown(this.towns[town_id]);
                town_id = this.towns_id.Next();
                if (this.towns_id.IsEnd()) {
                    town_id = this.towns_id.Begin();
                }
            }

            // road
            this.ManageRoadBuilder();
        }

        // Prevent excesive cpu usage
        if (AIController.GetTick() - start_tick < 5)
            AIController.Sleep(5);
    }
}

function CityLife::HandleEvents()
{
    while (AIEventController.IsEventWaiting())
    {
        local event = AIEventController.GetNextEvent();
        switch (event.GetEventType())
        {
            // * this is disabled because town list upkeeping is moved to decade updates
            // On town founding, add a new town to the list
            case AIEvent.ET_TOWN_FOUNDED:
                /*
                event = AIEventTownFounded.Convert(event);
                local town_id = event.GetTownID();
                // AILog.Info("New town founded: " + AITown.GetName(town_id));
                if (AITown.IsValidTown(town_id))
                    this.towns[town_id] <- Town(town_id, false); */
                break;

            // Lost vehicles are sent to the nearest depot (for parade)
            case AIEvent.ET_VEHICLE_LOST:
                event = AIEventVehicleLost.Convert(event);
                local vehicle_id = event.GetVehicleID();
                for (local order_pos = 0; order_pos < AIOrder.GetOrderCount(vehicle_id); ++order_pos)
                {
                    AIOrder.RemoveOrder(vehicle_id, order_pos);
                }
                AIVehicle.SendVehicleToDepot(vehicle_id);
                break;

            // On vehicle crash, remove the vehicle from its towns vehicle list
            case AIEvent.ET_VEHICLE_CRASHED:
                event = AIEventVehicleCrashed.Convert(event);
                local vehicle_id = event.GetVehicleID();
                foreach (town_id, town in this.towns)
                {
                    if (town.RemoveVehicle(vehicle_id))
                        break;
                }
                break;

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
    // AILog.Info("max_loan_amount: " + max_loan_amount);
    // AILog.Info("bank balance: " + bank_balance);
    max_loan_amount = max_loan_amount >  500000 ? max_loan_amount :  500000;
    max_loan_amount = max_loan_amount < 2000000 ? max_loan_amount : 2000000;
    if (loan_amount > 0 && bank_balance >= loan_amount)
    {
        AICompany.SetLoanAmount(0);
        bank_balance -= loan_amount;
    }

    AILog.Info("max loan amount: " + max_loan_amount);
    AILog.Info("bank balance: " + bank_balance);

    if (bank_balance < max_loan_amount)
    {
        AIToyLib.ToyAskMoney(max_loan_amount - bank_balance);
        AILog.Info("I am once again asking for your financial support of " + (max_loan_amount - bank_balance));
    }
}

function CityLife::AskForExemption()
{
    if (this.received_exemption)
        return;
    // Ask Exemption
    AIToyLib.AskExemption(1);
    AILog.Info("I am once again asking for your exemption as an AI");
    AIToyLib.Check();
}

function CityLife::ConfirmExemption(message, self)
{
    AILog.Info("I have received my exemption as an AI");
    self.received_exemption = true;
}

function CityLife::CreateTownList()
{
    local towns_list = AITownList();
    towns_list.Valuate(AITown.GetPopulation);
    towns_list.Sort(AIList.SORT_BY_VALUE, false);
    towns_list.KeepTop(this.MaxTownNum);

    local towns_array = {};

    foreach (t, _ in towns_list)
    {
        towns_array[t] <- Town(t, this.load_saved_data);
        towns_array[t].ScanRegion(this.NetworkRadius);
    }

    this.towns = towns_array;

    towns_list.Valuate(AIBase.RandItem);
    towns_list.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);
    towns_list.Valuate(function(_){return 0;});
    this.towns_id = towns_list;
}

function CityLife::LoadTownList()
{
    this.towns = {};
    foreach (t, _ in ::TownDataTable) {
        this.towns[t] <- Town(t, this.load_saved_data);
        // this.towns[t].ScanRegion(this.NetworkRadius);
    }

    this.towns_id = AIList();
    foreach (t in ::TownsIDList) {
        this.towns_id.AddItem(t, 0);
    }
}

function CityLife::RefreshTownList() {
    local towns_list = AITownList();
    towns_list.Valuate(AITown.GetPopulation);
    towns_list.Sort(AIList.SORT_BY_VALUE, false);
    towns_list.KeepTop(this.MaxTownNum);

    // get town not in this.towns_id
    local new_towns = [];
    foreach (t, _ in towns_list) {
        if (!this.towns_id.HasItem(t)) {
            new_towns.append(t);

            local name = AITown.GetName(t);
            local population = AITown.GetPopulation(t);
            AILog.Info("New town: " + name + " (" + population + ")");
        }
    }

    // get town not in new towns_list
    local removed_towns = [];
    foreach (t, _ in this.towns_id) {
        if (!towns_list.HasItem(t)) {
            removed_towns.append(t);

            local name = AITown.GetName(t);
            local population = AITown.GetPopulation(t);
            AILog.Info("Removed town: " + name + " (" + population + ")");
        }
    }

    // store new town data
    foreach (t in new_towns) {
        this.towns[t] <- Town(t, false);
        this.towns[t].ScanRegion(this.NetworkRadius);
    }

    // update list
    towns_list.Valuate(AIBase.RandItem);
    towns_list.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);
    towns_list.Valuate(function(_){return 0;});
    this.towns_id = towns_list

    local res = this.towns_id.Next();
    if (this.towns_id.IsEnd()) {
        res = this.towns_id.Begin();
    }

    // for removed town, callback all vehicles and sell them
    foreach (t in removed_towns) {
        local name = AITown.GetName(t);
        AILog.Info("Town: " + name + " sell all vehicles");
        this.towns[t].ManageVehiclesByCategory(
            0, 
            ::Category.MAIL | ::Category.GARBAGE | ::Category.FIRE | ::Category.POLICE | ::Category.AMBULANCE | ::Category.CAR
            0);
    }

    // scan every town
    foreach (t, _ in this.towns) {
        this.towns[t].ScanRegion(this.NetworkRadius);
    }

    return res
}

function CityLife::VerboseTownList()
{
    foreach (t, _ in this.towns) {
        local name = AITown.GetName(t);
        local population = AITown.GetPopulation(t);
        if (this.towns_id.HasItem(t)) {
            AILog.Info("  Service " + name + " (" + population + ")");
        } else {
            AILog.Info("  Inactive " + name + " (" + population + ")");
        }
    }
}

function CityLife::MonthlyManageTowns()
{
    foreach (t, _ in this.towns_id)
    {
        this.towns[t].MonthlyManageTown();
    }
}

function CityLife::ManageTown(town)
{
    town.ManageTown(this.road_type, this.MaxVehiclePerTown);
}

function CityLife::MonthlyManageRoadBuilder(town_id)
{
    if (this.duplicit_ai)
        return;

    this.road_builder.Init(this.towns, town_id, this.road_type);
}

function CityLife::ManageRoadBuilder()
{
    if (this.road_builder.FindPath(this.towns))
    {
        this.road_builder.BuildRoad(this.towns);
        // this.towns[this.road_builder.town_a].Parade(this.towns[this.road_builder.town_b]);
    }
}

function CityLife::SwitchToNewEpoch()
{
    foreach (town_id, town in this.towns) {
        foreach (alt_town_id, status in town.connection_status) {
            if (alt_town_id == town_id) {
                continue;
            }
            town.connection_status[alt_town_id] = false;
        }
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
    save_table.towns_id_list <- [];
    if (!this.ai_init_done)
    {
        save_table.town_data_table <- ::TownDataTable;
        save_table.towns_id_list <- ::TownsIDList;
    }
    else
    {
        save_table.duplicit_ai <- this.duplicit_ai;
        save_table.road_type <- this.road_type;
        foreach (town_id, town in this.towns)
        {
            save_table.town_data_table[town_id] <- town.SaveTownData();
        }
        foreach (t, _ in this.towns_id) {
             save_table.towns_id_list.append(t);
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
        ::TownsIDList <- saved_data.towns_id_list;
        this.duplicit_ai = saved_data.duplicit_ai;
        this.road_type = saved_data.road_type;
    }
    else
    {
        AILog.Info("Data format doesn't match with current version. Resetting.");
    }
}
