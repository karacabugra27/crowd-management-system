/**
 * Map component: returns occupancy status color
 */
export function statusColor(status) {
  const map = {
    empty: "#22c55e",
    low: "#84cc16",
    medium: "#eab308",
    high: "#f97316",
    full: "#ef4444",
  };
  return map[status] || "#6b7280";
}

export function statusLabel(status) {
  const map = {
    empty: "Boş",
    low: "Düşük",
    medium: "Orta",
    high: "Yoğun",
    full: "Dolu",
  };
  return map[status] || status;
}

export function statusBg(status) {
  const map = {
    empty: "rgba(34,197,94,0.15)",
    low: "rgba(132,204,22,0.15)",
    medium: "rgba(234,179,8,0.15)",
    high: "rgba(249,115,22,0.15)",
    full: "rgba(239,68,68,0.15)",
  };
  return map[status] || "rgba(107,114,128,0.15)";
}

export function formatPercent(val) {
  return `${Math.round(val)}%`;
}

export function formatDate(dateStr) {
  if (!dateStr) return "—";
  return new Date(dateStr).toLocaleString("tr-TR", {
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

export function formatTime(dateStr) {
  if (!dateStr) return "—";
  return new Date(dateStr).toLocaleString("tr-TR", {
    hour: "2-digit",
    minute: "2-digit",
  });
}
