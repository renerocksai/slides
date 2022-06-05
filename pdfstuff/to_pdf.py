import sys
import os
from fpdf import FPDF
import re


imgdir = sys.argv[1]

images = [f for f in os.listdir(imgdir) if f.endswith('.png')]

# natural sorting


def atoi(text):
    return int(text) if text.isdigit() else text


def natural_keys(text):
    '''
    alist.sort(key=natural_keys) sorts in human order
    http://nedbatchelder.com/blog/200712/human_sorting.html
    (See Toothy's implementation in the comments)
    '''
    return [atoi(c) for c in re.split(r'(\d+)', text)]


images.sort(key=natural_keys)


h = int(297/1920*1080)
w = 297
print(f'{w}x{h}')
pdf = FPDF('L', 'mm', (h, w))
# --> this doesn't work anymore: pdf = FPDF('L', 'px', (1920, 1080))

for f in sorted(images, key=natural_keys):
    pdf.add_page()
    print(f)
    pdf.image(os.path.join(imgdir, f), x=0, y=0, w=297, h=h)
pdf.output('output.pdf', 'F')
