---- Configuration Data: Modify to customize behavior

local FILE_PREFIX = "block_";
local FILE_SUFFIX = ".obj";
local EXPORT_NODES = { "wool:white", "wool:red", "wool:green", "wool:blue" };

---- End Configuration Data


Basis =
   {
      localToGlobal = function(self, pos)
         return { [self.e] = pos.x, [self.n] = pos.y, [self.u] = pos.z };
      end,

      globalToLocal = function(self, pos)
         return { x = pos[self.e], y = pos[self.n], z = pos[self.u] };
      end
   };
setmetatable(
   Basis,
   {
      __call = function(class, up)
         local e, n;
         if up == "x" then
            e, n = "y", "z";
         elseif up == "y" then
            e, n = "z", "x";
         elseif up == "z" then
            e, n = "x", "y";
         else
            error("illegal basis direction");
         end

         return setmetatable({ e = e, n = n, u = up }, { __index = class });
      end
   });


local function fileName(x, y, z)
   local xs = math.floor(x);
   local ys = math.floor(y);
   local zs = math.floor(z);
   if xs >= 0 then xs = tostring(xs); else xs = "m" .. tostring(-xs); end
   if ys >= 0 then ys = tostring(ys); else ys = "m" .. tostring(-ys); end
   if zs >= 0 then zs = tostring(zs); else zs = "m" .. tostring(-zs); end
   return FILE_PREFIX .. xs .. "-" .. ys .. "-" .. zs .. FILE_SUFFIX;
end

local isCidExported;
do
   local exportMap = nil;

   isCidExported = function(cid)
      if not exportMap then
         exportMap = {};
         for _, name in ipairs(EXPORT_NODES) do
            local cid = minetest.get_content_id(name);
            exportMap[cid] = true;
         end
      end

      return exportMap[cid] or false;
   end;
end

local function hashVert(pos)
   return (pos.x or 0) + 80*(pos.y or 0) + 6400*(pos.z or 0);
end


local function getObjData(xMin, yMin, zMin, xMax, yMax, zMax)
   local verts = {};
   local quads = {};

   local vertMap = {};

   local function getRowData(basis, xMin, xMax, y, z)
      local vm = minetest.get_voxel_manip();
      local pMin = basis:localToGlobal({ x = xMin, y = y, z = z - 0.5 });
      local pMax = basis:localToGlobal({ x = xMax, y = y, z = z + 0.5 });
      pMin, pMax = vm:read_from_map(pMin, pMax);
      local data = vm:get_data();
      local va = VoxelArea:new({ MinEdge = pMin, MaxEdge = pMax });

      local segs = {};
      local start, wasUp = nil, false;
      for x = xMin, xMax do
         local pL = basis:localToGlobal({ x = x, y = y, z = z - 0.5 });
         local pH = basis:localToGlobal({ x = x, y = y, z = z + 0.5 });
         local haveL = va:containsp(pL) and isCidExported(data[va:indexp(pL)]);
         local haveH = va:containsp(pH) and isCidExported(data[va:indexp(pH)]);
         local on, up = (haveL ~= haveH), haveH;
         if on then
            if not start then
               start, wasUp = x, up;
            elseif up ~= wasUp then
               segs[#segs + 1] = { xs = start, xe = x-1, ys = y, up = wasUp };
               start, wasUp = x, up;
            end
         elseif start then
            segs[#segs + 1] = { xs = start, xe = x-1, ys = y, up = wasUp };
            start = nil;
         end
      end
      if start then segs[#segs + 1] = { xs = start, xe = xMax, ys = y }; end

      return segs;
   end

   local function vertexIndex(basis, pos)
      local vv = basis:localToGlobal(pos);
      local vh = hashVert(vv);
      local vlist = vertMap[vh];
      if vlist then
         for v, vi in pairs(vlist) do
            if v.x == vv.x and v.y == vv.y and v.z == vv.z then
               return vi;
            end
         end
      else
         vlist = {};
         vertMap[vh] = vlist;
      end
      local vi = #verts + 1;
      verts[vi] = vv;
      vlist[vv] = vi;
      return vi;
   end

   local function drawRect(basis, xs, ys, xe, ye, z)
      local vi1 = vertexIndex(basis, { x = xs - 0.5, y = ys - 0.5, z = z });
      local vi2 = vertexIndex(basis, { x = xe + 0.5, y = ys - 0.5, z = z });
      local vi3 = vertexIndex(basis, { x = xe + 0.5, y = ye + 0.5, z = z });
      local vi4 = vertexIndex(basis, { x = xs - 0.5, y = ye + 0.5, z = z });
      quads[#quads + 1] = { vi1, vi2, vi3, vi4 };
   end

   local function drawRects(basis, prevRow, nextRow, y, z)
      local nri = 1;
      local nrSeg = nextRow[nri];

      for _, prSeg in ipairs(prevRow) do
         while nrSeg and nrSeg.xe < prSeg.xs do
            nri = nri + 1;
            nrSeg = nextRow[nri];
         end

         if nrSeg and
               (nrSeg.xs == prSeg.xs) and
               (nrSeg.xe == prSeg.xe) and
               (nrSeg.up == prSeg.up) then
            nrSeg.ys = prSeg.ys;
         else
            drawRect(basis, prSeg.xs, prSeg.ys, prSeg.xe, y, z);
         end
      end
   end

   local function drawSlice(basis, xMin, yMin, xMax, yMax, z)
      local nextRow = getRowData(basis, xMin, xMax, yMin, z);
      for y = yMin+1, yMax do
         local prevRow = nextRow;
         nextRow = getRowData(basis, xMin, xMax, y, z);
         drawRects(basis, prevRow, nextRow, y-1, z);
      end
      drawRects(basis, nextRow, {}, yMax, z);
   end

   local function drawSlices(basis, xMin, yMin, zMin, xMax, yMax, zMax)
      for z = zMin - 0.5, zMax + 0.5 do
         drawSlice(basis, xMin, yMin, xMax, yMax, z);
      end
   end

   for _, up in ipairs({ "x", "y", "z" }) do
      local basis = Basis(up);
      local pMin = basis:globalToLocal({ x = xMin, y = yMin, z = zMin });
      local pMax = basis:globalToLocal({ x = xMax, y = yMax, z = zMax });
      drawSlices(basis, pMin.x, pMin.y, pMin.z, pMax.x, pMax.y, pMax.z);
   end

   return verts, quads;
end

local function exportBlock(pos)
   local xMin = 80 * math.floor(pos.x / 80);
   local yMin = 80 * math.floor(pos.y / 80);
   local zMin = 80 * math.floor(pos.z / 80);
   local xMax = xMin + 79;
   local yMax = yMin + 79;
   local zMax = zMin + 79;

   local fname = fileName(xMin, yMin, zMin);
   local fpath = minetest.get_worldpath() .. "/" .. fname;
   local file, emsg = io.open(fpath, "w");
   if not file then error(emsg); end

   local verts, quads = getObjData(xMin, yMin, zMin, xMax, yMax, zMax);
   for _, v in ipairs(verts) do
      file:write("v "..(v.x-xMin).." "..(v.y-yMin).." "..(v.z-zMin).."\n");
   end
   for _, f in ipairs(quads) do
      file:write("f "..f[1].." "..f[2].." "..f[3].." "..f[4].."\n");
   end

   file:flush();
   file:close();

   return fname;
end


minetest.register_privilege(
   "export",
   {
      description = "Allows exporting of data to files",
      give_to_singleplayer = true
   });

minetest.register_chatcommand(
   "exportblock",
   {
      params = "",
      description = "Exports your current 80x80x80 node block to a file",
      privs = { export = true },
      func =
         function(name, paramStr)
            local player = minetest.get_player_by_name(name);
            local fname = exportBlock(player:getpos());
            return true, "current block exported to " .. fname;
         end
   });
