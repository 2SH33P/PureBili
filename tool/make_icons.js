// 生成 PureBili 应用图标：node tool/make_icons.js（需要 sharp）
// 设计：iOS 26 Liquid Glass 风格——粉色渐变底 + 磨砂玻璃电视 + 白色播放键。
const sharp = require('sharp');
const fs = require('fs');
const path = require('path');
const out = path.join(__dirname, '..', 'assets', 'icon');
fs.mkdirSync(out, { recursive: true });

const defs = `
<defs>
  <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="#FFA6C4"/>
    <stop offset="0.5" stop-color="#FB7299"/>
    <stop offset="1" stop-color="#D9467A"/>
  </linearGradient>
  <radialGradient id="blobA" cx="0.2" cy="0.15" r="0.6">
    <stop offset="0" stop-color="#FFFFFF" stop-opacity="0.55"/>
    <stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/>
  </radialGradient>
  <radialGradient id="blobB" cx="0.9" cy="0.95" r="0.6">
    <stop offset="0" stop-color="#8E5BFF" stop-opacity="0.45"/>
    <stop offset="1" stop-color="#8E5BFF" stop-opacity="0"/>
  </radialGradient>
  <linearGradient id="glass" x1="0" y1="0" x2="0.6" y2="1">
    <stop offset="0" stop-color="#FFFFFF" stop-opacity="0.62"/>
    <stop offset="0.55" stop-color="#FFFFFF" stop-opacity="0.26"/>
    <stop offset="1" stop-color="#FFFFFF" stop-opacity="0.18"/>
  </linearGradient>
  <linearGradient id="rim" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="#FFFFFF" stop-opacity="1"/>
    <stop offset="0.5" stop-color="#FFFFFF" stop-opacity="0.35"/>
    <stop offset="1" stop-color="#FFFFFF" stop-opacity="0.8"/>
  </linearGradient>
  <filter id="shadow" x="-20%" y="-20%" width="140%" height="150%">
    <feGaussianBlur in="SourceAlpha" stdDeviation="22"/>
    <feOffset dy="26"/>
    <feComponentTransfer><feFuncA type="linear" slope="0.28"/></feComponentTransfer>
    <feMerge><feMergeNode/><feMergeNode in="SourceGraphic"/></feMerge>
  </filter>
</defs>`;

// 玻璃电视图形，设计坐标系 1024x1024，主体位于中心约 62% 区域内（满足 Android 自适应图标安全区）
const glyph = `
<g filter="url(#shadow)">
  <!-- 天线 -->
  <g stroke="#FFFFFF" stroke-width="30" stroke-linecap="round" opacity="0.95">
    <line x1="420" y1="300" x2="366" y2="236"/>
    <line x1="604" y1="300" x2="658" y2="236"/>
  </g>
  <!-- 玻璃屏幕 -->
  <rect x="232" y="300" width="560" height="420" rx="110" fill="url(#glass)"/>
  <rect x="232" y="300" width="560" height="420" rx="110" fill="none" stroke="url(#rim)" stroke-width="10"/>
  <!-- 顶部高光 -->
  <path d="M300 350 Q512 318 724 350" stroke="#FFFFFF" stroke-opacity="0.7" stroke-width="14" stroke-linecap="round" fill="none"/>
  <!-- 播放键（圆角三角形） -->
  <path d="M466 430 Q446 418 446 442 L446 578 Q446 602 466 590 L586 522 Q606 510 586 498 Z"
        fill="#FFFFFF" stroke="#FFFFFF" stroke-width="22" stroke-linejoin="round"/>
  <!-- 底座 -->
  <rect x="402" y="756" width="220" height="26" rx="13" fill="#FFFFFF" opacity="0.9"/>
</g>`;

const background = `
<rect width="1024" height="1024" fill="url(#bg)"/>
<rect width="1024" height="1024" fill="url(#blobA)"/>
<rect width="1024" height="1024" fill="url(#blobB)"/>`;

const svg = (body) => `<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">${defs}${body}</svg>`;

// 1) iOS / Android 旧版：满版方形（系统自行裁圆角），无透明
const full = svg(background + glyph);
// 2) macOS / Windows：Big Sur 规范 824px 圆角方块 + 投影，四周透明
const mac = svg(`
<g transform="translate(100 100) scale(0.8046875)">
  <rect x="40" y="40" width="944" height="944" rx="220" fill="#000" opacity="0.10" filter="url(#shadow)"/>
  <clipPath id="sq"><rect width="1024" height="1024" rx="230"/></clipPath>
  <g clip-path="url(#sq)">${background}${glyph}</g>
  <rect x="3" y="3" width="1018" height="1018" rx="228" fill="none" stroke="#FFFFFF" stroke-opacity="0.35" stroke-width="6"/>
</g>`);
// 3) Android 自适应图标前景：透明底，图形缩到安全区
const fg = svg(`<g transform="translate(512 512) scale(0.72) translate(-512 -512)">${glyph}</g>`);

(async () => {
  fs.writeFileSync(path.join(out, 'icon.svg'), full);
  await sharp(Buffer.from(full)).flatten({ background: '#FB7299' }).png().toFile(path.join(out, 'icon.png'));
  await sharp(Buffer.from(mac)).png().toFile(path.join(out, 'icon_desktop.png'));
  await sharp(Buffer.from(fg)).png().toFile(path.join(out, 'icon_foreground.png'));
  console.log('icons written to', out);
})();
