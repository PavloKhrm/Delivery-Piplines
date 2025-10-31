export function normId(s) {
  const x = String(s || "").trim().toLowerCase().replace(/[^a-z0-9-]/g, "-").replace(/^-+|[-]+$/g, "");
  return x ? x.slice(0, 63) : `c-${Date.now()}`;
}
