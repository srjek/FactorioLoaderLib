local ZipModLoader = {}
ZipModLoader.__index = ZipModLoader

local directory_stack = {}

function ZipModLoader.new(dirname, mod_name, arc_subfolder)
    local filename = dirname .. mod_name .. ".zip"
    local arc = assert(zip.open(filename))
    local mod = {
        mod_name = mod_name .. "/",
        archive = arc,
        archive_name = filename,
        arc_subfolder = arc_subfolder,
    }
    return setmetatable(mod, ZipModLoader)
end

function ZipModLoader:__call(name)
    name = string.gsub(name, "%.", "/")
    local potential_files = { self.arc_subfolder .. name .. ".lua" }
    if #directory_stack ~= 0 then
        table.insert(potential_files, directory_stack[#directory_stack] .. name .. ".lua")
    end
    local file = nil
    local filename = nil
    for _, f in ipairs(potential_files) do
        file = self.archive:open(f)
        if file then
            filename = f
            break
        end
    end
    if not file then
        return "Not found: " .. name .. " in " .. self.archive_name
    end
    local content = file:read("*a")
    file:close()
    local bom_a, bom_b, bom_c = string.byte(content, 1, 3)
    if bom_a == 239 and bom_b == 187 and bom_c == 191 then
        content = content:sub(4)
    end
    local loaded_chunk, e = load(content, filename)
    return function()
        table.insert(directory_stack, filename:sub(1, filename:find("/[^/]*$")))
        if loaded_chunk == nil then
            print(loaded_chunk, e)
        end
        local result = loaded_chunk()
        table.remove(directory_stack)
        return result
    end
end

function ZipModLoader:close()
    self.archive:close()
end

return ZipModLoader
