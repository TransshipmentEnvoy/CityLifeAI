/*
 * This file is part of SuperLib.Helper, which is an AI Library for OpenTTD
 * Copyright (C) 2011  Leif Linse
 *
 * SuperLib.Helper is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 2 of the License
 *
 * SuperLib.Helper is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with SuperLib.Helper; If not, see <http://www.gnu.org/licenses/> or
 * write to the Free Software Foundation, Inc., 51 Franklin Street,
 * Fifth Floor, Boston, MA 02110-1301 USA.
 *
 */

// import("pathfinder.road", "RoadPathFinder_private", 4);
require("pathfinder/road.nut");


/*
* PUBLIC API
*
* For the public API, skip down to: class CityLifeAI_RoadPathFinder
*/


/*
* PRIVATE class
*
* Private Custom RPF for building new road or repairing existing road
*/

class _CityLifeAI_RoadPathFinder_private_CustomRPF extends RoadPathFinder_private
{
    forbidden_tiles = null;
    estimate_multiplier = null;

    constructor()
    {
        ::RoadPathFinder_private.constructor();

        this.forbidden_tiles = [];
        this.estimate_multiplier = 1;
    }

}
function _CityLifeAI_RoadPathFinder_private_CustomRPF::InitializePath(sources, goals)
{
    ::RoadPathFinder_private.InitializePath(sources, goals);
}

function _CityLifeAI_RoadPathFinder_private_CustomRPF::SetForbiddenTiles(squirrel_tile_array)
{
    this.forbidden_tiles = squirrel_tile_array;
}

function _CityLifeAI_RoadPathFinder_private_CustomRPF::SetEstimateMultiplier(estimate_multiplier)
{
    this.estimate_multiplier = estimate_multiplier;
}

function _CityLifeAI_RoadPathFinder_private_CustomRPF::_Cost(self, path, new_tile, new_direction)
{
    local cost = ::RoadPathFinder_private._Cost(self, path, new_tile, new_direction);
    local M = 10000;

    // Penalty for crossing railways without bridge
    if(AITile.HasTransportType(new_tile, AITile.TRANSPORT_RAIL)) cost += 800;

    // Add big M penalty if the tile is forbidden
    foreach(forbidden_tile in self.forbidden_tiles)
    {
        if(forbidden_tile == new_tile)
        {
            cost += M;
        }
    }

    // Try to build around drive through stops
    if(AIRoad.IsDriveThroughRoadStationTile(new_tile)) cost += 1000;

    if(path != null)
    {
        // Path is null on first node
        local prev_tile = path.GetTile();

        // If it is possible to reach the current tile from next tile but not in the other direction, then it is a one-way road
        // in the wrong direction.
        if(AIRoad.AreRoadTilesConnected(new_tile, prev_tile) && !AIRoad.AreRoadTilesConnected(prev_tile, new_tile))
        {
            // Don't try to use one-way roads from the back
            _SuperLib_Log.Info("One-way road detected", _SuperLib_Log.LVL_DEBUG);
            cost += M;
        }
    }

    return cost;
}

function _CityLifeAI_RoadPathFinder_private_CustomRPF::_Neighbours(self, path, cur_node)
{
    local tiles = ::RoadPathFinder_private._Neighbours(self, path, cur_node);

    if (path.GetParent() == null || AIMap.DistanceManhattan(cur_node, path.GetParent().GetTile()) == 1) {
        // make sure this is not a bridge end / tunnel end

        local offsets = []
        if (path.GetParent() == null) {
            offsets = [AIMap.GetTileIndex(0, 1), AIMap.GetTileIndex(0, -1),
                            AIMap.GetTileIndex(1, 0), AIMap.GetTileIndex(-1, 0)];
        } else {
            offsets = [cur_node - path.GetParent().GetTile()];
        }
        /* Check all tiles adjacent to the current tile. */
        foreach(offset in offsets)
        {
            //local next_tile = cur_node + offset;
            local cur_height = AITile.GetMaxHeight(cur_node);
            if(AITile.GetSlope(cur_node) != AITile.SLOPE_FLAT) continue;

            local bridge_length = 2;
            local i_tile = cur_node + offset;

            while(AITile.HasTransportType(i_tile, AITile.TRANSPORT_RAIL) || 
                AITile.HasTransportType(i_tile, AITile.TRANSPORT_WATER)) // try to bridge over rail or flat water (rivers/canals)
            {
                i_tile += offset;
                bridge_length++;
            }

            if(bridge_length <= 2) continue; // Nothing to bridge over
            if(!_SuperLib_Tile.IsStraight(cur_node, i_tile)) continue; // Detect map warp-arounds

            local bridge_list = AIBridgeList_Length(bridge_length);
            if(bridge_list.IsEmpty() || !AIBridge.BuildBridge(AIVehicle.VT_ROAD, bridge_list.Begin(), cur_node, i_tile)) {
                continue; // not possible to build bridge here
            }

            // Found possible bridge over rail
            tiles.push([i_tile, self._GetDirection(cur_node, cur_node+offset, true) << 4]);
        }
    }

    return tiles;
}

function _CityLifeAI_RoadPathFinder_private_CustomRPF::_Estimate(self, cur_tile, cur_direction, goal_tiles)
{
    local min_cost = ::RoadPathFinder_private._Estimate(self, cur_tile, cur_direction, goal_tiles);
    return (min_cost * self.estimate_multiplier).tointeger();
}

/*
* PRIVATE class
*
* Private Custom RPF for checking connectivity without allowing any construction
*/

class _CityLifeAI_RoadPathFinder_private_CustomRPF_NoBuild extends _CityLifeAI_RoadPathFinder_private_CustomRPF
{
    forbidden_tiles = null;
    estimate_multiplier = null;

    constructor()
    {
        ::RoadPathFinder_private.constructor();

        this.forbidden_tiles = [];
        this.estimate_multiplier = 1;
    }

}
/*function _CityLifeAI_RoadPathFinder_private_CustomRPF_NoBuild::InitializePath(sources, goals)
{
    ::RoadPathFinder_private.InitializePath(sources, goals);
}

function _CityLifeAI_RoadPathFinder_private_CustomRPF_NoBuild::SetForbiddenTiles(squirrel_tile_array)
{
    this.forbidden_tiles = squirrel_tile_array;
}

function _CityLifeAI_RoadPathFinder_private_CustomRPF_NoBuild::SetEstimateMultiplier(estimate_multiplier)
{
    this.estimate_multiplier = estimate_multiplier;
}
*/

function _CityLifeAI_RoadPathFinder_private_CustomRPF_NoBuild::_Cost(self, path, new_tile, new_direction)
{
    return ::RoadPathFinder_private._Cost(self, path, new_tile, new_direction);
}

function _CityLifeAI_RoadPathFinder_private_CustomRPF_NoBuild::_Neighbours(self, path, cur_node)
{
    // This is a modification of the default function body with some parts commented out.
    // This version will not consider neighbours that require building new road.

    /* self._max_cost is the maximum path cost, if we go over it, the path isn't valid. */
    if (path.GetCost() >= self._max_cost) return [];
    local tiles = [];

    /* Check if the current tile is part of a bridge or tunnel. */
    if ((AIBridge.IsBridgeTile(cur_node) || AITunnel.IsTunnelTile(cur_node)) &&
        AITile.HasTransportType(cur_node, AITile.TRANSPORT_ROAD)) {
        local other_end = AIBridge.IsBridgeTile(cur_node) ? AIBridge.GetOtherBridgeEnd(cur_node) : AITunnel.GetOtherTunnelEnd(cur_node);
        local next_tile = cur_node + (cur_node - other_end) / AIMap.DistanceManhattan(cur_node, other_end);
        if (AIRoad.AreRoadTilesConnected(cur_node, next_tile) /*|| AITile.IsBuildable(next_tile) || AIRoad.IsRoadTile(next_tile)*/) {
            tiles.push([next_tile, self._GetDirection(cur_node, next_tile, false)]);
        }
        /* The other end of the bridge / tunnel is a neighbour. */
        tiles.push([other_end, self._GetDirection(next_tile, cur_node, true) << 4]);
    } else if (path.GetParent() != null && AIMap.DistanceManhattan(cur_node, path.GetParent().GetTile()) > 1) {
        local other_end = path.GetParent().GetTile();
        local next_tile = cur_node + (cur_node - other_end) / AIMap.DistanceManhattan(cur_node, other_end);
        if (AIRoad.AreRoadTilesConnected(cur_node, next_tile) /*|| AIRoad.BuildRoad(cur_node, next_tile)*/) {
            tiles.push([next_tile, self._GetDirection(cur_node, next_tile, false)]);
        }
    } else {
        local offsets = [AIMap.GetTileIndex(0, 1), AIMap.GetTileIndex(0, -1),
                        AIMap.GetTileIndex(1, 0), AIMap.GetTileIndex(-1, 0)];
        /* Check all tiles adjacent to the current tile. */
        foreach (offset in offsets) {
            local next_tile = cur_node + offset;
            /* We add them to the to the neighbours-list if one of the following applies:
            * 1) There already is a connections between the current tile and the next tile.
            * 2) We can build a road to the next tile.
            * 3) The next tile is the entrance of a tunnel / bridge in the correct direction. */
            if (AIRoad.AreRoadTilesConnected(cur_node, next_tile)) {
                tiles.push([next_tile, self._GetDirection(cur_node, next_tile, false)]);
            } /*else if ((AITile.IsBuildable(next_tile) || AIRoad.IsRoadTile(next_tile)) &&
                    (path.GetParent() == null || AIRoad.CanBuildConnectedRoadPartsHere(cur_node, path.GetParent().GetTile(), next_tile)) &&
                    AIRoad.BuildRoad(cur_node, next_tile)) {
                tiles.push([next_tile, self._GetDirection(cur_node, next_tile, false)]);
            }*/ else if (self._CheckTunnelBridge(cur_node, next_tile)) {
                tiles.push([next_tile, self._GetDirection(cur_node, next_tile, false)]);
            }
        }
        /* Do not consider building of bridges
        if (path.GetParent() != null) {
            local bridges = self._GetTunnelsBridges(path.GetParent().GetTile(), cur_node, self._GetDirection(path.GetParent().GetTile(), cur_node, true) << 4);
            foreach (tile in bridges) {
                tiles.push(tile);
            }
        }*/
    }

    return tiles;
}

function _CityLifeAI_RoadPathFinder_private_CustomRPF_NoBuild::_Estimate(self, cur_tile, cur_direction, goal_tiles)
{
    local min_cost = ::RoadPathFinder_private._Estimate(self, cur_tile, cur_direction, goal_tiles);
    return (min_cost * self.estimate_multiplier).tointeger();
}


//
// Actual API class
//

class CityLifeAI_RoadPathFinder
{
    _pf = null;

    max_iterations = null;
    accumulated_iterations = null;
    step_size = null;
    find_path_error_code = null;

    // Error codes for GetFindPathError
    static PATH_FIND_NO_ERROR = 0; // No error has occured. Keep calling FindPath.
    static PATH_FIND_FAILED_NO_PATH = 1;
    static PATH_FIND_FAILED_TIME_OUT = 2;

    constructor(no_build = false)
    {
        if(!no_build)
            this._pf = _CityLifeAI_RoadPathFinder_private_CustomRPF();
        else
            this._pf = _CityLifeAI_RoadPathFinder_private_CustomRPF_NoBuild();
    }

    /*
    * - repair_existing = if true, use a much higher cost to build new road than for usual path finding.
    */
    function InitializePath(sources, goals, repair_existing = false, forbidden_tiles = [], estimate_multiplier = 1);

    /*
    * How many iterations should at maximum be executed by PathFind in total over several calls to
    * PathFind before it will report that no path can be found?
    * If set to null, the pf will not abort due to running out of iterations.
    */
    function SetMaxIterations(max_iterations);

    /*
    * How many iterations should be executed by each call to PathFind if no argument is given
    */
    function SetStepSize(step_size);

    /*
    * If num_iterations == null is used, SetStepSize must have been called previously to set
    * the number of iterations to use.
    *
    * Returns null if either the base class FindPath returns null (no path) or it runs out of iterations.
    * Use GetFindPathError to check what the actual error was.
    * Returns non-null when path has been found.
    */
    function FindPath(num_iterations = null);
    function GetFindPathError();

    /*
    * Returns the current amount of iterations that has been used since InitializePath
    */
    function GetIterationsUsed();
}

// It is safe to pass a float value to estimate_multiplier. The result after multiplying the result of _Estimate
// with estimate_multiplier will be casted to an integer.
function CityLifeAI_RoadPathFinder::InitializePath(sources, goals, repair_existing = false, forbidden_tiles = [], estimate_multiplier = 1)
{
    this._pf.InitializePath(sources, goals);
    this._pf.SetForbiddenTiles(forbidden_tiles);
    this._pf.SetEstimateMultiplier(estimate_multiplier);

    // Set SuperLib defaults
    this._pf.cost.no_existing_road = repair_existing? 300 : 40; // default = 40
    this._pf.cost.tile = 80; // default = 100
    this._pf.cost.max_bridge_length = 10; // default = 10
    this._pf.cost.max_tunnel_length = 8;
    this._pf.cost.turn = 20;
    this._pf.cost.slope = 250;
    this._pf.cost.bridge_per_tile = 350; //150;
    this._pf.cost.tunnel_per_tile = 320; //120;

    // Set maximum cost as some constant plus a factor times the cost of the optimal path to avoid to long detours
    // factor = 5/2 aka 2,5
    // this._pf.cost.max_cost = 100000 + (this._pf.cost.tile * AIMap.DistanceManhattan(sources[0], goals[0]) * 50) + this._pf.cost.turn * 20;
    // AILog.Info("max cost: " + this._pf.cost.max_cost);

    this.max_iterations = null;
    this.step_size = null;
    this.accumulated_iterations = 0;
    this.find_path_error_code = CityLifeAI_RoadPathFinder.PATH_FIND_NO_ERROR;

    // Defalut params
    this.SetStepSize(100);
}

function CityLifeAI_RoadPathFinder::SetMaxIterations(max_iterations)
{
    this.max_iterations = max_iterations;
}

function CityLifeAI_RoadPathFinder::SetStepSize(step_size)
{
    this.step_size = step_size;
}

function CityLifeAI_RoadPathFinder::FindPath(num_iterations = null)
{
    local num_iterations_to_run = num_iterations;
    if(num_iterations_to_run == null)
    {
        num_iterations_to_run = this.step_size;
    }

    // Reduce number of iterations to run if we would run more iterations than maximum allowed
    if(this.max_iterations != null && this.accumulated_iterations + num_iterations_to_run > this.max_iterations)
    {
        num_iterations_to_run = this.max_iterations - this.accumulated_iterations;
    }

    if(num_iterations_to_run <= 0)
    {
        // No path found (within time)
        _SuperLib_Log.Info("SuperLib: Finding path took to long -> abort", _SuperLib_Log.LVL_SUB_DECISIONS);
        //_SuperLib_Log.Info("SuperLib: Finding path took to long -> abort - used " + this.accumulated_iterations + " of max " + this.max_iterations, _SuperLib_Log.LVL_SUB_DECISIONS);
        // cancel pf
        this._pf._pathfinder._CleanPath();
        this._pf._running = false;
        this.find_path_error_code = CityLifeAI_RoadPathFinder.PATH_FIND_FAILED_TIME_OUT;
        return null;
    }

    //_SuperLib_Log.Info("SuperLib: used " + this.accumulated_iterations + " of max " + this.max_iterations + ". Run " + num_iterations_to_run + " more loops", _SuperLib_Log.LVL_SUB_DECISIONS);

    // Run FindPath in base class
    local result = this._pf.FindPath(num_iterations_to_run);
    this.accumulated_iterations += num_iterations_to_run;
    if(result == false) {
        // On underlying _pf timeout, report PATH_FIND_NO_ERROR
        // It's only when our this.accumulated_iterations exceed this.max_iterations
        // that we shall report timeout.
        this.find_path_error_code = CityLifeAI_RoadPathFinder.PATH_FIND_NO_ERROR;
        return null;
    } else if (result == null) {
        this.find_path_error_code = CityLifeAI_RoadPathFinder.PATH_FIND_FAILED_NO_PATH;
    }

    return result;
}

function CityLifeAI_RoadPathFinder::GetFindPathError()
{
    return this.find_path_error_code;
}

function CityLifeAI_RoadPathFinder::GetIterationsUsed()
{
    return this.accumulated_iterations;
}
