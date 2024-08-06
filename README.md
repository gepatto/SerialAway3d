# SerialAway3d

***A Haxe Away3D example reading data from a serialport***

This example reads data from a serialport.  
It expects newline seperated lines.
lines should be 4 comma separated values: ie 10,25,0,1 where:  
value 1 is Roll (0-359)   
value 2 is Pitch (0-359)  
value 3 is bntA pressed (1 or 0)  
value 4 is bntB pressed (1 or 0)  

You can use a micro:bit v2 with the following code
```
let buttonAValue = 0
let buttonBValue = 0
loops.everyInterval(20, function () {
    if (input.buttonIsPressed(Button.A)) {
        buttonAValue = 1
    } else {
        buttonAValue = 0
    }
    if (input.buttonIsPressed(Button.B)) {
        buttonBValue = 1
    } else {
        buttonBValue = 0
    }
    serial.writeNumbers([
    input.rotation(Rotation.Roll),
    input.rotation(Rotation.Pitch),
    buttonAValue,
    buttonBValue
    ])
})
```
Use the [makecode editor](https://makecode.microbit.org/#editor) in javascript mode to upload the code to micro:bit.  
The code above is not optimized but aimed at readability in makecode blocks

Find the name or index of the serialport and change line 111:  
`serialObj = new hxSerial.Serial(deviceList[deviceList.length - 1], 115200, true);`  
with the correct deviceList index or use a string with the name.  
The device list is traced to the terminal.  
*At the moment it chooses the last item in the devicelist.*
