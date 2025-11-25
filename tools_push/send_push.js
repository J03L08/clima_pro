const { GoogleAuth } = require('google-auth-library');
const fetch = require('node-fetch');

const projectId = 'clima-pro-461e1';

async function getAccessToken() {
  const auth = new GoogleAuth({
    scopes: ['https://www.googleapis.com/auth/firebase.messaging'],
    keyFile: './serviceAccount.json',
  });
  const client = await auth.getClient();
  const { token } = await client.getAccessToken();
  if (!token) throw new Error('No pude obtener access token');
  return token;
}

async function sendPush(toToken, title, body, data = {}) {
  const accessToken = await getAccessToken();
  const url = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      message: { token: toToken, notification: { title, body }, data },
    }),
  });
  const text = await res.text();
  if (!res.ok) throw new Error(`${res.status} ${text}`);
  console.log('✅ Enviado:', text);
}

const [,, to, title = 'ClimaPro', body = 'Tienes una nueva notificación'] = process.argv;
if (!to) {
  console.error('Uso: node send_push.js <fcmToken> "Título" "Mensaje"');
  process.exit(1);
}

sendPush(to, title, body).catch((e) => {
  console.error('❌ Error:', e.message);
  process.exit(1);
});