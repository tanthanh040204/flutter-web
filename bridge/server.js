const fs = require('fs');
const path = require('path');
const mqtt = require('mqtt');
const admin = require('firebase-admin');
const ROUTE_IDLE_TIMEOUT_MS = 20000; // 20 giây không có dữ liệu thì đóng route
const ROOT_DIR = __dirname;
const CONFIG_PATH = path.join(ROOT_DIR, 'config.json');

if (!fs.existsSync(CONFIG_PATH)) {
  console.error('[FATAL] Không tìm thấy file bridge/config.json');
  process.exit(1);
}

const config = JSON.parse(fs.readFileSync(CONFIG_PATH, 'utf8'));

const serviceAccountPath = path.resolve(
  ROOT_DIR,
  config.firebase?.serviceAccountPath || './serviceAccountKey.json'
);

if (!fs.existsSync(serviceAccountPath)) {
  console.error(`[FATAL] Không tìm thấy service account file: ${serviceAccountPath}`);
  process.exit(1);
}

const serviceAccount = require(serviceAccountPath);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

const mqttHost = config.mqtt?.host;
const mqttPort = Number(config.mqtt?.port || 8883);
const mqttUsername = config.mqtt?.username;
const mqttPassword = config.mqtt?.password;
const mqttTopic = config.mqtt?.topic || 'vehicles/+/state';
const clientIdPrefix = config.mqtt?.clientIdPrefix || 'bridge_node';

const vehiclesCollection = config.firestore?.vehiclesCollection || 'vehicles';
const writeIntervalMs = Number(config.firestore?.writeIntervalMs || 5000);
const verbose = Boolean(config.logging?.verbose);

if (!mqttHost || !mqttUsername || !mqttPassword) {
  console.error('[FATAL] Thiếu cấu hình MQTT trong config.json');
  process.exit(1);
}

const clientId = `${clientIdPrefix}_${Date.now()}`;
const mqttUrl = `mqtts://${mqttHost}:${mqttPort}`;

const lastWriteAt = new Map();
const lastTotalKmCache = new Map();
const lastVehicleStateCache = new Map();
const activeRoutes = new Map();

function log(...args) {
  if (verbose) {
    console.log(...args);
  }
}

function parseNumber(value, fallback = 0) {
  if (typeof value === 'number' && Number.isFinite(value)) return value;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function parseBoolean(value, fallback = false) {
  if (typeof value === 'boolean') return value;
  if (typeof value === 'string') {
    const v = value.trim().toLowerCase();
    if (v === 'true') return true;
    if (v === 'false') return false;
  }
  return fallback;
}

function resolveVehicleId(topic, data) {
  const parts = topic.split('/');
  const topicVehicleId =
    parts.length >= 2 && parts[1] ? String(parts[1]).trim() : '';

  if (topicVehicleId) return topicVehicleId;

  if (data && typeof data.id === 'string' && data.id.trim()) {
    return data.id.trim().toUpperCase();
  }

  return '';
}

// =========================
// MÚI GIỜ VIỆT NAM (UTC+7)
// =========================
function toVnDate(date = new Date()) {
  const utcMs = date.getTime() + date.getTimezoneOffset() * 60000;
  return new Date(utcMs + 7 * 60 * 60 * 1000);
}

function dayKeyOf(date = new Date()) {
  const vn = toVnDate(date);
  const y = vn.getUTCFullYear();
  const m = String(vn.getUTCMonth() + 1).padStart(2, '0');
  const d = String(vn.getUTCDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

function dayStartOfVn(date = new Date()) {
  const vn = toVnDate(date);
  const y = vn.getUTCFullYear();
  const m = vn.getUTCMonth();
  const d = vn.getUTCDate();

  // 00:00:00 UTC+7 => UTC time = -7h
  return new Date(Date.UTC(y, m, d, 0, 0, 0) - 7 * 60 * 60 * 1000);
}

function routeIdOf(date = new Date()) {
  const vn = toVnDate(date);
  const day = dayKeyOf(date);
  const hh = String(vn.getUTCHours()).padStart(2, '0');
  const mm = String(vn.getUTCMinutes()).padStart(2, '0');
  const ss = String(vn.getUTCSeconds()).padStart(2, '0');
  return `${day}_${hh}${mm}${ss}`;
}

function makePoint(lat, lon, ts, speedKmh, totalKm) {
  return { lat, lon, ts, speedKmh, totalKm };
}

function distanceMetersApprox(a, b) {
  const dx = (a.lon - b.lon) * 111320;
  const dy = (a.lat - b.lat) * 110540;
  return Math.sqrt(dx * dx + dy * dy);
}

async function getPreviousTotalKm(vehicleId, fallbackTotalKm) {
  if (lastTotalKmCache.has(vehicleId)) {
    return lastTotalKmCache.get(vehicleId);
  }

  try {
    const snap = await db.collection(vehiclesCollection).doc(vehicleId).get();
    const prev = snap.exists
      ? parseNumber(snap.data()?.totalKm, fallbackTotalKm)
      : fallbackTotalKm;
    lastTotalKmCache.set(vehicleId, prev);
    return prev;
  } catch (_) {
    lastTotalKmCache.set(vehicleId, fallbackTotalKm);
    return fallbackTotalKm;
  }
}

async function incrementMaintenanceKm(vehicleId, deltaKm) {
  if (!(deltaKm > 0)) return;

  const maintenanceRef = db
    .collection(vehiclesCollection)
    .doc(vehicleId)
    .collection('maintenance');

  const snap = await maintenanceRef.get();
  if (snap.empty) {
    log(`[MAINTENANCE] ${vehicleId} chưa có hạng mục bảo dưỡng để cộng dồn`);
    return;
  }

  const batch = db.batch();
  snap.forEach((doc) => {
    const data = doc.data() || {};
    const current = parseNumber(data.maintanceKm ?? data.maintenanceKm, 0);

    batch.set(
      doc.ref,
      {
        maintanceKm: current + deltaKm,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  });

  await batch.commit();
  log(`[MAINTENANCE] ${vehicleId} +${deltaKm}km cho tất cả hạng mục bảo dưỡng`);
}

async function incrementDailyUsage(vehicleId, totalKm, deltaKm, keepDays = 30) {
  if (!(deltaKm > 0)) return;

  const now = new Date();
  const dayKey = dayKeyOf(now);
  const dayStart = dayStartOfVn(now);

  const docRef = db
    .collection(vehiclesCollection)
    .doc(vehicleId)
    .collection('daily_usage')
    .doc(dayKey);

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(docRef);

    if (!snap.exists) {
      const startTotalKm = Math.max(0, totalKm - deltaKm);

      tx.set(docRef, {
        dayKey,
        dayStart: admin.firestore.Timestamp.fromDate(dayStart),
        startTotalKm,
        endTotalKm: totalKm,
        distanceKm: deltaKm,
        lastSeenAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: admin.firestore.Timestamp.fromDate(
          new Date(dayStart.getTime() + keepDays * 24 * 60 * 60 * 1000)
        ),
      });

      log(
        `[DAILY] CREATE ${vehicleId}/${dayKey} start=${startTotalKm.toFixed(3)} end=${totalKm.toFixed(3)} distance=${deltaKm.toFixed(3)}`
      );
      return;
    }

    const data = snap.data() || {};
    const currentDistance = parseNumber(data.distanceKm, 0);
    const nextDistance = currentDistance + deltaKm;

    tx.set(
      docRef,
      {
        endTotalKm: totalKm,
        distanceKm: nextDistance,
        lastSeenAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    log(
      `[DAILY] UPDATE ${vehicleId}/${dayKey} +${deltaKm.toFixed(3)} => ${nextDistance.toFixed(3)}`
    );
  });
}

async function pruneOldDailyUsage(vehicleId, keepDays = 30) {
  const keepFrom = dayStartOfVn(
    new Date(Date.now() - (keepDays - 1) * 24 * 60 * 60 * 1000)
  );

  const snap = await db
    .collection(vehiclesCollection)
    .doc(vehicleId)
    .collection('daily_usage')
    .where('dayStart', '<', admin.firestore.Timestamp.fromDate(keepFrom))
    .get();

  if (snap.empty) return;

  const batch = db.batch();
  snap.forEach((doc) => batch.delete(doc.ref));
  await batch.commit();

  log(`[DAILY] PRUNE ${vehicleId} deleted ${snap.size} old docs`);
}

async function createRouteDoc(vehicleId, route) {
  await db
    .collection(vehiclesCollection)
    .doc(vehicleId)
    .collection('history_routes')
    .doc(route.routeId)
    .set(
      {
        vehicleId,
        dayKey: route.dayKey,
        startAt: admin.firestore.Timestamp.fromDate(route.startAt),
        endAt: route.endAt
          ? admin.firestore.Timestamp.fromDate(route.endAt)
          : null,
        isClosed: route.isClosed,
        startTotalKm: route.startTotalKm,
        endTotalKm: route.endTotalKm,
        distanceKm: Math.max(0, route.endTotalKm - route.startTotalKm),
        points: route.points,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
}

async function startRoute(vehicleId, point, totalKm, nowDate) {
  const route = {
    routeId: routeIdOf(nowDate),
    dayKey: dayKeyOf(nowDate),
    startAt: nowDate,
    endAt: null,
    isClosed: false,
    startTotalKm: totalKm,
    endTotalKm: totalKm,
    lastPacketAt: nowDate,
    timeoutHandle: null,
    points: [point],
  };

  activeRoutes.set(vehicleId, route);
  await createRouteDoc(vehicleId, route);
  scheduleRouteTimeout(vehicleId);

  log(`[ROUTE] START ${vehicleId} -> ${route.routeId}`);
}

async function appendRoutePoint(vehicleId, point, totalKm, nowDate) {
  const route = activeRoutes.get(vehicleId);
  if (!route) return;

  route.lastPacketAt = nowDate;
  route.endTotalKm = totalKm;

  const lastPoint = route.points[route.points.length - 1];
  const movedEnough = !lastPoint || distanceMetersApprox(lastPoint, point) >= 5;
  const timeEnough = !lastPoint || (point.ts - lastPoint.ts) >= 15000;

  if (movedEnough || timeEnough) {
    route.points.push(point);
    await createRouteDoc(vehicleId, route);
  }

  refreshRouteActivity(vehicleId, nowDate);
}

async function closeRoute(vehicleId, point, totalKm, nowDate) {
  const route = activeRoutes.get(vehicleId);
  if (!route) return;

  if (route.timeoutHandle) {
    clearTimeout(route.timeoutHandle);
    route.timeoutHandle = null;
  }

  route.endAt = nowDate;
  route.isClosed = true;
  route.endTotalKm = totalKm;

  const lastPoint = route.points[route.points.length - 1];
  if (!lastPoint || distanceMetersApprox(lastPoint, point) >= 1) {
    route.points.push(point);
  }

  await createRouteDoc(vehicleId, route);
  activeRoutes.delete(vehicleId);

  log(`[ROUTE] CLOSE ${vehicleId} -> ${route.routeId}`);
}

async function pruneOldRoutes(vehicleId, keepDays = 30) {
  const keepFrom = dayStartOfVn(
    new Date(Date.now() - (keepDays - 1) * 24 * 60 * 60 * 1000)
  );

  const snap = await db
    .collection(vehiclesCollection)
    .doc(vehicleId)
    .collection('history_routes')
    .where('startAt', '<', admin.firestore.Timestamp.fromDate(keepFrom))
    .get();

  if (snap.empty) return;

  const batch = db.batch();
  snap.forEach((doc) => batch.delete(doc.ref));
  await batch.commit();

  log(`[ROUTE] PRUNE ${vehicleId} deleted ${snap.size} old routes`);
}

async function saveVehicleState(topic, data) {
  const vehicleId = resolveVehicleId(topic, data);
  if (!vehicleId) {
    log('[WARN] Không xác định được vehicleId từ topic/payload:', topic, data);
    return;
  }

  const now = Date.now();
  const last = lastWriteAt.get(vehicleId) || 0;

  if (now - last < writeIntervalMs) {
    log(`[SKIP] ${vehicleId} chưa đủ ${writeIntervalMs}ms để ghi tiếp`);
    return;
  }

  lastWriteAt.set(vehicleId, now);

  const lat = parseNumber(data.lat, 0);
  const lon = parseNumber(data.lon, 0);
  const batteryPercent = Math.max(
    0,
    Math.min(100, parseNumber(data.batteryPercent, 0))
  );
  const totalKm = parseNumber(data.totalKm, 0);
  const speedKmh = parseNumber(data.speedKmh, 0);
  const avgSpeedKmh = parseNumber(data.avgSpeedKmh, 0);

  const temp = parseNumber(data.temp, 0);
  const hum = parseNumber(data.hum, 0);
  const dust = parseNumber(data.dust, 0);

  const isLocked = parseBoolean(data.isLocked, false);
  const isRunning = parseBoolean(data.isRunning, false);

  const mqttTs = parseNumber(data.ts, Date.now());
  const nowDate = new Date();

  const previousTotalKm = await getPreviousTotalKm(vehicleId, totalKm);
  const deltaKm = Math.max(0, totalKm - previousTotalKm);
  lastTotalKmCache.set(vehicleId, totalKm);

  const point = makePoint(lat, lon, mqttTs, speedKmh, totalKm);

  const prevState = lastVehicleStateCache.get(vehicleId) || {
  isLocked: true,
  isRunning: false,
};

const active = activeRoutes.get(vehicleId);

// nếu qua ngày mới thì đóng route cũ và mở route mới
if (active && active.dayKey !== dayKeyOf(nowDate)) {
  await closeRoute(vehicleId, point, totalKm, nowDate);
}

if (!activeRoutes.has(vehicleId)) {
  await startRoute(vehicleId, point, totalKm, nowDate);
} else {
  await appendRoutePoint(vehicleId, point, totalKm, nowDate);
}

const shouldCloseRoute =
  activeRoutes.has(vehicleId) &&
  ((prevState.isRunning && !isRunning) || (!prevState.isLocked && isLocked));

if (shouldCloseRoute) {
  await closeRoute(vehicleId, point, totalKm, nowDate);
}

lastVehicleStateCache.set(vehicleId, {
  isLocked,
  isRunning,
});

  const doc = {
    id: vehicleId,
    name: data.name || vehicleId,
    batteryPercent,
    isLocked,
    isRunning,
    totalKm,
    speedKmh,
    avgSpeedKmh,
    temp,
    hum,
    dust,
    lastLocation: {
      lat,
      lon,
      name: data.name || vehicleId,
      totalKm,
    },
    mqttLastTopic: topic,
    mqttRawTs: data.ts ?? null,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  await db.collection(vehiclesCollection).doc(vehicleId).set(doc, { merge: true });

  if (deltaKm > 0) {
    await incrementMaintenanceKm(vehicleId, deltaKm);
    await incrementDailyUsage(vehicleId, totalKm, deltaKm, 30);
  }

  await pruneOldRoutes(vehicleId, 30);
  await pruneOldDailyUsage(vehicleId, 30);

  log(
    `[SAVE] ${vehicleId} totalKm=${totalKm.toFixed(3)} deltaKm=${deltaKm.toFixed(3)} temp=${temp} hum=${hum} dust=${dust}`
  );
}

const mqttClient = mqtt.connect(mqttUrl, {
  clientId,
  username: mqttUsername,
  password: mqttPassword,
  reconnectPeriod: 2000,
  connectTimeout: 10000,
  clean: true,
});

mqttClient.on('connect', () => {
  console.log('[MQTT] Connected:', mqttUrl);
  mqttClient.subscribe(mqttTopic, { qos: 1 }, (err) => {
    if (err) {
      console.error('[MQTT] Subscribe error:', err.message || err);
      return;
    }
    console.log('[MQTT] Subscribed topic:', mqttTopic);
  });
});

mqttClient.on('reconnect', () => {
  console.log('[MQTT] Reconnecting...');
});

mqttClient.on('close', () => {
  console.log('[MQTT] Connection closed');
});

mqttClient.on('error', (err) => {
  console.error('[MQTT] Error:', err.message || err);
});

mqttClient.on('message', async (topic, payloadBuffer) => {
  const raw = payloadBuffer.toString();

  log('\n[MQTT] Message received');
  log('  topic   =', topic);
  log('  payload =', raw);

  try {
    const data = JSON.parse(raw);
    await saveVehicleState(topic, data);
  } catch (err) {
    console.error('[MQTT->FIRESTORE] Save failed:', err.message || err);
  }
});

process.on('SIGINT', async () => {
  console.log('\n[APP] Stopping bridge...');
  try {
    mqttClient.end(true);
  } catch (_) {}
  process.exit(0);
});

function scheduleRouteTimeout(vehicleId) {
  const route = activeRoutes.get(vehicleId);
  if (!route) return;

  if (route.timeoutHandle) {
    clearTimeout(route.timeoutHandle);
  }

  route.timeoutHandle = setTimeout(async () => {
    try {
      const current = activeRoutes.get(vehicleId);
      if (!current || current.isClosed) return;

      const timeoutAt = new Date();
      const lastPoint = current.points[current.points.length - 1];

      await closeRoute(
        vehicleId,
        lastPoint || { lat: 0, lon: 0, ts: Date.now(), speedKmh: 0, totalKm: current.endTotalKm },
        current.endTotalKm,
        timeoutAt
      );
    } catch (e) {
      console.error(`[ROUTE] timeout close failed for ${vehicleId}:`, e.message || e);
    }
  }, ROUTE_IDLE_TIMEOUT_MS);
}

function refreshRouteActivity(vehicleId, nowDate) {
  const route = activeRoutes.get(vehicleId);
  if (!route) return;
  route.lastPacketAt = nowDate;
  scheduleRouteTimeout(vehicleId);
}