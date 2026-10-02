# PowerInfo Reborn

# The original MacOS app has been reborn!

PowerInfo Reborn is a small macOS menu bar app. It shows a popup whenever your Mac's power state changes, for example when you plug in the charger, unplug it, or turn Low Power Mode on or off.

It sits in the menu bar as "PIR". Clicking it opens a panel with detailed information about the connected charger. Right-click it for Settings, About and Quit.

## Features

Popups for these events, each of which can be turned on or off:

- Charger plugged in
- Charger unplugged
- Low Power Mode turned on
- Low Power Mode turned off
- Battery fully charged
- Battery low (you choose the level)
- Slow charger connected (you choose the wattage)

Charger details, shown when you click PIR in the menu bar:

- Charger: name, manufacturer, model, connection type, rated wattage, the negotiated voltage and current, the active USB Power Delivery profile, every power profile the charger offers, serial number, hardware and firmware versions, and more
- Power: live input power, voltage and current, how hard the charger is working, power going into or out of the battery, system load and adapter losses, and why charging is slow or paused
- Battery: charge in mAh, capacity compared to new, cycle count, voltage, current and temperature
- A Copy button that copies everything as text

What's shown depends on the Mac and charger; anything macOS doesn't report is left out.

Three popup styles:

- Classic: a rounded square at the bottom centre of the screen with an icon, the event name and the battery level.
- Island: a pill that slides down from the top of the screen.
- Detail Card: a card in the top right corner with the power source, charging status and Low Power Mode state.

Each style can use a glass, light or dark look.

Other settings:

- Popup size
- Colour or monochrome icons
- Reduce motion
- How long popups stay on screen
- Which display popups appear on
- Sound, and which system sound to play
- Launch at login
- Battery percentage next to PIR in the menu bar

## Requirements

- macOS 14 or later. The glass look uses the system glass effect on macOS 26 and later, and a blurred background on older versions.
  
## License

Copyright (c) 2026 Ka1bOne

This project is licensed under the Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International License. See the LICENSE file for the full text.

In short:

- You can download, build and use it for yourself.
- You can change it for your own personal use.
- You must keep the credit to Ka1bOne.
- You may not sell it or use it for any commercial purpose.
- You may not share or publish modified versions.

## Disclaimer

PowerInfo Reborn is an independent project and is not affiliated with or endorsed by Apple Inc. Mac and macOS are trademarks of Apple Inc.
