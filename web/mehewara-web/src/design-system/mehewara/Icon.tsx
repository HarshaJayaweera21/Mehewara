import { useId } from 'react';
import type { SVGProps } from 'react';
import './tokens.css';

const shapes = {
  'drainage': <><path d="M12 3C10 6 6 10 6 13a6 6 0 0 0 12 0c0-3-4-7-6-10Z M9 13a3 3 0 0 0 3 3 M4 21h16"/></>,
  'road': <><path d="M8 3 4 21M16 3l4 18M12 4v3M12 11v3M12 18v3"/></>,
  'waste': <><path d="M4 6h16M9 6V3h6v3M6 6l1 15h10l1-15M10 10v7M14 10v7"/></>,
  'electrical': <><path d="m13 2-9 12h7l-1 8 10-13h-7l1-7Z"/></>,
  'environment': <><path d="M20 3C8 2 3 7 5 14c2 7 12 6 14 0 1-3 1-7 1-11ZM4 21 15 10"/></>,
  'dashboard': <><path d="m3 10 9-7 9 7v10a1 1 0 0 1-1 1h-5v-7H9v7H4a1 1 0 0 1-1-1V10Z"/></>,
  'reports': <><path d="M14 3H6a1 1 0 0 0-1 1v16a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1V8l-5-5ZM14 3v5h5M8 16v2M12 13v5M16 11v7"/></>,
  'problems': <><path d="m3 8 9-5 9 5-9 5-9-5ZM3 12l9 5 9-5M3 16l9 5 9-5"/></>,
  'work-orders': <><path d="M9 5H6a1 1 0 0 0-1 1v14a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1V6a1 1 0 0 0-1-1h-3M9 3h6v4H9V3ZM8 14l3 3 5-6"/></>,
  'map': <><path d="m3 5 6-2 6 2 6-2v16l-6 2-6-2-6 2V5ZM9 3v16M15 5v16"/></>,
  'analytics': <><path d="M3 3v18h18M7 17v-6M12 17V6M17 17v-8"/></>,
  'users': <><circle cx="9" cy="7" r="3"/><path d="M3 21v-2a6 6 0 0 1 12 0v2H3ZM16 4a3 3 0 0 1 0 6M18 14a5 5 0 0 1 3 5v2h-3"/></>,
  'settings': <><path d="m10 3-.5 2.2-2 .9-2-.7-2 3.4L5 10.4v2.2l-1.5 1.6 2 3.4 2-.7 2 .9L10 20h4l.5-2.2 2-.9 2 .7 2-3.4-1.5-1.6v-2.2L20.5 8l-2-3.4-2 .7-2-.9L14 3h-4Z"/><circle cx="12" cy="11.5" r="3"/></>,
  'search': <><circle cx="10.5" cy="10.5" r="7.5"/><path d="m16 16 5 5"/></>,
  'filter': <><path d="M3 6h5M12 6h9M3 12h10M17 12h4M3 18h3M10 18h11"/><circle cx="10" cy="6" r="2"/><circle cx="15" cy="12" r="2"/><circle cx="8" cy="18" r="2"/></>,
  'location': <><path d="M19 10c0 5-7 11-7 11S5 15 5 10a7 7 0 1 1 14 0Z"/><circle cx="12" cy="10" r="2.5"/></>,
  'calendar': <><rect x="3" y="5" width="18" height="16" rx="2"/><path d="M7 3v4M17 3v4M3 10h18M7 14h2M13 14h2M7 17h2"/></>,
  'document': <><path d="M14 3H6a1 1 0 0 0-1 1v16a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1V8l-5-5ZM14 3v5h5M9 12h6M9 16h6"/></>,
  'arrow-right': <><path d="M4 12h16M13 5l7 7-7 7"/></>,
  'arrow-left': <><path d="M20 12H4M11 5l-7 7 7 7"/></>,
  'chevron-down': <><path d="m5 9 7 7 7-7"/></>,
  'bell': <><path d="M18 9a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9ZM10 21h4M12 3V2"/></>,
  'user': <><circle cx="12" cy="7" r="4"/><path d="M4 21v-2a8 6 0 0 1 16 0v2H4Z"/></>,
  'refresh': <><path d="M20 4v5h-5M4 20v-5h5M4.5 9a8 8 0 0 1 13-4l2.5 4M4 15l2.5 4a8 8 0 0 0 13-4"/></>,
  'warning': <><path d="M10.3 4a2 2 0 0 1 3.4 0l8 14a2 2 0 0 1-1.7 3H4a2 2 0 0 1-1.7-3l8-14ZM12 9v5M12 17v.1"/></>,
  'info': <><circle cx="12" cy="12" r="9"/><path d="M12 11v6M12 7v.1"/></>,
  'close': <><path d="m6 6 12 12M18 6 6 18"/></>,
  'grid': <><rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><rect x="14" y="14" width="7" height="7" rx="1"/></>,
  'list': <><path d="M8 5h13M8 12h13M8 19h13M3 5h.1M3 12h.1M3 19h.1"/></>,
};
export type IconName = keyof typeof shapes;
export interface IconProps extends Omit<SVGProps<SVGSVGElement>, 'name' | 'children'> { name: IconName; size?: 16 | 20 | 24; title?: string; }
/** Decorative by default. Supply title for a standalone meaningful icon. */
export function Icon({ name, size = 24, title, color = 'var(--mehewara-forest, #123C32)', className = '', ...props }: IconProps) {
  const id = useId();
  return <svg {...props} width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" color={color} strokeWidth={1.75} strokeLinecap="round" strokeLinejoin="round" focusable="false" role={title ? 'img' : undefined} aria-hidden={title ? undefined : true} aria-labelledby={title ? id : undefined} className={('mehewara-icon ' + className).trim()}>
    {title && <title id={id}>{title}</title>}
    {shapes[name]}
  </svg>;
}
