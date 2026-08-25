# greetd + tuigreet

The primary login path: a black-screen TUI greeter with the
`IDENTIFY YOURSELF, PROGRAM` greeting and accent-colored borders.

`install.sh` does all of this when you pick `greetd` at the login prompt
(or pass `--login greetd`); the steps below are the manual equivalent.

## Install

```bash
sudo apt install greetd                      # noble has greetd in universe
# tuigreet is NOT in noble's archive — install.sh pulls the static binary:
#   https://github.com/apognu/tuigreet/releases  -> /usr/local/bin/tuigreet
```

## Enable (and cleanly disable SDDM)

```bash
sudo cp login/greetd/config.toml /etc/greetd/config.toml
sudo systemctl disable sddm                  # do NOT --now from inside X
sudo systemctl enable greetd
echo /usr/sbin/greetd | sudo tee /etc/X11/default-display-manager
sudo reboot
```

At the greeter: `F2` picks the session (**bspwm** or **Openbox**),
`F3` toggles the command line. `--remember` restores your last choice.

## Roll back to SDDM

```bash
sudo systemctl disable greetd
sudo systemctl enable sddm
echo /usr/bin/sddm | sudo tee /etc/X11/default-display-manager
sudo reboot
```

## Theming note

tuigreet's `--theme` only understands ANSI color *names*, not hex — so
cyan mode uses `cyan` and orange mode approximates with `red`. The exact
palette hexes apply everywhere past the login screen.
