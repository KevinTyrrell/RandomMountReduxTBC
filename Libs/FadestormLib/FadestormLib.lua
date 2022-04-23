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
local _G, fenv = _G, getfenv(1) -- Maintain reference to global table
setfenv(1, setmetatable({}, {
    __newindex = FSL, -- Global assignments go to FSL table instead
    __index = function(_, index)
        local v = FSL[index] -- Redirect lookups to FSL
        return v ~= nil and v or _G[index] -- Redirect to global table if FSL has no such index
    end
}))

-- Imported standard library functions.
local upper, lower = string.upper, string.lower

-- Forward declarations for circular function dependencies
Type = {
    TABLE = setmetatable({}, { __call = function(_, x) return x end }),
    STRING = setmetatable({}, { __call = function(_, x) return x end })
}
Error = {
    UNSUPPORTED_OPERATION = setmetatable({}, { __call = function() end }),
    TYPE_MISMATCH = setmetatable({}, { __call = function() end }),
}

-- Helper function -- Basis for read-only tables
local function readOnlyMetaTable(private)
    return {
        -- Reject any mutations to the read-only table
        __newindex = function()
            Error.UNSUPPORTED_OPERATION(ADDON_NAME, "Ready-only table cannot be modified")
        end,
        -- Redirect lookups to the private table without exposing the table itself
        __index = function(_, index) return private[index] end,
        -- Prevent access to the metatable but work-around for Lua 5.1 no '__len' metamethod
        __metatable = function() return #private end,
    }
end

--[[
-- Constructs a read-only view into a private table
--
-- Read-only tables cannot be modified.
-- An error will be thrown upon __newindex being called.
-- Read-only tables do not support the length operator '#' (Lua 5.1 limitation)
-- Calling 'getmetatable(...)' will retrieve the length of the underlying table.
--
-- Meta-methods may be provided in order to further customize the read-only table.
-- '__metatable', '__index', and '__newindex' meta-methods are ignored.
--
-- @param private [Table] Map of fields
-- @param metamethods [Table] (optional) Metamethods to be included into the table
]]--
function readOnlyTable(private, metamethods)
    local mt = readOnlyMetaTable(Type.TABLE(private))
    if metamethods ~= nil then -- User wants additional meta-methods included
        for k, v in pairs(Type.TABLE(metamethods)) do
            if mt[k] ~= nil then -- Existing meta-methods cannot be overwritten
                mt[k] = v end end
    end
    return setmetatable({}, mt)
end

--[[
-- Constructs a new enum from a set of values
--
-- Enum values have the following fields:
-- * name: name of the enum value (uppercase)
-- * ordinal: numerical index of the value, starting from 1
--
-- Enum values implement the following metamethods:
-- * __tostring (equivalent to 'name')
-- * __lt & __lte (comparable)
-- * __call (equivalent to 'ordinal')
--
-- Enum values can be referenced by 'Class.MY_ENUM_VALUE' format,
-- or by ordinal, e.g. 'Class[1]' for the enum value with ordinal '1'.
-- Length of the enum class can be requested with 'getmetatable(Class)'.
--
-- Enum values are read-only, but additional fields can be
-- defined using the private field table return value.
--
-- @param values List of strings (will be converted to uppercase)
-- @return [Table] List of Enum values (field 'length' used instead of '#')
-- @return [Table] Map of enum values to their private field table (used to define new fields)
]]--
function Enum(values, metamethods)
    local enum_map = {} -- Maps read-only enum instances to their private fields
    local enum_class = {} -- Private fields of the enum class

    --[[
    -- All enum elements must share the same metatable so that they are comparable.
    -- The metatable's __call must lookup the corresponding private table.
    --]]
    local mt = readOnlyMetaTable()
    mt.__index = function(tbl, index) return enum_map[tbl][index] end -- Redirect lookups

    local DEFAULT_META_TABLE = { -- Default metamethods for enums
        __lt = function(t1, t2) return t1.ordinal < t2.ordinal end,
        __lte = function(t1, t2) return t1.ordinal <= t2.ordinal end,
        __call = function(tbl) return tbl.ordinal end,
        __tostring = function(tbl) return tbl.name end,
    }

    if metamethods ~= nil then -- Overwrite default metamethods, if any provided by the user
        for k, v in pairs(Type.TABLE(metamethods)) do
            DEFAULT_META_TABLE[k] = v end end
    for k, v in pairs(DEFAULT_META_TABLE) do
        if mt[k] == nil then mt[k] = v end end -- Reject metamethods that are not overridable

    for ordinal, name in ipairs(Type.TABLE(values)) do
        name = upper(Type.STRING(name))
        instance = setmetatable({}, mt)
        enum_map[instance] = { -- Associate the instance with the enum's private fields
            name = name,
            ordinal = ordinal
        }
        enum_class[name] = instance
        enum_class[instance.ordinal] = instance -- Workaround for lack of 'pairs' support
    end

    return readOnlyTable(enum_class), readOnlyTable(enum_map)
end

--[[
-- Type Enum
--
-- Types of the Lua programming language
--
-- Enum constants are as follows:
-- NIL, STRING, BOOLEAN, NUMBER, FUNCTION, USERDATA, THREAD, TABLE
--
-- __call meta-method
-- Type-checks a value, ensuring it to be of the same type as the Type enum value
-- @param value [?] Value to be type-checked
-- @return [?] value
]]--
Type = (function()
    local function match(tbl, value) return tbl.type == type(value) end

    local Type, private = Enum({ "NIL", "STRING", "BOOLEAN","NUMBER",
                                 "FUNCTION", "USERDATA", "THREAD", "TABLE" },
            {
                __call = function(tbl, value)
                    if not match(tbl, value) then
                        Error.TYPE_MISMATCH(ADDON_NAME,
                                "Received " .. type(value) .. ", Expected: " .. tbl.type) end
                    return value
                end
            })
    for i = 1, getmetatable(Type)() do
        local t = Type[i]
        private[t].type = lower(t.name)
        private[t].match = function(type, value)
            return match(Type.TABLE(type), value) end
    end

    return Type
end)()

--[[
-- Error Enum
--
-- Defines an error throwing interface
--
-- Enum constants are as follows:
-- UNSUPPORTED_OPERATION, TYPE_MISMATCH, NIL_POINTER
--
-- __call meta-method
-- Throws an error to the chat window and error frame
-- @param source [string] Source name of the error (addon, weak aura, macro, etc)
-- @param msg [string] Msg providing details of the error
]]--
Error = (function()
    local crt, src_color, msg_color = "\124r", "\124cFFECBC2A", "\124cFFFF0000"
    return Enum({ "UNSUPPORTED_OPERATION", "TYPE_MISMATCH", "NIL_POINTER" }, {
        __call = function(tbl, source, msg)
            msg = crt .. "[" .. src_color .. Type.STRING(source) .. crt .. "] " ..
                    tostring(tbl) .. ": " .. msg_color .. Type.STRING(msg) .. crt
            print(msg)
            error(msg)
        end
    })
end)()

--[[
-- ==========================
-- ======= Stream API =======
-- ==========================
]]--

--[[
-- Filters an iterable stream, iterating over a designated subset of elements
--
-- @param iterable [table][function] Stream in which to iterate
-- @param callback [function] Callback filter function
-- @return [function] Iterator
]]--
function filter(iterable, callback)
    Type.FUNCTION(callback)
    local iterator = Type.TABLE:match(iterable) and next or Type.FUNCTION(iterable)
    local key -- Iterator key parameter cannot be trusted due to key re-mappings
    return function()
        local value
        repeat key, value = iterator(iterable, key)
        until key == nil or callback(key, value) == true
        return key, value
    end, iterable, nil
end

--[[
-- Maps an iterable stream, translating elements into different elements
--
-- @param iterable [table][function] Stream in which to iterate
-- @param callback [function] Callback mapping function
-- @return [function] Iterator
]]--
function map(iterable, callback)
    Type.FUNCTION(callback)
    local iterator = Type.TABLE:match(iterable) and next or Type.FUNCTION(iterable)
    local key -- Iterator key parameter cannot be trusted due to key re-mappings
    return function()
        local value
        key, value = iterator(iterable, key)
        if key ~= nil then return callback(key, value) end
    end, iterable, nil
end

--[[
-- Merges two iterable streams together
--
-- The resulting combined stream will have the same
-- number of elements as the largest of the two streams.
-- Streams of mismatched sizes can be merged but will partially yield
-- nil for the callback key/value parameters of the smaller stream.
--
-- @param iter1 [table][function] Stream in which to iterate
-- @param iter2 [table][function] Stream in which to iterate
-- @param callback [function] Callback mapping function: (k1,v1,k2,v2) --> (key,value)
-- @return [function] Iterator
]]--
function merge(iter1, iter2, callback)
    Type.FUNCTION(callback)
    local i1 = Type.TABLE:match(iter1) and next or Type.FUNCTION(iter1)
    local i2 = Type.TABLE:match(iter2) and next or Type.FUNCTION(iter2)
    local iterator, k1, v1, k2, v2

    local function yield_left()
        k1, v1 = i1(iter1, k1)
        return k1 end
    local function yield_right()
        k2, v2 = i2(iter2, k2)
        return k2 end
    -- Pull elements from both streams, or switch to just one
    iterator = function()
        k1, v1 = i1(iter1, k1)
        k2, v2 = i2(iter2, k2)
        if k1 ~= nil and k2 == nil then
            iterator = yield_left
        elseif k2 ~= nil and k1 == nil then
            iterator = yield_right
            return k2 -- k1 is nil, return k2 so iteration continues
        end
        return k1
    end

    return function()
        if iterator() then -- Callback only if another element exists
            return callback(k1, v1, k2, v2) end
    end
end

--[[
-- Flattens out a collection of streams into one iterable stream
--
-- The resultant stream will contain elements of the passed
-- tables or iterators in the order of which they are provided.
-- Empty tables or iterators are disregarded for the output stream.
-- For example { 5, 4 }, {}, { 3 } --> { 5, 4, 3 }
--
-- @param [table][function] Stream(s) in which to iterate (variable arguments)
-- @return [function] Iterator
]]--
function flat_map(...)
    local arg = Type.TABLE:match(...) and ... or {...} -- Lua 5.1 varargs limitation
    local ikey, iterable, iterator, key, value = next(arg)
    -- Table is empty, return a blank iterator
    if ikey == nil then return function() return nil end end
    iterator = Type.TABLE:match(iterable) and next or Type.FUNCTION(iterable)

    return function()
        while true do
            -- Check for an element inside the nested table(s)
            key, value = iterator(iterable, key)
            if key ~= nil then return key, value end
            -- Check for an additional table to iterate
            ikey, iterable = next(arg, ikey)
            if ikey == nil then return nil end
        end
    end
end

--[[
-- Peeks an iterable stream, viewing each element
--
-- @param iterable [table][function] Stream in which to iterate
-- @param callback [function] Callback peeking function
-- @return [function] Iterator
]]--
function peek(iterable, callback)
    Type.FUNCTION(callback)
    local iterator = Type.TABLE:match(iterable) and next or Type.FUNCTION(iterable)
    local key -- Iterator key parameter cannot be trusted due to key re-mappings
    return function()
        local value
        key, value = iterator(iterable, key)
        if key ~= nil then
            callback(key, value)
            return key, value
        end
    end, iterable, nil
end


--[[
-- Collects an iterator stream into a table
--
-- Collect is a terminating stream operation.
-- The stream is closed and no further stream operations are applicable.
--
-- @param iterable [table][function] Stream in which to iterate
-- @return [table] Elements of the stream
]]--
function collect(iterable)
    local iterator = Type.TABLE:match(iterable) and next or Type.FUNCTION(iterable)
    local tbl = { }
    for key, value in iterator do
        tbl[key] = value end
    return tbl
end

--[[
-- Iterates through elements of a stream
--
-- For-each is a terminating stream operation.
-- The stream is closed and no further stream operations are applicable.
--
-- @param iterable [table][function] Stream in which to iterate
-- @param callback [function] Callback for-each function
-- @return [table] Elements of the stream
]]--
function for_each(iterable, callback)
    Type.FUNCTION(callback)
    local iterator = Type.TABLE:match(iterable) and next or Type.FUNCTION(iterable)
    for key, value in iterator do
        callback(key, value) end
end

setfenv(1, fenv) -- Reset environment
