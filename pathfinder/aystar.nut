/**
 * An AyStar implementation.
 *  It solves graphs by finding the fastest route from one point to the other.
 *
 * Based on Graph.AyStar.6, but using AIPriorityQueue
 */

/**
 * An AyStar implementation.
 *  It solves graphs by finding the fastest route from one point to the other.
 */
class AyStar
{
    _queue_class = AIPriorityQueue;
    _pf_instance = null;
    _cost_callback = null;
    _estimate_callback = null;
    _neighbours_callback = null;
    _check_direction_callback = null;
    _open = null;
    _closed = null;
    _goals = null;

    /**
     * @param pf_instance An instance that'll be used as 'this' for all
     *  the callback functions.
     * @param cost_callback A function that returns the cost of a path. It
     *  should accept four parameters, old_path, new_tile, new_direction and
     *  cost_callback_param. old_path is an instance of AyStar.Path, and
     *  new_node is the new node that is added to that path. It should return
     *  the cost of the path including new_node.
     * @param estimate_callback A function that returns an estimate from a node
     *  to the goal node. It should accept four parameters, tile, direction,
     *  goal_nodes and estimate_callback_param. It should return an estimate to
     *  the cost from the lowest cost between node and any node out of goal_nodes.
     *  Note that this estimate is not allowed to be higher than the real cost
     *  between node and any of goal_nodes. A lower value is fine, however the
     *  closer it is to the real value, the better the performance.
     * @param neighbours_callback A function that returns all neighbouring nodes
     *  from a given node. It should accept three parameters, current_path, node
     *  and neighbours_callback_param. It should return an array containing all
     *  neighbouring nodes, which are an array in the form [tile, direction].
     * @param check_direction_callback A function that returns either false or
     *  true. It should accept four parameters, tile, existing_direction,
     *  new_direction and check_direction_callback_param. It should check
     *  if both directions can go together on a single tile.
     */
    constructor(pf_instance, cost_callback, estimate_callback, neighbours_callback, check_direction_callback)
    {
        if (typeof(pf_instance) != "instance") throw("'pf_instance' has to be an instance.");
        if (typeof(cost_callback) != "function") throw("'cost_callback' has to be a function-pointer.");
        if (typeof(estimate_callback) != "function") throw("'estimate_callback' has to be a function-pointer.");
        if (typeof(neighbours_callback) != "function") throw("'neighbours_callback' has to be a function-pointer.");
        if (typeof(check_direction_callback) != "function") throw("'check_direction_callback' has to be a function-pointer.");

        this._pf_instance = pf_instance;
        this._cost_callback = cost_callback;
        this._estimate_callback = estimate_callback;
        this._neighbours_callback = neighbours_callback;
        this._check_direction_callback = check_direction_callback;
    }

    /**
     * Initialize a path search between sources and goals.
     * @param sources The source nodes. This can an array of either [tile, direction]-pairs or AyStar.Path-instances.
     * @param goals The target tiles. This can be an array of either tiles or [tile, next_tile]-pairs.
     * @param ignored_tiles An array of tiles that cannot occur in the final path.
     */
    function InitializePath(sources, goals, ignored_tiles = []);

    /**
     * Try to find the path as indicated with InitializePath with the lowest cost.
     * @param iterations After how many iterations it should abort for a moment.
     *  This value should either be -1 for infinite, or > 0. Any other value
     *  aborts immediatly and will never find a path.
     * @return A route if one was found, or false if the amount of iterations was
     *  reached, or null if no path was found.
     *  You can call this function over and over as long as it returns false,
     *  which is an indication it is not yet done looking for a route.
     */
    function FindPath(iterations);
};

function AyStar::InitializePath(sources, goals, ignored_tiles = [])
{
    if (typeof(sources) != "array" || sources.len() == 0) throw("sources has be a non-empty array.");
    if (typeof(goals) != "array" || goals.len() == 0) throw("goals has be a non-empty array.");

    this._open = this._queue_class();
    this._closed = AIList();

    foreach (node in sources) {
        if (typeof(node) == "array") {
            if (node[1] <= 0) throw("directional value should never be zero or negative.");

            local new_path = this.Path(null, node[0], node[1], this._cost_callback, this._pf_instance);
            this._open.Insert(new_path, new_path.GetCost() + this._estimate_callback(this._pf_instance, node[0], node[1], goals));
        } else {
            this._open.Insert(node, node.GetCost());
        }
    }

    this._goals = goals;

    foreach (tile in ignored_tiles) {
        this._closed.AddItem(tile, ~0);
    }
}

function AyStar::FindPath(iterations)
{
    if (this._open == null) throw("can't execute over an uninitialized path");

    while (this._open.Count() > 0 && (iterations == -1 || iterations-- > 0)) {
        /* Get the path with the best score so far */
        local path = this._open.Pop();
        local cur_tile = path.GetTile();
        /* Make sure we didn't already passed it */
        if (this._closed.HasItem(cur_tile)) {
            /* If the direction is already on the list, skip this entry */
            if ((this._closed.GetValue(cur_tile) & path.GetDirection()) != 0) continue;

            /* Scan the path for a possible collision */
            local scan_path = path.GetParent();

            local mismatch = false;
            while (scan_path != null) {
                if (scan_path.GetTile() == cur_tile) {
                    if (!this._check_direction_callback(this._pf_instance, cur_tile, scan_path.GetDirection(), path.GetDirection())) {
                        mismatch = true;
                        break;
                    }
                }
                scan_path = scan_path.GetParent();
            }
            if (mismatch) continue;

            /* Add the new direction */
            this._closed.SetValue(cur_tile, this._closed.GetValue(cur_tile) | path.GetDirection());
        } else {
            /* New entry, make sure we don't check it again */
            this._closed.AddItem(cur_tile, path.GetDirection());
        }
        /* Check if we found the end */
        foreach (goal in this._goals) {
            if (typeof(goal) == "array") {
                if (cur_tile == goal[0]) {
                    local neighbours = this._neighbours_callback(this._pf_instance, path, cur_tile);
                    foreach (node in neighbours) {
                        if (node[0] == goal[1]) {
                            this._CleanPath();
                            return path;
                        }
                    }
                    continue;
                }
            } else {
                if (cur_tile == goal) {
                    this._CleanPath();
                    return path;
                }
            }
        }
        /* Scan all neighbours */
        local neighbours = this._neighbours_callback(this._pf_instance, path, cur_tile);
        foreach (node in neighbours) {
            if (node[1] <= 0) throw("directional value should never be zero or negative.");

            if ((this._closed.GetValue(node[0]) & node[1]) != 0) continue;
            /* Calculate the new paths and add them to the open list */
            local new_path = this.Path(path, node[0], node[1], this._cost_callback, this._pf_instance);
            this._open.Insert(new_path, new_path.GetCost() + this._estimate_callback(this._pf_instance, node[0], node[1], this._goals));
        }
    }

    if (this._open.Count() > 0) return false;
    this._CleanPath();
    return null;
}

function AyStar::_CleanPath()
{
    this._closed = null;
    this._open = null;
    this._goals = null;
}

/**
 * The path of the AyStar algorithm.
 *  It is reversed, that is, the first entry is more close to the goal-nodes
 *  than his GetParent(). You can walk this list to find the whole path.
 *  The last entry has a GetParent() of null.
 */
class AyStar.Path
{
    _prev = null;
    _tile = null;
    _direction = null;
    _cost = null;
    _length = null;

    constructor(old_path, new_tile, new_direction, cost_callback, pf_instance)
    {
        this._prev = old_path;
        this._tile = new_tile;
        this._direction = new_direction;
        this._cost = cost_callback(pf_instance, old_path, new_tile, new_direction);
        if (old_path == null) {
            this._length = 0;
        } else {
            this._length = old_path.GetLength() + AIMap.DistanceManhattan(old_path.GetTile(), new_tile);
        }
    };

    /**
     * Return the tile where this (partial-)path ends.
     */
    function GetTile() { return this._tile; }

    /**
     * Return the direction from which we entered the tile in this (partial-)path.
     */
    function GetDirection() { return this._direction; }

    /**
     * Return an instance of this class leading to the previous node.
     */
    function GetParent() { return this._prev; }

    /**
     * Return the cost of this (partial-)path from the beginning up to this node.
     */
    function GetCost() { return this._cost; }

    /**
     * Return the length (in tiles) of this path.
     */
    function GetLength() { return this._length; }
};
