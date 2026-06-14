# 🏠 우리 가족 규칙 앱

Flutter + Firebase로 만든 가족 규칙 관리 및 점수 시스템

---

## 📱 주요 기능

| 기능 | 설명 |
|------|------|
| 📋 규칙 관리 | 부모가 가족 규칙 추가/삭제 |
| ⭐ 점수 요청 | 규칙 완료 시 점수 요청 제출 |
| ✅ 승인 시스템 | **본인 외 다른 가족이 승인해야 점수 반영** |
| 🔄 점수 초기화 | 초기화 요청 → 다른 가족 승인 → 초기화 |
| 🏆 가족 순위 | 실시간 점수 현황 및 순위 |

---

## 🚀 설치 가이드

### 1단계: Firebase 프로젝트 생성

1. [Firebase Console](https://console.firebase.google.com) 접속
2. **새 프로젝트 만들기** → 프로젝트 이름 입력 (예: `family-rules-app`)
3. Google Analytics는 선택 사항 (비활성화 가능)

### 2단계: Firebase 서비스 활성화

**Authentication 설정:**
1. Firebase Console → Authentication → 시작하기
2. 로그인 방법 → **이메일/비밀번호** 활성화

**Firestore 설정:**
1. Firebase Console → Firestore Database → 데이터베이스 만들기
2. **테스트 모드**로 시작 (나중에 보안 규칙 적용)
3. 위치: `asia-northeast3` (서울)

**Android 앱 등록:**
1. Firebase Console → 프로젝트 설정 → 앱 추가 → Android
2. 패키지 이름: `com.family.rules_app`
3. `google-services.json` 다운로드
4. 파일을 `android/app/` 폴더에 복사

### 3단계: FlutterFire CLI 설정

```bash
# FlutterFire CLI 설치
dart pub global activate flutterfire_cli

# Firebase 연결 (프로젝트 루트에서 실행)
flutterfire configure --project=YOUR_PROJECT_ID

# 자동으로 lib/firebase_options.dart 생성됨
```

### 4단계: 패키지 설치

```bash
flutter pub get
```

### 5단계: 초기 데이터 설정 (가족 계정 생성)

```bash
# Node.js 필요
cd family_rules_app
npm install firebase-admin

# Firebase Console → 프로젝트 설정 → 서비스 계정 → 새 비공개 키 생성
# 다운로드한 파일을 serviceAccountKey.json으로 저장 후:

node firebase_setup.js
```

**또는 Firebase Console에서 직접 생성:**
1. Authentication → 사용자 추가
2. Firestore → `members` 컬렉션에 문서 추가:
   ```json
   {
     "name": "아빠",
     "email": "dad@family.com",
     "role": "parent",
     "totalScore": 0
   }
   ```

### 6단계: Firestore 보안 규칙 적용

Firebase Console → Firestore → 규칙 탭에 `firestore.rules` 내용 붙여넣기

### 7단계: 빌드 및 설치

```bash
# 디버그 빌드 (개발 중 USB 연결 설치)
flutter run

# 릴리즈 APK 빌드 (직접 설치)
flutter build apk --release

# APK 위치: build/app/outputs/flutter-apk/app-release.apk
# 자녀 폰에 APK 전송 후 설치 (설정 → 알 수 없는 앱 허용 필요)
```

---

## 📁 프로젝트 구조

```
lib/
├── main.dart                  # 앱 진입점 + Firebase 초기화
├── firebase_options.dart      # FlutterFire 자동 생성 (7단계 후 생김)
├── models/
│   ├── rule.dart              # 규칙 모델
│   ├── score_request.dart     # 점수/초기화 요청 모델
│   └── family_member.dart     # 가족 구성원 모델
├── services/
│   └── firebase_service.dart  # Firebase 모든 작업 처리
├── providers/
│   └── auth_provider.dart     # 로그인 상태 관리
└── screens/
    ├── login_screen.dart      # 로그인 화면
    ├── home_screen.dart       # 메인 (하단 탭 네비게이션)
    ├── rules_screen.dart      # 규칙 목록 및 관리
    ├── score_screen.dart      # 점수 요청 화면
    ├── requests_screen.dart   # 승인/거절 화면
    └── family_score_screen.dart # 가족 점수 순위
```

---

## 🗄️ Firestore 데이터 구조

```
members/
  {uid}/
    name: "아빠"
    role: "parent" | "child"
    totalScore: 150
    email: "dad@family.com"

rules/
  {ruleId}/
    title: "숙제 완료하기"
    description: "학교 숙제를 스스로 완료했을 때"
    points: 20
    createdBy: "아빠"
    createdAt: timestamp
    isActive: true

requests/
  {requestId}/
    type: "scoreAdd" | "resetScore"
    status: "pending" | "approved" | "rejected"
    requestedBy: uid
    requestedByName: "자녀이름"
    ruleId: ruleId (점수 요청 시)
    ruleTitle: "숙제 완료하기"
    points: 20
    targetUserId: uid
    createdAt: timestamp
    approvedBy: "엄마"
    approvedAt: timestamp
```

---

## 🔑 로그인 계정 (firebase_setup.js로 생성 시)

| 이름 | 이메일 | 비밀번호 | 역할 |
|------|--------|----------|------|
| 아빠 | dad@family.com | family1234 | 부모 |
| 엄마 | mom@family.com | family1234 | 부모 |
| 자녀이름 | child@family.com | child1234 | 자녀 |

> ⚠️ **보안 주의:** 실제 사용 시 비밀번호를 변경하세요!

---

## 🎨 화면 구성

| 탭 | 대상 | 기능 |
|----|------|------|
| 📋 규칙 | 전체 | 규칙 목록 보기. 부모는 추가/삭제 가능 |
| ⭐ 점수요청 | 전체 | 규칙 완료 버튼으로 점수 요청 제출 |
| ✅ 승인 | 전체 | 대기 중인 요청 승인/거절 (본인 요청 제외) |
| 🏆 가족점수 | 전체 | 가족 점수 순위 + 부모는 초기화 요청 가능 |

---

## 🔄 점수/초기화 흐름

```
점수 흐름:
자녀가 "숙제 완료!" 버튼 클릭
    → 요청 생성 (pending)
    → 부모 앱에 대기 중 표시
    → 부모가 "승인" 클릭
    → 자녀 점수 +20점 반영

초기화 흐름:
부모A가 "자녀 점수 초기화 요청"
    → 요청 생성 (pending)
    → 부모B 또는 자녀가 "승인"
    → 해당 멤버 점수 0으로 초기화
```
