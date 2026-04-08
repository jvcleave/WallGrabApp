macos port using https://github.com/kenshaw/wallgrab as a reference

<img width="1367" height="1031" alt="image" src="https://github.com/user-attachments/assets/e0a06534-8505-485a-aaa8-ba43de3112d2" />

## Running

Open [WallGrabApp.xcodeproj](./WallGrabApp.xcodeproj) in Xcode and run the `WallGrabApp` scheme.

You can also build from Terminal:

```bash
xcodebuild -project WallGrabApp.xcodeproj -scheme WallGrabApp -configuration Debug -sdk macosx build
```

## Using The App

1. Launch the app and wait for the catalog to load.
2. Use `Refresh` if you want to fetch the latest Apple aerial catalog again.
3. Choose an output folder from the toolbar, the sidebar card, or the detail panel.
4. Select one video, or `Command`-click to select multiple videos.
5. Click `Download Video` or `Download N Videos`.
6. Click `Play Video` to preview the selected item in the built-in player.

## Notes

- `Ready` means the item is available to download. It does not mean it has already been saved.
- `Saved` means that video was downloaded to the selected output folder during the current session.
- The sidebar `Catalog: Ready` status only means the metadata loaded successfully.

Thanks kenshaw!
