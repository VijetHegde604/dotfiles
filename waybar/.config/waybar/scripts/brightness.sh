#!/bin/bash

current=$(brightnessctl -d intel_backlight g)
max=$(brightnessctl -d intel_backlight m)
percent=$((current * 100 / max))

echo "{\"text\": \"󰃠 ${percent}%\", \"percent\": ${percent}}"
