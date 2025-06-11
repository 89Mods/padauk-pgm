# PMS150 programmer

Open-source programmer for the Padauk PMS150 / PMC150 devices, specifically the SOT23-5 variants (SOIC-8 not supported right now).

This programmer was designed to replicate the scope traces from reverse engineering of the official programmer as closely as possible. The only thing it can’t do is modulate the VDD voltage on the target device, but can change the VPP voltage to any level between 7V and 13V or shut it off entirely.

This project is not yet the simplest possible programmer, just a jumping off point for me to start optimizing from. Its actually quite overkill, as experimenting with the hardware already shows that a constant VPP of 11V is fine and, except for Q3, the FETs could be replaced by direct connections to GPIO pins on the CH32V003. The current involves are way too tiny to require FETs to switch them. At some point in the future, I will make a new revision of this programmer that is truly as minimal as possible.

I also added support for PDK13 devices to my fork of the AS Assembler. [Check it out here.](https://github.com/AvalonSemiconductors/asl-avalonsemi/tree/avalonsemi).
