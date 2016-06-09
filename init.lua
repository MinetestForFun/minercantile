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
minercantile.stock.money = 800000
minercantile.stock.transac_b = 0
minercantile.stock.transac_s = 0

--functions specific to wallet
minercantile.wallet = {}
-- table players wallets
minercantile.wallets = {}

--load money
dofile(minetest.get_modpath("minercantile") .. "/wallets.lua")
dofile(minetest.get_modpath("minercantile") .. "/change.lua")
dofile(minetest.get_modpath("minercantile") .. "/shop.lua")



--load items base and available
minercantile.load_stock_base()
minetest.after(1, function()
		minercantile.shop.register_items()
		minercantile.load_stock()
	end
)
minetest.log("action", "[minercantile] Loaded")
