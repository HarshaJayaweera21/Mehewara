import { useCallback, useEffect, useRef, useState } from 'react';
import { Icon, StatusBadge, mehewaraAssets } from '../../design-system/mehewara';
import './LandingPage.css';

interface LandingPageProps {
  onSignIn: () => void;
  onSignUp: () => void;
}

const reportExamples = [
  { image: mehewaraAssets.problemDrainage, alt: 'Blocked roadside drain with wet pavement', icon: 'drainage' as const, category: 'Drainage', title: 'A blocked drain after heavy rain', location: 'Central College Road', status: 'in-progress' as const },
  { image: mehewaraAssets.problemRoadPothole, alt: 'Pothole and cracked asphalt on a municipal road', icon: 'road' as const, category: 'Roads', title: 'A pothole on the daily route', location: 'Main Street', status: 'assigned' as const },
  { image: mehewaraAssets.problemWaste, alt: 'Waste accumulated beside a public road', icon: 'waste' as const, category: 'Waste', title: 'Waste beside a public road', location: 'Central Market Road', status: 'identified' as const },
  { image: mehewaraAssets.problemStreetlight, alt: 'Streetlight illuminating a municipal road at dusk', icon: 'electrical' as const, category: 'Streetlights', title: 'A streetlight lighting the way again', location: 'Station Road', status: 'resolved' as const },
  { image: mehewaraAssets.problemEnvironment, alt: 'Fallen branch blocking a public footpath', icon: 'environment' as const, category: 'Environment', title: 'A fallen branch across a footpath', location: 'Park Lane', status: 'identified' as const },
];

type ReportExample = (typeof reportExamples)[number];

function ReportExampleCard({ report, decorative = false }: { report: ReportExample; decorative?: boolean }) {
  return (
    <article className="landing-report-card" aria-hidden={decorative || undefined}>
      <div className="landing-report-image"><img src={report.image} alt={decorative ? '' : report.alt} width="1536" height="864" loading="lazy" /></div>
      <div className="landing-report-body"><span className="landing-report-category"><Icon name={report.icon} size={16} /> {report.category}</span><h3>{report.title}</h3><p><Icon name="location" size={16} /> {report.location}</p><div className="landing-report-footer"><span>Example report</span><StatusBadge value={report.status} /></div></div>
    </article>
  );
}

const processSteps = [
  { icon: 'document' as const, title: 'Tell us what you see', description: 'Add a photo, a location, and a few useful details. That is enough to start a report.' },
  { icon: 'problems' as const, title: 'The right team sees it', description: 'Related reports come together so municipal coordinators can understand the full issue.' },
  { icon: 'refresh' as const, title: 'Follow what happens', description: 'See the status change as work is assigned, carried out, and resolved.' },
];

export function LandingPage({ onSignIn, onSignUp }: LandingPageProps) {
  const [menuOpen, setMenuOpen] = useState(false);
  const reportTrackRef = useRef<HTMLDivElement>(null);
  const [activeReport, setActiveReport] = useState(0);
  const [reportsVisible, setReportsVisible] = useState(false);
  const [reportsHovered, setReportsHovered] = useState(false);
  const [reportsKeyboardFocused, setReportsKeyboardFocused] = useState(false);
  const [reportsTouched, setReportsTouched] = useState(false);
  const closeMenu = () => setMenuOpen(false);

  const updateReportScroll = () => {
    const track = reportTrackRef.current;
    if (!track) return;
    const cards = Array.from(track.querySelectorAll<HTMLElement>('.landing-report-card'));
    if (cards.length < reportExamples.length + 1) return;
    const step = cards[1].offsetLeft - cards[0].offsetLeft;
    const cycleWidth = cards[reportExamples.length].offsetLeft - cards[0].offsetLeft;
    if (track.scrollLeft >= cycleWidth - 1) track.scrollLeft -= cycleWidth;
    const nextIndex = Math.min(reportExamples.length - 1, Math.max(0, Math.round(track.scrollLeft / step)));
    setActiveReport((current) => current === nextIndex ? current : nextIndex);
  };

  const scrollReports = useCallback((direction: -1 | 1) => {
    const track = reportTrackRef.current;
    const cards = track?.querySelectorAll<HTMLElement>('.landing-report-card');
    if (!track || !cards || cards.length < 2) return;
    const distance = cards[1].offsetLeft - cards[0].offsetLeft;
    const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    track.scrollBy({ left: direction * distance, behavior: reducedMotion ? 'auto' : 'smooth' });
  }, []);

  useEffect(() => {
    const track = reportTrackRef.current;
    if (!track || !('IntersectionObserver' in window)) return;
    const observer = new IntersectionObserver(([entry]) => setReportsVisible(entry.isIntersecting), { threshold: 0.35 });
    observer.observe(track);
    return () => observer.disconnect();
  }, []);

  useEffect(() => {
    if (!reportsVisible || reportsHovered || reportsKeyboardFocused || reportsTouched) return;
    const timer = window.setInterval(() => {
      if (!document.hidden && !window.matchMedia('(prefers-reduced-motion: reduce)').matches) scrollReports(1);
    }, 5000);
    return () => window.clearInterval(timer);
  }, [reportsVisible, reportsHovered, reportsKeyboardFocused, reportsTouched, scrollReports]);

  return (
    <div className="landing-page" id="top">
      <a className="landing-skip" href="#main-content">Skip to content</a>
      <header className="landing-header">
        <a className="landing-brand" href="#top" aria-label="Mehewara home" onClick={closeMenu}>
          <img src={mehewaraAssets.mehewaraLogoCompact} alt="Mehewara" width="520" height="144" />
        </a>
        <button type="button" className="landing-menu-button" aria-label={menuOpen ? 'Close navigation' : 'Open navigation'} aria-expanded={menuOpen} aria-controls="landing-navigation" onClick={() => setMenuOpen((open) => !open)}>
          <span aria-hidden="true" /><span aria-hidden="true" />
        </button>
        <nav id="landing-navigation" className={menuOpen ? 'landing-nav is-open' : 'landing-nav'} aria-label="Main navigation">
          <a href="#how-it-works" onClick={closeMenu}>How it works</a>
          <a href="#community" onClick={closeMenu}>Community issues</a>
          <a href="#why-mehewara" onClick={closeMenu}>Why Mehewara</a>
          <span className="landing-nav-divider" aria-hidden="true" />
          <button className="landing-nav-login" type="button" onClick={() => { closeMenu(); onSignIn(); }}>Log in</button>
          <button className="landing-nav-join" type="button" onClick={() => { closeMenu(); onSignUp(); }}>Get started <Icon name="arrow-right" size={16} /></button>
        </nav>
      </header>

      <main id="main-content">
        <section className="landing-hero" aria-labelledby="landing-title">
          <div className="landing-hero-inner">
            <div className="landing-hero-copy">
              <p className="landing-hero-overline"><span aria-hidden="true" /> Cleaner cities. Stronger communities.</p>
              <h1 id="landing-title">Your street.<br /><span>A better city.</span></h1>
              <p className="landing-hero-intro">From a blocked drain to a safer walkway, Mehewara helps you raise local concerns and see how they are handled.</p>
              <div className="landing-hero-actions">
                <button type="button" className="landing-button landing-button-dark" onClick={onSignUp}>Report a problem <Icon name="arrow-right" size={20} /></button>
                <a className="landing-button landing-button-outline" href="#how-it-works">See how it works</a>
              </div>
              <p className="landing-hero-note"><Icon name="info" size={16} /> Made for residents and municipal teams</p>
            </div>

            <div className="landing-hero-visual" aria-label="Illustration of a report moving toward resolution">
              <div className="hero-visual-halo" aria-hidden="true" />
              <div className="hero-visual-caption">A clearer path from report to response</div>
              <div className="hero-report-preview">
                <div className="hero-preview-topline"><span><img src={mehewaraAssets.mehewaraLogoIcon} alt="" width="24" height="24" /> Community report</span><Icon name="document" size={20} /></div>
                <img className="hero-preview-photo" src={mehewaraAssets.problemDrainage} alt="Blocked roadside drainage grate" width="1536" height="864" fetchPriority="high" />
                <div className="hero-preview-content">
                  <span className="hero-preview-category"><Icon name="drainage" size={16} /> Drainage</span>
                  <h2>Blocked roadside drainage</h2>
                  <p><Icon name="location" size={16} /> Central College Road</p>
                  <div className="hero-preview-progress"><span>Report progress</span><StatusBadge value="in-progress" /></div>
                  <div className="hero-progress-track" aria-hidden="true"><span /></div>
                  <div className="hero-progress-labels"><span>Reported</span><span>In progress</span><span>Resolved</span></div>
                </div>
              </div>
              <div className="hero-update-card"><span className="hero-update-icon"><Icon name="bell" size={20} /></span><div><strong>Stay in the loop</strong><span>See each step as it happens</span></div></div>
              <div className="hero-image-credit">Illustrative report preview</div>
            </div>
          </div>
          <img className="landing-hero-city" src={mehewaraAssets.mehewaraWelcomeCityscape} alt="" aria-hidden="true" />
        </section>

        <div className="landing-capabilities" aria-label="What Mehewara helps you do">
          <div><Icon name="location" size={20} /><span>Put issues on the map</span></div>
          <div><Icon name="reports" size={20} /><span>Bring related reports together</span></div>
          <div><Icon name="refresh" size={20} /><span>See progress clearly</span></div>
        </div>

        <section id="how-it-works" className="landing-process landing-section" aria-labelledby="process-title">
          <div className="landing-section-intro"><div><p className="landing-kicker">A simple process</p><h2 id="process-title">Your concern deserves<br />a clear next step.</h2></div><p>One place to report a local issue, understand its progress, and help your neighbourhood move forward.</p></div>
          <div className="landing-process-grid">
            {processSteps.map((step, index) => (
              <article className="landing-process-step" key={step.title}>
                <div className="landing-step-top"><span className="landing-step-icon"><Icon name={step.icon} size={24} /></span><span className="landing-step-number">0{index + 1}</span></div>
                <h3>{step.title}</h3><p>{step.description}</p>
              </article>
            ))}
          </div>
        </section>

        <section className="landing-city-moment" aria-labelledby="city-moment-title">
          <img src={mehewaraAssets.mehewaraWelcomeBg} alt="" aria-hidden="true" width="1920" height="640" loading="lazy" />
          <div className="landing-city-moment-copy">
            <h2 id="city-moment-title">We all share<br /><span>this city.</span></h2>
            <p>Every street, walkway and public space is worth caring for.</p>
          </div>
        </section>

        <section
          id="community"
          className="landing-community"
          aria-labelledby="community-title"
          onMouseEnter={() => setReportsHovered(true)}
          onMouseLeave={() => setReportsHovered(false)}
          onFocusCapture={(event) => {
            if (event.target instanceof HTMLElement && event.target.matches(':focus-visible')) setReportsKeyboardFocused(true);
          }}
          onBlurCapture={(event) => {
            if (!event.currentTarget.contains(event.relatedTarget as Node | null)) setReportsKeyboardFocused(false);
          }}
          onTouchStart={() => setReportsTouched(true)}
          onTouchEnd={() => setReportsTouched(false)}
          onTouchCancel={() => setReportsTouched(false)}
        >
          <div className="landing-community-inner">
            <div className="landing-community-heading">
              <div><p className="landing-kicker">The issues around us</p><h2 id="community-title">Every report tells us<br />where care is needed.</h2></div>
              <div className="landing-community-side">
                <p>From everyday road repairs to cleaner public spaces, clear reporting helps teams see what needs attention.</p>
                <div className="landing-report-controls">
                  <span aria-live={reportsHovered || reportsKeyboardFocused || reportsTouched ? 'polite' : 'off'} aria-label={`Example ${activeReport + 1} of ${reportExamples.length}`}>{String(activeReport + 1).padStart(2, '0')} <span>/</span> {String(reportExamples.length).padStart(2, '0')}</span>
                  <button type="button" aria-label="Previous example reports" aria-controls="landing-report-track" disabled={activeReport === 0} onClick={() => scrollReports(-1)}><Icon name="arrow-left" size={20} /></button>
                  <button type="button" aria-label="Next example reports" aria-controls="landing-report-track" onClick={() => scrollReports(1)}><Icon name="arrow-right" size={20} /></button>
                </div>
              </div>
            </div>
            <div
              id="landing-report-track"
              className="landing-report-track"
              ref={reportTrackRef}
              role="region"
              aria-label="Example community reports"
              tabIndex={0}
              onScroll={updateReportScroll}
              onKeyDown={(event) => {
                if (event.key === 'ArrowRight' || event.key === 'ArrowLeft') {
                  event.preventDefault();
                  scrollReports(event.key === 'ArrowRight' ? 1 : -1);
                }
              }}
            >
              {reportExamples.map((report) => (
                <ReportExampleCard key={report.title} report={report} />
              ))}
              {reportExamples.map((report) => (
                <ReportExampleCard key={`${report.title}-loop`} report={report} decorative />
              ))}
            </div>
            <p className="landing-scroll-hint">Swipe to see more examples</p>
          </div>
        </section>

        <section id="why-mehewara" className="landing-story landing-section" aria-labelledby="story-title">
          <div className="landing-story-visual"><img src={mehewaraAssets.problemEnvironment} alt="Fallen tree branch across a public footpath" width="1536" height="864" loading="lazy" /><div className="landing-story-tag"><Icon name="environment" size={20} /> Better public spaces begin with being heard.</div></div>
          <div className="landing-story-copy">
            <p className="landing-kicker">Why Mehewara</p><h2 id="story-title">People notice the details. Together, we can act on them.</h2>
            <p>A branch across a footpath. A streetlight that needs attention. A problem that keeps returning. Mehewara gives those observations a useful place to go.</p>
            <div className="landing-story-points">
              <div><span><Icon name="users" size={20} /></span><p><strong>One shared view</strong>Residents and coordinators can follow the same issue.</p></div>
              <div><span><Icon name="map" size={20} /></span><p><strong>Grounded in place</strong>Locations help teams understand the area affected.</p></div>
              <div><span><Icon name="analytics" size={20} /></span><p><strong>A fuller picture</strong>Related concerns reveal patterns worth addressing.</p></div>
            </div>
            <button type="button" className="landing-text-link" onClick={onSignUp}>Create your account <Icon name="arrow-right" size={20} /></button>
          </div>
        </section>

        <section className="landing-final-cta" aria-labelledby="final-cta-title">
          <img className="landing-final-leaves" src={mehewaraAssets.mehewaraWelcomeLeaves} alt="" aria-hidden="true" />
          <div><p className="landing-kicker">Your community starts here</p><h2 id="final-cta-title">See a problem? Help move it forward.</h2><p>Share a local concern and follow the response in one place.</p></div>
          <button type="button" className="landing-button landing-button-light" onClick={onSignUp}>Get started <Icon name="arrow-right" size={20} /></button>
        </section>
      </main>

      <footer className="landing-footer">
        <div className="landing-footer-main"><div><img src={mehewaraAssets.mehewaraLogoCompact} alt="Mehewara" width="520" height="144" /><p>Cleaner cities. Stronger communities.</p></div><nav aria-label="Footer navigation"><a href="#how-it-works">How it works</a><a href="#community">Community issues</a><a href="#why-mehewara">Why Mehewara</a><button type="button" onClick={onSignIn}>Log in</button></nav></div>
        <p className="landing-footer-bottom">© {new Date().getFullYear()} Mehewara Municipal Services</p>
      </footer>
    </div>
  );
}
