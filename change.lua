
local coins_convert = {
	["minercantile:copper_coin"]=1, ["minercantile:silver_coin"]=100, ["minercantile:gold_coin"]=10000,
	["maptools:copper_coin"]=1, ["maptools:silver_coin"]=100, ["maptools:gold_coin"]=10000,
}


--if maptools then use maptools coins else use minercantile coins
if minetest.get_modpath("maptools") ~= nil then
	minetest.override_item("maptools:copper_coin", {
		inventory_image = "minercantile_copper_coin.png",
	})

	minetest.override_item("maptools:silver_coin", {
		inventory_image = "minercantile_silver_coin.png",
	})

	minetest.override_item("maptools:gold_coin", {
		inventory_image = "minercantile_gold_coin.png",
	})
else
	minetest.register_craftitem("minercantile:copper_coin", {
		description = "Copper Coin",
		inventory_image = "minercantile_copper_coin.png",
		wield_scale = {x = 0.5, y = 0.5, z = 0.25},
		stack_max = 10000,
		groups = {not_in_creative_inventory = 0},
	})

	minetest.register_craftitem("minercantile:silver_coin", {
		description = "Silver Coin",
		inventory_image = "minercantile_silver_coin.png",
		wield_scale = {x = 0.5, y = 0.5, z = 0.25},
		stack_max = 10000,
		groups = {not_in_creative_inventory = 0},
	})

	minetest.register_craftitem("minercantile:gold_coin", {
		description = "Gold Coin",
		inventory_image = "minercantile_gold_coin.png",
		wield_scale = {x = 0.5, y = 0.5, z = 0.25},
		stack_max = 10000,
		groups = {not_in_creative_inventory = 0},
	})

	minetest.register_alias("maptools:copper_coin", "minercantile:copper_coin")
	minetest.register_alias("maptools:silver_coin", "minercantile:silver_coin")
	minetest.register_alias("maptools:gold_coin", "minercantile:gold_coin")
end


local function get_bancomatic_formspec(pos, name)
	local spos = pos.x .. "," .. pos.y .. "," .. pos.z
	local formspec =
		"size[8,9]bgcolor[#2A2A2A;]label[3.35,0;Bancomatic]" ..
		"label[0,0;Your money:"..minercantile.wallet.get_money(name).."$]" ..
		"label[2,1;Put your coins to convert on your wallet]" ..

		"image[0,1.5;1,1;minercantile_gold_coin.png]" ..
		"label[1,1.7;= "..coins_convert["minercantile:gold_coin"].."$]" ..
		"image[0,2.5;1,1;minercantile_silver_coin.png]" ..
		"label[1,2.7;= "..coins_convert["minercantile:silver_coin"].."$]" ..
		"image[0,3.5;1,1;minercantile_copper_coin.png]" ..
		"label[1,3.7;= "..coins_convert["minercantile:copper_coin"].."$]" ..

		"list[nodemeta:" .. spos .. ";main;3.5,2.5;1,1;]" ..
		"list[current_player;main;0,4.85;8,1;]" ..
		"list[current_player;main;0,6.08;8,3;8]" ..
		"listring[nodemeta:" .. spos .. ";main]" ..
		"listring[current_player;main]" --..
		--default.get_hotbar_bg(0,4.85)
	return formspec
end


--change money. code based on atm from https://github.com/minetest-mods/global_exchange
minetest.register_node("minercantile:bancomatic_bottom", {
	description = "Bancomatic",
	inventory_image = "minercantile_bancomatic_front.png",
	wield_image = "minercantile_bancomatic_front.png",
	drawtype = "nodebox",
	tiles = {
		"minercantile_bancomatic_back.png",
		"minercantile_bancomatic_back.png",
		"minercantile_bancomatic_back.png",
		"minercantile_bancomatic_back.png",
		"minercantile_bancomatic_back.png",
		"minercantile_bancomatic_back.png",
	},
	paramtype = "light",
	paramtype2 = "facedir",
	is_ground_content = false,
	light_source = 3,
		groups = {cracky=2, atm = 1},
	node_box = {
		type = "fixed",
		fixed = {
		{-0.5, -0.5, -0.5, 0.5, 0.5, 0.5},
		}
	},
	selection_box = {
		type = "fixed",
		fixed = {
			{-0.5, -0.5, -0.5, 0.5, 0.5, 0.5},
			{-0.5, 0.5, -0.5, -0.375, 1.125, -0.25},
			{0.375, 0.5, -0.5, 0.5, 1.125, -0.25},
			{-0.5, 0.5, -0.25, 0.5, 1.5, 0.5},
			{-0.5, 1.125, -0.4375, -0.375, 1.25, -0.25},
			{0.375, 1.125, -0.4375, 0.5, 1.25, -0.25},
			{-0.5, 1.25, -0.375, -0.375, 1.375, -0.25},
			{0.375, 1.25, -0.375, 0.5, 1.375, -0.25},
			{-0.5, 1.375, -0.3125, -0.375, 1.5, -0.25},
			{0.375, 1.375, -0.3125, 0.5, 1.5, -0.25},
		},
	},
	on_place = function(itemstack, placer, pointed_thing)
		local under = pointed_thing.under
		local pos
		if minetest.registered_items[minetest.get_node(under).name].buildable_to then
			pos = under
		else
			pos = pointed_thing.above
		end
		local def = minetest.registered_nodes[minetest.get_node(pos).name]
		if not def or not def.buildable_to then
			minetest.remove_node(pos)
			return itemstack
		end
		local dir = minetest.dir_to_facedir(placer:get_look_dir())
		local pos2 = {x = pos.x, y = pos.y + 1, z = pos.z}
		local def2 = minetest.registered_nodes[minetest.get_node(pos2).name]
		if not def2 or not def2.buildable_to then
			return itemstack
		end
		minetest.set_node(pos, {name = "minercantile:bancomatic_bottom", param2 = dir})
		minetest.set_node(pos2, {name = "minercantile:bancomatic_top", param2 = dir})
	end,
	on_destruct = function(pos)
		local pos2 = {x = pos.x, y = pos.y + 1, z = pos.z}
		local n2 = minetest.get_node(pos2)
		if minetest.get_item_group(n2.name, "atm") == 2 then
			minetest.remove_node(pos2)
		end
	end,
	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		meta:set_string("infotext", "Bancomatic")
		local inv = meta:get_inventory()
		inv:set_size("main", 1 * 1)
	end,
	can_dig = function(pos, player)
		local name = player:get_player_name()
		return (minetest.check_player_privs(name, {protection_bypass = true}) or minetest.check_player_privs(name, {shop = true}))
	end,
	allow_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
		return 0
	end,
	allow_metadata_inventory_put = function(pos, listname, index, stack, player)
		local itname = stack:get_name()
		if coins_convert[itname] ~= nil then
			return stack:get_count()
		end
		return 0
	end,
	allow_metadata_inventory_take = function(pos, listname, index, stack, player)
		return 0
	end,
	on_metadata_inventory_put = function(pos, listname, index, stack, player)
		local itname = stack:get_name()
		if coins_convert[itname] ~= nil then
			local name = player:get_player_name()
			local meta = minetest.get_meta(pos)
			local inv = meta:get_inventory()
			local nb = stack:get_count()
			local amount = coins_convert[itname]*nb
			minercantile.wallet.give_money(name, amount)
			inv:set_stack(listname, index, nil)
			minetest.log("action", player:get_player_name() .. " put " .. stack:get_name() .. " to bancomatic at " .. minetest.pos_to_string(pos))
			minetest.show_formspec(name, "minercantile:bancomatic", get_bancomatic_formspec(pos, name))
		end
	end,
	on_rightclick = function(pos, node, clicker)
		minetest.show_formspec(clicker:get_player_name(), "minercantile:bancomatic", get_bancomatic_formspec(pos, clicker:get_player_name()))
	end,
})


minetest.register_node("minercantile:bancomatic_top", {
	drawtype = "nodebox",
	tiles = {
		"minercantile_bancomatic_back.png",
		"minercantile_bancomatic_back.png",
		"minercantile_bancomatic_side.png",
		"minercantile_bancomatic_side.png",
		"minercantile_bancomatic_back.png",
		"minercantile_bancomatic_front.png",
	},
	paramtype = "light",
	paramtype2 = "facedir",
	is_ground_content = false,
	light_source = 3,
	node_box = {
		type = "fixed",
		fixed = {
			{-0.5, -0.5, -0.5, -0.375, 0.125, -0.25},
			{0.375, -0.5, -0.5, 0.5, 0.125, -0.25},
			{-0.5, -0.5, -0.25, 0.5, 0.5, 0.5},
			{-0.5, 0.125, -0.4375, -0.375, 0.25, -0.25},
			{0.375, 0.125, -0.4375, 0.5, 0.25, -0.25},
			{-0.5, 0.25, -0.375, -0.375, 0.375, -0.25},
			{0.375, 0.25, -0.375, 0.5, 0.375, -0.25},
			{-0.5, 0.375, -0.3125, -0.375, 0.5, -0.25},
			{0.375, 0.375, -0.3125, 0.5, 0.5, -0.25},
		}
	},
	selection_box = {
		type = "fixed",
		fixed = {0, 0, 0, 0, 0, 0},
	},
	groups = { atm = 2, not_in_creative_inventory = 1},
})
