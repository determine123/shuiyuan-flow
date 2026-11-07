"""从确定性的波纹几何图形生成各平台应用图标，需 Pillow。"""
import math
from pathlib import Path
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parent.parent

def icon(size):
    scale = 4
    canvas = Image.new('RGBA', (size * scale, size * scale), '#087F83')
    draw = ImageDraw.Draw(canvas)
    unit = size * scale / 108
    for base in (35, 54, 73):
        points = [(round(x * unit), round((base - 4 * math.sin((x - 24) * math.pi / 15)) * unit))
                  for x in (24 + step / 4 for step in range(241))]
        width = round(6 * unit)
        draw.line(points, fill='white', width=width, joint='curve')
        for x, y in (points[0], points[-1]):
            r = width / 2
            draw.ellipse((x - r, y - r, x + r, y + r), fill='white')
    return canvas.resize((size, size), Image.Resampling.LANCZOS)

paths = list((root / 'ios/Runner/Assets.xcassets/AppIcon.appiconset').glob('*.png'))
paths += list((root / 'macos/Runner/Assets.xcassets/AppIcon.appiconset').glob('*.png'))
paths += list((root / 'android/app/src/main/res').glob('mipmap-*/ic_launcher.png'))
for path in paths:
    with Image.open(path) as existing:
        size = existing.width
    icon(size).convert('RGB').save(path)
icon(256).save(root / 'windows/runner/resources/app_icon.ico', sizes=[(16,16),(32,32),(48,48),(64,64),(128,128),(256,256)])
print(f'Generated {len(paths)} PNG icons and Windows ICO.')
