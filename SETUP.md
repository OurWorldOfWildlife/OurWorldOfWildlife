# Setting up River's admin page

Everything is built. These steps connect it to a free database so River can log in, write posts and upload photos.

Do them with the project email (river@ourworldofwildlife.org or a dedicated Gmail) so the accounts belong to the project and not to one person.

## 1. Create the database (about 5 minutes)
1. Go to supabase.com and sign up (free plan).
2. Click **New project**. Name it `our-world-of-wildlife`, pick a region near New Jersey (US East) and save the database password somewhere safe.

## 2. Run the setup file
1. In the project, open **SQL Editor**, then **New query**.
2. Paste the whole contents of `schema.sql` and click **Run**.
   This creates the posts table, the photo storage and the rules for who can do what.

## 3. Lock down sign-ups
1. Open **Authentication** and find the sign-in settings. Turn **off** "Allow new users to sign up".
2. Open **URL Configuration**. Set **Site URL** to `https://ourworldofwildlife.org` and add `https://ourworldofwildlife.org/admin.html` to the redirect URLs.
   (Menu names shift now and then. Use the dashboard search if you cannot find them.)

## 4. Add the team
1. Open **Authentication, Users, Add user, Create new user**.
2. Add River and one grown-up. Type an email and a password for each and tick **Auto Confirm User**.

## 5. Give each person a role
Back in **SQL Editor**, run this with the real emails:

```sql
-- the grown-up: can publish, edit and delete anything
insert into public.admins (user_id, role)
select id, 'owner' from auth.users where email = 'GROWN-UP-EMAIL';

-- River: can write drafts and upload photos. A grown-up publishes them.
insert into public.admins (user_id, role)
select id, 'editor' from auth.users where email = 'RIVER-EMAIL';
```

To let River publish on her own later, run:

```sql
update public.admins set role = 'owner'
where user_id = (select id from auth.users where email = 'RIVER-EMAIL');
```

## 6. Connect the site
1. Open **Project Settings, API**. Copy the **Project URL** and the **anon** (or **publishable**) key.
2. Paste them into `config.js`. This key is meant to be public. Never paste a `service_role` or secret key anywhere.

## 7. Upload to GitHub
Upload everything in this folder to the repo, including the hidden `.github` folder, `admin.html`, `config.js`, `schema.sql` and `SETUP.md`. Then visit `https://ourworldofwildlife.org/admin.html`.

## 8. Keep the free database awake
Free Supabase projects pause after a week with no activity. The included `.github/workflows/keepalive.yml` pings the database twice a week.
1. In the GitHub repo, open **Settings, Secrets and variables, Actions**.
2. Add two repository secrets: `SUPABASE_URL` (the Project URL) and `SUPABASE_ANON_KEY` (the same key as in config.js).
3. Open the **Actions** tab, choose "Keep database awake" and click **Run workflow** once to test it.

GitHub turns off scheduled workflows in repos with no activity for 60 days, so re-enable it if that happens. Publishing a new post or editing the site counts as activity.

## How it works day to day
- River signs in at `/admin.html` with her email and password, or taps "Email me a sign-in link".
- She picks what she is adding (blog post, sanctuary update, magazine piece or gallery photo), writes, adds a photo and saves.
- The grown-up signs in, reviews drafts in the list and clicks **Publish**. It shows up on the site right away.
- Photos are shrunk to 1600 pixels and re-saved before upload, which also removes hidden location data.
