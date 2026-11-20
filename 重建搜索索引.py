# 每期新报告发布后运行一次，重建 search-index.json（目录页全文检索数据源）
# 用法: python3 重建搜索索引.py
import re, json, html, glob, os

entries = []
for f in sorted(glob.glob(os.path.join(os.path.dirname(os.path.abspath(__file__)), "2026-*.html")), reverse=True):
    raw = open(f, encoding="utf-8").read()
    m = re.search(r"<title>(.*?)</title>", raw)
    title = m.group(1) if m else os.path.basename(f)
    body = re.sub(r"<script[\s\S]*?</script>", " ", raw)
    body = re.sub(r"<style[\s\S]*?</style>", " ", body)
    text = html.unescape(re.sub(r"<[^>]+>", " ", body))
    text = re.sub(r"\s+", " ", text).strip()
    entries.append({"f": os.path.basename(f), "t": title, "x": text})

out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "search-index.json")
json.dump(entries, open(out, "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
print("rebuilt:", len(entries), "entries,", os.path.getsize(out), "bytes")
