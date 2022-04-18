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
local upper = string.upper

-- Forward declarations for circular function dependencies
FSL.Type = {
    TABLE = setmetatable({}, { __call = function(_, x) return x end }),
    STRING = setmetatable({}, { __call = function(_, x) return x end })
}

function FSL:readOnlyTable(private, meta)
    -- Initialize optional parameter
    private = private == nil and {} or FSL.Type.TABLE(private)
    local mt = {
        __metatable = false, -- Forbid access of this metatable through 'getmetatable'
        __newindex = function()
            FSL:throw(ADDON_NAME, Error.ILLEGAL_MODIFICATION, "Ready-only table cannot be modified")
        end,
        __index = function(_, index) return private[index] end
    }
    if meta ~= nil then -- User wants additional meta-methods included
        for k, v in pairs(FSL.Type.TABLE(meta)) do
            if mt[k] ~= nil then -- Existing meta-methods cannot be overwritten
                mt[k] = v end end
    end

    return setmetatable({}, mt), private
end


--[[
-- Constructs a new enum from a set of values
--
-- Enum values have the following fields:
-- * name: name of the enum value (uppercase)
-- * ordinal: numerical index of the value, starting from 1
-- * __tostring: equivalent to 'name'
--
-- Enum values are read-only, but additional fields can be
-- defined using the private field table return value.
--
-- @param values List of strings (will be converted to uppercase)
-- @return [Table] List of Enum values (field 'length' used instead of '#')
-- @return [Table] Map of enum values to their private field table (used to define new fields)
]]--
function FSL:Enum(values)
    -- Translates public tables into their respective private tables
    local pub_prv = {}
    local enum = {}

    -- In order for table values to be compared, they must share the same metatable
    local mt = {
        __lt = function(t1, t2) return t1.ordinal < t2.ordinal end,
        __lte = function(t1, t2) return t1.ordinal <= t2.ordinal end,
        __call = function(tbl) return tbl.ordinal end,
        __tostring = function(tbl) return tbl.name end,
        __metatable = false,
        __newindex = function()
            FSL:throw(ADDON_NAME, Error.ILLEGAL_MODIFICATION, "Ready-only table cannot be modified")
        end,
        __index = function(tbl, index)
            return pub_prv[tbl][index] -- Access the private table for this enum
        end
    }

    -- Ensure there are no duplicate enum names
    for i, v in ipairs(FSL.Type.TABLE(values)) do
        enum[upper(FSL.Type.STRING(v))] = i end
    for name, ordinal in pairs(enum) do
        pub_prv[setmetatable({}, mt)] = {
            name = name,
            ordinal = ordinal
        }
    end
    enum = {} -- Prepare enum table
    for k, v in pairs(pub_prv) do
        enum[v.ordinal] = k end
    enum.length = #enum -- Lua 5.1 workaround for missing meta-method '__len'
    enum = FSL:readOnlyTable(enum)
    return enum, FSL:readOnlyTable({}, {
        __index = pub_prv -- Provide access to underlying enum private fields
    })
end

