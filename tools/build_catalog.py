"""Export the Labyrinth credo catalogue and bundled art; never read game caches."""
import json
import re
import shutil
from pathlib import Path

repo = Path(__file__).resolve().parents[3]
addon = Path(__file__).resolve().parents[1]
source = (repo / "src/haven/QuestObjectivesWindow.java").read_text(encoding="utf-8")
section = source.split("private static final CatalogCredo[] CREDO_CATALOG = {", 1)[1].split("\n\t};", 1)[0]
entries = []
for match in re.finditer(r'new CatalogCredo\("([^"\n]+)", "([^"\n]+)",\s*"((?:[^"\\]|\\.)*)",\s*new String\[\] \{(.*?)\}(.*?)\)', section, re.S):
    name, image, description, bonuses, requires = match.groups()
    strings = lambda value: [json.loads('"' + text + '"') for text in re.findall(r'"((?:[^"\\]|\\.)*)"', value)]
    entries.append(dict(name=name, image="art/"+image, description=json.loads('"'+description+'"'), bonuses=strings(bonuses), requires=strings(requires)))
assert len(entries) == 21, f"Expected 21 source credos, found {len(entries)}"
(addon / "art").mkdir(exist_ok=True)
quote = lambda text: json.dumps(text, ensure_ascii=False)
lines = ["-- Generated from Labyrinth's QuestObjectivesWindow.java. Edit its source, then export.", "QuestUICatalog = {"]
for entry in entries:
    lines.append("  {name="+quote(entry["name"])+", image="+quote(entry["image"])+", description="+quote(entry["description"])+",")
    for key in ("bonuses", "requires"):
        lines.append("   "+key+"={"+", ".join(map(quote, entry[key]))+"},")
    lines.append("  },")
    shutil.copyfile(repo / "src/haven/credo" / Path(entry["image"]).name, addon / entry["image"])
lines.append("}")
(addon / "catalog.lua").write_text("\n".join(lines)+"\n", encoding="utf-8")
print(f"Exported {len(entries)} credos and their existing artwork")
