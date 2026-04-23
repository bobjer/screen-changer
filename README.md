# ScreenChanger

A minimal macOS menu bar app that swaps the mirror master between the built-in MacBook display and one external display.

Left-click the `🖥` menu bar icon to switch display roles. Right-click it for:

- `Toggle Launch at Login`
- `Quit ScreenChanger`

If no external display is connected, the icon is dimmed. It becomes active automatically when an external display is connected.

## Build

```sh
make
```

The app bundle is written to:

```text
build/ScreenChanger.app
```

Run it:

```sh
make run
```

For regular use, move `build/ScreenChanger.app` to `/Applications`, launch it, then enable launch at login from the right-click menu.

## Homebrew Cask

This repository includes a cask template at `Casks/screen-changer.rb`.

Build a release zip and checksum:

```sh
make dist
```

Publish `build/ScreenChanger-0.1.0.zip` as a GitHub release asset, then make sure the `sha256` in `Casks/screen-changer.rb` matches the checksum printed by `make dist`.

In a tap repository such as `bobjer/homebrew-retype`, place the cask at:

```text
Casks/screen-changer.rb
```

Users can install it with:

```sh
brew tap bobjer/retype
brew install --cask screen-changer
```

Or without a separate tap command:

```sh
brew install --cask bobjer/retype/screen-changer
```
