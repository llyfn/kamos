// KAMOS — Screen: Follow request Inbox (SPEC §5.4).
// Only in-app notification surface in MVP. Approve/decline per request.
// Badge count = unread requests on the bell icon in FeedScreen.

const InboxScreen = ({ requests, onClose, onApprove, onDecline }) => {
  const { tt } = useLocale();
  const [items, setItems] = React.useState(requests || []);

  const handle = (id, kind) => {
    setItems(prev => prev.filter(r => r.id !== id));
    if (kind === 'approve') onApprove?.(id);
    else onDecline?.(id);
  };

  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', background: 'var(--bg-page)' }}>
      <TopBar
        title={tt({ en: 'Follow requests', ja: 'フォローリクエスト', ko: '팔로우 요청' })}
        onBack={onClose}
      />
      <div style={{ flex: 1, overflowY: 'auto', padding: '8px 16px 16px' }}>
        {items.length === 0 ? (
          <EmptyState
            title={tt({ en: 'No pending requests', ja: '保留中のリクエストはありません', ko: '대기 중인 요청이 없습니다' })}
            body={tt({
              en: 'Follow requests appear here while your account is private.',
              ja: 'アカウントが非公開の間、リクエストはここに表示されます。',
              ko: '비공개 계정일 때 팔로우 요청이 여기에 표시됩니다.',
            })}
          />
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {items.map(r => (
              <Card key={r.id}>
                <div style={{ display: 'flex', gap: 12, alignItems: 'center' }}>
                  <Avatar initial={r.avatar} size={44} tone="kinari"/>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ fontFamily: 'var(--font-body)', fontSize: 14, fontWeight: 600, color: 'var(--fg-1)' }}>{r.displayName}</div>
                    <div style={{ fontFamily: 'var(--font-mono)', fontSize: 12, color: 'var(--fg-3)' }}>@{r.user}</div>
                    {r.bio && <div style={{ fontSize: 12, color: 'var(--fg-2)', marginTop: 2 }}>{r.bio}</div>}
                    <div style={{ fontFamily: 'var(--font-mono)', fontSize: 11, color: 'var(--fg-3)', marginTop: 4 }}>{r.when}</div>
                  </div>
                </div>
                <div style={{ display: 'flex', gap: 8, marginTop: 12 }}>
                  <Btn kind="secondary" full onClick={() => handle(r.id, 'decline')}>{tt(UI.decline)}</Btn>
                  <Btn kind="primary"   full onClick={() => handle(r.id, 'approve')}>{tt(UI.approve)}</Btn>
                </div>
              </Card>
            ))}
          </div>
        )}
      </div>
    </div>
  );
};

Object.assign(window, { InboxScreen });
