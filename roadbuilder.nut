/*
 * This file is part of CityLifeAI, an AI for OpenTTD.
 *
 * It's free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the
 * Free Software Foundation, version 2 of the License.
 *
 */

enum PathfinderStatus {
    IDLE,
    RUNNING,
    FINISHED
};

class RoadBuilder
{
    status = null;
    pathfinder = null;
    town_a = null;
    town_b = null;
    road_type = null;
    path = null;

    constructor()
    {
        this.pathfinder =  RoadPathFinder();
        this.status = PathfinderStatus.IDLE;
    }
}

function RoadBuilder::Init(towns)
{
    if (this.status != PathfinderStatus.IDLE)
        return false;

    if (!this.FindTownsToConnect(towns))
        return false;

    this.road_type = this.FindFastestRoadType();

    this.pathfinder.InitializePath([AITown.GetLocation(this.town_a)], [AITown.GetLocation(this.town_b)], true);
    this.pathfinder.SetMaxIterations(500000);
    this.pathfinder.SetStepSize(100);
    this.status = PathfinderStatus.RUNNING;

    AILog.Info("Planning road between " + AITown.GetName(this.town_a) + " and " + AITown.GetName(this.town_b));
    return true;
}

function RoadBuilder::FindFastestRoadType()
{
    local road_types = AIRoadTypeList(AIRoad.ROADTRAMTYPES_ROAD);
    road_types.Valuate(AIRoad.GetMaxSpeed);

    road_types.Sort(AIList.SORT_BY_VALUE, true); // Check for compatible speed unlimited road
    local engine = ::EngineList.Begin();
    foreach (road, speed in road_types)
    {
        if (speed > 0)
            break;
        else if (AIEngine.CanRunOnRoad(engine, road))
            return road;
    }

    road_types.Sort(AIList.SORT_BY_VALUE, false); // Pick fastest compatible speed limited road
    foreach (road, _ in road_types) {
        if (AIEngine.CanRunOnRoad(engine, road))
            return road;
    }

    return road_types.Begin();
}

function RoadBuilder::FindTownsToConnect(towns)
{
    local town_list = AITownList();
    town_list.Valuate(AITown.GetPopulation);
    town_list.Sort(AIList.SORT_BY_VALUE, false);

    this.town_a = null;
    foreach (town_id, population in town_list)
    {
        if (towns[town_id].connections.len() < 5 && population / 2000 > towns[town_id].connections.len())
        {
            this.town_a = town_id;
            town_list.RemoveItem(town_id);
            break;
        }
    }

    if (this.town_a == null || towns[this.town_a].depot == null)
        return false;

    town_list.Valuate(AITown.GetDistanceManhattanToTile, AITown.GetLocation(this.town_a));
    town_list.Sort(AIList.SORT_BY_VALUE, true);

    this.town_b = null;
    foreach (town_id, distance in town_list)
    {
        if (distance < 100 && towns[town_id].connections.len() <= towns[this.town_a].connections.len())
        {
            local connection_exists = false;
            foreach (connection in towns[this.town_a].connections)
            {
                if (connection == town_id)
                {
                    connection_exists = true;
                    break;
                }
            }

            if (!connection_exists)
            {
                this.town_b = town_id;
                break;
            }
        }
    }

    if (towns[this.town_a].depot == null)
        return false;

    if (this.town_b == null) {
        towns[this.town_a].connections.append(-1); // No available town to connect to, increase the connections
        return false;
    }

    return true;
}

function RoadBuilder::FindPath(towns)
{
    if (this.status != PathfinderStatus.RUNNING)
        return false;

    AIRoad.SetCurrentRoadType(this.road_type);

    this.path = this.pathfinder.FindPath();
    if (this.path == null)
    {
        local pf_err = this.pathfinder.GetFindPathError();
        if (pf_err != RoadPathFinder.PATH_FIND_NO_ERROR)
        {
            AILog.Info("Path between " + AITown.GetName(this.town_a) + " and " + AITown.GetName(this.town_b) + " failed " + pf_err);
            towns[this.town_a].connections.append(this.town_b);
            towns[this.town_b].connections.append(this.town_a);
            this.status = PathfinderStatus.IDLE;
        }
        return false;
    }

    return true;
}

function RoadBuilder::BuildRoad(towns)
{
    while (this.path != null) {
		local par = this.path.GetParent();

		if (par != null) {
			local last_node = this.path.GetTile();

			if (AIMap.DistanceManhattan(this.path.GetTile(), par.GetTile()) == 1 )
            {
				if (AIRoad.AreRoadTilesConnected(this.path.GetTile(), par.GetTile()))
                {
					if (AITile.HasTransportType(par.GetTile(), AITile.TRANSPORT_RAIL))
					{
						local bridge_result = SuperLib.Road.ConvertRailCrossingToBridge(par.GetTile(), this.path.GetTile());
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
					local straight_begin = this.path;
					local straight_end = par;

                    local prev = straight_end.GetParent();
                    while(prev != null &&
                            SuperLib.Tile.IsStraight(straight_begin.GetTile(), prev.GetTile()) &&
                            AIMap.DistanceManhattan(straight_end.GetTile(), prev.GetTile()) == 1)
                    {
                        straight_end = prev;
                        prev = straight_end.GetParent();
                    }

                    /* update the looping vars. (this.path is set to par in the end of the main loop) */
                    par = straight_end;

					// Build road
                    local result = false;
                    while (!result)
                    {
                        result = AIRoad.BuildRoad(straight_begin.GetTile(), straight_end.GetTile());
                        if (AIError.GetLastError() != AIError.ERR_VEHICLE_IN_THE_WAY)
                            break;
                    }

                    if (!result && !AIError.GetLastError() == AIError.ERR_ALREADY_BUILT)
                        AILog.Info("Build road error: " + AIError.GetLastErrorString());
				}
			} else {
				if (AIBridge.IsBridgeTile(this.path.GetTile())) {
					/* A bridge exists */

					// Check if it is a bridge with low speed
					local bridge_type_id = AIBridge.GetBridgeID(this.path.GetTile())
					local bridge_max_speed = AIBridge.GetMaxSpeed(bridge_type_id);

					if(bridge_max_speed < 100) // low speed bridge
					{
						local other_end_tile = AIBridge.GetOtherBridgeEnd(this.path.GetTile());
						local bridge_length = AIMap.DistanceManhattan( this.path.GetTile(), other_end_tile ) + 1;
						local bridge_list = AIBridgeList_Length(bridge_length);

						bridge_list.Valuate(AIBridge.GetMaxSpeed);
						bridge_list.KeepAboveValue(bridge_max_speed);

						if(!bridge_list.IsEmpty())
						{
							// Pick a random faster bridge than the current one
							bridge_list.Valuate(AIBase.RandItem);
							bridge_list.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);

							// Upgrade the bridge
                            local result = false;
                            while (!result)
                            {
                                result = AIBridge.BuildBridge( AIVehicle.VT_ROAD, bridge_list.Begin(), this.path.GetTile(), other_end_tile );
                                if (AIError.GetLastError() != AIError.ERR_VEHICLE_IN_THE_WAY)
                                    break;
                            }

                            if (!result && !AIError.GetLastError() == AIError.ERR_ALREADY_BUILT)
							    AILog.Info("Upgrade bridge error: " + AIError.GetLastErrorString());
						}
					}

				} else if(AITunnel.IsTunnelTile(this.path.GetTile())) {
					/* A tunnel exists */

					// All tunnels have equal speed so nothing to do
				} else {
					/* Build a bridge or tunnel. */

					/* If it was a road tile, demolish it first. Do this to work around expended roadbits. */
					if (AIRoad.IsRoadTile(this.path.GetTile()) &&
							!AIRoad.IsRoadStationTile(this.path.GetTile()) &&
							!AIRoad.IsRoadDepotTile(this.path.GetTile())) {
						AITile.DemolishTile(this.path.GetTile());
					}
					if (AITunnel.GetOtherTunnelEnd(this.path.GetTile()) == par.GetTile()) {

						local result = AITunnel.BuildTunnel(AIVehicle.VT_ROAD, this.path.GetTile());
						if (!result && !AIError.GetLastError() == AIError.ERR_ALREADY_BUILT) {
                            AILog.Info("Build tunnel error: " + AIError.GetLastErrorString());
						}
					} else {
						local bridge_list = AIBridgeList_Length(AIMap.DistanceManhattan(this.path.GetTile(), par.GetTile()) +1);
						bridge_list.Valuate(AIBridge.GetMaxSpeed);
                        bridge_list.KeepAboveValue(100);

                        bridge_list.Valuate(AIBase.RandItem);
                        bridge_list.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);

                        local result = false;
                        while (!result)
                        {
                            result = AIBridge.BuildBridge(AIVehicle.VT_ROAD, bridge_list.Begin(), this.path.GetTile(), par.GetTile());
                            if (AIError.GetLastError() != AIError.ERR_VEHICLE_IN_THE_WAY)
                                break;
                        }

                        if (!result && !AIError.GetLastError() == AIError.ERR_ALREADY_BUILT)
                            AILog.Info("Build bridge error: " + AIError.GetLastErrorString());
					}
				}
			}
		}
		this.path = par;
	}

    this.status = PathfinderStatus.IDLE;
    AILog.Info("Path between " + AITown.GetName(this.town_a) + " and " + AITown.GetName(this.town_b) + " built");
    towns[this.town_a].connections.append(this.town_b);
    towns[this.town_b].connections.append(this.town_a);
}

function GetRoadType(location)
{
    local road_types = AIRoadTypeList(AIRoad.ROADTRAMTYPES_ROAD);
    local dummy = AITestMode();

    // Check if the road type at the location is usable
    foreach (road, _ in road_types)
    {
        if (!AIRoad.ConvertRoadType(location, location, road) && AIError.GetLastError() == AIRoad.ERR_UNSUITABLE_ROAD)
            return road;
    }

    // Get the default road for an engine type and check if it is available to the AI
    local engine = ::EngineList.Begin();
    if (AIRoad.IsRoadTypeAvailable(AIEngine.GetRoadType(engine)))
        return AIEngine.GetRoadType(engine);

    // Filter roads to only those that are compatible to an engine and randomly chose one
    local compatible_road_types = AIList();
    foreach (road, _ in road_types)
    {
        if (AIEngine.CanRunOnRoad(engine, road))
            compatible_road_types.AddItem(road, 0);
    }

    if (compatible_road_types.Count() == 1)
        return compatible_road_types.Begin();
    else if (compatible_road_types.Count() > 1)
    {
        compatible_road_types.Valuate(AIBase.RandItem);
        compatible_road_types.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);
        return compatible_road_types.Begin();
    }

    // No compatible road type, clear engine list so that all town operations are disabled for a year
    AILog.Error("No compatible road type to build, will retry in a year.");
    ::EngineList.Clear();

    return null;
}

function BuildDepot(town_id)
{
    local depot_placement_tiles = AITileList();
    local town_location = AITown.GetLocation(town_id);

    local road_type = GetRoadType(town_location);
    if (road_type == null) {
        AILog.Warning(AITown.GetName(town_id) + ": Could not detect town road type");
        return null;
    }
    AIRoad.SetCurrentRoadType(road_type);

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
    local directions = [1, -1, AIMap.GetMapSizeX(), -AIMap.GetMapSizeX()];
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
                        || AIError.GetLastError() == AIRoad.ERR_ROAD_ONE_WAY_ROADS_CANNOT_HAVE_JUNCTIONS
                        || AIError.GetLastError() == AIRoad.ERR_ROAD_WORKS_IN_PROGRESS
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