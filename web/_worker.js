export default {
  async fetch(request, env) {
    const url = new URL(request.url);

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

    const matchedPrefix = Object.keys(proxyMap)
      .find(prefix => url.pathname.startsWith(prefix));

    if (matchedPrefix) {
      if (request.method === "OPTIONS") {
        return new Response(null, {
          status: 204,
          headers: {
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
            "Access-Control-Allow-Headers": request.headers.get("Access-Control-Request-Headers") || "*",
            "Access-Control-Max-Age": "86400",
          },
        });
      }

      const targetBase = proxyMap[matchedPrefix];
      const remainingPath = url.pathname.replace(matchedPrefix, "");
      let targetUrl = targetBase + remainingPath + url.search;
      console.log(targetUrl);
      if (targetBase === "base64url") {
        const encodedUrl = url.searchParams.get("url");
        targetUrl = atob(encodedUrl);
      }

      const modifiedRequest = new Request(targetUrl, {
        method: request.method,
        headers: request.headers,
        body: request.method !== "GET" && request.method !== "HEAD" ? request.body : null,
        redirect: "follow",
      });

      try {
        let response = await fetch(modifiedRequest);

        response = new Response(response.body, response);
        response.headers.set("Access-Control-Allow-Origin", "*");
        response.headers.set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS");
        response.headers.set("Access-Control-Allow-Headers", "*");

        return response;
      } catch (e) {
        return new Response(`Proxy Error: ${e.message}`, { status: 502 });
      }
    }

    return env.ASSETS.fetch(request);
  },
};
