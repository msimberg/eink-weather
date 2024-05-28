#!/usr/bin/env python
##
 #  @filename   :   main.cpp
 #  @brief      :   7.5inch e-paper display demo
 #  @author     :   Yehui from Waveshare
 #
 #  Copyright (C) Waveshare     July 28 2017
 #
 # Permission is hereby granted, free of charge, to any person obtaining a copy
 # of this software and associated documnetation files (the "Software"), to deal
 # in the Software without restriction, including without limitation the rights
 # to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 # copies of the Software, and to permit persons to  whom the Software is
 # furished to do so, subject to the following conditions:
 #
 # The above copyright notice and this permission notice shall be included in
 # all copies or substantial portions of the Software.
 #
 # THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 # IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 # FITNESS OR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 # AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 # LIABILITY WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 # OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 # THE SOFTWARE.
 ##

import epd5in83b
from PIL import Image
from PIL import ImageDraw
from PIL import ImageFont
import random
import sys

EPD_WIDTH = 600
EPD_HEIGHT = 448

def main():
    epd = epd5in83b.EPD()
    epd.init()

    image_black = Image.open(sys.argv[1])
    image_red = Image.new('1', (EPD_WIDTH, EPD_HEIGHT), 255)    # 255: clear the frame

    if len(sys.argv) < 3 or (sys.argv[2] not in ["red", "black"]):
        print("usage: command <image> {red|black}")
        sys.exit(1)

    if sys.argv[2] == "red":
        image_black, image_red = image_red, image_black

    epd.display_frame(epd.get_frame_buffer(image_black), epd.get_frame_buffer(image_red))


if __name__ == '__main__':
    main()
