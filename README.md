# CandleFlameSim
Candle flame/flicker simulator based on PIC Microcontroller.

The original circuit was designed for use with LEDs or low-voltage lamps (you'll find details in the code comments), but it can be easily adapted for bigger loads as below.

![Image](flicker.jpg)
*Driving a logic level FET via 120 Ohm resistor - used with a 12V 20/50W halogen lamp or 55W car headlamp bulb for stage effects (fireplaces etc.)*

The FET barely gets warm with a 4.5A load so no heatsink is required. The 'Transistor' on the right is a 5V (78L05) voltage regulator for the PIC. There's some thick wiring on the back of the stripboard connecting the FET to the terminals, and also some wirewrap wire between the 12V in and the PIC/voltage regulator.
