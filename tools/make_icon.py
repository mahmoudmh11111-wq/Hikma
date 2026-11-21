from PIL import Image, ImageDraw
import sys
S=4096; img=Image.new("RGB",(S,S),(250,248,244)); d=ImageDraw.Draw(img)
ink=(28,28,31); gold=(181,140,84)
def mark(cx,cy,r):
    # a quotation mark: dot with a curved tail falling down-left
    d.ellipse([cx-r,cy-r,cx+r,cy+r],fill=ink)
    d.polygon([(cx+r*0.98,cy+r*0.15),(cx+r*0.55,cy+r*2.1),(cx-r*0.35,cy+r*2.45),(cx+r*0.05,cy+r*0.9)],fill=ink)
r=360
mark(S*0.40,S*0.43,r); mark(S*0.60,S*0.43,r)

img.resize((1024,1024),Image.LANCZOS).save(sys.argv[1])
