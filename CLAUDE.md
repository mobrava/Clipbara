# PasteClip - Claude Code 프로젝트 설정

## 빌드 & 실행

- xcodegen 사용: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodegen generate`
- 빌드: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Clipbara.xcodeproj -scheme Clipbara -configuration Debug build`
- **빌드 성공 후 항상 기존 앱 종료 → 재실행까지 자동으로 수행할 것:**
  ```
  pkill -f Clipbara.app || true
  sleep 1
  open ~/Library/Developer/Xcode/DerivedData/Clipbara-fkhylhcltueskmgbecvzvekxrevf/Build/Products/Debug/Clipbara.app
  ```

## 릴리스 & 배포

1. `Clipbara/Info.plist`의 `CFBundleShortVersionString`, `CFBundleVersion` 버전 업데이트
2. 코드 변경사항 커밋
3. DMG 빌드: `bash scripts/build-release.sh` (EdDSA 서명 + appcast.xml 자동 업데이트 포함)
4. **`appcast.xml` 수정 (2가지 작업 필수)**:
   - **새 버전 item 추가**: 빌드 스크립트는 첫 번째 item의 서명/크기만 덮어쓸 뿐 새 항목을 생성하지 않음. 새 item을 기존 첫 번째 item 위에 추가하고 `sparkle:version`, `sparkle:shortVersionString`, URL, 릴리스 노트, EdDSA 서명, length를 정확히 기입할 것
   - **appcast URL은 반드시 v-prefixed 파일명 사용**: `Clipbara-v{VERSION}.dmg` (v 접두사 있는 것). 기존 배포 URL과 Homebrew cask가 이 이름을 쓰고 있음. (예전에 v 없는 파일이 "손상"되던 원인은 GitHub가 아니라 `.github/workflows/release.yml`이었음: 태그 push 시 서명 없이 빌드한 DMG를 같은 이름으로 덮어쓰고 릴리스 노트도 교체했음. 이 워크플로는 삭제됨. 릴리스용 CI 워크플로를 다시 추가하지 말 것)
   - **이전 버전 item의 서명/크기 복원**: 빌드 스크립트가 첫 번째 item의 `sparkle:edSignature`와 `length`를 새 빌드 값으로 덮어쓰므로, `git show HEAD:appcast.xml`로 원래 값을 확인해서 복원할 것. 이걸 빠뜨리면 이전 버전의 Sparkle 업데이트가 깨짐
5. appcast.xml 커밋 & 푸시
6. GitHub 릴리스 생성 + DMG 업로드 + **업로드 검증**:
   ```
   git tag v{VERSION} && git push origin v{VERSION}
   cp build/Clipbara-{VERSION}.dmg /tmp/Clipbara-v{VERSION}.dmg
   gh release create v{VERSION} build/Clipbara-{VERSION}.dmg /tmp/Clipbara-v{VERSION}.dmg --title "v{VERSION}" --notes "..."
   ```
   **반드시 업로드 후 두 DMG 모두 검증할 것:**
   ```
   gh release download v{VERSION} -p "Clipbara-*.dmg" -D /tmp/verify --clobber
   shasum -a 256 /tmp/verify/Clipbara-*.dmg  # 두 파일 모두 빌드 스크립트 출력의 SHA256과 일치해야 함
   ```
7. (선택) Homebrew tap 업데이트 (`mobrava/homebrew-tap`):
   - `Casks/pasteclip.rb`의 `version`과 `sha256` 변경 (sha256은 빌드 스크립트 출력에 나옴)
   - Homebrew cask URL은 `Clipbara-v{VERSION}.dmg` (v 접두사 있음) — 6단계에서 이미 함께 업로드됨
   - GitHub API로 업데이트: `gh api repos/mobrava/homebrew-tap/contents/Casks/pasteclip.rb --method PUT ...`
8. Gatekeeper 문제 시: `xattr -cr /Applications/Clipbara.app`

## Sparkle 자동 업데이트

- Sparkle 2.x SPM 의존성 사용, 앱 내 자동 업데이트 지원
- appcast URL: `https://raw.githubusercontent.com/mobrava/Clipbara/main/appcast.xml`
- EdDSA 비공개키는 macOS Keychain에 저장됨 (`sign_update`가 자동 접근)
- 공개키는 Info.plist `SUPublicEDKey`에 설정됨 (노출 안전)
- `CheckForUpdatesViewModel` (`Services/UpdaterService.swift`): `@EnvironmentObject`로 뷰에 전달
- **코드 서명 (매우 중요)**: 빌드 스크립트는 ad-hoc 서명 + identifier 기반 designated requirement re-sign 사용. **반드시 inside-out 순서로 서명해야 함**: Sparkle 내부 XPC 서비스(Installer.xpc, Downloader.xpc) → Autoupdate, Updater.app → Sparkle.framework → 외부 앱 번들. 외부 앱만 re-sign하고 내부 XPC를 빠뜨리면 Sparkle이 installer를 실행할 때 서명 체인 불일치로 "An error occurred while launching the installer" 에러 발생함

## 프로젝트 규칙

- Swift 6 strict concurrency (`SWIFT_STRICT_CONCURRENCY: complete`)
- macOS 14+ 타겟
- SwiftData 사용 (`#Index`, `#Unique`는 macOS 15 전용이므로 사용 금지)
- KeyboardShortcuts, Sparkle SPM 의존성
- `skipNextChange` 패턴: PasteService 호출 전 ClipboardMonitor.skipNextChange() 필수
- NSPanel(nonactivatingPanel) + NSHostingView로 SwiftUI 호스팅
- **SwiftData 저장 규칙**: 데이터 변경(insert/delete/update) 후 반드시 `try? modelContext.save()` 호출. autosave에 의존하지 말 것
- **뷰 lifecycle 주의**: NSHostingView 내에서 `@Query`를 가진 뷰를 if/else로 조건부 표시하면 파괴/재생성 시 @Query 동기화가 깨질 수 있음. ZStack + opacity 패턴 사용
