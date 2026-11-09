"""
generate_netsuite_icon.py
Generates a high-tech modern network suite launcher icon for 'Alijaya NetSuite'
"""

import math
import os
from PIL import Image, ImageDraw, ImageFilter

MASTER_SIZE = 1024
SS_SIZE = 2048

# Cyber Tech Palette
BG_DARK = (7, 16, 30, 255)         # Deepest Cyber Navy
BG_LIGHT = (14, 38, 70, 255)       # Luminous Cyber Blue
CYAN_BRIGHT = (0, 229, 255, 255)    # Neon Cyan (#00E5FF)
EMERALD_NEON = (0, 230, 118, 255)  # Neon Green (#00E676)
WHITE = (255, 255, 255, 255)
BLUE_ACCENT = (41, 121, 255, 255)

def build_icon():
    print("Building Alijaya NetSuite master icon...")
    cx = SS_SIZE / 2
    cy = SS_SIZE / 2
    
    # 1. Radial background
    bg = Image.new("RGBA", (SS_SIZE, SS_SIZE), BG_DARK)
    bg_draw = ImageDraw.Draw(bg)
    max_r = SS_SIZE * 0.85
    steps = 150
    for i in range(steps, -1, -1):
        t = i / steps
        r = int(BG_LIGHT[0] * (1 - t) + BG_DARK[0] * t)
        g = int(BG_LIGHT[1] * (1 - t) + BG_DARK[1] * t)
        b = int(BG_LIGHT[2] * (1 - t) + BG_DARK[2] * t)
        cur_r = max_r * t
        bg_draw.ellipse([cx - cur_r, cy - cur_r, cx + cur_r, cy + cur_r], fill=(r, g, b, 255))
        
    # Squircle mask
    corner_radius = int(SS_SIZE * 0.22)
    mask = Image.new("L", (SS_SIZE, SS_SIZE), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, SS_SIZE, SS_SIZE], radius=corner_radius, fill=255)
    
    canvas = Image.new("RGBA", (SS_SIZE, SS_SIZE), (0, 0, 0, 0))
    canvas.paste(bg, (0, 0), mask)
    draw = ImageDraw.Draw(canvas)
    
    # 2. Outer Cyber Frame (Double Rounded Rect)
    inset = int(SS_SIZE * 0.05)
    r_frame = corner_radius - inset
    draw.rounded_rectangle([inset, inset, SS_SIZE - inset, SS_SIZE - inset], radius=r_frame, outline=CYAN_BRIGHT, width=int(SS_SIZE * 0.012))
    
    inset2 = inset + int(SS_SIZE * 0.018)
    draw.rounded_rectangle([inset2, inset2, SS_SIZE - inset2, SS_SIZE - inset2], radius=r_frame - int(SS_SIZE * 0.018), outline=(0, 229, 255, 60), width=int(SS_SIZE * 0.004))
    
    # 3. Hexagonal Network Grid / Tech Mesh in Background
    grid_layer = Image.new("RGBA", (SS_SIZE, SS_SIZE), (0, 0, 0, 0))
    g_draw = ImageDraw.Draw(grid_layer)
    hex_r = SS_SIZE * 0.16
    for i in range(6):
        ang1 = i * (math.pi / 3)
        ang2 = (i + 1) * (math.pi / 3)
        x1 = cx + hex_r * 2.2 * math.cos(ang1)
        y1 = cy + hex_r * 2.2 * math.sin(ang1)
        x2 = cx + hex_r * 2.2 * math.cos(ang2)
        y2 = cy + hex_r * 2.2 * math.sin(ang2)
        g_draw.line([(x1, y1), (x2, y2)], fill=(0, 229, 255, 25), width=int(SS_SIZE * 0.003))
        g_draw.line([(cx, cy), (x1, y1)], fill=(0, 229, 255, 18), width=int(SS_SIZE * 0.002))
    canvas = Image.alpha_composite(canvas, grid_layer)
    
    # 4. Central Network Router / Fiber Optical Emblem
    emblem = Image.new("RGBA", (SS_SIZE, SS_SIZE), (0, 0, 0, 0))
    e_draw = ImageDraw.Draw(emblem)
    
    # Concentric WiFi / Signal Waves on top
    for i in range(3):
        wave_r = int(SS_SIZE * (0.24 + i * 0.08))
        wave_box = [cx - wave_r, cy * 0.70 - wave_r, cx + wave_r, cy * 0.70 + wave_r]
        e_draw.arc(wave_box, start=220, end=320, fill=CYAN_BRIGHT if i == 2 else (0, 229, 255, 160), width=int(SS_SIZE * 0.018))
        
    # Central Router / Gateway Box
    box_w = int(SS_SIZE * 0.44)
    box_h = int(SS_SIZE * 0.20)
    box_y = int(cy * 1.05)
    
    # Rounded router base
    e_draw.rounded_rectangle(
        [cx - box_w / 2, box_y - box_h / 2, cx + box_w / 2, box_y + box_h / 2],
        radius=int(box_h * 0.35),
        fill=(15, 30, 55, 255),
        outline=CYAN_BRIGHT,
        width=int(SS_SIZE * 0.010)
    )
    
    # Router LED Status Lights (Green & Cyan)
    led_y = box_y
    led_r = int(SS_SIZE * 0.016)
    led_colors = [EMERALD_NEON, EMERALD_NEON, CYAN_BRIGHT, CYAN_BRIGHT, (255, 215, 0, 255)]
    for idx, col in enumerate(led_colors):
        lx = cx - box_w * 0.32 + idx * (box_w * 0.16)
        e_draw.ellipse([lx - led_r, led_y - led_r, lx + led_r, led_y + led_r], fill=col)
        # Small glow
        glow_r = led_r * 2
        e_draw.ellipse([lx - glow_r, led_y - glow_r, lx + glow_r, led_y + glow_r], fill=(col[0], col[1], col[2], 60))
        
    # Dual Router Antennas
    ant_w = int(SS_SIZE * 0.012)
    # Left antenna
    e_draw.line([(cx - box_w * 0.35, box_y - box_h / 2), (cx - box_w * 0.40, box_y - int(box_h * 1.3))], fill=CYAN_BRIGHT, width=ant_w)
    e_draw.ellipse([cx - box_w * 0.40 - ant_w, box_y - int(box_h * 1.3) - ant_w, cx - box_w * 0.40 + ant_w, box_y - int(box_h * 1.3) + ant_w], fill=WHITE)
    # Right antenna
    e_draw.line([(cx + box_w * 0.35, box_y - box_h / 2), (cx + box_w * 0.40, box_y - int(box_h * 1.3))], fill=CYAN_BRIGHT, width=ant_w)
    e_draw.ellipse([cx + box_w * 0.40 - ant_w, box_y - int(box_h * 1.3) - ant_w, cx + box_w * 0.40 + ant_w, box_y - int(box_h * 1.3) + ant_w], fill=WHITE)
    
    # 5. Fiber Optic Cable / Ethernet Network Hub at Bottom
    hub_y = box_y + int(box_h * 1.05)
    hub_w = int(box_w * 0.65)
    # Branching lines connecting to 3 network nodes
    node_r = int(SS_SIZE * 0.025)
    nodes_x = [cx - hub_w / 2, cx, cx + hub_w / 2]
    
    for nx in nodes_x:
        # Line from router to node
        e_draw.line([(cx, box_y + box_h / 2), (nx, hub_y)], fill=(0, 230, 118, 180), width=int(SS_SIZE * 0.007))
        # Node circle
        e_draw.ellipse([nx - node_r, hub_y - node_r, nx + node_r, hub_y + node_r], fill=EMERALD_NEON, outline=WHITE, width=int(SS_SIZE * 0.004))
        
    # Soft Bloom / Glow
    bloom = emblem.filter(ImageFilter.GaussianBlur(int(SS_SIZE * 0.02)))
    canvas = Image.alpha_composite(canvas, bloom)
    canvas = Image.alpha_composite(canvas, emblem)
    
    # Glass sheen
    sheen = Image.new("RGBA", (SS_SIZE, SS_SIZE), (0, 0, 0, 0))
    ImageDraw.Draw(sheen).polygon([(0, 0), (SS_SIZE * 0.95, 0), (SS_SIZE * 0.12, SS_SIZE * 0.52), (0, SS_SIZE * 0.52)], fill=(255, 255, 255, 20))
    sheen_clipped = Image.new("RGBA", (SS_SIZE, SS_SIZE), (0, 0, 0, 0))
    sheen_clipped.paste(sheen, (0, 0), mask)
    canvas = Image.alpha_composite(canvas, sheen_clipped)
    
    return canvas.resize((MASTER_SIZE, MASTER_SIZE), Image.Resampling.LANCZOS)

def main():
    master = build_icon()
    
    # Save assets/images
    os.makedirs("D:/alijaya_network_suite/assets/images", exist_ok=True)
    master.save("D:/alijaya_network_suite/assets/images/app_logo.png", "PNG")
    print("Saved assets/images/app_logo.png")
    
    # Save Android mipmaps
    densities = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    for folder, sz in densities.items():
        p = f"D:/alijaya_network_suite/android/app/src/main/res/{folder}"
        os.makedirs(p, exist_ok=True)
        master.resize((sz, sz), Image.Resampling.LANCZOS).save(f"{p}/ic_launcher.png", "PNG")
        print(f"Saved {folder}/ic_launcher.png ({sz}x{sz})")

if __name__ == "__main__":
    main()
