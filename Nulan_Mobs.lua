dofile(GetInfo(60) .. "aardwolf_colors.lua")

hunter_room_id = 38000
hunter_run_timout_seconds = 15

bag_id_var_name = "nulan_var_bag_id"
keep_tokens_var_name = "nulan_var_keep_tokens"
debug_mode_var_name = "exits_var_debug_mode"

bag_id = GetVariable(bag_id_var_name) or ""
keep_tokens = tonumber(GetVariable(keep_tokens_var_name)) or 1
debug_mode = tonumber(GetVariable(debug_mode_var_name)) or 0

running_to_hunter = false
current_mob = ""
current_token = ""
current_index = ""

--
-- Create Lookup Tables
--

token_to_mobs = {
	["token eagle feather"] = {
		["booted eagle"] = 1,
		["solitary eagle"] = 2,
		["eagle"] = 3
	},
	["token songbird feather"] = {
		["colorful robin"] = 1,
		["eating finch"] = 2,
		["dull robin"] = 3,
		["finch"] = 4
	},
	["token grouse feather"] = {
		["male sharp-tailed grouse"] = 1,
		["female sharp-tailed grouse"] = 2
	},
	["prairie dog fur token"] = {
		["prairie dog puppy"] = 1,
		["alert prairie dog"] = 2,
		["playful prairie dog"] = 3,
		["playful prairie dog puppy"] = 4,
		["hungry prairie dog"] = 5,
		["prairie dog"] = 6
	},
	["token badger fur"] = {
		["grumpy badger"] = 1
	},
	["token wolf tooth"] = {
		["wolf pup"] = 1,
		["spotted grey wolf"] = 2,
		["pure white wolf"] = 3,
		["grey wolf"] = 4,
		["black wolf"] = 5,
		["male alpha wolf"] = 6,
		["female alpha wolf"] = 7
	},
	["token owl feather"] = {
		["male horned owl"] = 1,
		["hunting horned owl"] = 2,
		["female horned owl"] = 3,
		["lonely horned owl"] = 4
	},
	["token deer mouse tail"] = {
		["brown deer mouse"] = 1,
		["timid deer mouse"] = 2,
		["adorable deer mouse"] = 3,
		["shy deer mouse"] = 4,
		["angry deer mouse"] = 5
	}
}

mob_to_token = {}

for token, mobs in pairs(token_to_mobs) do
	for mob, index in pairs(mobs) do
		mob_to_token[mob] = token
	end
end

--
-- Plugin Methods
--

local plugin_id_gmcp_handler = "3e7dedbe37e44942dd46d264"

function OnPluginBroadcast(msg, id, name, text)
	if (id == plugin_id_gmcp_handler) then
		if (text == "room.info") then
			on_room_info_update(gmcp("room.info"))
		end
	end
end

function OnPluginInstall()
	init_plugin()
end

function OnPluginConnect()
	init_plugin()
end

function OnPluginEnable()
	init_plugin()
end

function init_plugin()
	Message("Enabled Plugin")
	on_room_info_update(gmcp("room.info"))
end

function gmcp(s)
	local ret, datastring = CallPlugin(plugin_id_gmcp_handler, "gmcpdata_as_string", s)
	pcall(loadstring("data = " .. datastring))
	return data
end

--
-- Alias methods
--

function alias_set_bag_id(name, line, wildcards)
	local new_bag_id = Trim(wildcards.bag)

	if new_bag_id == "" then
		new_bag_id = ""
		Message("@WItems will no longer be stored in a bag")
	else
		Message("@WItems will now be automatically stored in the bag @Y" .. new_bag_id)
	end
	SetVariable(bag_id_var_name, new_bag_id)
	bag_id = new_bag_id
end

function alias_set_keep_tokens(name, line, wildcards)
	local new_keep_tokens = Trim(wildcards.keep)

	if new_keep_tokens == "" then
		if keep_tokens == 1 then
			new_keep_tokens = 0
		else
			new_keep_tokens = 1
		end
	else
		new_keep_tokens = string.lower(new_keep_tokens)
		if new_keep_tokens == "1" or new_keep_tokens == "true" then
			new_keep_tokens = 1
		else
			new_keep_tokens = 0
		end
	end

	if new_keep_tokens == 0 then
		Message("@WItems will no longer be automatically kept")
	else
		Message("@WItems will now automatically be kept")
	end
	SetVariable(nulan_var_keep_tokens, new_keep_tokens)
	keep_tokens = new_keep_tokens
end

function alias_set_debug_mode(name, line, wildcards)
	local new_debug_mode = -1

	if debug_mode == 1 then
		new_debug_mode = 0
	else
		new_debug_mode = 1
	end

	if new_debug_mode == 0 then
		Message("@WDisabled debug logs")
	else
		Message("@WEnabled debug logs")
	end
	SetVariable(debug_mode_var_name, new_debug_mode)
	debug_mode = new_debug_mode
end

function alias_options(name, line, wildcards)
	local options_bag_id = bag_id
	if options_bag_id == "" then
		options_bag_id = "@RNot Set"
	else
		options_bag_id = "@G" .. options_bag_id
	end
	local options_keep_items = "@RNo"
	if keep_tokens then
		options_keep_items = "@GYes"
	end

	Message(string.format([[@WCurrent options:@w

  @WBag Id:      @w(%s@w)
  @WKeep Items:  @w(%s@w)]], options_bag_id, options_keep_items))
end

function clean_mob_name(mob)
	mob = Trim(mob)
	mob = string.lower(mob)
	mob = string.gsub(mob, "^an ", "")
	mob = string.gsub(mob, "^a ", "")
	return mob
end

function alias_check_mob(name, line, wildcards)
	local mob = clean_mob_name(wildcards.mob)
	if mob == "" then
		Message("@WYou must specify a mob name. @C[@Gusage:@W nulan check @Ymob@C]")
		return
	end

	token = mob_to_token[mob]
	if token == nil then
		Message(string.format("@WFailed to find mob with name '@Y%s@W'", mob))
		return
	end

	index = token_to_mobs[token][mob]
	if index == nil then
		Message(string.format("@WFailed to find index for mob with name '@Y%s@W'", mob))
		return
	end

	Message(string.format("@WResult for '@Y%s@W' @C[@Gitem:@W '@Y%s@W'@C] [@Gnumber:@W @Y%s@C]", mob, token, index))

	running_to_hunter = false
	current_mob = ""
	current_token = ""
	current_index = ""
end

function alias_get_mob(name, line, wildcards)
	local mob = clean_mob_name(wildcards.mob)
	if mob == "" then
		Message("@WYou must specify a mob name. @C[@Gusage:@W nulan get @Ymob@C]")
		return
	end

	token = mob_to_token[mob]
	if token == nil then
		Message(string.format("@WFailed to find mob with name '@Y%s@W'", mob))
		return
	end

	index = token_to_mobs[token][mob]
	if index == nil then
		Message(string.format("@WFailed to find index for mob with name '@Y%s@W'", mob))
		return
	end

	running_to_hunter = false
	current_mob = mob
	current_token = token
	current_index = index

	Message(string.format("@WResult for '@Y%s@W' @C[@Gitem:@W '@Y%s@W'@C] [@Gnumber:@W @Y%s@C]", mob, token, index))

	if is_at_hunter() then
		get_mob()
		return
	end

	-- Run to the Hunter
	Message("@WRunning to Nulan Hunter")
	running_to_hunter = true
	Execute("mapper goto " .. hunter_room_id)
	DoAfterSpecial(hunter_run_timout_seconds, [[ check_running_to_hunter() ]], sendto.script)
end

function alias_help(name, line, wildcards)
	Message([[@WCommands:@w

  @Wnulan help                @w- Print out this help message
  @Wnulan update              @w- Updates to the latest version of the plugin
  @Wnulan reload              @w- Reloads the plugin
  @Wnulan options             @w- Print out the plugin options
  @Wnulan set bag @Ybag_id      @w- Sets the bag to retrieve and store items from
  @Wnulan set keep            @w- Toggles automatically keeping items
  @Wnulan check @Ymob           @w- Prints out details on how to get a mob
  @Wnulan get @Ymob             @w- Runs to the Nulan Hunter and gets the mob specified

  @Wnulan debug               @w- Toggles debug logs
  @Wnulan force update @Ybranch @w- Force updates to the branch specified]])
end

--
-- Hunter Methods
--

function is_at_hunter()
	return room_id == hunter_room_id
end

function on_at_hunter()
	if running_to_hunter then
		get_mob()
	end
end

function check_running_to_hunter()
	if running_to_hunter then
		Message("@WTimed out running to hunter")
		running_to_hunter = false
		current_mob = ""
		current_token = ""
		current_index = ""
	end
end

function get_mob()
	running_to_hunter = false

	if bag_id ~= "" then
		Execute("get '" .. current_token .. "' " .. bag_id)
	end

	if keep_tokens then
		Execute("unkeep '" .. current_token .. "'")
	end

	Execute("give '" .. current_token .. "' hunter")

	-- Wait before sending say
	DoAfterSpecial(0.5, [[ get_mob_say_index() ]], sendto.script)
end

function get_mob_say_index()
	Execute("say " .. current_index)

	-- Wait before trying to put items back away in a bag
	DoAfterSpecial(0.5, [[ get_mob_put_item_away() ]], sendto.script)
end

function get_mob_put_item_away()
	if keep_tokens then
		Execute("keep '" .. current_token .. "'")
	end

	if bag_id ~= "" then
		Execute("put '" .. current_token .. "' " .. bag_id)
	end

	running_to_hunter = false
	current_mob = ""
	current_token = ""
	current_index = ""
end

--
-- Room Methods
--

room_id = 0

function on_room_info_update(room_info)
	room_id = tonumber(room_info.num)

	if is_at_hunter() then
		on_at_hunter()
	end
end

--
-- Print methods
--

function Message(str)
	AnsiNote(stylesToANSI(ColoursToStyles(string.format("\n@C[@GNulan@C] %s@w\n", str))))
end

function Debug(str)
	if debug_mode == 1 then
		Message(string.format("@gDEBUG@w %s", str))
	end
end

function Error(str)
	Message(string.format("@RERROR@w %s", str))
end

--
-- Update code
--

async = require "async"

local version_url = "https://raw.githubusercontent.com/AardPlugins/Aardwolf-Nulan-Mobs/refs/heads/main/VERSION"
local plugin_base_url = "https://raw.githubusercontent.com/AardPlugins/Aardwolf-Nulan-Mobs/refs"
local plugin_files = {
	{
		remote_file = "Nulan_Mobs.xml",
		local_file =  GetPluginInfo(GetPluginID(), 6),
		update_page= ""
	},
	{
		remote_file = "Nulan_Mobs.lua",
		local_file =  GetPluginInfo(GetPluginID(), 20) .. "Nulan_Mobs.lua",
		update_page= ""
	}
}
local download_file_index = 0
local download_file_branch = ""
local plugin_version = GetPluginInfo(GetPluginID(), 19)

function download_file(url, callback)
	Debug("Starting download of " .. url)
	-- Add timestamp as a query parameter to bust cache
	url = url .. "?t=" .. GetInfo(304)
	async.doAsyncRemoteRequest(url, callback, "HTTPS")
end

function alias_reload_plugin(name, line, wildcards)
	Message("Reloading plugin")
	reload_plugin()
end

function alias_update_plugin(name, line, wildcards)
	Debug("Checking version to see if there is an update")
	download_file(version_url, check_version_callback)
end

function check_version_callback(retval, page, status, headers, full_status, request_url)
	if status ~= 200 then
		Error("Error while fetching latest version number")
		return
	end

	local upstream_version = Trim(page)
	if upstream_version == tostring(plugin_version) then
		Message("@WNo new updates available")
		return
	end

	Message("@WUpdating to version " .. upstream_version)

	local branch = "tags/v" .. upstream_version
	download_plugin(branch)
end

function alias_force_update_plugin(name, line, wildcards)
	local branch = "main"

	if wildcards.branch ~= "" then
		branch = wildcards.branch
	end

	Message("@WForcing updating to branch " .. branch)

	branch = "heads/" .. branch
	download_plugin(branch)
end

function download_plugin(branch)
	Debug("Downloading plugin branch " .. branch)
	download_file_index = 0
	download_file_branch = branch

	download_next_file()
end

function download_next_file()
	download_file_index = download_file_index + 1

	if download_file_index > #plugin_files then
		Debug("All plugin files downloaded")
		finish_update()
		return
	end

	local url = string.format("%s/%s/%s", plugin_base_url, download_file_branch, plugin_files[download_file_index].remote_file)
	download_file(url, download_file_callback)
end

function download_file_callback(retval, page, status, headers, full_status, request_url)
	if status ~= 200 then
		Error("Error while fetching the plugin")
		return
	end

	plugin_files[download_file_index].update_page = page

	download_next_file()
end

function finish_update()
	Message("@WUpdating plugin. Do not touch anything!")

	-- Write all downloaded files to disk
	for i, plugin_file in ipairs(plugin_files) do
		local file = io.open(plugin_file.local_file, "w")
		file:write(plugin_file.update_page)
		file:close()
	end

	reload_plugin()

	Message("@WUpdate complete!")
end

function reload_plugin()
	if GetAlphaOption("script_prefix") == "" then
		SetAlphaOption("script_prefix", "\\\\\\")
	end
	Execute(
		GetAlphaOption("script_prefix") .. 'DoAfterSpecial(0.5, "ReloadPlugin(\'' .. GetPluginID() .. '\')", sendto.script)'
	)
end
