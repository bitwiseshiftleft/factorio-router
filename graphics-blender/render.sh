#!/bin/sh

cd graphics-blender
/Applications/Blender.app/Contents/MacOS/Blender --background --python render.py || exit 1
# rm router_black.png
# rm router_white.png
