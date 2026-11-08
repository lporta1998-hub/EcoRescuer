import os
from PIL import Image
R=GAME_ROOT
N='rs/'
cells=[
 ('Characters/CharacterLabra/Assets/Sprites/Labra.png',[(0,0,48,48),(0,48,48,96),(48,144,96,192)],5),
 ('Characters/CharacterRanger/Assets/Sprites/RangerIdle.png',[(0,128,64,192),(0,64,64,128)],4),
 ('Characters/CharacterNerd/Assets/Sprites/idle.png',[(0,128,64,192),(0,64,64,128)],4),
 ('Characters/CharacterBoar/Assets/Sprites/boar-character.png',[(0,520,64,584),(0,584,64,648)],4),
]
import sys
GAME_ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")) + "/"  # the EcoRescuer project
bg=tuple(int(x) for x in (sys.argv[1] if len(sys.argv)>1 else '70,110,70').split(','))
out=Image.new('RGBA',(2400,560),bg+(255,))
x=10
for f,boxes,s in cells:
    for b in boxes:
        for row,base in enumerate([R,N]):
            im=Image.open(base+f).convert('RGBA').crop(b); im=im.resize((im.width*s,im.height*s),Image.NEAREST)
            out.paste(im,(x,10+row*275),im)
        x+= (b[2]-b[0])*s-20
out.crop((0,0,x+20,560)).save('preview_chars.png')
