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
    function GetDescription()   { return "Populates city with life by adding cars, bikes and service vehicles. Provide good public services to reduce the traffic. Happy cities will grow and connect to nearby towns. Requires newGRF with eyecandy vehicles and GS with ToyLib support."; }
    function GetVersion()       { return SELF_VERSION; }
    function GetDate()          { return SELF_DATE; }
    function GetAPIVersion()    { return "1.10"; }
    function GetURL()           { return "https://www.tt-forums.net/viewtopic.php?f=65&t=89121"; }
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
