/*
 * This file is part of CityLifeAI, an AI for OpenTTD.
 *
 * It's free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the
 * Free Software Foundation, version 2 of the License.
 *
 */

class Town
{
    id = null;                  // Town id
    depot = null;               // Built depo
    directions = null;         // A list with all directions.

    constructor(town_id)
    {
        this.id = town_id;
        this.directions = [1, -1, AIMap.GetMapSizeX(), -AIMap.GetMapSizeX()];
    }
}

function Town::ManageTown()
{
    if (this.depot == null)
    {
        AILog.Info("Trying to build a depot in town " + AITown.GetName(this.id));
        this.depot = this.BuildDepot()
    }
}

function Town::BuildDepot()
{
    local depot_placement_tiles = AITileList();
    local town_location = AITown.GetLocation(this.id);

    // The rectangle corners must be valid tiles
    local corner1 = town_location - AIMap.GetTileIndex(15, 15);
    while(!AIMap.IsValidTile(corner1)) {
        corner1 += AIMap.GetTileIndex(1, 1);
    }

    local corner2 = town_location + AIMap.GetTileIndex(15, 15);
    while(!AIMap.IsValidTile(corner2)) {
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
    while(!depot_placement_tiles.IsEnd()) {
        foreach (direction in directions)
        {
            if (!AIRoad.IsRoadTile(depot_tile + direction)) {
                continue;
            }

            if (AIRoad.CanBuildConnectedRoadPartsHere(depot_tile, depot_tile + direction, depot_tile + direction + 1)) {
                if (AIRoad.BuildRoad(depot_tile, depot_tile + direction) && AIRoad.BuildRoadDepot(depot_tile, depot_tile + direction))
                    return depot_tile;
            }
        }

        AISign.BuildSign(depot_tile, "tile");
        depot_tile = depot_placement_tiles.Next();
    }

    return null;
}