# Galaksija Resources

This repository contains various resources for retro computer [Galaksija](https://en.wikipedia.org/wiki/Galaksija_(computer)) (eng. Galaxy). Most of this stuff is not available nowhere else and are created or adapted by me.

## Expansion Slot PCB

Many, if not most classical Galaksija computers are made without expansion port connector. This edge connector is meant to be made as two sided PCB soldered on top of the one sided motherboard.

This repository contains Gerber files for PCB manufacturing for this kind of edge connector. It is designed to be backward compatible with original edge PCB connector but has some additional signal pins as well as a power supply (VCC) pin which were omitted in the original design. These additional signals and VCC must be brought with wires and soldered to the
expansion connector PCB at marked solder pads (e.g. `READ` CPU signal should be soldered to pad marked as `RD-`). As an addition, in comparison to the original edge PCB connector, this connector has some extra ground (GND) pins provided.

Next image shows top side look of the expansion connector PCB.

![Expansion port PCB.](/images/expansion_port_pcb.png)

And the next image shows port pinout looking from the outside towards the connector.

![Expansion port pinout.](/images/expansion_port_pinout.png)

## ROM Binary Files

ROM binary files at this repository are ROM A and ROM B files for classical Galaksija computers with ROM A changed to support keyboard layout identical to layout of newer Galaksija 2024. This layout is more favorable because it allows use of standard PC keyboard keycaps. With this ROM A patch, use of standard keycaps is now possible for old/classical Galaksijas, too.

## ROM Source Files

ROM A and ROM B source files are ROM assembly source code files for classical Galaksija. ROM A source file has many additional comments and many addresses changed to more readable symbolical form, while ROM B source is equal to official source available as a PDF file and has only original comments in Serbian language.

## Machine Code Monitor

This is assembly source code for the machine code monitor program originally written by Voja Antonić in year 1984 and published in a computer magazine as a hex dump.

This version of that monitor program has rewritten disassembler part of the code. It now uses a bit more memory then before (about 2.5Kbyte vs 2Kbyte) for additional tables for instruction opcodes but actual disassembling code is much smaller then in original program. Of course, disassembler source code is also much more readable now.

The MIT License (MIT)

Copyright (c) 2024 Vitomir Spasojević (<https://github.com/DigitalVS/Galaxy-Resources>). All rights reserved.
