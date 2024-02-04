VERSION=0.0.3
MODS_DIR="$(HOME)/Library/Application Support/factorio/mods"
FILES= info.json changelog.txt *.lua prototypes graphics lualib locale README.md resources \
	resources/default.png resources/leaf.png resources/connected.png resources/threshold.png
BLENDER= graphics/router-entity.png

all: mod
mod: build/router_$(VERSION).zip
run:
	open -a Factorio

clean:
	rm -fr build

graphics/router-entity.png graphics/light.png graphics/router-icon.png graphics/router-icon-mask.png graphics/io-entity.png:\
		graphics-blender/router.blend graphics-blender/*.py graphics-blender/*.sh
	mkdir -p graphics-blender/output
	sh graphics-blender/render.sh
	mv graphics-blender/output/router.png graphics/router-entity.png
	mv graphics-blender/output/io.png graphics/io-entity.png
	mv graphics-blender/output/light.png graphics/
	# Extract the icon version, which has the lights present
	convert -crop 256x256+48+0 graphics-blender/output/router_icon_white.png -resize 128x128 graphics/router-icon.png
	convert -crop 256x256+48+0 graphics-blender/output/router_icon_mask.png -resize 128x128 graphics/router-icon-mask.png
	convert -crop 192x192+80+40 graphics-blender/output/io_North_icon_white.png -resize 128x128 graphics/io-icon.png
	convert -crop 192x192+80+40 graphics-blender/output/io_icon_mask.png -resize 128x128 graphics/io-icon-mask.png


resources/default.png: graphics/default.png
	convert $< -crop 32x32+192+0 $@

resources/leaf.png: graphics/leaf.png
	convert $< -crop 32x32+192+0 $@
	
resources/connected.png: graphics/connected.png
	convert $< -crop 32x32+192+0 $@
	
resources/threshold.png: graphics/threshold.png
	convert $< -crop 32x32+192+0 $@

build/router_$(VERSION).zip: $(FILES) $(BLENDER)
	rm -fr build
	mkdir -p build/router_$(VERSION)
	cp -r $(FILES) build/router_$(VERSION)
	cd build && zip -r router_$(VERSION).zip router_$(VERSION)

install: mod
	cp build/router_$(VERSION).zip $(MODS_DIR)/