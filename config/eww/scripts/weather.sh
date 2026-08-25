#!/usr/bin/env bash
# Weather for the HUD card. No API key: wttr.in first, Open-Meteo as fallback
# (geolocated via ipinfo.io). Cached 15 min so a HUD toggle never blocks.
# Output: one JSON line {"temp","desc","icon"}.

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/tron"
CACHE="$CACHE_DIR/weather.json"
mkdir -p "$CACHE_DIR"

fresh() { [ -f "$CACHE" ] && [ "$(( $(date +%s) - $(stat -c %Y "$CACHE") ))" -lt 900 ]; }
if fresh; then cat "$CACHE"; exit 0; fi

icon_for() { # WMO-ish / keyword -> nerd font icon
    case "$(echo "$1" | tr '[:upper:]' '[:lower:]')" in
        *thunder*) echo "󰖓";;
        *snow*|*sleet*|*blizzard*) echo "󰖘";;
        *rain*|*drizzle*|*shower*) echo "󰖗";;
        *fog*|*mist*|*haze*) echo "󰖑";;
        *cloud*|*overcast*) echo "󰖐";;
        *clear*|*sunny*) echo "󰖙";;
        *) echo "󰖕";;
    esac
}

emit() { printf '{"temp":"%s","desc":"%s","icon":"%s"}\n' "$1" "$2" "$3" | tee "$CACHE"; }

# --- primary: wttr.in --------------------------------------------------------
j="$(curl -sf -m 10 'https://wttr.in/?format=j1' 2>/dev/null)"
if [ -n "$j" ]; then
    temp="$(echo "$j" | jq -r '.current_condition[0].temp_C' 2>/dev/null)"
    desc="$(echo "$j" | jq -r '.current_condition[0].weatherDesc[0].value' 2>/dev/null)"
    if [ -n "$temp" ] && [ "$temp" != "null" ]; then
        emit "${temp}°C" "$(echo "$desc" | tr '[:lower:]' '[:upper:]' | cut -c1-20)" "$(icon_for "$desc")"
        exit 0
    fi
fi

# --- fallback: open-meteo via IP geolocation ---------------------------------
loc="$(curl -sf -m 5 'https://ipinfo.io/loc' 2>/dev/null)"   # "lat,lon"
if [ -n "$loc" ]; then
    lat="${loc%,*}" lon="${loc#*,}"
    j="$(curl -sf -m 10 "https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,weather_code" 2>/dev/null)"
    temp="$(echo "$j" | jq -r '.current.temperature_2m' 2>/dev/null)"
    code="$(echo "$j" | jq -r '.current.weather_code' 2>/dev/null)"
    if [ -n "$temp" ] && [ "$temp" != "null" ]; then
        case "$code" in
            0) desc="CLEAR";; 1|2) desc="PARTLY CLOUDY";; 3) desc="OVERCAST";;
            45|48) desc="FOG";; 5*|6*|8[0-2]) desc="RAIN";; 7*|85|86) desc="SNOW";;
            95|96|99) desc="THUNDERSTORM";; *) desc="UNKNOWN";;
        esac
        emit "${temp}°C" "$desc" "$(icon_for "$desc")"
        exit 0
    fi
fi

printf '{"temp":"--","desc":"NO UPLINK","icon":"󰖪"}\n'
