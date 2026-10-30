-- The shop: styles bought with eddies. What is sold is in the catalogue;
-- what is owned comes only from signed purchases in the ledger (a style that
-- costs nothing is always owned), and what is worn is an ordinary setting,
-- one style per category.

local Catalogue = require("cyberui/data/catalogue")
local Ledger = require("cyberui/data/ledger")
local Settings = require("cyberui/settings")

local Shop = {}

Shop.categories = Catalogue

local by_id, category_of = {}, {}
for _i, cat in ipairs(Catalogue) do
    for _j, style in ipairs(cat.styles) do
        by_id[style.id] = style
        category_of[style.id] = cat
    end
end

-- The style with this id, or nil.
function Shop.style(id)
    return by_id[id]
end

-- The category a style belongs to.
function Shop.categoryOf(style)
    return category_of[style.id]
end

-- The category with this id.
function Shop.category(id)
    for _i, cat in ipairs(Catalogue) do
        if cat.id == id then return cat end
    end
end

-- Is the style the reader's: free, or bought?
function Shop.owned(style)
    return style.price == 0 or Ledger.has("s", style.id)
end

-- The setting that holds the worn style of a category.
local function key(cat_id) return "style_" .. cat_id end

-- The style worn in a category: the chosen one if it is owned, else the free one.
function Shop.worn(cat_id)
    local cat = Shop.category(cat_id)
    local chosen = by_id[Settings.get(key(cat_id))]
    if chosen and category_of[chosen.id] == cat and Shop.owned(chosen) then return chosen end
    return cat.styles[1]
end

-- Wear an owned style. Returns false for one that is not owned.
function Shop.wear(style)
    if not Shop.owned(style) then return false end
    Settings.save(key(category_of[style.id].id), style.id)
    return true
end

-- Buy a style: true, or false and why ("owned", "short").
function Shop.buy(style)
    if Shop.owned(style) then return false, "owned" end
    return Ledger.spend(style.id, style.price)
end

-- Where a style stands: "worn", "owned", "buy" (affordable) or "short", with
-- the eddies still missing for the last.
function Shop.status(style)
    if Shop.worn(category_of[style.id].id) == style then return "worn" end
    if Shop.owned(style) then return "owned" end
    local missing = style.price - Ledger.balance()
    return missing > 0 and "short" or "buy", math.max(0, missing)
end

return Shop
