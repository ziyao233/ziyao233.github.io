--[[
	Blog
	File:/Template.lua
	By MIT License.
	Copyright (c) 2021-2022 Ziyao.All rights reserved.
	From Mixol
]]

local string	= require("string");
local math	= require("math");
local io	= require("io");


local templateProtoType = {};
local templateMeta = {
			__index = templateProtoType,
		     };

local Template = function(path)
	local file = assert(io.open(path,"r"));

	local tplSrc = file:read("a");

	file:close();
	local tpl = {
			src = tplSrc,
		    };

	return setmetatable(tpl,templateMeta);
end

templateProtoType.replace = function(self,arg)
	local env = {
			tpl	= {
					arg	= arg,
				  },
		    };
	setmetatable(env,{__index = _G,});

	return string.gsub(self.src,"$(=*)$(.-)$%1%$",
			   function(_equals,code)
			   	env.tpl.result = {};
				load(code,"Code in template","t",env)();
				local result = table.concat(env.tpl.result);
				return result;
			   end
			  );
end

return {
	Template = Template
       };
