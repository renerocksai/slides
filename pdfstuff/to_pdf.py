import sys
import os
from fpdf import FPDF

imgdir = sys.argv[1]

images = [f for f in os.listdir(imgdir) if f.endswith('.png')]
images.sort()




h=int(297/1920*1080)
w=297
print(f'{w}x{h}')
pdf = FPDF('L', 'mm', (h, w))

for f in sorted(images):
    pdf.add_page()
    pdf.image(os.path.join(imgdir, f), x=0, y=0, w=297, h=h)
pdf.output('output.pdf', 'F')

