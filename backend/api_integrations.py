import os
from dotenv import load_dotenv

# Load environment variables from .env
load_dotenv()

# Feature Toggle for Sentry Error Tracking
SENTRY_ENABLED = os.getenv("SENTRY_ENABLED", "False").lower() == "true"

if SENTRY_ENABLED:
    import sentry_sdk
    from sentry_sdk.integrations.flask import FlaskIntegration

    sentry_sdk.init(
        dsn=os.getenv("SENTRY_DSN"),
        integrations=[FlaskIntegration()],
        traces_sample_rate=1.0
    )
    print("✅ Sentry Enabled")
else:
    print("⚠️ Sentry is disabled. Set SENTRY_ENABLED=True in .env to activate it.")
