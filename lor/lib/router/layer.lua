local pcall = pcall
local pathRegexp = require("lor.lib.utils.path_to_regexp")
local debug = require("lor.lib.debug")
math.randomseed(os.time())

local function is_table_empty(t)
    if t == nil or _G.next(t) == nil then
        return true
    else
        return false
    end
end

local function mixin(a, b)
    if a and b then
        for k, v in pairs(b) do
            a[k] = b[k]
        end
    end
    return a
end

local function random()
    return math.random(0, 1000)
end

local function doAfterError(err)
    print("---------------------------------------- TRACK BEGIN ----------------------------------------");
    print("LUA XPCALL ERROR:", err);
    print("---------------------------------------- TRACK  END  ----------------------------------------");
    return false;
end



local Layer = {}

function Layer:new(path, options, fn, fn_args_length)
    local opts = options or {}
    local instance = {}
    instance.handle = fn
    instance.name = random() -- path -- "default_fn_name" --fn and fn.name and (fn.name or '<anonymous>')
    instance.params = {}
    instance.path = nil
    instance.keys = {}
    instance.length = fn_args_length -- todo:shoule only be 3 or 4
    instance.regexp = {}
    local tmp_pattern = pathRegexp.parse_pattern(path, instance.keys, opts)
    if tmp_pattern == "" or not tmp_pattern then
        instance.regexp.pattern = "/"
    else
        instance.regexp.pattern = tmp_pattern
    end

    debug("layer.lua#new - ", "fn_args_len:", fn_args_length, "\tname:", instance.name, "\tpath:", path, "\tpattern:", instance.regexp.pattern)


    setmetatable(instance, { __index = self })
    return instance
end


function Layer:handle_error(error, req, res, next)
    --print("layer.lua - Layer:handle_error", "error:", error)
    local fn = self.handle
    -- fn should pin a property named 'length' to indicate its args length
    if self.length ~= 4 then
        debug("not match handle_error")
        next(error)
        return
    end

    local ok, e = pcall(function() fn(error, req, res, next) end)
    --print(random() .. "  layer.lua - Layer:handle_error", "ok?", ok, "error:", e, "pcall_error:", e, "layer.name:", self.name)

    if not ok then
        next(e)
    end
end


function Layer:handle_request(req, res, next)
    local fn = self.handle
    if self.length > 3 then
        debug("---------->not match handle_request")
        next()
        return
    end

    --local trackId = random()
    --debug(trackId .. "  layer.lua - Layer:handle_request+", "layer.name:", self.name, "middle_type:", self.length)
    local ok, e = pcall(function() fn(req, res, next) end);
    --debug(trackId .. "  layer.lua - Layer:handle_request-", "ok?", ok, "error:", e, "layer.name:", self.name, "middle_type:", self.length)

    if not ok then
        --debug("handle_request:pcall error", ok, e)
        next(e)
    end
end

-- req's fullpath
function Layer:match(path)
    debug("layer.lua#match before:", "path:", path, "pattern:", self.regexp.pattern,  "fast_slash:", self.regexp.fast_slash)
    if not path then
        self.params = nil
        self.path = nil
        debug("layer.lua#match 1")
        return false
    end


    local match_or_not = pathRegexp.is_match(path, self.regexp.pattern)
    if not match_or_not then
        debug("layer.lua#match 3")
        return false
    end


    local m = pathRegexp.parse_path(path, self.regexp.pattern, self.keys)
    if m then
        debug("layer.lua#match 4", path, self.regexp.pattern, self.keys, m)
    end

    -- store values
    self.path = path
    self.params = mixin( m, self.params) -- this is only this layer's params


--    debug(function()
--        print("layer.lua# print layer.params")
--        if self.params then
--            for i, v in pairs(self.params) do
--                print(i, v)
--            end
--        end
--    end)

    return true
end





return Layer