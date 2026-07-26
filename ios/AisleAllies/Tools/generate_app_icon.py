#!/usr/bin/env python3
"""Generate the dependency-free Aisle Allies app icon."""

from pathlib import Path
import struct
import zlib


SIZE = 1024
pixels = bytearray(SIZE * SIZE * 3)


def set_pixel(x: int, y: int, color: tuple[int, int, int]) -> None:
    if 0 <= x < SIZE and 0 <= y < SIZE:
        offset = (y * SIZE + x) * 3
        pixels[offset : offset + 3] = bytes(color)


def rectangle(
    left: int,
    top: int,
    right: int,
    bottom: int,
    color: tuple[int, int, int],
) -> None:
    for y in range(max(0, top), min(SIZE, bottom)):
        start = (y * SIZE + max(0, left)) * 3
        width = max(0, min(SIZE, right) - max(0, left))
        pixels[start : start + width * 3] = bytes(color) * width


def ellipse(
    center_x: int,
    center_y: int,
    radius_x: int,
    radius_y: int,
    color: tuple[int, int, int],
) -> None:
    for y in range(center_y - radius_y, center_y + radius_y + 1):
        relative_y = (y - center_y) / radius_y
        half_width = int(radius_x * max(0.0, 1.0 - relative_y**2) ** 0.5)
        rectangle(center_x - half_width, y, center_x + half_width + 1, y + 1, color)


def polygon(points: list[tuple[int, int]], color: tuple[int, int, int]) -> None:
    minimum_y = max(0, min(point[1] for point in points))
    maximum_y = min(SIZE - 1, max(point[1] for point in points))
    for y in range(minimum_y, maximum_y + 1):
        intersections: list[int] = []
        for index, start in enumerate(points):
            end = points[(index + 1) % len(points)]
            if (start[1] <= y < end[1]) or (end[1] <= y < start[1]):
                x = start[0] + (y - start[1]) * (end[0] - start[0]) / (
                    end[1] - start[1]
                )
                intersections.append(int(x))
        intersections.sort()
        for index in range(0, len(intersections) - 1, 2):
            rectangle(intersections[index], y, intersections[index + 1] + 1, y + 1, color)


def png_chunk(kind: bytes, data: bytes) -> bytes:
    return (
        struct.pack(">I", len(data))
        + kind
        + data
        + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)
    )


def save_png(path: Path) -> None:
    scanlines = bytearray()
    stride = SIZE * 3
    for y in range(SIZE):
        scanlines.append(0)
        scanlines.extend(pixels[y * stride : (y + 1) * stride])

    png = bytearray(b"\x89PNG\r\n\x1a\n")
    png.extend(png_chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, 2, 0, 0, 0)))
    png.extend(png_chunk(b"IDAT", zlib.compress(bytes(scanlines), level=9)))
    png.extend(png_chunk(b"IEND", b""))
    path.write_bytes(png)


def draw_icon() -> None:
    for y in range(SIZE):
        for x in range(SIZE):
            mix = (x + y) / (SIZE * 2)
            glow = max(0.0, 1.0 - (((x - 700) / 650) ** 2 + ((y - 250) / 650) ** 2))
            checker = 8 if ((x // 128) + (y // 128)) % 2 == 0 else 0
            set_pixel(
                x,
                y,
                (
                    min(255, int(43 + mix * 10 + glow * 43) + checker),
                    min(255, int(18 + mix * 67 + glow * 22) + checker),
                    min(255, int(88 + mix * 35 + glow * 64) + checker),
                ),
            )

    ellipse(520, 730, 370, 115, (28, 16, 55))

    # Cart handle and wheels.
    rectangle(180, 300, 238, 690, (246, 246, 242))
    rectangle(180, 290, 410, 346, (246, 246, 242))
    ellipse(390, 770, 76, 76, (31, 27, 44))
    ellipse(390, 770, 34, 34, (255, 205, 38))
    ellipse(760, 770, 76, 76, (31, 27, 44))
    ellipse(760, 770, 34, 34, (255, 205, 38))

    # Bright shopping-cart basket.
    polygon(
        [(250, 360), (870, 360), (790, 665), (315, 665)],
        (255, 99, 70),
    )
    polygon(
        [(275, 393), (832, 393), (767, 625), (335, 625)],
        (112, 40, 120),
    )

    for x in range(355, 790, 105):
        polygon(
            [(x, 390), (x + 28, 390), (x - 5, 628), (x - 33, 628)],
            (255, 180, 60),
        )
    rectangle(282, 485, 830, 520, (255, 180, 60))

    # Racing bolt and pantry cross.
    polygon(
        [(585, 395), (500, 520), (568, 520), (510, 630), (690, 475), (608, 475)],
        (255, 225, 40),
    )
    rectangle(710, 220, 775, 345, (255, 255, 255))
    rectangle(680, 250, 805, 315, (255, 255, 255))

    output = (
        Path(__file__).resolve().parents[1]
        / "AisleAllies"
        / "Assets.xcassets"
        / "AppIcon.appiconset"
        / "AisleAlliesIcon.png"
    )
    save_png(output)
    print(f"Wrote {output}")


if __name__ == "__main__":
    draw_icon()
