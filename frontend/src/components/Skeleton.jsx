export default function Skeleton({ variant = "line", count = 1, style }) {
  const cls =
    variant === "card"
      ? "skeleton-card"
      : variant === "ring"
      ? "skeleton-ring"
      : "skeleton skeleton-line";
  if (count <= 1) {
    return <div className={cls} style={style} aria-hidden="true" />;
  }
  return (
    <>
      {Array.from({ length: count }).map((_, i) => (
        <div key={i} className={cls} style={style} aria-hidden="true" />
      ))}
    </>
  );
}

export function DashboardSkeleton() {
  return (
    <div aria-busy="true" aria-label="Yükleniyor">
      <div className="page-header">
        <div style={{ flex: 1 }}>
          <Skeleton style={{ width: 180, height: 28 }} />
          <Skeleton style={{ width: 260, height: 14, marginTop: 8 }} />
        </div>
      </div>
      <div className="stats-grid">
        {Array.from({ length: 4 }).map((_, i) => (
          <Skeleton key={i} variant="card" style={{ height: 96 }} />
        ))}
      </div>
      <div className="section">
        <div className="section-header">
          <Skeleton style={{ width: 140, height: 20 }} />
        </div>
        <div className="area-cards-grid">
          {Array.from({ length: 6 }).map((_, i) => (
            <Skeleton key={i} variant="card" style={{ height: 160 }} />
          ))}
        </div>
      </div>
    </div>
  );
}

export function AnalyticsSkeleton() {
  return (
    <div aria-busy="true" aria-label="Yükleniyor">
      <Skeleton variant="card" style={{ height: 320 }} />
      <div style={{ height: 16 }} />
      <Skeleton variant="card" style={{ height: 240 }} />
    </div>
  );
}
