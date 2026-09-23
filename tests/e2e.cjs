// End-to-end test in a real browser.
// Usage: NODE_PATH=$(npm root -g) node tests/e2e.cjs [url]
// With no url, the local index.html is served (the Supabase backend is still real).
const { chromium } = require('playwright');
const assert = require('assert');

const URL = process.argv[2] || 'http://gradebook.test/';

(async () => {
  const proxy = process.env.HTTPS_PROXY ? { server: process.env.HTTPS_PROXY } : undefined;
  const browser = await chromium.launch({ proxy });
  const page = await browser.newPage();
  if (process.env.HTTPS_PROXY) {
    // Behind a TLS-intercepting sandbox proxy the browser can't verify certs itself,
    // so Playwright performs the real HTTPS requests from Node and hands them to the page.
    await page.route(/^https:\/\//, async r => r.fulfill({ response: await r.fetch() }));
  }
  if (!process.argv[2]) {
    await page.route('http://gradebook.test/**', r => r.fulfill({ path: __dirname + '/../index.html', contentType: 'text/html' }));
  }
  const login = async (email, pw) => {
    await page.fill('#email', email);
    await page.fill('#password', pw);
    await page.click('#loginForm button');
  };
  const names = () => page.$$eval('#rows tr td:first-child', tds => tds.map(td => td.textContent));
  const gradeOf = name => page.locator('#rows tr', { hasText: name }).locator('input').inputValue();

  await page.goto(URL);
  await page.waitForSelector('#loginForm', { state: 'visible' });

  await login('teacher1@school.test', 'wrong');
  await page.waitForSelector('#msg.err');
  assert.match(await page.textContent('#msg'), /Invalid email or password/);
  console.log('ok - wrong password rejected');

  await login('teacher1@school.test', 'teacher1pass');
  await page.waitForSelector('#app', { state: 'visible' });
  let n = await names();
  assert.equal(n.length, 5);
  assert.ok(n.includes('Emma Brown') && !n.includes('Sophia Anderson'));
  console.log('ok - teacher1 sees only own 5 students:', n.join(', '));

  const newGrade = String(50 + Math.floor(Math.random() * 50));
  await page.locator('#rows tr', { hasText: 'Emma Brown' }).locator('input').fill(newGrade);
  await page.locator('#rows tr', { hasText: 'Emma Brown' }).locator('button').click();
  await page.waitForSelector('#msg.ok');
  console.log('ok - saved Emma Brown =', newGrade);

  await page.reload();
  await page.waitForSelector('#app', { state: 'visible' });
  await page.waitForSelector('#rows tr');
  assert.equal(await gradeOf('Emma Brown'), newGrade);
  console.log('ok - grade persisted after refresh');

  await page.click('#logout');
  await page.waitForSelector('#loginForm', { state: 'visible' });
  await page.reload();
  await page.waitForSelector('#loginForm', { state: 'visible' });
  await login('teacher1@school.test', 'teacher1pass');
  await page.waitForSelector('#rows tr');
  assert.equal(await gradeOf('Emma Brown'), newGrade);
  console.log('ok - grade persisted after logout + login');

  await page.click('#logout');
  await login('teacher2@school.test', 'teacher2pass');
  await page.waitForSelector('#rows tr');
  n = await names();
  assert.equal(n.length, 5);
  assert.ok(n.includes('Sophia Anderson') && !n.includes('Emma Brown'));
  console.log('ok - teacher2 sees only own 5 students:', n.join(', '));

  await browser.close();
  console.log('ALL PASSED against', URL);
})().catch(e => { console.error('FAILED:', e.message); process.exit(1); });
