-- Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

-- MATH --

declare extern type Vec2 with
    read X: number
    read Y: number

    --- Returns the length of this `Vec2`.
    function Length(self): number
    --- Returns a normalized copy of this `Vec2`. If its length is zero, this results in `nan`.
    function Normalize(self): Vec2
    --- Returns the dot product of this `Vec2` and the given `Vec2`.
    function Dot(self, other: Vec2): number
end

declare extern type Vec3 with
    read X: number
    read Y: number
    read Z: number

    --- Returns the length of this `Vec3`.
    function Length(self): number
    --- Returns a normalized copy of this `Vec3`. If its length is zero, this results in `nan`.
    function Normalize(self): Vec3
    --- Returns the dot product of this `Vec3` and the given `Vec3`.
    function Dot(self, other: Vec3): number
    --- Returns the cross product of this `Vec3` and the given `Vec3`.
    function Cross(self, other: Vec3): Vec3

	function __add(self, other: Vec3): Vec3
	function __div(self, other: Vec3 | number): Vec3
	function __idiv(self, other: Vec3 | number): Vec3
	function __mul(self, other: Vec3 | number): Vec3
	function __sub(self, other: Vec3): Vec3
	function __unm(self): Vec3
end

declare extern type Quat with
    --- The X (1st) component of this `Quat`.
    read X: number
    --- The Y (2nd) component of this `Quat`.
    read Y: number
    --- The Z (3rd) component of this `Quat`.
    read Z: number
    --- The W (4th) component of this `Quat`.
    read W: number

    --- Returns a normalized copy of this `Quat`. If its length is zero, this results in `nan`.
    function Normalize(self): Quat
    --- Returns the inverse of this `Quat`.
    function Inverse(self): Quat
    --- Interpolates this `Quat` to the target with the given alpha using spherical linear interpolation.
    function Slerp(self, target: Quat, alpha: number): Quat
    
    function __mul(self, other: Vec3): Vec3
    function __mul(self, other: Quat): Quat
end

declare extern type Mat4 with
    read C00: number
    read C01: number
    read C02: number
    read C03: number

    read C10: number
    read C11: number
    read C12: number
    read C13: number

    read C20: number
    read C21: number
    read C22: number
    read C23: number

    read C30: number
    read C31: number
    read C32: number
    read C33: number

    --- Returns the inverse of this `Mat4`.
    function Inverse(self): Mat4
    --- Returns the transpose of this `Mat4`.
    function Transpose(self): Mat4
    
    function __mul(self, other: Vec3): Vec3
    function __mul(self, other: Mat4): Mat4
end

declare extern type Transform with
    read Position: Vec3
    read Rotation: Quat
    read Scale: Vec3

    function ToMat4(self): Mat4
    function ForwardVector(self): Vec3
    function RightVector(self): Vec3
    function UpVector(self): Vec3
end

-- Math globals

--- A 3D value that has a length and direction.
declare Vec3: {
    --- Creates a new `Vec3` from the given components.
    read new: (x: number?, y: number?, z: number?) -> Vec3,
    --- A `Vec3` with 0 length.
    read zero: Vec3,
    --- A `Vec3` with 1 length.
    read one: Vec3,
    --- A `Vec3` with a value of 1 on the X axis.
    read xAxis: Vec3,
    --- A `Vec3` with a value of 1 on the Y axis.
    read yAxis: Vec3,
    --- A `Vec3` with a value of 1 on the Z axis.
    read xAxis: Vec3,
}

--- A 4D value, commonly used for representing 3D rotation.
declare Quat: {
    --- A `Quat` with zero rotation.
    read Identity: Quat,
    --- Creates a `Quat` with the given Euler rotation.
    read fromEuler: (euler: Vec3) -> Quat,
    --- Creates a `Quat` of the given axis rotated around the given angle in degrees.
    read axisAngle: (axis: Vec3, angle: number) -> Quat,
    --- Creates a `Quat` facing the given direction, optionally with an up vector of the given value.
    read lookRotation: (direction: Vec3, up: Vec3?) -> Quat,
}

--- A matrix with 4 rows and 4 columns, for a total of 16 values.
declare Mat4: {
    --- A constant representing a `Mat4` with no translation or rotation, and a unit scale.
    read identity: Mat4,
    --- Creates a new `Mat4` with a translation of the given value, no rotation, and a unit scale.
    read fromTranslation: (translation: Vec3) -> Mat4,
    --- Creates a new `Mat4` with a rotation of the given value, no translation, and a unit scale.
    read fromRotation: (rotation: Quat) -> Mat4,
    --- Creates a new `Mat4` with a scale of the given value, no translation, and no rotation. 
    read fromScale: (scale: Vec3) -> Mat4,
    --- Creates a new `Mat4` with a translation, rotation, and scale of the given values.
    read fromTRS: (translation: Vec3, rotation: Quat, scale: Vec3) -> Mat4,
}

export type SignalConnection = {
    Disconnect: (self: SignalConnection) -> ()
}

export type Signal<T...> = {
    Connect: (self: Signal<T...>, callback: (T...) -> ()) -> SignalConnection,
    Fire: (self: Signal<T...>, T...) -> ()
}

-- ECS --

declare extern type Entity with
    --- Adds a pre-registered component of the given name with the given value. This does not implicitly register components.
    --- You must register custom components using `World:RegisterComponent()` prior to using this.
    function AddComponent(self, name: string, value: any): ()

    --- Fires when this entity is destroyed.
    Destroyed: Signal<()>
    --- Fires when this entity is updated, with the frame delta time as the first argument.
    Updated: Signal<number>
    
    Components: { [string]: any }
end