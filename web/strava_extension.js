(function () {
  let domContentLoadedLoggerRegistered = false;
  let iframeUrlMessengerRegistered = false;

  async function getExtensionTabId() {
    const currentTab = await new Promise((resolve) => {
      chrome.tabs.getCurrent(resolve);
    });
    if (!currentTab?.id) {
      throw new Error('Unable to resolve the extension tab id');
    }
    return currentTab.id;
  }

  async function getOnlyIframeFrame(tabId) {
    const frames = await new Promise((resolve) => {
      chrome.webNavigation.getAllFrames(
        { tabId },
        (items) => resolve(items ?? []),
      );
    });
    const targetFrame = frames.find((frame) => frame.frameId !== 0);
    if (!targetFrame) {
      throw new Error('Unable to find iframe frameId');
    }
    return targetFrame;
  }

  async function getOnlyIframeFrameId(tabId) {
    return (await getOnlyIframeFrame(tabId)).frameId;
  }

  function checkChromeApi() {
    if (!globalThis.chrome?.tabs?.getCurrent) {
      throw new Error('chrome.tabs.getCurrent is unavailable');
    }
    if (!chrome.webNavigation?.getAllFrames) {
      throw new Error('chrome.webNavigation.getAllFrames is unavailable');
    }
    if (!chrome.scripting?.executeScript) {
      throw new Error('chrome.scripting.executeScript is unavailable');
    }
  }

  function registerDomContentLoadedLogger() {
    if (domContentLoadedLoggerRegistered) {
      return;
    }
    if (!globalThis.chrome?.webNavigation?.onDOMContentLoaded) {
      return;
    }
    domContentLoadedLoggerRegistered = true;

    chrome.webNavigation.onDOMContentLoaded.addListener(
      async (details) => {
        try {
          const tabId = await getExtensionTabId();
          if (
            details.tabId !== tabId ||
            details.frameId === 0 ||
            details.parentFrameId !== 0
          ) {
            return;
          }

          const results = await chrome.scripting.executeScript({
            target: {
              tabId,
              frameIds: [details.frameId],
            },
            func: () => {
              const csrfDOM = document.querySelector('meta[name="csrf-token"]');
              const csrfToken = (csrfDOM && csrfDOM.content) || '';
              return {
                url: location.href,
                csrfToken,
              };
            },
          });
          const result = results?.[0]?.result;
          console.log('Strava iframe DOMContentLoaded:', result);
          globalThis.postMessage(
            {
              source: 'stravaExtension',
              type: 'stravaDomContentLoaded',
              payload: result,
            },
            globalThis.location.origin,
          );
        } catch (error) {
          console.log(
            'Failed to read Strava DOMContentLoaded content:',
            error,
          );
        }
      }, {
      url: [
        {
          schemes: ['https'],
          hostSuffix: 'strava.com',
        },
      ],
    }
    );
  }

  function postIframeUrl(url, type = 'stravaIframeUrlChanged') {
    if (!url) {
      return;
    }
    globalThis.postMessage(
      {
        source: 'stravaExtension',
        type,
        payload: { url },
      },
      globalThis.location.origin,
    );
  }

  function registerIframeUrlMessenger() {
    if (iframeUrlMessengerRegistered) {
      return;
    }
    if (!globalThis.chrome?.webRequest?.onBeforeRedirect) {
      return;
    }
    iframeUrlMessengerRegistered = true;

    chrome.webRequest.onBeforeRedirect.addListener(async (details) => {
      try {
        const tabId = await getExtensionTabId();
        if (
          details.tabId !== tabId ||
          details.frameId === 0 ||
          details.parentFrameId !== 0
        ) {
          return;
        }
        if (!details.redirectUrl || details.redirectUrl.startsWith('http')) {
          return;
        }
        postIframeUrl(details.redirectUrl);
      } catch (error) {
        console.log('Failed to post Strava iframe URL:', error);
      }
    }, { urls: ['https://*.strava.com/*'] });
  }

  async function executeInOnlyIframe(func, args = []) {
    checkChromeApi();

    const tabId = await getExtensionTabId();
    const frameId = await getOnlyIframeFrameId(tabId);
    const results = await chrome.scripting.executeScript({
      target: {
        tabId,
        frameIds: [frameId],
      },
      args,
      func,
    });

    return results?.[0]?.result ?? null;
  }

  async function getIframeUrl() {
    checkChromeApi();

    const tabId = await getExtensionTabId();
    const frame = await getOnlyIframeFrame(tabId);
    return frame?.url ?? null;
  }

  async function logout() {
    return executeInOnlyIframe(() => {
      const logoutLink = document.createElement('a');
      logoutLink.rel = 'nofollow';
      logoutLink.dataset.method = 'delete';
      logoutLink.href = '/session';
      logoutLink.style.display = 'none';

      document.body.appendChild(logoutLink);
      logoutLink.click();
      logoutLink.remove();

      return {
        ok: true,
        title: document.title,
        pathname: location.pathname,
      };
    });
  }

  async function upload(fileName, fileBase64) {
    return executeInOnlyIframe(
      async (fileName, fileBase64) => {
        if (location.pathname === '/login') {
          throw new Error('Please log in before uploading a file');
        }

        const csrfToken =
          document.querySelector('meta[name="csrf-token"]')?.content ?? '';
        if (!csrfToken) {
          throw new Error('CSRF token was not found on the current page');
        }

        const binary = atob(fileBase64);
        const bytes = Uint8Array.from(binary, (char) => char.charCodeAt(0));
        const formData = new FormData();
        formData.append('_method', 'post');
        formData.append('authenticity_token', csrfToken);
        formData.append(
          'files[]',
          new Blob([bytes], { type: 'application/octet-stream' }),
          fileName,
        );

        const response = await fetch('https://www.strava.com/upload/files', {
          method: 'POST',
          headers: {
            accept: 'text/plain, */*; q=0.01',
            'x-csrf-token': csrfToken,
            'x-requested-with': 'XMLHttpRequest',
          },
          body: formData,
          credentials: 'include',
        });

        return {
          ok: response.ok,
          status: response.status,
          body: await response.text(),
          pathname: location.pathname,
        };
      },
      [fileName, fileBase64],
    );
  }

  globalThis.stravaExtension = {
    getIframeUrl,
    logout,
    upload,
  };

  registerDomContentLoadedLogger();
  registerIframeUrlMessenger();
})();
