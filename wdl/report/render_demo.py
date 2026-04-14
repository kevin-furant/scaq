from __future__ import annotations

import json
from pathlib import Path

from jinja2 import Environment, FileSystemLoader, select_autoescape


BASE_DIR = Path(__file__).resolve().parent
TEMPLATE_FILE = "reseq_variant_report_template.j2"
DATA_FILE = BASE_DIR / "fake_render_data.json"
OUTPUT_FILE = BASE_DIR / "rendered_demo.html"


def main() -> None:
    env = Environment(
        loader=FileSystemLoader(str(BASE_DIR)),
        autoescape=select_autoescape(["html", "xml"]),
    )
    template = env.get_template(TEMPLATE_FILE)

    with DATA_FILE.open("r", encoding="utf-8") as f:
        context = json.load(f)

    html = template.render(**context)
    OUTPUT_FILE.write_text(html, encoding="utf-8")
    print(f"Rendered: {OUTPUT_FILE}")


if __name__ == "__main__":
    main()
