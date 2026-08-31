# NKG Launcher

The NKG launcher owns central authentication, application permissions, and the application directory. The child applications remain independent projects:

- `https://logistics.nkg.app` → `nkg_logis_real`
- `https://waterpark.nkg.app` → `waterpark`

## Supabase setup

1. Create or select the central NKG Supabase project.
2. Run [`db/central_authorization.sql`](db/central_authorization.sql) in its SQL editor.
3. Create users in Supabase Authentication.
4. Assign each user a role using the SQL comment at the bottom of the schema file.

The central project should contain only NKG identity and authorization tables. Keep logistics and waterpark business tables in their existing projects.

## Run locally

```bash
flutter pub get
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-publishable-key
```

The launcher calls `get_my_launcher_apps`, so users see only applications granted through their roles. An app with status `paused` remains visible but cannot be opened.

## Deployment domains

Configure production deployments as:

```text
nkg.app
logistics.nkg.app
waterpark.nkg.app
```

Set the child-app URLs in `launcher_apps` after deployment. Do not put child-app source code inside this project.
# AppLauncher
