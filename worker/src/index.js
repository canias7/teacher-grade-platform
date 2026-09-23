// Teacher gradebook API (Cloudflare Worker). The browser talks only to this;
// this Worker is the only thing that talks to the Postgres database.
import { Client } from 'pg';

const cors = {
  'Access-Control-Allow-Origin': 'https://canias7.github.io',
  'Access-Control-Allow-Headers': 'Authorization, Content-Type',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, OPTIONS',
};
const json = (body, status = 200) =>
  new Response(body === null ? null : JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } });

export default {
  async fetch(req, env, ctx) {
    if (req.method === 'OPTIONS') return new Response(null, { headers: cors });
    const url = new URL(req.url);
    const db = new Client({ connectionString: env.HYPERDRIVE ? env.HYPERDRIVE.connectionString : env.DATABASE_URL });
    try {
      await db.connect();

      if (req.method === 'POST' && url.pathname === '/api/login') {
        const { email, password } = await req.json();
        // bcrypt check runs in Postgres (pgcrypto) to stay within the Worker's CPU limit.
        const { rows } = await db.query(
          `select id, name, email from gradebook.teachers
            where email = lower(trim($1)) and password_hash = extensions.crypt($2, password_hash)`,
          [String(email), String(password)]);
        if (!rows[0]) return json({ message: 'Invalid email or password' }, 401);
        const s = await db.query('insert into gradebook.sessions(teacher_id) values ($1) returning token', [rows[0].id]);
        return json({ token: s.rows[0].token, name: rows[0].name, email: rows[0].email });
      }

      // Everything below requires a valid session; the teacher id comes from the session, never the client.
      const token = (req.headers.get('Authorization') || '').replace(/^Bearer /, '');
      const auth = await db.query('select teacher_id from gradebook.sessions where token::text = $1 and expires_at > now()', [token]);
      const teacherId = auth.rows[0]?.teacher_id;
      if (!teacherId) return json({ message: 'Not logged in' }, 401);

      if (req.method === 'GET' && url.pathname === '/api/students') {
        const { rows } = await db.query(
          'select id, name, subject, grade from gradebook.students where teacher_id = $1 order by name', [teacherId]);
        return json(rows);
      }

      const m = url.pathname.match(/^\/api\/students\/(\d+)\/grade$/);
      if (req.method === 'PUT' && m) {
        const { grade } = await req.json();
        if (!Number.isInteger(grade) || grade < 0 || grade > 100) return json({ message: 'Grade must be between 0 and 100' }, 400);
        const { rowCount } = await db.query(
          'update gradebook.students set grade = $1, updated_at = now() where id = $2 and teacher_id = $3',
          [grade, Number(m[1]), teacherId]);
        return rowCount ? json({ id: Number(m[1]), grade }) : json({ message: 'Student not found' }, 404);
      }

      if (req.method === 'POST' && url.pathname === '/api/logout') {
        await db.query('delete from gradebook.sessions where token::text = $1', [token]);
        return json(null, 204);
      }

      return json({ message: 'Not found' }, 404);
    } catch (e) {
      console.error(e);
      return json({ message: 'Server error' }, 500);
    } finally {
      ctx.waitUntil(db.end().catch(() => {}));
    }
  },
};
