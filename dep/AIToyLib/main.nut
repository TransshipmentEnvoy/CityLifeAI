/* -*- Mode: C++; tab-width: 6 -*- */
/*
 *
 * This file is part of ToyLib a library for OpenTTD
 * Copyright (C) 2014 Krinn <krinn@chez.com>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

require("version.nut");
class AIToyLib
{
    static State = { scp_handle = null, alone = true }; // first store the scp handle, second store if the lib works alone or with a SCP ready host
    constructor(scp_handle)
    {
        if (scp_handle == null) {
            // We will handle SCP ourselves if the main script don't use scp
            scp_handle = SCPLib(AITOYLIB_SHORTNAME, AITOYLIB_VERSION, null);
            AIToyLib.State.alone = true;
        } else {
            AIToyLib.State.alone = false;
        }
        AIToyLib.State.scp_handle = scp_handle;
        scp_handle.SetEventHandling(true); // force events on
        scp_handle.SCPLogging_Error(true);
        scp_handle.AddCommand("MoneyPlease", "GSToyLib Set v1", this);
        scp_handle.AddCommand("Exemption", "GSToyLib Set v1", this);
    }
}

function AIToyLib::SCPConfigChange(events, info, error)
/**
 * Change some SCP configuration, this is to allow a script not using SCP still be able to alter some basic SCP configuration
 * Default are : events true, info and error to false
 * @param events true to enable SCP to handle events for the host script (if your script don't use events, enable it)
 * @param info true to enable SCP debug message (it will flood you)
 * @param error true to enable SCP reporting errors messages (that's still an SCP debug feature), but reporting errors from SCP can help users see your script isn't at fault
 */
{
    AIToyLib.State.scp_handle.SetEventHandling(events);
    AIToyLib.State.scp_handle.SCPLogging_Error(error);
    AIToyLib.State.scp_handle.SCPLogging_Info(info);
}

function AIToyLib::Check()
/**
 * Check do nothing more than just called the SCPLib.Check, while we must have that check done, script using SCP are already doing it, so they just don't need that function
 * If the lib was init with an SCP handle, this will do nothing, leaving the SCP Check done by the hosting script. Unlike SCPLIb.Check this function handle all events in one time and return nothing ; for a more fine tuning Check use the SCPLib.Check function.
 */
{
    if (AIToyLib.State.alone)    while (AIToyLib.State.scp_handle.Check()) {};
}

function AIToyLib::ToyAskMoney(money)
/**
 * This is just how the lib ask money to the GS using SCP. Nothing hard as SCP handle everything for us, Read SCP doc for more : http://wiki.openttd.org/SCPLib_doc
 * @param money to amount of money SCP will request to the GS.
 */
{
    AIToyLib.State.scp_handle.QueryServer("MoneyPlease", "GSToyLib Set v1", money);
}

function AIToyLib::AskExemption(status) {
    AIToyLib.State.scp_handle.QueryServer("Exemption", "GSToyLib Set v1", status);
}
