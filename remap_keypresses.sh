#!/bin/bash

# Use xdotool to get the parent process of the active window
W=`xdotool getactivewindow`
S0=`xprop -id ${W} |awk '/WM_CLASS/{print $4}'`

# Check if active window parent has "chrome" in name
echo "$S0" | grep -ic 'chrome'
if [ $? -eq 0 ];then
  S1=1
else
  S1=0
fi

case "$1" in
  "j")
    #if C-j was passed as an argument AND 
    #the focused window is chrome browser, press C-b
    #otherwise do nothing
    if [ "$S1" = 1 ]; then
      xdotool getwindowfocus key --window %@ ctrl+b
    else
      xdotool getwindowfocus key --window %@ ctrl+j
    fi
    ;;
  "k")_
    #if C-k was passed as an argument AND 
    #the focused window is chrome browser, press C-m
    #otherwise do nothing
    if [ "$S1" = 1 ]; then
      xdotool getwindowfocus key --window %@ ctrl+m
    else
      #xdotool getwindowfocus type --window %@ ctrl+k
      xdotool getwindowfocus key --window %@ ctrl+k
    fi
    ;;
  *)
    #if some other argument, write to keypress.error.log
    Time=$(date +%T%s%n)
    echo "$Time: Argument $1 not recognized by remap_keypresses.sh" >> remap_keypresses.error.log.txt
    ;;
esac
