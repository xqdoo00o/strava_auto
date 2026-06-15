const SSO_TARGET_HOST = "sso.garmin.cn";

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (
      url.pathname.startsWith("/sso")
    ) {
      return handleGarminSso(request);
    }

    const proxyMap = {
      "/proxy/onelap/login": "https://www.onelap.cn/api/login",
      "/proxy/onelap/otm": "https://otm.onelap.cn",
      "/proxy/igp/service": "https://prod.zh.igpsport.com/service",
      "/proxy/igp/download": "base64url",
      "/proxy/keep": "https://api.gotokeep.com",
      "/proxy/garmin-cn/connect": "https://connectapi.garmin.cn",
      "/proxy/garmin-cn/diauth": "https://diauth.garmin.cn",
      "/proxy/garmin/connect": "https://connectapi.garmin.com",
      "/proxy/garmin/diauth": "https://diauth.garmin.com",
    };

    const matchedPrefix = Object.keys(proxyMap).find(prefix =>
      url.pathname.startsWith(prefix)
    );

    if (matchedPrefix) {
      return handleNormalProxy(request, matchedPrefix, proxyMap[matchedPrefix]);
    }

    return env.ASSETS.fetch(request);
  },
};

async function handleGarminSso(request) {
  if (request.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: corsHeaders(),
    });
  }

  const url = new URL(request.url);

  const targetUrl = new URL(url.toString());
  targetUrl.protocol = "https:";
  targetUrl.hostname = SSO_TARGET_HOST;

  const headers = new Headers(request.headers);

  headers.set("Host", SSO_TARGET_HOST);
  headers.set("Origin", `https://${SSO_TARGET_HOST}`);
  headers.set("Referer", `https://${SSO_TARGET_HOST}/`);

  headers.delete("cf-connecting-ip");
  headers.delete("cf-ipcountry");
  headers.delete("cf-ray");
  headers.delete("x-forwarded-proto");

  const response = await fetch(targetUrl.toString(), {
    method: request.method,
    headers,
    body:
      request.method === "GET" || request.method === "HEAD"
        ? undefined
        : request.body,
    redirect: "manual",
    cf: {
      cacheTtl: 0,
      cacheEverything: false,
    },
  });

  const respHeaders = new Headers(response.headers);

  const location = respHeaders.get("Location");
  if (location && response.status >= 300 && response.status < 400) {
    respHeaders.set("Location", rewriteLocation(location, request.url));
  }

  Object.entries(corsHeaders()).forEach(([k, v]) => {
    respHeaders.set(k, v);
  });

  respHeaders.delete("content-security-policy");
  respHeaders.delete("content-security-policy-report-only");
  respHeaders.delete("x-frame-options");

  if (targetUrl.pathname === "/sso/js/postmessage.js") {
    let js = await response.text();

    js = js.replace(
      /var\s+newURL\s*=.*?;/g,
      "var newURL      = '*';"
    );

    respHeaders.delete("content-length");

    return new Response(js, {
      status: response.status,
      statusText: response.statusText,
      headers: respHeaders,
    });
  }

  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers: respHeaders,
  });
}

async function handleNormalProxy(request, matchedPrefix, targetBase) {
  if (request.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: corsHeaders(),
    });
  }

  const url = new URL(request.url);
  const remainingPath = url.pathname.replace(matchedPrefix, "");
  let targetUrl = targetBase + remainingPath + url.search;

  if (targetBase === "base64url") {
    const encodedUrl = url.searchParams.get("url");
    targetUrl = atob(encodedUrl);
  }

  const modifiedRequest = new Request(targetUrl, {
    method: request.method,
    headers: request.headers,
    body:
      request.method !== "GET" && request.method !== "HEAD"
        ? request.body
        : null,
    redirect: "follow",
  });

  try {
    let response = await fetch(modifiedRequest);

    response = new Response(response.body, response);
    response.headers.set("Access-Control-Allow-Origin", "*");
    response.headers.set(
      "Access-Control-Allow-Methods",
      "GET, POST, PUT, DELETE, OPTIONS"
    );
    response.headers.set("Access-Control-Allow-Headers", "*");

    return response;
  } catch (e) {
    return new Response(`Proxy Error: ${e.message}`, { status: 502 });
  }
}

function rewriteLocation(location, workerUrl) {
  const worker = new URL(workerUrl);
  const loc = new URL(location, `https://${SSO_TARGET_HOST}`);

  loc.protocol = worker.protocol;
  loc.host = worker.host;

  return loc.toString();
}

function corsHeaders() {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET,POST,PUT,PATCH,DELETE,OPTIONS",
    "Access-Control-Allow-Headers": "*",
    "Access-Control-Max-Age": "86400",
  };
}