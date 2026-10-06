// Builds feed.xml (an RSS feed of River's blog) from the published blog posts in Supabase.
// Run by .github/workflows/feed.yml. Needs SUPABASE_URL and SUPABASE_ANON_KEY.
import { writeFileSync } from 'node:fs';

const API = (process.env.SUPABASE_URL || '').replace(/\/$/, '');
const KEY = process.env.SUPABASE_ANON_KEY || '';
const SITE = (process.env.SITE_URL || 'https://ourworldofwildlife.org').replace(/\/$/, '');
const OUT = process.env.FEED_OUT || 'feed.xml';

if (!API || !KEY) { console.error('Missing SUPABASE_URL or SUPABASE_ANON_KEY'); process.exit(1); }

const cols = 'id,title,category,body,image_path,image_alt,created_at,updated_at';
const res = await fetch(`${API}/rest/v1/posts?select=${cols}&type=eq.blog&published=eq.true&order=created_at.desc&limit=30`, { headers: { apikey: KEY } });
if (!res.ok) { console.error('Could not read posts:', res.status, await res.text()); process.exit(1); }
const rows = await res.json();
if (!Array.isArray(rows)) { console.error('Unexpected response'); process.exit(1); }

const esc = s => String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
const toHtml = r => {
  const img = r.image_path ? `<p><img src="${esc(`${API}/storage/v1/object/public/site-images/${encodeURI(r.image_path)}`)}" alt="${esc(r.image_alt || '')}"></p>` : '';
  const paras = String(r.body || '').split(/\n\s*\n/).map(p => p.trim()).filter(Boolean)
    .map(p => `<p>${esc(p).replace(/\n/g, '<br>')}</p>`).join('');
  return img + paras;
};

// Use the newest post date (not "now") so the file only changes when a post changes.
const newest = rows.reduce((m, r) => Math.max(m, new Date(r.updated_at || r.created_at).getTime()), 0);
const items = rows.map(r => `    <item>
      <title>${esc(r.title)}</title>
      <link>${esc(`${SITE}/#/blog/${r.id}`)}</link>
      <guid isPermaLink="false">${esc(r.id)}</guid>
      <pubDate>${new Date(r.created_at).toUTCString()}</pubDate>${r.category ? `\n      <category>${esc(r.category)}</category>` : ''}
      <description>${esc(toHtml(r))}</description>
    </item>`).join('\n');

const xml = `<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">
  <channel>
    <title>River's Blog | Our World of Wildlife</title>
    <link>${SITE}/#/blog</link>
    <atom:link href="${SITE}/feed.xml" rel="self" type="application/rss+xml"/>
    <description>Stories, discoveries and ideas for helping the planet, from River.</description>
    <language>en-us</language>
    <lastBuildDate>${new Date(newest).toUTCString()}</lastBuildDate>
${items}
  </channel>
</rss>
`;
writeFileSync(OUT, xml);
console.log(`Wrote ${OUT} with ${rows.length} post(s).`);
