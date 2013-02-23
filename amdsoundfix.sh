#!/bin/bash

# amdsoundfix.sh : this script fix the sound lost issue when output
#                  device is turned off.

# HDMI device identity for xrandr (use "xrandr" command to identify it)
HDMI_SND_DEV="DFP1"

# HDMI device tag for PulseAudio (use "pactl list" command to identify it)
HDMI_SND_TAG="HDMI / DisplayPort"

# PulseAudio HDMI device status
HDMI_SND_STATE="not available"

# Display output identifier
DISPLAY=":0"

# Default configuration file
CONFIG="$HOME/.amdsoundfix.cfg"

# Load configuration file
if [[ -f "${CONFIG}" ]]; then
	. "${CONFIG}"
fi

# Usage function
function usage {
	cat << EOF
Usage: $(basename ${0}) [--scan] [--run] [--help]
  --scan	scan system and create configuration file
  --run		reload device based on configuration file
  --help	print this help
EOF
}

# This funtion reload device if necessary
function run {
	# Export display value
	export DISPLAY

	# Check if the HDMI sound device is down
	if pactl list | grep -e "${HDMI_SND_TAG}.*.${HDMI_SND_STATE}" > /dev/null; then
		xrandr --output ${HDMI_SND_DEV} --off
		xrandr --auto
		return $?;
	else
		echo "No HDMI problems detected. Exiting."
	fi
}

# This function search parameters values dynamically
function scan {
	# List of conneced devices
	local L_DEV_LIST=()

	# Temporary id
	local L_ID=0

    # Dynamically extract X11 Display port
    DISPLAY=$(who | grep -e '(:[0-9]' | sed -e 's/.*(//g' -e 's/)//g' | head -1)

	# Get xrandr HDMI device name of connected devices
	for _DEV in $(xrandr -d $DISPLAY | grep ' connected' | cut -d' ' -f1)
	do
		L_DEV_LIST=( ${L_DEV_LIST[@]} "${_DEV}" )
	done

	# Show list of connected devices and wait for the user's choice
	echo "List of connected devices detected on your computer:"

	L_ID=0

	# List found devices
	for _DEV in "${L_DEV_LIST}"
	do
		echo "$L_ID: $_DEV"
		L_ID=$(( L_ID + 1 ))
	done

	if [[ "${#L_DEV_LIST[@]}" == 0 ]]; then
		echo "No devices found. Exiting."
		exit 1;
	fi


	# Ask user for a choice (accept only usable numbers)
	while ! [ "${L_ID}" -eq "${L_ID}" 2>/dev/null ] \
		|| ! [[ "${L_ID}" -lt ${#L_DEV_LIST[@]} && "${L_ID}" -ge 0 ]]
	do
		echo "Select your HDMI device [0-"$(( ${#L_DEV_LIST[@]} - 1 ))"]: "
		read L_ID
	done

	# Write down value in configuration file
	cat << EOF >> ${CONFIG}
DISPLAY="${DISPLAY}"
HDMI_SND_DEV="${L_DEV_LIST[${L_ID}]}"
HDMI_SND_TAG="${HDMI_SND_TAG}"
HDMI_SND_STATE="${HDMI_SND_STATE}"
EOF
}

# This function create the file configuration
function init {
    # Check existing configuration file
	if [[ -f "${CONFIG}" ]]; then
		echo "WARNING: ${CONFIG} already exists. Do you want to replace it? (y/N)" && read _ANSW;

		# Aborted if Warning message not validated by user
		if ! [[ "${_ANSW}" == "Y" || "${_ANSW}" == "y" ]]; then
			echo "Scan aborted. Exiting."
			exit 1;
		fi
	fi

	# Create an empty configuration file
	touch ${CONFIG}

	# Insert headers
	cat << EOF > ${CONFIG}
#!/bin/bash
#
# amdsoundfix scripts packaging
# ---
# This configuration file is dedicated to amdsoundfix script
#

# HDMI device identity for xrandr (use "xrandr" command to identify it)
#HDMI_SND_DEV="DFP1"

# HDMI device tag for PulseAudio (use "pactl list" command to identify it)
#HDMI_SND_TAG="HDMI / DisplayPort"

# PulseAudio HDMI device status
#HDMI_SND_STATE="not available"

# Display output identifier
#DISPLAY=":0"

### Values behind this line was generated automatically

EOF

    # Get authority on X server running instance
    export XAUTHORITY=${HOME}/.Xauthority

	# Run the dynamic scan
	scan;
}


# Get parameters
if [[ $# != 1 ]]
then
        usage
else
        case "${1}" in
                '--scan')
                        init ;;
                '--run')
                        run ;;
                *) 
                        usage ;;
        esac
fi

exit $?
