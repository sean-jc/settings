#!/bin/bash
echo 55aa > /sys/bus/pci/devices/0000:00:02.0/rom

for i in {1..2}; do
   cat /sys/bus/pci/devices/0000:00:02.0/rom &> /dev/null
   sleep 1
done
