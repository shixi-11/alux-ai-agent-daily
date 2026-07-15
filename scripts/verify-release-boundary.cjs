#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');

const date = process.argv[2];
if (!/^\d{4}-\d{2}-\d{2}$/.test(date || '')) {
  console.error('usage: node scripts/verify-release-boundary.cjs YYYY-MM-DD');
  process.exit(64);
}

const root = path.resolve(__dirname, '..');
const compact = date.replace(/-/g, '');
const [year, month, day] = date.split('-');
const files = [
  `content/zh/${compact}_ALUX_AI智能体情报日报.html`,
  `content/en/${compact}.body.html`,
  'content/en/translation-manifest.json',
  'public/index.html',
  'public/en/index.html',
  'public/latest/index.html',
  'public/en/latest/index.html',
  `public/${year}/${month}/${day}/index.html`,
  `public/en/${year}/${month}/${day}/index.html`,
  'public/archive.json',
  'public/en/archive.json',
  'public/sitemap.xml',
];

const forbidden = [
  ['macOS local path', /\/Users\/[A-Za-z0-9._-]+\//g],
  ['Windows local path', /[A-Za-z]:\\Users\\[^\\\s<]+\\/g],
  ['private workspace path', /(?:\.openclaw|\.codex)[\\/]|workspace-[A-Za-z0-9_-]+_agent|outputs[\\/]alux-ai-agent-daily/gi],
  ['internal artifact', /research[_ -]?packet|send[_ -]?ledger|translation_review\.json|HEARTBEAT_OK|\.run-lock/gi],
  ['internal process narration', /工作日志|自言自语|质量门禁日志|工具输出|失败原因[：:]|网络未恢复/gi],
  ['private Telegram recipient', /Telegram\s*(?:target|chat(?:\s*id)?|recipient|私聊对象)[：:=\s]+\d{7,15}/gi],
  ['GitHub token', /(?:github_pat_|gh[pousr]_)[A-Za-z0-9_]{20,}/g],
  ['OpenAI-style secret', /\bsk-[A-Za-z0-9_-]{20,}\b/g],
  ['Google API key', /\bAIza[0-9A-Za-z_-]{30,}\b/g],
  ['AWS access key', /\bAKIA[0-9A-Z]{16}\b/g],
  ['Telegram bot token', /\b\d{8,12}:[A-Za-z0-9_-]{30,}\b/g],
  ['private key', /-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----/g],
];

const failures = [];
for (const relative of files) {
  const absolute = path.join(root, relative);
  if (!fs.existsSync(absolute) || !fs.statSync(absolute).isFile()) {
    failures.push(`${relative}: missing release file`);
    continue;
  }
  const text = fs.readFileSync(absolute, 'utf8');
  for (const [label, pattern] of forbidden) {
    pattern.lastIndex = 0;
    const match = pattern.exec(text);
    if (match) {
      failures.push(`${relative}: ${label}`);
    }
  }
}

if (failures.length) {
  console.error(JSON.stringify({ ok: false, date, failures }, null, 2));
  process.exit(1);
}

console.log(JSON.stringify({ ok: true, date, checkedFiles: files.length }, null, 2));
