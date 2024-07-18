Floaticator
===========

A mod for Minetest, adding a node (based on the Floatater from Minecraft's joke snapshot 24w14potato) which transports structures as a sort of voxel area entity when powered by mesecons. Very much in progress and unfinished, plenty of known bugs, doesn't yet support all drawtypes, paramtypes, nodebox types, etc.; nodes in transport are intentionally frozen and cannot yet be interacted with. Feel free to test it out and find even more bugs for me to fix. A list of known bugs is maintained below.

Known Bugs
----------

* Many less-common drawtypes such as firelike, torchlike, fencelike and raillike are not yet supported and are instead drawn like air in the VAE.
* Several paramtypes and (often associated) nodebox types are not yet supported. Unsupported paramtypes are ignored, nodebox types are probably just drawn as either full cubes or just the fixed box.
* Selection boxes for connected nodeboxes seem to be drawn as full cubes.
* While node timers and metadata fields are carried across and reinstated on the other side, node inventories are not.
* Mesecons components such as the floaticator itself don't update after being transported.
* The VAE does not push objects in front of it or on top of it.
* Nodes being transported may be cloned on reloading the world, as they detach from the VAE which then spawns new ones to replace them.
* Crashes for whatever reason may cause the floater to become unresponsive.

License
-------

Floaticator is licensed under the MIT license:

Floaticator

Copyright (C) 2024 theidealist (theidealistmusic@gmail.com)

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.