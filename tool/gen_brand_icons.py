"""SetBeat 品牌图标生成器（纯标准库，无第三方依赖）。

产出三组资源：
  1. assets/icon/app_icon.png             1024  传统启动图标（深色底 + 品牌标记）
  2. assets/icon/app_icon_foreground.png  1024  自适应图标前景（透明底，留安全区）
  3. android/.../drawable-*dpi/ic_stat_setbeat.png
                                          24/36/48/72/96  通知栏单色小图标
                                            （必须纯白 + 透明底，Android 会自行着色）

几何全部以「环半径 = 1.0」为单位建模，再按目标尺寸缩放，
与原版 android/app/src/main/res/drawable-v24/ic_launcher_foreground.xml 同源：
环形进度（右上缺口 60°）+ 时钟指针 + 缺口处的节拍点。

用法： python tool/gen_brand_icons.py
"""

import math
import os
import struct
import zlib

# ---------------------------------------------------------------- 几何常量（单位：环半径）

RING_SW = 0.28                     # 环描边宽度
HAND_SW = 0.269                    # 指针描边宽度
# 指针：12 点方向 -> 圆心 -> 右下，肘点在圆心（与原版矢量 M54,42 L54,54 L62,59 同源）
HAND = [
    ((0.0, -0.4615), (0.0, 0.0)),
    ((0.0, 0.0), (0.3077, 0.1923)),
]
DOT_C = (0.7881, -0.8654)          # 节拍点圆心（落在缺口方向外侧）
DOT_R = 0.1923                     # 节拍点半径
GAP_HALF = 30.0                    # 缺口半角（度）
GAP_CENTER = math.degrees(math.atan2(DOT_C[1], DOT_C[0])) % 360.0
# 缺口两端的圆头帽端点（描边端头必须为 round，与矢量 strokeLineCap="round" 一致）
_CAP0_A = math.radians(GAP_CENTER + GAP_HALF)
_CAP1_A = math.radians(GAP_CENTER - GAP_HALF)
CAP0 = (math.cos(_CAP0_A), math.sin(_CAP0_A))
CAP1 = (math.cos(_CAP1_A), math.sin(_CAP1_A))

# 品牌色
C_RING = (0xFF, 0x6B, 0x35)
C_HAND = (0xFF, 0xFF, 0xFF)
C_DOT = (0xFF, 0x8C, 0x5A)
C_WHITE = (0xFF, 0xFF, 0xFF)
BG = (0x0D, 0x10, 0x20)

# 标记的整体外接半径（环外沿 + 节拍点），用于计算安全区缩放
EXTENT = max(1.0 + RING_SW / 2.0, math.hypot(*DOT_C) + DOT_R)


# ---------------------------------------------------------------- 形状命中测试


def _seg_dist(p, a, b):
    ax, ay = a
    bx, by = b
    px, py = p
    dx, dy = bx - ax, by - ay
    l2 = dx * dx + dy * dy
    if l2 == 0.0:
        return math.hypot(px - ax, py - ay)
    t = ((px - ax) * dx + (py - ay) * dy) / l2
    t = 0.0 if t < 0.0 else (1.0 if t > 1.0 else t)
    return math.hypot(px - (ax + t * dx), py - (ay + t * dy))


def hit(p):
    """返回该点落在哪个部件上：'dot' / 'hand' / 'ring' / None（坐标单位：环半径）。"""
    px, py = p
    if math.hypot(px - DOT_C[0], py - DOT_C[1]) <= DOT_R:
        return 'dot'
    for a, b in HAND:
        if _seg_dist(p, a, b) <= HAND_SW / 2.0:
            return 'hand'
    d = math.hypot(px, py)
    if abs(d - 1.0) <= RING_SW / 2.0:
        ang = math.degrees(math.atan2(py, px)) % 360.0
        if abs(((ang - GAP_CENTER + 180.0) % 360.0) - 180.0) > GAP_HALF:
            return 'ring'
    # 缺口两端的圆头帽
    cap_r = RING_SW / 2.0
    if (math.hypot(px - CAP0[0], py - CAP0[1]) <= cap_r
            or math.hypot(px - CAP1[0], py - CAP1[1]) <= cap_r):
        return 'ring'
    return None


# ---------------------------------------------------------------- 光栅化


def raster(size, radius_ratio, ss=3, background=None, monochrome=False,
           corner_radius_ratio=0.0):
    """把品牌标记光栅化为 RGBA 像素。

    size            输出边长（px）
    radius_ratio    环半径占边长的比例
    background      背景色元组，None 表示透明
    monochrome      全部部件用纯白（用于通知栏小图标）
    corner_radius_ratio  圆角矩形背景的圆角比例，0 表示满幅方形
    """
    out = bytearray(size * size * 4)
    cx = cy = size / 2.0
    inv = 1.0 / size
    n = ss * ss
    step = 1.0 / ss
    half = 0.5
    inv_r = 1.0 / radius_ratio

    for y in range(size):
        for x in range(size):
            acc = {'ring': 0, 'hand': 0, 'dot': 0}
            for sy in range(ss):
                fy = y + (sy + half) * step
                for sx in range(ss):
                    fx = x + (sx + half) * step
                    # 换算到「环半径 = 1」坐标系
                    px = (fx - cx) * inv * inv_r
                    py = (fy - cy) * inv * inv_r
                    k = hit((px, py))
                    if k is not None:
                        acc[k] += 1
            ri, gi, bi, ai = 0, 0, 0, 0
            if background is not None:
                ri, gi, bi = background
                ai = 255
                if corner_radius_ratio > 0.0:
                    cr = corner_radius_ratio * size
                    qx = min(x + 0.5, size - x - 0.5)
                    qy = min(y + 0.5, size - y - 0.5)
                    if qx < cr and qy < cr:
                        dd = math.hypot(cr - qx, cr - qy)
                        if dd > cr:
                            ai = 0
            for key in ('dot', 'hand', 'ring'):
                c = acc[key]
                if c == 0:
                    continue
                if monochrome:
                    col = C_WHITE
                else:
                    col = {'ring': C_RING, 'hand': C_HAND, 'dot': C_DOT}[key]
                a = c / n
                # 标准 source-over 混合
                na = a + (ai / 255.0) * (1.0 - a)
                if na <= 0.0:
                    continue
                ri = int(round((col[0] * a + ri * (ai / 255.0) * (1.0 - a)) / na))
                gi = int(round((col[1] * a + gi * (ai / 255.0) * (1.0 - a)) / na))
                bi = int(round((col[2] * a + bi * (ai / 255.0) * (1.0 - a)) / na))
                ai = int(round(na * 255))
            o = (y * size + x) * 4
            out[o] = ri
            out[o + 1] = gi
            out[o + 2] = bi
            out[o + 3] = ai
    return bytes(out)


def write_png(path, size, rgba):
    raw = bytearray()
    stride = size * 4
    for y in range(size):
        raw.append(0)
        raw += rgba[y * stride:(y + 1) * stride]

    def chunk(tag, data):
        return (struct.pack('>I', len(data)) + tag + data
                + struct.pack('>I', zlib.crc32(tag + data) & 0xFFFFFFFF))

    png = (b'\x89PNG\r\n\x1a\n'
           + chunk(b'IHDR', struct.pack('>IIBBBBB', size, size, 8, 6, 0, 0, 0))
           + chunk(b'IDAT', zlib.compress(bytes(raw), 9))
           + chunk(b'IEND', b''))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'wb') as fh:
        fh.write(png)
    print(f'  {path}  ({size}x{size}, {len(png) / 1024:.1f} KB)')


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    res = os.path.join(root, 'android', 'app', 'src', 'main', 'res')

    print('生成应用图标：')
    # 传统图标：深色底 + 标记占外接 62%
    write_png(os.path.join(root, 'assets', 'icon', 'app_icon.png'), 1024,
              raster(1024, 0.62 / (EXTENT * 2), ss=3, background=BG,
                     corner_radius_ratio=0.0))
    # 自适应前景：透明底，标记限制在 66% 安全区内
    write_png(os.path.join(root, 'assets', 'icon', 'app_icon_foreground.png'), 1024,
              raster(1024, 0.64 / (EXTENT * 2), ss=3))

    print('生成通知栏小图标（纯白单色）：')
    for folder, px in (('mdpi', 24), ('hdpi', 36), ('xhdpi', 48),
                       ('xxhdpi', 72), ('xxxhdpi', 96)):
        write_png(os.path.join(res, f'drawable-{folder}', 'ic_stat_setbeat.png'), px,
                  raster(px, 0.30, ss=4, monochrome=True))
    print('完成。')


if __name__ == '__main__':
    main()
