import os
from pathlib import Path

def get_icc_path ():
    env = os.getenv("PDF_ICC_PATH")
    if env and Path(env).exists():
        return env
    for p in [
        "./resource_files/AdobeRGB1998.icc",
        "/Library/ColorSync/Profiles/AdobeRGB1998.icc",
        "/System/Library/ColorSync/Profiles/AdobeRGB1998.icc",
        "/usr/share/color/icc/AdobeRGB1998.icc",
        "/usr/share/color/icc/adobe/AdobeRGB1998.icc",
        "/usr/local/share/color/icc/AdobeRGB1998.icc"
    ]:
        if Path(p).exists():
            return p
    return None

def get_exec_path ():
    for p in [
        "../_build/default/app/pdfaer.exe",
        "../../_build/default/app/pdfaer.exe",
        "../../pdfaer.exe",
        "../../app/pdfaer.exe",
        "pdfaer.exe"
    ]:
        if Path(p).exists() and os.access(p, os.X_OK):
            return str(p)
    return None
