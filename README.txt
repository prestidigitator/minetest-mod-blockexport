Block Export Mod
================

This mod defines a new chat command "/exportblock" which writes 3D node data
of the player's current 80x80x80 node block to a file.  The chat command
requires the "export" privilege, also defined by the mod.

Data is exported in Wavefront OBJ format, to a file named
"<prefix><bx>-<by>-<bz><suffix>", where <prefix> is the configurable string
FILE_PREFIX defaulting to "block_", <suffix> is the configurable string
FILE_SUFFIX defaulting to ".obj", and <bx>, <by>, and <bz> are the (minimum) x,
y, and z coordinates of the exported block, with negative values prefixed by an
"m" character rather than a minus sign.  For example, with the default values
blocks close to the origin might be exported as "block_0-0-0.obj" and
"block_m80-m80-m80.obj".

The entire block is exported as a single mesh, with internal faces between
adjoining blocks removed.  The mesh object's origin will be at the world
origin, while the vertex coordinates will be located at their corresponding
locations within the block.

Mod Details
-----------

Required Minetest Version: >= 0.4.9

Dependencies: none

New Privileges: export

Commands:

   /exportblock
      -- Requires "export" privilege.  Takes no parameters.  Exports nodes from
         the player's current 80x80x80 node block named in EXPORT_NODES.

Note: The default configuration has a soft dependency on wool simply because it
lists some "wool:..." node types as the ones to export.  See the EXPORT_NODES
configuration variable.

Git Repo: https://github.com/prestidigitator/minetest-mod-blockexport

Change History
--------------

Version 1.0

* Released 2014-08-17
* Known issue: Adjoining planar faces may not be joined at all vertices and
               edges due to the way they are divided into rectangular strips.
* Known issue: May need to be mirrored in most modeling programs due to
               Minetest/OpenGL's non-standard left-handed coordinate system.

Copyright and Licensing
-----------------------

All contents are the original creations of the mod author.

Author: prestidigitator (as registered on forum.minetest.net)
License: WTFPL (all content)
