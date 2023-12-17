#!/bin/bash

#How much light change must be seen by the sensor befor it will act
LightChange=10

#How often it check the sensor
SensorDelay=1

# Scale sesor to displas brightness range
SensorToDisplayScale=1

#This should match your refesh rate other wise it will either change the back light more times than needed or too few for a smooth animation
LevelSteps=60
# The is should match the LevelSteps but in the acual time each event should take to see
AnimationDelay=0.016


# Read the variable names
MaxScreenBrightness=255

MinimumBrightness=000



# 2 : Default | 1 : Add Offset | 0 : Subtract Offset, Recomended not to change
op=2

while getopts i:d: flag
do
    case "${flag}" in
        i) op=1
           num=${OPTARG};;
        d) op=0 
           num=${OPTARG};;
    esac
done
if [[ -f /tmp/AB.offset ]]
then
  OffSet=$(cat /tmp/AB.offset)
else
  OffSet=0
  $(echo $OffSet > /tmp/AB.offset)
fi

OffSet=$((OffSet < 0 ? 0 : OffSet))


if [[ $op -lt 2 ]]
then
  if [[ $op -eq 1 ]]
  then
    OffSet=$((OffSet + num))
  else 
    OffSet=$((OffSet - num))
  fi

  OffSet=$((OffSet < 0 ? 0 : OffSet))

  $(echo $OffSet > /tmp/AB.offset)
  
  exit

fi

# This was moved down here to not affect performance of setting AB.offset
priority=19 # Priority level , 0 = regular app , 19 = very much background app

# Set the priority of the current script, Thank you  Theluga.
renice "$cpu_limit" "$$"



touch '/tmp/AB.running'

OldLight=$(cat /sys/bus/iio/devices/iio\:device0/in_illuminance_raw)

until [ -f /tmp/AB.kill ]
do
	if [[ -f /tmp/AB.stop ]]
	then
		rm '/tmp/AB.stop'
		rm '/tmp/AB.running'

		until [[ -f /tmp/AB.start ]]
		do
			sleep 10
		done
		rm '/tmp/AB.start'
		touch '/tmp/AB.running'
	else

    if [[ -f /tmp/AB.offset ]]
    then
      OffSet=$(cat /tmp/AB.offset)
    else
      OffSet=0
      $(echo $OffSet > /tmp/AB.offset)
    fi

		Light=$(cat /sys/bus/iio/devices/iio\:device0/in_illuminance_raw)
    Light=$((Light + OffSet))

    if [[ $Light -lt $LightChange ]] 
    then
      MaxOld=$((OldLight + LightChange))
      MinOld=$((OldLight - LightChange))
    else
      MaxOld=$((OldLight + OldLight/LightChange))
      MinOld=$((OldLight - OldLight/LightChange))
    fi

    if [[ $Light -gt $MaxOld ]] || [[ $Light -lt $MinOld ]]
    then


		  CurrentBrightness=$(cat /sys/class/backlight/amdgpu_bl1/brightness)


		  Light=$(( $Light + $MinimumBrightness ))


		  TempLight=$(($Light * $SensorToDisplayScale))

		  if [[ $TempLight -gt $MaxScreenBrightness ]]
		  then
			  NewLight=$MaxScreenBrightness
		  else
			  NewLight=$TempLight
		  fi

		  DiffCount=$(( ($NewLight - $CurrentBrightness)/$LevelSteps ))

		  for i in $(eval echo {1..$LevelSteps} )
		  do

			  NewLight=$(( $DiffCount ))

			  if [[ $NewLight -lt 0 ]]
			  then
			  NewLight=$( echo "$NewLight" | awk -F "-" {'print$2'})
			  NewLight=$(echo $NewLight-)
			  else
			  NewLight=$(echo +$NewLight)
			  fi

			  brightnessctl -q s $NewLight
			  sleep $AnimationDelay

		  done

      OldLight=$Light
    fi
   
		sleep $SensorDelay
  fi

done


rm '/tmp/AB.running'
rm '/tmp/AB.kill'



