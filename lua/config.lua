return {
    -- Relative paths are resolved against the project directory, not mGBA's cwd.
    rom = "auto", -- auto | crystal-de | crystal-en-10 | crystal-en-11
    mode = "validate", -- validate: stop after 8 encounters; hunt: continue
    state = "states/before-celebi.state",
    shiny = "output/celebi-shiny.state", -- existing destination ALWAYS blocks a run
    log = "output/encounters.log", -- false disables the disk log
    screenshot = false, -- optional output/celebi-shiny.state.png
    validation_encounters = 8,
    timeout_frames = 3600,
    stable_frames = 2,
    status_frames = 60,
    rng = {
        delay_count = 257, delay_stride = 73,
        gap_variants = 32, hold_variants = 4,
        identical_limit = 8, window = 32, minimum_unique = 4,
    },
    controls = {
        -- mGBA GB key bitmask: A=1, B=2, Select=4, Start=8,
        -- Right=16, Left=32, Up=64, Down=128. Stand facing the shrine.
        prefix = {}, -- optional { { keys=64, frames=1 }, { keys=0, frames=2 } }
        confirm_keys = 1,
        base_gap = 6,
    },
    -- Stable mGBA has no Lua frontend speed/pause setter. Configure Fast Forward
    -- in mGBA itself. The controller runs once per emulated frame at any speed.
    speed = "frontend",
}
