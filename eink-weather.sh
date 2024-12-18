#!/usr/bin/env bash

set -euo pipefail

temp_image=$(mktemp /tmp/eink-weather.bmp.XXXXXXXX)

trap 'rm -rf "${temp_image}"' EXIT

openmeteo_api_url="https://api.open-meteo.com/v1/forecast"
openmeteo_latitude="$(echo ${EINK_WEATHER_OPENMETEO_LOCATION} | cut -f1 -d,)"
openmeteo_longitude="$(echo ${EINK_WEATHER_OPENMETEO_LOCATION} | cut -f2 -d,)"
openmeteo_timezone="${EINK_WEATHER_OPENMETEO_TIMEZONE}"
openmeteo_request_url="${openmeteo_api_url}?latitude=${openmeteo_latitude}&longitude=${openmeteo_longitude}&timezone=${openmeteo_timezone}&current=apparent_temperature,weather_code&hourly=weather_code,precipitation&daily=apparent_temperature_max,apparent_temperature_min,sunrise,sunset"

declare -A wmo_codes
wmo_codes["0"]="Clear"
wmo_codes["1"]="Mostly clear"
wmo_codes["2"]="Partly cloudy"
wmo_codes["3"]="Overcast"
wmo_codes["45"]="Fog"
wmo_codes["48"]="Rime fog"
wmo_codes["51"]="Light drizzle"
wmo_codes["53"]="Drizzle"
wmo_codes["55"]="Heavy drizzle"
wmo_codes["56"]="Light freezing drizzle"
wmo_codes["57"]="Freezing drizzle"
wmo_codes["61"]="Light rain"
wmo_codes["63"]="Rain"
wmo_codes["65"]="Heavy rain"
wmo_codes["66"]="Light freezing rain"
wmo_codes["67"]="Freezing rain"
wmo_codes["71"]="Light snow"
wmo_codes["73"]="Snow"
wmo_codes["75"]="Heavy snow"
wmo_codes["77"]="Snow grains"
wmo_codes["80"]="Light showers"
wmo_codes["81"]="Showers"
wmo_codes["82"]="Heavy showers"
wmo_codes["85"]="Light snow showers"
wmo_codes["86"]="Snow showers"
wmo_codes["95"]="Thunderstorms"
wmo_codes["96"]="Light thunderstorms with hail"
wmo_codes["99"]="Thunderstorms with hail"

background_color="white"
foreground_color="black"

function no_negative_zero {
	if [[ "${1}" == "-0" ]]; then
		echo "0"
	else
		echo "${1}"
	fi
}

# Get the time.
time=$(date +"%H:%M")

# Get the openmeteo weather.
openmeteo_json=$(curl "${openmeteo_request_url}")

openmeteo_current_temperature=$(echo ${openmeteo_json} | jq '.current.apparent_temperature')
openmeteo_current_temperature=$(printf %.0f ${openmeteo_current_temperature})
openmeteo_current_summary=${wmo_codes[$(echo ${openmeteo_json} | jq -r '.current.weather_code')]}

sunrise_today=$(date --date=$(echo ${openmeteo_json} | jq -r '.daily.sunrise[0]') +'%H:%M')
sunset_today=$(date --date=$(echo ${openmeteo_json} | jq -r '.daily.sunset[0]') +'%H:%M')

# Construct the image to be shown.
# Background.
convert \
	-size 600x448 \
	xc:${background_color} \
	bmp:${temp_image}

# Precipitation. Draw first to allow text to be drawn on top of the bars with
# outlines.
n_hours=$((24 * 7))
rectangles=""
precipitation=( $(echo ${openmeteo_json} | jq '.hourly.precipitation[]') )
for i in $(seq 0 $((n_hours - 1))); do
	precip_intensity=${precipitation[$i]}
	bar_top=$(echo "scale=5; 448 - ($precip_intensity * 20)" | bc)
	bar_left=$(echo "scale=5; $i * (600 / $n_hours)" | bc)
	bar_bottom=448
	bar_right=$(echo "scale=5; $bar_left + (600 / $n_hours)" | bc)
	rectangles+=" rectangle ${bar_left},${bar_top}, ${bar_right},${bar_bottom}"
done
convert \
	"${temp_image}" \
	+antialias \
	-size 600x448 \
	xc:transparent \
	-fill ${foreground_color} \
	-draw "${rectangles}" \
	-compose over -composite \
	bmp:${temp_image}

# Date, sunrise, and sunset.
convert \
	${temp_image} \
	+antialias \
	-background none \
	-gravity north \
	-fill ${foreground_color} \
	-font "Iosevka-Bold" \
	-size 600x40 \
	label:"↑${sunrise_today}     $(date +'%A %-d %B %Y')     ${sunset_today}↓" \
	-geometry +0+20 \
	-compose over -composite \
	bmp:${temp_image}

# Time.
convert \
	${temp_image} \
	+antialias \
	-background none \
	-gravity north \
	-fill ${foreground_color} \
	-font "Iosevka-Bold" \
	-size 600x280 \
	label:"${time}" \
	-geometry +0+20 \
	-compose over -composite \
	bmp:${temp_image}

# Current temperature and weather.
convert \
	${temp_image} \
	+antialias \
	-background none \
	-gravity north \
	-fill ${foreground_color} \
	-font "Iosevka-Bold" \
	-size 600x60 \
	label:"$(no_negative_zero ${openmeteo_current_temperature})° ${openmeteo_current_summary}" \
	-geometry +0+280 \
	-compose over -composite \
	bmp:${temp_image}

# Weekly weather.
n_days=7
weekdays=$(echo ${openmeteo_json} | jq ".daily.time[:${n_days}]")
weekday_temperatures_high=$(echo ${openmeteo_json} | jq ".daily.apparent_temperature_max[:${n_days}]")
weekday_temperatures_low=$(echo ${openmeteo_json} | jq ".daily.apparent_temperature_min[:${n_days}]")
for i in $(seq 0 $((n_days - 1))); do
	set -x
	box_top=340
	box_left=$(echo "scale=5; $i * (600 / $n_days) - 300 + (600 / $n_days) / 2" | bc)
	box_size_y=80
	box_size_x=$(echo "scale=5; (600 / $n_days)" | bc)
	day=$(echo ${weekdays} | jq ".[${i}]" |  xargs -I '{}' date --date='{}' +'%a')
	temperature_high=$(no_negative_zero $(echo ${weekday_temperatures_high} | jq ".[${i}]" | xargs -I '{}' printf '%.0f' '{}'))
	temperature_low=$(no_negative_zero $(echo ${weekday_temperatures_low} | jq ".[${i}]" | xargs -I '{}' printf '%.0f' '{}'))
	convert \
		${temp_image} \
		+antialias \
		-background none \
		-gravity north \
		-fill ${foreground_color} \
		-pointsize 26 \
		-font "Iosevka-Bold" \
		-size ${box_size_x}x${box_size_y} \
		label:"\\${day}\n${temperature_high}/${temperature_low}" \
		-geometry +${box_left}+${box_top} \
		-compose over -composite \
		bmp:${temp_image}
	set +x
	if (( i < n_days )); then
		line_y=$(echo "scale=5; ($i + 1) * (600 / $n_days)" | bc)
		convert \
			"${temp_image}" \
			+antialias \
			-size 600x448 \
			xc:transparent \
			-stroke ${foreground_color} \
			-fill none \
			-draw "stroke-dasharray 1,8,1,8,1,8,1,8 line ${line_y},447 ${line_y},410" \
			-compose over -composite \
			bmp:${temp_image}
	fi
done

# Invert if night.
sunrise_seconds=$(date --date=$(echo ${openmeteo_json} | jq -r '.daily.sunrise[0]') +'%s')
sunset_seconds=$(date --date=$(echo ${openmeteo_json} | jq -r '.daily.sunset[0]') +'%s')
now_seconds=$(date +'%s')
if ((now_seconds <= sunrise_seconds || sunset_seconds <= now_seconds)); then
	convert \
		${temp_image} \
		-negate \
		bmp:${temp_image}
fi

image_color="black"
if ((openmeteo_current_temperature >= 20)); then
	image_color="red"
fi

echo "Displaying \"${temp_image}\" at ${time}"
/home/pi/src/eink-weather/python/main.py \
	"${temp_image}" \
	"${image_color}"
