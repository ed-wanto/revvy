# 개인정보 보호

[English](PRIVACY.md) · [日本語](PRIVACY.ja.md) · [简体中文](PRIVACY.zh-Hans.md) · **한국어**

이 문서는 현재 소스 코드에서 Revvy가 데이터를 어떻게 다루는지 설명합니다. 영어판과 차이가 있을 경우 [영어판](PRIVACY.md)을 기준으로 합니다.

## 요약

- Revvy는 개발자에게 데이터를 **전혀 전송하지 않습니다**. 분석, 광고, 충돌 보고 SDK도 포함하지 않습니다.
- GitHub 기능을 사용하지 않는 한 캡처한 내용은 Mac 밖으로 나가지 않습니다.
- GitHub 기능을 사용하면 선택한 GitHub 저장소로만 데이터를 전송합니다.

## Mac에 저장되는 데이터

| 데이터 | 위치 |
| --- | --- |
| 캡처한 이미지, 주석, 메모, 인식된 텍스트 | `~/Library/Application Support/Revvy/Captures` (샌드박스 빌드는 앱 컨테이너 내부) |
| 설정 (단축키, 눈금자 단위, 패널 상태, 선택한 저장소 등) | 앱 환경설정 (`UserDefaults`) |
| GitHub 액세스 토큰 | macOS 키체인 |

텍스트 인식(OCR)은 Apple Vision을 사용해 Mac에서 처리하며, 인식을 위해 이미지를 업로드하지 않습니다.

기록에서 캡처를 삭제하면 Mac에서만 삭제됩니다.

## 화면 기록 권한

Revvy는 스크린샷을 찍기 위해 화면 기록 권한을 요청합니다. 사용자가 캡처를 시작할 때(단축키, 플로팅 패널, 메뉴 또는 버튼)만 화면을 캡처합니다. 화면 눈금자는 화면을 캡처하지 않습니다.

## GitHub로 전송되는 데이터

Revvy는 다음 경우에만 GitHub(`github.com`, `api.github.com`)와 통신합니다.

| 시점 | 전송 내용 |
| --- | --- |
| GitHub 연결 | 앱의 공개 Client ID를 사용한 기기 흐름(device flow) 요청. 접근 승인은 브라우저에서 합니다. |
| 저장소, 레이블, 담당자 불러오기 | 사용자 토큰으로 인증된 요청 |
| **링크 생성 및 복사** / **Issue 생성** | 주석이 포함된 이미지를 선택한 저장소의 브랜치(기본값 `feedback-assets`)에 커밋합니다. Issue의 경우 제목, 코멘트, 레이블, 담당자, 환경 정보(앱 버전, macOS 버전, Mac 모델, 디스플레이 크기, 캡처 시각, GitHub 사용자 이름)도 전송합니다. |

- **공개** 저장소로 보낸 이미지는 공개됩니다. **비공개** 저장소에서는 GitHub의 접근 권한이 적용됩니다.
- Revvy는 Issue 텍스트의 일부 민감한 내용(토큰, JWT, `Authorization`/`Cookie` 헤더, 이메일 주소)을 가리지만, 이미지 속 민감한 정보는 **제거하지 않습니다**. 공유하기 전에 이미지와 텍스트를 확인하세요.
- 로컬 기록을 삭제해도 GitHub의 이미지, 커밋, Issue는 삭제되지 않습니다. GitHub에서 관리하세요.
- GitHub의 **Settings → Applications → Authorized OAuth Apps**에서 언제든지 Revvy의 접근 권한을 취소할 수 있고, Revvy에서는 사이드바의 계정 메뉴에서 연결을 해제할 수 있습니다.

GitHub의 데이터 처리는 [GitHub General Privacy Statement](https://docs.github.com/site-policy/privacy-policies/github-general-privacy-statement)를 따릅니다.

## 개발자 옵션 (직접 배포 빌드 전용)

Mac App Store 외부에서 배포되는 빌드에는, 사용자가 명시적으로 선택할 때만 로그인된 `gh` CLI의 토큰을 읽는 개발자 옵션이 있습니다. 샌드박스 빌드에는 이 옵션이 없습니다.

## 변경 사항

이 문서의 변경 내역은 이 저장소의 Git 기록에서 확인할 수 있습니다.

## 문의

개인정보 관련 질문은 이 저장소에 Issue로 남겨 주세요. 민감한 내용은 [SECURITY.md](SECURITY.md)의 안내를 따르세요.
