-- Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

local assets = {} :: {
    --- Loads an asset from the given path. This function can error if the asset doesn't exist 
    --- or if loading the asset fails, so wrapping it in a `pcall()` is encouraged.
    load: (path: AssetPath) -> Asset,
    --- Checks if an asset exists at the given path.
    exists: (pah: AssetPath) -> boolean,
}

return assets