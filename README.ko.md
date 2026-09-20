<p align="center">
  <img src="IssueShot/Assets.xcassets/AppIcon.appiconset/icon-256.png" width="128" height="128" alt="Revvy 앱 아이콘">
</p>

<h1 align="center">Revvy</h1>

<p align="center">
  Mac에서 스크린샷을 찍고, 주석을 달고, 측정하고, 공유하세요. 그리고 바로 GitHub Issue로.
</p>

<p align="center">
  <a href="README.md">English</a> ·
  <a href="README.ja.md">日本語</a> ·
  <a href="README.zh-Hans.md">简体中文</a> ·
  <b>한국어</b>
</p>

<p align="center">
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-green"></a>
  <img alt="macOS 15+" src="https://img.shields.io/badge/macOS-15%2B-blue">
  <img alt="Swift 6" src="https://img.shields.io/badge/Swift-6-orange">
</p>

---

Revvy는 고쳐야 할 부분을 말로 설명하는 대신 "보여 주기" 위한 macOS 네이티브 앱입니다. 어떤 앱에서든 스크린샷을 찍고, 사각형·화살표·텍스트·픽셀 단위 눈금자로 주석을 단 뒤, GitHub Issue나 링크로 공유할 수 있습니다. 캡처, 주석, 복사, 저장은 계정 없이 사용할 수 있습니다.

> **상태:** 초기 개발 단계(0.x)입니다. 미완성 부분이나 호환되지 않는 변경이 있을 수 있습니다.

이 문서는 [영어 README](README.md)를 번역한 것이며, 차이가 있을 경우 영어판을 기준으로 합니다.

## 목차

- [기능](#기능)
- [요구 사항](#요구-사항)
- [설치](#설치)
- [사용 방법](#사용-방법)
- [키보드 단축키](#키보드-단축키)
- [설정](#설정)
- [개인정보 보호](#개인정보-보호)
- [소스에서 빌드하기](#소스에서-빌드하기)
- [포크 배포하기](#포크-배포하기)
- [현지화](#현지화)
- [프로젝트 구조](#프로젝트-구조)
- [알려진 제한 사항](#알려진-제한-사항)
- [기여하기](#기여하기) · [보안](#보안) · [라이선스](#라이선스)

## 기능

**어디서나 캡처**
- ScreenCaptureKit을 이용한 영역 캡처와 전체 화면 캡처
- 어떤 앱에서도 동작하는 전역 단축키(기본값: 영역 <kbd>⌃⇧4</kbd>, 전체 화면 <kbd>⌃⇧3</kbd>), 설정에서 변경 가능
- 모든 앱 위에 떠 있는 작은 캡처 패널, 버튼 하나 크기로 접기 가능
- 메뉴 막대에서 캡처, 눈금자, 설정 호출
- 다중 디스플레이 지원: 선택 오버레이가 모든 디스플레이에 표시되고, 드래그한 디스플레이를 캡처
- 드래그 앤 드롭(Finder, 브라우저, 사진, macOS 스크린샷 썸네일), 클립보드, 파일에서 가져오기

**주석**
- 사각형, 화살표, 펜, 텍스트 도구(4가지 색상)
- 도형 선택·이동·크기 조절, 그리는 중에도 가까운 도형을 바로 잡기(<kbd>⌥</kbd>를 누르면 겹쳐 그리기)
- 화살표 키로 1px 미세 조정(<kbd>⇧</kbd>로 10px), 복제, 삭제, 실행 취소 및 복귀
- 원본 이미지 픽셀 기준 거리 눈금자(px, em 또는 둘 다)
- 내보내기에 포함되지 않는 좌표 눈금자와 중앙 안내선
- 10~400% 확대/축소, 핀치 확대/축소, 손 도구로 이동(100%는 이미지 1픽셀을 화면 1포인트로 표시)

**화면 눈금자**
- 스크린샷 없이 어떤 앱 위에서든 크기를 측정
- 드래그로 이동, 가장자리 드래그로 크기 조절, 화살표 키로 이동, <kbd>⌥</kbd>+화살표로 크기 조절
- 10px 간격 눈금, 중앙 안내선, 복제, 여러 눈금자 동시 표시
- 디스플레이 전체를 가로지르는 세로·가로 안내선, 위치와 가장 가까운 평행선까지의 간격 표시
- 눈금자와 안내선은 스크린샷에도 포함되므로 측정한 상태 그대로 공유할 수 있습니다

**보관과 검색**
- 사이드바의 캡처 기록과 메모
- 기기 내 텍스트 인식(Apple Vision)으로 이미지 속 텍스트로 캡처 검색
- 인식된 텍스트 복사, 주석이 포함된 이미지 복사, PNG로 저장

**GitHub에 공유**
- GitHub 기기 흐름(device flow)으로 로그인(Client Secret 불필요, 토큰은 키체인에 저장)
- 주석이 달린 스크린샷, 레이블, 담당자가 포함된 Issue 생성. 환경 정보(앱 버전, macOS, 기기, 디스플레이)를 자동으로 추가
- 주석이 포함된 이미지를 업로드하고 링크를 한 번에 복사
- Issue 텍스트의 토큰, JWT, `Authorization`/`Cookie` 헤더, 이메일 주소를 자동으로 가림

## 요구 사항

- macOS 15 Sequoia 이상
- 화면 기록 권한(첫 캡처 시 요청)
- GitHub 기능을 사용할 때만 GitHub 계정 필요

## 설치

### 다운로드

서명 및 공증된 빌드는 [Releases](../../releases) 페이지에 게시됩니다. `.dmg`를 다운로드한 뒤 **Revvy**를 **응용 프로그램** 폴더로 드래그하고 실행하세요.

### 직접 빌드하기

[소스에서 빌드하기](#소스에서-빌드하기)를 참고하세요.

### 처음 실행할 때

1. Revvy를 엽니다. 화면 오른쪽 위 근처에 캡처 패널이 나타납니다.
2. 첫 캡처를 합니다. macOS가 **화면 기록** 권한을 요청하면 **시스템 설정 → 개인정보 보호 및 보안 → 화면 및 시스템 오디오 녹음**에서 Revvy를 허용하세요.
3. 그래도 캡처가 되지 않으면 Revvy를 종료했다가 다시 여세요(macOS는 앱을 다시 시작한 뒤에 권한을 적용하기도 합니다).

## 사용 방법

### 캡처

| 방법 | 동작 |
| --- | --- |
| <kbd>⌃⇧4</kbd>(전역) 또는 캡처 패널의 영역 버튼 | 드래그로 영역 선택. 오버레이가 모든 디스플레이에 표시되며 <kbd>Esc</kbd>로 취소 |
| <kbd>⌃⇧3</kbd>(전역) 또는 디스플레이 버튼 | 포인터가 있는 디스플레이 전체를 캡처 |
| <kbd>⌘⇧V</kbd> 또는 도구 막대의 **캡처 ▾ → 클립보드에서 붙여넣기** | 클립보드의 이미지 사용 |
| 드래그 앤 드롭 | Revvy 윈도우나 캡처 패널에 이미지를 놓기 |
| 도구 막대의 **캡처 ▾ → 이미지 파일 열기…** | 이미지 파일 열기 |

Revvy 윈도우와 캡처 패널은 스크린샷에 나타나지 않습니다. 화면 눈금자와 안내선은 측정 결과를 남길 수 있도록 캡처됩니다(마우스를 올렸을 때만 나타나는 버튼은 제외). 캡처가 끝나면 모든 눈금자와 안내선이 화면에서 사라지며, <kbd>Esc</kbd>로 캡처를 취소하면 그대로 남습니다.

캡처 패널의 **×**를 누르면 버튼 하나 크기로 접히고, 그 버튼을 누르면 다시 펼쳐집니다. 패널을 완전히 숨기려면 메뉴 막대 메뉴, 설정 또는 단축키를 사용하세요.

### 주석

캔버스 아래쪽 팔레트에서 도구를 선택합니다.

- **선택 및 이동** — 도형을 클릭해 선택하고 드래그해 이동. 화살표와 눈금자는 끝점을 드래그해 조정
- **눈금자(거리 측정)** — 드래그로 측정. <kbd>⇧</kbd>를 누르면 수평/수직
- **사각형**, **화살표**, **펜** — 드래그로 그리기. 기존 도형 근처를 드래그하면 이동하고, <kbd>⌥</kbd>를 누르면 겹쳐 그리기
- **텍스트** — 클릭한 위치에 텍스트를 놓고 입력한 뒤 <kbd>↩</kbd>로 확정(<kbd>⌥↩</kbd>로 줄바꿈). 놓인 텍스트는 텍스트 도구로 클릭하거나 다른 도구로 이중 클릭해 편집
- **손 도구** — 확대 상태에서 드래그로 이동

도구 막대의 공유 메뉴에서 **이미지 복사** 또는 **PNG로 저장…**을 사용할 수 있습니다. 복사, 저장, 공유되는 것은 주석이 포함된 이미지입니다. 안내선, 좌표 눈금자, 선택 핸들은 내보내지 않습니다.

### 화면 눈금자

캡처 패널의 눈금자 버튼을 누르거나, 메뉴 막대 메뉴에서 **화면 눈금자 추가**를 선택하거나, <kbd>⌃⌘R</kbd>를 누르면 포인터 위치에 320 × 200 크기의 눈금자가 나타납니다.

- 안쪽을 드래그해 이동하고, 가장자리나 모서리를 드래그해 크기 조절
- 화살표 키로 1px 이동(<kbd>⇧</kbd>로 10px), <kbd>⌥</kbd>+화살표로 크기 조절
- <kbd>⌘D</kbd> 복제, <kbd>⌘;</kbd> 중앙 안내선, <kbd>Esc</kbd> 또는 <kbd>⌘W</kbd> 닫기
- 마우스를 올리면 안내선·복제·닫기 버튼이 나타나며, 오른쪽 클릭으로도 같은 작업 가능
- <kbd>⌃⌘T</kbd>로 모든 눈금자와 안내선 가리기/보기

**안내선** — 캡처 패널의 세로선·가로선 버튼(메뉴 막대 메뉴나 눈금자의 오른쪽 클릭 메뉴에서도 가능)을 누르면 포인터 위치에 디스플레이 전체를 가로지르는 선이 그려집니다. 드래그하거나 화살표 키(<kbd>⇧</kbd>로 10px)로 이동합니다. 레이블에는 디스플레이 왼쪽·위쪽 가장자리로부터의 거리와, 평행한 선이 있으면 그 간격이 표시됩니다. <kbd>⌘D</kbd>로 복제, <kbd>Esc</kbd> 또는 <kbd>⌫</kbd>로 삭제합니다. 전역 단축키는 설정에서 지정할 수 있습니다.

크기는 포인트 단위이며 CSS 픽셀과 같습니다. 단위(px/em)는 눈금자 설정을 따릅니다.

### GitHub에 공유

1. **GitHub에 연결**을 누르고 브라우저에서 코드를 승인합니다(기기 흐름).
2. 인스펙터에서 저장소를 선택합니다.
3. **링크 생성 및 복사**는 주석이 포함된 이미지를 업로드하고 URL을 복사합니다.
4. **Issue 생성**은 제목(비워 두면 본문 첫 줄), 코멘트, 스크린샷, 레이블, 담당자, 환경 정보가 포함된 Issue를 만듭니다.

이미지는 Issue 본문에 포함하지 않고 전용 브랜치(기본값 `feedback-assets`)의 `screenshots/`에 커밋합니다. 공개 저장소에서는 이미지도 공개되며, 비공개 저장소에서는 접근 권한이 있는 사람만 볼 수 있습니다. 로컬 기록을 삭제해도 GitHub의 데이터는 삭제되지 않습니다.

조직 저장소에서는 조직이 OAuth App을 승인해야 할 수 있습니다.

## 키보드 단축키

| 단축키 | 동작 | 범위 |
| --- | --- | --- |
| <kbd>⌃⇧4</kbd> | 영역 캡처 | 전역(변경 가능) |
| <kbd>⌃⇧3</kbd> | 전체 화면 캡처 | 전역(변경 가능) |
| <kbd>⌃⌘R</kbd> | 화면 눈금자 추가 | 전역(변경 가능) |
| <kbd>⌃⌘T</kbd> | 눈금자 보기/가리기 | 전역(변경 가능) |
| — | 플로팅 패널 보기/가리기 | 전역(설정에서 지정) |
| — | 세로/가로 안내선 추가 | 전역(설정에서 지정) |
| <kbd>⌘⇧V</kbd> | 클립보드 이미지 사용 | 앱 내 |
| <kbd>⌘Z</kbd> / <kbd>⇧⌘Z</kbd> | 실행 취소/복귀(입력 중에는 텍스트, 그 외에는 주석) | 앱 내 |
| <kbd>⌘D</kbd> | 선택한 주석 또는 눈금자 복제 | 앱 내/눈금자 |
| <kbd>⌫</kbd> | 선택한 주석 삭제 | 캔버스 |
| 화살표 키 | 1px 이동(<kbd>⇧</kbd>로 10px) | 캔버스/눈금자 |
| <kbd>⌘+</kbd> <kbd>⌘-</kbd> <kbd>⌘1</kbd> <kbd>⌘0</kbd> | 확대, 축소, 실제 크기, 화면에 맞추기 | 캔버스 |
| <kbd>⌘;</kbd> | 중앙 안내선 | 캔버스/눈금자 |
| <kbd>⌘↩</kbd> | Issue 생성 | 인스펙터 |

<kbd>⌘⇧3</kbd>, <kbd>⌘⇧4</kbd>, <kbd>⌘⇧5</kbd>는 macOS 기본 스크린샷 기능이 사용하므로 전역 단축키로 지정할 수 없습니다.

## 설정

**Revvy → 설정…**(<kbd>⌘,</kbd>) 또는 메뉴 막대 메뉴의 **설정…**에서 엽니다.

- **단축키** — 전역 단축키 기록(클릭한 뒤 키를 누름, <kbd>Esc</kbd> 취소, <kbd>⌫</kbd> 지우기), 플로팅 패널 보기/가리기, 기본값으로 복원. 다른 앱이 이미 사용 중인 조합이면 경고합니다
- **눈금자** — 표시 단위(px, em 또는 둘 다)와 em 계산에 사용할 루트 `font-size`
- **Issue** — 자동으로 추가할 레이블(기본값 `app-feedback`)과 스크린샷 보관 브랜치(기본값 `feedback-assets`)
- **GitHub 연결** — 포크용 OAuth App Client ID 덮어쓰기

## 개인정보 보호

- 캡처한 이미지, 주석, 메모, 인식된 텍스트는 Mac(`~/Library/Application Support/Revvy/Captures`)에만 저장됩니다
- 텍스트 인식은 Apple Vision을 사용해 기기에서 처리합니다
- GitHub 토큰은 macOS 키체인에 저장됩니다
- 분석, 광고, 충돌 보고 SDK가 없으며 개발자에게 아무것도 전송하지 않습니다
- GitHub 기능을 사용할 때만 데이터가 Mac 밖으로 나가며, 선택한 저장소로만 전송됩니다

자세한 내용은 [PRIVACY.ko.md](PRIVACY.ko.md)를 참고하세요.

## 소스에서 빌드하기

필요 사항: macOS 15 이상, Xcode 26 이상, [XcodeGen](https://github.com/yonaskolb/XcodeGen)

```bash
brew install xcodegen
git clone https://github.com/<owner>/revvy.git
cd revvy
make run    # Xcode 프로젝트 생성, 빌드, 실행
```

기타 명령:

```bash
make open   # 프로젝트를 생성하고 Xcode에서 열기
make build  # build/에 Debug 빌드
make test   # Swift Testing 테스트 실행
make clean  # 빌드 결과물과 생성된 프로젝트 삭제
```

Xcode 프로젝트는 `project.yml`에서 생성되며 저장소에 커밋하지 않습니다.

### 코드 서명

기본적으로 애드혹(ad-hoc) 서명을 사용하므로 Apple Developer 계정이 필요 없습니다. 애드혹 서명은 빌드할 때마다 바뀌므로 macOS가 화면 기록 권한이나 키체인 접근을 다시 요청할 수 있습니다. 일상적인 개발에는 본인의 인증서로 서명하세요.

```bash
cp Config/Local.xcconfig.example Config/Local.xcconfig
# DEVELOPMENT_TEAM을 본인의 팀 ID로 설정
make build
```

`Config/Local.xcconfig`는 Git에서 무시됩니다.

## 포크 배포하기

1. **Bundle ID** — `project.yml`의 `PRODUCT_BUNDLE_IDENTIFIER`를 변경합니다(내부 모듈 이름은 과거 사정으로 `IssueShot`으로 남아 있습니다).
2. **GitHub OAuth App** — <https://github.com/settings/applications/new>에서 본인의 OAuth App을 만들고 **Device Flow**를 활성화한 뒤, Client ID를 `IssueShot/OAuthConfig.swift`에 설정합니다. 기기 흐름은 Client Secret을 사용하지 않으므로 Client ID는 공개해도 됩니다.
3. **Developer ID 빌드** — Developer ID Application 인증서와 공증용 자격 증명을 준비한 뒤:

   ```bash
   make notary-setup TEAM_ID=YOUR_TEAM_ID APPLE_ID=you@example.com
   make dist TEAM_ID=YOUR_TEAM_ID              # 서명, 공증, 스테이플 → dist/Revvy-<version>.dmg
   TEAM_ID=YOUR_TEAM_ID ./scripts/dist.sh --no-notarize   # 서명과 패키징만
   ```

   DMG에는 설치 화면(배경 이미지와 아이콘 배치)이 포함됩니다. `pip3 install --user dmgbuild pillow`가 필요하며, 없으면 기본 디스크 이미지로 만들어집니다. 앱 아이콘을 바꾼 뒤에는 `python3 scripts/make-dmg-background.py`로 배경을 다시 만드세요.

4. **Mac App Store(선택)** — App Sandbox를 활성화한 `AppStore` 빌드 구성, 개인정보 보호 매니페스트, 내보내기 스크립트가 포함되어 있습니다. [docs/APP_STORE.md](docs/APP_STORE.md)를 참고하세요.

## 현지화

앱과 문서는 다음 언어를 지원합니다.

| 언어 | 앱 | README |
| --- | --- | --- |
| 일본어(개발 언어) | ✅ | [README.ja.md](README.ja.md) |
| 영어 | ✅ | [README.md](README.md) |
| 중국어 간체 | ✅ | [README.zh-Hans.md](README.zh-Hans.md) |
| 한국어 | ✅ | [README.ko.md](README.ko.md) |

UI 문구는 String Catalog `IssueShot/Resources/Localizable.xcstrings`에 있습니다. 언어를 추가하거나 번역을 개선하려면 Xcode에서 카탈로그를 열어 번역을 추가하고 Pull Request를 보내 주세요. Revvy는 **시스템 설정 → 일반 → 언어 및 지역**의 언어 순서를 따르며, 앱별 언어도 그곳에서 설정할 수 있습니다.

## 프로젝트 구조

```
IssueShot/
  IssueShotApp.swift        앱 진입점, 메뉴, 메뉴 막대
  AppModel.swift            캡처, 주석, 기록, GitHub 상태
  CaptureControls.swift     전역 단축키, 플로팅 패널, 캡처 진입점
  Models/                   주석, 도형 계산, 뷰포트 계산, GitHub 모델
  Services/                 화면 캡처, 이미지 드롭, 단축키, GitHub 클라이언트/인증, 기록과 텍스트 인식, 가림 처리
  Views/                    SwiftUI/AppKit 뷰(편집기, 사이드바, 인스펙터, 패널, 화면 눈금자, 설정)
  Resources/                String Catalog, 개인정보 보호 매니페스트, 아이콘
IssueShotTests/             Swift Testing 테스트
Config/                     서명 및 빌드 구성
scripts/                    배포 스크립트
docs/                       추가 문서
```

## 알려진 제한 사항

- 동영상이나 GIF 녹화는 지원하지 않습니다
- 공유는 GitHub 저장소의 브랜치를 사용하며 별도의 이미지 호스팅이 없으므로, 저장소 접근 권한이 없는 사람은 비공개 저장소의 링크를 열 수 없습니다
- 화면 기록 권한을 변경한 뒤에는 앱을 다시 시작해야 할 수 있습니다
- 공식 빌드에 포함된 GitHub OAuth App의 등록 이름은 아직 "IssueShot"입니다

## 기여하기

버그 보고, 아이디어, Pull Request를 환영합니다. [CONTRIBUTING.md](CONTRIBUTING.md)를 참고하세요.

## 보안

취약점은 공개 Issue에 올리지 마세요. [SECURITY.md](SECURITY.md)를 참고하세요.

## 라이선스

[MIT](LICENSE) © Revvy contributors
