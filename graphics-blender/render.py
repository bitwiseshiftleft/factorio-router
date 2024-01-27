import bpy
from itertools import chain

# TODO: organize this better.  Less copy-paste

brightenPaintFactor = 1.3
brightenLightFactor = 0.4

(width,height) = 416,320
(lamp_width,lamp_height) = 32,32
(lamp_offx,lamp_offy) = 214,232
shadow_factor = 4

bpy.ops.wm.open_mainfile(filepath="router.blend")

mat = bpy.data.materials["Painted metal"]
clip = bpy.data.materials.get("Clip")
lamp = bpy.data.materials.get("IndicatorLight")
o = bpy.context.scene.objects.get("ShadowPlane")
o.hide_viewport = o.hide_render = True


# Render with xy plane to catch shadow and glow
lights = bpy.data.collections["Entrance lights"]
lights.hide_viewport = lights.hide_render = True

bulbs = bpy.data.collections["Bulbs"]
for bulb in bulbs.objects:
    if bulb.data.materials:
        bulb.data.materials[0] = clip
    else:
        bulb.data.materials.append(clip)


# Render with black paint
paintColor = mat.node_tree.nodes["RGB.001"].outputs[0]
paintColor.default_value = (0, 0, 0, 1)
bpy.context.scene.render.resolution_x = width
bpy.context.scene.render.resolution_y = height
bpy.context.scene.render.filepath = 'router_black.png'
bpy.ops.render.render(write_still=True)

# Render with white paint
paintColor.default_value = (1, 1, 1, 1)
bpy.context.scene.render.filepath = 'router_white.png'
bpy.ops.render.render(write_still=True)

# with lights on instead of clip.  First make the lamps still clip, but a little bigger...
bulbs_big = bpy.data.collections["BulbsBig"]
bulbs_big.hide_viewport = bulbs_big.hide_render = False
for bulb in bulbs_big.objects:
    bulb.data.materials[0] = clip
bpy.context.scene.render.filepath = 'router_with_clips.png'
bpy.ops.render.render(write_still=True)

for bulb in bulbs_big.objects:
    bulb.data.materials[0] = lamp
bpy.context.scene.render.filepath = 'router_with_lamps.png'
bpy.ops.render.render(write_still=True)

# Render with xy plane to catch shadow and glow
o = bpy.context.scene.objects.get("ShadowPlane")
o.hide_viewport = o.hide_render = False
bpy.context.scene.render.filepath = 'router_shadow.png'
bpy.ops.render.render(write_still=True)

lights.hide_viewport = lights.hide_render = False
bpy.context.scene.render.filepath = 'router_shadow_glow.png'
bpy.ops.render.render(write_still=True)

# Remove the shadow plane, tie points and fine details
o.hide_viewport = o.hide_render = True
lights.hide_viewport = lights.hide_render = True
lights = bpy.data.collections["TiePoints"]
lights.hide_viewport = lights.hide_render = True
o = bpy.context.scene.objects.get("BodyRivets")
o.hide_viewport = o.hide_render = False
bpy.context.scene.render.filepath = 'router_icon.png'
bpy.ops.render.render(write_still=True)

paintColor = mat.node_tree.nodes["RGB.001"].outputs[0]
paintColor.default_value = (0, 0, 0, 1)
bpy.context.scene.render.filepath = 'router_icon_black.png'
bpy.ops.render.render(write_still=True)
   



b = bpy.data.images.load(filepath="router_black.png").pixels[:4*width*height]
w = bpy.data.images.load(filepath="router_white.png").pixels[:4*width*height]
g = bpy.data.images.load(filepath="router_shadow_glow.png").pixels[:4*width*height]
s = bpy.data.images.load(filepath="router_shadow.png").pixels[:4*width*height]
C = bpy.data.images.load(filepath="router_with_clips.png").pixels[:4*width*height]
L = bpy.data.images.load(filepath="router_with_lamps.png").pixels[:4*width*height]

delta = bpy.data.images.new("router", width, 4*height, alpha=True)
def generatePixels():
    # glow
    i = 0
    for y in range(height):
        for x in range(width):
            # TODO: there's probably some kind of gamma thing going on here
            abc = [min(
                max(0,1-(1-g[4*i+j])/max(0.01,1-s[4*i+j])),
                max(0,g[4*i+j]-s[4*i+j])
            )*brightenLightFactor for j in range(3)]
            ma = max(*abc)
            if ma < 0.02: yield (0,0,0,0)
            else:
                ma = max(ma,0.1)
                yield tuple(abc[j]/ma for j in range(3)) + (ma,)
            i += 1

    # shadow
    i = 0
    baseline = s[0]
    for y in range(height):
        for x in range(width):
            
            ma = min(1,max(0,max(*(
                b[4*i+j]*b[4*i+3]+baseline*(1-b[4*i+3])  # b rendered over baseline
                -s[4*i+j]*s[4*i+3]              # shadow
            for j in range(3))))*shadow_factor)
            yield (0,0,0,ma)
            i += 1

    # mask
    i = 0
    for y in range(height):
        for x in range(width):
            ma = max(0,max(*(w[4*i+j]-b[4*i+j] for j in range(3))))
            ma *= (w[4*i+3]+b[4*i+3]) / 2
            ma0 = min(brightenPaintFactor*ma, 1)
            if ma0 < 0.1: yield (1,1,1,ma0)
            else: yield tuple((w[4*i+j]-b[4*i+j])/ma for j in range(3))+ (ma0,)
            i += 1

    # item   
    i = 0
    for y in range(height):
        for x in range(width):
            yield tuple(b[4*i:4*i+4])
            i += 1


delta.pixels = tuple(chain.from_iterable(generatePixels()))
delta.update()
delta.save(filepath="router.png")

def lampPixels():
    # lamp sprite
    for y in range(lamp_height):
        for x in range(lamp_width):
            i = 4*((y+lamp_offy)*width + (x+lamp_offx))
            yield (L[i+0],L[i+1],L[i+2],L[i+3]-C[i+3])
lamp = bpy.data.images.new("light", lamp_width, lamp_height, alpha=True)
lamp.pixels = tuple(chain.from_iterable(lampPixels()))
lamp.update()
lamp.save(filepath="light.png")


b = bpy.data.images.load(filepath="router_icon_black.png").pixels[:4*width*height]
w = bpy.data.images.load(filepath="router_icon.png").pixels[:4*width*height]
delta = bpy.data.images.new("router_icon_mask", width, height, alpha=True)
def iconPixels():
    # mask
    i = 0
    for y in range(height):
        for x in range(width):
            ma = max(0,max(*(w[4*i+j]-b[4*i+j] for j in range(3))))
            ma *= (w[4*i+3]+b[4*i+3]) / 2
            ma0 = min(brightenPaintFactor*ma, 1)
            if ma0 < 0.1: yield (1,1,1,ma0)
            else: yield tuple((w[4*i+j]-b[4*i+j])/ma for j in range(3))+ (ma0,)
            i += 1
delta.pixels = tuple(chain.from_iterable(iconPixels()))
delta.update()
delta.save(filepath="router_icon_mask.png")