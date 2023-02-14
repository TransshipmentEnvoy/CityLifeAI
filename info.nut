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
    function GetAuthor() {
        return "Forked by TransshipmentEnvoy";
    }

    function GetName() {
        return "CityLifeAI(Custom)";
    }

    function GetShortName() {
        return "CLAC";
    }

    function GetDescription() {
        return "Populates city with life by adding cars, bikes and service vehicles. Provide good public services to reduce the traffic. Happy cities will grow and connect to nearby towns. Requires newGRF with eyecandy vehicles and GS with ToyLib support.";
    }

    function GetVersion() {
        return SELF_VERSION;
    }

    function GetDate() {
        return SELF_DATE;
    }

    function GetAPIVersion() {
        return "1.10";
    }

    function GetURL() {
        return "https://www.tt-forums.net/viewtopic.php?f=65&t=89121";
    }

    function MinVersionToLoad() {
        return SELF_MINLOADVERSION;
    }

    function UseAsRandomAI() {
        return false;
    }

    function CreateInstance() {
        return "CityLife";
    }

    function GetSettings() {
        AddSetting({
            name = "MaxTownNum",
            description = "The maximum town number this AI will service",
            easy_value = 30,
            medium_value = 30,
            hard_value = 30,
            custom_value = 30,
            flags = CONFIG_INGAME,
            step_size = 1,
            min_value = 0,
            max_value = 100
        });
        AddSetting({
            name = "MaxVehiclePerTown",
            description = "The maximum vehicle per town per service",
            easy_value = 50,
            medium_value = 50,
            hard_value = 50,
            custom_value = 50,
            flags = CONFIG_INGAME,
            step_size = 1,
            min_value = 0,
            max_value = 100
        });
        AddSetting({
            name = "NetworkRadius",
            description = "The maximum radius of the road network this AI will build",
            easy_value = 960,
            medium_value = 960,
            hard_value = 960,
            custom_value = 960,
            flags = CONFIG_INGAME,
            step_size = 64,
            min_value = 64,
            max_value = 4096
        });
        AddSetting({
            name = "debug_signs",
            description = "Debug: Build signs",
            easy_value = 0,
            medium_value = 0,
            hard_value = 0,
            custom_value = 0,
            flags = CONFIG_BOOLEAN | CONFIG_INGAME | CONFIG_DEVELOPER
        });
    } // GetSettings

}

RegisterAI(CityLife()); // Tell the core we are an AI