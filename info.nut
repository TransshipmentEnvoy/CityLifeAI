/*
 * This file is part of CityLifeAI, an AI for OpenTTD.
 *
 * It's free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the
 * Free Software Foundation, version 2 of the License.
 *
 */

require("version.nut");

class CityLife extends AIInfo {
    function GetAuthor()        { return "Firrel"; }
    function GetName()          { return "CityLifeAI"; }
    function GetShortName()     { return "CLAI"; }
    function GetDescription()   { return "Builds random cars on your streets if you have a GRF with cars."; }
    function GetVersion()       { return SELF_VERSION; }
    function GetDate()          { return SELF_DATE; }
    function GetAPIVersion()    { return "1.10"; }
    function GetURL()           { return ""; }
    function MinVersionToLoad() { return SELF_MINLOADVERSION; }
    function UseAsRandomAI ()   { return false; }
    function CreateInstance()   { return "CityLife"; }

    function GetSettings() {
        AddSetting({
            name = "debug_signs", 
            description = "Debug: Build signs", 
            easy_value = 0, medium_value = 0, hard_value = 0, custom_value = 0, 
            flags = CONFIG_BOOLEAN | CONFIG_INGAME  | CONFIG_DEVELOPER});
    } // GetSettings

}

RegisterAI(CityLife()); // Tell the core we are an AI
