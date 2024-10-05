#!/usr/bin/env bash

set -euo pipefail

echo "Updating clock and weather every ${1} minutes"

temp_image=$(mktemp /tmp/eink-weather.bmp.XXXXXXXX)

trap 'rm -rf "${temp_image}"' EXIT

pirateweather_api_url="https://api.pirateweather.net/forecast"
pirateweather_api_key="${EINK_WEATHER_PIRATEWEATHER_KEY}"
pirateweather_location="${EINK_WEATHER_PIRATEWEATHER_LOCATION}"
pirateweather_optional_params="?units=si"
pirateweather_request_url="${pirateweather_api_url}/${pirateweather_api_key}/${pirateweather_location}${pirateweather_optional_params}"

background_color="white"
foreground_color="black"

while true; do
	minutes=$(date +"%-M")
	if ((minutes % ${1} != 0)); then
		sleep 30
		continue
	fi

	# Get the time.
	time=$(date +"%H:%M")

	# Get the pirateweather weather.
	pirateweather_json=$(curl "${pirateweather_request_url}")

	pirateweather_current_temperature=$(echo ${pirateweather_json} | jq '.currently.temperature')
	pirateweather_current_temperature=$(printf %.0f ${pirateweather_current_temperature})
	pirateweather_current_summary=$(echo ${pirateweather_json} | jq -r '.currently.summary')
	pirateweather_hourly_summary=$(echo ${pirateweather_json} | jq -r '.hourly.summary')
	pirateweather_daily_summary=$(echo ${pirateweather_json} | jq -r '.daily.summary')

	sunrise_today=$(date --date=@$(echo ${pirateweather_json} | jq -r '.daily.data[0].sunriseTime') +'%H:%M')
	sunset_today=$(date --date=@$(echo ${pirateweather_json} | jq -r '.daily.data[0].sunsetTime') +'%H:%M')

	# Construct the image to be shown.
	# Background.
	convert \
		-size 600x448 \
		xc:${background_color} \
		bmp:${temp_image}

	# Date, sunrise, and sunset.
	convert \
		${temp_image} \
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
		-background none \
		-gravity north \
		-fill ${foreground_color} \
		-font "Iosevka-Bold" \
		-size 600x280 \
		label:"${time}" \
		-geometry +0+20 \
		-compose over -composite \
		bmp:${temp_image}

	# Darksky weather. Temperature and current weather.
	convert \
		${temp_image} \
		-background none \
		-gravity north \
		-fill ${foreground_color} \
		-font "Iosevka-Bold" \
		-size 600x60 \
		label:"${pirateweather_current_temperature}° ${pirateweather_hourly_summary}" \
		-geometry +0+280 \
		-compose over -composite \
		bmp:${temp_image}

	# Weekly weather
	weekdays=$(echo ${pirateweather_json} | jq '.daily.data[].time' | head -n 7 |  xargs -I '{}' date --date=@'{}' +'   %a' | tr -d '\n' | sed 's|^   ||')
	convert \
		${temp_image} \
		-background none \
		-gravity north \
		-fill ${foreground_color} \
		-font "Iosevka-Bold" \
		-size 600x36 \
		label:"\\${weekdays}" \
		-geometry +0+340 \
		-compose over -composite \
        bmp:${temp_image}

	weekday_temperatures_high=$(echo ${pirateweather_json} | jq '.daily.data[].temperatureHigh' | head -n 7 |  xargs -I '{}' printf '%6.0f' '{}' | tr -d '\n' | sed 's|^   ||')
	convert \
		${temp_image} \
		-background none \
		-gravity north \
		-fill ${foreground_color} \
		-font "Iosevka-Bold" \
		-size 600x36 \
		label:"\\${weekday_temperatures_high}" \
		-geometry +0+370 \
		-compose over -composite \
        bmp:${temp_image}
	weekday_temperatures_low=$(echo ${pirateweather_json} | jq '.daily.data[].temperatureLow' | head -n 7 |  xargs -I '{}' printf '%6.0f' '{}' | tr -d '\n' | sed 's|^   ||')
	convert \
		${temp_image} \
		-background none \
		-gravity north \
		-fill ${foreground_color} \
		-font "Iosevka-Bold" \
		-size 600x36 \
		label:"\\${weekday_temperatures_low}" \
		-geometry +0+400 \
		-compose over -composite \
        bmp:${temp_image}

	for i in {0..6}; do
		precip_intensity=$(echo ${pirateweather_json} | jq ".daily.data[${i}].precipIntensity")
		bar_top=$(echo "scale=5; 448 - ($precip_intensity * 100)" | bc)
		bar_left=$((90 + i * 78))
		bar_bottom=448
		bar_right=$((bar_left + 10))
		convert \
			"${temp_image}" \
			-size 600x448 \
			xc:transparent \
			-fill ${foreground_color} \
			-stroke ${background_color} \
			-draw "rectangle ${bar_left},${bar_top}, ${bar_right},${bar_bottom}" \
		    -compose over -composite \
			bmp:${temp_image}
	done

	# Invert if night.
	sunrise_seconds=$(date --date=@$(echo ${pirateweather_json} | jq -r '.daily.data[0].sunriseTime') +'%s')
	sunset_seconds=$(date --date=@$(echo ${pirateweather_json} | jq -r '.daily.data[0].sunsetTime') +'%s')
	now_seconds=$(date +'%s')
	if ((now_seconds <= sunrise_seconds || sunset_seconds <= now_seconds)); then
		convert \
			${temp_image} \
			-negate \
			bmp:${temp_image}
	fi

	image_color="black"
	if ((pirateweather_current_temperature >= 20)); then
		image_color="red"
	fi

	echo "Displaying \"${temp_image}\" at ${time}"
	/home/pi/src/eink-weather/python/main.py \
		"${temp_image}" \
		"${image_color}"

	sleep 30
done
