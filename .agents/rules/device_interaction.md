---
trigger: always_on
---

# Device Interaction Guidelines

- **Manual User Testing & Touch Input:** Do not write or run automated scripts (e.g. `adb shell input tap`) to touch screen buttons or navigate the device.
- **Request User Action:** Whenever a button click, dialog interaction, form fill, or screenshot of a specific screen state is needed, ask the user to perform it on the phone.
