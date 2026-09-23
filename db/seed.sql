-- Test teachers (passwords are bcrypt-hashed) and fake students.
insert into gradebook.teachers(email, name, password_hash) values
  ('teacher1@school.test', 'Ms. Alice Johnson', extensions.crypt('teacher1pass', extensions.gen_salt('bf'))),
  ('teacher2@school.test', 'Mr. Bob Smith',     extensions.crypt('teacher2pass', extensions.gen_salt('bf')));

insert into gradebook.students(teacher_id, name, subject, grade)
select t.id, v.name, v.subject, v.grade
from (values
  ('teacher1@school.test', 'Emma Brown',      'Math',    88),
  ('teacher1@school.test', 'Liam Davis',      'Math',    74),
  ('teacher1@school.test', 'Olivia Garcia',   'Math',    92),
  ('teacher1@school.test', 'Noah Martinez',   'Math',    65),
  ('teacher1@school.test', 'Ava Wilson',      'Math',    81),
  ('teacher2@school.test', 'Sophia Anderson', 'Science', 90),
  ('teacher2@school.test', 'Mason Thomas',    'Science', 70),
  ('teacher2@school.test', 'Isabella Taylor', 'Science', 84),
  ('teacher2@school.test', 'Ethan Moore',     'Science', 59),
  ('teacher2@school.test', 'Mia Jackson',     'Science', 77)
) as v(email, name, subject, grade)
join gradebook.teachers t on t.email = v.email;
