// firebase_setup.js
// Firebase Console > Firestore에서 직접 실행하거나
// Node.js 스크립트로 초기 데이터 설정
//
// 사용법: node firebase_setup.js
// 필요: npm install firebase-admin

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json'); // Firebase에서 다운로드

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const auth = admin.auth();
const db = admin.firestore();

async function setup() {
  console.log('🚀 가족 앱 초기 설정 시작...');

  // ── 1. 가족 계정 생성 ────────────────────────────
  const familyMembers = [
    { name: '아빠', email: 'dad@family.com', password: 'family1234', role: 'parent' },
    { name: '엄마', email: 'mom@family.com', password: 'family1234', role: 'parent' },
    { name: '자녀이름', email: 'child@family.com', password: 'child1234', role: 'child' },
  ];

  for (const member of familyMembers) {
    try {
      // Firebase Auth 계정 생성
      const userRecord = await auth.createUser({
        email: member.email,
        password: member.password,
        displayName: member.name,
      });

      // Firestore 멤버 문서 생성
      await db.collection('members').doc(userRecord.uid).set({
        name: member.name,
        email: member.email,
        role: member.role,
        totalScore: 0,
      });

      console.log(`✅ ${member.name} (${member.email}) 생성 완료 - UID: ${userRecord.uid}`);
    } catch (e) {
      if (e.code === 'auth/email-already-exists') {
        console.log(`⚠️  ${member.email} 이미 존재함 - 건너뜀`);
      } else {
        console.error(`❌ ${member.name} 생성 실패:`, e.message);
      }
    }
  }

  // ── 2. 샘플 규칙 추가 ────────────────────────────
  const sampleRules = [
    { title: '숙제 완료하기', description: '학교 숙제를 스스로 완료했을 때', points: 20 },
    { title: '방 청소하기', description: '자기 방을 깨끗하게 정리했을 때', points: 15 },
    { title: '일찍 일어나기', description: '알람 없이 스스로 기상했을 때', points: 10 },
    { title: '식사 준비 돕기', description: '부모님 식사 준비를 도왔을 때', points: 15 },
    { title: '독서 30분', description: '책을 30분 이상 읽었을 때', points: 10 },
  ];

  for (const rule of sampleRules) {
    await db.collection('rules').add({
      ...rule,
      createdBy: '시스템',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      isActive: true,
    });
    console.log(`📋 규칙 추가: ${rule.title}`);
  }

  console.log('\n🎉 설정 완료!');
  console.log('\n📱 앱 로그인 정보:');
  familyMembers.forEach(m => {
    console.log(`  ${m.name}: ${m.email} / ${m.password}`);
  });
}

setup().catch(console.error);
