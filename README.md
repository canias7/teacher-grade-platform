# teacher-grade-platform

A small teacher gradebook. Teachers log in, see only their own students, and change grades. Grades are saved in Postgres, so they're still there after a refresh or a logout.

**Live:** https://canias7.github.io/teacher-grade-platform/

## Test accounts

| Email | Password | Students |
|---|---|---|
| teacher1@school.test | teacher1pass | 5 Math students |
| teacher2@school.test | teacher2pass | 5 Science students |

## How it works

- **Frontend:** a single static page, `index.html`, served by GitHub Pages. It has no build step.
- **Database:** Supabase Postgres (free). Everything lives in its own `gradebook` schema, which the public API doesn't expose: `teachers`, `students`, `sessions`.
- **Auth:** passwords are hashed with bcrypt (`pgcrypto`). `gb_login` checks the password and returns a random session token that is valid for 12 hours. `gb_logout` deletes the token.
- **Isolation:** the browser can only call four `SECURITY DEFINER` functions: `gb_login`, `gb_logout`, `gb_my_students` and `gb_set_grade`. Each one turns the token into a teacher id on the server and filters on `teacher_id`. A teacher can't read or change another teacher's students, and the tables can't be queried directly.

## Setup from scratch

1. Run `db/schema.sql`, then `db/seed.sql`, in the Supabase SQL editor.
2. Put your project URL and publishable key in `index.html` (`API` / `KEY`).
3. Host `index.html` anywhere static, e.g. GitHub Pages.

## Test

`node tests/e2e.mjs [url]` drives a real browser. It logs in, changes a grade, refreshes, logs out and back in, and checks that each teacher only sees their own students.
