# Aseprite Prefabs
A simple extension for [Aseprite](https://www.aseprite.org/) which allows you to use other projects/images as prefabs (nested copies)

![Aseprite_iKrf4DVQXv](https://github.com/user-attachments/assets/461fc2fa-e4f9-4bd6-802a-d68452de6aaf)

## Features
1. Nesting images or whole projects (even with multiple layers) inside other projects
2. Prefab instances automatically update when we make a change in the prefab itself
   1. You can place the prefab and the sprite containing prefab instances side by side to see the changes in realtime
3. Any number of different prefabs (images/projects) can be added to a single project
4. Any number of prefab instances can be used (each instance needs a separate layer)
5. Supports displaying a selected frame in the prefab instance
6. Undo/redo support
7. Upon opening the `Prefab Window`, all images/projects used as prefabs are opened aswell
8. Prefab layers will change their color depending on the state of the prefab
   1.  Active (bright green) - the prefab instance is actively being updated
   2.  Empty (dark green) - no prefab is currently selected for this layer (the selected option is \[empty])
   3.  Missing (red) - file associated with the prefab is not opened. All prefab files
9. Select multiple frames in the prefab layer to change all of them at the same time
   1. In case of multi-frame editing, the slider will be replaced with a text field, allowing for fine-tuned operations (see [Multi-Frame Editing](#multi-frame-editing) section for more info)

## How to install
1. Download the [Prefabs.aseprite-extension](https://github.com/Xemar5/aseprite-prefabs/releases/latest) file from the latest release
2. Double-click the downloaded file to install the extension

## How to use
1. Launch the Aseprite and open a new/existing project; this will be our main project
2. Open any number of additional projects/images which will be used as prefabs
3. Go to `View > Prefabs > Prefab Window` to start the extension
4. Create a new prefab layer via `Layer > New... > New Prefab Layer` and select it
5. In the `Prefab` dropdown, select any project/image opened in step 2.
6. Using the `Frame` slider, select the prefab frame you want to display

## Multi-Frame Editing
1. Select any number of frames in a prefab layer
   - Frames don't need to be continuous (you can add a frame to selection by holding Shift)
2. Using the provided text field, type in a name of a tag from the prefab sprite in quotation marks or an equation that will be applied to all selected frames
   - To use frames from a tag, type in the tag name in quotation marks, like so `"My Tag"`
      - If more frames are selected in the root sprite than the tag frame length, the frames will cycle, e.g. [2, 3, 4, 2, 3, 4, 2, 3]
      - If fewer frames are selected in the root sprite then the tag frame length, the frames will be truncated, e.g. [2. 3]
   - Any Lua code is supported here (even functions, like `math.sin(3)`), so be careful not to paste malicious code
   - There are 3 special keywords
      - `i` - the index in the selection, starting from 1 (e.g. 1, 2, 3, 4, 5, ...)
      - `f` - the selected frame number (i.e. if you start the selection from frame 5 to 8, it will be 5, 6, 7, 8)
      - `c` - the count of the selection (the number of selected frames)
3. Press the button below the text field to apply the change to selected frames
   - A live result is displayed on the button after each change in the text field
   - If there is an error with the text input, the button will be disabled

Examples:
- `4` - set all frames to 4
- `2 + 2 * 2` - set all frames to 6 (order of operations matter; you can use parenthesis `( )`)
- `i` - set frames to [1, 2, 3, 4, ...]
- `i + 2` - set frames to [3, 4, 5, 6, ...]
- `c + 1 - i` - set frames to [..., 4, 3, 2, 1] (reverse order)
- `(i - 1) % 3 + 2` - set frames to loop back after 3rd frame (second to last number), starting from 2 (last number) - [2, 3, 4, 2, 3, 4, 2, 3, ...]
- `math.sin(i)` - calculate sinus from the current frame and round it to nearest whole number
- `"Idle"` - set frames to match frames used in tag "Idle" in the prefab

## Limitations
1. You can't edit the prefab inside the main project, you need to update the prefab sprites directly
2. Opening another file with a plugin requires user permission. It is suggested to set the toggle to trust the plugin for better user experience
3. All changes made in a prefab layer will be overwritten when you update the corresponding prefab (some other actions will also trigger the prefab instance to be refreshed, overwritting all changes)
4. Layers of prefab instances are always merged down in the main project
5. ~~You can place each prefab tab next to the main project to see both at the same time, but prefab instances do not automatically change whenever you make a change in the original prefab, you need to swich back to the main project tab for changes to take effect. This is because updating all instances on every change would slow down the editor~~ Prefab instances correctly update as soon as the prefab is changed starting from version 0.2
