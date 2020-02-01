# sim7

Intergrate the snap7 PLC library into MATLAB via system objects.

## Requirements

* Linux OS
* MATLAB (18a or later) w/ Coder & RTW addons
* PLC (pingable)

## Installation

Install the snap7 library as outlined in snap7's documentation. Note install not just build, else you will need to modify the `sim7.m` source to point to the correct items.

The `snap7.h` header file requires some changes to work with MATLAB:

1) remove/change the bool typedef
2) guard the true/false defines
3) add static keyword to all const variable declarations

## Useage

A MATLAB example is given below:

    conn = sim7();
    conn.loadSnap7();

    u1 = uint8(1);
    u2 = uint8(2);

    conn.setup(u1,u2);
    [y1, y2] = conn.step(u1,u2);
    conn.release();

A simulink [model](./tests/test7.slx) is included in the [tests](./tests/) folder to demonstrate operation within Simulink. The models compiles via RTW for a standalone executable.

## Notes

More features are available via S-Functions but system objects are (relatively) quick and easy. Plus they work in MATLAB and don't need TLC for codegen.

## Links

[snap7](http://snap7.sourceforge.net/)
