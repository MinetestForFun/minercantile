local states = {}

--function load a player's wallet
function minercantile.wallet.load_wallet(name)
	if minercantile.wallets[name] == nil then
		minercantile.wallets[name] = {}
	end
	local file, err = io.open(minercantile.path_wallet..name, "r")
	if file then
		local data = minetest.deserialize(file:read("*all"))
		file:close()
		if data and type(data) == "table" then
			if data.money then
				minercantile.wallets[name].money = data.money
			else
				minercantile.wallets[name].money = 0
			end
			if data.transactions then
				minercantile.wallets[name].transactions = table.copy(data.transactions)
			else
				minercantile.wallets[name].transactions = {}
			end
			return
		end
	end
	--if new player then wallet is empty
	minercantile.wallets[name].money = 0
	minercantile.wallets[name].transactions = {}
end


function minercantile.wallet.save_wallet(name)
	local input, err = io.open(minercantile.path_wallet..name, "w")
	if input then
		input:write(minetest.serialize(minercantile.wallets[name]))
		input:close()
		minetest.log("info", "saved " .. minercantile.path_wallet..name)
	else
		minetest.log("error", "open(" .. minercantile.path_wallet..name .. ", 'w') failed: " .. err)
	end

	--unload wallet if player offline
	local connected = false
	for _, player in pairs(minetest.get_connected_players()) do
		local player_name = player:get_player_name()
		if player_name and player_name ~= "" and player_name == name then
			connected = true
			break
		end
	end
	if not connected then
		minercantile.wallets[name] = nil
	end
end


function minercantile.wallet.get_money(name)
	if minercantile.wallets[name] == nil then
		minercantile.wallet.load_wallet(name)
	end
	return minercantile.wallets[name].money
end


function minercantile.wallet.give_money(name, amount, transaction)
	if minercantile.wallets[name] == nil then
		minercantile.wallet.load_wallet(name)
	end
	minercantile.wallets[name].money = minercantile.wallet.get_money(name) + amount
	if transaction then
		local trans = os.date().. ":"..transaction
		minercantile.add_transactions(name, trans)
	end
	minercantile.wallet.save_wallet(name)
end


function minercantile.wallet.take_money(name, amount, transaction)
	if minercantile.wallets[name] == nil then
		minercantile.wallet.load_wallet(name)
	end
	minercantile.wallets[name].money = minercantile.wallet.get_money(name) - amount
	if transaction then
		local trans = os.date().. ": "..transaction
		minercantile.add_transactions(name, trans)
	end
	minercantile.wallet.save_wallet(name)
end


function minercantile.wallet.get_transactions(name)
	if minercantile.wallets[name] == nil then
		minercantile.wallet.load_wallet(name)
	end
	return minercantile.wallets[name].transactions
end


function minercantile.add_transactions(name, new_transaction)
	local old = minercantile.wallet.get_transactions(name)
	minercantile.wallets[name].transactions = {new_transaction}
	for _, trans in pairs(old) do
		table.insert(minercantile.wallets[name].transactions, trans)
		if #minercantile.wallets[name].transactions > 9 then
			break
		end
	end
end


function minercantile.send_money(sender, receiver, amount)
	if minercantile.wallet.get_money(sender) < amount then
		return false
	end
	minercantile.wallet.take_money(sender, amount, "Send "..amount.."$ to "..receiver)
	minercantile.wallet.give_money(receiver, amount, "Received "..amount.."$ from "..sender)
	return true
end


function minercantile.get_formspec_wallet(name)
	if minercantile.wallets[name] == nil then
		minercantile.wallet.load_wallet(name)
	end
	local formspec = {}
	table.insert(formspec,"size[10,9]bgcolor[#2A2A2A;]label[4.4,0;My Wallet]")
	table.insert(formspec,"label[0.5,1;Sold: ".. tostring(minercantile.wallet.get_money(name)) .."$]")
	table.insert(formspec,"label[4,2.3;10 last transactions]")
	
	local transactions = minercantile.wallet.get_transactions(name)
	if #transactions < 1 then
		table.insert(formspec,"label[3.5,4;There are no transactions]")
	else
		local y = 3
		for _,transac in pairs(transactions) do
		table.insert(formspec,"label[1.5,"..y..";".. transac .."]")
			y = y+0.4
		end
	end

	table.insert(formspec,"button[0,8.2;1.5,1;page;Transfert]")
	table.insert(formspec,"button_exit[8,8.2;1.5,1;close;Close]")
	return table.concat(formspec)
end


function minercantile.get_formspec_wallet_transfert(name)
	local money = minercantile.wallet.get_money(name)
	local formspec = {}
	table.insert(formspec,"size[10,9]bgcolor[#2A2A2A;]label[4.4,0;My Wallet]")
	table.insert(formspec,"label[0.5,1;Sold: ".. tostring(money) .."$]")
	
	if money < 5 then
		table.insert(formspec, "label[2,4.5;Sorry you can't send money, minimum amount is 5$]")
	else
		if not states[name] then
			states[name] = {}
		end
		if not states[name].players_list or states[name].refresh then
			states[name].refresh = nil
			states[name].players_list = {}
			states[name].selected_id = 0
			for _,player in pairs(minetest.get_connected_players()) do
				local player_name = player:get_player_name()
				if player_name and player_name ~= "" and player_name ~= name then
					table.insert(states[name].players_list, player_name)
				end
			end
			states[name]["receiver"] = nil
		end
		if not states[name].amount then
			states[name].amount = 5
		end
		if #states[name].players_list == 0 then
			table.insert(formspec, "label[2,3.6;There are no player, refresh]")
			table.insert(formspec,"button[6,3.4;2,1;refresh;refresh list]")
		else
			table.insert(formspec, "dropdown[3,3.5;3,1;receiver;"..table.concat(states[name].players_list, ",")..";"..states[name].selected_id.."]")
			table.insert(formspec, "label[3.5,6.4;Send "..states[name]["amount"].."$ to "..(states[name]["receiver"] or "").." ?]")
			table.insert(formspec,"button[4.1,7;1.5,1;send;send]")
			table.insert(formspec,"button[6,3.4;1.5,1;refresh;refresh list]")	
			table.insert(formspec, "label[3.5,4.5;Amount to send (minimum 5$)]")
			table.insert(formspec, "button[1.7,5;1,1;amount;-1]")
			table.insert(formspec, "button[2.7,5;1,1;amount;-10]")
			table.insert(formspec, "button[3.7,5;1,1;amount;-100]")
			table.insert(formspec, "label[4.7,5.2;"..tostring(states[name]["amount"]).."]")
			table.insert(formspec, "button[5.4,5;1,1;amount;+100]")
			table.insert(formspec, "button[6.4,5;1,1;amount;+10]")
			table.insert(formspec, "button[7.4,5;1,1;amount;+1]")
		end
	end
	table.insert(formspec,"button[0,8.2;1.5,1;page;wallet]")
	table.insert(formspec,"button_exit[8,8.2;1.5,1;close;Close]")
	return table.concat(formspec)
end


function minercantile.get_formspec_wallet_transfert_send(name)
	local formspec = {"size[6,3]bgcolor[#2A2A2A;]label[2,0;Validate sending]"}
	table.insert(formspec, "label[2,1.2;Send "..tostring(states[name]["amount"]).."$ to ".. states[name]["receiver"] .."]")
	table.insert(formspec, "button_exit[1.1,2.1;1.5,1;close;Abort]")
	table.insert(formspec, "button[3.3,2.1;1.5,1;send;Send]")
	return table.concat(formspec)
end


minetest.register_on_player_receive_fields(function(player, formname, fields)
	local name = player:get_player_name()
	if not name or name == "" then return end
	if formname == "minercantile:ended" then
		states[name] = nil
		return
	elseif formname == "minercantile:wallet" then
		if fields["quit"] or fields["close"] then
			states[name] = nil
			return
		elseif fields["page"] then
			minetest.show_formspec(name, "minercantile:transfert", minercantile.get_formspec_wallet_transfert(name))
			return
		end
	elseif formname == "minercantile:transfert" then
		if fields["quit"] then
			states[name] = nil
			return
		elseif fields["page"] then
			minetest.show_formspec(name, "minercantile:wallet", minercantile.get_formspec_wallet(name))
			return
		elseif fields["refresh"] then
			states[name].refresh = true
		elseif fields["amount"] then
			local inc = tonumber(fields["amount"])
			if inc ~= nil then
				states[name]["amount"] = states[name]["amount"] + inc
			end
			if states[name]["amount"] > minercantile.wallet.get_money(name) then
				 states[name]["amount"] = minercantile.wallet.get_money(name)
			end
			if states[name]["amount"] < 5 then
				 states[name]["amount"] = 5
			end
		elseif fields["send"] then
			if states[name]["receiver"] and states[name]["receiver"] ~= "" then
				minetest.show_formspec(name, "minercantile:transfert_send", minercantile.get_formspec_wallet_transfert_send(name))
				return
			end
		elseif fields["receiver"] then
			for i, n in pairs(states[name].players_list) do
				if n == fields["receiver"] then
					states[name]["receiver"] = fields["receiver"]
					states[name].selected_id = i
					break
				end
			end
		end
		minetest.show_formspec(name, "minercantile:transfert", minercantile.get_formspec_wallet_transfert(name))
	elseif formname == "minercantile:transfert_send" then
		if fields["send"] then
			if minercantile.send_money( name, states[name]["receiver"], states[name]["amount"]) then
				minetest.show_formspec(name, "minercantile:ended", "size[5,3]bgcolor[#2A2A2A;]label[1.8,0;Validated]label[1.7,1;Money sent]button_exit[1.8,2.1;1.5,1;close;Close]")
			else
				minetest.show_formspec(name, "minercantile:ended", "size[5,3]bgcolor[#2A2A2A;]label[1.6,0;Error]label[1.6,1;Error occured]button_exit[1.8,2.1;1.5,1;close;Close]")
			end
		elseif fields["quit"] or fields["close"] then
			states[name] = nil
			return
		end
	end
end)


if (minetest.get_modpath("unified_inventory")) then
	unified_inventory.register_button("wallet", {
		type = "image",
		image = "minercantile_gold_coin.png",
		tooltip = "My Wallet",
		show_with = "interact",
		action = function(player)
			local name = player:get_player_name()
			if not name then return end
			local formspec = minercantile.get_formspec_wallet(name)
			minetest.show_formspec(name, "minercantile:wallet", formspec)
		end,
	})
else
	minetest.register_chatcommand("wallet",{
		params = "",
		description = "Shows your money wallet",
		privs = {interact= true},
		func = function (name, params)
		local formspec = minercantile.get_formspec_wallet(name)
		minetest.show_formspec(name, "minercantile:wallet", formspec)
		end,
	})
end


minetest.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	if not name or name == "" then return end
	minercantile.wallet.load_wallet(name)
end)

minetest.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	if not name or name == "" then return end
	minercantile.wallets[name] = nil
end)

