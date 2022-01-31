#!/usr/bin/env lua

--[[
	Generate the website
	A normal Lua 5.4(or newer) Distribution
		with io.popen support is needed.
	By MIT License.
	Copyright(c) 2022 Suote127.All rights reserved.
]]

local io		= require("io");
local string		= require("string");
local os		= require("os");
local table		= require("table");

local modTemplate	= require("Template");

local gListFileName <const>	= "ArticleList.lua";
local gIndexTplName <const>	= "index.tpl.html";
local gArtTplName <const>	= "Article.tpl.html";
local gOutputDir <const>	= "./output/";
local gSrcDir <const>		= "./src/";

local listFile = assert(io.open(gListFileName,"r"),
			"Cannot open article list file");
local list = load("return " .. listFile:read("a"))();
listFile:close();
--[[
	This file should be like:
	{
		{
			name:	"hello_world",
			title:	"Hello World",
			date:	"2022-01-29"
		},
		...
	}
]]

--[[	Load templates	]]

local indexTpl = modTemplate.Template(gIndexTplName);
local articleTpl = modTemplate.Template(gArtTplName);

--[[	Spawn the reserved list	and preprocess	]]
local tmp = {}
local target = {};
for _,article in pairs(list)
do
	tmp[article.name] = article;
	local year,month,day = string.match(article.date,
					    "(%d%d%d%d)%-(%d%d)-(%d%d)");
	year,month,day = tonumber(year),tonumber(month),tonumber(day);
	article.time = os.time({
				year	= year,
				month	= month,
				day	= day,
			       });
	table.insert(target,article.name);
end
local nativeList = list;
list = tmp;
tmp = nil;

--[[	Generate only the specific article	]]
if arg[1]
then
	target = {arg[1]};
end

--[[	Generate articles	]]
print("Generating articles");
print(string.format("%d needs generating",
		    #target));
for _,name in pairs(target)
do
	-- Logging
	io.write(string.format("Generating %s...",name));

	--[[	Convert Markdown with md2html	]]
	local pipe = io.popen(string.format(
	[[
		/usr/bin/env md2html %s%s.md
	]],
					    gSrcDir,
					    name),
			      "r");

	local htmlSrc = pipe:read("a");
	pipe:close();

	--[[	Template replacement	]]
	local tplArg = {
				title	= list[name].title,
				content = htmlSrc,
				date	= list[name].date,
		       };
	local resultHtml = articleTpl:replace(tplArg);
	local path = string.format("%s%s.html",gOutputDir,name);
	local outputFile = io.open(path,"w");
	assert(outputFile,"Cannot open output file " .. path);
	outputFile:write(resultHtml);
	outputFile:close();

	-- Logging
	print("Done");

	list[name].path = path;
end

--[[	Generate the mainpage "index.html"	]]
table.sort(nativeList,function(a1,a2)
				return a1.date > a2.date;
		      end
	  );

io.write("Generating index.html...");
local resultHtml	= indexTpl:replace(nativeList);
local indexPath		= string.format("%sindex.html",
					gOutputDir);
local outputIndex	= io.open(indexPath,"w");
outputIndex:write(resultHtml);
print("Done");
