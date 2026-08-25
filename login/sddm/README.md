# SDDM variant (optional)

If you'd rather keep Lubuntu's stock SDDM than switch to greetd, the
installer can skin it with [Sugar Candy](https://framagit.org/MarianArlt/sddm-sugar-candy)
plus our grid wallpaper and accent.

Pick `sddm` at the installer's login prompt (or `--login sddm`). Manual steps:

```bash
sudo apt install qml-module-qtquick-controls2 qml-module-qtgraphicaleffects
sudo git clone --depth 1 https://framagit.org/MarianArlt/sddm-sugar-candy.git \
    /usr/share/sddm/themes/sugar-candy
sudo cp theme/wallpapers/tron-grid.png \
    /usr/share/sddm/themes/sugar-candy/Backgrounds/tron-grid.png
sudo cp login/sddm/theme.conf.user \
    /usr/share/sddm/themes/sugar-candy/theme.conf.user
printf '[Theme]\nCurrent=sugar-candy\n' | sudo tee /etc/sddm.conf.d/10-tron-theme.conf
```

Sugar Candy is QML-heavy; it takes a couple of seconds to paint on the
N4000 but costs nothing once you're logged in. sddm-astronaut needs Qt6 /
newer QML modules than noble ships cleanly, so Sugar Candy is the variant
wired into the installer.
