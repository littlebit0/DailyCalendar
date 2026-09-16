"""Convert KMA's official district/grid workbook to the offline region index."""

import argparse
import json
from pathlib import Path
import xml.etree.ElementTree as ET
import zipfile


def convert(source):
    ns = {"m": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}
    with zipfile.ZipFile(source) as archive:
        strings = [
            "".join(item.itertext())
            for item in ET.fromstring(archive.read("xl/sharedStrings.xml")).findall("m:si", ns)
        ]
        rows = ET.fromstring(archive.read("xl/worksheets/sheet1.xml")).findall("m:sheetData/m:row", ns)
        regions = []
        for row in rows[1:]:
            cells = {}
            for cell in row:
                column = "".join(c for c in cell.attrib["r"] if c.isalpha())
                value = cell.findtext("m:v", "", ns)
                cells[column] = strings[int(value)] if cell.get("t") == "s" else value
            if cells.get("A") != "kor" or not cells.get("F") or not cells.get("G"):
                continue
            regions.append({
                "id": cells["B"],
                "name": " ".join(cells.get(c, "") for c in "CDE").strip(),
                "x": int(cells["F"]), "y": int(cells["G"]),
                "latitude": round(float(cells["O"]), 7),
                "longitude": round(float(cells["N"]), 7),
            })
        if len(regions) < 3000 or len({r["id"] for r in regions}) != len(regions):
            raise ValueError("Incomplete or duplicate KMA region index")
        return regions


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("source")
    parser.add_argument("output")
    args = parser.parse_args()
    Path(args.output).parent.mkdir(parents=True, exist_ok=True)
    Path(args.output).write_text(json.dumps(convert(args.source), ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")
