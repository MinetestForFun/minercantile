unused_args = false
allow_defined_top = true
max_line_length = 999

globals = {
    "minercantile",
}

read_globals = {
    string = {fields = {"split", "trim"}},
    table = {fields = {"copy", "getn"}},

    "minetest", "ItemStack",
    "default", "unified_inventory",
}
