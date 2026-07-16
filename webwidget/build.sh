#!/bin/bash
# 웹 위젯 빌드: 크롤러로 난지캠핑장 라이브 데이터를 받아 index.html에 주입 → dist/index.html
set -e
cd "$(dirname "$0")"
mkdir -p dist

echo "▶ 라이브 데이터 수집(최대 5회 재시도)…"
DATA=""
for i in 1 2 3 4 5; do
  DATA=$(node ../crawler/crawl.mjs --json 2>/dev/null || true)
  n=$(printf '%s' "$DATA" | node -e "let s='';process.stdin.on('data',d=>s+=d).on('end',()=>{try{console.log(JSON.parse(s).services.length)}catch{console.log(0)}})" 2>/dev/null || echo 0)
  echo "  시도 $i: ${n}건"; [ "$n" = "6" ] && break
done

echo "▶ 데이터 주입…"
STAMP=$(date "+%Y-%m-%d %H:%M")
DATA_WITH_TS=$(printf '%s' "$DATA" | node -e "let s='';process.stdin.on('data',d=>s+=d).on('end',()=>{const o=JSON.parse(s);o.generatedAt='$STAMP';process.stdout.write(JSON.stringify(o))})")
node -e "
const fs=require('fs');
let h=fs.readFileSync('index.html','utf8');
h=h.replace('__DATA__', process.argv[1]);
fs.writeFileSync('dist/index.html', h);
console.log('✅ dist/index.html 생성');
" "$DATA_WITH_TS"

echo "실행:  open \"$PWD/dist/index.html\""
