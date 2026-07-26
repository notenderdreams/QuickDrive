-- prototypes/grids.lua
-- Ensures all vehicles (Cars, Tanks, Spidertrons, modded vehicles) have an equipment grid

local categories = {}
if data.raw["equipment-category"] then
  for name, _ in pairs(data.raw["equipment-category"]) do
    table.insert(categories, name)
  end
else
  categories = {"armor", "universal", "vehicle", "spidertron"}
end

data:extend({
  {
    type                 = "equipment-grid",
    name                 = "quick-drive-vehicle-grid",
    width                = 12,
    height               = 12,
    equipment_categories = categories,
  }
})

local vehicle_types = {"car", "spider-vehicle"}
for _, vtype in ipairs(vehicle_types) do
  if data.raw[vtype] then
    for name, proto in pairs(data.raw[vtype]) do
      if not proto.equipment_grid then
        proto.equipment_grid = "quick-drive-vehicle-grid"
      end
    end
  end
end
