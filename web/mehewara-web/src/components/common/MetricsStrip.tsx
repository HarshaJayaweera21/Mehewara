import React from 'react';
import './MetricsStrip.css';

export interface MetricItem {
  id?: string;
  label: string;
  value: string | number;
  descriptor?: string;
  hasPip?: boolean;
  pipColor?: 'mint' | 'amber' | 'coral' | 'blue';
  onClick?: () => void;
}

export interface MetricsStripProps {
  items: MetricItem[];
  columns?: number;
  className?: string;
  ariaLabel?: string;
}

export const MetricsStrip: React.FC<MetricsStripProps> = ({
  items,
  columns,
  className = '',
  ariaLabel = 'Operational Metrics Summary',
}) => {
  const colCount = columns || items.length;

  return (
    <section
      className={`mw-metrics-strip ${className}`.trim()}
      style={{ gridTemplateColumns: `repeat(${colCount}, 1fr)` }}
      aria-label={ariaLabel}
    >
      {items.map((item, index) => (
        <div
          key={item.id || item.label || index}
          className={`mw-metric-cell ${item.onClick ? 'clickable' : ''}`}
          onClick={item.onClick}
          role={item.onClick ? 'button' : undefined}
          tabIndex={item.onClick ? 0 : undefined}
        >
          <div className="mw-metric-label-row">
            <span className="mw-metric-label">{item.label}</span>
            {item.hasPip && (
              <span className={`mw-metric-pip ${item.pipColor ? `pip-${item.pipColor}` : ''}`} />
            )}
          </div>
          <span className="mw-metric-value">{item.value}</span>
          {item.descriptor && <span className="mw-metric-descriptor">{item.descriptor}</span>}
        </div>
      ))}
    </section>
  );
};
