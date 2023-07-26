#!/usr/bin/env bash

docker run --device /dev/kvm --device /dev/dri:/dev/dri -v /tmp/.X11-unix:/tmp/.X11-unix -e DISPLAY -v $(pwd):/home/$USER/data slides /home/$USER/data/"$@"
