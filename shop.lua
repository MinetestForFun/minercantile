local shop_sell = {} --formspec temporary variables
local shop_buy = {}
local shop_admin = {}

minercantile.shop.max_stock = 20000 --shop don't buy infinity items
--shop type, only if item name contains word
minercantile.shop.shop_type = {"General", "3d_armor", "Axe_", "Bag", "Beds", "Boats", "Brick", "Carts", "Chest", "Cobble", "Columnia", "Decor", "Dye", "Doors", "Farming", "Fence", "Fishing", "Food", "Glass", "Hoe", "Ingot", "Lump", "Mesecons", "Nether", "Pickaxe", "Pipeworks", "Runes", "Shield", "Shovel", "Sign", "Slab", "Spears", "Stair_", "Stone", "Sword", "Throwing", "Tree", "Walls", "Wood", "Wool"}


--function shop money
function minercantile.shop.get_money()
	return (minercantile.stock.money or 0)
end

function minercantile.shop.take_money(money, saving)
	minercantile.stock.money = minercantile.shop.get_money() - money
	if minercantile.shop.get_money() < 0 then
		minercantile.stock.money = 0
	end
	if saving then
		minercantile.save_stock()
	end
end

function minercantile.shop.give_money(money, saving)
	minercantile.stock.money = minercantile.shop.get_money() + money
	if saving then
		minercantile.save_stock()
	end
end

function minercantile.shop.get_nb(itname)
	if minercantile.stock.items[itname] then
		return minercantile.stock.items[itname].nb
	end
	return 0
end

function minercantile.shop.get_transac_b()
	return minercantile.stock.transac_b
end

function minercantile.shop.get_transac_s()
	return minercantile.stock.transac_s
end


function minercantile.shop.set_transac_b()
	minercantile.stock.transac_b = minercantile.stock.transac_b + 1
end

function minercantile.shop.set_transac_s()
	minercantile.stock.transac_s = minercantile.stock.transac_s + 1
end

function minercantile.shop.is_available(itname)
	if minercantile.registered_items[itname] then
		return true
	end
	return false
end

function minercantile.shop.get_item_def(itname)
	if minercantile.registered_items[itname] then
		return minercantile.registered_items[itname]
	end
	return nil
end

-- table of sellable/buyable items,ignore admin stuff
function minercantile.shop.register_items()
	minercantile.registered_items = {}
	for itname, def in pairs(minetest.registered_items) do
		if not itname:find("maptools:") --ignore maptools
		and not itname:find("_coin")
		and not def.groups.not_in_creative_inventory
		and not def.groups.unbreakable
		and (def.description and def.description ~= "") then
			minercantile.registered_items[itname] = {groups = def.groups, desc = def.description}
		end
	end
	minercantile.shop.register_whitelist()
end


function minercantile.shop.register_whitelist()
	for _, itname in pairs(minercantile.shop.items_whitelist) do
		local def = minetest.registered_items[itname]
		if def then
			minercantile.registered_items[itname] = {groups = def.groups, desc = def.description}
		end
	end
end


function minercantile.shop.add_item(itname, nb)
	if minercantile.shop.is_available(itname) then
		if not minercantile.stock.items[itname] then
			minercantile.stock.items[itname] = {nb=0}
		end
		minercantile.stock.items[itname].nb = minercantile.stock.items[itname].nb + nb
		minercantile.save_stock()
	end
end

function minercantile.shop.del_item(itname, nb)
	if minercantile.shop.is_available(itname) then
		if not minercantile.stock.items[itname] then
			minercantile.stock.items[itname] = {nb=0}
		end
		minercantile.stock.items[itname].nb = minercantile.stock.items[itname].nb - nb
		if minercantile.stock.items[itname].nb < 0 then
			minercantile.stock.items[itname].nb = 0
		end
		minercantile.save_stock()
	end
end


--function save items_base
function minercantile.save_stock_base()
	local input, err = io.open(minercantile.file_stock_base, "w")
	if input then
		input:write(minetest.serialize(minercantile.stock_base))
		input:close()
	else
		minetest.log("error", "open(" .. minercantile.file_stock_base .. ", 'w') failed: " .. err)
	end
end

--function load items_base from file
function minercantile.load_stock_base()
	local file = io.open(minercantile.file_stock_base, "r")
	if file then
		local data = minetest.deserialize(file:read("*all"))
		file:close()
		if data and type(data) == "table" then
			minercantile.stock_base = table.copy(data)
			if minercantile.stock_base.money then
				minercantile.stock.money = minercantile.stock_base.money
			end
			if minercantile.stock_base.items then
				for itname, def in pairs(minercantile.stock_base.items) do
					minercantile.stock.items[itname] = table.copy(def)
				end
			end
		end
	end
end

--function save stock items
function minercantile.save_stock()
	local input, err = io.open(minercantile.file_stock, "w")
	if input then
		input:write(minetest.serialize(minercantile.stock))
		input:close()
	else
		minetest.log("error", "open(" .. minercantile.file_stock .. ", 'w') failed: " .. err)
	end
end

--function load stock items from file
function minercantile.load_stock()
	local file = io.open(minercantile.file_stock, "r")
	if file then
		local data = minetest.deserialize(file:read("*all"))
		file:close()
		if data and type(data) == "table" then
			if data.money then
				minercantile.stock.money = data.money
			end
			if data.items then
				for itname, def in pairs(data.items) do
					minercantile.stock.items[itname] = table.copy(def)
				end
			end
			if data.transac_b then
				minercantile.stock.transac_b = data.transac_b
			end
			if data.transac_s then
				minercantile.stock.transac_s = data.transac_s
			end
		end
	end
end

--create list items for formspec (search/pages)
function minercantile.shop.set_items_buy_list(name, shop_type)
	shop_buy[name] = {page=1, search=""}
	shop_buy[name].items_type = {}
	for itname, def in pairs(minercantile.stock.items) do
		if minercantile.shop.is_available(itname) and def.nb > 0 then
			if shop_type == "General" or itname:find(string.lower(shop_type)) then
				table.insert(shop_buy[name].items_type, itname)
			end
		end
	end
	table.sort(shop_buy[name].items_type)
end


-- sell fonction
function minercantile.shop.get_buy_price(itname)
	local price = nil
	local money = minercantile.shop.get_money()
	if not minercantile.stock.items[itname] then
		minercantile.stock.items[itname] = {nb=0}
	end

	local nb = minercantile.stock.items[itname].nb
	if minercantile.stock.items[itname].price ~= nil then -- if defined price
		price = math.ceil(minercantile.stock.items[itname].price)
	else
		price = math.ceil((money/1000)/(math.log(nb+2000-99)*10)*1000000/(math.pow((nb+2000-99),(2.01))))
	end
	if price and price < 1 then price = 1 end
	return price
end


-- sell fonction
function minercantile.shop.get_sell_price(itname, wear)
	local price = nil
	local money = minercantile.shop.get_money()
	if not minercantile.stock.items[itname] then
		minercantile.stock.items[itname] = {nb=0}
	end

	local nb = minercantile.stock.items[itname].nb

	if minercantile.stock.items[itname].price ~= nil then -- if defined price
		price = math.floor(minercantile.stock.items[itname].price)
	else
		price = math.floor(((money/1000)/(math.log(nb+2000+99)*10)*1000000/(math.pow((nb+2000+99),(2.01))))+0.5)
	end

	if wear and wear > 0 then --calcul price with % wear, (0-65535)
		local pct = math.ceil(((65535-wear)*100)/65535)
		price = math.floor((price * pct)/100)
	end

	if price < 1 then price = 1 end
	return price
end


local function set_pages_by_search(name, search)
	shop_buy[name].page = 1
	shop_buy[name].search = minetest.formspec_escape(search)
	shop_buy[name].items_list = {}
	for _, itname in ipairs(shop_buy[name].items_type) do
		if minercantile.shop.get_nb(itname) > 0 then
			local item = minercantile.registered_items[itname]
			if item then
				if string.find(itname, search) or string.find(string.lower(item.desc), search) then
					table.insert(shop_buy[name].items_list, itname)
				end
			end
		end
	end
	table.sort(shop_buy[name].items_list)
end


local function get_shop_inventory_by_page(name)
	local page = shop_buy[name].page
	local search = shop_buy[name].search
	local nb_items, nb_pages
	local inv_list = {}
	if search ~= "" then
		nb_items = #shop_buy[name].items_list
		nb_pages = math.ceil(nb_items/32)
		if page > nb_pages then page = nb_pages end
		local index = (page*32)-32
		for i=1, 32 do
			local itname = shop_buy[name].items_list[index+i]
			if not itname then break end
			local nb = minercantile.shop.get_nb(itname)
			if nb > 0 then
				local price = minercantile.shop.get_buy_price(itname)
				if price and price > 0 then
					table.insert(inv_list, {name=itname, nb=nb, price=price})
				end
			end
		end
	else
		nb_items = #shop_buy[name].items_type
		nb_pages = math.ceil(nb_items/32)
		if page > nb_pages then page = nb_pages end
		local index = (page*32)-32
		for i=1, 32 do
			local itname = shop_buy[name].items_type[index+i]
			if itname then
				local nb = minercantile.shop.get_nb(itname)
				if nb > 0 then
					local price = minercantile.shop.get_buy_price(itname)
					if price and price > 0 then
						table.insert(inv_list, {name=itname, nb=nb, price=price})
					end
				end
			end
		end
	end
	shop_buy[name].nb_pages = nb_pages
	return inv_list
end


--buy
function minercantile.shop.buy(name, itname, nb, price)
	local player = minetest.get_player_by_name(name)
	if not player then return false end
	local player_inv = player:get_inventory()
	local shop_money = minercantile.shop.get_money()
	local player_money = minercantile.wallet.get_money(name)
	if player_money < 1 then
		minetest.show_formspec(name, "minercantile:confirmed", "size[6,3]bgcolor[#2A2A2A;]label[2.6,0;Shop]label[1,1;Sorry, you have not enough money]button[1.3,2.1;1.5,1;return_buy;Return]button_exit[3.3,2.1;1.5,1;close;Close]")
		return false
	end

	local items_nb = minercantile.stock.items[itname].nb
	if items_nb < 1 then
		minetest.show_formspec(name, "minercantile:confirmed", "size[6,3]bgcolor[#2A2A2A;]label[2.6,0;Shop]label[1,1;Sorry, shop have 0 item ".. itname.."]button[1.3,2.1;1.5,1;return_buy;Return]button_exit[3.3,2.1;1.5,1;close;Close]")
		return false
	end

	local item_can_sell = nb
	if items_nb < 4 then
		item_can_sell = 1
	elseif items_nb/4 < nb then
		item_can_sell = math.floor(items_nb/4)
	end

	local price_total = math.floor(item_can_sell * price)
	local player_can_buy = item_can_sell
	if player_money < price_total then
		player_can_buy = math.floor(player_money/price)
	end

	local sell_price = player_can_buy * price
	local stack = ItemStack(itname.." "..player_can_buy)
	--player_inv:room_for_item("main", stack)
	local nn = player_inv:add_item("main", stack)
	local count = nn:get_count()
	if count > 0 then
		minetest.spawn_item(player:getpos(), {name=itname, count=count, wear=0, metadata=""})
	end

	minercantile.stock.items[itname].nb = minercantile.stock.items[itname].nb - player_can_buy
	minercantile.shop.set_transac_b()
	minercantile.shop.give_money(sell_price, true)

	minercantile.wallet.take_money(name, sell_price, " Buy "..player_can_buy .." "..itname..", price "..sell_price)
	minetest.show_formspec(name, "minercantile:confirmed", "size[6,3]bgcolor[#2A2A2A;]label[2.6,0;Shop]label[1.3,0.8;You buy "..player_can_buy .." "..itname.."]label[1.3,1.3;price "..sell_price.."$]button[1.3,2.1;1.5,1;return_buy;Return]button_exit[3.3,2.1;1.5,1;close;Close]")
	return true
end


local function show_formspec_to_buy(name)
	local player = minetest.get_player_by_name(name)
	if not player or not shop_buy[name] then return end
	local formspec = {"size[13,10]bgcolor[#2A2A2A;]label[6,0;Buy Items]"}
	table.insert(formspec, "label[0,0;Your money:"..minercantile.wallet.get_money(name) .."$]")
	local inv_items = get_shop_inventory_by_page(name)
	table.insert(formspec, "label[0.8,1.4;Page: ".. shop_buy[name].page.." of ".. shop_buy[name].nb_pages.."]")
	if shop_buy[name].search ~= "" then
		table.insert(formspec, "label[3,1.4;Filter: ".. minetest.formspec_escape(shop_buy[name].search) .."]")
	end
	local x = 0.8
	local y = 2
	local j = 1
	for i=1, 32 do
		local item = inv_items[i]
		if item then
			table.insert(formspec, "item_image_button["..x..","..y..";1,1;"..item.name..";buttonchoice_"..item.name..";"..item.nb.."]")
			table.insert(formspec, "label["..(x)..","..(y+0.8)..";"..item.price.."$]")
		else
			table.insert(formspec, "image["..x..","..y..";1,1;minercantile_img_inv.png]")
		end
		x = x +1.5
		j = j +1
		if j > 8 then
			j = 1
			x = 0.8
			y = y + 1.6
		end
	end

	table.insert(formspec, "field[5.75,8.75;2.2,1;searchbox;;]")
	table.insert(formspec, "image_button[7.55,8.52;.8,.8;ui_search_icon.png;searchbutton;]tooltip[searchbutton;Search]")
	table.insert(formspec, "button[5.65,9.3;1,1;page_dec;<]")
	table.insert(formspec, "button[6.55,9.3;1,1;page_inc;>]")
	table.insert(formspec, "button_exit[11,9.3;1.5,1;choice;Close]")
	minetest.show_formspec(name, "minercantile:shop_buy",  table.concat(formspec))
end


local function get_formspec_buy_items(name)
	local itname = shop_buy[name].itname
	local max = shop_buy[name].max
	local nb = shop_buy[name].nb
	local price = shop_buy[name].price
	local formspec = {"size[8,6]bgcolor[#2A2A2A;]label[3.5,0;Buy Items]"}
	table.insert(formspec, "label[3.4,1;Stock:"..minercantile.shop.get_nb(itname).."]")
	table.insert(formspec, "item_image_button[3.6,1.5;1,1;"..itname..";buttonchoice_"..itname..";"..nb.."]")
	if minetest.registered_items[itname] and minetest.registered_items[itname].stack_max and minetest.registered_items[itname].stack_max == 1 then
		table.insert(formspec, "label[2.2,2.5;This item is being sold by 1 max]")
	else
		table.insert(formspec, "button[0.6,1.5;1,1;amount;-1]")
		table.insert(formspec, "button[1.6,1.5;1,1;amount;-10]")
		table.insert(formspec, "button[2.6,1.5;1,1;amount;-20]")
		table.insert(formspec, "button[4.6,1.5;1,1;amount;+20]")
		table.insert(formspec, "button[5.6,1.5;1,1;amount;+10]")
		table.insert(formspec, "button[6.6,1.5;1,1;amount;+1]")
	end
	table.insert(formspec, "label[3.2,3;Price:"..price.."$]")
	table.insert(formspec, "label[3.2,3.4;Amount:".. nb.." items]")
	table.insert(formspec, "label[3.2,3.8;Total:"..nb * price.."$]")
	table.insert(formspec, "button[3.3,5;1.5,1;confirm;Confirm]")
	table.insert(formspec, "button[0,0;1.5,1;abort;Return]")
	return table.concat(formspec)
end


-- sell
function minercantile.shop.player_sell(name)
	local player = minetest.get_player_by_name(name)
	if not player then return false end
	local player_inv = player:get_inventory()
	local shop_money = minercantile.shop.get_money()

	if shop_money < 4 then
		minetest.show_formspec(name, "minercantile:confirmed", "size[6,3]bgcolor[#2A2A2A;]label[2.6,0;Shop]label[1,1;Sorry, shop have not enough money]button[1.3,2.1;1.5,1;return_sell;Return]button_exit[3.3,2.1;1.5,1;close;Close]")
		return false
	end
	local item = shop_sell[name].item
	local index = item.index
	local nb = shop_sell[name].nb
	local price = shop_sell[name].price
	local stack = player_inv:get_stack("main", index)
	local itname = stack:get_name()
	local items_nb = stack:get_count()

	if itname ~= item.name or items_nb == 0 then
		minetest.show_formspec(name, "minercantile:confirmed", "size[6,3]bgcolor[#2A2A2A;]label[2.6,0;Shop]label[1.5,1;Sorry, You have 0 item ..".. itname.."]button[1.3,2.1;1.5,1;return_sell;Return]button_exit[3.3,2.1;1.5,1;close;Close]")
		return false
	end

	local item_can_sell = nb
	if items_nb < nb then
		item_can_sell = items_nb
	end

	local price_total = math.floor(item_can_sell * price)
	local shop_can_buy = item_can_sell
	if (shop_money/4) < price_total then
		shop_can_buy = math.floor((shop_money/4)/price)
	end

	if shop_can_buy == 0 then
		minetest.show_formspec(name, "minercantile:confirmed", "size[6,3]bgcolor[#2A2A2A;]label[2.6,0;Shop]label[1,1;Sorry, shop have not enough money]button[1.3,2.1;1.5,1;return_sell;Return]button_exit[3.3,2.1;1.5,1;close;Close]")
		return false
	end

	local taken = stack:take_item(shop_can_buy)
	local sell_price = math.floor((taken:get_count()) * price)
	player_inv:set_stack("main", index, stack)
	minercantile.stock.items[itname].nb = minercantile.stock.items[itname].nb + shop_can_buy
	minercantile.shop.set_transac_s()
	minercantile.shop.take_money(sell_price, true)

	minercantile.wallet.give_money(name, sell_price, " Sell "..shop_can_buy .." "..itname..", price "..sell_price)
	minetest.show_formspec(name, "minercantile:confirmed", "size[6,3]bgcolor[#2A2A2A;]label[2.6,0;Shop]label[1.3,0.8;You sell "..shop_can_buy .." "..itname.."]label[1.3,1.3;price "..sell_price.."$]button[1.3,2.1;1.5,1;return_sell;Return]button_exit[3.3,2.1;1.5,1;close;Close]")
	return true
end

local function get_wear_img(wear)
	local pct = math.floor(((65535-wear)*10)/65535)
	for i=9, 0, -1 do
		if pct == i then
			return "minercantile_wear_".. i ..".png"
		end
	end
	return nil
end

-- show sell formspec
local function show_formspec_to_sell(name)
	local player = minetest.get_player_by_name(name)
	if not player then return end
	local formspec = {"size[13,10]bgcolor[#2A2A2A;]label[6,0;Sell Items]"}
	table.insert(formspec, "label[0,0;Your money:"..minercantile.wallet.get_money(name) .."$]")
	local player_inv = player:get_inventory()
	shop_sell[name] = {}
	shop_sell[name].items = {}
	for i=1, player_inv:get_size("main") do
		local stack = player_inv:get_stack("main", i)
		if not stack:is_empty() then
			local itname = stack:get_name()
			if minercantile.shop.is_available(itname) and minercantile.shop.get_nb(itname) < minercantile.shop.max_stock then
				local nb = stack:get_count()
				local wear = stack:get_wear()
				local price = minercantile.shop.get_sell_price(itname, wear)
				if price and price > 0 then
					table.insert(shop_sell[name].items, {name=itname, nb=nb, price=price, index=i, wear=wear})
				end
			end
		end
	end
	local x = 0.8
	local y = 2
	local j = 1
	for i=1, 32 do
		local item = shop_sell[name].items[i]
		if item then
			table.insert(formspec, "item_image_button["..x..","..y..";1,1;"..item.name..";buttonchoice_"..i..";"..item.nb.."]")
			table.insert(formspec, "label["..(x)..","..(y+0.9)..";"..item.price.."$]")
			if item.wear and item.wear > 0 then
				local img = get_wear_img(item.wear)
				if img then
					table.insert(formspec, "image["..x..","..(y+0.1)..";1,1;"..img.."]")
				end
			end
		else
			table.insert(formspec, "image["..x..","..y..";1,1;minercantile_img_inv.png]")
		end
		x = x +1.5
		j = j + 1
		if j > 8 then
			j = 1
			x = 0.8
			y = y + 1.6
		end
	end
	table.insert(formspec, "button_exit[5.8,9.3;1.5,1;choice;Close]")
	minetest.show_formspec(name, "minercantile:shop_sell",  table.concat(formspec))
end


local function get_formspec_sell_items(name)
	local item = shop_sell[name].item
	local itname = item.name
	local index = shop_sell[name].index
	local max = shop_sell[name].max
	local nb = shop_sell[name].nb
	local price = minercantile.shop.get_sell_price(itname, item.wear)
	shop_sell[name].price = price
	local formspec = {"size[8,6]bgcolor[#2A2A2A;]label[3.5,0;Sell Items]"}
	table.insert(formspec, "item_image_button[3.6,1.5;1,1;"..itname..";buttonchoice_"..index..";"..nb.."]")
	if item.wear and item.wear > 0 then
		local img = get_wear_img(item.wear)
		if img then
			table.insert(formspec, "image[3.6,1.6;1,1;"..img.."]")
		end
	end

	if minetest.registered_items[itname] and minetest.registered_items[itname].stack_max and minetest.registered_items[itname].stack_max == 1 then
		table.insert(formspec, "label[2.2,2.5;This item is being sold by 1 max]")
	else
		table.insert(formspec, "button[0.6,1.5;1,1;amount;-1]")
		table.insert(formspec, "button[1.6,1.5;1,1;amount;-10]")
		table.insert(formspec, "button[2.6,1.5;1,1;amount;-20]")
		table.insert(formspec, "button[4.6,1.5;1,1;amount;+20]")
		table.insert(formspec, "button[5.6,1.5;1,1;amount;+10]")
		table.insert(formspec, "button[6.6,1.5;1,1;amount;+1]")
	end

	table.insert(formspec, "label[3.2,3;Price:"..price.."$]")
	table.insert(formspec, "label[3.2,3.4;Amount:".. nb.." items]")
	table.insert(formspec, "label[3.2,3.8;Total:"..nb * price.."$]")
	table.insert(formspec, "button[3.3,5;1.5,1;confirm;Confirm]")
	table.insert(formspec, "button[0,0;1.5,1;abort;Return]")
	return table.concat(formspec)
end


local function get_formspec_welcome(name)
	local formspec = {"size[6,5]bgcolor[#2A2A2A;]label[2.6,0;Shop]"}
		table.insert(formspec, "image[1,1;5,1.25;minercantile_shop_welcome.png]")
		table.insert(formspec, "label[1,2.5;Total purchases: "..minercantile.shop.get_transac_b().."]")
		table.insert(formspec, "label[1,3;Total sales: "..minercantile.shop.get_transac_s().."]")
		table.insert(formspec, "button[1,4.3;1.5,1;choice;Buy]")
		table.insert(formspec, "button[3.5,4.3;1.5,1;choice;Sell]")
	return table.concat(formspec)
end

-- formspec admin shop
function minercantile.get_formspec_shop_admin_shop(pos, node_name, name)
	if not shop_admin[name] then
		shop_admin[name] = {}
	end
	shop_admin[name].pos = pos
	shop_admin[name].node_name = node_name

	local formspec = {"size[6,6]bgcolor[#2A2A2A;]label[2.2,0;Shop Admin]button[4.5,0;1.5,1;shop;Shop]"}
	local isnode = minetest.get_node_or_nil(pos)
	if not isnode or isnode.name ~= node_name then return end
	local meta = minetest.get_meta(pos)
	local shop_type = meta:get_int("shop_type")
	table.insert(formspec, "label[1,1;Shop Type:]")
	table.insert(formspec, "dropdown[3,1;3,1;select_type;"..table.concat(minercantile.shop.shop_type, ",")..";"..shop_type.."]")

	local isopen = meta:get_int("open")
	if isopen == 1 then
		table.insert(formspec, "label[1,2;Is Open: Yes]button[3.5,1.8;1.5,1;open_close;No]")
	else
		table.insert(formspec, "label[1,2;Is Open: No]button[3.5,1.8;1.5,1;open_close;Yes]")
	end

	local always_open = meta:get_int("always_open")
	if always_open == 1 then
		table.insert(formspec, "label[1,3;Open 24/24: Yes]button[3.5,2.8;1.5,1;always_open;No]")
	else
		table.insert(formspec, "label[1,3;Open 24/24: No]button[3.5,2.8;1.5,1;always_open;Yes]")
	end
	table.insert(formspec, "label[1,4;Shop money:"..minercantile.shop.get_money().."$]")
	table.insert(formspec, "button_exit[2.4,5.3;1.5,1;close;Close]")
	return table.concat(formspec)
end


minetest.register_on_player_receive_fields(function(player, formname, fields)
	local name = player:get_player_name()
	if not name or name == "" then return end
	if formname == "minercantile:shop_welcome" then
		if fields["choice"] then
			if fields["choice"] == "Buy" then
				show_formspec_to_buy(name)
			elseif fields["choice"] == "Sell" then
				show_formspec_to_sell(name)
			end
			return
		end
	elseif formname == "minercantile:shop_buy" then
		for b, n in pairs(fields) do
			if string.find(b, "buttonchoice_") then
				if not shop_buy[name] then return end
				local itname = string.sub(b, 14)
				shop_buy[name].itname = itname
				shop_buy[name].max = math.floor(minercantile.shop.get_nb(itname)/4)
				shop_buy[name].nb = 1
				shop_buy[name].price = minercantile.shop.get_buy_price(itname)
				minetest.show_formspec(name, "minercantile:shop_buy_items",  get_formspec_buy_items(name))
				return
			end
		end
		if fields["quit"] then
			return
		elseif fields["searchbutton"] then
			local search = string.sub(string.lower(fields["searchbox"]), 1, 14)
			set_pages_by_search(name, search)
		elseif fields["page_inc"] then
			if shop_buy[name].page < shop_buy[name].nb_pages then
				shop_buy[name].page = shop_buy[name].page+1
			end
		elseif fields["page_dec"] then
			if shop_buy[name].page > 1 then
				shop_buy[name].page = shop_buy[name].page-1
			end
		end
		show_formspec_to_buy(name)
	elseif formname == "minercantile:shop_buy_items" then
		if fields["amount"] then
			local inc = tonumber(fields["amount"])
			if inc ~= nil then
				shop_buy[name].nb = shop_buy[name].nb + inc
			end
			if shop_buy[name].nb > 99 then
				shop_buy[name].nb = 99
			end
			if shop_buy[name].nb > shop_buy[name].max then
				 shop_buy[name].nb = shop_buy[name].max
			end
			if shop_buy[name].nb < 1 then
				 shop_buy[name].nb = 1
			end
		elseif fields["abort"] then
			show_formspec_to_buy(name)
			return
		elseif fields["confirm"] then
			minercantile.shop.buy(name, shop_buy[name].itname, shop_buy[name].nb, shop_buy[name].price)
			return
		elseif fields["quit"] then
			shop_buy[name] = nil
			return
		end
		minetest.show_formspec(name, "minercantile:shop_buy_items",  get_formspec_buy_items(name))
	elseif formname == "minercantile:shop_sell" then
		for b, n in pairs(fields) do
			if string.find(b, "buttonchoice_") then
				if not shop_sell[name] then
					shop_sell[name] = {}
				end
				local index = tonumber(string.sub(b, 14))
				shop_sell[name].index = index
				local item = shop_sell[name].items[index]
				shop_sell[name].item = item
				shop_sell[name].itname = item.name
				shop_sell[name].max = item.nb
				shop_sell[name].wear = item.wear
				shop_sell[name].nb = 1
				shop_sell[name].price = minercantile.shop.get_sell_price(item.name, item.wear)
				minetest.show_formspec(name, "minercantile:shop_sell_items",  get_formspec_sell_items(name))
				break
			end
		end
		return
	elseif formname == "minercantile:shop_sell_items" then
		if fields["amount"] then
			local inc = tonumber(fields["amount"])
			if inc ~= nil then
				shop_sell[name].nb = shop_sell[name].nb + inc
			end
			if shop_sell[name].nb > shop_sell[name].max then
				 shop_sell[name].nb = shop_sell[name].max
			end
			if shop_sell[name].nb > 99 then
				shop_sell[name].nb = 99
			end
			if shop_sell[name].nb < 1 then
				 shop_sell[name].nb = 1
			end
		elseif fields["abort"] then
			show_formspec_to_sell(name)
			return
		elseif fields["confirm"] then
			minercantile.shop.player_sell(name)
			return
		elseif fields["quit"] then
			shop_sell[name] = nil
			return
		end
		minetest.show_formspec(name, "minercantile:shop_sell_items",  get_formspec_sell_items(name))
	elseif formname == "minercantile:confirmed" then
		if fields["return_sell"] then
			show_formspec_to_sell(name)
		elseif fields["return_buy"] then
			show_formspec_to_buy(name)
		end
	-- admin conf
	elseif formname == "minercantile:shop_admin_shop" then
		if fields["quit"] then
			shop_admin[name] = nil
			return
		elseif fields["shop"] then
			minetest.show_formspec(name, "minercantile:shop_welcome",  get_formspec_welcome(name))
			return
		end
		local pos = shop_admin[name].pos
		local node_name = shop_admin[name].node_name
		local isnode = minetest.get_node_or_nil(pos)
		if not isnode or isnode.name ~= node_name then return end --FIXME
		local meta = minetest.get_meta(pos)

		if fields["open_close"] then
			local open = 0
			if fields["open_close"] == "Yes" then
				open = 1
			end
			meta:set_int("open", open)
		elseif fields["always_open"] then
			local always_open = 0
			if fields["always_open"] == "Yes" then
				always_open = 1
			end
			meta:set_int("always_open", always_open)
		elseif fields["select_type"] then
			for i, n in pairs(minercantile.shop.shop_type) do
				if n == fields["select_type"] then
					meta:set_int("shop_type", i)
					local t = string.gsub(n, "_$","")
					meta:set_string("infotext", t.." Shop")
					break
				end
			end
		end
		minetest.show_formspec(name, "minercantile:shop_admin_shop",  minercantile.get_formspec_shop_admin_shop(pos, node_name, name))
	end
end)


--Barter shop.
minetest.register_node("minercantile:shop", {
	description = "Barter Shop",
	tiles = {"minercantile_shop.png"},
	groups = {snappy=2,choppy=2,oddly_breakable_by_hand=2},
	sounds = default.node_sound_wood_defaults(),
	paramtype2 = "facedir",
	drawtype = "mesh",
	mesh = "minercantile_shop.obj",
	paramtype = "light",
	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		meta:set_string("infotext", "General Shop")
		meta:set_int("open", 1)
		meta:set_int("always_open", 0)
		meta:set_int("shop_type", 1)
	end,
	can_dig = function(pos, player)
		local name = player:get_player_name()
		return (minetest.check_player_privs(name, {protection_bypass = true}) or minetest.check_player_privs(name, {shop = true}))
	end,
	on_rightclick = function(pos, node, player, itemstack, pointed_thing)
		local name = player:get_player_name()
		if not name or name == "" then return end
		local meta = minetest.get_meta(pos)
		local shop_type = minercantile.shop.shop_type[meta:get_int("shop_type")] or "General"
		minercantile.shop.set_items_buy_list(name, shop_type)
		if minetest.check_player_privs(name, {protection_bypass = true}) or minetest.check_player_privs(name, {shop = true}) then
			minetest.show_formspec(name, "minercantile:shop_admin_shop",  minercantile.get_formspec_shop_admin_shop(pos, node.name, name))
		else
			local isopen = meta:get_int("open")
			if (isopen and isopen == 1) then
				local always_open = meta:get_int("always_open")
				local tod = (minetest.get_timeofday() or 0) * 24000
				if always_open == 1 or (tod > 8000 and tod < 19000) then --FIXME check tod 8h-19h
					minetest.show_formspec(name, "minercantile:shop_welcome",  get_formspec_welcome(name))
				else
					minetest.show_formspec(name, "minercantile:closed", "size[6,3]bgcolor[#2A2A2A;]label[2.6,0;Shop]label[1.2,1;Sorry shop is only open 8h-19h]button_exit[2.3,2.1;1.5,1;close;Close]")
				end
			else
				minetest.show_formspec(name, "minercantile:closed", "size[6,3]bgcolor[#2A2A2A;]label[2.6,0;Shop]label[1.7,1;Sorry shop is closed]button_exit[2.3,2.1;1.5,1;close;Close]")
			end
		end
	end,
})


minetest.register_chatcommand("shop_addmoney",{
	params = "money",
	description = "give money to the shop",
	privs = {shop = true},
	func = function(name, param)
		param = string.gsub(param, " ", "")
		local amount = tonumber(param)
		if amount == nil then
			minetest.chat_send_player(name, "invalid, you must add amount at param")
			return
		end
		minercantile.shop.give_money(amount, true)
		minetest.chat_send_player(name, "you add "..amount.. ", new total:".. minercantile.shop.get_money())
	end,
})

minetest.register_chatcommand("shop_delmoney",{
	params = "money",
	description = "del money from the shop",
	privs = {shop = true},
	func = function(name, param)
		param = string.gsub(param, " ", "")
		local amount = tonumber(param)
		if (amount  == nil ) then
			minetest.chat_send_player(name, "invalid, you must add amount at param")
			return
		end
		minercantile.shop.take_money(amount, true)
		minetest.chat_send_player(name, "you delete "..amount.. ", new total:".. minercantile.shop.get_money())
	end,
})

minetest.register_chatcommand("shop_additem",{
	params = "name number",
	description = "give item to the shop",
	privs = {shop = true},
	func = function(name, param)
		if ( param == nil ) then
			minetest.chat_send_player(name, "invalid, no param")
			return
		end
		local itname, amount = param:match("^(%S+)%s(%S+)$")
		if itname == nil then
			minetest.chat_send_player(name, "invalid param item")
			return
		end
		if not minercantile.shop.is_available(itname) then
			minetest.chat_send_player(name, "invalid param item unknow")
			return
		end
		if amount == nil or not tonumber(amount) then
			minetest.chat_send_player(name, "invalid param amount")
			return
		end
		local amount = tonumber(amount)
		if amount < 1 then
			minetest.chat_send_player(name, "invalid param amount")
			return
		end
		minercantile.shop.add_item(itname, amount)
		minetest.chat_send_player(name, "you add "..amount.. " items, new total:".. minercantile.shop.get_nb(itname))
	end,
})

minetest.register_chatcommand("shop_delitem",{
	params = "name number",
	description = "del item from the shop",
	privs = {shop = true},
	func = function(name, param)
		if ( param == nil ) then
			minetest.chat_send_player(name, "invalid, no param")
			return
		end
		local itname, amount = param:match("^(%S+)%s(%S+)$")
		if itname == nil then
			minetest.chat_send_player(name, "invalid param item")
			return
		end
		if not minercantile.shop.is_available(itname) then
			minetest.chat_send_player(name, "invalid param item unknow")
			return
		end
		if amount == nil or not tonumber(amount) then
			minetest.chat_send_player(name, "invalid param amount")
			return
		end
		local amount = tonumber(amount)
		if amount < 1 then
			minetest.chat_send_player(name, "invalid param amount")
			return
		end
		minercantile.shop.del_item(itname, amount)
		minetest.chat_send_player(name, "you delete "..amount.. " items, new total:".. minercantile.shop.get_nb(itname))
	end,
})
