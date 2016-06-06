
--[[
"maptools:copper_coin"
"maptools:silver_coin"
"maptools:gold_coin"

100 pc = 1pa, 100pa = 1po
--]]

local convertion = { ["maptools:copper_coin"]=1, ["maptools:silver_coin"]=9, ["maptools:gold_coin"]=81}

local function get_bancomatic_formspec(pos, name)
	local spos = pos.x .. "," .. pos.y .. "," .. pos.z
	local formspec =
		"size[8,9]label[3.35,0;Bancomatic]" ..
		"label[0,0;Your money:"..minercantile.wallet.get_money(name).."$]" ..
		"label[2,1;Put your coins to convert on your wallet]" ..
		
		"image[0,1.5;1,1;maptools_gold_coin.png]" ..
		"label[1,1.7;= "..convertion["maptools:gold_coin"].."$]" ..
		"image[0,2.5;1,1;maptools_silver_coin.png]" ..
		"label[1,2.7;= "..convertion["maptools:silver_coin"].."$]" ..
		"image[0,3.5;1,1;maptools_copper_coin.png]" ..
		"label[1,3.7;= "..convertion["maptools:copper_coin"].."$]" ..
		
		"list[nodemeta:" .. spos .. ";main;3.5,2.5;1,1;]" ..
		"list[current_player;main;0,4.85;8,1;]" ..
		"list[current_player;main;0,6.08;8,3;8]" ..
		"listring[nodemeta:" .. spos .. ";main]" ..
		"listring[current_player;main]" --..
		--default.get_hotbar_bg(0,4.85)
	return formspec
end



--change money.
minetest.register_node("minercantile:bancomatic", {
	description = "Bancomatic",
	tiles = {
		"minercantile_bancomatic_back.png",
		"minercantile_bancomatic_back.png",
		"minercantile_bancomatic_side.png",
		"minercantile_bancomatic_side.png",
		"minercantile_bancomatic_back.png",
		"minercantile_bancomatic_front.png",
	},
	--top, bottom, right, left, back, front
	paramtype2 = "facedir",
	--groups = {choppy = 2, oddly_breakable_by_hand = 2},
	groups = {snappy=2, choppy=2, oddly_breakable_by_hand=2},
	legacy_facedir_simple = true,
	is_ground_content = false,
	sounds = default.node_sound_wood_defaults(),
	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		meta:set_string("infotext", "Bancomatic")
		local inv = meta:get_inventory()
		inv:set_size("main", 1 * 1)
	end,
	can_dig = function(pos,player)
		local name = player:get_player_name()
		return (minetest.check_player_privs(name, {protection_bypass = true}) or minetest.check_player_privs(name, {server = true}))
	end,
	allow_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
		return 0
	end,
    allow_metadata_inventory_put = function(pos, listname, index, stack, player)
		local item = stack:get_name()
		if item == "maptools:copper_coin" or item == "maptools:silver_coin" or item == "maptools:gold_coin" then
			return stack:get_count()
		end
		return 0
	end,
    allow_metadata_inventory_take = function(pos, listname, index, stack, player)
		return 0
	end,
    on_metadata_inventory_put = function(pos, listname, index, stack, player)
		local item = stack:get_name()
		if item == "maptools:copper_coin" or item == "maptools:silver_coin" or item == "maptools:gold_coin" then
			local name = player:get_player_name()
			local meta = minetest.get_meta(pos)
			local inv = meta:get_inventory()
			local nb = stack:get_count()
			local amount = convertion[item]*nb
			minercantile.wallet.give_money(name, amount)
			inv:set_stack(listname, index, nil)
			minetest.log("action", player:get_player_name() .. " put " .. stack:get_name() .. " to bancomatic at " .. minetest.pos_to_string(pos))
			minetest.show_formspec(name, "minercantile:bancomatic", get_bancomatic_formspec(pos, name))
		end
	end,
    on_metadata_inventory_take = function(pos, listname, index, stack, player)
	end,
	on_rightclick = function(pos, node, clicker)
		minetest.show_formspec(clicker:get_player_name(), "minercantile:bancomatic", get_bancomatic_formspec(pos, clicker:get_player_name()))
	end,
	on_blast = function() end,
})


--nodes 
minetest.register_craft({
	output = "minercantile:bancomatic",
	recipe = {
		{"default:wood", "default:mese", "default:wood"},
		{"default:wood", "default:mese", "default:wood"},
		{"default:wood", "default:mese", "default:wood"},
	},
})
