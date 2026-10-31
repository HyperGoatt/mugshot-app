#!/usr/bin/env python3
"""Compose review boards from the actual native captures; never redraw app content."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
root=Path(__file__).resolve().parent
font='/System/Library/Fonts/Helvetica.ttc'
def board(names,path,cols=3):
 rows=(len(names)+cols-1)//cols;cw=410;ch=835
 im=Image.new('RGB',(cols*cw+30,rows*ch+105),'#EEE6D8');d=ImageDraw.Draw(im)
 d.text((30,22),'THE WEEKLY POUR / NATIVE DESIGN PREVIEW',font=ImageFont.truetype(font,25),fill='#1F1712')
 for i,(name,label) in enumerate(names):
  a=Image.open(root/'screens'/f'{name}.png');a.thumbnail((380,740));x=30+(i%cols)*cw;y=85+(i//cols)*ch;im.paste(a,(x,y));d.text((x,y+750),label,font=ImageFont.truetype(font,19),fill='#1F1712')
 im.save(root/path,optimize=True)
board([('cover','01 · A warm welcome'),('highlight','03 · A memory to turn over'),('usual','05 · The repeat order')],'first-look.png')
board([(x,y) for x,y in zip(['cover','moments','highlight','places','usual','ending'],['The welcome','Your little moments','That really good sip','Your coffee circuit','The repeat order','A keepsake ending'])],'story-board.png')
board([('journal','The Journal entry'),('invitation','The Sunday invitation'),('share','Choose what you share'),('single','A one-sip week'),('quiet','Room for every pace'),('no-photo','A photo-free memory')],'experience-board.png')
assets=root/'review/assets';assets.mkdir(parents=True,exist_ok=True)
for name in ['cover','highlight','usual']:
 a=Image.open(root/'screens'/f'{name}.png');a.thumbnail((603,1167));a.save(assets/f'{name}.png',optimize=True)
