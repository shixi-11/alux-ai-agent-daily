from pathlib import Path

import cv2
import numpy as np


URL = "https://ai.alux.network/daily/"
OUTPUT = Path(__file__).with_name("qr.png")


def main() -> None:
    params = cv2.QRCodeEncoder_Params()
    params.correction_level = cv2.QRCodeEncoder_CORRECT_LEVEL_H
    params.mode = cv2.QRCodeEncoder_MODE_BYTE

    matrix = cv2.QRCodeEncoder_create(params).encode(URL)
    # OpenCV returns white modules as 255 and black modules as 0.
    # Four modules of white quiet zone are required for reliable scanning.
    matrix = np.pad(matrix, 4, mode="constant", constant_values=255)
    module_size = 24
    image = cv2.resize(
        matrix,
        (matrix.shape[1] * module_size, matrix.shape[0] * module_size),
        interpolation=cv2.INTER_NEAREST,
    )
    encoded, payload = cv2.imencode(".png", image)
    if not encoded:
        raise RuntimeError("Could not encode QR image")
    payload.tofile(str(OUTPUT))

    decoded, _, _ = cv2.QRCodeDetector().detectAndDecode(image)
    if decoded != URL:
        raise RuntimeError(f"QR verification failed: {decoded!r}")

    print(f"QR_OK {OUTPUT} {image.shape[1]}x{image.shape[0]} {decoded}")


if __name__ == "__main__":
    main()
