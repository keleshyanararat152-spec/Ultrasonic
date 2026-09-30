Platform.
i choose Arduino Platform for my Project.

Wiring.
For leds i have 4 led 2 green one Yellow and one blue.
from Arduino ground one wire to my breadboard minus and after that i connect my resistor one part to breadboard minus and second
part to led minus foot and from the led + foots i connected wires to Arduino pins.
For Ultrasonic i connected my gnd to breadboard gnd and ucc connected to 5v of Arduino and trig and echo to pins.

how HC-SR04 works
Ultrasonic works by sound waves it send 40hz sound wave to object and activates microphone and listen sound wave and when take the sound count the time.

distance formula 
because we know the sound speed 343 meter/second when we know how much time it take from the sonic to touch the object and return 
we multiply 0.0343 becuse its by millisecond and divde 2 becuse the time is bo and the return from the object.

Led Rules

first GREEn should start when button presed and formula is running and remaining three should depends on distance first blue within the 10cm range  50> yellow<150 green  in the 150> range

button behavior
button in the first press should start the led by their logic and second press turn off all.


how to build and run
engineering should have all connects like i described in wiring and connect  Arduino connect to pc.
Coding i the setup make the right pins and outputs for devices.

(Measurment Logic) in the Loop in the first i maked sure triger is low and after that sent 10 milisec sound wave with high in the triger and turned off with low when that happen i called my puls function puls func check when echo is high keep the time and after that check when will echo turn off and when turned off return start and end difference that give user distance time.
after that when we have distance with time we multiply that  0.0343 / 2 that gives me distance with cm  after that i will check ad turn the right led.

(Power logic) i have my lastButtonState variable which is keeping last state and it in the first is high becuse when power button nobody is using is keep 5v electricity and when someone pressed its become low im checking that with currentstate variable and when lastButtonState is high and currentstate is low that means someone presed button and in that time im changing system on value if it was false i will make it true and i will make false if it was true. when systemOn is false my program doing nothing and when is true it runs my setup.


in Addition i added buffer to my setup it make sound depends on the distance when distance is to short it make fast sounds when is longer slow sounds.


