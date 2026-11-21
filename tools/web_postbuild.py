"""flutter build web 뒤에 실행: 아이콘 글꼴 이름에 내용 해시를 붙인다.

왜: 앱 안 아이콘은 Flutter가 쓰는 아이콘만 남겨 줄인 글꼴 하나(MaterialIcons-Regular.otf)로 그려진다.
새 아이콘을 쓰면 글꼴 내용이 바뀌지만 이름은 같고, 글꼴은 브라우저가 하루 저장(firebase.json)하므로
전에 접속한 사람은 새 아이콘이 빈칸으로 보인다 (2026-11-21: 홈 화면 아이콘이 다른 사람 휴대폰에서 안 보임).
이름에 해시를 붙여 FontManifest.json(매번 새로 받음)이 새 이름을 가리키게 하면 바뀐 글꼴을 바로 받는다.

사용: python -I tools/web_postbuild.py   (build/web 기준)
"""
import hashlib
import json
import shutil
import sys
from pathlib import Path

WEB = Path(__file__).resolve().parent.parent / "build" / "web"
MANIFEST = WEB / "assets" / "FontManifest.json"


def main() -> int:
    fonts = json.loads(MANIFEST.read_text(encoding="utf-8"))
    changed = []
    for family in fonts:
        if family.get("family") != "MaterialIcons":
            continue
        for f in family["fonts"]:
            rel = f["asset"]  # 예: fonts/MaterialIcons-Regular.otf (assets/ 아래)
            src = WEB / "assets" / rel
            if not src.exists():
                print(f"없음: {src}", file=sys.stderr)
                return 1
            if "." in src.stem:  # 이미 해시가 붙어 있음 (두 번 실행)
                continue
            digest = hashlib.md5(src.read_bytes()).hexdigest()[:10]
            dst = src.with_name(f"{src.stem}.{digest}{src.suffix}")
            shutil.copyfile(src, dst)
            f["asset"] = str(Path(rel).with_name(dst.name)).replace("\\", "/")
            changed.append(f"{rel} -> {f['asset']}")
    MANIFEST.write_text(json.dumps(fonts, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print("\n".join(changed) if changed else "바꿀 글꼴 없음")
    return 0


if __name__ == "__main__":
    sys.exit(main())
