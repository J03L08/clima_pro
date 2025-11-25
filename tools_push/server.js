// tools_push/server.js
import express from "express";
import cors from "cors";
import bodyParser from "body-parser";
import fetch from "node-fetch";
import { GoogleAuth } from "google-auth-library";
import fs from "fs";

// Carga tu service account y projectId
const sa = JSON.parse(fs.readFileSync("./service-account.json", "utf8"));
const projectId = sa.project_id; // p.ej. "clima-pro-461e1"

const app = express();
app.use(cors());
app.use(bodyParser.json());

app.get("/health", (_, res) => res.send("ok ✅"));

// obtiene un access token para el scope de FCM
async function getAccessToken() {
  const auth = new GoogleAuth({
    credentials: sa,
    scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
  });
  const client = await auth.getClient();
  const token = await client.getAccessToken();
  return token.token;
}

// Enviar notificación vía HTTP v1
app.post("/notify/assignment", async (req, res) => {
  try {
    const { token, title, body, data } = req.body;

    if (!token) {
      return res.status(400).json({ error: "token requerido" });
    }

    const accessToken = await getAccessToken();
    const url = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;

    const payload = {
      message: {
        token,
        notification: { title, body },
        data: data || {},
      },
    };

    const r = await fetch(url, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(payload),
    });

    const text = await r.text();
    let json;
    try { json = JSON.parse(text); } catch { json = { raw: text }; }

    res.status(r.ok ? 200 : r.status).json(json);
  } catch (e) {
    res.status(500).json({ error: String(e) });
  }
});

app.listen(4000, "0.0.0.0", () =>
  console.log("🚀 Push API (HTTP v1) en http://localhost:4000")
);