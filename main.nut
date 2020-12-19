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
import("util.superlib", "SuperLib", 40);

RoadPathFinder <- SuperLib.RoadPathFinder;

enum PathfinderStatus {
    IDLE,
    RUNNING,
    FINISHED
};

class CityLife extends AIController
{
    load_saved_data = null;
    current_save_version = null;
    ai_init_done = null;
    current_date = null;
	current_month = null;
	current_year = null;
    toy_lib = null;
    towns = null;
    road_pathfinder = null;

    constructor() 
    {
        this.load_saved_data = false;
        this.current_save_version = SELF_VERSION;
        this.ai_init_done = false;
        this.current_date = 0;
        this.current_month = 0;
        this.current_year = 0;
        this.road_pathfinder = {pathfinder =  RoadPathFinder(),
                                status = PathfinderStatus.IDLE,
                                town_a = null,
                                town_b = null,
                                road_type = null};
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
            this.AskForMoney();

            this.current_month = month;
        }

        // Run the yearly functions
        local year = AIDate.GetYear(date);
        if (year - this.current_year != 0) 
        {
            AILog.Info("Yearly Update");

            CreateEngineList();
            this.YearlyManageRoadConstruction();

            this.current_year = year
        }

        this.HandleEvents();
        this.ManageTown(this.towns[town_index++]);
        town_index = town_index >= this.towns.len() ? 0 : town_index;
        this.ManageRoadPathfinder();
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

function CityLife::YearlyManageRoadConstruction()
{
    if (this.road_pathfinder.status != PathfinderStatus.IDLE)
    {
        return;
    }

    local town_list = AITownList();
    town_list.Valuate(AITown.GetPopulation);
    town_list.Sort(AIList.SORT_BY_VALUE, false);

    local town_a = null;
    foreach (town_id, population in town_list)
    {
        if (this.towns[town_id].connections.len() < 5 && population / 2000 > this.towns[town_id].connections.len())
        {
            town_a = town_id;
            town_list.RemoveItem(town_id);
            break;
        }
    }

    if (town_a == null)
        return;

    town_list.Valuate(AITown.GetDistanceManhattanToTile, AITown.GetLocation(town_a));
    town_list.Sort(AIList.SORT_BY_VALUE, true);

    local town_b = null;
    foreach (town_id, distance in town_list)
    {
        if (distance < 100 && this.towns[town_id].connections.len() <= this.towns[town_a].connections.len())
        {
            local connection_exists = false;
            foreach (connection in this.towns[town_a].connections)
            {
                if (connection == town_id)
                {
                    connection_exists = true;
                    break;
                }
            }

            if (!connection_exists)
            {
                town_b = town_id;
                break;
            }
        }
    }

    if (town_b == null) {
        this.towns[town_a].connections.append(-1); // No available town to connect to, increase the connections
        return;
    }

    this.road_pathfinder.pathfinder.InitializePath([AITown.GetLocation(town_a)], [AITown.GetLocation(town_b)], true);
    this.road_pathfinder.pathfinder.SetMaxIterations(500000);
    this.road_pathfinder.pathfinder.SetStepSize(100);
    this.road_pathfinder.status = PathfinderStatus.RUNNING;
    this.road_pathfinder.town_a = town_a;
    this.road_pathfinder.town_b = town_b;

    local road_types = AIRoadTypeList(AIRoad.ROADTRAMTYPES_ROAD);
    road_types.Valuate(AIRoad.GetMaxSpeed);
    road_types.Sort(AIList.SORT_BY_VALUE, false);
    this.road_pathfinder.road_type = road_types.Begin();

    AILog.Info("Creating path between " + AITown.GetName(town_a) + " and " +  AITown.GetName(town_b));
}

function CityLife::ManageRoadPathfinder()
{
    if (this.road_pathfinder.status != PathfinderStatus.RUNNING)
        return;

    AIRoad.SetCurrentRoadType(this.road_pathfinder.road_type);

    local path = this.road_pathfinder.pathfinder.FindPath();
    if (path == null)
    {
        local pf_err = this.road_pathfinder.pathfinder.GetFindPathError();
        if (pf_err != RoadPathFinder.PATH_FIND_NO_ERROR)
        {
            AILog.Info("Path between " + AITown.GetName(this.road_pathfinder.town_a) + " and " + AITown.GetName(this.road_pathfinder.town_b) + " failed " + pf_err);
            this.towns[this.road_pathfinder.town_a].connections.append(this.road_pathfinder.town_b);
            this.towns[this.road_pathfinder.town_b].connections.append(this.road_pathfinder.town_a);
            this.road_pathfinder.status = PathfinderStatus.IDLE;
        }
        return;
    }

    AILog.Info("Building path between " + AITown.GetName(this.road_pathfinder.town_a) + " and " + AITown.GetName(this.road_pathfinder.town_b));
    while (path != null) {
		local par = path.GetParent();

		if (par != null) {
			local last_node = path.GetTile();

			if (AIMap.DistanceManhattan(path.GetTile(), par.GetTile()) == 1 ) 
            {
				if (AIRoad.AreRoadTilesConnected(path.GetTile(), par.GetTile())) 
                {
					if (AITile.HasTransportType(par.GetTile(), AITile.TRANSPORT_RAIL))
					{
						local bridge_result = SuperLib.Road.ConvertRailCrossingToBridge(par.GetTile(), path.GetTile());
						if (bridge_result.succeeded == true)
						{
							local new_par = par;
							while (new_par != null && new_par.GetTile() != bridge_result.bridge_start && new_par.GetTile() != bridge_result.bridge_end)
							{
								new_par = new_par.GetParent();
							}
							
							par = new_par;
						}
						else
						{
							AILog.Info("Failed to bridge railway crossing");
						}
					}

				} else {

					/* Look for longest straight road and build it as one build command */
					local straight_begin = path;
					local straight_end = par;

                    local prev = straight_end.GetParent();
                    while(prev != null && 
                            SuperLib.Tile.IsStraight(straight_begin.GetTile(), prev.GetTile()) &&
                            AIMap.DistanceManhattan(straight_end.GetTile(), prev.GetTile()) == 1)
                    {
                        straight_end = prev;
                        prev = straight_end.GetParent();
                    }

                    /* update the looping vars. (path is set to par in the end of the main loop) */
                    par = straight_end;

					// Build road
					local result = AIRoad.BuildRoad(straight_begin.GetTile(), straight_end.GetTile());
                    if (!result && !AIError.GetLastError() == AIError.ERR_ALREADY_BUILT)
                        AILog.Info("Build road error: " + AIError.GetLastErrorString());
				}
			} else {
				if (AIBridge.IsBridgeTile(path.GetTile())) {
					/* A bridge exists */

					// Check if it is a bridge with low speed
					local bridge_type_id = AIBridge.GetBridgeID(path.GetTile())
					local bridge_max_speed = AIBridge.GetMaxSpeed(bridge_type_id);

					if(bridge_max_speed < 100) // low speed bridge
					{
						local other_end_tile = AIBridge.GetOtherBridgeEnd(path.GetTile());
						local bridge_length = AIMap.DistanceManhattan( path.GetTile(), other_end_tile ) + 1;
						local bridge_list = AIBridgeList_Length(bridge_length);

						bridge_list.Valuate(AIBridge.GetMaxSpeed);
						bridge_list.KeepAboveValue(bridge_max_speed);

						if(!bridge_list.IsEmpty())
						{
							// Pick a random faster bridge than the current one
							bridge_list.Valuate(AIBase.RandItem);
							bridge_list.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);

							// Upgrade the bridge
							local result = AIBridge.BuildBridge( AIVehicle.VT_ROAD, bridge_list.Begin(), path.GetTile(), other_end_tile );
                            if (!result && !AIError.GetLastError() == AIError.ERR_ALREADY_BUILT)
							    AILog.Info("Upgrade bridge error: " + AIError.GetLastErrorString());
						}
					}

				} else if(AITunnel.IsTunnelTile(path.GetTile())) {
					/* A tunnel exists */
					
					// All tunnels have equal speed so nothing to do
				} else {
					/* Build a bridge or tunnel. */

					/* If it was a road tile, demolish it first. Do this to work around expended roadbits. */
					if (AIRoad.IsRoadTile(path.GetTile()) && 
							!AIRoad.IsRoadStationTile(path.GetTile()) &&
							!AIRoad.IsRoadDepotTile(path.GetTile())) {
						AITile.DemolishTile(path.GetTile());
					}
					if (AITunnel.GetOtherTunnelEnd(path.GetTile()) == par.GetTile()) {

						local result = AITunnel.BuildTunnel(AIVehicle.VT_ROAD, path.GetTile());
						if (!result && !AIError.GetLastError() == AIError.ERR_ALREADY_BUILT) {
                            AILog.Info("Upgrade tunnel error: " + AIError.GetLastErrorString());
						}
					} else {
						local bridge_list = AIBridgeList_Length(AIMap.DistanceManhattan(path.GetTile(), par.GetTile()) +1);
						bridge_list.Valuate(AIBridge.GetMaxSpeed);

						local result = AIBridge.BuildBridge(AIVehicle.VT_ROAD, bridge_list.Begin(), path.GetTile(), par.GetTile());
						if (!result && !AIError.GetLastError() == AIError.ERR_ALREADY_BUILT) {
                            AILog.Info("Upgrade bridge error: " + AIError.GetLastErrorString());
						}
					}
				}
			}
		}
		path = par;
	}

    this.road_pathfinder.status = PathfinderStatus.IDLE;
    AILog.Info("Path between " + AITown.GetName(this.road_pathfinder.town_a) + " and " + AITown.GetName(this.road_pathfinder.town_b) + " built");
    this.towns[this.road_pathfinder.town_a].connections.append(this.road_pathfinder.town_b);
    this.towns[this.road_pathfinder.town_b].connections.append(this.road_pathfinder.town_a);
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
