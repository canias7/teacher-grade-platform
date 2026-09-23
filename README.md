# teacher-grade-platform

A small teacher gradebook. Teachers log in, see only their own students, and change grades. Grades are saved in Postgres, so they're still there after a refresh or a logout.

**Live:** https://canias7.github.io/teacher-grade-platform/

## Test accounts

| Email | Password | Students |
|---|---|---|
| teacher1@school.test | teacher1pass | 5 Math students |
| teacher2@school.test | teacher2pass | 5 Science students |

## How it works

```
Browser (index.html on GitHub Pages)
   → Backend API: Cloudflare Worker  https://teacher-grade-api.aniascapital.workers.dev  (worker/)
   → Database: Supabase Postgres, schema "gradebook" (reached through Cloudflare Hyperdrive)
```

- **Frontend:** a single static page, `index.html`, served by GitHub Pages. It only calls the backend API and has no database URL or key.
- **Backend API** (`worker/src/index.js`): `POST /api/login`, `GET /api/students`, `PUT /api/students/:id/grade`, `POST /api/logout`. It connects to Postgres as the `gradebook_api` role, which can only use the three `gradebook` tables.
- **Database:** tables `gradebook.teachers`, `gradebook.students` and `gradebook.sessions`. The public Supabase API doesn't expose this schema.
- **Auth:** passwords are stored as bcrypt hashes. On login, the Worker has Postgres check the password with `pgcrypto`, then stores a random session token that expires after 12 hours. Every other request resolves the token to a teacher on the server and filters on `teacher_id`, so a teacher can't read or change another teacher's students.

## Setup from scratch

1. Run `db/schema.sql`, then `db/seed.sql`, in the Supabase SQL editor. Set a password for the `gradebook_api` role.
2. Deploy the Worker from `worker/`:
   - `npx wrangler hyperdrive create teacher-grade-db --connection-string="postgres://gradebook_api:<password>@db.<project-ref>.supabase.co:5432/postgres"`
   - Put the Hyperdrive id in `wrangler.jsonc`, then run `npx wrangler deploy`.
3. Put the Worker URL in `index.html` (`API`), and host the page anywhere static, e.g. GitHub Pages.

## Test

`NODE_PATH=$(npm root -g) node tests/e2e.cjs [url]` drives a real browser. It logs in, changes a grade, refreshes, logs out and back in, and checks that each teacher only sees their own students.
