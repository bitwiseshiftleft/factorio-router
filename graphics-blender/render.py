import bpy
from itertools import chain
from math import pi
from mathutils import Euler, Matrix

brightenPaintFactor = 1.5
brightenLightFactor = 0.4
brightenLampFactor = 1.3

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
    lights = bpy.data.collections["IOPointlights"]
    lights.hide_viewport = lights.hide_render = not visible
entrance_lights_visible(False)

def set_bulb_texture(texture):
    for bulbGroup in ["Bulbs","BulbsBig","IoPointBulb"]:
        bulbs = bpy.data.collections[bulbGroup]
        for bulb in bulbs.objects:
            if bulb.data.materials: bulb.data.materials[0] = texture
            else: bulb.data.materials.append(texture)

def set_paint(value):
    paintColor = mat.node_tree.nodes["RGB.001"].outputs[0]
    paintColor.default_value = (value, value, value, 1)

# Render with black paint
set_bulb_texture(clip)
set_paint(0)
bpy.context.scene.render.filepath = "output/router_black.png"
bpy.ops.render.render(write_still=True)

# Render with white paint
set_paint(1)
bpy.context.scene.render.filepath = "output/router_white.png"
bpy.ops.render.render(write_still=True)

# with lights on instead of clip.  First make the lamps still clip, but a little bigger...
def big_bulbs_visible(visible=True):
    bulbs_big = bpy.data.collections["BulbsBig"]
    bulbs_big.hide_viewport = bulbs_big.hide_render = not visible
big_bulbs_visible(True)
bpy.context.scene.render.filepath = "output/router_with_clips.png"
bpy.ops.render.render(write_still=True)

# Next just render them
set_bulb_texture(lamp)
bpy.context.scene.render.filepath = "output/router_with_lamps.png"
bpy.ops.render.render(write_still=True)

# Render with xy plane to catch shadow and glow
def shadow_plane_visible(visible=True):
    o = bpy.context.scene.objects.get("ShadowPlane")
    o.hide_viewport = o.hide_render = not visible
shadow_plane_visible(True)
bpy.context.scene.render.filepath = "output/router_shadow.png"
bpy.ops.render.render(write_still=True)

# Render with entrance lights
entrance_lights_visible(True)
bpy.context.scene.render.filepath = "output/router_shadow_glow.png"
bpy.ops.render.render(write_still=True)

# Remove the shadow plane, tie points and fine details
def tie_points_visible(visible=True):
    for grp in ["TiePoints","ConnNorth","ConnWest","ConnCenter","Wires"]:
        tie_points = bpy.data.collections[grp]
        tie_points.hide_viewport = tie_points.hide_render = not visible

def rotated_tie_points(direction = None):
    directions = [] if direction is None else [direction]
    for grp in ["ConnNorth","ConnWest"]:
        tie_points = bpy.data.collections[grp]
        tie_points.hide_viewport = tie_points.hide_render = grp not in directions


def body_rivets_visible(visible=True):
    for obj in ["BodyRivets","IoRivets"]:
        o = bpy.context.scene.objects.get(obj)
        o.hide_viewport = o.hide_render = not visible

shadow_plane_visible(False)
entrance_lights_visible(False)
tie_points_visible(False)
body_rivets_visible(False)
# In white...
set_paint(1)
bpy.context.scene.render.filepath = "output/router_icon_white.png"
bpy.ops.render.render(write_still=True)

# And in black
set_paint(0)
bpy.context.scene.render.filepath = "output/router_icon_black.png"
bpy.ops.render.render(write_still=True)

def composite(width, imgData, offX, offY, f, *images, size=None, off=None):
    """
    Main subroutine to combine images into imgData
    """
    subw,subh = (None,None) if size is None else size
    subx,suby = (0,0) if off is None else off
    pixels = []
    for file in images:
        img = bpy.data.images.load(filepath="output/"+file)
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
                pix[4*((suby+y)*w+x+subx):4*((suby+y)*w+x+subx+1)]
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
delta.save(filepath="output/router.png")

C = bpy.data.images.load(filepath="output/router_with_clips.png").pixels[:4*width*height]
L = bpy.data.images.load(filepath="output/router_with_lamps.png").pixels[:4*width*height]
blf = brightenLampFactor
lamp = bpy.data.images.new("light", lamp_width, lamp_height, alpha=True)
lamp.pixels = tuple(
    P
    for y in range(lamp_height)
    for x in range(lamp_width)
    for i in [4*(width*(y+lamp_offy)+x+lamp_offx)]
    for P in (min(1,blf*L[i+0]),min(1,blf*L[i+1]),min(1,blf*L[i+2]),L[i+3]-C[i+3])
)
lamp.update()
lamp.save(filepath="output/light.png")


delta = bpy.data.images.new("router_icon_mask", width, height, alpha=True)
imgData = [0]*(4*width*height)
composite(width, imgData, 0, 0, composite_mask, "router_icon_white.png", "router_icon_black.png" )
delta.pixels = tuple(imgData)
delta.update()
delta.save(filepath="output/router_icon_mask.png")


###################################
# I/O ports
###################################

def hub_visible(visible=True):
    hub = bpy.data.collections["Hub"]
    hub.hide_viewport = hub.hide_render = not visible
def io_visible(visible=True):
    io = bpy.data.collections["IOPoint"]
    io.hide_viewport = io.hide_render = not visible
hub_visible(False)
io_visible(True)
tie_points_visible(True)
body_rivets_visible(True)
set_bulb_texture(clip)

rot_mat = Euler((0, 0, pi/2)).to_matrix().to_4x4()
sqz_fac = 1.2
sqz_mat = Matrix.Identity(4)
sqz_mat[0][0] = sqz_fac
sqz_mat[1][1] = 1/sqz_fac

dont_scale = set()
for grp in ["ConnCenter","ConnWest","ConnNorth"]:
    for obj in bpy.data.collections.get(grp).all_objects:
        dont_scale.add(obj)

for dir in ["North","East","South","West"]:
    shadow_plane_visible(False)
    entrance_lights_visible(False)

    if dir in ["North","South"]: rotated_tie_points("ConnNorth")
    else: rotated_tie_points("ConnWest")
    set_paint(1)
    bpy.context.scene.render.filepath = "output/io_%s_white.png" % dir
    bpy.ops.render.render(write_still=True)

    set_paint(0)
    bpy.context.scene.render.filepath = "output/io_%s_black.png" % dir
    bpy.ops.render.render(write_still=True)

    shadow_plane_visible(True)
    bpy.context.scene.render.filepath = "output/io_%s_shadow.png" % dir
    bpy.ops.render.render(write_still=True)

    entrance_lights_visible(True)
    bpy.context.scene.render.filepath = "output/io_%s_shadow_glow.png" % dir
    bpy.ops.render.render(write_still=True)

    # Rotate 90 degrees
    for grpname in ["IOPoint", "Tunnel items"]:
        grp = bpy.data.collections.get(grpname)
        for obj in grp.all_objects:
            obj.matrix_world = rot_mat @ obj.matrix_world
            if obj not in dont_scale: obj.matrix_world = sqz_mat @ obj.matrix_world

north_width = 320
east_width = 256
east_height = 256
north_height = 160
west_ox = east_ox = 64
north_ox,north_oy,south_oy = 48,128,112
io_width = 2*north_width+4*east_width
io_height = 4*north_height
delta = bpy.data.images.new("io", io_width, io_height, alpha=True)
imgData = [0]*(4*io_width*io_height)
for (dir,offo,offy) in [("North",0,north_oy),("South",north_width,south_oy)]:
    composite(io_width, imgData, offo, 0*north_height, composite_glow,   "io_%s_shadow_glow.png"%dir, "io_%s_shadow.png"%dir,
        size=(north_width,north_height),off=(north_ox,offy))
    composite(io_width, imgData, offo, 1*north_height, composite_shadow, "io_%s_black.png"%dir, "io_%s_shadow.png"%dir,
        size=(north_width,north_height),off=(north_ox,offy))
    composite(io_width, imgData, offo, 2*north_height, composite_mask,   "io_%s_white.png"%dir, "io_%s_black.png"%dir,
        size=(north_width,north_height),off=(north_ox,offy))
    composite(io_width, imgData, offo, 3*north_height, lambda x:x,       "io_%s_black.png"%dir,
        size=(north_width,north_height),off=(north_ox,offy))
for (dir,offo,offy) in [("East",2*north_width,east_ox),("West",2*north_width+2*east_width,west_ox)]:
    composite(io_width, imgData, offo, 0*east_height, composite_glow,   "io_%s_shadow_glow.png"%dir, "io_%s_shadow.png"%dir,
        size=(east_width,east_height),off=(north_ox,offy))
    composite(io_width, imgData, offo, 1*east_height, composite_shadow, "io_%s_black.png"%dir, "io_%s_shadow.png"%dir,
        size=(east_width,east_height),off=(north_ox,offy))
    composite(io_width, imgData, offo+east_width, 0*east_height, composite_mask,   "io_%s_white.png"%dir, "io_%s_black.png"%dir,
        size=(east_width,east_height),off=(north_ox,offy))
    composite(io_width, imgData, offo+east_width, 1*east_height, lambda x:x,       "io_%s_black.png"%dir,
        size=(east_width,east_height),off=(north_ox,offy))
delta.pixels = tuple(imgData)
delta.update()
delta.save(filepath="output/io.png")

# Icons
# Scale it a little x-taller
sqz_mat = Matrix.Identity(4)
sqz_fac = 1.3
sqz_mat[0][0] = sqz_fac
sqz_mat[1][1] = 1
for grpname in ["IOPoint", "Tunnel items"]:
    grp = bpy.data.collections.get(grpname)
    for obj in grp.all_objects:
        obj.matrix_world = sqz_mat @ obj.matrix_world
shadow_plane_visible(False)
entrance_lights_visible(False)
tie_points_visible(False)
body_rivets_visible(False)
# In white...
set_paint(1)
bpy.context.scene.render.filepath = "output/io_North_icon_white.png"
bpy.ops.render.render(write_still=True)

# And in black
set_paint(0)
bpy.context.scene.render.filepath = "output/io_North_icon_black.png"
bpy.ops.render.render(write_still=True)

delta = bpy.data.images.new("io_icon_mask", width, height, alpha=True)
imgData = [0]*(4*width*height)
composite(width, imgData, 0, 0, composite_mask, "io_North_icon_white.png", "io_North_icon_black.png" )
delta.pixels = tuple(imgData)
delta.update()
delta.save(filepath="output/io_icon_mask.png")