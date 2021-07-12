                ******************************
                *        City Life AI        *
                *      An AI for OpenTTD     *
                ******************************

Version: 1

Usefull URL's:
- forum topic: https://www.tt-forums.net/viewtopic.php?f=65&t=89121
- github: https://github.com/F1rrel/CityLifeAI


Content:
* 1. How the AI works
* 2. Settings
* 3. Requirements
* 4. License
* 5. Credits


1. How the AI works
Have you ever been stuck behind a horse ridden carriage or a very rude 
cyclist when travelling to work? This will provide this experience and more.

Populates villages, towns and cities with traffic of eye candy vehicles
available in several newGRFs. The vehicles are split into several categories:
cars, mail trucks, service vehicles. The AI manages the number of each category
dependent of the size of the city. No more five fire trucks in a small village.

By providing outstanding public services to the city, more people decide to use 
it, so the private transportation decreases. Also transporting mails decreases
the number of small companies that provided this service, taking them out of 
business and out of traffic.

This AI was designed to support NRT roads of "any" kind. On top of that, 
when the city reaches enought population, they decide to finally connect 
to the nearby towns. However some of them are corrupt and use up the money
without building anything or hire some questionable builder to build
unconnected roads. But if they succeed, they celebrate it in a big way!


2. Settings
You can't change the decisions of the cities, they act on their own, no 
amount of trees can solve it.


3. Requirements
- OpenTTD, v. 1.10.x or newer.
- SuperLib v. 40, SCPLib v. 45, AIToyLib v. 1 (all available in BaNaNaS
  and OTTD's "Online Content").
- Any eye candy road vehicle newGRF (with 0 running cost)
- Game Script which supports GSToyLib (otherwise it will bankrupt fast)


4. Recommended newGRFs and GS
- Eyecandy Road Vehicles
- Funny Cars
- Generic Cars
- DROP
- Renewed Village Growth

4. License
CityLifeAI is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, version 2 of the License
(see file license.txt).


5. Credits

Author: Firrel
