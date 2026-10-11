// mulberry32: small, fast, seedable PRNG. Not cryptographic - for fixtures only.

//`createRng` returns a **closure** — a function that remembers its own private state `a`.
// Each call mixes the state with bit operations and returns a number in `[0, 1)`. The same seed always produces the same sequence.
// `>>> 0` converts to an unsigned 32-bit integer; `Math.imul` does 32-bit multiplication without overflowing JavaScript's 53-bit number precision.
export function createRng(seed) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), a | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
