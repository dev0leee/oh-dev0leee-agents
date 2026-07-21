#!/usr/bin/env node
/**
 * 최소 statusline — `ctx: NN%  msg: NN%` 만 출력.
 *   ctx = 전체 컨텍스트 사용률 (context_window.used_percentage)
 *   msg = 대화 메시지 사용률 ≈ (전체 입력토큰 − 고정 오버헤드) / 컨텍스트 크기
 *         (/context 의 "Messages" 값 근사. 오버헤드는 OMC_MSG_OVERHEAD_TOKENS 로 조정)
 * 의존성 없음. Claude Code 가 statusline JSON 을 stdin 으로 넘겨줌.
 */
import { readFileSync } from "node:fs";

const OVERHEAD = Number(process.env.OMC_MSG_OVERHEAD_TOKENS ?? 25000); // 시스템+툴+스킬 근사

function readStdin() {
  try { return JSON.parse(readFileSync(0, "utf8")); } catch { return {}; }
}

const clampPct = (n) => Math.max(0, Math.min(100, Math.round(n)));

function main() {
  const s = readStdin();
  const cw = s.context_window ?? s ?? {};
  const size = Number(cw.context_window_size) || 0;

  const cu = cw.current_usage ?? {};
  const totalTokens =
    (Number(cu.input_tokens) || 0) +
    (Number(cu.cache_creation_input_tokens) || 0) +
    (Number(cu.cache_read_input_tokens) || 0);
  const totalInput = Number(cw.total_input_tokens) || totalTokens;

  // ctx: native 우선, 없으면 토큰으로 계산
  let ctx;
  if (typeof cw.used_percentage === "number" && !Number.isNaN(cw.used_percentage)) {
    ctx = clampPct(cw.used_percentage);
  } else if (size > 0) {
    ctx = clampPct((totalInput / size) * 100);
  } else {
    ctx = 0;
  }

  // msg: 전체 입력토큰에서 고정 오버헤드 제외
  let msg = 0;
  if (size > 0) {
    msg = clampPct(((Math.max(0, totalInput - OVERHEAD)) / size) * 100);
  }

  const pad = (n) => String(n).padStart(2, " ");
  process.stdout.write(`ctx: ${pad(ctx)}%  msg: ${pad(msg)}%`);
}

main();
