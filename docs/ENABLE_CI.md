# GitHub Actions CI 활성화

저장소 생성 토큰에 `workflow` 스코프가 없어 CI 워크플로가 트리거 경로 밖인
`.github/ci-workflow.yml`에 보관되어 있습니다. 활성화하려면:

```bash
gh auth refresh -s workflow -h github.com
mkdir -p .github/workflows
git mv .github/ci-workflow.yml .github/workflows/ci.yml
git commit -m "CI 워크플로 활성화"
git push
```
