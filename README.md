# Plutonium Ships Mod

**Plutonium Ships** is a Minetest mod that allows players to build and pilot custom ships and airships using blocks in the world. Players can create ships from wood, wool, and special blocks, then convert them into controllable entities.

---

## Features

* **Ship and Blimp Creation**

  * Build a ship or airship from blocks and convert it into a movable entity.
  * Ships move on water, airships float in the air.
  * Supports single driver control and passenger seats.

* **Custom Blocks**

  * Wood, wool, metal blocks, and special blocks like `plutoniumships:barre` (helm) and `plutoniumships:ballon` (balloon) can be used to build vehicles.

* **Repair System**

  * Use the **Repair Kit** to restore the ship’s structure.
  * Maximum structure is 200 points.

* **Admin Tool**

  * The **Destroyer Tool** instantly removes ships or blimps.

* **Visual Representation**

  * Ships and blimps are made of visual block entities matching the original construction.
  * Blocks can glow (e.g., lamps) or maintain their glass transparency.

* **Physics and Movement**

  * Ships obey water physics.
  * Airships can move vertically and horizontally with player controls.
  * Smooth acceleration, deceleration, and rotation mechanics.

---

## Installation

1. Place the `plutoniumships` folder in your Minetest `mods/` directory.
2. Enable the mod in your `world.mt` file or through the Minetest mod interface.
3. Launch Minetest and start building your ships!

---

## Usage

### Building a Ship or Blimp

1. Place blocks to form your structure:

   * Include **one helm (`plutoniumships:barre`)** for control.
   * Optionally include **balloons (`plutoniumships:ballon`)** for airships.
2. Right-click the helm to convert the structure into a ship or blimp.
3. Take control by right-clicking the helm in sneak mode (if repairing) or normally (if driving).

### Repairing a Vehicle

* Sneak + right-click with a **Repair Kit** to restore 10 structure points per use.

### Destroyer Tool (Admin Only)

* Instantly remove a ship or blimp by punching it with the **Destroyer Tool**.

---

## Crafting

### Repair Kit

```
anvil:hammer | default:wood | default:steel_ingot
default:wood | boats:boat   | default:wood
default:mese_crystal | default:wood | screwdriver:screwdriver
```

### Helm (`plutoniumships:barre`)

```
default:wood | repair_kit | default:wood
mesecons_materials:glue | mesecons_powerplant:power_plant | mesecons_materials:glue
default:wood | default:wood | default:wood
```

### Balloon (`plutoniumships:ballon`)

```
xdecor:rope | wool:white | xdecor:rope
wool:white | default:mese_crystal | wool:white
xdecor:rope | wool:white | xdecor:rope
```

---

## Limitations

* Maximum ship size: 50 blocks (configurable in init.lua).
* Only one helm per ship.
* At least 10 blocks required to create a ship (configurable in init.lua).
* Airships require at least 50% of blocks to be balloons to float (configurable in init.lua).


