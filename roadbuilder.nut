/*
 * This file is part of CityLifeAI(Custom), an AI for OpenTTD.
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
    roadtype = null;
    path = null;

    Me = null;

    constructor()
    {
        this.pathfinder =  RoadPathFinder();
        this.status = PathfinderStatus.IDLE;

        this.Me = AICompany.ResolveCompanyID(AICompany.COMPANY_SELF);
    }
}

function RoadBuilder::Init(towns, towns_id, roadtype)
{
    if (this.status != PathfinderStatus.IDLE)
        return false;

    if (!this.FindTownsToConnect(towns, towns_id))
        return false;

    this.roadtype = roadtype;
    this.pathfinder.InitializePath([AITown.GetLocation(this.town_a)], [AITown.GetLocation(this.town_b)], true);
    this.pathfinder.SetMaxIterations(5000000);
    this.pathfinder.SetStepSize(100);
    this.status = PathfinderStatus.RUNNING;

    AILog.Info("Planning road between " + AITown.GetName(this.town_a) + " and " + AITown.GetName(this.town_b));
    return true;
}

/*
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
*/

function RoadBuilder::FindTownsToConnect(towns, towns_id)
{
    // random sample in towns
    towns_id.Valuate(AIBase.RandItem);
    local center_town_id = towns_id.Begin();
    local center_town = towns[center_town_id];
    local center_town_pos = AITown.GetLocation(center_town_id);

    // create AIList for connected & not connected towns
    local connected_town_list = AIList();
    local disconnected_town_list = AIList();
    foreach (t, st in center_town.connection_status) {
        if (st) {
            connected_town_list.AddItem(t, 0);
        } else {
            disconnected_town_list.AddItem(t, 0);
        }
    }

    // from disconnect_town_list, choose the nearest to the centertown
    this.town_a == null
    disconnected_town_list.Valuate(AITown.GetDistanceManhattanToTile, center_town_pos);
    disconnected_town_list.Sort(AIList.SORT_BY_VALUE, true);
    local _town_a = disconnected_town_list.Begin();
    if (AITown.IsValidTown(_town_a)) {
        this.town_a = _town_a;
    }
    if (this.town_a == null) {
        return false;
    }

    // from connected_town_list, choose the nearest to the town_a
    this.town_b = null;
    connected_town_list.Valuate(AITown.GetDistanceManhattanToTile, AITown.GetLocation(this.town_a));
    connected_town_list.Sort(AIList.SORT_BY_VALUE, true);
    local _town_b = connected_town_list.Begin();
    local _town_ab_dist = connected_town_list.GetValue(_town_b);
    if (_town_ab_dist <= 240) {
        this.town_b = _town_b;
    }
    if (this.town_b == null) {
        return false;
    }

    return true;
}

function RoadBuilder::FindPath(towns)
{
    if (this.status != PathfinderStatus.RUNNING)
        return false;

    AIRoad.SetCurrentRoadType(this.roadtype);

    this.path = this.pathfinder.FindPath();
    if (this.path == null)
    {
        local pf_err = this.pathfinder.GetFindPathError();
        if (pf_err != RoadPathFinder.PATH_FIND_NO_ERROR)
        {
            AILog.Info("Path between " + AITown.GetName(this.town_a) + " and " + AITown.GetName(this.town_b) + " failed " + pf_err);
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
                    local path_t = this.path.GetTile();
                    local t = par.GetTile();
                    if (AIRoad.IsRoadTile(t) && AITile.GetOwner(t) == this.Me) {
                        // Upgrade road
                        local result = false;
                        while (!result) {
                            result = AIRoad.ConvertRoadType(path_t, t, AIRoad.GetCurrentRoadType());
                            if (AIError.GetLastError() != AIError.ERR_VEHICLE_IN_THE_WAY)
                                break;
                        }
                        if (!result && !AIError.GetLastError() == AIRoad.ERR_UNSUITABLE_ROAD) {
                            AILog.Info("Upgrade road error: " + AIError.GetLastErrorString());
                        }
                    } else {
                        // Build road
                        local result = false;
                        while (!result)
                        {
                            result = AIRoad.BuildRoad(path_t, t);
                            if (AIError.GetLastError() != AIError.ERR_VEHICLE_IN_THE_WAY)
                                break;
                        }

                        if (!result && !AIError.GetLastError() == AIError.ERR_ALREADY_BUILT) {
                            AILog.Info("Build road error: " + AIError.GetLastErrorString());
                            AIController.Break("debug")
                        }
                    }
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
                        local bridge_length_request = AIMap.DistanceManhattan(this.path.GetTile(), par.GetTile()) +1
                        local bridge_list = GetBridgeType(bridge_length_request);

                        // select random bridge
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
}


function GetRoadType()
{
    local ignore_road_table = {}
    ignore_road_table["ISR Style paved driveway"] <- 0;
    ignore_road_table["CHIPS Style asphalt driveway"] <- 0;
    ignore_road_table["CHIPS Style cobble driveway"] <- 0;
    ignore_road_table["CHIPS Style mud driveway"] <- 0;
    ignore_road_table["Paving slabs"] <- 0;
    ignore_road_table["Urban asphalt road"] <- 0;
    ignore_road_table["Urban asphalt road w/ stripes"] <- 0;
    ignore_road_table["Road Verge"] <- 0;
    ignore_road_table["Cobble stones road"] <- 0;
    ignore_road_table["ISR road"] <- 0;
    ignore_road_table["Cement slab of road"] <- 0;
    ignore_road_table["Asphalt concrete road"] <- 0;
    local dummy = AITestMode();

    // Filter out the road not desired
    local _road_types = AIRoadTypeList(AIRoad.ROADTRAMTYPES_ROAD);
    local road_types = AIList();
    foreach (r, _ in _road_types) {
        if ("IsCatenaryRoadType" in AIRoad) {
            if (AIRoad.IsCatenaryRoadType(r)) {
                continue;
            }
        }

        if (AIRoad.GetName(r) in ignore_road_table) {
            continue;
        }

        road_types.AddItem(r, 0);
    }

    // Check if the road type at the location is usable
    /* foreach (road, _ in road_types)
    {
        if (!AIRoad.ConvertRoadType(location, location, road) && AIError.GetLastError() == AIRoad.ERR_UNSUITABLE_ROAD)
            return road;
    }*/

    // Get the default road for an engine type and check if it is available to the AI
    local engine = ::EngineList.Begin();
    /* if (AIRoad.IsRoadTypeAvailable(AIEngine.GetRoadType(engine)))
        return AIEngine.GetRoadType(engine); */

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
        compatible_road_types.Valuate(AIRoad.GetMaxSpeed);

        // check max road speed
        local max_road_speed = 0;
        local candidate_list = AIList();
        foreach (r, speed in compatible_road_types) {
            if (speed > max_road_speed) {
                max_road_speed = speed;
            }
        }

        // collect
        foreach (r, speed in compatible_road_types) {
            if (speed == 0 || speed == max_road_speed) {
                candidate_list.AddItem(r, 0);
            }
        }
        candidate_list.Valuate(AIRoad.GetBuildCost, AIRoad.BT_ROAD);
        candidate_list.Sort(AIList.SORT_BY_VALUE, AIList.SORT_ASCENDING);
        return candidate_list.Begin();
    }

    // No compatible road type, clear engine list so that all town operations are disabled for a year
    AILog.Error("No compatible road type to build, will retry in a year.");
    ::EngineList.Clear();

    return null;
}

function GetBridgeType(length)
{
    local bridge_list = AIBridgeList_Length(length);

    // filter out undesired bridges

    // speed filter bridge
    bridge_list.Valuate(AIBridge.GetMaxSpeed);

    local has_fast_speed_bridge = false;
    foreach (b, speed in bridge_list) {
        if (speed > 100) {
            has_fast_speed_bridge = true;
            break;
        }
    }
    if (has_fast_speed_bridge) {
        bridge_list.KeepAboveValue(100);
    }
    return bridge_list
}

function BuildDepot(town_id)
{
    local depot_placement_tiles = AITileList();
    local town_location = AITown.GetLocation(town_id);

    // The rectangle corners must be valid tiles
    local corner1 = town_location - AIMap.GetTileIndex(25, 25);
    while(!AIMap.IsValidTile(corner1) || AIMap.DistanceManhattan(corner1, town_location) > 50) {
        corner1 += AIMap.GetTileIndex(1, 1);
    }

    local corner2 = town_location + AIMap.GetTileIndex(25, 25);
    while(!AIMap.IsValidTile(corner2) || AIMap.DistanceManhattan(corner2, town_location) > 50) {
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
                        || AIError.GetLastError() == AIError.ERR_VEHICLE_IN_THE_WAY
                        || AIError.GetLastError() == AITunnel.ERR_TUNNEL_CANNOT_BUILD_ON_WATER))
                {
                    AILog.Warning("Build road :: Tile " + depot_tile + ": " + AIError.GetLastErrorString());
                    // AISign.BuildSign(depot_tile, "tilexx");
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