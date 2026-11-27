--[[
    Nexaris Rarity System - Configuration
    Clean-room implementation for TFS 1.8 Downgrade (Protocol 8.60)
]]

Rarity = Rarity or {}

-- Rarity Tiers
Rarity.TIERS = {
    COMMON    = 0,
    UNCOMMON  = 1,
    RARE      = 2,
    EPIC      = 3,
    LEGENDARY = 4,
    MYTHIC    = 5,
    ETERNAL   = 6,
}

Rarity.TIER_INFO = {
    [Rarity.TIERS.COMMON] = {
        name = "Common",
        color = "#CCCCCC",
        colorCode = 129, -- White / Default
        maxSlots = 0,
        canAwaken = false,
        prefix = ""
    },
    [Rarity.TIERS.UNCOMMON] = {
        name = "Uncommon",
        color = "#4BB543",
        colorCode = 30, -- Green
        maxSlots = 1,
        canAwaken = false,
        prefix = "[Uncommon]"
    },
    [Rarity.TIERS.RARE] = {
        name = "Rare",
        color = "#3498DB",
        colorCode = 35, -- Blue
        maxSlots = 2,
        canAwaken = false,
        prefix = "[Rare]"
    },
    [Rarity.TIERS.EPIC] = {
        name = "Epic",
        color = "#9B59B6",
        colorCode = 84, -- Purple / Violet
        maxSlots = 3,
        canAwaken = false,
        prefix = "[Epic]"
    },
    [Rarity.TIERS.LEGENDARY] = {
        name = "Legendary",
        color = "#E67E22",
        colorCode = 198, -- Orange / Gold
        maxSlots = 4,
        canAwaken = true,
        nextTier = Rarity.TIERS.MYTHIC,
        downgradeTier = Rarity.TIERS.EPIC,
        prefix = "[Legendary]"
    },
    [Rarity.TIERS.MYTHIC] = {
        name = "Mythic",
        color = "#E74C3C",
        colorCode = 180, -- Crimson Red
        maxSlots = 5,
        canAwaken = true,
        nextTier = Rarity.TIERS.ETERNAL,
        downgradeTier = Rarity.TIERS.LEGENDARY,
        prefix = "[Mythic]"
    },
    [Rarity.TIERS.ETERNAL] = {
        name = "Eternal",
        color = "#00FFFF",
        colorCode = 71, -- Cyan / Cosmic
        maxSlots = 6,
        canAwaken = false,
        prefix = "[Eternal]"
    },
}

-- Currency & Materials: Essences (Configurable Item IDs)
-- No conversion between tiers is allowed.
Rarity.ESSENCE_ITEMS = {
    [Rarity.TIERS.COMMON]    = { itemId = 3038, name = "Common Essence" },    -- green gem ID placeholder
    [Rarity.TIERS.UNCOMMON]  = { itemId = 3037, name = "Uncommon Essence" },  -- yellow gem
    [Rarity.TIERS.RARE]      = { itemId = 3041, name = "Rare Essence" },      -- blue gem
    [Rarity.TIERS.EPIC]      = { itemId = 3036, name = "Epic Essence" },      -- violet gem
    [Rarity.TIERS.LEGENDARY] = { itemId = 3039, name = "Legendary Essence" }, -- red gem
    [Rarity.TIERS.MYTHIC]    = { itemId = 3042, name = "Mythic Essence" },    -- magic sulphur
    [Rarity.TIERS.ETERNAL]   = { itemId = 942,  name = "Eternal Essence" },   -- flawless ice crystal
}

-- Protection Material for Awakening (Prevent downgrade on failure)
Rarity.PROTECTION_MATERIAL = {
    itemId = 3061, -- Life Crystal
    name = "Awakening Protection Stone"
}

-- Equipment Slots allowed for Rarity
Rarity.ALLOWED_SLOTS = {
    [CONST_SLOT_HEAD]     = "helmet",
    [CONST_SLOT_NECKLACE] = "necklace",
    [CONST_SLOT_ARMOR]    = "armor",
    [CONST_SLOT_RIGHT]    = "hand",
    [CONST_SLOT_LEFT]     = "hand",
    [CONST_SLOT_LEGS]     = "legs",
    [CONST_SLOT_FEET]     = "feet",
    [CONST_SLOT_RING]     = "ring",
}

-- Bonus Pool Definitions
-- Each bonus has applicable item categories and [min, max] range per tier.
-- Categories: "weapon", "shield", "armor", "helmet", "legs", "boots", "jewelry"
Rarity.BONUS_DEFINITIONS = {
    ["flat_atk"] = {
        name = "Bonus Attack",
        format = "Attack: +%d",
        categories = { "weapon" },
        ranges = {
            [Rarity.TIERS.UNCOMMON]  = { min = 1,  max = 2 },
            [Rarity.TIERS.RARE]      = { min = 2,  max = 4 },
            [Rarity.TIERS.EPIC]      = { min = 4,  max = 7 },
            [Rarity.TIERS.LEGENDARY] = { min = 7,  max = 11 },
            [Rarity.TIERS.MYTHIC]    = { min = 12, max = 16 },
            [Rarity.TIERS.ETERNAL]   = { min = 17, max = 24 },
        }
    },
    ["flat_def"] = {
        name = "Bonus Defense",
        format = "Defense: +%d",
        categories = { "weapon", "shield" },
        ranges = {
            [Rarity.TIERS.UNCOMMON]  = { min = 1,  max = 2 },
            [Rarity.TIERS.RARE]      = { min = 2,  max = 4 },
            [Rarity.TIERS.EPIC]      = { min = 4,  max = 6 },
            [Rarity.TIERS.LEGENDARY] = { min = 7,  max = 10 },
            [Rarity.TIERS.MYTHIC]    = { min = 11, max = 15 },
            [Rarity.TIERS.ETERNAL]   = { min = 16, max = 22 },
        }
    },
    ["flat_arm"] = {
        name = "Bonus Armor",
        format = "Armor: +%d",
        categories = { "armor", "helmet", "legs", "boots" },
        ranges = {
            [Rarity.TIERS.UNCOMMON]  = { min = 1,  max = 1 },
            [Rarity.TIERS.RARE]      = { min = 2,  max = 3 },
            [Rarity.TIERS.EPIC]      = { min = 3,  max = 5 },
            [Rarity.TIERS.LEGENDARY] = { min = 5,  max = 8 },
            [Rarity.TIERS.MYTHIC]    = { min = 9,  max = 12 },
            [Rarity.TIERS.ETERNAL]   = { min = 13, max = 18 },
        }
    },
    ["max_hp"] = {
        name = "Max Health",
        format = "Max Health: +%d",
        categories = { "armor", "helmet", "legs", "boots", "jewelry" },
        ranges = {
            [Rarity.TIERS.UNCOMMON]  = { min = 20,  max = 50 },
            [Rarity.TIERS.RARE]      = { min = 50,  max = 100 },
            [Rarity.TIERS.EPIC]      = { min = 100, max = 200 },
            [Rarity.TIERS.LEGENDARY] = { min = 200, max = 350 },
            [Rarity.TIERS.MYTHIC]    = { min = 350, max = 550 },
            [Rarity.TIERS.ETERNAL]   = { min = 600, max = 1000 },
        }
    },
    ["max_mp"] = {
        name = "Max Mana",
        format = "Max Mana: +%d",
        categories = { "armor", "helmet", "legs", "boots", "jewelry" },
        ranges = {
            [Rarity.TIERS.UNCOMMON]  = { min = 20,  max = 50 },
            [Rarity.TIERS.RARE]      = { min = 50,  max = 100 },
            [Rarity.TIERS.EPIC]      = { min = 100, max = 200 },
            [Rarity.TIERS.LEGENDARY] = { min = 200, max = 350 },
            [Rarity.TIERS.MYTHIC]    = { min = 350, max = 550 },
            [Rarity.TIERS.ETERNAL]   = { min = 600, max = 1000 },
        }
    },
    ["crit_chance"] = {
        name = "Critical Chance",
        format = "Critical Chance: +%d%%",
        categories = { "weapon", "jewelry" },
        ranges = {
            [Rarity.TIERS.UNCOMMON]  = { min = 1, max = 2 },
            [Rarity.TIERS.RARE]      = { min = 2, max = 3 },
            [Rarity.TIERS.EPIC]      = { min = 3, max = 5 },
            [Rarity.TIERS.LEGENDARY] = { min = 5, max = 8 },
            [Rarity.TIERS.MYTHIC]    = { min = 8, max = 12 },
            [Rarity.TIERS.ETERNAL]   = { min = 13, max = 18 },
        }
    },
    ["life_leech"] = {
        name = "Life Leech",
        format = "Life Leech: +%d%%",
        categories = { "weapon", "armor" },
        ranges = {
            [Rarity.TIERS.UNCOMMON]  = { min = 1, max = 2 },
            [Rarity.TIERS.RARE]      = { min = 2, max = 3 },
            [Rarity.TIERS.EPIC]      = { min = 3, max = 5 },
            [Rarity.TIERS.LEGENDARY] = { min = 5, max = 8 },
            [Rarity.TIERS.MYTHIC]    = { min = 8, max = 12 },
            [Rarity.TIERS.ETERNAL]   = { min = 13, max = 18 },
        }
    },
    ["mana_leech"] = {
        name = "Mana Leech",
        format = "Mana Leech: +%d%%",
        categories = { "weapon", "helmet" },
        ranges = {
            [Rarity.TIERS.UNCOMMON]  = { min = 1, max = 2 },
            [Rarity.TIERS.RARE]      = { min = 2, max = 3 },
            [Rarity.TIERS.EPIC]      = { min = 3, max = 4 },
            [Rarity.TIERS.LEGENDARY] = { min = 4, max = 6 },
            [Rarity.TIERS.MYTHIC]    = { min = 6, max = 9 },
            [Rarity.TIERS.ETERNAL]   = { min = 10, max = 15 },
        }
    },
    ["bonus_speed"] = {
        name = "Speed",
        format = "Speed: +%d",
        categories = { "boots", "jewelry" },
        ranges = {
            [Rarity.TIERS.UNCOMMON]  = { min = 5,  max = 10 },
            [Rarity.TIERS.RARE]      = { min = 10, max = 20 },
            [Rarity.TIERS.EPIC]      = { min = 20, max = 35 },
            [Rarity.TIERS.LEGENDARY] = { min = 35, max = 50 },
            [Rarity.TIERS.MYTHIC]    = { min = 50, max = 75 },
            [Rarity.TIERS.ETERNAL]   = { min = 80, max = 120 },
        }
    },
    ["skill_melee"] = {
        name = "Melee Skills",
        format = "Melee Skills: +%d",
        categories = { "weapon", "shield", "jewelry" },
        ranges = {
            [Rarity.TIERS.UNCOMMON]  = { min = 1, max = 1 },
            [Rarity.TIERS.RARE]      = { min = 1, max = 2 },
            [Rarity.TIERS.EPIC]      = { min = 2, max = 3 },
            [Rarity.TIERS.LEGENDARY] = { min = 3, max = 5 },
            [Rarity.TIERS.MYTHIC]    = { min = 5, max = 8 },
            [Rarity.TIERS.ETERNAL]   = { min = 9, max = 14 },
        }
    },
    ["skill_dist"] = {
        name = "Distance Skill",
        format = "Distance Skill: +%d",
        categories = { "weapon", "jewelry" },
        ranges = {
            [Rarity.TIERS.UNCOMMON]  = { min = 1, max = 1 },
            [Rarity.TIERS.RARE]      = { min = 1, max = 2 },
            [Rarity.TIERS.EPIC]      = { min = 2, max = 3 },
            [Rarity.TIERS.LEGENDARY] = { min = 3, max = 5 },
            [Rarity.TIERS.MYTHIC]    = { min = 5, max = 8 },
            [Rarity.TIERS.ETERNAL]   = { min = 9, max = 14 },
        }
    },
    ["skill_magic"] = {
        name = "Magic Level",
        format = "Magic Level: +%d",
        categories = { "weapon", "helmet", "jewelry" },
        ranges = {
            [Rarity.TIERS.UNCOMMON]  = { min = 1, max = 1 },
            [Rarity.TIERS.RARE]      = { min = 1, max = 2 },
            [Rarity.TIERS.EPIC]      = { min = 2, max = 3 },
            [Rarity.TIERS.LEGENDARY] = { min = 3, max = 4 },
            [Rarity.TIERS.MYTHIC]    = { min = 5, max = 7 },
            [Rarity.TIERS.ETERNAL]   = { min = 8, max = 12 },
        }
    },
    ["res_all"] = {
        name = "All Protection",
        format = "All Protection: +%d%%",
        categories = { "armor", "shield", "jewelry" },
        ranges = {
            [Rarity.TIERS.UNCOMMON]  = { min = 1, max = 1 },
            [Rarity.TIERS.RARE]      = { min = 1, max = 2 },
            [Rarity.TIERS.EPIC]      = { min = 2, max = 3 },
            [Rarity.TIERS.LEGENDARY] = { min = 3, max = 5 },
            [Rarity.TIERS.MYTHIC]    = { min = 5, max = 8 },
            [Rarity.TIERS.ETERNAL]   = { min = 9, max = 14 },
        }
    },
}

-- Loot & Gating Configuration
Rarity.LOOT_CONFIG = {
    -- Minimum PowerScore required for a monster to even attempt rarity rolls
    MIN_SCORE_FOR_RARITY = 80,

    -- PowerScore Tier Caps: A monster cannot drop higher than its cap.
    CAPS = {
        { maxScore = 300,   maxTier = Rarity.TIERS.UNCOMMON },
        { maxScore = 1200,  maxTier = Rarity.TIERS.RARE },
        { maxScore = 3500,  maxTier = Rarity.TIERS.EPIC },
        { maxScore = 8000,  maxTier = Rarity.TIERS.LEGENDARY },
        { maxScore = 99999, maxTier = Rarity.TIERS.MYTHIC },
        -- Eternal is never rolled directly from normal monsters
    },

    -- Boss PowerScore Bonuses
    BOSS_WEIGHTS = {
        DEFAULT = 1500,
        BOOSTED_BOSS = 3000,
        NEMESIS = 5000,
        ARCHFOE = 3000,
        BANE = 1000,
    },

    -- Base chance dividers (Calculated as: chance = powerScore / divider)
    -- Lower divider = higher drop chance.
    TIER_CHANCE_DIVIDERS = {
        [Rarity.TIERS.UNCOMMON]  = 40,    -- e.g. Score 800 -> 20%
        [Rarity.TIERS.RARE]      = 120,   -- e.g. Score 1200 -> 10%
        [Rarity.TIERS.EPIC]      = 400,   -- e.g. Score 2000 -> 5%
        [Rarity.TIERS.LEGENDARY] = 1500,  -- e.g. Score 8000 -> 5.3%
        [Rarity.TIERS.MYTHIC]    = 8000,  -- e.g. Score 15000 -> 1.8%
    },

    -- Test switch: When true, EVERY dropped equipment is 100% guaranteed to be a Rarity item!
    FORCE_DROP_TEST = true,

    -- Global drop rate multiplier (1.0 = standard, 2.0 = double drop rate, etc.)
    CHANCE_MULTIPLIER = 1.0,

    -- Multiple rarity drops per kill configuration (Diminishing returns & caps)
    MULTIPLE_DROPS = {
        MAX_RARITY_PER_MONSTER = 1,          -- Regular monsters: at most 1 rarity item per corpse
        MAX_RARITY_PER_BOSS = 2,             -- Bosses: at most 2 rarity items per kill
        SUBSEQUENT_CHANCE_MULTIPLIER = 0.10, -- 90% chance penalty (0.10) for each subsequent rarity drop
    },
}

-- Salvage Configuration
Rarity.SALVAGE_CONFIG = {
    -- Amount of essences yielded by tier
    YIELDS = {
        [Rarity.TIERS.COMMON]    = { min = 1, max = 2 },
        [Rarity.TIERS.UNCOMMON]  = { min = 1, max = 3 },
        [Rarity.TIERS.RARE]      = { min = 2, max = 4 },
        [Rarity.TIERS.EPIC]      = { min = 3, max = 5 },
        [Rarity.TIERS.LEGENDARY] = { min = 4, max = 8 },
        [Rarity.TIERS.MYTHIC]    = { min = 6, max = 12 },
        [Rarity.TIERS.ETERNAL]   = { min = 10, max = 20 },
    },
    -- Multiplier based on item slot (heavier items yield more)
    SLOT_MULTIPLIERS = {
        ["armor"]   = 1.5,
        ["legs"]    = 1.3,
        ["weapon"]  = 1.2,
        ["shield"]  = 1.2,
        ["helmet"]  = 1.0,
        ["boots"]   = 1.0,
        ["necklace"]= 0.8,
        ["ring"]    = 0.8,
    }
}

-- Random Roll Configuration
Rarity.RANDOM_ROLL_CONFIG = {
    -- Essence cost to add a new bonus to an empty slot
    ADD_SLOT_COST = {
        [Rarity.TIERS.UNCOMMON]  = { essence = 2,  gold = 10000 },
        [Rarity.TIERS.RARE]      = { essence = 4,  gold = 30000 },
        [Rarity.TIERS.EPIC]      = { essence = 8,  gold = 80000 },
        [Rarity.TIERS.LEGENDARY] = { essence = 15, gold = 200000 },
        [Rarity.TIERS.MYTHIC]    = { essence = 25, gold = 500000 },
        [Rarity.TIERS.ETERNAL]   = { essence = 40, gold = 1500000 },
    },
    -- Essence cost to reroll an existing slot
    REROLL_SLOT_COST = {
        [Rarity.TIERS.UNCOMMON]  = { essence = 1,  gold = 5000 },
        [Rarity.TIERS.RARE]      = { essence = 2,  gold = 15000 },
        [Rarity.TIERS.EPIC]      = { essence = 4,  gold = 40000 },
        [Rarity.TIERS.LEGENDARY] = { essence = 8,  gold = 100000 },
        [Rarity.TIERS.MYTHIC]    = { essence = 15, gold = 250000 },
        [Rarity.TIERS.ETERNAL]   = { essence = 25, gold = 800000 },
    }
}

-- Awakening Configuration
Rarity.AWAKENING_CONFIG = {
    [Rarity.TIERS.LEGENDARY] = {
        targetTier = Rarity.TIERS.MYTHIC,
        successChance = 20,       -- 20% base chance
        failProgress = 10,        -- +10 progress on failure
        pityThreshold = 80,       -- 80 progress guarantees success (100%)
        essenceCost = 20,         -- Legendary Essence
        goldCost = 500000,        -- 500k gold
    },
    [Rarity.TIERS.MYTHIC] = {
        targetTier = Rarity.TIERS.ETERNAL,
        successChance = 5,        -- 5% base chance
        failProgress = 5,         -- +5 progress on failure
        pityThreshold = 100,      -- 100 progress guarantees success (100%)
        essenceCost = 35,         -- Mythic Essence
        goldCost = 2000000,       -- 2kk gold
    }
}
