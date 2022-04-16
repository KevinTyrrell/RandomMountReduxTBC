--[[
--    Copyright (C) 2021  Fadestorm - Earthfury-US
--
--    This program is free software: you can redistribute it and/or modify
--    it under the terms of the GNU General Public License as published by
--    the Free Software Foundation, either version 3 of the License, or
--    (at your option) any later version.
--
--    This program is distributed in the hope that it will be useful,
--    but WITHOUT ANY WARRANTY; without even the implied warranty of
--    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--    GNU General Public License for more details.
--
--    You should have received a copy of the GNU General Public License
--    along with this program.  If not, see <https://www.gnu.org/licenses/>.
]]--

-- LibStub library library initialization
local ADDON_NAME = "FadestormLib"
local MAJOR, MINOR = ADDON_NAME .. "-1", 0
local FSL = LibStub:NewLibrary(MAJOR, MINOR)
if not FSL then return end

-- Imported standard library functions.
---

-- Forward declarations for circular function dependencies
FSL.Type = {
    TABLE = setmetatable({}, { __call = function(x) return x end })
}

--[[
-- Constructs a read-only table
--
-- If a public table is provided, that table will become read-only

]]--
function FSL:readOnlyTable(private, public)
    private = private == nil and {} or FSL.Type.TABLE(private)
    tbl = setmetatable(public == nil and {} or FSL.Type.TABLE(public), {
        __metatable = false, -- Forbid access of this metatable through 'getmetatable'
        __newindex = function()
            FSL:throw(ADDON_NAME, Error.ILLEGAL_MODIFICATION, "Ready-only table cannot be modified")
        end,
        __index = function(_, index) return private[index] end
    })
    return public, private
end



local function readOnlyTable(tbl, keys)
    setmetatable(tbl, {

    })
    return tbl, keys
end

