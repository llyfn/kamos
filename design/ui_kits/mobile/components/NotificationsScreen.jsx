// KAMOS — Screen: Notifications (SPEC §5.4).
// Single in-app surface for all 5 notification types. Cursor-paginated 20/page,
// newest first. See design/notifications_ux.md for the full spec.
//
// Row visual states:
//   - unread → Card background tinted with --bg-tint-mizu (light brand wash)
//   - read   → Card background --bg-card (default)
// Crossfade between the two over var(--dur-base).
//
// Mark-on-scroll: in Flutter this fires via visibility_detector at ≥50% visible
// for ≥500ms. The kit demonstrates static rows only; the read/unread toggle is
// driven by the seed data and the "Mark all read" button.

// Resolve the verb template for a notification type and render it with the
// actor name bolded inline. Returns a React fragment, not a string.
const verbLine = (n, tt) => {
  const actorName = n.actor ? n.actor.displayName : tt(UI.notificationsDeletedActor);
  const key = {
    toast:           UI.notifVerbToast,
    comment:         UI.notifVerbComment,
    follow:          UI.notifVerbFollow,
    follow_request:  UI.notifVerbFollowRequest,
    follow_approved: UI.notifVerbFollowApproved,
  }[n.type];
  const template = tt(key);
  const [before, after] = template.split('{actor}');
  return (
    <span style={{
      fontFamily: 'var(--font-body)', fontSize: 15, lineHeight: 1.4, color: 'var(--fg-1)',
    }}>
      {before}
      <span style={{ fontWeight: 600, color: n.actor ? 'var(--fg-1)' : 'var(--fg-2)' }}>{actorName}</span>
      {after}
    </span>
  );
};

const NotificationRow = ({ n, onTap, onApprove, onDecline }) => {
  const { tt } = useLocale();
  const isRequest = n.type === 'follow_request';
  const deleted = !n.actor;

  return (
    <div
      onClick={() => !isRequest && onTap?.(n)}
      style={{
        background: n.read ? 'var(--bg-card)' : 'var(--bg-tint-mizu)',
        border: '1px solid var(--border-1)',
        borderRadius: 12, padding: 14,
        boxShadow: 'var(--shadow-1)',
        cursor: isRequest ? 'default' : 'pointer',
        transition: 'background var(--dur-base) var(--ease-out)',
      }}
    >
      <div style={{ display: 'flex', gap: 12, alignItems: 'flex-start' }}>
        <Avatar
          initial={deleted ? '—' : n.actor.avatar}
          size={40}
          tone={deleted ? 'kinari' : (n.actor.tone || 'kinari')}
        />
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ display: 'flex', alignItems: 'flex-start', gap: 8 }}>
            <div style={{ flex: 1, minWidth: 0 }}>
              {verbLine(n, tt)}
            </div>
            <div style={{
              fontFamily: 'var(--font-mono)', fontSize: 11, color: 'var(--fg-3)',
              flex: 'none', paddingTop: 2,
            }}>{n.when}</div>
          </div>
          {n.preview && (
            <div style={{
              fontFamily: 'var(--font-body)', fontSize: 13, color: 'var(--fg-2)',
              marginTop: 4, lineHeight: 1.4,
              whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
            }}>{n.preview}</div>
          )}
        </div>
      </div>
      {isRequest && (
        <div style={{ display: 'flex', gap: 8, marginTop: 12 }} onClick={(e) => e.stopPropagation()}>
          <Btn kind="secondary" full onClick={() => onDecline?.(n.id)}>{tt(UI.decline)}</Btn>
          <Btn kind="primary"   full onClick={() => onApprove?.(n.id)}>{tt(UI.approve)}</Btn>
        </div>
      )}
    </div>
  );
};

const NotificationsScreen = ({ notifications, onOpen, emptyMode = false }) => {
  const { tt } = useLocale();
  const [items, setItems] = React.useState(notifications || []);

  const hasUnread = items.some(n => !n.read);

  const markAllRead = () => {
    setItems(prev => prev.map(n => ({ ...n, read: true })));
  };

  const handleApprove = (id) => {
    // In Flutter: PATCH /follow/requests/:id/approve → then mark this notification row read.
    setItems(prev => prev.map(n => n.id === id ? { ...n, read: true } : n));
  };
  const handleDecline = (id) => {
    // In Flutter: PATCH /follow/requests/:id/decline → row stays but is now read.
    setItems(prev => prev.map(n => n.id === id ? { ...n, read: true } : n));
  };

  const showEmpty = emptyMode || items.length === 0;

  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', background: 'var(--bg-page)' }}>
      <TopBar
        title={tt(UI.notificationsTitle)}
        right={
          !showEmpty && (
            <button
              onClick={markAllRead}
              disabled={!hasUnread}
              style={{
                background: 'transparent', border: 'none', cursor: hasUnread ? 'pointer' : 'default',
                fontFamily: 'var(--font-body)', fontSize: 13, fontWeight: 600,
                color: 'var(--fg-brand)', opacity: hasUnread ? 1 : 0.4,
                padding: '6px 8px', whiteSpace: 'nowrap',
              }}
            >{tt(UI.notificationsMarkAllRead)}</button>
          )
        }
      />
      <div style={{ flex: 1, overflowY: 'auto', padding: '8px 16px 16px' }}>
        {showEmpty ? (
          <EmptyState
            glyph="通"
            title={tt(UI.notificationsEmptyTitle)}
            body={tt(UI.notificationsEmptyBody)}
          />
        ) : (
          <>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
              {items.map(n => (
                <NotificationRow
                  key={n.id}
                  n={n}
                  onTap={onOpen}
                  onApprove={handleApprove}
                  onDecline={handleDecline}
                />
              ))}
            </div>
            <PagingFooter
              state="idle"
              hasMore={false}
              endLabel={tt(UI.notificationsEnd)}
            />
          </>
        )}
      </div>
    </div>
  );
};

Object.assign(window, { NotificationsScreen, NotificationRow });
