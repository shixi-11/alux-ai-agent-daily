from io import BytesIO
from pathlib import Path

import cv2
import numpy as np
from PIL import Image


URL = "https://ai-agent-daily.alux.network/"
ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "output"
PNG = Path(__file__).with_name(".share-card-render.tmp.png")
JPG = OUTPUT / "20260715_ALUX智能体情报日报中文站扫码卡_3比4_4K.jpg"


def cv_image(payload: bytes) -> np.ndarray:
    image = cv2.imdecode(np.frombuffer(payload, dtype=np.uint8), cv2.IMREAD_COLOR)
    if image is None:
        raise RuntimeError("OpenCV could not decode image")
    return image


def decode(image: np.ndarray) -> str:
    value, _, _ = cv2.QRCodeDetector().detectAndDecode(image)
    return value


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    with Image.open(PNG) as source:
        if source.size != (3072, 4096):
            raise RuntimeError(f"PNG dimensions are {source.size}, expected 3072x4096")
        rgb = source.convert("RGB")
        rgb.save(JPG, "JPEG", quality=95, subsampling=0, optimize=True)

        tests: list[tuple[str, Image.Image]] = [("4K_PNG", rgb.copy())]
        for width in (1080, 720, 540, 360):
            height = round(width * 4 / 3)
            tests.append(
                (
                    f"RESIZE_{width}",
                    rgb.resize((width, height), Image.Resampling.LANCZOS),
                )
            )

        failures: list[str] = []
        results: list[str] = []
        for label, test_image in tests:
            buffer = BytesIO()
            test_image.save(buffer, "JPEG", quality=78, subsampling=0)
            decoded = decode(cv_image(buffer.getvalue()))
            results.append(f"{label}={decoded or 'NO_DECODE'}")
            if decoded != URL:
                failures.append(label)

    with Image.open(JPG) as final_jpg:
        if final_jpg.size != (3072, 4096) or final_jpg.mode != "RGB":
            raise RuntimeError(
                f"JPG validation failed: {final_jpg.size}, mode={final_jpg.mode}"
            )

    if failures:
        raise RuntimeError(f"QR failed in: {', '.join(failures)}; {'; '.join(results)}")

    PNG.unlink(missing_ok=True)
    print(f"JPG_OK {JPG} 3072x4096 RGB")
    print("QR_OK " + "; ".join(results))


if __name__ == "__main__":
    main()
