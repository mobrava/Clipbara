// Copy for the official site. Templates live in build-site.mjs.
// Keep every claim in line with README.md and docs/privacy.html.
export const repo = 'https://github.com/mobrava/Clipbara';
export const store = 'https://apps.apple.com/app/apple-store/id6803537696?pt=129317403&ct=official_website&mt=8';
export const release = `${repo}/releases/latest`;
const storeHref = store.replaceAll('&', '&amp;');
const brew = '<code>brew install --cask mobrava/tap/clipbara</code>';

export const content = {
 en: {
  title: 'Clipbara | Clipboard Manager for Mac & iPhone',
  description: 'Find what you copied, keep your favorites in Pinboards, and paste clips in order. Free and open-source on Mac. Optional iPhone sync with the App Store edition.',
  features: 'Features', privacy: 'Privacy', download: 'Download', help: 'FAQ', updates: 'Updates', get: 'Download', skip: 'Skip to content', menu: 'Open navigation',

  hero: 'Everything you copied,<br>one shortcut away',
  sub: 'A clipboard manager for Mac.<br>Press <span class="nowrap"><kbd>⇧</kbd><kbd>⌘</kbd><kbd>V</kbd></span> and your history slides up from the bottom of the screen.',
  cta: 'Download', secondary: 'View on GitHub',
  note: 'Free and open source on Mac · macOS 14 or later · iPhone sync in the App Store edition',
  deviceAlt: 'Clipbara on a Mac: the history panel at the bottom of the screen and a Quick Look preview above it',
  phoneAlt: 'Clipbara on iPhone showing example clips',

  featureHeading: 'History, search, Pinboards, Quick Look',
  slides: [
   ['Every copy is kept', 'Text, images, links, files, and colors go into the history. Click a card once and it is back on your clipboard.', 'panel-history', 'The Clipbara history panel with example image, code, link, and color clips'],
   ['Just start typing', 'Open the panel and type. Search by content or title, then narrow it down by type or date.', 'panel-search-dark', 'A search for invoice in Clipbara, with the matching text highlighted'],
   ['Pinboards for what you reuse', 'Group replies, snippets, and brand colors into tabs. Jump between them with <span class="nowrap"><kbd>⌘</kbd><kbd>1</kbd></span> to <span class="nowrap"><kbd>⌘</kbd><kbd>9</kbd></span>.', 'panel-pinboards', 'Clipbara Pinboard tabs with example snippets and colors'],
   ['Press Space for a closer look', 'Check a clip before you paste it. Text clips can be edited in place with <span class="nowrap"><kbd>⌘</kbd><kbd>E</kbd>.</span>', 'quicklook-popover', 'An image clip opened in Clipbara Quick Look']
  ],
  carousel: 'Clipbara features', previous: 'Previous feature', next: 'Next feature', slide: 'Show feature',

  queueHeading: 'Copy several,<br>paste them in order',
  queueText: 'Copy the name, the email, and the phone number first. Each <span class="nowrap"><kbd>⌘</kbd><kbd>V</kbd></span> then pastes the next one, so you stop switching back and forth.',
  queueNote: 'Clip Queue needs no extra permission.', queueLink: 'How to use it',
  queueAlt: 'Clip Queue with three example items waiting to be pasted',

  syncHeading: 'The same history<br>on your iPhone',
  syncRows: [
   ['Sync', 'Turn on iCloud Sync on both devices. Clips, titles, and Pinboards go both ways through your own iCloud.'],
   ['Keyboard', 'Add the Clipbara keyboard, switch to it with the globe key, and tap a clip to insert it in any app.'],
   ['Saving on iPhone', 'iOS does not let apps read the clipboard in the background. A clip is saved when you tap Paste in Clipbara or share to it from another app.']
  ],
  syncLink: 'Get it on the App Store', syncNote: 'App Store edition only · iOS 26 or later',
  syncAlt: 'The Clipbara keyboard on iPhone, inserting a saved reply into a message',

  privacyHeading: 'Your history stays on your devices',
  facts: [
   ['No server', 'There is no developer server holding your clips. Optional sync uses your private iCloud database.'],
   ['No account', 'Nothing to sign up for and nothing to log in to.'],
   ['No analytics', 'No telemetry and no usage tracking.']
  ],
  privacyMore: 'Apps such as password managers can be excluded from the history, and the code is open to read.',
  privacyLink: 'Privacy policy', sourceLink: 'Source code',

  downloadHeading: 'Download',
  downloadText: 'Both editions are built from the same repository. Run only one of them on a Mac.',
  editions: [
   {name: 'Direct download', price: 'Free', sub: 'DMG or Homebrew. The open-source build.', button: 'Download the DMG',
    rows: [['iPhone app and iCloud sync', 'Not included'], ['Paste into the active app', 'Included, with Accessibility permission'], ['Updates', 'Automatic, inside the app'], ['Requires', 'macOS 14 or later · Apple silicon and Intel']]},
   {name: 'App Store', price: 'Free for 7 days', sub: 'Then one purchase for Mac and iPhone. No subscription.', button: 'Get it on the App Store',
    rows: [['iPhone app and iCloud sync', 'Included'], ['Paste into the active app', 'Not included'], ['Updates', 'Through the App Store'], ['Requires', 'macOS 14 or later · iOS 26 or later']]}
  ],
  copy: 'Copy Homebrew command', copied: 'Copied', copyFail: 'Select and copy the command.',
  signed: 'The DMG is signed with <strong>Developer ID Application: MinSang Kim (5DH57J8HLC)</strong> and notarized by Apple.',
  safetyLink: 'Official download channels',

  faqHeading: 'Questions',
  faqs: [
   ['Is Clipbara free?', 'The direct-download and Homebrew editions for Mac are free and open source. The App Store edition has a 7-day trial, followed by a one-time purchase that unlocks both Mac and iPhone. There is no subscription.'],
   ['Which Mac edition should I choose?', 'Choose the App Store edition if you want iCloud sync and the iPhone companion. Choose the free DMG or Homebrew edition for a local Mac clipboard, including optional direct paste. The editions keep separate histories. You can export and import your history in Settings → General → Backup.'],
   ['Does selecting a clip paste it into my app?', 'By default, selecting a clip puts it back on the clipboard and closes the panel. Press ⌘V in the app you were using. The DMG edition can do that last step for you when Paste into the Active App is enabled in Settings → Pasting and Accessibility permission is granted. The App Store edition does not include direct paste.'],
   ['Does iPhone record everything I copy?', 'No. iOS does not allow background clipboard monitoring. Add a clip with the Paste button, share it to Clipbara, or turn on saving when the app opens. With iCloud sync enabled, supported clips from your Mac also appear on your iPhone. Copied files do not sync.'],
   ['Where is my clipboard history stored?', 'Your Mac stores it locally. Optional iCloud sync in the App Store edition uses your private iCloud database. Clipbara does not run a server for your clips or collect analytics. You can exclude apps, set retention limits, and delete history in Settings.'],
   ['Where can I get help or report a problem?', 'Open an issue in the official mobrava/Clipbara GitHub repository. Include your macOS or iOS version, the Clipbara version, and whether you use the App Store or DMG edition. Never include passwords or private clipboard contents.']
  ],

  product: 'Product', resources: 'Resources', source: 'Source code', safety: 'Official downloads',
  footerBlurb: 'A clipboard manager for Mac,<br>with an iPhone app.',
  copyright: '© 2026 Clipbara · Open source under GPL-3.0', languageLabel: 'Language',

  securityTitle: 'Official Clipbara downloads',
  securityLead: 'Get Clipbara from the project’s own distribution channels.',
  securitySections: [
   ['Where to download', `<ul><li><a href="${storeHref}">Apple App Store</a>: app ID 6803537696, developed by MinSang Kim.</li><li><a href="${release}">GitHub Releases</a>: mobrava/Clipbara.</li><li>Homebrew: ${brew}.</li></ul>`],
   ['Check the source, not just the logo', '<p>A copied logo or an ad above the search results does not make a site official. Follow the links from this page, the official GitHub repository, or the App Store listing. A legitimate third-party review or open-source mirror is not necessarily an impersonation.</p>'],
   ['Signed Mac downloads', '<p>The official DMG edition is signed with <strong>Developer ID Application: MinSang Kim</strong> (Team ID <code>5DH57J8HLC</code>) and notarized by Apple. We do not ask you to disable macOS security protections or run an activation script. A signature from a different developer is not proof that a file is ours.</p>'],
   ['Found a suspicious site?', `<p>Keep the full URL and a screenshot. Do not run its installer or share account details. <a href="${repo}/issues">Report it to the Clipbara project on GitHub</a>. Reports are reviewed before any public warning is made.</p>`]
  ]
 },

 ko: {
  title: 'Clipbara | Mac과 iPhone을 위한 클립보드 매니저',
  description: '복사 기록을 검색하고, 자주 쓰는 내용은 핀보드에 모아두세요. Mac 무료 오픈소스 앱. App Store판에서 iPhone과 iCloud 동기화도 사용할 수 있어요.',
  features: '기능', privacy: '개인정보', download: '다운로드', help: '자주 묻는 질문', updates: '업데이트', get: '다운로드', skip: '본문으로 바로가기', menu: '메뉴 열기',

  hero: '복사한 모든 것을<br>단축키 하나로 다시',
  sub: 'Mac용 클립보드 매니저예요.<br><span class="nowrap"><kbd>⇧</kbd><kbd>⌘</kbd><kbd>V</kbd>를</span> 누르면 복사 기록이 화면 아래에서 올라와요.',
  cta: '다운로드', secondary: 'GitHub에서 보기',
  note: 'Mac은 무료 오픈소스 · macOS 14 이상 · iPhone 동기화는 App Store판',
  deviceAlt: 'Mac 화면 아래에 열린 Clipbara 기록 패널과 그 위의 Quick Look 미리보기',
  phoneAlt: '예시 기록이 열린 iPhone용 Clipbara',

  featureHeading: '기록, 검색, 핀보드, 미리보기',
  slides: [
   ['복사한 건 전부 남아요', '텍스트, 이미지, 링크, 파일, 색상까지 기록에 쌓여요. 카드를 한 번 클릭하면 다시 클립보드로 돌아와요.', 'panel-history', '이미지, 코드, 링크, 색상 예시가 담긴 Clipbara 기록 패널'],
   ['열고 바로 입력하면 검색', '패널을 연 채로 입력하세요. 내용이나 제목으로 찾고, 유형과 날짜로 좁힐 수 있어요.', 'panel-search', '견적서를 검색해 일치하는 단어가 강조된 Clipbara 패널'],
   ['자주 쓰는 건 핀보드에', '답장 문구, 코드 조각, 브랜드 색처럼 반복해서 쓰는 것들을 탭으로 묶어 두세요. <span class="nowrap"><kbd>⌘</kbd><kbd>1</kbd>부터</span> <span class="nowrap"><kbd>⌘</kbd><kbd>9</kbd>로</span> 바로 이동해요.', 'panel-pinboards', '예시 문구와 색상이 모여 있는 Clipbara 핀보드 탭'],
   ['Space로 크게 보기', '붙여넣기 전에 내용을 확인하세요. 텍스트는 <span class="nowrap"><kbd>⌘</kbd><kbd>E</kbd>로</span> 그 자리에서 고칠 수 있어요.', 'quicklook-popover', 'Clipbara Quick Look으로 크게 연 이미지 클립']
  ],
  carousel: 'Clipbara 기능', previous: '이전 기능', next: '다음 기능', slide: '기능 보기',

  queueHeading: '여러 개 복사하고,<br>순서대로 붙여넣기',
  queueText: '이름, 이메일, 전화번호를 먼저 복사해 두세요. <span class="nowrap"><kbd>⌘</kbd><kbd>V</kbd>를</span> 누를 때마다 다음 항목이 붙여넣어져서, 앱 사이를 오갈 필요가 없어요.',
  queueNote: '클립 대기열은 별도 권한이 필요 없어요.', queueLink: '사용법 보기',
  queueAlt: '붙여넣을 항목 세 개가 담긴 클립 대기열',

  syncHeading: 'iPhone에서도<br>같은 기록',
  syncRows: [
   ['동기화', '두 기기에서 iCloud 동기화를 켜면 기록, 제목, 핀보드가 양쪽으로 오가요. 내 iCloud만 거쳐요.'],
   ['키보드', 'Clipbara 키보드를 추가하고 지구본 키로 전환하면, 어느 앱에서든 클립을 탭해서 넣을 수 있어요.'],
   ['iPhone에서 저장', 'iOS는 백그라운드에서 클립보드를 읽지 못하게 해요. Clipbara에서 붙여넣기 버튼을 누르거나 다른 앱에서 공유하면 저장돼요.']
  ],
  syncLink: 'App Store에서 받기', syncNote: 'App Store판 전용 · iOS 26 이상',
  syncAlt: 'iPhone의 Clipbara 키보드로 저장해 둔 답장을 메시지에 넣는 화면',

  privacyHeading: '기록은 내 기기에 남아요',
  facts: [
   ['서버 없음', '클립을 보관하는 개발자 서버가 없어요. 동기화를 켜도 내 개인 iCloud 데이터베이스만 써요.'],
   ['계정 없음', '가입도 로그인도 없어요.'],
   ['분석 없음', '사용 통계나 추적 도구를 넣지 않았어요.']
  ],
  privacyMore: '비밀번호 관리자 같은 앱은 기록에서 제외할 수 있고, 코드는 누구나 볼 수 있어요.',
  privacyLink: '개인정보처리방침', sourceLink: '소스 코드',

  downloadHeading: '다운로드',
  downloadText: '두 버전 모두 같은 저장소에서 빌드해요. Mac에서는 하나만 실행하세요.',
  editions: [
   {name: '직접 다운로드', price: '무료', sub: 'DMG 또는 Homebrew. 오픈소스 빌드예요.', button: 'DMG 다운로드',
    rows: [['iPhone 앱, iCloud 동기화', '없음'], ['활성 앱에 바로 붙여넣기', '있음 (손쉬운 사용 권한 필요)'], ['업데이트', '앱 안에서 자동 업데이트'], ['요구 사양', 'macOS 14 이상 · Apple silicon, Intel']]},
   {name: 'App Store', price: '7일 무료 체험', sub: '이후 한 번 구매로 Mac과 iPhone 모두. 구독은 없어요.', button: 'App Store에서 받기',
    rows: [['iPhone 앱, iCloud 동기화', '있음'], ['활성 앱에 바로 붙여넣기', '없음'], ['업데이트', 'App Store'], ['요구 사양', 'macOS 14 이상 · iOS 26 이상']]}
  ],
  copy: 'Homebrew 명령어 복사', copied: '복사했어요', copyFail: '명령어를 선택해서 복사해 주세요.',
  signed: 'DMG는 <strong>Developer ID Application: MinSang Kim (5DH57J8HLC)</strong>으로 서명하고 Apple 공증을 받았어요.',
  safetyLink: '공식 다운로드 경로',

  faqHeading: '자주 묻는 질문',
  faqs: [
   ['Clipbara는 무료인가요?', 'Mac용 DMG와 Homebrew판은 무료 오픈소스예요. App Store판은 7일 무료 체험 후 한 번 구매하면 Mac과 iPhone에서 사용할 수 있어요. 구독은 없어요.'],
   ['어떤 Mac 버전을 받으면 되나요?', 'iCloud 동기화와 iPhone 앱이 필요하면 App Store판을, Mac에서 로컬 기록과 선택적인 바로 붙여넣기를 쓰려면 무료 DMG나 Homebrew판을 받으세요. 두 버전의 기록은 따로 저장돼요. 설정 → 일반 → 백업에서 내보내기와 가져오기로 옮길 수 있어요.'],
   ['기록을 누르면 바로 붙여넣어지나요?', '기본 동작은 선택한 내용을 클립보드에 넣고 패널을 닫는 거예요. 사용하던 앱에서 ⌘V를 누르면 붙여넣어져요. DMG판에서는 설정 → 붙여넣기에서 활성 앱에 붙여넣기를 켜고 손쉬운 사용 권한을 주면 이 단계도 자동으로 해줘요. App Store판에는 바로 붙여넣기가 없어요.'],
   ['iPhone에서도 복사한 것을 모두 자동으로 저장하나요?', '아니요. iOS에서는 백그라운드 클립보드 감시가 허용되지 않아요. 붙여넣기 버튼, 다른 앱의 공유 메뉴, 앱을 열 때 저장하는 옵션으로 내용을 추가해요. iCloud 동기화를 켜면 Mac에서 복사한 지원 항목도 볼 수 있어요. 복사한 파일은 동기화되지 않아요.'],
   ['복사 기록은 어디에 저장되나요?', 'Mac에 로컬로 저장돼요. App Store판에서 동기화를 켜면 개인 iCloud 데이터베이스를 사용해요. Clipbara는 클립을 보관하는 개발자 서버나 분석 도구를 사용하지 않아요. 설정에서 앱 제외, 보관 기간, 기록 삭제를 관리할 수 있어요.'],
   ['문제가 생기면 어디로 문의하나요?', '공식 GitHub 저장소 mobrava/Clipbara에 이슈를 남겨 주세요. macOS나 iOS 버전, Clipbara 버전, App Store판인지 DMG판인지를 알려주시면 확인에 도움이 돼요. 비밀번호나 개인적인 복사 내용은 올리지 마세요.']
  ],

  product: '제품', resources: '도움말', source: '소스 코드', safety: '공식 다운로드',
  footerBlurb: 'Mac용 클립보드 매니저,<br>iPhone 앱 포함.',
  copyright: '© 2026 Clipbara · GPL-3.0 오픈소스', languageLabel: '언어',

  securityTitle: 'Clipbara 공식 다운로드',
  securityLead: '프로젝트가 직접 배포하는 경로에서 받아 주세요.',
  securitySections: [
   ['공식 배포 경로', `<ul><li><a href="${storeHref}">Apple App Store</a>: 앱 ID 6803537696, 개발자 MinSang Kim.</li><li><a href="${release}">GitHub Releases</a>: mobrava/Clipbara.</li><li>Homebrew: ${brew}.</li></ul>`],
   ['로고보다 주소를 확인해 주세요', '<p>같은 로고를 쓰거나 검색 광고 맨 위에 있다고 공식 사이트인 것은 아니에요. 이 페이지, 공식 GitHub 저장소, App Store 페이지의 링크를 따라가세요. 정상적인 소개 글이나 오픈소스 재배포 사이트가 모두 사칭인 것은 아니에요.</p>'],
   ['Mac 설치 파일의 서명', '<p>공식 DMG판은 <strong>Developer ID Application: MinSang Kim</strong>(Team ID <code>5DH57J8HLC</code>)으로 서명하고 Apple 공증을 받아 배포해요. macOS 보안 기능을 끄거나 활성화 스크립트를 실행하라고 요구하지 않아요. 다른 개발자의 서명이 있다는 것만으로 공식 파일이라고 볼 수 없어요.</p>'],
   ['의심스러운 사이트를 발견했다면', `<p>전체 URL과 화면을 남겨 주세요. 설치 파일은 실행하지 말고 계정 정보도 입력하지 마세요. <a href="${repo}/issues">Clipbara 공식 GitHub에 제보</a>해 주시면 사실을 확인한 뒤 대응할게요.</p>`]
  ]
 }
};
