# Advanced Weapons

Adds a variety of advanced weapons.

## About

Depends on `modlib` and `tnt`.
Written by LMD aka appguru(eu). Licensed under the MIT license.

## Screenshot

![Screenshot](screenshot.png)

## API

```lua
-- override this, should return true if names are opponents
function adv_weapons.is_opponent(playername1, playername2)
    return playername1 ~= playername2
end
```

## Features

* Explosives
  * Landmines
    * Place them on full height blocks
    * Walking on them triggers explosion
    * Can be (un)buried by digging node below them
    * Buried landmines are harder to spot & can't be easily picked up
* Special
  * Futuristic Grappling Hook
    * Throw to hook it somewhere
      * Creates Force Beam
    * Right-click ascent aid to (de)attach
      * Go forwards/backwards on the beam
  * Turrets
    * Gatlin Gun
      * Right-click turret base with gatlin barrel to arm
      * High reload rate, low damage & range
      * Turns slowly, so you can try dodging
      * Only attacks owners opponents
      * Destroying/digging the base destroys the turret
  * ~~Whips~~ temporarily cancelled as unfinished
    * High range, average damage
    * Causes bleeding & stunning (by chance)
    * Right-click to "capture" player
      * Drops their wielded item
      * Player can't attack while captured
      * Can be dragged around
      * Unleashed as soon as RMB is released
* Many more!
  * Soon
