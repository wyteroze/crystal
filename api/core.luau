-- Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

export type Signal<T...> = {
    Connect: (self: Signal<T...>, callback: (T...) -> ()) -> (),
    Fire: (self: Signal<T...>, T...) -> ()
}

local core = {} :: {

}

return core