minercantile = {}

--path
minercantile.path = minetest.get_worldpath()
minercantile.path_wallet =  minercantile.path.. "/minercantile_wallet/"
minercantile.file_stock_base = minercantile.path.."/minercantile_stock_base.txt"
minercantile.file_stock = minercantile.path.."/minercantile_stock.txt"
minetest.mkdir(minercantile.path_wallet)

--items
minercantile.stock_base = {}
minercantile.stock = {} -- table saved money, items list
minercantile.shop = {}
minercantile.shop.items_inventory = {}
minercantile.stock.items = {}
minercantile.stock.money = 10000

--functions specific to wallet
minercantile.wallet = {}
-- table players wallets
minercantile.wallets = {}
--load money
dofile(minetest.get_modpath("minercantile") .. "/wallets.lua")
dofile(minetest.get_modpath("minercantile") .. "/change.lua")
local shop = {} --formspec temporary variables
local shop_buy = {}
local shop_items_nb
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
	minercantile.set_items_inventory()
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
				minercantile.stock.items = table.copy(data.items)
			end
			minercantile.set_items_inventory()
			return
		end
	end
	if minercantile.stock_base then
		minercantile.stock.items = table.copy(minercantile.stock_base)
	end
	minercantile.set_items_inventory()
end


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


-- sell fonction
function minercantile.calcul_prices(item, object)
	local price = nil
	local money = minercantile.shop.get_money()
	if not minercantile.stock.items[item] then
		minercantile.stock.items[item] = {nb=1000} --FIXME random nb
		--minercantile.save_stock()
	end

	if minercantile.stock.items[item].price ~= nil then -- if defined price
		price = math.ceil(minercantile.stock.items[item].price)
	elseif object == "sell" then
		local nb = minercantile.stock.items[item].nb
		price = math.ceil((((money/2)/nb) - 0.49))
	elseif object == "buy" then
		local nb = minercantile.stock.items[item].nb
		price = math.ceil((((money/2)/nb) + 0.49))	
	end
	if price < 1 then price = 1 end
	return price
end


function minercantile.get_formspec_shop_admin_shop(pos, node_name, name)
	if not shop[name] then
		shop[name]  = {}
	end
	shop[name].pos = pos
	shop[name].node_name = node_name

	local formspec = {"size[6,6]label[2.2,0;Shop Admin]button[4.5,0;1.5,1;shop;Shop]"}
	local isnode = minetest.get_node_or_nil(pos)
	if not isnode or isnode.name ~= node_name then return end
	local meta = minetest.get_meta(pos)
	
	local isopen = meta:get_int("open") or 0
	if isopen == 1 then
		table.insert(formspec, "label[1,1;Is Open: Yes]button[3.5,0.8;1.5,1;open_close;No]")
	else
		table.insert(formspec, "label[1,1;Is Open: No]button[3.5,0.8;1.5,1;open_close;Yes]")
	end

	local always_open = meta:get_int("always_open") or 0
	if always_open == 1 then
		table.insert(formspec, "label[1,2;Open 24/24: Yes]button[3.5,1.8;1.5,1;always_open;No]")
	else
		table.insert(formspec, "label[1,2;Open 24/24: No]button[3.5,1.8;1.5,1;always_open;Yes]")
	end

	table.insert(formspec, "button_exit[2.4,5.3;1.5,1;close;Close]")
	return table.concat(formspec)
end


function minercantile.set_items_inventory()
	local count = 0
	for Index, Value in pairs(minercantile.stock.items) do
		count = count + 1
	end
	if shop_items_nb ~= count then
		shop_items_nb = count
		minercantile.shop.items_inventory = {}
		for n, def in pairs(minercantile.stock.items) do
			local item = minetest.registered_items[n]
			if item then
				table.insert(minercantile.shop.items_inventory, n)
			end
		end
		table.sort(minercantile.shop.items_inventory)
	end
end


local function set_pages_by_search(name, search)
	shop_buy[name].page = 1
	shop_buy[name].search = minetest.formspec_escape(search)
	shop_buy[name].items_list = {}
	local match = false
	for n, def in pairs(minercantile.stock.items) do
		local item = minetest.registered_items[n]
		if item then
			if string.find(item.name, search) or (item.description and item.description ~= "" and string.find(string.lower(item.description), search)) then
				table.insert(shop_buy[name].items_list, n)
				--shop_buy[name].items_list[n]
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
		local index = 0
		if nb_pages >1 then
			index = (page*32)-32
		end
		for i=1, 32 do
			local item = shop_buy[name].items_list[index+i]
			if not item then break end
			local nb = minercantile.stock.items[item].nb
			local price = minercantile.calcul_prices(item, "buy")
			table.insert(inv_list, {name=item,nb=nb,price=price})
		end
	else
		nb_items = shop_items_nb
		nb_pages = math.ceil(nb_items/32)
		if page > nb_pages then page = nb_pages end
		local index = 0
		if nb_pages >1 then
			index = (page*32)-32
		end
		for i=1, 32 do
			local item = minercantile.shop.items_inventory[index+i]
			if item then
				local nb = minercantile.stock.items[item].nb
				local price = minercantile.calcul_prices(item, "buy")
				table.insert(inv_list, {name=item,nb=nb,price=price})
			else
				break
			end
		end	

	end
	shop_buy[name].nb_pages = nb_pages
	return inv_list
end


--buy
function minercantile.buy(name, item, nb, price)
	local player = minetest.get_player_by_name(name)
	if not player then return false end
	local player_inv = player:get_inventory()
	local shop_money = minercantile.shop.get_money()
	local player_money = minercantile.wallet.get_money(name)
	if player_money < 1 then
		minetest.show_formspec(name, "minercantile:confirmed", "size[6,3]label[2.6,0;Shop]label[1,1;Sorry, you have not enough money]button[1.3,2.1;1.5,1;return;Return]button_exit[3.3,2.1;1.5,1;close;Close]")
		return false
	end	

	local items_nb = minercantile.stock.items[item].nb -4
	if items_nb < 1 then
		minetest.show_formspec(name, "minercantile:confirmed", "size[6,3]label[2.6,0;Shop]label[1.7,1;Sorry, shop have 0 item ..".. item.."]button[1.3,2.1;1.5,1;return;Return]button_exit[3.3,2.1;1.5,1;close;Close]")
		return false
	end

	local item_can_sell = nb
	if items_nb/4 < nb then
		item_can_sell = items_nb/4
	end

	local price_total = math.floor(item_can_sell * price)
	local player_can_buy = item_can_sell
	if player_money < price_total then
		player_can_buy = math.floor(player_money/price)	
	end
	print("player_can_buy:"..dump(player_can_buy))
	local sell_price = player_can_buy * price
	

	local stack = ItemStack(item.." "..player_can_buy)
	--player_inv:room_for_item("main", stack)
	local nn = player_inv:add_item("main", stack)
	local count = nn:get_count()
	if count > 0 then
		minetest.spawn_item(player:getpos(), {name=item, count=count, wear=0, metadata=""})
	end


	minercantile.stock.items[item].nb = minercantile.stock.items[item].nb - player_can_buy
	minercantile.shop.give_money(sell_price, true)

	minercantile.wallet.take_money(name, sell_price, " Buy "..player_can_buy .." "..item..", price "..sell_price)
	minetest.show_formspec(name, "minercantile:confirmed", "size[6,3]label[2.6,0;Shop]label[1,1;You buy "..player_can_buy .." "..item..", price "..sell_price.."]button[1.3,2.1;1.5,1;return;Return]button_exit[3.3,2.1;1.5,1;close;Close]")
	return true
end

local function show_formspec_to_buy(name)
	local player = minetest.get_player_by_name(name)
	if not player then return end
	if not shop_buy[name] then
		shop_buy[name] = {page=1, search=""}
	end
	local formspec = {"size[10,10]bgcolor[#2A2A2A;]label[0,0;shop money:"..minercantile.shop.get_money().."$]label[4.4,0;Buy Items]"}
	local inv_items = get_shop_inventory_by_page(name)
	table.insert(formspec, "label[0,0.5;Your money:"..minercantile.wallet.get_money(name) .."$]")
	table.insert(formspec, "label[0.2,1.4;Page: ".. shop_buy[name].page.." of ".. shop_buy[name].nb_pages.."]")
	if shop_buy[name].search ~= "" then
		table.insert(formspec, "label[2,1.4;Filter: ".. minetest.formspec_escape(shop_buy[name].search) .."]")
	end
	local x = 0.2
	local y = 2
	local j = 1
	for i=1, 32 do
		local item = inv_items[i]
		if item then
			table.insert(formspec, "item_image_button["..x..","..y..";1,1;"..tostring(item.name)..";buttonchoice_"..tostring(item.name)..";"..item.nb.."]")
			table.insert(formspec, "label["..(x)..","..(y+0.8)..";"..item.price.."$]")
		else
			table.insert(formspec, "image["..x..","..y..";1,1;minercantile_img_inv.png]")
		end
		x = x +1.2
		j = j +1
		if j > 8 then
			j = 1
			x = 0.2
			y = y + 1.4
		end
	end

	table.insert(formspec, "field[3.75,8.75;2.2,1;searchbox;;]")
	table.insert(formspec, "image_button[5.55,8.52;.8,.8;ui_search_icon.png;searchbutton;]tooltip[searchbutton;Search]")
	table.insert(formspec, "button[4,9.3;1,1;page_dec;<]")
	table.insert(formspec, "button[4.9,9.3;1,1;page_inc;>]")
	table.insert(formspec, "button_exit[8.2,9.3;1.5,1;choice;Close]")
	minetest.show_formspec(name, "minercantile:shop_buy",  table.concat(formspec))
end


local function get_formspec_buy_items(name)
	local item = shop_buy[name].item
	local max = shop_buy[name].max
	local nb = shop_buy[name].nb
	local price = shop_buy[name].price
	local formspec = {"size[8,6]label[3.5,0;Buy Items]"}
	table.insert(formspec, "button[0.6,2;1,1;amount;-1]")
	table.insert(formspec, "button[1.6,2;1,1;amount;-10]")
	table.insert(formspec, "button[2.6,2;1,1;amount;-20]")
	table.insert(formspec, "item_image_button[3.6,2;1,1;"..item..";buttonchoice_"..item..";"..nb.."]")
	table.insert(formspec, "button[4.6,2;1,1;amount;+20]")
	table.insert(formspec, "button[5.6,2;1,1;amount;+10]")
	table.insert(formspec, "button[6.6,2;1,1;amount;+1]")
	
	table.insert(formspec, "size[8,6]label[3,3;Buy ".. nb.."x"..price.."="..nb * price.."]")
	table.insert(formspec, "button[3.3,4;1.5,1;confirm;Confirm]")
	table.insert(formspec, "button[0,0;1.5,1;abort;Return]")
	return table.concat(formspec)
end





-- sell
function minercantile.sell(name, item, nb, price)
	local player = minetest.get_player_by_name(name)
	if not player then return false end
	local player_inv = player:get_inventory()
	local shop_money = minercantile.shop.get_money()

	if shop_money < 1 then
		minetest.show_formspec(name, "minercantile:confirmed", "size[6,3]label[2.6,0;Shop]label[1,1;Sorry, shop have not enough money]button[1.3,2.1;1.5,1;return;Return]button_exit[3.3,2.1;1.5,1;close;Close]")
		return false
	end	

	local items_nb = 0
	for i=1,player_inv:get_size("main") do
		if player_inv:get_stack("main", i):get_name() == item then
			items_nb = items_nb + player_inv:get_stack("main", i):get_count()
		end
	end	

	if items_nb == 0 then
		minetest.show_formspec(name, "minercantile:confirmed", "size[6,3]label[2.6,0;Shop]label[1.7,1;Sorry, You have 0 item ..".. item.."]button[1.3,2.1;1.5,1;return;Return]button_exit[3.3,2.1;1.5,1;close;Close]")
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
	elseif shop_money < price_total then
		shop_can_buy = math.floor(shop_money/price)	
	end
	print("shop_can_buy:"..dump(shop_can_buy))
	local sell_price = shop_can_buy * price
	
	for i=1,player_inv:get_size("main") do
		if player_inv:get_stack("main", i):get_name() == item then
			items_nb = items_nb + player_inv:get_stack("main", i):get_count()
		end
	end		

	local stack = ItemStack(item.." "..shop_can_buy)
	player_inv:remove_item("main", stack)

	minercantile.stock.items[item].nb = minercantile.stock.items[item].nb + shop_can_buy
	minercantile.shop.take_money(sell_price, true)

	minercantile.wallet.give_money(name, sell_price, " Sell "..shop_can_buy .." "..item..", price "..sell_price)
	minetest.show_formspec(name, "minercantile:confirmed", "size[6,3]label[2.6,0;Shop]label[1,1;You sell "..shop_can_buy .." "..item..", price "..sell_price.."]button[1.3,2.1;1.5,1;return;Return]button_exit[3.3,2.1;1.5,1;close;Close]")
	return true
end


-- show sell formspec
local function show_formspec_to_sell(name)
	local player = minetest.get_player_by_name(name)
	if not player then return end
	local formspec = {"size[10,8]bgcolor[#2A2A2A;]label[4,0;Sell Items]"}
	table.insert(formspec, "label[0,0;shop money:"..minercantile.shop.get_money().."$]")
	table.insert(formspec, "label[0,0.5;Your money:"..minercantile.wallet.get_money(name) .."$]")
	local player_inv = player:get_inventory()
	local inv_items = {}
	for i=1, player_inv:get_size("main") do
		if not player_inv:get_stack("main", i):is_empty() and minetest.registered_items[player_inv:get_stack("main", i):get_name()] then
			local item = player_inv:get_stack("main", i):get_name()
			if not inv_items[item] then
				inv_items[item] = {nb=0}
			end
			inv_items[item].nb = inv_items[item].nb + player_inv:get_stack("main", i):get_count()	
			if not inv_items[item].price then
				inv_items[item].price = minercantile.calcul_prices(item, "sell")
			end
		end
	end
	shop[name] = {}
	shop[name].items = table.copy(inv_items)
	local x = 0.2
	local y = 1
	for n, def in pairs(inv_items) do
		table.insert(formspec, "item_image_button["..x..","..y..";1,1;"..n..";buttonchoice_"..n..";"..def.nb.."]")
		table.insert(formspec, "label["..(x+0.2)..","..(y+0.8)..";"..def.price.."]")
		x = x +1.1
		if x > 8 then
			x = 0.2
			y = y + 1.4
		end
	end
	table.insert(formspec, "button_exit[1.3,7.3;1.5,1;choice;Close]")
	minetest.show_formspec(name, "minercantile:shop_sell",  table.concat(formspec))
end


local function get_formspec_sell_items(name)
	local item = shop[name].item
	local max = shop[name].max
	local nb = shop[name].nb
	local price = shop[name].price
	local formspec = {"size[8,6]label[3.5,0;Sell Items]"}

	table.insert(formspec, "button[0.6,2;1,1;amount;-1]")
	table.insert(formspec, "button[1.6,2;1,1;amount;-10]")
	table.insert(formspec, "button[2.6,2;1,1;amount;-20]")
	--table.insert(formspec, "label[3.7,5.2;"..tostring(nb).."]")
	table.insert(formspec, "item_image_button[3.6,2;1,1;"..item..";buttonchoice_"..item..";"..nb.."]")
	table.insert(formspec, "button[4.6,2;1,1;amount;+20]")
	table.insert(formspec, "button[5.6,2;1,1;amount;+10]")
	table.insert(formspec, "button[6.6,2;1,1;amount;+1]")
	
	table.insert(formspec, "size[8,6]label[3,3;sell ".. nb.."x"..price.."="..nb * price.."]")
	table.insert(formspec, "button[3.3,4;1.5,1;confirm;Confirm]")
	table.insert(formspec, "button[0,0;1.5,1;abort;Return]")
	return table.concat(formspec)
end


local function get_formspec_welcome(name)
	local formspec = {"size[6,5]label[2.6,0;Shop]"}
		table.insert(formspec, "image[1,1;5,1.25;minercantile_shop_welcome.png]")
		table.insert(formspec, "button[1.3,3.3;1.5,1;choice;Buy]")
		table.insert(formspec, "button[3.5,3.3;1.5,1;choice;Sell]")
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
				if not shop_buy[name] then
					shop_buy[name] = {}
				end
				local item = string.sub(b, 14)
				shop_buy[name].item = item
				shop_buy[name].max = tonumber(n)
				shop_buy[name].nb = 1
				--shop_buy[name].price = shop_buy[name].items[shop_buy[name].item].price
				shop_buy[name].price = minercantile.calcul_prices(item, "buy")
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
			if shop_buy[name].nb > shop_buy[name].max then
				 shop_buy[name].nb = shop_buy[name].max
			end
			if shop_buy[name].nb > 99 then
				shop_buy[name].nb = 99
			end
			if shop_buy[name].nb < 1 then
				 shop_buy[name].nb = 1
			end
		elseif fields["abort"] then
			show_formspec_to_buy(name)
			return
		elseif fields["confirm"] then
			minercantile.buy(name, shop_buy[name].item, shop_buy[name].nb, shop_buy[name].price)
			return
		elseif fields["quit"] then
			shop_buy[name] = nil
			return
		end
		minetest.show_formspec(name, "minercantile:shop_buy_items",  get_formspec_buy_items(name))
	elseif formname == "minercantile:shop_buy_confirm" then
	
	
	
	
	
	
	elseif formname == "minercantile:shop_sell" then
		for b, n in pairs(fields) do
			if string.find(b, "buttonchoice_") then
				if not shop[name] then
					shop[name] = {}
				end
				shop[name].item = string.sub(b, 14)
				shop[name].max = tonumber(n)
				shop[name].nb = 1
				shop[name].price = shop[name].items[shop[name].item].price
				minetest.show_formspec(name, "minercantile:shop_sell_items",  get_formspec_sell_items(name))
				break
			end
		end
		return
	elseif formname == "minercantile:shop_sell_items" then
		if fields["amount"] then
			local inc = tonumber(fields["amount"])
			if inc ~= nil then
				shop[name].nb = shop[name].nb + inc
			end
			if shop[name].nb > shop[name].max then
				 shop[name].nb = shop[name].max
			end
			if shop[name].nb > 99 then
				shop[name].nb = 99
			end
			if shop[name].nb < 1 then
				 shop[name].nb = 1
			end
		elseif fields["abort"] then
			show_formspec_to_sell(name)
			return
		elseif fields["confirm"] then
			minercantile.sell(name, shop[name].item, shop[name].nb, shop[name].price)
			return
		elseif fields["quit"] then
			shop[name] = nil
			return
		end
		minetest.show_formspec(name, "minercantile:shop_sell_items",  get_formspec_sell_items(name))
	elseif formname == "minercantile:confirmed" then
		if fields["return"] then
			show_formspec_to_sell(name)
		end
		return
		
		
		
		
	elseif formname == "minercantile:shop_admin_shop" then
		if fields["quit"] then
			shop[name] = nil
			return
		elseif fields["shop"] then
			minetest.show_formspec(name, "minercantile:shop_welcome",  get_formspec_welcome(name))
			return
		end
		local pos = shop[name].pos
		local node_name = shop[name].node_name
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
	--visual_scale = 0.5,
	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		meta:set_string("infotext", "Barter Shop")
		meta:set_int("open", 0)
		meta:set_int("always_open", 0)
	end,
	can_dig = function(pos,player)
		--return minetest.get_player_privs(player:get_player_name())["money_admin"] --FIXME
		--if minetest.check_player_privs(name, {protection_bypass = true}) or minetest.check_player_privs(name, {server = true}) then
		return true
	end,
	on_rightclick = function(pos, node, player, itemstack, pointed_thing)
		local name = player:get_player_name()
		if not name or name == "" then return end
		if minetest.check_player_privs(name, {protection_bypass = true}) or minetest.check_player_privs(name, {server = true}) then
			minetest.show_formspec(name, "minercantile:shop_admin_shop",  minercantile.get_formspec_shop_admin_shop(pos, node.name, name))
		else
			local meta = minetest.get_meta(pos)
			local isopen = meta:get_int("open")
			if (isopen and isopen == 1) then
				local always_open = meta:get_int("always_open")
				local tod = (minetest.get_timeofday() or 0) * 24000
				if always_open == 1 or (tod > 4500 and tod < 19500) then --FIXME check tod 8h-21h
					minetest.show_formspec(name, "minercantile:shop_welcome",  get_formspec_welcome(name))
				else
					minetest.show_formspec(name, "minercantile:closed", "size[6,3]label[2.6,0;Shop]label[1.2,1;Sorry shop is only open 7h-21h]button_exit[2.3,2.1;1.5,1;close;Close]")
				end
			else
				minetest.show_formspec(name, "minercantile:closed", "size[6,3]label[2.6,0;Shop]label[1.7,1;Sorry shop is closed]button_exit[2.3,2.1;1.5,1;close;Close]")
			end
		end
	end,
})


--nodes 
minetest.register_craft({
	output = "minercantile:shop",
	recipe = {
		{"default:wood", "default:wood", "default:wood"},
		{"default:wood", "default:mese", "default:wood"},
		{"default:wood", "default:wood", "default:wood"},
	},
})

--[[
if (minetest.get_modpath("unified_inventory")) then
	unified_inventory.register_button("shop_admin", {
		type = "image",
		image = "minercantile_shop.png", --FIXME change texture
		tooltip = "Admin Shop",
		show_with = "server",
		action = function(player)
			local name = player:get_player_name()
			if not name then return end
			local formspec = minercantile.get_formspec_shop_admin(name)
			minetest.show_formspec(name, "minercantile:shop_admin", formspec)
		end,
	})
else
	minetest.register_chatcommand("shop_admin",{
		params = "",
		description = "Show admin shop formspec",
		privs = {server = true},
		func = function (name, params)
		local formspec = minercantile.get_formspec_shop_admin(name)
		minetest.show_formspec(name, "minercantile:shop_admin", formspec)
		end,
	})
end
--]]

minetest.register_chatcommand("shop_addmoney",{
	params = "money",
	description = "give money to the shop",
	privs = {server = true},
	func = function(name, param)
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
	description = "del money to the shop",
	privs = {server = true},
	func = function(name, param)	
		local amount = tonumber(param)
		if (amount  == nil ) then
			minetest.chat_send_player(name, "invalid, you must add amount at param")
			return
		end
		minercantile.shop.take_money(amount, true)
		minetest.chat_send_player(name, "you delete "..amount.. ", new total:".. minercantile.shop.get_money())
	end,
})


--load items base and available
minercantile.load_stock_base()
minercantile.load_stock()
minetest.log("action", "[minercantile] Loaded")
