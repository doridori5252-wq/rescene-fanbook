import sys
from PIL import Image, ImageDraw, ImageFont
N=1024; SS=4; W=N*SS
im=Image.new("RGB",(W,W),"#eef1f6"); d=ImageDraw.Draw(im)
s=lambda v:int(v*SS)
# notebook body
x0,y0,x1,y1=232,176,744,848
cols=["#f0b93a","#8f5a72","#5fb882","#d07f45","#e8628f"]
th=(y1-y0-60)/5
for i,c in enumerate(cols):
    ty=y0+30+i*th
    d.rounded_rectangle([s(x1-40),s(ty+8),s(x1+70),s(ty+th-8)],radius=s(22),fill=c)
d.rounded_rectangle([s(x0),s(y0),s(x1),s(y1)],radius=s(44),fill="#18203a")
# pen-blue margin line
d.rectangle([s(x0+92),s(y0),s(x0+100),s(y1)],fill="#2b46c9")
# ring holes
for i in range(6):
    cy=y0+86+i*100
    d.ellipse([s(x0+30),s(cy-17),s(x0+64),s(cy+17)],fill="#eef1f6")
f=ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf",s(300))
t="R:"; bb=d.textbbox((0,0),t,font=f)
cx=(x0+100+x1)/2; cy=(y0+y1)/2
d.text((s(cx)-(bb[2]+bb[0])/2,s(cy)-(bb[3]+bb[1])/2),t,font=f,fill="#ffffff")
im=im.resize((N,N),Image.LANCZOS)
im.save(sys.argv[1])
