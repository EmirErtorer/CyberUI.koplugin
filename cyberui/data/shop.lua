-- The shop: styles bought with eddies. What is sold is in the catalogue;
-- what is owned comes only from signed purchases in the ledger (a style that
-- costs nothing is always owned), and what is worn is an ordinary setting,
-- one style per category.

local Catalogue = require("cyberui/data/catalogue")
local Economy = require("cyberui/data/economy")
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

-- Was the style paid for (or is it free)? Only this ever counts for keeps.
local function bought(style)
    return style.price == 0 or Ledger.has("s", style.id)
end

-- Is the style the reader's to wear: bought, or lent while the economy is off?
function Shop.owned(style)
    return bought(style) or not Economy.on()
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

-- Put back the free style wherever a look that was never paid for is worn,
-- and forget the choice, so it does not return if it is bought later.
function Shop.revert()
    for _i, cat in ipairs(Catalogue) do
        local chosen = by_id[Settings.get(key(cat.id))]
        if chosen and not bought(chosen) then Settings.set(key(cat.id), nil) end
    end
    Settings.flush()
end

-- Buy a style: true, or false and why ("off", "owned", "short").
function Shop.buy(style)
    if not Economy.on() then return false, "off" end
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
