import base64
import struct

def write_png(width, height):
    with open('assets/icons/app_icon.png', 'wb') as f:
        f.write(base64.b64decode(b'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAEUlEQVR42mNkYPhfz8DAwMAANokBAAn8A23jF8xYAAAAAElFTkSuQmCC'))

write_png(16, 16)
