#!/bin/bash
# 联慧东城法规觅踪 — 生成可对外分享的公网链接
# 双击运行。窗口保持打开期间链接有效；关闭窗口或电脑休眠则失效。
# 2026-11-20 修订：cloudflared 在部分网络（代理/QUIC受限）下返回 530，
# 故先试 cloudflared，失败自动回退 localhost.run（ssh -R）。

cd "$(dirname "$0")" || exit 1
PORT=8931
CFD="$HOME/.workbuddy/binaries/bin/cloudflared"
PY="/Users/wujiayue/.workbuddy/binaries/python/versions/3.13.12/bin/python3"
LOG=/tmp/cfd_share.log
LHR_LOG=/tmp/lhr_share.log

echo "────────────────────────────────────────"
echo " 联慧东城法规觅踪 · 公网分享"
echo "────────────────────────────────────────"

# 1. 本地静态服务
if lsof -i TCP:$PORT >/dev/null 2>&1; then
  echo "✓ 本地服务已在 $PORT 端口运行"
else
  echo "… 启动本地服务"
  nohup "$PY" -m http.server $PORT --bind 127.0.0.1 >/tmp/httpd_$PORT.log 2>&1 &
  sleep 2
fi

URL=""

# 2. 方案一：cloudflared 快速隧道
if [ -x "$CFD" ]; then
  echo "… 尝试 Cloudflare 隧道（约 15 秒）"
  rm -f "$LOG"
  nohup "$CFD" tunnel --url http://127.0.0.1:$PORT --no-autoupdate > "$LOG" 2>&1 &
  CFD_PID=$!
  for i in $(seq 1 20); do
    URL=$(grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' "$LOG" 2>/dev/null | head -1)
    [ -n "$URL" ] && break
    sleep 1
  done
  if [ -n "$URL" ]; then
    # 验证可达（530 视为失败）
    sleep 4
    CODE=$(curl -s -o /dev/null -m 10 -w '%{http_code}' "$URL/" 2>/dev/null)
    if [ "$CODE" != "200" ]; then
      echo "✗ Cloudflare 隧道不可达（HTTP $CODE），改用备用方案"
      kill $CFD_PID 2>/dev/null
      URL=""
    fi
  fi
fi

# 3. 方案二：localhost.run（ssh 反向隧道，免账号）
if [ -z "$URL" ]; then
  echo "… 启动 localhost.run 隧道（约 15 秒）"
  rm -f "$LHR_LOG"
  nohup ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=30 -R 80:localhost:$PORT nokey@localhost.run > "$LHR_LOG" 2>&1 &
  for i in $(seq 1 25); do
    URL=$(grep -oE 'https://[a-z0-9-]+\.app\.lhr\.life' "$LHR_LOG" 2>/dev/null | head -1)
    [ -n "$URL" ] && break
    sleep 1
  done
fi

if [ -z "$URL" ]; then
  echo "✗ 两种隧道均未能获取公网地址，请检查网络。日志：$LOG / $LHR_LOG"
  read -n 1 -s -r -p "按任意键退出"
  exit 1
fi

sleep 3
CODE=$(curl -s -o /dev/null -m 10 -w '%{http_code}' "$URL/" 2>/dev/null)
[ "$CODE" != "200" ] && sleep 6 && CODE=$(curl -s -o /dev/null -m 10 -w '%{http_code}' "$URL/" 2>/dev/null)

printf '%s' "$URL/" | pbcopy

echo ""
echo "════════════════════════════════════════"
echo "  公网链接（已复制到剪贴板，外部可直接点开）"
echo ""
echo "  $URL/"
echo ""
echo "  · 报告总目录（带搜索）： $URL/"
echo "  · 最新一期报告：        $URL/2026-11-20.html"
echo "  · 最新一期 PDF：        $URL/2026-11-20.pdf"
echo ""
echo "  状态检测：HTTP $CODE $([ "$CODE" = "200" ] && echo ✓ || echo '✗ 稍等片刻后重试')"
echo "════════════════════════════════════════"
echo ""
echo "⚠ 此窗口关闭、电脑休眠或断网，链接即刻失效，且重启后域名会变。"
echo "  需要永久固定网址，请把本文件夹托管到 GitHub Pages。"
echo ""

open "$URL/" 2>/dev/null
wait
