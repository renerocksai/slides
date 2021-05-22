#!/usr/bin/env python
import sys
from PIL import Image

if __name__ == '__main__':
    fname = sys.argv[1]

    im = Image.open(fname)
    w, h = im.size
    print(f'Orig   : {w}x{h}')
    
    arglen = len(sys.argv)

    if arglen > 2:
        dimension, new_size = sys.argv[2].split(':')
        new_size = int(new_size)

        if dimension == 'w': 
            frac = w / new_size
            w = new_size
            h = h / frac
        else:
            frac = h / new_size
            h = new_size
            w = w / frac
    print(f'Resized: {w:.0f}x{h:.0f}')

    center_x = (1920 - w) / 2
    center_y = (1080 - h) / 2
    print(f'Center : {center_x:.0f}, {center_y:.0f}')
