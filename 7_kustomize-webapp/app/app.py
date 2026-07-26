from flask import Flask
import os

app = Flask(__name__)


@app.get("/healthz")
def healthz():
    return {"status": "ok"}, 200


@app.get("/")
def welcome():
    env_name = os.environ.get("ENV_NAME", "unknown")
    bg_color = os.environ.get("BG_COLOR", "#1e293b")
    greeting = os.environ.get("GREETING", "Welcome")
    image_tag = os.environ.get("IMAGE_TAG", "local")

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8"/>
  <title>{env_name} — welcome</title>
  <style>
    body {{
      margin: 0;
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      font-family: Georgia, "Times New Roman", serif;
      background: {bg_color};
      color: #f8fafc;
    }}
    main {{
      max-width: 36rem;
      padding: 2.5rem;
      text-align: center;
    }}
    h1 {{ font-size: 2.4rem; font-weight: 400; margin: 0 0 1rem; }}
    .env {{
      display: inline-block;
      margin-top: 1.5rem;
      padding: 0.35rem 0.9rem;
      border: 1px solid rgba(248,250,252,0.45);
      letter-spacing: 0.08em;
      text-transform: uppercase;
      font-size: 0.85rem;
    }}
    .meta {{ margin-top: 2rem; opacity: 0.75; font-size: 0.9rem; }}
  </style>
</head>
<body>
  <main>
    <h1>{greeting}</h1>
    <p>You are viewing the platform demo webapp.</p>
    <div class="env">environment: {env_name}</div>
    <p class="meta">image tag: {image_tag}</p>
  </main>
</body>
</html>
"""


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", "8080")))
