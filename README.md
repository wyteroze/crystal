<p align="center">
  <img src="assets/icons/CrystalLogo.svg" alt="Crystal Engine logo" width="200"><br><br>
  <img src="assets/headers/CrystalHeader.svg" alt="crystal engine" width="350"><br>
  <img src="assets/headers/CrystalOneLiner.svg" alt="A simple, fast game engine that scripts in Lua and never takes control out of your hands." width="600"><br><br>
  <img src="assets/badges/version.svg" alt="Version">&ensp;<img src="assets/badges/zig.svg" alt="Zig version">
</p>

> <img src="assets/headers/crystalWarning.svg" alt="Warning" width="138"><br>
> Crystal is still in early development. This means APIs are unstable, and breaking changes occur often. Features like physics and an editor also don't exist yet. See the Roadmap below.

> <img src="assets/headers/crystalNote.svg" alt="Note" width="99"><br>
> This fork of the repository (/rewrite) is for the revamp of Crystal. Some major changes include moving to hardware-rendering, a paradigm shift to ECS, a more pragmatic Lua API, support for common filetypes, and more.

<br><img src="assets/headers/crystalAbout.svg" alt="About" width="114">

---

Crystal is a game engine written from scratch in Zig, with Lua as its scripting layer. It renders everything through its own custom software rasterizer, so there's no GPU between you and the engine; only SDL for windowing and input, and Lua for scripting.

Crystal's goal is to be a game engine that's simple and understandable, but still fast and powerful enough to make actual games in.

<br><img src="assets/headers/crystalFeatures.svg" alt="Features" width="153">

---

- Custom software 3D rasterizer with its own rendering pipeline
- Lua scripting with an easy-to-use reflection system for exposing engine objects directly to scripts
- Dedicated audio engine for playing music and SFX
- Fully scriptable keyboard and mouse input via Lua callbacks
- Widget system with custom bitmap font rendering
- Built-in support for .obj models, .bmp images, and .toml data/configs

<br><img src="assets/headers/crystalRoadmap.svg" alt="Roadmap" width="147">

---

Crystal is missing some important things before it's ready for real use:
1. A physics engine
2. A visual editor for building and playtesting games, importing assets, and more
3. General quality-of-life and polish work across the board as systems expand

<br><img src="assets/headers/crystalGettingStarted.svg" alt="Getting started" width="240">

---

> <img src="assets/headers/crystalNote.svg" alt="Note" width="99"><br>
> Currently only built and tested on macOS. Other platforms may work but aren't verified yet.

1. Clone the repo
```sh
git clone https://github.com/wyteroze/crystal.git
```
2. Install [SDL3](https://github.com/libsdl-org/SDL/releases) for your system
3. Build and run the project
```sh
zig build run
```

<br><img src="assets/headers/crystalExample.svg" alt="Example" width="138">

---

This is what scripting a scene looks like in Crystal:

```lua
local camera = Object.camera()
camera.Position = Vec3.new(0, 0, -5)
 
local scene = Scene.new("My scene")
local window = Window.new("Game window", 540, 360, 2)
window.Camera = camera
window.Scene = scene
 
local cubeMesh = Assets.loadMesh("cube.obj")
local cubeTex = Assets.loadImage("uzi.bmp")
local cube = Object.mesh(cubeMesh, cubeTex)
cube.Position = Vec3.new(2.5, 0, 0)
scene:AddObject(cube)
 
window:OnUpdate(function(dt)
    cube.Rotation = cube.Rotation + Vec3.new(dt * 5, dt * 50, dt * 20)
end)
```

<br><img src="assets/headers/crystalLicense.svg" alt="License" width="126">

---
Licensed under the [Apache 2.0 License](LICENSE)

<br><img src="assets/headers/crystalCredits.svg" alt="Credits" width="129">

---

- Skyboxes: https://screamingbrainstudios.itch.io/planet-surface-skyboxes
- Most icons: https://pixelarticons.com/
- "Oaboe" font: http://www.04.jp.org/
