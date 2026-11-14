import { urls } from './env';
import { waitFor } from './stack';

interface MailpitSummary {
  ID: string;
  Subject: string;
  To: { Address: string }[];
}

interface MailpitMessage {
  HTML: string;
  Text: string;
}

async function json<T>(path: string): Promise<T> {
  const response = await fetch(`${urls.mailpit}${path}`);
  if (!response.ok) throw new Error(`Mailpit ${path} responded ${response.status}`);
  return (await response.json()) as T;
}

export interface EmailQuery {
  to: string;
  subject: string;
  /** Text the HTML body must contain, e.g. the registrant's email in an admin notification. */
  bodyIncludes?: string;
}

/** Waits for a matching message and returns its HTML body. */
export async function waitForEmail(query: EmailQuery, timeoutMs = 60_000): Promise<string> {
  let html = '';
  await waitFor(
    `email "${query.subject}" to ${query.to}`,
    async () => {
      const list = await json<{ messages: MailpitSummary[] }>('/api/v1/messages?limit=200');
      const candidates = list.messages.filter(
        (m) =>
          m.Subject.includes(query.subject) &&
          m.To.some((t) => t.Address.toLowerCase() === query.to.toLowerCase()),
      );
      for (const candidate of candidates) {
        const message = await json<MailpitMessage>(`/api/v1/message/${candidate.ID}`);
        if (!query.bodyIncludes || message.HTML.includes(query.bodyIncludes)) {
          html = message.HTML;
          return true;
        }
      }
      return false;
    },
    timeoutMs,
    1_000,
  );
  return html;
}

export async function clearMailbox(): Promise<void> {
  await fetch(`${urls.mailpit}/api/v1/messages`, { method: 'DELETE' });
}
