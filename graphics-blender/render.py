import bpy
from itertools import chain

# TODO: organize this better.  Less copy-paste

brightenPaintFactor = 1.5
brightenLightFactor = 0.4

(width,height) = 416,320
(lamp_width,lamp_height) = 32,32
(lamp_offx,lamp_offy) = 214,232
shadow_factor = 4

bpy.ops.wm.open_mainfile(filepath="router.blend")
bpy.context.scene.render.resolution_x = width
bpy.context.scene.render.resolution_y = height

mat = bpy.data.materials["Painted metal"]
clip = bpy.data.materials.get("Clip")
lamp = bpy.data.materials.get("IndicatorLight")
o = bpy.context.scene.objects.get("ShadowPlane")
o.hide_viewport = o.hide_render = True


# Render with xy plane to catch shadow and glow
def entrance_lights_visible(visible=True):
    lights = bpy.data.collections["Entrance lights"]
    lights.hide_viewport = lights.hide_render = not visible
entrance_lights_visible(False)

def set_bulb_texture(texture):
    bulbs = bpy.data.collections["Bulbs"]
    for bulb in bulbs.objects:
        if bulb.data.materials: bulb.data.materials[0] = texture
        else: bulb.data.materials.append(texture)

    bulbs_big = bpy.data.collections["BulbsBig"]
    for bulb in bulbs_big.objects:
        bulb.data.materials[0] = texture

def set_paint(value):
    paintColor = mat.node_tree.nodes["RGB.001"].outputs[0]
    paintColor.default_value = (value, value, value, 1)

# Render with black paint
set_bulb_texture(clip)
set_paint(0)
bpy.context.scene.render.filepath = 'router_black.png'
bpy.ops.render.render(write_still=True)

# Render with white paint
set_paint(1)
bpy.context.scene.render.filepath = 'router_white.png'
bpy.ops.render.render(write_still=True)

# with lights on instead of clip.  First make the lamps still clip, but a little bigger...
def big_bulbs_visible(visible=True):
    bulbs_big = bpy.data.collections["BulbsBig"]
    bulbs_big.hide_viewport = bulbs_big.hide_render = not visible
big_bulbs_visible(True)
bpy.context.scene.render.filepath = 'router_with_clips.png'
bpy.ops.render.render(write_still=True)

# Next just render them
set_bulb_texture(lamp)
bpy.context.scene.render.filepath = 'router_with_lamps.png'
bpy.ops.render.render(write_still=True)

# Render with xy plane to catch shadow and glow
def shadow_plane_visible(visible=True):
    o = bpy.context.scene.objects.get("ShadowPlane")
    o.hide_viewport = o.hide_render = not visible
shadow_plane_visible(True)
bpy.context.scene.render.filepath = 'router_shadow.png'
bpy.ops.render.render(write_still=True)

# Render with entrance lights
entrance_lights_visible(True)
bpy.context.scene.render.filepath = 'router_shadow_glow.png'
bpy.ops.render.render(write_still=True)

# Remove the shadow plane, tie points and fine details
def tie_points_visible(visible=True):
    tie_points = bpy.data.collections["TiePoints"]
    tie_points.hide_viewport = tie_points.hide_render = not visible

def body_rivets_visible(visible=True):
    o = bpy.context.scene.objects.get("BodyRivets")
    o.hide_viewport = o.hide_render = not visible

shadow_plane_visible(False)
entrance_lights_visible(False)
tie_points_visible(False)
body_rivets_visible(False)
# In white...
set_paint(1)
bpy.context.scene.render.filepath = 'router_icon.png'
bpy.ops.render.render(write_still=True)

# And in black
set_paint(0)
bpy.context.scene.render.filepath = 'router_icon_black.png'
bpy.ops.render.render(write_still=True)

def composite(width, imgData, offX, offY, f, *images):
    """
    Main subroutine to combine images into imgData
    """
    subw = subh = None
    pixels = []
    for file in images:
        img = bpy.data.images.load(filepath=file)
        w,h = img.size
        pixels.append((w,h, img.pixels[:]))
        if subw is None:
            subw,subh = w,h
        else:
            subw = min(subw, w)
            subh = min(subh, h)
    
    for y in range(subh):
        for x in range(subw):
            local_pixels = [
                pix[4*(y*w+x):4*(y*w+x+1)]
                for w,_,pix in pixels
            ]
            imgData[
                4*((y+offY)*width + offX + x):
                4*((y+offY)*width + offX + x + 1)
            ] = f(*local_pixels)

def composite_glow(g,s):
    abc = [min(
        max(0,1-(1-g[j])/max(0.01,1-s[j])),
        max(0,g[j]-s[j])
    )*brightenLightFactor for j in range(3)]
    ma = max(*abc)
    if ma < 0.02: return (0,0,0,0)
    ma = max(ma,0.1)
    return tuple(abc[j]/ma for j in range(3)) + (ma,)

baseline = [None]
def composite_shadow(b,s,baseline=baseline):
    if baseline[0] is None: baseline[0] = s[0]
    return (0,0,0,
        min(1,max(0,max(*(b[j]*b[3]+baseline[0]*(1-b[3])-s[j]*s[3]
        for j in range(3))))*shadow_factor)
    )

def composite_mask(w, b):
    ma = max(0,max(*(w[j]-b[j] for j in range(3))))
    ma *= (w[3]+b[3]) / 2
    ma0 = min(brightenPaintFactor*ma, 1)
    if ma0 < 0.1: return (1,1,1,ma0)
    else: return tuple((w[j]-b[j])/ma for j in range(3))+ (ma0,)

delta = bpy.data.images.new("router", width, 4*height, alpha=True)
imgData = [0]*(16*width*height)
composite(width, imgData, 0, 0*height, composite_glow,   "router_shadow_glow.png", "router_shadow.png")
composite(width, imgData, 0, 1*height, composite_shadow, "router_black.png", "router_shadow.png")
composite(width, imgData, 0, 2*height, composite_mask,   "router_white.png", "router_black.png" )
composite(width, imgData, 0, 3*height, lambda x:x,       "router_black.png" )
delta.pixels = tuple(imgData)
delta.update()
delta.save(filepath="router.png")

C = bpy.data.images.load(filepath="router_with_clips.png").pixels[:4*width*height]
L = bpy.data.images.load(filepath="router_with_lamps.png").pixels[:4*width*height]
lamp = bpy.data.images.new("light", lamp_width, lamp_height, alpha=True)
lamp.pixels = tuple(
    P
    for y in range(lamp_height)
    for x in range(lamp_width)
    for i in [4*(width*(y+lamp_offy)+x+lamp_offx)]
    for P in (L[i+0],L[i+1],L[i+2],L[i+3]-C[i+3])
)
lamp.update()
lamp.save(filepath="light.png")


delta = bpy.data.images.new("router_icon_mask", width, height, alpha=True)
imgData = [0]*(4*width*height)
composite(width, imgData, 0, 0, composite_mask, "router_icon_white.png", "router_icon_black.png" )
delta.pixels = tuple(chain.from_iterable(imgData))
delta.update()
delta.save(filepath="router_icon_mask.png")