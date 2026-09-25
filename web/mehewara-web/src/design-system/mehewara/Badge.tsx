import type { HTMLAttributes } from 'react';
import './tokens.css';
const priorities = {"critical":"Critical","high":"High","medium":"Medium","low":"Low"} as const;
const statuses = {"identified":"Identified","assigned":"Assigned","in-progress":"In Progress","resolved":"Resolved"} as const;
export type Priority = keyof typeof priorities;
export type Status = keyof typeof statuses;
type BaseProps = Omit<HTMLAttributes<HTMLSpanElement>, 'children'>;
export function PriorityBadge({ value, className = '', ...props }: BaseProps & { value: Priority }) {
  return <span {...props} className={('mehewara-badge ' + className).trim()} data-kind="priority" data-value={value}><span className="mehewara-badge__dot" aria-hidden="true" />{priorities[value]}</span>;
}
export function StatusBadge({ value, className = '', ...props }: BaseProps & { value: Status }) {
  return <span {...props} className={('mehewara-badge ' + className).trim()} data-kind="status" data-value={value}><span className="mehewara-badge__dot" aria-hidden="true" />{statuses[value]}</span>;
}
