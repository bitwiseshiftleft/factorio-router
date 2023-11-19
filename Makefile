VERSION=0.0.1
MODS_DIR="$(HOME)/Library/Application Support/factorio/mods"
FILES= info.json changelog.txt *.lua prototypes graphics lualib locale README.md resources

all: mod
mod: build/router_$(VERSION).zip

clean:
	rm -fr build

build/router_0.0.1.zip: $(FILES)
	rm -fr build
	mkdir -p build/router_$(VERSION)
	convert graphics/default.png -crop 32x32+192+0 resources/default.png
	convert graphics/connected.png -crop 32x32+192+0 resources/connected.png
	convert graphics/leaf.png -crop 32x32+192+0 resources/leaf.png
	cp -r $(FILES) build/router_$(VERSION)
	cd build && zip -r router_$(VERSION).zip router_$(VERSION)

install: mod
	cp build/router_$(VERSION).zip $(MODS_DIR)/