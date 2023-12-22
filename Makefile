VERSION=0.0.1
MODS_DIR="$(HOME)/Library/Application Support/factorio/mods"
FILES= info.json changelog.txt *.lua prototypes graphics lualib locale README.md resources \
	resources/default.png resources/leaf.png resources/connected.png

all: mod
mod: build/router_$(VERSION).zip
run:
	open -a Factorio

clean:
	rm -fr build

resources/default.png: graphics/default.png
	convert $< -crop 32x32+192+0 $@

resources/leaf.png: graphics/leaf.png
	convert $< -crop 32x32+192+0 $@
	
resources/connected.png: graphics/connected.png
	convert $< -crop 32x32+192+0 $@

build/router_$(VERSION).zip: $(FILES)
	rm -fr build
	mkdir -p build/router_$(VERSION)
	cp -r $(FILES) build/router_$(VERSION)
	cd build && zip -r router_$(VERSION).zip router_$(VERSION)

install: mod
	cp build/router_$(VERSION).zip $(MODS_DIR)/