import './ArticlePane.css'

export function ArticlePane({ item }) {
  if (!item) {
    return <div className="article-pane article-empty">Select an article</div>
  }

  return (
    <div className="article-pane">
      <div className="article-header">
        <h1 className="article-title">
          {item.url ? <a href={item.url} target="_blank" rel="noreferrer">{item.title}</a> : item.title}
        </h1>
        <div className="article-meta">
          {item.author && <span>{item.author}</span>}
          {item.published_at && <span>{new Date(item.published_at).toLocaleString()}</span>}
        </div>
      </div>
      <div
        className="article-body"
        dangerouslySetInnerHTML={{ __html: item.content_html || '<p>No content.</p>' }}
      />
    </div>
  )
}
