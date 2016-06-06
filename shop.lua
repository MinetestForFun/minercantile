local shop = {} --formspec temporary variables
local shop_buy = {}

minercantile.shop.max_stock = 20000 --shop don't buy infinity items


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


-- table of sellable/buyable items,ignore admin stuff
function minercantile.shop.register_items()
	minercantile.registered_items = {}
	for name, def in pairs(minetest.registered_items) do
		if not def.groups.not_in_creative_inventory
		and not def.groups.unbreakable
		and def.description and def.description ~= "" then
		--and minetest.get_all_craft_recipes(name) then
			minercantile.registered_items[name] = {groups = def.groups, desc = def.description,}
		end
	end
end

function minercantile.shop.is_available(item)
	if minercantile.registered_items[item] then
		return true
	end
	return false
end

function minercantile.shop.get_item_def(item)
	if minercantile.registered_items[item] then
		return minercantile.registered_items[item]
	end
	return nil
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
	minercantile.shop.set_list()
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
			minercantile.shop.set_list()
			return
		end
	else
		if minercantile.stock_base then
			minercantile.stock.items = table.copy(minercantile.stock_base)
		end
		minercantile.shop.set_list()
	end
end

--create list items for formspec (search/pages)
function minercantile.shop.set_list()
	local list = {}
	for name, def in pairs(minercantile.stock.items) do
		if minercantile.shop.is_available(name) and def.nb > 0 then
			table.insert(list, name)
		end
	end
	table.sort(list)
	minercantile.shop.items_inventory = table.copy(list)
end

function minercantile.shop.get_nb(item)
	if minercantile.stock.items[item] then
		return minercantile.stock.items[item].nb
	end
	return 0
end

-- sell fonction
function minercantile.shop.get_price(item, object)
	if item == "maptools:copper_coin" or item == "maptools:silver_coin" or item == "maptools:gold_coin" then -- dont's buy/sell coins
		return nil
	end
	local price = nil
	local money = minercantile.shop.get_money()
	if not minercantile.stock.items[item] then
		minercantile.stock.items[item] = {nb=math.random(5000, 10000)}
	end

	local nb = minercantile.stock.items[item].nb
	if minercantile.stock.items[item].price ~= nil then -- if defined price
		price = math.ceil(minercantile.stock.items[item].price)
	elseif object == "sell" then
		price = math.ceil((money/10)/(math.log(nb+2000+99)*10)*1000000/(math.pow((nb+2000+99),(2.01))))
	elseif object == "buy" then
		price = math.ceil((money/10)/(math.log(nb+2000-99)*10)*1000000/(math.pow((nb+2000-99),(2.01))))
	end
	if price < 1 then price = 1 end
	return price
end



local function set_pages_by_search(name, search)
	shop_buy[name] = {}
	shop_buy[name].page = 1
	shop_buy[name].search = minetest.formspec_escape(search)
	shop_buy[name].items_list = {}
	for itname, def in pairs(minercantile.stock.items) do
		if def.nb > 0 then
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
			local item = shop_buy[name].items_list[index+i]
			if not item then break end
			local nb = minercantile.shop.get_nb(item)
			if nb > 0 then
				local price = minercantile.shop.get_price(item, "buy")
				if price and price > 0 then
					table.insert(inv_list, {name=item, nb=nb, price=price})
				end
			end
		end
	else
		nb_items = #minercantile.shop.items_inventory
		nb_pages = math.ceil(nb_items/32)
		if page > nb_pages then page = nb_pages end
		local index = (page*32)-32
		for i=1, 32 do
			local item = minercantile.shop.items_inventory[index+i]
			if item then
				local nb = minercantile.shop.get_nb(item)
				if nb > 0 then
					local price = minercantile.shop.get_price(item, "buy")
					if price and price > 0 then
						table.insert(inv_list, {name=item,nb=nb,price=price})
					end
				end
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
		minetest.show_formspec(name, "minercantile:confirmed", "size[6,3]bgcolor[#2A2A2A;]label[2.6,0;Shop]label[1,1;Sorry, you have not enough money]button[1.3,2.1;1.5,1;return_buy;Return]button_exit[3.3,2.1;1.5,1;close;Close]")
		return false
	end	

	local items_nb = minercantile.stock.items[item].nb
	if items_nb < 1 then
		minetest.show_formspec(name, "minercantile:confirmed", "size[6,3]bgcolor[#2A2A2A;]label[2.6,0;Shop]label[1,1;Sorry, shop have 0 item ".. item.."]button[1.3,2.1;1.5,1;return_buy;Return]button_exit[3.3,2.1;1.5,1;close;Close]")
		return false
	end

	local item_can_sell = nb
	if items_nb/4 < nb then
		item_can_sell = math.floor(items_nb/4)
	end

	local price_total = math.floor(item_can_sell * price)
	local player_can_buy = item_can_sell
	if player_money < price_total then
		player_can_buy = math.floor(player_money/price)
	end

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
	minetest.show_formspec(name, "minercantile:confirmed", "size[6,3]bgcolor[#2A2A2A;]label[2.6,0;Shop]label[1,1;You buy "..player_can_buy .." "..item..", price "..sell_price.."$]button[1.3,2.1;1.5,1;return_buy;Return]button_exit[3.3,2.1;1.5,1;close;Close]")
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
	--print(dump(inv_items))
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
	local formspec = {"size[8,6]bgcolor[#2A2A2A;]label[3.5,0;Buy Items]"}
	if minetest.registered_items[item] and minetest.registered_items[item].stack_max and minetest.registered_items[item].stack_max == 1 then
		table.insert(formspec, "label[2.1,1.5;This item is being sold by 1 max]")
	else
		table.insert(formspec, "button[0.6,1.5;1,1;amount;-1]")
		table.insert(formspec, "button[1.6,1.5;1,1;amount;-10]")
		table.insert(formspec, "button[2.6,1.5;1,1;amount;-20]")
		table.insert(formspec, "item_image_button[3.6,1.5;1,1;"..item..";buttonchoice_"..item..";"..nb.."]")
		table.insert(formspec, "button[4.6,1.5;1,1;amount;+20]")
		table.insert(formspec, "button[5.6,1.5;1,1;amount;+10]")
		table.insert(formspec, "button[6.6,1.5;1,1;amount;+1]")
	end
	table.insert(formspec, "label[3.5,2.7;Price:"..price.."$]")
	table.insert(formspec, "label[3.5,3.1;Amount:".. nb.." items]")
	table.insert(formspec, "label[3.5,3.5;Total:"..nb * price.."$]")
	table.insert(formspec, "button[3.3,5;1.5,1;confirm;Confirm]")
	table.insert(formspec, "button[0,0;1.5,1;abort;Return]")
	return table.concat(formspec)
end





-- sell
function minercantile.shop.player_sell(name, item, nb, price)
	local player = minetest.get_player_by_name(name)
	if not player then return false end
	local player_inv = player:get_inventory()
	local shop_money = minercantile.shop.get_money()

	if shop_money < 4 then
		minetest.show_formspec(name, "minercantile:confirmed", "size[6,3]bgcolor[#2A2A2A;]label[2.6,0;Shop]label[1,1;Sorry, shop have not enough money]button[1.3,2.1;1.5,1;return_sell;Return]button_exit[3.3,2.1;1.5,1;close;Close]")
		return false
	end	

	local items_nb = 0
	for i=1, player_inv:get_size("main") do
		if player_inv:get_stack("main", i):get_name() == item then
			items_nb = items_nb + player_inv:get_stack("main", i):get_count()
		end
	end	

	if items_nb == 0 then
		minetest.show_formspec(name, "minercantile:confirmed", "size[6,3]bgcolor[#2A2A2A;]label[2.6,0;Shop]label[1.7,1;Sorry, You have 0 item ..".. item.."]button[1.3,2.1;1.5,1;return_sell;Return]button_exit[3.3,2.1;1.5,1;close;Close]")
		return false
	end

	local item_can_sell = nb
	if items_nb < nb then
		item_can_sell = items_nb
	end

	local stock = minercantile.shop.get_nb(item)
	if stock >= minercantile.shop.max_stock then
		minetest.show_formspec(name, "minercantile:confirmed", "size[6,3]bgcolor[#2A2A2A;]label[2.6,0;Shop]label[1.7,1;Sorry, the shop has too much stock of ..".. item.."]button[1.3,2.1;1.5,1;return_sell;Return]button_exit[3.3,2.1;1.5,1;close;Close]")
		return false
	elseif (stock + item_can_sell) > minercantile.shop.max_stock then
		item_can_sell = (item_can_sell -((stock + item_can_sell) - minercantile.shop.max_stock))	
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

	local sell_price = math.floor(shop_can_buy * price)

	local stack = ItemStack(item.." "..shop_can_buy)
	player_inv:remove_item("main", stack)

	minercantile.stock.items[item].nb = minercantile.stock.items[item].nb + shop_can_buy
	minercantile.shop.take_money(sell_price, true)

	minercantile.wallet.give_money(name, sell_price, " Sell "..shop_can_buy .." "..item..", price "..sell_price)
	minetest.show_formspec(name, "minercantile:confirmed", "size[6,3]bgcolor[#2A2A2A;]label[2.6,0;Shop]label[1,1;You sell "..shop_can_buy .." "..item..", price "..sell_price.."$]button[1.3,2.1;1.5,1;return_sell;Return]button_exit[3.3,2.1;1.5,1;close;Close]")
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
		local stack = player_inv:get_stack("main", i)
		if not stack:is_empty() and minercantile.shop.is_available(stack:get_name()) then
			local item = stack:get_name()
			local price = minercantile.shop.get_price(item, "sell")
			if price and price > 0 then
				if not inv_items[item] then
					inv_items[item] = {nb=0}
				end
				inv_items[item].nb = inv_items[item].nb + stack:get_count()
				inv_items[item].price = price
			end
		end
	end
	shop[name] = {}
	shop[name].items = table.copy(inv_items)
	local inv_list = {}
	for n, def in pairs(inv_items) do
		table.insert(inv_list, {name=n,nb=def.nb,price=def.price})
	end
	
	local x = 0.2
	local y = 1	
	for i=1, 32 do
		local item = inv_list[i]
		if item then
			table.insert(formspec, "item_image_button["..x..","..y..";1,1;"..tostring(item.name)..";buttonchoice_"..tostring(item.name)..";"..item.nb.."]")
			table.insert(formspec, "label["..(x)..","..(y+0.8)..";"..item.price.."$]")
		else
			table.insert(formspec, "image["..x..","..y..";1,1;minercantile_img_inv.png]")
		end
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
	local formspec = {"size[8,6]bgcolor[#2A2A2A;]label[3.5,0;Sell Items]"}

	table.insert(formspec, "button[0.6,2;1,1;amount;-1]")
	table.insert(formspec, "button[1.6,2;1,1;amount;-10]")
	table.insert(formspec, "button[2.6,2;1,1;amount;-20]")
	--table.insert(formspec, "label[3.7,5.2;"..tostring(nb).."]")
	table.insert(formspec, "item_image_button[3.6,2;1,1;"..item..";buttonchoice_"..item..";"..nb.."]")
	table.insert(formspec, "button[4.6,2;1,1;amount;+20]")
	table.insert(formspec, "button[5.6,2;1,1;amount;+10]")
	table.insert(formspec, "button[6.6,2;1,1;amount;+1]")
	
	table.insert(formspec, "label[3,3;sell ".. nb.."x"..price.."="..nb * price.."]")
	table.insert(formspec, "button[3.3,4;1.5,1;confirm;Confirm]")
	table.insert(formspec, "button[0,0;1.5,1;abort;Return]")
	return table.concat(formspec)
end


local function get_formspec_welcome(name)
	local formspec = {"size[6,5]bgcolor[#2A2A2A;]label[2.6,0;Shop]"}
		table.insert(formspec, "image[1,1;5,1.25;minercantile_shop_welcome.png]")
		table.insert(formspec, "button[1.3,3.3;1.5,1;choice;Buy]")
		table.insert(formspec, "button[3.5,3.3;1.5,1;choice;Sell]")
	return table.concat(formspec)
end


function minercantile.get_formspec_shop_admin_shop(pos, node_name, name)
	if not shop[name] then
		shop[name]  = {}
	end
	shop[name].pos = pos
	shop[name].node_name = node_name

	local formspec = {"size[6,6]bgcolor[#2A2A2A;]label[2.2,0;Shop Admin]button[4.5,0;1.5,1;shop;Shop]"}
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
				shop_buy[name].price = minercantile.shop.get_price(item, "buy")
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
			minercantile.shop.player_sell(name, shop[name].item, shop[name].nb, shop[name].price)
			return
		elseif fields["quit"] then
			shop[name] = nil
			return
		end
		minetest.show_formspec(name, "minercantile:shop_sell_items",  get_formspec_sell_items(name))
	elseif formname == "minercantile:confirmed" then
		if fields["return_sell"] then
			show_formspec_to_sell(name)
		elseif fields["return_buy"] then
			show_formspec_to_buy(name)
		end
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
	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		meta:set_string("infotext", "Barter Shop")
		meta:set_int("open", 0)
		meta:set_int("always_open", 0)
	end,
	can_dig = function(pos, player)
		local name = player:get_player_name()
		return (minetest.check_player_privs(name, {protection_bypass = true}) or minetest.check_player_privs(name, {server = true}))
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
					minetest.show_formspec(name, "minercantile:closed", "size[6,3]bgcolor[#2A2A2A;]label[2.6,0;Shop]label[1.2,1;Sorry shop is only open 7h-21h]button_exit[2.3,2.1;1.5,1;close;Close]")
				end
			else
				minetest.show_formspec(name, "minercantile:closed", "size[6,3]bgcolor[#2A2A2A;]label[2.6,0;Shop]label[1.7,1;Sorry shop is closed]button_exit[2.3,2.1;1.5,1;close;Close]")
			end
		end
	end,
})


--nodes 
minetest.register_craft({
	output = "minercantile:shop",
	recipe = {
		{"default:wood", "default:wood", "default:wood"}, --FIXME find a free/better craft
		{"default:wood", "default:mese", "default:wood"},
		{"default:wood", "default:wood", "default:wood"},
	},
})

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
