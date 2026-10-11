-- Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

export type AssetPath = string
export type LoadStatus = "Success" | "Fail" | "Waiting"
export type Asset = {
    read SourcePath: string,
    read LoadStatus: LoadStatus,
    --- Halts this thread until the asset finishes loading.
    read Await: (self: Asset) -> (Asset)
}

export type ImageAsset = Asset & {
    read Size: Vec2,
}

export type FontAsset = Asset & {

}

export type MeshAsset = Asset & {

}

export type AudioAsset = Asset & {
    read SampleRate: number,
    read Channels: number,
    read Duration: number,
}

local assets = {} :: {
    --- Loads an asset from the given path. This function can error if the asset doesn't exist 
    --- or if loading the asset fails, so wrapping it in a `pcall()` is encouraged.
    load: (path: AssetPath) -> Asset,
    --- Checks if an asset exists at the given path.
    exists: (pah: AssetPath) -> boolean,
}

return assets